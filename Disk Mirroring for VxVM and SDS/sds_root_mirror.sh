#!/usr/bin/ksh -p
# Version	1.0
# Date		16 Apr 2004
# Author	Kirill Kartinkin

# Программа предназначена для зеркалирования системного диска
# средствами Solstice DiskSuite.
#
# Все разделы, кроме 0, преобразуются в мета-диски dX1 (первый диск) и dX2 (зеркало),
# из них собирается RAID-1 -- dX0.
# Корневая файловая система монтируется с d0, который, в свою очередь,
# состоит из половинок d1 и d2.
#
# Зеркалирование производится в два этапа.
# На первом этапе требуется запустить программу с параметрами -R ИмяДиска.
# Она разбивает диск-зеркало, создает мета-диски, представляющие собой зеркала,
# изменяет /etc/vfstab, добавляет в стартоывые скрипты файл 
# /etc/rcS.d/S99sdsrootmirror, после чего производит перезагрузку.
# На втором этапе (после перезагрузки) исполняется скрипт /etc/rcS.d/S99sdsrootmirror,
# который добавляет зеркала и синхронизирует данные.
#
# Ограничения:
#	Диски должны быть с одинаковой геометрией.
#	Раздел 0 должен содержать корневую файловую систему.
#	Должен существовать раздел с тэгом 9 (alternate),
#		размером не менее 12288 блоков размещения реплик.
#	Система должна находиться в однопользовательском режиме.
#	Для работы программы требуется пакет SUNWxcu4
#
# Как следствие, в процессе работы удаляется (и потом добавляется заново) swap,
# лежащий на системном диске.
#
# Использование:
#	sds_root_mirror1 [-F|-R] ИмяДиска
#
# Параметры:
#	ИмяДиска	Имя диска вида cXtXdX, на который будет производится зеркалирование
#	-F	показать, как будут сделаны мета-диски, но ничего не менять
#	-R	зеркалировать диск
# 
# Возвращаемые значения:
#	0	O.K.
#	1	/ лежит не на 0 разделе,
#		указанный диск совпадает с загрузочным,
#		или его просто не найдено
#	2	Диски имеют разную геометрию
#	3	Невозможно удалить swap
#	4	Ошибка при создании реплик
#	5	Ошибка при создании мета-дисков
#	6	Ошибка при создании мета-бисков для /
#	7	Ошибка при подмене /
#	8	Ошибка при добавлении зеркал
#	9	Раздел alternate не найден
#	100	Ошибка в параметрах

################################################################################
# Описываем переменные конфигурации

Name=${0##*/}
PATH=/bin:/usr/sbin:/usr/opt/SUNWmd/bin

# Файл, в котором сохраняется текущее состояние
RCFile=/etc/rcS.d/S99sdsrootmirror

# Размер реплики в блоках
# В Solaris 8 по умолчанию 1024
# В Solaris 9 -- 8192
MetaDBSize=4096

################################################################################
# Описываем вспомогательные функции

# Функция производит проверку кода возврата,
# если произошла ошибка -- выводится сообщение об ошибке и 
# осуществляется выход из программы.
#
# Параметры:
#	$1	код возврата в случае ошибки
# 	$2	сообщение об ошибке
#
function CheckRet
{
	if (( $? != 0 ))
	then
		# Код возврата не 0, выводим 
		print "Unnable to $2."
		exit $1
	fi
}	

################################################################################
################################################################################
# Разбираем параметры командной строки
if (( $# != 2 ))
then
	print "Usage: ${Name} [-F|R] c?t?d?"
	exit 100
fi

Fake=1
while (( $# > 0 ))
do
	case "$1" in
		-F) Fake=1;;
		-R) Fake=0;;
        *)
			MirrorDisk=$1
			;;
    esac
	shift
done

################################################################################

# Определяем системный диск...
RootSlice=$(nawk '$3=="/" { print $1 }' /etc/vfstab)
RootSlice=${RootSlice##*/}
RootDisk=${RootSlice%s*}
# ...и раздел корневой файловой системы
RootSlice=${RootSlice#*s}

# Мне удобно, чтобы root был на разделе 0. Обычно так и есть.
# Все, делающие иначе, смотрите рис. 1.
if (( ${RootSlice} != 0 ))
then
	# Таковы ограничения
	print "Root slice must be 0."
	exit 1
fi

if [[ ${RootDisk} == ${MirrorDisk} ]]
then
	# Ошибка при задании параметров -- диски должны отличаться
	print "Disk (${MirrorDisk}) is the same with root disk."
	exit 1
fi

# Проверяем геометрии дисков
Out=$(format </dev/null)
# Выкусываем описания дисков из вывода команды format
RootDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${RootDisk} '$1~Disk { print $2 }')
MirrorDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${MirrorDisk} '$1~Disk { print $2 }')
if [[ -z ${MirrorDiskDescr} ]]
then
	# Диска под зеркало не нашли, обидно
	print "Disk ${MirrorDisk} not found."
	exit 1
fi

if [[ "${MirrorDiskDescr}" != "${RootDiskDescr}" ]]
then
	print "This program can mirror disks with a same geometry only."
	print "\t${RootDisk} <${RootDiskDescr}"
	print "\t${MirrorDisk} <${MirrorDiskDescr}"
	exit 2
fi

# Определяем раздел, на котором будут размещены реплики,
MetaDBSlice=$(prtvtoc -h /dev/dsk/${RootDisk}s2 | nawk '$2=="9" { print $1 ; exit }')

if [[ -z ${MetaDBSlice} ]]
then
	print "This program requires slice with an alternate tag."
	exit 9
fi

MetaDBSliceSize=$(prtvtoc -h /dev/dsk/${RootDisk}s2 | nawk '$2=="9" { print $5 ; exit }')
if (( ${MetaDBSliceSize} < $((${MetaDBSize}*3)) ))
then
	print "Slice /dev/dsk/${RootDisk}s${MetaDBSlice} too small (${MetaDBSliceSize} blocks)."
	print "We need $((${MetaDBSize}*3)) blocks. You can edit script to reduce the MetaDBSize parameter."
	exit 9
fi

# Строим список оставшихся разделов
Slices=$(prtvtoc -h /dev/dsk/${RootDisk}s2 | \
	nawk -v R=${RootSlice} -v S=${MetaDBSlice} '$1!="2" && $1!=R && $1!=S { print $1 }')

# Выводим будущую таблицу разбиения
#	ФС	Раздел (мета-диск)	Раздел (мета-диск)
print "Current root disk slices\tTargeted mirror slices"
# Root отдельно
print "\t/	${RootDisk}s0 (d1)\t${MirrorDisk}s0 (d2)"
# По всем остальным разделам, если они есть
if [[ -n ${Slices} ]]
then
	for Slice in ${Slices}
	do
		print "\t$(nawk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)	${RootDisk}s${Slice}═(d${Slice}1)\t${MirrorDisk}s${Slice}═(d${Slice}2)"
	done
fi

if (( $Fake == 1 ))
then
	# Всю волнующую информацию напечатали, выходим
	print "Fake partioning done."
	exit 0
else
	# Предупреждаем...
	print "\nThe system MUST be in single-user mode to mirror root disk."
	# Выводим план работ
	print "\tStep 1. Create metadb replicas."
	print "\tStep 2. Create metadisks for swap, root and other slices."
	print "\tStep 3. Install new root metadisk."
	print "\tStep 4. Reboot. Attention! System will be rebooted automaticly."
	print -n "\nPress Control-C to exit or Return to continue... "
	read
fi

trap 'print "You are not allowed to terminate this program."' 1 2 3 15

################################################################################
print "======\nStep 1"
print "Coping partition table from ${RootDisk} to ${MirrorDisk}..."
# Диски с одинаковой геометрией, проходит такой фокус:
#dd if=/dev/dsk/${RootDisk}s0 of=/dev/dsk/${MirrorDisk}s0 bs=512 count=1
prtvtoc -h /dev/dsk/${RootDisk}s2 |fmthard -s - /dev/rdsk/${MirrorDisk}s2
CheckRet 3 "copy vtoc."
print "Done."

################################################################################
# Cоздаем на выделенном разделе реплики
print "======\nStep 1"
print "Creating metaDBs..."
# Три реплики на системном диске
metadb -f -a -c 3 -l ${MetaDBSize} /dev/dsk/${RootDisk}s${MetaDBSlice}
CheckRet 4 "create metaDBs on ${RootDisk}s${MetaDBSlice}"
# Три -- на зеркале
metadb -f -a -c 3 -l ${MetaDBSize} /dev/dsk/${MirrorDisk}s${MetaDBSlice}
CheckRet 4 "create metaDBs on ${MirrorDisk}s${MetaDBSlice}"
print "Done."

################################################################################
# Создаем мета-диск под swap на соответствующем разделе.
print "======\nStep 2"

if [[ -n ${Slices} ]]
then
	# По всем разделам, кроме корневого
	for Slice in ${Slices}
	do
		FS=$(nawk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)
		# Сначала из раздела первого диска создаем мета-диск dX1
		print "Creating metadisk (d${Slice}0=d${Slice}1+d${Slice}2) for ${FS}..."
		metainit -f d${Slice}1 1 1 /dev/dsk/${RootDisk}s${Slice}
		CheckRet 5 "create d${Slice}1 metadisk"
		# Потом, на диске под зеркало создаем
		# из соответствующего раздела мета-диск dX2
		metainit d${Slice}2 1 1 /dev/dsk/${MirrorDisk}s${Slice}
		CheckRet 5 "create d${Slice}2 metadisk"
		# Объявляем dX0 как mirror из одной половинки dX1,
		# dX2 в зеркало не добавляем, нельзя синхронизировать,
		# пока ФС смонтирована с раздела.
		metainit d${Slice}0 -m d${Slice}1
		CheckRet 5 "create d${Slice}0 metadisk"
		# Правим /etc/vfstab
		# В строке монтирования меняем /dev/dsk на /dev/md/dsk
		# и /dev/rdsk на /dev/md/rdsk
		sed -e "s/\/dev\/rdsk\/${RootDisk}s${Slice}/\/dev\/md\/rdsk\/d${Slice}0/" \
			-e "s/\/dev\/dsk\/${RootDisk}s${Slice}/\/dev\/md\/dsk\/d${Slice}0/" \
			/etc/vfstab >/tmp/vfstab.$$
		cp /tmp/vfstab.$$ /etc/vfstab
		print "Done."
	done
fi

# Теперь переходим к корню. С ним аналогично, только имена отличаются.
print "Creating metadisk (d0=d1+d2) for root..."
metainit -f d1 1 1 /dev/dsk/${RootDisk}s0
CheckRet 6 "create d1 metadisk"
metainit d2 1 1 /dev/dsk/${MirrorDisk}s0
CheckRet 6 "create d2 metadisk"
metainit d0 -m d1
CheckRet 6 "create d0 metadisk"
# Файл /etc/vfstab не правим, это сделает позже metaroot.
print "Done."

################################################################################
print "======\nStep 4"
print "Installing root metadisk..."

# Создаем стартовый скрипт, который добавит зеркала
print '#!/sbin/sh' >${RCFile}
print 'echo "Attaching submirrors..."' >>${RCFile}
print 'metattach d0 d2' >>${RCFile}
print 'if [ $? != 0 ]' >>${RCFile}
print 'then' >>${RCFile}
print '	echo "Unnable to attach submirror d2 to d0"' >>${RCFile}
print '	exit 8' >>${RCFile}
print 'fi' >>${RCFile}
print 'for Slice in "" '${Slices} >>${RCFile}
print 'do' >>${RCFile}
print '	metattach d${Slice}0 d${Slice}2' >>${RCFile}
print '	if [ $? != 0 ]' >>${RCFile}
print '	then' >>${RCFile}
print '		echo "Unnable to attach submirror d${Slice}2 to d${Slice}0"' >>${RCFile}
print '#		exit 8' >>${RCFile}
print '	fi' >>${RCFile}
print 'done' >>${RCFile}
print 'echo "Done."' >>${RCFile}
print "rm ${RCFile}; exit 0" >>${RCFile}

# Программа правит /etc/system и /etc/vfstab
metaroot d0
lockfs -fa
CheckRet 7 "install root metadisk"
print "Done."

################################################################################
print "======\nStep 4"
print "\n\tThe system will be rebooted now."
print -n "\nPress Return to continue... "
read

sync;sync;reboot
