#!/bin/bash
##############################################################################
# This program full fills message queue
# The threshold when the queue "full"
THRESHOLD=6
# Payload will [0, MAX_PAYLOAD)
max_payload=6
# Maximum delay in seconds between messages
max_delay=4
# Recalculate delays every REC_TIME messages
rec_time=$(( THRESHOLD / 2 ))

##############################################################################
# Program to monitor queue length
# It prints string like "<some name> = <value>"
Path=${0%/*}/
QUEUE_MONITOR="${Path}check_mq.py"

# Program that sends messages
# Takes payload as parameter
SENDER="Send.class"
# jars that sender depends on 
JARS=(amqp-client-4.0.0.jar slf4j-api-1.7.22.jar slf4j-nop-1.7.22.jar)

##############################################################################
# Looking for SENRER in current directory
if [[ -f ${SENDER} ]]
then
	Path=""
fi
# and in directory this script called from
if [[ ! -f ${Path}${SENDER} ]]
then
	print "ERROR: Neither ./${SENDER} nor ${Path}${SENDER}	found." >&2
	exit 1
fi

# Check QUEUE_MONITOR presents
if [[ ! -x ${QUEUE_MONITOR} ]]
then
	print "ERROR: ${QUEUE_MONITOR} not found." >&2
	exit 1
fi

# Build jars list for "java -cp"
includes="${Path}."
for jar in ${JARS[*]}
do
	includes+=":${Path}${jar}"
done

##############################################################################
# Fill queue
# Use i to count messages between recalculations of the delays
# Change only one bound (max_delay and max_payload) at a time
# Bounds can't be more than 20 and less than 2
i=1
delay=0
UPPER_BOUND=$(( THRESHOLD * 3 / 2))
BOTTOM_BOUND=$(( THRESHOLD / 2 ))
while true
do
	# Take pseudo-random number and send message
	java -cp ${includes} ${SENDER%.*} $((RANDOM % max_payload)) 1>&2

	if (( i == rec_time ))
	then # Recalculate MAX_PAYLOAD if needed
     	set -- $(${QUEUE_MONITOR})
        length=$3
        if (( length >= UPPER_BOUND ))
        then
            (( max_payload = max_payload > 2 ? max_payload - 1 : max_payload ))
        elif (( length < BOTTOM_BOUND ))
        then
            (( max_payload = max_payload < 20 ? max_payload + 1 : max_payload ))
        fi
        echo "Queue length: ${length}, max_payload: ${max_payload}" >&2
    elif (( i == rec_time * 2 ))
    then # Recalculate MAX_DELAY if needed
     	set -- $(${QUEUE_MONITOR})
        length=$3
        if (( length >= UPPER_BOUND ))
        then
            (( max_delay =  max_delay < 20 ? max_delay + 1 : max_delay ))
        elif (( length < BOTTOM_BOUND ))
        then
            (( max_delay = max_delay > 2 ? max_delay - 1 : max_delay ))
        fi
        echo "Queue length: ${length}, max_delay: ${max_delay}" >&2
        i=0
    fi
    (( i += 1 ))
    sleep $((RANDOM % max_delay))
done