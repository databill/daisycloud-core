
##��Windows����PCLint���ʱ����
ifeq (_OS_NT,$(_COMPILE_TYPE))
export _TECS_ROOT_PATH           =    z:
else
export _TECS_ROOT_PATH           =    $(shell pwd)/..
endif

export _TECS_CODE_PATH           = $(_TECS_ROOT_PATH)/code
export _TECS_CLIENT_PATH         = $(_TECS_ROOT_PATH)/client
export _TECS_CONTRIB_PATH        = $(_TECS_ROOT_PATH)/contrib
export _TECS_BACKEND_PATH         = $(_TECS_ROOT_PATH)/backend
export _TECS_TARGET_PATH         = $(_TECS_ROOT_PATH)/target
export _TECS_TMP_PATH            = $(_TECS_ROOT_PATH)/tmp
export _TECS_MAK_PATH            = $(_TECS_ROOT_PATH)/make
export _TECS_TOOLS_PATH          = $(_TECS_ROOT_PATH)/tools
export _TECS_RPM_PATH            = $(_TECS_ROOT_PATH)/rpm


export VER_PREFIX = installdaisy
export VER_SUFFIX = bin
## ���빤����·��
export CROSS_COMPILE_BASE        = /opt
export LINT_CROSS_COMPILE_BASE   = X:

export _TECS_VERNO        =    02.01.10
##���ɲ��԰汾��
ifeq ($(BUILD_NUMBER),) 
export VER_I              = 0
else
export VER_I              = $(BUILD_NUMBER)
endif
##ϵͳ���԰汾��
export VER_B              = 1
##���ⷢ���汾��
export VER_P              = 1
##RELEASE�汾��,�˱���һ����Ҫ�ڱ����ʱ��ָ��
export _VER_REL           = $(VER_P).$(VER_B).$(VER_I)

##Openstackϵͳ���԰汾��
export VER_OPENSTACK_B              = 0
##Openstack���ⷢ���汾��
export VER_OPENSTACK_P              = 1
export VER_OPENSTACK_I              = 0

##Openstack RELEASE�汾��,�˱���һ����Ҫ�ڱ����ʱ��ָ��
export _VER_OPENSTACK_REL           = $(VER_OPENSTACK_P).$(VER_OPENSTACK_B).$(VER_OPENSTACK_I)

export _VER_DAISYCLIENT_REL        = $(_VER_OPENSTACK_REL)
export _VER_IRONICDISCOVERD_REL        = $(_VER_OPENSTACK_REL)
