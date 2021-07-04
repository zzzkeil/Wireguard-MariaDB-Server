#!/bin/bash
clear
echo " ##############################################################################"
echo " #    #"
echo " #     #"
echo " #   #"
echo " #  #"
echo " ##############################################################################"
echo " ##############################################################################"
echo " #  #"
echo " ##############################################################################"
echo ""
echo ""
echo ""
echo "To EXIT this script press  [ENTER]"
echo 
read -p "To RUN this script press  [Y]" -n 1 -r
echo
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
#
### root check
if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi
#
### base_setup check
if [[ -e /root/base_setup.README ]]; then
     echo "base_setup script installed - OK"
	 else
	 wget -O  base_setup.sh https://raw.githubusercontent.com/zzzkeil/base_setups/master/base_setup.sh
         chmod +x base_setup.sh
	 echo ""
	 echo ""
	 echo " Attention !!! "
	 echo " My base_setup script not installed,"
         echo " you have to run ./base_setup.sh manualy now and reboot, after that you can run this script again."
	 echo ""
	 echo ""
	 exit 1
fi
#
### OS version check
if [[ -e /etc/debian_version ]]; then
      echo "Debian Distribution"
      else
      echo "This is not a Debian Distribution."
      exit 1
fi
#
### script already installed check
if [[ -e /root/Wireguard-MariaDB-Server.README ]]; then
	 exit 1
fi
#
### create backupfolder for original files
mkdir /root/script_backupfiles/
#
### wireguard port stettings
echo " Make your port settings now:"
echo "------------------------------------------------------------"
read -p "Choose your Wireguard Port: " -e -i 51822 wg0port
echo "------------------------------------------------------------"
echo
echo "------------------------------------------------------------"
read -p "Choose your MariaDB Port: " -e -i 3306 dbport
echo "------------------------------------------------------------"
#
### apt systemupdate and installs	 
echo
VERSION_ID=$(cat /etc/os-release | grep "VERSION_ID")
if [[ "$VERSION_ID" = 'VERSION_ID="10"' ]]; then
	echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable-wireguard.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable
fi

if [[ "$VERSION_ID" = 'VERSION_ID="18.04"' ]]; then
    add-apt-repository ppa:wireguard/wireguard
fi

if [[ "$VERSION_ID" = 'VERSION_ID="20.04"' ]]; then
    echo " system is ubuntu 20.04 - no ppa:wireguard needed "
fi

apt update && apt upgrade -y && apt autoremove -y
apt install qrencode python curl linux-headers-$(uname -r) -y 
apt install wireguard-dkms wireguard-tools -y
#
### setup ufw 
ufw allow $wg0port/udp
ufw allow in on wg0 to any
#ufw allow in on wg0 from 10.0.0.11 to any port  proto tcp
#ufw allow in on wg0 from 10.0.0.12 to any port 3306 proto tcp


#
### setup wireguard keys and configs
mkdir /etc/wireguard/keys
chmod 700 /etc/wireguard/keys

touch /etc/wireguard/keys/server0
chmod 600 /etc/wireguard/keys/server0
wg genkey > /etc/wireguard/keys/server0
wg pubkey < /etc/wireguard/keys/server0 > /etc/wireguard/keys/server0.pub

touch /etc/wireguard/keys/client1
chmod 600 /etc/wireguard/keys/client1
wg genkey > /etc/wireguard/keys/client1
wg pubkey < /etc/wireguard/keys/client1 > /etc/wireguard/keys/client1.pub

touch /etc/wireguard/keys/client2
chmod 600 /etc/wireguard/keys/client2
wg genkey > /etc/wireguard/keys/client2
wg pubkey < /etc/wireguard/keys/client2 > /etc/wireguard/keys/client2.pub

### -
echo "[Interface]
Address = 10.8.0.1/24
ListenPort = $wg0port
PrivateKey = SK01
# client1
[Peer]
PublicKey = PK01
AllowedIPs = 10.8.0.11/32
# client2
[Peer]
PublicKey = PK02
AllowedIPs = 10.8.0.12/32

" > /etc/wireguard/wg0.conf
sed -i "s@SK01@$(cat /etc/wireguard/keys/server0)@" /etc/wireguard/wg0.conf
sed -i "s@PK01@$(cat /etc/wireguard/keys/client1.pub)@" /etc/wireguard/wg0.conf
sed -i "s@PK02@$(cat /etc/wireguard/keys/client2.pub)@" /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

### -
echo "[Interface]
Address = 10.8.0.11/32
PrivateKey = CK01
[Peer]
Endpoint = IP01:$wg0port
PublicKey = SK01
AllowedIPs = 10.8.0.1/32
" > /etc/wireguard/client1.conf
sed -i "s@CK01@$(cat /etc/wireguard/keys/client1)@" /etc/wireguard/client1.conf
sed -i "s@SK01@$(cat /etc/wireguard/keys/server0.pub)@" /etc/wireguard/client1.conf
sed -i "s@IP01@$(hostname -I | awk '{print $1}')@" /etc/wireguard/client1.conf
chmod 600 /etc/wireguard/client1.conf

echo "[Interface]
Address = 10.8.0.12/32
PrivateKey = CK02
[Peer]
Endpoint = IP01:$wg0port
PublicKey = SK01
AllowedIPs = 10.8.0.1/32
" > /etc/wireguard/client2.conf
sed -i "s@CK02@$(cat /etc/wireguard/keys/client2)@" /etc/wireguard/client2.conf
sed -i "s@SK01@$(cat /etc/wireguard/keys/server0.pub)@" /etc/wireguard/client2.conf
sed -i "s@IP01@$(hostname -I | awk '{print $1}')@" /etc/wireguard/client2.conf
chmod 600 /etc/wireguard/client2.conf


apt install mariadb-server -y
/usr/sbin/service mysql stop
###configure MariaDB

### MariaDB Data-at-Rest Encryption
mkdir /etc/mysql/keys
echo  "1;"$(openssl rand -hex 32) > /etc/mysql/keys/enc_keys
echo  "2;"$(openssl rand -hex 32) >> /etc/mysql/keys/enc_keys
echo  "3;"$(openssl rand -hex 32) >> /etc/mysql/keys/enc_keys
echo  "4;"$(openssl rand -hex 32) >> /etc/mysql/keys/enc_keys
openssl rand -hex 256 > /etc/mysql/keys/enc_paswd.key
openssl enc -aes-256-cbc -md sha1 -pbkdf2 -pass file:/etc/mysql/keys/enc_paswd.key -in /etc/mysql/keys/enc_keys -out /etc/mysql/keys/enc_key.enc

chown -R mysql:root /etc/mysql/keys
chmod 500 /etc/mysql/keys/
chown mysql:root /etc/mysql/keys/enc_paswd.key /etc/mysql/keys/enc_key.enc
chmod 600 /etc/mysql/keys/enc_paswd.key /etc/mysql/keys/enc_key.enc


### MariaDB Data-in-Transit Encryption
mkdir /etc/mysql/certs
openssl genrsa 4096 > /etc/mysql/certs/ca-key.pem
openssl req -new -x509 -nodes -days 365000 -key /etc/mysql/certs/ca-key.pem -out /etc/mysql/certs/ca-cert.pem
openssl req -newkey rsa:4096 -nodes -keyout /etc/mysql/certs/server-key.pem -out /etc/mysql/certs/server-req.pem
openssl rsa -in /etc/mysql/certs/server-key.pem -out /etc/mysql/certs/server-key.pem
openssl x509 -req -in /etc/mysql/certs/server-req.pem -days 365000 -CA /etc/mysql/certs/ca-cert.pem -CAkey /etc/mysql/certs/ca-key.pem -set_serial 01 -out /etc/mysql/certs/server-cert.pem

openssl req -newkey rsa:4096 -nodes -keyout /etc/mysql/certs/client-key.pem -out /etc/mysql/certs/client-req.pem
openssl rsa -in /etc/mysql/certs/client-key.pem -out /etc/mysql/certs/client-key.pem
openssl x509 -req -in /etc/mysql/certs/client-req.pem -CA /etc/mysql/certs/ca-cert.pem -CAkey /etc/mysql/certs/ca-key.pem -set_serial 01 -out /etc/mysql/certs/client-cert.pem
chown mysql.mysql /etc/mysql/certs/


echo "
[sqld]

# File Key Management Plugin
plugin_load_add=file_key_management
file_key_management = ON file_key_management_encryption_algorithm=aes_cbc file_key_management_filename = /etc/mysql/keys/enc_keys.enc
file_key_management_filekey = /etc/mysql/keys/enc_paswd.key

# InnoDB/XtraDB Encryption Setup
innodb_default_encryption_key_id = 1
innodb_encrypt_tables = ON
innodb_encrypt_log = ON
innodb_encryption_threads = 4

# Aria Encryption Setup
aria_encrypt_tables = ON

# Temp & Log Encryption
encrypt-tmp-disk-tables = 1
encrypt-tmp-files = 1
encrypt_binlog = ON
" > /etc/mysql/my_enc.cnf


echo "
[mariadb]
ssl-ca=/etc/mysql/certs/ca-cert.pem
ssl-cert=/etc/mysql/certs/server-cert.pem
ssl-key=//etc/mysql/certs/server-key.pem
tls_version = TLSv1.3
" > /etc/mysql/my_tls.cnf





mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
echo "
[mysqld]
bind-address = 0.0.0.0
port = $dbport

slow_query_log_file    = /var/log/mysql/mariadb-slow.log
long_query_time        = 10
log_slow_rate_limit    = 1000
log_slow_verbosity     = query_plan
log-queries-not-using-indexes

" > /etc/mysql/my.cnf
/usr/sbin/service mysql restart
clear
echo ""
echo " Your database server will now be hardened - just follow the instructions."
echo " Keep in mind: your MariaDB root password is still NOT set!"
echo ""
mysql_secure_installation


systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
wget -O  add_database.sh https://raw.githubusercontent.com/zzzkeil/Wireguard-MariaDB-Server/main/add_database.sh
chmod +x add_database.sh
curl -o add_client.sh https://raw.githubusercontent.com/zzzkeil/Wireguard-DNScrypt-VPN-Server/master/tools/add_client.sh
curl -o remove_client.sh https://raw.githubusercontent.com/zzzkeil/Wireguard-DNScrypt-VPN-Server/master/tools/remove_client.sh
chmod +x add_client.sh
chmod +x remove_client.sh
clear
echo " to add or remove clients run ./add_client.sh or remove_client.sh"
echo " To add a database run ./add_database.sh "


