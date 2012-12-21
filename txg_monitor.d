#!/usr/sbin/dtrace -s
#pragma D option quiet

inline int MIN_MS = 1;

dtrace:::BEGIN
{
        printf("Tracing ZFS spa_sync() slower than %d ms...\n", MIN_MS);
        @bytes = sum(0);
}

fbt::spa_sync:entry
/args[0]->spa_name == $$1 && !self->start/
{
        in_spa_sync = 1;
        self->start = timestamp;
        self->spa = args[0];
}

txg_delay:entry
/args[0]->dp_spa->spa_name == $$1/
{
        @delays=count();
}

dsl_pool_tempreserve_space:entry
/args[0]->dp_spa->spa_name == $$1/
{
        @wrl_min = min(args[0]->dp_write_limit);
        @wrl_max = max(args[0]->dp_write_limit);
        @reserved_max = max(args[0]->dp_space_towrite[args[2]->tx_txg & 3] + (args[0]->dp_tempreserved[args[2]->tx_txg & 3] / 2));
}

dsl_pool_tempreserve_space:return
/args[1]==91/
{
        @throttles=count();
}

io:::start
/in_spa_sync/
{
        @io = count();
        @bytes = sum(args[0]->b_bcount);
}

fbt::spa_sync:return
/self->start && (this->ms = (timestamp - self->start) / 1000000) > MIN_MS/
{
        normalize(@bytes, 1048576);
        normalize(@wrl_min, 1048576);
        normalize(@wrl_max, 1048576);
        normalize(@reserved_max, 1048576);
        printf("%-20Y %-10s %6d ms, ", walltimestamp,
            stringof(self->spa->spa_name), this->ms);
        printa("%@d MB %@d I/O %@d delays %@d throttles; Write Limit min: %@d MB; max: %@d MB; reserved_max: %@d MB\n",
                @bytes, @io, @delays, @throttles, @wrl_min, @wrl_max, @reserved_max);
}

fbt::spa_sync:return
/self->start/
{
        self->start = 0; self->spa = 0; in_spa_sync = 0;
        clear(@bytes); clear(@io); clear(@delays); clear(@throttles); trunc(@wrl_min); trunc(@wrl_max); trunc(@reserved_max);
}