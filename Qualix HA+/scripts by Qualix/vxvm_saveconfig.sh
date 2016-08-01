#!/bin/sh
######################################################################
#
# Program:
# --------
# vxvm_saveconfig.sh            Release 1.1.2
#
# Copyright (c) 1996-98 FullTime Software, Inc.
# All Rights Reserved Worldwide.
#
# $Id: vxvm_saveconfig.sh,v 1.1 1999/02/04 07:30:16 vlp Exp $
#
# Description:
#       This program searches for all disks under the control of VxVM
#       and saves the raw images of the configuration database. These
#       image files are useful for recovery from corrupted databases.
#
#       This script also creates a text file of the configuration
#       database which can be used for recovery in conjunction
#       with vxmake.
#
#       Please run this script after making changes to the
#       VxVM configuration.
#
# Usage:
#       vxvm_saveconfig.sh <diskgroup>
#
# Suggested usage (Bourne or Korne shell):
#       vxvm_saveconfig.sh <diskgroup> > <diskgroup>.`/bin/uname -n`.log 2>&1
#
# Suggested usage (C-shell):
#       vxvm_saveconfig.sh <diskgroup> >& <diskgroup>.`/bin/uname -n`.log
#
# Returns:
#       ./<diskgroup>.`/bin/uname -n`.tar.Z
#
######################################################################

AWK="/bin/awk"
BASENAME="/bin/basename"
CHMOD="/bin/chmod"
COMPRESS="/bin/compress"
DD="/bin/dd"
ECHO="echo"
GREP="/bin/grep"
LS="/bin/ls"
MKDIR="/bin/mkdir"
PRTVTOC="/usr/sbin/prtvtoc"
RM="/bin/rm"
SED="/bin/sed"
TAR="/usr/sbin/tar"
UNAME="/bin/uname"
VXDG="/usr/sbin/vxdg"
VXDISK="/usr/sbin/vxdisk"
VXPRINT="/usr/sbin/vxprint"

$ECHO ""
$ECHO " The configuration database is stored on every VxVM managed disk."
$ECHO " To determine which slice holds the configuration database, one"
$ECHO " needs to run 'prtvtoc' and look for the slice with tag 15.  Then"
$ECHO " one compares this slice to the priv_cpath field from the output of"
$ECHO " 'vxprint -g <diskgroup> -m'. The two should match. In case they"
$ECHO " do not, one will want to report this to the vendor."
$ECHO ""
$ECHO " If VxVM is unable to find any copy of the configuration"
$ECHO " databases, it will not be able to import the diskgroup or start"
$ECHO " up volumes. This may happen if the VxVM database is corrupted."
$ECHO ""
$ECHO " This script will make a backup copy of all the configuration slices"
$ECHO " which may be used at a later time to recover from database corruption."

if [ "$#" -ne 1 ]; then
        $ECHO ""
        $ECHO "Usage:"
        $ECHO " `$BASENAME $0` <diskgroup>"
        $ECHO ""
        exit 1
fi

DISKGROUP=$1

IMPORTED=`$VXDG list | $GREP "^$DISKGROUP[ \t]"`
if [ -z "$IMPORTED" ]; then
   $ECHO ""
   $ECHO "The diskgroup $DISKGROUP is not imported."
   exit 1
fi

#
# Get all VM disks in diskgroup.
#
DESTNAME="${DISKGROUP}.`$UNAME -n`"

if [ -f "./$DESTNAME.tar.Z" ]; then
   $ECHO ""
   $ECHO "./$DESTNAME.tar.Z exists; bye."
   exit 1
fi

if [ ! -d "./$DESTNAME" -a ! -f "./$DESTNAME" ]; then
   $MKDIR ./$DESTNAME
else
   $ECHO ""
   $ECHO "./$DESTNAME exists; bye."
   exit 1
fi

vmdisks=`$VXDISK -g $DISKGROUP list | $AWK '{print $1}' | $GREP -v DEVICE`

#
# Locate the configuration slice in VTOC and compare it to VxVM database.
# They should match.
#
for x in $vmdisks; do
        #
        # Remove slice info, leaving c1t1d0
        #
        disk=`$ECHO $x | $SED 's/s.*//'`

        #
        # Locate slice with tag 15 from output of prtvtoc
        #
        vtoc_config_slice=`$PRTVTOC /dev/rdsk/$x  | $GREP -v "*" | \
                $AWK '$2 == 15 {print $1}'`

        vtoc_config_slice=`$ECHO ${disk}s${vtoc_config_slice}`
        #
        # <Sample output>       priv_cpath="/dev/rdsk/c1t1d0s3"
        #
        vmdb_config_slice=`$VXPRINT -g $DISKGROUP -m | $GREP priv_cpath | \
                           $GREP $disk | $AWK -F\" '{print $2}' | \
                           $SED -e 's#/dev/rdsk/##' -e 's#/dev/vx/rdmp/##'` 

        if [ "$vtoc_config_slice" = "$vmdb_config_slice" ]; then
                $ECHO ""
                $ECHO "Configuration slice $vmdb_config_slice matches ..."
                $ECHO "Copying /dev/rdsk/$vmdb_config_slice to" \
                  "./$DESTNAME/$vmdb_config_slice ..."
                $DD if=/dev/rdsk/$vmdb_config_slice \
                       of=./$DESTNAME/$vmdb_config_slice
                $ECHO "Done."
                $ECHO "To restore use:"
                $ECHO "$DD of=./$DESTNAME/$vmdb_config_slice" \
                              "if=/dev/rdsk/$vmdb_config_slice"
        else
                $ECHO ""
                $ECHO "ERROR: Configuration slices do not match:"
                $ECHO "ERROR: vtoc_config_slice=$vtoc_config_slice"
                $ECHO "ERROR: vmdb_config_slice=$vmdb_config_slice"
                # exit 1
        fi
done
$ECHO ""
$ECHO "(After restoring a slice, use 'vxdg -tfC import $DISKGROUP')"

FILE="$DISKGROUP.vxmake"
$ECHO ""
$ECHO "Now creating a text file configuration of the diskgroup $DISKGROUP ..."
$ECHO "(This file can be used in 'vxmake -d $FILE' to recreate"
$ECHO "volume, plex, and subdisk objects.  It will *not* recreate"
$ECHO "diskgroup or vmdisk objects.)"
$VXPRINT -g $DISKGROUP -vpshm > ./$DESTNAME/$FILE
$ECHO "Done.  Saved in file ./$DESTNAME/$FILE."
$ECHO ""

$ECHO "Making the tar'ed and compress'ed archive ..."
$TAR -cvf - ./$DESTNAME | $COMPRESS > $DESTNAME.tar.Z
$CHMOD 600 $DESTNAME.tar.Z
$RM -rf ./$DESTNAME

$ECHO ""
$ECHO "Done:"
$ECHO "-----"
$ECHO `$LS -l $DESTNAME.tar.Z`
$ECHO ""
$ECHO "Please backup $DESTNAME.tar.Z, it may be needed someday."
$ECHO "Remember to run this script everytime changes are made to"
$ECHO "the VxVM configuration."
$ECHO ""

exit 0 
