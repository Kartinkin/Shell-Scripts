base: 
  '*':
    - common
  
  {{ pillar['mq-server']['hostname'] }}:
    - rabbitmq
    - publisher
#    - nagios-server
    - ganglia-server
    
  '{{ pillar['workername'] }}*':
    - worker
#    - nagios-minion
    - ganglia-node

