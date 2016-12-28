publisher:
  pkg.installed:
    - name: default-jre

{% set p_path = pillar['Publisher']['path'] %}

# Copy sender, jars, publisher and monitor
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
    - name: {{ p_path }}/{{ file }}
    - source: salt://publisher/{{ file }}
    - user: {{ pillar['Publisher']['user'] }}
    - group: {{ pillar['Publisher']['group'] }}
    - mode: {{ mode }}
    - require:
      - pkg: rabbitmq-server
{% endfor %}

# Start or restart publisher
Publisher:
  cmd.run:
    - name: sh -c "pkill publisher.sh ; {{ p_path }}/publisher.sh >>{{ p_path }}/publisher.log 2>&1 &)"
    - watch:
      - file: publisher.sh
    - require:
        - file: Send.class
        - file: check_mq.py