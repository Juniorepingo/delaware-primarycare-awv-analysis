USE pcp_awv_de;         
-- ============================================================
-- 08_export_tableau.sql
-- Purpose: Build Tableau-ready dataset for AWV visualization
-- Notes:
--  - No window functions
--  - No CTEs (WITH …)
--  - MySQL Workbench compatible
-- ============================================================

DROP TABLE IF EXISTS tableau_awv_export;

CREATE TABLE tableau_awv_export AS
SELECT
    s.npi,
    s.site_key,
    s.street1,
    s.street2,
    s.city,
    s.state,
    s.zip5,
    c.primary_specialty,
    CASE 
        WHEN UPPER(c.primary_specialty) IN ('NURSE PRACTITIONER','PHYSICIAN ASSISTANT') THEN 'NP/PA'
        ELSE 'MD/DO'
    END AS provider_type_group,

    /* NPI-level AWV (G0438/G0439) services */
    COALESCE(a.awv_services_2019, 0) AS awv_services_2019,
    CASE WHEN COALESCE(a.awv_services_2019, 0) > 0 THEN 1 ELSE 0 END AS is_awv_active,

    /* City PCP site count (distinct canonical sites in that city) */
    COALESCE(cs.pcp_sites_in_city, 0) AS pcp_sites_in_city
FROM canonical_provider_site s
JOIN physician_compare c
  ON c.npi = s.npi
LEFT JOIN (
    SELECT
        h.npi,
        SUM(h.line_srvc_cnt) AS awv_services_2019
    FROM physician_supplier_hcpcs h
    WHERE h.hcpcs_code IN ('G0438','G0439')
    GROUP BY h.npi
) a
  ON a.npi = s.npi
LEFT JOIN (
    SELECT
        s2.city,
        COUNT(DISTINCT s2.site_key) AS pcp_sites_in_city
    FROM canonical_provider_site s2
    JOIN physician_compare c2
      ON c2.npi = s2.npi
    WHERE c2.is_primary_care = 1
      AND c2.state = 'DE'
    GROUP BY s2.city
) cs
  ON cs.city = s.city
WHERE c.is_primary_care = 1
  AND c.state = 'DE';
  
SELECT *
FROM tableau_awv_export;
-- In the result grid: Export > CSV (save to data/exports/tableau_awv_export.csv)

