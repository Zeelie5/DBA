USE master
GO

SET NOCOUNT ON

/*Generate an execution script for each database that needs the owner changed*/
DECLARE @LoopExecuteScripts TABLE (exec_command VARCHAR(1000))

INSERT INTO @LoopExecuteScripts
SELECT 'ALTER AUTHORIZATION ON DATABASE::[' + name + '] TO sa'
FROM sys.databases
WHERE owner_sid <> 0x01
	AND state_desc = 'ONLINE'

/*Loop through each record in @LoopExecuteScripts table and execute the command*/
DECLARE @Current_Record VARCHAR(1000)

SELECT @Current_Record = MIN(exec_command)
FROM @LoopExecuteScripts

WHILE @Current_Record IS NOT NULL
BEGIN
	PRINT @Current_Record

	EXEC (@Current_Record)

	--Delete processed record
	DELETE
	FROM @LoopExecuteScripts
	WHERE exec_command = @Current_Record

	--Get next record to be processed
	SELECT @Current_Record = MIN(exec_command)
	FROM @LoopExecuteScripts
END
