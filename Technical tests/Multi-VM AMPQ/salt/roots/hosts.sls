# Create records in /etc/hosts for all VMs
Add central to /etc/host:
  host.present:
    - names:
      - {{ pillar['mq-server']['hostname'] }}
      - mq-server
    - ip: {{ pillar['mq-server']['ip'] }}

{% for hostname, ip in pillar.get('workers', {}).items() %}
Add {{ hostname }} to /etc/host:
  host.present:
    - name: {{ hostname }}
    - ip: {{ ip }}
{% endfor %}
