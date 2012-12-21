#!/usr/sbin/dtrace -s

#pragma D option quiet

tcp:::send
{
    snxt[args[1]->cs_cid, args[3]->tcps_snxt] = timestamp;
    bytesrttttmp[args[1]->cs_cid, args[3]->tcps_snxt] =
        args[2]->ip_plength - args[4]->tcp_offset;
}

tcp:::receive
/ snxt[args[1]->cs_cid, args[4]->tcp_ack] /
{
    @bytesrtt[args[2]->ip_saddr, args[4]->tcp_sport] =
        sum(bytesrttttmp[args[1]->cs_cid, args[4]->tcp_ack]);
    @meanrtt[args[2]->ip_saddr, args[4]->tcp_sport] =
        avg(timestamp - snxt[args[1]->cs_cid, args[4]->tcp_ack]);
    @stddevrtt[args[2]->ip_saddr, args[4]->tcp_sport] =
            stddev(timestamp - snxt[args[1]->cs_cid, args[4]->tcp_ack]);
    @countrtt[args[2]->ip_saddr, args[4]->tcp_sport] = count();
    snxt[args[1]->cs_cid, args[4]->tcp_ack] = 0;
    bytesrttttmp[args[1]->cs_cid, args[4]->tcp_ack] = 0;
}

END
{
    printf("%-20s %-8s %-15s %-15s %-10s %-7s\n",
        "Remote host", "Port", "TCP Avg RTT(ns)", "StdDev", "NumBytes",
        "NumSegs");
    printa("%-20s %-8d %@-15d %@-15d %@-10d %@-7d\n", @meanrtt,
        @stddevrtt, @bytesrtt, @countrtt);
}
