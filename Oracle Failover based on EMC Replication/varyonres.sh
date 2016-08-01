#!/usr/bin/ksh
################################################################################
# Программа импорирует дисковые ресурсы и добавляет сетевые интерфейсы.
# Можно запускать неоднократно.
#
# Алгоритм работы такой:
#	1. Открывается доступ к томам дискового массива. Для этого:
#		а) Проверяется состояние томов на локальном массиве. Если статус
#			томов не syncronized или consistent, программа завершает работу.
#		б) Проверяется направление репликации. Если на локальном массиве
#			одни тома primary, а другие secondry - выход.
#			Если все тома primaty - переходим к шагу 2.
#		в1) Если второй массив доступен, там проверяется статус половинок 
#			зеркал. Если информацию о них получить не удалось - выход. 
#			Если информация, полученная там, не соответствует мнению
#			локального массива (или установлен режим  fractured),
#			и в параметрах командной строки нет опции -fmf, то выход.
#			Если же указано -fmf, продолжаем не глядя на статусы.
#		в2) Если нет доступа ко второму массиву и нет опции -fmf, то выход.
#			Если нет доступа, но опция указана, продолжаем.
#		г) Для всех томов дается команда promote
#		д) Для всех пар устанавливается режим автоматической репликации.
#	2. Сервер берет на себя управление группами томов. Если некоторые группы
# 		томов не подняты, продолжаем, но в конце будет выдана ошибка
#		(см. возвращаемые значения).
#	3. Проверяются и монтируются файловые системы. Если некоторые файловые
# 		системы не смонтированы, продолжаем, но в конце будет выдана ошибка.
#		(см. возвращаемые значения).
#	4. Добавляются сетевые интерфейсы.
################################################################################
#
# Использование:
#	varyonres.sh [-h] [-fvg] [-fmf] [-c ConfigFile] [-v]
#
# Параметры:
#	-h			краткая справка;
#	-fvg			использовать опцию -f при выполнении varyonvg;
#	-fmf			развернуть реплликацию даже если обнаружны ошибки.
#				ВНИМАНИЕ! При запуске с данной опцией возможна полная
#				или частичная потеря данных. Использовать эту опцию
#				только если есть четкое понимание состояния дисковых
#				массивов и представление о том, что произойдет в ходе
#				выполнения данной программы;
#	-v			выводить комментарии по ходу работы;
#	-c ConfigFile	указывает файл с параметрами, где ConfigFile - имя файла.
#				Если опция не указана, используется
#				varyres.conf из директории, где находится программа.
#
# Взведенные биты в возвращаемом значении:
#	Все нули	все группы томов активированы, файловые системы смонтированы; 
#	1		одна или несколько групп томов не активирована;
#	2		не смогли починить одну или несколько файловых систем;
#	4		не смогли смонтировать одну или несколько файловых систем;
#	8		не смогли настроить один или несколько сетевых интерфейсов.
#	16		не доступен локальный дисковый массив
#	32		не доступен удаленный дисковый массив
#	64		обнаружены проблемы с репликацией
#	255		проблемы с конфигурационным файлом
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
ForceVaryOn=""
ForceFailover=0
Verbose=0
Ret=0

while [[ -n "$1" ]]
do
	case $1 in
		"-c") shift
			ConfigFile=$1
			;;
		"-fvg") ForceVaryOn="-f"
			;;
		"-fmf") ForceFailover=1
			;;
		"-v") Verbose=1
			;;
		"-vv") set -x
			;;
		"-h")
			print "Usage: $MyName [-h] [-v] [-fvg] [-fmf] [-c ConfigFile]"
			print "	-h			this message"
			print "	-fvg			force volume group activating"
			print "	-fmf			force mirror failover"
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

LocalSP=""
for SP in ${LocalSPNames[*]} ""
do
	ping $SP 56 1 >/dev/null
	if (( $? == 0 ))
	then
		(( Verbose )) && print "Local  array SP $SP is alive"
		LocalSP=$SP
		break
	else
		print "$MyName: Local  array SP $SP is unreachable."
	fi
done
if [[ -z $LocalSP ]]
then
	print "$MyName: The Storage Processors for the local array are unreachable."
	exit 16
fi
	
RemoteSP=""
for SP in ${RemoteSPNames[*]} ""
do
	ping $SP 56 1 >/dev/null
	if (( $? == 0 ))
	then
		(( Verbose )) && print "Remote array SP $SP is alive"
		RemoteSP=$SP
		break
	else
		print "$MyName: Remote array SP $SP is unreachable."
	fi
done
if [[ -z $RemoteSP ]]
then
	print "$MyName: The Storage Processors for the remote array are unreachable."
	(( Ret=Ret|32 ))
fi

function GetMirrStatus
{ #	$1	адрес контроллера массива
#	$2	имя зеркала
	naviseccli -h $1 mirror -sync -list -name "$2" | \
	awk '/Remote Mirror Status/ { Status=$4 }
		/Image State/ { State=$3 }
		/Image UID/ { UID=$3 }
		/Is Image Primary.*YES/ { PrimUID=UID }
		/Is Image Primary.*NO/  { SecUID=UID }
		/Image Condition.*ractured/ { Cond="fractured" ; continue }
		/Image Condition/ { Cond=$3 }
		END { print PrimUID" "SecUID" "Status" "State" "Cond }'
}

i=0
Synced=1
Mixed=0
while (( i < ${#Mirrors[*]} ))
do
	GetMirrStatus $LocalSP "${Mirrors[$i]}" | \
		read MirrPrimaryUIDs[$i] MirrSecondaryUIDs[$i] MirrRoles[$i] MirrStates[$i] MirrConds[$i]

	if [[ ${MirrRoles[$i]} == "Mirrored" ]]
	then
		(( Verbose )) && print "Local array owns ${Mirrors[$i]} primary copy (${MirrStates[$i]})"
		if [[ $Role == "Secondary" ]]
		then
			Role="Mixed"
			break
		else
			Role="Primary"
		fi
	else
		(( Verbose )) && print "Local array owns ${Mirrors[$i]} secondary copy (${MirrStates[$i]})"
		if [[ $Role == "Primary" ]]
		then
			Role="Mixed"
			break
		else
			Role="Secondary"
		fi
	fi 
	[[ ${MirrStates[$i]} == "Synchronized" || ${MirrStates[$i]} == "Consistent" ]] || Synced=0

	(( i+=1 ))
done

if (( ! $Synced ))
then
	print "$MyName: Mirrors are not synchronized."
	exit $((Ret|64))
fi

if [[ $Role == "Mixed" ]]
then
	print "$MyName: Devices are in an invalid mix of states."
	exit $((Ret|64))
elif [[ $Role == "Primary" ]]
then
	(( Verbose )) && print "Mirrors are all read/write enabled."
else # $Role == "Secondary"
	if [[ -z $RemoteSP ]]
	then
		(( $ForceFailover )) || exit $Ret
	else
		i=0
		Fruc=0
		while (( i < ${#Mirrors[*]} ))
		do
			GetMirrStatus $RemoteSP "${Mirrors[$i]}" | \
				read m1 m2 m3 RemoteMirrStates[$i] RemoteMirrConds[$i]
			if [[ -z ${RemoteMirrStates[$i]} && -z ${RemoteMirrConds[$i]} ]]
			then
				print "$MyName: There is no secondary image available for mirror ${Mirrors[$i]}."
				(( Ret=Ret|64 ))
		     else
				(( Verbose )) && print "Remote array: ${Mirrors[$i]} is in ${RemoteMirrStates[$i]} state (${RemoteMirrConds[$i]})"
		     	if [[ ${MirrConds[$i]} == "fractured" || ${RemoteMirrConds[$i]} == "fractured" || \
					${RemoteMirrConds[$i]} != ${MirrConds[$i]} || \
					${RemoteMirrStates[$i]} != ${MirrStates[$i]} ]]
				then
					print "$MyName: ${Mirrors[$i]} is in fractured condition."			
					Fruc=1
				fi
			fi
			(( i+=1 ))
		done

		(( $((Ret&64)) )) && exit $Ret

		if (( $Fruc && !$ForceFailover ))
		then
			print "$MyName: Some mirrors are in fractured condition."			
			exit $((Ret|64))
		fi
	fi
	
	i=0
	while (( i < ${#Mirrors[*]} ))
	do
		naviseccli -h $LocalSP mirror -sync -promoteimage -name "${Mirrors[$i]}" -imageuid "${MirrSecondaryUIDs[$i]}" -o
		if (( $? != 0 ))
		then
			print "$MyName: Unable to promote the image for ${Mirrors[$i]}."
			(( Ret=Ret|128 ))
		else
			(( Verbose )) && print "${Mirrors[$i]} promoted"
			naviseccli -h $LocalSP mirror -sync -changeimage -name "${Mirrors[$i]}" -imageuid "${MirrPrimaryUIDs[$i]}" -recoverypolicy auto -o || \
				print "$MyName: Unable to change the 'recoverypolicy' to auto for ${Mirrors[$i]}."
		fi
		(( i+=1 ))
	done
	(( $((Ret&128)) )) && exit $Ret
fi

cfgmgr

i=0
AvailableVGs=$(lsvg -o)
for VG in ${VGs[*]}
do
	if [[ -n $(print "$AvailableVGs" | grep "$VG" ) ]]
	then
		(( Verbose )) && print "$VG is already active, nothing to do."
	else
		[[ -z ${HDisks[$i]} ]] && importvg -L $VG ${HDisks[$i]} || \
			(( Ret=Ret|1 )) && continue
		varyonvg $ForceVaryOn $VG
		if (( $? == 0 ))
		then
			(( Verbose )) && print "$VG activated."
		else
			(( Ret=Ret|1 ))
		fi
	fi
	(( i+=1 ))
done
(( Ret != 0 )) && exit 1


MountedFSs=$(mount)
for FS in ${FSs[*]}
do
	if [[ -n $(print "$MountedFSs" | grep "$FS" ) ]]
	then
		(( Verbose )) && print "$FS is already mounted, nothing to do."
	else
		fsck -fp ${FS}
		if (( $? == 0 ))
		then
			mount $FS 
			if (( $? == 0 ))
			then
				(( Verbose )) && print "$FS mounted."
			else
				(( Ret=Ret|4 ))
			fi
		else
			(( Ret=Ret|2 ))
		fi
	fi
done

i=0
for IP in ${IPs[*]}
do
	if [[ -n $(lsattr -El ${Ifs[$i]} -a alias4 | awk '$2~"'$IP'" { print $2 }') ]]
	then
		(( Verbose )) && print "$IP is already up, nothing to do."
	else
		[[ -n ${Netmasks[$i]} ]] && Netmask=",${Netmasks[$i]}"
		#ifconfig ${Ifs[$i]} alias $IP netmask ${Netmasks[$i]} up
		chdev -l ${Ifs[$i]} -a alias4=$IP$Netmask
		if (( $? == 0 ))
		then
			(( Verbose )) && print "$IP added."
		else
			(( Ret=Ret|8 ))
		fi
	fi
	(( i=i+1 ))
done

exit $Ret
                                