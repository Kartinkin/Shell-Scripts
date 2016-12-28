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

{% set publisher_sh = "publisher.sh" %}
{% set publisher_path = pillar['Publisher']['path'] + "/" + publisher_sh %}
{{ publisher_sh }}:
  file.managed:
    - name: {{ publisher_path }}
    - source: salt://publisher/{{ publisher_sh }}
    - user: {{ pillar['Publisher']['user'] }}
    - group: {{ pillar['Publisher']['group'] }}
    - mode: 755
    - require:
      - pkg: rabbitmq-server

  cmd.run:
    - name: sh -c "pgrep {{ publisher_sh }} || {{ publisher_path }} >{{ publisher_path }}.log 2>&1 &)"
    - require:
        - file: Send.class
        - file: monrabbit
