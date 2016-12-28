base: 
  '*':
    - hosts
    - python
  
  {{ pillar['mq-server']['hostname'] }}:
    - rabbitmq
    - publisher
#    - ganglia.ganglia-server
    - nagios.nagios-server
         
  '{{ pillar['workername'] }}*':
    - worker
#    - ganglia.ganglia-node
    - nagios.nagios-minion
