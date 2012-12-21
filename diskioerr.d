#!/usr/sbin/dtrace -s 

#pragma D option quiet
#pragma D option dynvarsize=8m
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

This script is intended to track IO where some buffer error was registered,
by looking for the B_ERROR flag in the bufinfo_t struct.
*/



dtrace:::BEGIN {
        printf("Tracing... Hit Ctrl-C to end.\n");
}
io:::start {
        start_time[arg0] = timestamp;
        fire = 1;
}
io:::done / (args[0]->b_flags & B_READ) && (args[0]->b_flags & B_ERROR) && (this->start = start_time[arg0]) / {

        @errors[args[1]->dev_pathname, "Error Code", args[0]->b_error] = count();
        this->delta = (timestamp - this->start) / 1000;
/*        @plots["Read I/O, us",
        execname,
        args[1]->dev_statname,
        args[1]->dev_pathname,
        args[1]->dev_major,
        args[1]->dev_minor] = quantize(this->delta);
        @avgs["Avg Read I/O, us"] = avg(this->delta);
        @avgbytes["Avg Read bytes"] = avg(args[0]->b_bcount);
        @perio_t["Avg Read bytes/us"] = avg(args[0]->b_bcount / this->delta);
*/
        start_time[arg0] = 0;
        error = 1;
}

io:::done / !(args[0]->b_flags & B_READ) && (args[0]->b_flags & B_ERROR) && (this->start = start_time[arg0]) / {

        @errors[args[1]->dev_pathname, "Error Code",args[0]->b_error] = count();
        this->delta = (timestamp - this->start) / 1000;
/*        @plots["Write I/O, us",
        execname,
        args[1]->dev_statname,
        args[1]->dev_pathname,
        args[1]->dev_major,
        args[1]->dev_minor] = quantize(this->delta);
        @avgs["Avg Write I/O, us"] = avg(this->delta);
        @avgbytes["Avg Write bytes"] = avg(args[0]->b_bcount);
        @perio_t["Avg Write bytes/us"] = avg(args[0]->b_bcount / this->delta);
*/
        start_time[arg0] = 0;
        self->error = 1;

}

profile:::tick-5sec / error == 1 / {
        printa("%s %s %d %@d\n", @errors); trunc(@errors);
/*        printf("%Y\n", walltimestamp);
        printa("%s %s %s :: %s\n (%d,%d), us:\n%@d\n", @plots);
        printa("%18s %44@d\n", @avgs);
        printa("%18s %44@d\n", @avgbytes);
        printa("%18s %44@d\n", @perio_t);
        printf("%s\n","");
        trunc(@avgs); trunc(@avgbytes); trunc(@perio_t);
*/
        error = 0;
}
