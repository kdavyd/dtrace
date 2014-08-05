#!/usr/sbin/dtrace -s
#pragma D option quiet

allocb_oversize:entry
{
        @[stack()]=count();
        @s=sum(arg0);
}

tick-10sec
{
        printf("%Y\n",walltimestamp);
        printa(@);
        printa(@s);
}
