#!/usr/bin/ksh -p
# Version	1.0
# Date		13 Apr 2005
# Author	Kirill Kartinkin

# Программа предназначена для зеркалирования инкапсулированного системного диска
# средствами Veritas Volume Manager.
#
# Зеркалирование производится в два этапа.
# На первом этапе в группу rootdg добавляется диск-зеркало, потом тома,
# лежащие на системном диске (rootdisk), переносятся на диск-зеркало.
# Системный диск удаляется из группы rootdg -- это позволит нам его добавить заново 
# На втором этапе к томам добавляются зеркала.
#
# Ограничения:
#	Системный диск должен быть заранее инкапсулирован.
#	Если в rootdg более одного диска, зеркалируются только те тома,
#	которые лежат на диске rootdisk.
#	Диски должны быть с одинаковой геометрией.
#	На системном диске должен быть один свободный цилиндр.
#	Для работы программы требуется пакет SUNWxcu4
#	
# Использование:
#	Ставите Veritas Volume Manager
#	Пришиваете необходимые заплатки
#	Запускаете vx_root_mirror.sh ИмяДиска, где ИмяДиска -- имя диска (вида cXtXdX),
#		на который будет производится зеркалирование
#	Запускаете vx_vtoc.sh -R
# 
# Возвращаемые значения:
#	0	O.K.
#	1	Уже есть одно зеркало
#	2	Не найдено системного диска
#	3	Не найдено диска, предполагаемого под зеркало
#	4	Диски не одинаковые
#	5	На системном диске нет пустого цилиндра
#	6	Ошибка при добавлении диска rootdiskm в дисковую группу rootdg
#	7	Ошибка при переносе тома с диска roodisk на зеркало rootdiskm
#	8	Ошибка при удалении диска rootdisk из дисковой группы rootdg
#	9	Ошибка при добавлении диска rootdisk в дисковую группу rootdg
#	10	Ошибка при зеркалировании тома
#	100	Ошибки в параметрах командной строки

################################################################################
# Описываем переменные конфигурации и производим необходимые проверки

RootClone=rootclone
RootSpare=rootspare

Name=${0##*/}
PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

################################################################################
# Разбираем параметры командной строки
if (( $# == 0 ))
then
	print "Usage: ${Name} [spare cXtXdX] [mirror cXtXdX] [clone cXtXdX]"
	exit 100
fi


################################################################################
function CheckRet
{
	if (( $? != 0 ))
	then
		print "Unnable to $2."
		if [[ -z ${Debug} ]]
		then
			exit $1
		else
			print "Debug mode:"
			/usr/xpg4/bin/sh -o emacs
		fi
	fi
}	


Path=${0%/*}
if [[ ${Path} == $0 ]]
then
	Path=""
else
	Path=${Path}/
fi

Version=$(pkginfo -l VRTSvxvm|awk '$1=="VERSION:" { print $2 ; exit}' )
print "VxVM version: ${Version}"
Version=${Version%%.*}
if (( ${Version} < 4 ))
then
	DiskSetupOpts=""
else
	DiskSetupOpts="format=sliced"
fi

while (( $# > 0 ))
do
	print "################################################################################
"
	case $1 in
		mirror)
			print "Mirroring root disk...\n"
			${Path}/vx_root_mirror.sh $2
			${Path}/vx_vtoc.sh -R
			;;
		clone)
			print "Creating root's clone...\n"
			vxprint -g rootdg ${RootClone} 2>/dev/null
			if (( $? != 0 ))
			then
				vxdisksetup -i $2 ${DiskSetupOpts}
				CheckRet 6 "initialize disk $2."
				vxdg -g rootdg adddisk ${RootClone}=$2
				CheckRet 6 "add disk $2 to rootdg."
			fi
			${Path}cloneroot1.3 ${RootClone}
			;;
		spare)
			print "Adding spare disk...\n"
			vxprint -g rootdg ${RootSpare} 2>/dev/null
			if (( $? != 0 ))
			then
				vxdisksetup -i $2 ${DiskSetupOpts}
				CheckRet 6 "initialize disk $2."
				vxdg -g rootdg adddisk ${RootSpare}=$2
				CheckRet 6 "add disk $2 to rootdg."
			fi
			vxedit -g rootdg set spare=on ${RootSpare}
			vxedit -g rootdg set nconfig=all nlog=all rootdg
			;;
		*)
			print $*
			exit
			;;
	esac
	shift 2
done
