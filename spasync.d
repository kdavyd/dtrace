#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option dynvarsize=8m

inline int MIN_MS = 1000;

dtrace:::BEGIN
{
    printf("Tracing ZFS spa_sync() slower than %d ms...\n", MIN_MS);
    /* @bytes = sum(0); */
}

fbt::spa_sync:entry
/!self->start/
{
    in_spa_sync = 1;
    self->start = timestamp;
    self->spa = args[0];
    _count = 0;
    _bytes = 0;
}

io:::start
/in_spa_sync/
{
    /* @io = count();
    @bytes = sum(args[0]->b_bcount); */
    @avg_bytesize = avg(args[0]->b_bcount);
    _bytes += (args[0]->b_bcount);
    _count ++;
}

fbt::spa_sync:return
/ in_spa_sync && self->spa && self->start && (this->ms = (timestamp - self->start) / 1000000) > MIN_MS/
{
    this->count = (_count == 0) ? 1 : _count; /* We need to avoid division by zero */
    /* normalize(@bytes, 1048576); */
    this->mbytes = (_bytes == 0) ? 1 : _bytes / 1048576;
    this->avg_iosize = _bytes / this->count;
    printf("%-20Y %-10s %6d ms, ", walltimestamp,
        stringof(self->spa->spa_name), this->ms);
    /* printa("%@d MB %@d I/O\n", @bytes, @io); */
    printf("Bytes(b): %d, Megabytes(MB): %d, IOP(s): %d, Avg. Size: %d\n", _bytes, this->mbytes, _count, this->avg_iosize);
}

fbt::spa_sync:return
/self->spa/
{
    self->start = 0; self->spa = 0; in_spa_sync = 0; _bytes = 0;
    /* clear(@bytes); clear(@io); */
}