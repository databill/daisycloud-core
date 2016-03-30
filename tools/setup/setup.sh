#!/bin/bash

#ע�⣺ȫ�ֱ������ֲ����ظ�
_SETUP_DIR=`pwd` 
packstack_answer_file="${_SETUP_DIR}/tecs.conf"
#ͷ�ļ�����
cd $_SETUP_DIR/common/ 
.  daisy_global_var.sh
.  daisy_common_func.sh
.  daisy_yum.sh

cd $_SETUP_DIR/install/
.  install_interface.sh

cd $_SETUP_DIR/upgrade/
.  upgrade_interface.sh

cd $_SETUP_DIR/uninstall/
.  uninstall_interface.sh

cd $_SETUP_DIR #�ص���ǰ�ű�Ŀ¼



function welcome
{
    echo
    echo "===================================="
    echo "    ZTE DAISY Installation Wizard"
    echo "===================================="
}

function showhelp
{
    echo
    echo "Usage: ./installtecs_(arch).bin"
    echo "operation supported: "
    
    echo "install:  install daisy automatically;"
    
    echo "upgrade:  upgrade daisy automatically;"
    
    echo "clean:  remove all daisy related packages on localhost automatically;"
    
    echo "help:  show help;"
    
    echo
}

function parse_args
{
    operation=""
    mode=""
    local optlist="$@" 
    local result=0
    
    while [ -n "$1" ]; do
        case $1 in
            "install")
                  [ "$operation" = "" ] && operation="install" || result=1
                shift
                ;;

            "uninstall")
                  [ "$operation" = "" ] && operation="uninstall" || result=1
                break
                ;;
            "clean")
                  [ "$operation" = "" ] && operation="clean" || result=1
                shift 
                ;;
            "upgrade")
                  [ "$operation" = "" ] && operation="upgrade" || result=1
                  break
                ;;
            "-y")
                  [ "$default_config" = "" ] && mode="conf" && default_config="true" || result=1
                  break
                ;;
            "unzip")
                  [ "$operation" = "" ] && operation="unzip" || result=1
                  break
                ;;
            "help")
                  showhelp
                  exit 0
                ;;
            *)
                result=1
                break
        
        esac
    done
     
    if [ "$result" -ne 0 ];then
         echo "error option \"$optlist\""
        showhelp
        exit "$result"
    fi
}


function unzip
{
    local path=$1
    if [ ! -e "$path" ]; then
        echo "Error! no unzip target path!"
        exit
    fi
    
    echo "begin to unzip $0 to $path, please wait ..."
    cp -fR ./* "$path"
    exit 0
}

# ��⵱ǰϵͳ���Ƿ�װ��TECS,�������ʾ�Ƿ����
function clean_tecs
{    
    check_installed "daisy"
    if [[ "$has_installed" == "yes" ]];then
    # ж�� DAISY ���� ���������а�װ���������������
        echo -e "daisy has been already installed on this host?"
        echo -e "Warning: overwrite installation will drop  user data of daisy!"
        read_bool "Do you want uninstall old daisy?" "no"
        [[ $answer == "no" ]] && return 
        # ���л�������
        uninstall_daisy        
        cd  $_SETUP_DIR       
    fi
}


#��ʾһ�������˵������û�ѡ��װ�����á�ж�ء�������
function operation_menu
{
    echo "1. install"
    echo "2. upgrade"
    echo "3. clean"
    echo "4. help"
    echo "5. exit"
    echo
    
    echo -e "Please select an operation: \c"
    read opt
    
    case $opt in
        "1") operation="install" ;;
        "2") operation="upgrade" ;;
        "3") operation="clean" ;;
        "4") operation="help" ;;
        "5") operation="exit";;
        *)
            echo "You select an invalid operation \"${opt}\"!"
            operation_menu
        ;;
    esac
}

# ������װ�˵���operationѡ��installʱ����˲˵�
function install_menu
{
    echo 
    echo "===================================="
    echo "      installation daisy             "
    echo "===================================="
    
    all_install
}

welcome

mkdir -p /home/daisy_install/
rm -rf /home/daisy_install/daisy-template.conf
cp daisy.conf /home/daisy_install/daisy-template.conf
if [ ! -e "/home/daisy_install/daisy.conf" ];then
    cp daisy.conf /home/daisy_install/daisy.conf
fi

#��װ������������Ҫ��¼��װʱ��ĵط����ȡ���ȫ�ֱ���
current_time=`date +%Y-%m-%d-%H-%M-%S`

#��ȡos type 
os_type="unknown"
[ "`uname -a | grep -c el6`" -eq 1 ] && os_type="el6"
[ "`uname -a | grep -c el7`" -eq 1 ] && os_type="el7"
[[ $os_type == "unknown" ]] && { echo "unknown os type: `uname -a`"; exit -1; }

if [[ -z "$@" ]];then
    operation_menu
else
    parse_args "$@" 
fi

[ -z "$operation" ] && echo "nothing to do?" && exit

case $operation in

    "install") 
    yum_set
    install_menu
    ;;
    
    "upgrade")
    yum_set
    upgrade_daisy
    ;;

    "clean")    
    yum_set    
    uninstall_daisy
    ;;
    "unzip")
    unzip $2    
    ;;

    "help")
    showhelp
    ;;

   "exit")
    echo "nothing to do?"
    exit 0
    ;;
    
    *)
    echo "unknown install argument: $operation!"
    showhelp
    ;;
esac

rm -rf /etc/yum.repos.d/daisy*.repo

