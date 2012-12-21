#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
        printf("Tracing... Hit Ctrl-C to end.\n");
}

io:::start
{
        start_time[arg0] = timestamp;
}

io:::done
/this->start = start_time[arg0]/
{
        this->delta = (timestamp - this->start) / 1000;
        @avgs[args[1]->dev_pathname,args[1]->dev_statname, args[1]->dev_major, args[1]->dev_minor] =
            avg(this->delta);
        start_time[arg0] = 0;
}

tick-1sec
{
        printa("%s\t%s\t%d\t%d\t%@d\n", @avgs);
}
