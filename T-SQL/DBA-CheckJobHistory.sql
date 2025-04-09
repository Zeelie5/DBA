DECLARE @StartDatetime DATETIME,
		@EndDatetime DATETIME

SET @StartDatetime = DATEADD(WEEK,-2,GETDATE())
SET @EndDatetime = GETDATE()

DECLARE @JobsToExclude TABLE
(
  Name NVARCHAR(128)
)
INSERT @JobsToExclude
SELECT 'DatabaseBackup - USER_DATABASES - FULL'

DECLARE @CategoriesToExclude TABLE
(
  Name NVARCHAR(128)
)
INSERT @CategoriesToExclude
SELECT 'Report Server'

SELECT sysjobs.name,
msdb.dbo.agent_datetime(run_date, run_time) AS [DateTimeRun],
STUFF(STUFF(STUFF(
    RIGHT('00' + TRIM(STR((sysjobhistory.run_duration / 240000))), 2) +
    RIGHT('00' + TRIM(STR((sysjobhistory.run_duration / 10000) % 24)), 2) +
    RIGHT('0000' + STR(sysjobhistory.run_duration), 4)
    , 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS [StepLastRunDuration],
sysjobhistory.run_duration,
*
FROM msdb..sysjobhistory
INNER JOIN msdb..sysjobs ON sysjobhistory.job_id = sysjobs.job_id
INNER JOIN msdb..syscategories ON sysjobs.category_id = syscategories.category_id
WHERE
	step_id = 0 AND
	msdb.dbo.agent_datetime(run_date, run_time) BETWEEN @StartDatetime AND @EndDatetime AND
	syscategories.name NOT IN (SELECT Name FROM @CategoriesToExclude) AND
	sysjobs.name NOT IN (SELECT Name FROM @JobsToExclude)
ORDER BY msdb.dbo.agent_datetime(run_date, run_time) DESC