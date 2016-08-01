#!/usr/bin/ksh -p
# Version	1.0
# Date		13 Sep 2004
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

# Имя файла с журналом
LogFile=/var/adm/vx_vtoc.log

# Путь и префикс для файлов, в которые будут записаны старые VTOC'и
# Например, в данном случае имя будет /var/adm/vx_vtoc.c0t0d0
VTOCFile=/var/adm/vx_vtoc

RootDisk=rootdisk
RootDiskM=rootmirror

# Список томов, которые требуется преобразовавать в разделы.
# Кроме томов, указанных в этом списке, мы будем искать остальные, лежащие на rootdisk.
# Имя тома из группы rootdg
set -A Volumes rootvol var swapvol usr opt home

# При зеркалировании используем блок побольше
IOSize="256k"

Name=${0##*/}
PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

################################################################################
# Разбираем параметры командной строки
if (( $# == 0 ))
then
	print "Usage: ${Name} cXtXdX -d"
	exit 100
else
	MirrorDisk=$1
fi

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
		if [[ -z ${Debug} ]]
		then
			exit $1
		else
			print "Debug mode:"
			/usr/xpg4/bin/sh -o emacs
		fi
	fi
}	

if [[ $2 == "-d" ]]
then
	Debug="Debug"
else
	Debug=""
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

################################################################################
################################################################################
print -n "Looking for a rootdisk... "
# Извлекаем список SubDisk'ов, на которых могут лежать rootvol, swapvol, usr и var.
# На случай, если какого-то тома нет, игнорируем ошибки.
# Сначала мы выбираем строки с описанием поддисков
#	sd	rootdisk-01	rootvol-01	ENABLED,
# потом из имени SubDisk'а выделяем первую часть,
# предполагая, что это и будет именем физического диска
SD="$(vxprint -g rootdg ${Volumes[*]} 2>/dev/null | \
	nawk '$1=="sd" { print $2 }' | \
	nawk ' BEGIN { FS="-" } { print $1 }' | sort | uniq )"

if (( $(print "${SD}" | wc -l ) != 1 ))
then
	# Больше одного системного диска.
	print "More than one root disks found ("${SD}")."
	# Берем диск на котором лежит rootvol.
	SD="$(vxprint -g rootdg rootvol 2>/dev/null | \
		nawk '$1=="sd" { print $2 }' | \
		nawk ' BEGIN { FS="-" } { print $1 }' | sort | uniq )"
	if (( $(print "${SD}" | wc -l) > 1 ))
	then
		# Если снова больше одного диска,
		# значит, rootvol уже зазеркален.
		print "\nYou have mirrored rootvol."
		exit 1
	fi
	print "Done.\n\tSelecting ${SD}."
fi

if [[ -z ${SD} ]]
then
	# Что-то здесь не так...
	print "Root disk not found."
	exit 2
fi

print -n "Encounting volumes on the ${SD}... "
# Переменная Vol пробегает по всем известным нам заранее системным томам.
# В переменную Vols мы собираем найденные на диске ${SD} тома.
Vols=""
# В переменную OVols заносим все тома с диска ${SD}.
OVols="$(vxprint -g rootdg 2>/dev/null | \
		nawk -v R=${SD} '$1=="sd" && $2~"^"R"-" { print $3 } ' | sed -e 's/-01//' )"
# В теле цикла заполняем Vols, выкидывая их из OVols.
# Это делается с целью сохранить порядок томов.
# Сначала должны идти rootvol и т.п., потом пользовательские.
for Vol in ${Volumes[*]}
do
	# Проверяем, есть ли том
	V=$(vxprint -g rootdg ${Vol} 2>/dev/null | \
		nawk -v R=${SD} '$1=="sd" && $2~"^"R"-" { print $3 ; exit } ' | sed -e 's/-01//' )
	if [[ -n $V ]]
	then
		# Есть, выкидываем его из OVols
		OVols=$(print "${OVols}" | grep -v $V)
		# и добавляем в Vols
		Vols="${Vols} $V"
	fi
done
# В конец Vols добавляем все остальные тома
Vols="${Vols} ${OVols}"
unset V OVols
print "Done.\n\tVolumes to proceed:"${Vols}"."

print -n "Checking disk geometry..."
# Проверяем геометрии дисков
Out=$(format </dev/null)
# Ищем логическое имя системного диска (cXtXdX)
RD=$(vxprint -g rootdg 2>/dev/null | \
	nawk -v R=${SD} '$1=="dm" && $2==R { print $3 } ')
RD=${RD%s*}
# Выкусываем описания дисков из вывода команды format
RootDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${RD} '$1~Disk { print $2 }')
MirrorDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${MirrorDisk} '$1~Disk { print $2 }')

if [[ -z ${MirrorDiskDescr} ]]
then
	# Описания диска под зеркало не нашли,
	# обидно
	print "\nDisk ${MirrorDisk} not found."
	exit 3
fi

if [[ "${MirrorDiskDescr}" != "${RootDiskDescr}" ]]
then # Мы тупо сравниваем описание дисков
	print "\nThis program can mirror disks with a same geometry only."
	print "\t${RD} <${RootDiskDescr}"
	print "\t${MirrorDisk} <${MirrorDiskDescr}"
	print -n "Press enter to continue or Control-C to exit... "
	read
#	exit 4
fi
print "Done."

# VxVM требует один цилиндр под свои данные. 
# Проверяем наличие свобоного места, ведь при инкапсуляции он
# отрезает меньше цилиндра.
print -n "Checking for free cylinder... "
# Размер цилиндра считаем умножив число головок на число секторов
CylSize=$(print ${RootDiskDescr} | nawk '{ print $NF*$(NF-2) }')
# Свободный объем прикидываем,
# выясняя максимального объема тома,
# который можно создать на системном диске.
Free=$(vxassist -g rootdg -p maxsize alloc=${SD} 2>/dev/null)
if [[ -z ${Free} ]]
then # Когда нет места, vxassist ничего не возвращает
	Free=0
fi
if (( ${Free} < ${CylSize} ))
then
	# Нет места
	print "\nThe system disk has not enouth space."
	print "You must have at least one cylinder (${CylSize} sectors)."
	exit 5
fi
print "Done.\n\tCylinder size is ${CylSize} sectors."
print "\t${Free} sectors are available on the ${SD}."
unset RootDiskDescr MirrorDiskDescr
unset CylSize Free

trap 'print "You are not allowed to terminate this program."' 1 2 3 15

################################################################################
# Перемещаем данные с системного диска на зеркало
print "\nStep 1. Moving data from ${SD} to ${RootDiskM}:"
print "Volumes to proceed:"${Vols}"."
# Для этого сначала создаем зеркало, а потом удаляем первоисточник.

# Сначала инициализируем диск,..
print "Adding mirror disk ${MirrorDisk} as ${RootDiskM} to rootdg..."
vxdisksetup -i ${MirrorDisk} ${DiskSetupOpts}
CheckRet 6 "initialize disk ${MirrorDisk}."
# потом добавляем его в группу rootdg
vxdg -g rootdg adddisk ${RootDiskM}=${MirrorDisk}
CheckRet 6 "add disk ${MirrorDisk} to rootdg."
vxedit -g rootdg set nohotuse="on" ${RootDiskM}
print "Done."

#Vols=$(vxprint -g rootdg ${Volumes[*]} 2>/dev/null | \
#	awk '$1=="v" { print $2 }' )

for Vol in ${Vols}
do
	# Для каждого тома добавляем зеркало, чтобы потом удалить оригинал.
	print "Mirroring ${Vol}..."

	# Отдельно обрабатывается rootvol
	if [[ ${Vol} == rootvol ]]
	then
		# Для зеркалирования rootvol есть специальная команда.
		# Она поправит nvramrc.
		vxrootmir ${RootDiskM}
	else
		# Для остальных томов просто добавляем зеркало
		vxassist -g rootdg -o iosize=${IOSize} mirror ${Vol} layout=contig,diskalign ${RootDiskM}
	fi
	CheckRet 7 "mirror ${Vol}."
	# А теперь удаляем оригинал. Отрываем plex, а затем удалем его.
	print "Removing mirror from ${Vol}..."
	vxplex -g rootdg dis ${Vol}-01
	CheckRet 7 "remove mirror from ${Vol}."
	vxedit -g rootdg -fr rm ${Vol}-01
	CheckRet 7 "remove mirror from ${Vol}."
done
print "Done."

# Удаляем бывший загрузочным диск
print "Removing ${SD}..."
# Это защита от дурака, снимаем ее. Больше она не нужна.
vxedit -g rootdg rm rootdiskPriv 2>/dev/null
#CheckRet 4 "remove disk ${SD} from rootdg."
# Удаляем диск из группы...
vxdg -g rootdg rmdisk ${SD}
CheckRet 8 "remove disk ${SD} from rootdg."
# ...и переводим его в начальное состояние.
vxdiskunsetup ${RD}
CheckRet 8 "remove disk ${RD}."
print "Done".

################################################################################
print "\nStep 2. Coping data from ${RootDiskM} to ${RootDisk}."

print "Adding disk ${RD} as ${RootDisk} to rootdg..."
# Заново инициализируем диск...
vxdisksetup -i ${RD} ${DiskSetupOpts}
CheckRet 9 "initialize disk ${RD}."
# ...и добавляем его в группу rootdg
vxdg -g rootdg adddisk ${RootDisk}=${RD}
CheckRet 9 "add disk ${RD} to rootdg."
vxedit -g rootdg set nohotuse="on" ${RootDisk}
print "Done."

# Переменная Vol пробегает по всем томам из группы rootdg,
# лежащим на загрузочном диске 
for Vol in ${Vols}
do
	# Для каждого тома добавляем теперь уже настоящее зеркало.
	print "Mirroring ${Vol}..."
	if [[ ${Vol} == rootvol ]]
	then
		vxrootmir ${RootDisk}
	else
		vxassist -g rootdg -o iosize=${IOSize} mirror ${Vol} layout=contig,diskalign ${RootDisk}
	fi
	CheckRet 10 "mirror ${Vol}."
done
print "Done."

eeprom use-nvramrc?=true
vxedit -g rootdg set nconfig=all nlog=all rootdg

# Напоминалочка
print "\nStep 3. Use vx_vtoc.sh to partioning ${RootDiskM} and ${RootDisk} disks."
