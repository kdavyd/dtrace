#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
        trace("Tracing... Interval 5 secs.\n");
}

nfsv3:::op-*
{
        @ops[args[0]->ci_remote, probename] = count();
}

profile:::tick-5sec,
dtrace:::END
{
        printf("\n   %-32s %-28s %8s\n", "Client", "Operation", "Count");
        printa("   %-32s %-28s %@8d\n", @ops);
        trunc(@ops);
}