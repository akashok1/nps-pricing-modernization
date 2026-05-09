DROP TABLE visitation;
DROP TABLE fees;
DROP TABLE vse;

-- visitation table (IRMA monthly data)
CREATE TABLE visitation (
    park_name TEXT NOT NULL,
    unit_code TEXT,
    park_type TEXT,
    region TEXT,
    state TEXT,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    recreation_visits NUMERIC,
    non_recreation_visits NUMERIC,
    recreation_hours NUMERIC,
    non_recreation_hours NUMERIC,
    concessioner_lodging NUMERIC,
    concessioner_camping NUMERIC,
    tent_campers NUMERIC,
    rv_campers NUMERIC,
    backcountry NUMERIC,
    non_recreation_overnight_stays NUMERIC,
    miscellaneous_overnight_stays NUMERIC,
    PRIMARY KEY (park_name, year, month)
);

-- entrance fees table
CREATE TABLE fees (
    park_name TEXT PRIMARY KEY,
    state TEXT,
    entrance_fee NUMERIC,
    fee_type TEXT,
    per_person_fee NUMERIC
);

-- visitor spending effects (VSE) annual data
CREATE TABLE vse (
    park_name TEXT NOT NULL,
    year INTEGER NOT NULL,
    recreation_visits NUMERIC,
    visitor_spending NUMERIC,
    jobs_supported NUMERIC,
    labor_income NUMERIC,
    value_added NUMERIC,
    economic_output NUMERIC,
    PRIMARY KEY (park_name, year)
);

-- indexes for the joins
CREATE INDEX idx_visitation_park_year ON visitation(park_name, year);
CREATE INDEX idx_vse_park_year ON vse(park_name, year);