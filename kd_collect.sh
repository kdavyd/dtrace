#!/usr/bin/bash

zfs create syspool/perflogs
zfs set compression=gzip-9 syspool/perflogs
zfs set mountpoint=/perflogs syspool/perflogs
cd /perflogs
wget https://raw.github.com/kdavyd/dtrace/master/nfsutil.d --no-ch
wget https://raw.github.com/kdavyd/dtrace/master/txg_monitor.v3.d --no-ch
wget https://raw.github.com/kdavyd/dtrace/master/kmem_reap_100ms.d --no-ch
chmod +x *.d
./nfsutil.d >> nfsutil.out &
for i in `zpool list -H -o name`; do
  ./txg_monitor.v3.d $i >> txg.$i.out &
done
./kmem_reap_100ms.d >> kmem.out &
nmc -c "show performance arc" >> arcstat.out &
while true; do date >> arc.out; echo ::arc | mdb -k >> arc.out; sleep 60; done &
echo "The logging is now set up. It will run indefinitely until the system is rebooted."
echo "Please collect logs from the /perflogs/ folder in the root of the appliance."
