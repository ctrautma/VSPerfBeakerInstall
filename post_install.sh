#!/bin/bash
set -x

yum -y install iperf3
ln -s /usr/bin/iperf3 /usr/bin/iperf
yum install -y kernel-devel
yum install -y numactl-devel
yum install -y tuna
yum install -y git
yum install -y nano
yum install -y ftp 
yum install -y wget 
yum install -y sysstat
yum install -y automake
yum install -y curl
yum install -y libibverbs
yum install -y nmap-ncat
yum install -y tcpdump

# netperf & iperf
yum install -y gcc-c++
yum install -y make
yum install -y gcc

rpm -q grubby || yum -y install grubby

yum -y install kernel-modules-extra

echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

lksctp_install()
{
    yum -y install lksctp-tools lksctp-tools-devel
    return $?
}

netperf_install()
{
    # force install lksctp for netperf sctp support
    lksctp_install
    rpm -q gcc || yum -y install gcc
    rpm -q autoconf || yum -y install autoconf
    rpm -q automake || yum -y install automake
    rpm -q bzip2 || yum -y install bzip2
    local OUTPUTFILE=`mktemp /mnt/testarea/tmp.XXXXXX`
    SRC_NETPERF="http://netqe-infra01.knqe.eng.rdu2.dc.redhat.com/share/tools/netperf-20210121.tar.bz2"

    pushd `pwd` 1>/dev/null
    wget -nv -N $SRC_NETPERF
    tar xjvf $(basename $SRC_NETPERF)
    cd $(basename $SRC_NETPERF| awk -F. '{print $1}')
    check_arch
    ./autogen.sh
    lsmod | grep sctp
    if [ $? -ne 0 ];then
        modprobe sctp
    fi
    if checksctp; then
        ./configure --enable-sctp CFLAGS="-fcommon -Wno-implicit-function-declaration" && make && make install | tee -a $OUTPUTFILE
    else
        ./configure CFLAGS="-fcommon -Wno-implicit-function-declaration" && make && make install | tee -a $OUTPUTFILE
    fi
    popd 1>/dev/null
    return 0
}

netperf_install

set +x