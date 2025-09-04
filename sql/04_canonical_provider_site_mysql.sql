USE pcp_awv_de;

/* ================================================
   Rebuild canonical_provider_site (FULL_GROUP_BY safe)
   - No DELETE/UPDATE (avoids safe update mode)
   - Dedup by (npi, site_key)
   - site_key = street1|city|state|zip5  (street2 excluded)
   - street2 representative = longest non-null value
   ================================================ */


DROP TABLE IF EXISTS canonical_provider_site;
CREATE TABLE canonical_provider_site (
  npi      VARCHAR(10),
  street1  VARCHAR(120),
  -- keep a representative street2 for reference only (not in key)
  street2  VARCHAR(120),
  city     VARCHAR(60),
  state    CHAR(2),
  zip5     CHAR(5),
  site_key VARCHAR(255),
  PRIMARY KEY (npi, site_key)
);

/* Build canonical sites from Compare + HCPCS
   - Normalize case/zip
   - EXCLUDE street2 from site_key so suites don’t fragment
   - Pick deterministic street2 within each site for reference
*/
INSERT INTO canonical_provider_site (npi, street1, street2, city, state, zip5, site_key)
SELECT
  t.npi,
  t.street1,
  /* deterministic street2: longest non-empty, then alphabetic */
  SUBSTRING_INDEX(
    SUBSTRING_INDEX(
      GROUP_CONCAT(NULLIF(t.street2,'') ORDER BY LENGTH(t.street2) DESC, t.street2 DESC SEPARATOR '||'),
      '||', 1
    ),
  '||', -1) AS street2,
  t.city,
  t.state,
  t.zip5,
  CONCAT_WS('|', t.street1, t.city, t.state, t.zip5) AS site_key
FROM (
  SELECT DISTINCT
    TRIM(c.npi) AS npi,
    UPPER(TRIM(c.street1)) AS street1,
    UPPER(TRIM(COALESCE(c.street2,''))) AS street2,
    UPPER(TRIM(c.city)) AS city,
    UPPER(TRIM(c.state)) AS state,
    c.zip5
  FROM physician_compare c

  UNION

  SELECT DISTINCT
    TRIM(h.npi) AS npi,
    UPPER(TRIM(h.street1)) AS street1,
    UPPER(TRIM(COALESCE(h.street2,''))) AS street2,
    UPPER(TRIM(h.city)) AS city,
    UPPER(TRIM(h.state)) AS state,
    h.zip5
  FROM physician_supplier_hcpcs h
) AS t
GROUP BY t.npi, t.street1, t.city, t.state, t.zip5;
