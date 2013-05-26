#!/usr/sbin/dtrace -s
#pragma D option quiet

/* Description: This script will show progress of any active scrubs
 * happening on the system. It has been tested and sanity-checked on mirror
 * and raidz1 vdevs, but since we are tracing deep within zio, should hold
 * true for all other types. It is functionally equivalent to resilver.d, just 
 * traces scrub.
 */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2013, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.1b */

dtrace:::BEGIN
{
        printf("Tracing with 10 second interval...\n");
        printf("If there is no scrub happening, only timestamps will appear. \n");
}

zio_read:entry
/args[7] == 20/
/*
   Priority 20 reads indicate ZIO_PRIORITY_SCRUB
   This might change in the future, but for now it
   looks like a safe way to detect only scrub IO.
*/
{
        @ops = count();
        @bs = quantize(args[4]);
        @tp = sum(args[4]);
}

dsl_scan_scrub_cb:entry
/*
   The only reason we're tracing here is
   to determine throttling factor.
*/
{
        self->in_scrub_cb = 1;
}

dsl_scan_scrub_cb:return
{
        self->in_scrub_cb = NULL;
}


fbt:genunix:delay:entry
/ self->in_scrub_cb /
/*
   Argh. What is a tick - 1ms or 10ms?
   Based on observation, appears to be 10ms.
*/
{
        @delay_times = count();
        @delay_ticks = sum(args[0]);
}

tick-10sec
{
        normalize(@tp, 10*1024);
        normalize(@bs, 10);
        normalize(@ops, 10);
        printf("\n%Y", walltimestamp);
        printa("\n\nScrub IOPs: %@d ",@ops);
        printa("\nScrub Blocksize: %@a",@bs);
        printa("\nScrub Throughput: %@d KB/sec",@tp);
        printa("\nThrottled %@d times by %@d ticks in last interval", @delay_times, @delay_ticks);
        trunc(@ops); trunc(@bs); trunc(@tp); trunc(@delay_times); trunc(@delay_ticks);
}
