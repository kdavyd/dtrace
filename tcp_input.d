#!/usr/sbin/dtrace -s
#pragma D option quiet

tcp_input_listener:entry
{
	printf("%Y cnt %d max %d\n",walltimestamp,
		((conn_t *)args[0])->conn_proto_priv.cp_tcp->tcp_conn_req_cnt_q,
		((conn_t *)args[0])->conn_proto_priv.cp_tcp->tcp_conn_req_max);
}
