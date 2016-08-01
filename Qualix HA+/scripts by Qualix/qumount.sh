#!/bin/sh
#
# Copyright (c) 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: qumount.sh,v 1.7 1999/02/17 02:14:28 vlp Exp $
#

conffile=/etc/qhap.conf

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"

bindir=${topdir}/bin

os="`uname`"
if test "${os}" = "AIX"
then
  AIX=1
else
  AIX=0
fi

lockfs=/usr/sbin/lockfs

if test X"${AIX}" != "X" -a "${AIX}" -gt 0
then
  umount=/usr/sbin/umount
else
  umount=/sbin/umount
fi

if test X"${AIX}" != "X" -a "${AIX}" -gt 0
then
  mount=/usr/sbin/mount
else
  mount=/sbin/mount
fi

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


did_lockfs=0

rv=0

if test "$#" -ne 1
then
  echo "Usage: $0 mpoint"
  echo "  mpoint: a mounted point for a file system to be unmounted."
  exit 1
fi

Mpoint=$1

is_lockfs()
{
  mpoint=$1

  ${lockfs} ${mpoint} | awk '$2 ~ /^hard$/ {print $0}' | grep "^${mpoint} " > /dev/null

  return $?
}

# Let's make sure that mpoint is a mounted file system
sanity_check()
{
  #mpoint=$1

  if test X"${AIX}" != "X" -a "${AIX}" -gt 0
  then
    ${mount} -p | awk '{print $2}' | grep "^$1$" > /dev/null 2>&1
    lrv=$?
  else
    ${mount} -p | awk '{print $3}' | grep "^$1$" > /dev/null 2>&1
    lrv=$?
  fi

  return ${lrv}
}

get_fstyp()
{
  rv=`$mount -p|awk '{print $3, $4}'|grep "^$1 "|awk '{print $2}'`
}

qumount()
{
  mpoint=$1

  seconds=5
  for i in 1 2 3
  do
    sanity_check ${mpoint}
    status=$?
    if test "${status}" -ne 0
    then
      echo "## mpoint=${mpoint} does NOT appear to be mounted. (Attempt #${i})."
      echo "## Will re-check in ${seconds} seconds."
      sleep ${seconds} 
      continue
    else
      #echo "## mpoint=${mpoint} is mounted. (Attempt #${i})."
      break
    fi
  done
  
  if test "${status}" -ne 0
  then
    echo "## mpoint=${mpoint} is NOT a mounted file system."
    echo "## Will NOT try to umount mpoint=${mpoint}."
    return 1 
  fi
  
  #lock_type="-e"	# error-lock
  lock_type="-h"	# hard-lock
  #lock_type="-n"	# name-lock
  if test -f ${lockfs}
  then
    get_fstyp ${mpoint}
    if [ "$rv" = ufs ]
    then
      is_lockfs ${mpoint}
      status=$?
      if test "${status}" -eq 0
      then
	echo "## mpoint=${mpoint} is already hard-lock'ed." 
      else
	echo "## Attempt to lockfs mpoint=${mpoint} ..."
	${lockfs} -c "HA+" ${lock_type} ${mpoint}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "## FAILED to lockfs() mpoint=${mpoint}."
	  echo "## mpoint=${mpoint} is NOT lockfs'ed"
	else
	  echo "## OK. mpoint=${mpoint} is lockfs'ed"
	fi
      fi
    else
      echo "## mpoint=$mpoint is $rv (not ufs), not trying to lockfs"
    fi
  fi
  
  for i in 1 2 3 4 5
  do
    echo "## Trying to kill all processes on mpoint=${mpoint} ... (Attempt #${i})"
  
    if test X"${lsof}" = "X"
    then
      echo "## Using 'fuser' to get a list of PID's with opened file ..."
      if test X"${AIX}" != "X" -a "${AIX}" -gt 0
      then
        fuser ${mpoint} > /tmp/$$.out 2>/tmp/$$.err
      else
        fuser -c ${mpoint} > /tmp/$$.out 2>/tmp/$$.err
      fi
      cat /tmp/$$.out | tr -s ' \t' | tr ' ' '\n' | grep -v '^$' > /tmp/$$.pid
    else
      echo "## Using lsof=${lsof} to get a list of PID's with opened file ..."
      ${lsof} -t ${mpoint} > /tmp/$$.pid
    fi
  
    if test X"${qkillall}" = "X"
    then
      echo "## Using 'kill' to stop all processes  with opened file ..."
      kill `cat /tmp/$$.pid`
      cat /tmp/$$.pid
    else
      echo "## Using qkillall=${qkillall} to stop all processes  with opened file ..."
      #${qkillall} -f /tmp/$$.pid -t 2
      ${qkillall} -d -f /tmp/$$.pid -t 2
      #cat /tmp/$$.pid
    fi
  
    echo "## All processes on mpoint=${mpoint} are gone ..."
    
    echo "## Attempt to umount mpoint=${mpoint} ... (Attempt #${i})"
    ${umount} ${mpoint}
    status=$?
    if test "${status}" -ne 0
    then
      echo "## FAILED to unmount mpoint=${mpoint}. (Attempt #${i})"
      rv=1
      sleep 2
    else
      echo "## OK. mpoint=${mpoint} in unmounted. (Attempt #${i})"
      rv=0
      break
    fi
  done
  
  #if test -f ${lockfs}
  #then
  #  echo "## Attempt to un-lockfs mpoint=${mpoint} ..."
  #  ${lockfs} -u ${mpoint}
  #fi
  
  /bin/rm -f /tmp/$$.*
  
  return ${rv} 
}

get_lofs()
{
  mpoint=$1
  rv=""
  rv="`${mount} -p | awk '$4 ~ /^lofs$/ {print $0}' | grep \"^${mpoint}\" | awk '{print $3}'`"

  if test X"${rv}" = "X"
  then
    return 1
  else
    return 0
  fi
}

mpoint_list="${Mpoint}"

get_lofs ${Mpoint}
status=$?
if test "${status}" -eq 0
then
  echo "## mpoint=${Mpoint} has the following loopback file system:"
  echo "##  ${rv}"
  echo "##  will also attempt to unmount those loopback file systems"
  mpoint_list="${rv} ${mpoint_list}"
fi

for m in ${mpoint_list}
do
  #echo ${m}
  qumount ${m}
  status=$?
  if test "${status}" -ne 0
  then
    echo "## qumount.sh: Cannot unmount mpoint=${m}."
    exit 1
  fi
done

exit 0
