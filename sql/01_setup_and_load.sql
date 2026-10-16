-- =====================================================================
-- 01_setup_and_load.sql
-- Purpose : Create the database, load the raw CSV exactly as received,
--           and add a row_id so every row can be traced.
-- Engine  : MySQL 8.0+
-- Note    : Edit the file path in LOAD DATA to match your machine.
--           Connection setting required: OPT_LOCAL_INFILE=1
-- =====================================================================

SET GLOBAL local_infile = 1;

CREATE DATABASE IF NOT EXISTS retail_audit CHARACTER SET utf8mb4;
USE retail_audit;

-- Raw layer: every column is text on purpose. No cleaning happens here.
DROP TABLE IF EXISTS raw_online_retail;
CREATE TABLE raw_online_retail (
  invoice       VARCHAR(20),
  stock_code    VARCHAR(30),
  description   VARCHAR(255),
  quantity      VARCHAR(20),
  invoice_date  VARCHAR(30),
  price         VARCHAR(20),
  customer_id   VARCHAR(20),
  country       VARCHAR(60)
);

LOAD DATA LOCAL INFILE 'C:/data/online_retail/online_retail_II.csv'
INTO TABLE raw_online_retail
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SHOW WARNINGS;

-- Row identifier (follows file order: sheet 1 rows first, then sheet 2).
ALTER TABLE raw_online_retail
  ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY FIRST;

-- ---------------------------------------------------------------------
-- Verification (expected results in comments)
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_rows, MIN(row_id) AS min_id, MAX(row_id) AS max_id
FROM raw_online_retail;                                   -- 1067371, 1, 1067371

SELECT COUNT(*) AS rows_with_carriage_return
FROM raw_online_retail WHERE country LIKE '%\r%';         -- 0

-- Sheet-order assumption: row_id <= 525461 belongs to sheet 1.
SELECT (row_id <= 525461) AS is_sheet1,
       MIN(invoice_date) AS first_date, MAX(invoice_date) AS last_date, COUNT(*) AS rows_n
FROM raw_online_retail GROUP BY is_sheet1;
