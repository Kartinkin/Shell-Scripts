nagios-host:
  pkg.installed:
    - name: nagios-nrpe-server
      
  file.append:
    - name: /etc/nagios/nrpe.cfg
    - text: server_address={{ pillar['mq-server']['hostname'] }}

#  service.enabled: