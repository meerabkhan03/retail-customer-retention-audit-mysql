-- =====================================================================
-- 07_cohort_retention.sql
-- Purpose : Monthly customer cohorts and retention.
-- Input   : customer_invoices
-- Output  : customer_months, customer_cohorts, cohort_retention
-- WARNING : DROPs and recreates the three tables above (derived tables).
-- Definitions
--   cohort            = calendar month of a customer's first valid invoice
--   retention month k = share of the cohort with >= 1 invoice in month (cohort + k)
--                       (not necessarily consecutive months)
--   window            = 2009-12 to 2011-11. December 2011 holds only 9 days, so its
--                       activity is ignored and customers whose first purchase is in
--                       December 2011 are not assigned to a cohort.
--   December 2009     = opening cohort (includes customers already active before the data).
--   Empty (NULL) cells = not yet observable, not zero.
-- =====================================================================
USE retail_audit;

DROP TABLE IF EXISTS customer_months;
CREATE TABLE customer_months AS
SELECT DISTINCT customer_id, invoice_month AS activity_month
FROM customer_invoices
WHERE invoice_month < '2011-12-01';
ALTER TABLE customer_months ADD PRIMARY KEY (customer_id, activity_month);

DROP TABLE IF EXISTS customer_cohorts;
CREATE TABLE customer_cohorts AS
SELECT customer_id, MIN(activity_month) AS cohort_month
FROM customer_months
GROUP BY customer_id;
ALTER TABLE customer_cohorts ADD PRIMARY KEY (customer_id);

-- A complete cohort x month grid, so months with zero activity appear as 0.
DROP TABLE IF EXISTS cohort_retention;
CREATE TABLE cohort_retention AS
WITH RECURSIVE n AS (
  SELECT 0 AS month_index
  UNION ALL
  SELECT month_index + 1 FROM n WHERE month_index < 23
),
sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size
  FROM customer_cohorts GROUP BY cohort_month
),
grid AS (
  SELECT s.cohort_month, s.cohort_size, n.month_index
  FROM sizes s
  JOIN n ON DATE_ADD(s.cohort_month, INTERVAL n.month_index MONTH) <= '2011-11-01'
),
act AS (
  SELECT c.cohort_month,
         TIMESTAMPDIFF(MONTH, c.cohort_month, m.activity_month) AS month_index,
         COUNT(*) AS active_customers
  FROM customer_months m
  JOIN customer_cohorts c ON c.customer_id = m.customer_id
  GROUP BY c.cohort_month, TIMESTAMPDIFF(MONTH, c.cohort_month, m.activity_month)
)
SELECT g.cohort_month, g.month_index, g.cohort_size,
       COALESCE(a.active_customers, 0) AS active_customers,
       ROUND(100 * COALESCE(a.active_customers, 0) / g.cohort_size, 1) AS retention_pct
FROM grid g
LEFT JOIN act a ON a.cohort_month = g.cohort_month AND a.month_index = g.month_index;
ALTER TABLE cohort_retention ADD PRIMARY KEY (cohort_month, month_index);

-- K1. Who is in the cohorts? Expected: 5852 | 5824 | 28
SELECT (SELECT COUNT(DISTINCT customer_id) FROM customer_invoices) AS customers_total,
       (SELECT COUNT(*) FROM customer_cohorts) AS customers_in_cohorts,
       (SELECT COUNT(DISTINCT customer_id) FROM customer_invoices
         WHERE invoice_month >= '2011-12-01'
           AND customer_id NOT IN (SELECT customer_id FROM customer_cohorts)) AS excluded_first_bought_dec_2011;

-- K2. Internal consistency. Expected: 24 cohorts | 0 | 24889 | 24889
SELECT COUNT(DISTINCT cohort_month) AS cohorts,
       SUM(month_index = 0 AND retention_pct <> 100) AS cohorts_not_100_at_month0,
       SUM(active_customers) AS sum_active_cells,
       (SELECT COUNT(*) FROM customer_months) AS customer_months_rows
FROM cohort_retention;

-- K3. Retention table (24 rows; cohort sizes sum to 5824).
SELECT DATE_FORMAT(cohort_month, '%Y-%m') AS cohort, MAX(cohort_size) AS size,
  MAX(CASE WHEN month_index = 1  THEN retention_pct END) AS m1,
  MAX(CASE WHEN month_index = 2  THEN retention_pct END) AS m2,
  MAX(CASE WHEN month_index = 3  THEN retention_pct END) AS m3,
  MAX(CASE WHEN month_index = 6  THEN retention_pct END) AS m6,
  MAX(CASE WHEN month_index = 9  THEN retention_pct END) AS m9,
  MAX(CASE WHEN month_index = 12 THEN retention_pct END) AS m12
FROM cohort_retention
GROUP BY cohort_month
ORDER BY cohort_month;

-- K4. Average retention in month k over new cohorts (Jan 2010 onward).
-- Expected: m1 21.0 | m2 21.5 | m3 21.1 | m6 18.4 | m9 15.0 | m12 18.4
--           (22, 21, 20, 17, 14, 11 cohorts; the cohort set differs by row)
SELECT month_index, COUNT(*) AS cohorts_observed, SUM(cohort_size) AS customers,
       SUM(active_customers) AS active_customers,
       ROUND(100 * SUM(active_customers) / SUM(cohort_size), 1) AS weighted_retention_pct
FROM cohort_retention
WHERE cohort_month > '2009-12-01' AND month_index IN (1, 2, 3, 6, 9, 12)
GROUP BY month_index
ORDER BY month_index;

-- K5. Share of customers who came back at least once within 3, 6 and 12 months.
-- Groups: opening cohort (Dec 2009), early new cohorts (Jan-Jun 2010, may include
-- existing customers), later new cohorts (Jul 2010 onward = the best estimate for
-- genuinely new customers). Only customers with a fully observable window count.
-- Expected (returned %): opening 63.0 / 77.5 / 88.4; Jan-Jun 2010 45.0 / 64.4 / 76.3;
--                        Jul 2010 onward 39.5 / 48.2 / 60.2
SELECT CASE WHEN c.cohort_month = '2009-12-01' THEN 'a: opening cohort (Dec 2009)'
            WHEN c.cohort_month <  '2010-07-01' THEN 'b: new cohorts Jan-Jun 2010'
            ELSE 'c: new cohorts Jul 2010 onward' END AS cohort_group,
       h.n AS within_months,
       COUNT(*) AS eligible_customers,
       SUM(EXISTS (SELECT 1 FROM customer_months m
                   WHERE m.customer_id = c.customer_id
                     AND m.activity_month > c.cohort_month
                     AND m.activity_month <= DATE_ADD(c.cohort_month, INTERVAL h.n MONTH))) AS returned_customers,
       ROUND(100 * SUM(EXISTS (SELECT 1 FROM customer_months m
                   WHERE m.customer_id = c.customer_id
                     AND m.activity_month > c.cohort_month
                     AND m.activity_month <= DATE_ADD(c.cohort_month, INTERVAL h.n MONTH))) / COUNT(*), 1) AS returned_pct
FROM customer_cohorts c
JOIN (SELECT 3 AS n UNION ALL SELECT 6 UNION ALL SELECT 12) h
  ON DATE_ADD(c.cohort_month, INTERVAL h.n MONTH) <= '2011-11-01'
GROUP BY cohort_group, h.n
ORDER BY cohort_group, h.n;
