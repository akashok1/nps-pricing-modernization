SELECT park_name, year, SUM(recreation_visits) as total
FROM visitation
WHERE year BETWEEN 2000 and 2025
GROUP BY park_name, year
HAVING SUM(recreation_visits) > 10000000
ORDER BY SUM(recreation_visits) DESC;

--idk just total visits of parks as CTE 

-- 0) HAVING can have aggregates but WHERE CANNOT
WITH park_stats as (
	SELECT park_name,
			SUM(recreation_visits) as total_visits,
			ROUND(AVG(recreation_visits),1) as monthly_visits,
			COUNT(*) as months_recorded
	FROM visitation
	WHERE year>=2020
	GROUP BY park_name
)
SELECT * FROM park_stats WHERE months_recorded <72;

SELECT park_name, 
       COUNT(*) AS rows_total,
       COUNT(recreation_visits) AS rows_with_visits,
       SUM(recreation_visits) AS total_visits
FROM visitation
WHERE year = 2024
GROUP BY park_name
HAVING COUNT(*) = COUNT(recreation_visits);

-- to check for null values for any column
SELECT COUNT(*) - COUNT(recreation_visits) as null_values
FROM visitation;




--1) GROUP BY (one row per group condition)
SELECT park_name, year, SUM(recreation_visits) as total
FROM visitation
WHERE year=2024
GROUP BY park_name, month
HAVING SUM(recreation_visits) > 10000000
ORDER BY SUM(recreation_visits) DESC;

/* XXXX BIG importance here, even tho below logically it makes sense only 1 region per park_name
postgres denies because as per schema only primary key values i.e (park_name,year,month) provides unique values
everything else will be denied. if someone tries to add yosemite to multiple, database will allow it */
SELECT park_name, region, SUM(recreation_visits)
FROM visitation
WHERE year >= 2020
GROUP BY park_name;

-- does NOT work because after GROUP BY filters park_name, year there's no month to sort through for ORDER BY
SELECT park_name, year, AVG(recreation_visits)
FROM visitation
GROUP BY park_name, year
ORDER BY month;



-- 2) JOINS 

-- default JOIN is inner join
SELECT v.park_name, v.recreation_visits, vse.jobs_supported
FROM visitation v
JOIN vse vse ON v.park_name = vse.park_name
WHERE vse.jobs_supported <50;
--GROUP BY v.park_name, v.recreation_visits;

SELECT DISTINCT v.park_name, f.entrance_fee
FROM visitation v
INNER JOIN fees f ON v.park_name = f.park_name
ORDER BY f.entrance_fee;

SELECT v.park_name, f.entrance_fee
FROM visitation v
INNER JOIN fees f ON v.park_name = f.park_name
ORDER BY f.entrance_fee;

-- when doing joins, ensure left join has same count as normal count on table else the join key has duplicates
-- here join key is primary key so duplicates aren't an issue (both 193696 rows)
SELECT COUNT(*) FROM visitation;
SELECT COUNT(*) FROM fees;
SELECT COUNT(*) FROM visitation v LEFT JOIN fees f ON v.park_name = f.park_name;

--LEFT JOIN & RIGHT JOIN
-- keeps all rows from left/right of JOIN keyword, gives value for column where it matches and NULL for where it doesn't
SELECT v.park_name, v.year, v.recreation_visits, f.entrance_fee
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
WHERE v.year = 2024;


SELECT v.park_name
FROM visitation v
LEFT JOIN fees f ON f.park_name = v.park_name
WHERE year=1980;				--condition on left table i.e visitation

SELECT COUNT(*)
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
WHERE year =1980;		

-- multiple joins

SELECT v.park_name, v.year, f.entrance_fee, SUM(v.recreation_visits) as visits, vse.visitor_spending, SUM(v.recreation_visits)*f.entrance_fee AS revenue
FROM visitation v
INNER JOIN fees f ON v.park_name = f.park_name
INNER JOIN vse ON v.park_name = vse.park_name
				AND v.year = vse.year
WHERE v.year BETWEEN 2020 AND 2025
GROUP BY v.park_name, v.year, f.entrance_fee, vse.visitor_spending
ORDER BY vse.visitor_spending DESC;

SELECT v.park_name,v.year,SUM(v.recreation_visits) AS visits,f.entrance_fee,
       vse.visitor_spending
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
LEFT JOIN vse  ON v.park_name = vse.park_name
				AND v.year = vse.year
WHERE v.year=2024
GROUP BY v.park_name, v.year, f.entrance_fee, vse.visitor_spending
ORDER BY visits DESC;

SELECT *
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
LEFT JOIN vse  ON v.park_name = vse.park_name
WHERE v.year=2024;

-- Filter applied DURING join. Free parks still show (with NULL fee)
SELECT distinct v.park_name, f.entrance_fee
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name 
                AND f.entrance_fee >= 20;

-- Filter applied AFTER join. Free parks dropped because NULL > 30 is NULL
SELECT v.park_name, f.entrance_fee
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
WHERE f.entrance_fee > 30;

SELECT v.park_name,
v.year,
       SUM(v.recreation_visits) AS total_visits,
       f.entrance_fee,
       f.fee_type,
       f.per_person_fee
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
WHERE v.year BETWEEN 2020 AND 2024
GROUP BY v.park_name, f.entrance_fee, f.fee_type, f.per_person_fee,v.year
ORDER BY total_visits DESC
LIMIT 20;


SELECT f.park_name, f.entrance_fee, vse.visitor_spending
FROM fees f
LEFT JOIN vse ON f.park_name = vse.park_name AND vse.year=2024;



-- 1) Find parks in visitation with NO fee record (find orphans pattern)
SELECT DISTINCT v.park_name, f.entrance_fee
FROM visitation v
LEFT JOIN fees f ON v.park_name=f.park_name
WHERE f.park_name is NULL;
-- LEFT JOIN, then WHERE right_table.key IS NULL = "left rows that don't match." 
-- Memorize this pattern, it's everywhere in interview problems and data quality work.


-- 2) 20 parks by 2020-2024 visits with fee info
SELECT v.park_name, SUM(v.recreation_visits) as visits, f.entrance_fee, f.fee_type, f.per_person_fee
FROM visitation v
LEFT JOIN fees f ON v.park_name= f.park_name 
WHERE year BETWEEN 2020 and 2024
GROUP BY v.park_name, f.entrance_fee, f.fee_type, f.per_person_fee
ORDER BY visits DESC
LIMIT 20;

-- TRIPLE join with CTE to see top 30 economic output parks from 2020 to 2024
WITH yearly_visits AS (
    SELECT park_name, year, SUM(recreation_visits) AS visits
    FROM visitation
    WHERE year BETWEEN 2020 AND 2024
    GROUP BY park_name, year
)
SELECT yv.park_name, 
       yv.year, 
       yv.visits,
       f.per_person_fee,
       yv.visits * COALESCE(f.per_person_fee, 0) AS est_entrance_rev,
       vse.visitor_spending,
       vse.economic_output,
       vse.jobs_supported
FROM yearly_visits yv
LEFT JOIN fees f ON yv.park_name = f.park_name
LEFT JOIN vse   ON yv.park_name = vse.park_name 
              AND yv.year = vse.year
ORDER BY est_entrance_rev DESC NULLS LAST	-- defualt for DESC is NULLS first
LIMIT 30;

--getting region/state wise split of visits and 
SELECT v.park_name, ROUND(SUM(v.recreation_visits)) as visits, ROUND(SUM(vse.jobs_supported)) as no_of_jobs
FROM visitation v 
LEFT JOIN vse ON v.park_name = vse.park_name
				AND v.year = vse.year
WHERE v.year BETWEEN 2020 and 2024 and v.state ='SD'
GROUP BY v.park_name
ORDER BY visits DESC;


-- find pairs of parks in the same state where one had way more 2024 visits than another.
WITH park_visits_2024 as (
	SELECT park_name, state, SUM(recreation_visits) as visits
	FROM visitation
	WHERE year = 2024
	GROUP BY park_name, state
)
SELECT a.state, 
	   b.park_name as big_park, b.visits as more_visits,
	   a.park_name as small_park, a.visits as less_visits,
	   ROUND((b.visits/a.visits)) as ratio
	   --ROUND((b.visits / NULLIF(a.visits, 0))::numeric, 1) AS ratio
FROM park_visits_2024 a
INNER JOIN park_visits_2024 b ON a.state = b.state
	       AND b.visits > a.visits * 10 
		   AND a.visits > 50000
ORDER BY ratio DESC;


-- SELF JOIN lesser fine query than above
WITH park_2024 AS (
    SELECT park_name, state, SUM(recreation_visits) AS visits
    FROM visitation 
    WHERE year = 2024 
    GROUP BY park_name, state
)
SELECT a.park_name AS smaller_park,
       b.park_name AS bigger_park,
       a.state,
       a.visits AS smaller_visits,
       b.visits AS bigger_visits
FROM park_2024 a
JOIN park_2024 b ON a.state = b.state 
ORDER BY a.state, bigger_visits DESC;
                AND b.visits > a.visits * 5

-- parks that account for more than 50% of their state's visits
WITH park_visit AS(
	SELECT park_name, state, SUM(recreation_visits) as park_visits
	FROM visitation
	GROUP BY park_name, state
),
state_visits AS(
	SELECT state, SUM(recreation_visits) as state_visits
	FROM visitation
	GROUP BY state
),
combined AS(
	SELECT pv.park_name, pv.state, park_visits, state_visits,
	   	   ROUND((park_visits/state_visits)*100) as pct_state
	FROM park_visit as pv 
	LEFT JOIN state_visits sv ON pv.state = sv.state
)
SELECT *
FROM combined
WHERE pct_state > 50
ORDER BY pct_state DESC;

SELECT COUNT(*) as numb, state, SUM(recreation_visits)
FROM visitation
WHERE year = 2024
GROUP BY state
ORDER BY numb

-- number of parks in each state in 2024
WITH parks AS(
	SELECT DISTINCT park_name, state
	FROM visitation
	WHERE year = 2024
)
SELECT COUNT(park_name) as numb_parks, state
FROM parks
GROUP BY state
ORDER BY numb_parks DESC;




-- CASE WHEN

-- giving parks a tier based on traffic and finding how many in each tier
WITH park_tier AS(
	SELECT park_name, SUM(recreation_visits) as visits,
	   CASE
	   		WHEN SUM(recreation_visits) > 5000000 THEN 'Heavy traffic'
			WHEN SUM(recreation_visits) > 1000000 THEN 'High traffic'
			WHEN SUM(recreation_visits) > 100000 THEN 'Medium traffic'
			WHEN SUM(recreation_visits) > 10000 THEN 'Low traffic'
			ELSE 'Minimal'
	   END AS traffic_tier
	FROM visitation
	WHERE year = 2024
	GROUP BY park_name
)
SELECT traffic_tier, COUNT(park_name)
FROM park_tier
GROUP BY traffic_tier;

-- Conditional aggregation
-- number of paid, free, exp parks in each region in 2024
SELECT region,
		COUNT(*) AS total_parks,
		COUNT(CASE WHEN entrance_fee > 0 THEN 1 END) as paid_parks,
		COUNT(CASE WHEN entrance_fee = 0 OR entrance_fee IS NULL THEN 1 END) as free_parks,
		COUNT(CASE WHEN entrance_fee > 20 THEN 1 END) as expensive_parks,
		ROUND(AVG(CASE WHEN entrance_fee > 0 THEN entrance_fee END)) as avg_fee_only_paid_parks
FROM visitation v
LEFT JOIN fees f ON v.park_name = f.park_name
WHERE year = 2024
GROUP BY region;

--above gives including months (x12 for each park year) so not accurate, bwlow doesn't 
WITH 
park_2024 AS (
    SELECT DISTINCT v.park_name, v.region, f.entrance_fee
    FROM visitation v
    LEFT JOIN fees f ON v.park_name = f.park_name
    WHERE v.year = 2024
),
high_traffic_parks AS (
    SELECT park_name
    FROM visitation
    WHERE year = 2024
    GROUP BY park_name
    HAVING SUM(recreation_visits) > 1000000
)
SELECT p.region,
       COUNT(*) AS total_parks,
       COUNT(CASE WHEN ht.park_name IS NOT NULL THEN 1 END) AS high_traffic_parks,
       COUNT(CASE WHEN p.entrance_fee IS NULL AND ht.park_name IS NOT NULL THEN 1 END) AS free_high_traffic
FROM park_2024 p
LEFT JOIN high_traffic_parks ht ON p.park_name = ht.park_name
GROUP BY p.region
ORDER BY free_high_traffic DESC;
		
--  Inside ORDER BY (custom sort)
-- Sort by your own logic instead of a column's natural order.
SELECT park_name, entrance_fee
FROM fees
ORDER BY 
    CASE 
        WHEN entrance_fee > 20 THEN 1
        WHEN entrance_fee > 15 THEN 2
        WHEN entrance_fee > 0  THEN 3
        ELSE 4
    END,
	park_name;


-- Cross - tabulation (pivot tables in SQL)
-- years as columns instead of row
SELECT park_name,
		SUM(CASE WHEN year = 2020 THEN recreation_visits END) as visits_2020,
		SUM(CASE WHEN year = 2021 THEN recreation_visits END) as visits_2021,
		SUM(CASE WHEN year = 2022 THEN recreation_visits END) as visits_2022,
		SUM(CASE WHEN year = 2023 THEN recreation_visits END) as visits_2023,
		SUM(CASE WHEN year = 2024 THEN recreation_visits END) as visits_2024
FROM visitation
WHERE year BETWEEN 2020 AND 2024
GROUP BY park_name
ORDER BY visits_2024 DESC NULLS LAST;


-- categorizing parks by relationship between fee and traffic
WITH park_visits AS(
	SELECT park_name, SUM(recreation_visits) as visits
	FROM visitation
	WHERE year BETWEEN 2020 AND 2024
	GROUP BY park_name
),
park_traffic AS (
	SELECT park_name, visits,
		CASE
			WHEN visits > 30000000 THEN 'Heavy Traffic'
			WHEN visits > 15000000 THEN 'High Traffic'
			WHEN SUM(visits) > 7500000 THEN 'Medium Traffic'
			WHEN SUM(visits) > 3000000 THEN 'Low Traffic'
			ELSE 'Minimal Traffic'
		END AS visit_traffic
	FROM park_visits
	GROUP BY park_name,visits
)
SELECT pt.park_name, entrance_fee, visits, visit_traffic,
	CASE
		WHEN entrance_fee IS NULL AND visit_traffic  IN ('Heavy Traffic', 'High Traffic') THEN 'free + traffic'
		WHEN entrance_fee IS NOT NULL AND visit_traffic ='Heavy Traffic' THEN 'paid + traffic'
		WHEN entrance_fee IS NOT NULL AND visit_traffic ='Minimal Traffic' THEN 'paid + min traffic'
		WHEN entrance_fee IS NOT NULL AND visit_traffic IN ('Low Traffic','Minimal Traffic') THEN 'free + low traffic'
		ELSE 'reasonable'
	END AS behaviour
FROM park_traffic pt
LEFT JOIN fees f ON pt.park_name = f.park_name
ORDER BY 
	CASE 
		WHEN visit_traffic = 'Heavy Traffic' THEN 1
		WHEN visit_traffic = 'High Traffic' THEN 2
		WHEN visit_traffic = 'Medium Traffic' THEN 3
		WHEN visit_traffic = 'Low Traffic' THEN 4
		WHEN visit_traffic = 'Minimal Traffic' THEN 5
	END,
	entrance_fee DESC NULLS LAST;

-- simpler way claude gave to do it
-- but the view in order by is different than how i want (nulls are in between if visits order is maintained strict desc order)
WITH park_data AS (
    SELECT v.park_name,
           SUM(v.recreation_visits) AS visits,
           f.entrance_fee
    FROM visitation v
    LEFT JOIN fees f ON v.park_name = f.park_name
    WHERE v.year BETWEEN 2020 AND 2024
    GROUP BY v.park_name, f.entrance_fee
)
SELECT park_name,
       visits,
       entrance_fee,
       CASE
           WHEN visits > 30000000 THEN 'Heavy Traffic'
           WHEN visits > 15000000 THEN 'High Traffic'
           WHEN visits > 7500000  THEN 'Medium Traffic'
           WHEN visits > 3000000  THEN 'Low Traffic'
           ELSE 'Minimal Traffic'
       END AS visit_traffic,
       CASE
           WHEN entrance_fee IS NULL AND visits > 15000000 THEN 'free + traffic'
           WHEN entrance_fee IS NOT NULL AND visits > 30000000 THEN 'paid + traffic'
           WHEN entrance_fee IS NOT NULL AND visits <= 3000000 THEN 'paid + low traffic'
           ELSE 'reasonable'
       END AS behaviour
FROM park_data
ORDER BY visits DESC;


-- WINDOW FUNCTIONS
-- RANK() top 5 paid parks for visitation in each region 
WITH ranked AS(
	SELECT region, v.park_name, SUM(recreation_visits) as visits,entrance_fee,
	RANK() OVER (PARTITION  BY region ORDER BY SUM(recreation_visits) DESC) as rnk
	FROM visitation v
	LEFT JOIN fees f ON v.park_name = f.park_name
	WHERE entrance_fee IS NOT NULL
	--WHERE year BETWEEN 2020 AND 2024
	GROUP BY region,v.park_name, entrance_fee
)
SELECT * 
FROM ranked
WHERE rnk <=5
ORDER BY region;

-- LAG and LEAD
-- Look at previous/next row's value within a window. Year-over-year change is the textbook use case:
WITH yearly AS (
    SELECT park_name, year, SUM(recreation_visits) AS visits
    FROM visitation
    WHERE year BETWEEN 2018 AND 2024
    GROUP BY park_name, year
)
SELECT park_name, year, visits,
	LAG(visits) OVER (PARTITION BY park_name ORDER BY year) as prev_year_visits,
	visits - LAG(visits) OVER (PARTITION BY park_name ORDER BY year) as yoy_change,
	ROUND(((visits - LAG(visits) OVER (PARTITION BY park_name ORDER BY year))::numeric 
              / NULLIF(LAG(visits) OVER (PARTITION BY park_name ORDER BY year), 0) * 100), 1) AS yoy_pct
FROM yearly
GROUP BY park_name, year, visits;


--Running totals and moving averages

SELECT park_name, year,
       SUM(recreation_visits) AS yearly_visits,
       SUM(SUM(recreation_visits)) OVER (PARTITION BY park_name ORDER BY year) as cum_visits,			-- to find cumulative over park_name in the order of year
       ROUND(AVG(SUM(recreation_visits)) OVER (PARTITION BY park_name ORDER BY year 
                                          ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS rolling_3yr_avg
FROM visitation
WHERE year BETWEEN 2018 AND 2024
GROUP BY park_name, year
ORDER BY park_name, year;

/* NTILE for bucketing
NTILE(n) divides rows into n equal buckets. 
Replaces your manual CASE WHEN tiers when you want statistical buckets */
SELECT park_name, visits,
       NTILE(5) OVER (ORDER BY visits DESC) AS visit_quintile
FROM (SELECT park_name, SUM(recreation_visits) AS visits 
      FROM visitation WHERE year BETWEEN 2020 AND 2024 GROUP BY park_name) sub;


-- AGGREGATES SUM, AVG, COUNT, MIN, MAX as window functions
WITH park_visits AS(
	SELECT park_name,region, SUM(recreation_visits) as visits
	FROM visitation
	WHERE year BETWEEN 2020 and 2024
	GROUP BY park_name, region
)
SELECT region, park_name, visits,
		ROUND(AVG(visits) OVER (PARTITION BY region)) AS avg_visits,
		ROUND(visits - AVG(visits) OVER (PARTITION BY region)) AS diff_from_avg,
		ROUND(visits / SUM(visits) OVER (PARTITION BY region) * 100,2) AS pct_of_region
FROM park_visits
GROUP BY region, park_name,visits;

SELECT year from vse group by year


WITH park_year AS (
SELECT park_name, year, SUM(recreation_visits) as visits
FROM visitation
WHERE park_name = 'Washington Monument'
GROUP BY park_name, year
)
SELECT park_name, year, visits,
	ROUND(AVG(visits) OVER (PARTITION BY park_name)) AS avg_visits
FROM park_year
GROUP BY park_name, visits, year
ORDER BY year;

SELECT park_name, year, SUM(recreation_visits) as visits
FROM visitation
WHERE park_name = 'Washington Monument'
GROUP BY park_name, year
ORDER BY year;




-- CLAUDE ITERATION 1 FOR PROJECT QUERIES USING VIEWS

-- Annual visitation aggregated from monthly + period flag for COVID handling
CREATE OR REPLACE VIEW vw_visitation_annual AS
SELECT 
    park_name,
    park_type,
    region,
    state,
    year,
    SUM(recreation_visits) AS annual_visits,
    CASE 
        WHEN year BETWEEN 2017 AND 2019 THEN 'pre_covid'
        WHEN year BETWEEN 2020 AND 2021 THEN 'covid'
        WHEN year BETWEEN 2022 AND 2024 THEN 'post_covid'
        ELSE 'other'
    END AS period
FROM visitation
WHERE year BETWEEN 2017 AND 2024
GROUP BY park_name, park_type, region, state, year;

-- test it
SELECT * FROM vw_visitation_annual WHERE park_name = 'Yellowstone NP' ORDER BY year;

CREATE OR REPLACE VIEW vw_park_economics AS
SELECT 
    v.park_name,
    v.park_type,
    v.region,
    v.state,
    v.year,
    v.period,
    v.annual_visits,
    vse.visitor_spending,
    vse.jobs_supported,
    vse.economic_output,
    f.entrance_fee,
    f.fee_type,
    f.per_person_fee,
    -- revenue proxy: only meaningful for fee-charging parks
    CASE 
        WHEN f.per_person_fee IS NOT NULL 
        THEN v.annual_visits * f.per_person_fee 
        ELSE NULL 
    END AS estimated_fee_revenue,
    -- spending per visitor: efficiency metric
    CASE 
        WHEN v.annual_visits > 0 
        THEN vse.visitor_spending / v.annual_visits 
        ELSE NULL 
    END AS spending_per_visitor
FROM vw_visitation_annual v
LEFT JOIN vse 
    ON v.park_name = vse.park_name AND v.year = vse.year
LEFT JOIN fees f 
    ON v.park_name = f.park_name;

-- test
SELECT * FROM vw_park_economics 
WHERE park_name IN ('Acadia NP', 'Yellowstone NP', 'Zion NP') 
ORDER BY park_name, year;

WITH period_avg AS (
    SELECT 
        park_name,
        period,
        AVG(annual_visits) AS avg_visits,
        AVG(visitor_spending) AS avg_spending
    FROM vw_park_economics
    WHERE period IN ('pre_covid', 'post_covid')
    GROUP BY park_name, period
),
pivoted AS (
    SELECT 
        park_name,
        MAX(CASE WHEN period = 'pre_covid' THEN avg_visits END) AS pre_covid_visits,
        MAX(CASE WHEN period = 'post_covid' THEN avg_visits END) AS post_covid_visits,
        MAX(CASE WHEN period = 'pre_covid' THEN avg_spending END) AS pre_covid_spending,
        MAX(CASE WHEN period = 'post_covid' THEN avg_spending END) AS post_covid_spending
    FROM period_avg
    GROUP BY park_name
)
SELECT 
    park_name,
    pre_covid_visits,
    post_covid_visits,
    ROUND((post_covid_visits / NULLIF(pre_covid_visits, 0))::numeric, 2) AS visit_recovery_ratio,
    ROUND((post_covid_spending / NULLIF(pre_covid_spending, 0))::numeric, 2) AS spending_recovery_ratio
FROM pivoted
WHERE pre_covid_visits > 50000  -- ignore parks too small to be meaningful
ORDER BY visit_recovery_ratio ASC
LIMIT 20;

SELECT 
    park_name,
    state,
    region,
    AVG(spending_per_visitor) AS avg_spending_per_visitor,
    AVG(annual_visits) AS avg_annual_visits
FROM vw_park_economics
WHERE period = 'post_covid'
  AND annual_visits > 50000
GROUP BY park_name, state, region
ORDER BY avg_spending_per_visitor DESC
LIMIT 20;


-- THIS IS WRONG LOGIC (tryna find parks grew per year finding which affected by covid level)
-- this just shows relative levels of growth from previous year, baseline is inconsistent
--2021 has 2020 which is much lower so not representative
WITH parks_view AS ( 
	SELECT park_name, year, SUM(recreation_visits) as visits
	FROM visitation
	WHERE year BETWEEN 2017 AND 2024
	GROUP BY park_name, year
),
diff_parks AS(
	SELECT park_name, year, visits,
	visits - LAG(visits) OVER (PARTITION BY park_name ORDER BY year) as diff_prev_visits
	FROM parks_view
)
SELECT year,
	COUNT(*) as total_parks
FROM diff_parks
WHERE diff_prev_visits >0
GROUP BY year
ORDER BY year;


-- THIS IS CORRECT, has 2019 as baseline and the rest are clauclated with that
WITH yearly AS (
    SELECT park_name, year, SUM(recreation_visits) AS visits
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, year
),
with_baseline AS (
    SELECT park_name, year, visits,
           MAX(CASE WHEN year = 2019 THEN visits END) OVER (PARTITION BY park_name) AS visits_2019
    FROM yearly
)
SELECT year,
       COUNT(*) AS total_parks,
       COUNT(CASE WHEN visits >= visits_2019 THEN 1 END) AS parks_at_or_above_2019,
       COUNT(CASE WHEN visits < visits_2019 * 0.8 THEN 1 END) AS parks_below_80pct_of_2019,
       ROUND(AVG((visits / NULLIF(visits_2019, 0) * 100))::numeric, 1) AS avg_pct_of_2019
FROM with_baseline
WHERE year >= 2020
GROUP BY year
ORDER BY year;