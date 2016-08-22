#!/usr/xpg4/bin/sh
# Version	3.0
# Date		3 Nov 98
# Author	Kirill Kartinkin
#
# Программа описывает функции Logger и Date
#
# Для использования функции Logger Вы должны source данный файл
# в Вашей программе (. /var/adm/bin/logger.sh).
# Перед использованием программы требуется
# определить следующие переменные окружения
# 	Name -- имя программы, использующей функцию Logger 
#	LOGGER_FACILITY -- используется для задания
#		пары (facility.level). Может принимать значения
#		user, kern, mail, daemon, auth, lpr, local0-5.
#		Если не задано, то user.
#	LOGGER_TAG --  определяет ярлык (tag) для отправляемого сообщения
#		При описании предыдущих двух переменных Вы можете использовать
#		имя переменной окружения, например, LOGGER_TAG='$MyTag'.
#		Если не задано, то Logger.
#	LOGGER_PRINT -- если значение равно 1 программа выводит сообщение в stdout
#	LOGGER_LOG -- если значение равно 1 программа отправляет сообщение
#		по протоколу syslog.
# 		Сообщение будет выведено в stdout и отправлено в syslog,
#		даже если предыдущие две переменные не описаны.
#
# Параметры:
# Если программе даны параметры, то вызывается функция Logger с параметрами:
#	$1	-- уровень выжности сообщения (см. syslog (3C))
#	$2	-- сообщение


################################################################################
# Функция выводит в stdout текущую дату в формате "Ммм ДД ЧЧ:ММ:СС",
# где Ммм -- трехбуквенное сокращение месяца, ДД -- число месяца (1-31),
# ЧЧ:ММ:СС -- время в 24-часовом формате.
#
function Date
{
	date '+%b %e %X'
}

# Проверяем, описаны ли переменные LOGGER_PRINT и LOGGER_LOG,
# и задаем параметры
if (( ${LOGGER_PRINT:-1} == 1 ))
then
	# Для печати сообщения используем print
	LOGGER_Print=print
else
	LOGGER_Print=:
fi

if (( ${LOGGER_LOG:-1} == 1 ))
then
	# Для отправки сообщения используем программу logger
	LOGGER_Logger=logger
else
	LOGGER_Logger=:
fi

# Вычисляем LOGGER_FACILITY и LOGGER_TAG
# Используем eval, чтобы можно было задавать параметры неявно
eval LOGGER_FACILITY=${LOGGER_FACILITY}
eval LOGGER_TAG=${LOGGER_TAG}

# Если значения переменных пусты, выставляем по умолчанию
: ${LOGGER_FACILITY:=user}
: ${LOGGER_TAG:=Logger}

################################################################################
# Функция передает сообщение по протоколу syslog и выводит его в stderr.
# Параметры:
#   $1 - уровень важности (см. syslog (3C)). Может принимать значения
#		alert, crit, err, warning, notice, info, debug
#   $2 - текст сообщения
#
# Передаваемое сообщение имеет следующий вид:
#	Важность: Сообщение
# Сообщение, выводимое в stdout, имеет в следующий вид:
#	$(Date): ${Name} Важность: Сообщение
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
