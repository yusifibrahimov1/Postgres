#------------------------------------------------------------------------------
# SERVERS FOR FAILVOER CLUSTER
#------------------------------------------------------------------------------

# ETCD Servers: 
  3 Node - 2 Main Side, 1 DR Side.
  Resources:
	  CPU: 4
  	RAM: 8GB
	  Disk: /root 60GB
	  data directory: /var/lib/etcd 60GB (SSD - mountpoint)
 
# DATABASE Servers: 
  3 Node - 2 Main Side, 1 DR Side
  Resources:
  	RAM: 24GB
  	CPU: 12
  	Disk: /root 60GB
  	data directory: /var/lib/pgsql 700GB (mountpoint)
 
# PROXY Servers: 
  2 Node - 1 Main Side, 1 DR Side. 
  Resources:
  	CPU: 2
  	RAM: 4GB
  	Disk: /root 40GB

# All Nodes:
vim /etc/hosts
	$etcd01_IP        $etcd01_HOSTNAME
	$etcd02_IP        $etcd02_HOSTNAME
	$etcd03_IP        $etcd03_HOSTNAME
	$database01_IP    $database01_HOSTNAME
	$database02_IP    $database02_HOSTNAME
	$database03_IP    $database03_HOSTNAME
	$proxy01_IP       $proxy01_HOSTNAME
	$proxy02_IP       $proxy02_HOSTNAME


#------------------------------------------------------------------------------
# ETCD CLUSTER
#------------------------------------------------------------------------------

## Installation
dnf install https://ftp.postgresql.org/pub/repos/yum/common/pgdg-rhel8-extras/redhat/rhel-8-x86_64/etcd-3.5.10-1PGDG.rhel8.x86_64.rpm

## Configuration

vim /etc/etcd/etcd.conf
# Change name,client addresses for other ETCD Nodes
	{
	  "name": "etcd1",
	  "data-dir": "/var/lib/etcd",
	  "listen-client-urls": "http://$ETCD01_IP:2379",
	  "advertise-client-urls": "http://$ETCD01_IP:2379",
	  "listen-peer-urls": "http://$ETCD01_IP:2380",
	  "initial-advertise-peer-urls": "http://$ETCD01_IP:2380",
	  "initial-cluster": "etcd1=http://$ETCD01_IP:2380,etcd2=http://$ETCD02_IP:2380,etcd3=http://$ETCD03_IP:2380",
	  "initial-cluster-token": "etcd-cluster",
	  "initial-cluster-state": "new",
	  "logger": "zap",
	  "log-outputs": ["stderr", "/var/log/etcd/etcd.log"],
	  "log-level": "info"
	}

vim .bash_profile
	ENDPOINTS=http://$etcd01:2379,http://$etcd02:2379,http://$etcd03:2379
. .bash_profile

vim /etc/logrotate.d/etcd
	/var/log/etcd/*.log {
	  daily
	  missingok
	  rotate 7
	  compress
	  dateext
	  delaycompress
	  copytruncate
	  notifempty
	}

## Starting ETCD Nodes
# All Nodes:
	systemctl enable etcd.service
# You must start service in same time or near time:
	systemctl start etcd.service
	systemctl status etcd.service


## Check ETCD Cluster

etcdctl --endpoints=$ENDPOINTS --write-out=table member list
				+------------------+---------+-------+---------------------------+---------------------------+------------+
				|        ID        | STATUS  | NAME  |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
				+------------------+---------+-------+---------------------------+---------------------------+------------+
				| 5c4b8702690b77bb | started | etcd3 | http://$ETCD03_IP:2380    | http://$ETCD03_IP:2379    |      false |
				| 698e3dc2ecbda681 | started | etcd1 | http://$ETCD01_IP:2380    | http://$ETCD01_IP:2379    |      false |
				| c94fc324e0e12e6b | started | etcd2 | http://$ETCD02_IP:2380    | http://$ETCD02_IP:2379    |      false |
				+------------------+---------+-------+---------------------------+---------------------------+------------+

etcdctl --endpoints=$ENDPOINTS --write-out=table endpoint status
				+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
				|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
				+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
				| http://$ETCD01_IP:2379    | 698e3dc2ecbda681 |  3.5.12 |   37 kB |     false |      false |         3 |         12 |                 12 |        |
				| http://$ETCD02_IP:2379    | c94fc324e0e12e6b |  3.5.12 |   20 kB |     false |      false |         3 |         12 |                 12 |        |
				| http://$ETCD03_IP:2379    | 5c4b8702690b77bb |  3.5.12 |   20 kB |      true |      false |         3 |         12 |                 12 |        |
				+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+


#------------------------------------------------------------------------------
# PATRONI CLUSTER
#------------------------------------------------------------------------------

## Installation
	# Install Patroni from repo
	wget https://ftp.postgresql.org/pub/repos/yum/common/redhat/rhel-8-x86_64/patroni-3.0.4-1PGDG.rhel8.x86_64.rpm
	rpm -ivh patroni-3.0.4-1PGDG.rhel8.x86_64.rpm
	dnf install python3-cdiff python3-click python3-prettytable python3-psutil python3-psycopg2 python3-pyyaml python3-urllib3 python3-ydiff python3-devel gcc
	yum install python3-devel
	rpm -ivh patroni-3.0.4-1PGDG.rhel8.x86_64.rpm
	dnf install patroni
	# Install Patroni-Etcd Extension from repo
	wget https://ftp.postgresql.org/pub/repos/yum/common/redhat/rhel-8-x86_64/patroni-etcd-3.0.4-1PGDG.rhel8.x86_64.rpm
	rpm -ivh patroni-etcd-3.0.4-1PGDG.rhel8.x86_64.rpm
	wget https://rpmfind.net/linux/epel/8/Everything/x86_64/Packages/p/python3-certifi-2018.10.15-7.el8.noarch.rpm
	rpm -ivh python3-certifi-2018.10.15-7.el8.noarch.rpm
	dnf install python3-dns python3-etcd patroni-etcd

## Configuration
vim /etc/patroni/patroni.yml
  # Check Validate of Patroni configuration file
    patroni --validate-config /etc/patroni/patroni.yml	

scope: postgres
namespace: /postgresdb/
name: postgresdb01
# name: postgresdb02
# name: postgresdb03
	
log:
  level: INFO
  dir: /var/log/patroni
  file: patroni.log
  file_size: 1000000000
  format: '%(asctime)s %(levelname)s: %(message)s'
	
restapi:
    listen: 0.0.0.0:8008
    connect_address: $DB01_IP:8008
    # connect_address: $DB02_IP:8008
   #  connect_address: $DB03_IP:8008

etcd3:
    hosts: $ETCD01_IP:2379, $ETCD02_IP:2379, host: $ETCD03_IP:2379
    namespace: /postgresdb

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
 		primary_start_timeout: 300
    check_timeline: true
    slots:
      postgresdb02:
        type: physical
      postgresdb03:
        type: physical
      # postgresdb01:
        # typeL physical
    postgresql:
      use_pg_rewind: true
      remove_data_directory_on_rewind_failure: true
      remove_data_directory_on_diverged_timelines: false
      use_slots: true
      parameters:
        wal_level: replica
	
  initdb:
  - encoding: UTF8
  - data-checksums
	
  pg_hba:
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator $DB01_IP/32 md5
  - host replication replicator $DB02_IP/32 md5
  - host replication replicator $DB03_IP/32 md5
  - host all all 0.0.0.0/0 md5
	
postgresql:
  listen: 0.0.0.0:5432
  connect_address: $DB01_IP:5432
  # connect_address: $DB02_IP:5432
  # connect_address: $DB03_IP:5432
  data_dir: /var/lib/pgsql/16/data
  bin_dir: /usr/pgsql-16/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: '*****'
    superuser:
      username: postgres
      password: '*****'
    rewind:
      username: postgres
      password: '*****'
  parameters:
    unix_socket_directories: /var/run/postgresql
	
tags:
    noloadbalance: false
    clonefrom: false
    nosync: false
    failover_priority: 3
    # failover_priority: 2
    # failover_priority: 1
	    

## Check Patroni Cluster

## Check validate configuration file:
	patroni --validate-config /etc/patroni/patroni.yml	
# Change Patroni configuration:
	patronictl -c /etc/patroni/patroni.yml edit-config
# Show Patroni cluster and members health:
	patronictl -c /etc/patroni/patroni.yml list
		+ Cluster: postgres (7331817566576517652) -----------+----+-----------+
		| Member       | Host          | Role    | State     | TL | Lag in MB |
		+--------------+---------------+---------+-----------+----+-----------+
		| postgresdb01 |    $DB01_IP   | Leader  | running   |  1 |           |
		| postgresdb02 |    $DB02_IP   | Replica | streaming |  1 |         0 |
    | postgresdb02 |    $DB03_IP   | Replica | streaming |  1 |         0 |
		+--------------+---------------+---------+-----------+----+-----------+


#------------------------------------------------------------------------------
# HAPROXY CLUSTER
#------------------------------------------------------------------------------

## Installation
sudo dnf install haproxy

## Configuration
vim /etc/haproxy/haproxy.cfg

global
    maxconn 1000
    log         /dev/log local0
	
defaults
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s
	
listen stats
    mode http
    bind *:7000
	  stats enable
	  stats uri /

listen master
    bind *:5000 
    option httpchk OPTIONS /primary
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server postgresdb01 $NODE01_IP:5432 maxconn 1000 check port 8008
    server postgresdb02 $NODE02_IP:5432 maxconn 1000 check port 8008
    server postgresdb03 $NODE03_IP:5432 maxconn 1000 check port 8008

listen replica
    bind *:5001
    option httpchk OPTIONS /replica
    http-check expect status 200
		balance leastconn
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server postgresdb01 $NODE01_IP:5432 maxconn 500 check port 8008
    server postgresdb02 $NODE02_IP:5432 maxconn 500 check port 8008
    server postgresdb03 $NODE03_IP:5432 maxconn 500 check port 8008


## Log Rotation
mkdir /var/lib/haproxy/dev/log

vim /etc/rsyslog.d/99-haproxy.conf
	$AddUnixListenSocket /var/lib/haproxy/dev/log
	:programname, startswith, "haproxy" {
	  /var/log/haproxy/haproxy.log
	  stop
	}

vim /etc/logrotate.d/haproxy
	/var/log/haproxy/haproxy.log {
	    daily
	    rotate 7
	    missingok
	    notifempty
	    compress
	    sharedscripts
	    postrotate
	        /bin/kill -HUP `cat /var/run/syslogd.pid 2> /dev/null` 2> /dev/null || true
	        /bin/kill -HUP `cat /var/run/rsyslogd.pid 2> /dev/null` 2> /dev/null || true
	    endscript
	}

systemctl restart rsyslog.service
systemctl status rsyslog.service

## Start HAProxy Cluster
# All Nodes:
systemctl enable haproxy.service
systemctl start haproxy.service


#------------------------------------------------------------------------------
# KEEPALIVED CLUSTER
#------------------------------------------------------------------------------

## Installation
dnf install keepalived

## Configuration
  # learn network interface
  ip link show => interface
  	1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
  	    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
  	2: (ens160): <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
  	    link/ether 00:0c:29:c4:3b:04 brd ff:ff:ff:ff:ff:ff


vim /etc/keepalived/keepalived.conf

global_defs {
    user root
}
vrrp_script chk_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}
vrrp_instance VI_1 {
    interface ens160
    state MASTER
    priority 100
    virtual_router_id 51
    authentication {
        auth_type PASS
        auth_pass 1234
    }
    virtual_ipaddress {
        $VIRTUAL_IP
    }
    unicast_src_ip $PROXY01_IP
    unicast_peer {
    $PROXY02_IP
    }
    track_script {
        chk_haproxy
    }
}


## Starting KeelAlived Cluster
systemctl enable keepalived.service
systemctl start keepalived.service
systemctl status keepalived.service

# Proxy01
hostname -I
	$PROXY01_IP $VIRTUAL_IP    # => Master Proxy Node

# Proxy02
hostname -I
	$PROXY02_IP                # => Backup Proxy Node









































