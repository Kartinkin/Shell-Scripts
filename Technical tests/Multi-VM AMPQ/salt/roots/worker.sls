#python-packages:
#  pkg.installed:
#    - pkgs:
#     - python
#      - python-pip

#pika:
#  pip.installed:
#    - require:
#      - pkg: python-packages

worker:
  file.managed:
    - name: /home/vagrant/worker.py
    - source: salt://resources/worker.py
    - user: vagrant
    - group: vagrant
    - mode: 755
    - watch:
      - pip: pika
      
  cmd.run:
    - name: sh -c "pgrep worker.py || (/home/vagrant/worker.py >/dev/null 2>&1 &)"
      
