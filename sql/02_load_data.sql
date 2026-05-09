-- visitation: load with column mapping since CSV is CamelCase
COPY visitation (
    park_name, unit_code, park_type, region, state, year, month,
    recreation_visits, non_recreation_visits, recreation_hours, non_recreation_hours,
    concessioner_lodging, concessioner_camping, tent_campers, rv_campers,
    backcountry, non_recreation_overnight_stays, miscellaneous_overnight_stays
)
FROM '/tmp/visitation_cleaned.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY fees (park_name, state, entrance_fee, fee_type, per_person_fee)
FROM '/tmp/fees_cleaned.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY vse (park_name, year, recreation_visits, visitor_spending, jobs_supported, labor_income, value_added, economic_output)
FROM '/tmp/VSE_2017_2024_processed.csv'
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');


-- to remove data in rows but keep schema so reload dat using above COPY commands 
TRUNCATE TABLE visitation;
TRUNCATE TABLE fees;
TRUNCATE TABLE vse;