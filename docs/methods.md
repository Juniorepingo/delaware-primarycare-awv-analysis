# Methods & Documentation

## 1. Methods
- **Staging Layer**: All columns imported as `TEXT`. Ensures raw fidelity, especially for ZIP codes and numeric identifiers.  
- **Analysis Layer**: Created typed tables (VARCHAR, INT, DECIMAL, BOOLEAN). Selected only relevant fields for analysis.  
- **Canonical Provider Site**: Normalized addresses to generate consistent `site_key` (street1 + city + state + zip5).  
- **Specialty Filter**: Defined primary care specialties (Family Medicine, Internal Medicine, Geriatric Medicine, General Practice, Nurse Practitioner, Physician Assistant).  
- **AWV Identification**: Used HCPCS codes `G0438` (Initial AWV) and `G0439` (Subsequent AWV).  

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
Strategies to improve Delaware AWV uptake:

1. **High-Volume Practices**  
   - Focus on Wilmington & Newark hubs with multi-million service volumes.  
   - Replicate workflows from Lewes’ top-performing site (`20251 John J Williams Hwy`).  

2. **Low-Performing Sites**  
   - Target practices with <10,000 AWVs despite active NPIs.  
   - Provide workflow redesign, reminder systems, and EHR prompts.  

3. **Patient Engagement**  
   - Deploy patient-facing reminders (texts, calls, portal messages).  
   - Leverage nurse navigators to schedule AWVs proactively.  

4. **Equity Lens**  
   - Tailor outreach for dual-eligible and minority populations where AWV uptake is historically lower.  

5. **ACO Alignment**  
   - Tie AWV improvements to shared savings contracts (reduced preventable admissions/readmissions).  

---
