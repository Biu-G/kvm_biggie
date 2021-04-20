#!/bin/bash
#######################################################
# $Name:        create_kvm_machine.sh
# $Version:     v1.0
# $Function:    create kvm machine
# $Author:      dongjiaxiao
# $Create Date: 2020-04-12
# $Description: shell
######################################################
#set -x
# 检查基础镜像和xml是否存在并生成uuid，mac 信息
function check(){
	if [ ! -f "${xmls_dir}${base_xml}" ]&&[ ! -f "${images_dir}${base_img}" ] # 判断基础xml和基础镜像是否存在
	then
		echo "基础镜像或者基础镜像xml不存在"
		exit 1
	else
   		vir_uuid=`uuidgen`
		vir_mac="52:54:$(dd if=/dev/urandom count=1 2>/dev/null | md5sum |sed -r 's/^(..)(..)(..)(..).*$/\1:\2:\3:\4/')"
		vir_name=$machine_name        
	fi 
	
}
#创建磁盘
function create_disk(){
	chattr -i  ${images_dir}$base_img
	qemu-img create -f qcow2 -F qcow2 -b ${images_dir}$base_img ${images_dir}${vir_name}.qcow2 ${vir_disk}G  &>/dev/null
}
#添加磁盘
function attach_disk(){
	qemu-img create -f qcow2  ${images_dir}${vir_name}-2.qcow2  ${vir_attach_disk}G  >/dev/null
	virsh attach-disk ${vir_name} ${images_dir}${vir_name}-2.qcow2 vdb --cache writeback --subdriver qcow2 --persistent >/dev/null
	
}

#配置xml ，替换内存cpu 等信息并导入
function conf_xml(){
	cp  ${xmls_dir}${base_xml}  /tmp/${vir_name}.xml
	sed -i "s#<memory unit='KiB'>.*</memory>#<memory unit='KiB'>${vir_mem}</memory>#"  /tmp/${vir_name}.xml 
	sed -i "s#<currentMemory unit='KiB'>.*</currentMemory>#<currentMemory unit='KiB'>${vir_mem}</currentMemory>#"   /tmp/${vir_name}.xml 
	sed -i "s#<vcpu placement='static'>.*</vcpu>#<vcpu placement='static'>${vir_cpu}</vcpu>#" /tmp/${vir_name}.xml
	sed -i "s/<name>.*<\/name>/<name>${vir_name}<\/name>/" /tmp/${vir_name}.xml
	sed -i "s/<uuid>.*<\/uuid>/<uuid>${vir_uuid}<\/uuid>/" /tmp/${vir_name}.xml
	#sed -i "s/<title>.*<\/title>/<title>${vir_ip}<\/title>/" /tmp/${vir_name}.xml
	sed -i "s#<source file=.*/>#<source file='${images_dir}${vir_name}.qcow2'/>#" /tmp/${vir_name}.xml
	sed -i "s/<mac address=.*\/>/<mac address='$vir_mac' \/>/" /tmp/${vir_name}.xml
	virsh define /tmp/${vir_name}.xml >/dev/null
	virt-edit -d ${vir_name}  /etc/sysconfig/network-scripts/ifcfg-enp1s0  -e "s#BOOTPROTO=".*"#BOOTPROTO=static#"  # 替换ip
    virt-edit -d ${vir_name}  /etc/sysconfig/network-scripts/ifcfg-enp1s0  -e "s#PROXY_METHOD=".*"#IPADDR="${vir_ip}"#"  # 替换ip
}

#启动并设置开机自启
function start_vir(){
	virsh start ${vir_name} >/dev/null
	virsh autostart ${vir_name} >/dev/null
	chattr +i  ${images_dir}$base_img
}
#记录创建日志
function create_vir_log(){
	echo "$(date +%F_%T)  vir_name: ${vir_name} vir_ip: ${vir_ip} !"   >>$vir_log_file
	echo "$(date +%F_%T)  vir_name: ${vir_name} vir_ip: ${vir_ip} 创建成功!" 
}

main(){
    images_dir="/home/jessi/kvm/data/" # 镜像存储的位置
    base_img="centos-base.qcow2"  # 基础镜像的名称
    xmls_dir="/etc/libvirt/qemu/"  # xml 的位置
    base_xml="centos-base.xml.bak"   # 基础xml的名称 
    vir_log_file="/tmp/kvm_create_log.txt" # 创建日志文件
    vir_disk=40 # 磁盘默认为50G  
    vir_cpu=3 # cpu默认为2核
    vir_mem=6291456 # 内存默认为8G
    vir_ip=192.168.122.1
    echo -e "服务器配置选项:\n 1: 3核6G 40G(测试) \n 2: 1核8G 50G(开发) \n 3: 2核8G 100G(数据库) \n 4: 4核20G 200G" 
    read  -t 30 -p  "输入你选择的配置的编号(1-4):" number
    read  -t 90 -p "输入想要创建的IP(192.168.1.1):"  vir_ip
    read  -t 120 -p "输入想要创建的机器名称(haha-biz-1234567-test):"  machine_name
    if [ -z "$vir_ip" ] || [  -z "$machine_name" ] # 判断是否输入ip和机器名称
    then
       echo "请输入ip和机器名称"
       exit -1
    fi
    case "$number" in
        [1] )
            check
            create_disk
            conf_xml
            start_vir
            create_vir_log
        ;;
        [2] )
            vir_cpu=1  # 设置为1核
            check
            create_disk
            conf_xml
            start_vir
            create_vir_log
        ;;
        [3] )
            vir_disk=100 #设置为磁盘100G盘
            check
            create_disk
            conf_xml
            start_vir
            create_vir_log
        ;;
        [4] )
            base_img="dc-base-image.qcow2"
            vir_cpu=4  # 设置为4核
            vir_mem=20971520 #设置内存为20G
            vir_disk=20 #设置为磁盘200G盘
            vir_attach_disk=200 # 设置附加盘的大小
            check
            create_disk
            conf_xml
            start_vir
            attach_disk
            create_vir_log
        ;;
        *) echo "输入编号(1-4)";;
    esac
}
main
