#!/usr/sbin/dtrace -s

/*
 * Script to observe the amount of dirty data being written out (async) 
 * per sync event and also to see the dirty data max, so we can see how
 * close we are to the limit.
 *
 * Author: Adam Leventhal
 * Copyright 2014 Joyent
 */

#pragma D option quiet

BEGIN
{
    printf("Monitoring TXG syncs (dirty data) for %s\n", $$1)
}

txg-syncing
/arg0 && ((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        this->dp = (dsl_pool_t *)arg0;
	start = timestamp;
}

txg-synced
/start && ((dsl_pool_t *)arg0)->dp_spa->spa_name == $$1/
{
        this->d = timestamp - start;
}


fbt::dsl_pool_need_dirty_delay:return
/args[1] == 1/
{
    this->delay++;
}

fbt::dsl_pool_need_dirty_delay:return
/args[1] == 0/
{
    this->no_delay++;
}

txg-syncing
/this->d && this->dp->dp_spa->spa_name == $$1 && (this->dp->dp_dirty_total / 1024) > 1/ 
{
        printf("%Y %s %4dMB of %4dMB used, synced in %dms, delays = %d, no_delays = %d\n", walltimestamp, stringof($$1), this->dp->dp_dirty_total / 1024 / 1024, `zfs_dirty_data_max / 1024 / 1024, this->d / 1000000, this->delay, this->no_delay);
	this->delay = 0;
	this->no_delay = 0;
}

