#!/usr/sbin/dtrace -Cs 

#pragma D option quiet 
#pragma D option switchrate=10hz 

typedef enum idm_status { 
        IDM_STATUS_SUCCESS = 0, 
        IDM_STATUS_FAIL, 
        IDM_STATUS_NORESOURCES, 
        IDM_STATUS_REJECT, 
        IDM_STATUS_IO, 
        IDM_STATUS_ABORTED, 
        IDM_STATUS_SUSPENDED, 
        IDM_STATUS_HEADER_DIGEST, 
        IDM_STATUS_DATA_DIGEST, 
        IDM_STATUS_PROTOCOL_ERROR, 
        IDM_STATUS_LOGIN_FAIL 
} idm_status_t; 

dtrace:::BEGIN 
{ 
   /* 
	* The following was generated from the SCSI_CMDS_KEY_STRINGS 
	* definitions in /usr/include/sys/scsi/generic/commands.h using sed.
	* Additional codes gathered from http://en.wikipedia.org/wiki/SCSI_command
	*/ 
	scsi_cmd[0x00] = "test_unit_ready"; 
	scsi_cmd[0x01] = "rezero/rewind"; 
	scsi_cmd[0x03] = "request_sense"; 
	scsi_cmd[0x04] = "format"; 
	scsi_cmd[0x05] = "read_block_limits"; 
	scsi_cmd[0x07] = "reassign"; 
	scsi_cmd[0x08] = "read"; 
	scsi_cmd[0x0a] = "write"; 
	scsi_cmd[0x0b] = "seek"; 
	scsi_cmd[0x0f] = "read_reverse";
	scsi_cmd[0x10] = "write_file_mark";
	scsi_cmd[0x11] = "space";
	scsi_cmd[0x12] = "inquiry";
	scsi_cmd[0x13] = "verify";
	scsi_cmd[0x14] = "recover_buffer_data";
	scsi_cmd[0x15] = "mode_select";
	scsi_cmd[0x16] = "reserve";
	scsi_cmd[0x17] = "release";
	scsi_cmd[0x18] = "copy";
	scsi_cmd[0x19] = "erase_tape";
	scsi_cmd[0x1a] = "mode_sense";
	scsi_cmd[0x1b] = "load/start/stop";
	scsi_cmd[0x1c] = "get_diagnostic_results";
	scsi_cmd[0x1d] = "send_diagnostic_command";
	scsi_cmd[0x1e] = "door_lock";
	scsi_cmd[0x23] = "read_format_capacity";
	scsi_cmd[0x24] = "set_window";
	scsi_cmd[0x25] = "read_capacity";
	scsi_cmd[0x28] = "read(10)";
	scsi_cmd[0x29] = "read_generation";
	scsi_cmd[0x2a] = "write(10)";
	scsi_cmd[0x2b] = "seek(10)";
	scsi_cmd[0x2c] = "erase(10)";
	scsi_cmd[0x2d] = "read_updated_block";
	scsi_cmd[0x2e] = "write_verify";
	scsi_cmd[0x2f] = "verify(10)";
	scsi_cmd[0x30] = "search_data_high";
	scsi_cmd[0x31] = "search_data_equal";
	scsi_cmd[0x32] = "search_data_low";
	scsi_cmd[0x33] = "set_limits";
	scsi_cmd[0x34] = "read_position";
	scsi_cmd[0x35] = "synchronize_cache";
	scsi_cmd[0x36] = "lock_unlock_cache";
	scsi_cmd[0x37] = "read_defect_data";
	scsi_cmd[0x38] = "medium_scan";
	scsi_cmd[0x39] = "compare";
	scsi_cmd[0x3a] = "copy_verify";
	scsi_cmd[0x3b] = "write_buffer";
	scsi_cmd[0x3c] = "read_buffer";
	scsi_cmd[0x3d] = "update_block";
	scsi_cmd[0x3e] = "read_long";
	scsi_cmd[0x3f] = "write_long";
	scsi_cmd[0x40] = "change_definition";
	scsi_cmd[0x41] = "write_same(10)";
	scsi_cmd[0x44] = "report_densities/read_header";
	scsi_cmd[0x45] = "play_audio(10)";
	scsi_cmd[0x46] = "get_configuration";
	scsi_cmd[0x47] = "play_audio_msf";
	scsi_cmd[0x4a] = "get_event_status_notification";
	scsi_cmd[0x4b] = "pause_resume";
	scsi_cmd[0x4c] = "log_select";
	scsi_cmd[0x4d] = "log_sense";
	scsi_cmd[0x50] = "xdwrite(10)";
	scsi_cmd[0x51] = "xpwrite(10)";
	scsi_cmd[0x52] = "xdread(10)";
	scsi_cmd[0x53] = "xdwriteread(10)";
	scsi_cmd[0x54] = "send_opc_information";
	scsi_cmd[0x55] = "mode_select(10)";
	scsi_cmd[0x56] = "reserve(10)";
	scsi_cmd[0x57] = "release(10)";
	scsi_cmd[0x58] = "repair track";
	scsi_cmd[0x5a] = "mode_sense(10)";
	scsi_cmd[0x5b] = "close_track/session";
	scsi_cmd[0x5c] = "read_buffer_capacity";
	scsi_cmd[0x5d] = "send_cue_sheet";
	scsi_cmd[0x5e] = "persistent_reserve_in";
	scsi_cmd[0x5f] = "persistent_reserve_out";
	scsi_cmd[0x7e] = "extended_cdb";
	scsi_cmd[0x7f] = "variable_length_cdb";
	scsi_cmd[0x80] = "write_file_mark(16)";
	scsi_cmd[0x81] = "read_reverse(16)";
	scsi_cmd[0x82] = "regenerate(16)";
	scsi_cmd[0x83] = "extended_copy";
	scsi_cmd[0x84] = "receive_copy_results";
	scsi_cmd[0x85] = "ata_command_passthrough(16)";
	scsi_cmd[0x86] = "access_control_in";
	scsi_cmd[0x87] = "access_control_out";
	scsi_cmd[0x88] = "read(16)";
	scsi_cmd[0x8a] = "write(16)";
	scsi_cmd[0x8b] = "orwrite";
	scsi_cmd[0x8c] = "read_attribute";
	scsi_cmd[0x8d] = "write_attribute";
	scsi_cmd[0x8e] = "write_verify(16)";
	scsi_cmd[0x8f] = "verify(16)";
	scsi_cmd[0x90] = "prefetch(16)";
	scsi_cmd[0x91] = "synchronize_cache(16)";
	scsi_cmd[0x92] = "space(16)/lock_unlock_cache(16)";
	scsi_cmd[0x93] = "write_same(16)";
	scsi_cmd[0x9e] = "service_action_in(16)";
	scsi_cmd[0x9f] = "service_action_out(16)";
	scsi_cmd[0xa0] = "report_luns";
	scsi_cmd[0xa1] = "ata_command_passthrough(12)";
	scsi_cmd[0xa2] = "security_protocol_in";
	scsi_cmd[0xa3] = "report_supported_opcodes";
	scsi_cmd[0xa4] = "maintenance_out";
	scsi_cmd[0xa5] = "move_medium";
	scsi_cmd[0xa6] = "exchange_medium";
	scsi_cmd[0xa7] = "move_medium_attached";
	scsi_cmd[0xa8] = "read(12)";
	scsi_cmd[0xa9] = "service_action_out(12)";
	scsi_cmd[0xaa] = "write(12)";
	scsi_cmd[0xab] = "service_action_in(12)";
	scsi_cmd[0xac] = "get_performance/erase(12)";
	scsi_cmd[0xad] = "read_dvd_structure";
	scsi_cmd[0xae] = "write_verify(12)";
	scsi_cmd[0xaf] = "verify(12)";
	scsi_cmd[0xb0] = "search_data_high(12)";
	scsi_cmd[0xb1] = "search_data_equal(12)";
	scsi_cmd[0xb2] = "search_data_low(12)";
	scsi_cmd[0xb3] = "set_limits(12)";
	scsi_cmd[0xb4] = "read_element_status_attached";
	scsi_cmd[0xb5] = "security_protocol_out"; 
	scsi_cmd[0xb6] = "send_volume_tag";
	scsi_cmd[0xb7] = "read_defect_data(12)";
	scsi_cmd[0xb8] = "read_element_status";
	scsi_cmd[0xb9] = "read_cd_msf";
	scsi_cmd[0xba] = "redundancy_group_in";
	scsi_cmd[0xbb] = "redundancy_group_out";
	scsi_cmd[0xbc] = "spare_in";
	scsi_cmd[0xbd] = "spare_out";
	scsi_cmd[0xbe] = "volume_set_in";
	scsi_cmd[0xbf] = "volume_set_out";
	
	/* Key codes */
	key_code[0x0] = "no_sense";
	key_code[0x1] = "soft_error";
	key_code[0x2] = "not_ready";
	key_code[0x3] = "medium_error";
	key_code[0x4] = "hardware_error";
	key_code[0x5] = "illegal_request";
	key_code[0x6] = "unit_attention";
	key_code[0x7] = "data_protect";
	key_code[0x8] = "blank_check";
	key_code[0x9] = "vendor_specific";
	key_code[0xa] = "copy_aborted";
	key_code[0xb] = "aborted_command";
	/* key_code[0xc] is obsolete */
	key_code[0xd] = "volume_overflow";
	key_code[0xe] = "miscompare";
	/* key_code[0xf] is reserved */
	
	/* kcq codes - of the form key/asc/ascq */
	/* http://en.wikipedia.org/wiki/Key_Code_Qualifier */
	kcq_code[0x0,0x0,0x0] = "no error";
	kcq_code[0x5,0x24,0x0] = "illegal field in CDB";
	kcq_code[0x6,0x29,0x0] = "POR or device reset occurred";
	kcq_code[0x6,0x29,0x1] = "POR occurred";
	
	/* IDM status codes */
	status[IDM_STATUS_FAIL] = "FAIL"; 
	status[IDM_STATUS_NORESOURCES] = "NORESOURCES"; 
	status[IDM_STATUS_REJECT] = "REJECT"; 
	status[IDM_STATUS_IO] = "IO"; 
	status[IDM_STATUS_ABORTED] = "ABORTED"; 
	status[IDM_STATUS_SUSPENDED] = "SUSPENDED"; 
	status[IDM_STATUS_HEADER_DIGEST] = "HEADER_DIGEST"; 
	status[IDM_STATUS_DATA_DIGEST] = "DATA_DIGEST"; 
	status[IDM_STATUS_PROTOCOL_ERROR] = "PROTOCOL_ERROR"; 
	status[IDM_STATUS_LOGIN_FAIL] = "LOGIN_FAIL"; 

	printf("%-20s  %-20s %s\n", "TIME", "CLIENT", "ERROR"); 
} 

fbt::idm_pdu_complete:entry 
/arg1 != IDM_STATUS_SUCCESS/ 
{ 
	this->ic = args[0]->isp_ic; 
	this->remote = (this->ic->ic_raddr.ss_family == AF_INET) ? 
		inet_ntoa((ipaddr_t *)&((struct sockaddr_in *)& 
		this->ic->ic_raddr)->sin_addr) : 
		inet_ntoa6(&((struct sockaddr_in6 *)& 
		this->ic->ic_raddr)->sin6_addr); 

	this->err = status[arg1] != NULL ? status[arg1] : lltostr(arg1); 
	printf("%-20Y  %-20s %s\n", walltimestamp, this->remote, this->err);
} 

fbt::stmf_send_scsi_status:entry
/ args[0]->task_mgmt_function == 0 && args[0]->task_sense_data != 0 /
{
	/* TODO: get the client address */
	printf("%-20Y  %-20s ", walltimestamp, "-");
	this->code = args[0]->task_cdb[0]; 
	this->cmd = scsi_cmd[this->code] != NULL ? 
	   scsi_cmd[this->code] : lltostr(this->code); 
	printf("CMD=%s, ", this->cmd);
	this->key_id = (unsigned)args[0]->task_sense_data[2];
	this->asc_id = (unsigned)args[0]->task_sense_data[12];
	this->ascq_id = (unsigned)args[0]->task_sense_data[13];
	this->key = key_code[this->key_id] != NULL ? key_code[this->key_id] : "TBD";
	this->kcq = kcq_code[this->key_id,this->asc_id,this->ascq_id] != NULL ?
		kcq_code[this->key_id,this->asc_id,this->ascq_id] : "TBD";
	printf("Check condition, Key/ASC/ASCQ = %x/%x/%x (%s/%s)\n",
	    this->key_id, this->asc_id, this->ascq_id,this->key, this->kcq);
}
