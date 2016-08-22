#!/bin/sh

PATH="/usr/bin:/usr/sbin:${PATH}"
export PATH

while read src dest
do
	awk -F= '$1=="EXP_VERSION" { print "EXP_VERSION='${EXP_VERSION}'" ; continue }
		{ print }' <$src >$dest
done

exit 0
