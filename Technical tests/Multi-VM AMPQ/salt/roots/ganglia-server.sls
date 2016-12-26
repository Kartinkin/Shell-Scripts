# Install required packages 
ganglia-server:
  pkg.installed:
    - pkgs:
      - gmetad
      - ganglia-monitor
      - rrdtool
      - ganglia-webfrontend

# Configure Apache
apache2:
  service.running:
    - enable: True
    - reload: True
    - watch:
      - file: httpd_config

httpd_config:
  file.copy:
    - name: /etc/apache2/sites-enabled/ganglia.conf
    - source: /etc/ganglia-webfrontend/apache.conf
    - require:
      - pkg: ganglia-server
 
# Configure Ganglia MetaData daemon with to clusters:
#   first for mqserver
#   second for workers
gmetad:
  service.running:
    - reload: True
    - watch:
      - pkg: ganglia-server
      - file: Comment localhost
      - file: Add data sources

Comment localhost:
  file.comment:
    - name: /etc/ganglia/gmetad.conf
    - regex: ^data_source.*localhost.*

Add data sources:
  file.blockreplace:
    - name: /etc/ganglia/gmetad.conf
    - append_if_not_found: True
    - marker_start: "# -START- Cluster for workers" 
    # I didn't find lambda...
    {% set workers = pillar.get('workers', {}).keys() %}
    {% set port = ":8557 " %}
    - content: |
        data_source "Central" 30 localhost:8649
        data_source "Workers" {{ port.join(workers) }}{{ port }}
    - marker_end:   "# --END-- Cluster for workers" 

ganglia-monitor:
  service.running:
    - reload: True
    - watch:
      - pkg: ganglia-server
      - file: Add node to cluster
      - file: Set udp_recv_channel
      - file: Set tcp_accept_channel
      - file: Set udp_send_channel
      - file: modpython config
      - file: monrabbit
      - file: monrabbit config
 
Add node to cluster:    
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "cluster {"
    - marker_end: owner = "unspecified"
    - content: '  name = "Central"'

Set udp_recv_channel: 
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "udp_recv_channel {" 
    - marker_end: "}"
    - content: "  port = 8649"

Set tcp_accept_channel:
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "tcp_accept_channel {"
    - marker_end: "}"
    - content: "  port = 8649"

Set udp_send_channel:
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "udp_send_channel {"
    - marker_end: "}"
    - content: |
        host = localhost
        port = 8649
        ttl = 1
    - show_changes: True

modpython config:
  file.managed:
    - name: /etc/ganglia/conf.d/modpython.conf
    - source: salt://resources/modpython.conf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
 
monrabbit:
  file.managed:
    - name:  /usr/lib/ganglia/python_modules/monrabbit.py
    - source: salt://resources/monrabbit.py
    - makedirs: True
    - user: root
    - group: root
    - mode: 755
    - require:
      - pip: pika

monrabbit config:
  file.managed:
    - name: /etc/ganglia/conf.d/monrabbit.pyconf
    - source: salt://resources/monrabbit.pyconf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
