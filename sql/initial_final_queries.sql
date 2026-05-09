-- Final query 1: park_summary.csv
WITH visitation_agg AS (
    SELECT park_name,
           region,
           state,
           park_type,
           unit_code,
           ROUND(SUM(CASE WHEN year BETWEEN 2017 AND 2024 THEN recreation_visits END)) AS total_visits_8yr,
           ROUND(SUM(CASE WHEN year BETWEEN 2020 AND 2024 THEN recreation_visits END)) AS total_visits_5yr,
           ROUND(AVG(CASE WHEN year BETWEEN 2017 AND 2024 THEN recreation_visits END) * 12) AS avg_annual_visits,
           ROUND(SUM(CASE WHEN year = 2024 THEN recreation_visits END)) AS visits_2024,
           ROUND(SUM(CASE WHEN year = 2023 THEN recreation_visits END)) AS visits_2023,
           ROUND(SUM(CASE WHEN year = 2020 THEN recreation_visits END)) AS visits_2020,
           ROUND(SUM(CASE WHEN year = 2019 THEN recreation_visits END)) AS visits_2019,
           ROUND(SUM(CASE WHEN year BETWEEN 2017 AND 2019 THEN recreation_visits END) / 3.0) AS avg_visits_pre_covid,
           ROUND(SUM(CASE WHEN year BETWEEN 2020 AND 2021 THEN recreation_visits END) / 2.0) AS avg_visits_covid,
           ROUND(SUM(CASE WHEN year BETWEEN 2022 AND 2024 THEN recreation_visits END) / 3.0) AS avg_visits_post_covid
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, region, state, park_type, unit_code
),
vse_agg AS (
    SELECT park_name,
           ROUND(AVG(visitor_spending)) AS avg_visitor_spending_8yr,
           ROUND(AVG(economic_output)) AS avg_economic_output_8yr,
           ROUND(AVG(jobs_supported)) AS avg_jobs_supported_8yr,
           ROUND(AVG(labor_income)) AS avg_labor_income_8yr,
           ROUND(SUM(visitor_spending)) AS total_visitor_spending_8yr,
           ROUND(SUM(economic_output)) AS total_economic_output_8yr,
           ROUND(AVG(CASE WHEN year BETWEEN 2017 AND 2019 THEN visitor_spending END)) AS avg_spending_pre_covid,
           ROUND(AVG(CASE WHEN year BETWEEN 2020 AND 2021 THEN visitor_spending END)) AS avg_spending_covid,
           ROUND(AVG(CASE WHEN year BETWEEN 2022 AND 2024 THEN visitor_spending END)) AS avg_spending_post_covid,
           ROUND(AVG(CASE WHEN year BETWEEN 2017 AND 2019 THEN economic_output END)) AS avg_output_pre_covid,
           ROUND(AVG(CASE WHEN year BETWEEN 2020 AND 2021 THEN economic_output END)) AS avg_output_covid,
           ROUND(AVG(CASE WHEN year BETWEEN 2022 AND 2024 THEN economic_output END)) AS avg_output_post_covid
    FROM vse
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name
)
SELECT v.park_name,
       v.region,
       v.state,
       v.park_type,
       v.unit_code,
       v.total_visits_8yr,
       v.total_visits_5yr,
       v.avg_annual_visits,
       v.visits_2024,
       v.visits_2023,
       v.visits_2020,
       v.visits_2019,
       v.avg_visits_pre_covid,
       v.avg_visits_covid,
       v.avg_visits_post_covid,
       ROUND((v.avg_visits_post_covid::numeric / NULLIF(v.avg_visits_pre_covid, 0)), 2) AS visit_recovery_index,
       ROUND(((v.visits_2024 - v.visits_2023)::numeric / NULLIF(v.visits_2023, 0) * 100), 1) AS yoy_change_2024_pct,
       f.entrance_fee,
       f.per_person_fee,
       f.fee_type,
       ROUND(v.total_visits_8yr * COALESCE(f.per_person_fee, 0)) AS est_entrance_revenue_8yr,
       vse.avg_visitor_spending_8yr,
       vse.total_visitor_spending_8yr,
       vse.avg_economic_output_8yr,
       vse.total_economic_output_8yr,
       vse.avg_jobs_supported_8yr,
       vse.avg_labor_income_8yr,
       vse.avg_spending_pre_covid,
       vse.avg_spending_covid,
       vse.avg_spending_post_covid,
       vse.avg_output_pre_covid,
       vse.avg_output_covid,
       vse.avg_output_post_covid,
       ROUND((vse.avg_visitor_spending_8yr::numeric / NULLIF(v.avg_annual_visits, 0)), 2) AS spending_per_visit,
       ROUND((vse.avg_economic_output_8yr::numeric / NULLIF(v.avg_annual_visits, 0)), 2) AS output_per_visit,
       ROUND((vse.avg_jobs_supported_8yr::numeric / NULLIF(v.avg_annual_visits / 1000000.0, 0)), 1) AS jobs_per_million_visits,
       ROUND((vse.total_visitor_spending_8yr::numeric / NULLIF(v.total_visits_8yr * COALESCE(f.per_person_fee, 0), 0)), 1) AS spending_to_fee_ratio,
       NTILE(5) OVER (ORDER BY v.total_visits_8yr DESC NULLS LAST) AS visit_quintile,
       CASE
           WHEN v.avg_annual_visits > 3000000 THEN 'Major (>3M)'
           WHEN v.avg_annual_visits > 1000000 THEN 'Significant (1M-3M)'
           WHEN v.avg_annual_visits > 100000  THEN 'Moderate (100k-1M)'
           ELSE 'Low (<100k)'
       END AS traffic_tier,
       CASE
           WHEN v.park_type = 'National Park' AND v.avg_annual_visits > 3000000 THEN 'Major National Park'
           WHEN v.park_type = 'National Park' AND v.avg_annual_visits > 1000000 THEN 'Significant National Park'
           WHEN v.park_type = 'National Park' THEN 'Smaller National Park'
           WHEN v.avg_annual_visits > 3000000 THEN 'Major Non-Park Unit'
           WHEN v.avg_annual_visits > 1000000 THEN 'Significant Non-Park Unit'
           ELSE 'Smaller Unit'
       END AS unit_classification,
       CASE
           WHEN f.per_person_fee IS NULL OR f.per_person_fee = 0 THEN 'Free'
           WHEN f.per_person_fee <= 10 THEN 'Low ($1-10)'
           WHEN f.per_person_fee <= 15 THEN 'Mid ($11-15)'
           ELSE 'High ($16+)'
       END AS fee_tier,
       CASE
           WHEN (f.per_person_fee IS NULL OR f.per_person_fee = 0) AND v.avg_annual_visits > 1000000 THEN 'Untapped: Free + High Traffic'
           WHEN f.per_person_fee <= 10 AND v.avg_annual_visits > 1000000 THEN 'Underpriced: Low Fee + High Traffic'
           WHEN f.per_person_fee >= 15 AND v.avg_annual_visits < 100000 THEN 'Possibly Overpriced: High Fee+ Low Traffic'
           ELSE 'Reasonable'
       END AS pricing_diagnosis,
       CASE WHEN v.park_name IN (
           'Acadia NP', 'Bryce Canyon NP', 'Everglades NP', 'Glacier NP',
           'Grand Canyon NP', 'Grand Teton NP', 'Rocky Mountain NP',
           'Sequoia NP', 'Kings Canyon NP', 'Yellowstone NP',
           'Yosemite NP', 'Zion NP'
       ) THEN 1 ELSE 0 END AS is_2026_surcharge_park
FROM visitation_agg v
LEFT JOIN fees f ON v.park_name = f.park_name
LEFT JOIN vse_agg vse ON v.park_name = vse.park_name
ORDER BY v.total_visits_8yr DESC NULLS LAST;










-- Final query 2: park_yearly.csv
WITH yearly_visits AS (
    SELECT park_name,
           region,
           state,
           park_type,
           year,
           ROUND(SUM(recreation_visits)) AS annual_visits
    FROM visitation
    WHERE year BETWEEN 2017 AND 2024
    GROUP BY park_name, region, state, park_type, year
)
SELECT yv.park_name,
       yv.region,
       yv.state,
       yv.park_type,
       yv.year,
       yv.annual_visits,
       LAG(yv.annual_visits) OVER (PARTITION BY yv.park_name ORDER BY yv.year) AS prev_year_visits,
       yv.annual_visits - LAG(yv.annual_visits) OVER (PARTITION BY yv.park_name ORDER BY yv.year) AS yoy_visit_change,
       ROUND(((yv.annual_visits - LAG(yv.annual_visits) OVER (PARTITION BY yv.park_name ORDER BY yv.year))::numeric 
              / NULLIF(LAG(yv.annual_visits) OVER (PARTITION BY yv.park_name ORDER BY yv.year), 0) * 100), 1) AS yoy_visit_change_pct,
       ROUND(vse.visitor_spending) AS visitor_spending,
       ROUND(vse.economic_output) AS economic_output,
       ROUND(vse.jobs_supported) AS jobs_supported,
       ROUND(vse.labor_income) AS labor_income,
       ROUND(vse.value_added) AS value_added,
       f.per_person_fee,
       f.fee_type,
       ROUND(yv.annual_visits * COALESCE(f.per_person_fee, 0)) AS est_annual_entrance_revenue,
       ROUND((vse.visitor_spending::numeric / NULLIF(yv.annual_visits, 0)), 2) AS spending_per_visit,
       ROUND((vse.economic_output::numeric / NULLIF(yv.annual_visits, 0)), 2) AS output_per_visit,
       CASE 
           WHEN yv.year BETWEEN 2017 AND 2019 THEN 'Pre-COVID'
           WHEN yv.year BETWEEN 2020 AND 2021 THEN 'COVID'
           ELSE 'Post-COVID'
       END AS covid_period
FROM yearly_visits yv
LEFT JOIN fees f ON yv.park_name = f.park_name
LEFT JOIN vse   ON yv.park_name = vse.park_name AND yv.year = vse.year
ORDER BY yv.park_name, yv.year;





select DISTINCT v.park_name, entrance_fee, AVG(recreation_visits) OVER (PARTITION BY v.park_name) AS avg_v
from vse v
left join fees f on v.park_name = f.park_name
where v.park_name ilike '%nra%'
GROUP BY v.park_name,entrance_fee, recreation_visits
ORDER BY avg_v DESC