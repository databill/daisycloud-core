##�˽ű�����һ��ʽִ��/home/opencos_install/afterĿ¼�µ�shell�ű�
##���ű��û�shell�ű��ļ�����/home/usrdata/Ŀ¼�£�ִ��./after.sh�Ϳ���ִ������/home/opencos_install/after�ű�
GUARD_DIR=/home/opencos_install/custom/after
[ ! -d $GUARD_DIR ] && exit 0
cd $GUARD_DIR
ALL_FILE=`ls $GUARD_DIR|grep .sh$`
RETVAL=
for FILE in $ALL_FILE
do    
    chmod +x $FILE
    bash $FILE
    RETVAL=$?
done
rpm -qi openstack-neutron-openvswitch >/dev/null && sed -i "/after.sh/d" /etc/rc.d/rc.local && sed -i "/sleep 30/d" /etc/rc.d/rc.local




