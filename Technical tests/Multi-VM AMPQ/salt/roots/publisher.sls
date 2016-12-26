publisher:
  pkg.installed:
    - name: default-jre

{% for file in 'Send.class', 'amqp-client-4.0.0.jar', 'slf4j-api-1.7.22.jar', 'slf4j-nop-1.7.22.jar' %}
{{ file }}:
  file.managed:
    - name: /var/lib/rabbitmq/{{ file }}
    - source: salt://resources/{{ file }}
    - user: rabbitmq
    - group: rabbitmq
    - mode: 644
    - require:
      - pkg: rabbitmq-server
{% endfor %}
