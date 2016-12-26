publisher:
  pkg.installed:
    - name: default-jre

{% for file in 'Send.class', 'amqp-client-4.0.0.jar', 'slf4j-api-1.7.22.jar', 'slf4j-nop-1.7.22.jar' %}
{{ file }}:
  file.managed:
    - name: {{ pillar['Publisher']['path'] }}/{{ file }}
    - source: salt://publisher/{{ file }}
    - user: {{ pillar['Publisher']['user'] }}
    - group: {{ pillar['Publisher']['group'] }}
    - mode: 644
    - require:
      - pkg: rabbitmq-server
{% endfor %}
