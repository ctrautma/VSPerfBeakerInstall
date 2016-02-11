#!/usr/bin/env bash

mypass="RedHat16"

# install and setup vnc
yum -y install $(echo "
tigervnc.x86_64"
)
if [ -e ~/.vnc ]
then
    echo "Skipping .vnc folder creation"
else
    mkdir ~/.vnc
fi

cp passwd ~/.vnc/passwd

# setup Pycharm
cd ~
wget https://download.jetbrains.com/python/pycharm-community-5.0.4.tar.gz
tar xvzf pycharm-community*.tar.gz -C /tmp/
chown -R root:root /tmp/pycharm*
mv /tmp/pycharm-community* /opt/pycharm-community
ln -s /opt/pycharm-community/bin/pycharm.sh /usr/local/bin/pycharm
ln -s /opt/pycharm-community/bin/inspect.sh /usr/local/bin/inspect

# run

vncserver:1 &
pycharm &


