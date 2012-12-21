#!/usr/sbin/dtrace -s

/* #pragma D option quiet */

/* This section may be of questionable value, but 
could be used to determine which block numbers correlate with
which uberblock update events
*/
io:genunix:default_physio:start,
io:genunix:bdev_strategy:start,
io:genunix:biodone:done
{
   printf ("%d %s Blk Num: %d Byte Count: %d", timestamp, execname,
     args[0]->b_blkno, args[0]->b_bcount);
}

fbt:zfs:uberblock_update:entry
{
   printf ("%d %s, %d, %d, last_sync_TXG: %d, birth_TXG: %d, %d, curr_TXG: %d", timestamp, execname,
     pid, args[0]->ub_rootbp.blk_prop, args[0]->ub_txg, 
     args[0]->ub_rootbp.blk_birth, args[1]->vdev_asize, args[2]);
}

/* 
Watch carefully for the `:return` probe, last arg. of which is a bool.,
indicating whether or not uberblock was updated during last TXG.
If the birth_TXG and the curr_TXG match, we know uberblock was updated,
and sure enough the `:return` probe should have its last argument be '1'.

Example (pay attn. to birth_TXG: 6147837, and curr_TXG: 6147837):
  0  52274           uberblock_update:entry 5857149610527 sched, 0, 9226475966770118659, last_sync_TXG: 6147836, birth_TXG: 6147837, 0, curr_TXG: 6147837
  0  52275          uberblock_update:return 5857149619433 sched, 0, 1
*/
fbt:zfs:uberblock_update:return
{
   printf ("%d %s, %d, %d", timestamp, execname,
     pid, args[1]);
}
