#!/usr/sbin/dtrace -s
 
/*
 *
 * filemon_zfs.d - Monitors specific file access
 *               Written using DTrace.
 *
 *
 * $Id: filemon_zfs.d 1 2010-03-12 14:16:26Z sergio $
 *
 * USAGE:       filemon_zfs.d
 *
 *  eg,
 *       ./filemon_zfs.d /var/adm/messages   # Monitor access to /var/adm/messages
 *
 * Must be root or with DTrace role privilege
 *
 * NOTES: This script uses dtrace so it should work on Solaris or OpenSolaris
 *
 * THANKS: The students of a DTrace course for the idea
 *
 * COPYRIGHT: Copyright (c) 2008 Sergio Rodriguez de Guzman Martinez
 *
 * CDDL HEADER START
 *
 *  The contents of this file are subject to the terms of the
 *  Common Development and Distribution License, Version 1.0 only
 *  (the "License").  You may not use this file except in compliance
 *  with the License.
 *
 *  You can obtain a copy of the license at Docs/cddl1.txt
 *  or http://www.opensolaris.org/os/licensing.
 *  See the License for the specific language governing permissions
 *  and limitations under the License.
 *
 * CDDL HEADER END
 *
 * Author: Sergio Rodriguez de Guzman [Madrid, Spain]
 *
 * 12-03-2010  Sergio Rodriguez de Guzman   Created this.
 *
 *
 */
 
#pragma D option quiet
 
BEGIN
{
        printf ("%20s%20s%8s%20s%10s%10s\n", "DATE", "CMD", "R/W/D", "PATH", "USER", "PID");
}
 
zfs_read:entry,
zfs_getpage:entry
{
       self->filepath = args[0]->v_path;
}
 
zfs_write:entry,
zfs_putpage:entry
{
       self->filepath = args[0]->v_path;
}
 
zfs_write:return,
zfs_putpage:return
/ strstr(stringof(self->filepath), $1) != NULL /
{

       printf("%20Y%20s%8s%    20s%10d%10d\n",
                walltimestamp, execname, "W", stringof(self->filepath), uid, pid);
       self->filepath = 0;
}
 
zfs_read:return,
zfs_getpage:return
/ strstr(stringof(self->filepath), $1) != NULL /
{
       printf("%20Y%20s%8s%    20s%10d%10d\n",
                walltimestamp, execname, "R", stringof(self->filepath), uid, pid);
       self->filepath = 0;
}
 
zfs_remove:entry
{
        self->filepath = strjoin( stringof(args[0]->v_path), "/" );
        self->filepath = strjoin( self->filepath, stringof(args[1]) );
}
 
zfs_remove:return
/ strstr(stringof(self->filepath), $1) != NULL /
{
       printf("%20Y%20s%8s%    20s%10d%10d\n",
                walltimestamp, execname, "D", stringof(self->filepath), uid, pid);
}
