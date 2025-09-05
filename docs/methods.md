# Methods & Documentation

## 1. Methods
- **Staging Layer**: All columns imported as `TEXT`. Ensures raw fidelity, especially for ZIP codes and numeric identifiers.  
- **Analysis Layer**: Created typed tables (VARCHAR, INT, DECIMAL, BOOLEAN). Selected only relevant fields for analysis.  
- **Canonical Provider Site**: Normalized addresses to generate consistent `site_key` (street1 + city + state + zip5).  
- **Specialty Filter**: Defined primary care specialties (Family Medicine, Internal Medicine, Geriatric Medicine, General Practice, Nurse Practitioner, Physician Assistant).  
- **AWV Identification**: Used HCPCS codes `G0438` (Initial AWV) and `G0439` (Subsequent AWV).  

### 🔄 SQL Script ↔ Documentation Mapping
| Script File                          | Purpose / Action                                                                 | Documentation Section                  |
|--------------------------------------|---------------------------------------------------------------------------------|-----------------------------------------|
| `00_reset.sql`                       | Drops & recreates schema (`pcp_awv_de`) to ensure clean setup.                   | Methods → Staging Layer setup           |
| `01_staging_raw_data.sql`            | Loads raw CSVs into staging tables, all fields as `TEXT` to preserve fidelity.   | Methods → Staging Layer                 |
| `02_analysis.sql`                    | Builds typed analysis tables (VARCHAR, INT, DECIMAL, BOOLEAN).                   | Methods → Analysis Layer                |
| `03_indexes_mysql.sql`               | Adds indexes (NPI, site key, provider type, etc.) for performance.               | QA Checks (efficiency & validation)     |
| `04_canonical_provider_site_mysql.sql` | Normalizes addresses, generates consistent `site_key` (ignores `street2`).       | Methods → Canonical Provider Site       |
| `05_views.sql`                       | Creates helper views linking Compare + HCPCS for easier querying.                | QA Checks & Cross-Table Consistency     |
| `06_exercises.sql`                   | Answers assessment questions (practice count, AWV volumes, top sites).           | Results Summary & Campaign Playbook     |
| `07_profile_and_normalize.sql`       | Profiles data, normalizes cities, fixes typos (e.g., `NEWARD` → `NEWARK`).       | Limitations → Data Quality              |
| `08_export_tableau.sql`              | Exports NPI + site-level dataset for Tableau dashboard.                          | Methods → Tableau Export                   |



---

## 2. QA Checks
- **Row Parity**: Confirm staging row counts match clean tables.  
- **Duplicates**: Ensure no duplicate NPIs or site_keys.  
- **Nulls**: Check for missing critical fields (NPI, ZIP, specialty).  
- **Cross-Table Consistency**: Validate NPI presence across Compare, Supplier Agg, and HCPCS tables.  
- **AWV Services Sanity**: Validate AWV service counts >0 only for primary care NPIs.  

---

## 3. Limitations
- **CMS Suppression**: Counts <11 suppressed; subgroup sums may not match reported totals.  
- **Address Granularity**: Some NPIs list corporate addresses instead of site-level locations.  
- **Practice Attribution**: Multi-site NPIs may be over- or under-attributed.  
- **Data Quality**: Typos in city names (e.g., `NEWARD` vs `NEWARK`) may fragment results.  
- **Time Lag**: 2019 dataset may not reflect post-pandemic AWV patterns.  

---

## 4. Campaign Playbook
Strategies to improve Delaware AWV uptake (informed by dashboard analysis):

High-Volume Practices
Focus on Wilmington & Newark hubs with the largest patient panels but low adoption. Replicate workflows from top-performing practices in Seaford and Lewes.

Low-Performing Sites
Target cities with large PCP footprints but <5% adoption (e.g., Wilmington, Newark). Introduce workflow redesign, reminder systems, and EHR prompts.

Patient Engagement
Deploy patient-facing reminders (texts, calls, portal messages). Leverage nurse navigators to schedule AWVs proactively.

Equity Lens
Tailor outreach for dual-eligible and minority populations where AWV uptake is historically lower.

ACO Alignment
Tie AWV improvements to shared savings contracts and reduced preventable admissions/readmissions.

## 5. Tableau Dashboard

Distribution & Capacity: Where AWVs are concentrated, top 10 practices.

City Adoption: % of sites active in each city.

Specialty Adoption: Family Practice vs Internal Medicine vs Other.

Benchmarking: Top-performing practices for workflow replication.

Access:
[Interactive Dashboard: View on Tableau Public] (https://public.tableau.com/app/profile/raphael.dibo.epingo.jr/viz/delaware_awv_analysis/DelawarePrimaryCareAWVAnalysis2019)

