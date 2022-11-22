#!/bin/bash 
# variables to be populated by terraform script
db_username=${db_username}
db_user_password=${db_user_password}
db_name=${db_name}
db_RDS=${db_RDS}
yum -y install httpd php php-mysql
wget https://wordpress.org/wordpress-5.1.1.tar.gz
tar -xzf wordpress-5.1.1.tar.gz
cp -r wordpress/* /var/www/html
rm -rf wordpress*
cd /var/www/html
sudo cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/${db_name}/g" wp-config.php
sed -i "s/username_here/${db_username}/g" wp-config.php
sed -i "s/password_here/${db_user_password}/g" wp-config.php
sed -i "s/localhost/${db_RDS}/g" wp-config.php
chmod -R 755 wp-content
chown -R apache:apache wp-content
systemctl enable httpd && systemctl start httpd 