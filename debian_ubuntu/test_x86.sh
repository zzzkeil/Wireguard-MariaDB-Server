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
read -p "Choose your Wireguard Port: " -e -i 51820 wg0port
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
ufw allow in on wg0 from 10.0.0.11 to any port 3306 proto tcp
ufw allow in on wg0 from 10.0.0.12 to any port 3306 proto tcp


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


apt install mariadb-server 
/usr/sbin/service mysql stop
###configure MariaDB

### MariaDB Data-at-Rest Encryption
mkdir /etc/mysql/keys
echo  "1;"$(openssl rand -hex 32) > /etc/mysql/keys/enc_keys
echo  "2;"$(openssl rand -hex 32) >> /etc/mysql/keys/enc_keys
echo  "3;"$(openssl rand -hex 32) >> /etc/mysql/keys/enc_keys
echo  "4;"$(openssl rand -hex 32) >> /etc/mysql/keys/enc_keys
openssl rand -hex 192> /etc/mysql/keys/enc_paswd.key
openssl enc -aes-256-cbc -md sha1 -pass file:/etc/mysql/keys/enc_paswd.key -in /etc/mysql/keys/enc_key.txt -out /etc/mysql/keys/enc_key.enc && sudo rm /etc/mysql/keys/enc_key.txt

chown -R mysql:root /etc/mysql/keys
chmod 500 /etc/mysql/keys/
chown mysql:root /etc/mysql/keys/enc_paswd.key /etc/mysql/keys/enc_key.enc
chmod 600 /etc/mysql/keys/enc_paswd.key /etc/mysql/keys/enc_key.enc


### MariaDB Data-in-Transit Encryption
#mkdir -p /etc/mysql/certs
#openssl genrsa 2048 > ca-key.pem
#openssl req -new -x509 -nodes -days 365000 -key ca-key.pem -out ca-cert.pem
#openssl req -newkey rsa:2048 -nodes -keyout server-key.pem -out server-req.pem
#openssl rsa -in server-key.pem -out server-key.pem
#openssl x509 -req -in server-req.pem -days 365000 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out server-cert.pem
#openssl req -newkey rsa:2048 -nodes -keyout client-key.pem -out client-req.pem
#openssl rsa -in client-key.pem -out client-key.pem
#openssl x509 -req -in client-req.pem -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 -out client-cert.pem
#chown mysql.mysql /etc/mysql/certs/


echo "
[sqld]

#File Key Management Plugin
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


mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
echo "[client]
default-character-set = utf8mb4
port = 3306
[mysqld_safe]
log_error=/var/log/mysql/mysql_error.log
nice = 0
socket = /var/run/mysqld/mysqld.sock
[mysqld]
basedir = /usr
bind-address = 10.8.0.1
binlog_format = ROW
bulk_insert_buffer_size = 16M
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
concurrent_insert = 2
connect_timeout = 5
datadir = /var/lib/mysql
default_storage_engine = InnoDB
expire_logs_days = 10
general_log_file = /var/log/mysql/mysql.log
general_log = 0
innodb_buffer_pool_size = 1024M
innodb_buffer_pool_instances = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 32M
innodb_max_dirty_pages_pct = 90
innodb_file_per_table = 1
innodb_open_files = 400
innodb_io_capacity = 4000
innodb_flush_method = O_DIRECT
key_buffer_size = 128M
lc_messages_dir = /usr/share/mysql
lc_messages = en_US
log_bin = /var/log/mysql/mariadb-bin
log_bin_index = /var/log/mysql/mariadb-bin.index
log_error = /var/log/mysql/mysql_error.log
log_slow_verbosity = query_plan
log_warnings = 2
long_query_time = 1
max_allowed_packet = 16M
max_binlog_size = 100M
max_connections = 200
max_heap_table_size = 64M
myisam_recover_options = BACKUP
myisam_sort_buffer_size = 512M
port = 3306
pid-file = /var/run/mysqld/mysqld.pid
query_cache_limit = 2M
query_cache_size = 64M
query_cache_type = 1
query_cache_min_res_unit = 2k
read_buffer_size = 2M
read_rnd_buffer_size = 1M
skip-external-locking
skip-name-resolve
slow_query_log_file = /var/log/mysql/mariadb-slow.log
slow-query-log = 1
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 4M
table_open_cache = 400
thread_cache_size = 128
tmp_table_size = 64M
tmpdir = /tmp
transaction_isolation = READ-COMMITTED
user = mysql
wait_timeout = 600

[mysqldump]
max_allowed_packet = 16M
quick
quote-names

[isamchk]
key_buffer = 16M
" > /etc/mysql/my.cnf
/usr/sbin/service mysql restart
clear
echo ""
echo " Your database server will now be hardened - just follow the instructions."
echo " Keep in mind: your MariaDB root password is still NOT set!"
echo ""
mysql_secure_installation







wget -O  add_database.sh https://raw.githubusercontent.com/zzzkeil/Wireguard-MariaDB-Server/main/add_database.sh
chmod +x add_database.sh
echo " To add a database run ./add_database.sh "
