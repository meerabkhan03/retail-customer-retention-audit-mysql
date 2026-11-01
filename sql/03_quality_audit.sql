-- =====================================================================
-- 03_quality_audit.sql
-- Purpose : Measure data-quality problems BEFORE deciding how to treat them.
-- Input   : stg_sales
-- Rule    : Reads data only, except one helper table (dup_groups, section L).
--           Decisions live in docs/decision_log.md.
-- =====================================================================
USE retail_audit;

-- A. Missing values -----------------------------------------------------
SELECT COUNT(*) AS total_rows,
       SUM(customer_id IS NULL)  AS missing_customer_id,
       ROUND(100 * SUM(customer_id IS NULL) / COUNT(*), 2) AS pct_missing_customer,
       SUM(description IS NULL)  AS missing_description
FROM stg_sales;

-- B. Exact duplicate rows ----------------------------------------------
-- B1. How many duplicate groups, and how many surplus rows?
SELECT COUNT(*) AS duplicate_groups, SUM(c - 1) AS extra_rows
FROM (
  SELECT COUNT(*) AS c
  FROM stg_sales
  GROUP BY invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
  HAVING COUNT(*) > 1
) d;

-- B2. On which days are the surplus rows concentrated?
SELECT DATE(invoice_date) AS day, SUM(c - 1) AS extra_rows
FROM (
  SELECT invoice_date, COUNT(*) AS c
  FROM stg_sales
  GROUP BY invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
  HAVING COUNT(*) > 1
) d
GROUP BY DATE(invoice_date)
ORDER BY extra_rows DESC
LIMIT 15;

-- C. Cancellations and negative quantities ------------------------------
SELECT is_cancellation,
       COUNT(*)            AS rows_n,
       SUM(quantity < 0)   AS negative_qty,
       SUM(quantity > 0)   AS positive_qty,
       SUM(quantity = 0)   AS zero_qty
FROM stg_sales GROUP BY is_cancellation;

SELECT LEFT(invoice, 1) AS first_char, COUNT(*) AS n
FROM stg_sales GROUP BY first_char ORDER BY n DESC;

-- Negative quantity WITHOUT a cancellation prefix (inspect these rows)
SELECT invoice, stock_code, description, quantity, price, customer_id
FROM stg_sales WHERE quantity < 0 AND is_cancellation = 0 LIMIT 20;

-- D. Price problems -----------------------------------------------------
SELECT SUM(price = 0) AS zero_price, SUM(price < 0) AS negative_price FROM stg_sales;

SELECT invoice, stock_code, description, quantity, price, customer_id
FROM stg_sales WHERE price <= 0 LIMIT 20;

-- E. Non-product stock codes -------------------------------------------
SELECT stock_code, MIN(description) AS sample_description, COUNT(*) AS n,
       ROUND(SUM(quantity * price), 2) AS revenue
FROM stg_sales
WHERE stock_code NOT REGEXP '^[0-9]{5}[A-Za-z]*$'
GROUP BY stock_code ORDER BY n DESC;

-- F. Inconsistent descriptions -----------------------------------------
SELECT stock_code, COUNT(DISTINCT description) AS description_variants
FROM stg_sales GROUP BY stock_code
HAVING COUNT(DISTINCT description) > 1
ORDER BY description_variants DESC LIMIT 20;

SELECT COUNT(*) AS rows_with_extra_spaces
FROM raw_online_retail
WHERE CHAR_LENGTH(description) <> CHAR_LENGTH(TRIM(description));

-- G. Date coverage ------------------------------------------------------
SELECT DATE_FORMAT(invoice_date, '%Y-%m') AS month,
       COUNT(DISTINCT invoice) AS invoices, COUNT(*) AS line_items
FROM stg_sales GROUP BY month ORDER BY month;

-- H. Countries ----------------------------------------------------------
SELECT country, COUNT(*) AS line_items, ROUND(SUM(quantity * price), 2) AS revenue
FROM stg_sales GROUP BY country ORDER BY line_items DESC LIMIT 10;

-- I. Revenue by category (starting point for the reconciliation table) --
SELECT CASE
         WHEN is_cancellation = 1 THEN 'cancellation'
         WHEN customer_id IS NULL THEN 'no customer id'
         ELSE 'identified customer sale'
       END AS category,
       COUNT(*) AS line_items,
       ROUND(SUM(quantity * price), 2) AS revenue
FROM stg_sales GROUP BY category;

-- J. Sheet overlap (does the same data appear in both sheets?) ---------
-- J1. Date range and size per source sheet
SELECT source_sheet, MIN(invoice_date) AS first_date, MAX(invoice_date) AS last_date,
       COUNT(*) AS line_items, COUNT(DISTINCT invoice) AS invoices
FROM stg_sales GROUP BY source_sheet;

-- J2. Invoices that appear in both sheets
SELECT COUNT(*) AS invoices_in_both_sheets
FROM (SELECT invoice FROM stg_sales GROUP BY invoice HAVING COUNT(DISTINCT source_sheet) = 2) x;

-- J3. For those invoices, are the two copies identical (line count and value)?
WITH per_sheet AS (
  SELECT invoice, source_sheet, COUNT(*) AS lines_n, ROUND(SUM(quantity * price), 2) AS value_n
  FROM stg_sales GROUP BY invoice, source_sheet
)
SELECT COUNT(*) AS overlapping_invoices,
       SUM(a.lines_n = b.lines_n AND a.value_n = b.value_n)  AS identical_copies,
       SUM(a.lines_n <> b.lines_n OR a.value_n <> b.value_n) AS differing_copies
FROM per_sheet a
JOIN per_sheet b ON a.invoice = b.invoice AND a.source_sheet = 1 AND b.source_sheet = 2;

-- J4. Size of the sheet-2 copy of overlapping invoices
SELECT COUNT(*) AS sheet2_rows_in_overlap, ROUND(SUM(quantity * price), 2) AS revenue
FROM stg_sales s
WHERE s.source_sheet = 2
  AND EXISTS (SELECT 1 FROM stg_sales t WHERE t.invoice = s.invoice AND t.source_sheet = 1);

-- K. What do rows with a missing description look like? ----------------
SELECT COUNT(*) AS rows_n,
       SUM(price = 0)           AS zero_price,
       SUM(customer_id IS NULL) AS no_customer,
       SUM(quantity < 0)        AS negative_qty
FROM stg_sales WHERE description IS NULL;

-- L. Duplicate investigation (uses the explicit lineage columns) --------
-- L1. Helper table: every group of identical lines, with the number of copies
--     in each worksheet. DROPs and rebuilds dup_groups (takes a few minutes;
--     raise the Workbench read timeout first, see README).
DROP TABLE IF EXISTS dup_groups;
CREATE TABLE dup_groups AS
SELECT invoice, stock_code, description, quantity, invoice_date, price, customer_id, country,
       COUNT(*)              AS copies,
       SUM(source_sheet = 1) AS in_s1,
       SUM(source_sheet = 2) AS in_s2
FROM stg_sales
GROUP BY invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
HAVING COUNT(*) > 1;

SELECT COUNT(*) AS duplicate_groups, SUM(copies - 1) AS surplus_rows
FROM dup_groups;                                           -- 32907, 34335

-- L2. Where do the duplicates come from?
--     Validated result: both sheets 22202 groups / 22844 surplus rows (all in
--     1-9 Dec 2010); inside sheet 1: 6122 / 6544; inside sheet 2: 4583 / 4947.
SELECT CASE WHEN in_s1 > 0 AND in_s2 > 0 THEN 'copies in BOTH sheets'
            WHEN in_s1 > 0 THEN 'repeated inside sheet 1'
            ELSE 'repeated inside sheet 2' END AS pattern,
       COUNT(*)        AS groups_n,
       SUM(copies - 1) AS surplus_rows,
       SUM(CASE WHEN invoice_date >= '2010-12-01' AND invoice_date < '2010-12-10'
                THEN copies - 1 ELSE 0 END) AS surplus_1_9_dec_2010
FROM dup_groups
GROUP BY pattern;
