#! /bin/bash

is_sbcx=no
TEMPLATE_IFCFG=/etc/sysconfig/network-scripts/template-ifcfg

#######################
#��ȡ����������
#######################
function get_board_type
{
    is_sbcx=no
    
    if [[ `dmidecode |grep "SBCJ"` != "" ]];then
        is_sbcx=yes
    fi
    
    if [[ `dmidecode |grep "SBCR"` != ""  ]];then
        is_sbcx=yes
    fi
    
    return 0
}

#######################
#ɾ���������ڵ������ļ�
#######################
function rm_ifcfg_file
{    
    
    IFCFG=/etc/sysconfig/network-scripts/
    for i in `ls /etc/sysconfig/network-scripts/ |grep ifcfg-`;
    do        
        if [[ $i != "ifcfg-lo" ]];then
            rm $IFCFG$i
        fi
    done
    
    return 0
}

#######################
#�������������ļ�ģ��
#######################
function create_tmp_ifcfg
{  
if [ ! -e $TEMPLATE_IFCFG ] ; then
cat >>$TEMPLATE_IFCFG <<'EOF'
BOOTPROTO="static"
ONBOOT="yes" 
EOF
fi

   return 0
}

#######################
#���ڹ̻�ʵ��
#######################
function eth_nicfix
{
    local eth_name=$1
    local eth_pci=$2
    local udev_config_file="/etc/udev/rules.d/72-nicfix.rules"
        
    #SBCJ��SBCR��Ƭ�޸ģ�����������ֱ���޸�udev����
    #if [[ ${is_sbcx} = "yes" ]];then
    #    echo "sbcx"
    #else
    #   echo "not sbcx"       
    #fi
    
    [[ ! -e $udev_config_file ]] && touch $udev_config_file
    if [[ -z `cat $udev_config_file | grep "$eth_pci"` ]];then
       local rule="SUBSYSTEM==\"net\", ACTION==\"add\", KERNELS==\"${eth_pci}\", NAME:=\"${eth_name}\""
       echo ${rule} >> $udev_config_file
    else
         sed -i  "/$eth_pci/s/NAME:=\".*\"/NAME:=\"${eth_name}\"/"  $udev_config_file 
    fi
}

#######################
#���������޸�
#######################
function eth_config
{
    local eth_name=$1
    local eth_ip=$2
    local eth_netmask=$3
    local eth_gateway=$4
    local eth_mode=$5
    local IFCFG=/etc/sysconfig/network-scripts/ifcfg-$eth_name  
    
    create_tmp_ifcfg
    
    if [ ! -e $IFCFG ]; then
        cp -f $TEMPLATE_IFCFG $IFCFG
        echo "nicfix: creat $IFCFG "
        echo "DEVICE=\"$eth_name\"" >> $IFCFG 
    else
        #�����������bond��Ա�ڣ���ô����Ҫ��ip
        if [[ `cat $IFCFG |grep "SLAVE=yes"` != "" ]]; then            
            eth_ip=""
            eth_netmask=""
            eth_gateway=""
            eth_mode=""
        fi
    fi
    sed -i '/HWADDR/d' $IFCFG
    [[ ! -z $eth_ip ]] &&  echo "IPADDR=\"$eth_ip\"" >> $IFCFG
    [[ ! -z $eth_netmask ]] &&  echo "NETMASK=\"$eth_netmask\"" >> $IFCFG
    [[ ! -z $eth_gateway ]] &&  echo "GATEWAY=\"$eth_gateway\"" >> $IFCFG
    [[ ! -z $eth_mode ]] &&  echo "BONDING_OPTS=\"miimon=100 mode=$eth_mode\"" >> $IFCFG
}


#######################
#bond�������޸�
#######################
function bond_config
{
    local bond_name=$1
    local bond_ip=$2
    local bond_netmask=$3
    local bond_gateway=$4
    local bond_mode=$5  
    local bond_slave1=$6  
    local bond_slave2=$7  
    
    #����ifcfg-$bond_name
    eth_config "$bond_name" "$bond_ip" "$bond_netmask" "$bond_gateway" "$bond_mode"
    
    #�޸�/etc/modprobe.d/bonding.conf
    local BOND_CFG=/etc/modprobe.d/bonding.conf
    [ ! -e ${BOND_CFG} ] && touch ${BOND_CFG}
    echo "alias ${bond_name} bonding" >>${BOND_CFG}
    echo "options ${bond_name} miimon=100 mode=${bond_mode}" >>${BOND_CFG}    
    
    #�޸ĸ�bond��Ա�ڵ������ļ�
    local bond_port="$bond_slave1 $bond_slave2"
    for i in ${bond_port};
    do
        local IFCFG=/etc/sysconfig/network-scripts/ifcfg-$i
        if [ ! -e $IFCFG ]; then            
           eth_config "$i" "" "" "" ""
        else
           #bond��Ա�ڲ���Ҫ��ip
           sed -i '/IPADDR/d' $IFCFG
           sed -i '/NETMASK/d' $IFCFG
           sed -i '/GATEWAY/d' $IFCFG
        fi
        
        if [[ `cat $IFCFG |grep "MASTER"` = "" ]]; then
            echo "MASTER=$bond_name" >> $IFCFG   
        else
            sed -i  "s/MASTER=.*/MASTER=$bond_name/"  $IFCFG 
        fi
            
        if [[ `cat $IFCFG |grep "SLAVE"` = "" ]]; then
            echo "SLAVE=yes" >> $IFCFG   
        else
            sed -i  "s/SLAVE=.*/SLAVE=yes/"  $IFCFG 
        fi
    done
}

function vlan_config
{
    local eth_name=$1
    local vlan_id=$2
    local eth_ip=$3
    local eth_netmask=$4
    local eth_gateway=$5
    local vlan_eth_name="$eth_name.$vlan_id"
    
    ip link add link $eth_name name $vlan_eth_name type vlan id $vlan_id    
    
    #����ifcfg-$vlan_eth_name
    eth_config "$vlan_eth_name" "$eth_ip" "$eth_netmask" "$eth_gateway" ""
    
    echo "VLAN=yes" >>/etc/sysconfig/network-scripts/ifcfg-$vlan_eth_name
    
}

###################start#################
#��ȡ����������
#get_board_type

#ɾ���������ڵ������ļ�
rm_ifcfg_file

#ֹͣ�����Լ������ڹ̻�����
systemctl disable nicfix.service
systemctl stop nicfix.service

