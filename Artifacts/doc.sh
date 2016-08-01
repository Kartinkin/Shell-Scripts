#!/usr/xpg4/bin/sh
# Version	0.0
# Date		2 Nov 2001
# Author	Kirill Kartinkin


Name=${0##*/}
PATH=/usr/xpg4/bin:/usr/bin:/usr/sbin:/usr/local/bin

set -A Hex 0 1 2 3 4 5 6 7 8 9 a b c d e f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f 40 41 42 43 44 45 46 47 48 49 4a 4b 4c 4d 4e 4f 50 51 52 53 54 55 56 57 58 59 5a 5b 5c 5d 5e 5f 60 61 62 63 64 65 66 67 68 69 6a 6b 6c 6d 6e 6f 70 71 72 73 74 75 76 77 78 79 7a 7b 7c 7d 7e 7f

if (( $# != 1 ))
then
	print "Usage ${Name} explorer_dir"
	exit 101
fi

ExpDir=$1

if [[ ! -d ${ExpDir} ]]
then
	print "Directory ${ExpDir} not found."
	exit 1
fi

cd ${ExpDir}
HostName=$(awk '$1=="Hostname:" { print $2 ; exit}' README)
SystemType=$(grep "System Type: " README | awk ' { print $NF}')

# Создаем список контролеров в самом начале, чтобы правильно писать потом пути
DiskControllers=$(awk '{ print $(NF-2)" "$NF }' disks/ls-l_dev_rdsk.out | grep -v total | \
	awk -Ft '$1!=Prev { print ; Prev=$1 }' | \
	while read Co Path
	do
		Co=${Co%t*}
		Path=${Path%/*}
		Path=${Path##*..}
		Path=${Path#*/}
		print "$Co /${Path#*/}"
	done | sort | uniq )

if [[ -d ssp ]]
then
	print "Глава Х Конфигурация Sun Enterprise 10000"
	grep "Information was gathered on" README | sed -e 's/Information was gathered on/Информация приводится по состоянию на/'

	print "Имя ssp: ${HostName}"
	Domains=$(awk -F: '{ print $1 }' ssp/domain_config)
	print "Домены: "${Domains}

	print "\nРаздел Х.1 Аппаратная часть"
	
	awk '$1=="Interconnect:" { print "\nЧастота шины: "$2" МГц" ; exit }' ssp/sys_clock.out
	awk '$1=="JTAG:" { print "Частота JTAG: "$2" МГц" ; exit }' ssp/sys_clock.out

	print "\nТаблица Х.1.1 Образующие компоненты"
	print "Слот\tНазвание\tP/N\tS/N\tСостояние"
	awk '/Support/, /^$/ { if ( NF!=0 && $1!="Support" && $1!~"--" ) { print $1"\t"$2 } }' ssp/hostinfo/hostinfo-p.out | \
		sed -e 's/on/включена/' | \
	while read Slot Other
	do
		print "\tCenterplane\t$(awk '{ print $4"\t"$NF ; exit }' ssp/board_id/board_id-bcp_${Slot}.out)"
		print "CSB${Slot}\tCenterplane Support Board\t$(awk '{ print $4"\t"$NF ; exit }' \
			ssp/board_id/board_id-bcsb_${Slot}.out)\t${Other}"
	done

	print "\nТаблица Х.1.2 Управляющие платы"
	print "Слот\tВерсия\tP/N\tS/N\tСостояние"
	awk '/Control/, /^$/ { if ( NF!=0 && $1!="Control" && $1!~"--" ) { print $1" "$2 } }' ssp/hostinfo/hostinfo-p.out | \
		sed -e 's/on/включена/' | \
	while read Slot Power
	do
		print "CB${Slot}\t$(awk -v S=${Slot} 'Prev=="cboard"S { print $NF ; exit }
			{ Prev=$NF }' ssp/cb_prom-r.out)\t$(awk '{ print $4"\t"$NF ; exit }' \
			ssp/board_id/board_id-bcb_${Slot}.out)\t${Power}"
	done

	print "\nТаблица Х.1.3 Системные платы"
	print "Слот\tНазвание\tP/N\tS/N\tСостояние"
	awk '/System/, /^$/ { if ( NF!=0 && $1!="System" && $1!~"--" ) { print $1"\t"$2 } }' ssp/hostinfo/hostinfo-p.out | \
		sed -e 's/on/включена/' | \
	while read Slot Other
	do
		print "SB${Slot}\tСистемная плата\t$(awk '{ print $4"\t"$NF ; exit }' \
			ssp/board_id/board_id-bsb_${Slot}.out)\t${Other}"
		if [[ -f ssp/board_id/board_id-bio_${Slot}.out ]]
		then
			print "\tПлата ввода/вывода (шина $(awk '$4~"501-4478" { print "Sbus)\t"$4"\t"$NF ; exit }
				$4~"501-4830" || $4~"501-4777" || $4~"501-4778" { print "PCI)\t"$4"\t"$NF ; exit }
				{ print "неизвестна)\t"$4"\t"$NF ; exit }' \
				ssp/board_id/board_id-bio_${Slot}.out)"
		fi
		if [[ -f ssp/board_id/board_id-bmem_${Slot}.out ]]
		then
			print "\tПлата памяти\t$(awk '{ print $4"\t"$NF ; exit }' ssp/board_id/board_id-bmem_${Slot}.out)"
		fi
	done

	print "\nТаблица Х.1.4 Вентиляторы"
	print "Слот\tСостояние"
	awk '/Fan/, /^$/ { if ( NF!=0 && $1!="Fan" && $1!~"--" ) { print "FT"$1"\t"$2 } }' ssp/hostinfo/hostinfo-p.out | \
		sed -e 's/on/работает/'

	print "\nТаблица Х.1.5 Блоки питания"
	print "Слот\tСостояние"
	awk '/Bulk/, /^$/ { if ( NF!=0 && $1!="Bulk" && $1!~"--" ) { print "PS"$1"\t"$2 } }' ssp/hostinfo/hostinfo-p.out | \
		sed -e 's/ok/работает/'

	print "\nТаблица Х.1.6 Разбиение на домены"
	print "Домен\tПлаты"
	awk -F: '{ print $1"\t"$NF }' ssp/domain_config

	print
fi

function PrintPCI
{
	#awk -F^ '$NF==$(NF-1) { print $1"\t"$2 ; break }
	#	{ print }' |
	grep -iv "pci-bridge" | uniq | \
	while read Slot Card
	do
		if (( ${Slot} >= $1))
		then
			print "на плате\t${Card}"
		else
			print "${Slot}\t${Card}"
		fi
#		print "${Slot} S1=${P1[$Slot]} S2=${P2[$Slot]}"
#                        /pci@1f,4000/SUNW,ifp@4 c1
#                        /pci@1f,4000/network@1,1        hme0
#                        /pci@1f,4000/pci@5/SUNW,qfe@0,1 qfe0
#                        /pci@1f,4000/pci@5/SUNW,qfe@1,1 qfe1
#                        /pci@1f,4000/pci@5/SUNW,qfe@2,1 qfe2
#                        /pci@1f,4000/pci@5/SUNW,qfe@3,1 qfe3
#                        /pci@1f,4000/scsi@3     c0
#                        /pci@1f,4000/scsi@3,1   glm1

		Out=$(awk -v S1=${P1[$Slot]} -v S2=${P2[$Slot]} -F/ \
			'NF==3 && $NF!~"pci_pci" && $2~"pci@"S1 && $3~"@"S2 { print $0 ; break }
			NF==4 && $2~"pci@"S1 && $3~"pci@"S2 { print $0 }
			NF==4 && $2~"ssm@" && $3~"pci@"S1 && $4~"@"S2 && $4!~"pci" { print $0 }
			NF==5 && $3~"pci@"S1 && $4~"pci@" && $5~"@"S2 { print $0 }' \
			etc/path_to_inst | sed -e 's/"//g' | grep -v ebus | sort | uniq | \
			awk '{ print " "$1" "$3" "$2 }' )
		if [[ -z ${Out} ]]
		then
			print "\t\t\tНичего не подключено (/pci@${P1[$Slot]}/<driver>@${P2[$Slot]})"
		else
			print "${Out}" | \
			while read Path Drv No
			do
				Co=$(print "${DiskControllers}" | awk -v P=${Path} '$2~"^"P { print $1; exit }')
				if [[ -n ${Co} ]]
				then
					print "\t\t\t${Path}\t${Co}"
				else
					print "\t\t\t${Path}\t${Drv}${No}"
				fi
			done
		fi
	done
	print "Примечание. Для сетевых карт логический путь это имя интерфейса, для дисковых контроллеров -- имя контроллера, для всех остальных карт -- имя драйвера."
}

print "Глава Х Сервер ${HostName}"
grep "Information was gathered on" README | sed -e 's/Information was gathered on/Информация приводится по состоянию на/'
print "Имя сервера: ${HostName}"
print "S/N: $(grep "System Serial number:" README | awk ' { print $NF}')"
print "Hostid: $(awk '$1=="Hostid:" { print $2 ; exit}' README)"
print "\nПодключенные устройства\nИмя\tМодель\tS/N"
print "\nРисунок Х.1 Размещение оборудования в стойках"

print "\nРаздел Х.1 Аппаратная часть"
print -n "Тип системы: (${SystemType}) Sun "

case ${SystemType} in
"SUNW,Ultra-Enterprise-10000")
	SystemModel=10000
	print "Enterprise ${SystemModel}"

	Boards=$(awk '/^---  ----  ----  ----  --------------------------------  ----------------------/,	/^$/ { print $1 }
		/^---  ---  -------  -----  ------  ------  ----/, /^$/ { print $1}
		$1=="Board" { print $2 }' sysconfig/prtdiag-v.out | \
		grep -v "\-\-\-" | sort | uniq)
	print "\nВ домен входят платы "${Boards}

	print "\nТаблица Х.1.1 Процессоры"
	print "Плата\tМодуль (Номер)\tПроцессор\tЧастота\tКэш"
	awk '/^---  ---  -------  -----  ------  ------  ----/, 
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1" "$3" "$6"\t"$4" МГц\t"$5" Мб" } }' \
		sysconfig/prtdiag-v.out | sed -e "s/US/UltraSPARC/" | \
	while read Board Slot Other
	do
		integer No
		(( No = Board * 4 + Slot ))
		print "${Board}\t${Slot} (${Hex[$No]})\t${Other}"
	done

	print "\nТаблица Х.1.3 Модули памяти"
	print "Плата\tБанк\tМодули"
	awk '/^           -----   -----   -----   -----/,
		/^$/ { print $2"\t0\t8x"$3/8" Мб\n\t"$2"\t1\t8x"$4/8" Мб\n\t"$2"\t2\t8x"$5/8" Мб\n\t"$2"\t3\t8x"$6/8" Мб" }' \
		sysconfig/prtdiag-v.out | \
		grep -v "8x0"

	print "\nТаблица Х.1.4 Карты ввода/вывода"
	print "Плата\tСлот\tКарта\tАппаратный путь\tЛогический путь"

	awk '/---  ----  ----  ----  --------------------------------  ----------------------/,
		/^$/ { if ( NF>0 && $1!~"---" ) { print $1" "$4" "$5" ("$NF")" } }' sysconfig/prtdiag-v.out | \
		uniq | \
	while read Brd Slot Card
	do
		print "${Brd}\t${Slot}\t${Card}"
		(( S1 = Brd * 2 ))
		(( S2 = Brd * 2 + 1))
		awk -v S1=${Hex[$((64+Brd*4))]} -v S2=${Hex[$((65+Brd*4))]} -v S3=${Hex[$Slot]} -F/ \
			'NF==3 && ( $2~"sbus@"S1 || $2~"sbus@"S2 ) && $3~"@"S3 { print $0 }' \
			etc/path_to_inst | grep -v sbusmem | sed -e 's/"//g' | sort | uniq | \
		while read Path No Drv
		do
			if [[ -n $(print "${Card}" | grep ${Drv}) ]]
			then
				Co=$(print "${DiskControllers}" | awk -v P=${Path} '$2~"^"P { print $1; exit }')
				if [[ -n ${Co} ]]
				then
					print "\t\t\t${Path}\t${Co}"
				else
					print "\t\t\t${Path}\t${Drv}${No}"
				fi
			fi
		done | sort
	done
	print "Примечание. Для сетевых карт логический путь это имя интерфейса, для дисковых контроллеров -- имя контроллера, для всех остальных карт -- имя драйвера."
;;


"SUNW,Ultra-Enterprise")
	SystemModel=$(awk '{ print $NF ; exit }' sysconfig/prtdiag-v.out)
	print "Enterprise ${SystemModel}"
	print "\nТаблица Х.1.1 Платы"
	print "Слот\tТип платы\tЧастота\tВерсия OpenBoot"
	awk '/^---  ---  --  -----  -----  ----  ----  ----  ----------      ----------/, 
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1" "$(NF-2)"\t"$(NF-1) } }' sysconfig/prtdiag-v.out | \
		sed -e "s/Unknown/Disk/" | sed -e "s/CPU/CPU\/Memory/g" | \
	while read Brd Others
	do
		print "${Brd}\t${Others}\t$(awk -v N=${Brd} '/^Board/ , /^$/ { if ( $2==N":" ) { print $3"="$4","$7"="$8 } }' sysconfig/prtdiag-v.out)"
	done

	print "\nТаблица Х.1.2 Процессоры"
	print "Плата\tМодуль (Номер)\tПроцессор\tЧастота\tКэш"
	awk '/^---  ---  -------  -----  ------  ------  ----/, 
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1"\t"$3" ("$2")\t"$6"\t"$4" МГц\t"$5" Мб" } }' \
		sysconfig/prtdiag-v.out | \
		sed -e "s/US/UltraSPARC/"

	print "\nТаблица Х.1.3 Модули памяти"
	print "Плата\tБанк\tМодули\tСкорость\tРасслоение"
	awk '/^---  -----  ----  -------  ----------  -----  -------  -------/,
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1"\t"$2"\t8x"$3/8" Мб\t"$6"\t"$7","$8 } }' \
		sysconfig/prtdiag-v.out

	print "\nТаблица Х.1.4 Карты ввода/вывода"
	print "Плата\tСлот\tКарта\tАппаратный путь\tЛогический путь"

	awk '/---  ----  ----  ----  --------------------------------  ----------------------/,
		/^$/ { if ( NF>0 && $1!~"--" ) { print $1" "$4" "$5" ("$NF")" } }' sysconfig/prtdiag-v.out | \
		uniq | \
	while read Brd Slot Card
	do
		print "${Brd}\t${Slot}\t${Card}"
		(( S1 = Brd * 2 ))
		(( S2 = Brd * 2 + 1))
		awk -v S1=${Hex[$((Brd*2))]} -v S2=${Hex[$((Brd*2+1))]} -v S3=${Hex[$Slot]} -F/ \
			'NF==3 && ( $2~"sbus@"S1 || $2~"sbus@"S2 ) && $3~"@"S3 { print $0 }' \
			etc/path_to_inst | grep -v sbusmem | sed -e 's/"//g' | sort | uniq | \
		while read Path No Drv
		do
			if [[ -n $(print "${Card}" | grep ${Drv}) ]]
			then
				Co=$(print "${DiskControllers}" | awk -v P=${Path} '$2~"^"P { print $1; exit }')
				if [[ -n ${Co} ]]
				then
					print "\t\t\t${Path}\t${Co}"
				else
					print "\t\t\t${Path}\t${Drv}${No}"
				fi
			fi
		done
	done
	print "Примечание. Для сетевых карт логический путь это имя интерфейса, для дисковых контроллеров -- имя контроллера, для всех остальных карт -- имя драйвера."

	print "\nТаблица Х.1.5 Блоки питания и вентиляторы"
	print "Слот\tБлок"
	awk '/^---------                     ------/,
		/^$/ { if ( NF==2 && $1!="---------" ) { 
			if ( $1=="PPS" ) { print "PPS\tПериферийный блок питания" } 
			else { print $1"\tБлок питания и вентиляции" } } }' \
		sysconfig/prtdiag-v.out

	Out=$(awk '/  ----  ---------   ------         -----------------------------------------/,
		/^$/ { if ( $3=="disk") { print $1"\t"$5"\t"$7"\n\t"$1"\t"$9"\t"$11 } }' \
		sysconfig/prtdiag-v.out | sed -e 's/://')
	if [[ -n ${Out} ]]
	then
		print "\nТаблица Х.1.6 Дисковые платы"
		print "Слот\tПозиция\tSCSI Id\n${Out}"
	fi
;;


"SUNW,Ultra-4"|"SUNW,Ultra-250"|"SUNW,Ultra-80"|"SUNW,Ultra-60")
	if [[ ${SystemType} == "SUNW,Ultra-250" ]]
	then
		SystemModel=250
	else
		SystemModel=$(awk '{ print $8 ; exit }' sysconfig/prtdiag-v.out)
	fi
	print "Enterprise ${SystemModel}"

	grep OBP sysconfig/prtdiag-v.out | \
		awk '{ print "Версия OBP: "$2", POST: "$5 }'
		
	print "\nТаблица Х.1.1 Процессоры"
	print "Слот (Номер)\tПроцессор\tЧастота\tКэш"
	awk '/^---  ---  -------  -----  ------  ------  ----/, 
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $3" ("$2")\t"$6"\t"$4" МГц\t"$5" Мб" } }' \
		sysconfig/prtdiag-v.out | \
		sed -e "s/US/UltraSPARC/"

	Out=$(awk '/^----    -----    ------   ----  ------/,
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1"\t4x"$4"\t"$2 } }' sysconfig/prtdiag-v.out | \
		sort | uniq )
	if [[ -z ${Out} ]]
	then
		awk '/Memory size:/, /Memory size:/ { print "\nОбъем памяти: "$3" Мб"; exit}' sysconfig/prtdiag-v.out
	else
		print "\nТаблица Х.1.2 Модули памяти"
		print "Банк\tМодули\tРасслоение"
		print "${Out}"
	fi

	awk '/Memory Interleave Factor/, /Memory Interleave Factor/ { print "Расслоение: "$5; exit}' \
		sysconfig/prtdiag-v.out

	print "\nТаблица Х.1.4 Карты ввода/вывода"
	print "Слот\tЧастота\tКарта\tАппаратный путь\tЛогический путь"

	case ${SystemModel} in
		"450")
			set -A P1 x 6,4000  6,4000 6,4000 6,2000 1f,2000 4,2000 4,4000 4,4000 4,4000 1f,4000 1f,4000 1f,4000 1f,4000
			set -A P2 x 4       3      2      1      1       1      4      3      2      4       1       2       3
			;;
		"420R")
			set -A P1 1f,2000 1f,4000 1f,4000 1f,4000 x x x x x x x 1f,4000 1f,4000
			set -A P2 1       4       2       5       x x x x x x x 1       3
			;;
		"250")
			set -A P1 1f,4000 1f,4000 1f,4000 1f,2000 x x x x x x x 1f,4000 1f,4000
			set -A P2 5       4       2       1       x x x x x x x 1       3
			;;
		"220R")
			set -A  P1 1f,2000 1f,4000 1f,4000 1f,4000 1f,4000 x x x x x x 1f,4000 1f,4000
			set -A  P2 1       2       4       5       4       x x x x x x 1       3
			;;
	esac

	(print "11 33 МГц\thme"
	print "12 33 МГц\tSymbios 53C875"
	if [[ ${SystemType} == "SUNW,Ultra-4" ]]
	then
		print "13 33 МГц\tSymbios 53C875"
	fi
	awk '/---  ----  ----  ----  --------------------------------  ----------------------/,
		/^$/ { if ( NF>0 && $1!~"--" ) { print $4" "$3" МГц\t"$5"\t"$NF } }' sysconfig/prtdiag-v.out | \
	awk '$3~"pciclass" && $4!="" { print $1" "$2"\t"$4 ; break }
		{ print $0 }' | sort | uniq | \
	awk '$3~"pciclass" && $1 == Prev { break }
		{ print ; Prev=$1 } ' ) | \
	PrintPCI 11 | \
	awk 'BEGIN { P="" ; i=0 }
		$NF~"<driver>" && ( C=="SUNW,pci-qfe" || ( S=="1" && C=="network-SUNW,hme" ) ) { break }
		$NF!~"scsi" && ( S=="3" && C=="Symbios,53C875" ) { i=1 ; break }
		NF==2 && i==1 { break }
		NF==2 { if  ( P!="" ) { print P } ; print $0 ; P="" ; i=0 ; break }
		{ P=$0 ; S=$1 ; C=$NF }'

#1       33 МГц  network-SUNW,hme        network-SUNW,hme
#                        Ничего не подключено (/pci@1f,4000/<driver>@4)
#1       33 МГц  SUNW,qfe-pci108e,1001   SUNW,pci-qfe
#                        Ничего не подключено (/pci@1f,4000/<driver>@4)
#		3       33 МГц  SUNW,qfe-pci108e,1001   SUNW,pci-qfe
#                        Ничего не подключено (/pci@1f,4000/<driver>@5)
#3       33 МГц  scsi-glm/disk   Symbios,53C875
#                        Ничего не подключено (/pci@1f,4000/<driver>@5)


	Out=$(awk '/^------     ------    ----    ------/,
		/^$/ { if ( NF==5 ) { print $1"\t"$2" W" } }' \
		sysconfig/prtdiag-v.out)
	if [[ -n "${Out}" ]]
	then
		print "\nТаблица Х.1.5 Блоки питания и вентиляторы"
		print "Слот\tМощность\n${Out}"
	fi
;;


"SUNW,Ultra-5_10"|"SUNW,UltraAX-i2"|"SUNW,UltraSPARC-IIi-cEngine")

	if [[ ${SystemType} == "SUNW,Ultra-5_10" ]]
	then
		SystemModel="5/10"
		print "Ultra ${SystemModel}"
		grep OBP sysconfig/prtdiag-v.out | awk '{ print "Версия OBP: "$2", POST: "$6 }'
	else
		SystemModel=$(awk '{ print $(NF-2) ; exit }' sysconfig/prtdiag-v.out)
		print "Netra ${SystemModel}"
		grep CORE sysconfig/prtdiag-v.out | awk '{ print "Версия CORE: "$2 }'
	fi

	awk '/^---  ---  -------  -----  ------  ------  ----/, 
		/^$/ { print "Процессор: UltraSPARC IIi " $4" МГц, кэш "$5" Мб" }' \
		sysconfig/prtdiag-v.out | awk 'NR==2 { print ; exit }'
	awk '/Memory size:/, /Memory size:/ { print "Объем памяти: "$3" Мб"; exit}' sysconfig/prtdiag-v.out

	print "\nТаблица Х.1.1 Карты ввода/вывода"
	print "Слот\tЧастота\tКарта\tАппаратный путь\tЛогический путь"
	awk '/---  ----  ----  ----  --------------------------------  ----------------------/,
		/^$/ { if ( NF>0 && $1!~"--") { print $2" "$4" "$3" МГц\t"$5"\t"$NF } }' sysconfig/prtdiag-v.out | \
		sort | uniq | grep -v ebus | \
	while read Bus Slot Card
	do
		if [[ ${Bus} == "PCI-1" || ${SystemType} == "SUNW,UltraAX-i2" || \
			( ${SystemModel} == "t1" && \
			${Slot} != 1 && ${Slot} != 2 && ${Slot} != 3 && ${Slot} != 14 ) ]]
		then
			print "на плате\t${Card}"
		else
			print "${Slot}\t${Card}"
		fi
		Out=$(awk -v B=${Bus} -v S=${Hex[${Slot}]} -F/ \
			'NF==4 && ( B=="PCI-1" || B=="PCI" ) && $3~"pci@1,1" && $4~"@"S { print $0 ; break }
			NF==5 && ( B=="PCI-2" || B=="PCI" ) && $4~"pci@1" && ( $5~"@"S || $5~S"\"" ) { print $0 ; break }
			NF==3 && B=="PCI" && $3~"@"S && $3!~"pci" { print $0 ; break }' \
			etc/path_to_inst | sed -e 's/"//g' | grep -v ebus | sort | uniq | \
			awk '{ print "\t\t\t"$1"\t"$3$2 }' )
		if [[ -z ${Out} ]]
		then
			print "\t\t\t/pci@1f,0/pci@1/pci@1/<driver>@${Slot}"
		else
			print "${Out}" | \
			while read Path No Drv
			do
				Co=$(print "${DiskControllers}" | awk -v P=${Path} '$2~"^"P { print $1; exit }')
				if [[ -n ${Co} ]]
				then
					print "\t\t\t${Path}\t${Co}"
				else
					print "\t\t\t${Path}\t${Drv}${No}"
				fi
			done
		fi
	done
	print "Примечание. Для сетевых карт логический путь это имя интерфейса, для дисковых контроллеров -- имя контроллера, для всех остальных карт -- имя драйвера."
;;


"SUNW,Sun-Fire")
	SystemModel=$(awk '{ print $NF ; exit }' sysconfig/prtdiag-v.out)
	print "Fire ${SystemModel}"

	grep OBP sysconfig/prtdiag-v.out | awk '{ print "Версия OBP: "$2 }'

	print "\nПлаты в данном домене: "$(awk '/^--------  -----  -----  -------  -------$/,
		/^$/ { if ( NF!=0 && $1!~"---" ) { print $1 } }' sysconfig/prtdiag-v.out | \
		awk -F/ '{ print $3 }')

	print "\nТаблица Х.1.1 Процессоры"
	print "Плата\tСлот (Номер)\tПроцессор\tЧастота\tКэш"
 	awk '/^----------  ----  ----  ----  -------  ----$/, 
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1"/ ("$2")\t"$5"\t"$3" МГц\t"$4" Мб" } }' \
		sysconfig/prtdiag-v.out | sed -e 's/P//' | awk -F/ '{ print $3"\t"$4$5 }' | \
		sed -e 's/US/UltraSPARC/' | sort

	print "\nТаблица Х.1.2 Модули памяти"
	print "Плата\tБанк\tМодули\tРасслоение"
	awk '/^-------------  ----  ----     ------   -----------  ------  ----------  ----------$/,
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1"/4x"$6" Мб\t"$7 } }' sysconfig/prtdiag-v.out | \
		sed -e 's/MB//' | sort | awk -F/ '{ print $3"\t"$4"\t"$6 }' | uniq

	print "\nТаблица Х.1.3 Карты ввода/вывода"
	print "Плата\tТип\tСлот\tЧастота\tКарта\tАппаратный путь\tЛогический путь"
	Out=$(awk '/^----------  ---- ---- ---- ---- ---- ---- ---- ----- --------------------------------/,
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1" "$3" "$8" "$2"\t"$5"\t"$6" МГц\t"$10"\t"$NF } }' sysconfig/prtdiag-v.out )

	i=0
	print "${Out}" | while read Board Port Dev Other
	do
		P1[$i]="${Hex[$Port]},"
		P2[$i]="${Dev%,0}"
		(( i = i + 1 ))
	done
	i=0
	print "${Out}" | while read Board Port Dev Other
	do
		Board=${Board#*0/}
		print "$i !${Board%/*}\t${Other}"
		(( i = i + 1 ))
	done | PrintPCI 100 | awk -F! '{ print $NF }'
	print "Примечание. Для сетевых карт логический путь это имя интерфейса, для дисковых контроллеров -- имя контроллера, для всех остальных карт -- имя драйвера."
exit
;;


"SUNW,Sun-Fire-280R"|"SUNW,Sun-Fire-480R"|"SUNW,Sun-Fire-880")
	if [[ ${SystemType} == "SUNW,Sun-Fire-280R" ]]
	then
		SystemModel=$(awk '{ print $(NF-3) ; exit }' sysconfig/prtdiag-v.out)
	else
		SystemModel=$(awk '{ print $NF ; exit }' sysconfig/prtdiag-v.out)
	fi
	print "Fire ${SystemModel}"

	grep OBP sysconfig/prtdiag-v.out | awk '{ print "Версия OBP: "$2 }'
		
	print "\nТаблица Х.1.1 Процессоры"
	print "Плата\tНомер\tПроцессор\tЧастота\tКэш"
 	awk '/---  ----  -------  ----/, 
		/^$/ { if ( NF!=0 && $1!~"--" ) { print $1"\t"$2"\t"$5"\t"$3" МГц\t"$4" Мб" } }' \
		sysconfig/prtdiag-v.out | \
		sed -e 's/US/UltraSPARC/' | sort

	print "\nТаблица Х.1.2 Модули памяти"
	print "Плата\tБанк\tМодули\tРасслоение"
	awk '/---  ---  ----     ------   -----------  ------  ----------  -----------/,
		/^$/ { if ( NF!=0 ) { print $0 } }' sysconfig/prtdiag-v.out | sed -e 's/MB//' | \
		awk	'BEGIN { i=0 }
			NR==1 { continue }
			i==0 && $1=="CA" { print "\t?\t4x"$4/2" Мб\t"$7 ; i=1 ; break }
			i==0 { print $1"\t?\t8x"$4/2" Мб\t"$7 ; i=1 ; break }
			i==3 { i=0 ; break }
			{ i=i+1 }'
		
	print "\nТаблица Х.1.3 Карты ввода/вывода"
	print "Слот\tЧастота\tКарта\tАппаратный путь\tЛогический путь"

	case ${SystemType} in
	"SUNW,Sun-Fire-280R")
		set -A P1 x 8,600000 8,700000 8,700000 8,700000 x x x x 8,700000 8,700000 8,600000 8,700000
		set -A P2 x 1        3        2        1        x x x x 5,1      6        4        5,3
		;;
	"SUNW,Sun-Fire-480R")
		set -A P1 8,600000 8,600000 8,700000 8,700000 8,700000 8,700000 x x x 8,700000 9,600000 9,600000 9,700000 9,700000
		set -A P2 1        2        2        3        4        5        x x x 6        1        2        1,3      2
		;;
	"SUNW,Sun-Fire-880")
		set -A P1 8,700000 8,700000 8,700000 8,700000 9,700000 9,700000 9,700000 9,600000 9,600000 8,700000 8,600000 8,600000 9,700000 9,700000
		set -A P2 5        4        3        2        4        3        2        2        1        1        2        1        1,1      1,3
		;;
	esac
	case ${SystemType} in
	"SUNW,Sun-Fire-280R")
		print "9 33 МГц\tRIO network"
		print "10 33 МГц\tSCSI"
		print "11 33 МГц\tFC-AL"
		print "12 33 МГц\tUSB"
		;;
	"SUNW,Sun-Fire-480R")
		print "9 33 МГц\tIDE"
		print "10 66 МГц\tCassini network"
		print "11 66 МГц\tFC-AL"
		print "12 33 МГц\tUSB"
		print "13 33 МГц\tCassini network"
		awk '$1=="PCI" { print $4" "$5" МГц\t"$9"\t"$NF }' sysconfig/prtdiag-v.out
		;;
	"SUNW,Sun-Fire-880")
		print "9 33 МГц\tSCSI"
		print "10 66 МГц\tFC-AL"
		print "11 66 МГц\tGEM"
		print "12 33 МГц\tRIO network"
		print "13 33 МГц\tUSB"
		awk '$1=="I/O" { print $5" "$6" МГц\t"$10"\t"$NF }' sysconfig/prtdiag-v.out
		;;
	esac | PrintPCI 9

	Other=$(awk '$1~"^PS" { print $1 }' sysconfig/prtdiag-v.out )
	print "\nБлоки питания: "${Other}
;;

*)
	print "неизвестной конструкции"
	cat sysconfig/prtdiag-v.out
;;
esac

print "\nТаблица Х.1.Х Параметры eeprom"
print "Параметр\tЗначение"
cat sysconfig/eeprom.out | grep -v "data not available" | sed -e 's/=/	/'

print "\nРаздел Х.2 Дисковая подсистема"
print "\nРисунок Х.2.1 Подключения дисковых массивов"
print "\tСхема подключения, с указанием портов"

print "\nТаблица Х.2.1 Дисковые контроллеры" 
print "Логическое имя\tАппаратный путь"
print "${DiskControllers}"

print "\nНе забывать про двойные пути! Проверять наличие двойных путей."
print "При обнаружении двойных путей из двух таблиц делать одну, указывать оба подкдючения (\"подключен к...\"), в логическом пути писать c[XY]tZd."

integer Tab=2
integer Pun=2

function PrintD1000
{
	print "\nПункт Х.2.${Pun} Дисковый массив D1000 <Имя>"
	(( Pun = Pun + 1 ))
	if [[	$(print "${Out}" | grep "t[89]d0" |wc -l ) == "       2" ]]
	then
		print -n "Порт A"
	elif [[	$(print "${Out}" | grep "t[01]d0" |wc -l ) == "       2" ]]
	then
		print -n "Порт B"
	fi
	print " подключен к ${Path}."
	print "Таблица Х.2.${Tab} Дисковый массив <Имя>"
	(( Tab = Tab + 1 ))
	print "Слот\tДиск\tВерсия FW\tСерийный номер\tАппаратный путь\tЛогический путь"
    #            0 1 2 3 4 5 6 7 8 9 10 11 12 13
	set -A Slots 0 1 2 3 4 5 x x 6 7 8  9  10 11
	print "${Out}" | while read HWPath LPath Model FW SN
	do
		Slot=${LPath#*t}
		Slot=${Slot%d*}
		print "${Slots[$Slot]} (${Slot})\t${Model}\t${FW}\t${SN}\t${HWPath}\t${LPath}"
	done 

	print "\nТаблица Х.2.${Tab} Дисковый массив D1000 <Имя>. Блоки питания, вентиляторы"
	print "Слот\tНазвание\nЛевый\tБлок питания\nПравый\tБлок питания\nЛевый\tБлок вентиляторов\nПравый\tБлок вентиляторов"
	(( Tab = Tab + 1 ))
}

function Print450
{
	print "\nПункт Х.2.${Pun} Внутренние диски"
	(( Pun = Pun + 1 ))
	print "Подключены к ${Path}."
	(( Tab = Tab + 1 ))
	print "Таблица Х.2.${Tab} Внутренние диски"
	print "Слот\tДиск\tВерсия FW\tСерийный номер\tАппаратный путь\tЛогический путь"
	print "${Out}" | while read HWPath LPath Model FW SN
	do
		Slot=${LPath#*t}
		print "${Slot%d*}\t${Model}\t${FW}\t${SN}\t${HWPath}\t${LPath}"
	done 
}

function Print250
{
	print "\nПункт Х.2.${Pun} Внутренние диски"
	(( Pun = Pun + 1 ))
	print "Подключены к ${Path}."
	print "Таблица Х.2.${Tab} Внутренние диски"
	(( Tab = Tab + 1 ))
	print "Слот\tДиск\tВерсия FW\tСерийный номер\tАппаратный путь\tЛогический путь"
	set -A Slots 0 x x x x x x x 1 2 3  4  5
	print "${Out}" | while read HWPath LPath Model FW SN
	do
		Slot=${LPath#*t}
		Slot=${Slot%d*}
		print "${Slots[$Slot]}\t${Model}\t${FW}\t${SN}\t${HWPath}\t${LPath}"
	done 
}

function Print5
{
	print "\nПункт Х.2.${Pun} Внутренние диски"
	(( Pun = Pun + 1 ))
	print "Подключены к ${Path}."
	(( Tab = Tab + 1 ))
	print "Таблица Х.2.${Tab} Внутренние диски"
	print "Слот\tДисk\tАппаратный путь\tЛогический путь"
	set -A Slots primary secondary
	print "${Out}" | while read HWPath LPath Other
	do
		Slot=${LPath#*t}
		Model=$(awk -v D=${LPath} '$2==D { print $3 }' disks/format.out | sed -e 's/<//' )
		print "${Slots[${Slot%d*}]}\t${Model}\t${HWPath}\t${LPath}"
	done 
}

function PrintPhoton
{
	Photons=$(ls -d disks/photon/ses* 2>/dev/null)
	if [[ -z ${Photons} ]]
	then
		Str="FC-AL disks"
		break
	fi

	File="/tmp/photon.$$."
	OutNew=""
	print "${Out}" | \
	while read HWPath Other
	do
		WWN=${HWPath#*w21}
		WWN=${WWN#*w22}
		WWN=${WWN%,0}
		WWN="20${WWN}"
		i=0
		for Photon in ${Photons}
		do
			if [[ -n $(grep ${WWN} ${Photon}/luxadm_display.out) ]]
			then
				print "${WWN} ${HWPath} ${Other}" >>${File}${Photon##*/}
				i=1
				break
			fi
		done
		if (( $i == 0 ))
		then
			OutNew="${OutNew}${HWPath}\t${Other}\n"
			Str="Глюкающий Photon или просто FC-AL диски"
		fi
	done

	for Photon in ${Photons}
	do
		if [[ -f ${File}${Photon##*/} ]]
		then
			integer N=$(awk '/SLOT   FRONT DISKS/, /SUBSYSTEM STATUS/ { print }' \
				${Photon}/luxadm_display.out | wc -l)
			case $N in
				13) N=2 ;;
				9) N=0 ;;
				*) N="x" ;;
			esac
			Name=$(awk -F: '$1=="FW Revision" { print $NF ; exit }' \
				${Photon}/luxadm_display.out | sed -e 's/Name://' )
			print "\nПункт Х.2.${Pun} Дисковый массив A5${N}000 ${Name}"
			(( Pun = Pun + 1 ))
			print "Интерфейсная плата $(awk '$2~"@w21" { print "A " ; exit }
				$2~"@w22" { print "B " ; exit }' ${File}${Photon##*/})подключена к ${Path}."

			awk '$1=="FW" { print $1" "$2"\n"$4"\n"$6 ; exit }' ${Photon}/luxadm_display.out
			print "\nТаблица Х.2.${Tab} Дисковый массив ${Name}"
			(( Tab = Tab + 1 ))
			print "Слот\tДиск\tВерсия FW\tСерийный номер\tАппаратный путь\tЛогический путь"
			cat ${File}${Photon##*/} | \
			while read WWN HWPath LPath Model FW SN
			do
				Slot=$(awk -v W=${WWN} '$4==W { print "f"$1 ; exit }
					$NF==W { print "r"$1 ; exit }' ${Photon}/luxadm_display.out)
				print "${Slot}\t${Model}\t${FW}\t${SN}\t${HWPath}\t${LPath}"
			done 

			print "\nТаблица Х.2.${Tab} Дисковый массив ${Name}. Блоки питания, вентиляторы,интерфейсные платы"
			(( Tab = Tab + 1 ))
			print "Слот\tНазвание"
			awk  -v i=0 'i==1 && $2~"O.K" { print "Спереди левый\tБлок питания" }
				i==1 && $4~"O.K" { print "Сзади\tБлок питания" }
				i==1 && $6~"O.K" { print "Спереди правый\tБлок питания" ; exit }
				$1=="Power" && $2=="Supplies" { i=1 }' ${Photon}/luxadm_display.out
			awk  -v i=0 'i==1 && $2~"O.K" { print "Спереди\tБлок вентиляторов и панель управления" }
				i==1 && $4~"O.K" { print "Сзади\tБлок вентиляторов" ; exit }
				$1=="Fans" { i=1 }' ${Photon}/luxadm_display.out
			awk  -v i=0 'i==1 && $1=="A:" && $2~"O.K" { print "Верхний (A)\tИнтерфейсная плата" ; IB="A" ; break }
				i==1 && $1=="B:" && $2~"O.K" { print "Нижний (B)\tИнтерфейсная плата" ; IB="B" ; break }
				i==1 && $1=="0" && $2~"O.K" { print IB"0 (Плата "IB" правый слот)\tGBIC" }
				i==1 && $1=="1" && $2~"O.K" { print IB"1 (Плата "IB" левый слот)\tGBIC" }
				i==1 && $6~"O.K" { print "Спереди правый\tБлок питания" ; exit }
				$1=="ESI" { i=1 }
				$1=="Disk" { exit }' ${Photon}/luxadm_display.out
		fi	
	done
	rm ${File}* 2>/dev/null
	Out="${OutNew}"
}

awk 'NF==1 { print $1 }' disks/format.out | \
while read Path
do
	print ${Path%/*}
done | uniq | \
while read Path
do
	Out=$(awk -v P=${Path} 'NF==1 && $1~P"/" { print Prev" "$1 ; break }
			{ Prev=$2 }' disks/format.out | \
		while read Dsk Devi
		do
			Devi=${Devi##*/}
			print "${Devi}\t${Dsk}\t$(awk -v D=${Dsk} '$1==D { print $3"\t"$(NF-1)"\t"$NF ; exit }
				$2==D { print $4"\t"$(NF-1)"\t"$NF ; exit }' disks/diskinfo)" 
		done ) #"
	integer N=$(print "${Out}" | wc -l )
	Str=""

	if [[ -n "$(print "${Out}" | awk '$3~"^OPEN-8"')" ]] 
#	&& ( ${Path} != ${Path##*socal} || ${Path} != ${Path##*fcaw} ) ]]
	then
		Str="Дисковый массив HP"
	elif [[ -n "$(print "${Out}" | awk '$3~"^T300"')" ]]
#		&& ( ${Path} != ${Path##*socal} || ${Path} != ${Path##*fcaw} || ${Path} != ${Path##*/fp@} ) ]]
	then
		Str="Дисковый массив T3"
	elif [[ -n "$(print "${Out}" | grep "ssd@w2")" ]]
#	( ${Path} != ${Path##*socal} || ${Path} != ${Path##*/fp@} ) && \
	then
		if [[ (( ${Path} == "/sbus@2,0/SUNW,socal@d,10000/sf@0,0" \
			|| ${Path} == "/sbus@6,0/SUNW,socal@d,10000/sf@0,0" ) && ${SystemModel} == "E3500" ) || \
			( ${Path} == "/pci@8,600000/SUNW,qlc@2/fp@0,0" && ${SystemModel} == "880" ) || \
			( ${Path} == "/pci@8,600000/SUNW,qlc@4/fp@0,0" && ${SystemModel} == "280R" ) || \
			( ${Path} == "/pci@9,600000/SUNW,qlc@2/fp@0,0" && ${SystemModel} == "480R" ) ]]

		then
			Print450
		else
#		if (( N >= 7 && N <= 22 ))
#		then
#			Str="Photon"
#		elif (( N < 7 ))
#		then
#			Str="Internal optical disks"
#		else
#			Str="Photons or other FC-AL devices"
#		fi
			PrintPhoton
		fi
#	elif [[ $N == 2 && \
#		-n $(print "${Out}" | grep t10d0) && -n $(print "${Out}" | grep t11d0) ]]
#	then
#		Str="Дисковая плата"
	elif [[ ${Path} != ${Path##*isp} || \
		( ${Path} != ${Path##*scsi} && ${Path} != ${Path##*pci} ) ]]
	then
		if [[ ( ${SystemModel} == "450" || ${SystemModel} == "420R" || \
			${SystemModel} == "220R" ) && ${Path} == "/pci@1f,4000/scsi@3" ]]
		then
			Print450
		elif [[ ${SystemModel} == "250" && ${Path} == "/pci@1f,4000/scsi@3" ]]
		then
			Print250
		elif [[ $(print "${Out}" | grep "t[01]d0" |wc -l ) == "       2" || \
			$(print "${Out}" | grep "t[89]d0" |wc -l ) == "       2" ]]
		then
			if (( N >= 2 && N <= 12 ))
			then
				PrintD1000
			else
				Str="Неизвестный дисковый массив (SCSI)"
			fi
		elif [[ -n $(print "${Out}" | grep "d1\t" ) ]]
		then
			Str="Дисковый массв (A1000?)"
		else
			Str="Неизвестный дисковый массив (SCSI)"
		fi
	elif [[ ${Path} == "/pci@1f,0/pci@1,1/ide@3" ]]
	then
		Print5
	else
		Str=" "
	fi
	if [[ -n ${Str} ]]
	then
		print "\nПункт Х.2.${Pun} ${Str}"
		(( Pun = Pun + 1 ))
		print "Подключены к ${Path}"
		print "\nТаблица Х.2.${Tab} ${Str}"
		(( Tab = Tab + 1 ))
		print "Аппаратный путь\tЛогическое имя\tМодель\tВерсия FW\tСерийный номер"
		print "${Out}"
	fi
done

Out=$(awk '$(NF-2)~"[0123456789]+$" { print $(NF-2)" "$NF }' disks/ls-l_dev_rmt.out | 
	grep -v total | \
while read Rmt Path
do
	Path=${Path%/*}
	Path=${Path##*..}
	Path=${Path#*/}
	Other=$(awk -v D=${Rmt} '$1~"rmt/"D { print $3"\t"$(NF-1)"\t"$NF ; exit }
				$2~"rmt/"D { print $4"\t"$(NF-1)"\t"$NF ; exit }' disks/diskinfo)
	print "/dev/rmt/$Rmt /${Path#*/}\t${Other}"
done | sort -n )

if [[ -n ${Out} ]]
then
	print "\nПункт Х.2.${Pun} Ленточные накопители"
	(( Pun = Pun + 1 ))
	print "\nТаблица Х.2.${Tab} Ленточные накопители"
	(( Tab = Tab + 1 ))
	print "Логическое имя\tАппаратный путь\tМодель\tВерсия FW\tСерийный номер"
	print "${Out}"
fi

print "\nПункт Х.2.${Pun} Загрузочные диски и параметры загрузки"
(( Pun = Pun + 1 ))
awk -F= '$NF==1 && $1=="nvramrc" { exit }
	/^nvramrc/, /^$/ { if ( $1~"security" ) { exit } else { print } }' sysconfig/eeprom.out | \
	grep -v "data not available"
grep ^boot-	sysconfig/eeprom.out | grep -v "data not available"

#print "Таблица 4.2.1 Дисковые массивы-коробки"
#print "	Имя	Модель	Версия FW"
#print "		Порт	Куда подключен (Слот-Карта-Порт)"
#print "		Слот	Диск-Объем-RPM	Версия FW"
#print "			Аппаратный путь	Логический путь"
#print "		Слот	Блок питания	Куда воткнут"
#print "		Слот	Вентилятор"
#print "Таблица 4.2.2 Дисковые массивы -- аппаратные RAIDы (A1000, T3)"
#print "	Имя	Модель	Кэш	Версия FW"
#print "		Контроллер"
#print "			Порт	Куда подключен (Слот-Карта-Порт)"
#print "		Слот	Диск-Объем-RPM	Версия FW"
#print "			Аппаратный путь	Логический путь"
#print "		Слот	Блок питания	Куда воткнут"
#print "		Слот	Вентилятор"
#print "Указывать настройки адаптера, если оптика. Не забывать про двойные пути."
#print "Таблица 4.2.3 Аппаратное разбиение дисковых массивов"
#print "	Имя"
#print "		LUN	Тип (RAID)	Параметры	Порты"
#print "			Диск (слот)"

print "\nРаздел Х.3 Логическое разбиение дискового пространства"
print "\nРисунок Х.3.1 Распределение дисковых групп по массивам"
print "Рисунок Х.3.2 Распределение томов по дискам в дисковых массивах"

print "\nТаблица Х.3.1 Разбиение дисков на разделы"
print "Диск\tРаздел\tТип\tРазмер"
for i in disks/prtvtoc/*
do
	j=${i##*/}
	j=${j%s*}
	Out=$(awk '$1!="*" { print "\t"$1"\t"$2"\t"$5/2048" Мб" } ' $i)
	integer N=$(print "${Out}" | wc -l )
	if [[ -n $(print "${Out}" | awk '$2=="15"') && $N == "3" ]]
	then
		: print "\t${j}\tVxVm"
	elif [[ -z $(print "${Out}" | awk '$1=="2"') ]]
	then
		print "${j}\tSDS metaset\n${Out}"
	elif [[ $N == "1" ]]
	then
		print "${j}\tне используется"
	else
		print "${j}"
		print "${Out}" | awk '$1!="2"' #| \
#		while read Slice Type Other
#		do
#			print "\t${Slice}\t${Type}\t${Other}\t$(awk -v D="/dev/dsk/${j}s${Slice}" '$1==D { print $3 ; exit }' etc/vfstab)"
#		done
	fi
done
print "Примечание 1. Диски, не указанные в списке, используются VxVM."
print "Примечание 2. Диски, помеченные как SDS, используются в metaset'ах. Диски из корневого metaset не отмечаются как SDS."
print "Примечание 3. Раздел 2 не указывается. На дисках, помеченных SDS, второй раздел отсутствует."

#print "\nОбязательно указать, какие диски загрузочные, на каких разделах какие лежат ФС (для VxVM-- тоже),nvramrc, boot-device."

Tab=2

if [[ -d disks/vxvm ]]
then
	print "\nПункт Х.3.1 Vritas Volume Manager"
	print "\nТаблица Х.3.${Tab} Группы"
	(( Tab = Tab + 1 ))
	print "Группа\tНазначение\tСписок серверов"
	VxDG=$(awk '{ print $1 }' disks/vxvm/vxdg-q-list.out)
	print "${VxDG}"

	Pun=1
	for i in ${VxDG}
	do
		print "\nПодпункт Х.3.1.${Pun} Группа $i"
		(( Pun = Pun + 1 ))

		print "\nТаблица Х.3.${Tab} Диски, входящие в группу $i"
		(( Tab = Tab + 1 ))
		print "Диск\tЛогический путь"
		awk -v DG=$i '$4==DG { print $3"\t"$1 } ' \
			disks/vxvm/vxdisk-list.out | sort

		print "\nТаблица Х.3.${Tab} Тома, входящие в группу $i"
		(( Tab = Tab + 1 ))
		print "Том\tРазмер\tПараметры\tОпции"
		awk -v DG=$i -v p=0 '
			$1=="dg" && $2==DG { p=1 ; break }
			$1=="dg" && $2!=DG && p==1 { exit }
			$1=="sv" { SV=$4 }
			$1=="v" && $2!=SV && p==1 { print $2"\t"$6/2048" Мб\t"$7"\t"$NF }' \
			disks/vxvm/vxprint-th.out 

		print "\nТаблица Х.3.${Tab} Тома, входящие в группу $i, логическая структура"
		(( Tab = Tab + 1 ))
		print "Группа\tТом\tРазмер\tПлекс\tТип\tДиск\tРазмер"
		awk -v DG=$i -v p=0 '
			$1=="dg" && $2==DG { p=1 ; break }
			$1=="dg" && $2!=DG && p==1 { exit }
			$1=="v" && p==1 { print "1/"$2"\t"$6/2048" Мб" }
			$1=="pl" && p==1 { print "2/"$2"\t"$7 }
			($1=="sd" || $1=="sv") && p==1 { print "3/"$4"\t"$6 }' disks/vxvm/vxprint-th.out | \
		awk -F/ 'BEGIN { i=0; j=1; T[1]="\t\t" ; T[2]="\t\t" ; T[3]="\t\t" }
			i>=$1 { a="" ; for ( k=1; k<j; ++k ) a=a""T[k] ; 
				for ( k=j; k<=i; ++k ) a=a""P[k]"\t" ;
				print a ; j=$1 }
			$1=="1" { P[1]=$2 ; i=1 }
			$1=="2" { P[2]=$2 ; i=2 }
			$1=="3" { P[3]=$2 ; i=3 }'
	done
fi

if [[ -d disks/sds ]]
then
	print "\nПункт Х.3.2 Solstice DiskSuite"

	print "\nТаблица Х.3.6 Группы"
	print "Группа	Назначение	Список серверов"
	print "Default\t\t${HostName}"
	Out=$(ls disks/sds/metaset.*.out 2>/dev/null)
	Sets=""
	if [[ -n ${Out} ]]
	then
		for i in ${Out}
		do
			Set=${i##*/}
			Set=${Set#*.}
			Set=${Set%.*}
			Ext=".${Set}"
			Exts="${Exts} ${Ext}"
			print "${Set}\t"$(awk '/Host/, /Drive/ { if ( NF==1 || $2=="Yes" ) { print "\t\t"$1 } }' $i)
		done
	fi

	Pun=1
	for Ext in "" ${Exts}
	do
		if [[ -z ${Ext} ]]
		then
			i="Default"
		else
			i=${Ext#.}
		fi
		print "\nПодпункт Х.3.1.${Pun} Группа $i"
		(( Pun = Pun + 1 ))
		print "\nТаблица Х.3.${Tab} Диски, входящие в группу $i"
		(( Tab = Tab + 1 ))
		print "Диск"
		if [[ -z ${Ext} ]]
		then
			awk -F/ '{ print $NF }' disks/sds/metadb.out | \
				grep -v flags | awk -Fs '{ print $1 }' | sort | uniq
		else
			awk '/Drive/, /^$/ { if ( NF!=0 && $1!="Drive" ) { print $1 } }' \
			disks/sds/metaset${Ext}.out
		fi

		Out=$(awk -F/ '{ print $NF }' disks/sds/metadb${Ext}.out | \
			grep -v flags | sort | \
			awk 'BEGIN { Prev="o" ; i=1 }
				$NF==Prev { i=i+1 ; break }
					$1!=Prev { if ( Prev!="o" ) { print Prev"\t"i } ; i=1; Prev=$NF }
					END { if ( Prev!="o" ) { print Prev"\t"i } }' )
		if [[ -n ${Out} ]]
		then
			print "\nТаблица Х.3.${Tab} Размещение реплик с конфигурацией"
			(( Tab = Tab + 1 ))
			print "Раздел диска\tКоличество реплик\n${Out}"
		else
			print "\nГруппа недоступна"
			continue
		fi

		print "\nТаблица Х.3.${Tab} Тома, входящие в группу $i, логическая структура"
		(( Tab = Tab + 1 ))
		print "Группа/Том\tРазмер\tТип\tОпции"
		print "\tЧасть\tТип\tРазделы дисков"
		awk 'BEGIN { M=o }
			$2=="Mirror" { Name=$1 ; M="m" ; break }
			$2=="Submirror" { Name=$1 ; M="su" ; break }
			$2=="Concat/Stripe" { Name=$1 ; M="co" ; break }
			$1=="Read" { ROpt=$3 ; break }
			$1=="Write" { WOpt=$3 ; break }
			$1=="Size:" { Size=$2/2048 }
			M=="m" && $1=="Size:" { print Name"\t"Size" Мб\tmirror\t"ROpt", "WOpt }
			M=="su" && $1=="Stripe" && $3=="(interlace:" { print "\t"Name"\tstripe\t"$4/2" Kb" ; M="dev" ; break }
			M=="su" && $1=="Stripe" { print "\t"Name"\tconcat" ; M="dev" ; break }
			M=="co" && $1=="Stripe" && $3=="(interlace:" { print Name"\t"Size" Мб\tstripe\t"$4/2" Kb" ; M="dev" ; break }
			M=="co" && $1=="Stripe" { print Name"\t"Size" Мб\tconcat" ; M="dev" ; break }
			M=="dev" && $1!="Device" && NF>0 { print "\t\t\t"$1 }' \
			disks/sds/metastat${Ext}.out
	done


fi

print "\nЧасть Х.4 ФС"
print "Таблица Х.4.1 ФС"
print "Точка монтирования\tТип\tПроход fsck\tТом\tОпции\tНазначение"
awk '$1~"#" { continue }
	$4!="swap" && $4!="fd" && $4!="proc" && $4!="nfs" { print $3"\t"$4"\t"$5"\t"$1"\t"$NF }' etc/vfstab
awk '$1~"#" { continue }
	$4=="swap" { print "\t"$4"\t\t"$1 }' etc/vfstab
awk '$1~"#" { continue }
	$4=="nfs" { print $3"\t"$4"\t"$5"\t"$1"\t"$NF }' etc/vfstab

if [[ -s etc/sharetab ]]
then
	print "\nТаблица Х.4.2 Exports"
	print "Файловая система\tОпции"
	awk '$1~"#" { continue }
		{ print $1"\t"$NF} ' etc/sharetab
fi

print "\nГлава 5 Операционная система\n"
tail -1 patch+pkg/showrev.out

print "\nТаблица 5.1 Установленное СПО, ППО"
print "ПО\tВерсия"
awk '{ print "Solaris\t"$3" "$4 }' sysconfig/uname-a.out

set -A Pkgs VRTSvxvm VRTSvmsa \
	VRTSvxfs VRTSvcs\
	SUNWmd SUNWmdg \
	QUALha \
	SUNWnetbp VRTSnetbp \
	SUNWsspr
set -A Descs "VERITAS Volume Manager" "VERITAS Volume Manager Storage Administrator" \
	"VERITAS File System" "VERITAS Cluster Server" \
	"Solstice DiskSuite" "Solstice DiskSuite Tool" \
	"Qualix HA+" \
	"VERITAS NetBackup" "VERITAS NetBackup" \
	"Sun Enterprise 10000 SSP"
integer i=0
for Pkg in ${Pkgs[*]}
do
	Ver=$(awk -v P=${Pkg} 'BEGIN { a=0 }
		$1=="PKGINST:" && ( $2==P || $2~P"." ) { a=1; continue }
		a==1 && $1=="VERSION:" { print $0 ; exit }' patch+pkg/pkginfo-l.out | \
		sed -e 's/   VERSION:  //')
	if [[ -n ${Ver} ]]
	then
		print "${Descs[$i]}\t${Ver}"
	fi
	(( i = i + 1 ))
done

print "\nТаблица 5.2 Лицензии"
print "\tЧто лицензировано\tКоличество\tКогда истекает"
if [[ -f license/vxlicense-p.out ]]
then
	awk '$3=="Feature" { Lic=$5 }
		$3=="Number" { No=$6 }
		$3=="Expiration" { print "\tVeritas "Lic"\t"No"\t"$0 }' \
		license/vxlicense-p.out |
		sed -e 's/vrts:vxlicense: INFO: Expiration date: //'
fi

print "\nГлава 6 Сеть"
print "\nТаблица 6.1 Сетевые интерфейсы"
print "Логическое имя\tИмя\tАдрес\tМаска\tMac-адрес\tСкорость\tНазначение"
awk 'BEGIN { a=0 }
	$1!="lo0" && $1~":" { Name=$1 ; a=1 ; continue }
	a==1 { Ip=$2 ; Mask=$4 ; a=2 ; continue }
	a==2 { print Name" "Ip" "Mask" "$2 ; a=0 ; continue }' sysconfig/ifconfig-a.out | \
while read 	Name Ip Mask Mac
do
	Host=$(awk -v I=$Ip '$1==I { print $2 }' etc/hosts)
	Host=${Host%%.*}
	print "${Name%:}\t${Host}\t${Ip}\t${Mask}\t${Mac}"
done

print "\nТаблица 6.2 Таблица маршрутизации"
cat netinfo/netstat-rn.out

print "\nНастройки DNS"
cat etc/resolv.conf

print "\nПриложение 1 Установленное СПО"
exit
print "\nТаблица П1.1 Установленные пакеты"
print "Категория\tНазвание\tНазначение"
print "Fully Installed pkgs"
sort patch+pkg/pkginfo-i.out | grep -v "Fully Installed pkgs" | grep -v "=" 
print "Partialy Installed pkgs"
sort patch+pkg/pkginfo-p.out | grep -v "Partialy Installed pkgs" |grep -v "="
