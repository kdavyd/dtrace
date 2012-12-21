#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option defaultargs
#pragma D option switchrate=10hz

dtrace:::BEGIN
{

}

/* see uts/common/fs/zfs/zfs_vnops.c */

fbt::zfs_read:entry,
fbt::zfs_write:entry
{
	self->path = args[0]->v_path;
	self->bytes = args[1]->uio_resid;
	self->start = timestamp;
}

fbt::zfs_read:return
/ this->iotime = (timestamp - self->start) /
{
        this->latency_ms =  this->iotime / 1000;
/*        printf("read  %5d  %5d\n", self->bytes, this->latency_ms); */
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        /* this->size = args[0]->b_bcount; */
        @bsize["read_b"] = avg(self->bytes);
        @avg_latency["read_lat"] = avg(this->latency_ms); 
}


fbt::zfs_write:return
/ this->iotime = (timestamp - self->start) /
{
        this->latency_ms =  this->iotime / 1000;
/*        printf("write  %5d  %5d\n", self->bytes, this->latency_ms); */
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        /* this->size = args[0]->b_bcount; */
        @bsize["write_b"] = avg(self->bytes);
        @avg_latency["write_lat"] = avg(this->latency_ms);
}

tick-1sec
/this->latency_ms > 0/
{
		printf("%u ",walltimestamp/1000000000);
	    printa("%s %@d ", @avg_latency);
	    printa("\t%s %@d ", @bsize);
	    printf("%s\n", "");
		self->path = 0; self->bytes = 0; self->start = 0;
		clear(@avg_latency); clear(@bsize);
}


/* fbt::zfs_read:return,
fbt::zfs_write:return
{
	self->path = 0; self->bytes = 0; self->start = 0;
	clear(@avg_latency); clear(@bsize);
} */