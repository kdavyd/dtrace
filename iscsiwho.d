#!/usr/sbin/dtrace -s
/*
 * iscsiwho.d - Report iSCSI client events. Solaris Nevada, DTrace.
 *
 * This traces requested iSCSI events when run on an iSCSI server.
 *
 * USAGE: iscsiwho.d            # Hit Ctrl-C to end
 *
 * FIELDS:
 *              REMOTE IP       IP address of the client
 *              iSCSI EVENT     iSCSI event type.
 *              COUNT           Number of events traced
 */

#pragma ident   "@(#)iscsiwho.d 1.3     07/03/27 SMI"

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
}

iscsi*:::
{
        @events[args[0]->ci_remote, probename] = count();
}

dtrace:::END
{
        printf("   %-26s %14s %8s\n", "REMOTE IP", "iSCSI EVENT", "COUNT");
        printa("   %-26s %14s %@8d\n", @events);
}
