#!/bin/bash


yum install -y virt-install libvirt virt-manager util-linux
systemctl start libvirtd
if ! virsh net-list --name | grep -q default;
then
    virsh net-define /usr/share/libvirt/networks/default.xml
    virsh net-start default
fi
virsh net-list --all

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
#DPDK_VERSION=`echo $temp_str | grep -oP "[1-9]+\.[1-9]+\-[1-9]+" | sed -n 's/\.//p'`
DPDK_VERSION=`echo $temp_str | grep -oP "\d+\.\d+\-\d+" | sed -n 's/\.//p'`
echo "DPDK VERISON IS "$DPDK_VERSION

extra="inst.ks=file:/${dist}-vm.ks console=ttyS0,115200"

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

rhel_version=`curl -s -k ${location}/media.repo | grep name= | awk '{print $NF}' | awk -F '.' '{print $1$2}'`
rhel_major_ver=`curl -s -k ${location}/media.repo | grep name= | awk '{print $NF}' | awk -F '.' '{print $1}'`
if (( $rhel_major_ver >= 8 ))
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
authselect --enableshadow --passalgo=sha512

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
timezone --utc US/Eastern
timesource --ntp-server 10.16.31.254
timesource --ntp-server clock.util.phx2.redhat.com
timesource --ntp-server clock2.util.phx2.redhat.com

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


if (( $rhel_major_ver >= 8 ))
then

touch /etc/yum.repos.d/rhel${rhel_major_ver}.repo

cat > /etc/yum.repos.d/rhel${rhel_major_ver}.repo << REPO
[RHEL-${rhel_major_ver}-BaseOS]
name=RHEL-${rhel_major_ver}-BaseOS
baseurl=$location
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_major_ver}-AppStream]
name=RHEL-${rhel_major_ver}-AppStream
baseurl=${location/BaseOS/AppStream}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_major_ver}-Highavail]
name=RHEL-${rhel_major_ver}-buildroot
baseurl=${location/BaseOS/HighAvailability}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_major_ver}-Storage]
name=RHEL-${rhel_major_ver}-Storage
baseurl=${location/BaseOS/ResilientStorage}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_major_ver}-NFV]
name=RHEL-${rhel_major_ver}-NFV
baseurl=${location/BaseOS/NFV}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_major_ver}-RT]
name=RHEL-${rhel_major_ver}-RT
baseurl=${location/BaseOS/RT}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[beaker-harness]
name=beaker-harness
baseurl=http://beaker.engineering.redhat.com/harness/RedHatEnterpriseLinux${rhel_major_ver}/
enabled=1
gpgcheck=0

[beaker-buildroot]
name=beaker-buildroot
baseurl=http://download.devel.redhat.com/rhel-${rhel_major_ver}/nightly/BUILDROOT-${rhel_major_ver}/latest-BUILDROOT-${rhel_major_ver}-RHEL-${rhel_major_ver}/compose/Buildroot/x86_64/os/
enabled=1
gpgcheck=0
skip_if_unavailable=1

[restraint]
name=restraint
baseurl=http://fs-qe.usersys.redhat.com/ftp/pub/lookaside/beaker-harness-active/rhel-${rhel_major_ver}
enabled=1
gpgcheck=0
skip_if_unavailable=1

REPO

fi


if (( $rhel_major_ver == 10 ))
then

cat > /etc/yum.repos.d/beaker-buildroot-10.repo << REPO
[beaker-buildroot]
name=beaker-buildroot
baseurl=http://download.devel.redhat.com/rhel-10/nightly/BUILDROOT-10-Public-Beta/latest-BUILDROOT-10-RHEL-10/compose/Buildroot/x86_64/os/
enabled=1
gpgcheck=0
skip_if_unavailable=1
REPO

fi

yum install -y git 1>>/root/post_install.log 2>&1
yum install -y wget 1>>/root/post_install.log 2>&1
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
git clone https://github.com/wanghekai/VSPerfBeakerInstall.git 1>>/root/post_install.log 2>&1
pushd VSPerfBeakerInstall 1>>/root/post_install.log 2>&1
sh post_install.sh  1>>/root/post_install.log 2>&1
popd 1>>/root/post_install.log 2>&1

%end

shutdown


KS_CFG

virsh net-destroy default
virsh net-start default

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
    --os-variant=rhel-unknown \
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
    --os-variant=rhel-unknown \
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

