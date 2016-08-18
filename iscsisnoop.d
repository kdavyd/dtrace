#!/usr/sbin/dtrace -s
/*
 * iscsisnoop.d - Snoop iSCSI events. Solaris Nevada, DTrace.
 *
 * This snoops iSCSI events when run on an iSCSI server.
 *
 * USAGE: iscsisnoop.d          # Hit Ctrl-C to end
 *
 * FIELDS:
 *              CPU             CPU event occured on
 *              REMOTE IP       IP address of the client
 *              EVENT           Data I/O event (data-send/data-receive)
 *              BYTES           Data bytes
 *              ITT             Initiator task tag
 *              SCSIOP          SCSI opcode as a description, as hex, or '-'
 *
 * NOTE: On multi-CPU servers output may not be in correct time order
 * (shuffled). A change in the CPU column is a hint that this happened.
 * If this is a problem, print an extra timestamp field and post sort.
 */

#pragma ident   "@(#)iscsisnoop.d       1.2     07/03/27 SMI"

#pragma D option quiet
#pragma D option switchrate=10

dtrace:::BEGIN
{
        printf("%3s  %-26s %-14s %6s %10s  %6s\n", "CPU", "REMOTE IP",
            "EVENT", "BYTES", "ITT", "SCSIOP");

        /*
         * SCSI opcode to string translation hash. This is from
         * /usr/include/sys/scsi/generic/commands.h. If you would
         * rather all hex, comment this out.
         */
        scsiop[0x08] = "read";
        scsiop[0x0a] = "write";
        scsiop[0x0b] = "seek";
        scsiop[0x28] = "read(10)";
        scsiop[0x2a] = "write(10)";
        scsiop[0x2b] = "seek(10)";
}

iscsi*:::data-*,
iscsi*:::login-*,
iscsi*:::logout-*,
iscsi*:::nop-*,
iscsi*:::task-*,
iscsi*:::async-*,
iscsi*:::scsi-response
{
        printf("%3d  %-26s %-14s %6d %10d  -\n", cpu, args[0]->ci_remote,
            probename, args[1]->ii_datalen, args[1]->ii_itt);
}

iscsi*:::scsi-command
/scsiop[args[2]->ic_cdb[0]] != NULL/
{
        printf("%3d  %-26s %-14s %6d %10d  %s\n", cpu, args[0]->ci_remote,
            probename, args[1]->ii_datalen, args[1]->ii_itt,
            scsiop[args[2]->ic_cdb[0]]);
}

iscsi*:::scsi-command
/scsiop[args[2]->ic_cdb[0]] == NULL/
{
        printf("%3d  %-26s %-14s %6d %10d  0x%x\n", cpu, args[0]->ci_remote,
            probename, args[1]->ii_datalen, args[1]->ii_itt,
            args[2]->ic_cdb[0]);
}
