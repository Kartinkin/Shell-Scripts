#!/usr/bin/ksh -p
# Version	1.0
# Date		13 Apr 2005
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

RootClone=rootclone
RootSpare=rootspare

Name=${0##*/}
PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

################################################################################
# ��������� ��������� ��������� ������
if (( $# == 0 ))
then
	print "Usage: ${Name} [spare cXtXdX] [mirror cXtXdX] [clone cXtXdX]"
	exit 100
fi


################################################################################
function CheckRet
{
	if (( $? != 0 ))
	then
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


Path=${0%/*}
if [[ ${Path} == $0 ]]
then
	Path=""
else
	Path=${Path}/
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

while (( $# > 0 ))
do
	print "################################################################################
"
	case $1 in
		mirror)
			print "Mirroring root disk...\n"
			${Path}/vx_root_mirror.sh $2
			${Path}/vx_vtoc.sh -R
			;;
		clone)
			print "Creating root's clone...\n"
			vxprint -g rootdg ${RootClone} 2>/dev/null
			if (( $? != 0 ))
			then
				vxdisksetup -i $2 ${DiskSetupOpts}
				CheckRet 6 "initialize disk $2."
				vxdg -g rootdg adddisk ${RootClone}=$2
				CheckRet 6 "add disk $2 to rootdg."
			fi
			${Path}cloneroot1.3 ${RootClone}
			;;
		spare)
			print "Adding spare disk...\n"
			vxprint -g rootdg ${RootSpare} 2>/dev/null
			if (( $? != 0 ))
			then
				vxdisksetup -i $2 ${DiskSetupOpts}
				CheckRet 6 "initialize disk $2."
				vxdg -g rootdg adddisk ${RootSpare}=$2
				CheckRet 6 "add disk $2 to rootdg."
			fi
			vxedit -g rootdg set spare=on ${RootSpare}
			vxedit -g rootdg set nconfig=all nlog=all rootdg
			;;
		*)
			print $*
			exit
			;;
	esac
	shift 2
done
