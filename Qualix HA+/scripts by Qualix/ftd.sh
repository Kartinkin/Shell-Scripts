#!/bin/sh
#
# Copyright (c) 1998 Qualix Group, Inc. All Rights Reserved.
#
# $Id: ftd.sh,v 1.2 1998/12/17 02:05:56 vlp Exp $


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

setup_env()
{
  # BINDIR and TABDIR are passed down from parent
  [ -z "${BINDIR}" ] && BINDIR="`pwd`/../../bin"
  [ -z "${TABDIR}" ] && TABDIR="`pwd`"
  SGID="`basename ${TABDIR}`"
  bindir="${BINDIR}"
}

do_qping()
{
  tab=$1

  qping=${bindir}/qping.sh 
  if test ! -x ${qping}
  then
    return 0
  fi
  f=${sgdir}/qping.attempts
  if test -s ${f}
  then
    attempts="`cat ${f}`"
  else
    attempts=2
  fi
  if test -f ${sgdir}/qping.tab 
  then
    tab=${sgdir}/qping.tab
  fi

  ${qping} ${tab} ${attempts}
  status=$?
  if test "${status}" -ne 0
  then
    echo "### Service group=${sgname} is ready to transit to SERVED stated but"
    echo "###   an IP number for the service group is still ping'able."
    echo "###   Please check the heartbeat network for problems."
    #return 99
    return 88
  else
    return 0
  fi
}

do_if_start()
{
  execee "ftd.sh:do_if_start($*)" do_qping ${if_tabfile} || return 1

  ${BINDIR}/if.sh ${if_tabfile} start
  status=$?

  return ${status}
}

do_if_stop()
{
  ${BINDIR}/if.sh ${if_tabfile} stop
  status=$?

  return ${status}
}

do_fs_start()
{
  ${BINDIR}/fs.sh ${fs_tabfile} start
  status=$?

  return ${status}
}

do_fs_stop()
{
  ${BINDIR}/fs.sh ${fs_tabfile} stop
  status=$?

  return ${status}
}

do_daemons_start()
{
  execee "ftd.sh:do_daemons_start($*) (NB: you might need to run ftdstart -a;ftdstop -sa)" /etc/init.d/FTSWftd-scan start || return 1
  execee "ftd.sh:do_daemons_start($*)" /etc/init.d/FTSWftd-startdaemons start || return 1
 
  return 0
}

do_daemons_stop()
{
  execee "ftd.sh:do_daemons_stop($*)" /etc/init.d/FTSWftd-startdaemons stop || return 1
  execee "ftd.sh:do_daemons_stop($*)" /etc/init.d/FTSWftd-scan stop || return 1
   
  return 0
}

do_start()
{
  table=$1

  do_if_start
  status=$?
  if test "${status}" -ne 0
  then
    # XXX error message
    return 1
  fi

  do_fs_start
  status=$?
  if test "${status}" -ne 0
  then
    # XXX error message
    return 1
  fi

  do_daemons_start
  status=$?
  if test "${status}" -ne 0
  then
    # XXX error message
    return 1
  fi

  return 0
}

do_stop()
{
  table=$1

  do_daemons_stop
  status=$?
  if test "${status}" -ne 0
  then
    # XXX error message
    return 1
  fi

  do_fs_stop
  status=$?
  if test "${status}" -ne 0
  then
    # XXX error message
    return 1
  fi

  do_if_stop
  status=$?
  if test "${status}" -ne 0
  then
    # XXX error message
    return 1
  fi

  return 0
}

# Setting up env
setup_env

if test "$#" -eq 1
then
  if_tabfile=`pwd`/ftd.if.tab
  fs_tabfile=`pwd`/ftd.fs.tab
  command=$1
elif test "$#" -eq 2
then
  tabdir="`dirname $1`"
  if_tabfile=${tabdir}/ftd.if.tab
  fs_tabfile=${tabdir}/ftd.fs.tab
  command=$2
elif test "$#" -eq 3
then
  if_tabfile=$1
  fs_tabfile=$2
  command=$3
else
  echo "Usage: $0 ftd.if.tab ftd.fs.tab [start | stop]"
  exit 1
fi

if test ! -r "${if_tabfile}"
then
  echo "$0: File=${if_tabfile} is not readable."
  exit 1
fi

if test ! -r "${fs_tabfile}"
then
  echo "$0: File=${fs_tabfile} is not readable."
  #exit 1
fi

d="`dirname ${fs_tabfile}`"
SGID="`basename ${d}`"

if test -f ${d}/ftd.env
then
  . ${d}/ftd.env
fi

case "$command" in
  'start')
    echo "### sg=${SGID} -- Trying to start FTD."
    do_start "${fs_tabfile}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Started FTD successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to start FTD."
      exit $status
    fi
    ;;

  'stop')
    echo "### sg=${SGID} -- Trying to stop FTD."
    do_stop "${fs_tabfile}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Stopped FTD successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to stop disk FTD."
      exit $status
    fi
    ;;
  
  *)
    echo "Usage: $0 ftd.tab [start | stop]"
    exit 1
    ;;
esac

exit 0
