DECLARE @TopRecordCount INT = 10,
		@StartDateTime DATETIME,
		@EndDateTime DATETIME,
		@MetricDESC VARCHAR(20)

SET @StartDateTime = GETDATE()-1
SET @EndDateTime = GETDATE()
SET @MetricDESC = 'Runtime'

IF @MetricDESC = 'Runtime'

  BEGIN

    SELECT TOP (@TopRecordCount) query_store_query.query_id,
    query_store_query_text.query_sql_text,
    SUM(query_store_runtime_stats.count_executions) AS TotalExecutions,
    SUM((CAST(query_store_runtime_stats.avg_duration AS DECIMAL(18,5))/1000) * query_store_runtime_stats.count_executions)/60000 AS TotalDurationMin,
    (SUM((CAST(query_store_runtime_stats.avg_duration AS DECIMAL(18,5))/1000) * query_store_runtime_stats.count_executions)/60000)/SUM(query_store_runtime_stats.count_executions) AS AverageDurationMin,
    SUM((CAST(query_store_runtime_stats.avg_cpu_time AS DECIMAL(18,5))/1000) * query_store_runtime_stats.count_executions)/60000 AS TotalCPUMin,
    (SUM((CAST(query_store_runtime_stats.avg_cpu_time AS DECIMAL(18,5))/1000) * query_store_runtime_stats.count_executions)/60000)/SUM(query_store_runtime_stats.count_executions) AS AverageCPUMin,
    SUM(query_store_runtime_stats.avg_logical_io_reads                       * query_store_runtime_stats.count_executions) AS TotalLogicalIOReads,
    CAST((SUM(query_store_runtime_stats.avg_logical_io_reads * query_store_runtime_stats.count_executions))/SUM(query_store_runtime_stats.count_executions) AS BIGINT) AS AverageLogicalIOReads,
    SUM(query_store_runtime_stats.avg_logical_io_writes * query_store_runtime_stats.count_executions) AS TotalLogicalIOWrites,
    CAST((SUM(query_store_runtime_stats.avg_logical_io_writes * query_store_runtime_stats.count_executions)/SUM(query_store_runtime_stats.count_executions)) AS BIGINT) AS AverageLogicalIOWrites,
    SUM(query_store_runtime_stats.avg_physical_io_reads * query_store_runtime_stats.count_executions) AS TotalPhysicalIOReads,
    CAST((SUM(query_store_runtime_stats.avg_physical_io_reads * query_store_runtime_stats.count_executions)/SUM(query_store_runtime_stats.count_executions)) AS BIGINT) AS AveragePhysicalIOReads,
    SUM(query_store_runtime_stats.avg_rowcount * query_store_runtime_stats.count_executions) AS TotalRowCount,
    CAST((SUM(query_store_runtime_stats.avg_rowcount * query_store_runtime_stats.count_executions)/SUM(query_store_runtime_stats.count_executions)) AS BIGINT) AS AverageRowCount
    FROM [V11_AP_WSML_DATA].sys.query_store_query
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_query_text ON query_store_query.query_text_id = query_store_query_text.query_text_id 
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_plan ON query_store_query.query_id = query_store_plan.query_id 
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_runtime_stats ON query_store_plan.plan_id = query_store_runtime_stats.plan_id
    WHERE
	    query_store_runtime_stats.last_execution_time BETWEEN @StartDateTime AND @EndDateTime
    GROUP BY query_store_query.query_id,
    query_store_query_text.query_sql_text
	ORDER BY SUM(query_store_runtime_stats.avg_duration * query_store_runtime_stats.count_executions) DESC

  END

IF @MetricDESC = 'Wait'

  BEGIN

    SELECT TOP (@TopRecordCount) query_store_query.query_id,
    query_store_query_text.query_sql_text,
    SUM(CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)))/60000 AS TotalWaitTimeMin,
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Buffer IO', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [BufferIOMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Network IO', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [NetworkIOMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Lock', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [LockMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Latch', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [LatchMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Unknown', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [UnknownMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'CPU', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [CPUMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Memory', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [MemoryMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Parallelism', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [ParallelismMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Other Disk IO', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [OtherDiskIOMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Idle', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [IdleMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Buffer Latch', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [BufferLatchMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'SQL CLR', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [SQLCLRMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Preemptive', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [PreemptiveMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Tracing', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [TracingMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Replication', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [ReplicationMin],
    SUM(IIF(query_store_wait_stats.wait_category_desc = 'Tran Log IO', CAST(query_store_wait_stats.total_query_wait_time_ms AS DECIMAL(18,5)), 0))/60000 AS [TranLogIOMin]
    FROM [V11_AP_WSML_DATA].sys.query_store_query
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_query_text ON query_store_query.query_text_id = query_store_query_text.query_text_id 
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_plan ON query_store_query.query_id = query_store_plan.query_id 
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_runtime_stats ON query_store_plan.plan_id = query_store_runtime_stats.plan_id
    INNER JOIN [V11_AP_WSML_DATA].sys.query_store_wait_stats ON query_store_runtime_stats.plan_id = query_store_wait_stats.plan_id AND
															    query_store_runtime_stats.execution_type = query_store_wait_stats.execution_type AND
															    query_store_runtime_stats.runtime_stats_interval_id = query_store_wait_stats.runtime_stats_interval_id
    WHERE
	    query_store_runtime_stats.last_execution_time BETWEEN @StartDateTime AND @EndDateTime
    GROUP BY query_store_query.query_id,
    query_store_query_text.query_sql_text
    ORDER BY SUM(query_store_wait_stats.total_query_wait_time_ms) DESC

  END