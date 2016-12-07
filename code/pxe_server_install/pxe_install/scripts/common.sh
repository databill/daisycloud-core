#!/bin/bash

ISO_MOUNT_DIR_NUM=10
ISO_NFS_TAB=/var/log/iso_nfs_tab.log
PXE_OS_TAB=/var/log/pxe_os_table.log

#######################
# ��¼��־��/var/log/pxe_install.log
# $1:Ҫ��¼����־
# $2:���ֵΪconsole����ôͬʱ������Ļ�ϴ�ӡ�˼�¼
# ��������Ĺ��ܣ���¼һ�������־�����������־ǰ����ϼ�¼��ʱ��
#######################
function pxelog
{
    local LOGFILE=/var/log/pxe_install.log
    
    if [ ! -f $LOGFILE ]; then
        touch $LOGFILE
    fi
    #��¼��־
    LANG=en_US.ISO8859-1
    echo -n `date '+%b %d %T'` >> $LOGFILE
    echo -e " $1" >> $LOGFILE
    [[ $2 = "console" ]] && echo -e "$1"
    return 0
}

#######################
#��json�����ļ���ȡ����
#######################
function get_config
{
    local file=$1
    local key=$2

    [ ! -e $file ] && { pxelog "file ${file} not exit!!" "console"; return; }
    config_answer=$(jq ".$key" $file | sed "s/\"//g" )
    pxelog "${key}=$config_answer"
    [[ "null" == ${config_answer} ]] && config_answer=""
    #config_answer=$(echo $config_answer | sed "s/\"//g")
    #���Ծ��ſ�ͷ��ע�����Լ�����֮����grep����"key"���ڵ���
    #local line=`sed '/^[[:space:]]*#/d' $file | sed /^[[:space:]]*$/d | grep -w "$key"| grep "$key[[:space:]]*="`
    #if [ -z "$line" ]; then
    #    config_answer=""
    #else
        #����һ��=���滻Ϊ�ո���ɾ����һ�����ʵõ�value
    #    config_answer=`echo $line | sed 's/=/ /' | sed -e 's/^\w*\ *//'`
    #fi
    
}

#######################
#���ò�����conf�����ļ�
#######################
function set_config
{
    local file=$1
    local key=$2
    local value=$3

    [ ! -e $file ] && return

    #echo update key $key to value $value in file $file ...
    local exist=`grep "^[[:space:]]*[^#]" $file | grep -c "$key[[:space:]]*=[[:space:]]*.*"`
    #ע�⣺���ĳ����ע�ͣ���ͷ��һ���ַ�������#��!!!
    local comment=`grep -c "^[[:space:]]*#[[:space:]]*$key[[:space:]]*=[[:space:]]*.*"  $file`
    
    if [[ $value == "#" ]];then
        if [ $exist -gt 0 ];then
            sed  -i "/^[^#]/s/$key[[:space:]]*=/\#$key=/" $file       
        fi
        return
    fi

    if [ $exist -gt 0 ];then
        #����Ѿ�����δע�͵���Ч�����У�ֱ�Ӹ���value
        sed  -i "/^[^#]/s#$key[[:space:]]*=.*#$key=$value#" $file
        
    elif [ $comment -gt 0 ];then
        #��������Ѿ�ע�͵��Ķ�Ӧ�����У���ȥ��ע�ͣ�����value
        sed -i "s@^[[:space:]]*#[[:space:]]*$key[[:space:]]*=[[:space:]]*.*@$key=$value@" $file
    else
        #������ĩβ׷����Ч������
        #local timestamp=`env LANG=en_US.UTF-8 date`
        #local writer=`basename $0`
        echo "" >> $file
        #echo "# added by $writer at $timestamp" >> $file
        echo "$key=$value" >> $file
    fi
}

function convert_mac_to_ip
{
    local dhcp_mac=$1
    local lease_file=/var/lib/dhcpd/dhcpd.leases
    local line
    local ip_addr
    local log_postfix
    install_log=""
    
    #��ȡlease�ļ������������mac��ַ���к�
    line=`grep -n -wi "${dhcp_mac}" ${lease_file} |tail -n 1 |awk -F':' '{print $1}'`
    
    [[ ${line} == "" ]] && { pxelog "pxe server did not assign an ip to this target machine";return 1; }
    
    #�ҵ�����к�֮ǰ���һ�γ��ֵ�ip
    ip_addr=`head -n ${line} ${lease_file} | grep -o '\<[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\>' |tail -n 1`
    
    #��ip��ַ�õ�log��־�ļ���
    install_log=/var/log/${ip_addr}
    log_postfix=".log"
    install_log=${install_log}${log_postfix}
    pxelog "dhcp_mac=${dhcp_mac} MACADDR=${MACADDR} install_log=${install_log}!"
    
    return 0
}


function repir_iso_nfs_number
{
    local MACADDR=$1
    local ISOMOUNTPATH=$2
    local oper=$3
    
    pxelog "starting repair $ISOMOUNTPATH used number in $ISO_NFS_TAB!"
    (
        flock -x 200
        used_number=`cat $ISO_NFS_TAB |grep -w "${ISOMOUNTPATH}" | awk -F' ' '{print $2}' |head -n 1`
        #�ж�used_number�Ƿ�Ϊ����
        expr $used_number "+" 10 &> /dev/null
        if [ $? -ne 0 ];then
            pxelog "${ISOMOUNTPATH} used number is not a digital!" "console"
            return 1
        fi
        
        pxelog "befor $oper ${MACADDR}, ${ISOMOUNTPATH} is used by $used_number nfs client!"        
        if [[ $oper == "add" ]]; then
            ((used_number=$used_number+1))        
        elif [[ $oper == "dec" ]]; then
            if [[ $used_number -gt 0 ]]; then
                ((used_number=$used_number-1))
                if [[ $used_number -eq 0 ]]; then
                    local linuxinstall_mount=`basename ${ISOMOUNTPATH}`
                    linuxinstall_mount="linuxinstall-""${linuxinstall_mount}"".mount"
                    systemctl disable $linuxinstall_mount &>/dev/null
                    systemctl stop $linuxinstall_mount  &>/dev/null 
                    umount -l ${ISOMOUNTPATH} &>/dev/null
                fi
            else
                pxelog "[error]${ISOMOUNTPATH} is not mounted, cann't clean!"
                return 1
            fi
        elif [[ $oper == "clean" ]]; then
            if [[ $used_number -ne 0 ]]; then
                used_number=0
            fi        
        else
             pxelog "repir_iso_nfs_number inputpara err: oper=$oper!"
        fi
        sed -i "s%${ISOMOUNTPATH} .*%${ISOMOUNTPATH}        $used_number%g" $ISO_NFS_TAB
        pxelog "after $oper ${MACADDR}, ${ISOMOUNTPATH} is used by $used_number nfs client!"
    ) 200>/var/log/iso_nfs_tab.lock
    
    pxelog "started repair $ISOMOUNTPATH used number in $ISO_NFS_TAB!"
}

function clean_iso_nfs_number
{
    local ISOMOUNTPATH
    
    [[ ! -f $ISO_NFS_TAB ]] && return 0
    
    pxelog "starting clean $ISO_NFS_TAB!"
    (
        flock -x 200
        for (( i=1; i<=$ISO_MOUNT_DIR_NUM; i++))
        do
            ISOMOUNTPATH=/linuxinstall/linuxinstall_$i
            systemctl disable linuxinstall-linuxinstall_$i.mount &>/dev/null
            systemctl stop linuxinstall-linuxinstall_$i.mount &>/dev/null
            umount -l ${ISOMOUNTPATH} &>/dev/null
            sed -i "s%${ISOMOUNTPATH} .*%${ISOMOUNTPATH}        0%g" $ISO_NFS_TAB
        done
    ) 200>/var/log/iso_nfs_tab.lock    
    
    pxelog "started to clean $ISO_NFS_TAB!"
      
}

function clean_os_files
{
    local MACADDR=$1
    local OS_TABLE=$2
    local linuxinstall_dir=""
    
    #ɾ��/home/install_share��/tftpboot�º�Ŀ�����صĶ���
    rm /home/install_share/${MACADDR} -rf
    rm /tftpboot/${MACADDR} -rf
    rm /tftpboot/pxelinux.cfg/01-${MACADDR} -rf
    
    #�����Ŀ���ʹ�õ�iso mount·����ʹ������һ���������0�ˣ���umount
    [[ -f $OS_TABLE ]] && { linuxinstall_dir=`cat $OS_TABLE | grep -wi "$MACADDR" |awk -F' ' '{print $4}'`; }
    if [[ `echo $linuxinstall_dir |grep "/linuxinstall/linuxinstall_*"` != "" ]]; then
        repir_iso_nfs_number $MACADDR $linuxinstall_dir "dec"
        local newlog=`cat $OS_TABLE | grep -wi "$MACADDR" |sed "s%$linuxinstall_dir%null%g"`
        sed -i "s%$MACADDR.*%$newlog%g" $OS_TABLE
    else
        pxelog "[info]$MACADDR does not have a iso nfs dir or $OS_TABLE not exist!"
    fi
}

function clean_all_os_files
{
    #ɾ��/home/install_share��/tftpboot������Ŀ�����صĶ���
    rm /home/install_share/* -rf
    
    if [[ -d /tftpboot ]]; then
        mkdir -p /tftpboot_bak
        cp -rf /tftpboot/* /tftpboot_bak/
        rm -rf /tftpboot/*
        cp /tftpboot_bak/initrd.img /tftpboot/
        cp /tftpboot_bak/pxelinux.0 /tftpboot/
        cp /tftpboot_bak/vmlinuz /tftpboot/
        cp -rf /tftpboot_bak/pxelinux.cfg /tftpboot/
        rm -rf /tftpboot/pxelinux.cfg/01-*
        rm -rf /tftpboot_bak 
    fi   
    
    #������/linuxinstall/linuxinstall_n��·��umount��ʹ����Ҳ��0
    clean_iso_nfs_number
}

function clean_os_table
{
    local MACADDR=$1
    local OS_TABLE=$2
    
    if [ -f ${OS_TABLE} ]; then
        [[ `cat ${OS_TABLE} |grep "${MACADDR}"` != "" ]] &&  sed -i "/${MACADDR}/d" ${OS_TABLE}
    fi    
}

#���ĳ��Ŀ���ʹ�ù�������ip����־
function clean_mac_all_log
{
    local dhcp_mac=$1
    local lease_file=/var/lib/dhcpd/dhcpd.leases
    local line_mac
    local ip_addr
    local log_postfix
    install_log_tmp=""
    
    #��ȡlease�ļ����Ƿ�������mac��ַ
    list=`grep -n -wi "${dhcp_mac}" ${lease_file} |awk -F':' '{print $1}'`
    
    [[ ${list} == "" ]] && { pxelog "pxe server did not assign an ip to this target machine";return 1; }
        
    #���lease�ļ����Ƿ�������mac��ַ��ɾ����һ��
    for i in $list
    do
        #�ҵ��������mac��ַ���ڵ��к�
        line_mac=$i
        
        #�ҵ�����к�֮ǰ���һ�γ��ֵ�ip
        line=`head -n ${line_mac} ${lease_file} | grep -n -o '\<[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\>' |tail -n 1`
               
        ip_addr=`echo $line |awk -F':' '{print $2}'`
                        
        #��ip��ַ�õ�log��־�ļ������������־
        install_log_tmp=/var/log/${ip_addr}
        log_postfix=".log"
        install_log_tmp=${install_log_tmp}${log_postfix}
                
        if [[ ${install_log_tmp} != "" ]]; then
            INSTALL_LOG_TMP=${install_log_tmp}
            if [ -f ${INSTALL_LOG_TMP} ]; then
              echo > ${INSTALL_LOG_TMP}
              pxelog "clean_mac_all_log dhcp_mac=${dhcp_mac} MACADDR=${MACADDR} install_log_tmp=${install_log_tmp} clean ${install_log_tmp}!"
            else
                pxelog "clean_mac_all_log dhcp_mac=${dhcp_mac} MACADDR=${MACADDR} install_log_tmp=${install_log_tmp} not exist!"
            fi
        fi
    done
    return 0    
}

#�������Ŀ���ʹ�ù�������ip����־
function clean_all_log
{
    local lease_file=/var/lib/dhcpd/dhcpd.leases
    local ip_addr
    local log_postfix
    install_log_tmp=""
    
    [[ ! -f $lease_file ]] && return 0
    
    #��ȡlease�ļ������з����ȥ��ip
    list=`cat $lease_file |grep -o '\<[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\>'`
    
    [[ ${list} == "" ]] && { pxelog "pxe server did not assign an ip to any target machine";return 1; }
        
    #���lease�ļ����Ƿ�������mac��ַ��ɾ����һ��
    for i in $list
    do
        ip_addr=$i
                        
        #��ip��ַ�õ�log��־�ļ������������־
        install_log_tmp=/var/log/${ip_addr}
        log_postfix=".log"
        install_log_tmp=${install_log_tmp}${log_postfix}
                
        if [[ ${install_log_tmp} != "" ]]; then
            INSTALL_LOG_TMP=${install_log_tmp}
            if [ -f ${INSTALL_LOG_TMP} ]; then
                echo > ${INSTALL_LOG_TMP}
                pxelog "clean_all_log install_log_tmp=${install_log_tmp} clean ${install_log_tmp}!"
            else
                pxelog "clean_all_log install_log_tmp=${install_log_tmp} not exist!"
            fi
        fi
    done
    return 0    
}

#���ĳ��Ŀ������ʹ�õ�ip����־
function clean_mac_last_log
{
    local dhcp_mac=$1
    
    convert_mac_to_ip ${dhcp_mac} || { return 1; }
    INSTALL_LOG=${install_log}
                        
    if [ -f ${INSTALL_LOG} ]; then
        echo > $INSTALL_LOG
        pxelog "clean_mac_last_log dhcp_mac=${dhcp_mac} MACADDR=${MACADDR} install_last_log=${INSTALL_LOG} clean ${INSTALL_LOG}!"
    else
        pxelog "clean_mac_last_log dhcp_mac=${dhcp_mac} MACADDR=${MACADDR} install_last_log=${INSTALL_LOG} not exist!"
    fi
    return 0    
}

