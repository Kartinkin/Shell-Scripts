#!/usr/bin/ksh
#
################################################################################
# Программа депорирует дисковые ресурсы. Отмонтируются файловые системы,
# сервер перестает управлять группами томов. Удаляются сетевые интерфейсы.
# Можно запускать неоднократно.
################################################################################
#
# Использование:
#	varyoffres.sh [-h] [-f] [-c ConfigFile]
#
# Параметры:
#	-h			краткая справка;
#	-f			при проблемах с отмонтированием файловых систем
#				используется umount -f; 
#	-v			выводить комментарии по ходу работы;
#	-c ConfigFile	указывает файл с параметрами, где ConfigFile - имя файла.
#				Если опция не указана, используется
#				varyres.conf из директории, где находится программа.
#
# Взведенные биты в возвращаемом значении:
#	Все нули	все группы томов активированы, файловые системы смонтированы; 
#	1		одна или несколько групп томов не деактивирована;
#	4		не смогли отмонтировать одну или несколько файловых систем;
#	8		не смогли удалить один или несколько сетевых интерфейсов.
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
Force=""
Verbose=0

while [[ -n "$1" ]]
do
	case $1 in
		"-c") shift
			ConfigFile=$1
			;;
		"-f") Force="-f"
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
			exit 255
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

Ret=0

i=0
for IP in ${IPs[*]}
do
	IP=$(lsattr -El ${Ifs[$i]} -a alias4 | awk '$2~"'$IP'" { print $2 }')
	if [[ -z $IP ]]
	then
		(( Verbose )) && print "${IPs[$i]} is not up, nothing to do."
	else
		# ifconfig ${Ifs[$i]} delete $IP
		chdev -l ${Ifs[$i]} -a delalias4=$IP
		if (( $? == 0 ))
		then
			(( Verbose )) && print "${IP%,*} unconfigured."
		else
			(( Ret=Ret|8 ))
		fi
	fi
	(( i+=1 ))
done

MountedFSs=$(mount)
for FS in ${FSs[*]}
do
	if [[ -z $(print "$MountedFSs" | grep "$FS") ]]
	then
		(( Verbose )) && print "$FS is not mounted, nothing to do."
	else
		umount $FS
		if (( $? == 0 ))
		then
			(( Verbose )) && print "$FS unmounted."
		elif [[ -n $Force ]]
		then
			umount -f $FS
			if (( $? == 0 ))
			then
				(( Verbose )) && print "$FS unmounted (forced)."
			else
				(( Ret=Ret|4 ))
			fi
		fi
	fi
done

AvailableVGs=$(lsvg -o)
for VG in ${VGs[*]}
do
	if [[ -z $(print "$AvailableVGs" | grep "$VG" ) ]]
	then
		(( Verbose )) && print "$VG is not active, nothing to do."
	else
		varyoffvg $VG
		if (( $? == 0 ))
		then
			(( Verbose )) && print "Volume group $VG deactivated."
		else
			(( Ret=Ret|1 ))
		fi
	fi
done

exit $Ret
                                