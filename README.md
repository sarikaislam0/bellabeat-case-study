# bellabeat-case-study
SQL, Excel and Tableau analysis of Fitbit usage data with marketing recommendations for Bellabeat’s Leaf tracker.

# Bellabeat Case Study: How Fitbit Users Move Through the Day and Week

**Google Data Analytics Capstone** | SQL (BigQuery), Excel, Tableau

**Live dashboard:** ![Live Dashboard](https://public.tableau.com/views/Bellabeat_17923712259800/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## Summary

Bellabeat is a health-focused smart device company for women. Its cofounder asked the marketing analytics team to study how people use non-Bellabeat smart devices and turn those trends into marketing recommendations for one Bellabeat product. I chose **Leaf**, Bellabeat's wellness tracker that can be worn as a bracelet, necklace or clip.

**Headline findings**
- Steps peak around **midday and 7 PM**, with a dip near 3 PM.
- **Monday (8,204 average steps)** and **Saturday (8,181)** are the most active days.
- **Wear consistency is low:** 44% of users logged step data on only 2 to 11 days, and just 1 of 34 logged it on 22 or more.

---

## 1. Ask

**Business task:** Analyze non-Bellabeat smart device usage to guide Bellabeat's marketing strategy for the Leaf tracker.

**Guiding questions**
1. What are some trends in smart device usage?
2. How could these trends apply to Bellabeat customers?
3. How could these trends influence Bellabeat's marketing strategy?

**Stakeholders:** Urska Srsen (cofounder and Chief Creative Officer), Sando Mur (cofounder), and the Bellabeat executive team.

---

## 2. Prepare

**Data source:** [FitBit Fitness Tracker Data](https://www.kaggle.com/datasets/arashnic/fitbit) on Kaggle (CC0 public domain, made available through Mobius), as recommended in the case study brief.

**Tables used**

| Table | Contents |
| --- | --- |
| `daily_activity` | Daily steps, distance, calories and minutes by activity level |
| `hourlySteps` | Steps per hour |
| `minutesSleep` | Sleep records |
| `weightLog` | Weight entries |

I profiled all four tables for row and user counts. The analysis focuses on `daily_activity` and `hourlySteps`, since there were significantly less users that logged their sleep and weight.

**Data credibility (ROCCC)**
- **Reliable / Original:** Collected from real Fitbit devices, but only users who consented to share data.
- **Comprehensive:** Limited. The sample is small and has no demographic information.
- **Current:** The data is from 2016, so habits may have changed.
- **Cited:** Public dataset with a named source.

**Known limitations**
- Small sample (the brief describes 30 users; my tables contain 34 distinct IDs).
- Fitbit devices, not Bellabeat products.
- No demographics, so findings cannot be generalized to Bellabeat's target customers.

---

## 3. Process

**Tools:** Excel for initial review and cleanup (pivot tables, formatted dates, conditional formatting, filtering and removing excess columns) and Google BigQuery (SQL) for profiling, validation and the clean table.

### Step 1: Profile the tables

```sql
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
```

### Step 2: Check for duplicates and nulls

```sql
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
```

### Step 3: Create the clean table

```sql
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
```

### Step 4: Verify the clean table

```sql
-- check the clean table
SELECT
  COUNT(*) AS row_count,
  COUNT(DISTINCT Id) AS users,
  ROUND(AVG(TotalSteps)) AS avg_steps,
  COUNTIF(ActivityDate IS NULL) AS null_dates
FROM `portfolio-509922.bellabeat.daily_clean`;
```

---

## 4. Analyze

### Average steps per weekday

```sql
-- find the average steps per day
SELECT
  weekday_name,
  COUNT(*) AS num_of_days,
  ROUND(AVG(TotalSteps)) AS avg_steps
FROM
  `portfolio-509922.bellabeat.daily_clean`
GROUP BY weekday_name
ORDER BY avg_steps DESC;
```

### Average steps by hour of the day

```sql
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
```

### Minimum and maximum user logs

```sql
-- max and min user logs
SELECT
  Id,
  COUNT(Id) as total_logs
FROM
  `portfolio-509922.bellabeat.daily_clean`
GROUP BY Id
ORDER BY total_logs;
-- found that minimum user logs is 2 and maximum is 32
```

### Wear consistency: user levels

```sql
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
```

### Percentage of users in each level

```sql
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
```

---

## 5. Share

![Dashboard](<Dashboard 1.png>)

| Finding | Detail |
| --- | --- |
| Weekly pattern | Monday (8,204) and Saturday (8,181) are the most active days; Sunday averages 7,150 |
| Tuesday | The lowest average (5,980), noted on the dashboard as likely understated by partial-wear days |
| Daily pattern | Steps peak around midday and 7 PM, dip near 3 PM, and are minimal from late night to 5 AM |
| Wear consistency | Light 15 users (44.12%), Moderate 18 (52.94%), Active 1 (2.94%) |

Groups are based on days with step data: Light = 2 to 11 days, Moderate = 12 to 21, Active = 22 to 32.

---

## 6. Act: Leaf marketing recommendations

1. **Sell Leaf as all-day jewelry.** Most users wear their device inconsistently. Leaf can be worn as a bracelet, necklace or clip and fits any outfit, so marketing should emphasize wearing it every day, not just while exercising.
2. **Time campaigns to the activity peaks.** Concentrate Leaf ads and app messages around midday and early evening, when users are most active and most likely to be engaged with their device.
3. **Pair Leaf with Bellabeat membership.** Offer personalized guidance to re-engage light-wear users, who make up 44% of this sample.

**Next steps**
- Validate findings with Bellabeat's own Leaf data.
- Add demographic data to see whether patterns differ by age or lifestyle.
- Analyze the sleep data to explore Leaf's sleep and stress tracking.

---

## Files

| File | Description |
| --- | --- |
| `bellabeat-proj.sql` | Profiling, validation and cleaning queries |
| `Dashboard 1.png` | Dashboard image |
| `https://public.tableau.com/views/Bellabeat_17923712259800/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link` | Interactive dashboard |

---

*Data: FitBit Fitness Tracker Data (CC0: Public Domain), Mobius, via Kaggle.*
