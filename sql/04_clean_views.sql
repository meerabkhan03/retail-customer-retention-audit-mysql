-- =====================================================================
-- 04_clean_views.sql
-- Purpose : Apply the documented cleaning rules. Every raw row gets exactly
--           ONE classification: either kept, or excluded for ONE reason
--           (the first rule that applies, in the order below).
-- Input   : stg_sales
-- WARNING : DROPs and recreates overlap_invoices and sales_classified (derived tables;
--           raw and staging data are untouched) and re-creates the three views.
-- Output  : overlap_invoices, sales_classified, and views
--           sales_clean, sales_customers, returns_clean
-- Rule order (documented in docs/decision_log.md):
--   1 export duplicate        sheet-2 copy of an invoice already present in sheet 1
--   2 non-merchandise code    postage, fees, adjustments, tests (explicit list)
--   3 cancellation (return)   invoice number starts with 'C'
--   4 zero or negative price
--   5 non-positive quantity
-- =====================================================================
USE retail_audit;

-- Invoices present in BOTH sheets (verified identical copies: 1,088 invoices).
DROP TABLE IF EXISTS overlap_invoices;
CREATE TABLE overlap_invoices AS
SELECT invoice FROM stg_sales
GROUP BY invoice HAVING COUNT(DISTINCT source_sheet) = 2;
ALTER TABLE overlap_invoices ADD PRIMARY KEY (invoice);

-- One row per raw row, with its classification.
DROP TABLE IF EXISTS sales_classified;
CREATE TABLE sales_classified AS
SELECT
  s.source_sheet,
  s.source_row,
  s.invoice,
  UPPER(TRIM(s.stock_code))      AS stock_code,       -- tidy codes such as '85123a' or '47503J '
  s.description,
  s.quantity,
  s.invoice_date,
  s.price,
  s.customer_id,
  s.country,
  s.is_cancellation,
  ROUND(s.quantity * s.price, 2) AS line_amount,
  CASE
    WHEN s.source_sheet = 2 AND o.invoice IS NOT NULL
      THEN '1 export duplicate (sheet 2 copy)'
    WHEN UPPER(TRIM(s.stock_code)) IN
         ('POST','DOT','C2','C3','M','D','S','BANK CHARGES','ADJUST','ADJUST2',
          'AMAZONFEE','B','CRUK','TEST001','TEST002')
      THEN '2 non-merchandise code'
    WHEN s.is_cancellation = 1
      THEN '3 cancellation (return)'
    WHEN s.price <= 0
      THEN '4 zero or negative price'
    WHEN s.quantity <= 0
      THEN '5 non-positive quantity'
    ELSE NULL                                         -- NULL = kept
  END AS exclusion_reason
FROM stg_sales s
LEFT JOIN overlap_invoices o ON o.invoice = s.invoice;

ALTER TABLE sales_classified ADD PRIMARY KEY (source_sheet, source_row);
CREATE INDEX idx_sc_customer ON sales_classified (customer_id);
CREATE INDEX idx_sc_date     ON sales_classified (invoice_date);

-- Valid merchandise sales (with or without a customer ID): use for revenue totals.
CREATE OR REPLACE VIEW sales_clean AS
SELECT * FROM sales_classified WHERE exclusion_reason IS NULL;

-- Valid sales from identified customers: use for retention and RFM.
CREATE OR REPLACE VIEW sales_customers AS
SELECT * FROM sales_clean WHERE customer_id IS NOT NULL;

-- Customer returns, kept separately (not subtracted from sales).
CREATE OR REPLACE VIEW returns_clean AS
SELECT * FROM sales_classified WHERE exclusion_reason = '3 cancellation (return)';

-- Quick check: must equal 1067371
SELECT COUNT(*) AS classified_rows FROM sales_classified;
