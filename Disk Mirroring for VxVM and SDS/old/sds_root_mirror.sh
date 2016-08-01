#!/usr/xpg4/bin/sh
# Version	0.0
# Date		25 Sep 2002
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
#	������� ������ ���������� � �������������������� ������.
#	��� ������ ��������� ��������� ����� SUNWxcu4
#
# ��������! ������� ��������� �������, �� �� �������� ��� �������
# ���������� �������. ������� ��������� �� ���������� swap �������.
# ��� ���������, � �������� ������ ��������� (� ����� ����������� ������) swap,
# ������� �� ��������� �����.
#
# �������������:
#	sds_root_mirror [-F|-R] ��������
#
# ���������:
#	��������	��� ����� ���� cXtXdX, �� ������� ����� ������������ ��������������
#	-F	��������, ��� ����� ������� ����-�����, �� ������ �� ������
#	�R	������������� ����
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
#	100	������ � ����������
#0x09            /* Alternate s#

################################################################################
# ��������� ���������� ������������

Name=${0##*/}
PATH=/usr/xpg4/bin:/usr/sbin:/bin:/usr/opt/SUNWmd/bin

# ����, � ������� ����������� ������� ���������
RCFile=/etc/rcS.d/S99sdsrootmirror

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
RootSlice=$(awk '$3=="/" { print $1 }' /etc/vfstab)
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
RootDiskDescr=$(print "$Out" | awk -F"<" -v Disk=${RootDisk} '$1~Disk { print $2 }')
MirrorDiskDescr=$(print "$Out" | awk -F"<" -v Disk=${MirrorDisk} '$1~Disk { print $2 }')
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

# ���������� ������, �� ������� ��������� swap,
# �� ��� ������������ ����� ����������� �������
SwapSlice=$(awk '$4=="swap" { print $1 }' /etc/vfstab)
SwapSlice=${SwapSlice##*/}
SwapSlice=${SwapSlice#*s}

# ������ ������ ���������� ��������
Slices=$(prtvtoc -h /dev/dsk/${RootDisk}s2 | \
	awk -v R=${RootSlice} -v S=${SwapSlice} '$1!="2" && $1!=R && $1!=S { print $1 }')

# ������� ������� ������� ���������
#	��	������ (����-����)	������ (����-����)
print "Current root disk slices\tTargeted mirror slices"
# Root ��������
print "\t/	${RootDisk}s0 (d1)\t${MirrorDisk}s0 (d2)"
# Swap, �����������, ����
print "\tswap	${RootDisk}s${SwapSlice}�(d${SwapSlice}1)\t${MirrorDisk}s${SwapSlice}�(d${SwapSlice}2)"
# �� ���� ��������� ��������, ���� ��� ����
if [[ -n ${Slices} ]]
then
	for Slice in ${Slices}
	do
		print "\t$(awk -v S=${RootDisk}s${Slice} '$1~S { print $3 }' /etc/vfstab)	${RootDisk}s${Slice}�(d${Slice}1)\t${MirrorDisk}s${Slice}�(d${Slice}2)"
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
# ����� � ���������� ����������, �������� ����� �����:
#dd if=/dev/dsk/${RootDisk}s0 of=/dev/dsk/${MirrorDisk}s0 bs=512 count=1
prtvtoc -h /dev/dsk/${RootDisk}s2 |fmthard -s - /dev/rdsk/${MirrorDisk}s2
CheckRet 3 "copy vtoc."
print "Done."

# ������� �� ������ swap, �.�. ��� ����� ����� ��� �������
print "Deleting the swap area (${RootDisk}s${SwapSlice})..."
print "Plese ignore the follows dumpadm messages."
# �������...
swap -d /dev/dsk/${RootDisk}s${SwapSlice}
# ���������, ���������� ��
swap -l 2>/dev/null |grep ${RootDisk}s${SwapSlice} >/dev/null
if (( $? == 0 ))
then
	# ���, swap �������
	print "Unnable to delete the ${RootDisk}s${SwapSlice} swap area."
	exit 3
fi
print "Done."

################################################################################
# C������ �� ������� ��-��� swap �������
print "======\nStep 2"
print "Creating metaDBs..."
# ��� ������� �� ��������� �����
metadb -f -a -c 3 /dev/dsk/${RootDisk}s${SwapSlice}
CheckRet 4 "create metaDBs on ${RootDisk}s${SwapSlice}"
# ��� -- �� �������
metadb -f -a -c 3 /dev/dsk/${MirrorDisk}s${SwapSlice}
CheckRet 4 "create metaDBs on ${MirrorDisk}s${SwapSlice}"
print "Done."

################################################################################
# ������� ����-���� ��� swap �� ��������������� �������.
print "======\nStep 3"
# ������, ������, ���� ����-���� ������. 
print "Creating metadisk (d${SwapSlice}0=d${SwapSlice}1+d${SwapSlice}2) for swap..."
# ������ � ������:
#	������� �� ������� ������� ����� ������� ����-���� dX1
metainit d${SwapSlice}1 1 1 /dev/dsk/${RootDisk}s${SwapSlice}
CheckRet 5 "create d${SwapSlice}1 metadisk"
#	�����, �� ����� ��� ������� ������� �� ���������������� �������
#	����-���� dX2
metainit d${SwapSlice}2 1 1 /dev/dsk/${MirrorDisk}s${SwapSlice}
CheckRet 5 "create d${SwapSlice}2 metadisk"
#	��������� dX0 ��� mirror �� ����� ��������� dX1,
#	dX2 � ������� �� ���������, ����� ����������������,
#	���� �� ���� ������������ � �������.
metainit d${SwapSlice}0 -m d${SwapSlice}1
CheckRet 5 "create d${SwapSlice}0 metadisk"

# ������ /etc/vfstab
# � ������ ������������ ������ /dev/dsk �� /dev/md/dsk
awk -v S=${SwapSlice} -v R=${RootDisk} \
	'$1=="/dev/dsk/"R"s"S { print "/dev/md/dsk/d"S"0\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\n#"$0 ; break }
	{ print $0 }' /etc/vfstab >/tmp/vfstab.$$
cp /tmp/vfstab.$$ /etc/vfstab
print "Done."

if [[ -n ${Slices} ]]
then
	# ������ ����������� �������� � ���������� ���������
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
lockfs -af
CheckRet 7 "install root metadisk"
print "Done."

################################################################################
print "======\nStep 5"
print "\n\tThe system will be rebooted now."
print -n "\nPress Return to continue... "
read
sync;sync;reboot
