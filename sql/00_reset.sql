-- Adjust schema name if needed
DROP DATABASE IF EXISTS pcp_awv_de;
CREATE DATABASE pcp_awv_de CHARACTER SET utf8mb4 
COLLATE utf8mb4_0900_ai_ci;
USE pcp_awv_de;

-- (Optional) session sanity for Workbench quirks
SET SESSION sql_safe_updates = 0;           -- avoids 1175 while rebuilding
-- We won't rely on changing ONLY_FULL_GROUP_BY; queries below are compliant.
