#!/usr/xpg4/bin/sh
# Version	3.0
# Date		3 Nov 98
# Author	Kirill Kartinkin
#
# ��������� ��������� ������� Logger � Date
#
# ��� ������������� ������� Logger �� ������ source ������ ����
# � ����� ��������� (. /var/adm/bin/logger.sh).
# ����� �������������� ��������� ���������
# ���������� ��������� ���������� ���������
# 	Name -- ��� ���������, ������������ ������� Logger 
#	LOGGER_FACILITY -- ������������ ��� �������
#		���� (facility.level). ����� ��������� ��������
#		user, kern, mail, daemon, auth, lpr, local0-5.
#		���� �� ������, �� user.
#	LOGGER_TAG --  ���������� ����� (tag) ��� ������������� ���������
#		��� �������� ���������� ���� ���������� �� ������ ������������
#		��� ���������� ���������, ��������, LOGGER_TAG='$MyTag'.
#		���� �� ������, �� Logger.
#	LOGGER_PRINT -- ���� �������� ����� 1 ��������� ������� ��������� � stdout
#	LOGGER_LOG -- ���� �������� ����� 1 ��������� ���������� ���������
#		�� ��������� syslog.
# 		��������� ����� �������� � stdout � ���������� � syslog,
#		���� ���� ���������� ��� ���������� �� �������.
#
# ���������:
# ���� ��������� ���� ���������, �� ���������� ������� Logger � �����������:
#	$1	-- ������� �������� ��������� (��. syslog (3C))
#	$2	-- ���������


################################################################################
# ������� ������� � stdout ������� ���� � ������� "��� �� ��:��:��",
# ��� ��� -- ������������� ���������� ������, �� -- ����� ������ (1-31),
# ��:��:�� -- ����� � 24-������� �������.
#
function Date
{
	date '+%b %e %X'
}

# ���������, ������� �� ���������� LOGGER_PRINT � LOGGER_LOG,
# � ������ ���������
if (( ${LOGGER_PRINT:-1} == 1 ))
then
	# ��� ������ ��������� ���������� print
	LOGGER_Print=print
else
	LOGGER_Print=:
fi

if (( ${LOGGER_LOG:-1} == 1 ))
then
	# ��� �������� ��������� ���������� ��������� logger
	LOGGER_Logger=logger
else
	LOGGER_Logger=:
fi

# ��������� LOGGER_FACILITY � LOGGER_TAG
# ���������� eval, ����� ����� ���� �������� ��������� ������
eval LOGGER_FACILITY=${LOGGER_FACILITY}
eval LOGGER_TAG=${LOGGER_TAG}

# ���� �������� ���������� �����, ���������� �� ���������
: ${LOGGER_FACILITY:=user}
: ${LOGGER_TAG:=Logger}

################################################################################
# ������� �������� ��������� �� ��������� syslog � ������� ��� � stderr.
# ���������:
#   $1 - ������� �������� (��. syslog (3C)). ����� ��������� ��������
#		alert, crit, err, warning, notice, info, debug
#   $2 - ����� ���������
#
# ������������ ��������� ����� ��������� ���:
#	��������: ���������
# ���������, ��������� � stdout, ����� � ��������� ���:
#	$(Date): ${Name} ��������: ���������
#	
function Logger
{
	case $1 in
		alert)
			LevelStr="Alert:    "
			;;
		crit)
			LevelStr="Critical: "
			;;
		err)
			LevelStr="Error:    "
			;;
		warning)
			LevelStr="Warning:  "
			;;
		notice)
			LevelStr="Notice:   "
			;;
		info)
			LevelStr="Info:     "
			;;
		debug)
			LevelStr="Debug:    "
			;;
		*)
			LevelStr=""
			${LOGGER_Print} "Logger: Bad option($1): $2" >&2
			${LOGGER_Logger} -p ${LOGGER_FACILITY}.debug -t ${LOGGER_TAG} "Bad option($1):  "$2
			;;
	esac
	if [[ ! -z ${LevelStr} ]]
	then
		${LOGGER_Print} "$(Date): ${Name} ${LevelStr}$2" >&2
		${LOGGER_Logger} -p ${LOGGER_FACILITY}.$1 -t ${LOGGER_TAG} ${LevelStr}$2
	fi
}

################################################################################
#
if [[ ${USE_LOGGER:-0} = 1 && -n $1$2 ]]
then
	Logger $1 $2
fi
