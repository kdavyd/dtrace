#!/usr/bin/bash
#
# Author: Kirill.Davydychev@Nexenta.com
# Copyright 2013, Nexenta Systems, Inc. 
#

#
# Basic sanity check
#

un="/usr/bin/uname"
nmc_cmd=$(which nmc)
if [[ ! $(${un} -v) =~ NexentaOS ]]; then
        printf "%s\n" "System is not a NexentaStor Appliance. Exiting."
        exit 1
elif [ ! -x "${nmc_cmd}" ]; then
        printf "%s\n" "NMC is not found. Exiting." \
        "This script may not be apporpriate for this system."
        exit 1
fi

#
# Setup the performance logs filesystem, it's fine if we fail - that just means we already have this.
#

zfs create syspool/perflogs
zfs set compression=gzip-9 syspool/perflogs
zfs set mountpoint=/perflogs syspool/perflogs
cd /perflogs

#
# Download necessary scripts
#

wget https://raw.github.com/kdavyd/dtrace/master/nfsutil.d --no-ch
wget https://raw.github.com/kdavyd/dtrace/master/txg_monitor.v3.d --no-ch
wget https://raw.github.com/kdavyd/dtrace/master/kmem_reap_100ms.d --no-ch
wget https://raw.github.com/kdavyd/dtrace/master/zfsio.d --no-ch
wget https://raw.github.com/kdavyd/arcstat/master/arcstat.pl --no-ch
chmod +x *.d
chmod +x arcstat.pl

#
# Start the traces
#

./nfsutil.d >> nfsutil.out &
for i in `zpool list -H -o name`; do
  sleep 1
  ./txg_monitor.v3.d $i >> txg.$i.out &
done
./kmem_reap_100ms.d >> kmem.out &
./arcstat.pl -f time,read,hits,miss,hit%,l2read,l2hits,l2miss,l2hit%,arcsz,l2size 1 >> arcstat.out &
./zfsio.d >> zfsio.out &
zpool iostat -Td 1 >> zpooliostat1.out &
while true; do date >> arc.out; echo ::arc | mdb -k >> arc.out; sleep 60; done &
sleep 5

#
# Finish
#

echo "The logging is now set up. It will run indefinitely until the system is rebooted."
echo "Please collect logs from the /perflogs/ folder in the root of the appliance."

#
# Todo: Error-proof the process, add an exit timer to each trace.
#
