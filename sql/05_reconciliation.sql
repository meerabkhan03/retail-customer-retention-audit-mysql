-- =====================================================================
-- 05_reconciliation.sql
-- Purpose : Prove that no row was lost or double-counted, and sanity-check
--           the cleaning rules. Read-only. Run each query on its own.
-- Input   : sales_classified, sales_clean, overlap_invoices, stg_sales
-- Expected values below are the validated results on the full dataset.
-- =====================================================================
USE retail_audit;

-- R1. Grand total.
-- Expected: 1067371 rows; 19287250.55 (gross line total, NOT "revenue").
SELECT COUNT(*) AS line_items, ROUND(SUM(line_amount), 2) AS gross_line_total
FROM sales_classified;

-- R2. Raw rows = excluded rows (by reason) + kept rows.
-- Expected: 1: 22523 / 377488.45   2: 5712 / -73186.01   3: 17975 / -719762.50
--           4: 6013 / 0.00         (no reason 5)           KEPT: 1015148 / 19702710.61
SELECT COALESCE(exclusion_reason, 'KEPT: sales_clean') AS category,
       COUNT(*) AS line_items,
       ROUND(SUM(line_amount), 2) AS amount
FROM sales_classified
GROUP BY COALESCE(exclusion_reason, 'KEPT: sales_clean')
ORDER BY category;

-- R3. Kept rows split by whether the customer is identified.
-- Expected: no customer id 226959 / 2577769.63 / 0 customers;
--           with customer id 788189 / 17124940.98 / 5852 customers.
SELECT CASE WHEN customer_id IS NULL THEN 'kept, no customer id'
            ELSE 'kept, with customer id' END AS category,
       COUNT(*) AS line_items,
       ROUND(SUM(line_amount), 2) AS amount,
       COUNT(DISTINCT customer_id) AS customers
FROM sales_clean
GROUP BY category;

-- R4. Sheet 1 rows must never be removed as export duplicates. Expected: 0
SELECT COUNT(*) AS sheet1_rows_wrongly_removed
FROM sales_classified
WHERE source_sheet = 1 AND exclusion_reason LIKE '1%';

-- R5. Number of invoices present in both worksheets. Expected: 1088
SELECT COUNT(*) AS overlap_invoice_count FROM overlap_invoices;

-- R6. Sanity of kept rows. Expected: min_quantity 1, min_price 0.03,
--     dates 2009-12-01 07:45:00 to 2011-12-09 12:50:00
SELECT MIN(quantity) AS min_quantity, MIN(price) AS min_price,
       MIN(invoice_date) AS first_date, MAX(invoice_date) AS last_date
FROM sales_clean;

-- R7. Stock codes in kept rows that are not plain 5-digit product codes.
-- Expected: only genuine products, vouchers and the shop's DCGS items.
SELECT stock_code, MIN(description) AS sample_description,
       COUNT(*) AS line_items, ROUND(SUM(line_amount), 2) AS amount
FROM sales_clean
WHERE stock_code NOT REGEXP '^[0-9]{5}[A-Z]*$'
GROUP BY stock_code
ORDER BY line_items DESC;

-- R8. Rows excluded as non-merchandise (rows already removed as export
--     duplicates are not counted again). Expected total: 5712 / -73186.01
SELECT stock_code, COUNT(*) AS line_items, ROUND(SUM(line_amount), 2) AS amount
FROM sales_classified
WHERE exclusion_reason = '2 non-merchandise code'
GROUP BY stock_code
ORDER BY line_items DESC;

-- R9. Sensitivity: identical repeated lines still in sales_clean (kept on purpose).
-- Expected: 11731 surplus rows / 57092.82 / 0.29 percent of kept amount
SELECT d.surplus_rows, d.surplus_amount,
       ROUND(100 * d.surplus_amount / t.total_amount, 2) AS pct_of_kept_amount
FROM (
  SELECT SUM(c - 1) AS surplus_rows, ROUND(SUM((c - 1) * qty * prc), 2) AS surplus_amount
  FROM (
    SELECT COUNT(*) AS c, MAX(quantity) AS qty, MAX(price) AS prc
    FROM sales_clean
    GROUP BY invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
    HAVING COUNT(*) > 1
  ) g
) d
CROSS JOIN (SELECT ROUND(SUM(line_amount), 2) AS total_amount FROM sales_clean) t;

-- R10. Line-by-line proof of the worksheet overlap: for every distinct line in the
--      overlapping invoices, compare how often it appears in each sheet.
-- Expected: 22202 line groups, 22202 matching, 0 mismatching.
WITH k AS (
  SELECT s.invoice, s.stock_code, s.description, s.quantity, s.invoice_date, s.price,
         s.customer_id, s.country,
         SUM(s.source_sheet = 1) AS n1, SUM(s.source_sheet = 2) AS n2
  FROM stg_sales s
  JOIN overlap_invoices o ON o.invoice = s.invoice
  GROUP BY s.invoice, s.stock_code, s.description, s.quantity, s.invoice_date, s.price,
           s.customer_id, s.country
)
SELECT COUNT(*)      AS distinct_line_groups,
       SUM(n1 = n2)  AS matching_groups,
       SUM(n1 <> n2) AS mismatching_groups
FROM k;

-- R11. Do the audit counts carry through every category?
-- Expected TOTAL row: 1067371 | 19494 cancellations | 6225 zero/negative price |
--   3457 negative quantity without 'C' | 243007 no customer id | 4382 no description.
-- Expected KEPT row: zeros everywhere except no_customer_id = 226959.
SELECT category, rows_n, cancellations, zero_or_negative_price, negative_qty_no_c,
       no_customer_id, no_description
FROM (
  SELECT COALESCE(exclusion_reason, 'KEPT') AS category, COUNT(*) AS rows_n,
         SUM(is_cancellation = 1) AS cancellations,
         SUM(price <= 0) AS zero_or_negative_price,
         SUM(quantity < 0 AND is_cancellation = 0) AS negative_qty_no_c,
         SUM(customer_id IS NULL) AS no_customer_id,
         SUM(description IS NULL) AS no_description
  FROM sales_classified
  GROUP BY COALESCE(exclusion_reason, 'KEPT')
  UNION ALL
  SELECT 'TOTAL', COUNT(*), SUM(is_cancellation = 1), SUM(price <= 0),
         SUM(quantity < 0 AND is_cancellation = 0), SUM(customer_id IS NULL),
         SUM(description IS NULL)
  FROM sales_classified
) t
ORDER BY (category = 'TOTAL'), category;

-- R12. Is the overlap window fully covered by the overlapping invoices?
-- Expected: 0 and 0.
SELECT SUM(s.source_sheet = 1 AND s.invoice_date >= '2010-12-01' AND o.invoice IS NULL) AS sheet1_dec_rows_outside_overlap,
       SUM(s.source_sheet = 2 AND s.invoice_date <  '2010-12-10' AND o.invoice IS NULL) AS sheet2_window_rows_outside_overlap
FROM stg_sales s
LEFT JOIN overlap_invoices o ON o.invoice = s.invoice;

-- R13. Is each kept invoice consistent (one customer, one country)?
-- Expected: 39516 invoices; 0 with several customers; 0 mixing known and missing
--   customer; 82 with more than one timestamp (handled when invoices are
--   aggregated for the customer analysis); 0 with several countries.
SELECT COUNT(*) AS invoices,
       SUM(n_customers > 1) AS invoices_with_several_customers,
       SUM(n_null > 0 AND n_null < n_lines) AS invoices_mixing_known_and_missing_customer,
       SUM(n_timestamps > 1) AS invoices_with_several_timestamps,
       SUM(n_countries > 1) AS invoices_with_several_countries
FROM (
  SELECT invoice, COUNT(*) AS n_lines, COUNT(DISTINCT customer_id) AS n_customers,
         SUM(customer_id IS NULL) AS n_null, COUNT(DISTINCT invoice_date) AS n_timestamps,
         COUNT(DISTINCT country) AS n_countries
  FROM sales_clean GROUP BY invoice
) x;
