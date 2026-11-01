-- =====================================================================
-- 02_staging.sql
-- Purpose : Pre-flight checks, then build a typed staging table.
--           Nothing is deleted here; problem rows are flagged, not removed.
-- Input   : raw_online_retail     Output: stg_sales
-- WARNING : DROPs and recreates stg_sales (a derived table; raw data is untouched).
-- =====================================================================
USE retail_audit;

-- ---------------------------------------------------------------------
-- Pre-flight: each query must return 0 before converting text to types
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS bad_quantity FROM raw_online_retail WHERE quantity NOT REGEXP '^-?[0-9]+$';
SELECT COUNT(*) AS bad_price    FROM raw_online_retail WHERE price NOT REGEXP '^-?[0-9]+([.][0-9]+)?$';
SELECT COUNT(*) AS bad_date     FROM raw_online_retail WHERE invoice_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$';
SELECT COUNT(*) AS bad_custid   FROM raw_online_retail WHERE customer_id <> '' AND customer_id NOT REGEXP '^[0-9]+$';

-- ---------------------------------------------------------------------
-- Staging table (source_sheet + source_row identify each row)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS stg_sales;
CREATE TABLE stg_sales AS
SELECT
  source_sheet,
  source_row,
  invoice,
  stock_code,
  NULLIF(TRIM(description), '')               AS description,     -- leading/trailing spaces trimmed
  CAST(quantity AS SIGNED)                    AS quantity,
  CAST(invoice_date AS DATETIME)              AS invoice_date,
  CAST(price AS DECIMAL(10,2))                AS price,
  CAST(NULLIF(customer_id, '') AS UNSIGNED)   AS customer_id,
  country,
  (invoice LIKE 'C%')                         AS is_cancellation
FROM raw_online_retail;

ALTER TABLE stg_sales ADD PRIMARY KEY (source_sheet, source_row);
CREATE INDEX idx_stg_invoice  ON stg_sales (invoice);
CREATE INDEX idx_stg_customer ON stg_sales (customer_id);
CREATE INDEX idx_stg_date     ON stg_sales (invoice_date);

SELECT COUNT(*) AS staging_rows FROM stg_sales;   -- must be 1067371
SHOW WARNINGS;
