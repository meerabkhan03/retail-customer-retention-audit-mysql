# Findings: data quality and cleaning

Customer-level findings (cohort retention, RFM, revenue concentration) are added to this document when
that analysis is complete. Everything below is reproduced by `sql/03_quality_audit.sql`,
`sql/04_clean_views.sql` and `sql/05_reconciliation.sql`.

## 1. The workbook contains the same data twice

The two worksheets overlap on **1-9 December 2010**. 1,088 invoices appear in both sheets, and every one is
an exact copy (22,202 distinct lines, all with identical counts in both sheets). Removing the second copy
removes **22,523 rows (£377,488.45)**, 2.11% of the raw rows. Without this step, the 1-9 December 2010 sales
would be counted twice.

## 2. Exact duplicates are mostly, but not only, the overlap

There are 32,907 groups of identical lines, with 34,335 surplus rows (3.22% of raw). 22,844 of those surplus
rows sit in the overlap window (identical copies in both sheets); 11,491 are repeats inside a single worksheet.
Removing the sheet-2 overlap copy (22,523 rows) leaves 11,812 surplus lines. 11,731 of them are in the kept data
(£57,092.82, 0.29% of kept amount) and the other 81 belong to rows excluded by other rules. The remaining
repeats are kept because repeated scans of the same item are plausible.

## 3. Roughly one row in four has no customer

22.77% of raw rows (243,007) have no Customer ID. After cleaning, 226,959 kept lines (£2,577,769.63) have none,
so customer-level analysis covers 86.92% of kept merchandise amount (5,852 customers).

## 4. Not every row is a sale

Of 1,067,371 raw rows, 1,015,148 (95.11%) are valid merchandise sales. The rest are export copies, fees and postage,
returns and zero-price rows. Several non-merchandise codes are large: Amazon fees (-£221,520.50), a bad-debt
adjustment (-£147,614.08) and Dotcom postage (£309,844.10). Leaving them in would distort revenue and customer
value materially.

## 5. Returns

17,975 cancellation lines (-£719,762.50) are held in a separate returns view. They cannot be linked to
the original invoice, so they are reported alongside sales rather than netted against individual purchases.

## 6. Where the sales are

Before cleaning, 981,330 of 1,067,371 line items (91.94%) are UK sales; the next largest countries are EIRE,
Germany, France and the Netherlands.

## 7. Reading the raw total

The raw gross line total of £19,287,250.55 mixes sales, returns, fees, postage and duplicate rows. Valid
merchandise sales are **£19,702,710.61**.
