#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
}

fbt::zfs_read:entry, fbt::zfs_write:entry
{
        self->ts = timestamp;
        /* Storing buffer size to make sure that io:::done probes are triggered
        only when this value is greater than 0 */
        self->path = args[0]->v_path;
        self->size = args[1]->uio_resid;
}

fbt::zfs_write:return
/ self->ts /
{
        this->type =  probefunc == "zfs_write" ? "Write" : "Read";
        this->delta = (timestamp - self->ts);
        /* printf("[WRITE] Device: %5s Size (bytes): %5d Time (us): %5u \n", 
                stringof(self->path), self->size, this->delta); */
        this->p = self->path == NULL ? "Unknown" : self->path;
        @writes[stringof(this->p)] = sum(self->size/(1024));
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        /* this->size = args[0]->b_bcount; */
        @bsize["average write, bytes"] = avg(self->size);
        @plots["write I/O, us"] = quantize(this->delta/1000);
        @avgs["average write I/O, us"] = avg(this->delta/1000);
        this->delta = 0;
        self->ts = 0;
}

fbt::zfs_read:return
/ self->ts /
{
        this->type =  probefunc == "zfs_write" ? "Write" : "Read";
        this->delta = (timestamp - self->ts);
        /* printf("[READ]  Device: %5s Size (bytes): %5d Time (us): %5u \n", 
                stringof(self->path), self->size, this->delta); */
        this->p = self->path == NULL ? "Unknown" : self->path;
        @reads[stringof(this->p)] = sum(self->size/(1024));
/*      @plots[args[1]->dev_statname, args[0]->b_bcount] = quantize(this->delta); */
        /* Figure out average byte size*/
        /* this->size = args[0]->b_bcount; */
        @bsize["average read, bytes"] = avg(self->size);
        @plots["read I/O, us"] = quantize(this->delta/1000);
        @avgs["average read I/O, us"] = avg(this->delta/1000); 
        this->delta = 0;
        self->ts = 0;
}

dtrace:::END
{
        printf("\nI/O completed time and size summary:\n\n");
        printa("\t%s     %@d\n", @avgs);
        printa("\t%s     %@d\n", @bsize);
        printa("\n   %s\n%@d\n", @plots);
        trunc(@reads, 10); trunc(@writes, 10);
        printa("[READ] Device: %5s KBytes: %@d\n", @reads);
        printa("[WRITE] Device: %5s KBytes: %@d\n", @writes);
}
