#!/bin/bash 
# variables to be populated by terraform script
db_username=${db_username}
db_user_password=${db_user_password}
db_name=${db_name}
db_RDS=${db_RDS}

# install LAMP server (Linux, Apache, MySQL, PHP/Perl/Python)
yum update -y 
# install apache server and mysql client 
yum install -y httpd
yum install -y mysql 

# enable php7
amazon-linux-extras enable php7.4
yum clean metadata 
yum install -y php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap,devel}

# consider installing imagick extension here ?? 

systemctl restart php-fpm.service

systemct1 start httpd 

# change OWNER and permission of directory /var/www/
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;



#**********************Installing Wordpress using WP CLI********************************* 
# install the CLI on EC2 instance 
# curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
# # chmod +x <filename> means that you'll make the file executable. In this case, means you can actually use the wordpress CLI 
# chmod +x wp-cli.phar
# wp core download --path=/var/www/html --allow-root
# # create and populate the wordpress configuration file 
# wp config create --dbname=$db_name --dbuser=$db_username --dbpass=$db_user_password --dbhost=$db_RDS --path=/var/www/html --allow-root --extra-php <<PHP
# define( 'FS_METHOD', 'direct' );
# define('WP_MEMORY_LIMIT', '128M');
# PHP

#**********************Installing Wordpress manually********************************* 
# Download wordpress package and extract
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
# Create wordpress configuration file and update database value
cd /var/www/html
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/${db_name}/g" wp-config.php
sed -i "s/username_here/${db_username}/g" wp-config.php
sed -i "s/password_here/${db_user_password}/g" wp-config.php
sed -i "s/localhost/${db_RDS}/g" wp-config.php
cat <<EOF >>/var/www/html/wp-config.php
define( 'FS_METHOD', 'direct' );
define('WP_MEMORY_LIMIT', '128M');
EOF

# Change permission of /var/www/html/
chown -R ec2-user:apache /var/www/html
chmod -R 774 /var/www/html

#  enable .htaccess files in Apache config using sed command
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/httpd/conf/httpd.conf

#Make apache  autostart and restart apache
systemctl enable  httpd.service
systemctl restart httpd.service
echo WordPress Installed