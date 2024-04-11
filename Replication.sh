#------------------------------------------------------------------------------
# STREAMING REPLICATION
#------------------------------------------------------------------------------

## On Master Node

# Replication user
CREATE USER replicator WITH PASSWORD '*****' REPLICATION;

vim /var/lib/pgsql/16/data/postgresql.auto.conf
	wal_level = replica
  synchronous_standby_name = ''
	# For Synchronous Replication 
		# *
		# ANY 1 (node1)
		# ANY 1 (node1, node2)
		# FIRST 1 (node1, node2, node3)
		# FIRTS 2 (node1, node2, node3)

vim /var/lib/pgsql/16/data/pg_hba.conf
  host    replication     replicator     $MASTER_NODE_IP/32        md5
  host    replication     replicator     $REPLICA_NODE_IP/32       md5

SELECT pg_reload_conf();
	# /usr/pgsql-16/bin/pg_ctl -D /var/lib/pgsql/16/data reload

## On Replica Node

/usr/pgsql-16/bin/pg_basebackup -D /var/lib/pgsql/16/data -Fp -R -X stream -c fast -C -S $SLOT -h $MASTER_NODE_IP -U replicator -P

vim /var/lib/pgsql/16/data/postgresql.auto.conf
	hot_standby = on
	hot_standby_feedback = on
	max_standby_streaming_delay = 30s
	recovery_min_apply_delay = 0
	wal_receiver_create_temp_slot = off
	wal_receiver_status_interval = 10s
	wal_receiver_timeout = 1min
	wal_retrieve_retry_interval = 5s
	primary_conninfo = '... application_name=$REPLICA_NODE_HOSTNAME ...'

sudo systemctl enable postgresql-16.service
sudo systemctl start postgresql-16.service

## Check Replication

# On Master Node: 
	SELECT * FROM pg_stat_replication;
	SELECT * FROM pg_replication_slots;

# On Replica Node: 
	SELECT pg_is_in_recovery();
	SELECT * FROM pg_stat_wal_receiver;

## SwitchOver & FailOver

## SwitchOver: 
	# Master Node: 
	sudo systemctl stop postgresql-16.service
	# Replica Node: 
	SELECT pg_promote();
		#	/usr/pgsql-16/bin/pg_ctl -D /var/lib/pgsql/16/data promote

## Failover: 
	# Master Node Crash
	# Replica Node: 
	SELECT pg_promote();
		#	/usr/pgsql-16/bin/pg_ctl -D /var/lib/pgsql/16/data promote


#------------------------------------------------------------------------------
# LOGICAL REPLICATION
#------------------------------------------------------------------------------

## On Publisher Node

# Replication User
CREATE USER replicator WITH PASSWORD '*****' REPLICATION;
GRANT USAGE ON SCHEMA $app_schema TO replicator; 
GRANT SELECT ON ALL TABLES IN SCHEMA $app_schema TO replicator; 

vim /var/lib/pgsql/16/data/postgresql.conf
	wal_level = logical

vim /var/lib/pgsql/16/data/pg_hba.conf
		host    replication     replicator     $PUBLISHER_NODE_IP/32        md5
    host    replication     replicator     $SUBSCRIBER_NODE_IP/32       md5

sudo systemctl restart postgresql-16.service

# Create Publication & Logical replication slot
CREATE PUBLICATION $publication_name FOR ALL TABLES;
SELECT pg_create_logical_replication_slot('$logical_slot', 'pgoutput');

# Export Schema Objects from Publisher Node
pg_dump -d $database -s -f logical_replication.sql

## On Subscriber Node

# Import Schema Objects to Publisher Node
pgsql -d $database < logical_replication.sql

CREATE SUBSCRIPTION $subscription_name CONNECTION 'dbname=$database host=$PUBLISHER_NODE_IP user=replicator password=***** port=5432' PUBLICATION $publication_name WITH (create_slot=false,slot_name=$logical_slot);








