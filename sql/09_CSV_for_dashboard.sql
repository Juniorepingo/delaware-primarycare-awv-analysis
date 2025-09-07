/* ============================================================
   08_export_tableau_unified.sql
   One-table export powering Q1–Q3 + specialty/city adoption
   Grain: UNION of SITE, CITY, SPECIALTY records
   Constraints: MySQL Workbench friendly (no CTEs, no windows)
   Scope: Delaware only
   ============================================================ */

USE pcp_awv_de;

-- Clean slate
DROP TABLE IF EXISTS tmp_site_base;
DROP TABLE IF EXISTS tmp_city_rollup;
DROP TABLE IF EXISTS tmp_specialty_rollup;
DROP TABLE IF EXISTS tableau_awv_unified;

-- ------------------------------------------------------------
-- 1) Build SITE-level base (canonical sites + site-level AWV totals)
--    Includes: PCP flag, provider type, adoption flags
-- ------------------------------------------------------------
CREATE TABLE tmp_site_base AS
SELECT
    s.npi,
    s.site_key,
    CONCAT_WS(' | ', s.street1, s.city, s.state, s.zip5) AS practice_label,
    s.street1, s.street2, s.city, s.state, s.zip5,
    c.primary_specialty,
    CASE WHEN UPPER(c.primary_specialty) IN ('NURSE PRACTITIONER','PHYSICIAN ASSISTANT') THEN 'NP/PA'
         ELSE 'MD/DO'
    END AS provider_type_group,
    CASE
      WHEN c.is_primary_care = 1
        OR UPPER(c.primary_specialty) IN ('FAMILY PRACTICE','INTERNAL MEDICINE','GENERAL PRACTICE','GERIATRIC MEDICINE')
      THEN 1 ELSE 0
    END AS is_pcp_site,
    /* SITE-level AWV (align via canonical and filter by canonical DE) */
    COALESCE(a_site.awv_services_2019_site, 0) AS awv_site_total,
    CASE WHEN COALESCE(a_site.awv_services_2019_site,0) > 0 THEN 1 ELSE 0 END AS is_awv_active
FROM canonical_provider_site s
JOIN physician_compare c
  ON c.npi = s.npi
LEFT JOIN (
    SELECT
        v.site_key,
        SUM(v.line_srvc_cnt) AS awv_services_2019_site
    FROM v_ps_hcpcs_with_site v
    JOIN canonical_provider_site sc
      ON sc.npi = v.npi
     AND sc.site_key = v.site_key
    WHERE v.hcpcs_code IN ('G0438','G0439')
      AND sc.state = 'DE'   -- state filter comes from canonical
    GROUP BY v.site_key
) a_site
  ON a_site.site_key = s.site_key
WHERE c.state = 'DE';

-- Helpful index for joins/rollups
ALTER TABLE tmp_site_base ADD INDEX ix_tmp_site_city (city);
ALTER TABLE tmp_site_base ADD INDEX ix_tmp_site_sitekey (site_key);

-- ------------------------------------------------------------
-- 2) CITY rollup (for Q3 + city adoption card)
--    - sites_in_city: distinct PCP sites
--    - city_total_services: ALL Medicare services (from PSA), city level
--    - pct_sites_doing_awv: PCP sites with >0 AWVs / PCP sites
-- ------------------------------------------------------------
CREATE TABLE tmp_city_rollup AS
SELECT
    s.city,
    COUNT(DISTINCT CASE WHEN s.is_pcp_site = 1 THEN s.site_key END) AS sites_in_city,
    /* City total services from PSA (NPI-based), aligned to DE sites */
    (
      SELECT ROUND(SUM(a1.total_services),0)
      FROM (
        SELECT a.npi, a.city, a.state,
               (COALESCE(a.total_med_services,0) + COALESCE(a.total_drug_services,0)) AS total_services
        FROM physician_supplier_agg a
        WHERE a.state = 'DE'
      ) a1
      JOIN (
        SELECT DISTINCT s2.npi, s2.city, s2.state
        FROM canonical_provider_site s2
        WHERE s2.state = 'DE'
      ) d
        ON d.npi  = a1.npi
       AND d.city = a1.city
       AND d.state= a1.state
      WHERE d.city = s.city
    ) AS city_total_services,
    ROUND(
      100.0 *
      COUNT(DISTINCT CASE WHEN s.is_pcp_site = 1 AND s.awv_site_total > 0 THEN s.site_key END)
      / NULLIF(COUNT(DISTINCT CASE WHEN s.is_pcp_site = 1 THEN s.site_key END),0)
    , 2) AS pct_sites_doing_awv
FROM tmp_site_base s
GROUP BY s.city;

ALTER TABLE tmp_city_rollup ADD INDEX ix_tmp_city_city (city);

-- ------------------------------------------------------------
-- 3) SPECIALTY rollup (for “AWV Adoption by Specialty” chart)
-- ------------------------------------------------------------
CREATE TABLE tmp_specialty_rollup AS
SELECT
  UPPER(s.primary_specialty) AS primary_specialty,
  COUNT(DISTINCT s.site_key) AS sites_in_specialty,
  COUNT(DISTINCT CASE WHEN s.awv_site_total > 0 THEN s.site_key END) AS specialty_sites_doing_awv,
  ROUND(
    100.0 *
    COUNT(DISTINCT CASE WHEN s.awv_site_total > 0 THEN s.site_key END)
    / NULLIF(COUNT(DISTINCT s.site_key),0)
  , 2) AS specialty_pct_sites_doing_awv
FROM tmp_site_base s
WHERE s.is_pcp_site = 1
GROUP BY UPPER(s.primary_specialty);

-- ------------------------------------------------------------
-- 4) Unified export table (one table → one CSV)
--    record_type: 'SITE' | 'CITY' | 'SPECIALTY'
-- ------------------------------------------------------------
CREATE TABLE tableau_awv_unified AS
/* SITE rows */
SELECT
  'SITE' AS record_type,
  s.site_key,
  s.practice_label,
  s.street1, s.street2, s.city, s.state, s.zip5,
  s.primary_specialty,
  s.provider_type_group,
  s.is_pcp_site,
  s.awv_site_total,
  s.is_awv_active,
  /* City/Specialty fields null on SITE rows */
  NULL AS sites_in_city,
  NULL AS city_total_services,
  NULL AS pct_sites_doing_awv,
  NULL AS sites_in_specialty,
  NULL AS specialty_sites_doing_awv,
  NULL AS specialty_pct_sites_doing_awv
FROM tmp_site_base s

UNION ALL

/* CITY rows */
SELECT
  'CITY' AS record_type,
  NULL AS site_key,
  NULL AS practice_label,
  NULL AS street1, NULL AS street2, c.city, 'DE' AS state, NULL AS zip5,
  NULL AS primary_specialty,
  NULL AS provider_type_group,
  NULL AS is_pcp_site,
  NULL AS awv_site_total,
  NULL AS is_awv_active,
  c.sites_in_city,
  c.city_total_services,
  c.pct_sites_doing_awv,
  NULL AS sites_in_specialty,
  NULL AS specialty_sites_doing_awv,
  NULL AS specialty_pct_sites_doing_awv
FROM tmp_city_rollup c

UNION ALL

/* SPECIALTY rows */
SELECT
  'SPECIALTY' AS record_type,
  NULL AS site_key,
  NULL AS practice_label,
  NULL AS street1, NULL AS street2, NULL AS city, 'DE' AS state, NULL AS zip5,
  r.primary_specialty,
  NULL AS provider_type_group,
  NULL AS is_pcp_site,
  NULL AS awv_site_total,
  NULL AS is_awv_active,
  NULL AS sites_in_city,
  NULL AS city_total_services,
  NULL AS pct_sites_doing_awv,
  r.sites_in_specialty,
  r.specialty_sites_doing_awv,
  r.specialty_pct_sites_doing_awv
FROM tmp_specialty_rollup r;

-- ------------------------------------------------------------
-- 5) Quick QA (optional)
-- ------------------------------------------------------------
-- Q1: expect ~410
SELECT COUNT(DISTINCT site_key) FROM tableau_awv_unified WHERE record_type='SITE' AND is_pcp_site=1;

-- Q2: expect Lewes ~ 2,497 at top
SELECT practice_label, city, awv_site_total FROM tableau_awv_unified
WHERE record_type='SITE' AND is_pcp_site=1 AND awv_site_total>0
 ORDER BY awv_site_total DESC LIMIT 10;

-- sanity check
 SELECT
  practice_label,
  city,
  MAX(awv_site_total) AS awv_site_total
FROM tableau_awv_unified
WHERE record_type='SITE' AND is_pcp_site=1 AND awv_site_total > 0
GROUP BY practice_label, city
ORDER BY awv_site_total DESC
LIMIT 10;


-- Q3: city totals present
SELECT city, sites_in_city, city_total_services, pct_sites_doing_awv
 FROM tableau_awv_unified WHERE record_type='CITY' ORDER BY city_total_services DESC;

-- ------------------------------------------------------------
-- 6) Final export
--    In Workbench: run the SELECT below and Export → CSV
-- ------------------------------------------------------------
SELECT * FROM tableau_awv_unified;

-- Quick QA Checks in SQL for Final export dataset
-- Rows by record type
SELECT record_type, COUNT(*)
FROM tableau_awv_unified
GROUP BY record_type;

-- PCP sites (should be 410)
SELECT COUNT(DISTINCT site_key)
FROM tableau_awv_unified
WHERE record_type='SITE' AND is_pcp_site=1;

-- Top sites (Lewes ~2,497 AWVs should be #1)
SELECT practice_label, city, awv_site_total
FROM tableau_awv_unified
WHERE record_type='SITE' AND is_pcp_site=1 AND awv_site_total > 0
ORDER BY awv_site_total DESC
LIMIT 10;

