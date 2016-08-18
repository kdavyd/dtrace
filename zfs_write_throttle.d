#!/usr/sbin/dtrace -s

/*
 * COPYRIGHT: Copyright (c) 2008 Thomas Bastian.
 *
 * CDDL HEADER START
 *
 *  The contents of this file are subject to the terms of the
 *  Common Development and Distribution License, Version 1.0 only
 *  (the "License").  You may not use this file except in compliance
 *  with the License.
 *
 *  You can obtain a copy at http://www.opensolaris.org/os/licensing.
 *  See the License for the specific language governing permissions
 *  and limitations under the License.
 *
 * CDDL HEADER END
 *
 * Version: 20080728
 */

#pragma D option quiet

fbt:zfs:spa_sync:entry
{
  self->t = timestamp;
  self->pool = args[0]->spa_dsl_pool;
  self->txg = args[1];
  self->pname = stringof(self->pool->dp_root_dir->dd_myname);

  @wlimit[self->pname, "Write limit (MB)"] =
    lquantize(self->pool->dp_write_limit / 1048576, 250, 8192, 250);
  @scnt[self->pname] = count();
}

fbt:zfs:spa_sync:return
/self->t/
{
  @stime[self->pname, "Sync time (ms)"] =
    lquantize((timestamp - self->t) / 1000000, 20, 2000, 20);
  @bytes[self->pname] =
    sum(self->pool->dp_space_towrite[self->txg & 4] / 1048576);
  @written[self->pname, "Written (MB)"] =
    lquantize(self->pool->dp_space_towrite[self->txg & 4] / 1048576,
              200, 4096, 200);

  self->t = 0;
  self->pool = 0;
  self->txg = 0;
  self->pname = 0;
}

fbt:zfs:txg_delay:entry
{
  self->d_t = timestamp;
  self->d_pname = stringof(args[0]->dp_root_dir->dd_myname);
}

fbt:zfs:txg_delay:return
/self->d_t && ((timestamp - self->d_t) >= 10000)/
{
  @txgdelay[self->d_pname] = count();
  self->d_t = 0;
  self->d_pname = 0;
}

fbt:zfs:txg_delay:return
/self->d_t && ((timestamp - self->d_t) < 10000)/
{
  self->d_t = 0;
  self->d_pname = 0;
}

tick-10s
{
  printf("--- %Y\n", walltimestamp);
  normalize(@scnt, 10);
  printf("  %-47s %18s\n", "", "Sync rate (/s)");
  printa("  %-47s %@18d\n", @scnt);
  printf("\n");
  trunc(@scnt);

  normalize(@bytes, 10);
  printf("  %-47s %18s\n", "", "MB/s");
  printa("  %-47s %@18d\n", @bytes);
  printf("\n");
  trunc(@bytes);

  normalize(@txgdelay, 10);
  printf("  %-47s %18s\n", "", "Delays/s");
  printa("  %-47s %@18d\n", @txgdelay);
  printf("\n");
  trunc(@txgdelay);

  printa(@stime);
  trunc(@stime);

  printa(@written);
  trunc(@written);

  printa(@wlimit);
  trunc(@wlimit);
}
