#!/bin/bash
##############################################################################
# This program full fills message queue
# The threshold when the queue "full"
THRESHOLD=6
# Payload will [0, MAX_PAYLOAD)
MAX_PAYLOAD=10
# Maximum delay in seconds between messages
MAX_DELAY=2

##############################################################################
# Program to monitor queue length
# It prints string like "<some name> = <value>"
QUEUE_MONITOR="/usr/lib/ganglia/python_modules/monrabbit.py"

function QueueTooLong
{ # Function checks queue length and returns
  #    true    queue length > THRESHOLD * 3
  #    false   else
	Length=$(${QUEUE_MONITOR})
	Length=${Length##* }
	echo "Queue length: ${Length}" >&2
	(( Length / 3 > THRESHOLD ))
}

# Program that sends messages
# Takes payload as parameter
SENDER="Send.class"
# jars that sender depends on 
JARS=(amqp-client-4.0.0.jar slf4j-api-1.7.22.jar slf4j-nop-1.7.22.jar)

##############################################################################
Path=${0%/*}/
# Looking for SENRER in current directory
if [[ -f ${SENDER} ]]
then
	Path=""
fi
# and in directory this script called from
if [[ ! -f ${Path}${SENDER} ]]
then
	print "ERROR: Neither ./${SENDER} nor ${Path}${SENDER}	found."
	exit 1
fi

# Check QUEUE_MONITOR presents
if [[ ! -x ${QUEUE_MONITOR} ]]
then
	print "ERROR: ${QUEUE_MONITOR} not found."
	exit 1
fi

# Build jars list for "java -cp"
Includes="${Path}."
for Jar in ${JARS[*]}
do
	Includes+=":${Path}${Jar}"
done

# Fill queue
i=0
while true
do
	# Take pseudo-random number
	Delay=$RANDOM
	(( Delay %= MAX_PAYLOAD))
	# Send message
	java -cp ${Includes} ${SENDER%.*} ${Delay}

    if (( i < THRESHOLD ))
    then
       (( i += 1 ))
       continue
    fi
	Delay=$RANDOM
	(( Delay %= MAX_DELAY))
	sleep ${Delay}
    (( Delay += 1 ))
    while $(QueueTooLong)
	do
	    echo "Sleepping ${Delay}"
		sleep ${Delay}
	done
done