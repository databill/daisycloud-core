#!/bin/bash
# �ṩ��yum��װ��صĹ��������ͱ���
if [ ! "$_UPGRADE_INTERFACE_FILE" ];then
_UPGRADE_INTERFACE_DIR=`pwd`
cd $_UPGRADE_INTERFACE_DIR/../common/
.  daisy_common_func.sh
.  daisy_global_var.sh

cd $_UPGRADE_INTERFACE_DIR/../install/
.  install_func.sh

cd $_UPGRADE_INTERFACE_DIR
.  upgrade_func.sh

daisy_upgrade="/var/log/daisy/daisy_upgrade"
upgradedatefile=`date -d "today" +"%Y%m%d-%H%M%S"`
logfile=$daisy_upgrade/daisyupgrade_$upgradedatefile.log

function upgrade_daisy
{
    if [ ! -d "$daisy_upgrade" ];then
        mkdir -p $daisy_upgrade
    fi
 
    if [ ! -f "$logfile" ];then
        touch $logfile
    fi 

    write_upgrade_log "wait to stop daisy services..."
    stop_service_all 

    #��ȡ��ǰ����daisy�����
    get_daisy_services
    
    # ����daisy�����
    upgrade_rpms_by_yum "$all_daisy_services"

    
    #ͬ��daisy���ݿ�
    which daisy-manage >> $logfile 2>&1
    if [ "$?" == 0 ];then
        write_upgrade_log  "start daisy-manage db_sync..." 
        daisy-manage db_sync
        [ "$?" -ne 0 ] && { write_upgrade_log "Error:daisy-manage db_sync command faild"; exit 1; } 
    fi

    #ͬ��ironic���ݿ�
    which ironic-dbsync >> $logfile 2>&1
    if [ "$?" == 0 ];then
        write_upgrade_log "start ironic-dbsync ..." 
        ironic-dbsync --config-file /etc/ironic/ironic.conf
        [ "$?" -ne 0 ] && { write_upgrade_log "Error:ironic-dbsync --config-file /etc/ironic/ironic.conf faild"; exit 1; } 
    fi

    #ͬ��keystone���ݿ�
    which keystone-manage >> $logfile 2>&1
    if [ "$?" == 0 ];then
        write_upgrade_log  "start keystone-manage db_sync..." 
        keystone-manage db_sync
        [ "$?" -ne 0 ] && { write_upgrade_log "Error:keystone-manage db_sync command faild"; exit 1; } 
    fi

    write_upgrade_log  "wait to start daisy service..."
    start_service_all >> $logfile 2>&1

    write_upgrade_log  "Daisy upgrade successful..."
}

_UPGRADE_INTERFACE_FILE="upgrade_interface.sh"
fi
