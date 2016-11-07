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

GUEST_IMAGE="7.3"

# settings to change if needed
# OVS folder to install from
ovs_folder="~/ovs2517/*.rpm"

# DPDK folder to install on host
dpdk_folder="~/dpdk1607/*.rpm"

# XENA Info
xena_ip="10.19.15.19"
xena_module="3"

# Isolated CPU list
ISOLCPUS='2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,46'

# NICs to use in VSPerf
NIC1="p6p1"
NIC2="p6p2"

install_utilities() {
yum install -y wget nano ftp yum-utils git tuna
}

run_build_scripts() {

echo "start to run the build_base_machine.sh..."
cd ~/vswitchperf/systems
export VSPERFENV_DIR="$HOME/vsperfenv"
. "rhel/$OS_NAME/build_base_machine.sh" || exit 1
. "rhel/$OS_NAME/prepare_python_env.sh"
cd ~/vswitchperf

}

change_to_7_3() {

cd ~/vswitchperf/systems/rhel
mv 7.2 7.3

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
    mv Xena2544.exe ~/vswitchperf/tools/pkt_gen/xena/.
}

change_conf_file() {
rm ~/vswitchperf/conf/02_vswitch.conf

cat <<EOT >> ~/vswitchperf/conf/02_vswitch.conf
# Copyright 2015-2016 Intel Corporation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ############################
# DPDK configuration
# ############################

# DPDK target used when builing DPDK
RTE_TARGET = 'x86_64-native-linuxapp-gcc'

# list of NIC HWIDs to which traffic generator is connected
# In case of NIC with SRIOV suport, it is possible to define,
# which virtual function should be used
# e.g. value '0000:05:00.0|vf1' will configure two VFs and second VF
# will be used for testing
WHITELIST_NICS=["0000:03:00.0", "0000:03:00.1"]

# vhost character device file used by dpdkvhostport QemuWrap cases
VHOST_DEV_FILE = 'ovs-vhost-net'

# location of vhost-user sockets relative to 'ovs_var_tmp'
VHOST_USER_SOCKS = 'dpdkvhostuser*'

# ############################
# Directories
# ############################
VSWITCH_DIR = os.path.join(ROOT_DIR, 'vswitches')

# please see conf/00_common.conf for description of PATHS dictionary
# Every vswitch type supported by VSPERF must have its configuration
# stored inside PATHS['vswitch']. List of all supported vswitches
# can be obtained by call of ./vsperf --list-vswitches
#
# Directories defined by "ovs_var_tmp" and "ovs_etc_tmp" will be used
# by OVS to temporarily store its configuration, pid and socket files.
# In case, that these directories exist already, then their original
# content will be restored after the testcase execution.

# ############################
# vswitch configuration
# ############################
# These are DPDK EAL parameters and they may need to be changed depending on
# hardware configuration, like cpu numbering and NUMA.
#
# parameters used for legacy DPDK configuration through '--dpdk' option of ovs-vswitchd
# e.g. ovs-vswitchd --dpdk --socket-mem 1024,0
VSWITCHD_DPDK_ARGS = ['-c', '0x4', '-n', '4', '--socket-mem 1024,1024']

# options used for new type of OVS configuration via calls to ovs-vsctl
# e.g. ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024,0"
VSWITCHD_DPDK_CONFIG = {
    'dpdk-init' : 'true',
    'dpdk-lcore-mask' : '0x4',
    'dpdk-socket-mem' : '1024,1024',
}
# Note: VSPERF will automatically detect, which type of DPDK configuration should
# be used.

# To enable multi queue with dpdk modify the below param to the number of
# queues for dpdk. 0 = disabled
VSWITCH_DPDK_MULTI_QUEUES = 0

# Use old style OVS DPDK Multi-queue startup. If testing versions of OVS 2.5.0
# or before, enable this setting to allow DPDK Multi-queue to enable correctly.
OVS_OLD_STYLE_MQ = True

# parameters passed to ovs-vswitchd in case that OvsVanilla is selected
VSWITCHD_VANILLA_ARGS = []

# Bridge name to be used by VSWTICH
VSWITCH_BRIDGE_NAME = 'br0'

# directory where hugepages will be mounted on system init
HUGEPAGE_DIR = '/dev/hugepages'

# If no hugepages are available, try to allocate HUGEPAGE_RAM_ALLOCATION.
# Default is 10 GB.
# 10 GB (10485760 kB) or more is recommended for PVP & PVVP testing scenarios.
HUGEPAGE_RAM_ALLOCATION = 10485760

# Sets OVS PMDs core mask to 30 for affinitization to 5th and 6th CPU core.
# Note that the '0x' notation should not be used.
VSWITCH_PMD_CPU_MASK = '440000440000'
VSWITCH_AFFINITIZATION_ON = 1

VSWITCH_FLOW_TIMEOUT = '30000'

# log file for ovs-vswitchd
LOG_FILE_VSWITCHD = 'vswitchd.log'

# log file for ovs-dpdk
LOG_FILE_OVS = 'ovs.log'

# default vswitch implementation
VSWITCH = "OvsDpdkVhost"
PATHS['dpdk'] = {
        'type' : 'bin',
        'src': {
            'path': os.path.join(ROOT_DIR, 'src/dpdk/dpdk/'),
            # To use vfio set:
            'modules' : ['uio', 'vfio-pci'],
            #'modules' : ['uio', os.path.join(RTE_TARGET, 'kmod/igb_uio.ko')],
            'bind-tool': 'tools/dpdk*bind.py',
            'testpmd': os.path.join(RTE_TARGET, 'app', 'testpmd'),
        },
    'bin': {
            'bind-tool': '/usr/share/dpdk/tools/dpdk-devbind.py',
            'modules' : ['vfio-pci'],
            'testpmd' : 'testpmd'
        }
    }

PATHS['vswitch'] = {
    'none' : {      # used by SRIOV tests
        'type' : 'src',
        'src' : {},
    },
    'OvsDpdkVhost': {
        'type' : 'bin',
        'src': {
            'path': os.path.join(ROOT_DIR, 'src/ovs/ovs/'),
            'ovs-vswitchd': 'vswitchd/ovs-vswitchd',
            'ovsdb-server': 'ovsdb/ovsdb-server',
            'ovsdb-tool': 'ovsdb/ovsdb-tool',
            'ovsschema': 'vswitchd/vswitch.ovsschema',
            'ovs-vsctl': 'utilities/ovs-vsctl',
            'ovs-ofctl': 'utilities/ovs-ofctl',
            'ovs-dpctl': 'utilities/ovs-dpctl',
            'ovs-appctl': 'utilities/ovs-appctl',
        },
    'bin': {
            'ovs-vswitchd': 'ovs-vswitchd',
            'ovsdb-server': 'ovsdb-server',
            'ovsdb-tool': 'ovsdb-tool',
            'ovsschema': '/usr/share/openvswitch/vswitch.ovsschema',
            'ovs-vsctl': 'ovs-vsctl',
            'ovs-ofctl': 'ovs-ofctl',
            'ovs-dpctl': 'ovs-dpctl',
            'ovs-appctl': 'ovs-appctl',
        }
    },
    'ovs_var_tmp': '/var/run/openvswitch/',
    'ovs_etc_tmp': '/etc/openvswitch/',
}

PATHS['vswitch'].update({'OvsVanilla' : copy.deepcopy(PATHS['vswitch']['OvsDpdkVhost'])})
PATHS['vswitch']['OvsVanilla']['src']['path'] = os.path.join(ROOT_DIR, 'src_vanilla/ovs/ovs/')
PATHS['vswitch']['OvsVanilla']['src']['modules'] = ['datapath/linux/openvswitch.ko']
PATHS['vswitch']['OvsVanilla']['bin']['modules'] = ['libcrc32c', 'ip_tunnel', 'vxlan', 'gre', 'nf_nat', 'nf_nat_ipv6', 'nf_nat_ipv4', 'nf_conntrack', 'nf_defrag_ipv4', 'nf_defrag_ipv6', '/usr/lib/modules/3.10.0-514.el7.x86_64/kernel/net/openvswitch/openvswitch.ko']
EOT

echo "start to change the redhat related conf..."
echo "detecting nic 1"
nic1pci=$(ethtool -i $NIC1 | grep bus-info | awk '{print $2}')
echo "detecting nic 2"
nic2pci=$(ethtool -i $NIC2 | grep bus-info | awk '{print $2}')
cd ~/vswitchperf

sed -i "/PATHS['dpdk'] = {/,+15 d" ~/vswitchperf/conf/02_vswitch.conf
sed -i "/PATHS['vswitch'] = {/,+31 d" ~/vswitchperf/conf/02_vswitch.conf
sed -i "/PATHS['vswitch']['OvsVanilla']['bin']['modules'] = ['openvswitch']/d" ~/vswitchperf/conf/02_vswitch.conf

sed -i '/RTE_TARGET/c\#RTE_TARGET=' conf/10_custom.conf
sed -i '/WHITELIST_NICS/c\WHITELIST_NICS=["'$nic1pci'", "'$nic2pci'"]' conf/02_vswitch.conf

kernel=$(uname -r)
echo -e "\nPATHS['vswitch']['OvsVanilla']['bin']['modules'] = ['libcrc32c', 'ip_tunnel', 'vxlan', 'gre', 'nf_nat', 'nf_nat_ipv6', 'nf_nat_ipv4', 'nf_conntrack', 'nf_defrag_ipv4', 'nf_defrag_ipv6', '/usr/lib/modules/$kernel/kernel/net/openvswitch/openvswitch.ko']\n" >> conf/02_vswitch.conf
}

setup_xena() {
echo -e "\nTRAFFICGEN_XENA_IP='${xena_ip}'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN_XENA_PORT1='0'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN_XENA_PORT2='1'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN_XENA_USER='vsperf'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN_XENA_PASSWORD='xena'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN_XENA_MODULE1='${xena_module}'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN_XENA_MODULE2='${xena_module}'" >> ~/vswitchperf/conf/10_custom.conf
echo -e "TRAFFICGEN = 'Xena'" >> ~/vswitchperf/conf/10_custom.conf
}

clone_vsperf() {

echo "start to clone vsperf project..."
cd ~
git clone https://gerrit.opnfv.org/gerrit/vswitchperf
cd vswitchperf
# because of the ever evolving code lets use the last stable commit that is known
# to work with this script. Only drawback is it puts you into a detached head state
git checkout 9b1af783ec53050129239102355e1a5c3ceb1d97
git fetch https://gerrit.opnfv.org/gerrit/vswitchperf refs/changes/95/20295/3 && git cherry-pick FETCH_HEAD
cd ~
}

download_rpms() {

# these need to be changed to by dynamic based on the beaker recipe
echo "start to install ovs rpm in host"
cd ~
mkdir ovs2505 ovs2510 ovs2514b ovs2514p ovs2517 dpdk220 dpdk1604 dpdk1607 qemu2301 tuned_profiles
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.5.0/5.git20160628.el7fdb/noarch/openvswitch-test-2.5.0-5.git20160628.el7fdb.noarch.rpm -P ~/ovs2505/.
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.5.0/14.git20160727.el7fdb/x86_64/openvswitch-2.5.0-14.git20160727.el7fdb.x86_64.rpm -P ~/ovs2514b/.
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.5.0/14.git20160727.el7fdp/x86_64/openvswitch-2.5.0-14.git20160727.el7fdp.x86_64.rpm -P ~/ovs2514p/.
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.5.0/17.git20160727.el7fdb/x86_64/openvswitch-2.5.0-17.git20160727.el7fdb.x86_64.rpm -P ~/ovs2517/.
wget http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/2.2.0/3.el7/x86_64/dpdk-2.2.0-3.el7.x86_64.rpm -P ~/dpdk220/.
wget http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/2.2.0/3.el7/x86_64/dpdk-tools-2.2.0-3.el7.x86_64.rpm -P ~/dpdk220/.
wget http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/16.04/4.el7fdb/x86_64/dpdk-16.04-4.el7fdb.x86_64.rpm -P ~/dpdk1604/.
wget http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/16.04/4.el7fdb/x86_64/dpdk-tools-16.04-4.el7fdb.x86_64.rpm -P ~/dpdk1604/.
wget http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/16.07/1.el7fdb/x86_64/dpdk-16.07-1.el7fdb.x86_64.rpm -P ~/dpdk1607/.
wget http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/16.07/1.el7fdb/x86_64/dpdk-tools-16.07-1.el7fdb.x86_64.rpm -P ~/dpdk1607/.
yum  install -y qemu-kvm*
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/tuned/2.7.1/4.el7fdb/noarch/tuned-2.7.1-4.el7fdb.noarch.rpm -P ~/tuned_profiles/.
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/tuned/2.7.1/4.el7fdb/noarch/tuned-profiles-cpu-partitioning-2.7.1-4.el7fdb.noarch.rpm -P ~/tuned_profiles/.
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/tuned/2.7.1/4.el7fdb/noarch/tuned-profiles-nfv-2.7.1-4.el7fdb.noarch.rpm -P ~/tuned_profiles/.
wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/tuned/2.7.1/4.el7fdb/noarch/tuned-profiles-realtime-2.7.1-4.el7fdb.noarch.rpm -P ~/tuned_profiles/.

rpm -ivh $ovs_folder
rpm -ivh $dpdk_folder
rpm -Uvh ~/tuned_profiles/tuned-2.7.1-4.el7fdb.noarch.rpm
rpm -ivh ~/tuned_profiles/tuned-profiles-realtime-2.7.1-4.el7fdb.noarch.rpm
rpm -ivh ~/tuned_profiles/tuned-profiles-nfv-2.7.1-4.el7fdb.noarch.rpm
rpm -ivh ~/tuned_profiles/tuned-profiles-cpu-partitioning-2.7.1-4.el7fdb.noarch.rpm

}

configure_hugepages() {
#config the hugepage
sed -i 's/\(GRUB_CMDLINE_LINUX.*\)"$/\1/g' /etc/default/grub
sed -i "s/GRUB_CMDLINE_LINUX.*/& nohz=on default_hugepagesz=1G hugepagesz=1G hugepages=24 intel_iommu=on iommu=pt\"/g" /etc/default/grub
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

modify_vnf_conf() {

rm -f /root/vswitchperf/conf/04_vnf.conf

cat <<EOT >> /root/vswitchperf/conf/04_vnf.conf
# Copyright 2015-2016 Intel Corporation.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ############################
# VNF configuration
# ############################
VNF_DIR = 'vnfs/'
VNF = 'QemuDpdkVhostUser'
VNF_AFFINITIZATION_ON = True

# ############################
# Directories, executables and log files
# ############################

# please see conf/00_common.conf for description of PATHS dictionary
PATHS['qemu'] = {
        'type' : 'bin',
        'src': {
        'path': os.path.join(ROOT_DIR, 'src/qemu/qemu/'),
            'qemu-system': 'x86_64-softmmu/qemu-system-x86_64'
        },
	'bin': {
        'qemu-system': '/usr/libexec/qemu-kvm'
        }
    }

# log file for qemu
LOG_FILE_QEMU = 'qemu.log'

# log file for all commands executed on guest(s)
# multiple guests will result in log files with the guest number appended
LOG_FILE_GUEST_CMDS = 'guest-cmds.log'

# ############################
# Guest configuration
# ############################
# All configuration options related to a particular VM instance are defined as
# lists and prefixed with `GUEST_` label. It is essential, that there is enough
# items in all `GUEST_` options to cover all VM instances involved in the test.
# In case there is not enough items, then VSPERF will use the first item of
# particular `GUEST_` option to expand the list to required length. First option
# can contain macros starting with `#` to generate VM specific values. These
# macros can be used only for options of `list` or `str` types with `GUEST_`
# prefix.
# Following macros are supported:
#
# * #VMINDEX - it is replaced by index of VM being executed; This macro is
#   expanded first, so it can be used inside other macros.
#
# * #MAC(mac_address[, step]) - it will iterate given `mac_address` with
#   optional `step`. In case that step is not defined, then it is set to 1.
#   It means, that first VM will use the value of `mac_address`, second VM
#   value of `mac_address` increased by `step`, etc.
#
# * #IP(ip_address[, step]) - it will iterate given `ip_address` with optional
#   step. In case that step is not defined, then it is set to 1.
#   It means, that first VM will use the value of `ip_address`, second VM
#   value of `ip_address` increased by `step`, etc.
#
# * #EVAL(expression) - it will evaluate given `expression` as python code;
#   Only simple expressions should be used. Call of the functions is not
#   supported.
GUEST_IMAGE = ['rhel7.3-vsperf.qcow2', 'rhel7.3-vsperf.qcow2']

# guarding timer for VM start up
# For 2 VNFs you may use [180, 180]
GUEST_TIMEOUT = [180]

# Guest images may require different drive types such as ide to mount shared
# locations and/or boot correctly. You can modify the types here.
GUEST_BOOT_DRIVE_TYPE = ['ide']
GUEST_SHARED_DRIVE_TYPE = ['ide']

# packet forwarding mode supported by testpmd; Please see DPDK documentation
# for comprehensive list of modes supported by your version.
# e.g. io|mac|mac_retry|macswap|flowgen|rxonly|txonly|csum|icmpecho|...
# Note: Option "mac_retry" has been changed to "mac retry" since DPDK v16.07
GUEST_TESTPMD_FWD_MODE = 'csum'

# guest loopback application method; supported options are:
#       'testpmd'       - testpmd from dpdk will be built and used
#       'l2fwd'         - l2fwd module provided by Huawei will be built and used
#       'linux_bridge'  - linux bridge will be configured
#       'buildin'       - nothing will be configured by vsperf; VM image must
#                         ensure traffic forwarding between its interfaces
# This configuration option can be overridden by CLI SCALAR option
# guest_loopback, e.g. --test-params "guest_loopback=l2fwd"
# For 2 VNFs you may use ['testpmd', 'l2fwd']
GUEST_LOOPBACK = ['testpmd']

# username for guest image
GUEST_USERNAME = ['root']

# password for guest image
GUEST_PASSWORD = ["redhat"]

# login username prompt for guest image
GUEST_PROMPT_LOGIN = ['.* login:']

# login password prompt for guest image
GUEST_PROMPT_PASSWORD = ['Password: ']

# standard prompt for guest image
GUEST_PROMPT = ['root.*#']

# defines the number of NICs configured for each guest, it must be less or equal to
# the number of NICs configured in GUEST_NICS
GUEST_NICS_NR = [2]

# template for guests with 4 NICS, but only GUEST_NICS_NR NICS will be configured at runtime
GUEST_NICS = [[{'device' : 'eth0', 'mac' : '#MAC(00:00:00:00:00:01,2)', 'pci' : '00:03.0', 'ip' : '#IP(192.168.1.2,4)/24'},
               {'device' : 'eth1', 'mac' : '#MAC(00:00:00:00:00:02,2)', 'pci' : '00:04.0', 'ip' : '#IP(192.168.1.3,4)/24'},
               {'device' : 'eth2', 'mac' : '#MAC(cc:00:00:00:00:01,2)', 'pci' : '00:06.0', 'ip' : '#IP(192.168.1.4,4)/24'},
               {'device' : 'eth3', 'mac' : '#MAC(cc:00:00:00:00:02,2)', 'pci' : '00:07.0', 'ip' : '#IP(192.168.1.5,4)/24'},
             ]]

# amount of host memory allocated for each guest
GUEST_MEMORY = ['4096']
# number of hugepages configured inside each guest
GUEST_HUGEPAGES_NR = ['1']

# test-pmd requires 2 VM cores
GUEST_SMP = ['3']

# Host cores to use to affinitize the SMP cores of a QEMU instance
# For 2 VNFs you may use [(4,5), (6, 7)]
GUEST_CORE_BINDING = [('4', '6', '28', '8', '30')]

# Queues per NIC inside guest for multi-queue configuration, requires switch
# multi-queue to be enabled for dpdk. Set to 0 for disabled. Can be enabled if
# using Vanilla OVS without enabling switch multi-queue.
GUEST_NIC_QUEUES = [0]

# Disable VHost user guest NIC merge buffers by enabling the below setting. This
# can improve performance when not using Jumbo Frames.
GUEST_NIC_MERGE_BUFFERS_DISABLE = [True]

# Virtio-Net vhost thread CPU mapping. If using  vanilla OVS with virtio-net,
# you can affinitize the vhost-net threads by enabling the below setting. There
# is one vhost-net thread per port per queue so one guest with 2 queues will
# have 4 vhost-net threads. If more threads are present than CPUs given, the
# affinitize will overlap CPUs in a round robin fashion.
VSWITCH_VHOST_NET_AFFINITIZATION = False
VSWITCH_VHOST_CPU_MAP = [4,5,8,11]

GUEST_START_TIMEOUT = [120]
GUEST_OVS_DPDK_DIR = ['/root/ovs_dpdk']
GUEST_OVS_DPDK_SHARE = ['/mnt/ovs_dpdk_share']

# IP addresses to use for Vanilla OVS PXP testing
# Consider using RFC 2544/3330 recommended IP addresses for benchmark testing.
# Network: 198.18.0.0/15
# Netmask: 255.254.0.0
# Broadcast: 198.19.255.255
# First IP: 198.18.0.1
# Last IP: 198.19.255.254
# Hosts: 131070
#

# ARP entries for the IXIA ports and the bridge you are using:
VANILLA_TGEN_PORT1_IP = '1.1.1.10'
VANILLA_TGEN_PORT1_MAC = 'AA:BB:CC:DD:EE:FF'

VANILLA_TGEN_PORT2_IP = '1.1.2.10'
VANILLA_TGEN_PORT2_MAC = 'AA:BB:CC:DD:EE:F0'

GUEST_BRIDGE_IP = ['#IP(1.1.1.5)/16']

# ############################
# Guest TESTPMD configuration
# ############################

# packet forwarding mode supported by testpmd; Please see DPDK documentation
# for comprehensive list of modes supported by your version.
# e.g. io|mac|mac_retry|macswap|flowgen|rxonly|txonly|csum|icmpecho|...
# Note: Option "mac_retry" has been changed to "mac retry" since DPDK v16.07
GUEST_TESTPMD_FWD_MODE = ['csum']

# Set the CPU mask for testpmd loopback. To bind to specific guest CPUs use -l
GUEST_TESTPMD_CPU_MASK = ['-l 0,1,2']
#GUEST_TESTPMD_CPU_MASK = ['-c 0x3']

# Testpmd multi-core config. Leave at 0's for disabled. Will not enable unless
# GUEST_NIC_QUEUES are > 0. For bi directional traffic NB_CORES must be equal
# to (RXQ + TXQ).
GUEST_TESTPMD_NB_CORES = [2]
GUEST_TESTPMD_TXQ = [1]
GUEST_TESTPMD_RXQ = [1]

EOT

}

modify_guest_rhel_common() {
echo "start to modify the code about the redhat guest..."
#modify the code to make the guest use the redhat kernel and rpms
sed -i "s/scsi/ide/g"  /root/vswitchperf/conf/04_vnf.conf

#modify the redhat guest password
sed -i '/GUEST_PASSWORD =/c\GUEST_PASSWORD = ["redhat"]' ~/vswitchperf/conf/04_vnf.conf

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

if [ "$OS_NAME" == "7.3" ]
    then
        wget -P ~/vswitchperf/ $SERVER/rhel7.3-vsperf.qcow2 >/dev/null 2>&1
    else
        wget -P ~/vswitchperf/ $SERVER/rhel7.2-vsperf.qcow2 >/dev/null 2>&1
fi
}

create_irq_script() {
touch /usr/share/dpdk/affinity.sh
cat <<'EOT' > /usr/share/dpdk/affinity.sh
#!/bin/bash
MASK=1 # core0 only
for I in `ls -d /proc/irq/[0-9]*` ; do echo $MASK > ${I}/smp_affinity ; done
echo $MASK > /proc/irq/default_smp_affinity
EOT
chmod +x /usr/share/dpdk/affinity.sh
}

qemu_modified_code() {
# VSPerf by default currently uses upstream bits to build uio_igb in place on
# the guest. We need to modify the qemu file so it will use vfio no iommu for 7.3
# and uio_pci_generic for 7.2. We do this by adding a modified testpmd method
# into the file. Working on a patch to allow for different modprobes and binds...
# We also make it so instead of building dpdk inside the guest from upstream,
# we install the rpms we used on the host.
# also turn of irqlabance and run the irq pinning to cpu 0 script

# remove drive sharing
sed -i "/                     '-drive',$/,+3 d" ~/vswitchperf/vnfs/qemu/qemu.py
sed -i "/self._copy_fwd_tools_for_all_guests()/c\#self._copy_fwd_tools_for_all_guests()" ~/vswitchperf/testcases/testcase.py

if [ "$OS_NAME" == "7.3" ]
then
cat <<EOT >> ~/vswitchperf/vnfs/qemu/qemu.py
    def _configure_testpmd(self):
        """
        Configure VM to perform L2 forwarding between NICs by DPDK's testpmd
        """
        self._configure_copy_sources('DPDK')
        self._configure_disable_firewall()

        # Guest images _should_ have 1024 hugepages by default,
        # but just in case:'''
        self.execute_and_wait('sysctl vm.nr_hugepages={}'.format(S.getValue('GUEST_HUGEPAGES_NR')[self._number]))

        # Mount hugepages
        self.execute_and_wait('mkdir -p /dev/hugepages')
        self.execute_and_wait(
            'mount -t hugetlbfs hugetlbfs /dev/hugepages')

        # build and configure system for dpdk
        self.execute_and_wait('cd ' + S.getValue('GUEST_OVS_DPDK_DIR')[self._number] +
                              '/DPDK')
        self.execute_and_wait('cat /proc/meminfo')
        self.execute_and_wait('rpm -ivh ~/1607/dpdk*.rpm ')
        self.execute_and_wait('modprobe -r vfio')
        self.execute_and_wait('modprobe -r vfio_iommu_type1')
        self.execute_and_wait("modprobe vfio enable_unsafe_noiommu_mode=Y")
        self.execute_and_wait("modprobe vfio-pci")
        self.execute_and_wait('systemctl stop irqlabance')
        self.execute_and_wait('./affinity.sh')
        self.execute_and_wait('tuna -Q')
        self.execute_and_wait('cat /proc/cmdline')
        self.execute_and_wait('./tools/dpdk*bind.py --status')

        # disable network interfaces, so DPDK can take care of them
        for nic in self._nics:
            self.execute_and_wait('ifdown ' + nic['device'])

        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py --status')
        pci_list = ' '.join([nic['pci'] for nic in self._nics])
        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py -u ' + pci_list)
        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py -b vfio-pci ' + pci_list)
        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py --status')
#        self.execute_and_wait('export LD_LIBRARY_PATH=/root/dpdk-16.07/x86_64-native-linuxapp-gcc/lib:${LD_LIBRARY_PATH}')
#        self.execute_and_wait('./dpdk_nic_bind.py -u ' + pci_list)
#        self.execute_and_wait('./dpdk_nic_bind.py -b vfio-pci ' + pci_list)
#        self.execute_and_wait('./dpdk_nic_bind.py --status')


        # build and run 'test-pmd'
#        self.execute_and_wait('cd ' + S.getValue('GUEST_OVS_DPDK_DIR')[self._number] +
#                              '/DPDK/app/test-pmd')
#        self.execute_and_wait('make clean')
#        self.execute_and_wait('make')
        list_string = ""
        for nic in pci_list.split():
            list_string += "-w {} ".format(nic)
        self.execute_and_wait('cd /usr/bin')
        if int(S.getValue('GUEST_NIC_QUEUES')[self._number]) >=0:
            self.execute_and_wait(
#                '/root/dpdk-16.07/x86_64-native-linuxapp-gcc/build/app/test-pmd/testpmd {} {} -n4 --socket-mem 1024 --'.format(
                './testpmd {} {} -n4 --socket-mem 1024 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')[self._number], list_string) +
                ' --burst=64 -i --txqflags=0xf00 --rxd=2048 --txd=2048 ' +
                '--nb-cores={} --rxq={} --txq={} '.format(
                    S.getValue('GUEST_TESTPMD_NB_CORES')[self._number],
                    S.getValue('GUEST_TESTPMD_TXQ')[self._number],
                    S.getValue('GUEST_TESTPMD_RXQ')[self._number]) +
                '--disable-hw-vlan --disable-rss', 60, "Done")
        else:
            self.execute_and_wait(
                'testpmd {} -n 4 --socket-mem 512 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')[self._number]) +
                ' --burst=64 -i --txqflags=0xf00 ' +
                '--disable-hw-vlan', 60, "Done")
        self.execute('set fwd ' + self._testpmd_fwd_mode, 1)
        self.execute_and_wait('start', 20,
                              'TX RS bit threshold=.+ - TXQ flags=0x.+')
EOT
else
cat <<EOT >> ~/vswitchperf/vnfs/qemu/qemu.py
    def _configure_testpmd(self):
        """
        Configure VM to perform L2 forwarding between NICs by DPDK's testpmd
        """
        self._configure_copy_sources('DPDK')
        self._configure_disable_firewall()

        # Guest images _should_ have 1024 hugepages by default,
        # but just in case:'''
        self.execute_and_wait('sysctl vm.nr_hugepages={}'.format(S.getValue('GUEST_HUGEPAGES_NR')[self._number]))

        # Mount hugepages
        self.execute_and_wait('mkdir -p /dev/hugepages')
        self.execute_and_wait(
            'mount -t hugetlbfs hugetlbfs /dev/hugepages')

        # build and configure system for dpdk
        self.execute_and_wait('cd ' + S.getValue('GUEST_OVS_DPDK_DIR')[self._number] +
                              '/DPDK')
        self.execute_and_wait('cat /proc/meminfo')
        self.execute_and_wait('rpm -ivh ~/1607/dpdk*.rpm ')
        self.execute_and_wait("modprobe uio_pci_generic")
        self.execute_and_wait('systemctl stop irqlabance')
        self.execute_and_wait('./affinity.sh')
        self.execute_and_wait('tuna -Q')
        self.execute_and_wait('cat /proc/cmdline')
        self.execute_and_wait('./tools/dpdk*bind.py --status')

        # disable network interfaces, so DPDK can take care of them
        for nic in self._nics:
            self.execute_and_wait('ifdown ' + nic['device'])

        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py --status')
        pci_list = ' '.join([nic['pci'] for nic in self._nics])
        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py -u ' + pci_list)
        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py -b uio_pci_generic ' + pci_list)
        self.execute_and_wait('/root/dpdk-16.07/tools/dpdk*bind.py --status')
#        self.execute_and_wait('export LD_LIBRARY_PATH=/root/dpdk-16.07/x86_64-native-linuxapp-gcc/lib:${LD_LIBRARY_PATH}')
#        self.execute_and_wait('./dpdk_nic_bind.py -u ' + pci_list)
#        self.execute_and_wait('./dpdk_nic_bind.py -b vfio-pci ' + pci_list)
#        self.execute_and_wait('./dpdk_nic_bind.py --status')


        # build and run 'test-pmd'
#        self.execute_and_wait('cd ' + S.getValue('GUEST_OVS_DPDK_DIR')[self._number] +
#                              '/DPDK/app/test-pmd')
#        self.execute_and_wait('make clean')
#        self.execute_and_wait('make')
        list_string = ""
        for nic in pci_list.split():
            list_string += "-w {} ".format(nic)
        self.execute_and_wait('cd /usr/bin')
        if int(S.getValue('GUEST_NIC_QUEUES')[self._number]) >=0:
            self.execute_and_wait(
#                '/root/dpdk-16.07/x86_64-native-linuxapp-gcc/build/app/test-pmd/testpmd {} {} -n4 --socket-mem 1024 --'.format(
                './testpmd {} {} -n4 --socket-mem 1024 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')[self._number], list_string) +
                ' --burst=64 -i --txqflags=0xf00 --rxd=2048 --txd=2048 ' +
                '--nb-cores={} --rxq={} --txq={} '.format(
                    S.getValue('GUEST_TESTPMD_NB_CORES')[self._number],
                    S.getValue('GUEST_TESTPMD_TXQ')[self._number],
                    S.getValue('GUEST_TESTPMD_RXQ')[self._number]) +
                '--disable-hw-vlan --disable-rss', 60, "Done")
        else:
            self.execute_and_wait(
                'testpmd {} -n 4 --socket-mem 512 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')[self._number]) +
                ' --burst=64 -i --txqflags=0xf00 ' +
                '--disable-hw-vlan', 60, "Done")
        self.execute('set fwd ' + self._testpmd_fwd_mode, 1)
        self.execute_and_wait('start', 20,
                              'TX RS bit threshold=.+ - TXQ flags=0x.+')
EOT
fi
}

add_rte_version() {
    #copy the rte_version.sh to the folder to prevent vsperf error at end because
    # upstream bits not available to determine version.
    echo "copy the rte_version.sh to the /usr/share/dpdk/lib/librte_eal/common/include/"
    mkdir -p /root/vswitchperf/src/dpdk/dpdk/lib/librte_eal/common/include/
    wget -P /root/vswitchperf/src/dpdk/dpdk/lib/librte_eal/common/include/ http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vsperf/rte_version.h
}

modify_06fwd_conf() {
    echo "start to modify 06_pktfwd.conf..."
    sed -i "/TESTPMD_FWD_MODE =/c\TESTPMD_FWD_MODE = ['io']" /root/vswitchperf/conf/06_pktfwd.conf
    sed -i "/PIDSTAT_MONITOR =/c\PIDSTAT_MONITOR = ['ovs-vswitchd', 'ovsdb-server', 'qemu-kvm', 'testpmd']" /root/vswitchperf/conf/06_pktfwd.conf
}

modify_05collector_conf() {
    echo "start to modify 05_collector.conf..."
    sed -i "/PIDSTAT_MONITOR =/c\PIDSTAT_MONITOR = ['ovs-vswitchd', 'ovsdb-server', 'qemu-kvm']" /root/vswitchperf/conf/05_collector.conf
}

color_mod() {
echo -e "LS_COLORS='rs=0:di=01;32:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.axa=00;36:*.oga=00;36:*.spx=00;36:*.xspf=00;36:';" >> ~/.bashrc
echo -e "export LS_COLORS" >> ~/.bashrc
}

#main

install_utilities
clone_vsperf
if [ "$OS_NAME" == "7.3" ]
    then
        change_to_7_3
fi
run_build_scripts
install_mono_rpm
Copy_Xena2544
setup_xena
add_yum_profiles
download_rpms
create_irq_script
change_conf_file
modify_vnf_conf
modify_guest_rhel_common
modify_05collector_conf
modify_06fwd_conf
download_vnf_image
qemu_modified_code
add_rte_version
color_mod
configure_hugepages