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
    - watch:
      - pkg: nagios-server
     
##############################################################################
# Set nagioasadmin's password to 'q1' 
Password:
  cmd.run:
    - name: htpasswd -cb /etc/nagios3/htpasswd.users nagiosadmin q1 >/dev/null 2>&1
    - pkg: nagios-server
    - watch_in:
      - service: nagios-service
    
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
    - watch_in:
      - service: nagios-service
 
##############################################################################
# Generate config files of worker hosts
{% for worker, ip in pillar['workers'].items() %}
Create config {{ worker }}:
  file.managed:
    - name: /etc/nagios3/conf.d/{{ worker }}_nagios2.cfg
    - source: salt://nagios/localhost_nagios2.cfg
    - require:
      - file: localhost_nagios2.cfg
    - watch_in:
      - service: nagios-service

Add hostname to {{ worker }}:
  file.blockreplace:
    - name: /etc/nagios3/conf.d/{{ worker }}_nagios2.cfg
    - marker_start: "define host{" 
    - content: |
           use       generic-host
           host_name {{ worker }}
           alias     {{ worker }}
           address   {{ ip }}
    - marker_end: "}"
    - require:
      - file: Create config {{ worker }}
    - watch_in:
      - service: nagios-service

Add services to {{ worker }}:
  file.replace:
    - name: /etc/nagios3/conf.d/{{ worker }}_nagios2.cfg
    - pattern: host_name.*localhost
    - repl: "   host_name    {{ worker }}"
    - require:
      - file: Create config {{ worker }}
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

/etc/nagios-plugins/config/check_mq.cfg:
  file.managed:
    - source: salt://nagios/check_mq.cfg
    - watch_in:
      - service: nagios-service

Add mq_check:
  file.append:
    - name: /etc/nagios3/conf.d/localhost_nagios2.cfg
    - text: |
        define service{
        use                             generic-service         ; Name of service template to use
        host_name                       localhost
        service_description             RabbitMQ queue length
        check_command                   check_mq
        }
    - require:
      - file: localhost_nagios2.cfg
    - watch_in:
      - service: nagios-service

