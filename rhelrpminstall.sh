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
elif [ "$HOSTNAME" == "netqe15" ]
    then
    NIC1="p2p1"
    NIC2="p2p2"
    PMDMASK="aa00"
elif [ "$HOSTNAME" == "netqe23" ]
    then
    NIC1="p6p1"
    NIC2="p6p2"
    PMDMASK="500000000500000000"
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

#kernel_update='http://download.eng.bos.redhat.com/rel-eng/RHEL-7.4-20170608.3/compose/Server/x86_64/os'

install_utilities() {
yum install -y wget nano ftp yum-utils git tuna openssl sysstat
}

run_build_scripts() {

echo "start to run the build_base_machine.sh..."
cd ~/vswitchperf/systems
mv rhel/7.2/ rhel/7.4
sed -i s/'    make || die "Make failed"'/'#     make || die "Make failed"'/ ~/vswitchperf/systems/build_base_machine.sh
./build_base_machine.sh >>/dev/null
cd ~/vswitchperf

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

clone_vsperf() {

echo "start to clone vsperf project..."
cd ~
git clone https://gerrit.opnfv.org/gerrit/vswitchperf
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
yum install -y qemu-kvm-rhev*
rpm -ivh $ovs_folder
rpm -ivh $dpdk_folder
rpm -Uvh $tuned_folder/tuned-2.8.0-2.el7fdp.noarch.rpm
rpm -ivh $tuned_folder/tuned-profiles-cpu-partitioning-2.8.0-2.el7fdp.noarch.rpm

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

}

download_vnf_image() {
cd ~
git clone https://github.com/ctrautma/VSPerfBeakerInstall.git
chmod +x ~/VSPerfBeakerInstall/vmcreate.sh
MYCOMPOSE=`cat /etc/yum.repos.d/beaker-Server.repo | grep baseurl | cut -c9-`
./VSPerfBeakerInstall/vmcreate.sh -c 3 -l $MYCOMPOSE
mv /var/lib/libvirt/images/master.qcow2 ~/vswitchperf/rhel1Q.qcow2
./VSPerfBeakerInstall/vmcreate.sh -c 5 -l $MYCOMPOSE
mv /var/lib/libvirt/images/master.qcow2 ~/vswitchperf/rhel2Q.qcow2
./VSPerfBeakerInstall/vmcreate.sh -c 9 -l $MYCOMPOSE
mv /var/lib/libvirt/images/master.qcow2 ~/vswitchperf/rhel4Q.qcow2
}

create_irq_script() {
echo none
}

qemu_modified_code() {

# remove drive sharing
sed -i "/                     '-drive',$/,+3 d" ~/vswitchperf/vnfs/qemu/qemu.py
sed -i "/self._copy_fwd_tools_for_all_guests()/c\#self._copy_fwd_tools_for_all_guests()" ~/vswitchperf/testcases/testcase.py

cat <<EOT >> ~/vswitchperf/vnfs/qemu/qemu.py
    def _configure_testpmd(self):
        """
        Configure VM to perform L2 forwarding between NICs by DPDK's testpmd
        """
        #self._configure_copy_sources('DPDK')
        self._configure_disable_firewall()

        # Guest images _should_ have 1024 hugepages by default,
        # but just in case:'''
        self.execute_and_wait('sysctl vm.nr_hugepages={}'.format(S.getValue('GUEST_HUGEPAGES_NR')[self._number]))

        # Mount hugepages
        self.execute_and_wait('mkdir -p /dev/hugepages')
        self.execute_and_wait(
            'mount -t hugetlbfs hugetlbfs /dev/hugepages')

        self.execute_and_wait('cat /proc/meminfo')
        self.execute_and_wait('rpm -ivh ~/dpdkrpms/1705/*.rpm ')
        self.execute_and_wait('cat /proc/cmdline')
        self.execute_and_wait('dpdk-devbind --status')

        # disable network interfaces, so DPDK can take care of them
        for nic in self._nics:
            self.execute_and_wait('ifdown ' + nic['device'])

        self.execute_and_wait('dpdk-bind --status')
        pci_list = ' '.join([nic['pci'] for nic in self._nics])
        self.execute_and_wait('dpdk-devbind -u ' + pci_list)
        self._bind_dpdk_driver(S.getValue(
            'GUEST_DPDK_BIND_DRIVER')[self._number], pci_list)
        self.execute_and_wait('dpdk-devbind --status')

        # get testpmd settings from CLI
        testpmd_params = S.getValue('GUEST_TESTPMD_PARAMS')[self._number]
        if S.getValue('VSWITCH_JUMBO_FRAMES_ENABLED'):
            testpmd_params += ' --max-pkt-len={}'.format(S.getValue(
                'VSWITCH_JUMBO_FRAMES_SIZE'))

        self.execute_and_wait('testpmd {}'.format(testpmd_params), 60, "Done")
        self.execute('set fwd ' + self._testpmd_fwd_mode, 1)
        self.execute_and_wait('start', 20, 'testpmd>')

    def _bind_dpdk_driver(self, driver, pci_slots):
        """
        Bind the virtual nics to the driver specific in the conf file
        :return: None
        """
        if driver == 'uio_pci_generic':
            if S.getValue('VNF') == 'QemuPciPassthrough':
                # unsupported config, bind to igb_uio instead and exit the
                # outer function after completion.
                self._logger.error('SR-IOV does not support uio_pci_generic. '
                                   'Igb_uio will be used instead.')
                self._bind_dpdk_driver('igb_uio_from_src', pci_slots)
                return
            self.execute_and_wait('modprobe uio_pci_generic')
            self.execute_and_wait('dpdk-devbind -b uio_pci_generic '+
                                  pci_slots)
        elif driver == 'vfio_no_iommu':
            self.execute_and_wait('modprobe -r vfio')
            self.execute_and_wait('modprobe -r vfio_iommu_type1')
            self.execute_and_wait('modprobe vfio enable_unsafe_noiommu_mode=Y')
            self.execute_and_wait('modprobe vfio-pci')
            self.execute_and_wait('dpdk-devbind -b vfio-pci ' +
                                  pci_slots)
        elif driver == 'igb_uio_from_src':
            # build and insert igb_uio and rebind interfaces to it
            self.execute_and_wait('make RTE_OUTPUT=$RTE_SDK/$RTE_TARGET -C '
                                  '$RTE_SDK/lib/librte_eal/linuxapp/igb_uio')
            self.execute_and_wait('modprobe uio')
            self.execute_and_wait('insmod %s/kmod/igb_uio.ko' %
                                  S.getValue('RTE_TARGET'))
            self.execute_and_wait('dpdk-devbind -b igb_uio ' + pci_slots)
        else:
            self._logger.error(
                'Unknown driver for binding specified, defaulting to igb_uio')
            self._bind_dpdk_driver('igb_uio_from_src', pci_slots)

EOT

}

add_rte_version() {
    #copy the rte_version.sh to the folder to prevent vsperf error at end because
    # upstream bits not available to determine version.
    echo "copy the rte_version.sh to the /usr/share/dpdk/lib/librte_eal/common/include/"
    mkdir -p /root/vswitchperf/src/dpdk/dpdk/lib/librte_eal/common/include/
    wget -P /root/vswitchperf/src/dpdk/dpdk/lib/librte_eal/common/include/ http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vsperf/rte_version.h
}

color_mod() {
echo -e "LS_COLORS='rs=0:di=01;32:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.axa=00;36:*.oga=00;36:*.spx=00;36:*.xspf=00;36:';" >> ~/.bashrc
echo -e "export LS_COLORS" >> ~/.bashrc
}

create_10_conf() {
cat <<EOT >> ~/vswitchperf/conf/10_custom.conf
GUEST_IMAGE = ['rhel1Q.qcow2']

GUEST_BOOT_DRIVE_TYPE = ['ide']
GUEST_SHARED_DRIVE_TYPE = ['ide']

GUEST_DPDK_BIND_DRIVER = ['vfio_no_iommu']

GUEST_PASSWORD = ['redhat']

GUEST_NICS = [[{'device' : 'eth0', 'mac' : '#MAC(00:00:00:00:00:01,2)', 'pci' : '00:03.0', 'ip' : '#IP(192.168.1.2,4)/24'},
               {'device' : 'eth1', 'mac' : '#MAC(00:00:00:00:00:02,2)', 'pci' : '00:04.0', 'ip' : '#IP(192.168.1.3,4)/24'},
               {'device' : 'eth2', 'mac' : '#MAC(cc:00:00:00:00:01,2)', 'pci' : '00:06.0', 'ip' : '#IP(192.168.1.4,4)/24'},
               {'device' : 'eth3', 'mac' : '#MAC(cc:00:00:00:00:02,2)', 'pci' : '00:07.0', 'ip' : '#IP(192.168.1.5,4)/24'},
             ]]

GUEST_MEMORY = ['4096']

GUEST_HUGEPAGES_NR = ['1']

GUEST_TESTPMD_FWD_MODE = ['io']

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

TEST_PARAMS = {'TRAFFICGEN_PKT_SIZES':(64,), 'TRAFFICGEN_DURATION':30, 'TRAFFICGEN_LOSSRATE':0}

# Xena traffic generator connection info
TRAFFICGEN_XENA_IP = '10.19.15.19'
TRAFFICGEN_XENA_PORT1 = '0'
TRAFFICGEN_XENA_PORT2 = '1'
TRAFFICGEN_XENA_USER = 'vsperf'
TRAFFICGEN_XENA_PASSWORD = 'xena'
TRAFFICGEN_XENA_MODULE1 = '3'
TRAFFICGEN_XENA_MODULE2 = '3'

# Xena Port IP info
TRAFFICGEN_XENA_PORT0_IP = '192.168.199.10'
TRAFFICGEN_XENA_PORT0_CIDR = 24
TRAFFICGEN_XENA_PORT0_GATEWAY = '192.168.199.1'
TRAFFICGEN_XENA_PORT1_IP = '192.168.199.11'
TRAFFICGEN_XENA_PORT1_CIDR = 24
TRAFFICGEN_XENA_PORT1_GATEWAY = '192.168.199.1'

# Xena RFC 2544 options
# Please reference xena documentation before making changes to these settings
TRAFFICGEN_XENA_2544_TPUT_INIT_VALUE = '10.0'
TRAFFICGEN_XENA_2544_TPUT_MIN_VALUE = '0.1'
TRAFFICGEN_XENA_2544_TPUT_MAX_VALUE = '100.0'
TRAFFICGEN_XENA_2544_TPUT_VALUE_RESOLUTION = '0.5'
TRAFFICGEN_XENA_2544_TPUT_USEPASS_THRESHHOLD = 'false'
TRAFFICGEN_XENA_2544_TPUT_PASS_THRESHHOLD = '0.0'

# Xena RFC 2544 final verification options
TRAFFICGEN_XENA_RFC2544_VERIFY = False
TRAFFICGEN_XENA_RFC2544_VERIFY_DURATION = 600
# Number of verify attempts before giving up...
TRAFFICGEN_XENA_RFC2544_MAXIMUM_VERIFY_ATTEMPTS = 10
# Logic for restarting binary search, see documentation for details
TRAFFICGEN_XENA_RFC2544_BINARY_RESTART_SMART_SEARCH = True

TRAFFICGEN = 'Xena'

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
    'ovs_var_tmp': '/usr/local/var/run/openvswitch/',
    'ovs_etc_tmp': '/usr/local/etc/openvswitch/',
    'VppDpdkVhost': {
        'type' : 'bin',
        'src': {
            'path': os.path.join(ROOT_DIR, 'src/vpp/vpp/build-root/build-vpp-native'),
            'vpp': 'vpp',
            'vppctl': 'vppctl',
        },
        'bin': {
            'vpp': 'vpp',
            'vppctl': 'vppctl',
        }
    },
}

PATHS['dpdk'] = {
        'type' : 'bin',
        'src': {
            'path': os.path.join(ROOT_DIR, 'src/dpdk/dpdk/'),
            # To use vfio set:
            # 'modules' : ['uio', 'vfio-pci'],
            'modules' : ['uio', os.path.join(RTE_TARGET, 'kmod/igb_uio.ko')],
            'bind-tool': 'tools/dpdk*bind.py',
            'testpmd': os.path.join(RTE_TARGET, 'app', 'testpmd'),
        },
        'bin': {
            'bind-tool': '/usr/share/dpdk/tools/dpdk-devbind.py',
            'modules' : ['uio', 'vfio-pci'],
            'testpmd' : 'testpmd'
        }
    }

TESTPMD_ARGS = ['--nb-cores=4', '--txq=1', '--rxq=1']

TESTPMD_FWD_MODE = 'io'

PATHS['vswitch'].update({'OvsVanilla' : copy.deepcopy(PATHS['vswitch']['OvsDpdkVhost'])})
PATHS['vswitch']['ovs_var_tmp'] = '/var/run/openvswitch/'
PATHS['vswitch']['ovs_etc_tmp'] = '/etc/openvswitch/'
PATHS['vswitch']['OvsVanilla']['bin']['modules'] = [
        'libcrc32c', 'ip_tunnel', 'vxlan', 'gre', 'nf_nat', 'nf_nat_ipv6',
        'nf_nat_ipv4', 'nf_conntrack', 'nf_defrag_ipv4', 'nf_defrag_ipv6',
        'openvswitch']
PATHS['vswitch']['OvsVanilla']['type'] = 'bin'

VSWITCHD_DPDK_ARGS = ['-l', '2,4,6,8,10', '-n', '4', '--socket-mem 1024']
GUEST_CORE_BINDING = [('12', '14', '16')]

#VSWITCHD_DPDK_ARGS = ['-l', '22,20,18,16,14', '-n', '4', '--socket-mem 1024']
#GUEST_CORE_BINDING = [('12', '10', '8')]

GUEST_NIC_MERGE_BUFFERS_DISABLE = [True]

VSWITCH_JUMBO_FRAMES_ENABLED = False
VSWITCH_JUMBO_FRAMES_SIZE = 9000

VSWITCH_DPDK_MULTI_QUEUES = 0
GUEST_NIC_QUEUES = [0]

WHITELIST_NICS = ['$NIC1_PCI_ADDR', '$NIC2_PCI_ADDR']

DPDK_SOCKET_MEM = ['1024', '1024']

VSWITCHD_DPDK_ARGS = ['-l', '14,16,18,20,22', '-n', '4']

VSWITCH_VHOST_NET_AFFINITIZATION = False
VSWITCH_VHOST_CPU_MAP = [4,5,8,11]

VSWITCH_PMD_CPU_MASK = '$PMDMASK'

GUEST_SMP = ['3']

GUEST_CORE_BINDING = [('4', '6', '30')]

GUEST_TESTPMD_PARAMS = ['-l 0,1,2 -n 4 --socket-mem 512 -- '
                        '--burst=64 -i --txqflags=0xf00 '
                        '--disable-hw-vlan --nb-cores=2, --txq=1 --rxq=1 --rxd=512 --txd=512']
EOT

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
ovs-vsctl add-port ovsbr0 dpdk0 -- set interface dpdk0 type=dpdk ofport_request=10
ovs-vsctl add-port ovsbr0 dpdk1     -- set interface dpdk1 type=dpdk ofport_request=11
ovs-vsctl add-port ovsbr0 vhost0     -- set interface vhost0 type=dpdkvhostuser ofport_request=20
ovs-vsctl add-port ovsbr0 vhost1     -- set interface vhost1 type=dpdkvhostuser ofport_request=21

ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=10,idle_timeout=0,action=output:20
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=20,idle_timeout=0,action=output:10
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=21,idle_timeout=0,action=output:11
ovs-ofctl -O OpenFlow13 --timeout 10 add-flow ovsbr0 in_port=11,idle_timeout=0,action=output:21

chmod 777 /var/run/openvswitch/vhost0
chmod 777 /var/run/openvswitch/vhost1
EOT
chmod +x ~/ovs-dpdk.sh
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
      <page size='524288' unit='KiB' nodeset='0'/>
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
      <source file='/root/rhel1Q.qcow2'/>
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
      <driver name='vhost'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x09' function='0x0'/>
    </interface>
    <interface type='vhostuser'>
      <mac address='52:54:00:11:8f:e9'/>
      <source type='unix' path='/var/run/openvswitch/vhost0' mode='client'/>
      <model type='virtio'/>
      <driver name='vhost'/>
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

}

update_kernel() {
echo none
}

cpu_layout() {
touch ~/cpu_layout.py
cat <<EOT > ~/cpu_layout.py
#!/usr/bin/env python

#
#   BSD LICENSE
#
#   Copyright(c) 2010-2014 Intel Corporation. All rights reserved.
#   Copyright(c) 2017 Cavium, Inc. All rights reserved.
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions
#   are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#     * Neither the name of Intel Corporation nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
from __future__ import print_function
import sys
try:
    xrange # Python 2
except NameError:
    xrange = range # Python 3

sockets = []
cores = []
core_map = {}
base_path = "/sys/devices/system/cpu"
fd = open("{}/kernel_max".format(base_path))
max_cpus = int(fd.read())
fd.close()
for cpu in xrange(max_cpus + 1):
    try:
        fd = open("{}/cpu{}/topology/core_id".format(base_path, cpu))
    except IOError:
        continue
    except:
        break
    core = int(fd.read())
    fd.close()
    fd = open("{}/cpu{}/topology/physical_package_id".format(base_path, cpu))
    socket = int(fd.read())
    fd.close()
    if core not in cores:
        cores.append(core)
    if socket not in sockets:
        sockets.append(socket)
    key = (socket, core)
    if key not in core_map:
        core_map[key] = []
    core_map[key].append(cpu)

print(format("=" * (47 + len(base_path))))
print("Core and Socket Information (as reported by '{}')".format(base_path))
print("{}\n".format("=" * (47 + len(base_path))))
print("cores = ", cores)
print("sockets = ", sockets)
print("")

max_processor_len = len(str(len(cores) * len(sockets) * 2 - 1))
max_thread_count = len(list(core_map.values())[0])
max_core_map_len = (max_processor_len * max_thread_count)  \
                      + len(", ") * (max_thread_count - 1) \
                      + len('[]') + len('Socket ')
max_core_id_len = len(str(max(cores)))

output = " ".ljust(max_core_id_len + len('Core '))
for s in sockets:
    output += " Socket %s" % str(s).ljust(max_core_map_len - len('Socket '))
print(output)

output = " ".ljust(max_core_id_len + len('Core '))
for s in sockets:
    output += " --------".ljust(max_core_map_len)
    output += " "
print(output)

for c in cores:
    output = "Core %s" % str(c).ljust(max_core_id_len)
    for s in sockets:
        if (s,c) in core_map:
            output += " " + str(core_map[(s, c)]).ljust(max_core_map_len)
        else:
            output += " " * (max_core_map_len + 1)
    print(output)
EOT
chmod +x ~/cpu_layout.py
}

install_utilities
add_yum_profiles
download_rpms
clone_vsperf
run_build_scripts
install_mono_rpm
Copy_Xena2544
create_irq_script
download_vnf_image
qemu_modified_code
add_rte_version
color_mod
create_10_conf
create_bind_script
create_other_scripts
create_guest_image
cpu_layout
#update_kernel
configure_hugepages