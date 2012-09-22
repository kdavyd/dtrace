#!/usr/sbin/dtrace -s

fbt::arc_kmem_reap_now:entry
{
    self->start[probefunc] = timestamp;
    self->strategy = args[0];
    self->in_kmem = 1;
}

fbt::arc_adjust:entry,
fbt::arc_shrink:entry,
fbt::arc_do_user_evicts:entry,
fbt::dnlc_reduce_cache:entry,
fbt::kmem_reap:entry
/self->in_kmem/
{
    self->start[probefunc] = timestamp;
}

kmem_depot_ws_reap:entry
{
        self->i = 1;
        self->start[probefunc] = timestamp;
        self->kct = args[0];
        self->magcount = 0;
        self->slabcount = 0;
}

kmem_magazine_destroy:entry
/self->i/
{
        self->magcount += 1;
}

kmem_slab_free:entry
/self->i/
{
        self->slabcount += 1;
}

fbt::arc_adjust:return,
fbt::arc_shrink:return,
fbt::arc_do_user_evicts:return,
fbt::dnlc_reduce_cache:return,
fbt::kmem_reap:return
/self->start[probefunc] && self->in_kmem && ((self->end[probefunc] = timestamp - self->start[probefunc]) > 100000000)/
{
        printf("%Y %d ms", walltimestamp,
                (timestamp - self->start[probefunc]) / 1000000);
        self->start[probefunc] = NULL;
}

fbt::arc_adjust:return,
fbt::arc_shrink:return,
fbt::arc_do_user_evicts:return,
fbt::dnlc_reduce_cache:return,
fbt::kmem_reap:return
/self->start[probefunc] && self->in_kmem && ((self->end[probefunc] = timestamp - self->start[probefunc]) < 100000000)/
{
        self->start[probefunc] = NULL;
}


kmem_depot_ws_reap:return
/self->i && ((self->ts_end[probefunc] = timestamp - self->start[probefunc]) > 100000000)/
{
        self->i = NULL;
        printf("%Y %s %d ms %d mags %d slabs", walltimestamp, self->kct->cache_name, (self->ts_end[probefunc])/1000000, self->magcount, self->slabcount);
        self->start[probefunc] = NULL;

}

kmem_depot_ws_reap:return
/self->i && ((self->ts_end[probefunc] = timestamp - self->start[probefunc]) < 100000000)/
{
        self->i = NULL;
        self->start[probefunc] = NULL;
}


fbt::arc_kmem_reap_now:return
/self->start[probefunc] && ((self->end[probefunc] = timestamp - self->start[probefunc]) > 100000000)/
{
        printf("%Y %d ms, strategy %d", walltimestamp,
                (timestamp - self->start[probefunc]) / 1000000, self->strategy);
        self->start[probefunc] = NULL;
        self->in_kmem = NULL;
}

fbt::arc_kmem_reap_now:return
/self->start[probefunc] && ((self->end[probefunc] = timestamp - self->start[probefunc]) < 100000000)/
{
        self->start[probefunc] = NULL;
        self->in_kmem = NULL;
}
