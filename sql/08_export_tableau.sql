/* ============================================================
   08_export_tableau.sql
   Purpose: Build Tableau-ready dataset supporting Q1–Q3
   Notes:
     - MySQL Workbench compatible (no CTEs, no window funcs)
     - Preserves legacy NPI-level AWV field for Q3 stability
     - Adds site-level AWV field + PCP flag for Q1 & Q2
     - Scope limited to Delaware (state='DE')
   ============================================================ */

USE pcp_awv_de;

DROP TABLE IF EXISTS tableau_awv_export;

CREATE TABLE tableau_awv_export AS
SELECT
    s.npi,
    s.site_key,
    CONCAT_WS(' | ', s.street1, s.city, s.state, s.zip5) AS practice_label,
    s.street1, s.street2, s.city, s.state, s.zip5,
    c.primary_specialty,
    CASE WHEN UPPER(c.primary_specialty) IN ('NURSE PRACTITIONER','PHYSICIAN ASSISTANT') THEN 'NP/PA' ELSE 'MD/DO' END AS provider_type_group,

    /* Q3 (legacy NPI-level) */
    COALESCE(a_npi.awv_services_2019_npi, 0)   AS awv_services_2019,

    /* Q2 per-(NPI,site) slice (kept for completeness; not used for top-site KPI) */
    COALESCE(a_site_npi.awv_services_2019_site, 0) AS awv_services_2019_site,

    /* ⭐ Q2 site TOTAL across all NPIs at that site (use this in Tableau) */
    COALESCE(a_site_total.awv_services_2019_site_total, 0) AS awv_services_2019_site_total,

    /* Q1 flag */
    CASE
      WHEN c.is_primary_care = 1
        OR UPPER(c.primary_specialty) IN ('FAMILY PRACTICE','INTERNAL MEDICINE','GENERAL PRACTICE','GERIATRIC MEDICINE')
      THEN 1 ELSE 0
    END AS is_pcp_site,

    CASE WHEN COALESCE(a_site_total.awv_services_2019_site_total,0) > 0 THEN 1 ELSE 0 END AS is_awv_active,
    COALESCE(cs.pcp_sites_in_city, 0) AS pcp_sites_in_city

FROM canonical_provider_site s
JOIN physician_compare c ON c.npi = s.npi

/* NPI-level AWV (Q3 safe) */
LEFT JOIN (
  SELECT v.npi, SUM(v.line_srvc_cnt) AS awv_services_2019_npi
  FROM v_ps_hcpcs_with_site v
  WHERE v.hcpcs_code IN ('G0438','G0439') AND v.state='DE'
  GROUP BY v.npi
) a_npi ON a_npi.npi = s.npi

/* Site-level per-(NPI,site) slice (not for the KPI) */
LEFT JOIN (
  SELECT v.npi, v.site_key, SUM(v.line_srvc_cnt) AS awv_services_2019_site
  FROM v_ps_hcpcs_with_site v
  JOIN canonical_provider_site s3 ON s3.npi=v.npi AND s3.site_key=v.site_key
  WHERE v.hcpcs_code IN ('G0438','G0439') AND s3.state='DE'
  GROUP BY v.npi, v.site_key
) a_site_npi ON a_site_npi.npi=s.npi AND a_site_npi.site_key=s.site_key

/* ⭐ Site-level TOTAL across all NPIs at the site */
LEFT JOIN (
  SELECT v.site_key, SUM(v.line_srvc_cnt) AS awv_services_2019_site_total
  FROM v_ps_hcpcs_with_site v
  JOIN canonical_provider_site s4 ON s4.npi=v.npi AND s4.site_key=v.site_key
  WHERE v.hcpcs_code IN ('G0438','G0439') AND s4.state='DE'
  GROUP BY v.site_key
) a_site_total ON a_site_total.site_key = s.site_key

/* City PCP site counts (unchanged) */
LEFT JOIN (
  SELECT s2.city, COUNT(DISTINCT s2.site_key) AS pcp_sites_in_city
  FROM canonical_provider_site s2
  JOIN physician_compare c2 ON c2.npi=s2.npi
  WHERE c2.is_primary_care=1 AND c2.state='DE'
  GROUP BY s2.city
) cs ON cs.city = s.city

WHERE c.state='DE';



-- QA Checks for tableau_awv_export

-- Q1: Primary care practice count
-- Expect ~410
SELECT COUNT(DISTINCT site_key) AS practice_count
FROM tableau_awv_export
WHERE is_pcp_site = 1;

-- Q2: Top site by AWVs (site total)
-- Expect Lewes site ≈ 2,497
SELECT practice_label, city, awv_services_2019_site_total
FROM tableau_awv_export
WHERE awv_services_2019_site_total > 0
ORDER BY awv_services_2019_site_total DESC
LIMIT 5;

-- Q3: NPI-level AWV total (continuity)
-- Should match earlier NPI-level sanity check (~82,222)
SELECT SUM(awv_services_2019) AS total_npi_awv
FROM tableau_awv_export;

-- Cross-check: site total vs. NPI total
-- Should match earlier NPI-level sanity check (~82,222)
SELECT SUM(awv_services_2019) AS total_npi_awv
FROM tableau_awv_export;

-- Coverage sanity: every DE site has PCP flag + totals
-- No missing PCP flags
SELECT COUNT(*) AS missing_pcp_flag
FROM tableau_awv_export
WHERE is_pcp_site IS NULL;

-- No negative AWV values
SELECT COUNT(*) AS negative_awv
FROM tableau_awv_export
WHERE awv_services_2019_site_total < 0;

-- Top city context (for Q3 campaign insight)
-- Should match your Q3 exercise results (Newark, Wilmington, Dover, Lewes at top)
SELECT city,
       COUNT(DISTINCT site_key) AS sites,
       SUM(awv_services_2019)   AS total_npi_awv
FROM tableau_awv_export
GROUP BY city
ORDER BY total_npi_awv DESC
LIMIT 10;
