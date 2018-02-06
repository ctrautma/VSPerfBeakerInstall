# vmscripts

VM Installer script for use within beaker or other automated tasks.

Allows for creating of a fully tuned VM based on the kernel compose 
provided.

For beaker tests simply grab your compose location and then apply it 
to the execution of the script.

"""
MYCOMPOSE=`cat /etc/yum.repos.d/beaker-Server.repo | grep baseurl | cut -c9-`

vmcreate.sh -c 3 -l $MYCOMPOSE
"""

The -c is important to specify how the VM will be tuned. This option 
sets the tuned-adm cpu-partitioning profile how many CPUs to add
into its config file.  In the above example the VM will be tuned
for 3 VCPUs. This means Vcpu 1 and 2 will be isolated.

The -l option specifies the compose location. It can be set to
any valid compose location for VM installation. Even public compose
locations.

The script does disable selinux temporarily during it execution.

The script by default runs in silent mode with no output. If needed
a -d option can be added to get the full output. This is handy since
failures will not be shown on the screen. This logic will be added
later to better indicate a possible failure in installing the VM.

As part of the installation it will clone 
https://github.com/ctrautma/vmscripts.git inside of the VM and run
the setup_rpms.sh script which is responsible for pulling down
different DPDK versions as well as different useful scripts. Feel
free to request changes or submit a pull request to this repo to
update the VM filse that are installed.

