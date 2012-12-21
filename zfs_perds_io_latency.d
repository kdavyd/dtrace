#!/usr/sbin/dtrace -s
#pragma D option quiet

BEGIN {

        x = 0; 
        y = 0;
        watermark = 100; /* We want to track all IO slower than 50ms. */
        start_d = timestamp;
        to_millisec = 1000000;
        to_microsec = 1000;
        div = "--------------------------------------------------------------------------------";
}

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && args[3]/ /* Reads */

{
        this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
        this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
        /* this->path = strjoin(strjoin(this->parent,"/"),this->ds); */ /* Dirty hack - parent/this format doesn't guarantee full path */
        self->path = strjoin(strjoin(this->parent,"/"),this->ds);
        self->uniq = args[0]->dn_objset->os_dsl_dataset->ds_fsid_guid;
        self->reads = 1;
        ts[ self->path, self->reads, self->uniq ] = timestamp;
       
}

dmu_buf_hold_array_by_dnode:entry
/args[0]->dn_objset->os_dsl_dataset && !args[3]/ /* Writes */

{
        this->ds = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_myname);
        this->parent = stringof(args[0]->dn_objset->os_dsl_dataset->ds_dir->dd_parent->dd_myname);
        /* this->path = strjoin(strjoin(this->parent,"/"),this->ds); */ /* Dirty hack - parent/this format doesn't guarantee full path */
        self->path = strjoin(strjoin(this->parent,"/"),this->ds);
        self->uniq = args[0]->dn_objset->os_dsl_dataset->ds_fsid_guid;
        self->writes = 1;
        ts[ self->path, self->writes, self->uniq ] = timestamp;
       
}

dmu_buf_hold_array_by_dnode:return
/ts[ self->path, self->reads, self->uniq ] && args[1] == 0/
{
        x = (timestamp - ts[ self->path, self->reads, self->uniq ]) / to_microsec;
        @["Reads (us)", self->path] = lquantize(x,0,100,10);
        self->reads = 0;
}

dmu_buf_hold_array_by_dnode:return
/ts[ self->path, self->writes, self->uniq ] && args[1] == 0/
{
        x = (timestamp - ts[ self->path, self->writes, self->uniq ]) / to_microsec;
        @["Writes (us)", self->path] = lquantize(x,0,100,10);
        self->writes = 0;
}
