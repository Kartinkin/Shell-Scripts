## Devops Homework — multi-VM AMQP 

### Goal

 Set up environment on a Vagrant boxes with AMQP broker, message publisher, message consumer and a monitoring system. Monitor queue length with alerting enabled when length exceeds certain threshold.

Provision servers with configuration management tool and automate whole setup as much as possible. All additional setup that is required on top of minimal distribution (packages, services, directories, settings) should be described as code (configuration management).

1. Prepare Vagrantfile with two boxes inside – CENTRAL and WORKER. 
2. [on CENTRAL] Setup AMQP broker – Rabbit/Zero/your choice with a single queue and no authentication.
3. [on CENTRAL] Write and deploy a simple application in Java to publish messages to broker's queue. It should take message payload from command line argument.
4. [on WORKER] Write and deploy a simple application in Python to consume messages from queue, parse the payload as integer and sleep <payload> number of seconds.
5. [on CENTRAL] Set up basic monitoring system that should monitor and keep trends of basic parameters (CPU, RAM, disk data) on CENTRAL and WORKER.
6. [on CENTRAL] Add monitoring to AMQP queue. It should report number of unprocessed messages. Set up thresholds that would trigger an alarm in the monitoring system.
7. [on CENTRAL] Create a script that shall clog the queue above the threshold set up in n.6.
8. Bonus Task. Create a script/Vagrantfile which will spin-up extra worker machine WORKER_N who will consume message on parallel with the original WORKER. It should register in monitoring too for basic parameters. Make sure we can spin-up multiple machines with this script – WORKER_2,  WORKER_3...

Deliverables

This is Vagrant environment with to type

Run 'vagrant up' in the root directory of the project to bring homework environment up. This command starts two boxes. First one is CENTRAL box with RabbitMQ server, queue filler and Ganglia monitoring system. The second is WORKER_0 box with queue reader. 

You can start any additional workers you like with 'vagrant up WORKER_<N>' command, where <N> is box number. Vagrantfile file contains WORKERS_MAX_NUM configurable parameter to make a number of worker's box templates.

Use http://localhost:8888/ganglia/ to access monitoring system. Neither username nor password are required.

1. Plain text file with short and sane instructions of:
a) how to run stress test
b) how to access monitoring system - url, credentials, etc
2. Vagrant project:
a) should contain a working configuration, so that a simple "vagrant up" can be used to set up the project
b) should contain all configuration management code that is required to set up environment
c) should contain all the necessary extra files (if any)

Technical requirements

1. Use Linux distribution of your choice, but install minimal version of it
2. Use AMQP compatible message broker – Rabbit/Zero/Jero/your choice
3. Use Puppet, Chef, Ansible or Salt as a configuration management tool
4. Use configuration management tool locally as for standalone host (without pulling configuration from server/master/etc)
5. Use Zabbix, Ganglia, Nagios or similar tools for monitoring
6. Monitoring system should only visually show alert in dashboard, no other actions required.
7. All documentation, comments, etc should be written in English

What gets evaluated

1. Requirements
2. Installation automation

3. Clarity of documentation and how easy it is to set up the project

4. Usage of configuration management tool
5. Monitoring system reactions to stress test runs
6. Ability to add workers by simply spinning extra machine
