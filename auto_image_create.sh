#!/bin/bash

rm -f /var/lib/libvirt/images/*
ls -al /var/lib/libvirt/images/

unset VM_NAME

virsh list --all --name | xargs -I {} virsh destroy  {}
virsh list --all --name | xargs -I {} virsh undefine {}

url_76=http://download.eng.pek2.redhat.com/rhel-7/rel-eng/latest-RHEL-7.6/compose/Server/x86_64/os/

url_77=http://download.eng.pek2.redhat.com/rhel-7/rel-eng/latest-RHEL-7.7/compose/Server/x86_64/os/

url_78=http://download.eng.pek2.redhat.com/rhel-7/rel-eng/latest-RHEL-7.8/compose/Server/x86_64/os/

url_80=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.0/compose/BaseOS/x86_64/os/

url_81=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.1/compose/BaseOS/x86_64/os/

url_82=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.2/compose/BaseOS/x86_64/os/

url_79=http://download.eng.pek2.redhat.com/rhel-7/nightly/latest-RHEL-7.9/compose/Server/x86_64/os/

url_83=http://download.eng.bos.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.3/compose/BaseOS/x86_64/os/

url_84=http://download.eng.bos.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.4/compose/BaseOS/x86_64/os/

url_89=http://download.eng.pek2.redhat.com/rhel-8/rel-eng/RHEL-8/latest-RHEL-8.9.0/compose/BaseOS/x86_64/os/

url_93=http://download.eng.pek2.redhat.com/rhel-9/rel-eng/RHEL-9/latest-RHEL-9.3.0/compose/BaseOS/x86_64/os/

for url in $url_89
do
    for i in 1Q
    do
        for j in viommu
        do
            echo $url
            rhel_ver=`echo ${url%/} | awk -F '/' '{print $(NF-4)}' | awk -F '-' '{print $NF}'`
            vm_name="rhel${rhel_ver}-vsperf"-${i}-${j}
            export VM_NAME=${vm_name}
            echo $VM_NAME
            if [[ $j == viommu ]]
            then
                cmd="sh vmcreate.sh -c $(( ${i%Q} * 2 + 1 )) -l $url -d -v"
            else
                cmd="sh vmcreate.sh -c $(( ${i%Q} * 2 + 1 )) -l $url -d"
            fi
            echo $cmd
            eval $cmd
        done
    done
done

unset VM_NAME

