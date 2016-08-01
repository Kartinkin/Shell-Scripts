#!/bin/sh
#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: vxvm.dg.sh,v 1.7 1998/01/24 00:16:56 plv Exp $
#

vxdg=/usr/sbin/vxdg
if test ! -f ${vxdg}
then
  vxdg=vxdg
fi

vxvol=/usr/sbin/vxvol
if test ! -f ${vxvol}
then
  vxvol=vxvol
fi

vxrecover=/usr/sbin/vxrecover
if test ! -f ${vxrecover}
then
  vxrecover=""
fi

dg_print()
{
  dg=$1

  ${vxdg} list ${dg}

  return $?
}

dg_check()
{
  dg=$1

  ${vxdg} list ${dg} > /dev/null 2>&1

  return $?
}

dg_is_imported()
{
  dg=$1

  dg_check ${dg}
  status="$?"
  if test "$status" -ne 0
  then
    return 1
  fi

  ${vxdg} list ${dg} | grep 'import-id' > /dev/null 2>&1

  return $?
}

dg_import()
{
  dg=$1

  ${vxdg} -t import ${dg} 2>&1
  status="$?"

  if test "$status" -eq 0 -o "$status" -eq 12 
  then # Disk group exists and is imported
    echo "dg_import($dg): Imported dg=${dg} successfully."
  else
    # XXX Dangerous operation: I am clearing the lock flag
    echo "dg_import($dg): Warning: last attemp to import failed. Try again. This time will attemp to clear lock."
    ${vxdg} -t -C import ${dg} 2>&1
    status="$?"

    if test "$status" -eq 0	# success
    then
      echo "dg_import($dg): Imported dg=${dg} successfully (with clear flag)."
    else
      # XXX Dangerous operation: I am forcing the import
      echo "dg_import($dg): Warning: last attemp to import failed. Try again. This time will use 'force' flag."
      ${vxdg} -t -f -C import ${dg} 2>&1
      status="$?"

      if test "$status" -eq 0	# success
      then
        echo "dg_import($dg): Imported dg=${dg} successfully (with force flag)."
      else
        echo "ERR: dg_import($dg): Failed to import dg=${dg} (with force flag)."
        return 1
      fi # force success
    fi # clear success
  fi # no flag success

  return 0
}

dg_export()
{
  dg=$1

  ${vxdg} -t deport ${dg}
  status="$?"
  if test "$status" -eq 0	# success
  then
    echo "dg_export($dg): Deported dg=${dg} successfully."
  else
    echo "ERR: dg_export($dg): Failed to deport dg=${dg}."
    return 1
  fi

  return 0
}

dg_start_volumes()
{
  dg=$1

  if test X"${vxrecover}" != "X"
  then
    # Start all disabled volumes but no recovery
    ${vxrecover} -g ${dg} -sn
  else
    ${vxvol} -g ${dg} startall
  fi
  status="$?"
  if test "$status" -eq 0	# success
  then
    echo "dg_start_volumes($dg): Started all volumes for dg=${dg} successfully."
  else
    echo "ERR: dg_start_volumes($dg): Failed to start all volumes for dg=${dg}."
    return 1
  fi

  if test X"${vxrecover}" != "X"
  then
    ${vxrecover} -g ${dg} -b
    status="$?"
    if test "$status" -eq 0	# success
    then
      echo "dg_start_volumes($dg): Started recovery operations for dg=${dg} successfully (background)."
    else
      echo "ERR: dg_start_volumes($dg): Failed to start recovery operations for dg=${dg} (background)."
      return 1
    fi
  fi

  return 0
}

dg_stop_volumes()
{
  dg=$1
  ${vxvol} -o bg -g ${dg} stopall
  status="$?"
  if test "$status" -eq 0	# success
  then
    echo "dg_stop_volumes($dg): Stopped all volumes for dg=${dg} successfully."
  else
    echo "ERR: dg_stop_volumes($dg): Failed to stop all volumes for dg=${dg}."
    return 1
  fi

  return 0
}

dg_online()
{
  dg=$1

  dg_import ${dg}
  status=$?
  if test "${status}" -ne 0
  then
    echo "dg_online($dg): Failed to import disk group=${dg}."
    return 1
  fi

  dg_start_volumes ${dg}
  status=$?
  if test "${status}" -ne 0
  then
    echo "dg_online($dg): Failed to start all volumes for disk group=${dg}."
    return 1
  fi

  #dg_print ${dg}

  return 0
}

dg_offline()
{
  dg=$1

  dg_stop_volumes ${dg}
  status=$?
  if test "${status}" -ne 0
  then
    echo "dg_offline($dg): Failed to stop all volumes for disk group=${dg}."
    return 1
  fi

  dg_export ${dg}
  status=$?
  if test "${status}" -ne 0
  then
    echo "dg_offline($dg): Failed to deport disk group=${dg}."
    return 1
  fi

  return 0
}

do_start()
{
  table=$1
  cat ${table} | grep -v '^[ \t]*#' | (
  while read dg junk
  do
    if test -n "${dg}" 			# not blank space
    then
        dg_is_imported ${dg}
        status="$?"
        if test "$status" -eq 0
        then
	  echo "vxvm.dg.sh: do_start() disk group=${dg} exists and is imported."
	  continue
        fi

        dg_online ${dg}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "vxvm.dg.sh: do_start() failed bring disk group=${dg} online."
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
  while read dg junk
  do
    if test -n "${dg}" 			# not blank space
    then
	dg_check ${dg}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "vxvm.dg.sh: do_stop() disk group=${dg} does not exist."
	  continue
	fi

        dg_offline ${dg}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "vxvm.dg.sh: do_stop() failed bring disk group=${dg} offline."
	  return 1
	fi
    fi
  done )

  return $?
}

if test "$#" -eq 1
then
  dgtab=`pwd`/vxvm.dg.tab
  command=$1
elif test "$#" -eq 2
then
  dgtab=$1
  command=$2
else
  echo "Usage: $0 vxvm-dg-table [start | stop]"
  exit 1
fi

if test ! -r "${dgtab}"
then
  echo "$0: File=${dgtab} is not readable."
  exit 1
fi

d="`dirname ${dgtab}`"
SGID="`basename ${d}`"

case "$command" in
  'start')
    echo "### sg=${SGID} -- Trying to start Vxvm disk groups."
    do_start "${dgtab}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Started Vxvm disk groups successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to start Vxvm disk groups."
      exit $status
    fi
    ;;

  'stop')
    echo "### sg=${SGID} -- Trying to stop Vxvm disk groups."
    do_stop "${dgtab}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Stopped Vxvm disk groups successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to stop disk Vxvm groups."
      exit $status
    fi
    ;;
  
  *)
    echo "Usage: $0 vxvm-dg-table [start | stop]"
    exit 1
    ;;
esac

exit 0
