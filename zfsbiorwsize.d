#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
}

fbt::zfs_read:entry, fbt::zfs_write:entry
{
        this->startzfsio = 1;
        start_time[arg0] = timestamp;
        /* Storing buffer size to make sure that io:::done probes are triggered
        only when this value is greater than 0 */
        this->path = args[0]->v_path;
        this->size = args[1]->uio_resid;
}


io:::start
/ this->startzfsio /
{
        /* Storing buffer size to make sure that io:::done probes are triggered
        only when this value is greater than 0 */
        trig = args[0]->b_bufsize;
}

io:::done

/ this->startzfsio && (args[0]->b_flags & B_READ) && (this->start = start_time[arg0]) /
{
        this->delta = (timestamp - this->start) / 1000;
        printf("[READ]  Device: %5s Size (bytes): %5d Time (us): %5u \n", 
                args[1]->dev_statname, args[0]->b_bcount, this->delta);
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        this->size = args[0]->b_bcount;
        @bsize["average read, bytes"] = avg(this->size);
        @plots["read I/O, us"] = quantize(this->delta);
        @avgs["average read I/O, us"] = avg(this->delta); 
        start_time[arg0] = 0;
}

io:::done
/ this->startzfsio && !(args[0]->b_flags & B_READ) && (this->start = start_time[arg0]) /
{
        this->delta = (timestamp - this->start) / 1000;
        printf("[WRITE] Device: %5s Size (bytes): %5d Time (us): %5u \n", 
                args[1]->dev_statname, args[0]->b_bcount, this->delta);
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        this->size = args[0]->b_bcount;
        @bsize["average write, bytes"] = avg(this->size);
        @plots["write I/O, us"] = quantize(this->delta);
        @avgs["average write I/O, us"] = avg(this->delta);
        start_time[arg0] = 0;
}

fbt::zfs_read:return
/ this->start = start_time[arg0] /
{
        this->delta = (timestamp - this->start) / 1000;
        printf("[READ]  Device: %5s Size (bytes): %5d Time (us): %5u \n", 
                stringof(this->path), this->size, this->delta);
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        /* this->size = args[0]->b_bcount; */
        @zbsize["average read, bytes"] = avg(this->size);
        @zplots["read I/O, us"] = quantize(this->delta);
        @zavgs["average read I/O, us"] = avg(this->delta); 
        start_time[arg0] = 0;
        this->startzfsio = 0;
}

fbt::zfs_write:return
/ this->start = start_time[arg0] /
{
        this->delta = (timestamp - this->start) / 1000;
        printf("[WRITE] Device: %5s Size (bytes): %5d Time (us): %5u \n", 
                stringof(this->path), this->size, this->delta);
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        /* this->size = args[0]->b_bcount; */
        @zbsize["average write, bytes"] = avg(this->size);
        @zplots["write I/O, us"] = quantize(this->delta);
        @zavgs["average write I/O, us"] = avg(this->delta);
        start_time[arg0] = 0;
        this->startzfsio = 0;
}

dtrace:::END
/trig > 0/
{
        printf("\nI/O completed time and size summary:\n\n");
        printa("\t%s     %@d\n", @avgs);
        printa("\t%s     %@d\n", @bsize);
        printa("\n   %s\n%@d\n", @plots);
        trig = 0;
                printf("\nI/O completed time and size summary:\n\n");
        printa("\t%s     %@d\n", @zavgs);
        printa("\t%s     %@d\n", @zbsize);
        printa("\n   %s\n%@d\n", @zplots);
        trig = 0;
}
