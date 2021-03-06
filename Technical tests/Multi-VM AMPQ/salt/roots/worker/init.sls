{% set worker_py = 'worker.py' %}
{% set worker_path = pillar['Worker']['path'] + '/' + worker_py %}

worker:
  file.managed:
    - name: {{ worker_path }}
    - source: salt://worker/worker.py
    - user: {{ pillar['Worker']['user'] }}
    - group: {{ pillar['Worker']['group'] }}
    - mode: 755
      
  cmd.run:
    - name: sh -c "pgrep {{ worker_py }} || {{ worker_path }} >>{{ worker_path }}.log 2>&1 &)"
    - require:
      - pkg: python-packages # Python and pika packages come from common.sls
