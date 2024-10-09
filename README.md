This repo contains scripts for setting up a 3 node ceph cluster with minimal configuration on a RHEL OS on Power
You need access to the ceph rpms for this.

###Prerequisites:

1. 3 VMs + an additional VM for testing. 
2. each of these 3 VMs should have a free disk with 500G. 
3. Update the node IP and client IP in nodes.info
4. You need a repository whre you have ceph rpms, which needs to be updated in nodes.info


###Setup:
1. Enable password root login, set the root password and also setup the RHEL subscription. You need to update the 
   subscription user credentials in the script before running it.
   
   `sh env_setup.sh` 
   

2. Next run the `ceph.sh` script to install the ceph rpm and configure ceph cluster.
    Before running, comment `#if selinux is enabled, run below` part if the selinux is  not 
   enabled.
   

3. Run `ceph -s` to verify the cluster status
   

4. If the cluster health is in WARN state , run the following
   
   `ceph crash ls`
   
   `ceph crash archive <crash id>`
    ```
   # ceph crash ls
   # ceph crash archive '2024-10-07T17:36:59.449933Z_370f950c-a23c-4424-b4a2-83b934691c22'
   ```

###Clean Up:
    
1. To remove the ceph cluster setup run `uninstall_ceph.sh`