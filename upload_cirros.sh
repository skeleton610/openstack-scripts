################################################################################################
#
#	This script will download tty-linux image from:
#   https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
#	Then upload it to glance
#   It is a qcow2 format (for qemu/kvm - high compressed) ~ 9.3 MB
#
#	There're plenty of Ubuntu, CentOs image from Canonical or Stackops,etc
#	but it will take long time to download ( > 200MB ) 
#   so I recommend you download these file first on the client
#	then try to upload it later.
#
################################################################################################

# Scource the openrc file # just for sure if we source the openrc file

source ~/.bashrc

# Create a new folder to store all the image like tty-linux

cd ~
mkdir img
cd ~/img

echo "
##############################
Download cirros image to ~/img
##############################
"

wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

echo "
######################################
Upload this is cirros image to glance. 
######################################
"

glance add is_public=true container_format=bare disk_format=qcow2 distro="Cirros" name="Cirros-0.3.0" < cirros-0.3.0-x86_64-disk.img

echo "
###############
List the images
###############
"
glance index

###===END===####################################################
#
#   This image has default user and password is cirros:cubswin:)
#   so we can ssh to it directly without keypair
#
