#!/usr/bin/env bash

# Assumes the following beaker install
# Family: RedHatEnterpriseLinux7
# Tag: RELEASED
# Distro: RHEL-7.2
# Distro Tree: RHEL-7.2 Client x86_64

# verify OS level
OS=$(cat /etc/os-release | awk /^NAME/ | awk '{split($0,a,"="); print a[2]}')
VER=$(cat /etc/os-release | awk /^VERSION_ID/ | awk '{split($0,a,"="); print a[2]}')

if [ "$OS" != '"Red Hat Enterprise Linux Client"' ] || [ "$VER" != '"7.2"' ]
then
    echo This script is designed to run on RHEL 7.2 Workstation x86_64
    exit 1
fi

ROOT_UID=0

# check if root
if [ "$UID" -ne "$ROOT_UID" ]
then
    # installation must be run via root
    echo Please log in as root to run this script
    exit 1
fi

# start in root home folder
cd ~

# install compilers
yum -y install $(echo "
automake
gcc
gcc-c++
glibc.i686
kernel-devel
fuse-devel
pixman-devel
openssl-devel
sysstat.x86_64
glib2-devel"
)

# tools
yum -y install $(echo "
libtool
libpcap-devel
libnet
socat
git"
)

# Python dependencies for correct build
yum -y install $(echo "
tk-devel
openssl
openssl-devel"
)

# install python3 as alt install option
echo Installing python 3.x
wget https://www.python.org/ftp/python/3.4.2/Python-3.4.2.tar.xz
tar -xf Python-3.4.2.tar.xz
cd Python-3.4.2
./configure 1>/dev/null
make 1>/dev/null
make altinstall 1>/dev/null
cd ..
# cleanup
rm -Rf Python-3.4.2
rm -f Python-3.4.2.tar.xz

# clone repo using anonymous http (read only)
git clone https://gerrit.opnfv.org/gerrit/vswitchperf

# if this is to work two ports should have a traffic gen attached
PORT1=$(ip a | awk /"<BROADCAST"/ | awk /"p[0-9]p1"/ | awk '{print $2}' | awk -F: '$0=$1')
PORT2=$(ip a | awk /"<BROADCAST"/ | awk /"p[0-9]p2"/ | awk '{print $2}' | awk -F: '$0=$1')

echo "VSWITCH = 'OvsVanilla'" >> ~/vswitchperf/conf/10_custom.conf
echo "VSWITCH_VANILLA_PHY_PORT_NAMES = ['$PORT1', '$PORT2']" >> ~/vswitchperf/conf/10_custom.conf

# run make to start up ovs with dpdk
echo running make on ovs, qemu, and dpdk
cd ~/vswitchperf/src
make 2>install.log 1>/dev/null || echo '!!!Error during make, check install.log for details!!!'; tail -10 install.log
cd ..

# install python3 packages
pip3.4 install virtualenv

# install python 3 virtual env
export VSPERFENV_DIR="$HOME/vsperfenv"

# create virtualenv for python
virtualenv-3.5 "$VSPERFENV_DIR"

# start virtualenv and install requirements
source ~/vsperfenv/bin/activate
pip3.4 install -r ~/vswitchperf/requirements.txt

echo "##########################################"
echo "# Added $PORT1 and $PORT2 to use in ovs. #"
echo "# If there are not the desired devices   #"
echo "# to use please modify them in the       #"
echo "# conf/10_custom.conf file.              #"
echo "##########################################"

echo Activate the python 3 environment by executing "source ~/vsperfenv/bin/activate"
echo Switch to the ~/vswitchperf folder.
echo Then you can execute ./vsperf --help to see options
echo You can also just execute ./vsperf --trafficgen Dummy to see sample run.


vsperfKill()
{
    pid=$(ps -auxww | grep python | grep vsperf | grep -v grep | awk '{print $2}')
    kill ${pid}
    echo killed ${pid}
}