#!/usr/sbin/dtrace -AFs 
#pragma D option quiet

/* This script will enable anonymous tracing of the SFP identification code in ixgbe on boot. 
 * Based on the error code one can tell what exactly the issue is, and whether it's in the SFP. */
 
/* Usage: run "./ixgbe_debug.d", reboot, and collect the contents of the anon buffer with "dtrace -ae". */

/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2014, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.1 */
/* To get the latest version of this script, 
 * wget https://raw.github.com/kdavyd/dtrace/master/ixgbe_debug.d --no-ch */


ixgbe_identify_sfp_module_generic:return
/arg1==-19/
{
    printf("%s:%s\n",probefunc,"IXGBE_ERR_SFP_NOT_SUPPORTED");
}

ixgbe_identify_sfp_module_generic:return
/arg1==-20/
{
    printf("%s:%s\n",probefunc,"IXGBE_ERR_SFP_NOT_PRESENT");
}

ixgbe_identify_sfp_module_generic:return
/arg1==-21/
{
    printf("%s:%s\n",probefunc,"IXGBE_ERR_SFP_NO_INIT_SEQ_PRESENT");
}

ixgbe_identify_sfp_module_generic:return
/arg1==0/
{
    printf("%s:%s\n",probefunc,"IXGBE_SUCCESS");
}
