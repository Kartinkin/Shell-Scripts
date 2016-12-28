#!/usr/bin/python
import pika
import sys

QUEUE_NAME = "technical_test"
MQ_SERVER = "mq-server"
THRESHOLD = 6

def metric_handler(name):
    """Return a value for the requested metric"""
    connection = pika.BlockingConnection(pika.ConnectionParameters(host = MQ_SERVER ))
    channel = connection.channel()
    return channel.queue_declare(queue = QUEUE_NAME, durable = True).method.message_count
    
def metric_init(lparams = {}):
    """Initialize metric descriptors"""
    metric = {
        'name': 'mq_length',
        'call_back': metric_handler,
        'time_max': 60,
        'value_type': 'uint',
        'units': 'messages',
        'slope': 'both',
        'format': '%d',
        'description': "central queue length",
        'groups': 'rabbitmq' }
    return [metric]

def metric_cleanup():
    """Cleanup"""
    pass

# the following code is for debugging and testing
if __name__ == '__main__':
    len = metric_handler("")
    if len is None:
        sys.exit(3)
    if len >= THRESHOLD * 2:
        print "CRITICAL - ", len, "messages in ", QUEUE_NAME, "."
        sys.exit(2)
    elif len >= THRESHOLD:
        print "WARNING - ", len, "messages in ", QUEUE_NAME, "."
        sys.exit(1)
    else:
        print "WARNING - ", len, "messages in ", QUEUE_NAME, "."
        sys.exit(1)

