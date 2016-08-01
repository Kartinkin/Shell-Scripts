#!/bin/sh
#
# Copyright (c) 1996 Qualix Group, Inc. All Rights Reserved.
#
# $Id: if.sh.m,v 1.11 1998/01/24 00:16:29 plv Exp $
#

# BINDIR and TABDIR are passed down
[ -z "${BINDIR}" ] && BINDIR="`pwd`/../../bin"
[ -z "${TABDIR}" ] && TABDIR="`pwd`"
SGID="`basename ${TABDIR}`"

. ${BINDIR}/if.lib.sh

# do_start $1=iftab
# bring up all interfaces in $1
do_start()
{
  cat $1 | grep -v '^[ \t]*#' | sort | (
    while read dev_ inet_ netmask_ broadcast_ ether_ mtu_ metric_ adev_ junk
    do
      [ "X${dev_}" = "X" -o "X${dev_}" = "X-" ] && continue

      dev_list_="${dev_}"

      [ "X${adev_}" = "X" -o "X${adev_}" = "X-" ] || dev_list_="${dev_list_} ${adev_}"

      for d_ in ${dev_list_}
      do
	if_is_disabled ${d_} && continue
        if_config ${d_} ${inet_} ${netmask_} ${broadcast_} ${ether_} ${mtu_} ${metric_} || return 1
      done

      if if_use_adev ${dev_} ${adev_}
      then
	echo "###do_start() sg=${SGID}: Using alternate device=${adev_} instead of device=${dev_}."
	dev_=${adev_}
      fi
      if_up ${dev_} ${inet_} || return 1

    done

    return 0
  )

  return $?
}

# do_stop $1=iftab
# bring down all interfaces in $1
# NB: it doesn't make sense to abort if an error is encountered
do_stop()
{
  cat $1 | grep -v '^[ \t]*#' | sort -r | (
    while read dev_ inet_ netmask_ broadcast_ ether_ mtu_ metric_ adev_ junk
    do
      [ "X${dev_}" = "X" -o "X${dev_}" = "X-" ] && continue

      dev_list_=${dev_}
      dev_up_=${dev_}
      if [ "X${adev_}" != "X" -a "X${adev_}" != "X-" ]
      then
        dev_list_="${dev_list_} ${adev_}"
	if if_use_adev ${dev_} ${adev_}
	then
          echo "###do_stop() sg=${SGID}: Bringing down alternate device=${adev_} instead of device=${dev_}."
	  dev_up_=${adev_}
	fi
      fi

      if if_down ${dev_up_} ${inet_} ${netmask_} ${broadcast_} ${ether_} ${mtu_} ${metric_}
      then
        echo "###do_stop() sg=${SGID}: network interface device ${dev_up_} brought DOWN."
      else
        echo "###do_stop() sg=${SGID}: failed to bring DOWN interface device ${dev_up_}."
      fi

      for d_ in ${dev_list_}
      do
	if_is_disabled ${d_} && continue
        if_unconfig ${d_} ${inet_} ${netmask_} ${broadcast_} ${ether_} ${mtu_} ${metric_} || return 1
      done

    done

    return 0
  )

  return $?
}


case "$#" in
  2)
    iftab=$1
    command=$2
    ;;
  1)
    iftab="${TABDIR}/if.tab"
    command=$1
    ;;
  *)
    echo "Usage: $0 [interface_table] (start | stop)"
    exit 1
    ;;
esac

if [ ! -r "$iftab" ]
then
  echo "$0: File=$iftab is not readable."
  exit 1
fi

case "$command" in
  'start')
    echo ""
    echo "###" 
    echo "### sg=${SGID} - Trying to bring network interfaces up ..."
    echo "###" 
    echo ""
    do_start $iftab
    status=$?
    if test "$status" -eq 0
    then
      echo ""
      echo "###"
      echo "### sg=${SGID} - Brought network interfaces up successfully."
      echo "###"
      echo ""
    else
      echo ""
      echo "###"
      echo "### sg=${SGID} - Failed to bring up network interfaces online."
      echo "###"
      echo ""
    fi
    exit $status
    ;;

  'stop')
    echo ""
    echo "###"
    echo "### sg=${SGID} - Trying to bring network interfaces down ..."
    echo "###"
    echo ""
    do_stop $iftab
    status=$?
    if test "$status" -eq 0
    then
      echo ""
      echo "###"
      echo "### sg=${SGID} - Brought network interfaces down successfully."
      echo "###"
      echo ""
    else
      echo ""
      echo "###"
      echo "### sg=${SGID} - Failed to bring down network interfaces online."
      echo "###"
      echo ""
    fi
    exit $status
    ;;
  
  *)
    echo "Usage: $0 [interface_table] (start | stop)"
    exit 1
    ;;
esac

exit 0
