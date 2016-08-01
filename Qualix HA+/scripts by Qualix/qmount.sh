#!/bin/sh
#
# Copyright (c) 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: qmount.sh,v 1.8 1998/01/24 00:16:43 plv Exp $
#

# BINDIR and TABDIR are passed down from parent

conffile=/etc/qhap.conf

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"

bindir=${topdir}/bin
mount=/usr/sbin/mount

os="`uname`"
if test "${os}" = "AIX"
then
  AIX=1
else
  AIX=0
fi
seconds=1

if test -f ./qkillall
then
  qkillall=./qkillall
elif test -f ${bindir}/qkillall
then
  qkillall=${bindir}/qkillall
else
  qkillall=""
fi

if test -f ./lsof
then
  lsof=./lsof
elif test -f ${bindir}/lsof
then
  lsof=${bindir}/lsof
else
  lsof=""
fi

find_mpoint()
{
  for i 
  do
    rv=${i}
  done
}

kill_all_pids()
{
  echo "## Trying to kill all processes on mpoint=${mpoint} ..."

  if test X"${lsof}" = "X"
  then
    echo "## Using 'fuser' to get a list of PID's with opened file ..."
    if test X"${AIX}" != "X" -a "${AIX}" -gt 0
    then
      fuser ${mpoint} > /tmp/$$.out 2>/tmp/$$.err
    else
      fuser ${mpoint} > /tmp/$$.out 2>/tmp/$$.err
    fi
    cat /tmp/$$.out | tr -s ' \t' | tr ' ' '\n' | grep -v '^$' > /tmp/$$.pid
  else
    echo "## Using lsof=${lsof} to get a list of PID's with opened file ..."
    ${lsof} -t ${mpoint} > /tmp/$$.pid
  fi

  if test X"${qkillall}" = "X"
  then
    echo "## Using 'kill' to stop all processes  with opened file ..."
    cat /tmp/$$.pid
  else
    echo "## Using qkillall=${qkillall} to stop all processes  with opened file ..."
    #${qkillall} -f /tmp/$$.pid -t 2
    ${qkillall} -d -f /tmp/$$.pid -t 2
  fi

  /bin/rm -rf /tmp/$$.pid /tmp/$$.err /tmp/$$.out

  echo "## All processes on mpoint=${mpoint} are gone ..."
}  

umount_if_mpoint_is_mounted()
{
  mpoint=$1

  ${mount} -p | cut -f3 -d ' ' | grep "^${mpoint}$" > /tmp/$$.mpoint

  if test ! -s /tmp/$$.mpoint
  then
    /bin/rm -rf /tmp/$$.mpoint
    return 0
  fi

  cat /tmp/$$.mpoint | (
    while read mp
    do
      f=${bindir}/qumount.sh
      if test -f ${f}
      then
        ${f} ${mp}
      else
        ${umount} ${mp}
      fi
      status=$?
      if test "${status}" -ne 0
      then
	exit 1
      fi
    done
    exit 0
  )
  status=$?

  /bin/rm -rf /tmp/$$.mpoint

  return $?
}

find_mpoint $*
mpoint="${rv}"

echo "## Running 'qmount' to mount file system ${mpoint} ..."

argv0=$1
shift

for i in 1 2 3 4 5
do
  kill_all_pids ${mpoint}
  umount_if_mpoint_is_mounted ${mpoint}

  echo "## Mounting mpoint=${mpoint} ... (Attempt #${i})"
  ${argv0} $*
  status=$?
  if test "${status}" -eq 0
  then
    echo "## OK mpoint=${mpoint} is mounted ... (after attempt #${i})"
    /bin/rm -rf /tmp/$$.pid /tmp/$$.err /tmp/$$.out
    exit 0
  fi
  sleep ${seconds}
done

for i in 1 2 3 4 5
do
  kill_all_pids ${mpoint}
  umount_if_mpoint_is_mounted ${mpoint}

  echo "## Mounting mpoint=${mpoint} using overlay option ... (Attempt #${i})"
  ${argv0} -O $*
  status=$?
  if test "${status}" -eq 0
  then
    echo "## OK mpoint=${mpoint} is mounted using overlay option ... (after attempt #${i})"
    /bin/rm -rf /tmp/$$.pid /tmp/$$.err /tmp/$$.out
    exit 0
  fi
  sleep ${seconds}
done

echo "## FAILED to mount mpoint=${mpoint} ... (after #${i} attempts)"

/bin/rm -rf /tmp/$$.pid /tmp/$$.err /tmp/$$.out
exit 1
