#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option defaultargs
#pragma D option switchrate=10hz

dtrace:::BEGIN
{
        rx = 0; wx = 0;
}

/* see uts/common/fs/zfs/zfs_vnops.c */

fbt::zfs_read:entry,
fbt::zfs_write:entry,
fbt::zfs_fsync:entry
{
	self->path = args[0]->v_path;
        self->bytes = ((uio_t *)arg1)->uio_resid;
	self->start = timestamp;
        self->id = self->start+self->bytes;
}

fbt::zfs_read:return
/ self->bytes != NULL && self->start+self->bytes == self->id /

{
        this->latency = (timestamp - self->start) / 1000;
        this->ops = "read";
        @bytes["bytes"] = sum(self->bytes);
        @latency["Dist (bytes/us):", this->ops] = quantize(self->bytes/this->latency);
}

fbt::zfs_write:return
/ self->bytes != NULL && self->start+self->bytes == self->id /

{
        this->latency = (timestamp - self->start) / 1000;
        this->ops = "write";
        @latency["Dist (bytes/us):", this->ops] = quantize(self->bytes/this->latency);
}

fbt::zfs_read:return,
fbt::zfs_write:return
/ self->bytes != NULL && self->start+self->bytes == self->id /

{
        self->start = 0;
        self->bytes = 0;
        self->id = 0;
}

tick-30sec
{
	printa("%18s %s %@d\n", @latency);
        printa(@bytes);
	trunc(@latency);
        trunc(@bytes);
}