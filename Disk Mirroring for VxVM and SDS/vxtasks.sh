#!/usr/bin/ksh -p
# Version	2.5
# Date		12 Jul 2006
# Author	Kirill Kartinkin

# Программа выполняет необходимые по EIS модификации
# системной дисковой группы rootdg в Veritas Volume Manager.
#
# Программа работает с VxVM версий 3.x и 4.x.
#
# Использование:
#	vxroottasks.sh [-g DiskGroupName]
#		[mirror [-all] cXtXdX]
#		[spare cXtXdX]
#		[clone [-all] [cXtXdX]]
#		[vtoc [-fake|-all] DiskName]
#		[addmirror [-all|-force] DiskName=cXtXdX]
#		[removemirror DiskName]
#		[setupdump [-fake]]
#	где DiskName -- имя диска в VxVM.
# Параметры вызова:
#	mirror -- выполняет следующю последовательность:
#		addmirror [-all] rootmirror=cXtXdX
#		removemirror rootdisk
#		addmirror [-all] rootdisk=CYtYdY
#		vtoc rootdisk
#		vtoc rootmirror
#		setupdump, если не установлен dedicated dump device
#	spare -- добавляет spare-диск.
#	clone -- создает клон системного диска
#		(авторы алгоритма Игорь Увкин и Александр Факанов).
#	vtoc -- программа отражеет тома rootvol, swapvol, usr, opt, var и home
#		из группы rootdg на разделы физических дисков.
#		С параметррм -fake показывает, какое будет разбиение,
#		но ничего не делает.
#		Если указана опция -all, пытается отобразить все тома. Unsupported.
#		Разбиение:
#			Partition  Tag  Flags  Mount Directory
#			0          2    00    /
#			1          7    00    /var
#			3          15   00    vxvm 
#			4          14   00    vxvm
#			5          3    01    swap
#			6          4    00    /usr
#			7          0    00    /opt
#			7          8    00    /export/home
#		В /etc/vfstab добавляются коментарии со строками для монтирования
#		указанных файловых систем.
#		Старые VTOC'и записываются в $VTOCFile.
#		Кроме всего прочего, запускает setupdump.
#	addmirror -- зеркалирует системный диск,
#		инициализируя диск cXtXdX и добавляя его в rootdg с именем DiskName.
#		Если указана опция -all,
#		зеркалируюся все тома с первого найденного системного диска.
#		Если указана опция -force,
#		зеркалируются только тома rootvol, swapvol, usr, opt, var и home
#		(задается переменной SatelliteVolumes).
#		Если никаких опций не указано, и кроме системных системных томов
#		на исходном диске есть еще что-то, зеркалирование не производится.
#		Кроме всего прочего, запускает setupdump.
#	removemirror -- удвляет зеркала с указанного диска,
#		после чего удаляет диски из rootdg и деинициализирует его.
#		Если на диске лежат незазеркалированные тома,
#		никакие операции не производятся.
#		Кроме всего прочего, запускает setupdump.
#	setupdump -- конфигурирует dump device, выбирая первый диск,
#		на котором есть swapvol, отображенный на физический раздел.
#		Если dump device установлен на раздел диска, на котором нет swapvol,
#		никаких действий не производится.
#		Если указана опция -fake, выводятся только диагностические сообщения,
#		физически ничего не меняется.
#
#	Все параметры можно указывать одновременно.
#	 
# Возвращаемые значения:
#	0	O.K.
#	1	Ошибка при добавлении зеркала
#	6	Ошибка при добавлении диска дисковую группу rootdg
#	100	Ошибки в параметрах командной строки

################################################################################
# Описываем переменные конфигурации

Name=${0##*/}
Path=${0%/*}
if [[ ${Path} == $0 ]]
then
	Path=""
else
	Path=${Path}/
fi

PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

# Имена дисков по-умолчанию
RootDiskName=rootdisk
RootMirrorName=rootmirror
RootCloneName=rootclone
RootSpareName=rootspare

SatelliteVolumes="rootvol var swapvol usr opt home"

# При зеркалировании используем блок побольше
IOSize="256k"

GuardSuff="guard"
GuardPUtil0="DONOTUSE"

VTOCTag="vxvm"

TempDir=/var/adm/config
if [[ ! -d ${TempDir} ]]
then
	mkdir -p ${TempDir}
fi

# Имя файла с журналом
LogFile=${TempDir}/vx_tasks.log
# Путь и префикс для файлов, в которые будут записаны старые VTOC'и
# Например, в данном случае имя будет ${TempDir}/vtoc.c0t0d0
VTOCFile=${TempDir}/vtoc

if [[ $1 == "-g" ]]
then
	DGName="$2"
	shift 2
else
	DGName=rootdg
fi

# Проверяем версию VxVM, поскольку инициализация дисков в четвертой версии
# требует дополнительных опций
Version=$(pkginfo -l VRTSvxvm|awk '$1=="VERSION:" { print $2 ; exit}' )
Version=${Version%%.*}
if (( ${Version} < 4 ))
then
	DiskSetupOpts=""
	BootSetupOpts=""
else
	DiskSetupOpts="format=sliced"
	BootSetupOpts="-g ${DGName}"
fi

# Я еще не понял в каких версиях,
# но иногда VxVM при инициализации диска оставляет нулевой цилиндр свободным.
# Чтобы избедать этого, раскомментируйте следующую строку
#DiskSetupOpts="${DiskSetupOpts} old_layout"

################################################################################
################################################################################
# Описываем вспомогательные функции

################################################################################
function Usage
{
	print "Usage: ${Name} [-g DiskGroupName]"
	print "\t[vtoc [-fake] DiskName]"
	print "\t[mirror [-all] cXtXdX]"
	print "\t[spare cXtXdX]"
	print "\t[clone [-all] [cXtXdX]]"
	print "\t[addmirror [-all|-force] DiskName=cXtXdX]"
	print "\t[removemirror DiskName]"
	print "\t[setupdump [-fake]]"
	exit 100
}

################################################################################
function PrintList
{
	Out=""
	for i in $*
	do
		Out="${Out}\"$i\","
	done
	print "${Out%,}"
}

################################################################################
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
			/usr/bin/ksh -o emacs
		fi
	fi
}	

################################################################################
# Функция ищет, на каком диске лежит rootvol.
# Если дисков несколько, выбирается первый
#
# Изменяемые внешние переменные:
#	RootDisk	имя диска
#	RootDiskPV	физическое имя диска
#	RootDiskPV_	физичесоке имя диска без s2
#
# Возвращаемые значения:
#	0	O.K.
#	1	Диск не найден
#
function FindRootDisk
{
	RootDisk=$(vxprint -Q -g ${DGName} -e"sd_pl_name.pl_volume == \"rootvol\" && sd_name != \"rootdisk-B0\"" -F"%disk")
	if [[ -z "${RootDisk}" ]]
	then
		print "\tRootdisk not found."
		return 1
	elif [[ "${RootDisk%
*}" != "${RootDisk}" ]]
	then
		print "\tVolume rootvol found on the follows disks: "${RootDisk}"."
		RootDisk=${RootDisk%%
*}
		print "\tDisk ${RootDisk} selected as a source."
		print -n "Press Control-C to exit or Return to continue "
		read
	fi
	print "Volume rootvol found on the disk ${RootDisk}."
	# Находим имя физического диска
	# Переменная PV срдержит имя диска, а
	# переменная PV_ -- имя без указания раздела
	RootDiskPV=$(vxprint -g ${DGName} -dF '%daname' ${RootDisk} 2>/dev/null)
	RootDiskPV_=${RootDiskPV%s*}
}

################################################################################
# Функция заполняет переменные Volumes и VolumesToProceed.
# Имена томов в списках отсортированы следующим образом: сначала идут системные
# тома в порядке, указанном в SatelliteVolumes,
# потом остальные в алфавитном порядке.

#
# Параметры:
#	ИмяДискаВVxVM
# Используемые внешние переменные:
#	SatelliteVolumes список системных томов
# Изменяемые внешние переменные:
#	Volumes	имена томов, которые лежат на указанном диске
#	VolumesToProceed	имена системных томов
#	PV		физическое имя диска
#	PV_		физичесоке имя диска без s2
# 
# Возвращаемые значения:
#	0	O.K.
#
function ColVolumes
{
	VolumesToProceed=""
	PV=""
	PV_=""
	# Находим имя физического диска
	# Переменная PV срдержит имя диска, а
	# переменная PV_ -- имя без указания раздела
	PV=$(vxprint -g ${DGName} -dF '%daname' $1 2>/dev/null)
	PV_=${PV%s*}
	# Список всех томов на диске
	Vols=$(vxprint -Q -g ${DGName} -e"pl_sd.sd_dm_name == \"$1\" && pl_volume != \"\"" -F "%vol")
	
	if [[ -z ${Vols} ]]
	then
		print "\tNo volumes found on disk $1."
		return 1
	fi

	# В цикле заполняем список системных томов и сортируем список Volumes.
	# Для каждого значения переменной Volume производится проверка на наличие
	# тома с таким именем, при наличии том добавляется в список VolumesToProceed.
	# Также Volume ищется в списке Vols, и генериуется новый список Volumes
	# (для сохранения правильного порядка томов).
	VolumesToProceed=""
	Volumes=""
	for Volume in ${SatelliteVolumes}
	do # Для каждого тома из списка SatelliteVolumes
		if [[ -n $(vxprint -g ${DGName} -e"v_nplex > 0 && v_plex.pl_subdisk.sd_dm_name == \"$1\" && name == \"${Volume}\"" -F"%vol") ]]
		then # Том есть на диске, добавляем его в VolumesToProceed
			VolumesToProceed="${VolumesToProceed} ${Volume}"
		fi
		if [[ -n $(print "${Vols}" | grep ${Volume}) ]]
		then # Том есть в списке Vols, добавляем его в Volumes
			Volumes="${Volumes} ${Volume}"
			# и выкидываем из Vols
			Vols="$(print "${Vols}" | grep -v ${Volume})"
		fi
#		print "Volumes=${Volumes}\nVolumesToProceed=${VolumesToProceed}"
	done
	if [[ -n ${Vols} ]]
	then # Если что-то осталось в Vols, добавляем это в конец Volumes
		Volumes="${Volumes} ${Vols}"
	fi
	print "\tSubdisks from the listed volumes are found on the the disk $1:\n\t\t"${Volumes}
}

################################################################################
################################################################################
#

################################################################################
# Функция предназначена для отражения томов rootvol, swapvol, usr, opt и  var 
# лежащих на указанном диске на разделы этого диска.
#
# Разбиение:
#	Partition  Tag  Flags  Mount Directory
#	0          2    00    /
#	1          7    00    /var
#	3          15   00    vxvm 
#	4          14   00    vxvm
#	5          3    01    swap
#	6          4    00    /usr
#	7          0    00    /opt
#	7          8    00    /export/home
#
# В /etc/vfstab добавляются коментарии со строками для монтирования
# указанных файловых систем.
# Старые VTOC'и записываются в $VTOCFile.
#	
# Использование:
#	CreateVTOC ИмяДискаВVxVM
# Используемые внешние переменные:
#	Force	если имеет значение 0, то функция показывает,
#		как будет переразбит диск, но ничего не меняет
#	SetDump	если имеет значение 1, то функция
#		дополнительно устанавливает раздел, на который отображается swapvol,
#		как dump device

# 
# Возвращаемые значения:
#	0	O.K.

function CreateVTOC
{
	Disk=$1
	
	print "Building VTOC for the disk ${Disk}..."
	ColVolumes ${Disk}
	if (( $? != 0 ))
	then
		return 1
	fi
	if (( ${Force} == 2 ))
	then
		VolumesToProceed=${Volumes}
	fi
	#########################################
	# Сначала строим полное имя устройства,
	# у которого и обнуляем таблицу разделов,
	# с целью занести новые значения.

	# Запоминаем старую таблицу
	VTOC="$(prtvtoc -h /dev/dsk/${PV})"
	# ... и записываем ее в журнал и в специальный файл
	print "${VTOC}" > ${VTOCFile}.${PV_}

	# Перекраиваем таблицу, удаляя все разделы,
	# кроме 2 и разделов VxVM
	# (если мы оставим старое разбиение, не пройдет vxmksdpart).
	if (( ${Force} != 0 ))
	then
		# Естественно, делаем это только в реальной жизни
		print "${VTOC}" | \
			nawk '$2!=5 && $2!=14 && $2!=15 { print "\t"$1"\t0\t00\t0\t0\t0" ; continue }
	        	{ print $0 }' | \
	   	    fmthard -s - /dev/rdsk/${PV} >/dev/null 2>&1
	fi
	# Получаем список занятых разделов.
	BusySlices=$(print "${VTOC}" | \
		nawk '$2==5 || $2==14 || $2==15 { print $1 }')
	# Удаляем переводы строки
	BusySlices=$(print ${BusySlices})
	print "\tSlices are used: ${BusySlices}"

	# Удаляем старые записи из /etc/vfstab
	cp /etc/vfstab /etc/vfstab.vtoc
	grep -v "${VTOCTag} /dev/dsk/${PV_}s" /etc/vfstab.vtoc >/etc/vfstab
	print "# ${Disk}" >>/etc/vfstab

	FirstSwap=
	#########################################################
	# Лежащие диске тома отображаются в разделы диска
	# В переменной BusySlices храним список занятых разделов,
	# пополняем его по мере продвижения.
	for Volume in ${VolumesToProceed}
	do	# Определяем, что за том,
		# ищем пустой раздел, добавляем его в список занятых
		# после чего отображаем на него том

		# Имя subdisk'а данного тома, который лежит на данном диске
		SD=$(vxprint -Q -g ${DGName} \
			-e"sd_dm_name == \"${Disk}\" && sd_pl_name.pl_volume == \"${Volume}\" " \
			-F "%name")
		if [[ -z ${SD} ]]
		then # На этом диске такого тома нет
			continue
		fi

		RDsk='/dev/rdsk/${PV_}s${Slice}'
		Dsk='/dev/dsk/${PV_}s${Slice}'

		case ${Volume} in
			rootvol)
				# Атрибуты раздела, см. prtvtoc(1M)
				Tag="0x02"
				Flags="0x00"
				# Опции в vfstab, см. vfstab(4).
				FSCKOrder="1"
				FSType="ufs"
				MountOnBoot="no"
				MountPoint="/"
				# Раздел, на который пытаться положить том.
				# Если раздел занят, том будет помещен на первый свободный
				Slice=0
				;;
			var)
				Tag="0x07"
				Flags="0x00"
				FSCKOrder="1"
				FSType="ufs"
				MountOnBoot="no"
				MountPoint="/var"
				Slice=1
				;;
			swapvol)
				Tag="0x03"
				Flags="0x01"
				FSCKOrder="-"
				FSType="swap"
				MountOnBoot="no"
				MountPoint="-"
				Slice=5
				RDsk="-"
				;;
			usr)
				Tag="0x04"
				Flags="0x00"
				FSCKOrder="1"
				FSType="ufs"
				MountOnBoot="no"
				MountPoint="/usr"
				Slice=6
				;;
			opt)
				Tag="0x00"
				Flags="0x00"
				FSCKOrder="2"
				FSType="ufs"
				MountOnBoot="yes"
				MountPoint="/opt"
				Slice=7
				;;
			home)
				Tag="0x08"
				Flags="0x00"
				FSCKOrder="2"
				FSType="ufs"
				MountOnBoot="yes"
				MountPoint="/export/home"
				Slice=7
				;;
			*)
				Tag="0x00"
				Flags="0x00"
				mount -p | egrep "/dev/vx/dsk/.*/${Volume}" | read BDev CDev MountPoint FSType FSCKOrder MountOnBoot Options;
				FSCKOrder="3"
				#FSType="ufs"
				#MountOnBoot="no"
				Slice=7
				;;
			esac

		# Проверяем, можно ли положить на Slice
		if [[ "${BusySlices}" == "${BusySlices#*${Slice}}" ]]
		then
			# Да, PrefSlice свободен
			# Раздел найден
			# и будет нами занят
			BusySlices="${BusySlices} ${Slice}"
		else
			# Пробегаем по всем номерам в поисках свободного
			Slice=""
			for S in 0 1 3 4 5 6 7
			do
				# Как только нашли свободный
				if [[ "${BusySlices}" == "${BusySlices#*$S}" ]]
				then
					# Запоминаем его номер
					Slice=${S}
					# и добавляем в список занятых,
					BusySlices="${BusySlices} ${S}"
					break
				fi
			done
			# Если не нашли свободного раздела,
			if [[ -z ${Slice} ]]
			then
				# грустим и переходим к следующему тому.
				print "\tThere is no free slices to map volume ${Volume}."
				continue
			fi
		fi

		print "\tMapping subdisk ${SD} (volume ${Volume}) to ${PV_}s${Slice}..."
		if (( ${Force} != 0 ))
		then # Том отображается на раздел ...
			vxmksdpart -g ${DGName} ${SD} ${Slice} ${Tag} ${Flags}
			# ...и в /etc/vfstab добавляется строка для аварийного монтирования ФС
			eval print "\#${VTOCTag} ${Dsk}	${RDsk}	${MountPoint}	${FSType}	${FSCKOrder}	${MountOnBoot}	-" >>/etc/vfstab
#			if [[ ${Volume} == "swapvol" && -z ${FirstSwap} ]]
#			then
#				eval FirstSwap=${Dsk}
#				SwapDsk=${PV_}
#			fi
		else
			print "\t\t"vxmksdpart -g ${DGName} ${SD} ${Slice} ${Tag} ${Flags}
		fi
	# Переходим к следующему тому
	done

}

################################################################################
# Функция предназначена для зеркалирования всех томов с указанного диска.
#
# Параметры:
#	ИмяДискаВVxVM	имя исходного диска
#	ИмяДискаВVxVM	будет дадено диску cXtXdX при добавлении в ${DGName}
# Используемые внешние переменные:
# 	Force	Если значение 0, то в том случае, если список системных томов и
#			список томов на диске не совпадают, зеркалирование не производится.
#		Если значение 1, копируются только тома из переменной VolumeToProceed,
#		даже если список системных томов и список томов на диске не совпадают.
#		Если значение 2, то копируются все тома.
# 
# Возвращаемые значения:
#	0	O.K.
#	1	Список системных томов и список томов на диске не совпадают и All=0
#	2	Ошибка при добавлении плекса
#
function AddMirror
{
	Orig=$1
	Target=$2
	
	print "Mirroring disk ${Orig} to ${Target}"
	# Узнаем, какие тома зеркалировать
	ColVolumes ${Orig}

	if (( ${Force} == 2 ))
	then # Указана опция "все тома"
		VolumesToProceed="${Volumes}"
	elif [[ "${VolumesToProceed}" != "${Volumes}" ]]
	then # На диске лежат незнакомые тома
		print -n "\tbut only\n\t\t${VolumesToProceed}\n\t"
		if ((${Force} == 1 ))
		then
			print "will be mirrored."
		else
			print "encounted for mirroring.\n\tYou should use '-force' or '-all' options."
			return 1
		fi
	fi

	#########################################################
	# Зеркалируем тома
#	print "VolumesToProceed=${VolumesToProceed}"
	for Volume in ${VolumesToProceed}
	do	# Для добавления зеркала используем vxassist
		print "\tMirroring ${Volume}..."
		vxassist -g ${DGName} -o iosize=${IOSize} mirror ${Volume} layout=contig,diskalign ${Target}
		if (( $? != 0 ))
		then
			print "\tUnnable to create ${Volume}'s mirror on the disk ${Target}."
			return 2
		fi
	done
	print "\tExecuting vxbootsetup..."
	vxbootsetup ${BootSetupOpts} ${Target}
}

################################################################################
# Функция предназначена для удаления плексов, лежащих на указанном диске
#
# Параметры:
#	ИмяДискаВVxVM	имя диска
# 
# Возвращаемые значения:
#	0	O.K.
#	1	Некоторые тома, лежащие на диске, имеют только один плекс.
#		Никакие плексы не удалены.
#	2	Ошибка удаления плекса.
#
function RemoveMirror
{
	Orig=$1
	
	print "Removing mirrors from the disk ${Orig}"
	# Узнаем, какие тома лежат на диске
	ColVolumes ${Orig}
	VolumesToProcced="${Volumes}"

	Volumes=$(vxprint -g ${DGName} -e"v_nplex == 1 && v_plex.pl_subdisk.sd_dm_name == \"$Orig\"" -F"%vol")
	if [[ -n ${Volumes} ]]
	then
		print "\tThe follows volumes has only one plex:\n\t\t"${Volumes}
		print "\tand they can not be removed. Terminating."
		return 1
	fi
	
	#########################################################
	# Получаем список плексов, лежащих на указанном диске
	Plexes=$(vxprint -g ${DGName} -e"pl_subdisk.sd_dm_name == \"$Orig\"" -F"%plex")
	# Переменная Plex пробегает по списку найденных плексов.
	for Plex in ${Plexes}
	do  # Сначала отрываем плекс от тома,..
		print "\tRemoving plex ${Plex}..."
		vxplex -g ${DGName} dis ${Plex}
		if (( $? != 0 ))
		then
			print "\tUnnable to dissociate ${Plex}."
			return 2
		fi
		# ...потом удаляем
		vxedit -g ${DGName} -rf rm ${Plex}
		if (( $? != 0 ))
		then
			print "\tUnnable to remove ${Plex}."
			return 2
		fi
	done
}

################################################################################
# Функция предназначена для удаления диска из дисковой группы
#
# Параметры:
#	ИмяДискаВVxVM	имя диска
# Возвращаемые значения:
#	0	O.K.
#	1	Ошибка удаления диска.
#
function RemoveDisk
{
	Orig=$1
	print "Removing ${Orig} from ${DGName}"
	# Это защита от дурака, снимаем ее. Больше она не нужна.
	vxedit -g ${DGName} rm ${Orig}Priv 2>/dev/null
	# Удаляем диск из группы...
	vxdg -g ${DGName} rmdisk ${Orig}
	if (( $? != 0 ))
	then
		print "\tUnnable to remove disk ${Orig} from ${DGName}."
		return 1
	fi
	# ...и переводим его в начальное состояние.
	vxdiskunsetup ${PV_}
	if (( $? != 0 ))
	then
		print "\tUnnable to remove disk ${Orig}."
		return 1
	fi
}

################################################################################
# Функция инициализирует диск и добавляет его в группу ${DGName}
#
# Параметры:
#	ИмяДискаВVxVM	имя диска
#	cXtXdX			физическое имя диска
#
# Возвращаемые значения:
#	0	O.K.
#	1	Ошибка инициализации дискаНекоторые тома, лежащие на диске, имеют только один плекс.
#		Никакие плексы не удалены.
#	2	Ошибка удаления плекса.
#
function SetupDisk
{	# Сначала инициализируем диск,..
	print "Adding disk $2 to the ${DGName}"
	print "\tInitializing the private region on the disk $2..."
	vxdisksetup -i $2 ${DiskSetupOpts}
	if (( $? != 0 ))
	then
		print "\tWould You like to forcibly inittialize disk?"
		print -n "Press Control-C to exit or Return to continue "
		read
		vxdiskunsetup -C $2 
		if (( $? != 0 ))
		then
			return 1
		fi
		vxdisksetup -i $2 ${DiskSetupOpts}
		if (( $? != 0 ))
		then
			return 1
		fi
	fi
	# потом добавляем его в группу ${DGName}
	print "\tAdding disk $2 as a $1 to the ${DGName}..."
	vxdg -g ${DGName} adddisk $1=$2
	if (( $? != 0 ))
	then
		print "\tUnnable to add disk $1 to ${DGName}."
		return 2
	fi
	vxedit -g ${DGName} set nohotuse="on" $1
	vxedit -g ${DGName} set nconfig=all nlog=all ${DGName}
}


################################################################################
# Функция преобразует оторванное зеркало в клон
#	Создается subdisk, закрывающий собой весь диск (чтобы не было свободного места)
#	В корневом разделе в файле /etc/vfstab подставляются разделы вместо томов
#	Из /etc/system удаляется rootdev и прочее
#	Устанавливается bootblock
#	DumpDevice назначается на swap область с этого диска
#
# Параметры:
#	ИмяДискаВVxVM	имя диска
#
# Возвращаемые значения:
#	0	O.K.
#	1	не удается смонтировать корневой раздел
#
function SetupClone
{
	Clone=$1
	print "\tConfiguring root clone"
	CloneLen=$(vxprint -g ${DGName} -F"%len" ${Clone})
	vxmake -g ${DGName} sd ${Clone}-${GuardSuff} disk=${Clone} len=${CloneLen} putil0=${GuardPUtil0}
	vxedit -g ${DGName} set nconfig=all nlog=all ${DGName}
	ColVolumes ${Clone}
	MntPoint=/tmp/${Clone}.$$
	Mnt=$(mount -p | nawk '$1 == "/dev/dsk/'${PV_}s0'" {print $3}')
	if [[ -n "${Mnt}" ]]
	then
		umount ${Mnt}
	fi
	print "\tMounting /dev/dsk/${PV_}s0..."
	mkdir ${MntPoint}
	fsck -y /dev/dsk/${PV_}s0 && \
	mount /dev/dsk/${PV_}s0 ${MntPoint}
	if (( $? != 0 ))
	then
		print "\tUnnable to mount /dev/dsk/${PV_}s0."
		return 1
	fi

	print "\tPatching /etc/vfstab..."
	mv ${MntPoint}/etc/vfstab ${MntPoint}/etc/vfstab.pre_clone
	print "fd	-	/dev/fd	fd	-	no	-" >${MntPoint}/etc/vfstab
	print "/proc	-	/proc	proc	-	no	-" >>${MntPoint}/etc/vfstab
	print "swap	-	/tmp	tmpfs	-	yes	-" >>${MntPoint}/etc/vfstab
	nawk -v PV="/dev/dsk/${PV_}" -v Tag=${VTOCTag} '$1=="#"Tag && $2~PV { print }' ${MntPoint}/etc/vfstab.pre_clone | \
		sed -e "s/\#${VTOCTag}//" >>${MntPoint}/etc/vfstab

	print "\tPatching /etc/system..."
	mv ${MntPoint}/etc/system ${MntPoint}/etc/system.pre_clone
	sed -e 's/^\(.*vol_rootdev_is_volume.*\)$/* COMMENTED * \1/' \
		-e 's/^\(.*rootdev:.*\)$/* COMMENTED * \1/' \
		${MntPoint}/etc/system.pre_clone >${MntPoint}/etc/system

	print "\tSetting dump device..."
	rm -f ${MntPoin}/etc/vx/.dumpadm
	SwapSlice=$(nawk '$4=="swap" { print $1; exit }' ${MntPoint}/etc/vfstab)
	#SwapSlice=${SwapSlice##*s}
	dumpadm -u -d ${SwapSlice}
		
	/usr/sbin/installboot \
		/usr/platform/`uname -i`/lib/fs/ufs/bootblk \
		/dev/rdsk/${PV_}s0

	print "\tUmounting /dev/dsk/${PV_}s0..."
	cd /
	umount ${MntPoint}
	rm -rf ${MntPoint}
}

################################################################################
# Функция конфигурирует dump device на раздел диска на котором лежит swapvol
#
# Используемые внешние переменные:
# 	Force -- Если переменная равна 0, выводятся только диагоностические сообщения,
#		 и ничего не меняется.
#		Если значение 1 -- dump переназначается в любом случае.
#		Если значение равно 2 -- dump переназначается только при
#			он не был назначен
#			он был назначен не на тот раздел
#			он был назначен на swap
#
# Возвращаемые значения:
#	0	O.K.
#	1	Ошибка инициализации дискаНекоторые тома, лежащие на диске, имеют только один плекс.
#		Никакие плексы не удалены.
#	2	Ошибка удаления плекса.
#

function SetupDump
{
#set -x
	print "Configuring dump device..."
	# Ищем subdisk'и, на которых лежит swapvol
	# В переменной DumpDev храним строчки вида
	# ИмяДиска (cXdXtXs4) СмещениеОтРаздела4 Длина
	DumpGhost=$(vxprint -g ${DGName} -se \
		"sd_pl_offset=1 && assoc.assoc=\"swapvol\"" \
		-F "%path %dev_offset %len\n")
	# dump_ghost бывает при инкапсуляции
	DumpDev=$(vxprint -g ${DGName} -se \
		"sd_pl_offset=0 && assoc.assoc=\"swapvol\" && \
		len >= assoc.assoc.len" \
		-F "%path %dev_offset %len\n")
	DumpDev="${DumpDev}\n${DumpGhost}"

	# В переменную CurDump заносим dump device
	# В переменную CurDumpDsk -- без номера раздела
	CurDump=$(nawk -F= '$1=="DUMPADM_DEVICE" { print $2 ; exit }' /etc/dumpadm.conf )
	CurDump=${CurDump##*/}
#	print "\tDump device is ${CurDump}."
	CurDumpDsk=${CurDump%s*}

	# Ищем разделы, на которые отображен swapvol
	# Пробегаем строкам переменной DumpDev
	# в SwapDevs заносим найденные разделы
	SwapDevs=""
	print "\n${DumpDev}" | awk '$0!="" { print $0 }' | \
	while read Dev Offset Len
	do
		if [[ "x${Dev}" == "x-" ]]
		then
			continue
		fi
		if (( $Offset == 1 ))
		then
			# Бывает после инкапсуляции
			Offset=0
			(( Len = Len + 1 ))
		fi
		Dev=${Dev##*/}
		Dev=${Dev%s*}
		# Считываем таблицу разделов
		VTOC=$(prtvtoc -h /dev/dsk/${Dev}s2)
		# Ищем public region и запоминаем его смещение
		PubOffset=$(print "${VTOC}" | nawk '$2=="14" { print $4 ; exit}')
		# Реальное смещение тома на диске будет таким
		(( Offset =	Offset + PubOffset ))
		# Ищем раздел swap, запоминаем его номер, смещение и длину
		set -A Swap $(print "${VTOC}" | nawk -v O=${Offset} '$2=="3" && $4==O { print $0 ; exit}')
		if [[ -n ${Swap[3]} && -n ${Swap[4]} ]]
		then
			if (( ${Swap[3]} == $Offset && ${Swap[4]} >= ${Len} ))
			then # Да, смещение совпадает, длина тоже
				SwapDevs="${SwapDevs} ${Dev}s${Swap[0]}"
			fi
		fi
	done
	SwapDevs=$(print ${SwapDevs% })
	if [[ -z ${SwapDevs} ]]
	then
		print "Warning! No suitable partition from swapvol to set as the dump device."
		return 1
	fi
#	print "\tSwap slices are ${SwapDevs}."

	DumpDiskName=$(vxprint -g ${DGName} -e "sd_path ~ /${CurDump%s*}/" -F "%disk" 2>/dev/null| head -1)

	# В цикле проверяем куда смотрит dump device
	# Переменная Slice пробегает по разделам со swap
	SliceMismatch=
	for Slice in ${SwapDevs}
	do
		SwapDsk=${Slice%s*}
		if [[ ${Slice} == ${CurDump} ]]
		then # Dump совпадает с одним из swap'ов
			print "\tDump device is already on swap slice $Slice on disk ${DumpDiskName}."
			return 0
		elif [[ ${SwapDsk} == ${CurDumpDsk} ]]
		then # Dump не совпадает с разделом swap, но находится на одном диске,
			# пора бить тревогу
			SliceMismatch=${Slice}
		fi
		done


	if [[ ${Force} == 1 || \
		( ${Force} == 2 && ( -n ${SliceMismatch} || -z ${CurDump} || ${CurDump} == swap )) ]]
	then
		DumpDiskName=$(vxprint -g rootdg -e "sd_path ~ /${SwapDevs%%s*}/" -F "%disk" | head -1)
		print "\tConfiguring slice ${SwapDevs%% *} on disk ${DumpDiskName} as dump device..."
		dumpadm -u -d /dev/dsk/${SwapDevs%% *}
		/usr/lib/vxvm/bin/vxswapctl set /dev/dsk/${SwapDevs%% *}
	elif [[ -n ${SliceMismatch} || -z ${CurDump} || ${CurDump} == swap ]]
	then # Указаний менять не было, но такая конфигурация опасна!
		print "\tWarning! Slice ${SwapDevs%% *} on disk ${DumpDiskName} should be configured as dump device manually."
		print "\tUse setupdump option."
	else # Dump лежит на отдельном диске, и указаний менять что-либо не было
		print "\tDump device configured on dedicated slice ${CurDump} on disk ${DumpDiskName}."
		print "\tIf You want to change it to ${SwapDevs%% *}, use setupdump option."
	fi
}

################################################################################
################################################################################
# Разбираем параметры командной строки и производим необходимые проверки
# Сразу делаем, что заказано
if (( $# == 0 ))
then
	Usage
fi


while (( $# > 0 ))
do	# Первый параметр должен быть ключевым словом, второй именем диска.
	# Для создания клона и dump'а имя диска указывать не обязательно,
	# в последнем случае Shift будет поставлен в 1.
	Shift=2
	print "################################################################################"
	case $1 in
		setupdump)
			Force=1
			Shift=1
			if [[ $2 == "-fake" ]]
			then
				Force=0
				shift
			fi
			SetupDump
			;;
		vtoc)
			if [[ -z $2 ]]
			then
				Usage
			fi
			Force=1
			if [[ $2 == "-fake" ]]
			then
				Force=0
				shift
			fi
			if [[ -z $2 ]]
			then
				Usage
			elif [[ -z $(vxprint -g ${DGName} -dF '%daname' "$2" 2>/dev/null) ]]
			then
				Usage
				print "Disk $2 not found in the group ${DGName}."
			else
				CreateVTOC $2 && \
				Force=2 && SetupDump
			fi
			;;
		mirror)
			if [[ -z $2 ]]
			then
				Usage
			fi
			Force=0 # В том случае, если список системных томов и
			# список томов на диске не совпадают, зеркалирование не производится.
			if [[ $2 == "-all" ]]
			then # Копируются все тома.
				Force=2
				shift
			fi
			FindRootDisk && \
			SetupDisk ${RootMirrorName} $2 && \
			AddMirror ${RootDisk} ${RootMirrorName} && \
			RemoveMirror ${RootDisk} && \
			RemoveDisk ${RootDisk} && \
			SetupDisk ${RootDiskName} ${RootDiskPV_} && \
			AddMirror ${RootMirrorName} ${RootDiskName} && \
			Force=1 && \
			CreateVTOC ${RootMirrorName} && \
			CreateVTOC ${RootDiskName} && \
			SetupDump
			;;
		addmirror)
			if [[ -z $2 ]]
			then
				Usage
			fi
			Force=0 # В том случае, если список системных томов и
			# список томов на диске не совпадают, зеркалирование не производится.
			if [[ $2 == "-all" ]]
			then # Копируются все тома.
				Force=2
				shift
			fi
			if [[ $2 == "-force" ]]
			then # Копируются только системные тома,
				# даже если на диске томов больше.
				Force=1
				shift
			fi

			DiskName=${2%=*}
			PhysDisk=${2#*=}
			FindRootDisk && \
			SetupDisk ${DiskName} ${PhysDisk} && \
			AddMirror ${RootDisk} ${DiskName} && \
			Force=1 && 	CreateVTOC ${DiskName} && \
			Force=0 && SetupDump
			;;
		removemirror)
			if [[ -z $2 ]]
			then
				Usage
			fi
			RemoveMirror $2 && \
			RemoveDisk $2 && \
			Force=0 && SetupDump
			;;
		clone)
			Force=1 # Копируются только системные тома, также force и для VTOC
			if [[ $2 == "-all" ]]
			then # Копируются все тома.
				Force=2
				shift
			fi
			print -n "Creating root's clone on the disk "
			if [[ -z $(vxprint -g ${DGName} -F"%daname" ${RootCloneName} 2>/dev/null) ]]
			then
				if [[ -z $2 ]]
				then
					Usage
				fi
				print "$2"
				SetupDisk ${RootCloneName} $2 || exit
			else
				Shift=1
				print "${RootCloneName}"
			fi
			ColVolumes ${RootCloneName}
			if [[ -n ${Volumes} ]]
			then
				print "\tUnable to continue."
				exit
			fi
			TargetLen=$(vxprint -g ${DGName} -F"%len" ${RootCloneName})
			SDLen=$(vxprint -g ${DGName} -F"%len" ${RootCloneName}-${GuardSuff} 2>/dev/null)
			SDPUtil0=$(vxprint -g ${DGName} -F"%putil0" ${RootCloneName}-${GuardSuff} 2>/dev/null)
			if [[ ${SDLen} == ${TargetLen} && "${SDPUtil0}" == "${GuardPUtil0}" ]]
			then
				vxedit -rf -g ${DGName} rm ${RootCloneName}-${GuardSuff} || exit
			fi
			FindRootDisk && \
			AddMirror ${RootDisk} ${RootCloneName} && \
			CreateVTOC ${RootCloneName} && \
			RemoveMirror ${RootCloneName} && \
			SetupClone ${RootCloneName}
			;;
		spare)
			if [[ -z $2 ]]
			then
				Usage
			fi
			print "Adding disk $2 as spare"
			SetupDisk ${RootSpareName} $2 && \
			vxedit -g ${DGName} set nohotuse=off spare=on ${RootSpareName}
			grep "COMMENTED by vxtasks.sh" /etc/init.d/vxvm-recover >/dev/null
			if (( $? != 0 ))
			then
				print "\tPatching /etc/init.d/vxvm-recover..."
				cp /etc/init.d/vxvm-recover /etc/init.d/vxvm-recover.pre_clone
				sed -e 's/^\(.*vxrelocd .*&\)$/# COMMENTED by vxtasks.sh # \1/' \
					-e 's/^\(.*vxsparecheck .*&\)$/vxsparecheck root \&/' \
					/etc/init.d/vxvm-recover.pre_clone >/etc/init.d/vxvm-recover 
			fi
			;;
		*)
			Usage
			;;
	esac
	shift ${Shift}
done
