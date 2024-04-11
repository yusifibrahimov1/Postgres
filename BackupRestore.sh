#------------------------------------------------------------------------------
# SETUP SERVERS FOR PGBACKREST
#------------------------------------------------------------------------------

## On Backup Server / Master Node
sudo dnf install pgbackrest
sudo mkdir /backup-postgres/
sudo chown -R postgres:postgres /backup-postgres/
sudo vim /etc/fstab
	$REMOTE_BACKUPSERVER:/postgres  /backup-postgres/         nfs      auto,rw,defaults  0  0
mount -a
sudo mkdir /backup-postgres/POSTGRES
sudo chmod -R 755 postgres:postgres /backup-postgres/POSTGRES

## SSH Key file generate between Servers: 
	# All Nodes: 
		ssh-keygen -t rsa
	# Backup Server: 
		ssh-copy-id -i ~/.ssh/id_rsa.pub postgres@$MasterNode_IP
		ssh-copy-id -i ~/.ssh/id_rsa.pub postgres@$ReplicaNode_IP
	# Master Node: 
		ssh-copy-id -i ~/.ssh/id_rsa.pub postgres@$BackupServer_IP
		ssh-copy-id -i ~/.ssh/id_rsa.pub postgres@$ReplicaNode_IP
	# Replica Node: 
		ssh-copy-id -i ~/.ssh/id_rsa.pub postgres@$BackupServer_IP
		ssh-copy-id -i ~/.ssh/id_rsa.pub postgres@$MasterNode_IP


#------------------------------------------------------------------------------
# CONFIGURATION PGBACKREST
#------------------------------------------------------------------------------

## On Master Node: 
sudo vim /etc/pgbackrest.conf
	[POSTGRES]
	pg1-path=/var/lib/pgsql/16/data
	pg2-host= $REPLICA_NODE_IP
	pg2-path= /var/lib/pgsql/16/data
	repo1-retention-full=2
	process-max= $CPU/3
	compress=y
	compress-level=3

	[global]
	repo1-path=/backup-postgres/POSTGRES
	log-level-console=detail 
	log-level-file=detail
	start-fast=y
	stop-auto=y
	backup-standby=y
	archive-async=y
	spool-path=/var/spool/pgbackrest/

	[global:archive-push] 
	process-max=1
	compress=y
	compress-level=3

	[global:backup] 
	process-max= $CPU/3
	compress=y
	compress-level=3

sudo vim /var/lib/pgsql/16/data/postgresql.conf
	archive_mode = on
	archive_command = 'pgbackrest --stanza=POSTGRES archive-push %p'

sudo systemctl restart postgresql-16.service

## On Replica Node: 
sudo vim /etc/pgbackrest.conf
	[POSTGRES]
	pg1-path=/var/lib/pgsql/16/data
	process-max= 2
	compress=y
	compress-level=3

	[global]
	repo1-host= $MASTER_NODE_IP
	repo1-host-user=postgres
	log-level-console=detail
	log-level-file=detail

	[global:archive-push]
	process-max=1
	compress=y
	compress-level=3

	[global:backup] 
	process-max= $CPU/3
	compress=y
	compress-level=3


#------------------------------------------------------------------------------
# STANZA COMMANDS
#------------------------------------------------------------------------------

pgbackrest --stanza=POSTGRES stanza-create
pgbackrest --stanza=POSTGRES check
pgbackrest --stanza=POSTGRES info
pgbackrest --stanza=POSTGRES start
pgbackrest --stanza=POSTGRES stop

pgbackrest --stanza=POSTGRES backup --type=full
pgbackrest --stanza=POSTGRES backup --type=diff
pgbackrest --stanza=POSTGRES backup --type=incr
pgbackrest --stanza=POSTGRES check


#------------------------------------------------------------------------------
# AUTOMATION & MONITORING BACKUP PROCESS
#------------------------------------------------------------------------------

## Automation Backup Process

mkdir /var/lib/pgsql/16/scripts
touch /var/lib/pgsql/16/scripts/full-backup.sh
touch /var/lib/pgsql/16/scripts/diff-backup.sh

mkdir /var/lib/pgsql/16/backups
touch /var/lib/pgsql/16/backups/backup.log

chmod -R 775 postgres:postgres /var/lib/pgsql/16/scripts/full-backup.sh
chmod -R 775 postgres:postgres /var/lib/pgsql/16/scripts/diff-backup.sh

vim full-backup.sh
	pgbackrest --stanza=POSTGRES backup--type=full  2>&1 | tee -a /var/lib/pgsql/16/backups/backup.log

vim diff-backup.sh
	pgbackrest --stanza=POSTGRES backup--type=diff  2>&1 | tee -a /var/lib/pgsql/16/backups/backup.log

crontab -e
	0 1 * * 0       bash /var/lib/pgsql/16/scripts/full-backup.sh
	0 1 * * 1-6     bash /var/lib/pgsql/16/scripts/diff-backup.sh
	0 9 * * *       truncate -s 0 /var/lib/pgsql/16/backup.log

## Monitoring Backup Process

sudo dnf install mailx

sudo vim /etc/mail.rc
	set smtp-use-starttls
	set ssl-verify=ignore
	set smtp="smtp://$MAIL_SERVER_IP:$SMTP_PORT"
	set smtp-auth=login
	set smtp-auth-user="$mail_user"
	set smtp-auth-password="$mail_user_pass"
	set from="$mail"

touch /var/lib/pgsql/16/scripts/mail.sh
chmod -R 775 postgres:postgres mail.sh

vim mail.sh
	###
	cmd=$(grep -ci "success" /var/lib/pgsql/16/backups/backup.log)

	if [ "$cmd" != "0" ]; then
	        pgbackrest info --stanza=POSTGRES >> /var/lib/pgsql/13/backups/backup.log
 	       tail -6 /var/lib/pgsql/16/backups/backup.log | mailx -s "POSTGRES BACKUP SUCCESSFULLY"  $MAIL
	else    
  	     tail -7 /var/lib/pgsql/16/backups/backup.log | mailx -s "POSTGRES BACKUP FAILED"        $MAIL
	fi
	###

crontab -e
	0 8 * * *       bash /var/lib/pgsql/16/scripts/mail.sh


#------------------------------------------------------------------------------
# RESTORE BACKUPS
#------------------------------------------------------------------------------

## List exists Backup Labels

pgbackrest --stanza=POSTGRES info
	full backup: 20240117-103837F
            timestamp start/stop: 2024-01-17 10:38:37+04 / 2024-01-17 10:38:39+04
            wal start/stop: 000000010000000000000002 / 000000010000000000000002
            database size: 23.4MB, database backup size: 23.4MB
            repo1: backup set size: 3.1MB, backup size: 3.1MB
	diff backup: 20240117-103837F_20240117-104039D
            timestamp start/stop: 2024-01-17 10:40:39+04 / 2024-01-17 10:40:40+04
            wal start/stop: 000000010000000000000004 / 000000010000000000000004
            database size: 23.4MB, database backup size: 2.1MB
            repo1: backup set size: 3.1MB, backup size: 258.8KB
            backup reference list: 20240117-103837
	full backup: 20240117-104511F
            timestamp start/stop: 2024-01-17 10:45:11+04 / 2024-01-17 10:45:13+04
            wal start/stop: 000000010000000000000008 / 000000010000000000000008
            database size: 23.4MB, database backup size: 23.4MB
            repo1: backup set size: 3.1MB, backup size: 3.1MB
	diff backup: 20240117-104511F_20240117-104702D
            timestamp start/stop: 2024-01-17 10:47:02+04 / 2024-01-17 10:47:04+04
            wal start/stop: 00000001000000000000000B / 00000001000000000000000B
            database size: 23.4MB, database backup size: 34.1KB
            repo1: backup set size: 3.1MB, backup size: 2.3KB
            backup reference list: 20240117-104511F
	diff backup: 20240117-104511F_20240117-104910D
            timestamp start/stop: 2024-01-17 10:49:10+04 / 2024-01-17 10:49:11+04
            wal start/stop: 00000001000000000000000E / 00000001000000000000000E
            database size: 23.4MB, database backup size: 36.4KB
            repo1: backup set size: 3.1MB, backup size: 2.5KB
            backup reference list: 20240117-104511F

## Restore Commands

sudo systemctl stop postgresql-13.service

# Restore to Last Backup: 
	pgbackrest --stanza=POSTGRES restore
	pgbackrest --stanza=POSTGRES restore --delta

# Point in Time Recovery: 
	pgbackrest --stanza=POSTGRES restore --delta --type=time --target="2024-01-17 10:47:18"
	pgbackrest --stanza=POSTGRES restore --delta --type=time --target="2024-01-17 10:47:18" --target-action=promote

# Restore to Other Data Directory: 
	pgbackrest --stanza=POSTGRES restore --delta --type=time --target="2024-01-17 10:49:11" --pg1-path=/u01/data/

vim /var/lib/pgsql/16/data/postgresql.conf
	archive_mode = 'off'

sudo systemctl start postgresql-16.service
# If not use --target-action=promote Option then user this query: 
	# select pg_wal_replay_resume();
