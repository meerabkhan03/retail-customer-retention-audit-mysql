-- =====================================================================
-- 09_validation_summary.sql
-- Purpose : One query that re-checks the key numbers of the whole project after
--           a complete run of scripts 01 to 08. Read-only.
-- Use     : Run it as a single statement. Every row should show PASS.
--           A FAIL means a script did not run completely or the data differs
--           from the one used in this analysis (see docs/decision_log.md).
-- =====================================================================
USE retail_audit;

SELECT check_name, expected, actual, IF(expected = actual, 'PASS', 'FAIL') AS status
FROM (
SELECT 1 AS n, 'raw rows loaded' AS check_name, CAST(1067371 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM raw_online_retail) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 2 AS n, 'worksheet 1 rows' AS check_name, CAST(525461 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM raw_online_retail WHERE source_sheet = 1) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 3 AS n, 'worksheet 2 rows' AS check_name, CAST(541910 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM raw_online_retail WHERE source_sheet = 2) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 4 AS n, 'staging rows' AS check_name, CAST(1067371 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM stg_sales) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 5 AS n, 'invoices present in both worksheets' AS check_name, CAST(1088 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM overlap_invoices) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 6 AS n, 'excluded: export duplicates' AS check_name, CAST(22523 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM sales_classified WHERE exclusion_reason LIKE '1%') AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 7 AS n, 'excluded: non-merchandise codes' AS check_name, CAST(5712 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM sales_classified WHERE exclusion_reason LIKE '2%') AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 8 AS n, 'excluded: cancellations (returns)' AS check_name, CAST(17975 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM sales_classified WHERE exclusion_reason LIKE '3%') AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 9 AS n, 'excluded: zero or negative price' AS check_name, CAST(6013 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM sales_classified WHERE exclusion_reason LIKE '4%') AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 10 AS n, 'kept: valid merchandise sales' AS check_name, CAST(1015148 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM sales_clean) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 11 AS n, 'gross line total (all rows, GBP)' AS check_name, CAST(19287250.55 AS DECIMAL(16,2)) AS expected, CAST((SELECT ROUND(SUM(line_amount), 2) FROM sales_classified) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 12 AS n, 'kept amount (GBP)' AS check_name, CAST(19702710.61 AS DECIMAL(16,2)) AS expected, CAST((SELECT ROUND(SUM(line_amount), 2) FROM sales_clean) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 13 AS n, 'identified customers' AS check_name, CAST(5852 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(DISTINCT customer_id) FROM customer_invoices) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 14 AS n, 'invoices of identified customers' AS check_name, CAST(36594 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM customer_invoices) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 15 AS n, 'customers assigned to a cohort' AS check_name, CAST(5824 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM customer_cohorts) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 16 AS n, 'monthly cohorts' AS check_name, CAST(24 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(DISTINCT cohort_month) FROM cohort_retention) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 17 AS n, 'customers in segments' AS check_name, CAST(5852 AS DECIMAL(16,2)) AS expected, CAST((SELECT COUNT(*) FROM customer_segments WHERE segment IS NOT NULL) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 18 AS n, 'net customer value (GBP)' AS check_name, CAST(16413300.86 AS DECIMAL(16,2)) AS expected, CAST((SELECT ROUND(SUM(net_monetary), 2) FROM customer_segments) AS DECIMAL(16,2)) AS actual
  UNION ALL SELECT 19 AS n, 'top 10 percent share of gross sales (%)' AS check_name, CAST(63.8 AS DECIMAL(16,2)) AS expected, CAST((SELECT ROUND(100 * SUM(CASE WHEN rnk <= CEIL(n * 0.10) THEN monetary END) / SUM(monetary), 1) FROM (SELECT monetary, ROW_NUMBER() OVER (ORDER BY monetary DESC, customer_id) AS rnk, COUNT(*) OVER () AS n FROM customer_rfm_base) t) AS DECIMAL(16,2)) AS actual
) t
ORDER BY n;
