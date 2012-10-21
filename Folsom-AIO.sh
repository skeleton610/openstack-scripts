#########################################################################################
#
#	Author. Tung Ns (tungns.inf@gmail.com)
#
#	This script will install an Openstack (Folsom) on single machine with these components:
#		- keystone
#		- glance
#		- nova : all components (nova-network using VlanManager mode)
#       - cinder (replace nova-volume)
#       - horizon
#
#########################################################################################


#!/bin/bash

###############################################
# Change these values to fit your requirements
###############################################

IP=172.17.17.21             # You public IP 
PUBLIC_IP_RANGE=172.17.17.64/27 # The floating IP range
PUBLIC_NIC=eth0             # The public NIC, floating network, allow instance connect to Internet
PRIVATE_NIC=eth0            # The private NIC, fixed network. If you have more than 2 NICs specific it eg: eth1
MYSQL_PASS=root             # Default password of mysql-server
CLOUD_ADMIN=admin           # Cloud admin of Openstack
CLOUD_ADMIN_PASS=password   # Password will use to login into Dashboard later
TENANT=openstackDemo          # The name of tenant (project)
SERVICE_TENANT=service		# Service tenant
REGION=RegionOne            # You must specific it. Imagine that you have multi datacenter. Not important, just keep it by default
HYPERVISOR=qemu             # if your machine support KVM (check by run $ kvm-ok), change QEMU to KVM
NOVA_VOLUME=/dev/sdb        # Partition to use with nova-volume, here I have 2 HDD then it is sdb

################################################

# Check if user is root

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   echo "Please run $ sudo bash then rerun this script"
   exit 1
fi

##### Pre-configure #####
# Enable Cloud Archive repository for Ubuntu

cat > /etc/apt/sources.list.d/folsom.list <<EOF
deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main
EOF

# add the public key for the folsom repository
sudo apt-get install ubuntu-cloud-keyring

# update Ubuntu
apt-get update
apt-get upgrade -y

# Load 8021q module into the kernel - support Vlan mode
modprobe 8021q

# Create ~/openrc contains identity information

cat > ~/openrc <<EOF
export OS_USERNAME=$CLOUD_ADMIN
export OS_TENANT_NAME=$TENANT
export OS_PASSWORD=$CLOUD_ADMIN_PASS
export OS_AUTH_URL=http://$IP:5000/v2.0/
export OS_REGION_NAME=$REGION
export SERVICE_ENDPOINT="http://$IP:35357/v2.0"
export SERVICE_TOKEN=012345SECRET99TOKEN012345
export OS_NO_CACHE=1
EOF

source ~/openrc

cat >> ~/.bashrc <<EOF
source ~/openrc
EOF

source ~/.bashrc

echo "
######################################
	Content of ~/openrc
######################################
"
cat ~/openrc
sleep 1

echo "
######################################
	Install ntp server
######################################
"
sleep 1

apt-get install -y ntp

sed -i 's/server ntp.ubuntu.com/server ntp.ubuntu.com\nserver 127.127.1.0\nfudge 127.127.1.0 stratum 10/g' /etc/ntp.conf
service ntp restart

echo "
######################################
	Install Mysql Server
######################################
"
sleep 1

# Store password in /var/cache/debconf/passwords.dat

cat <<MYSQL_PRESEED | debconf-set-selections
mysql-server-5.5 mysql-server/root_password password $MYSQL_PASS
mysql-server-5.5 mysql-server/root_password_again password $MYSQL_PASS
mysql-server-5.5 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

apt-get -y install python-mysqldb mysql-server

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
service mysql restart
sleep 2

mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE keystone_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON keystone_db.* TO 'keystone'@'%' IDENTIFIED BY 'keystone';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON keystone_db.* TO 'keystone'@'localhost' IDENTIFIED BY 'keystone';"

mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE glance_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON glance_db.* TO 'glance'@'%' IDENTIFIED BY 'glance';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON glance_db.* TO 'glance'@'localhost' IDENTIFIED BY 'glance';"

mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE nova_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON nova_db.* TO 'nova'@'%' IDENTIFIED BY 'nova';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON nova_db.* TO 'nova'@'localhost' IDENTIFIED BY 'nova';"

mysql -u root -p$MYSQL_PASS -e 'CREATE DATABASE cinder_db;'
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON cinder_db.* TO 'cinder'@'%' IDENTIFIED BY 'cinder';"
mysql -u root -p$MYSQL_PASS -e "GRANT ALL ON cinder_db.* TO 'cinder'@'localhost' IDENTIFIED BY 'cinder';"

echo "
#####################################
	Install Keystone
#####################################
"
sleep 2

apt-get install -y keystone

rm /var/lib/keystone/keystone.db

sed -i 's/# admin_token = ADMIN/admin_token = 012345SECRET99TOKEN012345/g' /etc/keystone/keystone.conf
sed -i "s/# bind_host = 0.0.0.0/bind_host = 0.0.0.0/g" /etc/keystone/keystone.conf
sed -i "s/# public_port = 5000/public_port = 5000/g" /etc/keystone/keystone.conf
sed -i "s/# admin_port = 35357/admin_port = 35357/g" /etc/keystone/keystone.conf
sed -i "s/# compute_port = 8774/compute_port = 8774/g" /etc/keystone/keystone.conf
sed -i "s/# verbose = False/verbose = True/g" /etc/keystone/keystone.conf
sed -i "s/# debug = False/debug = True/g" /etc/keystone/keystone.conf
sed -i "s/# use_syslog = False/use_syslog = False/g" /etc/keystone/keystone.conf
sed -i "s|connection = sqlite:////var/lib/keystone/keystone.db|connection = mysql://keystone:keystone@$IP/keystone_db|g" /etc/keystone/keystone.conf

service keystone restart
sleep 3
keystone-manage db_sync
sleep 3
service keystone restart
sleep 3

KEYSTONE_IP=$IP
SERVICE_ENDPOINT=http://$IP:35357/v2.0/
SERVICE_TOKEN=012345SECRET99TOKEN012345

NOVA_IP=$IP
VOLUME_IP=$IP
GLANCE_IP=$IP
EC2_IP=$IP

NOVA_PUBLIC_URL="http://$NOVA_IP:8774/v2/%(tenant_id)s"
NOVA_ADMIN_URL=$NOVA_PUBLIC_URL
NOVA_INTERNAL_URL=$NOVA_PUBLIC_URL

VOLUME_PUBLIC_URL="http://$VOLUME_IP:8776/v1/%(tenant_id)s"
VOLUME_ADMIN_URL=$VOLUME_PUBLIC_URL
VOLUME_INTERNAL_URL=$VOLUME_PUBLIC_URL

GLANCE_PUBLIC_URL="http://$GLANCE_IP:9292/v1"
GLANCE_ADMIN_URL=$GLANCE_PUBLIC_URL
GLANCE_INTERNAL_URL=$GLANCE_PUBLIC_URL
 
KEYSTONE_PUBLIC_URL="http://$KEYSTONE_IP:5000/v2.0"
KEYSTONE_ADMIN_URL="http://$KEYSTONE_IP:35357/v2.0"
KEYSTONE_INTERNAL_URL=$KEYSTONE_PUBLIC_URL

EC2_PUBLIC_URL="http://$EC2_IP:8773/services/Cloud"
EC2_ADMIN_URL="http://$EC2_IP:8773/services/Admin"
EC2_INTERNAL_URL=$EC2_PUBLIC_URL

## Define Admin, Member role and OpenstackDemo tenant
TENANT_ID=$(keystone tenant-create --name $TENANT | grep id | awk '{print $4}')
ADMIN_ROLE=$(keystone role-create --name Admin | grep id | awk '{print $4}')
MEMBER_ROLE=$(keystone role-create --name Member | grep id | awk '{print $4}')

# create user admin
ADMIN_USER=$(keystone user-create --name $CLOUD_ADMIN --tenant-id $TENANT_ID --pass $CLOUD_ADMIN_PASS --email root@localhost --enabled true | grep id | awk '{print $4}')

# grant Admin role to the admin user in the openstackDemo tenant
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $TENANT_ID

## Create Service tenant. This tenant contains all the services that we make known to the service catalog.
SERVICE_TENANT_ID=$(keystone tenant-create --name $SERVICE_TENANT | grep id | awk '{print $4}')

# Create services user in Service tenant
GLANCE_ID=$(keystone user-create --name glance --tenant-id $SERVICE_TENANT_ID --pass glance --enabled true | grep id | awk '{print $4}')
NOVA_ID=$(keystone user-create --name nova --tenant-id $SERVICE_TENANT_ID --pass nova --enabled true | grep id | awk '{print $4}')
EC2_ID=$(keystone user-create --name ec2 --tenant-id $SERVICE_TENANT_ID --pass ec2 --enabled true | grep id | awk '{print $4}')
CINDER_ID=$(keystone user-create --name cinder --tenant-id $SERVICE_TENANT_ID --pass cinder --enabled true | grep id | awk '{print $4}')

# Grant admin role for those service user in Service tenant
for ID in $GLANCE_ID $NOVA_ID $EC2_ID $CINDER_ID
do
keystone user-role-add --user-id $ID --tenant-id $SERVICE_TENANT_ID --role-id $ADMIN_ROLE
done

## Define services
KEYSTONE_SERVICE_ID=$(keystone service-create --name keystone --type identity --description 'OpenStack Identity Service' | grep 'id ' | awk '{print $4}')
COMPUTE_SERVICE_ID=$(keystone service-create --name nova --type compute --description 'OpenStack Compute Service' | grep id | awk '{print $4}') 
VOLUME_SERVICE_ID=$(keystone service-create --name volume --type volume --description 'OpenStack Volume Service' | grep id | awk '{print $4}')
GLANCE_SERVICE_ID=$(keystone service-create --name glance --type image --description 'OpenStack Image Service'  | grep id | awk '{print $4}')
EC2_SERVICE_ID=$(keystone service-create --name ec2 --type ec2 --description 'EC2 Service' | grep id | awk '{print $4}')
CINDER_SERVICE_ID=$(keystone service-create --name cinder --type volume --description 'Cinder Service' | grep id | awk '{print $4}')

# Create endpoints to these services
keystone endpoint-create --region $REGION --service-id $COMPUTE_SERVICE_ID --publicurl $NOVA_PUBLIC_URL --adminurl $NOVA_ADMIN_URL --internalurl $NOVA_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $VOLUME_SERVICE_ID --publicurl $VOLUME_PUBLIC_URL --adminurl $VOLUME_ADMIN_URL --internalurl $VOLUME_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $KEYSTONE_SERVICE_ID --publicurl $KEYSTONE_PUBLIC_URL --adminurl $KEYSTONE_ADMIN_URL --internalurl $KEYSTONE_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $GLANCE_SERVICE_ID --publicurl $GLANCE_PUBLIC_URL --adminurl $GLANCE_ADMIN_URL --internalurl $GLANCE_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $EC2_SERVICE_ID --publicurl $EC2_PUBLIC_URL --adminurl $EC2_ADMIN_URL --internalurl $EC2_INTERNAL_URL
keystone endpoint-create --region $REGION --service-id $CINDER_SERVICE_ID --publicurl $VOLUME_PUBLIC_URL --adminurl $VOLUME_ADMIN_URL --internalurl $VOLUME_INTERNAL_URL


# Verifying
keystone user-list

echo "
####################################
	Install Glance
####################################
"
sleep 2

apt-get install -y glance

rm /var/lib/glance/glance.sqlite

# Update /etc/glance/glance-api-paste.ini, /etc/glance/glance-registry-paste.ini

#~ sed -i "s/%SERVICE_TENANT_NAME%/$SERVICE_TENANT/g" /etc/glance/glance-api-paste.ini /etc/glance/glance-registry-paste.ini
#~ sed -i "s/%SERVICE_USER%/glance/g" /etc/glance/glance-api-paste.ini /etc/glance/glance-registry-paste.ini
#~ sed -i "s/%SERVICE_PASSWORD%/glance/g" /etc/glance/glance-api-paste.ini /etc/glance/glance-registry-paste.ini

cat >> /etc/glance/glance-api-paste.ini <<EOF
admin_tenant_name = $SERVICE_TENANT
admin_user = glance
admin_password = glance
EOF

cat >> /etc/glance/glance-registry-paste.ini <<EOF
[filter:authtoken]
admin_tenant_name = $SERVICE_TENANT
admin_user = glance
admin_password = glance
EOF

# update authtoken
sed -i "s/pipeline = unauthenticated-context registryapp/pipeline = authtoken auth-context context registryapp/g" /etc/glance/glance-registry-paste.ini

# Update /etc/glance/glance-registry.conf

sed -i "s|sql_connection = sqlite:////var/lib/glance/glance.sqlite|sql_connection = mysql://glance:glance@$IP/glance_db|g" /etc/glance/glance-registry.conf

# Add to the and of /etc/glance/glance-registry.conf and /etc/glance/glance-api.conf

cat >> /etc/glance/glance-registry.conf <<EOF
flavor = keystone
EOF

cat >> /etc/glance/glance-api.conf <<EOF
flavor = keystone
EOF

# Sync glance_db

restart glance-api
restart glance-registry

sleep 3

glance-manage version_control 0
glance-manage db_sync

sleep 3

restart glance-api
restart glance-registry

echo "
#####################################
	Install Nova
#####################################
"
sleep 2

# Check to install nova-compute-kvm or nova-compute-qemu

if [ $HYPERVISOR == "qemu" ]; then
	apt-get -y install nova-compute nova-compute-qemu
else
	apt-get -y install nova-compute nova-compute-kvm
fi

apt-get install -y rabbitmq-server nova-volume nova-novncproxy nova-api nova-ajax-console-proxy nova-cert nova-consoleauth nova-doc nova-scheduler nova-network

# Change owner and permission for /etc/nova/

groupadd nova
usermod -g nova nova
chown -R nova:nova /etc/nova
chmod 644 /etc/nova/nova.conf

# Update /etc/nova/api-paste.ini
sed -i "s/127.0.0.1/$IP/g" /etc/nova/api-paste.ini
sed -i "s/%SERVICE_TENANT_NAME%/$SERVICE_TENANT/g" /etc/nova/api-paste.ini
sed -i "s/%SERVICE_USER%/nova/g" /etc/nova/api-paste.ini
sed -i "s/%SERVICE_PASSWORD%/nova/g" /etc/nova/api-paste.ini

# Update hypervisor in nova-compute.conf

if [ $HYPERVISOR == "qemu" ]; then
	sed -i 's/kvm/qemu/g' /etc/nova/nova-compute.conf
fi

# Update nova.conf

cat > /etc/nova/nova.conf <<EOF
[DEFAULT]

# LOG/STATE
verbose=True
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
logging_context_format_string=%(asctime)s %(color)s%(levelname)s %(name)s [%(request_id)s %(user_name)s %(project_name)s%(color)s] %(instance)s%(color)s%(message)s
logging_default_format_string=%(asctime)s %(color)s%(levelname)s %(name)s [-%(color)s] %(instance)s%(color)s%(message)s
logging_debug_format_suffix=from (pid=%(process)d) %(funcName)s %(pathname)s:%(lineno)d
logging_exception_prefix=%(color)s%(asctime)s TRACE %(name)s %(instance)s

# AUTHENTICATION
use_deprecated_auth=false
auth_strategy=keystone
keystone_ec2_url=http://$IP:5000/v2.0/ec2tokens

# SCHEDULER
scheduler_driver=nova.scheduler.simple.SimpleScheduler
#compute_scheduler_driver=nova.scheduler.filter_scheduler.FilterScheduler

# DATABASE
sql_connection=mysql://nova:nova@$IP/nova_db

# NETWORK
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
network_manager=nova.network.manager.VlanManager
public_interface=$PUBLIC_NIC
vlan_interface=$PRIVATE_NIC
fixed_range=10.10.10.0/24
routing_source_ip=$IP
force_dhcp_release=True
iscsi_helper=ietadm
iscsi_ip_address=$IP
#my_ip=$IP
#multi_host=True
#firewall_driver=nova.virt.libvirt.firewall.IptablesFirewallDriver

# NOVNC
novnc_enabled=true
novncproxy_base_url=http://$IP:6080/vnc_auto.html
novncproxy_port=6080
xvpvncproxy_base_url=http://$IP:6081/console
vncserver_listen=0.0.0.0
vncserver_proxyclient_address=$IP

# APIs
osapi_compute_extension=nova.api.openstack.compute.contrib.standard_extensions
s3_host=$IP
ec2_host=$IP
ec2_dmz_host=$IP
#cc_host=$IP
enabled_apis=ec2,osapi_compute,metadata
nova_url=http://$IP:8774/v1.1/
ec2_url=http://$IP:8773/services/Cloud
#volume_api_class=nova.volume.cinder.API

# RABBIT
rabbit_host=$IP

# GLANCE
glance_api_servers=$IP:9292
image_service=nova.image.glance.GlanceImageService

# COMPUTE
#connection_type=libvirt
compute_driver=libvirt.LibvirtDriver
libvirt_type=qemu
libvirt_cpu_mode=none
allow_resize_to_same_host=True
libvirt_use_virtio_for_bridges=true
start_guests_on_host_boot=false
resume_guests_state_on_host_boot=false
api_paste_config=/etc/nova/api-paste.ini
rootwrap_config=/etc/nova/rootwrap.conf
#instance_name_template=instance-%08x

# CINDER
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
EOF

# Config nova-volume
#~ vgremove nova-volumes $NOVA_VOLUME # just for sure, if the 1st time this script failed, then rerun...
#~ 
#~ pvcreate -ff -y $NOVA_VOLUME # if rerun the script we need force option
#~ vgcreate nova-volumes $NOVA_VOLUME

cat > ~/nova_restart <<EOF
sudo restart libvirt-bin
sudo /etc/init.d/rabbitmq-server restart
for i in nova-network nova-compute nova-api nova-objectstore nova-scheduler nova-volume nova-consoleauth nova-cert nova-novncproxy
do
sudo service "\$i" restart # need \ before $ to make it a normal charactor not variable
done
EOF

chmod +x ~/nova_restart

# Sync nova_db
  
~/nova_restart
sleep 3
 nova-manage db sync
sleep 3
~/nova_restart
sleep 3
nova-manage service list

# Create fixed and floating ips

nova-manage network create --label vlan1 --fixed_range_v4 10.10.10.0/24 --num_networks 1 --network_size 256 --vlan 1 #--multi_host=T

nova-manage floating create --ip_range $PUBLIC_IP_RANGE

# Define security rules

nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0 
nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
nova secgroup-add-rule default tcp 80 80 0.0.0.0/0

# Create key pair

mkdir ~/key
cd ~/key
nova keypair-add mykeypair > mykeypair.pem
chmod 600 mykeypair.pem
cd

echo "
#####################################
	Install Cinder
#####################################
"
sleep 1

sudo apt-get install -y cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms python-cinderclient tgt

# Update /etc/cinder/api-paste.ini
sed -i "s/127.0.0.1/$IP/g" /etc/cinder/api-paste.ini
sed -i "s/%SERVICE_TENANT_NAME%/$SERVICE_TENANT/g" /etc/cinder/api-paste.ini
sed -i "s/%SERVICE_USER%/cinder/g" /etc/cinder/api-paste.ini
sed -i "s/%SERVICE_PASSWORD%/cinder/g" /etc/cinder/api-paste.ini

# Update /etc/cinder/cinder.conf
cat >> /etc/cinder/cinder.conf <<EOF
sql_connection = mysql://cinder:cinder@$IP/cinder_db
EOF

# Sync database
cinder-manage db sync

# Restart cinder service
service cinder-volume restart
service cinder-api restart 

echo "
#####################################
	Install Horizon
#####################################
"
sleep 2

apt-get install --no-install-recommends -y memcached libapache2-mod-wsgi openstack-dashboard novnc

# Disable Quantum
cat >> /etc/openstack-dashboard/local_settings.py <<EOF
QUANTUM_ENABLED = False
EOF

# Default istallation uses $IP/horizon to access dashboard
sed -i "s|/horizon|/|g" /etc/apache2/conf.d/openstack-dashboard.conf

service apache2 restart

echo "
#################################################################
#
#    Now you can open your browser and enter your IP: $IP
#    Login with your user and password: $CLOUD_ADMIN@$CLOUD_ADMIN_PASS
#    Enjoy!
#
#################################################################"

#===END===#
