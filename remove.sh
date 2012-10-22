#!/bin/bash
# Remove all the Openstack components: keystone, glance, nova, cinder, horizon
# Remove mysql-server, ntp, python-django

# remove mysql databases
mysql -u root -proot -e 'DROP DATABASE keystone_db;'
mysql -u root -proot -e 'DROP DATABASE glance_db;'
mysql -u root -proot -e 'DROP DATABASE nova_db;'
mysql -u root -proot -e 'DROP DATABASE cinder_db;'

# remove openstack
sudo apt-get autoremove -y --purge ntp python-mysqldb mysql-server keystone glance rabbitmq-server nova-volume nova-novncproxy nova-api nova-ajax-console-proxy nova-cert nova-consoleauth nova-doc nova-scheduler nova-network nova-compute memcached libapache2-mod-wsgi openstack-dashboard cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms python-cinderclient tgt

rm -rf /var/lib/nova /var/lib/glance /var/lib/mysql /var/lib/libvirt/ /var/log/nova /var/log/glance /etc/mysql /etc/cinder /var/log/cinder /var/lib/cinder

sed -i "s/source ~/openrc//g" ~/.bashrc
