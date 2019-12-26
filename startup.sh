#!/bin/bash
## ScriptName  : CentOS_TestLink_Redmine
## reference: https://www.vultr.com/docs/how-to-install-testlink-on-centos-7

set -x

function centos8() {

# locale
dnf install -y langpacks-ja || exit 1
rm /etc/localtime
ln -s /usr/share/zoneinfo/Japan /etc/localtime

FWSTAT=$(systemctl status firewalld.service | awk '/Active/ {print $2}')

if [ "${FWSTAT}" = "inactive" ]; then
    systemctl start firewalld.service
    firewall-cmd --zone=public --add-service=ssh --permanent
    systemctl enable firewalld.service
fi

firewall-cmd --add-service=http --zone=public --permanent
firewall-cmd --add-service=https --zone=public --permanent
# firewall testlink
firewall-cmd --zone=public --add-port=30000/tcp --permanent
# firewall redmine
firewall-cmd --zone=public --add-port=30001/tcp --permanent

firewall-cmd --reload

# dnf repository
dnf config-manager --set-enabled PowerTools
dnf -y install epel-release
dnf config-manager --set-enabled epel

dnf -y install redhat-rpm-config || exit 1
dnf -y install expect byobu || exit 1
dnf -y install git svn || exit 1

# dnf LAMP
#dnf -y --disablerepo=epel install httpd-devel mod_ssl php php-devel php-pear mariadb-server php-mbstring php-xml php-gd php-mysqlnd git svn || exit 1
dnf -y install httpd-devel mod_ssl php php-devel php-pear mariadb-server \
 php-mbstring php-xml php-gd php-mysqlnd || exit 1

# php.ini testlink
sudo cp /etc/php.ini /etc/php.ini.bak
sudo sed -i "s/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 2880/" /etc/php.ini
sudo sed -i "s/max_execution_time = 30/max_execution_time = 120/" /etc/php.ini

# git clone testlink
if [ ! -e /var/lib/testlink-code]; then
    git clone -b testlink_1_9 https://github.com/TestLinkOpenSourceTRMS/testlink-code.git
    sudo mv testlink-code /var/lib/
    sudo chown -R apache:apache /var/lib/testlink-code
    sudo cp /var/lib/testlink-code/custom_config.inc.php.example /var/lib/testlink-code/custom_config.inc.php
    sudo sed -i "s|// $tlCfg->log_path = '/var/testlink-ga-testlink-code/logs/';|$tlCfg->log_path = '/var/lib/testlink-code/logs/';|" /var/lib/testlink-code/custom_config.inc.php
    sudo sed -i "s|// $g_repositoryPath = '/var/testlink-ga-testlink-code/upload_area/';|$g_repositoryPath = '/var/lib/testlink-code/upload_area/';|" /var/lib/testlink-code/custom_config.inc.php
fi

# dnf redmine4 (build)
dnf -y install libxml2-devel libxslt-devel gcc bzip2 openssl-devel \
 zlib-devel gdbm-devel ncurses-devel autoconf automake bison gcc-c++ \
 libffi-devel libtool patch readline-devel sqlite-devel \
 glibc-headers glibc-devel libicu-devel libidn-devel libyaml || exit 1

# dnf redmine3 (build)
# dnf -y install readline-devel zlib-devel curl-devel libyaml openssl-devel \
# libxml2-devel libxslt-devel sqlite-devel || exit 1

# dnf redmine (epel)
dnf -y install ImageMagick-devel libyaml-devel || exit 1
# dnf redmine ruby
dnf -y install ruby ruby-devel || exit 1

# gem rails
echo 'gem: -N' >/etc/gemrc
gem install rails -N || exit 1

# dnf redmine HTTP RDB
dnf -y install httpd-devel mod_ssl mariadb-server mariadb-devel || exit 1

cat <<-EOT >/etc/my.cnf
    [mysqld]
    datadir=/var/lib/mysql
    socket=/var/lib/mysql/mysql.sock
    user=mysql
    # Disabling symbolic-links is recommended to prevent assorted security risks
    symbolic-links=0
    innodb_file_per_table
    query-cache-size=16M
    character-set-server=utf8
    [mysql]
    default-character-set=utf8
EOT

systemctl status mariadb.service >/dev/null 2>&1 || systemctl start mariadb.service
for i in {1..5}; do
    sleep 1
    systemctl status mariadb.service && break
    [ "$i" -lt 5 ] || exit 1
done
systemctl enable mariadb.service || exit 1

# mariaDB Setting
if [ ! -f /root/.my.cnf ]; then
NEWMYSQLPASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

/usr/bin/mysqladmin -u root password "$NEWMYSQLPASSWORD" || exit 1

cat <<-EOT >/root/.my.cnf
        [client]
        host     = localhost
        user     = root
        password = $NEWMYSQLPASSWORD
        socket   = /var/lib/mysql/mysql.sock
EOT
chmod 600 /root/.my.cnf
fi

USERNAME="rm_$(mkpasswd -l 10 -C 0 -s 0)"
PASSWORD=$(mkpasswd -l 32 -d 9 -c 9 -C 9 -s 0 -2)

# mariaDB database redmine
echo "create database db_redmine default character set utf8;" | mysql --defaults-file=/root/.my.cnf
echo "grant all on db_redmine.* to $USERNAME@'localhost' identified by '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf
# mariaDB database testlink
echo "CREATE DATABASE testlink;" | mysql --defaults-file=/root/.my.cnf
echo "CREATE USER 'testlinkuser'@'localhost' IDENTIFIED BY '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf
echo "GRANT ALL PRIVILEGES ON testlink.* TO 'testlinkuser'@'localhost' IDENTIFIED BY '$PASSWORD' WITH GRANT OPTION;" | mysql --defaults-file=/root/.my.cnf
echo "flush privileges;" | mysql --defaults-file=/root/.my.cnf

svn co http://svn.redmine.org/redmine/branches/3.4-stable /var/lib/redmine || exit 1

cat <<-EOT >/var/lib/redmine/config/database.yml
production:
    adapter: mysql2
    database: db_redmine
    host: localhost
    username: $USERNAME
    password: $PASSWORD
    encoding: utf8
EOT

cd /var/lib/redmine || exit 1
gem install json || exit 1
gem install sprockets -v 3.7.2 || exit 1
gem uninstall bundler
gem install bundler --version '1.17.3' || exit 1
bundle install --without development test || exit 1
bundle exec rake generate_secret_token || exit 1
RAILS_ENV=production bundle exec rake db:migrate

# httpd.conf
cat <<-EOT >/etc/httpd/conf.d/testlink.conf
NameVirtualHost *:30000
Listen 30000
<VirtualHost *:30000>
DocumentRoot /var/lib/testlink-code
<Directory "/var/lib/testlink-code">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
</Directory>
ErrorLog /var/log/httpd/testlink-error_log
CustomLog /var/log/httpd/testlink-access_log common
</VirtualHost>
EOT
cat <<-EOT >/etc/httpd/conf/redmine.conf
NameVirtualHost *:30001
Listen 30001
<VirtualHost *:30001>
DocumentRoot /var/lib/redmine/public
<Directory "/var/lib/redmine/public">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
</Directory>
ErrorLog /var/log/httpd/redmine-error_log
CustomLog /var/log/httpd/redmine-access_log common
</VirtualHost>
EOT

# httpd redmine
gem install passenger -N || exit 1
passenger-install-apache2-module -a
passenger-install-apache2-module --snippet >/etc/httpd/conf.d/passenger.conf
chown -R apache:apache /var/lib/redmine
echo "Include conf/redmine.conf" >>/etc/httpd/conf/httpd.conf

systemctl status httpd.service >/dev/null 2>&1 || systemctl start httpd.service
for i in {1..5}; do
    sleep 1
    systemctl status httpd.service && break
    [ "$i" -lt 5 ] || exit 1
done
systemctl enable httpd.service || exit 1

reboot

}

### main ###

VERSION=$(rpm -q centos-release --qf "%{VERSION}")

[ "$VERSION" = "8.0" ] && centos8
