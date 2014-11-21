#!/usr/sbin/dtrace -qs

dtrace:::BEGIN
{
        r_iops = 1;
        rtask = 0;
        rqtime = 0;
        r_lu_xfer = 0;
        r_lport_xfer = 0;

        w_iops = 1;
        wtask = 0;
        wqtime = 0;
        w_lu_xfer = 0;
        w_lport_xfer = 0;
}

/*
 * read task completed
 */
sdt:stmf:stmf_task_free:stmf-task-end
/((scsi_task_t *) arg0)->task_flags & 0x40/
{
        this->task = (scsi_task_t *) arg0;
        this->lu = (stmf_lu_t *) this->task->task_lu;
        this->itask = (stmf_i_scsi_task_t *) this->task->task_stmf_private;
        this->lport = this->task->task_lport;

        r_iops = r_iops + 1;

        rtask = rtask + (arg1 / 1000);
        rqtime = rqtime + (this->itask->itask_waitq_time / 1000);
        r_lu_xfer = r_lu_xfer + (this->itask->itask_lu_read_time / 1000);
        r_lport_xfer = r_lport_xfer + (this->itask->itask_lport_read_time / 1000);
}

/*
 * write task completed
 */
sdt:stmf:stmf_task_free:stmf-task-end
/((scsi_task_t *) arg0)->task_flags & 0x20/
{
        this->task = (scsi_task_t *) arg0;
        this->lu = (stmf_lu_t *) this->task->task_lu;
        this->itask = (stmf_i_scsi_task_t *) this->task->task_stmf_private;
        this->lport = this->task->task_lport;

        w_iops = w_iops + 1;

        /* Save total time in usecs */
        wtask = wtask + (arg1 / 1000);
        wqtime = wqtime + (this->itask->itask_waitq_time / 1000);
        w_lu_xfer = w_lu_xfer + (this->itask->itask_lu_write_time / 1000);
        w_lport_xfer = w_lport_xfer + (this->itask->itask_lport_write_time / 1000);
}

profile:::tick-5sec
/r_iops || w_iops/
{

        timer = (walltimestamp / 1000000000);

        avg_task = rtask / r_iops;
        avg_qtime = rqtime / r_iops;
        avg_lu_xfer = r_lu_xfer / r_iops;
        avg_lport_xfer = r_lport_xfer / r_iops;

        printf("r_s %d %d\n", r_iops, timer);
        printf("r_lu_xfer_us %d %d\n", avg_lu_xfer, timer);
        printf("r_lport_xfer_us %d %d\n", avg_lport_xfer, timer);
        printf("r_qtime_us %d %d\n", avg_qtime, timer);
        printf("r_tasktime_us %d %d\n", avg_task, timer);

        avg_task = wtask / w_iops;
        avg_qtime = wqtime / w_iops;
        avg_lu_xfer = w_lu_xfer / w_iops;
        avg_lport_xfer = w_lport_xfer / w_iops;

        printf("w_s %d %d\n", w_iops, timer);
        printf("w_lu_xfer_us %d %d\n", avg_lu_xfer, timer);
        printf("w_lport_xfer_us %d %d\n", avg_lport_xfer, timer);
        printf("w_qtime_us %d %d\n", avg_qtime, timer);
        printf("w_tasktime_us %d %d\n", avg_task, timer);

        /* Resetting globals */
        r_iops = 1;
        rtask = 0;
        rqtime = 0;
        r_lu_xfer = 0;
        r_lport_xfer = 0;

        w_iops = 1;
        wtask = 0;
        wqtime = 0;
        w_lu_xfer = 0;
        w_lport_xfer = 0;
}
