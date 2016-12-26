Add central:
  host.present:
    - names:
      - {{ pillar['mq-server']['hostname'] }}
      - mq-server
    - ip: {{ pillar['mq-server']['ip'] }}

{% for hostname, ip in pillar.get('workers', {}).items() %}
Add {{ hostname }}:
  host.present:
    - name: {{ hostname }}
    - ip: {{ ip }}
{% endfor %}

python-packages:
  pkg.installed:
    - pkgs:
      - python
      - python-pip

pika:
  pip.installed:
    - require:
      - pkg: python-packages

