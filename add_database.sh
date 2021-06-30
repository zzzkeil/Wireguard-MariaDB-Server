#!/bin/bash
clear
echo "To EXIT this script press  [ENTER]"
echo 
read -p "To RUN this script press  [Y]" -n 1 -r
echo
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi



randomkey1=$(date +%s | cut -c 3-)
read -p "sql databasename: " -e -i db$randomkey1 databasename
read -p "sql databaseuser: " -e -i dbuser$randomkey1 databaseuser
randomkey2=$(</dev/urandom tr -dc 'A-Za-z0-9.:_' | head -c 12  ; echo)
read -p "sql databaseuserpasswd: " -e -i $randomkey2 databaseuserpasswd
echo "
Added database without new domain
databasename : $databasename
databaseuser : $databaseuser
databaseuserpasswd : $databaseuserpasswd
#
" >> /root/mysql_database_list.txt

mysql -uroot <<EOF
CREATE DATABASE $databasename CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER $databaseuser@localhost identified by '$databaseuserpasswd';
GRANT ALL PRIVILEGES on $databasename.* to $databaseuser@localhost;
FLUSH privileges;
EOF
