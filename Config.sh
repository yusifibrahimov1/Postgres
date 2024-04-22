#------------------------------------------------------------------------------
# REPORTING & LOGGING
#------------------------------------------------------------------------------

# - Where to Log -

log_destination = 'stderr'

# This is used when logging to stderr:
logging_collector = on

# These are only used if logging_collector is on:
log_directory = 'log'
log_filename = 'postgresql-%a.log'
#log_file_mode = 0600
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = on

# These are relevant when logging to syslog:
#syslog_facility = 'LOCAL0'
#syslog_ident = 'postgres'
#syslog_sequence_numbers = on
#syslog_split_messages = on

# This is only relevant when logging to eventlog (Windows):
#event_source = 'PostgreSQL'

# - When to Log -

#log_min_messages = warning
#log_min_error_statement = error
log_min_duration_statement = 2s
#log_min_duration_sample = -1
#log_statement_sample_rate = 1.0
#log_transaction_sample_rate = 0.0
#log_startup_progress_interval = 10s

# - What to Log -

#debug_print_parse = off
#debug_print_rewritten = off
#debug_print_plan = off
#debug_pretty_print = on
log_autovacuum_min_duration = 0
log_checkpoints = on
#log_connections = off
#log_disconnections = off
#log_duration = off
#log_error_verbosity = default
#log_hostname = off
log_line_prefix = '< %m user=%u db=%d host=%h  queryID=%Q  %a [%p]  '
log_lock_waits = on
log_recovery_conflict_waits = on
#log_parameter_max_length = -1
#log_parameter_max_length_on_error = 0
#log_statement = 'none'
#log_replication_commands = off
log_temp_files = 0
log_timezone = 'Asia/Baku'


#------------------------------------------------------------------------------
# PROCESS TITLE
#------------------------------------------------------------------------------

cluster_name = '$PROJECT_NAME'


#------------------------------------------------------------------------------
# STATISTICS
#------------------------------------------------------------------------------

# track_activities = on
# track_activity_query_size = 1024
# track_counts = on
track_io_timing = on
track_wal_io_timing = on
# track_functions = none
# stats_fetch_consistency = cache

compute_query_id = on
# log_statement_stats = off
# log_parser_stats = off
# log_planner_stats = off
# log_executor_stats = off
