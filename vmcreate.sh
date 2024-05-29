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

#rhel_version=`echo $location | awk -F '/' '{print $(NF-3)}' | awk -F '-' '{print $1}' | tr -d '.'`
#fix this rhel7 and rhel8 location different use regex get version info 
#rhel_version=`echo $location | grep -oP "\/RHEL-\d+\.\d+|\/\d+\.\d+|\/latest-RHEL-\d+\.\d+" | tr -d '\.\/\-[a-zA-Z]'`
#curl -I ${location}/isolinux/grub.conf
# compose_link=`sed "s/compose.*/COMPOSE_ID/g" <<< "$location"`
# echo $compose_link
# curl -I $compose_link
# rhel_version=`curl -s -k ${location}/isolinux/grub.conf | grep title | grep -v Test | awk '{print $NF}' | tr -d '\.\/\-[a-zA-Z]'`
rhel_version=`curl -s -k ${location}/media.repo | grep name= | awk '{print $NF}' | awk -F '.' '{print $1$2}'`
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


if (( $rhel_version >= 80 ))
then

touch /etc/yum.repos.d/rhel8.repo

cat > /etc/yum.repos.d/rhel8.repo << REPO
[RHEL-${rhel_version}-BaseOS]
name=RHEL-${rhel_version}-BaseOS
baseurl=$location
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_version}-AppStream]
name=RHEL-${rhel_version}-AppStream
baseurl=${location/BaseOS/AppStream}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_version}-Highavail]
name=RHEL-${rhel_version}-buildroot
baseurl=${location/BaseOS/HighAvailability}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_version}-Storage]
name=RHEL-${rhel_version}-Storage
baseurl=${location/BaseOS/ResilientStorage}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_version}-NFV]
name=RHEL-${rhel_version}-NFV
baseurl=${location/BaseOS/NFV}
enabled=1
gpgcheck=0
skip_if_unavailable=1

[RHEL-${rhel_version}-RT]
name=RHEL-${rhel_version}-RT
baseurl=${location/BaseOS/RT}
enabled=1
gpgcheck=0
skip_if_unavailable=1

REPO

fi

yum -y install iperf3
ln -s /usr/bin/iperf3 /usr/bin/iperf

yum install -y kernel-devel numactl-devel
yum install -y tuna git nano ftp wget sysstat automake 1>/root/post_install.log 2>&1

yum install libibverbs -y

yum install -y nmap-ncat tcpdump

# netperf & iperf
yum install -y gcc-c++ make gcc

rpm -q grubby || yum -y install grubby

echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-$(( ${rhel_version} / 10 )).noarch.rpm

if (( $rhel_version >= 80 )) && (( $rhel_version < 90 ))
then
    yum install -y http://download.eng.bos.redhat.com/brewroot/vol/rhel-8/packages/netperf/2.7.0/5.el8eng/x86_64/netperf-2.7.0-5.el8eng.x86_64.rpm
    yum install -y iperf3
elif (( $rhel_version >= 90 ))
then
    yum -y install iperf3
    yum -y install netperf
else
    # Install python2 for dpdk bonding
    yum -y install python

    # Install netperf
    netperf=netperf-2.6.0
    wget http://lacrosse.corp.redhat.com/~haliu/${netperf}.tar.gz -O /tmp/${netperf}.tar.gz
    tar zxvf /tmp/${netperf}.tar.gz
    pushd ${netperf}
    # add support for IBM new system arch ppc64le
    sed -i "/ppc64/i\ppc64le:Linux:*:*)\n\ echo powerpc64le-unknown-linux-gnu\n\ exit ;;" config.guess
    ./configure && make && make install
    popd

    # Install iperf
    IPERF_FILE="iperf-2.0.5.tar.gz"
    wget http://lacrosse.corp.redhat.com/~haliu/${IPERF_FILE}
    tar xf ${IPERF_FILE}
    BUILD_DIR="${IPERF_FILE%.tar.gz}"
    cd ${BUILD_DIR}
    # add support for IBM new system arch ppc64le
    sed -i "/ppc64/i\ppc64le:Linux:*:*)\n\ echo powerpc64le-unknown-linux-gnu\n\ exit ;;" config.guess
    ./configure && make && make install
    cd ..

    #Cleanup directories
    rm -f ${IPERF_FILE}
    rm -Rf IPERF*
    rm -f ${netperf}.tar.gz
    rm -Rf netperf*
fi

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

