#!/usr/sbin/dtrace -s

txg_delay:entry
{
        @[probefunc]=count();
}

dsl_pool_tempreserve_space:return
/args[1]==91/
{
        @r[probefunc]=count();
}

tick-10sec
{
        printa("Writes delayed %@d times in last interval\n",@);
        printa("Writes throttled %@d times in last interval", @r);
        trunc(@);
        trunc(@r);
} 
