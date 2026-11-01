-- =====================================================================
-- 01_setup_and_load.sql
-- Purpose : Create the database and load the raw CSV exactly as received.
--           Every source column is text; the two lineage columns
--           (source_sheet, source_row) come from the conversion script.
-- Engine  : MySQL 8.0+
-- WARNING : DROPs and recreates raw_online_retail (every run reloads the raw data).
-- Note    : Edit the file path in LOAD DATA to match your machine.
--           Connection setting required: OPT_LOCAL_INFILE=1
-- =====================================================================

SET GLOBAL local_infile = 1;

CREATE DATABASE IF NOT EXISTS retail_audit CHARACTER SET utf8mb4;
USE retail_audit;

DROP TABLE IF EXISTS raw_online_retail;
CREATE TABLE raw_online_retail (
  invoice       VARCHAR(20),
  stock_code    VARCHAR(30),
  description   VARCHAR(255),
  quantity      VARCHAR(20),
  invoice_date  VARCHAR(30),
  price         VARCHAR(20),
  customer_id   VARCHAR(20),
  country       VARCHAR(60),
  source_sheet  TINYINT NOT NULL,   -- lineage: sheet position in the workbook
  source_row    INT NOT NULL        -- lineage: row position within the sheet
);

LOAD DATA LOCAL INFILE 'C:/data/online_retail/online_retail_II.csv'
INTO TABLE raw_online_retail
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(invoice, stock_code, description, quantity, invoice_date,
 price, customer_id, country, source_sheet, source_row);

SHOW WARNINGS;

-- Uniqueness of lineage doubles as an integrity check (fails if a row is duplicated).
ALTER TABLE raw_online_retail ADD PRIMARY KEY (source_sheet, source_row);

-- ---------------------------------------------------------------------
-- Verification (expected results in comments)
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM raw_online_retail;                        -- 1067371

SELECT COUNT(*) AS rows_with_carriage_return
FROM raw_online_retail WHERE country LIKE '%\r%';          -- 0

-- Per-sheet size and date range. Must match the Excel file:
--   sheet 1: 525461 rows, 2009-12-01 .. 2010-12-09
--   sheet 2: 541910 rows, 2010-12-01 .. 2011-12-09
SELECT source_sheet, COUNT(*) AS rows_n,
       MIN(invoice_date) AS first_date, MAX(invoice_date) AS last_date
FROM raw_online_retail GROUP BY source_sheet;

-- Boundary rows. Must match the Excel file:
--   last row of sheet 1: invoice 538171 (09/12/2010 20:01)
--   first row of sheet 2: invoice 536365 (01/12/2010 08:26)
SELECT source_sheet, source_row, invoice, invoice_date FROM raw_online_retail
WHERE (source_sheet = 1 AND source_row = 525461) OR (source_sheet = 2 AND source_row = 1);
