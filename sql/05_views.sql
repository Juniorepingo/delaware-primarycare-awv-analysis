-- 05_views.sql — helper view for HCPCS with site_key aligned to canonical
USE pcp_awv_de;

DROP VIEW IF EXISTS v_ps_hcpcs_with_site;
CREATE ALGORITHM=MERGE SQL SECURITY INVOKER VIEW v_ps_hcpcs_with_site AS
SELECT
  h.npi,
  UPPER(TRIM(h.hcpcs_code))          AS hcpcs_code,
  h.hcpcs_desc,
  h.line_srvc_cnt,
  UPPER(TRIM(h.street1))             AS street1,
  UPPER(TRIM(COALESCE(h.street2,''))) AS street2,   -- kept for reference; not in key
  UPPER(TRIM(h.city))                AS city,
  UPPER(TRIM(h.state))               AS state,
  LPAD(SUBSTRING_INDEX(COALESCE(h.zip5,''), '-', 1), 5, '0') AS zip5,
  CONCAT_WS('|',
    UPPER(TRIM(h.street1)),
    UPPER(TRIM(h.city)),
    UPPER(TRIM(h.state)),
    LPAD(SUBSTRING_INDEX(COALESCE(h.zip5,''), '-', 1), 5, '0')
  ) AS site_key
FROM physician_supplier_hcpcs h;

