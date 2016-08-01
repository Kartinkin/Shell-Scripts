#!/usr/bin/ksh
#
################################################################################
# Программа останавливает СУБД Oracle. Можно запускать неоднократно.
# Действия производятся в следующей последовательности:
#	Сначала выполняется shutdown immediate
#	Если он не сработал, дается команда shutdown abort
#	Если и после этого есть процессы СУБД, им посылается сигнал SIGKILL
#	Останавливается listener
################################################################################
#
# Использование:
#	stopora.sh [-h] [-v] [-c ConfigFile]
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
#	1			остались процессы СУБД или listener'а;
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
	(( Verbose )) && print "The Oracle home $ORACLE_HOME does not exist."
	exit 0
fi

for i in $ORACLE_HOME/bin/sqlplus $ORACLE_HOME/bin/lsnrctl
do
	if [[ ! -x $i ]]
	then
		print "$MyName: $i not found."
		exit 255
	fi
done

PATH=$ORACLE_HOME/bin:$PATH

if [[ -z $(IsOracleOnline $OraAdm $ORACLE_SID -1) ]]
then
	(( Verbose )) && print "Oracle is not running, nothing to do."
else
	print "shutdown immediate\n" | su $OraAdm -c $ORACLE_HOME/bin/sqlplus / as sysdba
	if [[ -n $(IsOracleOnline $OraAdm $ORACLE_SID $ImmediateTimeout) ]]
	then
		print "shutdown abort\n" | su $OraAdm -c $ORACLE_HOME/bin/sqlplus / as sysdba
		OraPIDs=$(IsOracleOnline $OraAdm $ORACLE_SID $AbortTimeout)
		[[ -n $OraPIDs ]] && kill -9 $OraPIDs
	fi
fi

if [[ -z $(IsListenerOnline $OraAdm $LISTENER -1) ]]
then
	(( Verbose )) && print "Listener is not running, nothing to do."
else
	su $OraAdm -c $ORACLE_HOME/bin/lsnrctl stop $LISTENER
	OraPIDs=$(IsListenerOnline $OraAdm $LISTENER $ListenerTimeout)
	[[ -n $OraPIDs ]] && kill -9 $OraPIDs
fi

[[ -z $(IsOracleOnline $OraAdm $ORACLE_SID -1) && \
	-z $(IsListenerOnline $OraAdm $LISTENER -1) ]]
exit $?