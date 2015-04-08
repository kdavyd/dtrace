#!/usr/sbin/dtrace -s
#pragma D option quiet

sdt:smbsrv::-smb_op-NtCreateX-start
{
        self->sr =  (struct smb_request *)arg0;
        self->op =  (struct open_param *)arg1;
        printf("%Y %s %s %s\n", walltimestamp, stringof(self->sr->uid_user->u_name), stringof(self->sr->tid_tree->t_resource), stringof(self->op->fqi.fq_path.pn_path));
}
