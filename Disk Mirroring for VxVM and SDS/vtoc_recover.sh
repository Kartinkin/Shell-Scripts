#!/usr/bin/ksh -p
# 	0.0
# Date		26 Jul 2004
# Author	Kirill Kartinkin

# ��������� ������������� ��� ������ �������� ������ UFS �� �����
# � ��������� �������� ��������.
#
# ��������� ��������� ���� ������� �� ���������, ������� ����� ������ �
# ��������� ����������, ���� ��� �������� ����������� ����������, ��������
# ������ ���������� ��� ��� �� � ��������� ������� � ����� ����������
# ������������. ��� ��������� �������������� ������ ���������� �������� ��
# ������ �� �� ������� � ������������ ������������.
#
# �� ��������� ������������ �� ���� ������������ ����� ������� ��������
# � ���������� ������� ��������� fsck �� ��� ��������� ��.
#
# ���������:
#	�������� -- ��� ����� ������������ ����� (���� cXtXdX)
# 
# ������������ ��������:
#	0	O.K.
#	1	������������ ������� ������
#	3	�� ������� �����
#	100	������ � ���������� ��������� ������

################################################################################
# ��������� ���������� ������������ � ���������� ����������� ��������
Name=${0##*/}
PATH=/usr/bin:/usr/sbin

TempFile=/tmp/vtocrec.$$

################################################################################
# ��������� ��������� ��������� ������
if (( $# == 0 ))
then
	print "Usage: ${Name} cXtXdX -d"
	exit 100
else
	Disk=$1
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
			/usr/bin/ksh -o emacs
		fi
	fi
}	

# ������� �������� �������� � ��������� ckyorn
# ��� ������ "��" ���������� 0, "���" -- 1. 
#
# ���������:
#	$1	����� �������
#
function Prompt
{
	case $(ckyorn -p "$*") in
		"y"|"Y") return 0 ;;
		"q"|"Q")
			rm ${TempFile}
			exit 1 ;;
		*) return 1 ;;
	esac
}

if [[ $2 == "-d" ]]
then
	Debug="Debug"
else
	Debug=""
fi

################################################################################
################################################################################

# ������� ��������� �����
Out=$(format </dev/null)
# ���� ������ � ������ �����
DiskDescr=$(print "$Out" | nawk -F"<" -v Disk=${Disk} '$1~Disk { print $2 }')
if [[ -z ${DiskDescr} ]]
then
	# �������� ����� �� �����, ������
	print "\nDisk ${Disk} not found."
	exit 3
fi

# ��������� ������ ��������, ������� ����� ������� �� ����� ��������
# �������� ����� ���������.
set -A Sizes $(print ${DiskDescr} | nawk '{ print $NF*$(NF-2)" "$(NF-6)}')
CylSize=${Sizes[0]}
Cyls=${Sizes[1]}
unset Sizes
print "Disk has ${Cyls} cylinders, cylinder size is ${CylSize} blocks.\n"

# ���������� VTOC, �� ���� ��� ����������� ������ ������
VTOC=$(prtvtoc -h /dev/dsk/${Disk}s2 | awk '$1=="2" { print ; exit }')

# � ����� �������� �� ���� ��������� (���������� Cyl),
# � ������ ������� ���� �������� �����������.
# ���� ������� ��, ������� ������ ��� ���.
integer Cyl=0
# � ���������� i ����������� ������� ������.
integer i=0

while (( ${Cyl} < ${Cyls} ))
do
	# ����� �������
	echo "\r${Cyl}\c"

	# ��� ����� 16-31 � 32-47 ����� (������ � ��������� ����������).
	# ���������� �� ��������� ���� ��������������� �����.
	dd if=/dev/dsk/${Disk}s2 of=${TempFile} iseek=$((Cyl*CylSize+16)) bs=512 count=32 2>/dev/null
	
	# ���� ���������� �������.
	set -A Magics $(od -t x1 ${TempFile} | \
		nawk 'NF>3 && $(NF-2)=="01" && $(NF-1)=="19" && $NF=="54" { print $1 }')
	# ��� UFS ��� ������ ���� ��� �� ����� �������
	if [[ "${Magics[0]}" == "0002520" &&  "${Magics[1]}" == "0022520" ]]
	then
		# �����, �������, UFS
		# �������, � ������ �������� ����������� ����� ���������� ������������
		FS=$(od -c -j 212 ${TempFile} | head -2 | cut -b8-72 | sed -e 's/  \\0//g')
		FS=$(print $FS | sed -e 's/ //g')
		# � ��� ������ �������� ������� �� ������� ����������
		Sz1=$(od -t u4 -j 36 ${TempFile} | awk '{ print $2; exit}')
		# � ��� -- �� �������
		Sz2=$(od -t u4 -j 8228 ${TempFile} | awk '{ print $2; exit}')
		# ���������, ��������� �� �������
		if (( ${Sz1} == ${Sz2} ))
		then
			# ��, � ������� �������� ����������� ��� ����� ��
		    # ��������� ������ � ���������, ����� �� �� �����������
			(( Sz2 = Sz1 / CylSize * 2))

			# ������������� ������� �� �������������
			Prompt "Starting cylinder ${Cyl}, size $((Sz1/1024)) Mb (${Sz2} cyls), last mounted on ${FS}.\nIs it true?"
			if (( $? == 0 ))
			then
				# ������������ ����������
				# ���������� ����� ������ � VTOC 
				VTOC="${VTOC}\n$i 0 00 $((Cyl*CylSize)) $((Sz1*2)) $((Cyl*CylSize+Sz1*2-1))"
				# ����������� i �� ������� ������������ ����� 2
				if (( $i == 1 ))
				then
					i=3
				else
					(( i = i + 1 ))
				fi
				# ����� �� ����������� �������� � ��,
				# ����� ������� �� �� ��������� �������
				(( Cyl = Cyl + Sz2 - 1 ))
				# ����� ������� �� �� ��������� �������
				#(( Cyl = Cyl + Sz2 ))
				print "Jumping to cylinder ${Cyl}."
			fi
		fi
	fi
	# �������� � ���������� ��������
	(( Cyl = Cyl + 1 ))
done

# ������������� VTOC
Prompt "Apply this VTOC:\n${VTOC}\n ?"
if (( $? == 0 ))
then
	# ������������� ��������,
	# ���������� ����� ������� ��������
	print "${VTOC}" | fmthard -s - /dev/rdsk/${Disk}s2
	prtvtoc -h /dev/rdsk/${Disk}s2

	# �� ���� ����� �������� ��������� fsck
	(( i = i - 1 ))
	while (( i >= 0 ))
	do
		if (( $i != 2 ))
		then
			print "\nStarting fsck on slice $i:"
			fsck -NF ufs /dev/dsk/${Disk}s${i}
		fi
		(( i = i - 1 ))
	done
fi

rm ${TempFile} 2>/dev/null
exit 0
