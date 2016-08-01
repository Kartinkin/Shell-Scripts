#!/bin/sh
#
# Copyright (c) 1996 Qualix Group, Inc. All Rights Reserved.
#
# $Id: if.lib.sh.m,v 1.11 1999/02/20 02:15:16 vlp Exp $
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
[ -z "${BINDIR}" ] && BINDIR="${TOPDIR}/bin"

DEVDIR="${TOPDIR}/dev"
DEVCONFDIR="${TOPDIR}/dev/ifs"

ifconfig=/usr/sbin/ifconfig
[ -x ${ifconfig} ] || ifconfig=ifconfig

ifoffline="${BINDIR}/ifoffline.sh"
[ -x ${ifoffline} ] || ifoffline=ifoffline.sh

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

#return whether $1 is a virtual interface, store the physical interface in $rv
if_is_virtual()
{
  rv="`expr $1 : '\(.*\):.*'`"

  [ -n "${rv}" -a "${rv}" != 0 ] && return 0

  rv=$1
  return 1
}

# if_is_disabled $1=device
# if device is disabled will echo so and return 0
# otherwise will return 1
if_is_disabled()
{
  if_is_virtual $1
  disable_file_list="${DEVDIR}/$1.disable ${DEVDIR}/${rv}.disable"

  for f in ${disable_file_list}
  do
    if [ -f ${f} ]
    then
      echo "if_is_disabled($*): File=${f} exists. Will not configure device $1."
      return 0
    fi
  done

  return 1
}

# if_use_adev $1=device $2=adev
# returns true if should use alternative device
# will also echo complaints (and do cleanup) if files to
# use alternate device are there but alternate device isn't there
if_use_adev()
{
  if_is_virtual $1
  use_adev_file_list="${DEVDIR}/$1.use_adev ${DEVDIR}/${rv}.use_adev"

  for f in ${use_adev_file_list}
  do
    [ -f "${f}" ] || continue

    if [ "X$2" != "X" -a "X$2" != "X-" ]
    then
      return 0
    else
      echo "if_use_adev($*): file ${f} exists, but no alternative device specified."
      echo "	Removing file ${f}."
      /bin/rm -f ${f}
    fi
  done

  return 1
}

# if_print $1=device
# print info about a device
if_print()
{
  execee "if_print($*)" ${ifconfig} $1

  return $?
}

# if_exists $1=device
# see if the device physically exists on system
# side effect: will plumb unplumbed device
if_exists()
{
  ${ifconfig} $1 plumb > /dev/null 2>&1

  return $?
}

# if_check $1=device
# see if the device exists
if_check()
{
  ${ifconfig} $1 > /dev/null 2>&1

  return $?
}

# if_is_up $1=device
# see if the device is UP
if_is_up()
{
  ${ifconfig} $1 | grep 'UP' > /dev/null 2>&1

  return $?
}

# if_exists_and_up $1=device
# see if the device exists and is up
if_exist_and_up()
{
  if_check $* && if_is_up $* && return 0

  return 1
}

# if_set_mac $1=device $2=inet $3=netmask $4=broadcast $5=ether $6=mtu $7=metric $8=dev_state
# sets the MAC address of the interface
if_set_mac()
{
  execee "if_set_mac($*)" ${ifconfig} $1 ether $5 || return 1

  echo "if_set_mac($*): changed MAC successfully."
  return 0
}

# if_unset_mac $1=device
# resets the MAC address of the interface
if_unset_mac()
{

  return 0
}

# if_add $1=device
# plumb interface
if_add()
{
  if_is_virtual $1

  execee "if_add($*)" ${ifconfig} $rv plumb || return 1
  echo "if_add($*): added interface=$1 successfully."

  return 0
}

# ifconfig_up $1=device
# bring up the specified device
ifconfig_up()
{
  execee "ifconfig_up($*)" ${ifconfig} $1 up || return 1
  echo "ifconfig_up($*): up device=$1 successfully."

  return 0
}

# if_down $1=device
ifconfig_down()
{
  execee "if_down($*)" ${ifconfig} $1 down || return 1
  #echo "if_down($*): down device=$1 successfully." 

  return 0
}

# ifconfig_config $1=device $2=inet $3=netmask $4=broadcast $5=ether $6=mtu $7=metric $8=dev_state
# will configure a network interface and set all things
# will keep the interface down if $8 = down, else bring it up ($8 should be up or down)
ifconfig_config()
{
  if_add $* || return 1

  params="$1"
  [ "X$2" != "X-" ] && params="${params} inet $2"
  [ "X$3" != "X-" ] && params="${params} netmask $3"
  [ "X$4" != "X-" ] && params="${params} broadcast $4"
  [ "X$5" != "X-" ] && { if_set_mac $* || return 1;}
  [ "X$6" != "X-" ] && params="${params} mtu $6"
  [ "X$7" != "X-" ] && params="${params} metric $7"
  params="${params} -trailers $8"

  execee "ifconfig_config($*)" ${ifconfig} ${params} || return 1

  return 0
}

# ifconfig_unconfig $1=device $2=inet $3=netmask $4=broadcast $5=ether $6=mtu $7=metric
# will unconfigure a network interface
ifconfig_unconfig()
{
  ifconfig_down $* || return 1

#  if_remove $* || return 1

  return 0
}

# read_if_config $1=device
# get all information about the device
read_if_config()
{
  ifconffile="${DEVCONFDIR}/$1"
  if [ ! -f ${ifconffile} ]
  then
    echo "read_if_config($*): Configuration file ${ifconffile} for interface $1 doesn't exist"
    return 1
  fi

  set -- `cat ${ifconffile}`

  if [ $# -lt 7 ]
  then
    echo "read_if_config($*): Configuration file ${ifconffile} has wrong number of entries"
    return 1
  fi

  rv="$*"

  return 0
}

# write_if_config $1=device $2=inet $3=netmask $4=broadcast $5=ether $6=mtu $7=metric
# writes information about a device
write_if_config()
{
  if [ $# -lt 7 ]
  then
    echo "write_if_config($*): recieved wrong number of parameters, supposed to get 7"
    return 1
  fi

  [ -d ${DEVCONFDIR} ] || mkdir -p ${DEVCONFDIR}
  echo $* > ${DEVCONFDIR}/$1

  return 0
}

# clear_if_config $1=device
# remove interface information file
clear_if_config()
{
  ifconffile="${DEVCONFDIR}/$1"

  if [ ! -f ${ifconffile} ]
  then
    echo "clear_if_config($*): Configuration file ${ifconffile} got lost."
    return 0
  fi

  rm -f ${DEVCONFDIR}/$1

  return 0
}

# if_config $1=device $2=inet $3=netmask $4=broadcast $5=ether $6=mtu $7=metric
# store all information about this interface (or alias) for if_up
if_config()
{
  set -- $* - - - - - - -
  set -- $1 $2 $3 $4 $5 $6 $7

  if [ $5 != "-" ] && if_is_virtual $1
  then
    echo "if_config($*): Setting MAC address is not allowed for virtual interface $1."
    echo "	Will ignore MAC address $5."
    set -- $1 $2 $3 $4 - $6 $7
  fi

  write_if_config $*

  return 0
}

# if_up $1=device
# pick up all information about this interface (or alias) and configure it
if_up()
{
  read_if_config $* || return 1
  set -- ${rv} up

  ifconfig_config $* || return 1

  return 0
}

# if_down $1=device
# bring down the interface
if_down()
{
  read_if_config $* || return 1
  set -- ${rv} up

  ifconfig_unconfig $* || return 1

  return 0
}

# if_unconfig $1=device
# get rid of all information about this interface
if_unconfig()
{
  clear_if_config $* || return 1

  return 0
}
