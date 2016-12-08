#!/bin/bash

###############################################################################################
#    ���ܣ���ȡos��װ���ȵĺ�������
###############################################################################################
function find_string_in_file
{
    local file=$1
    local string=$2
    exist=yes

    local result=`cat ${file} |grep -a "${string}"`
    [[ ${result} == "" ]] && exist=no
}

function print_progress
{
    local OS_TABLE=$1
    local MACADDR=$2
    local descript
    
    descript=`cat ${OS_TABLE} | grep -wi "${MACADDR}" |awk -F' ' '{print $2"   "$3}'`
    pxelog "${descript}" "console"
}

function modify_os_table
{
    local OS_TABLE=$1
    local MACADDR=$2
    local rate_value=$3
    local rate_descript=$4
    
    local tmp_rate=`cat $OS_TABLE | grep -wi "$MACADDR" |awk -F' ' '{print $2}'`
    
    [[ $rate_value == $tmp_rate ]] && return 0
    
    local linuxinstall_dir=`cat $OS_TABLE | grep -wi "$MACADDR" |awk -F' ' '{print $4}'`
    sed -i "s%${MACADDR}.*%${MACADDR}   ${rate_value}   ${rate_descript}   ${linuxinstall_dir}%g" ${OS_TABLE}
}

#�������
function set_done
{
    local INSTALL_LOG=$1
    local OS_TABLE=$2
    local MACADDR=$3
    
    modify_os_table ${OS_TABLE} ${MACADDR} "100" "done_install"
    pxelog "${MACADDR} install complete, will clean files and ${INSTALL_LOG}!"
    print_progress ${OS_TABLE} ${MACADDR}
    clean_os_files ${MACADDR} ${OS_TABLE}
    echo > ${INSTALL_LOG}
}


#�˺������Ǵ���־�ļ�����anaconda��������׶εĹؼ�����ȷ�ϰ�װ���ȣ�ÿ���׶ζ�Ӧ�İ�װ�����ǹ̶���
#�����Ľ׶���ǰ��ʼ���������˸�������ֵ������Ҫ���·������ϵ�һ��Ŀ�����װͳ�Ʊ�
#����anaconda: Thread Done: AnaConfigurationThread----100% done_install
#����anaconda: Running Thread: AnaConfigurationThread----62%-100%   post_config
#����anaconda: Running Thread: AnaInstallThread----2%-62%   package_install���ڼ���Ҫ��ϸ��
#����anaconda: Running Thread: AnaStorageThread----1%   storage_config
#����0%  plan_install
#$1: Ŀ�����װ��־�ļ�
#$2: Ŀ�����װͳ�Ʊ�
#$3: Ŀ���mac��ַ
function get_progress_rh70_base
{
    local INSTALL_LOG=$1
    local OS_TABLE=$2
    local MACADDR=$3
    local descript
    local rate_value 
    
    
    #�鿴��־������anaconda: Thread Done: AnaConfigurationThread,�ѵ��ˣ���ʾ��װ��ɣ�������100%
    descript="anaconda: Thread Done: AnaConfigurationThread"
    find_string_in_file ${INSTALL_LOG} "${descript}"
    if [ ${exist} == yes ]; then
        set_done $INSTALL_LOG $OS_TABLE $MACADDR
        return 0
    fi       
    
        
    #�鿴��־������anaconda: Running Thread: AnaConfigurationThread���ѵ��ˣ���ʾ��ִ��post�׶ε����ã�������62%-100%�������ַֺü����׶�
    descript="anaconda: Running Thread: AnaConfigurationThread"
    find_string_in_file ${INSTALL_LOG} "${descript}"
    if [ ${exist} == yes ]; then
        #�鿴��־������yum.*Installed�ĸ������ܹ�28�����ڼ�ٷֱ���79-96%
        number=`cat ${INSTALL_LOG} |grep "yum.*Installed" | wc -l`
        if [ ${number} -gt 0 ]; then
            ((rate_value=${number}*17/28+79)) 
            [[ $rate_value -gt 99 ]] && rate_value=99
            modify_os_table ${OS_TABLE} ${MACADDR} "${rate_value}" "post_config"
            print_progress ${OS_TABLE} ${MACADDR}
            return 0
        fi
    
        #�鿴��־������anaconda: Running post-installation scripts,�ѵ��ˣ���ʾ�Ѿ�ִ����66%
        descript="anaconda: Running post-installation scripts"
        find_string_in_file ${INSTALL_LOG} "${descript}"
        if [ ${exist} == yes ]; then
            modify_os_table ${OS_TABLE} ${MACADDR} "66" "post_config"
            print_progress ${OS_TABLE} ${MACADDR}            
            return 0
        fi         
        
        modify_os_table ${OS_TABLE} ${MACADDR} "62" "post_config"
        print_progress ${OS_TABLE} ${MACADDR}
        return 0
    fi       
        
    #�鿴��־������anaconda: Running Thread: AnaInstallThread���ѵ��ˣ���ʾ��ִ��package�İ�װ��2%-62%�������ַֺü����׶�
    descript="anaconda: Running Thread: AnaInstallThread"
    find_string_in_file ${INSTALL_LOG} "${descript}"
    if [ ${exist} == yes ]; then
        #�鿴��־������packaging:  transaction complete���ѵ��ˣ���ʾ�Ѿ�ִ����61%
        descript="packaging:  transaction complete"
        find_string_in_file ${INSTALL_LOG} "${descript}"
        if [ ${exist} == yes ]; then
            modify_os_table ${OS_TABLE} ${MACADDR} "61" "package_install"
            print_progress ${OS_TABLE} ${MACADDR}
            return 0
        fi
    
        #�鿴��־������packaging: Installed products updated���ѵ��ˣ���ʾ�Ѿ�ִ����54%
        descript="packaging: Installed products updated"
        find_string_in_file ${INSTALL_LOG} "${descript}"
        if [ ${exist} == yes ]; then
            modify_os_table ${OS_TABLE} ${MACADDR} "54" "package_install"
            print_progress ${OS_TABLE} ${MACADDR}
            return 0
        fi
        
        #�鿴��־������packaging: Performing post-installation setup tasks���ѵ��ˣ���ʾ�Ѿ�ִ����43%
        descript="packaging: Performing post-installation setup tasks"
        find_string_in_file ${INSTALL_LOG} "${descript}"
        if [ ${exist} == yes ]; then
            modify_os_table ${OS_TABLE} ${MACADDR} "43" "package_install"
            print_progress ${OS_TABLE} ${MACADDR}
            return 0
        fi
        
        #�鿴��־������packaging: Preparing transaction from installation source���ѵ��ˣ���ʾ��5%-43%֮�䣬��Ҫ���ݰ�װ�İ�����ϸ��
        descript="packaging: Preparing transaction from installation source"
        find_string_in_file ${INSTALL_LOG} "${descript}"
        if [ ${exist} == yes ]; then
            descript="packaging: Installing"
            find_string_in_file ${INSTALL_LOG} "${descript}"
            if [ ${exist} == yes ]; then
                #���ݰ�װ�����������
                #��ȡ����־�а�װ�����һ����¼packaging: Installing **** (**/***) 
                descript=`cat ${INSTALL_LOG} |grep "packaging: Installing" | tail -n 1`
                #��ȡ����װ�İ������ܰ���**/***
                descript=${descript%\)*}
                descript=${descript##*\(}
                local total_pachages=${descript#*/}
                local installed_packages=${descript%/*}
                pxelog "total_pachages=$total_pachages installed_packages=$installed_packages"
                ((rate_value=${installed_packages}*38/${total_pachages}+5))
                modify_os_table ${OS_TABLE} ${MACADDR} "${rate_value}" "package_install"
                print_progress ${OS_TABLE} ${MACADDR}
                return 0
            fi
        
            modify_os_table ${OS_TABLE} ${MACADDR} "5" "package_install"
            print_progress ${OS_TABLE} ${MACADDR}
            return 0
        fi
        
        
        modify_os_table ${OS_TABLE} ${MACADDR} "2" "package_install"
        print_progress ${OS_TABLE} ${MACADDR}
        return 0
    fi
    
    #�鿴��־������anaconda: Running Thread: AnaStorageThread���ѵ��ˣ���ʾ��ִ�д洢�豸�����ã�������1%
    descript="anaconda: Running Thread: AnaStorageThread"
    find_string_in_file ${INSTALL_LOG} "${descript}"
    if [ ${exist} == yes ]; then
        modify_os_table ${OS_TABLE} ${MACADDR} "1" "storage_config"
        print_progress ${OS_TABLE} ${MACADDR}
        return 0
    fi    
    
    modify_os_table ${OS_TABLE} ${MACADDR} "0" "plan_install"
    print_progress ${OS_TABLE} ${MACADDR}
    return 0 
}

function get_progress_rh65_base
{
    local INSTALL_LOG=$1
    local OS_TABLE=$2
    local MACADDR=$3
    local tmp_process=""
    local tmp_rate=""
    
    
    local array_process=("complete" "dopostaction" "postscripts" "methodcomplete" "copylogs" "setfilecon" 
                     "writeksconfig" "reipl" "instbootloader" "firstboot" "writeconfig" "postinstallconfig"
                     "installpackages" "preinstallconfig" "install" "postselection" "basepkgsel" "reposetup"
                     "bootloadersetup" "enablefilesystems" "storagedone" "autopartitionexecute" "setuptime")
    local array_rate=("100" "95" "90" "85" "80" "75"\
                      "70" "65" "60" "55" "50" "45"\
                      "40" "35" "30" "25" "20" "15"\
                      "10" "7" "3" "2" "1")                      
    local array_process_num=${#array_process[@]}                
    local array_rate_num=${#array_rate[@]} 
     
    [[ $array_process_num != $array_rate_num ]] && { pxelog "array_process_num != array_rate_num"; return 1; }
    
    for (( i=0; i<$array_process_num; i++ ))
    do
        tmp_process=${array_process[$i]}
        tmp_rate=${array_rate[$i]}
        #redhat6.5��־���ص��ǣ�һ���׶ο�ʼ�ı�־moving (1) to step *****���׶ν����ı�־leaving (1) step *****�������ÿ�ʼ�ı�־��ġ�to step *****����Ϊ��ѯ�ؼ���
        if [[ `cat $INSTALL_LOG | grep -w "to step $tmp_process"` != "" ]]; then
            if [[ $tmp_rate == 100 ]]; then            
               set_done $INSTALL_LOG $OS_TABLE $MACADDR                  
            else
               modify_os_table ${OS_TABLE} ${MACADDR} "$tmp_rate" "$tmp_process"
               print_progress ${OS_TABLE} ${MACADDR}
            fi
            break       
        fi
    done 
    
    if [[ $i == $array_process_num ]]; then
        modify_os_table ${OS_TABLE} ${MACADDR} "0" "plan_install"
        print_progress ${OS_TABLE} ${MACADDR}
    fi
}



function get_progress
{
    local INSTALL_LOG=$1
    local OS_TABLE=$2
    local MACADDR=$3
    local descript
    local keywords="to step setuptime"
    
    #��־�����ڵ�����£���Ŀ�����װͳ�Ʊ�����ȥ��һ����Ӧ�İ�װ������������0%Ҳ����100%����ô����
    if [ ! -f ${INSTALL_LOG} ]; then
        descript=`cat ${OS_TABLE} | grep -wi "${MACADDR}" |awk -F' ' '{print $2}'`
        if [[ ${descript} != "0" && ${descript} != "100" ]];then
            modify_os_table ${OS_TABLE} ${MACADDR} "0" "error"            
            pxelog "log file ${INSTALL_LOG} not exist,can not get progress!"     
        fi
        print_progress ${OS_TABLE} ${MACADDR}
        return 0
    fi    
    
    #����־�в��ҹؼ��֣�to step setuptime������ҵ��ˣ���redhat6.5�Ĺ��򶨽��ȣ�����redhat7.0�ķ�ʽ
    if [[ `cat $INSTALL_LOG |grep "$keywords"` != "" ]]; then
        get_progress_rh65_base $@; return $?
    else
        get_progress_rh70_base $@; return $?
    fi
}
