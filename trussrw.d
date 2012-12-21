/*
* Run script with dtrace -qs	
*/
dtrace:::BEGIN
	{
		i = 20;
	}


syscall::read:entry,
syscall::write:entry
/i > 0, pid == $1/
{
	trace(i--);
	printf("\n[%s] , %s, %s(%d, 0x%x, %4d)", execname, probename, probefunc, arg0, arg1, arg2);
}

syscall::read:return,
syscall::write:return
/pid == $1/
{
	printf("\t\t = %d\n", arg1);
}

syscall::read:entry,
syscall::write:entry
/i == 0/
{
	trace("blastoff!");
	exit(0)
}