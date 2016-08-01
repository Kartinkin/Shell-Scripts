#!/bin/sh
#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: ha_panic.sh.m,v 1.6 1999/02/26 10:26:22 vlp Exp $
#

logfile=/var/adm/log/qhap.log

echo "`date`:HA_PANIC!!!, being asked to panic" >>$logfile
echo "`date`:HA_PANIC!!!, my pid is $$, here's what's currently running:" >>$logfile
echo "------------------------------------------------------------" >>$logfile
ps -ef >>$logfile 2>&1
echo "------------------------------------------------------------" >>$logfile
echo "`date`:HA_PANIC!!! PANICING!!!" >>$logfile

adb=/usr/bin/adb

sync=/usr/sbin/sync
reboot=/usr/sbin/reboot
sync_flag=1

if test $# -gt 0
then
  if test "$1" = "-nosync"
  then
    sync_flag=0
  fi
fi

if test "${sync_flag}" -gt 0
then
  ${sync}; ${sync}; ${sync}
fi

${adb} -k -w /dev/ksyms /dev/mem  << _END_OF_INPUT_
vfs_sync/W 0x81c7e008
vfs_sync+4/W 0x81e80000
vfs_syncall/W 0x81c7e008
vfs_syncall+4/W 0x81e80000
rootdir/W 0
_END_OF_INPUT_

exit 0
