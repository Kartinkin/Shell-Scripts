##############################################################################
# Install required packages 
ganglia-server:
  pkg.installed:
    - pkgs:
      - gmetad
      - ganglia-monitor
      - rrdtool
      - ganglia-webfrontend

##############################################################################
# Configure Apache
/etc/apache2/sites-enabled/ganglia.conf:
  file.copy:
    - source: /etc/ganglia-webfrontend/apache.conf
    - require:
      - pkg: ganglia-server
      - pkg: apache2 
    - watch_in:
      - pkg: httpd-service

##############################################################################
# Configure Ganglia MetaData daemon with to clusters:
#   first for mqserver
#   second for workers
gmetad:
  service.running:
#    - enable: True
    - require:
      - pkg: ganglia-server

gmetad.conf:
  file.managed:
    - name: /etc/ganglia/gmetad.conf
    - source: salt://ganglia/gmetad.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ganglia-server
    - watch_in:
      - service: gmetad

#Comment default data source:
#  file.comment:
#    - name: /etc/ganglia/gmetad.conf
#    - regex: ^data_source\s["']((?!Central).)*['"]
#    - require:
#      - pkg: ganglia-server
#
#{% set server_cluster_name = pillar['Ganglia']['server_cluster']['name'] %}
#{% set server_cluster_port = pillar['Ganglia']['server_cluster']['port'] %}
#{% set worker_cluster_name = pillar['Ganglia']['worker_cluster']['name'] %}
#{% set worker_cluster_port = pillar['Ganglia']['worker_cluster']['port'] %}
#
#Add data sources:
#  file.blockreplace:
#    - name: /etc/ganglia/gmetad.conf
#    - append_if_not_found: True
#    - marker_start: "# -START- Salt.ganglia.ganglia-server.sls"
#
#    # I didn't find lambda...
#    {% set workers = pillar.get('workers', {}).keys() %}
#    {% set port = ":" + worker_cluster_port.__str__() + " " %}
#
#    - content: |
#        data_source "{{ server_cluster_name }}" 30 localhost:{{ server_cluster_port }}
#        data_source "{{ worker_cluster_name }}" {{ port.join(workers) }}{{ port }}
#    - marker_end: "# --END-- Salt.ganglia.ganglia-server.sls" 
#    - require:
#      - pkg: ganglia-server

##############################################################################
# Configure Ganglia monitor
ganglia-monitor:
  service.running:
#    - enable: True
    - require:
      - pkg: ganglia-server

gmond.conf:
  file.managed:
    - name: /etc/ganglia/gmond.conf
    - source: salt://ganglia/gmond.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - context:
      cluster: {{ pillar['Ganglia']['server_cluster']['name'] }}
      port:    {{ pillar['Ganglia']['server_cluster']['port'] }}
      node:    false
    - require:
      - pkg: ganglia-server
    - watch_in:
      - service: ganglia-monitor

##############################################################################
# Configure gmont to monitor message queue
modpython config:
  file.managed:
    - name: /etc/ganglia/conf.d/modpython.conf
    - source: salt://ganglia/modpython.conf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ganglia-server
      - file: monrabbit
    - watch_in:
      - service: ganglia-monitor
 
monrabbit:
  file.symlink:
    - name:  /usr/lib/ganglia/python_modules/monrabbit.py
    - target: {{ pillar['Publisher']['path'] }}/check_mq.py
    - makedirs: True
    - require:
      - file: check_mq.py
      - pkg: ganglia-server
    - watch_in:
      - service: ganglia-monitor

monrabbit config:
  file.managed:
    - name: /etc/ganglia/conf.d/monrabbit.pyconf
    - source: salt://ganglia/monrabbit.pyconf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ganglia-server
      - file: monrabbit
    - watch_in:
      - service: ganglia-monitor

##############################################################################
# Add mq_report
mq_report.php:
  file.managed:
    - name: /usr/share/ganglia-webfrontend/graph.d/mq_report.php
    - source: salt://ganglia/mq_report.php
    - user: root
    - group: root
    - mode: 644
    - require:
       - pkg: ganglia-server
    - watch_in:
       - service: gmetad
  
##############################################################################
#Set mq_report:
#  file.blockreplace:
#    - name: /usr/share/ganglia-webfrontend/templates/default/cluster_view.tpl 
#    - marker_start: '<TD ROWSPAN=2 ALIGN="CENTER" VALIGN=top>'
#    - content: |
#        <A HREF="./graph.php?g=mq_report&amp;z=large&amp;{graph_args}">
#        <IMG BORDER=0 ALT="{cluster} LOAD"
#        SRC="./graph.php?g=mq_report&amp;z=medium&amp;{graph_args}">
#        </A>
#    - marker_end: '<A HREF="./graph.php?g=load_report&amp;z=large&amp;{graph_args}">'
#    - require:
#       - pkg: ganglia-server

