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

# settings to change if needed
# OVS RPM to install
#ovs_rpm="http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.5.0/5.git20160628.el7fdb/x86_64/openvswitch-2.5.0-5.git20160628.el7fdb.x86_64.rpm"
ovs_rpm="http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch/2.5.0/10.git20160727.el7fdb/x86_64/openvswitch-2.5.0-10.git20160727.el7fdb.x86_64.rpm"

# DPDK RPMS to install in guest and host
#dpdk_rpm="http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/16.04/4.el7fdb/x86_64/dpdk-16.04-4.el7fdb.x86_64.rpm"
#dpdk_tools_rpm="http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/16.04/4.el7fdb/x86_64/dpdk-tools-16.04-4.el7fdb.x86_64.rpm"
dpdk_rpm="http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/2.2.0/3.el7/x86_64/dpdk-2.2.0-3.el7.x86_64.rpm"
dpdk_tools_rpm="http://download.eng.pnq.redhat.com/brewroot/packages/dpdk/2.2.0/3.el7/x86_64/dpdk-tools-2.2.0-3.el7.x86_64.rpm"

# XENA Info
xena_ip="10.19.15.19"
xena_module="3"

# Isolated CPU list
ISOLCPUS='1,3,5'

# no soft tick cpus
HZ_CPUS='1,3,5'

# NICs to use in VSPerf
NIC1="p2p1"
NIC2="p2p2"

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

    wget --user="${USER}" --password="${PASS}" "ftp://${HOST}/${FILE}"
    mv Xena2544.exe ~/vswitchperf/tools/pkt_gen/xena/.
}

copy_bits() {

echo "copy the ovs bits to locations needed for VSPerf..."
cd ~/vswitchperf
mkdir /usr/bin/ovsdb
mkdir /usr/bin/utilities
mkdir /usr/bin/vswitchd

cp /usr/sbin/ovsdb-server /usr/bin/ovsdb/.
cp /usr/bin/ovsdb-tool /usr/bin/ovsdb/.
cp /usr/bin/ovs-vsctl /usr/bin/utilities/.
cp /usr/bin/ovs-ofctl /usr/bin/utilities/.
cp /usr/bin/ovs-dpctl /usr/bin/utilities/.
cp /usr/sbin/ovs-vswitchd /usr/bin/vswitchd/.
cp /usr/share/openvswitch/vswitch.ovsschema /usr/bin/vswitchd/.

}

delete_bits() {
X=$(rpm -qa | grep openvswitch)
rpm -e $X
X=$(rpm -qa | grep dpdk-tools)
rpm -e $X
X=$(rpm -qa | grep dpdk)
rpm -e $X
rm -f /usr/share/dpdk/*.rpm

rm -Rf /usr/bin/ovsdb
rm -Rf /usr/bin/utilities
rm -Rf /usr/bin/vswitchd

}
change_conf_file() {

echo "start to change the redhat related conf..."
echo "detecting nic 1"
nic1pci=$(ethtool -i $NIC1 | grep bus-info | awk '{print $2}')
echo "detecting nic 2"
nic2pci=$(ethtool -i $NIC2 | grep bus-info | awk '{print $2}')
cd ~/vswitchperf
echo -e "\nOVS_DIR_VANILLA = '/usr/bin'\n" >> conf/00_common.conf
echo -e "OVS_DIR_USER = '/usr/bin'\n" >> conf/00_common.conf
echo -e "RTE_SDK_USER = '/usr/share/dpdk'\n" >> conf/00_common.conf
echo -e "\nOVS_VAR_DIR = '/var/run/openvswitch/'\n" >> conf/02_vswitch.conf
echo -e "OVS_ETC_DIR = '/etc/openvswitch/'\n" >> conf/02_vswitch.conf
echo -e "DPDK_MODULES = [('vfio-pci'),]\n" >> conf/02_vswitch.conf
echo -e "SYS_MODULES = ['cuse']" >> conf/02_vswitch.conf
sed -i '/RTE_TARGET/c\#RTE_TARGET=' conf/10_custom.conf
sed -i '/WHITELIST_NICS/c\WHITELIST_NICS=["'$nic1pci'", "'$nic2pci'"]' conf/02_vswitch.conf

kernel=$(uname -r)
echo -e "\nVSWITCH_VANILLA_KERNEL_MODULES = ['libcrc32c', 'ip_tunnel', 'vxlan', 'gre', 'nf_nat', 'nf_nat_ipv6', 'nf_nat_ipv4', 'nf_conntrack', 'nf_defrag_ipv4', 'nf_defrag_ipv6', '/usr/lib/modules/$kernel/kernel/net/openvswitch/openvswitch.ko']\n" >> conf/02_vswitch.conf

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
}

install_rpms() {

# these need to be changed to by dynamic based on the beaker recipe
echo "start to install ovs rpm in host"
wget $ovs_rpm >/dev/null 2>&1
wget $dpdk_rpm >/dev/null 2>&1
wget $dpdk_tools_rpm >/dev/null 2>&1
rpm -ivh *.rpm
mkdir -p /usr/share/dpdk
mv *.rpm /usr/share/dpdk/.
}

configure_hugepages() {
#config the hugepage
sed -i 's/\(GRUB_CMDLINE_LINUX.*\)"$/\1/g' /etc/default/grub
sed -i "s/GRUB_CMDLINE_LINUX.*/& nohz=on default_hugepagesz=1G hugepagesz=1G hugepages=24 intel_iommu=on iommu=pt isolcpus=$ISOLCPUS nohz_full=$HZ_CPUS rcu_nocbs=$HZ_CPUS  intel_pstate=disable nosoftlockup\"/g" /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot
}

run_qemu_make() {

# To run pvp/pvvp tests need qemu built
echo "start to make the qemu..."
cd ~/vswitchperf/src/qemu
make

}

modify_vnf_conf() {

echo "start to modify GUEST_IMG of the 04_vnf.conf..."
# set the GUEST_IMAGE value
if [ "$OS_NAME" == "7.3" ]
    then
        sed -i '/GUEST_IMAGE =/c\GUEST_IMAGE = ["rhel7.3.qcow2","rhel7.3.qcow2"]' ~/vswitchperf/conf/04_vnf.conf
    else
        sed -i '/GUEST_IMAGE =/c\GUEST_IMAGE = ["rhel7.2.z.qcow2","rhel7.2.z.qcow2"]' ~/vswitchperf/conf/04_vnf.conf
fi
sed -i '/GUEST_BOOT_DRIVE_TYPE/c\GUEST_BOOT_DRIVE_TYPE = "ide"' ~/vswitchperf/conf/04_vnf.conf
sed -i '/GUEST_SHARED_DRIVE_TYPE/c\GUEST_SHARED_DRIVE_TYPE = "ide"' ~/vswitchperf/conf/04_vnf.conf
sed -i '/GUEST_PASSWORD/c\GUEST_PASSWORD = "redhat"' ~/vswitchperf/conf/04_vnf.conf
sed -i '/GUEST_NET1_PCI_ADDRESS/c\GUEST_NET1_PCI_ADDRESS = ["00:03.0", "00:03.0", \\' ~/vswitchperf/conf/04_vnf.conf
sed -i '/GUEST_NET2_PCI_ADDRESS/c\GUEST_NET2_PCI_ADDRESS = ["00:04.0", "00:04.0", \\' ~/vswitchperf/conf/04_vnf.conf

}

download_vnf_image() {

echo "start to down load vnf image..."
# down load the rhel image for guest
if [ "$OS_NAME" == "7.3" ]
    then
        wget -P ~/vswitchperf/ http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vm/rhel7.3.qcow2 >/dev/null 2>&1
    else
        wget -P ~/vswitchperf/ http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vm/rhel7.2.qcow2 >/dev/null 2>&1
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
        self.execute_and_wait('sysctl vm.nr_hugepages=1024')

        # Mount hugepages
        self.execute_and_wait('mkdir -p /dev/hugepages')
        self.execute_and_wait(
            'mount -t hugetlbfs hugetlbfs /dev/hugepages')

        # build and configure system for dpdk
        self.execute_and_wait('cd ' + S.getValue('GUEST_OVS_DPDK_DIR') +
                              '/DPDK')
        # disable network interfaces, so DPDK can take care of them
        self.execute_and_wait('ifdown ' + self._net1)
        self.execute_and_wait('ifdown ' + self._net2)
        self.execute_and_wait('rpm -ivh dpdk*.rpm ')
        self.execute_and_wait("modprobe vfio enable_unsafe_noiommu_mode=Y")
        self.execute_and_wait("modprobe vfio-pci")
        self.execute_and_wait('systemctl stop irqlabance')
        self.execute_and_wait('./affinity.sh')
        self.execute_and_wait('./tools/dpdk*bind.py --status')
        self.execute_and_wait(
            './tools/dpdk*bind.py -u' ' ' +
            S.getValue('GUEST_NET1_PCI_ADDRESS')[self._number] + ' ' +
            S.getValue('GUEST_NET2_PCI_ADDRESS')[self._number])
        self.execute_and_wait(
            "./tools/dpdk*bind.py -b vfio-pci" " " +
            S.getValue('GUEST_NET1_PCI_ADDRESS')[self._number] + ' ' +
            S.getValue('GUEST_NET2_PCI_ADDRESS')[self._number])
        self.execute_and_wait('./tools/dpdk*bind.py --status')

        # run 'test-pmd'
        if int(S.getValue('GUEST_NIC_QUEUES')):
            self.execute_and_wait(
                'testpmd {} -n4 --socket-mem 512 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')) +
                ' --burst=64 -i --txqflags=0xf00 ' +
                '--nb-cores={} --rxq={} --txq={} '.format(
                    S.getValue('GUEST_TESTPMD_NB_CORES'),
                    S.getValue('GUEST_TESTPMD_TXQ'),
                            S.getValue('GUEST_TESTPMD_RXQ')) +
                '--disable-hw-vlan', 60, "Done")
        else:
            self.execute_and_wait(
                'testpmd {} -n 4 --socket-mem 512 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')) +
                ' --burst=64 -i --txqflags=0xf00 ' +
                '--disable-hw-vlan', 60, "Done")
        self.execute('set fwd ' + self._testpmd_fwd_mode, 1)
        self.execute_and_wait('start', 20,
                              'TX RS bit threshold=.+ - TXQ flags=0xf00')

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
        self.execute_and_wait('sysctl vm.nr_hugepages=1024')

        # Mount hugepages
        self.execute_and_wait('mkdir -p /dev/hugepages')
        self.execute_and_wait(
            'mount -t hugetlbfs hugetlbfs /dev/hugepages')

        # build and configure system for dpdk
        self.execute_and_wait('cd ' + S.getValue('GUEST_OVS_DPDK_DIR') +
                              '/DPDK')
        # disable network interfaces, so DPDK can take care of them
        self.execute_and_wait('ifdown ' + self._net1)
        self.execute_and_wait('ifdown ' + self._net2)
        self.execute_and_wait('rpm -ivh dpdk*.rpm ')
        self.execute_and_wait("modprobe uio_pci_generic")
        self.execute_and_wait('systemctl stop irqlabance')
        self.execute_and_wait('./affinity.sh')
        self.execute_and_wait('./tools/dpdk*bind.py --status')
        self.execute_and_wait(
            './tools/dpdk*bind.py -u' ' ' +
            S.getValue('GUEST_NET1_PCI_ADDRESS')[self._number] + ' ' +
            S.getValue('GUEST_NET2_PCI_ADDRESS')[self._number])
        self.execute_and_wait(
            "./tools/dpdk*bind.py -b uio_pci_generic" " " +
            S.getValue('GUEST_NET1_PCI_ADDRESS')[self._number] + ' ' +
            S.getValue('GUEST_NET2_PCI_ADDRESS')[self._number])
        self.execute_and_wait('./tools/dpdk*bind.py --status')

        # run 'test-pmd'
        if int(S.getValue('GUEST_NIC_QUEUES')):
            self.execute_and_wait(
                'testpmd {} -n4 --socket-mem 512 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')) +
                ' --burst=64 -i --txqflags=0xf00 ' +
                '--nb-cores={} --rxq={} --txq={} '.format(
                    S.getValue('GUEST_TESTPMD_NB_CORES'),
                    S.getValue('GUEST_TESTPMD_TXQ'),
                            S.getValue('GUEST_TESTPMD_RXQ')) +
                '--disable-hw-vlan', 60, "Done")
        else:
            self.execute_and_wait(
                'testpmd {} -n 4 --socket-mem 512 --'.format(
                    S.getValue('GUEST_TESTPMD_CPU_MASK')) +
                ' --burst=64 -i --txqflags=0xf00 ' +
                '--disable-hw-vlan', 60, "Done")
        self.execute('set fwd ' + self._testpmd_fwd_mode, 1)
        self.execute_and_wait('start', 20,
                              'TX RS bit threshold=.+ - TXQ flags=0xf00')

EOT
fi
}

add_rte_version() {
    #copy the rte_version.sh to the folder to prevent vsperf error at end because
    # upstream bits not available to determine version.
    echo "copy the rte_version.sh to the /usr/share/dpdk/lib/librte_eal/common/include/"
    mkdir -p /usr/share/dpdk/lib/librte_eal/common/include/
    wget -P /usr/share/dpdk/lib/librte_eal/common/include/ http://netqe-infra01.knqe.lab.eng.bos.redhat.com/vsperf/rte_version.h
}

#main
if [ ! -z $1 ]
then
    if [ $1 = "copyonly" ]
    then
    delete_bits
    install_rpms
    copy_bits
    exit 0
    fi
fi

install_utilities
clone_vsperf
if [ "$OS_NAME" == "7.3" ]
    then
        change_to_7_3
fi
run_build_scripts
run_qemu_make
install_mono_rpm
Copy_Xena2544
setup_xena
install_rpms
copy_bits
create_irq_script
change_conf_file
modify_vnf_conf
download_vnf_image
qemu_modified_code
add_rte_version
configure_hugepages