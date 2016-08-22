#!/usr/xpg4/bin/sh
# Version	0.0
# Date		3 Nov 98
# Author	Kirill Kartinkin

# Программа архивирует файлы журналов.
# Для этого создается специальная директория, в которую перемещаются
# журнальные файлы. Файлы дополнительно сжимаются. Храняется три последние
# копии файлов с именами Имя.Z, Имя.old.Z и Имя.oldest.Z. Имя строится следующим
# образом: из полного пути убирается лидируюший знак "/", в пути все "/"
# заменяются на ".", а в имени файла все "." заменяются на "_".
#
# Пользователь adm из группы adm получает все права на архив.
#
# Программа проверяет результаты операций перемещения и сжатия файлов, если
# одна из них завершились с ошибкой, журнальный файл не архивируется.
#
# Опции:
#	-d path	директория, в которую меремещаются файлы.
#		Если параметр не задан, используется /var/adm/logs.archive
#		Если директории не существует, она создается
#	-c	сжимать архивируемые файлы программой compress
#		по умолчанию установлен
#	-C	не сжимать архивируемые файлы
#	-f file	файл со списком журналов
#		Если вместо имени файла передан "-", то используется stdin
#		Если параметр не задан,
#		используется содержимое переменной ArchiveDir
#
# Возвращаемые значения:
#	0	O.K.
#	1	невозможно создать архив
#	2	ошибка при чтении списка файлов
#	4	ошибка сдвига старых архивных файлов
#	8	ошибка архивирования файла
#	16	ошибка сжатия файла
#	100	ошибка в командной строке
#	101	невозможно определить функцию Logger
#
# Программа должна запускаться от имени пользователя root.

# Для начала узнаем как нас вызвали.
# Эта программа часто вставляется в cron...
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

################################################################################
# Описываем переменные конфигурации и производим необходимые проверки

# Устанавливаем необходимые пути поиска
PATH=/usr/xpg4/bin:/usr/bin:/var/adm/bin

Name=${0##*/}

# Директория, в которой ведется архив журналов.
# Не рекомендуется заранее ее создавать.
ArchiveDir=/var/adm/logs.archive

# Указывает на необходимость компрессии
Compress=1
# Суффикс в имени сжатого файла
CompressExt=".Z"

# Переменная LogFile содержит список файлов журналов.
# Будем ее постепенно заполнять
LogFiles=""

# 3 файла журналов NFS
LogFiles="${LogFiles} /var/adm/lockd.log /var/adm/statd.log /var/adm/mountd.log"

# 5 файлов учета пользовательских входов в систему
LogFiles="${LogFiles} /var/adm/utmp /var/adm/wtmp /var/adm/btmp"
LogFiles="${LogFiles} /var/adm/utmpx /var/adm/wtmpx"

# Файл журнала сервиса cron
# (первое имя используется в HP-UX,второе в Solaris)
LogFiles="${LogFiles} /var/adm/cron/log /var/cron/log"

# Файл журнала сервиса switch user
File=$(ccat /etc/default/su 2>/dev/null |\
	awk 'BEGIN { FS="=" } $1=="SULOG" { print $2 }')
if [[ -z ${File} ]]
then
	LogFiles="${LogFiles} /var/adm/sulog"
else
	LogFiles="${LogFiles} ${File}"
fi

# Файл с записями неуспешнах попыток входа в систему
LogFiles="${LogFiles} /var/adm/loginlog"

# Выбираем журнальные файлы из конфигурации syslog.conf
# Для этого выбираем из файла конфигурации syslog все имена файлов,
# а потом проверяем, обычный ли это файл и есть ли он.
for File in $( ccat /etc/syslog.conf | \
	awk '{ for (i = NF; i > 0; --i)
			{ if ($i~"^/") 
				{ print $i }
			}
		}' | sed -e 's/,//g' | sort | uniq )
do
	# Внимание! Не меняйте POSIX-shell на другой.
	# Не всегда -f означает "regular file"
	if [[ -f ${File} ]]
	then
		# Да, это обычный файл
		LogFiles="${LogFiles} ${File}"
	fi
done

# 2 файла журналов кластерного пакета Qualix HA+
LogFiles="${LogFiles} /var/adm/log/qhap.log /var/adm/log/cma.log"

# Файл журнала Veritas Volume Manager
LogFiles="${LogFiles} /var/vxvm/vxconfigd.log"

# 2 файла журнала СУБД INFORMIX
LogFiles="${LogFiles} ~informix/online.log ~informix/ontape.log"

# Файл журнала кластерного пакета MC/ServiceGuard
#LogFile="${LogFile} /etc/cmcluster/depo/control.sh.log"

################################################################################
# Определяем функцию Logger
LOGGER_FACILITY=user
LOGGER_TAG=logcleaner
LOGGER_PRINT=0 # Печать сообщения не требуется
if [[ -f /var/adm/bin/logger.sh ]]
then
	. /var/adm/bin/logger.sh
else
	print "ERROR: Unnable to source /var/adm/bin/logger.sh"
	exit 101
fi

################################################################################
# Разбираем параметры командной строки
while (( $# > 0 ))
do
	case "$1" in
		-c) Compress=1;;
		-C) Compress=0
			CompressExt=""
			;;
		-f) List=$2
			shift
			;;
		-d) ArchiveDir=$2
			shift
			;;
        *)
			print "usage: ${Name} [-c|C] [-f file] [-d path]"
			exit 100
			;;
    esac
	shift
done

################################################################################
# Если нет директории с архивом, создаем ее
if [[ ! -d ${ArchiveDir} ]]
then
	mkdir -p ${ArchiveDir}
	if (( $? != 0 ))
	then
		Logger err "Unnable to create log's archive (${ArchiveDir})."
		exit 1
	fi
	# Права доступа rwxr-xr-x
	chmod 755 ${ArchiveDir}
#	chown adm:adm ${ArchiveDir}
	Logger info "Log's archive created."
fi

################################################################################
# Проверяем, надо ли считывать список файлов
if [[ -n ${List} ]]
then
	# Да, надо
	# Проверяем, не stdin ли это, а если нет, то есть ли файл со списком
	if [[ ${List} = "-" || -r ${List} ]]
	then
		# Подставляем имя файла и распечатываем файл
		# Если подставляется знак "-", то тоже все хорошо
		# команда cat берет данные из stdin
		LogFiles=$(cat ${List})
	else
		# Ошибка, файла не существует,
		# или он недоступен для чтения
		Logger err "Cannot open list file \"${List}\"."
		exit 2
	fi
fi

# Сохраняем список журнальных файлов
print "${LogFiles}" | sed -e 's/ /\
/g' >${ArchiveDir}/.list

# В этот файл будет записан список обработанных файлов
>${ArchiveDir}/.archived

################################################################################
# Переходим к обработке файлов

# Устанавливаем код возврата
integer Ret=0

# Переменная File проходит по элементам списка с именами журналов
for File in ${LogFiles}
do
	# В теле цикла архивируются журнальные файлы
	if [[ -s ${File} ]]
	then
		# Журнал ненулевой длины существует
		print ${File} >>${ArchiveDir}/.archived
		# Строим имя архивного файла
		# В имени файла все "." заменяются на "_",
		# из полного пути убирается лидируюший знак "/",
		# в пути все "/" заменяются на ".".
		FileName=$(print ${File} | \
			sed -e "s/\./_/g" -e "s/\///" -e "s/\//./g")
		# Строим полное имя заархивированного файла
		# и имена старых копий
		ArchivedFile="${ArchiveDir}/${FileName}${CompressExt}"
		ArchivedFileOld="${ArchiveDir}/${FileName}.old${CompressExt}"
		ArchivedFileOldest="${ArchiveDir}/${FileName}.oldest${CompressExt}"
		
		# Замещаем старые архивные файлы
		# FileName.old.Z --> FileName.oldest.Z
		# FileName.Z --> FileName.old.Z
		if [[ -f ${ArchivedFileOld} ]]
		then
			mv ${ArchivedFileOld} ${ArchivedFileOldest}
			if (( $? != 0 ))
			then
				Logger notice \
					"Unnable rename \"${ArchivedFileOld}\"."
				(( Ret = Ret | 4 ))
				continue
			fi
		fi
		if [[ -f ${ArchivedFile} ]]
		then
			mv ${ArchivedFile} ${ArchivedFileOld}
			if (( $? != 0 ))
			then
				Logger notice \
					"Unnable rename \"${ArchiveFile}\"."
				(( Ret = Ret | 4 ))
				continue
			fi
		fi
		if (( Compress != 1))
		then
			# Перемещаем журнальный файл 
			# Чтобы не заставлять программы открывать заново
			# журнальный файл, копируем его содержимое в архив
			cat ${File} >${ArchivedFile}
			if (( $? !=0 ))
			then
				Logger err "Failed to move file \"${File}\"."
				(( Ret = Ret | 8 ))
				continue
			fi
		else
			# Сжимаем архивный файл
			compress -f <${File} >${ArchivedFile}
			if (( $? == 1 ╕| $? > 2 ))
			then
				Logger err "Failed to compress file \"${ArchiveDir}/${FileName}\"."
				Logger info "File \"${File}\" not archived."
				(( Ret = Ret | 16 ))
				continue
			fi
			Logger info \
				"File \"${ArchiveDir}/${FileName}\" compressed."
		fi

#			chown adm:adm ${ArchivedFile}
		# Права доступа ╜rw-r--r--
		chmod 644 ${ArchivedFile}
		# Обнуляем старый лог (не создаем новый файл,
		# а обнуляем старый)
		>${File}
		Logger info "File \"${File}\" archived."
	fi
done

exit ${Ret}
