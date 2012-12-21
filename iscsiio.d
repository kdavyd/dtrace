#!/usr/sbin/dtrace -s
/*
 * iscsiio.d - Report iSCSI I/O. Solaris Nevada, DTrace.
 *
 * This traces requested iSCSI data I/O events when run on an iSCSI server.
 * The output reports iSCSI read and write I/O while this script was running.
 *
 * USAGE: iscsiio.d             # Hit Ctrl-C to end
 *
 * FIELDS:
 *              REMOTE IP       IP address of the client
 *              EVENT           Data I/O event (read/write)
 *              COUNT           Number of I/O events
 *              Kbytes          Total data Kbytes transferred
 *              KB/sec          Average data Kbytes/sec transferred
 */

#pragma ident   "@(#)iscsiio.d  1.2     07/03/27 SMI"

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
        start = timestamp;
}

iscsi*:::data-send
{
        @num[args[0]->ci_remote, "read"] = count();
        @bytes[args[0]->ci_remote, "read"] = sum(args[1]->ii_datalen);
        @rate[args[0]->ci_remote, "read"] = sum(args[1]->ii_datalen);
}

iscsi*:::data-receive
{
        @num[args[0]->ci_remote, "write"] = count();
        @bytes[args[0]->ci_remote, "write"] = sum(args[1]->ii_datalen);
        @rate[args[0]->ci_remote, "write"] = sum(args[1]->ii_datalen);
}

iscsi*:::scsi-command
/args[2]->ic_cdb[0] == 0x0a || args[2]->ic_cdb[0] == 0x2a/
{
        /*
         * scsi-command writes also move data. Their codes are in
         * /usr/include/sys/scsi/generic/commands.h .
         */
        @num[args[0]->ci_remote, "write"] = count();
        @bytes[args[0]->ci_remote, "write"] = sum(args[1]->ii_datalen);
        @rate[args[0]->ci_remote, "write"] = sum(args[1]->ii_datalen);
}

dtrace:::END
{
        normalize(@rate, (timestamp - start) * 1024 / 1000000000);
        printf("   %-26s %8s %8s %10s %10s\n", "REMOTE IP", "EVENT", "COUNT",
            "Kbytes", "KB/sec");
        normalize(@bytes, 1024);
        printa("   %-26s %8s %@8d %@10d %@10d\n", @num, @bytes, @rate);
}
