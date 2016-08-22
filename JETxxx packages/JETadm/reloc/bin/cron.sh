#!/usr/xpg4/bin/sh
# Version	1.0
# Date		1 Aug 2000
# Author	Kirill Kartinkin

# ��������� ��������� ��������� � ������
# ��������������� ��������� ������.
#
# ��������! ��������� �������� ������ ��� ������� Qualix HA+.
#
#
# ���������:
#	$1	��� ��� id ��������� ������
#	$2	��� ������������
#	$3	�������
# ����� ������� ��������� ���������, �������� �� �� ������ ����
# ��������� ������, ��������� �� ������������ �������� � �������� cron
# � ��������� �������� ������� � ����� � �� ����� ������������.
# 
# ������������ ��������:
#	0	O.K.
#	1	��������� ������ �� �������� �� ���� ����
#	2	������������ �� ����� ������������ �������� cron
#	101	���������� ���������� ������� Logger

# ��� ������ ������ ��� ��� �������.
# ���� �������� �� ��������� ������, �� �������� POSIX-shell,
# � ���� ������� cron, �� ����� Bourne shell.
x="A.B"
x=`(echo ${x%%.*}) 2>/dev/null`
# Bourne shell �� ����� ��������� ���������� �� ���������
if [ "$x" != "A" ]
then
	# �����, ���� �� �����, �������� ���� ����	
	$0 $*
	exit $?
fi

PATH=/sbin:/usr/sbin:/usr/xpg4/bin:/usr/bin

# ���������� ������� Logger
LOGGER_FACILITY=daemon
LOGGER_TAG=cron
LOGGER_PRINT=0 # ������ ��������� �� ���������
if [[ -f /var/adm/bin/logger.sh ]]
then
	. /var/adm/bin/logger.sh
else
	print "ERROR: Unnable to source /var/adm/bin/logger.sh"
	exit 101
fi

CronAllow=/etc/cron.d/cron.allow
CronDeny=/etc/cron.d/cron.deny

integer Allow=0

# ��� �������� ��������� ������?
if [[ $(qhap cl -g all stat2 | \
		awk -v SG=$1 '$1 == SG || $2 == SG { print $3" "$4 }') \
	= "SERVED $(hostname)" ]]
then
	# �� ������ ����
	# �������� ��������� ���������� ������������ (��. crontab(1))

	# ���� ���� ����������
	if [[ -f ${CronAllow} ]]
	then
		# ���� ���������� ����, ���� ��� ������������
		if [[ -n $(grep $2 ${CronAllow}) ]]
		then
			# �����
			Allow=1
		fi
	# ����� ���������� ���, ���� ���� ��������
	elif [[ -f ${CronDeny} ]]
	then
		# ���� ���������� ����, ������� ���� �� ��
		if [[ -s ${CronDeny} ]]
		then
			# ���� �� ����, ���� ��� ������������
			if [[ -z $(grep $2 ${CronDeny}) ]]
			then
				# �� �������
				Allow=1
			fi
		else
			# ���� ���������� ����, ��������� ����
			Allow=1
		fi
	elif [[ $2 = "root" ]]
	then
		# ��� �� ����� ����������, �� ����� ����������
		Allow=1
	fi
			
	if (( ${Allow} == 1 ))
	then
		# ������������ ��������� ������������ ������ cron
		Logger info "Starting \"$3\" for user $2 on this node."

		# ��������� ������������ �������������� ��������
		case $2 in
			root)
				$3
				;;
			#informix)
			#	. ~informix/.environment
			#	su $2 -c "$3"
			#	;;
			*)
				su - $2 -c "$3"
				;;
		esac
		exit 0
	else
		# ������������ �� ��������� ������������ ������ cron
		Logger err "User $2 not allowed to use cron service."
		exit 2
	fi
else
	# ��������� ������ �������� �� ������ ����
	Logger debug "Service group $1 don't running on this node. Exiting."
	exit 1
fi
