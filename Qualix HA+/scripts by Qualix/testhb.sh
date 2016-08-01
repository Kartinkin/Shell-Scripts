#!/bin/sh

#
# Copyright (c) 1996, 1997 Qualix Group, Inc. All Rights Reserved.
#
# $Id: testhb.sh,v 1.4 1998/01/24 00:16:55 plv Exp $
#

ping=/usr/sbin/ping

${ping} $* > /dev/null 2>&1
