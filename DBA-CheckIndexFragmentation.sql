DECLARE @Query NVARCHAR(MAX)
SET @Query = 'USE ? SELECT DB_NAME() as ''DB'',
dbschemas.[name] as ''Schema'', 
    dbtables.[name] as ''Table'', 
    dbindexes.[name] as ''Index'',
    indexstats.alloc_unit_type_desc,
    indexstats.avg_fragmentation_in_percent,
    indexstats.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
    AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.database_id = DB_ID()
ORDER BY indexstats.avg_fragmentation_in_percent desc'

DECLARE @FragmentedIndexes TABLE
(
	DB NVARCHAR(MAX),
	[Schema] NVARCHAR(MAX),
	[Table] NVARCHAR(MAX),
	[Index] NVARCHAR(MAX),
	alloc_unit_type_desc NVARCHAR(MAX),
	avg_fragmentation_in_percent DECIMAL(18,9),
	page_count INT
)

INSERT @FragmentedIndexes
exec sp_MSforeachdb @Query

SELECT *
FROM @FragmentedIndexes
WHERE
	DB NOT IN ('master', 'tempdb')
ORDER BY avg_fragmentation_in_percent DESC