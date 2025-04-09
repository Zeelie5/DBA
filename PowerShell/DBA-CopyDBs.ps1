$SourceServer = ""
$DestinationServer = ""
$SharedFolder = ""
$Databases = @("")
$username = ""  
$password = ""  
$wincred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName, $(convertto-securestring $Password -asplaintext -force)
$SourceConnection = Connect-DbaInstance -SqlInstance $SourceServer -SqlCredential $wincred -TrustServerCertificate
$DestinationConnection = Connect-DbaInstance -SqlInstance $DestinationServer -SqlCredential $wincred -TrustServerCertificate

Copy-DbaDatabase -Source $SourceServer -SourceSqlCredential $wincred -Destination $DestinationServer -DestinationSqlCredential $wincred -Database $Databases -Force -BackupRestore -SharedPath $SharedFolder -WithReplace -AdvancedBackupParams @{ CompressBackup = $true }