#!/usr/sbin/dtrace -s
#pragma D option quiet

nvp_buf_alloc:entry,kmem_firewall_va_alloc:entry,vmem_nextfit_alloc:entry,segkmem_alloc:entry,vmem_alloc:entry,smbsrv:smb_alloc:entry
{
        @[probefunc,stack()]=sum((uint64_t)args[1]);
}

kmem_alloc:entry,unix:smb_alloc:entry
{
        @[probefunc,stack()]=sum((uint64_t)args[0]);
}

kmem_cache_alloc:entry
{
        @cache[args[0]->cache_name,stack()]=sum((uint64_t)(args[0]->cache_bufsize));
}

vmem_seg_alloc:entry
{
        @[probefunc,stack()]=sum((uint64_t)args[3]);
}

kmem_slab_create:entry
{
         @slab[args[0]->cache_name,stack()]=sum(args[0]->cache_slabsize);
}

tick-1sec
{
        printf("%Y\n",walltimestamp);
        printf("================ SLAB ================\n");
        printa(@slab);  trunc(@slab);
        printf("================ CACHE ===============\n");
        printa(@cache); trunc(@cache);
        printf("================ OTHER ===============\n");
        trunc(@,20);    printa(@);      trunc(@);
}
