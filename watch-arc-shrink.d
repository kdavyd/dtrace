#!/usr/sbin/dtrace -s

fbt:zfs:arc_reclaim_needed:return
/args[1]/
{
	printf("%Y return=%d\n", walltimestamp, args[1]);
}

fbt:zfs:arc_shrink:entry 
{
	printf("%Y\n", walltimestamp);
}

