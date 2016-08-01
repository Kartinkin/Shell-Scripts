#!/bin/sh
#
# Copyright (c) 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: check_isolation.sh,v 1.12 1998/12/12 02:34:34 vlp Exp $
#

if test $# -ne 1
then
  echo "Usage: $0 sg"
  exit 1
fi

group_id=$1

conffile=/etc/qhap.conf

if [ ! -f ${conffile} ]
then
  echo "check_isolation.sh:File doesn't exist:${conffile}"
  exit 1
fi

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"

if [ -z "${topdir}" ]
then
  echo "check_isolation.sh:${conffile} does not contain installation directory"
  exit 1
fi

bindir=${topdir}/bin

ifconfig=/usr/sbin/ifconfig
netstat=/bin/netstat
sg_sh=${bindir}/sg
checkif=${bindir}/checkif
confq=${bindir}/confq
qcalc_bcast=${bindir}/qcalc_bcast

rv=0
for i in "${ifconfig}" "${netstat}" "${sg_sh}" "${checkif}" "${confq}" "${qcalc_bcast}"
do
  if [ ! -x "${i}" ]
  then
    echo "check_isolation.sh:${i} is not executable"
    rv=1
  fi
done

if [ ${rv} -ne 0 ]
then
  echo "check_isolation.sh:Some executables are missing, skipping test"
  exit 0
fi

sg=sg
config_tmp_file=/tmp/$$.ifconfig
exclude_file=/tmp/$$.exclude
dst_addr_file=/tmp/$$.dst_addr

${sg_sh} list_id | grep '^'"${group_id}"'$' > /dev/null 2>&1
status=$?
if test "${status}" -ne 0
then
  echo "    ERROR. group_id=${group_id} does NOT exist."
  exit 1
fi
sg_dir=${topdir}/${sg}/${group_id}
if test ! -d ${sg_dir}
then
  echo "Cannot find service group directory=${sg_dir}."
  exit 1
fi

if test -f ${sg_dir}/check_isolation.disable
then
  echo "File ${sg_dir}/check_isolation.disable exists. Network isolation checking is disable."
  exit 0
fi

if test ! -f ${sg_dir}/check_isolation.enable
then
  echo "File ${sg_dir}/check_isolation.enable does not exist. Network isolation checking is disable."
  exit 0
fi

cp /dev/null ${exclude_file}
${netstat} -ni | awk '{print $4}' | grep '^[0-9]' | sort | uniq > ${exclude_file}

hb_list="`${confq} heartbeat.interface`"

echo ""
echo "### Network isolation checking: heartbeat network ..."
rv=0
if test X"${hb_list}" != "X"
then
  for hb in ${hb_list}
  do
    echo "## Checking interface=${hb} ..."

    f=${sg_dir}/check_isolation.${hb}
    if test -s ${f}
    then
      echo "## Using a pre-defined list of IPs in file=${f} ..."
      cat ${f} | ${checkif} -E ${exclude_file} -V -r 1 -D ${hb} > /dev/null
      status=$?
    else
      dst_addr=""
      ${ifconfig} ${hb}  | grep broadcast > ${config_tmp_file}
      if test -s ${config_tmp_file}
      then
        dst_addr="`cat ${config_tmp_file} | awk '{print $6}'`"
      else
        ${ifconfig} ${hb} | grep '\-->' > ${config_tmp_file}
        if test -s ${config_tmp_file}
        then
          dst_addr="`cat ${config_tmp_file} | awk '{print $4}'`"
        else
  	  continue
        fi
      fi
  
      if test X"${dst_addr}" = "X"
      then
        continue
      fi
  
      #dst_addr=1.2.3.4
      ${checkif} -E ${exclude_file} -V -r 1 -D ${hb} ${dst_addr} > /dev/null
      status=$?
    fi

    if test "${status}" -eq 0
    then
      echo "## Interface=${hb} is NOT isolated ..."
      /bin/rm -rf ${config_tmp_file} 
      /bin/rm -rf ${exclude_file} 
      exit 0
    fi
    echo "## Interface=${hb} is isolated ..."
    rv=1
  done

  /bin/rm -rf ${config_tmp_file} 
fi
if test "${rv}" -ne 0
then
    echo "### Heartbeat network is isolated."
fi

echo ""
echo "### Network isolation checking: service network ..."

#sg_dir=${topdir}/${sg}/${group_id}
#if test ! -d ${sg_dir}
#then
#  echo "Cannot find service group directory=${sg_dir}."
#  /bin/rm -rf ${config_tmp_file} 
#  /bin/rm -rf ${exclude_file} 
#  exit 1
#fi
#
#iftab=${sg_dir}/if.tab
#cat ${iftab} | grep -v '^[ \t]*#' | sort | (
#  while read device_ inet_ junk
#  do
#    if test X"${device_}" != "X" -a "${device_}" != "-"
#    then
#      :
#    else
#      continue
#    fi
#
#    #echo ${device_}
#    echo "## Checking interface=${device_} ..."
#
#    dst_addr=""
#    ${ifconfig} ${device_}  | grep broadcast > ${config_tmp_file}
#    if test -s ${config_tmp_file}
#    then
#      dst_addr="`cat ${config_tmp_file} | awk '{print $6}'`"
#    else
#      ${ifconfig} ${device_} | grep '\-->' > ${config_tmp_file}
#     if test -s ${config_tmp_file}
#      then
#        dst_addr="`cat ${config_tmp_file} | awk '{print $4}'`"
#      else
#	continue
#      fi
#    fi
#
#    if test X"${dst_addr}" = "X"
#    then
#      continue
#    fi
#
#    #dst_addr=1.2.3.4
#    ${checkif} -E ${exclude_file} -V -r 1 -S ${inet_} ${dst_addr} > /dev/null
#    status=$?
#    if test "${status}" -eq 0
#    then
#      echo "## Interface=${device_} is NOT isolated ..."
#      /bin/rm -rf ${config_tmp_file} 
#      /bin/rm -rf ${exclude_file} 
#      exit 0
#    fi
#
#    echo "## Interface=${device_} is isolated."
#    rv=1
#  done
#
#  if test "${rv}" -ne 0
#  then
#    echo "### Service network is isolated."
#  fi
#  /bin/rm -rf ${config_tmp_file} 
#  /bin/rm -rf ${exclude_file} 
#  exit $rv 
#)
#
#status=$?

sg_dir=${topdir}/${sg}/${group_id}
if test ! -d ${sg_dir}
then
  echo "Cannot find service group directory=${sg_dir}."
  /bin/rm -rf ${config_tmp_file} 
  /bin/rm -rf ${exclude_file} 
  exit 1
fi

#$1=device $2=inet $3=netmask
#return in $dst_addr
get_broadcast_addr()
{
  ${ifconfig} $1  | grep broadcast > ${config_tmp_file} 2>/dev/null
  if test -s ${config_tmp_file}
  then
    dst_addr="`cat ${config_tmp_file} | awk '{print $6}'`"
  else
    ${ifconfig} $1 | grep '\-->' > ${config_tmp_file} 2>/dev/null
    if test -s ${config_tmp_file}
    then
      dst_addr="`cat ${config_tmp_file} | awk '{print $4}'`"
    else
      dst_addr="`${qcalc_bcast} $2 $3`"
    fi
  fi
}

get_if_broadcast_addr()
{
  if test X"${broadcast_}" != "X" -a "${broadcast_}" != "-"
  then
    dst_addr="${broadcast_}"
  else
    get_broadcast_addr ${device_} ${inet_} ${netmask_}
  fi

  if test X"${dst_addr}" = "X"
  then
    dst_addr="`${qcalc_bcast} ${inet_} ${netmask_}`"
  fi

  echo "${dst_addr}"
}

iftab=${sg_dir}/if.tab
cat ${iftab} | grep -v '^[ \t]*#' | sort | (
  while read org_device_ inet_ netmask_ broadcast_ ether_ mtu_ metric_ adev_ junk
  do
    for device_ in "${org_device_}" "${adev_}"
    do
      if test X"${device_}" != "X" -a "${device_}" != "-"
      then
	:
      else
	continue
      fi

      #echo ${device_}
      #echo "## Checking interface=${device_} ..."

      get_if_broadcast_addr
    done
  done
) > ${dst_addr_file}

if test ! -s "${dst_addr_file}"
then
  # No entries in if.tab file
  echo "### This service group has no entry in iftab=${sg_dir}/if.tab."
  echo "### Will ignore isolation checking for service network."
  status=0
else
  ${netstat} -ni | awk '{print $1}' | grep -v '^Name' | sort | uniq | (
    while read device_ junk
    do
      if test X"${device_}" != "X" -a "${device_}" != "-"
      then
	:
      else
	continue
      fi

      #echo ${device_}
      #echo "## Checking interface=${device_} ..."

      dst_addr=""
      ${ifconfig} ${device_}  | grep broadcast > ${config_tmp_file}
      if test -s ${config_tmp_file}
      then
	dst_addr="`cat ${config_tmp_file} | awk '{print $6}'`"
      else
	${ifconfig} ${device_} | grep '\-->' > ${config_tmp_file}
	if test -s ${config_tmp_file}
	then
	  dst_addr="`cat ${config_tmp_file} | awk '{print $4}'`"
	else
	  continue
	fi
      fi

      if test X"${dst_addr}" = "X"
      then
	continue
      fi

      match=0
      for d in `cat ${dst_addr_file}`
      do
	if test "${dst_addr}" = "${d}"
	then
	  match=1
	  break
	fi
      done

      if test "${match}" -ne 1
      then
	continue
      fi

      echo "## Checking interface=${device_} ..."
      f=${sg_dir}/check_isolation.${device_}
      if test -s ${f}
      then
	echo "## Using a pre-defined list of IPs in file=${f} ..."
	cat ${f} | ${checkif} -E ${exclude_file} -V -r 1 -D ${device_} > /dev/null
	status=$?
      else
	#dst_addr=1.2.3.4
	${checkif} -E ${exclude_file} -V -r 1 -D ${device_} ${dst_addr} > /dev/null
	status=$?
      fi
      if test "${status}" -eq 0
      then
	echo "## Interface=${device_} is NOT isolated ..."
	/bin/rm -rf ${config_tmp_file} 
	/bin/rm -rf ${exclude_file} 
	/bin/rm -rf ${dst_addr_file}
	exit 0
      fi

      echo "## Interface=${device_} is isolated."
      rv=1
    done

    if test "${rv}" -ne 0
    then
      echo "### Service network is isolated."
    fi
    /bin/rm -rf ${config_tmp_file} 
    /bin/rm -rf ${exclude_file} 
    /bin/rm -rf ${dst_addr_file}
    exit $rv 
  )
  status=$?
fi

/bin/rm -rf ${config_tmp_file} 
/bin/rm -rf ${exclude_file} 
/bin/rm -rf ${dst_addr_file}

exit ${status}
