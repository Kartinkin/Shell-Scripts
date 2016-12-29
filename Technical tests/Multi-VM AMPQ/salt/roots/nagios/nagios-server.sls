##############################################################################
# Install required packages 
nagios-server:
  pkg.installed:
    - pkgs:
      - nagios3
      - nagios-plugins
      - nagios-nrpe-plugin

nagios-service:
  service.running:
    - name: nagios3
    - enable: True
    - require:
      - pkg: nagios-server
     
##############################################################################
# Set nagioasadmin's password to 'q1' 
Password:
  cmd.run:
    - name: htpasswd -cb /etc/nagios3/htpasswd.users nagiosadmin q1 >/dev/null 2>&1
    - pkg: nagios-server
    - require:
      - pkg: nagios-server
      - pkg: apache2 
    - watch_in:
      - pkg: httpd-service
    
##############################################################################
# Configure Apache
/etc/apache2/sites-enabled/nagios.conf:
  file.copy:
    - source: /etc/nagios3/apache2.conf
    - require:
      - pkg: nagios-server
      - cmd: Password
    - watch_in:
      - pkg: httpd-service

##############################################################################
# Copy server's config file
localhost_nagios2.cfg:
  file.managed:
    - name: /etc/nagios3/conf.d/localhost_nagios2.cfg
    - source: salt://nagios/localhost_nagios2.cfg
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: nagios-server
    - watch_in:
      - service: nagios-service
 
##############################################################################
# Generate config files of worker hosts
{% for worker, ip in pillar['workers'].items() %}
{{ worker }}_nagios2.cfg:
  file.managed:
    - name: /etc/nagios3/conf.d/{{ worker }}_nagios2.cfg
    - source: salt://nagios/worker_nagios2.cfg
    - template: jinja
    - context:
      worker: {{ worker}}
      ip: {{ ip }}
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: nagios-server
    - watch_in:
      - service: nagios-service
{% endfor %}

##############################################################################
# Add service check_mq for mq-server
check_mq:
  file.symlink:
    - name: /usr/lib/nagios/plugins/check_mq
    - target: {{ pillar['Publisher']['path'] }}/check_mq.py
    - require:
      - file: check_mq.py
      - pkg: nagios-server

/etc/nagios-plugins/config/check_mq.cfg:
  file.managed:
    - source: salt://nagios/check_mq.cfg
    - require:
      - file: check_mq
    - watch_in:
      - service: nagios-service

