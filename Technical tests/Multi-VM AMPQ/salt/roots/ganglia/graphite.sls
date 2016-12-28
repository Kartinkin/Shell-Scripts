cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-enabled/
apt-get install libapache2-mod-wsgi

sudo -u www-data python /usr/lib/python2.7/dist-packages/graphite/manage.py syncdb --noinput