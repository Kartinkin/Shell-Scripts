#!/bin/sh

#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: sds.ds.sh,v 1.4 1998/01/24 00:16:48 plv Exp $
#

metastat=/usr/opt/SUNWmd/sbin/metastat
if test ! -f ${metastat}
then
  metastat=metastat
fi
metaset=/usr/opt/SUNWmd/sbin/metaset
if test ! -f ${metaset}
then
  metaset=metaset
fi

ds_print()
{
  ds=$1

  ${metastat} -s ${ds}

  return $?
}

ds_check()
{
  ds=$1

  ${metastat} -s ${ds} > /dev/null 2>&1

  return $?
}

ds_is_imported()
{
  ds=$1

  ds_check ${ds}
  status="$?"
  if test "$status" -ne 0
  then
    return 1
  fi

  return $?
}

ds_import()
{
  ds=$1

  ${metaset} -s ${ds} -t 2>&1
  status="$?"
  if test "$status" -eq 0
  then # Disk group exists and is imported
    echo "ds_import($ds): Imported ds=${ds} successfully."
  else
    # XXX Dangerous operation: I am clearing the lock flag
    echo "ds_import($ds): Warning: last attemp to import failed. Try again. This time will attemp to clear lock."
    ${metaset} -s ${ds} -t -f 2>&1
    status="$?"
    if test "$status" -eq 0	# success
    then
      echo "ds_import($ds): Imported ds=${ds} successfully (with clear flag)."
    else
      echo "ERR: ds_import($ds): Failed to import ds=${ds} (with clear flag)."
      return 1
    fi
  fi

  return 0
}

ds_export()
{
  ds=$1

  ${metaset} -s ${ds} -r
  status="$?"
  if test "$status" -eq 0	# success
  then
    echo "ds_export($ds): Released ds=${ds} successfully."
  else
    echo "ERR: ds_export($ds): Failed to release ds=${ds}."
    return 1
  fi

  return 0
}

ds_online()
{
  ds=$1

  ds_import ${ds}
  status=$?
  if test "${status}" -ne 0
  then
    echo "ds_online($ds): Failed to import disk set=${ds}."
    return 1
  fi

  ds_print ${ds}

  return 0
}

ds_offline()
{
  ds=$1

  ds_export ${ds}
  status=$?
  if test "${status}" -ne 0
  then
    echo "ds_online($ds): Failed to release disk set=${ds}."
    return 1
  fi

  return 0
}

do_start()
{
  table=$1
  cat ${table} | grep -v '^[ \t]*#' | (
  while read ds junk
  do
    if test -n "${ds}" 			# not blank space
    then
        ds_is_imported ${ds}
        status="$?"
        if test "$status" -eq 0
        then
	  echo "sds.ds.sh: do_start() disk set=${ds} exists and is imported."
	  continue
        fi

        ds_online ${ds}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "sds.ds.sh: do_start() failed bring disk set=${ds} online."
	  return 1
	fi
    fi
  done )

  return $?
}

do_stop()
{
  table=$1
  cat ${table} | grep -v '^[ \t]*#' | ( 
  while read ds junk
  do
    if test -n "${ds}" 			# not blank space
    then
	ds_check ${ds}
	status=$?
	if test "$status}" -ne 0
	then
	  echo "sds.ds.sh: do_stop() disk set=${ds} does not exist."
	  continue
	fi

        ds_offline ${ds}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "sds.ds.sh: do_start() failed bring disk set=${ds} offline."
	  return 1
	fi
    fi
  done )

  return $?
}

if test "$#" -ne 2
then
  echo "Usage: $0 sds-ds-table [start | stop]"
  exit 1
fi

sdstab="$1"

if test ! -r "$sdstab"
then
  echo "$0: File=$sdstab is not readable."
  exit 1
fi

d="`dirname ${sdstab}`"
SGID="`basename ${d}`"

case "$2" in
  'start')
    echo "### sg=${SGID} -- Trying to start SDS disk sets."
    do_start "${sdstab}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Started SDS disk sets successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to start SDS disk sets."
      exit $status
    fi
    ;;

  'stop')
    echo "### sg=${SGID} -- Trying to stop SDS disk sets."
    do_stop "${sdstab}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Stopped SDS disk sets successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to stop SDS disk sets."
      exit $status
    fi
    ;;
  
  *)
    echo "Usage: $0 sds-ds-table [start | stop]"
    exit 1
    ;;
esac

exit 0
