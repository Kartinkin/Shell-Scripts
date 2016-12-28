base: 
  '*':
    - hosts
    - python
  
  {{ pillar['mq-server']['hostname'] }}:
    - rabbitmq
    - publisher
    - httpd
    - ganglia.ganglia-server
    - nagios.nagios-server
         
  '{{ pillar['workername'] }}*':
    - worker
    - ganglia.ganglia-node
    - nagios.nagios-host
