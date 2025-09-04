-- NOTE: Staging was created via Workbench Import Wizard with ALL columns as TEXT for ALL 3 Dtasets.
-- Table name: staging_physician_compare
-- Table name: staging_physician_supplier_agg
-- Table name: staging_physician_supplier_hcpcs


-- Optional QA: verify headers & a few rows    -- Action here is just an optional sanity peek.                                
SHOW COLUMNS FROM staging_physician_compare;
SELECT * FROM staging_physician_compare LIMIT 5;

SHOW COLUMNS FROM staging_physician_supplier_agg;
SELECT * FROM staging_physician_supplier_agg LIMIT 5;

SHOW COLUMNS FROM staging_physician_supplier_hcpcs;
SELECT * FROM staging_physician_supplier_hcpcs LIMIT 5;