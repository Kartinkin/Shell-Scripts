#!/bin/sh
#
# Copyright (c) 1996 Qualix Group, Inc. All Rights Reserved.
#
# $Id: ifswitch.sh.m,v 1.9 1999/02/18 23:22:52 vlp Exp $
#

conffile=/etc/qhap.conf
qhap=/bin/qhap
[ -x ${qhap} ] || qhap=qhap

if [ -z "${TOPDIR}" ]
then
  TOPDIR="`${qhap} cl install_dir 2>/dev/null`"
  [ -n "${TOPDIR}" ] ||
    TOPDIR="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"
  export TOPDIR
fi

[ -z "${BINDIR}" ] && { BINDIR="${TOPDIR}/bin"; export BINDIR;}

ifls=./ifls
[ -x ${ifls} ] || ifls="${TOPDIR}/bin/ifls"
[ -x ${ifls} ] || ifls=ifls

. ${BINDIR}/if.lib.sh

basenames()
{
  for i
  do
    basename ${i}
  done
}

check_pdev()
{
  if_exists ${pdev} || { echo "Primary device '${pdev}' does not exist.";exit 1;}
}

check_adev()
{
  if_exists ${adev} || { echo "Alternate device '${adev}' does not exist.";exit 1;}
}

disable_flag=0

if [ "$1" = "-d" ]
then
  disable_flag=1
  shift
fi

if [ "$#" -ne 2 ]
then
  echo "Usage: $0 [-d] src_if dest_if"
  exit 1
fi

pdev=$1
adev=$2

check_pdev
check_adev

down_lists="`${ifls} -u ${pdev} | sort -r`"
down_db_lists="`basenames ${DEVCONFDIR}/${pdev}* | sort -r`"
up_lists="`basenames ${DEVCONFDIR}/${adev}*`"

if [ -n "${down_lists}" ]
then
  for iface_ in ${down_lists}
  do
    echo "## ifswitch.sh: Down interface=${iface_} ..."
    ${ifconfig} ${iface_} down
  done
fi

if [ -n "${down_db_lists}" ]
then
  for iface_ in ${down_db_lists}
  do
    echo "## ifswitch.sh: Create file ${DEVDIR}/${iface_}.use_adev ..."
    touch ${DEVDIR}/${iface_}.use_adev
  done
fi
echo "## ifswitch.sh: Create file ${DEVDIR}/${pdev}.use_adev ..."
touch ${DEVDIR}/${pdev}.use_adev

f=/etc/hostname.${pdev}
bf=/etc/.hostname.${pdev}
af=/etc/hostname.${adev}

if test -f ${f}
then
  echo "## ifswitch.sh: Switch ${f} to ${af} ..."
  cp -p ${f} ${af}	# switch hostname.xx
  mv ${f} ${bf}		# backup copy
fi

if test "${disable_flag}" -eq 1
then
  echo "## ifswitch.sh: Create file=${DEVDIR}/${pdev}.disable ..."
  touch ${DEVDIR}/${pdev}.disable
fi

if [ -n "${up_lists}" ]
then
  for iface_ in ${up_lists}
  do
    echo "## ifswitch.sh: Up interface=${iface_} ..."
    if_up ${iface_}
    if test -f ${DEVDIR}/${iface_}.use_adev
    then
      echo "## ifswitch.sh: Remove file=${DEVDIR}/${iface_}.use_adev ..."
      rm ${DEVDIR}/${iface_}.use_adev
    fi
  done
fi
/bin/rm -f ${DEVDIR}/${adev}*.use_adev

exit 0
