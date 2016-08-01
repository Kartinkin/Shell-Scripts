#!/usr/bin/ksh -p
# Version	1.0
# Date		16 Apr 2004
# Author	Kirill Kartinkin

# ��������� ������������� ��� �������������� ���������� �����
# ���������� Solstice DiskSuite.
#
# ��� �������, ����� 0, ������������� � ����-����� dX1 (������ ����) � dX2 (�������),
# �� ��� ���������� RAID-1 -- dX0.
# �������� �������� ������� ����������� � d0, �������, � ���� �������,
# ������� �� ��������� d1 � d2.
#
# �������������� ������������ � ��� �����.
# �� ������ ����� ��������� ��������� ��������� � ����������� -R ��������.
# ��� ��������� ����-�������, ������� ����-�����, �������������� ����� �������,
# �������� /etc/vfstab, ��������� � ���������� ������� ���� 
# /etc/rcS.d/S99sdsrootmirror, ����� ���� ���������� ������������.
# �� ������ ����� (����� ������������) ����������� ������ /etc/rcS.d/S99sdsrootmirror,
# ������� ��������� ������� � �������������� ������.
#
# �����������:
#	����� ������ ���� � ���������� ����������.
#	������ 0 ������ ��������� �������� �������� �������.
#	������ ������������ ������ � ����� 9 (alternate),
#		�������� �� ����� 12288 ������ ���������� ������.
#	������� ������ ���������� � �������������������� ������.
#	��� ������ ��������� ��������� ����� SUNWxcu4
#
# ��� ���������, � �������� ������ ��������� (� ����� ����������� ������) swap,
# ������� �� ��������� �����.
#
# �������������:
#	sds_root_mirror1 [-F|-R] ��������
#
# ���������:
#	��������	��� ����� ���� cXtXdX, �� ������� ����� ������������ ��������������
#	-F	��������, ��� ����� ������� ����-�����, �� ������ �� ������
#	-R	������������� ����
# 
# ������������ ��������:
#	0	O.K.
#	1	/ ����� �� �� 0 �������,
#		��������� ���� ��������� � �����������,
#		��� ��� ������ �� �������
#	2	����� ����� ������ ���������
#	3	���������� ������� swap
#	4	������ ��� �������� ������
#	5	������ ��� �������� ����-������
#	6	������ ��� �������� ����-������ ��� /
#	7	������ ��� ������� /
#	8	������ ��� ���������� ������
#	9	������ alternate �� ������
#	100	������ � ����������

################################################################################
# ��������� ���������� ������������

Name=${0##*/}
PATH=/bin:/usr/sbin:/usr/opt/SUNWmd/bin

# ����, � ������� ����������� ������� ���������
RCFile=/etc/rcS.d/S99sdsrootmirror

# ������ ������� � ������
# � Solaris 8 �� ��������� 1024
# � Solaris 9 -- 8192
MetaDBSize=4096

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
		exit $1
	fi
}	

################################################################################
################################################################################
# ��������� ��������� ��������� ������
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

# ���������� ��������� ����...
RootSlice=$(nawk '$3=="/" { print $1 }' /etc/vfstab)
RootSlice=${RootSlice##*/}
RootDisk=${RootSlice%s*}
# ...� ������ �������� �������� �������
RootSlice=${RootSlice#*s}

# ��� ������, ����� root ��� �� ������� 0. ������ ��� � ����.
# ���, �������� �����, �������� ���. 1.
if (( ${RootSlice} != 0 ))
then
	# ������ �����������
	print "Root slice must be 0."
	exit 1
fi

if [[ ${RootDisk} == ${MirrorDisk} ]]
then
	# ������ ��� ������� ���������� -- ����� ������ ����������
	print "Disk (${MirrorDisk}) is the same with root disk."
	exit 1
fi

# ��������� ��������� ������
Out=$(format </dev/null)
# ���������� �������� ������ �� ������ ������� format
RootDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${RootDisk} '$1~Disk { print $2 }')
MirrorDiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${MirrorDisk} '$1~Disk { print $2 }')
if [[ -z ${MirrorDiskDescr} ]]
then
	# ����� ��� ������� �� �����, ������
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

# ���������� ������, �� ������� ����� ��������� �������,
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

# ������ ������ ���������� ��������
Slices=$(prtvtoc -h /dev/dsk/${RootDisk}s2 | \
	nawk -v R=${RootSlice} -v S=${MetaDBSlice} '$1!="2" && $1!=R && $1!=S { print $1 }')

# ������� ������� ������� ���������
#	��	������ (����-����)	������ (����-����)
print "Current root disk slices\tTargeted mirror slices"
# Root ��������
print "\t/	${RootDisk}s0 (d1)\t${MirrorDisk}s0 (d2)"
# �� ���� ��������� ��������, ���� ��� ����
if [[ -n ${Slices} ]]
then
	for Slice in ${Slices}
	do
		print "\t$(nawk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)	${RootDisk}s${Slice}�(d${Slice}1)\t${MirrorDisk}s${Slice}�(d${Slice}2)"
	done
fi

if (( $Fake == 1 ))
then
	# ��� ��������� ���������� ����������, �������
	print "Fake partioning done."
	exit 0
else
	# �������������...
	print "\nThe system MUST be in single-user mode to mirror root disk."
	# ������� ���� �����
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
# ����� � ���������� ����������, �������� ����� �����:
#dd if=/dev/dsk/${RootDisk}s0 of=/dev/dsk/${MirrorDisk}s0 bs=512 count=1
prtvtoc -h /dev/dsk/${RootDisk}s2 |fmthard -s - /dev/rdsk/${MirrorDisk}s2
CheckRet 3 "copy vtoc."
print "Done."

################################################################################
# C������ �� ���������� ������� �������
print "======\nStep 1"
print "Creating metaDBs..."
# ��� ������� �� ��������� �����
metadb -f -a -c 3 -l ${MetaDBSize} /dev/dsk/${RootDisk}s${MetaDBSlice}
CheckRet 4 "create metaDBs on ${RootDisk}s${MetaDBSlice}"
# ��� -- �� �������
metadb -f -a -c 3 -l ${MetaDBSize} /dev/dsk/${MirrorDisk}s${MetaDBSlice}
CheckRet 4 "create metaDBs on ${MirrorDisk}s${MetaDBSlice}"
print "Done."

################################################################################
# ������� ����-���� ��� swap �� ��������������� �������.
print "======\nStep 2"

if [[ -n ${Slices} ]]
then
	# �� ���� ��������, ����� ���������
	for Slice in ${Slices}
	do
		FS=$(nawk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)
		# ������� �� ������� ������� ����� ������� ����-���� dX1
		print "Creating metadisk (d${Slice}0=d${Slice}1+d${Slice}2) for ${FS}..."
		metainit -f d${Slice}1 1 1 /dev/dsk/${RootDisk}s${Slice}
		CheckRet 5 "create d${Slice}1 metadisk"
		# �����, �� ����� ��� ������� �������
		# �� ���������������� ������� ����-���� dX2
		metainit d${Slice}2 1 1 /dev/dsk/${MirrorDisk}s${Slice}
		CheckRet 5 "create d${Slice}2 metadisk"
		# ��������� dX0 ��� mirror �� ����� ��������� dX1,
		# dX2 � ������� �� ���������, ������ ����������������,
		# ���� �� ������������ � �������.
		metainit d${Slice}0 -m d${Slice}1
		CheckRet 5 "create d${Slice}0 metadisk"
		# ������ /etc/vfstab
		# � ������ ������������ ������ /dev/dsk �� /dev/md/dsk
		# � /dev/rdsk �� /dev/md/rdsk
		sed -e "s/\/dev\/rdsk\/${RootDisk}s${Slice}/\/dev\/md\/rdsk\/d${Slice}0/" \
			-e "s/\/dev\/dsk\/${RootDisk}s${Slice}/\/dev\/md\/dsk\/d${Slice}0/" \
			/etc/vfstab >/tmp/vfstab.$$
		cp /tmp/vfstab.$$ /etc/vfstab
		print "Done."
	done
fi

# ������ ��������� � �����. � ��� ����������, ������ ����� ����������.
print "Creating metadisk (d0=d1+d2) for root..."
metainit -f d1 1 1 /dev/dsk/${RootDisk}s0
CheckRet 6 "create d1 metadisk"
metainit d2 1 1 /dev/dsk/${MirrorDisk}s0
CheckRet 6 "create d2 metadisk"
metainit d0 -m d1
CheckRet 6 "create d0 metadisk"
# ���� /etc/vfstab �� ������, ��� ������� ����� metaroot.
print "Done."

################################################################################
print "======\nStep 4"
print "Installing root metadisk..."

# ������� ��������� ������, ������� ������� �������
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

# ��������� ������ /etc/system � /etc/vfstab
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
