#!/bin/sh

#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: jfs.vg.sh,v 1.4 1998/01/24 00:16:32 plv Exp $
#
conffile=/etc/qhap.conf

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"

bindir=${topdir}/bin

if test -f /usr/sbin/lspv
then
  lspv=/usr/sbin/lspv
else
  lspv=lspv
fi

if test -f /usr/sbin/lsvg
then
  lsvg=/usr/sbin/lsvg
else
  lsvg=lsvg
fi

if test -f /usr/sbin/varyonvg
then
  varyonvg=/usr/sbin/varyonvg
else
  varyonvg=varyonvg
fi


if test -f /usr/sbin/varyoffvg
then
  varyoffvg=/usr/sbin/varyoffvg
else
  varyoffvg=varyoffvg
fi

qbdr=${topdir}/bin/qbdr

vg_print()
{
  vg=$1

  ${lsvg} ${vg}

  return $?
}

vg_check()
{
  vg=$1

  ${lsvg} | grep "^${vg}$" > /dev/null 2>&1

  return $?
}

vg_is_active()
{
  vg=$1

  vg_check ${vg}
  status="$?"
  if test "$status" -ne 0
  then
    return 1
  fi

  ${lsvg} -o | grep "^${vg}$" > /dev/null 2>&1

  return $?
}

vg_activate()
{
  vg=$1

  ${varyonvg} ${vg} 2>&1
  status="$?"
  if test "$status" -eq 0
  then # Volume group exists and is active
    echo "vg_activate($vg): Activate vg=${vg} successfully."
  else
    # XXX Dangerous operation: I am clearing the lock flag
    echo "vg_activate($vg): Warning: last attemp to activate failed. Try again. This time will attemp to clear lock."
    ${lspv} | grep "${vg}" | awk '{print $1}' | ${qbdr}
    ${varyonvg} ${vg} 2>&1
    status="$?"
    if test "$status" -eq 0	# success
    then
      echo "vg_activate($vg): Activate vg=${vg} successfully (with clear flag)."
    else
      echo "ERR: vg_activate($vg): Failed to activate vg=${vg} (with clear flag)."
      return 1
    fi
  fi

  return 0
}

vg_deactivate()
{
  vg=$1

  vg_is_active ${vg}
  status="$?"
  if test "$status" -ne 0
  then
    echo "vg_deactivate($vg): vg=${vg} is not active."
    return 0
  fi

  ${varyoffvg} ${vg}
  status="$?"
  if test "$status" -eq 0	# success
  then
    echo "vg_deactivate($vg): Deactivate vg=${vg} successfully."
  else
    echo "ERR: vg_deactivate($vg): Failed to deactivate vg=${vg}."
    return 1
  fi

  return 0
}

vg_online()
{
  vg=$1

  vg_activate ${vg}
  status=$?
  if test "${status}" -ne 0
  then
    echo "vg_online($vg): Failed to activate volume group=${vg}."
    return 1
  fi

  vg_print ${vg}

  return 0
}

vg_offline()
{
  vg=$1

  vg_deactivate ${vg}
  status=$?
  if test "${status}" -ne 0
  then
    echo "vg_offline($vg): Failed to deactivate volume group=${vg}."
    return 1
  fi

  return 0
}

do_start()
{
  table=$1
  cat ${table} | grep -v '^[ \t]*#' | (
  while read vg junk
  do
    if test -n "${vg}" 			# not blank space
    then
        vg_is_active ${vg}
        status="$?"
        if test "$status" -eq 0
        then
	  echo "jfs.vg.sh: do_start() volume group=${vg} exists and is active."
	  continue
        fi

        vg_online ${vg}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "jfs.vg.sh: do_start() failed bring volume group=${vg} online."
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
  while read vg junk
  do
    if test -n "${vg}" 			# not blank space
    then
	vg_check ${vg}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "jfs.vg.sh: do_stop() volume group=${vg} does not exist."
	  continue
	fi

        vg_offline ${vg}
	status=$?
	if test "${status}" -ne 0
	then
	  echo "jfs.vg.sh: do_stop() failed bring volume group=${vg} offline."
	  return 1
	fi
    fi
  done )

  return $?
}

if test "$#" -ne 2
then
  echo "Usage: $0 jfs-vg-table [start | stop]"
  exit 1
fi

vgtab=$1

if test ! -r "${vgtab}"
then
  echo "$0: File=${vgtab} is not readable."
  exit 1
fi

d="`dirname ${vgtab}`"
SGID="`basename ${d}`"

case "$2" in
  'start')
    echo "### sg=${SGID} -- Trying to start JFS volume groups."
    do_start "${vgtab}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Started JFS volume groups successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to start JFS volume groups."
      exit $status
    fi
    ;;

  'stop')
    echo "### sg=${SGID} -- Trying to stop JFS volume groups."
    do_stop "${vgtab}"
    status=$?
    if test "$status" -eq 0
    then
      echo "### sg=${SGID} -- Stopped JFS volume groups successfully."
      exit $status
    else
      echo "### sg=${SGID} -- Failed to stop disk JFS groups."
      exit $status
    fi
    ;;
  
  *)
    echo "Usage: $0 jfs-vg-table [start | stop]"
    exit 1
    ;;
esac

exit 0
