#!/usr/sbin/dtrace -s
#pragma D option quiet
#pragma D option defaultargs
#pragma D option switchrate=1000hz
#pragma D option dynvarsize=512m


inline int TICKS=$1;
inline string ADDR=$$2;

dtrace:::BEGIN
{
       TIMER = ( TICKS != NULL ) ?  TICKS : 1 ;
       ticks = TIMER;
       TITLE=10;
       title = 0;
       walltime= walltimestamp/1000000000;
    type="R";
        io_tm[type]=0;
        io_ct[type]=0;
        io_sz[type]=0;
        nfs_tm[type]=0;
        nfs_ct[type]=0;
        nfs_sz[type]=0;
        zfs_tm[type]=0;
        zfs_ct[type]=0;
        zfs_sz[type]=0;
        tcp_ct[type]=0;
        tcp_sz[type]=0;
    type="W";
        io_tm[type]=0;
        io_ct[type]=0;
        io_sz[type]=0;
        nfs_tm[type]=0;
        nfs_ct[type]=0;
        nfs_sz[type]=0;
        zfs_tm[type]=0;
        zfs_ct[type]=0;
        zfs_sz[type]=0;
        tcp_ct[type]=0;
        tcp_sz[type]=0;
    @nfs_rmx=max(0);
    @nfs_wmx=max(0);
    @zfs_rmx=max(0);
    @zfs_wmx=max(0);
    @io_rmx=max(0);
    @io_wmx=max(0);
}

/* ===================== beg TCP ================================= */
tcp:::send
/  ( ADDR == NULL || args[3]->tcps_raddr == ADDR ) &&  args[2]->ip_plength - args[4]->tcp_offset > 0 /
{
       this->type="R";
       tcp_ct[this->type]++;
       tcp_sz[this->type]=tcp_sz[this->type]+ args[2]->ip_plength - args[4]->tcp_offset;
       @tcprsz=quantize(args[2]->ip_plength - args[4]->tcp_offset);
}
tcp:::receive
/  ( ADDR == NULL || args[3]->tcps_raddr == ADDR ) &&  args[2]->ip_plength - args[4]->tcp_offset > 0 /
{
       this->type="W";
       tcp_ct[this->type]++;
       tcp_sz[this->type]=tcp_sz[this->type]+ args[2]->ip_plength - args[4]->tcp_offset;
       @tcpwsz=quantize(args[2]->ip_plength - args[4]->tcp_offset);
}
/* ===================== end TCP ================================= */

/* ===================== beg NFS ================================= */
nfsv3:::op-read-start, nfsv3:::op-write-start ,nfsv4:::op-read-start
{
        tm[args[1]->noi_xid] = timestamp;
        sz[args[1]->noi_xid] = args[2]->count    ;
}
nfsv4:::op-write-start
{
        tm[args[1]->noi_xid] = timestamp;
        sz[args[1]->noi_xid] = args[2]->data_len ;
}
nfsv3:::op-read-done, nfsv3:::op-write-done, nfsv4:::op-read-done, nfsv4:::op-write-done
/tm[args[1]->noi_xid]/
{
        this->delta= timestamp - tm[args[1]->noi_xid];
        this->type =  probename == "op-write-done" ? "W" : "R";
        nfs_tm[this->type]=nfs_tm[this->type]+this->delta;
        @nfs_rmx=max( (this->type == "R" ? this->delta : 0)/1000000);
        @nfs_wmx=max( (this->type == "W" ? this->delta : 0)/1000000);
        nfs_ct[this->type]++;
        nfs_sz[this->type]=nfs_sz[this->type]+ sz[args[1]->noi_xid];
        tm[args[1]->noi_xid] = 0;
        sz[args[1]->noi_xid] = 0;
}
/* --------------------- end NFS --------------------------------- */

/* ===================== beg ZFS ================================= */

zfs_read:entry,zfs_write:entry
{
         self->ts = timestamp;
         self->filepath = args[0]->v_path;
         self->size = ((uio_t *)arg1)->uio_resid;
}


zfs_read:return,zfs_write:return
/self->ts  /
{
        this->type =  probefunc == "zfs_write" ? "W" : "R";
        this->delta=timestamp - self->ts ;
        zfs_tm[this->type]= zfs_tm[this->type] + this->delta;
        zfs_ct[this->type]++;
        zfs_sz[this->type]=zfs_sz[this->type]+self->size;
        @zfs_rmx=max( (this->type == "R" ? this->delta : 0)/1000000);
        @zfs_wmx=max( (this->type == "W" ? this->delta : 0)/1000000);
        self->ts=0;
        self->filepath=0;
        self->size=0;
}
/* --------------------- end ZFS --------------------------------- */



/* ===================== beg IO ================================= */
io:::start
/ arg0 != NULL && args[0]->b_addr != 0 /
{
       tm_io[(struct buf *)arg0] = timestamp;
       sz_io[(struct buf *)arg0] = args[0]->b_bcount;

}
io:::done
/tm_io[(struct buf *)arg0]/
{
      this->type = args[0]->b_flags & B_READ ? "R" : "W" ;
      this->delta = ( timestamp - tm_io[(struct buf *)arg0]);
       io_tm[this->type]=io_tm[this->type]+this->delta;
       @io_rmx=max( (this->type == "R" ? this->delta : 0)/1000000);
       @io_wmx=max( (this->type == "W" ? this->delta : 0)/1000000);
       io_ct[this->type]++;
       io_sz[this->type]=io_sz[this->type]+ sz_io[(struct buf *)arg0] ;
       sz_io[(struct buf *)arg0] = 0;
       tm_io[(struct buf *)arg0] = 0;
}
/* --------------------- end IO --------------------------------- */



profile:::tick-1sec / ticks > 0 / { ticks--; }

profile:::tick-1sec
/ ticks == 0 /
{
    type="R";
    printf("-------------avg_ms--------MB/s--IO/sz/kb--max_ms--- summary\n");
    printf("   %s | IO  :  %4d.%03d  %6d.%03d  %4d ",type,
        (io_sz[type]/8196  == 0  ? 0 :  io_tm[type]/(io_sz[type]/8196))/1000000 ,
        ((io_sz[type]/8196  == 0  ? 0 :  io_tm[type]/(io_sz[type]/8196))/1000) % 1000,
        (io_sz[type]/TIMER)/1000000,
        ((io_sz[type]/TIMER)/1000)%1000,
        (io_ct[type]  == 0  ? 0 :  io_sz[type]/io_ct[type])/1000 );
    printa(" %@8u summary\n", @io_rmx);
    printf("   %s | ZFS :  %4d.%03d  %6d.%03d  %4d ",type,
        (zfs_sz[type]/8196 == 0  ? 0 :  zfs_tm[type]/(zfs_sz[type]/8196))/1000000,
        ((zfs_sz[type]/8196 == 0  ? 0 :  zfs_tm[type]/(zfs_sz[type]/8196))/1000) % 1000,
        (zfs_sz[type]/TIMER)/1000000,
        ((zfs_sz[type]/TIMER)/1000)%1000,
        (zfs_ct[type] == 0  ? 0 :  zfs_sz[type]/zfs_ct[type])/1000);
    printa(" %@8u summary\n", @zfs_rmx);
    printf("   %s | NFS :  %4d.%03d  %6d.%03d  %4d ",type,
        (nfs_sz[type]/8196 == 0  ? 0 :  nfs_tm[type]/(nfs_sz[type]/8196))/1000000,
        ((nfs_sz[type]/8196 == 0  ? 0 :  nfs_tm[type]/(nfs_sz[type]/8196))/1000) % 1000,
        (nfs_sz[type]/TIMER)/1000000,
        ((nfs_sz[type]/TIMER)/1000)%1000,
        (nfs_ct[type] == 0  ? 0 :  nfs_sz[type]/nfs_ct[type])/1000);
    printa(" %@8u summary ", @nfs_rmx );
    printf(" %8d \n", nfs_ct[type]);
    printf("   %s | TCP :            %6d.%03d       ",type,
        (tcp_sz[type]/TIMER)/1000000,
        ((tcp_sz[type]/TIMER)/1000)%1000
        );
    printf("          summary %d\n",tcp_ct[type]/TIMER);
    type="W";
    printf("   ------                                              summary\n");
    printf("   %s | IO  :  %4d.%03d  %6d.%03d  %4d ",type,
        (io_sz[type]/8196  == 0  ? 0 :  io_tm[type]/(io_sz[type]/8196))/1000000 ,
        ((io_sz[type]/8196  == 0  ? 0 :  io_tm[type]/(io_sz[type]/8196))/1000) % 1000,
        (io_sz[type]/TIMER)/1000000,
        ((io_sz[type]/TIMER)/1000)%1000,
        (io_ct[type]  == 0  ? 0 :  io_sz[type]/io_ct[type])/1000 );
    printa(" %@8u summary\n", @io_wmx);
    printf("   %s | ZFS :  %4d.%03d  %6d.%03d  %4d ",type,
        (zfs_sz[type]/8196 == 0  ? 0 :  zfs_tm[type]/(zfs_sz[type]/8196))/1000000,
        ((zfs_sz[type]/8196 == 0  ? 0 :  zfs_tm[type]/(zfs_sz[type]/8196))/1000) % 1000,
        (zfs_sz[type]/TIMER)/1000000,
        ((zfs_sz[type]/TIMER)/1000)%1000,
        (zfs_ct[type] == 0  ? 0 :  zfs_sz[type]/zfs_ct[type])/1000);
    printa(" %@8u summary\n", @zfs_wmx);
    printf("   %s | NFS :  %4d.%03d  %6d.%03d  %4d ",type,
        (nfs_sz[type]/8196 == 0  ? 0 :  nfs_tm[type]/(nfs_sz[type]/8196))/1000000,
        ((nfs_sz[type]/8196 == 0  ? 0 :  nfs_tm[type]/(nfs_sz[type]/8196))/1000) % 1000,
        (nfs_sz[type]/TIMER)/1000000,
        ((nfs_sz[type]/TIMER)/1000)%1000,
        (nfs_ct[type] == 0  ? 0 :  nfs_sz[type]/nfs_ct[type])/1000);
    printa(" %@8u summary\n", @nfs_wmx);
    printf("   %s | TCP :            %6d.%03d       ",type,
        (tcp_sz[type]/TIMER)/1000000,
        ((tcp_sz[type]/TIMER)/1000)%1000
        );
    printf("          summary %d\n",tcp_ct[type]/TIMER);
    printf(" IOPs   %u                                    summary\n", (io_ct["W"]+io_ct["R"])/TIMER);
/*
    printa("tcp in  (sz) %@d\n",@tcpwsz);
    printa("tcp out (sz) %@d\n",@tcprsz);
*/
    type="R";
    trunc(@tcpwsz);
    trunc(@tcprsz);
    io_tm[type]=0;
    io_ct[type]=0;
    io_sz[type]=0;
    nfs_tm[type]=0;
    nfs_ct[type]=0;
    nfs_sz[type]=0;
    zfs_tm[type]=0;
    zfs_ct[type]=0;
    zfs_sz[type]=0;
    tcp_ct[type]=0;
    tcp_sz[type]=0;
    type="W";
    io_tm[type]=0;
    io_ct[type]=0;
    io_sz[type]=0;
    nfs_tm[type]=0;
    nfs_ct[type]=0;
    nfs_sz[type]=0;
    zfs_tm[type]=0;
    zfs_ct[type]=0;
    zfs_sz[type]=0;
    tcp_ct[type]=0;
    tcp_sz[type]=0;
    ticks= TIMER;
    title--;
    clear(@nfs_rmx);
    clear(@nfs_wmx);
    clear(@zfs_rmx);
    clear(@zfs_wmx);
    clear(@io_rmx);
    clear(@io_wmx);
}

/* use if you want to print something every TITLE lines */
profile:::tick-1sec / title <= 0 / { title=TITLE; }