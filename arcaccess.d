#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
    printf("lbolt rate is %d Hertz.\n", `hz);
    printf("Tracing lbolts between ARC accesses...");
}

fbt::arc_access:entry
{
    self->ab = args[0];
    self->lbolt = args[0]->b_arc_access;
}

fbt::arc_access:return
/self->lbolt/
{
    @ = quantize(self->ab->b_arc_access - self->lbolt);
    self->ab = 0;
    self->lbolt = 0;
}