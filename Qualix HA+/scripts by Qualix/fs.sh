#!/bin/sh
#
# Copyright (c) 1996 Qualix Group, Inc. All Rights Reserved.
#
# $Id: fs.sh.m,v 1.17 1998/12/12 02:35:09 vlp Exp $
#
#

# BINDIR and TABDIR are passed down from parent
[ -z "${BINDIR}" ] && BINDIR="`pwd`/../../bin"
[ -z "${TABDIR}" ] && TABDIR="`pwd`"
SGID="`basename ${TABDIR}`"

fsck=/usr/sbin/fsck
mount=/usr/sbin/mount
umount=/usr/sbin/umount
fuser=/usr/sbin/fuser
mkdir="/bin/mkdir -p"
rm="/bin/rm -f"
cat=/bin/cat
sort=/usr/bin/sort
uniq=/usr/bin/uniq

console=/var/adm/messages

tsort=/usr/ccs/bin/tsort
lockd=/usr/lib/nfs/lockd

qmount=${BINDIR}/qmount.sh
qumount=${BINDIR}/qumount.sh

df=/usr/sbin/df
[ -x ${df} ] || df=/usr/bin/df
[ -x ${df} ] || df=df

share=/usr/sbin/share
[ -x ${share} ] || share=share

unshare=/usr/sbin/unshare
[ -x ${unshare} ] || unshare=unshare

scsi_check=${BINDIR}/scsi-check.sh
[ -x ${scsi_check} ] || scsi_check=""

#Volume script and table file definitions (the default is ${type}.sh/${type}.tab)
vol_sds_tab=sds.ds.tab
vol_sds_script=sds.ds.sh
vol_vxvm_tab=vxvm.dg.tab
vol_vxvm_script=vxvm.dg.sh
#clariion works with default

LIST_TO_TSORT_SED='
s/\([^,][^,]*\)/\1  \1/g
s/^\([^ ][^ ]*\)  *\(.*\)  *\([^ ][^ ]*\)$/\2  \1,\3/
s/^  //
s/,/ /g
'

# clean up temp files
cleanup()
{
  ${rm} /tmp/QHA.$$.*
}

# execee $1=from_info $2=command $3=arg1 $4=arg2 ...
# execute and echo on error,
# if any errors happen will print messages indicading so
execee()
{
  execee_from_info="$1"
  shift
  "$@"
  execee_status=$?
  if [ ${execee_status} -ne 0 ]
  then
    echo "${execee_from_info}: failed to '$@' (returned ${execee_status})."
  fi
  return ${execee_status}
}

killproc() {            # kill the named process(es)
        pid=`/usr/bin/ps -e |
             /usr/bin/grep $1 |
             /usr/bin/sed -e 's/^  *//' -e 's/ .*//'`
        [ "$pid" != "" ] && kill $pid
}

#check_executable $1=from_info $2=file
#checks whether the file exists
#sets execute permission
check_executable () {
  if [ ! -f "$2" ]
  then
    echo "$1: File '$2' does not exist"
    return 1
  fi

  [ -x "$2" ] || chmod +x "$2"
  return 0
}

fs_is_shared()
{
  mpoint=$1

  ${share} | tr -s ' ' | cut -d' ' -f2 | grep "^${mpoint}$" > /dev/null 2>&1

  return $?
}

fs_unshare()
{
  mpoint=$1

  ${unshare} ${mpoint}

  return $?
}

fs_print()
{
  mpoint=$1

  ${df} -k ${mpoint}

  return $?
}

fs_check()
{
  bdev=$1

  ${mount} -p | cut -f1 -d ' ' | grep "^${bdev}$" > /dev/null 2>&1

  return $?
}

fs_quota_on()
{
  bdev=$1

  grep "^${bdev}" /etc/mnttab | cut -f 4 | egrep -c "^quota|,quota" > /dev/null
  status=$?
  if test "${status}" -eq 0
  then
    /usr/sbin/quotacheck ${bdev}
    echo "Turning on UFS quota: ${bdev} \c"
    /usr/sbin/quotaon ${bdev}
    echo "done."
  fi

  return 0
}

fs_quota_off()
{
  bdev=$1

  grep "^${bdev}" /etc/mnttab | cut -f 4 | egrep -c "^quota|,quota" > /dev/null
  status=$?
  if test "${status}" -eq 0
  then
    echo "Turning off UFS quota: ${bdev} \c"
    /usr/sbin/quotaoff ${bdev}
    echo "done."
  fi

  return 0
}

#get_volume_info $1=voltype
#sets up voltab the volume table file and volscript the volume script file
get_volume_info()
{
  eval volscript=\${BINDIR}/\${vol_$1_script:-$1.sh}
  eval voltab=\${TABDIR}/\${vol_$1_tab:-$1.tab}
}

fs_online()
{
  bdev=$1
  rdev=$2
  mpoint=$3
  fstype=$4
  moptions=$5

  if test "X${fstype}" = "X" -o "X${fstype}" = "X-"
  then
    fstype="ufs"
  fi
  
  mount_flags="-F ${fstype}"
  case "${fstype}" in
    'vxfs')
	fsck_preen_flags="-F ${fstype}"
	fsck_force_flags="-F ${fstype} -y -o full"
        #mount_flags="${mount_flags}"	# add more to mount_flags
	;;
    'jfs')
	fsck_preen_flags="-fp"
	fsck_force_flags="-y"
        #mount_flags="${mount_flags}"	# add more to mount_flags
	;;
    'hfs')
	fsck_preen_flags="-F ${fstype} -P"
	fsck_force_flags="-F ${fstype} -y -f"
        #mount_flags="${mount_flags}"	# add more to mount_flags
	;;
    'nfs')
	fsck_preen_flags="-"
	fsck_force_flags="-"
        #mount_flags="${mount_flags}"	# add more to mount_flags
	;;
    *)
	fsck_preen_flags="-F ${fstype} -o p"
	fsck_force_flags="-F ${fstype} -y -o f"
        #mount_flags="${mount_flags}"	# add more to mount_flags
	;;
  esac
    
  if test "${fsck_preen_flags}" != "-"
  then
    echo "fs_online($*): checking device=${rdev} (preen mode) ..."
    ${fsck} ${fsck_preen_flags} ${rdev}
    status=$?
    if test "${status}" -ne 0 -a "${status}" -ne 40	# 40 is OK, see 'man fsck'
    then
      echo "fs_online($*): re-checking device=${rdev} (force mode) ..."
      ${fsck} ${fsck_force_flags} ${rdev}
      status=$?
      if test "${status}" -ne 0 -a "${status}" -ne 40	
      then
        echo "ERR: fs_online($*) failed to fsck device=${rdev}"
        return 1
      fi
    fi
  fi

  mntopts=""
  if test "X${moptions}" = "X" -o "X${moptions}" = "X-"
  then
    :
  else
    mntopts="${mntopts} -o ${moptions}"
  fi

  if test -x ${qmount}
  then
    ${qmount} ${mount} ${mount_flags} ${mntopts} ${bdev} ${mpoint}
  else
    ${mount} ${mount_flags} ${mntopts} ${bdev} ${mpoint}
  fi
  status=$?
  if test "${status}" -ne 0
  then
    echo "ERR: fs_online($*) failed to mount device=${bdev} to mount point=${mpoint}"
    return 1
  fi

  fs_quota_on ${bdev}
  status=$?
  if test "${status}" -ne 0
  then
    echo "ERR: fs_online() failed to turn on quota for device=${bdev}."
    return 1
  fi

  fs_print ${mpoint}

  return 0
}

fs_offline()
{
  bdev=$1
  rdev=$2
  mpoint=$3
  fstype=$4

  # check to see if raw device is accessible
  if test -n "${scsi_check}"
  then
    ${scsi_check} "$@"
    status="$?"
    if test "${status}" -ne 0
    then
      echo "fs_offline($*): rdev=${rdev} is not accessible."
      echo "  Abort un-mounting procedure."
      echo "  Will attemp to panic this server to release the shared disk."
      f=${BINDIR}/ha_panic.sh
      if test -x ${f}
      then
	${f} -nosync
      else
	echo "Cannot panic. Cannot find file=${f}."
	return 1
      fi
    fi
  fi

  fs_quota_off ${bdev}
  status=$?
  if test "${status}" -ne 0
  then
    echo "ERR: fs_offline() failed to turn off quota for device=${bdev}."
    return 1
  fi

  if test -f ${qumount}
  then
    ${qumount} ${mpoint}
    status=$?
    if test "${status}" -ne 0
    then
      echo "fs_offline(qumount.sh): Cannot un-mount mount point=${mpoint} ..."
      return 1
    else
      echo "fs_offline($*): mount point=${mpoint} is unmounted."
      return 0
    fi
  else
    # Try 5 times
    for i in 1 2 3 4 5
    do
      echo "fs_offline(attempt #$i): Trying kill all processes using mount point=${mpoint} ..."
      ${fuser} -cku ${mpoint}
      #${fuser} -cu ${mpoint}
  
      ${umount} ${mpoint}
      status=$?
      if test "${status}" -ne 0
      then
        # It is possible that lockd is causing the file system to be hung ...
        killproc `basename ${lockd}`
        ${umount} ${mpoint}
        status=$?
	${lockd} >> ${console} 2>&1
        if test "${status}" -eq 0
        then
          echo "fs_offline(attempt #$i): mount point=${mpoint} is unmounted."
          return 0
        fi
      else
        echo "fs_offline(attempt #$i): mount point=${mpoint} is unmounted."
        return 0
      fi
      sleep 1
    done

    echo "fs_offline(attempt #$i): Cannot un-mount mount point=${mpoint} ..."
    return 1
  fi

  return 1
}

fs_check_all_unmounted()
{
  [ -s $1 ] || return 0

  cat $1 | grep -v '^[ \t]*#' | tr '\011' ' ' | tr -s ' \011' | sort +2 | (
    while read bdev rdev mpoint fstype voltype moptions junk
    do
      [ "X${bdev}" = "X" -o "X${bdev}" = "X-" ] && continue

      if fs_check ${bdev}
      then
        echo "fs.sh: fs_check_all_unmounted($*) mount point ${mpoint} is still mounted."
        return 1
      fi
    done

    return 0
  )

  return $? 
}

unshare_nfs()
{
  if test -d ${TABDIR}/nfs.d
  then
    svcdir=${TABDIR}/nfs.d
    tabs="${svcdir}/dfstab ${svcdir}/dfs.tab"
    dfstab=""

    for tab in ${tabs}
    do
      if test -f ${tab}
      then
        dfstab=${tab}
        break
      fi
    done

    if test -z "${dfstab}"
    then
      echo "Cannot find shared file system information in any of:"
      echo "${tabs}"
    else
      cat ${dfstab} | egrep '^[^#]' | awk '{print $NF}' | (
        while read fs junk
        do
          unshare ${fs}
        done
      )
    fi
  fi
  return 0
}

share_nfs()
{
  if test -d ${TABDIR}/nfs.d
  then
    svcdir=${TABDIR}/nfs.d
    tabs="${svcdir}/dfstab ${svcdir}/dfs.tab"
    dfstab=""

    for tab in ${tabs}
    do
      if test -f ${tab}
      then
        dfstab=${tab}
        break
      fi
    done

    if test -z "${dfstab}"
    then
      echo "Cannot find shared file system information in any of:"
      echo "${tabs}"
    else
      sh ${dfstab}
    fi
  fi
  return 0
}

do_start()
{
  table=$1
  temp_list="/tmp/QHA.$$.list /tmp/QHA.$$.tlist /tmp/QHA.$$.sorted"
  ${rm} ${temp_list}
  touch ${temp_list}

  cat ${table} | grep -v '^[ \t]*#' | tr '\011' ' ' | tr -s ' \011' | sort +2 | (
    rv=0

    while read bdev rdev mpoint fstype voltype moptions junk
    do
      [ -n "${bdev}" ] || continue

      if [ "X${voltype}" != 'X-' ]
      then
	echo "${voltype}" | tr ',' '\n' >> /tmp/QHA.$$.list
	echo "${voltype}" | sed -e "${LIST_TO_TSORT_SED}" >> /tmp/QHA.$$.tlist
	[ `expr "${voltype}" : ".*,"` -ne 0 ] && rv=1
      fi

      [ "${bdev}" != "-" ] || continue

      if [ ! -d "${mpoint}" ]
      then
	echo "fs.sh: Mount point=${mpoint} does not exist. Creating mount point..."
	execee "fs.sh: do_start($*)" ${mkdir} ${mpoint} || return 2
      fi

      if fs_check ${bdev}
      then
	echo "fs.sh: do_start($mpoint) mount point=${mpoint} is already mounted."
	continue
      fi
    done 

    return ${rv}
  )
  status=$?

  case ${status} in
    0)
      ${cat} /tmp/QHA.$$.list | ${sort} | ${uniq} > /tmp/QHA.$$.sorted
      ;;
    1)
      if [ ! -x ${tsort} ]
      then
	echo "fs.sh: Must have tsort (${tsort}) in order to have dependendcies in volume types."
	return 1
      fi
      ${cat} /tmp/QHA.$$.tlist | ${tsort} > /tmp/QHA.$$.sorted
      ;;
    *)
      ${rm} ${temp_list}
      return 1
      ;;
  esac

  cat /tmp/QHA.$$.sorted | (
    while read voltype junk
    do
      get_volume_info $voltype

      check_executable "fs.sh: do_start($*)" ${volscript}
      if [ $? -ne 0 ]
      then
        echo "fs.sh: do_start($*): volume script for volume ${voltype} does not exist (maybe invalid volume)."
	return 1
      fi

      if [ ! -f ${voltab} ]
      then
        echo "fs.sh: do_start($*): table ${voltab} for volume ${voltype} does not exist."
	return 1
      fi

      execee "fs.sh: do_start($*): Starting volume ${voltype}" ${volscript} ${voltab} start || return 1

    done

    return 0
  )
  if [ $? -ne 0 ]
  then
    echo "fs.sh: do_start($*): failed to bring up volumes."
    ${rm} ${temp_list}
    return 1
  fi
  
  ${rm} ${temp_list}

  cat ${table} | grep -v '^[ \t]*#' | tr '\011' ' ' | tr -s ' \011' | sort +2 | (
    while read bdev rdev mpoint fstype voltype_list moptions junk
    do
      [ -n "${bdev}" -a "${bdev}" != "-" ] || continue

      if [ ! -d "${mpoint}" ]
      then
	echo "fs.sh: Mount point=${mpoint} does not exist. Creating mount point..."
	execee "fs.sh: do_start($*)" ${mkdir} ${mpoint} || return 2
      fi

      if fs_check ${bdev}
      then
	echo "fs.sh: do_start($mpoint) mount point=${mpoint} is already mounted."
	continue
      fi

      fs_online ${bdev} ${rdev} ${mpoint} ${fstype} ${moptions}
      if [ $? -ne 0 ]
      then
	echo "fs.sh: do_start($*) failed to bring file system ${mpoint} online."
	return 1
      fi
    done

    return 0
  ) || return 1

  # For compatibility
  if test ! -f ${TABDIR}/nfs.d/pre_ifup
  then
    share_nfs || return 1
  fi

  return 0
}
  

do_stop()
{
  # For compatibility
  if test ! -f ${TABDIR}/nfs.d/post_ifdown
  then
    unshare_nfs
  fi

  temp_list="/tmp/QHA.$$.list /tmp/QHA.$$.tlist /tmp/QHA.$$.fsorted /tmp/QHA.$$.sorted"
  ${rm} ${temp_list}
  touch ${temp_list}

  table=$1
  cat ${table} | grep -v '^[ \t]*#' | tr -s '\011' ' ' | tr -s ' \011' | sort -r +2 | (
    rv=0

    while read bdev rdev mpoint fstype voltype moptions scsilist junk
    do
      [ -n "${bdev}" ] || continue

      if [ "X${voltype}" != 'X-' ]
      then
	echo "${voltype}" | tr ',' '\n' >> /tmp/QHA.$$.list
	echo "${voltype}" | sed -e "${LIST_TO_TSORT_SED}" >> /tmp/QHA.$$.tlist
	[ `expr "${voltype}" : ".*,"` -ne 0 ] && rv=1
      fi

      [ "${bdev}" != "-" ] || continue

      # It is been reported that if there is an problem with disk cable,
      # the following test will fail. BUT ... unmount will succeed. So ...
      # if the following test fail, print error but do go on.
      if [ ! -d "${mpoint}" ]
      then
	echo "fs.sh: do_stop($mpoint): directory ${mpoint} does not exist."
	#continue;
      fi

      fs_check ${bdev}
      if [ $? -ne 0 ]
      then
	echo "fs.sh: do_stop($mpoint): mount point ${mpoint} is not mounted."
	continue
      fi

      #this should (it doesn't now) check and unshare any shared directories under ${mpoint}
      if fs_is_shared ${mpoint}
      then
	fs_unshare ${mpoint}
      fi

      fs_offline ${bdev} ${rdev} ${mpoint} ${fstype} ${voltype} ${moptions} ${scsilist} ${junk}
      if [ $? -ne 0 ]
      then
	echo "fs.sh: do_stop($*): failed to bring file system ${mpoint} offline."
	return 2
      fi

    done

    return ${rv}
  )
  status=$?

  case ${status} in
    0)
      ${cat} /tmp/QHA.$$.list | ${sort} | ${uniq} > /tmp/QHA.$$.fsorted
      ;;
    1)
      if [ ! -x ${tsort} ]
      then
	echo "fs.sh: Must have tsort (${tsort}) in order to have dependendcies in volume types."
	return 1
      fi
      ${cat} /tmp/QHA.$$.tlist | ${tsort} > /tmp/QHA.$$.fsorted
      ;;
    *)
      ${rm} ${temp_list}
      return 1
      ;;
  esac

  cat -n /tmp/QHA.$$.fsorted | sort -r | sed -e 's/^[^	]*	//' > /tmp/QHA.$$.sorted

  cat /tmp/QHA.$$.sorted | (
    while read voltype junk
    do
      get_volume_info $voltype

      check_executable "fs.sh: do_stop($*)" ${volscript}
      if [ $? -ne 0 ]
      then
        echo "fs.sh: do_stop($*): volume script for volume ${voltype} does not exist (maybe invalid volume)."
	return 1
      fi

      if [ ! -f ${voltab} ]
      then
        echo "fs.sh: do_stop($*): table ${voltab} for volume ${voltype} does not exist."
	return 1
      fi

      execee "fs.sh: do_stop($*): Stopping volume ${voltype}" ${volscript} ${voltab} stop || return 1

    done

    return 0
  )
  if [ $? -ne 0 ]
  then
    echo "fs.sh: do_stop($*): failed to bring down volumes."
    ${rm} ${temp_list}
    return 1
  fi
  
  ${rm} ${temp_list}

  # Sanity check
  fs_check_all_unmounted ${table}
  if [ $? -ne 0 ]
  then
    echo "fs.sh: do_stop($*): some shared mount point is still mounted."
    return 1
  fi

  return 0
}


case "$#" in
  2)
    fstab=$1
    command=$2
    ;;
  1)
    fstab="${TABDIR}/fs.tab"
    command=$1
    ;;
  *)
    echo "Usage: $0 [fs_table] (start | stop)"
    exit 1
    ;;
esac

if [ ! -r "${fstab}" ]
then
  echo "$0: File=${fstab} is not readable."
  exit 1
fi

#clean up temp files if we get some signals (we might be hanging)
trap 'cleanup;exit 1' 1 2 15

case "$command" in
  'start')
    echo ""
    echo "###" 
    echo "### sg=${SGID} - Trying to mount file systems ..."
    echo "###" 
    echo ""
    do_start ${fstab}
    status=$?
    if test "$status" -eq 0
    then
      echo ""
      echo "###"
      echo "### sg=${SGID} - Mounted file systems successfully."
      echo "###"
      echo ""
    else
      echo ""
      echo "###"
      echo "### sg=${SGID} - Failed to mount file systems."
      echo "###"
      echo ""
    fi
    exit $status
    ;;

  'stop')
    echo ""
    echo "###"
    echo "### sg=${SGID} - Trying to un-mount file systems ..."
    echo "###"
    echo ""
    do_stop ${fstab}
    status=$?
    if test "$status" -eq 0
    then
      echo ""
      echo "###"
      echo "### sg=${SGID} - Un-mounted file systems successfully."
      echo "###"
      echo ""
    else
      echo ""
      echo "###"
      echo "### sg=${SGID} - Failed to un-mount file systems."
      echo "###"
      echo ""
    fi
    exit $status
    ;;
  
  *)
    echo "Usage: $0 [fs_table] (start | stop)"
    exit 1
    ;;
esac

exit 0
