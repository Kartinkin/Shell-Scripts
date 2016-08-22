#!/usr/xpg4/bin/sh
# Version	0.0
# Date		3 Nov 98
# Author	Kirill Kartinkin

# ��������� ���������� ����� ��������.
# ��� ����� ��������� ����������� ����������, � ������� ������������
# ���������� �����. ����� ������������� ���������. ��������� ��� ���������
# ����� ������ � ������� ���.Z, ���.old.Z � ���.oldest.Z. ��� �������� ���������
# �������: �� ������� ���� ��������� ���������� ���� "/", � ���� ��� "/"
# ���������� �� ".", � � ����� ����� ��� "." ���������� �� "_".
#
# ������������ adm �� ������ adm �������� ��� ����� �� �����.
#
# ��������� ��������� ���������� �������� ����������� � ������ ������, ����
# ���� �� ��� ����������� � �������, ���������� ���� �� ������������.
#
# �����:
#	-d path	����������, � ������� ������������ �����.
#		���� �������� �� �����, ������������ /var/adm/logs.archive
#		���� ���������� �� ����������, ��� ���������
#	-c	������� ������������ ����� ���������� compress
#		�� ��������� ����������
#	-C	�� ������� ������������ �����
#	-f file	���� �� ������� ��������
#		���� ������ ����� ����� ������� "-", �� ������������ stdin
#		���� �������� �� �����,
#		������������ ���������� ���������� ArchiveDir
#
# ������������ ��������:
#	0	O.K.
#	1	���������� ������� �����
#	2	������ ��� ������ ������ ������
#	4	������ ������ ������ �������� ������
#	8	������ ������������� �����
#	16	������ ������ �����
#	100	������ � ��������� ������
#	101	���������� ���������� ������� Logger
#
# ��������� ������ ����������� �� ����� ������������ root.

# ��� ������ ������ ��� ��� �������.
# ��� ��������� ����� ����������� � cron...
# ���� �������� �� ��������� ������, �� �������� POSIX-shell,
# � ���� ������� cron, �� ����� Bourne shell.
x="A.B"
x=`(echo ${x%%.*}) 2>/dev/null`
# Bourne shell �� ����� ��������� ���������� �� ���������
if [ "$x" != "A" ]
then
	# �����, ���� �� �����, �������� ���� ����	
	$0 $*
	exit $?
fi

################################################################################
# ��������� ���������� ������������ � ���������� ����������� ��������

# ������������� ����������� ���� ������
PATH=/usr/xpg4/bin:/usr/bin:/var/adm/bin

Name=${0##*/}

# ����������, � ������� ������� ����� ��������.
# �� ������������� ������� �� ���������.
ArchiveDir=/var/adm/logs.archive

# ��������� �� ������������� ����������
Compress=1
# ������� � ����� ������� �����
CompressExt=".Z"

# ���������� LogFile �������� ������ ������ ��������.
# ����� �� ���������� ���������
LogFiles=""

# 3 ����� �������� NFS
LogFiles="${LogFiles} /var/adm/lockd.log /var/adm/statd.log /var/adm/mountd.log"

# 5 ������ ����� ���������������� ������ � �������
LogFiles="${LogFiles} /var/adm/utmp /var/adm/wtmp /var/adm/btmp"
LogFiles="${LogFiles} /var/adm/utmpx /var/adm/wtmpx"

# ���� ������� ������� cron
# (������ ��� ������������ � HP-UX,������ � Solaris)
LogFiles="${LogFiles} /var/adm/cron/log /var/cron/log"

# ���� ������� ������� switch user
File=$(ccat /etc/default/su 2>/dev/null |\
	awk 'BEGIN { FS="=" } $1=="SULOG" { print $2 }')
if [[ -z ${File} ]]
then
	LogFiles="${LogFiles} /var/adm/sulog"
else
	LogFiles="${LogFiles} ${File}"
fi

# ���� � �������� ���������� ������� ����� � �������
LogFiles="${LogFiles} /var/adm/loginlog"

# �������� ���������� ����� �� ������������ syslog.conf
# ��� ����� �������� �� ����� ������������ syslog ��� ����� ������,
# � ����� ���������, ������� �� ��� ���� � ���� �� ��.
for File in $( ccat /etc/syslog.conf | \
	awk '{ for (i = NF; i > 0; --i)
			{ if ($i~"^/") 
				{ print $i }
			}
		}' | sed -e 's/,//g' | sort | uniq )
do
	# ��������! �� ������� POSIX-shell �� ������.
	# �� ������ -f �������� "regular file"
	if [[ -f ${File} ]]
	then
		# ��, ��� ������� ����
		LogFiles="${LogFiles} ${File}"
	fi
done

# 2 ����� �������� ����������� ������ Qualix HA+
LogFiles="${LogFiles} /var/adm/log/qhap.log /var/adm/log/cma.log"

# ���� ������� Veritas Volume Manager
LogFiles="${LogFiles} /var/vxvm/vxconfigd.log"

# 2 ����� ������� ���� INFORMIX
LogFiles="${LogFiles} ~informix/online.log ~informix/ontape.log"

# ���� ������� ����������� ������ MC/ServiceGuard
#LogFile="${LogFile} /etc/cmcluster/depo/control.sh.log"

################################################################################
# ���������� ������� Logger
LOGGER_FACILITY=user
LOGGER_TAG=logcleaner
LOGGER_PRINT=0 # ������ ��������� �� ���������
if [[ -f /var/adm/bin/logger.sh ]]
then
	. /var/adm/bin/logger.sh
else
	print "ERROR: Unnable to source /var/adm/bin/logger.sh"
	exit 101
fi

################################################################################
# ��������� ��������� ��������� ������
while (( $# > 0 ))
do
	case "$1" in
		-c) Compress=1;;
		-C) Compress=0
			CompressExt=""
			;;
		-f) List=$2
			shift
			;;
		-d) ArchiveDir=$2
			shift
			;;
        *)
			print "usage: ${Name} [-c|C] [-f file] [-d path]"
			exit 100
			;;
    esac
	shift
done

################################################################################
# ���� ��� ���������� � �������, ������� ��
if [[ ! -d ${ArchiveDir} ]]
then
	mkdir -p ${ArchiveDir}
	if (( $? != 0 ))
	then
		Logger err "Unnable to create log's archive (${ArchiveDir})."
		exit 1
	fi
	# ����� ������� rwxr-xr-x
	chmod 755 ${ArchiveDir}
#	chown adm:adm ${ArchiveDir}
	Logger info "Log's archive created."
fi

################################################################################
# ���������, ���� �� ��������� ������ ������
if [[ -n ${List} ]]
then
	# ��, ����
	# ���������, �� stdin �� ���, � ���� ���, �� ���� �� ���� �� �������
	if [[ ${List} = "-" || -r ${List} ]]
	then
		# ����������� ��� ����� � ������������� ����
		# ���� ������������� ���� "-", �� ���� ��� ������
		# ������� cat ����� ������ �� stdin
		LogFiles=$(cat ${List})
	else
		# ������, ����� �� ����������,
		# ��� �� ���������� ��� ������
		Logger err "Cannot open list file \"${List}\"."
		exit 2
	fi
fi

# ��������� ������ ���������� ������
print "${LogFiles}" | sed -e 's/ /\
/g' >${ArchiveDir}/.list

# � ���� ���� ����� ������� ������ ������������ ������
>${ArchiveDir}/.archived

################################################################################
# ��������� � ��������� ������

# ������������� ��� ��������
integer Ret=0

# ���������� File �������� �� ��������� ������ � ������� ��������
for File in ${LogFiles}
do
	# � ���� ����� ������������ ���������� �����
	if [[ -s ${File} ]]
	then
		# ������ ��������� ����� ����������
		print ${File} >>${ArchiveDir}/.archived
		# ������ ��� ��������� �����
		# � ����� ����� ��� "." ���������� �� "_",
		# �� ������� ���� ��������� ���������� ���� "/",
		# � ���� ��� "/" ���������� �� ".".
		FileName=$(print ${File} | \
			sed -e "s/\./_/g" -e "s/\///" -e "s/\//./g")
		# ������ ������ ��� ����������������� �����
		# � ����� ������ �����
		ArchivedFile="${ArchiveDir}/${FileName}${CompressExt}"
		ArchivedFileOld="${ArchiveDir}/${FileName}.old${CompressExt}"
		ArchivedFileOldest="${ArchiveDir}/${FileName}.oldest${CompressExt}"
		
		# �������� ������ �������� �����
		# FileName.old.Z --> FileName.oldest.Z
		# FileName.Z --> FileName.old.Z
		if [[ -f ${ArchivedFileOld} ]]
		then
			mv ${ArchivedFileOld} ${ArchivedFileOldest}
			if (( $? != 0 ))
			then
				Logger notice \
					"Unnable rename \"${ArchivedFileOld}\"."
				(( Ret = Ret | 4 ))
				continue
			fi
		fi
		if [[ -f ${ArchivedFile} ]]
		then
			mv ${ArchivedFile} ${ArchivedFileOld}
			if (( $? != 0 ))
			then
				Logger notice \
					"Unnable rename \"${ArchiveFile}\"."
				(( Ret = Ret | 4 ))
				continue
			fi
		fi
		if (( Compress != 1))
		then
			# ���������� ���������� ���� 
			# ����� �� ���������� ��������� ��������� ������
			# ���������� ����, �������� ��� ���������� � �����
			cat ${File} >${ArchivedFile}
			if (( $? !=0 ))
			then
				Logger err "Failed to move file \"${File}\"."
				(( Ret = Ret | 8 ))
				continue
			fi
		else
			# ������� �������� ����
			compress -f <${File} >${ArchivedFile}
			if (( $? == 1 �| $? > 2 ))
			then
				Logger err "Failed to compress file \"${ArchiveDir}/${FileName}\"."
				Logger info "File \"${File}\" not archived."
				(( Ret = Ret | 16 ))
				continue
			fi
			Logger info \
				"File \"${ArchiveDir}/${FileName}\" compressed."
		fi

#			chown adm:adm ${ArchivedFile}
		# ����� ������� �rw-r--r--
		chmod 644 ${ArchivedFile}
		# �������� ������ ��� (�� ������� ����� ����,
		# � �������� ������)
		>${File}
		Logger info "File \"${File}\" archived."
	fi
done

exit ${Ret}
