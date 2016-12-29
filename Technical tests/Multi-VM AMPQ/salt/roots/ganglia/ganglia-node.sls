##############################################################################
# Install required packages 
ganglia-node:
  pkg.installed:
    - name: ganglia-monitor
      
##############################################################################
# Configure Ganglia monitor
ganglia-monitor:
  service.running:
#    - enable: True
    - require:
      - pkg: ganglia-node
  
gmond.conf:
  file.managed:
    - name: /etc/ganglia/gmond.conf
    - source: salt://ganglia/gmond.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - context:
      cluster: {{ pillar['Ganglia']['worker_cluster']['name'] }}
      port:    {{ pillar['Ganglia']['worker_cluster']['port'] }}
      node:    true
    - require:
      - pkg: ganglia-node
    - watch_in:
      - service: ganglia-monitor

