#!/usr/sbin/dtrace -FCs

$1:entry
{
	self->trace = 1;
}

$1:return
{
	printf("Returns 0x%llx", arg1);
	self->trace = 0;
}

::entry
/self->trace == 1/
{
}

::return
/self->trace == 1/
{
	printf("Returns 0x%llx", arg1);
}
