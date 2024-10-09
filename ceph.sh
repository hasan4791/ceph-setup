#!/bin/bash
DOMAIN=$(cat nodes.info | grep domain  | awk 'BEGIN{FS="="}{print $2}')
IPS=$(cat nodes.info | grep nodes  | awk 'BEGIN{FS="="}{print $2}')
CLIENT=$(cat nodes.info | grep client  | awk 'BEGIN{FS="="}{print $2}')
CEPH_REPO=$(cat nodes.info | grep ceph_repo  | awk 'BEGIN{FS="="}{print $2}')
num=1
for ip in $IPS
do
    echo "$ip node0$num node0$num.$DOMAIN" >>  /etc/hosts
    num=$(( $num + 1 ))
done
echo "$CLIENT dlp dlp.$DOMAIN" >>  /etc/hosts

echo "passw0rd" > /root/password.txt
for NODE in node01 node02 node03 dlp
do
    sshpass -f /root/password.txt  ssh -o StrictHostKeyChecking=no $NODE 'ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa '
    sshpass -f /root/password.txt  ssh -o StrictHostKeyChecking=no $NODE "hostnamectl hostname  $NODE"
done

for NODE in node01 node02 node03 dlp
do
    sshpass -f /root/password.txt ssh -o StrictHostKeyChecking=no $NODE 'sshpass -f /root/password.txt  ssh-copy-id node01'
    sshpass -f /root/password.txt ssh -o StrictHostKeyChecking=no $NODE 'sshpass -f /root/password.txt  ssh-copy-id node02'
    sshpass -f /root/password.txt ssh -o StrictHostKeyChecking=no $NODE 'sshpass -f /root/password.txt  ssh-copy-id node03'
    sshpass -f /root/password.txt ssh -o StrictHostKeyChecking=no $NODE 'sshpass -f /root/password.txt  ssh-copy-id dlp'
done


cat << EOF > ~/.ssh/config
Host node01
    Hostname node01.$DOMAIN
    User root
Host node02
    Hostname node02.$DOMAIN
    User root
Host node03
    Hostname node03.$DOMAIN
    User root
EOF

chmod 600 ~/.ssh/config

for NODE in node01 node02 node03 dlp
do
    ssh $NODE  'dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm '
done

cat << EOF > /etc/yum.repos.d/ceph.repo
[ceph]
baseurl=$CEPH_REPO
enabled=1
gpgcheck=0
countme=1
EOF
for NODE in node01 node02 node03 dlp
do
    scp /etc/yum.repos.d/ceph.repo root@$NODE:/etc/yum.repos.d/ceph.repo
done


for NODE in node01 node02 node03 dlp
do
    ssh $NODE "dnf -y install ceph"
done

#for NODE in node01 node02 node03
#do
#    ssh $NODE "firewall-cmd --add-service=ceph; firewall-cmd --runtime-to-permanent"
#done

cat << EOF > /etc/ceph/ceph.conf
[global]
# specify cluster network for monitoring
cluster network = $(ip route | awk '{print $1}'| tail -n 1)
# specify public network
public network = $(ip route | awk '{print $1}'| tail -n 1)
# specify UUID genarated above
fsid = $(uuidgen)
# specify IP address of Monitor Daemon
mon host = $(hostname -i)
# specify Hostname of Monitor Daemon
mon initial members = node01
osd pool default crush rule = -1

# mon.(Node name)
[mon.node01]
# specify Hostname of Monitor Daemon
host = node01
# specify IP address of Monitor Daemon
mon addr = $(hostname -i)
# allow to delete pools
mon allow pool delete = true
EOF
sync
ceph-authtool --create-keyring /etc/ceph/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'

ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring

export FSID=$(grep "^fsid" /etc/ceph/ceph.conf | awk {'print $NF'})
export NODENAME=$(grep "^mon initial" /etc/ceph/ceph.conf | awk {'print $NF'})
export NODEIP=$(grep "^mon host" /etc/ceph/ceph.conf | awk {'print $NF'})

monmaptool --create --add $NODENAME $NODEIP --fsid $FSID /etc/ceph/monmap
mkdir /var/lib/ceph/mon/ceph-node01

ceph-mon --cluster ceph --mkfs -i $NODENAME --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.keyring

chown ceph:ceph /etc/ceph/ceph.*
chown -R ceph:ceph /var/lib/ceph/mon/ceph-node01 /var/lib/ceph/bootstrap-osd
systemctl enable --now ceph-mon@$NODENAME
ceph mon enable-msgr2
ceph config set mon auth_allow_insecure_global_id_reclaim false

ceph mgr module enable pg_autoscaler

mkdir /var/lib/ceph/mgr/ceph-node01

ceph auth get-or-create mgr.$NODENAME mon 'allow profile mgr' osd 'allow *' mds 'allow *'

ceph auth get-or-create mgr.node01 > /etc/ceph/ceph.mgr.admin.keyring

cp /etc/ceph/ceph.mgr.admin.keyring /var/lib/ceph/mgr/ceph-node01/keyring

chown ceph:ceph /etc/ceph/ceph.mgr.admin.keyring

chown -R ceph:ceph /var/lib/ceph/mgr/ceph-node01

systemctl enable --now ceph-mgr@$NODENAME

#if selinux is enabled, run below
cat << EOF > cephmon.te
# create new
module cephmon 1.0;

require {
        type ceph_t;
        type ptmx_t;
        type initrc_var_run_t;
        type sudo_exec_t;
        type chkpwd_exec_t;
        type shadow_t;
        class file { execute execute_no_trans lock getattr map open read };
        class capability { audit_write sys_resource };
        class process setrlimit;
        class netlink_audit_socket { create nlmsg_relay };
        class chr_file getattr;
}

#============= ceph_t ==============
allow ceph_t initrc_var_run_t:file { lock open read };
allow ceph_t self:capability { audit_write sys_resource };
allow ceph_t self:netlink_audit_socket { create nlmsg_relay };
allow ceph_t self:process setrlimit;
allow ceph_t sudo_exec_t:file { execute execute_no_trans open read map };
allow ceph_t ptmx_t:chr_file getattr;
allow ceph_t chkpwd_exec_t:file { execute execute_no_trans open read map };
allow ceph_t shadow_t:file { getattr open read };

EOF
checkmodule -m -M -o cephmon.mod cephmon.te
semodule_package --outfile cephmon.pp --module cephmon.mod
semodule -i cephmon.pp
firewall-cmd --add-service=ceph-mon
firewall-cmd --runtime-to-permanent
ceph -s


for NODE in node01 node02 node03
do
    if [ ! ${NODE} = "node01" ]
    then
        scp /etc/ceph/ceph.conf ${NODE}:/etc/ceph/ceph.conf
        scp /etc/ceph/ceph.client.admin.keyring ${NODE}:/etc/ceph
        scp /var/lib/ceph/bootstrap-osd/ceph.keyring ${NODE}:/var/lib/ceph/bootstrap-osd
    fi
    ssh $NODE \
    "chown ceph:ceph /etc/ceph/ceph.* /var/lib/ceph/bootstrap-osd/*; \
    dd if=/dev/zero of=/dev/mapper/mpathb bs=10M count=1000 ;\
    ceph-volume raw prepare --data /dev/mapper/mpathb"
done

for NODE in node01 node02 node03
do
    ssh $NODE  'systemctl start ceph-osd@0.service'
    ssh $NODE  'systemctl enable ceph-osd@0.service'
    ssh $NODE  'systemctl start ceph-osd@1.service'
    ssh $NODE  'systemctl enable ceph-osd@1.service'
    ssh $NODE  'systemctl start ceph-osd@2.service'
    ssh $NODE  'systemctl enable ceph-osd@2.service'
done




ceph -s

# Run in node 1
#ssh-copy-id dlp
#ssh dlp "dnf -y install ceph"
scp /etc/ceph/ceph.conf dlp:/etc/ceph/
scp /etc/ceph/ceph.client.admin.keyring dlp:/etc/ceph/
ssh dlp "chown ceph:ceph /etc/ceph/ceph.*"
mkdir -p /var/lib/ceph/mds/ceph-node01
ceph-authtool --create-keyring /var/lib/ceph/mds/ceph-node01/keyring --gen-key -n mds.node01
chown -R ceph:ceph /var/lib/ceph/mds/ceph-node01
ceph auth add mds.node01 osd "allow rwx" mds "allow" mon "allow profile mds" -i /var/lib/ceph/mds/ceph-node01/keyring
systemctl enable --now ceph-mds@node01
ceph osd pool create cephfs_data 32
ceph osd pool create cephfs_metadata 32
ceph fs new cephfs cephfs_metadata cephfs_data
ceph fs ls
ceph mds stat
ceph fs status cephfs


ssh root@dlp 'ceph-authtool -p /etc/ceph/ceph.client.admin.keyring > admin.key'
ssh root@dlp 'chmod 600 admin.key'
ssh root@dlp "mount -t ceph node01.$DOMAIN:6789:/ /mnt -o name=admin,secretfile=admin.key"
ssh root@dlp 'df -hT'


ceph osd tree



