#!/bin/sh
#
# Copyright (c) 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: scsi-check.sh.m,v 1.1 1999/02/18 23:22:52 vlp Exp $
#

f=/usr/sbin/vxdg
if test -f ${f}
then
  vxdg=${f}
else
  vxdg=vxdg
fi

first_executable_in_list()
{
  for i
  do
    [ -x "${i}" ] && break
  done
  echo $i
}

dir="`dirname $0`"
[ -n "${BINDIR}" ] || BINDIR=$dir

checker=`first_executable_in_list ./scsiinfo.sh ${BINDIR}/scsiinfo.sh ${dir}/scsiinfo.sh ./scsi-check ${BINDIR}/scsi-check ${dir}/scsi-check scsi-check`

usage()
{
  echo "Usage: $0 [fs_table]"
}




is_vxvm()
{
  rv="`expr $1 : '/dev/vx/.*'`"
  return $?
}

is_sds()
{
  rv="`expr $1 : '/dev/md/.*'`"
  return $?
}

is_qds()
{
  rv="`expr $1 : '/dev/rdsk/qds.*'`"
  return $?
}

do_vxvm_dev()
{
  d=$1
  get_dg ${d}
  if test X"${rv}" = "X"
  then
    echo "Device=${d} is NOT a VxVM raw device."
    exit 1
  else
    dg=${rv}
  fi

  get_disks ${dg}
  if test X"${rv}" = "X"
  then
    echo "Cannot find any physical disk for dg=${dg}."
    exit 1
  else
    disks=${rv}
  fi

  echo "For diskgroup=${dg}, checking the following disks ..."
  for d in ${disks}
  do
    echo "  disk=${d}"
    ${checker} ${d}
    status=$?
    if test "${status}" -ne 0
    then
      return 1
    fi
  done

  return 0
}

do_sds_dev()
{
  echo "${myname}: (Warning) does not support checking Soltice DiskSuite device."
  return 0
}

do_qds_dev()
{
  #echo "${myname}: (Warning) does not support checking QDS device."
  return 0
}


do_ufs_dev()
{
  d=$1
  rv="`expr $1 : '/dev/rdsk/.*'`"
  status=$?
  if test "${status}" -ne 0
  then
    echo "Device=${d} is NOT a raw device."
    exit 1
  else
    disk=${dev}
  fi

  echo "Checking disk ..."
  ${checker} ${disk}
  status=$?
  if test "${status}" -eq 0
  then
    echo "  disk=${disk} is OK."
  else
    echo "  disk=${disk} is NOT OK."
  fi

  return ${status}
}

get_dg()
{
  rv="`expr $1 : '/dev/vx/rdsk/\(.*\)/.*'`"
}

get_disks()
{
  rv="`${vxdg} list $1 | grep '^config disk' | grep online | awk '{print $3}' | sort | uniq`"
}

#$1=dev $2=scsi-devices_to_check_if_exist
check_dev()
{
  if [ -n "$7" -a X"$7" != "X-" ]
  then
    [ "$7" = no ] && return 0
    set -- $7
  else
    [ "$4" = "nfs" ] && return 0
    rv="`expr "$2" : '/dev/rdsk/.*'`"
    if [ $? -ne 0 ]
    then
      echo "WARNING:device $2 is not /dev/rdsk device and check devices (parameter 7) not specified, not performing disk check on this device"
      return 0
    fi
    set -- $2
  fi

  e1=$1

  e2=`echo "$e1"|sed -e "s,/dev/rdsk/,,g"`
  be=$e2

  l1=`echo "$e2"|sed -e "s/[-()+&|<>=*!]/ /g"`

  l2=`for i in $l1;do expr $i : '[0-9]*$' > /dev/null || echo $i;done|sort -u`

  gooddisklist=
  baddisklist=

  for i in $l2
  do
    echo "`date`:Checking disk $i ..."
    ${checker} ${i}
    status=$?
    if test "${status}" -eq 0
    then
      echo "`date`:disk=${i} is OK."
      rv=1
      gooddisklist="$gooddisklist $i"
    else
      echo "`date`:disk=${i} is NOT OK."
      rv=0
      baddisklist="$baddisklist $i"
    fi
    be=`echo "$be"|sed -e "s/$i/$rv/g"`
  done

  rv=`awk 'BEGIN {if ('"$be"') print 0;else print 1;exit}'`
  if [ "$rv" -ne 0 -o $? -ne 0 ]
  then
    echo "disk check for expression ($e1) FAILED (substituted expression is ($be)) disks ($baddisklist) are NOT OK, disks ($gooddisklist) are OK"
    return 1
  fi

  if [ -n "$baddisklist" ]
  then
    echo "disk check for expression ($e1) SUCCEEDED (substituted expression is ($be)) disks ($baddisklist) are NOT OK, disks ($gooddisklist) are OK"
  else
    echo "disk check SUCCEEDED, ALL disks ($gooddisklist) are OK (for expression $e1 and substituted expression is '$be')"
  fi
}

check_dev "$@"
exit $?

fstab='fs.tab'
[ $# -ge 1 ] && fstab=$1

if [ ! -r "$fstab" ]
then
  echo "$0:$fstab not readable"
  usage
  exit 1
fi

cat "$fstab" | (
  ln=0
  while read bdev rdev mpoint fstype voltype moptions scsilist junk
  do
    ln=`expr $ln + 1`

    [ -n "$bdev" ] || continue
    expr "$bdev" : "#" > /dev/null && continue

    check_dev "$rdev" "$scsilist"
    if [ $? -ne 0 ]
    then
      echo "`date`:scsi_check failed for line $ln in $fstab"
      exit 1
    fi

  done
)
