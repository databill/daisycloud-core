#! /bin/bash

###################################################################################
#  ѯ���밲װϵͳ��OS/OPENCOS����ص����ò���
#  ��ڣ�interact_setup
#  ��ģ��Ľ����ű�����/custom/interact/Ŀ¼��,���ڴ�interfact()��ӵ��ýű�����
###################################################################################
export WORKDIR
source $WORKDIR/scripts/custom/interact/neutron_interact.sh
#��������
function interfact()
{
    local CUSTOM_CFG_FILE=$1
    ask_manage_bond $CUSTOM_CFG_FILE $2
    ask_virtualization_mechanism $CUSTOM_CFG_FILE 
}



