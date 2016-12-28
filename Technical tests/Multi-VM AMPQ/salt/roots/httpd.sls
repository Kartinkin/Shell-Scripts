##############################################################################
# Configure Apache
apache2:
  pkg.installed:
    - name: apache2

httpd-service:
  service.running:
    - name: apache2
    - enable: True
    - reload: True
    - require:
      - pkg: apache2 
