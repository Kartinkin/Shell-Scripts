#!/usr/bin/ksh -p
# Version	0.0
# Date		2 Nov 2001
# Author	Kirill Kartinkin

# ��������� ������������� ��� ��������� ����� rootvol, swapvol, usr, opt �  var 
# �� ������ rootdg ��� Veritas Volume Manager �� ������� ���������� ������.
#
# ���������:
#	Partition  Tag  Flags  Mount Directory
#	0          2    00    /
#	1          7    00    /var
#	3          15   00    vxvm 
#	4          14   00    vxvm
#	5          3    01    swap
#	6          4    00    /usr
#	7          0    00    /opt
#
# ����� ����, � /etc/vfstab ����������� ���������� �� �������� ��� ������������
# ��������� �������� ������.
# ����������� �������� ������������� � /var/adm/vx_vtoc.log (���������� $LogFile). 
# ������ VTOC'� ������������ � /var/adm/vx_vtoc.XXX (���������� $VTOCFile).
#	
#	��� ������ ��������� ��������� ����� SUNWxcu4
#
# ���������:
#	-F	��������, ��� ����� ���������� ����,�� ������ �� ������
#	�R	����������� ����
# 
# ������������ ��������:
#	0	O.K.

################################################################################
# ��������� ���������� ������������ � ���������� ����������� ��������

# ��� ����� � ��������
LogFile=/var/adm/vx_vtoc.log

# ���� � ������� ��� ������, � ������� ����� �������� ������ VTOC'�
# ��������, � ������ ������ ��� ����� /var/adm/vx_vtoc.c0t0d0
VTOCFile=/var/adm/vx_vtoc

# ������ �����, ������� ��������� ��������������� � �������
# ��� ���� �� ������ rootdg
Volumes[0]=rootvol
# �������� �������, ��. prtvtoc(1M)
Tags[0]=0x02
Flags[0]=0x00
# ������, ����������� � /etc/vfstab.
# ����������� ������ ����� ��� '"#��������vfstab"', ��. vfstab(4).
# ����� ������ ��������� ��� /dev/[r]dsk/${PV_}s${Slice}.
FSTab[0]='"#/dev/dsk/${PV_}s${Slice}	/dev/rdsk/${PV_}s${Slice}	/	ufs	1	no	-"'
# ������, �� ������� �������� �������� ���.
# ���� ������ �����, ��� ����� ������� �� ������ ��������� ����� ����������,
# � ����� � ���� ���� ������������� ����������� � ������
# � ������� ����������� ����� ���� (� ������� ��������).
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
# ��������� ��������� ��������� ������
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

# ��������� ������ SubDisk'��, �� ������� ����� ������ /, swap, /usr � /var.
# �� ������, ���� �����-������ �������� ������� ���, ���������� ������.
# ������� �� �������� ������ � ��������� ���������
#	sd	rootdisk-04	opt-01	ENABLED,
# ����� �� ����� SubDisk'� �������� ������ �����,
# �����������, ��� ��� � ����� ������ ����������� �����
SDs=$(vxprint -g rootdg ${Volumes[*]} 2>/dev/null | \
	nawk '$1=="sd" { print $2 }' | \
	nawk ' BEGIN { FS="-" } { print $1 }' | sort | uniq )

if [[ -z ${SDs} ]]
then
	# ���-�� ����� �� ���...
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

# �������� �� ���� ���������� ������ � 
# ��� ������� ������ ����� ������� ���������
for SD in ${SDs}
do
	# ������� ������ ������ ��� ����������,
	# � �������� � �������� ������� ��������,
	# � ����� ������� ����� ��������.
	
	# ������� ��� ����������� �����
	# ���������� PV �������� ��� �����, �
	# ���������� PV_ -- ��� ��� �������� �������
	PV=$(vxprint -g rootdg ${SD} | nawk '$1=="dm" { print $3 }')
	PV_=${PV%s*}
	
	print "Processing disk ${SD} (${PV_})..." | tee -a ${LogFile}

	# ���������� ������ �������
	VTOC="$(prtvtoc -h /dev/dsk/${PV})"
	# ... � ���������� �� � ������ � � ����������� ����
	print "Disk ${PV_}. Geometry and  partitioning:" >>${LogFile}
	print "\t(also wrote to the ${VTOCFile}.${PV_} file)" >>${LogFile}
	print "${VTOC}" | tee ${VTOCFile}.${PV_} >>${LogFile}

	# ������������ �������, ������ ��� �������,
	# ����� 2 � �������� VxVM
	# (���� �� ������� ������ ���������, �� ������� vxmksdpart).
	if (( $Fake	== 0 ))
	then
		# �����������, ������ ��� ������ � �������� �����
		print "${VTOC}" | \
			nawk '$2!=5 && $2!=14 && $2!=15 { print "\t"$1"\t0\t00\t0\t0\t0" ; continue }
	        	{ print $0 }' | \
	   	    fmthard -s - /dev/rdsk/${PV} >>${LogFile} 2>&1
	fi
	# �������� ������ ������� ��������.
	BusySlices=$(print "${VTOC}" | \
		nawk '$2==5 || $2==14 || $2==15 { print $1 }')
	# ������� �������� ������
	BusySlices=$(print ${BusySlices})
	print "\tUsed slices: ${BusySlices}." | tee -a ${LogFile}
	# ������� �� ���� ����� ���� ������������ � ������� �����
	# ���������� i ��������� �� ��������� �������� � ���������� �����
	i=0
	# � ���������� BusySlices ������ ������ ������� ��������,
	# ��������� ��� �� ���� �����������.
	for Volume in ${Volumes[*]}
	do
		# ���� ������ ������, ��������� ��� � ������ �������
		# ����� ���� ���������� �� ���� ���
		
		# ���������, ����� �� �������� �� PrefSlice
		if [[ "${BusySlices}" == "${BusySlices#*${PrefSlice[$i]}}" ]]
		then
			# ��, PrefSlice ��������
			# ������ ������
			Slice=${PrefSlice[$i]}
			# � ����� ���� �����
			BusySlices="${BusySlices} ${Slice}"
		else
			# ��������� �� ���� ������� � ������� ����������
			Slice=""
			for S in 0 1 3 4 5 6 7
			do
				# ��� ������ ����� ���������
				if [[ "${BusySlices}" == "${BusySlices#*$S}" ]]
				then
					# ���������� ��� �����
					Slice=${S}
					# � ��������� � ������ �������,
					BusySlices="${BusySlices} ${S}"
					break
				fi
			done
			# ���� �� ����� ���������� �������,
			if [[ -z ${Slice} ]]
			then
				# ������� � ��������� � ���������� ����.
				print "Unnable to map volume ${Volume}." | tee -a ${LogFile}
				print "Free slice on disk ${PV_} not found." | tee -a ${LogFile}
				continue
			fi
		fi
		# ��������� ��� ��������, �� ������� ����� ���������� ���.
		# �.�. �� ����� ���� �����, ���� �� �����. 
		VolSD=$(vxprint -g rootdg ${Volume} 2>>${LogFile} | \
			nawk '$1=="sd" &&  $NF!~"Block" { print $2 }' | \
			nawk -v S=${SD} ' BEGIN { FS="-" } $1==S { print $1"-"$2 }')
		# ���� ��� ����� �� ���� �����,
		if [[ -n ${VolSD} ]]
		then
			# ���������� �� ������
			print "\tMapping volume ${Volume} to ${PV_}s${Slice}..." \
				| tee -a ${LogFile}
			
			if (( $Fake	== 0 ))
			then
				# ��� ������������ �� ������ ...
				vxmksdpart -g rootdg ${VolSD} ${Slice} ${Tags[$i]} ${Flags[$i]} | \
					>>${LogFile} 2>&1
				# ...� � /etc/vfstab ����������� ������ ��� ���������� ������������ ��
				eval Str="${FSTab[$i]}"
				print "${Str}" >>/etc/vfstab
			else
				print "\t\t"vxmksdpart -g rootdg ${VolSD} ${Slice} ${Tags[$i]} ${Flags[$i]}
			fi
		fi
		(( i = i + 1 ))
		# ����������� i � ��������� � ���������� ����
	done
	if (( $Fake	== 0 ))
	then
		# ������� �������� ��������� � ����� /etc/vfstab
		print "\n" >>/etc/vfstab
	fi
done
