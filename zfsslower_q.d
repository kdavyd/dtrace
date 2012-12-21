#!/usr/sbin/dtrace -s
/*
 * zfsslower.d	show ZFS I/O taking longer than given ms.
 *
 * USAGE: zfsslower.d min_ms
 *    eg,
 *        zfsslower.d 100	# show I/O at least 100 ms
 *
 * This is from the DTrace book, chapter 5.  It has been enhanced to include
 * zfs_readdir() as well, which is shown in the "D" (direction) field as "D".
 *
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License, Version 1.0 only
 * (the "License").  You may not use this file except in compliance
 * with the License.
 *
 * You can obtain a copy of the license at http://smartos.org/CDDL
 *
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file.
 *
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 *
 * Copyright (c) 2012 Joyent Inc., All rights reserved.
 * Copyright (c) 2012 Brendan Gregg, All rights reserved.
 *
 * TESTED: this fbt provider based script may only work on some OS versions.
 *      121: ok
 */

#pragma D option quiet
#pragma D option defaultargs
#pragma D option switchrate=10hz

dtrace:::BEGIN
{
        printf("%-20s %-16s %1s %4s %6s %s\n", "TIME", "PROCESS",
            "D", "KB", "ms", "FILE");
        min_ns = $1 * 1000000;
}

/* see uts/common/fs/zfs/zfs_vnops.c */

fbt::zfs_read:entry, fbt::zfs_write:entry
{
        self->path = args[0]->v_path;
        self->kb = args[1]->uio_resid / 1024;
        self->start = timestamp;
}

fbt::zfs_readdir:entry
{
        self->path = args[0]->v_path;
        self->kb = 0;
        self->start = timestamp;
}

fbt::zfs_read:return, fbt::zfs_write:return, fbt::zfs_readdir:return
/self->start && (timestamp - self->start) >= min_ns/
{
        this->iotime = (timestamp - self->start) / 1000;
/*	this->dir = probefunc == "zfs_read" ? "R" :
	    probefunc == "zfs_write" ? "W" : "D";
        printf("%-20Y %-16s %1s %4d %6d %s\n", walltimestamp,
            execname, this->dir, self->kb, this->iotime,
            self->path != NULL ? stringof(self->path) : "<null>"); */

    @zfsIOlat[ this->dir = probefunc == "zfs_read" ? "R" :
        probefunc == "zfs_write" ? "W" : "D" ] = quantize(this->iotime);
}

fbt::zfs_read:return, fbt::zfs_write:return, fbt::zfs_readdir:return
{
        self->path = 0; self->kb = 0; self->start = 0;
}