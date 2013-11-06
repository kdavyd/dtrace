#!/usr/sbin/dtrace -s


pid$target:a.out:check_rmtcalls:entry
{
	self->i1 = 1;
	self->ts1 = timestamp;
}

pid$target:*:svc_getreq_poll:entry
{
	self->i2 = 1;
	self->ts2 = timestamp;
}

pid$target:*:svc_sendreply:entry
{
	self->i3 = 1;
	self->ts3 = timestamp;
}

svc_sendreply:entry
{
	self->i4 = 1;
	self->ts4 = timestamp;
}


pid$target:a.out:check_rmtcalls:return
/self->i1/
{
	@ts_rmt["check_rmtcalls"]=quantize(timestamp - self->ts1);
	self->i1 = 0;
	self->ts1 = 0;

}

pid$target:*:svc_getreq_poll:return
/self->i2/
{
	@ts_sgp["svc_getreq_poll"]=quantize(timestamp - self->ts2);
	self->i2 = 0;
	self->ts2 = 0;

}

pid$target:*:svc_sendreply:return
/self->i3/
{
	@ts_sr["pid svc_sendreply"]=quantize(timestamp - self->ts3);
	self->i3 = 0;
	self->ts3 = 0;

}

svc_sendreply:return
/self->i4/
{
	@ts_sr4["svc_sendreply"]=quantize(timestamp - self->ts4);
	self->i4 = 0;
	self->ts4 = 0;

}

tick-1sec
{
	printf("%Y\n",walltimestamp);	
}

tick-30sec
{
	printa(@ts_sr, @ts_sr4, @ts_sgp, @ts_rmt);
	trunc(@ts_sr);trunc(@ts_sr4);trunc(@ts_sgp); trunc(@ts_rmt);
}
