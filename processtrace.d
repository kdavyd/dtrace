#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option switchrate=10

proc:::create
{
	printf("%s %d %d 0 0 %s fork - - %d\n", zonename, pid, args[0]->pr_pid,
	    execname, timestamp);
	start[args[0]->pr_pid] = timestamp;
}

proc:::exec-success
{
	printf("%s %d %d 0 0 %s exec - - %d\n", zonename, ppid, pid,
	    execname, timestamp);
}

proc:::exit
/(this->s = start[pid])/
{
	printf("%s %d %d 0 0 %s exit %d ms %d\n", zonename, ppid, pid,
	    execname, (timestamp - this->s) / 1000000, timestamp);
	start[pid] = 0;
}

profile:::tick-1s
{
	printf("- - - - - - tick 1s - %d\n", timestamp);
}
