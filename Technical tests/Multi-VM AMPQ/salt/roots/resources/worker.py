#!/usr/bin/python
import pika
import time

QUEUE_NAME = "technical_test"
MQ_SERVER = "mq-server"

connection = pika.BlockingConnection(pika.ConnectionParameters(host = MQ_SERVER ))
channel = connection.channel()
channel.queue_declare(queue = QUEUE_NAME, durable = True)

def callback(channel, method, properties, body):
	print "Received", body
	try:
		time.sleep(int(body))
	except ValueError:
		pass
	print "Done"
	channel.basic_ack(delivery_tag = method.delivery_tag)

channel.basic_qos(prefetch_count=1)
channel.basic_consume(callback, queue = QUEUE_NAME)
channel.start_consuming()
