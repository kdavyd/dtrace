#!/usr/sbin/dtrace -s
#pragma D option quiet
#pragma D option dynvarsize=4M

BEGIN {

        x = 0; 
        y = 0;
        watermark = 50; /* We want to track all IO slower than 50ms. */
        start_d = walltimestamp;
        to_millisec = 1000000;
        to_microsec = 1000;
        div = "--------------------------------------------------------------------------------";
}

fbt:zfs:zio_vdev_io_start:entry
{
        self->io_offset = args[0]->io_offset;
        self->io_txg = args[0]->io_txg;
        ts[ self->io_offset, self->io_txg ] = timestamp;
        self->vtime = vtimestamp;
}

fbt:zfs:zio_vdev_io_done:entry
/* Measure Latency of I/Os tagged as ZIO_TYPE_READ */
/self->vtime && ts[ self->io_offset, self->io_txg ] && args[0]->io_spa->spa_name != NULL && args[0]->io_type == ZIO_TYPE_READ/
{
        this->spa_name = stringof(args[0]->io_spa->spa_name);
        this->x = (timestamp - ts[ self->io_offset, self->io_txg ]) / to_microsec;
        this->y = (vtimestamp - self->vtime) / to_microsec;
        @Realt["Time (us)", this->spa_name, "READ"] = lquantize(this->x,10,100,10);
        @CPUt["Time onCPU (us)", this->spa_name, "READ"] = lquantize(this->y,0,50,10);
        @rlat["Avg. Time (us)","READ"] = avg(this->x);
        @roncpu["Avg. Time onCPU (us)","READ"] = avg(this->y);
        ts[ self->io_offset, self->io_txg ] = 0;
        self->vtime = 0;
}

fbt:zfs:zio_vdev_io_done:entry
/* Measure Latency of I/Os tagged as ZIO_TYPE_WRITE */
/self->vtime && ts[ self->io_offset, self->io_txg ] && args[0]->io_spa->spa_name != NULL && args[0]->io_type == ZIO_TYPE_WRITE/
{
        this->spa_name = stringof(args[0]->io_spa->spa_name);
        this->x = (timestamp - ts[ self->io_offset, self->io_txg ]) / to_microsec;
        this->y = (vtimestamp - self->vtime) / to_microsec;
        @Realt["Time (us)", this->spa_name, "WRITE"] = lquantize(this->x,10,100,10);
        @CPUt["Time onCPU (us)", this->spa_name, "WRITE"] = lquantize(this->y,0,50,10);
        @wlat["Avg. Time (us)","WRITE"] = avg(this->x);
        @woncpu["Avg. Time onCPU (us)","WRITE"] = avg(this->y);
        ts[ self->io_offset, self->io_txg ] = 0;
        self->vtime = 0;
}
