# Methods & Documentation

---

## 1. Methods

**Staging Layer**  
- All columns imported as `TEXT` to preserve raw fidelity (ZIP codes, numeric IDs).  

**Analysis Layer**  
- Created typed tables (`VARCHAR`, `INT`, `DECIMAL`, `BOOLEAN`).  
- Selected relevant fields for analysis.  

**Canonical Provider Site**  
- Normalized addresses to generate consistent `site_key` = `street1|city|state|zip5`.  
- Excluded `street2` from the key to prevent suite/room fragmentation.  

**Specialty Filter**  
- Defined primary care specialties: Family Medicine, Internal Medicine, Geriatric Medicine, General Practice, Nurse Practitioner, Physician Assistant.  

**AWV Identification**  
- Used HCPCS codes `G0438` (Initial AWV) and `G0439` (Subsequent AWV).  

**SQL Pipeline Mapping**  

| Script File                  | Purpose / Action                                         | Docs Section                |
|-------------------------------|---------------------------------------------------------|-----------------------------|
| `00_reset.sql`               | Drops & recreates schema (`pcp_awv_de`).                 | Methods → Staging Layer     |
| `01_staging_raw_data.sql`    | Loads raw CSVs into staging tables (all TEXT).           | Methods → Staging Layer     |
| `02_analysis.sql`            | Builds typed analysis tables.                            | Methods → Analysis Layer    |
| `03_indexes_mysql.sql`       | Adds indexes (NPI, site key, provider type, etc.).       | QA Checks → Efficiency      |
| `04_canonical_provider_site` | Normalizes addresses, generates `site_key`.              | Methods → Canonical Site    |
| `05_views.sql`               | Creates helper views linking Compare + HCPCS.            | QA Checks → Consistency     |
| `06_exercises.sql`           | Answers Q1–Q3 with site-correct joins.                   | Results → Q1–Q3             |
| `07_profile_and_normalize`   | Profiles data, normalizes city names.                    | Limitations → Data Quality  |
| `08_export_tableau.sql`      | Exports site + NPI-level dataset for Tableau.            | Methods → Tableau Export    |
| `09_CSV_for_dashboard.sql`   | Builds unified SITE / CITY / SPECIALTY dataset.          | Methods → Tableau Export    |

---

## 2. QA Checks

- **Row Parity** → Confirm staging row counts = clean tables.  
- **Duplicates** → Ensure no duplicate NPIs or `site_key`.  
- **Nulls** → Validate no missing `NPI`, ZIP, or specialty values.  
- **Cross-Table Consistency** → Check NPI coverage across Compare, Agg, HCPCS.  
- **AWV Services Sanity** → Validate AWV counts >0 only for primary care NPIs.  

---

## 3. Limitations

- **CMS Suppression** → Counts <11 are suppressed; subgroup totals may not align.  
- **Address Granularity** → Some NPIs list corporate addresses, not true practice sites.  
- **Practice Attribution** → Multi-site NPIs may cause under/over-attribution.  
- **Data Quality** → Typos in city names (`NEWARD` → `NEWARK`, etc.) fragment results.  
- **Time Lag** → Data reflects 2019, pre-pandemic care patterns.  

---

## 4. Campaign Playbook (Q3 Insights → Action)

**High-Volume Practices**  
- Focus on Wilmington & Newark hubs with the largest patient panels but low adoption.  
- Replicate workflows from top-performing practices in Lewes & Seaford.  

**Low-Performing Sites**  
- Target cities with large PCP footprints but <5% adoption (e.g., Wilmington, Newark).  
- Introduce workflow redesign, reminder systems, and EHR prompts.  

**Patient Engagement**  
- Deploy reminders (texts, calls, portal messages).  
- Leverage nurse navigators to schedule AWVs proactively.  

**Equity Lens**  
- Tailor outreach for dual-eligible and minority populations with historically lower uptake.  

**ACO Alignment**  
- Tie AWV improvements to shared savings contracts and reduced avoidable admissions.  

---

## 5. Tableau Dashboard

- **Distribution & Capacity** – Top 10 practices by AWV volume.  
- **City Adoption** – % of primary care sites doing AWVs.  
- **Specialty Adoption** – Internal Medicine vs Family Practice vs Others.  
- **Benchmarking** – Replicable workflows from high-performing sites.  

👉 [View on Tableau Public](https://public.tableau.com/app/profile/raphael.dibo.epingo.jr/viz/DelawarePrimaryCareAnnualWellnessVisitAnalysis2019/DelawarePrimaryCareAnnualWellnessVisitAnalysis2019)
