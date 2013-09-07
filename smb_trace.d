#!/usr/sbin/dtrace -s
#pragma D option quiet

sdt:smbsrv::-smb_op-NtCreateX-start
{
        sr =  (struct smb_request *)arg0;
        op =  (struct open_param *)arg1;
        printf("%s %s %s\n", stringof(sr->uid_user->u_name), stringof(sr->tid_tree->t_resource), stringof(op->fqi.fq_path.pn_path));
}
