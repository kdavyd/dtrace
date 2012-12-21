#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option dynvarsize=4m
#pragma D option switchrate=10hz

/* This script quantizes IO by path, when first argument given is
a partial path. Normally, expecting to see a partial path to data
on a ZFS dataset. Since `/volumes` is the default path under which
all datasets are mounted, we would expect to see /volumes/poolname...
*/

dtrace:::BEGIN
{
	/* printf("%-12s %40s\n", "OP SIZE", "PATH"); */
	printf("Tracing... Hit Ctrl-C to end.\n");
	path = $1;
	read = 0;
	write = 0;

}

/* see uts/common/fs/zfs/zfs_vnops.c */

fbt::zfs_read:entry
/* Match first parameter on command line, 
expecting partial path, like /volumes/poolname */

/* If we cannot extract path information, we ignore. */
/args[0]->v_path != NULL && strstr(stringof(args[0]->v_path), path) != NULL/
{
	read = 1;
	self->path = args[0]->v_path;
	self->bytes = args[1]->uio_resid;

	@rbytes["read bytes", self->path != NULL ? stringof(self->path) : "<null>"] = quantize(self->bytes);
}

fbt::zfs_write:entry
/* Match first parameter on command line, 
expecting partial path, like /volumes/poolname */

/* If we cannot extract path information, we ignore. */
/args[0]->v_path != NULL && strstr(stringof(args[0]->v_path), path) != NULL/
{
	write = 1;
	self->path = args[0]->v_path;
	self->bytes = args[1]->uio_resid;

	@wbytes["write bytes", self->path != NULL ? stringof(self->path) : "<null>"] = quantize(self->bytes);

}

dtrace:::END
/read > 0/
{
	printa("%-16s Path: %s %@d\n", @rbytes);
}

dtrace:::END
/write > 0/
{
	printa("%-16s Path: %s %@d\n", @wbytes);
}