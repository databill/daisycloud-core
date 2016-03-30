#!/bin/sh
# ��ĳ���������������ң��Ժ�ssh��¼��ȥ����Ҫ����

#�������Ƿ�Ϸ�
ip=$1
if [ -z $ip ]; then
  echo "Usage: `basename $0` ipaddr passwd" >&2
  exit 1
fi

passwd=$2
if [ -z $passwd ]; then
  echo "Usage: `basename $0` ipaddr passwd" >&2
  exit 1
fi

rpm -qi sshpass >/dev/null 
if [ $? != 0 ]; then
  echo "Please install sshpass first!" >&2
  exit 1
fi

#���ԶԶ��ܲ���ping��ͨ
unreachable=`ping $ip -c 1 -W 3 | grep -c "100% packet loss"`
if [ $unreachable -eq 1 ]; then
  echo "host $ip is unreachable!!!"
  exit 1
fi

#���������û��ssh��Կ��������һ��
if [ ! -e ~/.ssh/id_dsa.pub ]; then
  echo "generating ssh public key ..."
  ssh-keygen -t dsa -f /root/.ssh/id_dsa -N ""
fi

#�����ڶԶ�ɾ��ԭ����������ι�Կ
user=`whoami`
host=`hostname`
keyend="$user@$host"
echo "my keyend = $keyend"
cmd="sed '/$keyend$/d'  -i ~/.ssh/authorized_keys"
#echo cmd:$cmd
echo "clear my old pub key on $ip ..."
sshpass -p $passwd ssh $ip "rm -rf /root/.ssh/known_hosts"
sshpass -p $passwd ssh $ip "touch ~/.ssh/authorized_keys"
sshpass -p $passwd ssh $ip "$cmd"

#�������ɵĿ�����ȥ
echo "copy my public key to $ip ..."
tmpfile=/tmp/`hostname`.key.pub
sshpass -p $passwd scp ~/.ssh/id_dsa.pub  $ip:$tmpfile

#�ڶԶ˽���׷�ӵ�authorized_keys
echo "on $ip, append my public key to ~/.ssh/authorized_keys ..."
sshpass -p $passwd ssh $ip "cat $tmpfile >> ~/.ssh/authorized_keys"
echo "rm tmp file $ip:$tmpfile"
sshpass -p $passwd ssh $ip "rm $tmpfile" 
echo "trustme ok!"




