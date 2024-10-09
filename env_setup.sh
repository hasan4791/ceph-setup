#!/bin/bash
# Run below 4 lines in each nodes to enable RootLogin and PasswordAuthentication
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/50-cloud-init.conf
service sshd restart
echo "passw0rd" | passwd --stdin root
subscription-manager register --username <user_name> --password "<password>" --force
subscription-manager repos --enable="rhel-9-for-ppc64le-baseos-rpms"
subscription-manager repos --enable="rhel-9-for-ppc64le-supplementary-rpms"
subscription-manager repos --enable="rhel-9-for-ppc64le-appstream-rpms"
subscription-manager repos --enable="rhel-9-for-ppc64le-highavailability-rpms"
subscription-manager repos --enable="codeready-builder-for-rhel-9-ppc64le-rpms"
dnf update -y
reboot