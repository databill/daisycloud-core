#!/bin/bash

#���ڰ�װdaisyʹ�õ�ȫ�ֱ���

if [ ! "$_INSTALL_GLOBAL_VAR_FILE" ];then

database_server_port=5432
cloudname=daisycloud
clustername=daisycluster
debugmode="no"
message_server=""

_INSTALL_GLOBAL_VAR_FILE="install_global_var.sh"
fi
