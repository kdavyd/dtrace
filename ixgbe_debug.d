#!/usr/sbin/dtrace -AFs 
#pragma D option quiet

/* This script will enable anonymous tracing of the SFP identification code in ixgbe on boot. 
 * Based on the error code one can tell what exactly the issue is, and whether it's in the SFP. */
 
/* Usage: run "./ixgbe_debug.d", reboot, and collect the contents of the anon buffer with "dtrace -ae". */

/* Author: Kirill.Davydychev@Nexenta.com */
/* Copyright 2014, Nexenta Systems, Inc. All rights reserved. */
/* Version: 0.2 */
/* To get the latest version of this script, 
 * wget https://raw.github.com/kdavyd/dtrace/master/ixgbe_debug.d --no-ch */

string ixgbe_err[uchar_t];

dtrace:::BEGIN
{
 /* Definitions from /usr/src/uts/common/io/ixgbe/ixgbe_type.h */
 /* Generated using awk '{print "ixgbe_err["$3"] = \"" $2"\";"}' */
 
 ixgbe_err[0] = "IXGBE_SUCCESS";
 ixgbe_err[-1] = "IXGBE_ERR_EEPROM";
 ixgbe_err[-2] = "IXGBE_ERR_EEPROM_CHECKSUM";
 ixgbe_err[-3] = "IXGBE_ERR_PHY";
 ixgbe_err[-4] = "IXGBE_ERR_CONFIG";
 ixgbe_err[-5] = "IXGBE_ERR_PARAM";
 ixgbe_err[-6] = "IXGBE_ERR_MAC_TYPE";
 ixgbe_err[-7] = "IXGBE_ERR_UNKNOWN_PHY";
 ixgbe_err[-8] = "IXGBE_ERR_LINK_SETUP";
 ixgbe_err[-9] = "IXGBE_ERR_ADAPTER_STOPPED";
 ixgbe_err[-10] = "IXGBE_ERR_INVALID_MAC_ADDR";
 ixgbe_err[-11] = "IXGBE_ERR_DEVICE_NOT_SUPPORTED";
 ixgbe_err[-12] = "IXGBE_ERR_MASTER_REQUESTS_PENDING";
 ixgbe_err[-13] = "IXGBE_ERR_INVALID_LINK_SETTINGS";
 ixgbe_err[-14] = "IXGBE_ERR_AUTONEG_NOT_COMPLETE";
 ixgbe_err[-15] = "IXGBE_ERR_RESET_FAILED";
 ixgbe_err[-16] = "IXGBE_ERR_SWFW_SYNC";
 ixgbe_err[-17] = "IXGBE_ERR_PHY_ADDR_INVALID";
 ixgbe_err[-18] = "IXGBE_ERR_I2C";
 ixgbe_err[-19] = "IXGBE_ERR_SFP_NOT_SUPPORTED";
 ixgbe_err[-20] = "IXGBE_ERR_SFP_NOT_PRESENT";
 ixgbe_err[-21] = "IXGBE_ERR_SFP_NO_INIT_SEQ_PRESENT";
 ixgbe_err[-22] = "IXGBE_ERR_NO_SAN_ADDR_PTR";
 ixgbe_err[-23] = "IXGBE_ERR_FDIR_REINIT_FAILED";
 ixgbe_err[-24] = "IXGBE_ERR_EEPROM_VERSION";
 ixgbe_err[-25] = "IXGBE_ERR_NO_SPACE";
 ixgbe_err[-26] = "IXGBE_ERR_OVERTEMP";
 ixgbe_err[-27] = "IXGBE_ERR_FC_NOT_NEGOTIATED";
 ixgbe_err[-28] = "IXGBE_ERR_FC_NOT_SUPPORTED";
 ixgbe_err[-30] = "IXGBE_ERR_SFP_SETUP_NOT_COMPLETE";
 ixgbe_err[-31] = "IXGBE_ERR_PBA_SECTION";
 ixgbe_err[-32] = "IXGBE_ERR_INVALID_ARGUMENT";
 ixgbe_err[-33] = "IXGBE_ERR_HOST_INTERFACE_COMMAND";
 ixgbe_err[-34] = "IXGBE_ERR_OUT_OF_MEM";
}

ixgbe_identify_sfp_module_generic:return,
ixgbe_identify_phy_generic:return,
ixgbe_reset_phy_generic:return,
ixgbe_read_phy_reg_generic:return,
ixgbe_write_phy_reg_generic:return,
ixgbe_setup_phy_link_generic:return,
ixgbe_get_copper_link_capabilities_generic:return,
ixgbe_check_phy_link_tnx:return,
ixgbe_setup_phy_link_tnx:return,
ixgbe_get_phy_firmware_version_tnx:return,
ixgbe_get_phy_firmware_version_generic:return,
ixgbe_reset_phy_nl:return,
ixgbe_identify_module_generic:return,
ixgbe_get_sfp_init_sequence_offsets:return,
ixgbe_tn_check_overtemp:return
{
    printf("%s:%s\n",probefunc,ixgbe_err[arg1]);
}

ixgbe_identify_phy_generic:return
/arg1 == -17/
{
    printf("%s: This is normal, the code retries. Ignore and carry on.\n",probefunc);
}
