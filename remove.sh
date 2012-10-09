#!/usr/bin
# Remove all the Openstack components

# remove mysql databases
mysql -u root -proot -e 'DROP DATABASE keystone_db;'
mysql -u root -proot -e 'DROP DATABASE glance_db;'
mysql -u root -proot -e 'DROP DATABASE nova_db;'

# remove openstack
sudo apt-get autoremove -y --purge ntp python-mysqldb mysql-server keystone glance rabbitmq-server nova-volume nova-novncproxy nova-api nova-ajax-console-proxy nova-cert nova-consoleauth nova-doc nova-scheduler nova-network nova-compute memcached libapache2-mod-wsgi openstack-dashboard

