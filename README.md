# Customer Retention & Data-Quality Audit of a UK Online Retailer (MySQL)

> **Status:** In progress. The data-quality audit is under way; retention and RFM analysis follow.

An end-to-end SQL analysis of about 1.07 million real retail transactions. The project first audits the data and documents every cleaning decision, then measures customer retention and segments customers by recency, frequency and monetary value (RFM).

## Business questions

1. How well does each monthly customer cohort keep buying over time?
2. How concentrated is revenue among the top customers?
3. Which customer segments are at risk, and how much revenue do they represent?

## Dataset

**Online Retail II**, UCI Machine Learning Repository (Daqing Chen), licensed CC BY 4.0.
Transactions of a UK-based online gift-ware retailer, 01/12/2009 to 09/12/2011. Many customers are wholesalers.
Download instructions: [data/README.md](data/README.md).

## Approach

| Step | Script | What happens |
|---|---|---|
| 1 | `sql/01_setup_and_load.sql` | Load the CSV unchanged into a raw, all-text table; add a row ID |
| 2 | `sql/02_staging.sql` | Validate formats, build a typed staging table with flags (nothing deleted) |
| 3 | `sql/03_quality_audit.sql` | Measure data-quality problems |
| 4 | *planned* | Apply documented cleaning rules; prove raw rows = kept rows + excluded rows |
| 5 | *planned* | Cohort retention analysis |
| 6 | *planned* | RFM segmentation and revenue concentration |

## Early findings (audit in progress)

- 1,067,371 rows loaded (525,461 + 541,910 across the two workbook sheets); the count reconciles with the source.
- 22.77% of rows (243,007) have no Customer ID.
- 34,335 surplus exact-duplicate rows; about two-thirds fall on 1-9 December 2010, which is consistent with the two sheets overlapping. Verification is under way.
- Line items reconcile across categories (identified sales, sales without customer ID, cancellations); see [docs/decision_log.md](docs/decision_log.md).

Full results and recommendations will be added when the analysis is complete.

## Repository structure

```
sql/      numbered SQL scripts, run in order
scripts/  CSV conversion script (Python)
docs/     decision log and findings
images/   charts and screenshots
data/     data source notes (the data itself is not stored here)
```

## How to reproduce

1. Download the dataset and convert it (see `data/README.md`).
2. Run the SQL scripts in `sql/` in numerical order on MySQL 8.0 or later.

Requires MySQL 8.0+ (CTEs and window functions), Python 3 with pandas and openpyxl for the conversion step.

## Limitations (preliminary)

- One retailer, two years; many wholesale buyers, so behaviour may differ from typical consumer retail.
- Customers without an ID cannot be included in retention or RFM analysis.
- Revenue figures are in GBP and not adjusted for inflation.

## Attribution

Chen, D. *Online Retail II* [Dataset]. UCI Machine Learning Repository. https://archive.ics.uci.edu/dataset/502/online+retail+ii. CC BY 4.0.
