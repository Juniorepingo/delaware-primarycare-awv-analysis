# Delaware Primary Care & Annual Wellness Visit (AWV) Analysis

📌 **Project Overview**  
This project analyzes Delaware’s Annual Wellness Visit (AWV) activity using CMS Public Use Files.  
It was developed as part of a technical SQL/analytics assessment and is structured for reproducibility.

The goal is to answer three key questions:

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
│ ├── 07_profile_and_normalize.sql
│ ├── 08_export_tableau.sql
│ └── 09_CSV_for_dashboard.sql


- **docs/** → project documentation (`methods.md`)  
- **sql/** → ordered pipeline scripts (00–09)  
- **.gitignore** → excludes raw CMS data, `.DS_Store`, exports, large docs  

---

## 🗂️ Data Sources
CMS PUFs (filtered to Delaware, 2019):  
- **Physician Compare** → provider demographics & specialties  
- **Physician Supplier Aggregate** → services & beneficiary characteristics  
- **Physician Supplier HCPCS** → line-level HCPCS detail (AWV = G0438/G0439)  

Raw files live locally under `data/raw/` but are not tracked in GitHub.

---

## ⚙️ How to Run
1. Set up MySQL Server and a CLI of your choice.  
2. Create schema: `pcp_awv_de`  
3. Confirm `sql_mode=ANSI_QUOTES`  
4. Run scripts in order:  
   - `00_reset.sql` → drop/create schema  
   - `01_staging_raw_data.sql` → import raw CSVs (TEXT only)  
   - `02_analysis.sql` → create typed clean tables  
   - `03_indexes_mysql.sql` → performance indexes  
   - `04_canonical_provider_site_mysql.sql` → normalize addresses → `site_key`  
   - `05_views.sql` → helper views  
   - `06_exercises.sql` → answers to Q1–Q3  
   - `07_profile_and_normalize.sql` → profiling & city normalization  
   - `08_export_tableau.sql` → Tableau-ready dataset  
   - `09_CSV_for_dashboard.sql` → unified SITE / CITY / SPECIALTY export  

5. Validate results with QA checks (see `docs/methods.md`).  

---

## 📊 Results Summary
- **Q1:** 410 unique primary care practices in Delaware  
- **Q2:** Top practice site → *20251 John J Williams Hwy, Lewes, DE* with **2,497 AWVs in 2019**  
- **Q3:**  
  - **Top cities by market size:** Newark (2.98M services), Dover (1.48M), Wilmington (1.30M)  
  - **Top specialties by adoption:** Internal Medicine (50%), Family Practice (44%)  

---

## 📊 Tableau Dashboard
👉 [View Interactive Dashboard on Tableau Public](https://public.tableau.com/app/profile/raphael.dibo.epingo.jr/viz/DelawarePrimaryCareAnnualWellnessVisitAnalysis2019/DelawarePrimaryCareAnnualWellnessVisitAnalysis2019)  

This dashboard provides four perspectives:  
- **Distribution & Capacity** – Where AWVs are concentrated; top 10 practices  
- **City Adoption** – % of sites active in each city  
- **Specialty Adoption** – Family Practice vs Internal Medicine vs Other specialties  
- **Benchmarking** – Top-performing practices to replicate workflows  

---

## 📖 Documentation
See [`docs/methods.md`](./docs/methods.md) for:  
- Methods & assumptions  
- QA checks  
- Data limitations  
- Campaign playbook (strategies to improve AWV adoption)  

---

## ⚠️ Notes
- Raw CMS CSVs are excluded from GitHub to keep the repo lean.  
- `.DS_Store` and local docs (*.pdf, *.docx) are ignored.  
- Repo is designed for **code + documentation**, not raw data hosting.  
