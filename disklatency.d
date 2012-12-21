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
    @[args[1]->dev_statname, args[1]->dev_major, args[1]->dev_minor] =
        quantize(this->delta);
    start_time[arg0] = 0;
}

dtrace:::END
{
    printa("   %s (%d,%d), us:\n%@d\n", @);
}