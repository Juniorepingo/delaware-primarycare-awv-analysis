-- ============================================================
-- 06_exercises.sql
-- Prereqs:
--   1) 02_analysis.sql  (multi-site per NPI; ONLY_FULL_GROUP_BY compliant)
--   2) 03_indexes.sql   (compare, agg, hcpcs indexes)
--   3) 04_canonical.sql (site_key = street1|city|state|zip5; Street2 excluded)
--   4) 05_views.sql     (v_ps_hcpcs_with_site aligns site_key to canonical)
-- Notes:
--   - Rounding is applied ONLY at presentation time via ROUND(...,0).
--   - ALL joins are site-correct using (npi, site_key).
-- ============================================================
USE pcp_awv_de;

-- ------------------------------------------------------------
-- Q1 — Primary care practices in DE (site-based)
-- Choose ONE of the two variants below and comment out the other.
-- ------------------------------------------------------------

/*** Q1A — STRICT PCP (MD/DO in classic PCP specialties) ***/
SELECT COUNT(*) AS primary_care_practices_DE
FROM (
  SELECT DISTINCT s.site_key
  FROM canonical_provider_site s
  JOIN physician_compare c ON c.npi = s.npi
  WHERE s.state = 'DE'
    AND (
      c.is_primary_care = 1 OR
      UPPER(c.primary_specialty) IN ('FAMILY PRACTICE','INTERNAL MEDICINE','GENERAL PRACTICE','GERIATRIC MEDICINE')
    )
) AS x;

/*** Q1B — BROAD PCP (includes NP/PA working in primary care) ***/
/*
SELECT COUNT(*) AS primary_care_practices_DE
FROM (
  SELECT DISTINCT s.site_key
  FROM canonical_provider_site s
  JOIN physician_compare c ON c.npi = s.npi
  WHERE s.state = 'DE'
    AND (
      -- MD/DO core PCP
      c.is_primary_care = 1 OR
      UPPER(c.primary_specialty) IN ('FAMILY PRACTICE','INTERNAL MEDICINE','GENERAL PRACTICE','GERIATRIC MEDICINE')
      -- NP/PA signal
      OR (UPPER(COALESCE(c.credential,'')) REGEXP '\\bNP\\b|\\bPA\\b'
          AND UPPER(COALESCE(c.all_secondary_specialties,'')) REGEXP 'FAMILY|INTERNAL|PRIMARY CARE|GERIATRIC')
    )
) AS x;
*/

-- ------------------------------------------------------------
-- Q2 — Top DE practice by Annual Wellness Visits (G0438/G0439)
-- Site-correct: join HCPCS (with derived site_key) to canonical on (npi, site_key).
-- ROUND only in the final select.
-- ------------------------------------------------------------
SELECT
  v.site_key,
  s.city,
  ROUND(SUM(v.line_srvc_cnt), 0) AS awv_services
FROM v_ps_hcpcs_with_site v
JOIN canonical_provider_site s
  ON s.npi = v.npi
 AND s.site_key = v.site_key
WHERE s.state = 'DE'
  AND v.hcpcs_code IN ('G0438','G0439')
GROUP BY v.site_key, s.city
ORDER BY awv_services DESC
LIMIT 1;

-- ------------------------------------------------------------
-- Q3 — Market view by DE city (site-based; services from agg)
--   1) Aggregate agg once per (npi, city, state)
--   2) Join to DISTINCT DE sites
--   3) ROUND totals at presentation time
-- ------------------------------------------------------------
SELECT
  d.city,
  COUNT(DISTINCT d.site_key)              AS sites,
  ROUND(SUM(a1.total_services), 0)        AS total_services
FROM (
  SELECT
    a.npi,
    a.city,
    a.state,
    (COALESCE(a.total_med_services,0) + COALESCE(a.total_drug_services,0)) AS total_services
  FROM physician_supplier_agg a
  WHERE a.state = 'DE'
) AS a1
JOIN (
  SELECT DISTINCT
    s.npi,
    s.city,
    s.state,
    s.site_key
  FROM canonical_provider_site s
  WHERE s.state = 'DE'
) AS d
  ON d.npi  = a1.npi
 AND d.city = a1.city
 AND d.state = a1.state
GROUP BY d.city
ORDER BY total_services DESC, sites DESC;

-- ------------------------------------------------------------
-- (Optional) City normalization for obvious typos (run once)
-- Uncomment to normalize city names before re-running Q3.
/*
DROP TABLE IF EXISTS city_norm;
CREATE TABLE city_norm (
  raw_city  VARCHAR(60) PRIMARY KEY,
  norm_city VARCHAR(60) NOT NULL
);

INSERT INTO city_norm (raw_city, norm_city) VALUES
  ('WIMINGTON','WILMINGTON'),
  ('NEWARD','NEWARK'),
  ('OCEANVIEW','OCEAN VIEW');

-- Q3 with normalization
SELECT
  d.city,
  COUNT(DISTINCT d.site_key)       AS sites,
  ROUND(SUM(a1.total_services),0)  AS total_services
FROM (
  SELECT
    a.npi,
    COALESCE(n.norm_city, a.city) AS city,
    a.state,
    (COALESCE(a.total_med_services,0) + COALESCE(a.total_drug_services,0)) AS total_services
  FROM physician_supplier_agg a
  LEFT JOIN city_norm n ON a.city = n.raw_city
  WHERE a.state = 'DE'
) AS a1
JOIN (
  SELECT DISTINCT
    s.npi,
    COALESCE(n.norm_city, s.city) AS city,
    s.state,
    s.site_key
  FROM canonical_provider_site s
  LEFT JOIN city_norm n ON s.city = n.raw_city
  WHERE s.state = 'DE'
) AS d
  ON d.npi  = a1.npi
 AND d.city = a1.city
 AND d.state = a1.state
GROUP BY d.city
ORDER BY total_services DESC, sites DESC;
*/

-- ------------------------------------------------------------
-- (Optional) Sanity checks
-- ------------------------------------------------------------
-- 1) Q2 join coverage: expect 0 (all DE HCPCS AWV rows map to canonical)
SELECT COUNT(*) AS unmatched_awv_rows_DE
FROM v_ps_hcpcs_with_site v
LEFT JOIN canonical_provider_site s
  ON s.npi = v.npi AND s.site_key = v.site_key
WHERE v.hcpcs_code IN ('G0438','G0439') AND v.state = 'DE' AND s.npi IS NULL;

-- 2) Site uniqueness (street2 excluded)
SELECT
  SUM(dup_cnt > 1) AS num_dup_site_keys_DE
FROM (
  SELECT npi, site_key, COUNT(*) AS dup_cnt
  FROM canonical_provider_site
  WHERE state = 'DE'
  GROUP BY npi, site_key
) z;
