#!/usr/sbin/dtrace -s 
#pragma D option quiet

ixgbe_identify_sfp_module_generic:return
/arg1==-19/
{
    printf("%s:%s\n",probefunc,"IXGBE_ERR_SFP_NOT_SUPPORTED")};
}

ixgbe_identify_sfp_module_generic:return
/arg1==-20/
{
    printf("%s:%s\n",probefunc,"IXGBE_ERR_SFP_NOT_PRESENT")};
}

ixgbe_identify_sfp_module_generic:return
/arg1==-21/
{
    printf("%s:%s\n",probefunc,"IXGBE_ERR_SFP_NO_INIT_SEQ_PRESENT")};
}

ixgbe_identify_sfp_module_generic:return
/arg1==0/
{
    printf("%s:%s\n",probefunc,"IXGBE_SUCCESS")};
}
