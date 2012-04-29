#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option dynvarsize=40m

/* Description: Trace I/O latency on a per-vdev basis. Script will not be maintained for the foreseeable future. */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2012, Nexenta Systems, Inc. All rights reserved. */

dtrace:::BEGIN
{
        trace("Tracing physical I/O latency... Ctrl-C to end.");

        /* see /usr/include/sys/fs/zfs.h */

        ziotype[0]  = "null";
        ziotype[1]  = "read";
        ziotype[2]  = "write";
        ziotype[3]  = "free";
        ziotype[4]  = "claim";
        ziotype[5]  = "ioctl";
        ziochild[0] = "vdev";
        ziochild[1] = "gang";
        ziochild[2] = "ddt";
        ziochild[3] = "logical";
}

fbt::zio_vdev_io_start:entry
/args[0]->io_type != 0/
{
        start_time[arg0] = timestamp;
}

fbt::zio_vdev_io_done:entry
/args[0]->io_type != 0 && start_time[arg0] > 0/ /* && args[0]->io_vd && args[0]->io_vd->vdev_path */
{
        this->iotime    = (timestamp - start_time[arg0])/1000;
        this->zpool     = stringof(args[0]->io_spa->spa_name);
        this->iotype    = ziotype[args[0]->io_type];
        this->childtype = ziochild[args[0]->io_child_type];
        this->path      = args[0]->io_vd ?
                                args[0]->io_vd->vdev_path ?
                                        stringof(args[0]->io_vd->vdev_path) :
                                "top_level_vdev" :
                          "pool";

        this->vdev_id   = args[0]->io_vd ?
                                args[0]->io_vd->vdev_id :
                          404; /* Not Found (pool) */
        this->vdev_pa   = args[0]->io_vd ?
                                args[0]->io_vd->vdev_parent ?
                                        args[0]->io_vd->vdev_parent->vdev_id :
                                12455 : /* L2ARC has no parent - set to 12455 (L2ArcSSd) */
                          404; /* Not found */

        /* XXX - Describe abnormal behaviors to watch out for */

        @latency[this->zpool, this->childtype, this->vdev_pa, this->vdev_id, this->iotype, this->path] = quantize(this->iotime);
        @avg_lat[this->zpool, this->childtype, this->vdev_pa, this->vdev_id, this->iotype, this->path] = avg(this->iotime);
        @sum_lat[this->zpool, this->childtype, this->vdev_pa, this->vdev_id, this->iotype, this->path] = sum(this->iotime);
}

dtrace:::END
{
        printa("ZPool: %12s  IOChild: %7s ParentVdevID: %5d  ThisVdevID: %3d  IOType: %5s  Disk: %s\t Latency distribution:%@d\n",@latency);
        printa("ZPool: %12s  IOChild: %7s ParentVdevID: %5d  ThisVdevID: %3d  IOType: %5s  Disk: %s\t AvgLatency(us): %@d\n",@avg_lat);
        printa("ZPool: %12s  IOChild: %7s ParentVdevID: %5d  ThisVdevID: %3d  IOType: %5s  Disk: %s\t TotLatency(us): %@d\n",@sum_lat);
        trunc(@latency);
        trunc(@avg_lat);
        trunc(@sum_lat);
}
