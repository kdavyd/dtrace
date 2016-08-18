#!/usr/sbin/dtrace -s

#pragma D option quiet

BEGIN
{
fpath = $1
}

syscall::read:entry,syscall::write:entry
/ fds[arg0].fi_pathname == fpath /
{
@fs[execname, fds[arg0].fi_pathname] = count(); 
self->ts = timestamp;
 } 

::ddt*:entry, ::zio_ddt*:entry
/self->ts && probefunc != "ddt_prefetch"/
{
@st[probefunc, stack()] = count();
printf("%s %Y\n", probefunc, walltimestamp);

self->ts = 0;
}

END
{
printa("Command: %-20s Count: %-@8d\nPath: %s", @fs);
trunc(@st,5);
exit(0);
}
