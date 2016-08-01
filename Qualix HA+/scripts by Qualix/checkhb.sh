#!/bin/sh


#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: checkhb.sh,v 1.5 1998/03/06 23:34:45 hle Exp $
#

conffile=/etc/qhap.conf

topdir="`grep machine.install_dir ${conffile} | awk -F: '{print $2}' | tr -d ' \011'`"

bindir=${topdir}/bin
nhbs="`${bindir}/confq heartbeat.interface 2>/dev/null | wc -l`"

if test ${nhbs} -le 0
then
  echo "There is NO heartbeat.interface defined in ${topdir}/etc/machine.conf"
  exit 1
fi

exit 0
