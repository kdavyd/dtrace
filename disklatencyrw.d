#!/usr/sbin/dtrace -s 

#pragma D option quiet
#pragma D option dynvarsize=4m
#pragma D option switchrate=10hz
/*
   Copyright 2012 Sam Zaydel - RackTop Systems

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

Script will collect per device IO statistics, and will display a distribution
graph similar to one below, along with statistics printed at the bottom. This is a
per-device output.

Read I/O, us sched sd4 :: /devices/pci@0,0/pci15ad,1976@10/sd@3,0:a
 (292,256), us:

           value  ------------- Distribution ------------- count    
               8 |                                         0        
              16 |                                         6        
              32 |@                                        10       
              64 |                                         0        
             128 |@@                                       23       
             256 |@                                        8        
             512 |                                         0        
            1024 |                                         0        
            2048 |@                                        16       
            4096 |@                                        10       
            8192 |@@@@@@@@                                 97       
           16384 |@@@@@@@@@@@@                             151      
           32768 |@@@@@@@@@@                               125      
           65536 |@@@                                      39       
          131072 |                                         4        
          262144 |                                         2        
          524288 |                                         0        
         1048576 |                                         2        
         2097152 |                                         0        

 Avg Write I/O, us                                          890
  Avg Read I/O, us                                        31407
   Avg Write bytes                                         8068
    Avg Read bytes                                       131072
 Avg Read bytes/us                                            6
Avg Write bytes/us                                            7

*/

dtrace:::BEGIN {
        printf("Tracing... Hit Ctrl-C to end.\n");
}
io:::start {
        start_time[arg0] = timestamp;
        fire = 1;
}
io:::done / (args[0]->b_flags & B_READ) && (this->start = start_time[arg0]) / {
        this->delta = (timestamp - this->start) / 1000;
        @plots["Read I/O, us",
        execname,
        args[1]->dev_statname,
        args[1]->dev_pathname,
        args[1]->dev_major,
        args[1]->dev_minor] = quantize(this->delta);
        @avgs["Avg Read I/O, us"] = avg(this->delta);
        @avgbytes["Avg Read bytes"] = avg(args[0]->b_bcount);
        @perio_t["Avg Read bytes/us"] = avg(args[0]->b_bcount / this->delta);
        start_time[arg0] = 0;
}

io:::done / !(args[0]->b_flags & B_READ) && (this->start = start_time[arg0]) / {
        this->delta = (timestamp - this->start) / 1000;
        @plots["Write I/O, us",
        execname,
        args[1]->dev_statname,
        args[1]->dev_pathname,
        args[1]->dev_major,
        args[1]->dev_minor] = quantize(this->delta);
        @avgs["Avg Write I/O, us"] = avg(this->delta);
        @avgbytes["Avg Write bytes"] = avg(args[0]->b_bcount);
        /* self->w_lat = args[0]->b_bcount / self->delta; */
        @perio_t["Avg Write bytes/us"] = avg(args[0]->b_bcount / this->delta);
        start_time[arg0] = 0;
}

profile:::tick-5sec / fire > 0 / {
        printf("%Y\n", walltimestamp);
        printa("%s %s %s :: %s\n (%d,%d), us:\n%@d\n", @plots);
        printa("%18s %44@d\n", @avgs);
        printa("%18s %44@d\n", @avgbytes);
        printa("%18s %44@d\n", @perio_t);
        printf("%s\n","");
        trunc(@avgs); trunc(@avgbytes); trunc(@perio_t);
        fire = 0;
}
