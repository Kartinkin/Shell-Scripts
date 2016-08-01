#!/bin/sh

#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: qping.sh.m,v 1.7 1998/02/19 01:01:32 hle Exp $
#

conffile=/etc/qhap.conf

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"

seconds=5
max_attempts=12

ping=/usr/sbin/ping
if test ! -x ${ping}
then
  ping=ping
fi

if test -f ./fping
then
  fping=./fping
elif test -f ${topdir}/bin/fping
then
  fping=${topdir}/bin/fping
else
  fping=""
fi

qwait="${topdir}/bin/qwait"

timeout="3"		# seconds

do_fping()
{
  iftab=$1
  cat ${iftab} | grep -v '^[ \t]*#' | awk '{print $2}' | ${fping} -Z
  status=$?
  if test ${status} -eq 0
  then
    return 1	# at minimum, a response
  else
    return 0
  fi
}

do_ping()
{
  iftab=$1
  cat ${iftab} | grep -v '^[ \t]*#' | sort | (
  while read device_ inet_ netmask_ broadcast_ ether_ mtu_ metric_ junk
  do
    if test -n "${device_}" 			# not blank space
    then
      ${qwait} -w ${timeout} ${ping} ${inet_} > /dev/null 2>&1
      status=$?
      if test "$status" -eq 0
      then
        echo "Service interface ${inet_} is still alive."
        return 1
      else
        echo "Service interface ${inet_} is down."
      fi
    fi	# blank space
  done
  return 0
  )

  return $?
}

if test "$#" -eq 1
then
  iftab=$1
elif test "$#" -eq 2
then
  iftab=$1
  max_attempts=$2
else
  echo "Usage: $0 interface-table [max_attempts]"
  exit 1
fi

if test ! -r "${iftab}"
then
  echo "$0: File=$iftab is not readable."
  exit 1
fi

if test X"${fping}" != "X"
then
  do_fping ${iftab}
  status=$?
  exit ${status}
fi

if test "${max_attempts}" -eq 0
then
  echo "$0 - Variable=max_attempts is set to zero. Skip testing."
  exit 0
fi

if test "${max_attempts}" -lt 0
then
  echo "$0 - Variable=max_attempts is less than zero. Will keep testing until ALL shared IP are dead."
fi

attempts=0
while true
do
  if test "${max_attempts}" -gt 0
  then
    if test "${attempts}" -ge "${max_attempts}"
    then
      break
    fi
  fi
  attempts=`expr ${attempts} + 1`
  do_ping ${iftab}
  status=$?
  if test "${status}" -eq 1	# still alive
  then
    echo "Will re-test in ${seconds} seconds. (Attempt ${attempts}/${max_attempts})."
    sleep ${seconds}
  else
    exit 0
  fi
done

exit 1
