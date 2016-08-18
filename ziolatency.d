#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option dynvarsize=4m

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
/args[0]->io_type != 0 && start_time[arg0] > 0 && args[0]->io_vd && args[0]->io_vd->vdev_path/
{
        this->iotime    = (timestamp - start_time[arg0])/1000;
        this->path      = stringof(args[0]->io_vd->vdev_path);
        this->zpool     = stringof(args[0]->io_spa->spa_name);
        this->iotype    = ziotype[args[0]->io_type];
        this->childtype = ziochild[args[0]->io_child_type];
        this->vdev_id   = args[0]->io_vd->vdev_id;

        /* XXX - Describe abnormal behaviors to watch out for */

        @latency[this->zpool, this->vdev_id, this->iotype, this->childtype, this->path] = quantize(this->iotime);
        @avg_lat[this->zpool, this->vdev_id, this->iotype, this->childtype, this->path] = avg(this->iotime);
}

dtrace:::END
{
        printa("ZPool: %s\tChildVdevID: %d\tIOType: %s\tIOChild: %s\tDisk: %s\t Latency distribution(us):%@d\n",@latency);
        printa("ZPool: %s\tChildVdevID: %d\tIOType: %s\tIOChild: %s\tDisk: %s\t AvgLatency(us): %@d\n",@avg_lat);
}
