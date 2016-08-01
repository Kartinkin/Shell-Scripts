#!/usr/xpg4/bin/sh
# Version	0.0
# Date		25 Sep 2002
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
#	Система должна находиться в однопользовательском режиме.
#	Для работы программы требуется пакет SUNWxcu4
#
# Внимание! Экономя свободные разделы, мы не выделяем под реплики
# отдельного раздела. Реплики создаются на содержащим swap разделе.
# Как следствие, в процессе работы удаляется (и потом добавляется заново) swap,
# лежащий на системном диске.
#
# Использование:
#	sds_root_mirror [-F|-R] ИмяДиска
#
# Параметры:
#	ИмяДиска	Имя диска вида cXtXdX, на который будет производится зеркалирование
#	-F	показать, как будут сделаны мета-диски, но ничего не менять
#	╜R	зеркалировать диск
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
#	100	Ошибка в параметрах
#0x09            /* Alternate s#

################################################################################
# Описываем переменные конфигурации

Name=${0##*/}
PATH=/usr/xpg4/bin:/usr/sbin:/bin:/usr/opt/SUNWmd/bin

# Файл, в котором сохраняется текущее состояние
RCFile=/etc/rcS.d/S99sdsrootmirror

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
RootSlice=$(awk '$3=="/" { print $1 }' /etc/vfstab)
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
RootDiskDescr=$(print "$Out" | awk -F"<" -v Disk=${RootDisk} '$1~Disk { print $2 }')
MirrorDiskDescr=$(print "$Out" | awk -F"<" -v Disk=${MirrorDisk} '$1~Disk { print $2 }')
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

# Определяем раздел, на котором находится swap,
# на нем впоследствии будут создаваться реплики
SwapSlice=$(awk '$4=="swap" { print $1 }' /etc/vfstab)
SwapSlice=${SwapSlice##*/}
SwapSlice=${SwapSlice#*s}

# Строим список оставшихся разделов
Slices=$(prtvtoc -h /dev/dsk/${RootDisk}s2 | \
	awk -v R=${RootSlice} -v S=${SwapSlice} '$1!="2" && $1!=R && $1!=S { print $1 }')

# Выводим будущую таблицу разбиения
#	ФС	Раздел (мета-диск)	Раздел (мета-диск)
print "Current root disk slices\tTargeted mirror slices"
# Root отдельно
print "\t/	${RootDisk}s0 (d1)\t${MirrorDisk}s0 (d2)"
# Swap, естественно, тоже
print "\tswap	${RootDisk}s${SwapSlice}═(d${SwapSlice}1)\t${MirrorDisk}s${SwapSlice}═(d${SwapSlice}2)"
# По всем остальным разделам, если они есть
if [[ -n ${Slices} ]]
then
	for Slice in ${Slices}
	do
		print "\t$(awk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)	${RootDisk}s${Slice}═(d${Slice}1)\t${MirrorDisk}s${Slice}═(d${Slice}2)"
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
	print "\n\tStep 1. Delete primary swap area and dump device."
	print "\tStep 2. Create metadb replicas."
	print "\tStep 3. Create metadisks for swap, root and other slices."
	print "\tStep 4. Install new root metadisk."
	print "\tStep 5. Reboot. Attention! System will be rebooted automaticly."
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

# Удаляем из ситемы swap, т.к. нам нужно место под реплики
print "Deleting the swap area (${RootDisk}s${SwapSlice})..."
print "Plese ignore the follows dumpadm messages."
# Удаляем...
swap -d /dev/dsk/${RootDisk}s${SwapSlice}
# Проверяем, получилось ли
swap -l 2>/dev/null |grep ${RootDisk}s${SwapSlice} >/dev/null
if (( $? == 0 ))
then
	# Нет, swap остался
	print "Unnable to delete the ${RootDisk}s${SwapSlice} swap area."
	exit 3
fi
print "Done."

################################################################################
# Cоздаем на разделе из-под swap реплики
print "======\nStep 2"
print "Creating metaDBs..."
# Три реплики на системном диске
metadb -f -a -c 3 /dev/dsk/${RootDisk}s${SwapSlice}
CheckRet 4 "create metaDBs on ${RootDisk}s${SwapSlice}"
# Три -- на зеркале
metadb -f -a -c 3 /dev/dsk/${MirrorDisk}s${SwapSlice}
CheckRet 4 "create metaDBs on ${MirrorDisk}s${SwapSlice}"
print "Done."

################################################################################
# Создаем мета-диск под swap на соответствующем разделе.
print "======\nStep 3"
# Размер, правда, стал чуть-чуть меньше. 
print "Creating metadisk (d${SwapSlice}0=d${SwapSlice}1+d${SwapSlice}2) for swap..."
# Сейчас и всегда:
#	Сначала из раздела первого диска создаем мета-диск dX1
metainit d${SwapSlice}1 1 1 /dev/dsk/${RootDisk}s${SwapSlice}
CheckRet 5 "create d${SwapSlice}1 metadisk"
#	Потом, на диске под зеркало создаем из соответствующего раздела
#	мета-диск dX2
metainit d${SwapSlice}2 1 1 /dev/dsk/${MirrorDisk}s${SwapSlice}
CheckRet 5 "create d${SwapSlice}2 metadisk"
#	Объявляем dX0 как mirror из одной половинки dX1,
#	dX2 в зеркало не добавляем, зачем синхронизировать,
#	если ФС пока смонтирована с раздела.
metainit d${SwapSlice}0 -m d${SwapSlice}1
CheckRet 5 "create d${SwapSlice}0 metadisk"

# Правим /etc/vfstab
# В строке монтирования меняем /dev/dsk на /dev/md/dsk
awk -v S=${SwapSlice} -v R=${RootDisk} \
	'$1=="/dev/dsk/"R"s"S { print "/dev/md/dsk/d"S"0\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\n#"$0 ; break }
	{ print $0 }' /etc/vfstab >/tmp/vfstab.$$
cp /tmp/vfstab.$$ /etc/vfstab
print "Done."

if [[ -n ${Slices} ]]
then
	# Делаем аналогичную операцию с остальными разделами
	for Slice in ${Slices}
	do
		FS=$(awk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)
		print "Creating metadisk (d${Slice}0=d${Slice}1+d${Slice}2) for ${FS}..."
		metainit -f d${Slice}1 1 1 /dev/dsk/${RootDisk}s${Slice}
		CheckRet 5 "create d${Slice}1 metadisk"
		metainit d${Slice}2 1 1 /dev/dsk/${MirrorDisk}s${Slice}
		CheckRet 5 "create d${Slice}2 metadisk"
		metainit d${Slice}0 -m d${Slice}1
		CheckRet 5 "create d${Slice}0 metadisk"
		awk -v S=${Slice} -v R=${RootDisk} \
			'$1=="/dev/dsk/"R"s"S { print "/dev/md/dsk/d"S"0\t/dev/md/rdsk/d"S"0\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\n#"$0 ; break }
			{ print $0 }' /etc/vfstab >/tmp/vfstab.$$
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
lockfs -af
CheckRet 7 "install root metadisk"
print "Done."

################################################################################
print "======\nStep 5"
print "\n\tThe system will be rebooted now."
print -n "\nPress Return to continue... "
read
sync;sync;reboot
