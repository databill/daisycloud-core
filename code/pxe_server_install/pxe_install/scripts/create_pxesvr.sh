#! /bin/bash

WORKDIR=/etc/pxe_install
source $WORKDIR/scripts/common.sh
source $WORKDIR/scripts/interface.sh
PXE_CFG=$2

#׼����������װjson�ļ���������jq��
rpm -qi jq >/dev/null 
[ $? -ne 0 ] && rpm -ivh ${WORKDIR}/pxe/jq-1.3-2.el7.x86_64.rpm

#׼���������ļ���
# ����/linuxinstall�Լ�������������
systemctl disable linuxinstall.mount &>/dev/null 
systemctl stop linuxinstall.mount &>/dev/null 


umount -l /linuxinstall &>/dev/null
for (( i=1; i<=$ISO_MOUNT_DIR_NUM; i++))
do
    [ ! -d /linuxinstall/linuxinstall_$i ] && mkdir -p /linuxinstall/linuxinstall_$i
    systemctl disable linuxinstall-linuxinstall_$i.mount &>/dev/null 
    systemctl stop linuxinstall-linuxinstall_$i.mount &>/dev/null
    umount -l /linuxinstall/linuxinstall_$i &>/dev/null
    rm -rf /linuxinstall/linuxinstall_$i/* &>/dev/null
done

# ����/home/install_share�Լ�������������
[ ! -d /home/install_share ] && mkdir -p /home/install_share
rm -rf /home/install_share/* 2>/dev/null

# ����/tftpboot�Լ�������������
[ ! -d /tftpboot ] && mkdir /tftpboot
rm -rf /tftpboot/* 2>/dev/null

# ����dhcp�����ip��ַ
pxelog "set dhcp ip..." "console"
#set_svrip $WORKDIR/pxe/pxe_env.conf

set_svrip $PXE_CFG

# ��װpxe���������
pxelog "install pxe..." "console"
PXE_FILE_PATH=$WORKDIR/pxe
install_pxe $PXE_FILE_PATH

# �����ļ�����
pxelog "config nfs..." "console"
systemctl stop nfs

# �鿴/etc/exports�Ƿ���#ע�ͱ�ǣ�����еĻ������������
install_share_dir=`cat /etc/exports | grep /home/install_share | grep \#`
[ -n "$install_share_dir" ] && sed -i "\/home\/install_share/d" /etc/exports

tftpboot_dir=`cat /etc/exports | grep /tftpboot | grep \#`
[ -n "$tftpboot_dir" ] && sed -i "\/tftpboot/d" /etc/exports

linuxinstall_dir=`cat /etc/exports | grep /linuxinstall | grep \#`
[ -n "$linuxinstall_dir" ] && sed -i "\/linuxinstall/d" /etc/exports

linuxinstall_dir=`cat /etc/exports | grep -w "/linuxinstall "`
[ -n "$linuxinstall_dir" ] && sed -i "\/linuxinstall/d" /etc/exports


#/* �����ļ����� */
[ `cat /etc/exports | grep -c /home/install_share` -eq 0 ] && { echo "/home/install_share *(rw,no_root_squash)">> /etc/exports; } \
             || { sed -i "s%/home/install_share.*%/home/install_share *(rw,no_root_squash)%g" /etc/exports; }
[ `cat /etc/exports | grep -c /tftpboot` -eq 0 ]           && { echo "/tftpboot *(ro)"      >> /etc/exports; } \
             || { sed -i "s%/tftpboot.*%/tftpboot *(ro)%g" /etc/exports; }
for (( i=1; i<=$ISO_MOUNT_DIR_NUM; i++))
do
    [ `cat /etc/exports | grep -c -w "/linuxinstall/linuxinstall_$i"` -eq 0 ]  && { echo "/linuxinstall/linuxinstall_$i *(ro)"  >> /etc/exports; } \
             || { sed -i "s%\/linuxinstall\/linuxinstall_$i .*%\/linuxinstall\/linuxinstall_$i *(ro)%g" /etc/exports; }
done

#����һ�ű�񣬴��10��iso��nfs·���Լ���ǰ��ʹ�õĴ���
rm -f $ISO_NFS_TAB &>/dev/null
touch $ISO_NFS_TAB
echo "iso_mount_point                    used" >>$ISO_NFS_TAB
for (( i=1; i<=$ISO_MOUNT_DIR_NUM; i++))
do
    echo "/linuxinstall/linuxinstall_$i        0" >>$ISO_NFS_TAB
done

# ����ISO�е��������򵽸�Ŀ¼
if [  -f "$WORKDIR/ramdisk/initrd.img" ]; then 
cp -f $WORKDIR/ramdisk/initrd.img        /tftpboot/
fi 

if [  -f "$WORKDIR/ramdisk/vmlinuz"  ]; then 
cp -f $WORKDIR/ramdisk/vmlinuz           /tftpboot/
fi 

cp -f /usr/share/syslinux/pxelinux.0           /tftpboot/


# ����pxe�����ļ�������ks�ļ�. �޸ĵ��ļ�·����/home/install_share/pxe_kickstart.cfg
#custom_pxecfg $WORKDIR/pxe/pxe_env.conf
custom_pxecfg $PXE_CFG


#����pxe������
start_pxesvr
 
