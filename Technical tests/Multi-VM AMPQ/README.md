## Devops Homework — multi-VM AMQP
### Goal
 Set up environment on a Vagrant boxes with AMQP broker, message publisher, message consumer and a monitoring system. Monitor queue length with alerting enabled when length exceeds certain threshold.

Provision servers with configuration management tool and automate whole setup as much as possible. All additional setup that is required on top of minimal distribution (packages, services, directories, settings) should be described as code (configuration management).

### Solution
This is Vagrant environment with number of VirtualBox boxes.  Download it via `git clone`. Run `vagrant up` in the root directory of the project to bring whole environment up. Two boxes will be started. First one is CENTRAL with RabbitMQ server, queue filler and monitoring system. The second is WORKER_0 with queue consumer. 

You can start any additional worker boxes you like with `vagrant up WORKER_<N>` command, where `<N>` is box number. Vagrantfile file contains `WORKERS_MAX_NUM` configurable parameter to make a number of worker's box templates.

SaltStack is used to provision hosts. It automaticaly starts script on host `central` to fullfill broker's queue. Script name is `/var/lib/rabbitmq/publisher.sh` and it log file is `/var/lib/rabbitmq/publisher.log`. Publisher sends random payloads and takes random delays between messages. Also it tunes automaticly message frequency and payload to keep queue length from `<threshold> / 2` to `<threshold> * 3 / 2`.

Worker `/home/vagrant/worker.py` (on the worker host) consumes messages from queue, parse the payload as integer and sleep `<payload>` number of seconds. It log file is `/home/vagrant/worker.py.log`.

Use [http://localhost:8888/ganglia/](http://localhost:8888/ganglia/) to access Ganglia monitoring system. Neither username nor password are required. Workers cluster consists of WORKERS nodes, Central cluster contains only one CENTRAL node. There is the `mq_length` metric for CENTRAL node, for example [http://localhost:8888/ganglia/graph.php?c=Central&h=central&v=0&m=mq_length&z=large](http://localhost:8888/ganglia/graph.php?c=Central&h=central&v=0&m=mq_length&z=large).

Unfortunatly there is no alerts in Ganglia web frontend. Zabbix installation is to complicated for me, and I don't like to use salt-formulas from Internet in homework, for this matter. So I configure Nagios for alerts. Use [http://localhost:8888/nagios3/](http://localhost:8888/ganglia/) with `nagioasadmin` as login name and `q1` as password.

Monitoring systems use script `/var/lib/rabbitmq/check_mq` to monitor queue length. The script can be used two ways: started from command line it prints queue length and returns state like Nagios plugin, also it contains `metric_init()` that returns the mq_length metric descriptor as Ganglia python monitor. 
