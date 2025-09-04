-- ============================================================
-- 07_profile_and_normalize.sql  (MySQL Workbench–safe)
-- Goal: profiling + normalization scaffolding for Q1–Q3
-- Notes:
--  • No CTEs, no UPDATE/DELETE, no index DDL here.
--  • Views avoid hcpcs_desc and use columns that exist in your schema.
--  • REGEXP literals made MySQL-friendly; ONLY_FULL_GROUP_BY safe.
-- ============================================================

USE pcp_awv_de;

-- ------------------------------------------------------------
-- A) PROFILING: ROW COUNTS & BASIC HEALTH
-- ------------------------------------------------------------

-- A1. Row counts (post-transform layer)
-- A1. Row counts (post-transform layer) — fixed alias (row_count)
SELECT 'physician_compare'         AS table_name, COUNT(*) AS row_count FROM physician_compare
UNION ALL SELECT 'physician_supplier_agg',               COUNT(*)          FROM physician_supplier_agg
UNION ALL SELECT 'physician_supplier_hcpcs',             COUNT(*)          FROM physician_supplier_hcpcs
UNION ALL SELECT 'canonical_provider_site',              COUNT(*)          FROM canonical_provider_site;


-- A2. Null/blank key parts (any of street1/city/state/zip5 missing)
SELECT 'canonical_null_key_parts' AS k,
       SUM((street1 IS NULL OR street1='') OR
           (city    IS NULL OR city='')    OR
           (state   IS NULL OR state='')   OR
           (zip5    IS NULL OR zip5=''))   AS v
FROM canonical_provider_site;

-- A3. ZIP sanity (non-5-char or non-numeric)
SELECT 'canonical_bad_zip5' AS k, COUNT(*) AS v
FROM canonical_provider_site
WHERE (zip5 IS NULL OR LENGTH(zip5)<>5 OR zip5 REGEXP '[^0-9]');

SELECT 'agg_bad_zip5' AS k, COUNT(*) AS v
FROM physician_supplier_agg
WHERE (zip5 IS NULL OR LENGTH(zip5)<>5 OR zip5 REGEXP '[^0-9]');

SELECT 'hcpcs_bad_zip5' AS k, COUNT(*) AS v
FROM physician_supplier_hcpcs
WHERE (zip5 IS NULL OR LENGTH(zip5)<>5 OR zip5 REGEXP '[^0-9]');

-- A4. Decimals present where counts are expected (FYI checks)
SELECT 'agg_med_has_decimal'  AS k,
       SUM(REPLACE(COALESCE(total_med_services,''),',','')  REGEXP '[.]') AS v
FROM stg_physician_supplier_agg;

SELECT 'agg_drug_has_decimal' AS k,
       SUM(REPLACE(COALESCE(total_drug_services,''),',','') REGEXP '[.]') AS v
FROM stg_physician_supplier_agg;

-- ------------------------------------------------------------
-- B) CITY VARIANTS: WHAT STRINGS EXIST & WHERE THEY DIVERGE
-- ------------------------------------------------------------

-- B1. Canonical: site counts by city (DE)
SELECT city, COUNT(*) AS site_count
FROM canonical_provider_site
WHERE state='DE'
GROUP BY city
ORDER BY site_count DESC, city;

-- B2. Agg: NPI-city rows by city (DE)
SELECT city, COUNT(*) AS npi_city_count
FROM physician_supplier_agg
WHERE state='DE'
GROUP BY city
ORDER BY npi_city_count DESC, city;

-- B3. HCPCS: rows by city (DE) via your existing view
SELECT city, COUNT(*) AS hcpcs_row_count
FROM v_ps_hcpcs_with_site
WHERE state='DE'
GROUP BY city
ORDER BY hcpcs_row_count DESC, city;

-- B4. Cross-table mismatches (DE)
-- Cities in canonical but not in agg
SELECT DISTINCT c.city AS canonical_only_city
FROM canonical_provider_site c
LEFT JOIN physician_supplier_agg a
  ON a.city=c.city AND a.state=c.state
WHERE c.state='DE' AND a.city IS NULL
ORDER BY c.city;

-- Cities in agg but not in canonical
SELECT DISTINCT a.city AS agg_only_city
FROM physician_supplier_agg a
LEFT JOIN canonical_provider_site c
  ON c.city=a.city AND c.state=a.state
WHERE a.state='DE' AND c.city IS NULL
ORDER BY a.city;

-- Cities in hcpcs (view) but no matching canonical site_key for that NPI
SELECT DISTINCT v.city AS hcpcs_only_city
FROM v_ps_hcpcs_with_site v
LEFT JOIN canonical_provider_site c
  ON c.npi=v.npi AND c.site_key=v.site_key
WHERE v.state='DE' AND c.npi IS NULL
ORDER BY v.city;

-- ------------------------------------------------------------
-- C) SITE KEY CONSISTENCY & DUPLICATION CHECKS
-- ------------------------------------------------------------

-- C1. Duplicated (npi, site_key) in canonical (should be 0 for DE)
SELECT SUM(dup_cnt>1) AS num_dup_site_keys_DE
FROM (
  SELECT npi, site_key, COUNT(*) AS dup_cnt
  FROM canonical_provider_site
  WHERE state='DE'
  GROUP BY npi, site_key
) z;

-- C2. HCPCS→Canonical join coverage (DE AWV rows that fail to map; expect 0)
SELECT COUNT(*) AS unmatched_awv_rows_DE
FROM v_ps_hcpcs_with_site v
LEFT JOIN canonical_provider_site s
  ON s.npi=v.npi AND s.site_key=v.site_key
WHERE v.hcpcs_code IN ('G0438','G0439') AND v.state='DE' AND s.npi IS NULL;

-- ------------------------------------------------------------
-- D) NORMALIZATION INFRA: CITY MAP (no indexes in this file)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS city_norm;
CREATE TABLE city_norm (
  raw_city  VARCHAR(60) PRIMARY KEY,
  norm_city VARCHAR(60) NOT NULL
);

-- Seed with known variants; extend after running section B/G
INSERT INTO city_norm (raw_city, norm_city) VALUES
  ('NEWARD','NEWARK'),
  ('WIMINGTON','WILMINGTON'),
  ('OCEANVIEW','OCEAN VIEW'),
  ('REHOBOTH','REHOBOTH BEACH'),
  ('WILMINGTON HOSPITAL 2ND FLOOR','WILMINGTON');

-- (Put any CREATE INDEX for city_norm into your 03_indexes.sql)

-- ------------------------------------------------------------
-- E) NORMALIZED VIEWS (do not mutate base tables)
-- ------------------------------------------------------------

-- Canonical (normalized city)
DROP VIEW IF EXISTS v_canonical_sites_norm;
CREATE VIEW v_canonical_sites_norm AS
SELECT
  s.npi,
  s.street1,
  s.street2,
  COALESCE(n.norm_city, s.city) AS city,
  s.state,
  s.zip5,
  s.site_key
FROM canonical_provider_site s
LEFT JOIN city_norm n
  ON s.city = n.raw_city;

-- Supplier Agg (normalized city)
DROP VIEW IF EXISTS v_physician_supplier_agg_norm;
CREATE VIEW v_physician_supplier_agg_norm AS
SELECT
  a.npi,
  COALESCE(n.norm_city, a.city) AS city,
  a.state,
  a.zip5,
  a.provider_type,
  a.total_med_services,
  a.total_drug_services
FROM physician_supplier_agg a
LEFT JOIN city_norm n
  ON a.city = n.raw_city;

-- HCPCS with site (normalized city)
DROP VIEW IF EXISTS v_ps_hcpcs_with_site_norm;
CREATE VIEW v_ps_hcpcs_with_site_norm AS
SELECT
  v.npi,
  v.hcpcs_code,
  v.line_srvc_cnt,
  v.street1,
  v.street2,
  COALESCE(n.norm_city, v.city) AS city,
  v.state,
  v.zip5,
  v.site_key
FROM v_ps_hcpcs_with_site v
LEFT JOIN city_norm n
  ON v.city = n.raw_city;


-- ------------------------------------------------------------
-- F) RE-RUN EXERCISES AGAINST NORMALIZED VIEWS (validation)
-- ------------------------------------------------------------

-- F1. Q1 (STRICT) with normalized canonical
SELECT COUNT(*) AS primary_care_practices_DE_norm
FROM (
  SELECT DISTINCT s.site_key
  FROM v_canonical_sites_norm s
  JOIN physician_compare c ON c.npi = s.npi
  WHERE s.state = 'DE'
    AND (
      c.is_primary_care = 1 OR
      UPPER(c.primary_specialty) IN ('FAMILY PRACTICE','INTERNAL MEDICINE','GENERAL PRACTICE','GERIATRIC MEDICINE')
    )
) x;


-- F2. Q2 with normalized HCPCS + canonical (site-correct; rounded at presentation)
SELECT
  v.site_key,
  s.city,
  ROUND(SUM(v.line_srvc_cnt), 0) AS awv_services
FROM v_ps_hcpcs_with_site_norm v
JOIN v_canonical_sites_norm s
  ON s.npi = v.npi AND s.site_key = v.site_key
WHERE s.state = 'DE'
  AND v.hcpcs_code IN ('G0438','G0439')
GROUP BY v.site_key, s.city
ORDER BY awv_services DESC
LIMIT 1;

-- F3. Q3 with normalized city names
SELECT
  d.city,
  COUNT(DISTINCT d.site_key)       AS sites,
  ROUND(SUM(a1.total_services),0)  AS total_services
FROM (
  SELECT
    a.npi,
    a.city,
    a.state,
    (COALESCE(a.total_med_services,0) + COALESCE(a.total_drug_services,0)) AS total_services
  FROM v_physician_supplier_agg_norm a
  WHERE a.state = 'DE'
) a1
JOIN (
  SELECT DISTINCT
    s.npi,
    s.city,
    s.state,
    s.site_key
  FROM v_canonical_sites_norm s
  WHERE s.state = 'DE'
) d
  ON d.npi  = a1.npi
 AND d.city = a1.city
 AND d.state = a1.state
GROUP BY d.city
ORDER BY total_services DESC, sites DESC;