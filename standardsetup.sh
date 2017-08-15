#!/usr/bin/env bash

# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k sts=4 sw=4 et
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/vsperf/install
#   Description: do vsperf install test
#   Author: Ting Li <tli@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2016 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Detect OS name and version from systemd based os-release file
. /etc/os-release

# Get OS name (the First word from $NAME in /etc/os-release)
OS_NAME="$VERSION_ID"

set -x
QEMU_FILE="/root/vswitchperf/vnfs/qemu/qemu.py"
TESTCASE_FILE="/root/vswitchperf/testcases/testcase.py"

# To speed up the download of guest images you can select your location below
QCOW_LOC="Westford"
#QCOW_LOC="China"

# settings to change if needed
# OVS folder to install from
ovs_folder="~/ovs2708/*.rpm"

# DPDK folder to install on host
dpdk_folder="~/dpdk1611/*.rpm"

# tuned profile folder
tuned_folder="~/tuned_profiles28"

# XENA Info
xena_ip="10.19.15.19"
xena_module="3"

# NICs to use in VSPerf
HOSTNAME=`hostname | awk -F'.' '{print $1}'`
if [ "$HOSTNAME" == "netqe22" ]
    then
    NIC1="p6p1"
    NIC2="p6p2"
    PMDMASK="050000050000"
    PMDMASK2Q="055000055000"
    PMDMASK4Q="055000055000"
elif [ "$HOSTNAME" == "netqe15" ]
    then
    NIC1="p2p1"
    NIC2="p2p2"
    PMDMASK="aa00"
    PMDMASK2Q="aa00"
    PMDMASK4Q="aa00"
elif [ "$HOSTNAME" == "netqe23" ]
    then
    NIC1="p6p1"
    NIC2="p6p2"
    PMDMASK="500000000500000000"
    PMDMASK2Q="550000000550000000"
    PMDMASK4Q="555500000555500000"
else
    echo "Please setup this system with this script...."
    exit 1
fi

NIC1_PCI_ADDR=`ethtool -i $NIC1 | grep -Eo '[0-9]+:[0-9]+:[0-9]+\.[0-9]+'`
NIC2_PCI_ADDR=`ethtool -i $NIC2 | grep -Eo '[0-9]+:[0-9]+:[0-9]+\.[0-9]+'`
NICNUMA=`cat /sys/class/net/$NIC1/device/numa_node`

# Isolated CPU list
ISOLCPUS=`lscpu | grep "NUMA node$NICNUMA" | awk '{print $4}'`

if [ `echo $ISOLCPUS | awk /'^0,'/` ]
    then
    ISOLCPUS=`echo $ISOLCPUS | cut -c 3-`
fi


install_utilities() {
yum install -y wget nano ftp yum-utils git tuna openssl libpcap libvirt sysstat
}

install_mono_rpm() {
    #install mono rpm
    echo "start to install mono rpm..."
    rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
    yum-config-manager --add-repo http://download.mono-project.com/repo/centos/
    yum -y install mono-complete
    yum-config-manager --disable download.mono-project.com_repo_centos_
}

Copy_Xena2544() {
    echo "start to copy xena2544.exe to xena folder..."
    #copy xena2544.exe to the test machine
    HOST='10.19.17.65'
    USER='user1'
    PASSWD='xena'
    FILE='Xena2544.exe'

    wget --user="${USER}" --password="${PASSWD}" "ftp://${HOST}/${FILE}"
}

download_rpms() {
if [ "$QCOW_LOC" == "China" ]
    then
    SERVER="download.eng.pnq.redhat.com"
elif [ "$QCOW_LOC" == "Westford" ]
    then
    SERVER="download-node-02.eng.bos.redhat.com"
fi

# these need to be changed to by dynamic based on the beaker recipe
echo "start to install ovs rpm in host"
cd ~
mkdir ovs2613 ovs2708 dpdk1607 dpdk1611 qemu2301 tuned_profiles27 tuned_profiles28
wget http://$SERVER/brewroot/packages/openvswitch/2.6.1/3.git20161206.el7fdb/x86_64/openvswitch-2.6.1-3.git20161206.el7fdb.x86_64.rpm -P ~/ovs2613/.
wget http://$SERVER/brewroot/packages/dpdk/16.07/1.el7fdb/x86_64/dpdk-16.07-1.el7fdb.x86_64.rpm -P ~/dpdk1607/.
wget http://$SERVER/brewroot/packages/dpdk/16.07/1.el7fdb/x86_64/dpdk-tools-16.07-1.el7fdb.x86_64.rpm -P ~/dpdk1607/.
wget http://$SERVER/brewroot/packages/dpdk/16.11/5.el7fdb/x86_64/dpdk-16.11-5.el7fdb.x86_64.rpm -P ~/dpdk1611/.
wget http://$SERVER/brewroot/packages/dpdk/16.11/5.el7fdb/x86_64/dpdk-tools-16.11-5.el7fdb.x86_64.rpm -P ~/dpdk1611/.
wget http://$SERVER/brewroot/packages/tuned/2.7.1/5.el7fdb/noarch/tuned-2.7.1-5.el7fdb.noarch.rpm -P ~/tuned_profiles27/.
wget http://$SERVER/brewroot/packages/tuned/2.7.1/5.el7fdb/noarch/tuned-profiles-cpu-partitioning-2.7.1-5.el7fdb.noarch.rpm -P ~/tuned_profiles27/.
wget http://$SERVER/brewroot/packages/tuned/2.7.1/5.el7fdb/noarch/tuned-profiles-nfv-2.7.1-5.el7fdb.noarch.rpm -P ~/tuned_profiles27/.
wget http://$SERVER/brewroot/packages/tuned/2.7.1/5.el7fdb/noarch/tuned-profiles-realtime-2.7.1-5.el7fdb.noarch.rpm -P ~/tuned_profiles27/.
wget http://$SERVER/brewroot/packages/tuned/2.8.0/2.el7fdp/noarch/tuned-2.8.0-2.el7fdp.noarch.rpm -P ~/tuned_profiles28/.
wget http://$SERVER/brewroot/packages/tuned/2.8.0/2.el7fdp/noarch/tuned-profiles-cpu-partitioning-2.8.0-2.el7fdp.noarch.rpm -P ~/tuned_profiles28/.
wget http://$SERVER/brewroot/packages/tuned/2.8.0/2.el7fdp/noarch/tuned-profiles-nfv-2.8.0-2.el7fdp.noarch.rpm -P ~/tuned_profiles28/.
wget http://$SERVER/brewroot/packages/tuned/2.8.0/2.el7fdp/noarch/tuned-profiles-realtime-2.8.0-2.el7fdp.noarch.rpm -P ~/tuned_profiles28/.
wget http://$SERVER/brewroot/packages/openvswitch/2.7.0/8.git20170530.el7fdb/x86_64/openvswitch-2.7.0-8.git20170530.el7fdb.x86_64.rpm -P ~/ovs2708/.
rpm -ivh http://$SERVER/brewroot/packages/driverctl/0.95/1.el7fdparch/noarch/driverctl-0.95-1.el7fdparch.noarch.rpm
#rpm -ivh $ovs_folder
#rpm -ivh $dpdk_folder
rpm -Uvh $tuned_folder/tuned-2.8.0-2.el7fdp.noarch.rpm
rpm -ivh $tuned_folder/tuned-profiles-cpu-partitioning-2.8.0-2.el7fdp.noarch.rpm
yum install -y qemu-kvm-rhev
#rpm -Uvh ~/qemu_2.9/qemu-kvm-common-rhev-2.9.0-10.el7.x86_64.rpm
#rpm -Uvh ~/qemu_2.9/qemu-kvm-rhev-2.9.0-10.el7.x86_64.rpm
#rpm -Uvh ~/qemu_2.9/qemu-kvm-tools-rhev-2.9.0-10.el7.x86_64.rpm
#rpm -Uvh ~/qemu_2.9/qemu-img-rhev-2.9.0-10.el7.x86_64.rpm

}

configure_hugepages() {
#config the hugepage
sed -i 's/\(GRUB_CMDLINE_LINUX.*\)"$/\1/g' /etc/default/grub
sed -i "s/GRUB_CMDLINE_LINUX.*/& nohz=on default_hugepagesz=1G hugepagesz=1G hugepages=24 intel_iommu=on iommu=pt \"/g" /etc/default/grub
echo -e "isolated_cores=$ISOLCPUS" >> /etc/tuned/cpu-partitioning-variables.conf
tuned-adm profile cpu-partitioning
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot
}

add_yum_profiles() {

cat <<EOT >> /etc/yum.repos.d/osp8-rhel.repo
[osp8-rhel7]
name=osp8-rhel7
baseurl=http://download.lab.bos.redhat.com/rel-eng/OpenStack/8.0-RHEL-7/latest/RH7-RHOS-8.0/x86_64/os/
enabled=1
gpgcheck=0
skip_if_unavailable=1
EOT

cat <<EOT >> /etc/yum.repos.d/tuned.repo
[tuned]
name=Tuned development repository for RHEL-7
baseurl=https://fedorapeople.org/~jskarvad/tuned/devel/repo/
enabled=1
gpgcheck=0
EOT

cat <<EOT >> /etc/yum.repos.d/rt.repo
[rhel72-nightly-rt]
name=RHEL7.2 nightly RT
baseurl=http://download.eng.bos.redhat.com/composes/latest-RHEL7/compose/Server-RT/x86_64/os/
enabled=0
gpgcheck=0
skip_if_unavailable=1
EOT

}

download_vnf_image() {

echo "start to down load vnf image..."
# down load the rhel image for guest
if [ "$QCOW_LOC" == "China" ]
    then
    SERVER="http://netqe-bj.usersys.redhat.com/share/vms"
elif [ "$QCOW_LOC" == "Westford" ]
    then
    SERVER="http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vm"
fi

wget -P ~/ $SERVER/rhel7.3-vsperf-1Q.qcow2 >/dev/null 2>&1
wget -P ~/ $SERVER/rhel7.3-vsperf-2Q.qcow2 >/dev/null 2>&1
wget -P ~/ $SERVER/rhel7.3-vsperf-4Q.qcow2 >/dev/null 2>&1
wget -P ~/ $SERVER/rhel73-rt.qcow2 >/dev/null 2>&1
wget -P ~/ $SERVER/rhel73-rt.xml >/dev/null 2>&1
wget -P ~/ $SERVER/rhel7.4-vsperf.qcow2 >/dev/null 2>&1

}

create_irq_script() {
touch ~/affinity.sh
cat <<'EOT' > ~/affinity.sh
#!/bin/bash
MASK=1 # core0 only
for I in `ls -d /proc/irq/[0-9]*` ; do echo $MASK > ${I}/smp_affinity ; done
echo $MASK > /proc/irq/default_smp_affinity
EOT
chmod +x ~/affinity.sh
}

color_mod() {
echo -e "LS_COLORS='rs=0:di=01;32:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.axa=00;36:*.oga=00;36:*.spx=00;36:*.xspf=00;36:';" >> ~/.bashrc
echo -e "export LS_COLORS" >> ~/.bashrc
}

create_bind_script() {

touch ~/bind.sh
cat <<EOT > ~/bind.sh
#!/bin/bash
set -x

setenforce permissive
modprobe vfio-pci
modprobe vfio

dpdk-devbind -b vfio-pci $NIC1_PCI_ADDR
sleep 3
dpdk-devbind -b vfio-pci $NIC2_PCI_ADDR
sleep 3

EOT
chmod +x ~/bind.sh

touch ~/binddrv.sh
cat <<EOT > ~/binddrv.sh
#!/bin/bash
set -x

setenforce permissive
modprobe vfio-pci
modprobe vfio

driverctl -v set-override $NIC1_PCI_ADDR vfio-pci
sleep 3
driverctl -v set-override $NIC2_PCI_ADDR vfio-pci
sleep 3

EOT
chmod +x ~/binddrv.sh
}


#main

create_other_scripts() {
touch ~/ovs-dpdk.sh
cat <<EOT > ~/ovs-dpdk.sh
set -x

setenforce permissive
modprobe openvswitch
systemctl stop openvswitch
sleep 3
systemctl start openvswitch
sleep 3

ovs-vsctl --if-exists del-br ovsbr0
sleep 5

ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl set Open_vSwitch . other_config={}
ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$PMDMASK
ovs-vsctl add-port ovsbr0 dpdk0 -- set interface dpdk0 type=dpdk ofport_request=10 options:dpdk-devargs=$NIC1_PCI_ADDR
ovs-vsctl add-port ovsbr0 dpdk1     -- set interface dpdk1 type=dpdk ofport_request=11 options:dpdk-devargs=$NIC2_PCI_ADDR
ovs-vsctl add-port ovsbr0 vhost0     -- set interface vhost0 type=dpdkvhostuser ofport_request=20
ovs-vsctl add-port ovsbr0 vhost1     -- set interface vhost1 type=dpdkvhostuser ofport_request=21

ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=10,idle_timeout=0,action=output:20
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=20,idle_timeout=0,action=output:10
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=21,idle_timeout=0,action=output:11
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=11,idle_timeout=0,action=output:21

chmod 777 /var/run/openvswitch/vhost0
chmod 777 /var/run/openvswitch/vhost1
EOT

touch ~/ovs-dpdk-2q.sh
cat <<EOT > ~/ovs-dpdk-2q.sh
set -x

setenforce permissive
modprobe openvswitch
systemctl stop openvswitch
sleep 3
systemctl start openvswitch
sleep 3

ovs-vsctl --if-exists del-br ovsbr0
sleep 5

ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl set Open_vSwitch . other_config={}
ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$PMDMASK2Q
ovs-vsctl add-port ovsbr0 dpdk0 -- set interface dpdk0 type=dpdk ofport_request=10 options:dpdk-devargs=$NIC1_PCI_ADDR options:n_rxq=2
ovs-vsctl add-port ovsbr0 dpdk1     -- set interface dpdk1 type=dpdk ofport_request=11 options:dpdk-devargs=$NIC2_PCI_ADDR options:n_rxq=2
ovs-vsctl add-port ovsbr0 vhost0     -- set interface vhost0 type=dpdkvhostuser ofport_request=20
ovs-vsctl add-port ovsbr0 vhost1     -- set interface vhost1 type=dpdkvhostuser ofport_request=21

ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=10,idle_timeout=0,action=output:20
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=20,idle_timeout=0,action=output:10
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=21,idle_timeout=0,action=output:11
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=11,idle_timeout=0,action=output:21

chmod 777 /var/run/openvswitch/vhost0
chmod 777 /var/run/openvswitch/vhost1
EOT

touch ~/ovs-dpdk-4q.sh
cat <<EOT > ~/ovs-dpdk-4q.sh
set -x

setenforce permissive
modprobe openvswitch
systemctl stop openvswitch
sleep 3
systemctl start openvswitch
sleep 3

ovs-vsctl --if-exists del-br ovsbr0
sleep 5

ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl set Open_vSwitch . other_config={}
ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$PMDMASK4Q
ovs-vsctl add-port ovsbr0 dpdk0 -- set interface dpdk0 type=dpdk ofport_request=10 options:dpdk-devargs=$NIC1_PCI_ADDR options:n_rxq=4
ovs-vsctl add-port ovsbr0 dpdk1     -- set interface dpdk1 type=dpdk ofport_request=11 options:dpdk-devargs=$NIC2_PCI_ADDR options:n_rxq=4
ovs-vsctl add-port ovsbr0 vhost0     -- set interface vhost0 type=dpdkvhostuser ofport_request=20
ovs-vsctl add-port ovsbr0 vhost1     -- set interface vhost1 type=dpdkvhostuser ofport_request=21

ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=10,idle_timeout=0,action=output:20
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=20,idle_timeout=0,action=output:10
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=21,idle_timeout=0,action=output:11
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=11,idle_timeout=0,action=output:21

chmod 777 /var/run/openvswitch/vhost0
chmod 777 /var/run/openvswitch/vhost1
EOT

touch ~/ovs-dpdk-vxlan.sh
cat <<EOT > ~/ovs-dpdk-vxlan.sh
set -x

setenforce permissive
modprobe openvswitch
systemctl stop openvswitch
sleep 3
systemctl start openvswitch
sleep 3

ovs-vsctl --if-exists del-br ovsbr0
sleep 5

ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl set Open_vSwitch . other_config={}
ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$PMDMASK
ovs-vsctl add-port ovsbr0 dpdk0 -- set interface dpdk0 type=dpdk ofport_request=10 options:dpdk-devargs=$NIC1_PCI_ADDR
ovs-vsctl add-port ovsbr0 vhost0     -- set interface vhost0 type=dpdkvhostuser ofport_request=20

chmod 777 /var/run/openvswitch/vhost0
EOT

touch ~/ovs-dpdk-vxlan.sh
cat <<EOT > ~/ovs-dpdk-vxlan-2q.sh
set -x

setenforce permissive
modprobe openvswitch
systemctl stop openvswitch
sleep 3
systemctl start openvswitch
sleep 3

ovs-vsctl --if-exists del-br ovsbr0
sleep 5

ovs-vsctl --if-exists del-br ovsbr0
ovs-vsctl --if-exists del-br ovsbr1
ovs-vsctl set Open_vSwitch . other_config={}
ovs-vsctl add-br ovsbr0 -- set bridge ovsbr0 datapath_type=netdev
ovs-vsctl add-br ovsbr1 -- set bridge ovsbr1 datapath_type=netdev
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,1024"
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=$PMDMASK
ovs-vsctl add-port ovsbr0 dpdk0 -- set interface dpdk0 type=dpdk ofport_request=10 options:n_rxq=2 options:dpdk-devargs=$NIC1_PCI_ADDR
ovs-vsctl add-port ovsbr1 vhost0     -- set interface vhost0 type=dpdkvhostuser ofport_request=20
ovs-vsctl add-port ovsbr1 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.9.106 options:dst_port=8472 options:key=1000 ofport_request=30
#ovs-vsctl add-port ovsbr1 geneve0 -- set interface geneve0 type=geneve options:remote_ip=192.168.9.106 options:dst_port=8472 options:key=1000
#ovs-vsctl add-port ovsbr1 gre0 -- set interface gre0 type=gre options:remote_ip=192.168.9.106 options:dst_port=8472 options:key=1000
testpmd -l 0,1,2 -n4 --socket-mem 1024,0 -- --burst=64 -i --txqflags=0xf00 --nb-cores=2 --rxq=4 --txq=4 --disable-hw-vlan --disable-rss

chmod 777 /var/run/openvswitch/vhost0

ip link set ovsbr0 up
ip addr add 192.168.9.105/24 dev ovsbr0
ip link set ovsbr1 up
ip addr add 192.168.19.105/24 dev ovsbr1
ip link set mtu 1450 dev ovsbr1
ovs-vsctl show
ip r
EOT

touch ~/guestbind.sh
cat <<EOT > ~/guestbind.sh
modprobe -r vfio
modprobe -r vfio_iommu_type1
modprobe vfio enable_unsafe_noiommu_mode=Y
modprobe vfio-pci

EOT

chmod +x ~/ovs-dpdk.sh
chmod +x ~/ovs-dpdk-2q.sh
chmod +x ~/ovs-dpdk-4q.sh
chmod +x ~/ovs-dpdk-vxlan.sh
chmod +x ~/ovs-dpdk-vxlan-2q.sh
chmod +x ~/guestbind.sh

}

create_guest_image() {

touch ~/guest30032.xml
cat <<EOT > ~/guest30032.xml
<domain type='kvm'>
  <name>guest30032</name>
  <uuid>37425e76-af6a-44a6-aba0-73434afe34c0</uuid>
  <memory unit='KiB'>4194304</memory>
  <currentMemory unit='KiB'>4194304</currentMemory>
  <memoryBacking>
    <hugepages>
      <page size='1048576' unit='KiB' nodeset='0'/>
    </hugepages>
    <access mode='shared'/>
  </memoryBacking>
  <vcpu placement='static'>3</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='4'/>
    <vcpupin vcpu='1' cpuset='6'/>
    <vcpupin vcpu='2' cpuset='30'/>
    <emulatorpin cpuset='4'/>
  </cputune>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc-i440fx-rhel7.2.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough'>
    <feature policy='require' name='tsc-deadline'/>
    <numa>
      <cell id='0' cpus='0-2' memory='4194304' unit='KiB' memAccess='shared'/>
    </numa>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/root/rhel7.3-vsperf-1Q.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </disk>
    <controller type='usb' index='0' model='ich9-ehci1'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x7'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci1'>
      <master startport='0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0' multifunction='on'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci2'>
      <master startport='2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci3'>
      <master startport='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </controller>
    <interface type='vhostuser'>
      <mac address='52:54:00:11:8f:e8'/>
      <source type='unix' path='/var/run/openvswitch/vhost0' mode='client'/>
      <model type='virtio'/>
      <driver name='vhost' queues='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x09' function='0x0'/>
    </interface>
    <interface type='vhostuser'>
      <mac address='52:54:00:11:8f:e9'/>
      <source type='unix' path='/var/run/openvswitch/vhost1' mode='client'/>
      <model type='virtio'/>
      <driver name='vhost' queues='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x08' function='0x0'/>
    </interface>
    <interface type='bridge'>
      <mac address='52:54:00:bb:63:7b'/>
      <source bridge='virbr0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='tablet' bus='usb'>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </memballoon>
  </devices>
  <seclabel type='dynamic' model='selinux' relabel='yes'/>
</domain>

EOT

systemctl start libvirtd
virsh define guest30032.xml
chmod 777 /root

touch ~/guest30032Van.xml
cat <<EOT > ~/guest30032Van.xml
<domain type='kvm' id='1'>
  <name>guest30032</name>
  <uuid>37425e76-af6a-44a6-aba0-73434afe34c0</uuid>
  <memory unit='KiB'>4194304</memory>
  <currentMemory unit='KiB'>4194304</currentMemory>
  <memoryBacking>
    <hugepages>
      <page size='1048576' unit='KiB' nodeset='0'/>
    </hugepages>
    <access mode='shared'/>
  </memoryBacking>
  <vcpu placement='static'>3</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='4'/>
    <vcpupin vcpu='1' cpuset='6'/>
    <vcpupin vcpu='2' cpuset='30'/>
    <emulatorpin cpuset='4'/>
  </cputune>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc-i440fx-rhel7.3.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none'>
    <feature policy='require' name='tsc-deadline'/>
    <numa>
      <cell id='0' cpus='0-2' memory='4194304' unit='KiB' memAccess='shared'/>
    </numa>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/root/rheltest.qcow2'/>
      <backingStore/>
      <target dev='vda' bus='virtio'/>
      <alias name='virtio-disk0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </disk>
    <controller type='usb' index='0' model='ich9-ehci1'>
      <alias name='usb'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x7'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci1'>
      <alias name='usb'/>
      <master startport='0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0' multifunction='on'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci2'>
      <alias name='usb'/>
      <master startport='2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci3'>
      <alias name='usb'/>
      <master startport='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'>
      <alias name='pci.0'/>
    </controller>
    <controller type='virtio-serial' index='0'>
      <alias name='virtio-serial0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </controller>
    <interface type='bridge'>
      <mac address='52:54:00:11:8f:e8'/>
      <source bridge='ovsbr0'/>
      <virtualport type='openvswitch'>
        <parameters interfaceid='f54fd445-25b0-4231-8ea7-b83f2a1f8df2'/>
      </virtualport>
      <target dev='tap0'/>
      <model type='virtio'/>
      <alias name='net0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x09' function='0x0'/>
    </interface>
    <interface type='bridge'>
      <mac address='52:54:00:11:8f:e9'/>
      <source bridge='ovsbr0'/>
      <virtualport type='openvswitch'>
        <parameters interfaceid='da83fecb-ae41-4a6f-aaff-5517c5e44337'/>
      </virtualport>
      <target dev='tap1'/>
      <model type='virtio'/>
      <alias name='net1'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x08' function='0x0'/>
    </interface>
    <interface type='bridge'>
      <mac address='52:54:00:bb:63:7b'/>
      <source bridge='virbr0'/>
      <target dev='vnet0'/>
      <model type='virtio'/>
      <alias name='net2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <source path='/dev/pts/1'/>
      <target port='0'/>
      <alias name='serial0'/>
    </serial>
    <console type='pty' tty='/dev/pts/1'>
      <source path='/dev/pts/1'/>
      <target type='serial' port='0'/>
      <alias name='serial0'/>
    </console>
    <channel type='unix'>
      <source mode='bind' path='/var/lib/libvirt/qemu/channel/target/domain-1-guest30032/org.qemu.guest_agent.0'/>
      <target type='virtio' name='org.qemu.guest_agent.0' state='connected'/>
      <alias name='channel0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='tablet' bus='usb'>
      <alias name='input0'/>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'>
      <alias name='input1'/>
    </input>
    <input type='keyboard' bus='ps2'>
      <alias name='input2'/>
    </input>
    <graphics type='vnc' port='5900' autoport='yes' listen='0.0.0.0'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <alias name='video0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <alias name='balloon0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </memballoon>
  </devices>
  <seclabel type='dynamic' model='selinux' relabel='yes'>
    <label>system_u:system_r:svirt_t:s0:c323,c846</label>
    <imagelabel>system_u:object_r:svirt_image_t:s0:c323,c846</imagelabel>
  </seclabel>
  <seclabel type='dynamic' model='dac' relabel='yes'>
    <label>+107:+107</label>
    <imagelabel>+107:+107</imagelabel>
  </seclabel>
</domain>
EOT

cat <<EOT > ~/guest30033.xml
<domain type='kvm'>
  <name>guest30033</name>
  <uuid>37425e76-af6a-44a6-aba0-73434afe34c1</uuid>
  <memory unit='KiB'>4194304</memory>
  <currentMemory unit='KiB'>4194304</currentMemory>
  <memoryBacking>
    <hugepages>
      <page size='1048576' unit='KiB' nodeset='0'/>
    </hugepages>
    <access mode='shared'/>
  </memoryBacking>
  <vcpu placement='static'>3</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='28'/>
    <vcpupin vcpu='1' cpuset='8'/>
    <vcpupin vcpu='2' cpuset='32'/>
    <emulatorpin cpuset='28'/>
  </cputune>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc-i440fx-rhel7.2.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough'>
    <feature policy='require' name='tsc-deadline'/>
    <numa>
      <cell id='0' cpus='0-2' memory='4194304' unit='KiB' memAccess='shared'/>
    </numa>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/root/rhel7.3-vsperf-1Q.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </disk>
    <controller type='usb' index='0' model='ich9-ehci1'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x7'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci1'>
      <master startport='0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0' multifunction='on'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci2'>
      <master startport='2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci3'>
      <master startport='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </controller>
    <interface type='vhostuser'>
      <mac address='52:54:00:11:8f:ea'/>
      <source type='unix' path='/var/run/openvswitch/vhost2' mode='client'/>
      <model type='virtio'/>
      <driver name='vhost'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x09' function='0x0'/>
    </interface>
    <interface type='vhostuser'>
      <mac address='52:54:00:11:8f:eb'/>
      <source type='unix' path='/var/run/openvswitch/vhost3' mode='client'/>
      <model type='virtio'/>
      <driver name='vhost'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x08' function='0x0'/>
    </interface>
    <interface type='bridge'>
      <mac address='52:54:00:bb:63:7c'/>
      <source bridge='virbr0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='tablet' bus='usb'>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </memballoon>
  </devices>
  <seclabel type='dynamic' model='selinux' relabel='yes'/>
</domain>
EOT


}

modify_xena_profile() {

sed -i 's/"LearningDuration": 5000.0/"LearningDuration": 180000.0/g' /root/vswitchperf/tools/pkt_gen/xena/profiles/baseconfig.x2544

}

install_utilities
add_yum_profiles
download_rpms
install_mono_rpm
Copy_Xena2544
#create_irq_script
download_vnf_image
color_mod
create_bind_script
create_other_scripts
create_guest_image
configure_hugepages
