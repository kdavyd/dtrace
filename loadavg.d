#!/usr/sbin/dtrace -s
#pragma D option quiet

profile:::tick-1sec
 {
        this->load1a  = `hp_avenrun[0] / 65536;
        this->load5a  = `hp_avenrun[1] / 65536;
        this->load15a = `hp_avenrun[2] / 65536;
        this->load1b  = ((`hp_avenrun[0] % 65536) * 100) / 65536;
        this->load5b  = ((`hp_avenrun[1] % 65536) * 100) / 65536;
        this->load15b = ((`hp_avenrun[2] % 65536) * 100) / 65536;

        printf("%.05d %d.%02d %d.%02d %d.%02d\n",
            walltimestamp/1000000000, this->load1a, this->load1b, this->load5a,
            this->load5b, this->load15a, this->load15b);

 }