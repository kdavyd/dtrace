#!/usr/bin/bash

if [ -z "$1" ]
  then
    export HOSTNAME=`hostname`
  else
    export HOSTNAME=$1
fi

if [ -z "$2" ]
  then
    export INTERVAL=10
  else
    export INTERVAL=$2
fi

/usr/sbin/dtrace -Cn '

#pragma D option quiet

/* Description: This script will show read/write IOPs and throughput for ZFS
 * filesystems and zvols on a per-dataset basis. It can be used to estimate
 * which dataset is causing the most I/O load on the current system. It should 
 * only be used for comparative analysis. */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2012, 2014 Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.5b */

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && args[3]/ /* Reads */
{
        this->d = args[0]->dn_objset->os_dsl_dataset->ds_dir;
        this->path = stringof(this->d->dd_myname);
        this->p = this->d->dd_parent;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;

        @ior[this->path] = count();
        @tpr[this->path] = sum(args[2]);
        @bsr[this->path] = avg(args[2]);
	@wts_sec[this->path] = max(walltimestamp / 1000000000);
        @distr[strjoin(this->path, " Reads")] = quantize(args[2]);
}

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && !args[3]/ /* Writes */
{
        this->d = args[0]->dn_objset->os_dsl_dataset->ds_dir;
        this->path = stringof(this->d->dd_myname);
        this->p = this->d->dd_parent;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;
        this->p =  (this->p != NULL) ? this->p->dd_parent : NULL;
        this->path = (this->p != NULL) ? strjoin(stringof(this->p->dd_myname),strjoin((this->p->dd_parent != NULL) ? "-" : "/" ,this->path)):this->path;

        @iow[this->path] = count();
        @tpw[this->path] = sum(args[2]);
        @bsw[this->path] = avg(args[2]);
	@wts_sec[this->path] = max(walltimestamp / 1000000000);
        @distw[strjoin(this->path, " Writes")] = quantize(args[2]);
}

tick-'$INTERVAL'sec,END
{
        printa("PUTVAL '$HOSTNAME'.zfs.%s/gauge-reads %@d:%@d\n", @wts_sec, @ior);
        printa("PUTVAL '$HOSTNAME'.zfs.%s/gauge-writes %@d:%@d\n", @wts_sec, @iow);
        printa("PUTVAL '$HOSTNAME'.zfs.%s/gauge-r_bytes %@d:%@d\n", @wts_sec, @tpr);
        printa("PUTVAL '$HOSTNAME'.zfs.%s/gauge-w_bytes %@d:%@d\n", @wts_sec, @tpw);
        printa("PUTVAL '$HOSTNAME'.zfs.%s/gauge-r_bs %@d:%@d\n", @wts_sec, @bsr);
        printa("PUTVAL '$HOSTNAME'.zfs.%s/gauge-w_bs %@d:%@d\n", @wts_sec, @bsw);



        trunc(@ior); trunc(@tpr); trunc(@iow); trunc(@tpw); trunc(@bsr); trunc(@bsw); trunc(@wts_sec);
     /* clear(@ior); clear(@tpr); clear(@iow); clear(@tpw); clear(@bsr); clear(@bsw);*/
     /* TODO: Make script more interactive. Above, uncomment clear() and comment trunc() line in order to change
        truncate behavior, or comment out both lines to get cumulative stats. */
}
'
