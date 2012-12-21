#!/usr/sbin/dtrace -s

fbt::space_map_alloc:entry
{
   self->s = arg1;
}

fbt::space_map_alloc:return
/arg1 != -1/
{
  self->s = 0;
}

fbt::space_map_alloc:return
/self->s && (arg1 == -1)/
{
  @s = quantize(self->s);
  self->s = 0;
}

tick-10s
{
  printa(@s);
}