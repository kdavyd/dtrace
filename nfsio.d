#!/usr/sbin/dtrace -s
#pragma D option quiet

dtrace:::BEGIN
{
        trace("Tracing... Hit Ctrl-C to end.\n");
}

nfsv3:::op-read-done
{
        @readbytes[args[1]->noi_curpath] = sum(args[2]->res_u.ok.data.data_len);
        @readiops[args[1]->noi_curpath] = count();
        @readbs[args[1]->noi_curpath] = avg(args[2]->res_u.ok.data.data_len);
}

nfsv4:::op-read-done
{
        @readbytes[args[1]->noi_curpath] = sum(args[2]->data_len);
        @readiops[args[1]->noi_curpath] = count();
        @readbs[args[1]->noi_curpath] = avg(args[2]->data_len);
}

nfsv3:::op-write-done
{
        @writebytes[args[1]->noi_curpath] = sum(args[2]->res_u.ok.count);
        @writeiops[args[1]->noi_curpath] = count();
        @writebs[args[1]->noi_curpath] = avg(args[2]->res_u.ok.count);
}

nfsv4:::op-write-done
{
        @writebytes[args[1]->noi_curpath] = sum(args[2]->count);
        @writeiops[args[1]->noi_curpath] = count();
        @writebs[args[1]->noi_curpath] = avg(args[2]->count);
}

dtrace:::END
{
        printf("\n%12s %12s %12s %12s %12s %12s %s\n", "Rbytes", "Rops", "Rbs", "Wbytes", "WOps", "Wbs", "Pathname");
        printa("%@12d %@12d %@12d %@12d %@12d %@12d %s\n", @readbytes, @readiops, @readbs, @writebytes, @writeiops, @writebs);
}
