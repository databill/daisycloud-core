#!/bin/bash
#1.���ȫ�ֱ��������ܻᱻ���������ű����ã�export��Ҳ�ɱ��ӽ����е�ִ�еĽű�����
#2.���нű��в����к���Щ�������ֳ�ͻ�ı���
#3.�벻Ҫ�������ȫ�ֱ������⸳ֵ����Щ��ʼ������Ϊ�� 

#��ֹ�ű��ظ�������
if [ ! "$_GLOBAL_VAR_FILE" ];then

#daisy��װ�򵼲���ʱ���¼
export current_time=""
#daisy����������install��uninstall��clean��upgrade��
export operation=""
#��װ�еľ���ģʽ
export mode=""
#yum�����װ
export daisy_yum=""

#daisy��װ�ļ�Ŀ¼
export daisy_install_path="/home/daisy_install"

export systemd_path="/usr/lib/systemd/system"
export lsb_path="/etc/init.d"
#�û�ָ�������ļ�

#���ݿ��û�������
export dbusername=root
export dbpassword=root

export _GLOBAL_VAR_FILE="daisy_global_var.sh"
fi
