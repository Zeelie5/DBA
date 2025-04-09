/*
declare @SQL nvarchar(max) ='use [?] dbcc opentran()'

exec msdb.sys.sp_MSforeachdb @SQL
*/

--sp_who2 -- select @@servername
SELECT DISTINCT
    @@SERVERNAME AS ServerName,
    d.name AS DatabaseName,
    c.net_transport,
    c.encrypt_option,
    c.local_tcp_port,
    c.auth_scheme,
    s.host_name,
    c.client_net_address,
    s.original_login_name,
    GETDATE() AS DateChecked
FROM sys.dm_exec_connections AS c
JOIN sys.dm_exec_sessions AS s ON c.session_id = s.session_id
JOIN sys.databases AS d ON s.database_id = d.database_id
--WHERE c.net_transport = 'TCP'

-- LEADBLOCKERS
IF EXISTS (
        SELECT * FROM sys.dm_exec_requests
        WHERE blocking_session_id <> 0
           )
        SELECT
        er.blocking_session_id
        ,es.session_id
		,SUBSTRING(st.text, er.statement_start_offset / 2,
        (CASE WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(nvarchar(max), st.text)) * 2
        ELSE er.statement_end_offset END - er.statement_start_offset) / 2) AS query_text
        ,es.program_name
        ,es.status
        ,es.login_name
        ,DB_NAME(er.database_id) as database_name
        ,es.host_name
        ,er.wait_type
        ,er.wait_time
        ,er.last_wait_type
        ,er.wait_resource
        ,CASE es.transaction_isolation_level WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'ReadUncommitted'
        WHEN 2 THEN 'ReadCommitted'
        WHEN 3 THEN 'Repeatable'
        WHEN 4 THEN 'Serializable'
        WHEN 5 THEN 'Snapshot'
        END AS transaction_isolation_level
        ,OBJECT_NAME(st.objectid, er.database_id) as object_name
        ,ph.query_plan
        FROM sys.dm_exec_connections ec
        LEFT OUTER JOIN sys.dm_exec_sessions es ON ec.session_id = es.session_id
        LEFT OUTER JOIN sys.dm_exec_requests er ON ec.connection_id = er.connection_id
        OUTER APPLY sys.dm_exec_sql_text(sql_handle) st
        OUTER APPLY sys.dm_exec_query_plan(plan_handle) ph
        WHERE ec.session_id <> @@SPID
        AND es.status = 'running'
        AND er.blocking_session_id > 0
        ORDER BY er.blocking_session_id desc, es.session_id --es.session_id
ELSE
  SELECT 'No blocking processes found!' [Status]

SELECT
es.session_id
,es.status
,es.login_name
,DB_NAME(er.database_id) as database_name
,es.host_name
,es.program_name
,er.blocking_session_id
,er.command
,es.reads
,es.writes
,es.cpu_time
,er.wait_type
,er.wait_time
,er.last_wait_type
,er.wait_resource
,CASE es.transaction_isolation_level WHEN 0 THEN 'Unspecified'
WHEN 1 THEN 'ReadUncommitted'
WHEN 2 THEN 'ReadCommitted'
WHEN 3 THEN 'Repeatable'
WHEN 4 THEN 'Serializable'
WHEN 5 THEN 'Snapshot'
END AS transaction_isolation_level
,OBJECT_NAME(st.objectid, er.database_id) as object_name
,SUBSTRING(st.text, er.statement_start_offset / 2,
(CASE WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(nvarchar(max), st.text)) * 2
ELSE er.statement_end_offset END - er.statement_start_offset) / 2) AS query_text
,ph.query_plan
FROM sys.dm_exec_connections ec
LEFT OUTER JOIN sys.dm_exec_sessions es ON ec.session_id = es.session_id
LEFT OUTER JOIN sys.dm_exec_requests er ON ec.connection_id = er.connection_id
OUTER APPLY sys.dm_exec_sql_text(sql_handle) st
OUTER APPLY sys.dm_exec_query_plan(plan_handle) ph
WHERE ec.session_id <> @@SPID
AND es.status = 'running'
ORDER BY es.program_name

-- HOW LONG DBCC STILL GOING TO TAKE
select percent_complete, command , start_time 
  from sys.dm_exec_requests
where command like '%dbcc%'

--or for a shrinkfile you can measure progress to some extent like such:
SELECT percent_complete, start_time, status, command, estimated_completion_time, cpu_time, total_elapsed_time--,*
  FROM 
       sys.dm_exec_requests
 WHERE
       command = 'DbccFilesCompact'

-- Average Total File Latency
SELECT *, 
       CASE
         WHEN [Average Total Latency] <1 THEN 'Excellent' 
         WHEN [Average Total Latency] <5 THEN 'Very good' 
         WHEN [Average Total Latency] <10 THEN 'Good' 
         WHEN [Average Total Latency] <20 THEN 'Poor' 
         WHEN [Average Total Latency] <100 THEN 'Bad' 
         WHEN [Average Total Latency] <500 THEN 'Very Bad' 
         WHEN [Average Total Latency] >=500 THEN 'Awful' 
         ELSE ''
       END AS [AvgTotLatStatus]
  FROM (
        SELECT  DB_NAME(vfs.database_id) AS database_name ,physical_name AS [Physical Name],
                size_on_disk_bytes / 1024 / 1024. AS [Size of Disk] ,
                CAST(io_stall_read_ms/(1.0 + num_of_reads) AS NUMERIC(10,1)) AS [Average Read latency] ,
                CAST(io_stall_write_ms/(1.0 + num_of_writes) AS NUMERIC(10,1)) AS [Average Write latency] ,
                CAST((io_stall_read_ms + io_stall_write_ms)
        /(1.0 + num_of_reads + num_of_writes) 
        AS NUMERIC(10,1)) AS [Average Total Latency],
                num_of_bytes_read / NULLIF(num_of_reads, 0) AS    [Average Bytes Per Read],
                num_of_bytes_written / NULLIF(num_of_writes, 0) AS   [Average Bytes Per Write]
        FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
          JOIN sys.master_files AS mf 
            ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id ) a 
ORDER BY [Average Total Latency] DESC

--SELECT name, log_reuse_wait_desc FROM sys.databases;

SELECT 
   r.session_id
 , r.command
 , CONVERT(NUMERIC(6,2), r.percent_complete) AS [Percent Complete]
 , CONVERT(VARCHAR(20), DATEADD(ms,r.estimated_completion_time,GetDate()),20) AS [ETA Completion Time]
 , CONVERT(NUMERIC(10,2), r.total_elapsed_time/1000.0/60.0) AS [Elapsed Min]
 , CONVERT(NUMERIC(10,2), r.estimated_completion_time/1000.0/60.0) AS [ETA Min]
 , CONVERT(NUMERIC(10,2), r.estimated_completion_time/1000.0/60.0/60.0) AS [ETA Hours]
 , CONVERT(VARCHAR(1000), 
      (SELECT SUBSTRING(text,r.statement_start_offset/2, CASE WHEN r.statement_end_offset = -1 
                                                             THEN 1000 
                                                             ELSE (r.statement_end_offset-r.statement_start_offset)/2 
                                                        END)
        FROM sys.dm_exec_sql_text(sql_handle)
       )
   ) AS [SQL]
  FROM sys.dm_exec_requests r 
 WHERE command IN ('RESTORE DATABASE', 'RESTORE HEADERONLY', 'BACKUP DATABASE','BACKUP LOG')