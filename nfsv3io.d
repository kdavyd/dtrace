#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
        interval = 5;
        printf("Tracing... Interval %d secs.\n", interval);
        tick = interval;
}

nfsv3:::op-*
{
        @ops[args[0]->ci_remote] = count();
}

nfsv3:::op-read-done
{
        @reads[args[0]->ci_remote] = count();
        @readbytes[args[0]->ci_remote] = sum(args[2]->res_u.ok.data.data_len);
}


nfsv3:::op-write-done
{
        @writes[args[0]->ci_remote] = count();
        @writebytes[args[0]->ci_remote] = sum(args[2]->res_u.ok.count);
}

profile:::tick-1sec
/tick-- == 0/
{
        normalize(@ops, interval);
        normalize(@reads, interval);
        normalize(@writes, interval);
        normalize(@writebytes, 1024 * interval);
        normalize(@readbytes, 1024 * interval);
        printf("\n   %-32s %6s %6s %6s %6s %8s\n", "Client", "r/s", "w/s",
            "kr/s", "kw/s", "ops/s");
        printa("   %-32s %@6d %@6d %@6d %@6d %@8d\n", @reads, @writes,
            @readbytes, @writebytes, @ops);
        trunc(@ops);
        trunc(@reads);
        trunc(@writes);
        trunc(@readbytes);
        trunc(@writebytes);
        tick = interval;
}