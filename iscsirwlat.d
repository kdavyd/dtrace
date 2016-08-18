#!/usr/sbin/dtrace -s
/*
 * iscsirwlat.d - Report iSCSI Read/Write Latency. Solaris Nevada, DTrace.
 *
 * This traces iSCSI data I/O events when run on an iSCSI server, and
 * produces a report of read/write latency in microseconds.
 *
 * USAGE: iscsirwlat.d          # Hit Ctrl-C to end
 *
 * FIELDS:
 *              EVENT           Data I/O event (data-send/data-receive)
 *              REMOTE IP       IP address of the client
 *              COUNT           Number of I/O events
 *              Kbytes          Total data Kbytes transferred
 *
 * NOTE: If you try to sum the read times, they will sometimes add to
 * a time longer than the sample time - the reason is that reads can
 * occur in parallel, and so suming them together will overcount.
 */

#pragma ident   "@(#)iscsirwlat.d       1.3     07/03/28 SMI"

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
}

iscsi*:::scsi-command
/args[2]->ic_cdb[0] == 0x08 || args[2]->ic_cdb[0] == 0x28/
{
        /*
         * self-> variables can't be used, as one thread receives the
         * scsi command while another receives the reads.
         */
        start_read[args[1]->ii_itt, args[1]->ii_initiator] = timestamp;
}

iscsi*:::scsi-command
/args[2]->ic_cdb[0] == 0x0a || args[2]->ic_cdb[0] == 0x2a/
{
        start_write[args[1]->ii_itt, args[1]->ii_initiator] = timestamp;
}

iscsi*:::data-send
/start_read[args[1]->ii_itt, args[1]->ii_initiator] &&
    (args[1]->ii_flags & ISCSI_FLAG_FINAL)/
{
        @read[args[0]->ci_remote] = quantize(timestamp -
            start_read[args[1]->ii_itt, args[1]->ii_initiator]);
        start_read[args[1]->ii_ttt, args[1]->ii_initiator] = 0;
}

iscsi*:::scsi-response
/start_write[args[1]->ii_itt, args[1]->ii_initiator]/
{
        @write[args[0]->ci_remote] = quantize(timestamp -
            start_write[args[1]->ii_itt, args[1]->ii_initiator]);
        start_write[args[1]->ii_itt, args[1]->ii_initiator] = 0;
}

dtrace:::END
{
        printf("Read Latency (ns),\n");
        printa(@read);
        printf("Write Latency (ns),\n");
        printa(@write);
}
