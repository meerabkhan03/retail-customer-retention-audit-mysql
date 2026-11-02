-- =====================================================================
-- 08_rfm_segments.sql
-- Purpose : Customer-level RFM table, rule-based segments, value concentration.
-- Input   : customer_invoices, returns_clean
-- Output  : customer_rfm_base, customer_segments
-- WARNING : DROPs and recreates the two tables above (derived tables).
-- Definitions
--   population       = all customers with >= 1 valid merchandise invoice
--   reference date   = 2011-12-10 (day after the last data point, 2011-12-09)
--   recency          = days from the customer's last invoice to the reference date
--   frequency        = number of valid merchandise invoices
--   gross_monetary   = valid merchandise sales, before returns
--   returns_amount   = that customer's cancellations (returns_clean); returns cannot be
--                      matched to the purchase they reverse
--   net_monetary     = gross_monetary + returns_amount. Value measures (segment value,
--                      spend deciles) use NET, because some large orders were later
--                      cancelled almost entirely (customers 16446 and 12346).
-- Segments are rule-based (not quintile scores) because many customers share the same
-- frequency, which would make tied scores arbitrary.
-- =====================================================================
USE retail_audit;

DROP TABLE IF EXISTS customer_rfm_base;
CREATE TABLE customer_rfm_base AS
SELECT i.customer_id,
       MIN(i.invoice_ts)                                AS first_purchase_ts,
       MAX(i.invoice_ts)                                AS last_purchase_ts,
       DATEDIFF('2011-12-10', DATE(MAX(i.invoice_ts)))  AS recency_days,
       COUNT(*)                                         AS frequency,
       ROUND(SUM(i.invoice_amount), 2)                  AS monetary,
       COALESCE(r.returns_amount, 0)                    AS returns_amount
FROM customer_invoices i
LEFT JOIN (
  SELECT customer_id, ROUND(SUM(line_amount), 2) AS returns_amount
  FROM returns_clean
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
) r ON r.customer_id = i.customer_id
GROUP BY i.customer_id, r.returns_amount;
ALTER TABLE customer_rfm_base ADD PRIMARY KEY (customer_id);

-- V1. Expected: 5852 | 36594 | 17124940.98 | min recency 1 | max recency 739 |
--               min frequency 1 | min monetary 2.95 | returns_total -711640.12
SELECT COUNT(*) AS customers, SUM(frequency) AS invoices, ROUND(SUM(monetary), 2) AS monetary_total,
       MIN(recency_days) AS min_recency, MAX(recency_days) AS max_recency,
       MIN(frequency) AS min_frequency, MIN(monetary) AS min_monetary,
       ROUND(SUM(returns_amount), 2) AS returns_total
FROM customer_rfm_base;

-- V2. Returns of these customers, calculated independently. Expected: -711640.12
SELECT ROUND(SUM(line_amount), 2) AS returns_of_population_customers
FROM returns_clean
WHERE customer_id IN (SELECT customer_id FROM customer_rfm_base);

-- D1. Recency distribution.
-- Expected customers: 1627 | 1258 | 586 | 790 | 1591
SELECT CASE WHEN recency_days <= 30  THEN '1: 0-30 days'
            WHEN recency_days <= 90  THEN '2: 31-90 days'
            WHEN recency_days <= 180 THEN '3: 91-180 days'
            WHEN recency_days <= 365 THEN '4: 181-365 days'
            ELSE '5: over 365 days' END AS recency_band,
       COUNT(*) AS customers, ROUND(SUM(monetary), 2) AS monetary
FROM customer_rfm_base GROUP BY recency_band ORDER BY recency_band;

-- D2. Frequency distribution.
-- Expected customers: 1618 | 945 | 1148 | 1180 | 961
SELECT CASE WHEN frequency = 1 THEN '1 invoice' WHEN frequency = 2 THEN '2 invoices'
            WHEN frequency <= 4 THEN '3-4 invoices' WHEN frequency <= 9 THEN '5-9 invoices'
            ELSE '10+ invoices' END AS frequency_band,
       COUNT(*) AS customers, ROUND(SUM(monetary), 2) AS monetary
FROM customer_rfm_base GROUP BY frequency_band ORDER BY MIN(frequency);

-- D3. Gross spend deciles (decile 1 = highest-spending 10%).
-- Expected: decile 1 = 586 customers, 10927073.96, 63.8 percent
SELECT decile, COUNT(*) AS customers, MIN(monetary) AS min_monetary, MAX(monetary) AS max_monetary,
       ROUND(SUM(monetary), 2) AS monetary,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_total
FROM (SELECT monetary, NTILE(10) OVER (ORDER BY monetary DESC) AS decile FROM customer_rfm_base) t
GROUP BY decile ORDER BY decile;

-- Segments. Thresholds: 90 days (about a quarter; 42 percent of new customers return
-- within 3 months), 365 days (one full seasonal cycle), 5 invoices (36.6 percent of
-- customers, 83.4 percent of gross sales).
DROP TABLE IF EXISTS customer_segments;
CREATE TABLE customer_segments AS
SELECT customer_id, recency_days, frequency,
       monetary                            AS gross_monetary,
       returns_amount,
       ROUND(monetary + returns_amount, 2) AS net_monetary,
       NTILE(10) OVER (ORDER BY monetary + returns_amount DESC) AS spend_decile,
       CASE
         WHEN recency_days > 365 AND frequency >= 5 THEN '6 Lost regular (365+ days, 5+ invoices)'
         WHEN recency_days > 365                    THEN '7 Lost occasional (365+ days, 1-4 invoices)'
         WHEN recency_days > 90  AND frequency >= 5 THEN '4 At risk (91-365 days, 5+ invoices)'
         WHEN recency_days > 90                     THEN '5 Cooling (91-365 days, 1-4 invoices)'
         WHEN frequency >= 5                        THEN '1 Loyal active (within 90 days, 5+ invoices)'
         WHEN frequency >= 2                        THEN '2 Developing (within 90 days, 2-4 invoices)'
         ELSE                                            '3 Recent first-time (within 90 days, 1 invoice)'
       END AS segment
FROM customer_rfm_base;
ALTER TABLE customer_segments ADD PRIMARY KEY (customer_id);

-- T1. Expected: 5852 | 0 | 17124940.98 | 16413300.86 | 20 customers with net <= 0
SELECT COUNT(*) AS customers, SUM(segment IS NULL) AS without_segment,
       ROUND(SUM(gross_monetary), 2) AS gross_total,
       ROUND(SUM(net_monetary), 2) AS net_total,
       SUM(net_monetary <= 0) AS customers_with_net_zero_or_below
FROM customer_segments;

-- T2. Segment summary on net value.
-- Expected customers: 1611 | 907 | 367 | 405 | 971 | 125 | 1466; net adds to 16413300.86;
-- top_decile_customers adds to 586
SELECT segment, COUNT(*) AS customers,
       ROUND(SUM(gross_monetary), 2) AS gross_monetary,
       ROUND(SUM(returns_amount), 2) AS returns_amount,
       ROUND(SUM(net_monetary), 2) AS net_monetary,
       ROUND(100 * SUM(net_monetary) / SUM(SUM(net_monetary)) OVER (), 1) AS pct_of_net,
       ROUND(AVG(frequency), 1) AS avg_invoices,
       ROUND(AVG(net_monetary), 0) AS avg_net_monetary,
       ROUND(AVG(recency_days), 0) AS avg_recency_days,
       SUM(spend_decile = 1) AS top_decile_customers
FROM customer_segments
GROUP BY segment
ORDER BY segment;

-- T3. The two customers whose large orders were almost fully cancelled.
-- Expected: 12346 in segment 5 (net 169.36); 16446 in segment 2 (net 2.90)
SELECT customer_id, segment, frequency, gross_monetary, returns_amount, net_monetary, spend_decile
FROM customer_segments
WHERE customer_id IN (16446, 12346);

-- Concentration -------------------------------------------------------
-- X1. Share of gross sales held by the top 1, 5, 10, 20 and 50 percent of customers.
-- Expected percent of total: 32.0 | 51.9 | 63.8 | 77.1 | 93.5
WITH ranked AS (
  SELECT monetary, ROW_NUMBER() OVER (ORDER BY monetary DESC, customer_id) AS rnk, COUNT(*) OVER () AS n
  FROM customer_rfm_base
),
cutoffs AS (SELECT 1 AS pct UNION ALL SELECT 5 UNION ALL SELECT 10 UNION ALL SELECT 20 UNION ALL SELECT 50)
SELECT c.pct AS top_pct_of_customers,
       SUM(r.rnk <= CEIL(r.n * c.pct / 100)) AS customers,
       ROUND(SUM(CASE WHEN r.rnk <= CEIL(r.n * c.pct / 100) THEN r.monetary END), 2) AS monetary,
       ROUND(100 * SUM(CASE WHEN r.rnk <= CEIL(r.n * c.pct / 100) THEN r.monetary END) / SUM(r.monetary), 1) AS pct_of_total
FROM ranked r CROSS JOIN cutoffs c
GROUP BY c.pct ORDER BY c.pct;

-- X2. Does concentration change after returns? Expected: gross 63.8 / 77.1 / 17124940.98;
--                                                         net   63.2 / 76.7 / 16413300.86
WITH g AS (
  SELECT monetary AS v, ROW_NUMBER() OVER (ORDER BY monetary DESC, customer_id) AS rnk, COUNT(*) OVER () AS n
  FROM customer_rfm_base
),
nt AS (
  SELECT monetary + returns_amount AS v,
         ROW_NUMBER() OVER (ORDER BY monetary + returns_amount DESC, customer_id) AS rnk, COUNT(*) OVER () AS n
  FROM customer_rfm_base
)
SELECT 'gross (before returns)' AS basis,
       ROUND(100 * SUM(CASE WHEN rnk <= CEIL(n * 0.10) THEN v END) / SUM(v), 1) AS top10_pct_share,
       ROUND(100 * SUM(CASE WHEN rnk <= CEIL(n * 0.20) THEN v END) / SUM(v), 1) AS top20_pct_share,
       ROUND(SUM(v), 2) AS total
FROM g
UNION ALL
SELECT 'net (after returns)',
       ROUND(100 * SUM(CASE WHEN rnk <= CEIL(n * 0.10) THEN v END) / SUM(v), 1),
       ROUND(100 * SUM(CASE WHEN rnk <= CEIL(n * 0.20) THEN v END) / SUM(v), 1),
       ROUND(SUM(v), 2)
FROM nt;

-- X3. Are returns concentrated? The ten largest returners.
-- Expected: 16446 (-168469.60, 23.7 percent) and 12346 (-77183.60, 10.8 percent) lead.
SELECT customer_id, returns_amount,
       ROUND(100 * returns_amount / (SELECT SUM(returns_amount) FROM customer_rfm_base), 1) AS pct_of_all_returns,
       monetary
FROM customer_rfm_base
ORDER BY returns_amount ASC
LIMIT 10;
