openstack-scripts
=================

This repo supplies a set of scripts to automatic install Openstack components.

* Install keystone, glance, nova in single machine (VirtualBox or real one) with single/double NIC(s).
* Install multi compute nodes.

1. The All-in-One.sh
====================

Install Openstack with there components:
    - keystone
    - glance 
    - nova (using VlanManager)
    
By default you it uses only one NIC (eth0), if you have more than one NICs. You can fix it on the config values part in the script.

The default HYPERVISOR is QEMU. If you install on a real machine and it supports KVM you should change default value 'qemu' to 'kvm' to have better performance.

To check if you CPU supports KVM just run: $ kvm-ok
If it prints out something like this:
    INFO: Your CPU does not support KVM extensions
    KVM acceleration can NOT be used
Means you can not use KVM.
Maybe you must install package cpu-checker to run $ kvm-ok.

nova-volume needs a partitions to install. Here I use Virtualbox and I attached a second HDD so the default value is NOVA_VOLUME=/dev/sdb
If you have created another partition to istall nova-volume, so you must change it (something like /dev/sda5...)

NOTICE: If you install this in real machine, make sure that you put the RIGHT partition. If you don't want to use nova-volume just disable the line NOVA_VOLUME=/dev/sdb.

After installation finish. You can open browser and enter the IP that you choose to install.
Then you'll see the Dashboard interface. Enter username and password (default is admin:password) then you can login and manage your Openstack cloud.

2. upload_cirros.sh
===================

This script will download Cirros-0.3.0 amd64 from launchpad.net/cirros
then upload Cirros image to glance.

Then you can use this image to create instances from Dashboard.
This image is very light ~ 8.3 MB.

3. upload_ttylinux.sh
=====================

This script will download Tty-linux image then upload it to glance.
This tty-linux image is about 23 MB very lightweight but I recommends you to use the Cirros and Ubuntu image.

