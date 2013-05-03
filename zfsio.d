#!/usr/sbin/dtrace -s
#pragma D option quiet

/* Description: This script will show read/write IOPs and throughput for ZFS
 * filesystems and zvols on a per-dataset basis. It can be used to estimate
 * which dataset is causing the most I/O load on the current system. It should 
 * only be used for comparative analysis. */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2012, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.4b */

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && args[3]/ /* Reads */
{
        this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
        this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
        this->path = strjoin(strjoin(this->parent,"/"),this->ds); /* Dirty hack - parent/this format doesn't guarantee full path */
        @ior[this->path] = count();
        @tpr[this->path] = sum(args[2]);
        @bsr[this->path] = avg(args[2]);
        @distr[strjoin(this->path, " Reads")] = quantize(args[2]);
}

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && !args[3]/ /* Writes */
{
        this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
        this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
        this->path = strjoin(strjoin(this->parent,"/"),this->ds);
        @iow[this->path] = count();
        @tpw[this->path] = sum(args[2]);
        @bsw[this->path] = avg(args[2]);
        @distw[strjoin(this->path, " Writes")] = quantize(args[2]);
}

tick-1sec
{
        printf("%Y                      operations       bandwidth           blocksize\n",walltimestamp);
        printf("Dataset                                  read   write  read       write      read   write\n");
        printf("                                         ------ ------ ---------- ---------- ------ ------\n");
        printa("%-40s %@-6d %@-6d %@-10d %@-10d %@-6d %@-6d\n",@ior,@iow,@tpr,@tpw,@bsr,@bsw);
        trunc(@ior); trunc(@tpr); trunc(@iow); trunc(@tpw); trunc(@bsr); trunc(@bsw);
     /* clear(@ior); clear(@tpr); clear(@iow); clear(@tpw); clear(@bsr); clear(@bsw);*/
     /* TODO: Make script more interactive. Above, uncomment clear() and comment trunc() line in order to change
        truncate behavior, or comment out both lines to get cumulative stats. */
}
