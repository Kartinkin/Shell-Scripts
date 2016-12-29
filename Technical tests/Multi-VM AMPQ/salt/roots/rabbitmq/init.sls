rabbitmq-server:
  pkg.installed:
    - name: rabbitmq-server

  service.running:
    - enable: True
    - require:
      - pkg: rabbitmq-server
    - watch:
      - file: /etc/rabbitmq/rabbitmq.config
    
  file.append:
    - name: /etc/rabbitmq/rabbitmq.config
    - text: '[{rabbit, [{loopback_users, []}]}].'