DECLARE @cmd varchar(MAX),
		@SearchText VARCHAR(MAX),
		@NameOrDefinition BIT = 1

SET @SearchText = ''
IF @NameOrDefinition = 1
BEGIN
 SET @cmd='USE [?] SELECT DB_NAME(),* FROM SYS.OBJECTS WHERE OBJECT_DEFINITION(object_id) LIKE ''%'+@SearchText+'%'''  
END ELSE
BEGIN
 SET @cmd='USE [?] SELECT DB_NAME(),* FROM SYS.OBJECTS WHERE NAME LIKE ''%'+@SearchText+'%'''  
END
exec sp_MSforeachdb @cmd