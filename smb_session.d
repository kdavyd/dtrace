#!/usr/sbin/dtrace -s
#pragma D option quiet

smb_session_create:entry
{
        self->i = 1;
}

smb_session_create:return
/self->i && args[1]==NULL/
{
        printf("Session_create returned NULL\n");
        self->i = 0;
}

smb_server_create_session:entry
{
        self->i2 = 1;
}

taskq_dispatch:entry
/self->i2/
{
        printf("%s taskq dispatched\n",stringof(args[0]->tq_name));
}

taskq_dispatch:return
/self->i2 && args[1] == 0/
{
        printf("taskq_dispatch returned 0\n");
}

taskq_ent_alloc:return
/self->i2 && args[1]!=NULL/
{
        printf("taskq_ent_alloc returned a value\n");
}

taskq_ent_alloc:return
/self->i2 && args[1] == NULL/
{
        printf("taskq_ent_alloc returned NULL\n");
}

taskq_bucket_dispatch:return
/self->i2 && args[1]!=NULL/
{
        printf("taskq_bucket_dispatch returned a value\n");
}

taskq_bucket_dispatch:return
/self->i2 && args[1] == NULL/
{
        printf("taskq_bucket_dispatch returned NULL\n");
}

taskq_bucket_dispatch:entry
/self->i2 && args[0]->tqbucket_nfree == 0/
{
        printf("tqbucket_nfree == 0; tqbucket_nalloc =%d \n",args[0]->tqbucket_nalloc);
}

taskq_bucket_dispatch:entry
/self->i2 && (args[0]->tqbucket_flags & 0x02)/
{
        printf("tqbucket_flags & TQBUCKET_SUSPEND\n");
}

smb_server_create_session:return
/self->i2/
{
        self->i2 = 0;
}

smb_session_create:return
/self->i && args[1]!=NULL/
{
        printf("Session_create returned with key %d\n",args[1]->sesskey);
        self->i = 0;
}
