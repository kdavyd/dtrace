#!/usr/sbin/dtrace -Cs 

/*
 * iscsi-inactivity-monitor.d
 *
 * This dtrace script looks for the lack of iscsi target traffic and
 * will log the non-event by timestamp.
 *
 * Sample output:
 ** iSCSI target inactivity monitor
 ** Inactivity threshold 11 seconds
 ** Start time 2010 Dec 22 16:41:54
 ** No incoming iSCSI traffic since 2010 Dec 22 16:41:54, current time 2010 Dec 22 16:42:06
 ** No outgoing iSCSI traffic since 2010 Dec 22 16:41:54, current time 2010 Dec 22 16:42:06
 ** iSCSI inactivity monitor, 856 total transfers at 2010 Dec 22 17:46:37
 *
 * Copyright 2010, Nexenta Systems, Inc.  All rights reserved.
 */
 
#pragma D option quiet 

inline int THRESHOLD = 11000000000; /* nanoseconds */

BEGIN {
	n = 0;
	start_active = 0;  /* current activity flag */
	start_ts = timestamp + THRESHOLD;
	start_ws = walltimestamp;
	done_active = 0;
	done_ts = start_ts;
	done_ws = start_ws;
	printf("iSCSI target inactivity monitor\n");
	printf("Inactivity threshold %d seconds\n", THRESHOLD/1000000000);
	printf("Start time %Y\n", start_ws);
}

iscsi:::xfer-start
{
	n++;
	start_ts = timestamp + THRESHOLD;
	start_ws = walltimestamp;
}
iscsi:::xfer-start
/!start_active/
{
	start_active = 1;
	printf("Incoming traffic at %Y\n", walltimestamp);
}

profile:::tick-1sec
/timestamp > start_ts && start_active/
{
	printf("No incoming iSCSI traffic since %Y, current time %Y\n", start_ws, walltimestamp);
	start_active = 0;
}

iscsi:::xfer-done
{
	done_ts = timestamp + THRESHOLD;
	done_ws = walltimestamp;
}
iscsi:::xfer-done
/!done_active/
{
	done_active = 1;
	printf("Outgoing traffic at %Y\n", walltimestamp);
}

profile:::tick-1sec
/timestamp > done_ts && done_active/
{
	printf("No outgoing iSCSI traffic since %Y, current time %Y\n", done_ws, walltimestamp);
	done_active = 0;
}

profile:::tick-1hour
{
	printf("iSCSI target inactivity monitor status at %Y\n", walltimestamp);
	printf("\tTotal transfers = %d\n", n);
	printf("\tIncoming flow %s\n", start_active ? "active" : "inactive");
	printf("\tLast incoming transfer at %Y\n", start_ws);
	printf("\tOutgoing flow %s\n", done_active ? "active" : "inactive");
	printf("\tLast outgoing transfer at %Y\n", done_ws);
}