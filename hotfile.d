#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
	printf("Tracing... Hit Ctrl-C to end.\n");
	line = "-----------";
	x = 0;
	hotcount = 10;
}

nfsv3:::op-read-start,
nfsv3:::op-write-start

{
	this->filepath = args[1]->noi_curpath;
    start[args[1]->noi_xid] = timestamp;
    active_nfs = 1;
    x = 1;
}

io:::start 
/active_nfs != 0/

{
	this->bytes = args[0]->b_bcount;
	/* @bytesize[args[2]->fi_pathname,pid, curpsinfo->pr_psargs] = quantize(this->bytes); */
	@totalb[args[0]->b_flags & B_READ ? "[READ]" : "[WRITE]", args[2]->fi_pathname] = sum(this->bytes);
}

nfsv3:::op-read-done,
nfsv3:::op-write-done
/start[args[1]->noi_xid] != 0/

{
    this->elapsed = timestamp - start[args[1]->noi_xid];
    /* this->filepath = args[1]->noi_curpath; */
    @nfs_rwtime[this->filepath, probename == "op-read-done" ? "Read time(us)" : "Write time(us)"] =
        quantize(this->elapsed / 1000);
    /* @host[args[0]->ci_remote] = sum(this->elapsed); */
    @rwlatency[args[0]->ci_remote, this->filepath,
    probename == "op-read-done" ? "Read time" : "Write time"] = sum(this->elapsed);

    start[args[1]->noi_xid] = 0;
    active_nfs = 0;
}

nfsv3:::op-read-done
{
	this->bytes = args[2]->res_u.ok.data.data_len;
	@nfsopsbypath["[READ]", this->filepath] = count();
    /* Collect sum of bytes for each client IP address */
    @nfsreadbytes[args[0]->ci_remote, "[READ]"] = sum(this->bytes);
    @busyfiles["[READ]", this->filepath] = sum(this->bytes);
}


nfsv3:::op-write-done
{	
	this->bytes = args[2]->res_u.ok.count;
	@nfsopsbypath["[WRITE]", this->filepath] = count();
	/* Collect sum of bytes for each client IP address */
	@nfswritebytes[args[0]->ci_remote, "[WRITE]"] = sum(this->bytes);
	@busyfiles["[WRITE]", this->filepath] = sum(this->bytes);
}

tick-1sec
/ x != 0 /
{
	printa("Client IP: %-16s NFS I/O: %-8s %@d bytes\n", @nfsreadbytes); 
	printa("Client IP: %-16s NFS I/O: %-8s %@d bytes\n", @nfswritebytes);
	printa("                            Physical I/O: %s %@d bytes\n", @totalb);
	normalize(@rwlatency,1000000); trunc(@rwlatency,5); trunc(@nfs_rwtime,5);
	printa("Client IP: %-16s Path: %s\n%s (ms) %@d\n", @rwlatency); printa(@nfs_rwtime);
	trunc(@nfs_rwtime); trunc(@rwlatency);
	trunc(@nfsreadbytes); trunc(@nfswritebytes); trunc(@totalb);
	x = 0;
}

dtrace:::END
{
	/* trunc(@bytesize,5);
	trunc(@totalb,5);
	printf("\n%-60s  %-8s %s\n", "Pathname", "PID", "CMD");
	printa("%-60s %-8d %S\n%@d\n", @bytesize);
	printa("----------\nPath: %s\nBytes Total: %@d\n----------\n",@totalb); */
	/* Summarize total operations and number of bytes read and written
	for each file, organized by path, and trimmed to number of files 
	equal to value of hotcount var. */
    printf("%s\n\n","---------------------- NFSv3 Read/Write top files Summary ----------------------");
    trunc(@busyfiles, hotcount);
    trunc(@nfsopsbypath, hotcount);

    printa("%s Path: %s %@d bytes, Operations: %@d\n", @busyfiles,@nfsopsbypath);
    /* normalize(@file, 1000);
    printa(@file); */
}
