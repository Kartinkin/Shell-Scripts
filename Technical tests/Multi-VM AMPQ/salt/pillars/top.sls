# We got some pillars from vagrant. There are:
#  mq-server:
#    hostname:       hostname of mq-server
#    ip:             ip of mq-server
#  workername:       worker hostname prefix 
#  workers:
#    <workername>:   ip of worker-0
#    <workername-1>: ip of worker-1


base:
  '*':
    - common