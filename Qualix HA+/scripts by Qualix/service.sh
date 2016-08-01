#!/bin/sh

#set -x

#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: service.sh,v 1.12 1998/09/04 00:29:51 ching Exp $
#

if test "$#" -ne 2
then
  echo "Usage: $0 bin_directory service_group_directory"
  exit 1
fi

export TOPDIR
export SGNAME

# If SGNAME is not set, very likely that this
# script was run manually. If so set sgname from pwd
sgname=${SGNAME}
if test -z "${SGNAME}"
then
  pwd="`pwd`"
  SGNAME="`basename ${pwd}`"
  sgname=${SGNAME}
fi

bindir=$1
if test ! -d "${bindir}"
then
  echo "$0: bindir=${bindir} does not exist."
  exit 1
fi
BINDIR=${bindir}; export BINDIR

tabdir=$2
if test ! -d "${tabdir}"
then
  echo "$0: tabdir=${tabdir} does not exist."
  exit 1
fi
TABDIR=${tabdir}; export TABDIR
sgdir=${tabdir}

do_pre_ifup()
{
  svc_list="`${bindir}/svc -g ${sgname} list`"
  for svc in $svc_list
  do
    f=${sgdir}/${svc}.d/pre_ifup
    if test -f ${f}
    then
      #echo "$0: do_pre_ifup for service=$svc"
      SVCNAME=${svc}
      export SVCNAME
      sh ${f}
      status=$?
      if test ${status} -ne 0
      then
	return 1
      fi
    fi
  done

  return 0
}

do_qds()
{
  f=${sgdir}/qds.if.tab
  if test ! -f ${f}
  then
    return 0
  fi
  cat ${f} | grep -v '^[ \t]*#' | sort | (
   while read device_
   do
    empty=1
    if test X"${device_}" != "X" -a "${device_}" != "-"
    then
      empty=0
    else
      continue
    fi
   done
   if test "${empty}" -eq 0
   then
     exit 0	# NOT empty
   else
     exit 1	# empty
   fi
  )
  status=$?
  if test "${status}" -ne 0
  then
    return 0
  fi

  #f=${sgdir}/qds.vol.tab
  #if test ! -f ${f}
  #then
  #  return 0
  #fi

  # XXX hard-coded installation directory
  QLIXds_dir=/etc/opt/QLIXds
  export QLIXds_dir
  # check to see if qds is installed and then run this
  if test -f "${QLIXds_dir}"/PMD.lic -o -f "${QLIXds_dir}"/RMD.lic
  then
    :
  else
    return 0
  fi

  #Start qDS
  echo ""
  echo "###"
  echo "### sg=${SGNAME} - Trying to start DataStar..."
  echo "###"
  echo ""

  b=${bindir}/qds.start.sh
  if test ! -f "${b}"
  then
    echo "$0: ds.start.sh=${b} does not exists"
    return 1
  else
    chmod +x ${b}
    ${b} 
    status=$?
  fi

  if test "${status}" -ne 0
  then
    echo ""
    echo "###"
    echo "### sg=${SGNAME} - Failed to bring DatsStar up ..."
    echo "###"
    echo ""
    return 1
  fi

  return ${status}
}

do_simple()
{
  if_tab=${tabdir}/if.tab
  if test ! -f "${if_tab}"
  then
    echo "$0: if_tab=${if_tab} does not exist."
    return 1
  fi

  fs_tab=${tabdir}/fs.tab
  if test ! -f "${fs_tab}"
  then
    echo "$0: fs_tab=${fs_tab} does not exist."
    return 1
  fi

#  do_qds
#  status=$?
#  if test "${status}" -ne 0
#  then
#    return 1
#  fi

  b=${bindir}/fs.sh
  if test ! -f "${b}"
    then
    echo "$0: fs.sh=${b} does not exist."
    return 1
  fi
  chmod +x ${b}
  ${b} ${fs_tab} start
  status=$?
  if test "${status}" -ne 0
  then
    return 1
  fi

  do_pre_ifup
  status=$?
  if test "${status}" -ne 0
  then
    return 1
  fi
  
  b=${bindir}/if.sh
  if test ! -f "${b}"
  then
    echo "$0: if.sh=${b} does not exist."
    return 1
  fi
  chmod +x ${b}
  ${b} ${if_tab} start
  status=$?
  if test "${status}" -ne 0
  then
    return 1
  fi

  return 0
}  

do_advance()
{
  d=${TABDIR}/init.d

  for f in ${d}/S*
  {
    if [ -s ${f} ]
    then
      case ${f} in
        *.sh) . ${f} ;;			# source it
           *) /sbin/sh ${f} start ;;	# sub shell
      esac
    fi
  }
}

if test -d "${TABDIR}/init.d"
then
  do_advance
else
  do_simple
fi

exit $?
