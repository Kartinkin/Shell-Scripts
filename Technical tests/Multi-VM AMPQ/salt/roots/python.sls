# Install python packages
python-packages:
  pkg.installed:
    - pkgs:
      - python
      - python-pip

pika:
  pip.installed:
    - require:
      - pkg: python-packages

