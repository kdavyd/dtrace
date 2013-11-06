#!/usr/sbin/dtrace -s


pid$target:a.out:pmapproc_getport:entry
{
	self->i = 1;
	self->depth = 0;
	self->ts = timestamp;
	@k[stack()]=count();
	@u[ustack()]=count();
	@in_getport = sum(1);
}

pid$target:a.out:pmapproc_getport:return
/self->i/
{
	@ts=quantize(timestamp - self->ts);
	self->i = 0;
	self->ts = 0;
	@in_getport = sum(-1);

}

tick-1sec
{
	printa("%@d in getport",@in_getport);
}

tick-30sec
{
	printa(@ts);printa(@k);printa(@u);
	trunc(@ts);trunc(@k);trunc(@u);
}
