##�˽ű�����һ��ʽִ��/home/opencos_install/Ŀ¼�µ�shell�ű�
##���ű��û�shell�ű��ļ�����/home/opencos_install/Ŀ¼�£�ִ��./before.sh�Ϳ���ִ������/home/opencos_install/�ű��Ľű�
GUARD_DIR=/home/opencos_install/custom/before
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
echo before>>/var/log/log.txt
[ $RETVAL -eq 0 ] && sed -i "/before.sh/d" /etc/rc.d/rc.local




