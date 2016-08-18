#!/usr/sbin/dtrace -qCs

/*
 * Chris.Gerhard@sun.com
 * Joel.Buckley@sun.com
 */

#pragma ident   "@(#)scsi.d	1.18	09/03/20 SMI"

/*
 * SCSI logging via dtrace.
 *
 * See http://blogs.sun.com/chrisg/tags/scsi.d
 *
 * Usage:
 *
 *	scsi.d [ @T time ][ hba [ X ]]
 *
 * With no arguments it logs every scsi packet out and as many returns
 * as it can find.
 *
 * So to trace all the io going via instance 2 qus driver do:
 *
 * scsi.d qus 2
 *
 * To do the same trace for 20 seconds do:
 *
 * scsi.d @T 20 qus 2
 *
 * NOTE: the "@" is used instead of the more traditional "-" as dtrace will
 * continue to parse arguments so would see "-T" as an argument to dtrace and
 * produce a usage error.
 *
 * Temporarily, ie I intend to change this in the future, scsi.d is also
 * taking some more arguments using the -D options as well. I suspect I will
 * get rid of the bizarre @T options above and change to using -D completely
 * but that will be some point in the future, if at all.
 *
 * The new options are:
 *
 *	-D EXECNAME='"foo"'
 * Which results scsi.d only reporting IO associated with the application "foo".
 * 	-D PRINT_STACK
 * Which results in scsi.d printing a kernel stack trace after every outgoing
 * packet.
 *	-D QUIET
 * Which results in none of the packets being printed. Kind of pointless
 * without another option.
 *	-D PERF_REPORT
 * Which results in a report of how long IOs took aggregated per HBA useful
 * with -D QUIET to get performance statistics.
 * -D TARGET_STATS
 *	aggregate the stats based on the target.
 * -D LUN_STATS
 * 	aggregate the stats based on the LUN. Requires TARGET_STATS
 * -D DYNVARSIZE
 *	pass this value to the #pragma D option dynvarsize= option.
 * -D HBA
 *	the name of the HBA we are interested in.
 * -D MIN_LBA
 *	Only report logical blocks over this value
 * -D MAX_LBA
 *	Only IOs to report logical blocks that are less than this value.
 * -D REPORT_OVERTIME=N
 *	Only report IOs that have taken longer than this number of nanoseconds.
 *	This only stops the printing of the packets not the collection of 
 *	statistics.
 *	There are some tuning options that take effect only when
 *	REPORT_OVERTIME is set. These are:
 *	-D NSPEC=N
 *		Set the number of speculations to this value.
 *	-D SPECSIZE=N
 *		Set the size of the speculaton buffer.  This should be 200 *
 *		the size of NSPEC.
 *	-D CLEANRATE=N
 *		Specify the clean rate.
 *
 * Finally scsi.d will also now accept the dtrace -c and -p options to trace
 * just the commands or process given.
 *
 * Since dtrace does not output in real time it is useful to sort the output
 * of the script using sort -n to get the entries in chronological order.
 *
 * NOTE:  This does not directly trace what goes onto the scsi bus or fibre,
 * to do so would require this script have knowledge of every HBA that could
 * ever be connected to a system. It traces the SCSI packets as they are
 * passed from the target driver to the HBA in the SCSA layer and then back
 * again. Although to get the packet when it is returned it guesses that the
 * packet will be destroyed using scsi_destroy_pkt and not modified before it
 * is. So far this has worked but there is no garauntee that it will work for
 * all HBAs and target drivers in the future.
 *
 */

/*
 * This can be used as a framework to report on any rountine that has
 * a scsi_pkt passed into it. Search for "FRAMEWORK" to see where you
 * have to add bits.
 */
#pragma D option quiet
#pragma D option defaultargs

#ifdef DYNVARSIZE
#pragma D option dynvarsize=DYNVARSIZE
#endif

#ifdef REPORT_OVERTIME

#ifdef NSPEC
#pragma D option nspec=NSPEC
#else
#pragma D option nspec=1000
#endif /* NSPEC */


#ifdef SPECSIZE
#pragma D option specsize=SPECSIZE
#else
#pragma D option specsize=200000
#endif /* SPECSIZE */

#ifdef CLEANRATE
#pragma D option cleanrate=CLEANRATE
#endif /* CLEANRATE */

#endif /* REPORT_OVERTIME */

/*
 * Have to include scsi_types.h so that in releases where scsi_address
 * contains a union and #defines for a_target, a_lun & a_sublun they get
 * picked up.
 */
#include <sys/scsi/scsi_types.h>

/*
 * Now work around CR 6798038. Depending on how that CR is fixed this
 * workaround may have to be revisited so that the script will work in
 * all cases.
 */
#ifdef a_lun
#undef a_lun
#define my_alun a.spi.a_lun
#else
#define my_alun a_lun
#endif

#ifdef a_target
#undef a_target
#define my_atarget a.spi.a_target
#else
#define my_atarget a_target
#endif

/*
 * Just for completeness. The script does not use sublun so these are not
 * needed but do no harm.
 */
#ifdef a_sublun
#undef a_sublun
#define my_asublun  a.spi.a_sublun
#else
#define my_asublun a_sublun
#endif

/*
 * Set both lba & len to 64Bit values, to avoid type mismatch later...
 *
 * The following does not function due to DTrace insufficient registers...
 *
 *  #define INT64(A, B, C, D, E, F, G, H) ( \
 *	(((A) & 0x0ffL) << 56) | \
 *	(((B) & 0x0ffL) << 48) | \
 *	(((C) & 0x0ffL) << 40) | \
 *	(((D) & 0x0ffL) << 32) | \
 *	(((E) & 0x0ffL) << 24) | \
 *	(((F) & 0x0ffL) << 16) | \
 *	(((G) & 0x0ffL) <<  8) | \
 *	((H) & 0x0ffL))
 *
 * Instead, calculate lower & upper values, then pass them into this macro:
 */
#define	INT64(A, B) ( \
	(((A) & 0x0ffffffffLL) << 32) | \
	((B) & 0x0ffffffffL))

#define	INT32(A, B, C, D) ( \
	(((A) & 0x0ffL) << 24) | \
	(((B) & 0x0ffL) << 16) | \
	(((C) & 0x0ffL) <<  8) | \
	((D) & 0x0ffL))
#define	INT16(A, B) ( \
	(((A) & 0x0ffL) <<  8) | \
	((B) & 0x0ffL))
#define	INT8(A) ( \
	((A) & 0x0ffL))

/* #define	A_TO_TRAN(ap)	((ap)->a_hba_tran) */
#define	P_TO_TRAN(pkt)	((pkt)->pkt_address.a_hba_tran)
/* #define	P_TO_ADDR(pkt)	(&((pkt)->pkt_address)) */
#define	P_TO_DEVINFO(pkt) ((struct dev_info *)(P_TO_TRAN(pkt)->tran_hba_dip))

#define	DEV_NAME(pkt) \
	stringof(`devnamesp[P_TO_DEVINFO(pkt)->devi_major].dn_name) /* ` */

#define	DEV_INST(pkt) (P_TO_DEVINFO(pkt)->devi_instance)

#ifdef MIN_BLOCK
#define MIN_TEST && this->lba >= (MIN_BLOCK) 
#else
#define MIN_TEST
#endif
#ifdef MAX_BLOCK
#define MAX_TEST && (this->lba <= ((MAX_BLOCK) + this->len))
#else
#define MAX_TEST
#endif

#define	ARGUMENT_TEST (this->pkt && (hba_set == 0 || \
	hba == DEV_NAME(this->pkt) && \
	(inst_set == 0 || inst == DEV_INST(this->pkt))) MIN_TEST MAX_TEST)

/*
 * PRINT_DEV_FROM_PKT
 *
 * From a scsi_pkt get the name of the driver and the instance of the
 * hba.
 */
#define	PRINT_DEV_FROM_PKT(pkt) \
	printf("%s%d:", DEV_NAME(pkt), DEV_INST(pkt))

#define	PRINT_TIMESTAMP() printf("%5.5d.%9.9d ", \
	(timestamp - script_start_time)/1000000000, \
	(timestamp - script_start_time)%1000000000);

/*
 * Look away now.
 *
 * This is just hackery to get around me being so stubborn I
 * don't want to wrap this in a shell script.
 */
#ifdef HBA
BEGIN {
	hba = HBA;
	hba_set = 1;
	timeout = 0;
	inst_set = 0;
	inst = 0;
}
#else

#define	TIMEOUT_SELECT "@T"

#define	DO_ARGS(N, NS, M, MS) \
BEGIN \
/ hba_set == 0 && NS != "" && NS != TIMEOUT_SELECT / \
{ \
	hba = NS; \
	hba_set = 1; \
} \
BEGIN \
/ hba_set == 1 && inst_set == 0 && MS != "" / \
{ \
	inst = M; \
	inst_set = 1; \
} \

BEGIN
/ $$1 == TIMEOUT_SELECT /
{
	timeout = $2;
}

#endif

BEGIN 
/ $$target != "" /
{
	target = $target;
}

BEGIN
{
#ifdef EXECNAME
	scsi_d_target_execname = EXECNAME;
#else
	scsi_d_target_execname = "";
#endif
}
#ifndef HBA
DO_ARGS($1, $$1, $2, $$2)
DO_ARGS($3, $$3, $4, $$4)
#endif

/*
 * You can open your eyes again now.
 */

BEGIN {
#ifdef REPORT_OVERTIME
	printf("Only reporting IOs longer than %dns\n", REPORT_OVERTIME);
#endif
	printf("Hit Control C to interrupt\n");
	script_start_time = timestamp;
	end_time = timestamp + (timeout * 1000000000);

	scsi_ops[0x000, 0x0] = "TEST_UNIT_READY";
	scsi_ops[0x001, 0x0] = "REZERO_UNIT_or_REWIND";
	scsi_ops[0x003, 0x0] = "REQUEST_SENSE";
	scsi_ops[0x004, 0x0] = "FORMAT_UNIT";
	scsi_ops[0x005, 0x0] = "READ_BLOCK_LIMITS";
	scsi_ops[0x006, 0x0] = "Unknown(06)";
	scsi_ops[0x007, 0x0] = "REASSIGN_BLOCKS";
	scsi_ops[0x008, 0x0] = "READ(6)";
	scsi_ops[0x009, 0x0] = "Unknown(09)";
	scsi_ops[0x00a, 0x0] = "WRITE(6)";
	scsi_ops[0x00b, 0x0] = "SEEK(6)";
	scsi_ops[0x00c, 0x0] = "Unknown(0c)";
	scsi_ops[0x00d, 0x0] = "Unknown(0d)";
	scsi_ops[0x00e, 0x0] = "Unknown(0e)";
	scsi_ops[0x00f, 0x0] = "READ_REVERSE";
	scsi_ops[0x010, 0x0] = "WRITE_FILEMARK";
	scsi_ops[0x011, 0x0] = "SPACE";
	scsi_ops[0x012, 0x0] = "INQUIRY";
	scsi_ops[0x013, 0x0] = "VERIFY";
	scsi_ops[0x014, 0x0] = "Unknown(14)";
	scsi_ops[0x015, 0x0] = "MODE_SELECT(6)";
	scsi_ops[0x016, 0x0] = "RESERVE(6)";
	scsi_ops[0x017, 0x0] = "RELEASE(6)";
	scsi_ops[0x018, 0x0] = "COPY";
	scsi_ops[0x019, 0x0] = "ERASE(6)";
	scsi_ops[0x01a, 0x0] = "MODE_SENSE(6)";
	scsi_ops[0x01b, 0x0] = "START_STOP_UNIT";
	scsi_ops[0x01c, 0x0] = "RECIEVE_DIAGNOSTIC_RESULTS";
	scsi_ops[0x01d, 0x0] = "SEND_DIAGNOSTIC";
	scsi_ops[0x01e, 0x0] = "PREVENT_ALLOW_MEDIUM_REMOVAL";
	scsi_ops[0x01f, 0x0] = "Unknown(1f)";
	scsi_ops[0x020, 0x0] = "Unknown(20)";
	scsi_ops[0x021, 0x0] = "Unknown(21)";
	scsi_ops[0x022, 0x0] = "Unknown(22)";
	scsi_ops[0x023, 0x0] = "READ_FORMAT_CAPACITY";
	scsi_ops[0x024, 0x0] = "Unknown(24)";
	scsi_ops[0x025, 0x0] = "READ_CAPACITY(10)";
	scsi_ops[0x026, 0x0] = "Unknown(26)";
	scsi_ops[0x027, 0x0] = "Unknown(27)";
	scsi_ops[0x028, 0x0] = "READ(10)";
	scsi_ops[0x02a, 0x0] = "WRITE(10)";
	scsi_ops[0x02b, 0x0] = "SEEK(10)_or_LOCATE(10)";
	scsi_ops[0x02e, 0x0] = "WRITE_AND_VERIFY(10)";
	scsi_ops[0x02f, 0x0] = "VERIFY(10)";
	scsi_ops[0x030, 0x0] = "SEARCH_DATA_HIGH";
	scsi_ops[0x031, 0x0] = "SEARCH_DATA_EQUAL";
	scsi_ops[0x032, 0x0] = "SEARCH_DATA_LOW";
	scsi_ops[0x033, 0x0] = "SET_LIMITS(10)";
	scsi_ops[0x034, 0x0] = "PRE-FETCH(10)";
	scsi_ops[0x035, 0x0] = "SYNCHRONIZE_CACHE(10)";
	scsi_ops[0x036, 0x0] = "LOCK_UNLOCK_CACHE(10)";
	scsi_ops[0x037, 0x0] = "READ_DEFECT_DATA(10)";
	scsi_ops[0x039, 0x0] = "COMPARE";
	scsi_ops[0x03a, 0x0] = "COPY_AND_WRITE";
	scsi_ops[0x03b, 0x0] = "WRITE_BUFFER";
	scsi_ops[0x03c, 0x0] = "READ_BUFFER";
	scsi_ops[0x03e, 0x0] = "READ_LONG";
	scsi_ops[0x03f, 0x0] = "WRITE_LONG";
	scsi_ops[0x040, 0x0] = "CHANGE_DEFINITION";
	scsi_ops[0x041, 0x0] = "WRITE_SAME(10)";
	scsi_ops[0x04c, 0x0] = "LOG_SELECT";
	scsi_ops[0x04d, 0x0] = "LOG_SENSE";
	scsi_ops[0x050, 0x0] = "XDWRITE(10)";
	scsi_ops[0x051, 0x0] = "XPWRITE(10)";
	scsi_ops[0x052, 0x0] = "XDREAD(10)";
	scsi_ops[0x053, 0x0] = "XDWRITEREAD(10)";
	scsi_ops[0x055, 0x0] = "MODE_SELECT(10)";
	scsi_ops[0x056, 0x0] = "RESERVE(10)";
	scsi_ops[0x057, 0x0] = "RELEASE(10)";
	scsi_ops[0x05a, 0x0] = "MODE_SENSE(10)";
	scsi_ops[0x05e, 0x0] = "PERSISTENT_RESERVE_IN";
	scsi_ops[0x05f, 0x0] = "PERSISTENT_RESERVE_OUT";
	scsi_ops[0x07f, 0x0] = "Variable_Length_CDB";
	scsi_ops[0x07f, 0x3] = "XDREAD(32)";
	scsi_ops[0x07f, 0x4] = "XDWRITE(32)";
	scsi_ops[0x07f, 0x6] = "XPWRITE(32)";
	scsi_ops[0x07f, 0x7] = "XDWRITEREAD(32)";
	scsi_ops[0x07f, 0x9] = "READ(32)";
	scsi_ops[0x07f, 0xb] = "WRITE(32)";
	scsi_ops[0x07f, 0xa] = "VERIFY(32)";
	scsi_ops[0x07f, 0xc] = "WRITE_AND_VERIFY(32)";
	scsi_ops[0x080, 0x0] = "XDWRITE_EXTENDED(16)";
	scsi_ops[0x081, 0x0] = "REBUILD(16)";
	scsi_ops[0x082, 0x0] = "REGENERATE(16)";
	scsi_ops[0x083, 0x0] = "EXTENDED_COPY";
	scsi_ops[0x086, 0x0] = "ACCESS_CONTROL_IN";
	scsi_ops[0x087, 0x0] = "ACCESS_CONTROL_OUT";
	scsi_ops[0x088, 0x0] = "READ(16)";
	scsi_ops[0x08a, 0x0] = "WRITE(16)";
	scsi_ops[0x08c, 0x0] = "READ_ATTRIBUTES";
	scsi_ops[0x08d, 0x0] = "WRITE_ATTRIBUTES";
	scsi_ops[0x08e, 0x0] = "WRITE_AND_VERIFY(16)";
	scsi_ops[0x08f, 0x0] = "VERIFY(16)";
	scsi_ops[0x090, 0x0] = "PRE-FETCH(16)";
	scsi_ops[0x091, 0x0] = "SYNCHRONIZE_CACHE(16)";
	scsi_ops[0x092, 0x0] = "LOCK_UNLOCK_CACHE(16)_or_LOCATE(16)";
	scsi_ops[0x093, 0x0] = "WRITE_SAME(16)_or_ERASE(16)";
	scsi_ops[0x09e, 0x0] = "SERVICE_IN_or_READ_CAPACITY(16)";
	scsi_ops[0x0a0, 0x0] = "REPORT_LUNS";
	scsi_ops[0x0a3, 0x0] = "MAINTENANCE_IN_or_REPORT_TARGET_PORT_GROUPS";
	scsi_ops[0x0a4, 0x0] = "MAINTENANCE_OUT_or_SET_TARGET_PORT_GROUPS";
	scsi_ops[0x0a7, 0x0] = "MOVE_MEDIUM";
	scsi_ops[0x0a8, 0x0] = "READ(12)";
	scsi_ops[0x0aa, 0x0] = "WRITE(12)";
	scsi_ops[0x0ae, 0x0] = "WRITE_AND_VERIFY(12)";
	scsi_ops[0x0af, 0x0] = "VERIFY(12)";
	scsi_ops[0x0b3, 0x0] = "SET_LIMITS(12)";
	scsi_ops[0x0b4, 0x0] = "READ_ELEMENT_STATUS";
	scsi_ops[0x0b7, 0x0] = "READ_DEFECT_DATA(12)";
	scsi_ops[0x0ba, 0x0] = "REDUNDANCY_GROUP_IN";
	scsi_ops[0x0bb, 0x0] = "REDUNDANCY_GROUP_OUT";
	scsi_ops[0x0bc, 0x0] = "SPARE_IN";
	scsi_ops[0x0bd, 0x0] = "SPARE_OUT";
	scsi_ops[0x0be, 0x0] = "VOLUME_SET_IN";
	scsi_ops[0x0bf, 0x0] = "VOLUME_SET_OUT";
	scsi_ops[0x0d0, 0x0] = "EXPLICIT_LUN_FAILOVER";
	scsi_ops[0x0f1, 0x0] = "STOREDGE_CONTROLLER";

	scsi_reasons[0] = "COMPLETED";
	scsi_reasons[1] = "INCOMPLETE";
	scsi_reasons[2] = "DMA_ERR";
	scsi_reasons[3] = "TRAN_ERR";
	scsi_reasons[4] = "RESET";
	scsi_reasons[5] = "ABORTED";
	scsi_reasons[6] = "TIMEOUT";
	scsi_reasons[7] = "DATA_OVERRUN";
	scsi_reasons[8] = "COMMAND_OVERRUN";
	scsi_reasons[9] = "STATUS_OVERRUN";
	scsi_reasons[10] = "Bad_Message";
	scsi_reasons[11] = "No_Message_Out";
	scsi_reasons[12] = "XID_Failed";
	scsi_reasons[13] = "IDE_Failed";
	scsi_reasons[14] = "Abort_Failed";
	scsi_reasons[15] = "Reject_Failed";
	scsi_reasons[16] = "Nop_Failed";
	scsi_reasons[17] = "Message_Parity_Error_Failed";
	scsi_reasons[18] = "Bus_Device_Reset_Failed";
	scsi_reasons[19] = "Identify_Message_Rejected";
	scsi_reasons[20] = "Unexpected_Bus_free";
	scsi_reasons[21] = "Tag_Rejected";
	scsi_reasons[22] = "TERMINATED";
	scsi_reasons[24] = "Device_Gone";

	scsi_state[0] = "Success";
	scsi_state[0x2] = "Check_Condition";
	scsi_state[0x4] = "Condition_Met";
	scsi_state[0x8] = "Busy";
	scsi_state[0x10] = "Intermidiate";
	scsi_state[0x14] = "Intermidiate-Condition_Met";
	scsi_state[0x18] = "Reservation_Conflict";
	scsi_state[0x22] = "Command_Terminated";
	scsi_state[0x28] = "Queue_Full";
	scsi_state[0x30] = "ACA_Active";


/* FRAMEWORK:- add your special string to this array */
	names[0] = "->"; /* Command sent */
	names[1] = "<-"; /* Command returning */
	names[2] = "ILL"; /* Illegal Request spotted */
}

fbt:scsi:scsi_transport:entry,
fbt:scsi:scsi_destroy_pkt:entry
/ timeout != 0 && end_time < timestamp /
{
	exit(0);
}

/*
 * relying on scsi_destroy_pkt to get the response is a
 * hack that may or may not always work depending on HBA
 * and target drivers.
 * With arc case: PSARC/2009/033 I can use scsi_hba_pkt_comp(). When that
 * is out in the wild it should be used.
 */
/*
 * If in any of these probes this->pkt is initialized to zero 
 * the knock on effect is none of the other probes for this clause further 
 * down get run.
 *
 * Do not just comment the probes out. Clause local variables are not
 * initialized by default so you will see run time dtrace errors if you do
 * where other variables do not get set.
 */

#define PROBE_SWITCH \
	((target == 0 || pid == target ) && \
	   (scsi_d_target_execname == "" || scsi_d_target_execname == execname))

fbt:scsi:scsi_transport:entry
/ !PROBE_SWITCH /
{
	this->pkt = (struct scsi_pkt *)0;
}
fbt:scsi:scsi_transport:entry
/ PROBE_SWITCH /
{
	this->pkt = (struct scsi_pkt *)arg0;
}

fbt:scsi:scsi_destroy_pkt:entry
{
	this->pkt = (struct scsi_pkt *)arg0;
}

/*
 * FRAMEWORK:- create your entry probe and make this->pkt point to the
 * argument that has the scsi_pkt. eg add one like this:
 * 
 */
fbt:*sd:*sd_sense_key_illegal_request:entry
/ !PROBE_SWITCH /
{
	this->pkt = (struct scsi_pkt *)0;
}
fbt:*sd:*sd_sense_key_illegal_request:entry
/ PROBE_SWITCH /
{
	this->pkt = (struct scsi_pkt *)arg3;
}

/* FRAMEWORK:- Add your probe name to the list for CDB_PROBES */
#define CDB_PROBES \
fbt:scsi:scsi_transport:entry, \
fbt:*sd:*sd_sense_key_illegal_request:entry

#define ENTRY_PROBES \
CDB_PROBES, \
fbt:scsi:scsi_destroy_pkt:entry

ENTRY_PROBES
/ this->pkt /
{
	this->cdb = (uchar_t *)this->pkt->pkt_cdbp;
	this->scb = (uchar_t *)this->pkt->pkt_scbp;
	this->group = ((this->cdb[0] & 0xe0) >> 5);
	this->lbalen = 0;
}
/*
 * 5.11 allows this->name = "->" but vanilla 5.10 does not so I'm sticking
 * to the setting a variable and then choosing the string from the global
 * array.
 */
fbt:scsi:scsi_transport:entry
/ this->pkt /
{
	start_time[this->scb] = timestamp;
	this->name = 0;
}

/*
 * If we are filtering on target pid or execname then only report
 * the return packets that we know we sent.
 */
fbt:scsi:scsi_destroy_pkt:entry
/ start_time[this->scb] == 0 && ( target != 0 || scsi_d_target_execname != "") /
{
	this->pkt = 0;
}

fbt:scsi:scsi_destroy_pkt:entry
/ this->pkt /
{
	this->name = 1;
}
/*
 * FRAMEWORK: Add your probe and set this->name to the offset of
 * your string in the names table.
 */
fbt:*sd:*sd_sense_key_illegal_request:entry
/ this->pkt /
{
	this->name = 2;
}

/*
 * Now cope with the differnent CDB layouts based on the group.
 *
 * Trying to use x = this->group == 0 ? y : z; results in D running out
 * of registers so it is all done using seperate probes.
 *
 * Group Listing:
 *	+ Group 0: 6Byte CDBs: scsi_ops[0x000] thru scsi_ops[0x01f]
 *	+ Group 1: 10Byte CDBs: scsi_ops[0x020] thru scsi_ops[0x03f]
 *	+ Group 2: 10Byte CDBs: scsi_ops[0x040] thru scsi_ops[0x05f]
 *	+ Group 3: Variable Length CDBs: scsi_ops[0x060] thru scsi_ops[0x07f]
 *	+ Group 4: 16Byte CDBs: scsi_ops[0x080] thru scsi_ops[0x09f]
 *	+ Group 5: 12Byte CDBs: scsi_ops[0x0a0] thru scsi_ops[0x0bf]
 *	  Group 6: Vendor Specific CDBs: scsi_ops[0x0c0] thru scsi_ops[0x0df]
 *	  Group 7: Vendor Specific CDBs: scsi_ops[0x0e0] thru scsi_ops[0x0ff]
 *
 * The groups with a leading plus sign "+" are of importance.
 */
ENTRY_PROBES
/ this->pkt && this->group == 0 /
{
	this->lba = INT32(0, (this->cdb[1] & 0x1f),
		this->cdb[2], this->cdb[3]);
	this->lbalen = 6;
	this->len = INT8(this->cdb[4]);
	this->control = this->cdb[5];
	this->sa = 0;
	this->cdblen = 6;
}

ENTRY_PROBES
/ this->pkt && this->group == 1 /
{
	this->lba = INT32(this->cdb[2], this->cdb[3],
		this->cdb[4], this->cdb[5]);
	this->lbalen = 8;
	this->len = INT16(this->cdb[7], this->cdb[8]);
	this->control = this->cdb[9];
	this->sa = 0;
	this->cdblen = 10;
}

ENTRY_PROBES
/ this->pkt && this->group == 2 /
{
	this->lba = INT32(this->cdb[2], this->cdb[3],
		this->cdb[4], this->cdb[5]);
	this->lbalen = 8;
	this->len = INT16(this->cdb[7], this->cdb[8]);
	this->control = this->cdb[9];
	this->sa = 0;
	this->cdblen = 10;
}

ENTRY_PROBES
/ this->pkt && this->group == 3 /
{
	/*
	 * This is to get around insufficient DTrace Registers...
	 *
	 * Instead of doing this in a single step like:
	 *
	 *   this->lba = INT64(\
	 *	this->cdb[2], this->cdb[3], this->cdb[4], this->cdb[5], \
	 *	this->cdb[6], this->cdb[7], this->cdb[8], this->cdb[9]);
	 *
	 * The int64 LBA value must be calculated in 5 steps...
	 */
	this->lbaUpper = INT32(this->cdb[12], this->cdb[13],
		this->cdb[14], this->cdb[15]);
	this->lbaLower = INT32(this->cdb[16], this->cdb[17],
		this->cdb[18], this->cdb[19]);
	this->lba = INT64(this->lbaUpper, this->lbaLower);
	this->lbaUpper = 0;
	this->lbaLower = 0;

	this->lbalen = 16;
	this->len = INT32(this->cdb[28], this->cdb[29],
		this->cdb[30], this->cdb[31]);
	this->control = this->cdb[1];
	this->sa = INT16(this->cdb[8], this->cdb[9]);
	this->cdblen = 32
}

ENTRY_PROBES
/ this->pkt && this->group == 4 /
{
	/*
	 * This is to get around insufficient DTrace Registers...
	 *
	 * Instead of doing this in a single step like:
	 *
	 *   this->lba = INT64(\
	 *	this->cdb[2], this->cdb[3], this->cdb[4], this->cdb[5], \
	 *	this->cdb[6], this->cdb[7], this->cdb[8], this->cdb[9]);
	 *
	 * The int64 LBA value must be calculated in 5 steps...
	 */
	this->lbaUpper = INT32(this->cdb[2], this->cdb[3],
		this->cdb[4], this->cdb[5]);
	this->lbaLower = INT32(this->cdb[6], this->cdb[7],
		this->cdb[8], this->cdb[9]);
	this->lba = INT64(this->lbaUpper, this->lbaLower);
	this->lbaUpper = 0;
	this->lbaLower = 0;

	this->lbalen = 16;
	this->len = INT32(this->cdb[10], this->cdb[11],
		this->cdb[12], this->cdb[13]);
	this->control = this->cdb[15];
	this->sa = 0;
	this->cdblen = 16;
}

ENTRY_PROBES
/ this->pkt && this->group == 5 /
{
	this->lba = INT32(this->cdb[2], this->cdb[3],
		this->cdb[4], this->cdb[5]);
	this->lbalen = 8;
	this->len = INT32(this->cdb[6], this->cdb[7],
		this->cdb[8], this->cdb[9]);
	this->control = this->cdb[11];
	this->sa = 0;
	this->cdblen = 12;
}
/*
 * We don't know the format of the  group 6 and 7 commands as they are
 * vendor specific. So I just print the cdb up to a maximum of 32 bytes.
 */
ENTRY_PROBES
/ this->pkt && this->group > 5 /
{
	this->lba = 0;
	this->lbalen = 0;
	this->len = 0;
	this->control = 0;
	this->sa = 0;
/*
 * At some point pkt_cdblen will make it into 5.10 but I can't at this moment
 * workout how I can test this before the script compiles (without wrapping
 * this in a ksh script which as I have mentioned above I'm not going to do).
 */
#ifndef __SunOS_5_10
	this->cdblen = this->pkt->pkt_cdblen;
#else
        this->cdblen = 32;
#endif

}

/*
 * The guts of the script. Report what we have if we are required.
 * First the stuff we do for both outgoing and incoming.
 */

ENTRY_PROBES
/ !ARGUMENT_TEST /
{
	this->arg_test_passed = 0;
}

ENTRY_PROBES
/ ARGUMENT_TEST /
{
	this->arg_test_passed = 1;
}

/*
 * If only reporting IO that takes more then a certan time then use
 * speculations to capture the outgoing data and then only commit the
 * speculation if the packet takes too long.
 */

#ifdef REPORT_OVERTIME 

#define SPECULATE speculate(specs[this->scb]);

ENTRY_PROBES
/ this->arg_test_passed  && specs[this->scb] == 0 /
{
	specs[this->scb] = speculation();
}

#else

#define SPECULATE

#endif /* REPORT_OVERTIME */

#ifndef QUIET
ENTRY_PROBES
/ this->arg_test_passed /
{
	SPECULATE
	PRINT_TIMESTAMP();
	PRINT_DEV_FROM_PKT(this->pkt);
	printf("%s 0x%2.2x %9s address %2.2d:%2.2d, lba 0x%*.*x, ",
	    names[this->name],
	    this->cdb[0],
	    scsi_ops[(uint_t)this->cdb[0], this->sa] != 0 ?
		    scsi_ops[(uint_t)this->cdb[0], this->sa] : "Unknown",
	    this->pkt->pkt_address.my_atarget,
	    this->pkt->pkt_address.my_alun,
	    this->lbalen, this->lbalen,
	    this->lba);
	printf("len 0x%6.6x, control 0x%2.2x timeout %d CDBP %p",
	    this->len, this->control,
	    this->pkt->pkt_time, this->cdb);
}

CDB_PROBES
/ this->arg_test_passed == 1 /
{
	SPECULATE
	printf(" %d %s(%d)", this->arg_test_passed, execname, pid);
}

/*
 * For those who are just not happy without some raw hex numbers. Print the
 * raw cdb.
 */
CDB_PROBES
/ this->arg_test_passed == 1 && this->cdblen /
{
	SPECULATE
	printf(" cdb(%d) ", this->cdblen);
}

/*
 * Now print each byte out of the cdb.
 */

#define	PRINT_CDB(N) \
CDB_PROBES \
/ this->arg_test_passed == 1 && this->cdblen > N/ \
{ \
	SPECULATE; \
	printf("%2.2x", this->cdb[N]) \
}
#else /* QUIET */
#define	PRINT_CDB(N)
#endif /* QUIET */

PRINT_CDB(0)
PRINT_CDB(1)
PRINT_CDB(2)
PRINT_CDB(3)
PRINT_CDB(4)
PRINT_CDB(5)
PRINT_CDB(6)
PRINT_CDB(7)
PRINT_CDB(8)
PRINT_CDB(9)
PRINT_CDB(10)
PRINT_CDB(11)
PRINT_CDB(12)
PRINT_CDB(13)
PRINT_CDB(14)
PRINT_CDB(15)
PRINT_CDB(16)
PRINT_CDB(17)
PRINT_CDB(18)
PRINT_CDB(19)
PRINT_CDB(20)
PRINT_CDB(21)
PRINT_CDB(22)
PRINT_CDB(23)
PRINT_CDB(24)
PRINT_CDB(25)
PRINT_CDB(26)
PRINT_CDB(27)
PRINT_CDB(28)
PRINT_CDB(29)
PRINT_CDB(30)
PRINT_CDB(31)

/*
 * Now the result on the incoming.
 */
#ifdef PERF_REPORT
fbt:scsi:scsi_destroy_pkt:entry
/ this->arg_test_passed == 1 && start_time[this->scb] != 0 /
{
	@[DEV_NAME(this->pkt), DEV_INST(this->pkt)
#ifdef TARGET_STATS
	    , this->pkt->pkt_address.a_target
#ifdef LUN_STATS
	    , this->pkt->pkt_address.a_lun
#endif
#endif
	    ] = quantize(timestamp - start_time[this->scb]);
}
#endif

fbt:scsi:scsi_destroy_pkt:entry
/ this->arg_test_passed == 1 /
{
	this->state = *(this->scb);
	this->state = this->state & 0x3E;
}
#ifndef QUIET
fbt:scsi:scsi_destroy_pkt:entry
/ this->arg_test_passed == 1 /
{
	SPECULATE
	printf(", reason 0x%x (%s) pkt_state 0x%x state 0x%x %s Time %dus\n",
	    this->pkt->pkt_reason,
	    scsi_reasons[this->pkt->pkt_reason] != 0 ?
		    scsi_reasons[this->pkt->pkt_reason] : "Unknown",
	    this->pkt->pkt_state, this->state, scsi_state[this->state] != 0 ?
		scsi_state[this->state]  : "Unknown",
	    start_time[this->scb] != 0 ?
		    (timestamp - start_time[this->scb])/1000 : 0);
}
#endif

#ifndef QUIET
CDB_PROBES
/ this->arg_test_passed == 1 /
{
	SPECULATE
	printf("\n");
}
#endif
/*
 * printing stacks of where we are called from can be useful however it
 * does mean you can't just pipe the output through sort(1). Does not work
 * with overtime as you can't put a stack into a speculation.
 */
#ifdef PRINT_STACK
CDB_PROBES
/ this->arg_test_passed == 1 /
{
	stack(10);
}
#endif

#ifdef REPORT_OVERTIME
fbt:scsi:scsi_destroy_pkt:entry
/ this->arg_test_passed == 1 &&
((timestamp - start_time[this->scb]) > REPORT_OVERTIME && start_time[this->scb]) /
{
	SPECULATE
	commit(specs[this->scb]);
	specs[this->scb] = 0;
}
fbt:scsi:scsi_destroy_pkt:entry
/ this->arg_test_passed == 1 &&
! ((timestamp - start_time[this->scb]) > REPORT_OVERTIME) /
{
	discard(specs[this->scb]);
	specs[this->scb] = 0;
}
#endif

fbt:scsi:scsi_destroy_pkt:entry
/ this->arg_test_passed == 1  /
{
	start_time[this->scb] = 0;
}

