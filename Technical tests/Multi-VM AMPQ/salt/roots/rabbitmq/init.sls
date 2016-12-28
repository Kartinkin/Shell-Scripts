rabbitmq-server:
  pkg.installed:
    - name: rabbitmq-server

  service.running:
#    - enable: True
    - reload: True
    - watch:
      - pkg: rabbitmq-server
    - require:
      - file: /etc/rabbitmq/rabbitmq.config
    
  file.append:
    - name: /etc/rabbitmq/rabbitmq.config
    - text: '[{rabbit, [{loopback_users, []}]}].'