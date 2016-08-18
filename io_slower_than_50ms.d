#!/usr/sbin/dtrace -s
/*
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
 * Copyright (c) 2012 RackTop Systems, All rights reserved.
 *
 * Script should help to pinpoint disks which are seemingly slower than
 * most, i.e. we can collect top 5 or in this case top 10 slowest to respond
 * disks on a system.
 * io_slower_than_50ms.d: show Physical I/O events taking longer than 50 ms.
 *
 * USAGE: io_slower_than_50ms.d
 *
 */

#pragma D option quiet
#pragma D option defaultargs
#pragma D option switchrate=10hz

#pragma D option quiet

BEGIN {
	x = 0; 
	y = 0;
	watermark = 50; /* We want to track all IO slower than 50ms. */
	start_d = timestamp;
	to_millisec = 1000000;
	div = "--------------------------------------------------------------------------------";
}

io::bdev_strategy:start
{
	st[args[0]->b_edev, args[0]->b_blkno, args[0]->b_addr] = timestamp;
	blk_addr = args[0]->b_addr;
} 

io:::done 
/ st[args[0]->b_edev, args[0]->b_blkno, args[0]->b_addr] /
{
	x = (timestamp - st[args[0]->b_edev, args[0]->b_blkno, args[0]->b_addr]) / to_millisec;
	@[args[0]->b_bcount/0x1000] = lquantize(x,20,80,10);
}

io:::done
/* We should arrive here eveery time we hip IO that passes the watermark
and we increment counter as well as add event to aggregation. */
/ x > watermark /
{
	y += 1;
	@slower_than_wm[args[1]->dev_pathname] = count();
}

io:::done
/ st[args[0]->b_edev, args[0]->b_blkno, args[0]->b_addr] /
{
	st[args[0]->b_edev, args[0]->b_blkno, args[0]->b_addr] = 0;
	blk_addr = 0;
	x = 0;
}

END
{
	stop_d = (timestamp - start_d) / to_millisec;
	trunc(@slower_than_wm,10);
	printa("\t time(ms)\t\t\t\t blocksize (KB): %d %24@d\n",@);
	printf("%s\n",div);
	printf("Top 10 slow disks by count of IO events longer than %d (ms)\n",watermark);
	printf("%s\n",div);
	printa("Number of slow IO events: %@d device: %s\n",@slower_than_wm);
	printf("%s\n",div);
	printf("Counted a total of %d events slower than %d (ms) in last %d seconds\n",y,watermark,stop_d/1000);
}
