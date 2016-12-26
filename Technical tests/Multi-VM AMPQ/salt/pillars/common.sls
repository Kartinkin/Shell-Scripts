Worker:
  path: /home/vagrant
  user: vagrant
  group: vagrant
  
Publisher:
  path: /var/lib/rabbitmq
  user: rabbitmq
  group: rabbitmq

Ganglia:
  worker_cluster:
    name: Workers
    port: "8557"
  server_cluster:
    name: Central
    port: "8649"
