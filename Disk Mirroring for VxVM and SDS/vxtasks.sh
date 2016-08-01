#!/usr/bin/ksh -p
# Version	2.5
# Date		12 Jul 2006
# Author	Kirill Kartinkin

# ��������� ��������� ����������� �� EIS �����������
# ��������� �������� ������ rootdg � Veritas Volume Manager.
#
# ��������� �������� � VxVM ������ 3.x � 4.x.
#
# �������������:
#	vxroottasks.sh [-g DiskGroupName]
#		[mirror [-all] cXtXdX]
#		[spare cXtXdX]
#		[clone [-all] [cXtXdX]]
#		[vtoc [-fake|-all] DiskName]
#		[addmirror [-all|-force] DiskName=cXtXdX]
#		[removemirror DiskName]
#		[setupdump [-fake]]
#	��� DiskName -- ��� ����� � VxVM.
# ��������� ������:
#	mirror -- ��������� �������� ������������������:
#		addmirror [-all] rootmirror=cXtXdX
#		removemirror rootdisk
#		addmirror [-all] rootdisk=CYtYdY
#		vtoc rootdisk
#		vtoc rootmirror
#		setupdump, ���� �� ���������� dedicated dump device
#	spare -- ��������� spare-����.
#	clone -- ������� ���� ���������� �����
#		(������ ��������� ����� ����� � ��������� �������).
#	vtoc -- ��������� �������� ���� rootvol, swapvol, usr, opt, var � home
#		�� ������ rootdg �� ������� ���������� ������.
#		� ���������� -fake ����������, ����� ����� ���������,
#		�� ������ �� ������.
#		���� ������� ����� -all, �������� ���������� ��� ����. Unsupported.
#		���������:
#			Partition  Tag  Flags  Mount Directory
#			0          2    00    /
#			1          7    00    /var
#			3          15   00    vxvm 
#			4          14   00    vxvm
#			5          3    01    swap
#			6          4    00    /usr
#			7          0    00    /opt
#			7          8    00    /export/home
#		� /etc/vfstab ����������� ���������� �� �������� ��� ������������
#		��������� �������� ������.
#		������ VTOC'� ������������ � $VTOCFile.
#		����� ����� �������, ��������� setupdump.
#	addmirror -- ����������� ��������� ����,
#		������������� ���� cXtXdX � �������� ��� � rootdg � ������ DiskName.
#		���� ������� ����� -all,
#		������������ ��� ���� � ������� ���������� ���������� �����.
#		���� ������� ����� -force,
#		������������� ������ ���� rootvol, swapvol, usr, opt, var � home
#		(�������� ���������� SatelliteVolumes).
#		���� ������� ����� �� �������, � ����� ��������� ��������� �����
#		�� �������� ����� ���� ��� ���-��, �������������� �� ������������.
#		����� ����� �������, ��������� setupdump.
#	removemirror -- ������� ������� � ���������� �����,
#		����� ���� ������� ����� �� rootdg � ���������������� ���.
#		���� �� ����� ����� ������������������� ����,
#		������� �������� �� ������������.
#		����� ����� �������, ��������� setupdump.
#	setupdump -- ������������� dump device, ������� ������ ����,
#		�� ������� ���� swapvol, ������������ �� ���������� ������.
#		���� dump device ���������� �� ������ �����, �� ������� ��� swapvol,
#		������� �������� �� ������������.
#		���� ������� ����� -fake, ��������� ������ ��������������� ���������,
#		��������� ������ �� ��������.
#
#	��� ��������� ����� ��������� ������������.
#	 
# ������������ ��������:
#	0	O.K.
#	1	������ ��� ���������� �������
#	6	������ ��� ���������� ����� �������� ������ rootdg
#	100	������ � ���������� ��������� ������

################################################################################
# ��������� ���������� ������������

Name=${0##*/}
Path=${0%/*}
if [[ ${Path} == $0 ]]
then
	Path=""
else
	Path=${Path}/
fi

PATH=/usr/bin:/usr/sbin:/etc/vx/bin/

# ����� ������ ��-���������
RootDiskName=rootdisk
RootMirrorName=rootmirror
RootCloneName=rootclone
RootSpareName=rootspare

SatelliteVolumes="rootvol var swapvol usr opt home"

# ��� �������������� ���������� ���� ��������
IOSize="256k"

GuardSuff="guard"
GuardPUtil0="DONOTUSE"

VTOCTag="vxvm"

TempDir=/var/adm/config
if [[ ! -d ${TempDir} ]]
then
	mkdir -p ${TempDir}
fi

# ��� ����� � ��������
LogFile=${TempDir}/vx_tasks.log
# ���� � ������� ��� ������, � ������� ����� �������� ������ VTOC'�
# ��������, � ������ ������ ��� ����� ${TempDir}/vtoc.c0t0d0
VTOCFile=${TempDir}/vtoc

if [[ $1 == "-g" ]]
then
	DGName="$2"
	shift 2
else
	DGName=rootdg
fi

# ��������� ������ VxVM, ��������� ������������� ������ � ��������� ������
# ������� �������������� �����
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

# � ��� �� ����� � ����� �������,
# �� ������ VxVM ��� ������������� ����� ��������� ������� ������� ���������.
# ����� �������� �����, ���������������� ��������� ������
#DiskSetupOpts="${DiskSetupOpts} old_layout"

################################################################################
################################################################################
# ��������� ��������������� �������

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

################################################################################
# ������� ����, �� ����� ����� ����� rootvol.
# ���� ������ ���������, ���������� ������
#
# ���������� ������� ����������:
#	RootDisk	��� �����
#	RootDiskPV	���������� ��� �����
#	RootDiskPV_	���������� ��� ����� ��� s2
#
# ������������ ��������:
#	0	O.K.
#	1	���� �� ������
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
	# ������� ��� ����������� �����
	# ���������� PV �������� ��� �����, �
	# ���������� PV_ -- ��� ��� �������� �������
	RootDiskPV=$(vxprint -g ${DGName} -dF '%daname' ${RootDisk} 2>/dev/null)
	RootDiskPV_=${RootDiskPV%s*}
}

################################################################################
# ������� ��������� ���������� Volumes � VolumesToProceed.
# ����� ����� � ������� ������������� ��������� �������: ������� ���� ���������
# ���� � �������, ��������� � SatelliteVolumes,
# ����� ��������� � ���������� �������.

#
# ���������:
#	���������VxVM
# ������������ ������� ����������:
#	SatelliteVolumes ������ ��������� �����
# ���������� ������� ����������:
#	Volumes	����� �����, ������� ����� �� ��������� �����
#	VolumesToProceed	����� ��������� �����
#	PV		���������� ��� �����
#	PV_		���������� ��� ����� ��� s2
# 
# ������������ ��������:
#	0	O.K.
#
function ColVolumes
{
	VolumesToProceed=""
	PV=""
	PV_=""
	# ������� ��� ����������� �����
	# ���������� PV �������� ��� �����, �
	# ���������� PV_ -- ��� ��� �������� �������
	PV=$(vxprint -g ${DGName} -dF '%daname' $1 2>/dev/null)
	PV_=${PV%s*}
	# ������ ���� ����� �� �����
	Vols=$(vxprint -Q -g ${DGName} -e"pl_sd.sd_dm_name == \"$1\" && pl_volume != \"\"" -F "%vol")
	
	if [[ -z ${Vols} ]]
	then
		print "\tNo volumes found on disk $1."
		return 1
	fi

	# � ����� ��������� ������ ��������� ����� � ��������� ������ Volumes.
	# ��� ������� �������� ���������� Volume ������������ �������� �� �������
	# ���� � ����� ������, ��� ������� ��� ����������� � ������ VolumesToProceed.
	# ����� Volume ������ � ������ Vols, � ����������� ����� ������ Volumes
	# (��� ���������� ����������� ������� �����).
	VolumesToProceed=""
	Volumes=""
	for Volume in ${SatelliteVolumes}
	do # ��� ������� ���� �� ������ SatelliteVolumes
		if [[ -n $(vxprint -g ${DGName} -e"v_nplex > 0 && v_plex.pl_subdisk.sd_dm_name == \"$1\" && name == \"${Volume}\"" -F"%vol") ]]
		then # ��� ���� �� �����, ��������� ��� � VolumesToProceed
			VolumesToProceed="${VolumesToProceed} ${Volume}"
		fi
		if [[ -n $(print "${Vols}" | grep ${Volume}) ]]
		then # ��� ���� � ������ Vols, ��������� ��� � Volumes
			Volumes="${Volumes} ${Volume}"
			# � ���������� �� Vols
			Vols="$(print "${Vols}" | grep -v ${Volume})"
		fi
#		print "Volumes=${Volumes}\nVolumesToProceed=${VolumesToProceed}"
	done
	if [[ -n ${Vols} ]]
	then # ���� ���-�� �������� � Vols, ��������� ��� � ����� Volumes
		Volumes="${Volumes} ${Vols}"
	fi
	print "\tSubdisks from the listed volumes are found on the the disk $1:\n\t\t"${Volumes}
}

################################################################################
################################################################################
#

################################################################################
# ������� ������������� ��� ��������� ����� rootvol, swapvol, usr, opt �  var 
# ������� �� ��������� ����� �� ������� ����� �����.
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
#	7          8    00    /export/home
#
# � /etc/vfstab ����������� ���������� �� �������� ��� ������������
# ��������� �������� ������.
# ������ VTOC'� ������������ � $VTOCFile.
#	
# �������������:
#	CreateVTOC ���������VxVM
# ������������ ������� ����������:
#	Force	���� ����� �������� 0, �� ������� ����������,
#		��� ����� ���������� ����, �� ������ �� ������
#	SetDump	���� ����� �������� 1, �� �������
#		������������� ������������� ������, �� ������� ������������ swapvol,
#		��� dump device

# 
# ������������ ��������:
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
	# ������� ������ ������ ��� ����������,
	# � �������� � �������� ������� ��������,
	# � ����� ������� ����� ��������.

	# ���������� ������ �������
	VTOC="$(prtvtoc -h /dev/dsk/${PV})"
	# ... � ���������� �� � ������ � � ����������� ����
	print "${VTOC}" > ${VTOCFile}.${PV_}

	# ������������ �������, ������ ��� �������,
	# ����� 2 � �������� VxVM
	# (���� �� ������� ������ ���������, �� ������� vxmksdpart).
	if (( ${Force} != 0 ))
	then
		# �����������, ������ ��� ������ � �������� �����
		print "${VTOC}" | \
			nawk '$2!=5 && $2!=14 && $2!=15 { print "\t"$1"\t0\t00\t0\t0\t0" ; continue }
	        	{ print $0 }' | \
	   	    fmthard -s - /dev/rdsk/${PV} >/dev/null 2>&1
	fi
	# �������� ������ ������� ��������.
	BusySlices=$(print "${VTOC}" | \
		nawk '$2==5 || $2==14 || $2==15 { print $1 }')
	# ������� �������� ������
	BusySlices=$(print ${BusySlices})
	print "\tSlices are used: ${BusySlices}"

	# ������� ������ ������ �� /etc/vfstab
	cp /etc/vfstab /etc/vfstab.vtoc
	grep -v "${VTOCTag} /dev/dsk/${PV_}s" /etc/vfstab.vtoc >/etc/vfstab
	print "# ${Disk}" >>/etc/vfstab

	FirstSwap=
	#########################################################
	# ������� ����� ���� ������������ � ������� �����
	# � ���������� BusySlices ������ ������ ������� ��������,
	# ��������� ��� �� ���� �����������.
	for Volume in ${VolumesToProceed}
	do	# ����������, ��� �� ���,
		# ���� ������ ������, ��������� ��� � ������ �������
		# ����� ���� ���������� �� ���� ���

		# ��� subdisk'� ������� ����, ������� ����� �� ������ �����
		SD=$(vxprint -Q -g ${DGName} \
			-e"sd_dm_name == \"${Disk}\" && sd_pl_name.pl_volume == \"${Volume}\" " \
			-F "%name")
		if [[ -z ${SD} ]]
		then # �� ���� ����� ������ ���� ���
			continue
		fi

		RDsk='/dev/rdsk/${PV_}s${Slice}'
		Dsk='/dev/dsk/${PV_}s${Slice}'

		case ${Volume} in
			rootvol)
				# �������� �������, ��. prtvtoc(1M)
				Tag="0x02"
				Flags="0x00"
				# ����� � vfstab, ��. vfstab(4).
				FSCKOrder="1"
				FSType="ufs"
				MountOnBoot="no"
				MountPoint="/"
				# ������, �� ������� �������� �������� ���.
				# ���� ������ �����, ��� ����� ������� �� ������ ���������
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

		# ���������, ����� �� �������� �� Slice
		if [[ "${BusySlices}" == "${BusySlices#*${Slice}}" ]]
		then
			# ��, PrefSlice ��������
			# ������ ������
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
				print "\tThere is no free slices to map volume ${Volume}."
				continue
			fi
		fi

		print "\tMapping subdisk ${SD} (volume ${Volume}) to ${PV_}s${Slice}..."
		if (( ${Force} != 0 ))
		then # ��� ������������ �� ������ ...
			vxmksdpart -g ${DGName} ${SD} ${Slice} ${Tag} ${Flags}
			# ...� � /etc/vfstab ����������� ������ ��� ���������� ������������ ��
			eval print "\#${VTOCTag} ${Dsk}	${RDsk}	${MountPoint}	${FSType}	${FSCKOrder}	${MountOnBoot}	-" >>/etc/vfstab
#			if [[ ${Volume} == "swapvol" && -z ${FirstSwap} ]]
#			then
#				eval FirstSwap=${Dsk}
#				SwapDsk=${PV_}
#			fi
		else
			print "\t\t"vxmksdpart -g ${DGName} ${SD} ${Slice} ${Tag} ${Flags}
		fi
	# ��������� � ���������� ����
	done

}

################################################################################
# ������� ������������� ��� �������������� ���� ����� � ���������� �����.
#
# ���������:
#	���������VxVM	��� ��������� �����
#	���������VxVM	����� ������ ����� cXtXdX ��� ���������� � ${DGName}
# ������������ ������� ����������:
# 	Force	���� �������� 0, �� � ��� ������, ���� ������ ��������� ����� �
#			������ ����� �� ����� �� ���������, �������������� �� ������������.
#		���� �������� 1, ���������� ������ ���� �� ���������� VolumeToProceed,
#		���� ���� ������ ��������� ����� � ������ ����� �� ����� �� ���������.
#		���� �������� 2, �� ���������� ��� ����.
# 
# ������������ ��������:
#	0	O.K.
#	1	������ ��������� ����� � ������ ����� �� ����� �� ��������� � All=0
#	2	������ ��� ���������� ������
#
function AddMirror
{
	Orig=$1
	Target=$2
	
	print "Mirroring disk ${Orig} to ${Target}"
	# ������, ����� ���� �������������
	ColVolumes ${Orig}

	if (( ${Force} == 2 ))
	then # ������� ����� "��� ����"
		VolumesToProceed="${Volumes}"
	elif [[ "${VolumesToProceed}" != "${Volumes}" ]]
	then # �� ����� ����� ���������� ����
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
	# ����������� ����
#	print "VolumesToProceed=${VolumesToProceed}"
	for Volume in ${VolumesToProceed}
	do	# ��� ���������� ������� ���������� vxassist
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
# ������� ������������� ��� �������� �������, ������� �� ��������� �����
#
# ���������:
#	���������VxVM	��� �����
# 
# ������������ ��������:
#	0	O.K.
#	1	��������� ����, ������� �� �����, ����� ������ ���� �����.
#		������� ������ �� �������.
#	2	������ �������� ������.
#
function RemoveMirror
{
	Orig=$1
	
	print "Removing mirrors from the disk ${Orig}"
	# ������, ����� ���� ����� �� �����
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
	# �������� ������ �������, ������� �� ��������� �����
	Plexes=$(vxprint -g ${DGName} -e"pl_subdisk.sd_dm_name == \"$Orig\"" -F"%plex")
	# ���������� Plex ��������� �� ������ ��������� �������.
	for Plex in ${Plexes}
	do  # ������� �������� ����� �� ����,..
		print "\tRemoving plex ${Plex}..."
		vxplex -g ${DGName} dis ${Plex}
		if (( $? != 0 ))
		then
			print "\tUnnable to dissociate ${Plex}."
			return 2
		fi
		# ...����� �������
		vxedit -g ${DGName} -rf rm ${Plex}
		if (( $? != 0 ))
		then
			print "\tUnnable to remove ${Plex}."
			return 2
		fi
	done
}

################################################################################
# ������� ������������� ��� �������� ����� �� �������� ������
#
# ���������:
#	���������VxVM	��� �����
# ������������ ��������:
#	0	O.K.
#	1	������ �������� �����.
#
function RemoveDisk
{
	Orig=$1
	print "Removing ${Orig} from ${DGName}"
	# ��� ������ �� ������, ������� ��. ������ ��� �� �����.
	vxedit -g ${DGName} rm ${Orig}Priv 2>/dev/null
	# ������� ���� �� ������...
	vxdg -g ${DGName} rmdisk ${Orig}
	if (( $? != 0 ))
	then
		print "\tUnnable to remove disk ${Orig} from ${DGName}."
		return 1
	fi
	# ...� ��������� ��� � ��������� ���������.
	vxdiskunsetup ${PV_}
	if (( $? != 0 ))
	then
		print "\tUnnable to remove disk ${Orig}."
		return 1
	fi
}

################################################################################
# ������� �������������� ���� � ��������� ��� � ������ ${DGName}
#
# ���������:
#	���������VxVM	��� �����
#	cXtXdX			���������� ��� �����
#
# ������������ ��������:
#	0	O.K.
#	1	������ ������������� �������������� ����, ������� �� �����, ����� ������ ���� �����.
#		������� ������ �� �������.
#	2	������ �������� ������.
#
function SetupDisk
{	# ������� �������������� ����,..
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
	# ����� ��������� ��� � ������ ${DGName}
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
# ������� ����������� ���������� ������� � ����
#	��������� subdisk, ����������� ����� ���� ���� (����� �� ���� ���������� �����)
#	� �������� ������� � ����� /etc/vfstab ������������� ������� ������ �����
#	�� /etc/system ��������� rootdev � ������
#	��������������� bootblock
#	DumpDevice ����������� �� swap ������� � ����� �����
#
# ���������:
#	���������VxVM	��� �����
#
# ������������ ��������:
#	0	O.K.
#	1	�� ������� ������������ �������� ������
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
# ������� ������������� dump device �� ������ ����� �� ������� ����� swapvol
#
# ������������ ������� ����������:
# 	Force -- ���� ���������� ����� 0, ��������� ������ ���������������� ���������,
#		 � ������ �� ��������.
#		���� �������� 1 -- dump ��������������� � ����� ������.
#		���� �������� ����� 2 -- dump ��������������� ������ ���
#			�� �� ��� ��������
#			�� ��� �������� �� �� ��� ������
#			�� ��� �������� �� swap
#
# ������������ ��������:
#	0	O.K.
#	1	������ ������������� �������������� ����, ������� �� �����, ����� ������ ���� �����.
#		������� ������ �� �������.
#	2	������ �������� ������.
#

function SetupDump
{
#set -x
	print "Configuring dump device..."
	# ���� subdisk'�, �� ������� ����� swapvol
	# � ���������� DumpDev ������ ������� ����
	# �������� (cXdXtXs4) �����������������4 �����
	DumpGhost=$(vxprint -g ${DGName} -se \
		"sd_pl_offset=1 && assoc.assoc=\"swapvol\"" \
		-F "%path %dev_offset %len\n")
	# dump_ghost ������ ��� ������������
	DumpDev=$(vxprint -g ${DGName} -se \
		"sd_pl_offset=0 && assoc.assoc=\"swapvol\" && \
		len >= assoc.assoc.len" \
		-F "%path %dev_offset %len\n")
	DumpDev="${DumpDev}\n${DumpGhost}"

	# � ���������� CurDump ������� dump device
	# � ���������� CurDumpDsk -- ��� ������ �������
	CurDump=$(nawk -F= '$1=="DUMPADM_DEVICE" { print $2 ; exit }' /etc/dumpadm.conf )
	CurDump=${CurDump##*/}
#	print "\tDump device is ${CurDump}."
	CurDumpDsk=${CurDump%s*}

	# ���� �������, �� ������� ��������� swapvol
	# ��������� ������� ���������� DumpDev
	# � SwapDevs ������� ��������� �������
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
			# ������ ����� ������������
			Offset=0
			(( Len = Len + 1 ))
		fi
		Dev=${Dev##*/}
		Dev=${Dev%s*}
		# ��������� ������� ��������
		VTOC=$(prtvtoc -h /dev/dsk/${Dev}s2)
		# ���� public region � ���������� ��� ��������
		PubOffset=$(print "${VTOC}" | nawk '$2=="14" { print $4 ; exit}')
		# �������� �������� ���� �� ����� ����� �����
		(( Offset =	Offset + PubOffset ))
		# ���� ������ swap, ���������� ��� �����, �������� � �����
		set -A Swap $(print "${VTOC}" | nawk -v O=${Offset} '$2=="3" && $4==O { print $0 ; exit}')
		if [[ -n ${Swap[3]} && -n ${Swap[4]} ]]
		then
			if (( ${Swap[3]} == $Offset && ${Swap[4]} >= ${Len} ))
			then # ��, �������� ���������, ����� ����
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

	# � ����� ��������� ���� ������� dump device
	# ���������� Slice ��������� �� �������� �� swap
	SliceMismatch=
	for Slice in ${SwapDevs}
	do
		SwapDsk=${Slice%s*}
		if [[ ${Slice} == ${CurDump} ]]
		then # Dump ��������� � ����� �� swap'��
			print "\tDump device is already on swap slice $Slice on disk ${DumpDiskName}."
			return 0
		elif [[ ${SwapDsk} == ${CurDumpDsk} ]]
		then # Dump �� ��������� � �������� swap, �� ��������� �� ����� �����,
			# ���� ���� �������
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
	then # �������� ������ �� ����, �� ����� ������������ ������!
		print "\tWarning! Slice ${SwapDevs%% *} on disk ${DumpDiskName} should be configured as dump device manually."
		print "\tUse setupdump option."
	else # Dump ����� �� ��������� �����, � �������� ������ ���-���� �� ����
		print "\tDump device configured on dedicated slice ${CurDump} on disk ${DumpDiskName}."
		print "\tIf You want to change it to ${SwapDevs%% *}, use setupdump option."
	fi
}

################################################################################
################################################################################
# ��������� ��������� ��������� ������ � ���������� ����������� ��������
# ����� ������, ��� ��������
if (( $# == 0 ))
then
	Usage
fi


while (( $# > 0 ))
do	# ������ �������� ������ ���� �������� ������, ������ ������ �����.
	# ��� �������� ����� � dump'� ��� ����� ��������� �� �����������,
	# � ��������� ������ Shift ����� ��������� � 1.
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
			Force=0 # � ��� ������, ���� ������ ��������� ����� �
			# ������ ����� �� ����� �� ���������, �������������� �� ������������.
			if [[ $2 == "-all" ]]
			then # ���������� ��� ����.
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
			Force=0 # � ��� ������, ���� ������ ��������� ����� �
			# ������ ����� �� ����� �� ���������, �������������� �� ������������.
			if [[ $2 == "-all" ]]
			then # ���������� ��� ����.
				Force=2
				shift
			fi
			if [[ $2 == "-force" ]]
			then # ���������� ������ ��������� ����,
				# ���� ���� �� ����� ����� ������.
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
			Force=1 # ���������� ������ ��������� ����, ����� force � ��� VTOC
			if [[ $2 == "-all" ]]
			then # ���������� ��� ����.
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
