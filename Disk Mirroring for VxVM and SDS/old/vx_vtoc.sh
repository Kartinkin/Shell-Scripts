#!/usr/bin/ksh -p
# Version	0.0
# Date		2 Nov 2001
# Author	Kirill Kartinkin

# Программа предназначена для отражения томов rootvol, swapvol, usr, opt и  var 
# из группы rootdg под Veritas Volume Manager на разделы физических дисков.
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
#
# Кроме того, в /etc/vfstab добавляются коментарии со строками для монтирования
# указанных файловых систем.
# Выполняемые действия журналируются в /var/adm/vx_vtoc.log (переменная $LogFile). 
# Старые VTOC'и записываются в /var/adm/vx_vtoc.XXX (переменная $VTOCFile).
#	
#	Для работы программы требуется пакет SUNWxcu4
#
# Параметры:
#	-F	показать, как будет переразбит диск,но ничего не менять
#	╜R	переразбить диск
# 
# Возвращаемые значения:
#	0	O.K.

################################################################################
# Описываем переменные конфигурации и производим необходимые проверки

# Имя файла с журналом
LogFile=/var/adm/vx_vtoc.log

# Путь и префикс для файлов, в которые будут записаны старые VTOC'и
# Например, в данном случае имя будет /var/adm/vx_vtoc.c0t0d0
VTOCFile=/var/adm/vx_vtoc

# Список томов, которые требуется преобразовавать в разделы
# Имя тома из группы rootdg
Volumes[0]=rootvol
# Атрибуты раздела, см. prtvtoc(1M)
Tags[0]=0x02
Flags[0]=0x00
# Строка, добавляемая в /etc/vfstab.
# Обязательно должна иметь вид '"#СтрокаИзvfstab"', см. vfstab(4).
# Имена дисков указывать как /dev/[r]dsk/${PV_}s${Slice}.
FSTab[0]='"#/dev/dsk/${PV_}s${Slice}	/dev/rdsk/${PV_}s${Slice}	/	ufs	1	no	-"'
# Раздел, на который пытаться положить том.
# Если раздел занят, том будет помещен на первый свободный после указанного,
# в связи с этим тома рекомендуется располагать в списке
# в порядке возрастания этого поля (в порядке важности).
PrefSlice[0]=0

# /var
Volumes[1]=var
Tags[1]=0x07
Flags[1]=0x00
FSTab[1]='"#/dev/dsk/${PV_}s${Slice}	/dev/rdsk/${PV_}s${Slice}	/var	ufs	1	no	-"'
PrefSlice[1]=1

# swap
Volumes[2]=swapvol
Tags[2]=0x03
Flags[2]=0x01
FSTab[2]='"#/dev/dsk/${PV_}s${Slice}		-	-	swap	-	no	-"'
PrefSlice[2]=5

# /usr
Volumes[3]=usr
Tags[3]=0x04
Flags[3]=0x00
FSTab[3]='"#/dev/dsk/${PV_}s${Slice}	/dev/rdsk/${PV_}s${Slice}	/usr	ufs	1	no	-"'
PrefSlice[3]=6

# /opt
Volumes[4]=opt
Tags[4]=0x00
Flags[4]=0x00
FSTab[4]='"#/dev/dsk/${PV_}s${Slice}	/dev/rdsk/${PV_}s${Slice}	/opt	ufs	1	no	-"'
PrefSlice[4]=7

Name=${0##*/}
PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

################################################################################
# Разбираем параметры командной строки
if (( $# == 0 ))
then
	print "Usage: ${Name} [-F|R]"
	exit 100
fi

while (( $# > 0 ))
do
	case "$1" in
		-F) Fake=1;;
		-R) Fake=0;;
        *)
			print "Usage: ${Name} [-F|R]"
			exit 100
			;;
    esac
	shift
done


################################################################################
################################################################################

# Извлекаем список SubDisk'ов, на которых могут лежать /, swap, /usr и /var.
# На случай, если какой-нибудь файловой системы нет, игнорируем ошибки.
# Сначала мы выбираем строки с описанием поддисков
#	sd	rootdisk-04	opt-01	ENABLED,
# потом из имени SubDisk'а выделяем первую часть,
# предполагая, что это и будет именем физического диска
SDs=$(vxprint -g rootdg ${Volumes[*]} 2>/dev/null | \
	nawk '$1=="sd" { print $2 }' | \
	nawk ' BEGIN { FS="-" } { print $1 }' | sort | uniq )

if [[ -z ${SDs} ]]
then
	# Что-то здесь не так...
	print "Root volumes not found."
	exit 1
fi

if (( $Fake	== 1 ))
then
	print -n "Fake r"
else
	date >> ${LogFile}
	print -n "R"
fi
print "epartionning started." | tee -a ${LogFile}
print "Logfile: ${LogFile}"

# Проходим по всем физическим дискам и 
# для каждого строим новую таблицу разбиения
for SD in ${SDs}
do
	# Сначала строим полное имя устройства,
	# у которого и обнуляем таблицу разделов,
	# с целью занести новые значения.
	
	# Находим имя физического диска
	# Переменная PV срдержит имя диска, а
	# переменная PV_ -- имя без указания раздела
	PV=$(vxprint -g rootdg ${SD} | nawk '$1=="dm" { print $3 }')
	PV_=${PV%s*}
	
	print "Processing disk ${SD} (${PV_})..." | tee -a ${LogFile}

	# Запоминаем старую таблицу
	VTOC="$(prtvtoc -h /dev/dsk/${PV})"
	# ... и записываем ее в журнал и в специальный файл
	print "Disk ${PV_}. Geometry and  partitioning:" >>${LogFile}
	print "\t(also wrote to the ${VTOCFile}.${PV_} file)" >>${LogFile}
	print "${VTOC}" | tee ${VTOCFile}.${PV_} >>${LogFile}

	# Перекраиваем таблицу, удаляя все разделы,
	# кроме 2 и разделов VxVM
	# (если мы оставим старое разбиение, не пройдет vxmksdpart).
	if (( $Fake	== 0 ))
	then
		# Естественно, делаем это только в реальной жизни
		print "${VTOC}" | \
			nawk '$2!=5 && $2!=14 && $2!=15 { print "\t"$1"\t0\t00\t0\t0\t0" ; continue }
	        	{ print $0 }' | \
	   	    fmthard -s - /dev/rdsk/${PV} >>${LogFile} 2>&1
	fi
	# Получаем список занятых разделов.
	BusySlices=$(print "${VTOC}" | \
		nawk '$2==5 || $2==14 || $2==15 { print $1 }')
	# Удаляем переводы строки
	BusySlices=$(print ${BusySlices})
	print "\tUsed slices: ${BusySlices}." | tee -a ${LogFile}
	# Лежащие на этом диске тома отображаются в разделы диска
	# Переменная i пробегает по элементам массивов с описаниями томов
	i=0
	# В переменной BusySlices храним список занятых разделов,
	# пополняем его по мере продвижения.
	for Volume in ${Volumes[*]}
	do
		# Ищем пустой раздел, добавляем его в список занятых
		# после чего отображаем на него том
		
		# Проверяем, можно ли положить на PrefSlice
		if [[ "${BusySlices}" == "${BusySlices#*${PrefSlice[$i]}}" ]]
		then
			# Да, PrefSlice свободен
			# Раздел найден
			Slice=${PrefSlice[$i]}
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
				print "Unnable to map volume ${Volume}." | tee -a ${LogFile}
				print "Free slice on disk ${PV_} not found." | tee -a ${LogFile}
				continue
			fi
		fi
		# Извлекаем имя поддиска, на котором лежит логический том.
		# Т.к. их может быть много, ищем по имени. 
		VolSD=$(vxprint -g rootdg ${Volume} 2>>${LogFile} | \
			nawk '$1=="sd" &&  $NF!~"Block" { print $2 }' | \
			nawk -v S=${SD} ' BEGIN { FS="-" } $1==S { print $1"-"$2 }')
		# Если том лежит на этом диске,
		if [[ -n ${VolSD} ]]
		then
			# отображаем на раздел
			print "\tMapping volume ${Volume} to ${PV_}s${Slice}..." \
				| tee -a ${LogFile}
			
			if (( $Fake	== 0 ))
			then
				# Том отображается на раздел ...
				vxmksdpart -g rootdg ${VolSD} ${Slice} ${Tags[$i]} ${Flags[$i]} | \
					>>${LogFile} 2>&1
				# ...и в /etc/vfstab добавляется строка для аварийного монтирования ФС
				eval Str="${FSTab[$i]}"
				print "${Str}" >>/etc/vfstab
			else
				print "\t\t"vxmksdpart -g rootdg ${VolSD} ${Slice} ${Tags[$i]} ${Flags[$i]}
			fi
		fi
		(( i = i + 1 ))
		# Увеличиваем i и переходим к следующему тому
	done
	if (( $Fake	== 0 ))
	then
		# Создаем красивое разбиение в файле /etc/vfstab
		print "\n" >>/etc/vfstab
	fi
done
