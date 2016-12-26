#!/usr/bin/python
import pika

QUEUE_NAME = "technical_test"
MQ_SERVER = "mq-server"

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
    descriptors = metric_init({})
    for d in descriptors:
        print (('%s = %s') % (d['name'], d['format'])) % (d['call_back'](d['name']))
