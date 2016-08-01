#!/usr/bin/ksh
#
################################################################################
# Программа запускает СУБД Oracle. Сначала запускается СУБД, потом listener.
# Можно запускать неоднократно.
################################################################################
#
# Использование:
#	startpora.sh [-h] [-v] [-c ConfigFile]
#
# Параметры:
#	-h			краткая справка;
#	-v			выводить комментарии по ходу работы;
#	-c ConfigFile	указывает файл с параметрами, где ConfigFile - имя файла.
#				Если опция не указана, используется
#				varyres.conf из директории, где находится программа.
#
# Возвращаемые значения:
#	0			все хорошо; 
#	1			что-то не запустилось;
#	255			проблемы с конфигурационным файлом или
#				нет необходимых утилит.
#
################################################################################

MyName=${0##*/}
MyPath=${0%/*}

if [[ "$MyPath" == "$MyName" ]]
then
	MyPath=$(which $MyPath)
	MyPath=${MyPath%/*}
fi

ConfigFile="$MyPath/varyres.conf"
Verbose=0

while [[ -n "$1" ]]
do
	case $1 in
		"-c") shift
			ConfigFile=$1
			;;
		"-v") Verbose=1
			;;
		"-vv") set -x
			;;
		"-h")
			print "Usage: $MyName [-h] [-v] [-c ConfigFile]"
			print "	-h			this message"
			print "	-c ConfigFile	use configuration file ConfigFile"
			print "	-v			verbose output"
			exit 0
			;;
	esac
	shift
	
done

if [[ -r "$ConfigFile" ]]
then
	. $ConfigFile
else
	print "$MyName: The configuration file $ConfigFile does not exist."
	exit 255
fi

if [[ ! -d $ORACLE_HOME ]]
then
	print "The Oracle home $ORACLE_HOME does not exist."
	exit 0
fi

for i in $ORACLE_HOME/bin/sqlplus $ORACLE_HOME/bin/lsnrctl
do
	if [[ ! -x $i ]]
	then
		(( Verbose )) && print "$MyName: $i not found."
		exit 255
	fi
done

PATH=$ORACLE_HOME/bin:$PATH

if [[ -n $(IsOracleOnline $OraAdm $ORACLE_SID -1) ]]
then
	(( Verbose )) && print "Oracle is already running, nothing to do."
else
	print "startup force" | su $OraAdm -c $ORACLE_HOME/bin/sqlplus / as sysdba
fi

if [[ -n $(IsListenerOnline $OraAdm $LISTENER -1) ]]
then
	(( Verbose )) && print "Listener is already running, nothing to do."
else
	su $OraAdm -c $ORACLE_HOME/bin/lsnrctl start $LISTENER
fi

[[ -n $(IsOracleOnline $OraAdm $ORACLE_SID -1) && \
	-n $(IsListenerOnline $OraAdm $LISTENER -1) ]]
exit $?