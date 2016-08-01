#!/bin/sh
#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: assist.sh,v 1.4 1998/01/24 00:16:18 plv Exp $
#
conffile=/etc/qhap.conf
sg=sg

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"
bindir=${topdir}/bin

do_add_sg_yes()
{
  sample_dir=${topdir}/examples/255.255.255.255
  sg_dir=${topdir}/${sg}
  new_dir=${sg_dir}/${group_id}

  ###
  ### sg directory
  ###
  echo "### Checking to see if directory=${new_dir} exists ..."
  if test -d "${new_dir}"
  then
    echo "### Directory=${new_dir} already EXISTS."
    echo "###   Please make sure that the *.tab files in ${new_dir} have relevant information."
  else
    echo "### Creating directory=${new_dir} ..."
    mkdir -p "${new_dir}"
    if test ! -d "${new_dir}"
    then
      echo "### Failed to create directory=${new_dir}."
      return 1
    fi
    echo "### Copying files from ${sample_dir} ..."
    (cd ${sample_dir}; tar cf - . ) | (cd ${new_dir}; tar xvfBp - )
  fi
  echo "### Done."

  ###
  ### Update shared memory
  ###
  echo "### Updating shared memory ..."
  tmpfile=/tmp/$$.conf
  cp /dev/null ${tmpfile}
  echo "group.name: ${group_name}" >> ${tmpfile}
  echo "group.id: ${group_id}" >> ${tmpfile}
  echo "group.priority: ${group_priority}" >> ${tmpfile}
  if test "${group_priority}" -eq 1
  then
    echo "group.ok_to_serve_on_startup: 1" >> ${tmpfile}
  fi
  ${bindir}/modshm < ${tmpfile}
  status=$?
  /bin/rm -f ${tmpfile}
  echo "### Done."

  return ${status} 
}

do_add_sg()
{
  while true
  do
    echo ""
    echo "###############################"
    echo ""
    echo "* Adding a service group"
    echo "  You will be prompted for the following information:"
    echo "    . A service group name"
    echo "    . A service group ID"
    echo "    . A service group priority"
    echo ""
  
    echo "  Enter a service group name (group.name)> \c"
    read group_name
    if test X"${group_name}" = "X"
    then
      return 1
    fi
    ${bindir}/sg list_name | grep '^'"${group_name}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -eq 0
    then
      echo "    ERROR. group_name=${group_name} already EXISTS."
      continue
    fi
  
    echo "  Enter a service group ID (group.id)> \c"
    read group_id
    if test X"${group_id}" = "X"
    then
      return 1
    fi
    ip_ok="`expr ${group_id} : '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'`"
    if test "${ip_ok}" -le 0
    then
      echo "    'group_id' must be in "d.d.d.d" notation. For example: 192.91.182.1"
      continue
    fi
    ${bindir}/sg list_id | grep '^'"${group_id}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -eq 0
    then
      echo "    ERROR. group_id=${group_id} already EXISTS."
      continue
    fi
  
    echo "  Enter a service group priority (group.priority)> \c"
    read group_priority 
    if test X"${group_priority}" = "X"
    then
      return 1
    fi
  
    echo ""
    echo "  Add a new service group using the following information?"
    echo "    group.name: ${group_name}"
    echo "    group.id: ${group_id}"
    echo "    group.priority: ${group_priority}"
    echo ""
    echo "  OK? [yes, no, abort]> \c"
    read answer
    case "${answer}" in 
      y*) do_add_sg_yes
        status=$?
        echo ""
        if test "${status}" -eq 0; \
        then \
  	  echo "## OK. Added service group=${group_name}."
        else\
  	  echo "## ERROR. Failed to add service group=${group_name}."
        fi
        echo ""
        return ${status}
        ;;
      n*) continue ;;
      a*) return 0 ;;
      *) return 0;;
    esac
  done

  return 0
}

do_remove_sg_yes()
{
  ${bindir}/sg -g ${group_id} delete
}

do_remove_sg()
{
  while true
  do
    echo ""
    echo "###############################"
    echo ""
    echo "* Removing a service group"
    echo "  You will be prompted for the following information:"
    echo "    . A service group ID"
    echo ""
  
    echo "  Enter a service group ID (group.id)> \c"
    read group_id
    if test X"${group_id}" = "X"
    then
      return 1
    fi
    ip_ok="`expr ${group_id} : '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'`"
    if test "${ip_ok}" -le 0
    then
      echo "    'group_id' must be in "d.d.d.d" notation. For example: 192.91.182.1"
      continue
    fi
    ${bindir}/sg list_id | grep '^'"${group_id}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -ne 0
    then
      echo "    ERROR. group_id=${group_id} does NOT exist."
      continue
    fi
  
    echo ""
    echo "  Remove service group with id=${group_id}?"
    echo ""
    echo "  OK? [yes, no, abort]> \c"
    read answer
    case "${answer}" in 
      y*) do_remove_sg_yes
        status=$?
        echo ""
        if test "${status}" -eq 0; \
        then \
  	  echo "## OK. Removed service group with id=${group_id}."
        else\
  	  echo "## ERROR. Failed to remove service group with id=${group_id}."
        fi
        echo ""
        return ${status}
        ;;
      n*) continue ;;
      a*) return 0 ;;
      *) return 0;;
    esac
  done
}

do_add_svc_yes()
{
  sample_dir=${topdir}/examples/255.255.255.255/svc.d
  services_dir=${topdir}/examples/services
  sg_dir=${topdir}/${sg}/${group_id}
  new_dir=${sg_dir}/${service_name}.d

  ###
  ### svc directory
  ###
  echo "### Checking to see if directory=${new_dir} exists ..."
  if test -d "${new_dir}"
  then
    echo "### Directory=${new_dir} already EXISTS."
    echo "###   Please make sure that the 'start', 'stop' and 'test' files in ${new_dir} are appropriate for this service."
  else
    echo "### Creating directory=${new_dir} ..."
    mkdir -p "${new_dir}"
    if test ! -d "${new_dir}"
    then
      echo "### Failed to create directory=${new_dir}."
      return 1
    fi

    if test -d ${services_dir}/${service_name}.d
    then
      echo "A bundled Service Module for '${service_name}' is available. Would you like to use it? \c"
      read answer
      if test x"${answer}" = "x" -o "${answer}" = "Y" -o "${answer}" = "y"
      then
	src_dir=${services_dir}/${service_name}.d
      else
	src_dir=${sample_dir}
      fi
    else
      src_dir=${sample_dir}
    fi

    echo "### Copying files from ${src_dir} ..."
    (cd ${src_dir}; tar cf - . ) | (cd ${new_dir}; tar xvfBp - )
  fi
  echo "### Done."

  ###
  ### Update shared memory
  ###
  echo "### Updating shared memory ..."
  tmpfile=/tmp/$$.conf
  cp /dev/null ${tmpfile}
  echo "group.name: ${group_name}" >> ${tmpfile}
  echo "service.name: ${service_name}" >> ${tmpfile}
  ${bindir}/modshm < ${tmpfile}
  status=$?
  /bin/rm -f ${tmpfile}
  echo "### Done."

  return ${status} 
}

do_add_svc()
{
  while true
  do
    echo ""
    echo "###############################"
    echo ""
    echo "* Adding a service"
    echo "  You will be prompted for the following information:"
    echo "    . A service group id of a service group to which the new service is associated"
    echo "    . A service name"
    echo ""
  
    echo "  Enter a service group ID (group.id)> \c"
    read group_id
    if test X"${group_id}" = "X"
    then
      return 1
    fi
    ip_ok="`expr ${group_id} : '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'`"
    if test "${ip_ok}" -le 0
    then
      echo "    'group_id' must be in "d.d.d.d" notation. For example: 192.91.182.1"
      continue
    fi
    ${bindir}/sg list_id | grep '^'"${group_id}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -ne 0
    then
      echo "    ERROR. group_id=${group_id} does NOT exist."
      continue
    fi
    group_name="`${bindir}/sg list | grep '^'"${group_id}"'|' | awk -F'|' '{print $2}'`"
    if test X"${group_name}" = "X"
    then
      echo "    Cannot find the name of group_id=${group_id}"
      continue
    fi

    echo "  Enter a service name (service.name)> \c"
    read service_name
    if test X"${service_name}" = "X"
    then
      return 1
    fi
    ${bindir}/svc -g ${group_id} list | grep '^'"${service_name}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -eq 0
    then
      echo "    ERROR. service_name=${service_name} already EXISTS for sg_id=${group_id}."
      continue
    fi
  
    echo ""
    echo "  Add a new service for group_id=${group_id} using the following information?"
    echo "    group.name: ${group_name}"
    echo "    service.name: ${service_name}"
    echo ""
    echo "  OK? [yes, no, abort]> \c"
    read answer
    case "${answer}" in 
      y*) do_add_svc_yes
        status=$?
        echo ""
        if test "${status}" -eq 0; \
        then \
  	  echo "## OK. Added service=${service_name}."
        else\
  	  echo "## ERROR. Failed to add service=${service_name}."
        fi
        echo ""
        return ${status}
        ;;
      n*) continue ;;
      a*) return 0 ;;
      *) return 0;;
    esac
  done

  return 0
}

do_remove_svc_yes()
{
  ${bindir}/svc -g ${group_id} -s "${service_name}" delete
}

do_remove_svc()
{
  while true
  do
    echo ""
    echo "###############################"
    echo ""
    echo "* Removing a service"
    echo "  You will be prompted for the following information:"
    echo "    . A service group id of a service group to which the service is associated"
    echo "    . A service name"
    echo ""
  
    echo "  Enter a service group ID (group.id)> \c"
    read group_id
    if test X"${group_id}" = "X"
    then
      return 1
    fi
    ip_ok="`expr ${group_id} : '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'`"
    if test "${ip_ok}" -le 0
    then
      echo "    'group_id' must be in "d.d.d.d" notation. For example: 192.91.182.1"
      continue
    fi
    ${bindir}/sg list_id | grep '^'"${group_id}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -ne 0
    then
      echo "    ERROR. group_id=${group_id} does NOT exist."
      continue
    fi
    group_name="`${bindir}/sg list | grep '^'"${group_id}"'|' | awk -F'|' '{print $2}'`"
    if test X"${group_name}" = "X"
    then
      echo "    Cannot find the name of group_id=${group_id}"
      continue
    fi

    echo "  Enter a service name (service.name)> \c"
    read service_name
    if test X"${service_name}" = "X"
    then
      return 1
    fi
    ${bindir}/svc -g ${group_id} list | grep '^'"${service_name}"'$' > /dev/null 2>&1
    status=$?
    if test "${status}" -ne 0
    then
      echo "    ERROR. service_name=${service_name} does NOT exist for sg_id=${group_id}."
      continue
    fi
  
    echo ""
    echo "  Remove service for group_id=${group_id} using the following information?"
    echo "    group.name: ${group_name}"
    echo "    service.name: ${service_name}"
    echo ""
    echo "  OK? [yes, no, abort]> \c"
    read answer
    case "${answer}" in 
      y*) do_remove_svc_yes
        status=$?
        echo ""
        if test "${status}" -eq 0; \
        then \
  	  echo "## OK. Removed service=${service_name}."
        else\
  	  echo "## ERROR. Failed to remove service=${service_name}."
        fi
        echo ""
        return ${status}
        ;;
      n*) continue ;;
      a*) return 0 ;;
      *) return 0;;
    esac
  done

  return 0
}

do_exit()
{
  exit $1
}

while true
do
  echo ""
  echo "###############################"
  echo ""
  echo "  [1] Add a new service group."
  echo "  [2] Remove a service group."
  echo "  [3] Add a new service."
  echo "  [4] Remove a service."
  echo ""
  echo "  [5] Exit."
  echo ""

  echo "  [1, 2, 3, 4 or 5]> \c"
  read answer 
  
  #echo ${answer}

  case "${answer}" in 
    1*) do_add_sg ;;
    2*) do_remove_sg ;;
    3*) do_add_svc ;;
    4*) do_remove_svc ;;
    5*) do_exit 0 ;;
    *) do_exit 0 ;;
  esac
done

exit 0
