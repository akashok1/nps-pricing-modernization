/* NPS Pricing Modernization Analysis: Exploratory and analytical queries

 Purpose: Document the analytical journey from raw data to cluster
 identification. Each block answers a specific business question.
 
 Inputs: Raw tables created in 01_create_tables.sql & 02_load_data
 1) visitation: monthly recreation visits 1979-2024 (193,696 rows)
 2) fees: per-park entrance fee data (104 rows)
 3) vse: NPS Visitor Spending Effects 2017-2024 (3,082 rows)
*/

SELECT * FROM visitation;
SELECT * FROM fees;
SELECT * FROM vse;

-- Part 1: Visitation patterns

-- 1.1 NPS system-wide visitation trend, full historical record
SELECT year,
       ROUND((SUM(recreation_visits) / 1000000.0):: numeric, 2) AS total_visits_million
FROM visitation
GROUP BY year
ORDER BY year;


-- 2.2 Park type distribution by total 8-year visitation
SELECT park_type,
       COUNT(DISTINCT park_name) AS unit_count,
       SUM(recreation_visits) AS total_visits_8yr
FROM visitation
WHERE year BETWEEN 2017 AND 2024
GROUP BY park_type
ORDER BY total_visits_8yr DESC;

-- 2.3 Top 25 parks by 8-year total visitation
SELECT park_name, park_type, state,
       SUM(recreation_visits) AS total_visits_8yr
FROM visitation
WHERE year BETWEEN 2017 AND 2024
GROUP BY park_name, park_type, state
ORDER BY total_visits_8yr DESC
LIMIT 25;

-- 2.4 Traffic tier distribution
WITH park_visits as(
	SELECT park_name, year, SUM(recreation_visits) as visits
	FROM visitation
	WHERE year BETWEEN 2017 and 2024
	GROUP BY park_name, year
)
SELECT park_name, SUM(visits) as total_visits_8yr, ROUND(AVG(visits)) as avg_visits_8yr,
	CASE
		WHEN AVG(visits) > 3000000 THEN 'Major (>3M/yr)'
       	WHEN AVG(visits) > 1000000 THEN 'Significant (1M-3M/yr)'
       	WHEN AVG(visits) > 100000  THEN 'Moderate (100K-1M/yr)'
       	ELSE 'Low (<100K/yr)'
   	END AS traffic_tier
FROM park_visits
GROUP BY park_name
ORDER BY avg_visits_8yr DESC;


-- 2.5 Count of parks in each traffic tier
WITH park_visits as(
	SELECT park_name, year, SUM(recreation_visits) as visits
	FROM visitation
	WHERE year BETWEEN 2017 and 2024
	GROUP BY park_name, year
),
parks_avg AS (
	SELECT park_name, SUM(visits) as total_visits_8yr, ROUND(AVG(visits)) as avg_visits_8yr,
		CASE
			WHEN AVG(visits) > 3000000 THEN 'Major (>3M/yr)'
       		WHEN AVG(visits) > 1000000 THEN 'Significant (1M-3M/yr)'
       		WHEN AVG(visits) > 100000  THEN 'Moderate (100K-1M/yr)'
       		ELSE 'Low (<100K/yr)'
   		END AS traffic_tier
	FROM park_visits
	GROUP BY park_name
)
SELECT COUNT(*) AS park_count, traffic_tier
FROM parks_avg
GROUP BY traffic_tier
ORDER BY traffic_tier;


-- 2.5 Pre-COVID (2017-2019) vs Post-COVID (2022-2024) visitation by park name/park types
-- Demonstrates which park names/types are growing post-pandemic
SELECT park_name,
	SUM(CASE WHEN year BETWEEN 2017 and 2019 THEN recreation_visits END) as total_pre_covid_visits,
	SUM(CASE WHEN year BETWEEN 2022 and 2024 THEN recreation_visits END) as total_post_covid_visits,
	ROUND(AVG(CASE WHEN year BETWEEN 2017 and 2019 THEN recreation_visits END)) as avg_pre_covid_visits,
	ROUND(AVG(CASE WHEN year BETWEEN 2022 and 2024 THEN recreation_visits END)) as avg_post_covid_visits,
	ROUND(AVG(CASE WHEN year BETWEEN 2022 and 2024 THEN recreation_visits END)
		/NULLIF(AVG(CASE WHEN year BETWEEN 2017 and 2019 THEN recreation_visits END),0)::numeric,2) as recovery_index
FROM visitation
WHERE year BETWEEN 2017 and 2024
GROUP BY park_name
ORDER BY recovery_index DESC NULLS LAST;


-- PART 3: Fee structure analysis

-- 3.1 Fee tier distribution
SELECT
    CASE
        WHEN per_person_fee IS NULL OR per_person_fee = 0 THEN '$0 (free)'
        WHEN per_person_fee < 10  THEN '$1-9'
        WHEN per_person_fee < 15  THEN '$10-14'
        WHEN per_person_fee < 20  THEN '$15-19'
        ELSE '$20+'
    END AS fee_tier,
    COUNT(*) AS park_count
FROM fees
GROUP BY fee_tier
ORDER BY fee_tier;


-- 3.2 Identifying highest-traffic free parks for revenue generation opportunities
WITH park_visits AS (
	SELECT v.park_name, park_type, year, entrance_fee, SUM(recreation_visits) as visits
	FROM visitation v
	LEFT JOIN fees f ON v.park_name = f.park_name
	WHERE year BETWEEN 2017 AND 2024
	GROUP BY v.park_name, park_type, year, entrance_fee
)
SELECT park_name, park_type, entrance_fee, ROUND(AVG(visits)) as avg_visits
FROM park_visits
WHERE entrance_fee IS NULL
GROUP BY park_name, entrance_fee, park_type
ORDER BY avg_visits DESC;


-- 3.3 Identify the 2026 EO (Executive order) 14314 surcharge parks in our data
-- (Per executive order: 11 flagship parks but in our data structure
--  Sequoia and Kings Canyon are split as separate units = 12 NPS units)

-- Potential revenue generated from $100 surcharge assuming 10% non residents visit each year
WITH park_visits AS (
	SELECT DISTINCT f.park_name, v.park_type, f.state,
       per_person_fee, year, SUM(recreation_visits) as visits
	FROM visitation v
	LEFT JOIN fees f ON v.park_name = f.park_name
	WHERE f.park_name IN (
    	'Grand Canyon NP', 'Yellowstone NP', 'Yosemite NP', 'Zion NP',
    	'Acadia NP', 'Grand Teton NP', 'Glacier NP', 'Bryce Canyon NP',
    	'Sequoia NP', 'Kings Canyon NP', 'Rocky Mountain NP',
    	'Everglades NP'
	)
	GROUP BY f.park_name, v.park_type,f.state, per_person_fee,year
)
SELECT park_name, park_type, state, per_person_fee, ROUND(AVG(visits)) as avg_visits_yr,
	ROUND(AVG(visits) * 0.1 * (per_person_fee+100)) AS revenue_generated_yr
FROM park_visits
GROUP BY park_name, park_type, state, per_person_fee;


-- PART 4: Visitor Spending Effects (VSE) analysis (2017-2024)
-- 4.1 Top 25 parks by 8-year cumulative visitor spending
SELECT park_name, SUM(recreation_visits),
       SUM(visitor_spending) AS total_spending_8yr,
       ROUND(SUM(visitor_spending) / NULLIF(SUM(recreation_visits), 0)::numeric ,2) AS avg_spending_per_visit
FROM vse
WHERE year BETWEEN 2017 AND 2024
GROUP BY park_name
ORDER BY total_spending_8yr DESC
LIMIT 25;


-- 4.2 Spending per visit distribution
WITH park_spv AS (
    SELECT park_name,
            ROUND(SUM(visitor_spending) / NULLIF(SUM(recreation_visits), 0)::numeric ,2) AS avg_spending_per_visit
    FROM vse
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name
)
SELECT
    CASE
        WHEN avg_spending_per_visit < 30  THEN '$0-29 (urban trip)'
        WHEN avg_spending_per_visit < 60  THEN '$30-59 (day trip)'
        WHEN avg_spending_per_visit < 100 THEN '$60-99 (destination)'
        WHEN avg_spending_per_visit < 150 THEN '$100-149 (high-end)'
        ELSE '$150+ (premium)'
    END AS spending_tier,
    COUNT(*) AS park_count,
    ROUND(AVG(avg_spending_per_visit),2) AS avg_spv_in_tier
FROM park_spv
WHERE avg_spending_per_visit IS NOT NULL
GROUP BY spending_tier
ORDER BY spending_tier;


-- 4.3 Economic impact concentration: what share of total visitor
-- spending comes from the top 10% of parks?
WITH park_total AS (
    SELECT park_name,
           SUM(visitor_spending) AS total_spending_8yr,
           NTILE(10) OVER (ORDER BY SUM(visitor_spending) DESC) AS decile --NTILE(10) dividing table rows into 10 groups
    FROM vse
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name
)
SELECT decile,
       COUNT(*) AS park_count,
       ROUND(SUM(total_spending_8yr)),
       ROUND((SUM(total_spending_8yr)::numeric
            / SUM(SUM(total_spending_8yr)) OVER()) * 100, 2) AS pct_of_system
FROM park_total
GROUP BY decile
ORDER BY decile;



-- PART 5: Cluster identification i.e most useful parks for us

-- 5.1 Initial candidate cluster: free parks with >1M avg annual visits
-- reduce grain wiht each CTE month -> year -> park/region
WITH yearly_visits AS (
    SELECT park_name, park_type, state, region, year,
           SUM(recreation_visits) AS annual_visits
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, park_type, state, region, year
),
park_visit_avgs AS (
    SELECT park_name, park_type, state, region,
           ROUND(AVG(annual_visits)) AS avg_annual_visits
    FROM yearly_visits
    GROUP BY park_name, park_type, state, region
),
park_spending AS (
    SELECT park_name,
           ROUND(SUM(visitor_spending)::numeric
                 / NULLIF(SUM(recreation_visits), 0), 2) AS spending_per_visit
    FROM vse
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name
)
SELECT pv.park_name, pv.park_type, pv.state, pv.region,
       pv.avg_annual_visits,
       ps.spending_per_visit,
       COALESCE(f.per_person_fee, 0) AS current_fee
FROM park_visit_avgs pv
LEFT JOIN park_spending ps ON pv.park_name = ps.park_name
LEFT JOIN fees f ON pv.park_name = f.park_name
WHERE COALESCE(f.per_person_fee, 0) = 0
  AND pv.avg_annual_visits >= 1000000
ORDER BY pv.avg_annual_visits DESC;


-- AFter some digging around, there are conditions and legalalities preventing fee collection in some parks :(

-- View 1: Park-level metrics from base tables
-- One row per park with visit averages, spending, and fee data (always use REPLACE)
CREATE OR REPLACE VIEW park_metrics AS
WITH yearly_visits AS (
    SELECT park_name, park_type, state, region, year,
           SUM(recreation_visits) AS annual_visits
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, park_type, state, region, year
),
park_visit_avgs AS (
    SELECT park_name, park_type, state, region,
           ROUND(AVG(annual_visits)) AS avg_annual_visits
    FROM yearly_visits
    GROUP BY park_name, park_type, state, region
),
park_spending AS (
    SELECT park_name,
           ROUND(SUM(visitor_spending)::numeric
                 / NULLIF(SUM(recreation_visits), 0), 2) AS spending_per_visit
    FROM vse
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name
)
SELECT pv.park_name,
       pv.park_type,
       pv.state,
       pv.region,
       pv.avg_annual_visits,
       ps.spending_per_visit,
       COALESCE(f.per_person_fee, 0) AS per_person_fee,
       CASE WHEN pv.park_name IN (
           'Acadia NP','Bryce Canyon NP','Everglades NP','Glacier NP',
           'Grand Canyon NP','Grand Teton NP','Rocky Mountain NP',
           'Sequoia NP','Kings Canyon NP','Yellowstone NP',
           'Yosemite NP','Zion NP'
       ) THEN 1 ELSE 0 END AS is_2026_surcharge_park
FROM park_visit_avgs pv
LEFT JOIN fees f ON pv.park_name = f.park_name
LEFT JOIN park_spending ps ON pv.park_name = ps.park_name;


-- View 2: Candidate cluster (the 24 fee-eligible parks)
-- Free + >1M visits + not memorial/parkway/urban NRA + not Smoky
-- Includes cluster_tier classification
CREATE OR REPLACE VIEW candidate_parks AS
SELECT park_name,
       park_type,
       state,
       region,
       avg_annual_visits,
       spending_per_visit,
       per_person_fee,
       CASE
           WHEN park_type IN (
               'National Park','National Seashore','National Preserve',
               'National River','National Scenic Riverway',
               'National Park & Preserve'
           ) THEN 'Tier 1'
           ELSE 'Tier 2'
       END AS cluster_tier
FROM park_metrics
WHERE per_person_fee = 0
  AND avg_annual_visits >= 1000000
  AND park_name NOT ILIKE '%MEM%'
  AND park_name NOT ILIKE '%Memorial%'
  AND park_name NOT ILIKE '%PKWY%'
  AND park_name NOT ILIKE '%Parkway%'
  AND park_name NOT IN (
      'Golden Gate NRA','Gateway NRA','Boston Harbor Islands NRA',
	  'Castle Clinton NM','Independence NHP'
  )
  AND park_name <> 'Great Smoky Mountains NP';




-- 5.2 Apply fee-eligibility filter to identify candidate parks
-- Excludes 17 units: memorials (statutory/practice), parkways (deed restrictions/diffuse access)
-- urban NRAs (uncontrolled access). See README for full classification rationale.
WITH yearly_visits AS (
    SELECT park_name, park_type, state, year,
           SUM(recreation_visits) AS annual_visits
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, park_type, state, year
),
park_visit_avgs AS (
    SELECT park_name, park_type, state,
           ROUND(AVG(annual_visits)) AS avg_annual_visits
    FROM yearly_visits
    GROUP BY park_name, park_type, state
)
SELECT pv.park_name, pv.park_type, pv.state,
       pv.avg_annual_visits,
       CASE
           WHEN pv.park_name ILIKE '%MEM%' OR pv.park_name ILIKE '%Memorial%'
               THEN 'Excluded: Memorial (practice/statutory)'
           WHEN pv.park_name ILIKE '%PKWY%' OR pv.park_name ILIKE '%Parkway%'
               THEN 'Excluded: Parkway (deed restriction/diffuse access)'
           WHEN pv.park_name IN (
                   'Golden Gate NRA', 'Gateway NRA',
                   'Boston Harbor Islands NRA', 'Castle Clinton NM',
                   'Independence NHP'
               )
               THEN 'Excluded: Urban NRA (uncontrolled access)'
           ELSE 'Fee-eligible candidate'
       END AS classification
FROM park_visit_avgs pv
LEFT JOIN fees f ON pv.park_name = f.park_name
WHERE COALESCE(f.per_person_fee, 0) = 0
  AND pv.avg_annual_visits >= 1000000
ORDER BY pv.avg_annual_visits DESC;


-- 5.3 Tier 1 vs Tier 2 split among candidate cluster based on park_type
-- Tier 1: NP, NS, NPRES, NR, NSR, NP&PRES = traditional fee-eligible units with controlled boundaries
-- Tier 2: NRA, NHP, NM = more complex implementation contexts
SELECT park_type, cluster_tier, COUNT(*) as park_count
FROM candidate_parks
GROUP BY park_type, cluster_tier;

-- importantly, we get the split for 24 parks identified to be potential revenue generators


-- 5.4 Cluster comparison aggregates (to compare potential candidates, non paid & EO 14314 surcharge  parks)
-- count of parks, avg_visists, spending/visit, avg current entrance fees
WITH comparison AS(
	SELECT *
	FROM park_metrics pm
	LEFT JOIN candidate_parks cp ON pm.park_name = 
	
)


-- Upon research yet again, Great Smoky has a deed which prevent it from collecting entrance fees. See README for more details.
-- PART 6: GRSM case study on park it forward (proof of concept)

-- 6.1 GRSM annual visitation 2017-2024 with Park It Forward marker
-- (Park It Forward parking fees implemented March 1, 2023)
SELECT park_name, year,
       SUM(recreation_visits) AS annual_visits,
       CASE WHEN year >= 2023 THEN 'Post-fee' ELSE 'Pre-fee' END AS period
FROM visitation
WHERE park_name = 'Great Smoky Mountains NP'
  AND year BETWEEN 2017 AND 2024
GROUP BY park_name, year
ORDER BY year;


-- 6.2 GRSM pre vs post-fee average visitds comparison
SELECT
    CASE WHEN year < 2023 THEN 'Pre-fee (2017-2022)' ELSE 'Post-fee (2023-2024)' END AS period,
    ROUND(AVG(yearly.annual_visits), 2) AS avg_visits
FROM (
    SELECT year, SUM(recreation_visits) AS annual_visits
    FROM visitation
    WHERE park_name = 'Great Smoky Mountains NP'
      AND year BETWEEN 2017 AND 2024
    GROUP BY year
) yearly
GROUP BY period
ORDER BY period;


-- PART 7: Final projection and revenue modeling

-- 7.1 Total projected revenue at $5/person fee with 0.7 capture rate
-- Conservative per Stevens et al. (2014) and Sage et al. (2017) which estimate actual NPS demand response at 1-3%.
SELECT cluster_tier,
       COUNT(*) AS park_count,
       SUM(avg_annual_visits) AS total_annual_visits,
       ROUND(SUM(avg_annual_visits * 5 * 0.7)) AS projected_annual_revenue
FROM candidate_parks
GROUP BY cluster_tier
ORDER BY projected_annual_revenue DESC;

-- 7.2 Tier 1 candidate parks: per-park revenue projection
SELECT park_name, park_type, state,
       avg_annual_visits,
       ROUND(spending_per_visit,2) AS spending_per_visit,
       ROUND(avg_annual_visits * 5 * 0.7) AS projected_revenue
FROM candidate_parks
WHERE cluster_tier = 'Tier 1'
ORDER BY projected_revenue DESC;


-- 7.3 Tier 2 candidate parks: per-park revenue projection
SELECT park_name, park_type, state,
       avg_annual_visits,
       ROUND(spending_per_visit,2) AS spending_per_visit,
       ROUND(avg_annual_visits * 5 * 0.7) AS projected_revenue
FROM candidate_parks
WHERE cluster_tier = 'Tier 2'
ORDER BY projected_revenue DESC;

-- 7.4 Sensitivity analysis: revenue at different fee levels
SELECT fee_level,
       ROUND(SUM(avg_annual_visits * fee_level * 0.7)) AS projected_revenue
FROM candidate_parks
CROSS JOIN (VALUES (3), (5), (7), (10)) AS fee_levels(fee_level)
GROUP BY fee_level
ORDER BY fee_level;

-- 7.4 Sensitivity analysis: revenue at different capture rates (we are being very conservative based on peer reviewed research)
SELECT capture_rate,
       ROUND(SUM(avg_annual_visits * 5 * capture_rate)) AS projected_revenue
FROM candidate_parks
CROSS JOIN (VALUES (0.65), (0.7), (0.75), (0.8), (0.85), (0.9)) AS capture_rate(capture_rate)
GROUP BY capture_rate
ORDER BY capture_rate;