declare @name varchar(150)
declare @query nvarchar (500)

DECLARE cur CURSOR FOR
    select name from master..syslogins

Open cur

FETCH NEXT FROM cur into @name

WHILE @@FETCH_STATUS = 0
BEGIN

set @query='USE [?]
IF ''?'' <> ''master'' AND ''?'' <> ''model'' AND ''?'' <> ''msdb'' AND ''?'' <> ''tempdb''
BEGIN   
exec sp_change_users_login ''Auto_Fix'', '''+ @name +'''
END'

EXEC master..sp_MSForeachdb @query

    FETCH NEXT FROM cur into @name

END

CLOSE cur
DEALLOCATE cur