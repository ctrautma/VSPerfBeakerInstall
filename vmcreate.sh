#!/bin/bash


yum install -y virt-install libvirt
systemctl start libvirtd

enforce_status=`getenforce`

setenforce permissive

LOCATION="http://download-node-02.eng.bos.redhat.com/released/RHEL-7/7.3/Server/x86_64/os/"
CPUS=3
DEBUG="no"
export VIOMMU="NO"

progname=$0

function usage () {
   cat <<EOF
Usage: $progname [-c cpus] [-l url to compose] [-v enable viommu] [-d debug output to screen ]
EOF
   exit 0
}

while getopts c:l:dhv FLAG; do
   case $FLAG in

   c)  echo "Creating VM with $OPTARG cpus" 
       CPUS=$OPTARG
       ;;
   l)  echo "Using Location for VM install $OPTARG"
       LOCATION=$OPTARG
       ;;
   v)  echo "VIOMMU is enabled"
       VIOMMU="YES";;
   d)  echo "debug enabled" 
       DEBUG="yes";;
   h)  echo "found $opt" ; usage ;;
   \?)  usage ;;
   esac
done

shift $(($OPTIND - 1))

vm=master
bridge=virbr0
master_image=master.qcow2
image_path=/var/lib/libvirt/images/
dist=rhel73
location=$LOCATION

extra="ks=file:/$dist-vm.ks console=ttyS0,115200"

master_exists=`virsh list --all | awk '{print $2}' | grep master`
if [ -z $master_exists ]; then
    master_exists='None'
fi

if [ $master_exists == "master" ]; then
    virsh destroy $vm
    virsh undefine $vm
fi

echo deleting master image
/bin/rm -f $image_path/$master_image

cat << KS_CFG > $dist-vm.ks
# System authorization information
auth --enableshadow --passalgo=sha512

# Use network installation
url --url=$location

# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=dhcp --device=eth0 --ipv6=auto --activate
# Root password
rootpw  redhat
# Do not configure the X Window System
skipx
# System timezone
timezone US/Eastern --isUtc --ntpservers=10.16.31.254,clock.util.phx2.redhat.com,clock02.util.phx2.redhat.com
# System bootloader configuration
bootloader --location=mbr --timeout=5 --append="crashkernel=auto rhgb quiet console=ttyS0,115200"
# Partition clearing information
autopart --type=plain
clearpart --all --initlabel --drives=vda
zerombr

%packages
@base
@core
@network-tools
%end

%post
cat >/etc/yum.repos.d/beaker-Server-optional.repo <<REPO
[beaker-Server-optional]
name=beaker-Server-optional
baseurl=$location
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPO

cat >~/viommu_setting.txt <<EOT
VIOMMU_SETTING=$VIOMMU
EOT

yum install -y tuna git nano ftp wget sysstat 1>/root/post_install.log 2>&1
git clone https://github.com/ctrautma/vmscripts.git /root/vmscripts 1>/root/post_install.log 2>&1
mv /root/vmscripts/* /root/. 1>/root/post_install.log 2>&1
rm -RF /root/vmscripts 1>/root/post_install.log 2>&1
/root/setup_rpms.sh 1>/root/post_install.log 2>&1

%end

shutdown

KS_CFG

echo creating new master image
qemu-img create -f qcow2 $image_path/$master_image 100G
echo undefining master xml
virsh list --all | grep master && virsh undefine master
echo calling virt-install

if [ $DEBUG == "yes" ]; then
virt-install --name=$vm\
	 --virt-type=kvm\
	 --disk path=$image_path/$master_image,format=qcow2,,size=3,bus=virtio\
	 --vcpus=$CPUS\
	 --ram=4096\
	 --network bridge=$bridge\
	 --graphics none\
	 --extra-args="$extra"\
	 --initrd-inject=/root/$dist-vm.ks\
	 --location=$location\
	 --noreboot\
         --serial pty\
         --serial file,path=/tmp/$vm.console
else
virt-install --name=$vm\
         --virt-type=kvm\
         --disk path=$image_path/$master_image,format=qcow2,,size=3,bus=virtio\
         --vcpus=$CPUS\
         --ram=4096\
         --network bridge=$bridge\
         --graphics none\
         --extra-args="$extra"\
         --initrd-inject=/root/$dist-vm.ks\
         --location=$location\
         --noreboot\
         --serial pty\
         --serial file,path=/tmp/$vm.console &> vminstaller.log
fi

rm $dist-vm.ks

setenforce $enforce_status