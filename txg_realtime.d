#!/usr/sbin/dtrace -s
#pragma D option quiet

/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2013, Nexenta Systems, Inc. All rights reserved. */
/* Version: 1.0 */

inline int MIN_MS = 1;

dtrace:::BEGIN
{
        @readbytes=sum(0);
        @writebytes=sum(0);
        wrl_max=0
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
        wrl_max = (args[0]->dp_write_limit/100)>wrl_max?(args[0]->dp_write_limit/100):wrl_max;
        @reserved_max = max(args[0]->dp_space_towrite[args[2]->tx_txg & 3] + (args[0]->dp_tempreserved[args[2]->tx_txg & 3] / 2));
}


dsl_pool_tempreserve_space:return
/args[1]==91/
{
        @throttles=count();
}

io:::start
/in_spa_sync && (args[0]->b_flags & 0x100)/
{
        @writeio = sum(1);
        @writebytes = sum(args[0]->b_bcount);
}

io:::start
/in_spa_sync && (args[0]->b_flags & 0x40)/
{
        @readio = sum(1);
        @readbytes = sum(args[0]->b_bcount);
}


tick-1sec
{
        normalize(@writebytes, 1048576);
        normalize(@readbytes, 1048576);
        normalize(@reserved_max, wrl_max);
        printf("%Y, %d, ",walltimestamp,in_spa_sync);
        printa("%@d wMB, %@d rMB, %@d wIo, %@d rIo, %@d dly, %@d thr, %@d pct \n",
                @writebytes, @readbytes, @writeio, @readio, @delays, @throttles, @reserved_max);
        clear(@writebytes); clear(@readbytes); clear(@writeio); clear(@readio); clear(@delays); clear(@throttles); wrl_max=0;
}


fbt::spa_sync:return
/self->start/
{
        self->start = 0; self->spa = 0; in_spa_sync = 0; clear(@reserved_max);
}
