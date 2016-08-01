#!/bin/sh
##
## clone
##
## Takes on-line copy of the running OS to a spare "clone" disk.
## Data is copied via mirroring volumes by Volume Manager
##
## Central assumptions:
## 1) A disk in rootdg is called "clone" (case sensitive match)
## 2) No volumes are defined on "clone"
##
#
# Slices for copy to clone by this script: /, /var
#
# 
##### number of slices #####
rootslice=0
swapslice=1
varslice=6
############################


echo `date '+%m/%d/%y %H:%M:%S'` --- Start create disk clone
TargetDiskEnclosure=`vxprint -g rootdg -F"%device_tag" clone`
if [ -z "$TargetDiskEnclosure" ] ; then
echo "WARNING: No disk found matching the name \"clone\"."
echo "Unable to continue."
exit 2
fi
vols=`vxprint -Q -g rootdg -e"pl_sd.sd_dm_name == \"clone\"" -F"%vol"`
if [ -n "$vols" ] ; then
echo "WARNING: Volumes found on \"clone\" disk."
echo "Unable to continue."
exit 2
fi

vxdisk list ${TargetDiskEnclosure}>/tmp/disk_clone_num$
TargetDisks=`nawk '$2 == "state=enabled" {print substr($1,1,length($1)-2)}' /tmp/disk_clone_num$`
TargetDisk=`echo "$TargetDisks" | while read DISK_LINE
do echo $DISK_LINE;break;done`

PATH=/usr/sbin:/usr/bin:$PATH
echo Name of clone disk: $TargetDiskEnclosure : $TargetDisk

### Removing sundisk DO_NOT_USE
vxedit rm DO_NOT_USE

### Initialize disk
vxdg rmdisk clone
/usr/lib/vxvm/bin/vxdisksetup -i $TargetDiskEnclosure
vxdg adddisk clone=$TargetDiskEnclosure

##### Mirroring data #####
date '+%m/%d/%y %H:%M:%S'
echo Mirroring root...
/etc/vx/bin/vxrootmir clone
date '+%m/%d/%y %H:%M:%S'
echo Mirroring swap...
vxassist -g rootdg mirror swapvol clone
date '+%m/%d/%y %H:%M:%S'
echo Mirroring /var...
vxassist -g rootdg mirror var clone
date '+%m/%d/%y %H:%M:%S'

##### Creating the underlying partitions #####
# swap
/usr/lib/vxvm/bin/vxmksdpart -g rootdg clone-02 $swapslice 0x03 0x01
# /var
/usr/lib/vxvm/bin/vxmksdpart -g rootdg clone-03 $varslice 0x07 0x00
# /arch
#/usr/lib/vxvm/bin/vxmksdpart -g rootdg clone-04 $archslice 0x08 0x00

##### Deleting clone slices #####
vxplex -o rm dis rootvol-03 swapvol-03 var-03

fsck -y /dev/dsk/${TargetDisk}s${rootslice}
fsck -y /dev/dsk/${TargetDisk}s${rootslice}
fsck -y /dev/dsk/${TargetDisk}s${rootslice}
fsck -y /dev/dsk/${TargetDisk}s${varslice}
fsck -y /dev/dsk/${TargetDisk}s${varslice}
fsck -y /dev/dsk/${TargetDisk}s${varslice}
### Mount on tmp mount point
mkdir -p /tmp/_clone/root
mount /dev/dsk/${TargetDisk}s${rootslice} /tmp/_clone/root

##### Tweak system config files #####
## /etc/system
mv /tmp/_clone/root/etc/system /tmp/_clone/root/etc/system.pre_clone
sed -e '/vol_rootdev_is_volume/d' -e '/rootdev:/d' /tmp/_clone/root/etc/system.pre_clone > /tmp/_clone/root/etc/system
## /etc/vfstab
mv /tmp/_clone/root/etc/vfstab /tmp/_clone/root/etc/vfstab.pre_clone
cat > /tmp/_clone/root/etc/vfstab <<EOVFSTAB
/dev/dsk/${TargetDisk}s${rootslice} /dev/rdsk/${TargetDisk}s${rootslice} / ufs 1 no -
/dev/dsk/${TargetDisk}s${swapslice} - - swap - no -
/dev/dsk/${TargetDisk}s${varslice} /dev/rdsk/${TargetDisk}s${varslice} /var ufs 1 no -
swap - /tmp tmpfs - no -
/proc - /proc proc - no -
#/dev/vx/dsk/cboss/orahome	/dev/vx/rdsk/cboss/orahome	/ora817	ufs	2	yes	logging
#/dev/vx/dsk/fcal/arch	/dev/vx/rdsk/fcal/arch	/arch	ufs     2	yes	logging
#/dev/vx/dsk/fcal/test	/dev/vx/rdsk/fcal/test	/test	ufs	2	yes	logging
#/dev/vx/dsk/fcal/fsrv	/dev/vx/rdsk/fcal/fsrv	/test	ufs	2	yes	logging
EOVFSTAB
### umount tmp space
umount /tmp/_clone/root

### Reserve clone disk by creating subdisk DO_NOT_USE
vxmake sd DO_NOT_USE dmname=clone dmoffset=0 len=`vxdg -g rootdg free clone|awk '$1 == "clone" {print $5}'` comment="Do not delete or relocate this subdisk."

echo `date '+%m/%d/%y %H:%M:%S'` --- Create disk clone complete
exit 0


