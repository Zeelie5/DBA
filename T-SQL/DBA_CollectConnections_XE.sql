CREATE EVENT SESSION [DBA_CollectConnections] ON SERVER ADD EVENT sqlserver.connectivity_ring_buffer_recorded (ACTION(sqlserver.client_app_name, sqlserver.client_connection_id, sqlserver.client_hostname, sqlserver.context_info, sqlserver.server_principal_name, sqlserver.session_id))
	,ADD EVENT sqlserver.LOGIN (
	SET collect_database_name = (1)
	,collect_options_text = (0) ACTION(sqlserver.client_app_name, sqlserver.client_connection_id, sqlserver.client_hostname, sqlserver.context_info, sqlserver.database_id, sqlserver.database_name, sqlserver.nt_username, sqlserver.server_instance_name, sqlserver.server_principal_name, sqlserver.session_nt_username, sqlserver.username)
	) ADD TARGET package0.event_file (
	SET filename = N'C:\temp\DBA_CollectConnections'
	,max_file_size = (5120)
	,max_rollover_files = (0)
	)
	WITH (
			MAX_MEMORY = 4096 KB
			,EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
			,MAX_DISPATCH_LATENCY = 30 SECONDS
			,MAX_EVENT_SIZE = 0 KB
			,MEMORY_PARTITION_MODE = NONE
			,TRACK_CAUSALITY = ON
			,STARTUP_STATE = ON
			)
GO

