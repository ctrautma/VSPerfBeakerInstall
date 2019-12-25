#!/bin/bash


yum install -y virt-install libvirt virt-manager util-linux
systemctl start libvirtd

enforce_status=`getenforce`

setenforce permissive

LOCATION="http://download-node-02.eng.bos.redhat.com/released/RHEL-7/7.3/Server/x86_64/os/"
CPUS=3
DEBUG="no"
VIOMMU="NO"
DPDK_BUILD="NO"
#DPDK_URL="http://download.eng.bos.redhat.com/brewroot/packages/dpdk/18.11/2.el7_6/x86_64/dpdk-18.11-2.el7_6.x86_64.rpm"
DPDK_URL=""

progname=$0

function usage () {
   cat <<EOF
Usage: $progname [-c cpus] [-l url to compose] [-v enable viommu] [-d debug output to screen ] [-r dpdk package location for guest]
EOF
   exit 0
}

while getopts c:l:r:dhvu FLAG; do
   case $FLAG in

   c)  echo "Creating VM with $OPTARG cpus" 
       CPUS=$OPTARG
       ;;
   l)  echo "Using Location for VM install $OPTARG"
       LOCATION=$OPTARG
       ;;
   v)  echo "VIOMMU is enabled"
       VIOMMU="YES";;
   u)  echo "Building upstream DPDK"
       DPDK_BUILD="YES";;
   d)  echo "debug enabled" 
       DEBUG="yes";;
   r)  echo "DPDK release verison $OPTARG"
       DPDK_URL=$OPTARG
       ;;
   h)  echo "found $opt" ; usage ;;
   \?)  usage ;;
   esac
done

shift $(($OPTIND - 1))

VM_NAME=${VM_NAME:-"master"}
vm=${VM_NAME}
bridge=virbr0
master_image=${vm}.qcow2
image_path=/var/lib/libvirt/images/
dist=rhel73
location=$LOCATION
if [[ ${location: -1} == "/" ]]
then
    location=${location: :-1}
fi

#echo $DPDK_URL
temp_str=$(basename $DPDK_URL)
DPDK_TOOL_URL=$(dirname $DPDK_URL)/${temp_str/dpdk/dpdk-tools}
DPDK_VERSION=`echo $temp_str | grep -oP "[1-9]+\.[1-9]+\-[1-9]+" | sed -n 's/\.//p'`
echo "DPDK VERISON IS "$DPDK_VERSION

extra="ks=file:/${dist}-vm.ks console=ttyS0,115200"

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

#rhel_version=`echo $location | awk -F '/' '{print $(NF-3)}' | awk -F '-' '{print $1}' | tr -d '.'`
#fix this rhel7 and rhel8 location different use regex get version info 
rhel_version=`echo $location | grep -oP "\/RHEL-\d+\.\d+|\/\d+\.\d+|\/latest-RHEL-\d+\.\d+" | tr -d '\.\/\-[a-zA-Z]'`
if (( $rhel_version >= 80 ))
then
    base_repo='repo --name="beaker-BaseOS" --baseurl='$location
    app_repo='repo --name="beaker-AppStream" --baseurl='${location/BaseOS/AppStream}
    highavail_repo='repo --name="beaker-HighAvailability" --baseurl='${location/BaseOS/HighAvailability}
    nfv_repo='repo --name="beaker-NFV" --baseurl='${location/BaseOS/NFV}
    storage_repo='repo --name="beaker-ResilientStorage" --baseurl='${location/BaseOS/ResilientStorage}
    rt_repo='repo --name="beaker-RT" --baseurl='${location/BaseOS/RT}
else
    base_repo='#'
    app_repo='#'
    highavail_repo='#'
    nfv_repo='#'
    storage_repo='#'
    rt_repo='#'
fi

cat << KS_CFG > $dist-vm.ks
# System authorization information
auth --enableshadow --passalgo=sha512

# Use network installation
url --url=$location

# Use text mode install
text
#graphical
$base_repo
$app_repo
$highavail_repo
$nfv_repo
$storage_repo
$rt_repo

# Run the Setup Agent on first boot
#firstboot --enable
firstboot --disabled
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8

# Network information
#network  --bootproto=dhcp --device=eth0 --ipv6=auto --activate
network  --bootproto=dhcp --ipv6=auto --activate

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

#firewall and selinux config
firewall --enabled
#selinux --permissive
selinux --enforcing


%packages --ignoremissing
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


if (( $rhel_version >= 80 ))
then

touch /etc/yum.repos.d/rhel8.repo

cat > /etc/yum.repos.d/rhel8.repo << REPO
[RHEL-8-BaseOS]
name=RHEL-8-BaseOS
baseurl=$location
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-AppStream]
name=RHEL-8-AppStream
baseurl=${location/BaseOS/AppStream}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-Highavail]
name=RHEL-8-buildroot
baseurl=${location/BaseOS/HighAvailability}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-Storage]
name=RHEL-8-Storage
baseurl=${location/BaseOS/ResilientStorage}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-NFV]
name=RHEL-8-NFV
baseurl=${location/BaseOS/NFV}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-8-RT]
name=RHEL-8-RT
baseurl=${location/BaseOS/RT}
enabled=1
gpgcheck=0
skip_if_unavailable=1"

REPO

fi

# if (( $rhel_version >= 80 ))
# then
#        yum -y install iperf3
#        ln -s /usr/bin/iperf3 /usr/bin/iperf
# else
#        yum -y install iperf
# fi

yum -y install iperf3
ln -s /usr/bin/iperf3 /usr/bin/iperf

yum install -y kernel-devel numactl-devel
yum install -y tuna git nano ftp wget sysstat 1>/root/post_install.log 2>&1

#Here mkdir and download dpdk
mkdir -p /root/dpdkrpms/$DPDK_VERSION
wget $DPDK_URL -P /root/dpdkrpms/$DPDK_VERSION/.
wget $DPDK_TOOL_URL -P /root/dpdkrpms/$DPDK_VERSION/.

git clone https://github.com/ctrautma/vmscripts.git /root/vmscripts 1>/root/post_install.log 2>&1
mv /root/vmscripts/* /root/. 1>/root/post_install.log 2>&1
rm -Rf /root/vmscripts 1>/root/post_install.log 2>&1

if [ "$VIOMMU" == "NO" ] && [ "$DPDK_BUILD" == "NO" ]; then
    /root/setup_rpms.sh 1>/root/post_install.log 2>&1
elif [ "$VIOMMU" == "YES" ] && [ "$DPDK_BUILD" == "NO" ]; then
    /root/setup_rpms.sh -v 1>/root/post_install.log 2>&1
elif [ "$VIOMMU" == "NO" ] && [ "$DPDK_BUILD" == "YES" ]; then
    /root/setup_rpms.sh -u 1>/root/post_install.log 2>&1
elif [ "$VIOMMU" == "YES" ] && [ "$DPDK_BUILD" == "YES" ]; then
    /root/setup_rpms.sh -u -v 1>/root/post_install.log 2>&1
fi

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
    --ram=8192\
    --network bridge=$bridge\
    --graphics none\
    --extra-args="$extra"\
    --initrd-inject `pwd`/$dist-vm.ks \
    --location=$location\
    --noreboot\
    --serial pty\
    --serial file,path=/tmp/$vm.console
else
virt-install --name=$vm\
    --virt-type=kvm\
    --disk path=$image_path/$master_image,format=qcow2,,size=3,bus=virtio\
    --vcpus=$CPUS\
    --ram=8192\
    --network bridge=$bridge\
    --graphics none\
    --extra-args="$extra"\
    --initrd-inject `pwd`/$dist-vm.ks \
    --location=$location\
    --noreboot\
    --serial pty\
    --serial file,path=/tmp/$vm.console &> vminstaller.log
fi

rm $dist-vm.ks

setenforce $enforce_status
