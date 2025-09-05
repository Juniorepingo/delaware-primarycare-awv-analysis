# Delaware Primary Care & Annual Wellness Visit (AWV) Analysis

## 📌 Project Overview
This project analyzes **Delaware’s Annual Wellness Visit (AWV) activity** using CMS Public Use Files.  
It was developed as part of a technical SQL/analytics assessment and is structured for reproducibility.

I aim to answer three questions:
1. **How many primary care practices are in Delaware?**  
2. **Which practice performed the highest number of AWVs in 2019?**  
3. **What strategies could increase AWV uptake among eligible beneficiaries?**

---

## 📂 Repo Structure

delaware-primarycare-awv-analysis/
├── .gitignore
├── README.md
├── docs/
│ └── methods.md # methods, QA checks, limitations, playbook
├── sql/
│ ├── 00_reset.sql
│ ├── 01_staging_raw_data.sql
│ ├── 02_analysis.sql
│ ├── 03_indexes_mysql.sql
│ ├── 04_canonical_provider_site_mysql.sql
│ ├── 05_views.sql
│ ├── 06_exercises.sql
│ └── 07_profile_and_normalize.sql
└── 08_export_tableau.sql


- **`docs/`** → project documentation (`methods.md`)  
- **`sql/`** → ordered pipeline scripts (00-08)  
- **`.gitignore`** → excludes raw CMS data, `.DS_Store`, exports, large docs  

---

## 🗂️ Data Sources
CMS PUFs (filtered to Delaware):
- **Physician Compare** → provider demographics & specialties  
- **Physician Supplier Aggregate** → services & beneficiary characteristics  
- **Physician Supplier HCPCS** → line-level HCPCS detail (AWV = G0438/G0439)  

Raw files live locally under `data/raw/` but are **not tracked in GitHub**.

---

## ⚙️ How to Run
1. **Set up MySQL Server and a CLI of your choice**  
   - Create schema: `pcp_awv_de`  
   - Confirm `sql_mode=ANSI_QUOTES`

2. **Run Scripts in Order**  
   - `00_reset.sql` → drop/create schema  
   - `01_staging_raw_data.sql` → import raw CSVs into staging tables (TEXT only)  
   - `02_analysis.sql` → create typed clean tables  
   - `03_indexes_mysql.sql` → performance indexes  
   - `04_canonical_provider_site_mysql.sql` → normalize addresses → `site_key`  
   - `05_views.sql` → helper views  
   - `06_exercises.sql` → answers to Q1–Q3  
   - `07_profile_and_normalize.sql` → profiling & city normalization  

3. **Validate Results**  
   - Run QA checks in `docs/methods.md`  
   - Inspect row counts, duplicates, nulls  

---

## 📊 Results Summary
- **Q1:** **410** unique primary care practices in Delaware  
- **Q2:** Top site → `20251 JOHN J WILLIAMS HWY | LEWES | DE | 19958` with **2,497 AWVs in 2019**  
- **Q3:** Top cities by AWV services: Newark, Wilmington, Dover, Lewes (see full table in docs)  

---

## 📊 Tableau Dashboard

The interactive dashboard is published on Tableau Public:  
👉 [View Delaware Primary Care & AWV Analysis (2019)](https://public.tableau.com/app/profile/raphael.dibo.epingo.jr/viz/delaware_awv_analysis/DelawarePrimaryCareAWVAnalysis2019)

This dashboard provides four perspectives:
1. **Distribution & Capacity** – Where AWVs are concentrated and top 10 practices.  
2. **City Adoption** – % of primary care sites performing AWVs.  
3. **Specialty Adoption** – Family Practice vs Internal Medicine vs Other specialties.  
4. **Benchmarking** – Top-performing practices to replicate workflows.  
**Build Tableau dashboard** under `/dashboards/`  

---

## 📖 Documentation
See [docs/methods.md](docs/methods.md) for:
- Methods  
- QA checks  
- Limitations  
- Campaign playbook (strategies to improve AWV adoption)  

---

## ⚠️ Notes
- Raw CMS CSVs are excluded from GitHub to keep the repo lean.  
- `.DS_Store` and local docs (`*.pdf`, `*.docx`) are ignored.  
- Repo is designed for **code + documentation**, not raw data hosting.
