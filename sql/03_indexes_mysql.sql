-- Helpful indexes physician_compare
CREATE INDEX ix_pc_state_city ON physician_compare (state, city);
CREATE INDEX ix_pc_ispc       ON physician_compare (is_primary_care);

-- Helpful indexes physician_supplier_agg
CREATE INDEX ix_psa_state_city ON physician_supplier_agg (state, city);

-- physician_supplier_hcpcs: support Q2 join + code filter
-- 1) Join helper (npi + site parts) — crucial so MySQL can seek by (npi, site)
CREATE INDEX ix_psh_npi_site ON physician_supplier_hcpcs (npi, street1, city, state, zip5);
-- 2) Code filter (for hcpcs_code IN ('G0438','G0439'))
CREATE INDEX ix_psh_code ON physician_supplier_hcpcs (hcpcs_code);

-- canonical_provider_site: state/city rollups (Q3)
CREATE INDEX ix_cps_state_city ON canonical_provider_site (state, city);
