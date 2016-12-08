#!/bin/bash
WORKDIR=/etc/pxe_install
source $WORKDIR/scripts/setup_func.sh
#source ./pxe_func.sh
source $WORKDIR/scripts/custom/interact.sh



#######################
#Ϊpxe server����ip
#######################
function set_svrip
{
	local ENV_CFG=$1
	
	# ���������ļ�����ȡdhcp�����ػ���������
	get_config $ENV_CFG "ethname_l"
	nic4dhcp=$config_answer
	
	# ��ȡ������Ϣ
	get_config $ENV_CFG "ip_addr_l"
	ipaddr=$config_answer
	get_config $ENV_CFG "net_mask_l"
	netmask=$config_answer
	pxelog "netmask is $netmask" "console"
	
	# �Ѷ�������ڵ�ַ�������
	for i in `ls /sys/class/net/`
	do
		is_link=`readlink /sys/class/net/$i | grep -c '/'`
		if [[ $is_link -eq 0 ]]; then
			continue
		fi    
		        
		if [ `ifconfig | grep -c $i:100` -eq 0 ]; then
			continue
		fi
		
		
		if [ `ifconfig $i:100 | grep -c "$ipaddr"` -eq 0 ]; then
			continue
		fi
		
		ifconfig $i:100 | grep -c "$ipaddr"
		
		ifconfig $i:100 0
		rm -rf /etc/sysconfig/network-scripts/ifcfg-"$i":100
	done

	# Ϊ���������ip��ַ����������Ч
	[[ `ifconfig $nic4dhcp |grep flag |grep -w UP` == "" ]] && ifconfig $nic4dhcp up
	ifconfig $nic4dhcp:100 $ipaddr netmask $netmask up
		
	nicfile=/etc/sysconfig/network-scripts/ifcfg-"$nic4dhcp":100
	
	touch $nicfile
	echo "DEVICE=\"$nic4dhcp:100\""   >  $nicfile
	echo "BOOTPROTO=\"static\""       >> $nicfile
	echo "ONBOOT=\"yes\""             >> $nicfile
	echo "IPADDR=$ipaddr"             >> $nicfile
	echo "NETMASK=$netmask"           >> $nicfile

}

#######################
#��װpxe���
#######################
function install_pxe
{
	local pxedir=$1
	cd $pxedir
	
	#/* ��װtftp ��RPM�� */
	rpm -qi xinetd >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./xinetd-2.3.15-12.el7.x86_64.rpm	
	rpm -qi tftp-server >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./tftp-server-5.2-11.el7.x86_64.rpm	
	rpm -qi tftp >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./tftp-5.2-11.el7.x86_64.rpm

	#/* ��װPXE�� */
	rpm -qi ipxe-roms-qemu >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./ipxe-roms-qemu-20130517-5.gitc4bce43.el7.noarch.rpm
	rpm -qi syslinux >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./syslinux-4.05-8.el7.x86_64.rpm

	#/* ��װDHCP�� */
	rpm -qi dhcp-common >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./dhcp-common-4.2.5-27.el7.x86_64.rpm	
	rpm -qi dhcp >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./dhcp-4.2.5-27.el7.x86_64.rpm

	#/* ��װntpdate�� */	
	rpm -qi ntpdate >/dev/null 
	[ $? -ne 0 ] && rpm -ivh ./ntpdate-4.2.6p5-18.el7.x86_64.rpm
	
	# ����tftp
	mkdir -p /tftpboot/pxelinux.cfg/

	# ������ǰĿ¼�µ�tftp�ļ��� xinetd.d����
	cp -rf ./tftp /etc/xinetd.d/

	cp -rf default /tftpboot/pxelinux.cfg/default
	
    cp -rf ./dhcpd.conf  /etc/dhcp
	
}


#######################
#����pxe�����ļ�����Ҫ�޸�dhcpd.conf/default
#######################
function custom_pxecfg
{
        pxelog "custom_pxecfg..." "console"
	local ENV_CFG=$1
	local DHCP_CFG=/etc/dhcp/dhcpd.conf
	local DEFAULT_CFG=/tftpboot/pxelinux.cfg/default
	
	get_config $ENV_CFG "ip_addr_l"
	svrip=$config_answer
	
	get_config $ENV_CFG "net_mask_l"
	mask=$config_answer

	subnet=`ipcalc -n "$svrip" "$mask" |awk -F'=' '{print $2}'`
	get_config $ENV_CFG "client_ip_begin"
	begin=$config_answer
	
	get_config $ENV_CFG "client_ip_end"
	end=$config_answer

	#sed -i "s/nfs:.*:\//nfs:$svrip:\//g"  	                        $DEFAULT_CFG
	#��default�µ�ks����ɾ��������dhcp_ip������
	sed -i "s/ks=.*pxe_kickstart.cfg/dhcp_ip=$svrip/g" $DEFAULT_CFG
	
	sed -i "s/next-server.*/next-server $svrip;/g"                  $DHCP_CFG
	
	sed -i "s/subnet.*netmask.*{/subnet $subnet netmask $mask {/g"  $DHCP_CFG
	
	sed -i "s/option routers.*;/option routers $svrip;/g"  	        $DHCP_CFG
	sed -i "s/option subnet-mask.*;/option subnet-mask $mask;/g"  	$DHCP_CFG
	sed -i "s/range.*;/range $begin $end;/g"                        $DHCP_CFG

}

#######################
#����pxe����
#######################
function start_pxesvr
{
	# �رշ���ǽ
	service iptables stop

	#/* ����NFS���� */
	service nfs restart

	#/* ����PXE���� */
	service xinetd restart

	#/* ����DHCP���� */
	if [ `service dhcpd status | grep -c running` == 0 ]; then
		service dhcpd restart
		pxelog "Inatall Environment Prepare Success! Have fun!" "console"
	else
		service dhcpd restart
		pxelog "Warning............................" "console"
		pxelog "Warning............................" "console"
		pxelog "Warning: other DHCP is Running. Restart DHCP....." "console"
		pxelog "Please Check Current Dhcp config. Sure Current Dhcp Can Auto Install ISO" "console"
		pxelog "Warning............................" "console"
		pxelog "Warning............................" "console"
	fi

	# ����pxe��ط���Ϊ���������� --added by xuyang
	chkconfig  --level 2345 nfs-server  on
	chkconfig  --level 2345 xinetd on
	chkconfig  --level 2345 dhcpd  on
	chkconfig  --level 2345 iptables  off
}

#pxe���ϲ�Ŀ¼��usrdata�����������ļ���ϵͳ
#��������������/home/install_share
