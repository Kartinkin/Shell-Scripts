base: 
  '*':
    - hosts
    - python
  
  {{ pillar['mq-server']['hostname'] }}:
    - rabbitmq
    - publisher
    - ganglia.ganglia-server
    
  '{{ pillar['workername'] }}*':
    - worker
    - ganglia.ganglia-node

