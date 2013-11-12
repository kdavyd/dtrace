#!/usr/sbin/dtrace -s
#pragma D option quiet

emlxs_reset:entry
{
    @[stack(100)]=count();
    printf("%Y: Reset entry command %d\n",walltimestamp,args[1]);
}

emlxs_reset:return
{
    printf("%Y: Reset return code %d\n",walltimestamp,args[1]);
    printa(@);
}

tick-30sec
{
    printa(@);trunc(@);
}
