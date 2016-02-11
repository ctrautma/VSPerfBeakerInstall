#!/usr/bin/env bash

mypass="RedHat16"

# install and setup vnc
yum -y install echo$(
tigervnc.x86_64
)
echo "$mypass" >password.tmp
vncpasswd password.tmp
rm -F password.tmp

# setup Pycharm
cd ~
wget https://download.jetbrains.com/python/pycharm-community-5.0.4.tar.gz
tar xvzf pycharm-community*.tar.gz -C /opt/pycharm-community
ln -s /opt/pycharm-community/bin/pycharm.sh /usr/local/bin/pycharm
ln -s /opt/pycharm-community/bin/inspect.sh /usr/local/bin/inspect

# run

vncserver:1 &
pycharm &


