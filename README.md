# NPS Pricing Modernization Analysis

Independent business analyst portfolio project examining National Park Service visitation, entrance fee, and visitor spending data to identify fee modernization opportunities at high-traffic, fee-eligible parks.

**Live dashboard:** https://public.tableau.com/app/profile/akashashok/viz/NPSPricingModernization/D1_Headline_Final
**Author:** Akash Ashok ([LinkedIn](https://linkedin.com/in/akash-v-ashok))

## Headline Finding

Great American Outdoors Act (GAOA) expired FY2025. 24 high-traffic parks remain at $0 entrance fee. Fee modernization following the Great Smoky Park It Forward model could recover an estimated $90M to $230M annually (midpoint $157M at $5/person, 0.7 demand factor) toward the $23B maintenance backlog.

## Business Question

Which NPS units are economically underperforming relative to demand, and where is untapped fee revenue?

## Audience

Prepared for Office of the Director, National Park Service (analytical target audience for portfolio purposes; see Disclaimer).

## Approach

1. **Cleaned and standardized** 46 years of NPS IRMA monthly visitation data (219K rows), 8 years of NPS Visitor Spending Effects reports (extracted from PDFs), and current NPS published entrance fees.
2. **Joined** datasets at the park-year level, fuzzy-matching park names across reporting systems via rapidfuzz.
3. **Modeled** projected fee revenue under a $5/person scenario at a 0.7 demand factor, applying conservative assumptions per Stevens (2014), Sage (2017), Heagney et al. (2018), Wang & Lin (2023), and Newbold (2025).
4. **Classified** 398 NPS units into Tier 1 (traditional fee-eligible), Tier 2 (NRAs and urban historical), Case Study (GRSM proof of concept), and excluded (memorials, parkways, etc.).
5. **Recommended** a 3-phase rollout sequenced by implementation feasibility, political risk, and equity exposure.

## Tech Stack

- **Python** (pandas, pdfplumber, rapidfuzz) for ETL and PDF extraction
- **PostgreSQL** via pgAdmin4 for data warehousing and analytical SQL
- **Tableau Public** for the executive dashboard

## Repository Structure
NPS-Analysis/
├── README.md                       (this file)
├── METHODOLOGY.md                  (detailed assumptions and citations)
├── data/
│   ├── raw/                        (NPS IRMA, VSE PDFs, fees CSV)
│   └── processed/
│       ├── visitation_cleaned.csv
│       ├── fees_cleaned.csv
│       ├── VSE_2017_2024_processed.csv
│       ├── park_summary.csv        (final extract for Tableau)
│       └── park_yearly.csv         (final extract for Tableau)
├── python/
│   └── data_cleaning.ipynb
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_load_data.sql
│   ├── 03_analysis.sql
│   └── 04_create_extracts.sql
└── tableau/
├── nps_pricing_modernization.twbx
└── dashboard_screenshot.png

## Data Sources

- **NPS IRMA** (Integrated Resource Management Applications): monthly visitation by park, 1979-2024.
- **NPS Visitor Spending Effects** annual reports, 2017-2024 (PDFs).
- **NPS official entrance fee data** as of January 2026.
- **NPS Park It Forward** press releases and public comment summaries (2022, 2024).
- **Great American Outdoors Act of 2020** (Public Law 116-152). Established the Legacy Restoration Fund for NPS deferred maintenance, funded through FY2025. https://www.congress.gov/bill/116th-congress/house-bill/1957
- **Federal Lands Recreation Enhancement Act** (FLREA, 16 USC 6801-6814). Statutory authority for NPS entrance fees. https://www.nps.gov/aboutus/flrea.htm
- **Executive Order 14314** (January 2026). Established $100 nonresident entrance surcharge at 11 high-traffic NPS units.

## Disclaimer

Independent analysis prepared for portfolio purposes. Not commissioned by or affiliated with the National Park Service or Department of the Interior.