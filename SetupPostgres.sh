#------------------------------------------------------------------------------
# DATABASE INSTANCE INSTALLATION
#------------------------------------------------------------------------------

## Check Postgres Repo: https://www.postgresql.org/download/linux/redhat/
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo dnf -qy module disable postgresql
sudo dnf install -y postgresql16-server

passwd postgres
sudo visudo
	postgres ALL=(ALL) ALL

/usr/pgsql-16/bin/initdb -D /var/lib/pgsql/16/data/ --data-checksums
	## Enable Data Cheksums for Active Instance:
			# show data_checksums; => off
			# sudo systemctl stop postgresql-16.service
			# /usr/pgsql-16/bin/pg_checksums -c /var/lib/pgsql/16/data/
			# /usr/pgsql-16/bin/pg_checksums -e /var/lib/pgsql/16/data/
			# sudo systemctl start postgresql-16.service
			# show data_checksums; => on

sudo systemctl enable postgresql-16.service
sudo systemctl start postgresql-16.service
sudo systemctl status postgresql-16.service

#------------------------------------------------------------------------------
# PACKAGES AND LIBRARIES
#------------------------------------------------------------------------------

## Packages & Libraries
sudo dnf install postgresql16-contrib
sudo dnf install pg_activity
sudo dnf install pgbackrest
sudo dnf install mailx

## Extensions for Postgres
\c app_database;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

#------------------------------------------------------------------------------
# ROLE & USER MANAGEMENT
#------------------------------------------------------------------------------

## Super User Password: 
ALTER USER postgres WITH PASSWORD '*****';

## For Application Side: 

# DATABASE: 		    app_database
# SCHEMA: 		      app_schema
# APP USER: 		    app_user
# READONLY ROLE: 		readonly
# DEVELOPER USER:		dev_user

# Database for Application: 
CREATE DATABASE app_database;
\c app_database
CREATE SCHEMA app_schema;

# Application User: 
CREATE USER app_user WITH PASSWORD '*****' LOGIN;
GRANT CONNECT ON DATABASE app_database TO app_user ;
GRANT USAGE ON SCHEMA app_schema TO app_user;
GRANT CREATE ON SCHEMA app_schema TO app_user;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA app_schema TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO app_user;

# ReadOnly Role: 
CREATE ROLE readonly WITH NOLOGIN;
GRANT CONNECT ON DATABASE app_database TO readonly;
GRANT USAGE ON SCHEMA app_schema TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA app_schema TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema GRANT SELECT ON TABLES TO readonly;
ALTER DEFAULT PRIVILEGES FOR ROLE app_user GRANT SELECT ON TABLES TO readonly;

# Developer User: 
CREATE USER dev_user WITH PASSWORD '*****' LOGIN;
GRANT readonly TO dev_user;

#------------------------------------------------------------------------------
# ACCESS MANAGEMENT
#------------------------------------------------------------------------------

vim /var/lib/pgsql/16/data/pg_hba.conf

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             0.0.0.0/0               md5
# Authentication for Admins
host    postgres        postgres        0.0.0.0/0               md5
## Authentication for Application
host    app_database    app_user        0.0.0.0/0               md5
## Authentication for Developers
host    app_database    dev_user        0.0.0.0/0               md5

#------------------------------------------------------------------------------
# DATABASE CONFIGURATION
#------------------------------------------------------------------------------

vim /var/lib/pgsql/16/data/postgresql.conf

###### LISTENER ######
listen_addresses = '*'
port = 5432
max_connections = 500
reserved_connections = 3
superuser_reserved_connections = 3

###### CLUSTER ######
cluster_name = 'application_name'

###### EXTENSIONS ######
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 5000
pg_stat_statements.track = top
pg_stat_statements.track_utility = on
pg_stat_statements.track_planning = off
pg_stat_statements.save = on

###### MEMORY & PARALLELISM ######
## Check pgtune: https://pgtune.leopard.in.ua/
#### Buffers & Memory
shared_buffers = RAM * 0.25
effective_cache_size = RAM * 0.75
maintenance_work_mem = 1GB
autovacuum_work_mem = -1
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = ( RAM / 2 * max_connections ) * 1024 ROUND DOWN to 2^x 
hash_mem_multiplier = 2.0
wal_buffers = 16MB 
huge_pages = try
#### Parallel Workers
max_worker_processes = 8
max_parallel_workers = 8
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4

###### BACKGROUND PROCESSES ######

#### Archiver Process
archive_mode = on
archive_command = 'true'
archive_timeout = 0

#### Checkpointer Process
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
checkpoint_warning = 30s
log_checkpoints = on
min_wal_size=500MB
max_wal_size=2GB

#### BgWriter Process
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 10000
bgwriter_lru_multiplier = 5.0

#### AutoVacuum Processes
autovacuum = on
log_autovacuum_min_duration = 0
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 1000
autovacuum_vacuum_insert_threshold = 1000
autovacuum_analyze_threshold = 1000
autovacuum_vacuum_scale_factor = 0.1
autovacuum_vacuum_insert_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.1
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_cost_limit = -1

#### Statistic Collector
track_io_timing = on
track_wal_io_timing = on
compute_query_id = on

#### Logger Process
logging_collector = on
log_line_prefix = '< %m user=%u db=%d host=%h  queryID=%Q %a [%p] '
log_lock_waits = on
log_error_verbosity = default
log_min_duration_statement = 10000
log_parameter_max_length = -1
log_parameter_max_length_on_error = -1
log_statement = 'none'
log_statement_sample_rate = 1.0






























