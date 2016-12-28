publisher:
  pkg.installed:
    - name: default-jre

{% set publisher_path = pillar['Publisher']['path'] %}

{% set files = {
  'Send.class' : '644',
  'amqp-client-4.0.0.jar' : '644',
  'slf4j-api-1.7.22.jar' : '644',
  'slf4j-nop-1.7.22.jar' : '644',
  'publisher.sh' : '755',
  'check_mq.py' : '755' } %}
    
{% for file, mode in files.items() %}
{{ file }}:
  file.managed:
    - name: {{ publisher_path }}/{{ file }}
    - source: salt://publisher/{{ file }}
    - user: {{ pillar['Publisher']['user'] }}
    - group: {{ pillar['Publisher']['group'] }}
    - mode: {{ mode }}
    - require:
      - pkg: rabbitmq-server
{% endfor %}

Publisher:
  cmd.run:
    - name: sh -c "pgrep publisher.sh || {{ publisher_path }}/publisher.sh >{{ publisher_path }}/publisher.log 2>&1 &)"
    - require:
        - file: Send.class
        - file: check_mq.py