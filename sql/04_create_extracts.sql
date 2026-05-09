/*
NPS Pricing Modernization Analysis: Final extract tables
Purpose: Build park_summary and park_yearly extract tables from raw sources (visitation, fees, vse). 
		 These tables are exported to CSV for Tableau consumption.

Inputs: 
1) visitation (raw, monthly, 1979-2024)
2) fees (raw, current as of Q1 2026 per nps.gov/aboutus/entrance-fee-prices.htm)
3) vse (NPS Visitor Spending Effects, 2017-2024)

Outputs:
1) park_summary: one row per park, 28 columns, ~398 rows
2) park_yearly:  one row per park-year, 14 columns, ~3000 rows
*/

DROP TABLE IF EXISTS park_summary;

CREATE TABLE park_summary AS
WITH visitation_agg AS (
    SELECT park_name, park_type, state, region, unit_code,
           ROUND(SUM(recreation_visits)) AS total_visits_8yr,
           ROUND(SUM(recreation_visits) / 8.0) AS avg_annual_visits,
           ROUND(SUM(CASE WHEN year = 2024 THEN recreation_visits ELSE 0 END)) AS visits_2024
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, park_type, state, region, unit_code
),
 
vse_agg AS (
    SELECT park_name,
           ROUND(SUM(visitor_spending)) AS total_visitor_spending_8yr,
           ROUND(AVG(visitor_spending)) AS avg_visitor_spending_8yr,
           ROUND(SUM(economic_output)) AS total_economic_output_8yr,
           ROUND(AVG(economic_output)) AS avg_economic_output_8yr,
           ROUND(AVG(jobs_supported)) AS avg_jobs_supported_8yr,
           ROUND(AVG(labor_income)) AS avg_labor_income_8yr,
           ROUND(AVG(visitor_spending / NULLIF(recreation_visits, 0))::numeric, 2) AS spending_per_visit
    FROM vse
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name
),
 
joined AS (
    SELECT v.park_name, v.park_type, v.state, v.region, v.unit_code,
           f.entrance_fee,
           f.fee_type,
           f.per_person_fee,
           v.total_visits_8yr,
           v.avg_annual_visits,
           v.visits_2024,
           vse.total_visitor_spending_8yr,
           vse.avg_visitor_spending_8yr,
           vse.total_economic_output_8yr,
           vse.avg_economic_output_8yr,
           vse.avg_jobs_supported_8yr,
           vse.avg_labor_income_8yr,
           vse.spending_per_visit
    FROM visitation_agg v
    LEFT JOIN fees f ON v.park_name = f.park_name
    LEFT JOIN vse_agg vse ON v.park_name = vse.park_name
),
 
classified AS (
    SELECT *,
           -- Traffic tier: bucketed annual visitation
           CASE
               WHEN avg_annual_visits > 3000000 THEN 'Major (>3M/yr)'
               WHEN avg_annual_visits > 1000000 THEN 'Significant (1M-3M/yr)'
               WHEN avg_annual_visits > 100000  THEN 'Moderate (100K-1M/yr)'
               ELSE 'Low (<100K/yr)'
           END AS traffic_tier,
 
           -- Fee tier: bucketed entrance fee
           CASE
               WHEN per_person_fee IS NULL OR per_person_fee = 0 THEN 'Free'
               WHEN per_person_fee < 10 THEN 'Low ($1-9)'
               WHEN per_person_fee < 20 THEN 'Mid ($10-19)'
               ELSE 'High ($20+)'
           END AS fee_tier,
 
           -- Fee-eligibility: see README §Methodology for analytical framework
           -- Basis: FLREA (16 USC 6801-6814) + observed practice + operational feasibility
           CASE
               WHEN park_name ILIKE '%mem%' OR park_name ILIKE '%memorial%' THEN 0
               WHEN park_name ILIKE '%pkwy%' OR park_name ILIKE '%parkway%' THEN 0
               WHEN park_name IN (
                       'Golden Gate NRA', 'Gateway NRA',
                       'Boston Harbor Islands NRA', 'Castle Clinton NM',
                       'Independence NHP'
                   )
                   THEN 0
               ELSE 1
           END AS is_fee_eligible,
 
           -- Exclusion reason: documents why is_fee_eligible = 0
           CASE
               WHEN park_name ILIKE '%mem%' OR park_name ILIKE '%memorial%'
                   THEN 'Memorial: practice and political precedent (no NPS memorial currently charges)'
               WHEN park_name ILIKE '%pkwy%' OR park_name ILIKE '%parkway%'
                   THEN 'Parkway: deed restrictions and diffuse multi-jurisdiction access'
               WHEN park_name IN (
                       'Golden Gate NRA', 'Gateway NRA',
                       'Boston Harbor Islands NRA', 'Castle Clinton NM',
                       'Independence NHP'
                   )
                   THEN 'Urban NRA/NHP: uncontrolled multi-point access'
               ELSE NULL
           END AS exclusion_reason,
 
           -- 2026 surcharge flag (Executive Order 14314)
           -- 12 NPS units; co-administered as 11 parks under the EO
           CASE
               WHEN park_name IN (
                       'Grand Canyon NP', 'Yellowstone NP', 'Yosemite NP', 'Zion NP',
                       'Acadia NP', 'Grand Teton NP', 'Glacier NP', 'Bryce Canyon NP',
                       'Sequoia NP', 'Kings Canyon NP', 'Rocky Mountain NP',
                       'Everglades NP'
                   )
                   THEN 1
               ELSE 0
           END AS is_2026_surcharge_park
    FROM joined
),
 
with_cluster AS (
    SELECT *,
           -- Pricing diagnosis: legacy classification, useful for D2 filters
           CASE
               WHEN fee_tier = 'Free'
                    AND traffic_tier IN ('Major (>3M/yr)', 'Significant (1M-3M/yr)')
                   THEN 'Untapped: Free + High Traffic'
               WHEN fee_tier = 'Low ($1-9)'
                    AND traffic_tier IN ('Major (>3M/yr)', 'Significant (1M-3M/yr)')
                   THEN 'Underpriced: Low Fee + High Traffic'
               WHEN fee_tier = 'High ($20+)'
                    AND traffic_tier IN ('Moderate (100K-1M/yr)', 'Low (<100K/yr)')
                   THEN 'Possibly Overpriced'
               ELSE 'Aligned'
           END AS pricing_diagnosis,
 
           -- Cluster tier: drives Dashboard 1 filtering and color
           --   Case Study (GRSM): proof of concept park
           --   Tier 1: traditional fee-eligible park types with controlled boundaries
           --   Tier 2: NRAs, NHPs, NMs with implementation complexity
           --   NULL: not in candidate cluster
           CASE
               WHEN park_name = 'Great Smoky Mountains NP'
                    AND is_fee_eligible = 1
                    AND fee_tier = 'Free'
                    AND avg_annual_visits >= 1000000
                   THEN 'Case Study (GRSM)'
               WHEN is_fee_eligible = 1
                    AND fee_tier = 'Free'
                    AND avg_annual_visits >= 1000000
                    AND park_type IN (
                            'National Park', 'National Seashore', 'National Preserve',
                            'National River', 'National Scenic Riverway',
                            'National Park & Preserve'
                        )
                   THEN 'Tier 1'
               WHEN is_fee_eligible = 1
                    AND fee_tier = 'Free'
                    AND avg_annual_visits >= 1000000
                   THEN 'Tier 2'
               ELSE NULL
           END AS cluster_tier
    FROM classified
),
 
final AS (
    SELECT *,
           CASE
               WHEN cluster_tier IN ('Tier 1', 'Tier 2')
                   THEN ROUND((avg_annual_visits * 5 * 0.7)::numeric)
               ELSE 0
           END AS projected_fee_revenue_5_usd
    FROM with_cluster
)
 
SELECT
    -- Park details
    park_name,
    park_type,
    state,
    region,
    unit_code,
 
    -- Fee details
    entrance_fee,
    fee_type,
    per_person_fee,
    fee_tier,
 
    -- Visitation
    total_visits_8yr,
    avg_annual_visits,
    visits_2024,
    traffic_tier,
 
    -- VSE aggregates
    total_visitor_spending_8yr,
    avg_visitor_spending_8yr,
    total_economic_output_8yr,
    avg_economic_output_8yr,
    avg_jobs_supported_8yr,
    avg_labor_income_8yr,
    spending_per_visit,
 
    -- Conclusions
    pricing_diagnosis,
    is_2026_surcharge_park,
    is_fee_eligible,
    exclusion_reason,
    cluster_tier,
    projected_fee_revenue_5_usd
   
FROM final
ORDER BY total_visits_8yr DESC NULLS LAST;

select * from park_summary;



-- park_yearly: one row per park-year, for time series visualization

DROP TABLE IF EXISTS park_yearly;

CREATE TABLE park_yearly AS
WITH yearly_visits AS (
    SELECT park_name, park_type, state, region, year,
           ROUND(SUM(recreation_visits)) AS annual_visits
    FROM visitation
    WHERE year BETWEEN 1979 AND 2024
    GROUP BY park_name, park_type, state, region, year
),
 
yearly_with_yoy AS (
    SELECT *,
           ROUND(
               (((annual_visits::numeric
                  / NULLIF(LAG(annual_visits) OVER (PARTITION BY park_name ORDER BY year), 0)) - 1) * 100)::numeric, 1) AS yoy_visit_change_pct
    FROM yearly_visits
),
 
joined_yearly AS (
    SELECT yw.park_name,
           yw.park_type,
           yw.state,
           yw.region,
           yw.year,
           yw.annual_visits,
           yw.yoy_visit_change_pct,
           ROUND(vse.visitor_spending) AS visitor_spending,
           ROUND(vse.economic_output) AS economic_output,
           ROUND(vse.jobs_supported) AS jobs_supported,
           ROUND(vse.labor_income) AS labor_income,
           ROUND((vse.visitor_spending / NULLIF(yw.annual_visits, 0))::numeric, 2) AS spending_per_visit,
           f.per_person_fee,
           ps.cluster_tier
    FROM yearly_with_yoy yw
    LEFT JOIN vse ON yw.park_name = vse.park_name AND yw.year = vse.year
    LEFT JOIN fees f ON yw.park_name = f.park_name
    LEFT JOIN park_summary ps ON yw.park_name = ps.park_name
)
 
SELECT
    park_name,
    park_type,
    state,
    region,
    year,
    annual_visits,
    yoy_visit_change_pct,
    visitor_spending,
    economic_output,
    jobs_supported,
    labor_income,
    spending_per_visit,
    per_person_fee,
    cluster_tier
FROM joined_yearly
ORDER BY park_name, year;

SELECT * FROM park_yearly;




-- Index for Tableau filter performance
CREATE INDEX idx_park_summary_cluster_tier ON park_summary(cluster_tier);
CREATE INDEX idx_park_summary_park_name ON park_summary(park_name);

CREATE INDEX idx_park_yearly_park_year ON park_yearly(park_name, year);
CREATE INDEX idx_park_yearly_cluster_tier ON park_yearly(cluster_tier);




-- Validation: confirm the extract tables look right before exporting

-- 398 rows
SELECT COUNT(*) AS park_summary_rows FROM park_summary;
 
-- 15,746 rows (~400 parks * up to 46 years, minus gaps before unit creation)
SELECT COUNT(*) AS park_yearly_rows FROM park_yearly;
 
-- Expected: 9 Tier 1, 15 Tier 2, 1 Case Study (GRSM) = 25 total
SELECT park_name, cluster_tier
FROM park_summary
WHERE cluster_tier IS NOT NULL
GROUP BY park_name, cluster_tier
ORDER BY cluster_tier;
 
-- $157.15 M (rounds to $150M for headline)
SELECT ROUND(SUM(projected_fee_revenue_5_usd) / 1000000.0, 2) AS total_projected_M
FROM park_summary;
 
-- Verify: no candidate park should also be a surcharge park i.e 0 rows
SELECT park_name, cluster_tier, is_2026_surcharge_park
FROM park_summary
WHERE cluster_tier IS NOT NULL
  AND is_2026_surcharge_park = 1;
-- Expected: 0 rows
 




-- Export commands (run from terminal, not pgAdmin)
-- \COPY park_summary TO '~/Desktop/NPS-Analysis/data/processed/park_summary.csv' WITH CSV HEADER;
-- \COPY park_yearly TO '~/Desktop/NPS-Analysis/data/processed/park_yearly.csv' WITH CSV HEADER;