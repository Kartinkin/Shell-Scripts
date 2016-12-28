#!/usr/bin/python
"""
This program can be used two ways:
    as Ganglia python monitor. It contains metric_init()
        returns the mq_length metric descriptor.
    as Nagios check command. It prints queue length and
        returns state when started from command line.
"""
import pika
import sys

# Threshold value for Nagios states:
#    queue length >= THRESHOLD * 2 -- critical, exit value 2
#    queue length >= THRESHOLD     -- warning, exit value 1
#    queue length < THRESHOLD      -- OK, exit value 0
THRESHOLD = 6

QUEUE_NAME = "technical_test"
MQ_SERVER = "mq-server"

def metric_handler(name):
    """Return a value for the requested metric"""
    connection = pika.BlockingConnection(pika.ConnectionParameters(host = MQ_SERVER ))
    channel = connection.channel()
    return channel.queue_declare(queue = QUEUE_NAME, durable = True).method.message_count
    
def metric_init(lparams = {}):
    """Initialize metric descriptor"""
    return {
        'name': 'mq_length',
        'call_back': metric_handler,
        'time_max': 60,
        'value_type': 'uint',
        'units': 'messages',
        'slope': 'both',
        'format': '%d',
        'description': "central queue length",
        'groups': 'rabbitmq' }

def metric_cleanup():
    """Cleanup"""
    pass

if __name__ == '__main__':
#   Called from command line
    len = metric_handler("")
    if len is None:
        sys.exit(3)
    if len >= THRESHOLD * 2:
        print "CRITICAL - ", len, "messages in", QUEUE_NAME
        sys.exit(2)
    elif len >= THRESHOLD:
        print "WARNING - ", len, "messages in", QUEUE_NAME
        sys.exit(1)
    else:
        print "OK - ", len, "messages in", QUEUE_NAME
        sys.exit(1)

