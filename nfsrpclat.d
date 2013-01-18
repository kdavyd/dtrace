#!/usr/sbin/dtrace -s
# pragma D option quiet


svc_cots_krecv:entry
{
self->xid = args[0]->xp_xid;
self->ts = timestamp;
}


svc_cots_ksend:entry
/self->xid && (timestamp-self->ts)/1000000 > 100/
{
self->rtaddr = ((struct sockaddr_in *)args[0]->xp_xpc.xpc_rtaddr.buf)->sin_addr.S_un.S_addr;
printf("%Y XID: %d Client: %i.%i.%i.%i lat: %d ms\n", walltimestamp,
                                                self->xid,
                                                self->rtaddr&0xff, self->rtaddr>>8&0xff,self->rtaddr>>16&0xff,self->rtaddr>>24,
                                                (timestamp-self->ts)/1000000);
}
