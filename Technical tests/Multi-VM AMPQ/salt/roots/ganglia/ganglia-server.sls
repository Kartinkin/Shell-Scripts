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
      - file: Comment default data source
      - file: Add data sources
      - network: routes

Comment default data source:
  file.comment:
    - name: /etc/ganglia/gmetad.conf
    - regex: ^data_source\s["']((?!Central).)*['"]

{% set server_cluster_name = pillar['Ganglia']['server_cluster']['name'] %}
{% set server_cluster_port = pillar['Ganglia']['server_cluster']['port'] %}
{% set worker_cluster_name = pillar['Ganglia']['worker_cluster']['name'] %}
{% set worker_cluster_port = pillar['Ganglia']['worker_cluster']['port'] %}

Add data sources:
  file.blockreplace:
    - name: /etc/ganglia/gmetad.conf
    - append_if_not_found: True
    - marker_start: "# -START- Salt.ganglia.ganglia-server.sls" 
    # I didn't find lambda...
    {% set workers = pillar.get('workers', {}).keys() %}
    {% set port = ":" + worker_cluster_port + " " %}
    - content: |
        data_source "{{ server_cluster_name }}" 30 localhost:{{ server_cluster_port }}
        data_source "{{ worker_cluster_name }}" {{ port.join(workers) }}{{ port }}
    - marker_end: "# --END-- Salt.ganglia.ganglia-server.sls" 

# Configure Ganglia monitor
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
    - content: '  name = "{{ server_cluster_name }}"'

Set udp_recv_channel: 
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "udp_recv_channel {" 
    - marker_end: "}"
    - content: "  port = {{ server_cluster_port }}"

Set tcp_accept_channel:
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "tcp_accept_channel {"
    - marker_end: "}"
    - content: "  port = {{ server_cluster_port }}"

Set udp_send_channel:
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "udp_send_channel {"
    - marker_end: "}"
    - content: |
        host = localhost
        port = {{ server_cluster_port }}
        ttl = 1
    - show_changes: True

# Configure gmont to monitor message queue
modpython config:
  file.managed:
    - name: /etc/ganglia/conf.d/modpython.conf
    - source: salt://ganglia/modpython.conf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
 
monrabbit:
  file.managed:
    - name:  /usr/lib/ganglia/python_modules/monrabbit.py
    - source: salt://ganglia/monrabbit.py
    - makedirs: True
    - user: root
    - group: root
    - mode: 755
    - require:
      - pip: pika

monrabbit config:
  file.managed:
    - name: /etc/ganglia/conf.d/monrabbit.pyconf
    - source: salt://ganglia/monrabbit.pyconf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
