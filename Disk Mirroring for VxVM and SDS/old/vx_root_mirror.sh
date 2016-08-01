#!/usr/bin/ksh -p
# Version	1.0
# Date		13 Sep 2004
# Author	Kirill Kartinkin

# ��������� ������������� ��� �������������� ������������������ ���������� �����
# ���������� Veritas Volume Manager.
#
# �������������� ������������ � ��� �����.
# �� ������ ����� � ������ rootdg ����������� ����-�������, ����� ����,
# ������� �� ��������� ����� (rootdisk), ����������� �� ����-�������.
# ��������� ���� ��������� �� ������ rootdg -- ��� �������� ��� ��� �������� ������ 
# �� ������ ����� � ����� ����������� �������.
#
# �����������:
#	��������� ���� ������ ���� ������� ��������������.
#	���� � rootdg ����� ������ �����, ������������� ������ �� ����,
#	������� ����� �� ����� rootdisk.
#	����� ������ ���� � ���������� ����������.
#	�� ��������� ����� ������ ���� ���� ��������� �������.
#	��� ������ ��������� ��������� ����� SUNWxcu4
#	
# �������������:
#	������� Veritas Volume Manager
#	���������� ����������� ��������
#	���������� vx_root_mirror.sh ��������, ��� �������� -- ��� ����� (���� cXtXdX),
#		�� ������� ����� ������������ ��������������
#	���������� vx_vtoc.sh -R
# 
# ������������ ��������:
#	0	O.K.
#	1	��� ���� ���� �������
#	2	�� ������� ���������� �����
#	3	�� ������� �����, ��������������� ��� �������
#	4	����� �� ����������
#	5	�� ��������� ����� ��� ������� ��������
#	6	������ ��� ���������� ����� rootdiskm � �������� ������ rootdg
#	7	������ ��� �������� ���� � ����� roodisk �� ������� rootdiskm
#	8	������ ��� �������� ����� rootdisk �� �������� ������ rootdg
#	9	������ ��� ���������� ����� rootdisk � �������� ������ rootdg
#	10	������ ��� �������������� ����
#	100	������ � ���������� ��������� ������

################################################################################
# ��������� ���������� ������������ � ���������� ����������� ��������

# ��� ����� � ��������
LogFile=/var/adm/vx_vtoc.log

# ���� � ������� ��� ������, � ������� ����� �������� ������ VTOC'�
# ��������, � ������ ������ ��� ����� /var/adm/vx_vtoc.c0t0d0
VTOCFile=/var/adm/vx_vtoc

RootDisk=rootdisk
RootDiskM=rootmirror

# ������ �����, ������� ��������� ��������������� � �������.
# ����� �����, ��������� � ���� ������, �� ����� ������ ���������, ������� �� rootdisk.
# ��� ���� �� ������ rootdg
set -A Volumes rootvol var swapvol usr opt home

# ��� �������������� ���������� ���� ��������
IOSize="256k"

Name=${0##*/}
PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

################################################################################
# ��������� ��������� ��������� ������
if (( $# == 0 ))
then
	print "Usage: ${Name} cXtXdX -d"
	exit 100
else
	MirrorDisk=$1
fi

################################################################################
# ��������� ��������������� �������

# ������� ���������� �������� ���� ��������,
# ���� ��������� ������ -- ��������� ��������� �� ������ � 
# �������������� ����� �� ���������.
#
# ���������:
#	$1	��� �������� � ������ ������
# 	$2	��������� �� ������
#
function CheckRet
{
	if (( $? != 0 ))
	then
		# ��� �������� �� 0, ������� 
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
# ��������� ������ SubDisk'��, �� ������� ����� ������ rootvol, swapvol, usr � var.
# �� ������, ���� ������-�� ���� ���, ���������� ������.
# ������� �� �������� ������ � ��������� ���������
#	sd	rootdisk-01	rootvol-01	ENABLED,
# ����� �� ����� SubDisk'� �������� ������ �����,
# �����������, ��� ��� � ����� ������ ����������� �����
SD="$(vxprint -g rootdg ${Volumes[*]} 2>/dev/null | \
	nawk '$1=="sd" { print $2 }' | \
	nawk ' BEGIN { FS="-" } { print $1 }' | sort | uniq )"

if (( $(print "${SD}" | wc -l ) != 1 ))
then
	# ������ ������ ���������� �����.
	print "More than one root disks found ("${SD}")."
	# ����� ���� �� ������� ����� rootvol.
	SD="$(vxprint -g rootdg rootvol 2>/dev/null | \
		nawk '$1=="sd" { print $2 }' | \
		nawk ' BEGIN { FS="-" } { print $1 }' | sort | uniq )"
	if (( $(print "${SD}" | wc -l) > 1 ))
	then
		# ���� ����� ������ ������ �����,
		# ������, rootvol ��� ����������.
		print "\nYou have mirrored rootvol."
		exit 1
	fi
	print "Done.\n\tSelecting ${SD}."
fi

if [[ -z ${SD} ]]
then
	# ���-�� ����� �� ���...
	print "Root disk not found."
	exit 2
fi

print -n "Encounting volumes on the ${SD}... "
# ���������� Vol ��������� �� ���� ��������� ��� ������� ��������� �����.
# � ���������� Vols �� �������� ��������� �� ����� ${SD} ����.
Vols=""
# � ���������� OVols ������� ��� ���� � ����� ${SD}.
OVols="$(vxprint -g rootdg 2>/dev/null | \
		nawk -v R=${SD} '$1=="sd" && $2~"^"R"-" { print $3 } ' | sed -e 's/-01//' )"
# � ���� ����� ��������� Vols, ��������� �� �� OVols.
# ��� �������� � ����� ��������� ������� �����.
# ������� ������ ���� rootvol � �.�., ����� ����������������.
for Vol in ${Volumes[*]}
do
	# ���������, ���� �� ���
	V=$(vxprint -g rootdg ${Vol} 2>/dev/null | \
		nawk -v R=${SD} '$1=="sd" && $2~"^"R"-" { print $3 ; exit } ' | sed -e 's/-01//' )
	if [[ -n $V ]]
	then
		# ����, ���������� ��� �� OVols
		OVols=$(print "${OVols}" | grep -v $V)
		# � ��������� � Vols
		Vols="${Vols} $V"
	fi
done
# � ����� Vols ��������� ��� ��������� ����
Vols="${Vols} ${OVols}"
unset V OVols
print "Done.\n\tVolumes to proceed:"${Vols}"."

print -n "Checking disk geometry..."
# ��������� ��������� ������
Out=$(format </dev/null)
# ���� ���������� ��� ���������� ����� (cXtXdX)
RD=$(vxprint -g rootdg 2>/dev/null | \
	nawk -v R=${SD} '$1=="dm" && $2==R { print $3 } ')
RD=${RD%s*}
# ���������� �������� ������ �� ������ ������� format
RootDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${RD} '$1~Disk { print $2 }')
MirrorDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${MirrorDisk} '$1~Disk { print $2 }')

if [[ -z ${MirrorDiskDescr} ]]
then
	# �������� ����� ��� ������� �� �����,
	# ������
	print "\nDisk ${MirrorDisk} not found."
	exit 3
fi

if [[ "${MirrorDiskDescr}" != "${RootDiskDescr}" ]]
then # �� ���� ���������� �������� ������
	print "\nThis program can mirror disks with a same geometry only."
	print "\t${RD} <${RootDiskDescr}"
	print "\t${MirrorDisk} <${MirrorDiskDescr}"
	print -n "Press enter to continue or Control-C to exit... "
	read
#	exit 4
fi
print "Done."

# VxVM ������� ���� ������� ��� ���� ������. 
# ��������� ������� ��������� �����, ���� ��� ������������ ��
# �������� ������ ��������.
print -n "Checking for free cylinder... "
# ������ �������� ������� ������� ����� ������� �� ����� ��������
CylSize=$(print ${RootDiskDescr} | nawk '{ print $NF*$(NF-2) }')
# ��������� ����� �����������,
# ������� ������������� ������ ����,
# ������� ����� ������� �� ��������� �����.
Free=$(vxassist -g rootdg -p maxsize alloc=${SD} 2>/dev/null)
if [[ -z ${Free} ]]
then # ����� ��� �����, vxassist ������ �� ����������
	Free=0
fi
if (( ${Free} < ${CylSize} ))
then
	# ��� �����
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
# ���������� ������ � ���������� ����� �� �������
print "\nStep 1. Moving data from ${SD} to ${RootDiskM}:"
print "Volumes to proceed:"${Vols}"."
# ��� ����� ������� ������� �������, � ����� ������� �������������.

# ������� �������������� ����,..
print "Adding mirror disk ${MirrorDisk} as ${RootDiskM} to rootdg..."
vxdisksetup -i ${MirrorDisk} ${DiskSetupOpts}
CheckRet 6 "initialize disk ${MirrorDisk}."
# ����� ��������� ��� � ������ rootdg
vxdg -g rootdg adddisk ${RootDiskM}=${MirrorDisk}
CheckRet 6 "add disk ${MirrorDisk} to rootdg."
vxedit -g rootdg set nohotuse="on" ${RootDiskM}
print "Done."

#Vols=$(vxprint -g rootdg ${Volumes[*]} 2>/dev/null | \
#	awk '$1=="v" { print $2 }' )

for Vol in ${Vols}
do
	# ��� ������� ���� ��������� �������, ����� ����� ������� ��������.
	print "Mirroring ${Vol}..."

	# �������� �������������� rootvol
	if [[ ${Vol} == rootvol ]]
	then
		# ��� �������������� rootvol ���� ����������� �������.
		# ��� �������� nvramrc.
		vxrootmir ${RootDiskM}
	else
		# ��� ��������� ����� ������ ��������� �������
		vxassist -g rootdg -o iosize=${IOSize} mirror ${Vol} layout=contig,diskalign ${RootDiskM}
	fi
	CheckRet 7 "mirror ${Vol}."
	# � ������ ������� ��������. �������� plex, � ����� ������ ���.
	print "Removing mirror from ${Vol}..."
	vxplex -g rootdg dis ${Vol}-01
	CheckRet 7 "remove mirror from ${Vol}."
	vxedit -g rootdg -fr rm ${Vol}-01
	CheckRet 7 "remove mirror from ${Vol}."
done
print "Done."

# ������� ������ ����������� ����
print "Removing ${SD}..."
# ��� ������ �� ������, ������� ��. ������ ��� �� �����.
vxedit -g rootdg rm rootdiskPriv 2>/dev/null
#CheckRet 4 "remove disk ${SD} from rootdg."
# ������� ���� �� ������...
vxdg -g rootdg rmdisk ${SD}
CheckRet 8 "remove disk ${SD} from rootdg."
# ...� ��������� ��� � ��������� ���������.
vxdiskunsetup ${RD}
CheckRet 8 "remove disk ${RD}."
print "Done".

################################################################################
print "\nStep 2. Coping data from ${RootDiskM} to ${RootDisk}."

print "Adding disk ${RD} as ${RootDisk} to rootdg..."
# ������ �������������� ����...
vxdisksetup -i ${RD} ${DiskSetupOpts}
CheckRet 9 "initialize disk ${RD}."
# ...� ��������� ��� � ������ rootdg
vxdg -g rootdg adddisk ${RootDisk}=${RD}
CheckRet 9 "add disk ${RD} to rootdg."
vxedit -g rootdg set nohotuse="on" ${RootDisk}
print "Done."

# ���������� Vol ��������� �� ���� ����� �� ������ rootdg,
# ������� �� ����������� ����� 
for Vol in ${Vols}
do
	# ��� ������� ���� ��������� ������ ��� ��������� �������.
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

# �������������
print "\nStep 3. Use vx_vtoc.sh to partioning ${RootDiskM} and ${RootDisk} disks."
