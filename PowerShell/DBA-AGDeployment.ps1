Import-Module DBATools
Set-DbatoolsInsecureConnection -SessionOnly

try {

$SourceServer = ""
$DestinationServer = ""
$Node2Server = ""
$AvailabilityGroup = ""
$SharedFolder = ""
$Databases = @("")
$SeedingMode = "Automatic"
$username = ""  
$password = ""  
$wincred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $Password -asplaintext -force)
$SourceConnection = Connect-DbaInstance -SqlInstance $SourceServer -SqlCredential $wincred -TrustServerCertificate
$DestinationConnection = Connect-DbaInstance -SqlInstance $DestinationServer -SqlCredential $wincred -TrustServerCertificate
$Node2Connection = Connect-DbaInstance -SqlInstance $Node2Server -SqlCredential $wincred -TrustServerCertificate

$ScriptDropDatabasesOnSecondary = 
"WHILE EXISTS(
		SELECT TOP 1 1
		FROM master.sys.databases
		WHERE
			databases.name NOT IN ('master','tempdb','model','msdb') AND
			databases.name NOT IN (SELECT databases.name
			FROM master.sys.dm_hadr_database_replica_states 
			INNER JOIN master.sys.databases ON dm_hadr_database_replica_states.database_id = databases.database_id
			WHERE is_local = 1 AND synchronization_state_desc = 'SYNCHRONIZED') AND
			databases.state_desc <> 'RESTORING')
BEGIN
	PRINT 'WAITING FOR THE SECONDARY TO PUT ALL DBs IN THE RESTORING STATE'
	WAITFOR DELAY '00:00:30';
END

DECLARE @DropDBSQLTable TABLE
(
	SQLStatement NVARCHAR(MAX)
)
DECLARE @DropDBCurrentSQL NVARCHAR(MAX)
 
INSERT @DropDBSQLTable
SELECT 'DROP DATABASE ' + QUOTENAME(name)
FROM master.sys.databases
WHERE
	databases.name NOT IN ('master','tempdb','model','msdb') AND
	databases.name NOT IN (SELECT databases.name
		FROM master.sys.dm_hadr_database_replica_states 
		INNER JOIN master.sys.databases ON dm_hadr_database_replica_states.database_id = databases.database_id
		WHERE is_local = 1 AND synchronization_state_desc = 'SYNCHRONIZED') AND
	databases.state_desc = 'RESTORING'

WHILE EXISTS(SELECT TOP 1 1 FROM @DropDBSQLTable)
BEGIN
	SET @DropDBCurrentSQL = (SELECT TOP 1 SQLStatement FROM @DropDBSQLTable)

	PRINT @DropDBCurrentSQL 
	EXEC SP_EXECUTESQL @DropDBCurrentSQL
	
	DELETE @DropDBSQLTable
	WHERE
		SQLStatement = @DropDBCurrentSQL
END"

$ScriptRunThisBeforeAddingDBsToAG = 
"USE master
GO

SET NOCOUNT ON

DECLARE @DesiredCompatibilityMode INT

SET @DesiredCompatibilityMode = (SELECT TOP 1 compatibility_level FROM master.sys.databases WHERE name = 'master')

DECLARE @LoopExecuteScripts TABLE (exec_command VARCHAR(1000))

INSERT INTO @LoopExecuteScripts
SELECT 'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(name) + ' TO sa'
FROM sys.databases
WHERE
	owner_sid <> 0x01 AND
	state_desc = 'ONLINE'

IF EXISTS(SELECT TOP 1 1 FROM @LoopExecuteScripts)
BEGIN
DECLARE @Current_Record VARCHAR(1000)

SELECT @Current_Record = MIN(exec_command)
FROM @LoopExecuteScripts

WHILE @Current_Record IS NOT NULL
BEGIN
	PRINT @Current_Record
	EXEC (@Current_Record)

	DELETE
	FROM @LoopExecuteScripts
	WHERE exec_command = @Current_Record

	SELECT @Current_Record = MIN(exec_command)
	FROM @LoopExecuteScripts
END
END ELSE
BEGIN
	PRINT 'No databases require the Ownership fix.'
END

DECLARE @UpgradeSQLTable TABLE
(
	SQLStatement NVARCHAR(MAX)
)
DECLARE @UpgradeCurrentSQL NVARCHAR(MAX)
 
INSERT @UpgradeSQLTable
SELECT 'ALTER DATABASE ' + QUOTENAME(name) + ' SET COMPATIBILITY_LEVEL = ' + CAST(@DesiredCompatibilityMode AS VARCHAR(20))
FROM master.sys.databases
WHERE
	compatibility_level <> @DesiredCompatibilityMode

IF EXISTS(SELECT TOP 1 1 FROM @UpgradeSQLTable)
BEGIN
WHILE EXISTS(SELECT TOP 1 1 FROM @UpgradeSQLTable)
BEGIN
	SET @UpgradeCurrentSQL = (SELECT TOP 1 SQLStatement FROM @UpgradeSQLTable)

	PRINT @UpgradeCurrentSQL 
	EXEC SP_EXECUTESQL @UpgradeCurrentSQL
	
	DELETE @UpgradeSQLTable
	WHERE
		SQLStatement = @UpgradeCurrentSQL
END
END ELSE
BEGIN
	PRINT 'No databases require COMPATIBILITY_LEVEL upgrades to ' + CAST(@DesiredCompatibilityMode AS VARCHAR(20)) + '.'
END

DECLARE @FixNO_WAITSQLTable TABLE
(
	SQLStatement NVARCHAR(MAX)
)
DECLARE @FixNO_WAITCurrentSQL NVARCHAR(MAX)
 
INSERT @FixNO_WAITSQLTable
SELECT 'ALTER DATABASE ' + QUOTENAME(name) + ' SET AUTO_CLOSE OFF WITH NO_WAIT'
FROM master.sys.databases
WHERE
	is_auto_close_on = 1
 
IF EXISTS(SELECT TOP 1 1 FROM @FixNO_WAITSQLTable)
BEGIN
WHILE EXISTS(SELECT TOP 1 1 FROM @FixNO_WAITSQLTable)
BEGIN
	SET @FixNO_WAITCurrentSQL = (SELECT TOP 1 SQLStatement FROM @FixNO_WAITSQLTable)
 
	PRINT @FixNO_WAITCurrentSQL
	EXEC SP_EXECUTESQL @FixNO_WAITCurrentSQL
	
	DELETE @FixNO_WAITSQLTable
	WHERE
		SQLStatement = @FixNO_WAITCurrentSQL
END
END ELSE
BEGIN
	PRINT 'No databases require NO_WAIT to be switched off.'
END

DECLARE @SetRecoveryModelSQLTable TABLE
(
	SQLStatement NVARCHAR(MAX)
)
DECLARE @SetRecoveryModelCurrentSQL NVARCHAR(MAX)
DECLARE @BackupSQLTable TABLE
(
	SQLStatement NVARCHAR(MAX)
)

INSERT @SetRecoveryModelSQLTable
SELECT 'ALTER DATABASE ' + QUOTENAME(name) + ' SET RECOVERY FULL WITH NO_WAIT'
FROM master.sys.databases
WHERE
	recovery_model_desc <> 'FULL' AND
	name NOT IN ('master','tempdb','msdb')

DECLARE @DefaultBackupDirectoryTable TABLE
(
	Value VARCHAR(MAX),
	Data VARCHAR(MAX)
)
DECLARE @DefaultBackupDirectory VARCHAR(MAX)

INSERT @DefaultBackupDirectoryTable
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer',N'BackupDirectory'

SET @DefaultBackupDirectory = (SELECT TOP 1 Data + '\' FROM @DefaultBackupDirectoryTable)

INSERT @BackupSQLTable
SELECT 'BACKUP DATABASE ' + QUOTENAME(name) + ' TO DISK = N''' + @DefaultBackupDirectory + name + '_'+CAST(FORMAT (GETDATE(), 'yyyy_MM_dd') AS NVARCHAR(20))+'_NEW.bak'+''' WITH NOFORMAT, NOINIT, NAME = N'''+name+'-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 10'
FROM master.sys.databases
WHERE
	recovery_model_desc <> 'FULL' AND
	name NOT IN ('master','tempdb','msdb')

IF EXISTS(SELECT TOP 1 1 FROM @SetRecoveryModelSQLTable)
BEGIN
WHILE EXISTS(SELECT TOP 1 1 FROM @SetRecoveryModelSQLTable)
BEGIN
	SET @SetRecoveryModelCurrentSQL = (SELECT TOP 1 SQLStatement FROM @SetRecoveryModelSQLTable)
 
	PRINT @SetRecoveryModelCurrentSQL
	EXEC SP_EXECUTESQL @SetRecoveryModelCurrentSQL
	
	DELETE @SetRecoveryModelSQLTable
	WHERE
		SQLStatement = @SetRecoveryModelCurrentSQL
END
END ELSE
BEGIN
	PRINT 'No databases have to be switched to the FULL recovery model.'
END

DECLARE @BackupCurrentSQL NVARCHAR(MAX)
 
IF EXISTS(SELECT TOP 1 1 FROM @BackupSQLTable)
BEGIN
WHILE EXISTS(SELECT TOP 1 1 FROM @BackupSQLTable)
BEGIN
	SET @BackupCurrentSQL = (SELECT TOP 1 SQLStatement FROM @BackupSQLTable)
 
	PRINT @BackupCurrentSQL
	EXEC SP_EXECUTESQL @BackupCurrentSQL
 
	DELETE @BackupSQLTable
	WHERE
		SQLStatement = @BackupCurrentSQL
END
END ELSE
BEGIN
	PRINT 'No databases have to be backed up after being switched to the FULL recovery model.'
END"

# Remove old databases from the Availability Group
Remove-DbaAgDatabase -SqlInstance $DestinationServer -AvailabilityGroup $AvailabilityGroup -Database $Databases -Confirm:$false
# Remove the old databases from the Secondary Node
Invoke-DbaQuery -SqlInstance $Node2Connection -Query $ScriptDropDatabasesOnSecondary
# Remove the old databases from the Primary Node
Remove-DbaDatabase -SqlInstance $DestinationServer -Database $Databases -Confirm:$false
# Import sp_configure from the source server to the destination server
Import-DbaSpConfigure -Source $SourceConnection -Destination $DestinationConnection -Force
# Restore Databases 
Copy-DbaDatabase -Source $SourceServer -SourceSqlCredential $wincred -Destination $DestinationServer -DestinationSqlCredential $wincred -Database $Databases -Force -BackupRestore -SharedPath $SharedFolder -WithReplace -AdvancedBackupParams @{ CompressBackup = $true }
# Fix databases to sync on the Availability Group
Invoke-DbaQuery -SqlInstance $DestinationConnection -Query $ScriptRunThisBeforeAddingDBsToAG
# Add databases to Availability Group
Add-DbaAgDatabase -SqlInstance $DestinationConnection -AvailabilityGroup $AvailabilityGroup -Database $Databases -SeedingMode $SeedingMode
# Port logins from Source Server
Copy-DbaLogin -Source $SourceServer -Destination $DestinationServer -ExcludeSystemLogins
# Sync objects between nodes on the new AG
Sync-DbaAvailabilityGroup -Primary $DestinationServer -AvailabilityGroup $AvailabilityGroup -DisableJobOnDestination
# Fix Memory and Max DOP after sp_configure
Set-DbaMaxMemory -SqlInstance $DestinationConnection
Set-DbaMaxMemory -SqlInstance $Node2Connection
Set-DbaMaxDop -SqlInstance $DestinationConnection
Set-DbaMaxDop -SqlInstance $Node2Connection
Set-DbaSpConfigure -SqlInstance $DestinationConnection -Name 'cost threshold for parallelism' -Value 50
Set-DbaSpConfigure -SqlInstance $Node2Connection -Name 'cost threshold for parallelism' -Value 50

}
catch {
	Write-Host "An error occurred:"
    Write-Host $_
}