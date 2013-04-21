#!/usr/sbin/dtrace -s
#pragma D option quiet

/* Description: This script measures the ZFS transaction group commit time, and tracks
 * several variables that affect it for each individual zpool. One of the key things it
 * also looks at is the amount of throttling and delaying that happens in each individual
 * spa_sync().
 * Some important concepts:
 * 1. Delaying (dly) means injecting a one-tick delay into the TXG coalescing 
 *    process,  effectively slowing down the rate at which the transaction group 
 *    fills. Throttling (thr), on the other hand means closing this TXG entirely, sending 
 *    it off to quiesce and then  flush to disk, and pushing all new incoming data 
 *    into the next TXG that is now "filling".
 * 2. The feedback loop which determines when to stop filling the current TXG and
 *    start a new one depends on a few kernel variables. The cutoff trigger (size)
 *    is calculated from dp_tempreserved and dp_space_towrite, which this script 
 *    combines into a value of reserved_max (res_max), duplicating the calculation
 *    that happens in the kernel. When res_max reaches 7/8 of current dp_write_limit,
 *    system starts delaying writes. When res_max reaches current dp_write_limit, 
 *    system attempts a throttle, which has higher impact on performance. It is not
 *    normal for a system to be constantly throttling/delaying, but if this happens
 *    from time to time it's okay - the feedback loop likely set dp_write_limit too
 *    low because there was no need for it to be high, and when write pattern changes,
 *    the adjustment happens due to dp_throughput rising.
 * 3. dp_write_limit is calculated as dp_throughput (dp_thr) multiplied by 
 *    zfs_txg_synctime_ms, with certain thresholds applied if necessary. NOTE: It
 *    accounts for write inflation, so it does not actually represent the amount of
 *    data that goes into any given TXG. The output of this script shows a spread of
 *    minimum and maximum of dp_write_limit recorded during each TXG, as well as the
 *    maximum of the reserve, and the current dp_throughput, which is calculated at
 *    the end of each TXG commit.
 * 4. Some comments on other output values:
 *    The X ms value at the beginning of each line is the length of the spa_sync() call
 *        in milliseconds. As a general rule, we should strive for it to be less than
 *        zfs_txg_synctime_ms, but that is not the only condition. When this number is
 *        pathologically high, this might indicate either a hardware issue or a code
 *        bottleneck; an example of such code bottleneck might be a metaslab allocator
 *        issue when pool space utilization reaches 75%-80% (sometimes even earlier),
 *        also known as free space fragmentation issue. Other causes of slowdowns may
 *        include checksumming bottleneck on a system with dedup enabled, ongoing ZFS
 *        operations such as a ZFS destroy, or an ongoing scrub/resilver, which by design
 *        will borrow time from each TXG commit to do its business.
 *    wMB and rMB is the amount of data written and read in MB's during the spa_sync()
 *        call. They are the total data written by the system, not just for the specific
 *        zpool.
 *    wIops and rIops are the I/O operations that happened during spa_sync(), also global
 *        unfortunately. They are already adjusted per second.
 *    dly+thr are the delays and throttles. Those, normally 0+0, are for the individual
 *        zpool.
 *    dp_wrl, res_max and dp_thr are covered above. Also for the individual pool. */

/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2013, Nexenta Systems, Inc. All rights reserved. */
/* Version: 3.0 */
/* To get the latest version of this script, 
 * wget https://raw.github.com/kdavyd/dtrace/master/txg_monitor.v3.d --no-ch */

inline int MIN_MS = 1;

dtrace:::BEGIN
{
        printf("Tracing ZFS spa_sync() slower than %d ms...\n", MIN_MS);
	@readbytes=sum(0);
	@writebytes=sum(0);
}

fbt::spa_sync:entry
/args[0]->spa_name == $$1 && !self->start/
{
        in_spa_sync = 1;
        self->start = timestamp;
        self->spa = args[0];
}

txg_delay:entry
/args[0]->dp_spa->spa_name == $$1/
{
        @delays=count();
}

dsl_pool_tempreserve_space:entry
/args[0]->dp_spa->spa_name == $$1/
{
        @wrl_min = min(args[0]->dp_write_limit);
        @wrl_max = max(args[0]->dp_write_limit);
	@dp_thr_max = max(args[0]->dp_throughput);
        @reserved_max = max(args[0]->dp_space_towrite[args[2]->tx_txg & 3] + (args[0]->dp_tempreserved[args[2]->tx_txg & 3] / 2));
}

dsl_pool_tempreserve_space:return
/args[1]==91/
{
        @throttles=count();
}

io:::start
/in_spa_sync && (args[0]->b_flags & 0x100)/
{
        @writeio = sum(1000);
        @writebytes = sum(args[0]->b_bcount);
}

io:::start
/in_spa_sync && (args[0]->b_flags & 0x40)/
{
        @readio = sum(1000);
        @readbytes = sum(args[0]->b_bcount);
}

fbt::spa_sync:return
/self->start && (this->ms = (timestamp - self->start) / 1000000) > MIN_MS/
{
        normalize(@writebytes, 1048576);
        normalize(@readbytes, 1048576);
        normalize(@wrl_min, 1048576);
        normalize(@wrl_max, 1048576);
        normalize(@reserved_max, 1048576);
        normalize(@dp_thr_max, 1049); /* dp_throughput is in bytes/millisec, we are converting to Mbytes/sec */
	normalize(@writeio,this->ms);
	normalize(@readio,this->ms);
        printf("%-20Y %-10s %6d ms, ", walltimestamp,
            stringof(self->spa->spa_name), this->ms);
        printa("%@d wMB %@d rMB %@d wIops %@d rIops %@d+%@d dly+thr; dp_wrl %@d MB .. %@d MB; res_max: %@d MB; dp_thr: %@d\n",
                @writebytes, @readbytes, @writeio, @readio, @delays, @throttles, @wrl_min, @wrl_max, @reserved_max, @dp_thr_max);
}

fbt::spa_sync:return
/self->start/
{
        self->start = 0; self->spa = 0; in_spa_sync = 0;
        clear(@writebytes); clear(@readbytes); clear(@writeio); clear(@readio); clear(@delays); clear(@throttles); trunc(@wrl_min); trunc(@wrl_max); trunc(@reserved_max); 
	trunc(@dp_thr_max);
}
