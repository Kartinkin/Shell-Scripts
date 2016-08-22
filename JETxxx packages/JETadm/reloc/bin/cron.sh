#!/usr/xpg4/bin/sh
# Version	1.0
# Date		1 Aug 2000
# Author	Kirill Kartinkin

# Запускает указанную программу с учетом
# местонахождения сервисной группы.
#
# Внимание! Программа работает только при наличии Qualix HA+.
#
#
# Параметры:
#	$1	Имя или id сервисной группы
#	$2	Имя пользователя
#	$3	Команда
# После запуска программа проверяет, работает ли на данном узле
# сервисная группа, разрешено ли пользователю работать с сервисом cron
# и исполняет заданную команду в среде и от имени пользователя.
# 
# Возвращаемые значения:
#	0	O.K.
#	1	сервисная группа не запушена на этом узле
#	2	пользователь не может пользоваться сервисом cron
#	101	невозможно определить функцию Logger

# Для начала узнаем как нас вызвали.
# Если вызывали из командной строки, то оболочка POSIX-shell,
# а если вызывал cron, то будет Bourne shell.
x="A.B"
x=`(echo ${x%%.*}) 2>/dev/null`
# Bourne shell не умеет разбивать переменные на подстроки
if [ "$x" != "A" ]
then
	# Точно, этот не умеет, вызываем сами себя	
	$0 $*
	exit $?
fi

PATH=/sbin:/usr/sbin:/usr/xpg4/bin:/usr/bin

# Определяем функцию Logger
LOGGER_FACILITY=daemon
LOGGER_TAG=cron
LOGGER_PRINT=0 # Печать сообщения не требуется
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

# Где работает сервисная группа?
if [[ $(qhap cl -g all stat2 | \
		awk -v SG=$1 '$1 == SG || $2 == SG { print $3" "$4 }') \
	= "SERVED $(hostname)" ]]
then
	# На данном узле
	# Начинаем проверять полномочия пользователя (см. crontab(1))

	# Ищем файл разрешений
	if [[ -f ${CronAllow} ]]
	then
		# Файл разрешений есть, ищем имя пользователя
		if [[ -n $(grep $2 ${CronAllow}) ]]
		then
			# нашли
			Allow=1
		fi
	# Файла разрешений нет, ищем файл запретов
	elif [[ -f ${CronDeny} ]]
	then
		# Файл запрещений есть, смотрим пуст ли он
		if [[ -s ${CronDeny} ]]
		then
			# Файл не пуст, ищем имя пользователя
			if [[ -z $(grep $2 ${CronDeny}) ]]
			then
				# не нейдено
				Allow=1
			fi
		else
			# Файл запрещений пуст, разрешено всем
			Allow=1
		fi
	elif [[ $2 = "root" ]]
	then
		# Нет ни файла разрешений, ни файла запрещений
		Allow=1
	fi
			
	if (( ${Allow} == 1 ))
	then
		# Пользователю разрешено использовать сервис cron
		Logger info "Starting \"$3\" for user $2 on this node."

		# Некоторые пользователи обрабатываются отдельно
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
		# Пользователю не разрешено использовать сервис cron
		Logger err "User $2 not allowed to use cron service."
		exit 2
	fi
else
	# Сервисная группа работает на другом узле
	Logger debug "Service group $1 don't running on this node. Exiting."
	exit 1
fi
