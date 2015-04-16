#!/usr/sbin/dtrace
#pragma D option quiet

/* Description: Track amount of times NFS QoS has throttled clients. */
/* USAGE: dtrace -p `pgrep rpcbind` -s svc_flowcontrol.d */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2015, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.1 */

dtrace:::BEGIN
/`svc_flowcontrol_disable == 1/
{
        trace("NFS flow control is disabled, exiting.");
        exit(0);
}

dtrace:::BEGIN
{
        @thr=count();
        clear(@thr);
}

fbt:rpcmod:svc_flowcontrol:entry
{
        self->in = 1;
        self->xprt = args[0]; 
}

fbt:rpcmod:svc_flowcontrol:return
/self->in && self->xprt->xp_full/
{
        self->in = 0;
        @thr = count();
        self->xprt = NULL;
}

fbt:rpcmod:svc_flowcontrol:return
/self->in && !self->xprt->xp_full/
{
        self->in = 0;
        self->xprt = NULL;
}

tick-5sec
{
        printf("%Y ",walltimestamp);
        printa("NFS QoS Throttles: %@d\n",@thr);clear(@thr);
}
