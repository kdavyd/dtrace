#!/usr/sbin/dtrace -s

#pragma D option quiet

dtrace:::BEGIN
{
    printf("Tracing... output every 10 seconds.\n");
}

fbt::sd_set_retry_bp:entry
{
    @[xlate <devinfo_t *>(args[1])->dev_statname,
        xlate <devinfo_t *>(args[1])->dev_major,
        xlate <devinfo_t *>(args[1])->dev_minor] = count();
}

tick-10sec
{
    printf("\n%Y:\n", walltimestamp);
    printf("%28s  %-3s,%-4s  %s\n", "DEVICE", "MAJ", "MIN", "RETRIES");
    printa("%28s  %-03d,%-4d  %@d\n", @);
    trunc(@);
}
