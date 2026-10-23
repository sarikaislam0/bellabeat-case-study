-- Row and User count of all tables
SELECT 'daily_activity' AS table_name, COUNT(*) AS row_count, COUNT(DISTINCT Id) AS num_users
FROM `portfolio-509922.bellabeat.daily_activity`
UNION ALL
SELECT 'hourlySteps', COUNT(*), COUNT(DISTINCT Id)
FROM `portfolio-509922.bellabeat.hourlySteps`
UNION ALL
SELECT 'minutesSleep', COUNT(*), COUNT(DISTINCT Id)
FROM `portfolio-509922.bellabeat.minutesSleep`
UNION ALL
SELECT 'weightLog', COUNT(*), COUNT(DISTINCT Id)
FROM `portfolio-509922.bellabeat.weightLog`;

-- Check for duplicates (no duplicates)
SELECT
  Id, ActivityDate, COUNT(*) as N,
FROM 
  `portfolio-509922.bellabeat.daily_activity`
GROUP BY 
  Id, ActivityDate
HAVING 
  COUNT(*) > 1
;

-- Check for nulls
SELECT
  (COUNTIF(Id IS NULL OR ActivityDate IS NULL OR TotalSteps IS NULL OR VeryActiveMinutes IS NULL OR FairlyActiveMinutes IS NULL OR LightlyActiveMinutes IS NULL OR SedentaryMinutes IS NULL)) AS null_row
FROM 
  `portfolio-509922.bellabeat.daily_activity`
;

-- Create a new clean table
CREATE OR REPLACE TABLE `portfolio-509922.bellabeat.daily_clean` AS
WITH tempr AS (
  SELECT
    Id,
    ActivityDate,
    TotalSteps,
    (VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes + SedentaryMinutes) AS active_min
  FROM `portfolio-509922.bellabeat.daily_activity`
)
SELECT DISTINCT
  *,
  FORMAT_DATE('%A', ActivityDate) AS weekday_name,
FROM tempr
WHERE TotalSteps > 0; -- remove the entries that have 0 total steps

-- check the clean table
SELECT 
  COUNT(*) AS row_count, 
  COUNT(DISTINCT Id) AS users, 
  ROUND(AVG(TotalSteps)) AS avg_steps,
  COUNTIF(ActivityDate IS NULL) AS null_dates
FROM `portfolio-509922.bellabeat.daily_clean`;

-- find the average steps per day
SELECT
  weekday_name,
  COUNT(*) AS num_of_days,
  ROUND(AVG(TotalSteps)) AS avg_steps
FROM
  `portfolio-509922.bellabeat.daily_clean`
GROUP BY weekday_name
ORDER BY avg_steps DESC;

-- find average steps by hour of the day
WITH hourly AS (
  SELECT
    PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', ActivityHour) AS time_stamp,
    StepTotal
  FROM `portfolio-509922.bellabeat.hourlySteps`
)
SELECT
  EXTRACT(HOUR FROM time_stamp)         AS hour_24,
  FORMAT_TIMESTAMP('%I %p', time_stamp) AS hour_label,
  ROUND(AVG(StepTotal))         AS avg_steps
FROM hourly
GROUP BY hour_24, hour_label
ORDER BY hour_24;

-- max and min user logs
SELECT
  Id,
  COUNT(Id) as total_logs
FROM
  `portfolio-509922.bellabeat.daily_clean`
GROUP BY Id
ORDER BY total_logs;
-- found that minimum user logs is 2 and maximum is 32

-- find how often people wear their FitBits
CREATE OR REPLACE TABLE `portfolio-509922.bellabeat.user_level_table` AS
  SELECT
    Id,
    COUNT(Id) AS total_logs,
    CASE
      WHEN COUNT(Id) BETWEEN 2 AND 11 THEN 'light_user'
      WHEN COUNT(Id) BETWEEN 12 AND 21 THEN 'moderate_user'
      WHEN COUNT(Id) BETWEEN 22 AND 32 THEN 'active_user'
    ELSE 'UNKNOWN'
    END AS user_level,
  FROM 
    `portfolio-509922.bellabeat.daily_clean`
  GROUP BY Id;

-- find the percentage 
WITH counts AS (
  SELECT
    COUNT(*) AS total,
    COUNTIF(user_level = 'light_user') AS light_users,
    COUNTIF(user_level = 'moderate_user') AS moderate_users,
    COUNTIF(user_level = 'active_user') AS active_users
  FROM `portfolio-509922.bellabeat.user_level_table`
)
SELECT
  total,
  ROUND(light_users / total * 100,1) AS light_users_percentage,
  ROUND(moderate_users / total * 100,1) AS moderate_users_percentage,
  ROUND(active_users / total * 100,1) AS active_users_percentage
FROM counts;


