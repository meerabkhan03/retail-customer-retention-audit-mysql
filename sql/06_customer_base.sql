-- =====================================================================
-- 06_customer_base.sql
-- Purpose : Build the invoice-level table for identified customers. All customer
--           analysis (cohorts, RFM) counts invoices, not individual lines.
-- Input   : sales_customers (valid merchandise sales with a Customer ID)
-- Output  : customer_invoices  (one row per invoice)
-- WARNING : DROPs and recreates customer_invoices (a derived table).
-- Rule    : An invoice's date is its earliest line timestamp.
-- =====================================================================
USE retail_audit;

DROP TABLE IF EXISTS customer_invoices;
CREATE TABLE customer_invoices AS
SELECT invoice,
       customer_id,
       MIN(invoice_date)                                        AS invoice_ts,
       MAX(invoice_date)                                        AS invoice_ts_last,
       CAST(DATE_FORMAT(MIN(invoice_date), '%Y-%m-01') AS DATE) AS invoice_month,
       COUNT(*)                                                 AS line_items,
       ROUND(SUM(line_amount), 2)                               AS invoice_amount
FROM sales_customers
GROUP BY invoice, customer_id;

-- The primary key also proves that no invoice belongs to two customers.
ALTER TABLE customer_invoices ADD PRIMARY KEY (invoice);
CREATE INDEX idx_ci_customer ON customer_invoices (customer_id, invoice_ts);

-- C1. Totals must equal sales_customers (C3).
-- Expected: 36594 invoices | 5852 customers | 788189 line items | 17124940.98
SELECT COUNT(*)                     AS invoices,
       COUNT(DISTINCT customer_id)  AS customers,
       SUM(line_items)              AS line_items,
       ROUND(SUM(invoice_amount),2) AS amount
FROM customer_invoices;

-- C2. Invoices with several timestamps; any crossing a month boundary?
-- Expected: 64 | 0 | 2 minutes
SELECT SUM(invoice_ts <> invoice_ts_last) AS invoices_with_several_timestamps,
       SUM(DATE_FORMAT(invoice_ts,'%Y-%m') <> DATE_FORMAT(invoice_ts_last,'%Y-%m')) AS invoices_crossing_a_month_boundary,
       MAX(TIMESTAMPDIFF(MINUTE, invoice_ts, invoice_ts_last)) AS max_minutes_apart
FROM customer_invoices;

-- C3. Reference totals. Expected: 788189 | 17124940.98 | 5852
SELECT COUNT(*) AS line_items, ROUND(SUM(line_amount),2) AS amount,
       COUNT(DISTINCT customer_id) AS customers
FROM sales_customers;
