#!/bin/sh

#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: clariion.sh,v 1.4 1998/01/24 00:16:23 plv Exp $
#

# BINDIR is being passed down from parent
if test -z "${BINDIR}"
then
  BINDIR="`pwd`/../../bin"
fi

install_path=${BINDIR}/..

RBIN=$install_path/bin
TRESPASS="$install_path/bin/trespass_array"
TEST_ACCESS="$install_path/bin/CL_check_lun"
AUTO_TRESPASS="$install_path/bin/CL_autotrespass"
REMOTE_AUTO_TRESPASS="${RBIN}/CL_autotrespass"
RSH="/bin/rsh"
DAEMON="$install_path/bin/CL_SPd"
TEST_DAEMON="$install_path/bin/CL_SPa"

do_start()
{
  table=$1
  while read primary_route secondary_route remote_host junk
  do
    if test -n "${primary_route}" 			# not blank space
    then
	$TEST_ACCESS  ${primary_route}
	status=$?
	if test "${status}" -eq 0
	then
	  echo "Clariion primary route=${primary_route} is accessible"
	  $AUTO_TRESPASS ${primary_route} off
	else
	  echo "Clariion primary route=${primary_route} is not accessible"
	  if test -z "${remote_host}" -o "${remote_host}" = "-"
	  then
	    echo "Trying to access locally via secondary route=${secondary_route}"
	    lun=`echo ${primary_route} | sed -e 's/c.*d//' | sed -e 's/s.*//'`
	    ${TRESPASS} ${secondary_route} -L $lun
	  else
	    echo "Trying to access remtoly via secondary route=${remote_host}:${secondary_route}"
	    rsh ${remote_host} $REMOTE_AUTO_TRESPASS ${secondary_route} on
	  fi
	fi
	$TEST_ACCESS  ${primary_route}
	status=$?
	if test "${status}" -eq 0
	then
	  echo "Clariion primary route=${primary_route} - trespass successfully"
	  $AUTO_TRESPASS ${primary_route} off
	else
	  echo "Failed to trespass for primary_route=${primary_route}"
	  return 1
	fi
    fi # not blank spaces
  done < ${table}

  return $? 
}

do_stop()
{
  table=$1
  cat ${table} | grep -v '^[ \t]*#' | (
  while read primary_route secondary_route remote_host junk
  do
    if test -n "${primary_route}" 			# not blank space
    then
	:
    fi # not blank spaces
  done )

  return $? 
}

if test "$#" -ne 2
then
  echo "Usage: $0 clariion-table [start | stop]"
  exit 1
fi

if test ! -r "$1"
then
  echo "$0: File=$1 is not readable."
  exit 1
fi

case "$2" in
  'start')
    echo '### Trying to own clariion file systems ...'
    do_start $1
    status=$?
    if test "$status" -eq 0
    then
      echo '### Owned clariion file systems successfully.'
      exit $status
    else
      echo '### Failed to own clariion file systems.'
      exit $status
    fi
    ;;

  'stop')
    echo '### Trying to dis-own clariion file systems ...'
    do_stop $1
    status=$?
    if test "$status" -eq 0
    then
      echo '### Dis-owned clariion file systems successfully.'
      exit $status
    else
      echo '### Failed to dis-owned clariion file systems.'
      exit $status
    fi
    ;;
  
  *)
    echo "Usage: $0 clariion-table [start | stop]"
    exit 1
    ;;
esac

exit 0
