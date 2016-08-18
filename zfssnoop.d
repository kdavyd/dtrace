#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option switchrate=10hz

/*
Collect information about file calls against ZFS
filesystems and at termination aggregate counts
for each call
*/

dtrace:::BEGIN
{
    printf("%-21s %6s %6s %-12.12s %-12s %-4s %s\n", "TIMESTAMP", "UID",
        "PID", "PROCESS", "CALL", "KB", "PATH");
}

/* see uts/common/fs/zfs/zfs_vnops.c */

fbt::zfs_read:entry, fbt::zfs_write:entry
{
    self->path = args[0]->v_path;
    self->kb = args[1]->uio_resid / 1024;
    self->time = walltimestamp;
}

fbt::zfs_open:entry
{
    self->path = (*args[0])->v_path;
    self->kb = 0;
    self->time = walltimestamp;
}

fbt::zfs_close:entry, fbt::zfs_ioctl:entry, fbt::zfs_getattr:entry,
fbt::zfs_readdir:entry
{
    self->path = args[0]->v_path;
    self->kb = 0;
    self->time = walltimestamp;
}

fbt::zfs_read:entry, fbt::zfs_write:entry, fbt::zfs_open:entry,
fbt::zfs_close:entry, fbt::zfs_ioctl:entry, fbt::zfs_getattr:entry,
fbt::zfs_readdir:entry
{
    @[probefunc,stringof(self->path)] = count();
    printf("%-21Y %6d %6d %-12.12s %-12s %-4d %s\n", self->time,
        uid, pid, execname, probefunc, self->kb,
        self->path != NULL ? stringof(self->path) : "<null>");
    self->path = 0; self->kb = 0;
}

dtrace:::END
{   
    printf("%s\n", " ... ");
    printf("%-12s %-60s %-8s\n", "CALL", "PATH", "COUNT");
    printa("%-12s %-60s %@-8d\n", @);
    exit(0);
}
