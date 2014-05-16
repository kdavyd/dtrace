#!/usr/sbin/dtrace -s
#pragma D option quiet

/* Description: Print kernel and userland stacks for every non-zero return from TUR */
/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2014, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.1 */

sd_ready_and_valid:entry
{
        self->i = 1;
}

sd_send_scsi_TEST_UNIT_READY:return
/self->i && arg1 != 0/
{
        printf("TUR returned code %d \n",arg1);
        stack();
        ustack();
}

sd_ready_and_valid:return
/self->i/
{
        self->i = 0;
}
