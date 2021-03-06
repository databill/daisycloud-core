#!/bin/bash
# provide yum related public functions and variables
if [ ! "$_INSTALL_INTERFACE_FILE" ];then
_INSTALL_INTERFACE_DIR=`pwd`
cd $_INSTALL_INTERFACE_DIR/../common/
.  daisy_global_var.sh
.  daisy_common_func.sh
cd $_INSTALL_INTERFACE_DIR
.  install_global_var.sh
.  install_func.sh

daisy_file="/etc/daisy/daisy-registry.conf"
db_name="daisy"
ironic_name="ironic"
keystone_db_name="keystone"
keystone_admin_token="e93e9abf42f84be48e0996e5bd44f096"
daisy_install="/var/log/daisy/daisy_install"
installdatefile=`date -d "today" +"%Y%m%d-%H%M%S"`
install_logfile=$daisy_install/daisyinstall_$installdatefile.log
discover_logfile="/var/log/ironic"
#the contents of the output is displayed on the screen and output to the specified file
function write_install_log
{
    local promt="$1"
    echo -e "$promt"
    echo -e "`date -d today +"%Y-%m-%d %H:%M:%S"`  $promt" >> $install_logfile
}
#install function
function all_install
{
    echo "*******************************************************************************"
    echo "daisy will installed  ..."
    echo "*******************************************************************************"

    if [ ! -d "$daisy_install" ];then
        mkdir -p $daisy_install
    fi

    if [ ! -f "$install_logfile" ];then
        touch $install_logfile
    fi

    if [ ! -d "$discover_logfile" ];then
        mkdir -p $discover_logfile
    fi

    rm -rf /root/.my.cnf
    [ "$?" -ne 0 ] && { write_install_log "Error:can not rm of /root/.my.cnf file"; exit 1; }
    write_install_log "install fping rpm"
    install_rpm_by_yum "fping"

    write_install_log "install mariadb-server rpm"
    install_rpm_by_yum "mariadb-server"

    write_install_log "install rabbitmq-server rpm"
    install_rpm_by_yum "rabbitmq-server"

    write_install_log "install keystone rpm"
    install_rpm_by_yum "openstack-keystone"

    write_install_log "install python-openstackclient rpm"
    install_rpm_by_yum "python-openstackclient"

    write_install_log "install ironic-discoverd depend rpm"
    install_rpm_by_yum "python-flask"

    write_install_log "install ironic-discoverd rpm"
    install_rpm_by_daisy_yum "openstack-ironic-discoverd python-ironic-discoverd"

    write_install_log "install daisy rpm"
    install_rpm_by_yum "daisy"

    write_install_log "install daisy dashboard rpm"
    install_rpm_by_yum "python-django"
    install_rpm_by_daisy_yum "python-django-horizon"
    install_rpm_by_yum "daisy-dashboard"

    write_install_log "install clustershell rpm"
    install_rpm_by_yum "clustershell"

    write_install_log "install discover relate rpm"
    install_rpm_by_yum "ipmitool"
    install_rpm_by_yum "syslinux"

    write_install_log "install wget rpm"
    install_rpm_by_yum "wget"


    if [ -f "/etc/zte-docker" ];then
        write_install_log "install pxe_docker_install rpm"
        install_rpm_by_yum pxe_docker_install
    else
        write_install_log "install pxe server rpm"
        install_rpm_by_daisy_yum pxe_server_install
        install_rpm_by_yum "dhcp"
        install_rpm_by_yum "nfs-utils"
    fi

    #get management network IP address, and then update the database of Daisy user to the configuration file
    get_public_ip
    if [ -z $public_ip ];then
        write_install_log "Error:default gateway is not set!!!"
        exit 1
    else
        update_section_config "$daisy_file" database connection "mysql://daisy:daisy@$public_ip/$db_name?charset=utf8"
        config_dashboard_local_setting
        config_keystone_local_setting
    fi

    ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
    systemctl restart httpd.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl restart httpd.service failed"; exit 1; }
    systemctl start daisy-api.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl start daisy-api.service failed"; exit 1; }
    systemctl start daisy-registry.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl start daisy-registry.service failed"; exit 1; }
    systemctl start mariadb.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl start mariadb.service failed"; exit 1; }

    systemctl enable httpd.service  >> $install_logfile 2>&1
    systemctl enable daisy-api.service >> $install_logfile 2>&1
    systemctl enable daisy-registry.service >> $install_logfile 2>&1
    systemctl enable mariadb.service >> $install_logfile 2>&1

    mysql_cmd="mysql"
    local mariadb_result=`systemctl is-active mariadb.service`
    if [ $? -eq 0 ];then
        # creat keystone datebase
        local create_keystone_sql="create database IF NOT EXISTS $keystone_db_name default charset=utf8"
        write_install_log "create $keystone_db_name database in mariadb"
        echo ${create_keystone_sql} | ${mysql_cmd}
        if [ $? -ne 0 ];then
            write_install_log "Error:create $keystone_db_name database failed..."
            exit 1
        fi

        # creat daisy datebase
        local create_db_sql="create database IF NOT EXISTS $db_name default charset=utf8"
        write_install_log "create $db_name database in mariadb"
        echo ${create_db_sql} | ${mysql_cmd}
        if [ $? -ne 0 ];then
            write_install_log "Error:create $db_name database failed..."
            exit 1
        fi

        # create keystone user
        write_install_log "create keystone user in mariadb"
        echo "grant all privileges on *.* to 'keystone'@'localhost' identified by 'keystone'" | ${mysql_cmd}
        if [ $? -ne 0 ];then
            write_install_log "Error:create keystone user failed..."
            exit 1
        fi

        # create daisy user
        write_install_log "create daisy user in mariadb"
        echo "grant all privileges on *.* to 'daisy'@'localhost' identified by 'daisy'" | ${mysql_cmd}
        if [ $? -ne 0 ];then
            write_install_log "Error:create daisy user failed..."
            exit 1
        fi

        # give the host access to keystone database
        write_install_log "Give the host access to the keystone database"
        echo "grant all privileges on keystone.* to 'keystone'@'%' identified by 'keystone'"| ${mysql_cmd}
        if [ $? -ne 0 ];then
            write_install_log "Error:Give the host access to the keystone database failed..."
            exit 1
        fi

        # give the host access to daisy database
        write_install_log "Give the host access to the daisy database"
        echo "grant all privileges on daisy.* to 'daisy'@'%' identified by 'daisy'"| ${mysql_cmd}
        if [ $? -ne 0 ];then
            write_install_log "Error:Give the host access to the daisy database failed..."
            exit 1
        fi

        echo "flush privileges"| ${mysql_cmd}

    else
        write_install_log "Error:mariadb service is not active"
        exit 1
    fi

    #creat keystone datebase tables
    which keystone-manage >> $install_logfile 2>&1
    if [ "$?" == 0 ];then
        write_install_log "start keystone-manage db_sync..."
        keystone-manage db_sync
        [ "$?" -ne 0 ] && { write_install_log "Error:keystone-manage db_sync command failed"; exit 1; }
        write_install_log "start keystone-manage fernet_setup..."
        keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
        [ "$?" -ne 0 ] && { write_install_log "Error:keystone-manage fernet_setup command failed"; exit 1; }
        write_install_log "start keystone-manage credential_setup..."
        keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
        [ "$?" -ne 0 ] && { write_install_log "Error:keystone-manage credential_setup command failed"; exit 1; }
        write_install_log "start keystone-manage bootstrap..."
        keystone-manage bootstrap --bootstrap-password $keystone_admin_token \
        --bootstrap-admin-url http://127.0.0.1:35357/v3/ \
        --bootstrap-internal-url http://127.0.0.1:35357/v3/ \
        --bootstrap-public-url http://127.0.0.1:5000/v3/ \
        --bootstrap-region-id RegionOne
        [ "$?" -ne 0 ] && { write_install_log "Error:keystone-manage bootstrap command failed"; exit 1; }
    fi

    params="--os-auth-url http://127.0.0.1:35357/v3 \
    --os-identity-api-version 3 \
    --os-project-domain-name default \
    --os-user-domain-name default \
    --os-project-name admin \
    --os-username admin \
    --os-password $keystone_admin_token"
    openstack $params project create --domain default --description "Demo Project" demo
    openstack $params user create --domain default --password daisy daisy
    openstack $params role create user
    openstack $params role add --project demo --user daisy user

    #creat daisy datebase tables
    which daisy-manage >> $install_logfile 2>&1
    if [ "$?" == 0 ];then
        write_install_log "start daisy-manage db_sync..."
        daisy-manage db_sync
        [ "$?" -ne 0 ] && { write_install_log "Error:daisy-manage db_sync command failed"; exit 1; }
    fi

    #add rabbitmq related configuration
    config_rabbitmq_env
    config_rabbitmq_config

    #Configure ironic related configuration items
    config_ironic_discoverd "/etc/ironic-discoverd/discoverd.conf" "$public_ip"

    #modify clustershell configuration
    clustershell_conf="/etc/clustershell/clush.conf"
    sed  -i "s/connect_timeout:[[:space:]]*.*/connect_timeout: 360/g" $clustershell_conf
    sed  -i "s/command_timeout:[[:space:]]*.*/command_timeout: 3600/g" $clustershell_conf

    systemctl restart rabbitmq-server.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl restart rabbitmq-server.service failed"; exit 1; }

    systemctl restart openstack-ironic-discoverd.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl restart openstack-ironic-discoverd.service failed"; exit 1; }

    systemctl start daisy-orchestration.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl start daisy-orchestration.service failed"; exit 1; }

    systemctl start daisy-auto-backup.service
    [ "$?" -ne 0 ] && { write_install_log "Error:systemctl start daisy-auto-backup.service failed"; exit 1; }
    
    systemctl enable daisy-orchestration.service >> $install_logfile 2>&1
    systemctl enable daisy-auto-backup.service >> $install_logfile 2>&1
    systemctl enable openstack-ironic-discoverd.service >> $install_logfile 2>&1

    #init daisy
    daisy_init_func

    modify_sudoers /etc/sudoers requiretty

    daisyrc_admin "$public_ip"

    build_pxe_server "$public_ip" "$bind_port"

    config_get_node_info

    write_install_log "Daisy Install Successfull..."

    config_file="/home/daisy_install/daisy.conf"
    [ ! -e $config_file ] && return

    if [ -f install_interface_patch.sh ]; then ./install_interface_patch.sh ; fi

    get_config "$config_file" default_backend_types
    local default_backend_types_params=$config_answer
    kolla=`echo $default_backend_types_params|grep 'kolla'|wc -l`
    if [ $kolla -ne 0 ];then
        write_install_log "Begin install kolla and depends..."
        kolla_install
    fi
}
_INSTALL_INTERFACE_FILE="install_interface.sh"

fi

