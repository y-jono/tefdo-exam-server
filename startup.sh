#!/bin/bash
## ScriptName  : CentOS_TestLink_Redmine
## reference: https://www.vultr.com/docs/how-to-install-testlink-on-centos-7

set -x

function provision() {

## Update all dnf package
dnf update -y || exit 1
dnf -y install redhat-rpm-config || exit 1
## dnf repository setting
dnf config-manager --set-enabled PowerTools
dnf -y install epel-release
dnf config-manager --set-enabled epel
## レポジトリ設定を更新したのでmetadataやpackageの不整合を防ぐために色々クリアする
dnf clean all -y || exit 1

## locale settings
dnf install -y langpacks-ja || exit 1
rm /etc/localtime
ln -s /usr/share/zoneinfo/Japan /etc/localtime

## firewall
FWSTAT=$(systemctl status firewalld.service | awk '/Active/ {print $2}')
if [ "${FWSTAT}" = "inactive" ]; then
    systemctl start firewalld.service
    firewall-cmd --zone=public --add-service=ssh --permanent
    systemctl enable firewalld.service
fi

firewall-cmd --add-service=http --zone=public --permanent
firewall-cmd --add-service=https --zone=public --permanent
## firewall open testlink port
firewall-cmd --zone=public --add-port=3000/tcp --permanent
## firewall open redmine port
firewall-cmd --zone=public --add-port=3001/tcp --permanent
## firewall open phpmyadmin port
firewall-cmd --zone=public --add-port=3002/tcp --permanent
## firewallを再起動しポート設定を適用する
firewall-cmd --reload

## Install repository clients
dnf -y install git svn || exit 1

## dnf install for LAMP packages
dnf -y install httpd-devel mod_ssl php php-devel php-pear mariadb-server \
 php-mbstring php-xml php-gd php-mysqlnd || exit 1

## php.ini settings for testlink 
cp /etc/php.ini /etc/php.ini.bak
sed -i "s/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 2880/" /etc/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 120/" /etc/php.ini

## git clone testlink
if [ ! -e /var/lib/testlink ]; then
    git clone https://github.com/TestLinkOpenSourceTRMS/testlink-code.git -b 1.9.20 testlink
    mv testlink /var/lib/
    cp /var/lib/testlink/custom_config.inc.php.example /var/lib/testlink/custom_config.inc.php
    sed -i.bak "s|// \$tlCfg->log_path = '/var/testlink-ga-testlink-code/logs/';|\$tlCfg->log_path = '/var/lib/testlink/logs/';|" /var/lib/testlink/custom_config.inc.php
    sed -i.bak "s|// \$g_repositoryPath = '/var/testlink-ga-testlink-code/upload_area/';|\$g_repositoryPath = '/var/lib/testlink/upload_area/';|" /var/lib/testlink/custom_config.inc.php
    chown -R apache:apache /var/lib/testlink
fi

## dnf install packages for building Redmine(Ruby on Rails)
dnf -y install libxml2-devel libxslt-devel gcc bzip2 openssl-devel \
 zlib-devel gdbm-devel ncurses-devel make autoconf automake bison gcc-c++ \
 libffi-devel libtool patch readline-devel sqlite-devel \
 glibc-headers glibc-devel libicu-devel libidn-devel libyaml ruby ruby-devel || exit 1

## dnf install packages for Redmine
dnf -y install ImageMagick-devel libyaml-devel || exit 1

## dnf install packages Redmine httpd service and RDB
dnf -y install httpd-devel mod_ssl mariadb-server mariadb-devel || exit 1

## MariaDB config settings
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

## start MariaDB service
systemctl status mariadb.service >/dev/null 2>&1 || systemctl start mariadb.service
for i in {1..5}; do
    sleep 1
    systemctl status mariadb.service && break
    [ "$i" -lt 5 ] || exit 1
done
systemctl enable mariadb.service || exit 1

## MariaDB password settings
## expectパッケージに入っている mkpasswd コマンドをインストールする
dnf install -y expect || exit 1
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

## MariaDB database for Redmine
echo "DROP DATABASE IF EXISTS db_redmine;" | mysql --defaults-file=/root/.my.cnf
echo "create database db_redmine default character set utf8;" | mysql --defaults-file=/root/.my.cnf
echo "grant all on db_redmine.* to $USERNAME@'localhost' identified by '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf

## MariaDB database for TestLink
echo "DROP DATABASE IF EXISTS testlink;" | mysql --defaults-file=/root/.my.cnf
echo "DROP USER 'testlinkuser'@'localhost';" | mysql --defaults-file=/root/.my.cnf
echo "CREATE DATABASE testlink;" | mysql --defaults-file=/root/.my.cnf
echo "CREATE USER 'testlinkuser'@'localhost' IDENTIFIED BY '$PASSWORD';" | mysql --defaults-file=/root/.my.cnf
echo "GRANT ALL PRIVILEGES ON testlink.* TO 'testlinkuser'@'localhost' IDENTIFIED BY '$PASSWORD' WITH GRANT OPTION;" | mysql --defaults-file=/root/.my.cnf
echo "flush privileges;" | mysql --defaults-file=/root/.my.cnf

## svn checkout Redmine
if [ ! -e /var/lib/redmine ]; then
svn checkout http://svn.redmine.org/redmine/branches/3.4-stable /var/lib/redmine || exit 1

cat <<-EOT >/var/lib/redmine/config/database.yml
production:
    adapter: mysql2
    database: db_redmine
    host: localhost
    username: $USERNAME
    password: $PASSWORD
    encoding: utf8
EOT

## Install redmine gems
cp /etc/gemrc /etc/gemrc.bak
echo 'gem: -N' >/etc/gemrc
cd /var/lib/redmine

# gem install bundler --version '1.17.3' -N || exit 1
# bundle config build.nokogiri --use-system-libraries || exit 1
# bundle install --without development test || exit 1
# bundle exec rake generate_secret_token || exit 1
# RAILS_ENV=production bundle exec rake db:migrate

## 権限設定
chown -R apache:apache /var/lib/redmine

fi

## Install Passenger(mod_rails) by dnf
# https://www.phusionpassenger.com/library/install/apache/yum_repo/
# dnf install -y curl || exit 1
# curl --fail -sSLo /etc/yum.repos.d/passenger.repo https://oss-binaries.phusionpassenger.com/yum/definitions/el-passenger.repo
# dnf install -y mod_passenger 

## Install Passenger(mod_rails) by gem
dnf install -y curl curl-devel || exit 
# gem install passenger -N || exit 1
# passenger-install-apache2-module --auto --languages ruby
# passenger-install-apache2-module --snippet >/etc/httpd/conf.d/passenger.conf


## phpMyAdmin
## TestLinkやRedmineの設定を確認するため、MariaDBの内容を編集できるツールを入れておく
if [ ! -e /var/lib/phpmyadmin ]; then
dnf install -y curl php-json php-pecl-zip || exit 1

mkdir ~/phpmyadmin
cd ~/phpmyadmin/

## install composer
EXPECTED_SIGNATURE="$(curl https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    >&2 echo 'ERROR: Invalid installer signature'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
RESULT=$?
echo $RESULT
rm composer-setup.php

## Composerでphpmyadminをインストールする
./composer.phar create-project phpmyadmin/phpmyadmin

mv phpmyadmin /var/lib/phpmyadmin
cd /var/lib/phpmyadmin
cp /var/lib/phpmyadmin/config.sample.inc.php /var/lib/phpmyadmin/config.inc.php
COOKIESECRET=$(mkpasswd -l 32 -d 8 -c 8 -C 8 -s 8)
sed -i.bak "s/\$cfg['blowfish_secret'] = '';/\$cfg['blowfish_secret'] = '$COOKIESECRET'/" /var/lib/phpmyadmin/config.inc.php

## 権限設定
chown -R apache:apache /var/lib/phpmyadmin
fi

## Apache httpd の設定
## Setting httpd config for (TestLink)
cat <<-EOT >/etc/httpd/conf.d/testlink.conf
Listen 3001
<VirtualHost 192.168.2.200:3001>
ServerName www.yjono.com
DocumentRoot /var/lib/testlink
<Directory "/var/lib/testlink">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
</Directory>
ErrorLog /var/log/httpd/testlink-error_log
CustomLog /var/log/httpd/testlink-access_log common
</VirtualHost>
EOT
## Setting httpd config for (Redmine)
cat <<-EOT >/etc/httpd/conf.d/redmine.conf
Listen 3000
<VirtualHost 192.168.2.200:3000>
ServerName www.yjono.com
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
## Setting httpd config for (phpMyAdmin)
cat <<-EOT >/etc/httpd/conf.d/phpmyadmin.conf
Listen 3002
<VirtualHost 192.168.2.200:3002>
ServerName www.yjono.com
DocumentRoot /var/lib/phpmyadmin
<Directory "/var/lib/phpmyadmin">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
</Directory>
ErrorLog /var/log/httpd/phpmyadmin-error_log
CustomLog /var/log/httpd/phpmyadmin-access_log common
</VirtualHost>
EOT

## Setting Server IP hostname
cp /etc/hosts /etc/hosts.bak
echo "192.168.2.200 www.yjono.com www" >>/etc/hosts


## SELinux
## redmineのSELinux設定を追い込むのは非常に骨が折れるため、いったんOFFとしエラーログを記録しておく
if "${SELINUX_ENABLED}"; then
## SELinuxを有効化する
enable_selinux
else
## SELinuxを無効化する
setenforce 0
sed -i.bak "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
fi


## Start httpd service
## httpdサービスが起動していなければ開始し、起動完了するまで待機する
systemctl status httpd.service >/dev/null 2>&1 || systemctl start httpd.service
for i in {1..5}; do
    sleep 1
    systemctl status httpd.service && break
    [ "$i" -lt 5 ] || exit 1
done
## サーバー起動時にhttpdがスタートするよう設定する
systemctl enable httpd.service || exit 1

## Option サーバーに乗り込んで操作するときに便利なツール
# dnf -y install byobu || exit 1

echo "NEWMYSQLPASSWORD"
echo $NEWMYSQLPASSWORD
echo "USERNAME"
echo $USERNAME
echo "PASSWORD"
echo $PASSWORD

## 全ての設定が再起動しても反映されていることを保証する為に、Provisioning完了後は再起動して確認する
reboot

}

## インターネットに一般公開するサーバーはセキリティ担保のためにSELinuxを有効にする
function enable_selinux() {
dnf install -y setools setools-console selinux-policy-devel policycoreutils-python-utils setroubleshoot-server || exit 1

## SELinux httpポートが未登録なら追加する
semanage port -l | grep http

## SELinux httpポートアクセス許可
semanage port -a -t http_port_t -p tcp 3000
semanage port -a -t http_port_t -p tcp 3001
semanage port -a -t http_port_t -p tcp 3002
## httpdプロセスにファイルアクセスを許可する
setsebool -P httpd_read_user_content 1
setsebool -P httpd_can_network_connect 1


## SELinux TestLink
sudo restorecon -RF /var/lib/testlink


## SELinux Redmine
## 参考: http://blog.redmine.jp/articles/3_4/install/enable-selinux/

## SELinuxファイルコンテキストの設定
## PassengerAgent
sudo semanage fcontext -a -s system_u -t passenger_exec_t -r s0 -f f "`passenger-config --root`/buildout/support-binaries/PassengerAgent"

## mod_passenger
sudo semanage fcontext -a -s system_u -t httpd_modules_t -r s0 -f f "`passenger-config --root`/buildout/apache2/mod_passenger\.so"

## redmine directory
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 "/var/lib/redmine/\.bundle(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_var_lib_t -r s0 "/var/lib/redmine/\.svn(/.*)?"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 "/var/lib/redmine/app(/.*)?"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 "/var/lib/redmine/config(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_var_lib_t -r s0 "/var/lib/redmine/db(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_var_lib_t -r s0 "/var/lib/redmine/files(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_var_lib_t -r s0 "/var/lib/redmine/lib(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_log_t -r s0 "/var/lib/redmine/log(/.*)?"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 "/var/lib/redmine/plugins(/.*)?"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 "/var/lib/redmine/public(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_var_lib_t -r s0 "/var/lib/redmine/public/plugin_assets(/.*)?"
sudo semanage fcontext -a -s system_u -t passenger_tmp_t -r s0 "/var/lib/redmine/tmp(/.*)?"
sudo semanage fcontext -a -s system_u -t lib_t -r s0 "/var/lib/redmine/vendor(/.*)?"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 -f f "/var/lib/redmine/config\.ru"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 -f f "/var/lib/redmine/Gemfile"
sudo semanage fcontext -a -s system_u -t httpd_sys_content_t -r s0 -f f "/var/lib/redmine/Gemfile\.lock"

## fcontextの設定を確認したい時は下のコマンドを使う
# semanage fcontext -l | grep -e redmine -e assenger

## redmine と gem の関連ファイルのSELinux権限設定をフォルダに反映する
sudo restorecon -RF  /var/lib/redmine /usr/share/gems/gems/

## プロセスpassenger_tがアクセスできるリソースをTE(Type Enforcement)で設定する
mkdir ~/redmine
cd ~/redmine
cat > ~/redmine/redmine_local.te << _EOF_
module redmine_local 1.0;

require {
        type passenger_t;
        type sysfs_t;
        class capability dac_override;
        class dir read;
}

allow passenger_t self:capability dac_override;
allow passenger_t sysfs_t:dir read;
_EOF_

make -f /usr/share/selinux/devel/Makefile
semodule -i redmine_local.pp

## 確認コマンド
# sudo semodule -l | grep redmine_local

}

###################################
### startup.shのエントリポイント ###
###################################

## インストール設定
SELINUX_ENABLED=false

## OSがCentOS8.1ならインストール開始
VERSION=$(rpm -q centos-release --qf "%{VERSION}")
[ "$VERSION" = "8.1" ] && provision
