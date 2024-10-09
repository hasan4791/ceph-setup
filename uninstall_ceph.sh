#!/bin/bash

# THis script cleans up the ceph cluster and wipe out the osd volumes for next use.

# uninstall - from node01
export FSID=$(grep "^fsid" /etc/ceph/ceph.conf | awk {'print $NF'})
export NODENAME=$(grep "^mon initial" /etc/ceph/ceph.conf | awk {'print $NF'})
export NODEIP=$(grep "^mon host" /etc/ceph/ceph.conf | awk {'print $NF'})
for NODE in node01 node02 node03
do
    ssh $NODE  'systemctl stop ceph-osd@0.service'
    ssh $NODE  'systemctl stop ceph-osd@1.service'
    ssh $NODE  'systemctl stop ceph-osd@2.service'
    systemctl stop ceph-mgr@$NODENAME
    systemctl stop ceph-mon@$NODENAME
    systemctl stop ceph-mds@$NODENAME
    sleep 10
    ssh $NODE 'dnf -y remove ceph*'
    ssh $NODE 'rm -rf /etc/ceph; rm -rf /var/lib/ceph ;rm -rf /var/log/ceph'
    ssh $NODE 'dd if=/dev/zero of=/dev/mapper/mpathb bs=10M count=1000'
done
