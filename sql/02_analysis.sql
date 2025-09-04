USE pcp_awv_de;

-- =======================================================
-- physician_compare (typed; multi-site per NPI + cleaned subset of columns)
-- =======================================================

DROP TABLE IF EXISTS physician_compare;
CREATE TABLE physician_compare (
  npi                       VARCHAR(10)    NOT NULL,
  last_name                 VARCHAR(60),
  first_name                VARCHAR(60),
  gender                    CHAR(1),
  credential                VARCHAR(40),
  primary_specialty         VARCHAR(120),
  secondary_specialty_1     VARCHAR(120),
  secondary_specialty_2     VARCHAR(120),
  secondary_specialty_3     VARCHAR(120),
  secondary_specialty_4     VARCHAR(120),
  all_secondary_specialties VARCHAR(512),
  street1                   VARCHAR(120),
  street2                   VARCHAR(120),
  city                      VARCHAR(60),
  state                     CHAR(2),
  zip5                      CHAR(5),
  is_primary_care           BOOLEAN DEFAULT 0,
  PRIMARY KEY (npi, street1, city, state, zip5)
);


INSERT INTO physician_compare (
  npi, last_name, first_name, gender, credential,
  primary_specialty, secondary_specialty_1, secondary_specialty_2, secondary_specialty_3, secondary_specialty_4,
  all_secondary_specialties, street1, street2, city, state, zip5, is_primary_care
)
SELECT
  t.npi,
  t.last_name,
  t.first_name,
  t.gender,
  t.credential,
  t.primary_specialty,
  t.secondary_specialty_1,
  t.secondary_specialty_2,
  t.secondary_specialty_3,
  t.secondary_specialty_4,
  t.all_secondary_specialties,
  t.street1,
  t.street2,        -- chosen deterministically (longest, then alpha)
  t.city,
  t.state,
  t.zip5,
  /* PCP flag if ANY specialty at this site implies primary care */
  ( t.all_specs REGEXP 'FAMILY PRACTICE|INTERNAL MEDICINE|GENERAL PRACTICE|GERIATRIC' ) AS is_primary_care
FROM (
  SELECT
    TRIM(npi) AS npi,
    /* deterministic picks for person fields */
    MAX(TRIM(last_name))   AS last_name,
    MAX(TRIM(first_name))  AS first_name,
    MAX(UPPER(TRIM(gender)))     AS gender,
    MAX(TRIM(credential))        AS credential,

    /* specialties: pick stable values; also build a combined list for PCP test */
    MAX(TRIM(primary_specialty))         AS primary_specialty,
    MAX(TRIM(secondary_specialty_1))     AS secondary_specialty_1,
    MAX(TRIM(secondary_specialty_2))     AS secondary_specialty_2,
    MAX(TRIM(secondary_specialty_3))     AS secondary_specialty_3,
    MAX(TRIM(secondary_specialty_4))     AS secondary_specialty_4,
    LEFT(
      UPPER(
        REPLACE(
          GROUP_CONCAT(DISTINCT TRIM(all_secondary_specialties) SEPARATOR '; '),
          '  ', ' '
        )
      ), 512
    ) AS all_secondary_specialties,

    /* normalized address (PK grain) */
    UPPER(TRIM(line_1_street_address))                            AS street1,
    /* choose street2 deterministically: longest non-empty, then alphabetic */
    SUBSTRING_INDEX(
      SUBSTRING_INDEX(
        GROUP_CONCAT(NULLIF(UPPER(TRIM(COALESCE(line_2_street_address,''))), '')
                      ORDER BY LENGTH(UPPER(TRIM(COALESCE(line_2_street_address,'')))) DESC,
                               UPPER(TRIM(COALESCE(line_2_street_address,''))) DESC
                      SEPARATOR '||'),
        '||', 1
      ),
      '||', -1
    ) AS street2,
    UPPER(TRIM(city))                                             AS city,
    UPPER(TRIM(state))                                            AS state,
    LPAD(SUBSTRING_INDEX(TRIM(zip_code), '-', 1), 5, '0')         AS zip5,

    /* combined specialties for PCP logic */
    UPPER(CONCAT_WS('; ',
      MAX(TRIM(primary_specialty)),
      REPLACE(GROUP_CONCAT(DISTINCT TRIM(all_secondary_specialties) SEPARATOR '; '), '  ', ' ')
    )) AS all_specs

  FROM stg_physician_compare
  WHERE NULLIF(TRIM(npi),'') IS NOT NULL
  GROUP BY
    TRIM(npi),
    UPPER(TRIM(line_1_street_address)),
    UPPER(TRIM(city)),
    UPPER(TRIM(state)),
    LPAD(SUBSTRING_INDEX(TRIM(zip_code), '-', 1), 5, '0')
) AS t;


-- =======================================================
-- physician_supplier_agg (typed; dedup/aggregate per NPI-city-state)
-- =======================================================
-- Rebuild agg table with decimals to preserve source precision
/* Rebuild (if needed) */
DROP TABLE IF EXISTS physician_supplier_agg;
CREATE TABLE physician_supplier_agg (
  npi                 VARCHAR(10) NOT NULL,
  provider_type       VARCHAR(120),
  city                VARCHAR(60) NOT NULL,
  state               CHAR(2)     NOT NULL,
  zip5                CHAR(5),
  total_med_services  DECIMAL(20,3),
  total_drug_services DECIMAL(20,3),
  PRIMARY KEY (npi, city, state)
);

/* Compliant INSERT: every non-grouped field aggregated */
INSERT INTO physician_supplier_agg (
  npi, provider_type, city, state, zip5, total_med_services, total_drug_services
)
SELECT
  TRIM(npi)                                              AS npi,
  /* choose a deterministic provider_type within the group */
  MAX(UPPER(TRIM(provider_type)))                         AS provider_type,
  UPPER(TRIM(nppes_provider_city))                        AS city,
  UPPER(TRIM(nppes_provider_state))                       AS state,
  /* pick a stable ZIP if multiple appear */
  MIN(LPAD(SUBSTRING_INDEX(TRIM(nppes_provider_zip),'-',1),5,'0')) AS zip5,
  /* aggregate services; keep decimals from source */
  SUM(COALESCE(NULLIF(REPLACE(total_med_services,  ',', ''), ''), '0') * 1.0) AS total_med_services,
  SUM(COALESCE(NULLIF(REPLACE(total_drug_services, ',', ''), ''), '0') * 1.0) AS total_drug_services
FROM stg_physician_supplier_agg
WHERE NULLIF(TRIM(npi),'') IS NOT NULL
GROUP BY
  TRIM(npi),
  UPPER(TRIM(nppes_provider_city)),
  UPPER(TRIM(nppes_provider_state));


-- =======================================================
-- physician_supplier_hcpcs (typed; address kept for site_key later)
-- =======================================================
DROP TABLE IF EXISTS physician_supplier_hcpcs;
CREATE TABLE physician_supplier_hcpcs (
  npi            VARCHAR(10) NOT NULL,
  hcpcs_code     VARCHAR(10),
  hcpcs_desc     VARCHAR(255),
  line_srvc_cnt  DECIMAL(20,3),    -- keep decimals if they appear
  street1        VARCHAR(120),
  street2        VARCHAR(120),
  city           VARCHAR(60),
  state          CHAR(2),
  zip5           CHAR(5),
  PRIMARY KEY (npi, hcpcs_code, street1, city, state, zip5)
);

INSERT INTO physician_supplier_hcpcs (
  npi, hcpcs_code, hcpcs_desc, line_srvc_cnt,
  street1, street2, city, state, zip5
)
SELECT
  TRIM(npi)                                         AS npi,
  UPPER(TRIM(hcpcs_code))                           AS hcpcs_code,
  MAX(TRIM(hcpcs_description))                      AS hcpcs_desc,   -- deterministic
  SUM(COALESCE(NULLIF(REPLACE(line_srvc_cnt, ',', ''), ''), '0') * 1.0) AS line_srvc_cnt,
  UPPER(TRIM(nppes_provider_street1))               AS street1,
  MAX(UPPER(TRIM(COALESCE(nppes_provider_street2,'')))) AS street2,   -- longest/any
  UPPER(TRIM(nppes_provider_city))                  AS city,
  UPPER(TRIM(nppes_provider_state))                 AS state,
  LPAD(SUBSTRING_INDEX(TRIM(nppes_provider_zip), '-', 1), 5, '0') AS zip5
FROM stg_physician_supplier_hcpcs
WHERE NULLIF(TRIM(npi),'') IS NOT NULL
GROUP BY
  TRIM(npi),
  UPPER(TRIM(hcpcs_code)),
  UPPER(TRIM(nppes_provider_street1)),
  UPPER(TRIM(nppes_provider_city)),
  UPPER(TRIM(nppes_provider_state)),
  LPAD(SUBSTRING_INDEX(TRIM(nppes_provider_zip), '-', 1), 5, '0');
