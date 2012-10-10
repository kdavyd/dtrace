#!/usr/sbin/dtrace -qs

BEGIN {
        tt = 0;                 /* timestamp */
        b = 0;                  /* bytecount */
        cnt = 0;                /* iocount */
        pool = $$1;
}

profile:::tick-1sec/i++ >= 3600/ {
        exit(o); /* Exit after 60 minites */
}

spa_sync:entry/(self->t == 0) && (tt == 0) && args[0]->spa_name == pool/{
        b = 0;
        cnt = 0;
        tt = timestamp;
        self->t = 1;
        printf("%Y ", walltimestamp);
}

spa_sync:return/(self->t == 1) && (tt != 0)/ {

        this->delta = (timestamp-tt);
        this->cnt = (cnt == 0) ? 1 : cnt; /* avoid divide by 0 */

        printf(
                ": %d MB; %d ms; avg sz %d KB; %d MB/sn\n",
                b / 1048576,
                this->delta / 1000000,
                b / this->cnt / 1024,
                (b * 1000000000) / (this->delta * 1048676)
        );

        tt = 0;
        self->t = 0;
}

bdev_strategy:entry/tt != 0/ {
        cnt++;
        b+= (args[0]->b_bcount);
}