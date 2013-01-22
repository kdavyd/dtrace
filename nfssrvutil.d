#!/usr/sbin/dtrace -s
#pragma D option quiet

/* Description: This script measures the percentage of NFS thread pool currently utilized 
 * (maximum being NFSD_SERVERS), along with Max pending (queued) NFS requests that have not 
 * yet been assigned a thread. It is useful in troubleshooting bottlenecks in the Solaris  
 * NFS server, and determining the correct NFSD_SERVERS value for high-load systems. */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2013, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.1 */

svc_xprt_qput:entry
{
        @pending_reqs  = max(args[0]->p_reqs);
        @act_threads   = max(args[0]->p_threads - args[0]->p_asleep);
        @pool_pct_util = max(100 * (args[0]->p_threads - args[0]->p_asleep) / args[0]->p_maxthreads);
}

tick-5sec
{
        printf("%Y", walltimestamp);
        printa(" Max Pending NFS requests: %@d; Max Active threads: %@d; Thread pool utilized percentage: %@d\n", @pending_reqs, @act_threads, @pool_pct_util);
        trunc(@pending_reqs); 
        trunc(@act_threads); 
        trunc(@pool_pct_util);
}
