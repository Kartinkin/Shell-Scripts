#!/usr/bin/ksh

################################################################################
# Программа запускает или останавливает ресурсные группы.
################################################################################
#
# Для того, чтобы воспользоваться программой, сделайте на нее символьные ссылки
# с именами следующего вида:
#	{start|stop}.<Имя>.sh
# где <Имя> - идентификатор ресурсной группы.
# Примеры:
# 	команда "ln -s start-stop.sh start.Boss.sh" создает ссылку с именем
#		для запуска ресурсной группы Босс-Кадровик
#		(конфигурационный файл start-stop.Boss.conf);
#	команда "ln -s start-stop.sh stop.TEMP.sh" создает ссылку с именем
#		для остановки ресурсной группы ТЕМП
#		(конфигурационный файл start-stop.TEMP.conf).
#
################################################################################
#
# Программа ищет файл start-stop.<Имя>.conf, находящийся в одной с ней
# директории, из которого берет все свои параметры и,
# в зависимости от своего имени, осуществляет...
#	...или запуск ресурсной группы:
#		1) Проверяется содержимое файла блокировки.
#		Файл состоит из одной строки
#		<День года> <Год> <Число секунд от 1.1.1970> <Дата-время в читаемом виде>
#		Если текущая дата совпадает, и разница во времени не более 60 минут,
#		работа продолжается, иначе выводится сообщение об ошибке.
#		2) Выполняется команда "varyonres.sh start-stop.<Имя>.conf".
#		Если команда вернула ошибку, работа завершается.
#		После устранения ошибок возможен повторный запуск данной программы,
#		но крайне желательно присутствие квалифицированного системного
#		администратора, поскольку процесс репликации, группы томов,
#		файловые системы и IP-адреса могут быть в любом состоянии.
#		3) Выполняется команда "startora.sh start-stop.<Имя>.conf".
#		4) Удаляется файл блокировки.
#	...или останов:
#		1) Выполняется команда "stopora.sh start-stop.<Имя>.conf".
#		Если команда вернула ошибку, работа завершается.
#		После устранения ошибок возможен повторный запуск данной программы.
#		2) Выполняется команда "varyoffres.sh start-stop.<Имя>.conf".
#		Если команда вернула ошибку, работа завершается.
#		После устранения ошибок возможен повторный запуск данной программы.
#		3) На удаленном сервере создаем файл блокировки.
#
################################################################################
#
# Использование:
#	{start|stop}.<Имя>.sh [-h] [-v]
#
# Параметры:
#	-h			краткая справка;
#	-v			выводить комментарии по ходу работы.
#
# Возвращаемые значения:
#	0			все хорошо; 
#	255			проблемы с конфигурационным файлом или
#				нет необходимых утилит.
#
################################################################################
#
# Используемые файлы:
#	start-stop.<Имя>.conf		файл конфигурации
#	start-stop.<Имя>.lock		файл блокировки
#	startora.sh, stopora.sh		программы для запуска и останова СУБД Oracle
#	varyonres.sh, varyoffres.sh	программы для импорта/эспорта дисковых ресурсов
# Файлы должны находиться в той же директории, в которой размещается символьные
# ссылки на данную программу, причем на всех серверах эти директории должны
# быть одинаковыми. 
#
# Для корректной работы программы между серверами должен быть настроен
# беспарольный доступ по ssh (с использованием открытых ключей)
# для пользователя root.
#
# Файл блокировки можно создать вручную командой
#	date '+%j %Y %s %H:%M %d/%b/%Y' >start-stop.<Имя>.lock
################################################################################
#
# Допускается 60 минут разницы во времени между созданием
# файла блокировки и запуском программы на другом узле.
# Значение переменной в секундах.
TimeDelta=$((60*60))
#
################################################################################

MyName=${0##*/}
MyPath=${0%/*}
if [[ $MyPath == "." ]]
then
	MyPath=$(pwd)
fi

Command=${MyName%%.*}
SID=${MyName%.sh}
SID=${SID#*.}
ConfigFile=$MyPath/start-stop.${SID}.conf
LockFile=$MyPath/start-stop.${SID}.lock

Verbose=""
while [[ -n "$1" ]]
do
	case $1 in
		"-v") Verbose="$Verbose -v"
			;;
		"-vv") Verbose="$Verbose -vv"
			set -x
			;;
		"-h")
			print "Usage: $MyName [-h] [-v]"
			exit 0
			;;
	esac
	shift
	
done

[[ "$MyName" != "start-stop.sh" ]] && \
if [[ -r "$ConfigFile" ]]
then
	. $ConfigFile
else
	print "$MyName: The configuration file $ConfigFile does not exist."
	exit 255
fi

for F in varyonres.sh varyoffres.sh startora.sh stopora.sh 
do
	if [[ ! -x $MyPath/$F ]]
	then
		print "$MyName: The file $MyPath/$F does not exist."
		exit 255
	fi
done

function Serious
{
	print "\tIf You seriously planning to initiate $SID resource group activation"
	print "\ton this host create the lock file manualy with command"
	print "\t\tdate '+%j %Y %s %H:%M %d/%b/%Y' >$LockFile"
}

case ${MyName%%.*} in
	start)
		if [[ -r $LockFile ]]
		then
			read LDay LYear LTime LOther <$LockFile
			CurDay=$(date '+%j')
			CurYear=$(date '+%Y')
			CurTime=$(date '+%s')
			#print "$LDay == $CurDay $LYear == $CurYear $LTime == $CurTime"
			#print "$LOther"
			(( Delta = CurTime - LTime ))
			if [[ $LDay != $CurDay || $LYear != $CurYear ]]
			then
				print "$MyName: Date mismatch."
				print "\tLock file contains $LDay.$LYear"
				print "\tToday is           $CurDay.$CurYear"
				Serious
			elif (( $Delta > $TimeDelta || $Delta <=0 ))
			then
				print "$MyName: Wrong time stamp."
				print "\tLock file contains $LTime"
				print "\tNow is             $CurTime"
				Serious
			else
				${MyPath}/varyonres.sh $Verbose -c $ConfigFile && \
				${MyPath}/startora.sh $Verbose -c $ConfigFile && \
				rm $LockFile
			fi
		else
			print "$MyName: The lock file $LockFile not found."
			Serious
		fi
		;;
	stop)
		Lock=$(date '+%j %Y %s %H:%M %d/%b/%Y')
		${MyPath}/stopora.sh $Verbose -c $ConfigFile && \
		${MyPath}/varyoffres.sh $Verbose -c $ConfigFile && \
		( print "$Lock" | ssh root@$RemoteHost "cat >$LockFile" )
		
		RLock=$(ssh root@$RemoteHost "cat $LockFile")
		if [[ ".$RLock" != ".$Lock" ]]
		then
			print "$MyName: Unnable to create lock file!!!"
			print "\tCreate it manualy on the host $RemoteHost with command"
			print "\t\tdate '+%j %Y %s %H:%M %d/%b/%Y' >$LockFile"
		elif [[ -n $Verbose ]]
		then
			print "The lock file $LockFile has been created on the host $RemoteHost ($Lock)."
		fi
		;;
	*)
		print "$MyName: The name of this script must be '{start|stop}.<OraSID>.sh'"
		exit 255
		;;
esac




