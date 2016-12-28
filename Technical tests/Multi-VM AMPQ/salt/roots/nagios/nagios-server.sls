nagios:
  pkg.installed:
    - pkgs:
      - nagios3-core
      - nagios-nrpe-plugin
      
  service.running:
    - name: nagios3
    - enable: true
    - watch:
      - pkg: nagios

  cmd.run:
    - name: htpasswd -cb /etc/nagios3/htpasswd.users nagiosadmin q1 >/dev/null 2>&1

{% for worker, ip in pillar.get('workers', {}).items() %}
/etc/nagios3/conf.d/{{ worker }}.cfg:
  file.prepend:
    - text: |
       define host{
           use       generic-host
           host_name {{ worker }}
           alias     {{ worker }}
           address   {{ ip }}
       }
    - contents: salt://resources/nagios.minion.cfg
    - require:
      - pkg: nagios 
{% endfor %}

