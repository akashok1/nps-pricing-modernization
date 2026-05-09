# Methodology and Assumptions

This document details the analytical decisions behind the NPS Pricing Modernization Analysis. The dashboard summarizes findings; this document defends them.

## Revenue Proxy Model

### Formula

`Projected fee revenue = Annual visits × Per-person fee × Demand factor`

### Parameters

- **Per-person fee**: $5 baseline (conservative). Range explored: $3-$7.
- **Demand factor**: 0.7 baseline. Range explored: 0.5-0.9.
- **Headline range**: $90M to $230M annually across 24 candidate parks. Midpoint at $5 / 0.7 demand = $157M.

### Demand Factor Justification

The 0.7 demand factor is more conservative than the existing elasticity literature suggests, by analytical choice.  Sage et al. (2017) estimate 1-3% visitation response at 'conic NPs. Newbold (2025) confirms low elasticity at Yellowstone specifically. Heagney et al. (2018) extend findings to broader recreation contexts. However, the existing literature focuses overwhelmingly on high visitation parks (Yellowstone, Yosemite, Grand Canyon). Elasticity research at smaller, urban, or NRA-type units is very sparse. The candidate parks in this analysis include many such units. Cluster comparison data shows visitors to candidate parks spend $51 per visit in gateway communities, versus $89 at currently-paid non-surcharge parks. This suggests greater price sensitivity at candidate parks. The 0.7 factor accounts for this expected behavioral asymmetry, providing a defensible conservative parameter where literature-implied factors (0.97-0.99 demand) might overstate revenue.

### Scope

Revenue model scoped to 2017-2024 visitation. Historical fee data is not publicly available at park level; applying current 2026 fees to decades-old visitation would overstate revenue. Per-vehicle fees converted to per-person equivalents at NPS standard of 2.5 persons per vehicle, consistent with VSE methodology.

## Park Classification

398 NPS units (as per 2024) classified into four groups:

- **Tier 1 (10 parks)**: Traditional fee-eligible NPs, NSes, and NPRESes currently at $0. High traffic (>1M visits/yr), low political friction.
- **Tier 2 (14 parks)**: NRAs, urban historical units, and DC parkland currently at $0. High traffic, higher political/operational complexity.
- **Case Study (1 park)**: Great Smoky Mountains NP. Park It Forward parking fee model implemented March 2023. Used as proof of concept for the broader recommendation.
- **Excluded (373 parks)**: Memorials, parkways, low-traffic units, and parks already charging fees.

## Exclusion Criteria

Excluded units reflect three factors:

1. **Documented legal restrictions**. The GRSM 1951 deed transfer prohibits tolls on primary park roads under 16 USC. Similar deed restrictions exist at other parkways but require park-specific legal review.
2. **Operational infeasibility for fee collection**. Uncontrolled multi-point access at urban NRAs and parkways spanning multiple jurisdictions.
3. **Observed NPS practice and political precedent**. No NPS memorial currently charges entrance fees. Fee proposals at iconic memorials would face significant political opposition.

The legal authority for NPS entrance fees is the Federal Lands Recreation Enhancement Act (FLREA, 16 USC 6801-6814). FLREA does not categorically prohibit fees at any specific unit type. Tier 2 and excluded parks may still warrant case-by-case review for fee modernization feasibility.

## EO 14314 Treatment

Executive Order 14314 (effective January 1, 2026) added a $100 per-person nonresident entrance surcharge at 11 high-profile NPS units (12 administrative units, since Sequoia and Kings Canyon are co-administered): Acadia, Bryce Canyon, Everglades, Glacier, Grand Canyon, Grand Teton, Rocky Mountain, Sequoia, Kings Canyon, Yellowstone, Yosemite, and Zion. The surcharge applies on top of existing standard entrance fees ($20-35 per vehicle base). EO 14314 surcharge revenue is excluded from the candidate revenue model since the candidate parks are by definition different from the surcharge parks. EO 14314 is referenced in the cluster comparison only as context for current NPS pricing variation.

## Fee Treatment

- Parks with suspended entrance fees (Bent's Old Fort NHS, San Francisco Maritime NHP) as of April 2026 treated as $0 to reflect current status.
- Parks with recently eliminated fees (Fort Smith NHS, Wilson's Creek NB, James A Garfield NHS) as of April 2026 treated as $0.
- Sequoia and Kings Canyon NPs treated as a single administrative unit consistent with IRMA reporting, despite separate visitation data.
- Amenity fees excluded from the proxy model: guided tours (First Ladies NHS, Sagamore Hill NHS, Theodore Roosevelt Inaugural NHS), concessionaire services (Gateway Arch tram, lodging concessions), and state-managed fees (Poverty Point NM, Louisiana state administration). This means the model underestimates total park revenue, particularly at high-traffic parks where concessionaire revenue is significant.

## Multi-State Park Assignment

Multi-state parks assigned a single primary state for analysis:

- **Appalachian NST** (14 states) → WV (NPS administrative headquarters)
- **Manhattan Project NHP** (TN/NM/WA) → NM (Los Alamos, primary historical site)
- **Minidoka NHS** (ID/WA) → ID (primary site)

## Data Scoping Decisions

A separate NPS unit list dataset (originally Dataset 4) was evaluated and dropped as redundant. IRMA already provides ParkType, Region, State, and UnitCode at the park level, so a standalone unit list added no new information. Monthly granularity was retained in the cleaned visitation data despite analysis being conducted at the annual level. This provides flexibility for future seasonal or month-of-year analysis without re-cleaning the source data.

## Park Name Standardization

Park names differ across NPS reporting systems (IRMA, VSE, fee schedules). Reconciled via:

- **Fuzzy matching** with rapidfuzz `process.extractOne()` and `token_sort_ratio` scorer. The token sort approach splits names into words, sorts alphabetically, then compares. This enables matches like "Black Canyon of the Gunnison NP" to "Canyon Black Gunnison National Park" despite word order differences.
- **Manual overrides** for park redesignations (Indiana Dunes NL → NP, Saint-Gaudens NHS → NHP, Pinnacles NM → NP) and PDF line-wrap fragments.
- **IRMA convention** chosen as the canonical naming standard given its status as the primary NPS visitation system.
- **Park abbreviation reference**: NPS 2024 Visitor Spending Effects appendix, page 62 of 68.

## VSE PDF Extraction

Eight years of Visitor Spending Effects reports (2017-2024) extracted from PDFs:

- **2017, 2018, 2019, 2023**: pdfplumber `extract_table()` (PDFs have ruled tables)
- **2020, 2021, 2022**: regex fallback on extracted text (these years' PDFs lack table structure)

### Cleaning Steps

- Stripped footnote markers from park names: parentheticals, lowercase letter footnotes (a/b/c), trailing `*` and `!`, `#` symbols in numeric values.
- Money columns multiplied by 1,000 (reports use thousands as the unit).
- Multi-state parks (Manhattan Project, Minidoka) consolidated via groupby sum due to text wrapping that affected regex name extraction.
- Park names standardized to IRMA convention via fuzzy match plus manual override.

### VSE Limitations

The 2024 jobs methodology was updated by NPS, so JobsSupported is not directly comparable across the full 2017-2024 window. Other money columns (Visitor Spending, Labor Income, Value Added, Economic Output) follow consistent VSE methodology across years. For trend analysis, CPI-adjustment to constant 2024 dollars is recommended before plotting.

## Database Design

PostgreSQL chosen over alternatives for indsutry alignment and scalability. Unit code used as the primary park identifier in production-equivalent queries (stable across renamings); park name used for display. Foreign keys not enforced because the relationship between visitation and fee data is not strict (some parks lack fee records; some fee records lack visitation). In a production OLTP system, FK constraints would be added with appropriate handling for missing references.

## Limitations Summary

The revenue proxy is an upper-bound estimate that does not account for:

- America the Beautiful annual pass holders (~$80/yr unlimited entry to all NPS units)
- Fee-free days (6 per year)
- Visitors entering through unstaffed entrances
- Group and discount rates
- Resident vs nonresident population mix at parks subject to EO 14314 surcharge

These factors collectively suggest the actual capture rate may be lower than modeled. The directional finding (substantial recoverable revenue at candidate parks) is robust to these limitations.

## Citations (APA)

- Sage, J. L., Nickerson, N. P., Miller, Z. D., Ocanas, A., & Thomsen, J. (2017). Thinking Outside the Park-National Park Fee Increase Effects on Gateway Communities.
- Heagney, E. C., Rose, J. M., Ardeshiri, A., & Kovač, M. (2018). Optimising recreation services from protected areas–Understanding the role of natural values, built infrastructure and contextual factors. Ecosystem services, 31, 358-370.
- Newbold, S. C. The price elasticity of the demand for visits to Yellowstone National Park.
- Yoon, H., & Zou, S. (2025). An empirical investigation of the effects of entrance fees on national park visitors. Tourism Recreation Research, 50(1), 150-160.
- NPS Visitor Spending Effects, annual reports 2017-2024.
- NPS Park It Forward press releases (2022, 2024).
- National Park Service. (2023). Park It Forward Phase Two: Public Comment Summary.

## Disclaimer

Independent analysis prepared for portfolio purposes. Not commissioned by or affiliated with the National Park Service or Department of the Interior.