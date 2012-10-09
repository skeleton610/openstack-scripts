###################################################################################################################
#
#	This script will download tty-linux image from:
#	http://smoser.brickies.net/ubuntu/ttylinux-uec/ttylinux-uec-amd64-12.1_2.6.35-22_1.tar.gz
#	Then upload it to glance
#	There're plenty of Ubuntu, CentOs image from Canonical or Stackops,etc
#	but it will take long time to download ( > 200MB ) so I recommend you download these file first on the client
#	then try to upload it later using the contruct below
#
###################################################################################################################

# Scource the openrc file # just make sure

source ~/openrc

# Create a new folder to store all the image like tty-linux

cd ~
mkdir img
cd ~/img


# Download this by wget

wget http://smoser.brickies.net/ubuntu/ttylinux-uec/ttylinux-uec-amd64-12.1_2.6.35-22_1.tar.gz

# Untar this file

tar zxvf ttylinux-uec-amd64-12.1_2.6.35-22_1.tar.gz

# Upload to glance

glance add name="tty-linux-kernel" disk_format=aki container_format=aki < ttylinux-uec-amd64-12.1_2.6.35-22_1-vmlinuz
kernelID=$(glance index | grep -i tty-linux-kernel | awk '{print $1}')

glance add name="tty-linux-ramdisk" disk_format=ari container_format=ari < ttylinux-uec-amd64-12.1_2.6.35-22_1-loader 
ramdiskID=$(glance index | grep -i tty-linux-ramdisk | awk '{print $1}')

glance add name="tty-linux" disk_format=ami container_format=ami kernel_id=$kernelID ramdisk_id=$ramdishID < ttylinux-uec-amd64-12.1_2.6.35-22_1.img

# List the images

glance index

###===END===###
