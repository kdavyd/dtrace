#!/usr/sbin/dtrace -s
/*
 * vnodeops.d	show latency in microseconds at the VFS layer for the various 
 * vnode types when reads, writes or fsyncs occur.
 *
 * This is based on scsilatency.d from the DTrace book, chapter 4.
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
 * Copyright (c) 2013 RackTop Systems, All rights reserved.
 * Copyright (c) 2013 Sam Zaydel, All rights reserved.
 *
 * CDDL HEADER END
 *
*/
 #pragma D option quiet

string vnode_type[uchar_t];

dtrace:::BEGIN
{
	/* See /usr/src/uts/common/sys/vnode.h for the full list. */
	vnode_type[0] = "no_type";
	vnode_type[1] = "regular";
	vnode_type[2] = "directory";
	vnode_type[3] = "block_device";
	vnode_type[4] = "character_device";
	vnode_type[5] = "link";
	vnode_type[6] = "fifo";
	vnode_type[7] = "door";
	vnode_type[8] = "procfs";
	vnode_type[9] = "sockfs";
	vnode_type[10] = "event_port";
	vnode_type[11] = "bad_vnode";

	printf("Tracing... Hit Ctrl-C to end.\n\n");
}

fbt:genunix:fop_fsync:entry,
fbt:genunix:fop_read:entry,
fbt:genunix:fop_write:entry {

	self->start = timestamp;
	this->type = args[0]->v_type;
	self->vnodetype = vnode_type[this->type] != NULL ? vnode_type[this->type] : "NULL";
}

fbt:genunix:fop_fsync:return,
fbt:genunix:fop_read:return,
fbt:genunix:fop_write:return 
/self->start/
{
	this->delta = timestamp - self->start;
	@latbytype["Time(us):", self->vnodetype, probefunc] = quantize(this->delta / 1000);
	self->start = 0;
	this->delta = 0;
	self->vnodetype = "x";
}
