# Customer Retention & Data-Quality Audit of a UK Online Retailer (MySQL)

> **Status:** data audit, cleaning and reconciliation, cohort retention, RFM segmentation and revenue concentration are
> complete and validated. Charts and a short written summary for non-technical readers are being added.

An end-to-end SQL analysis of 1,067,371 real retail transaction lines. The project first proves what is in the data and
documents every cleaning decision, then measures customer retention, segments customers by recency, frequency and value,
and shows how concentrated sales are.

## Business questions

1. How well does each monthly customer cohort keep buying over time?
2. Which customers and segments matter most, and which are at risk?
3. How concentrated is revenue among the highest-value customers?

## Dataset

**Online Retail II**, UCI Machine Learning Repository (Daqing Chen), CC BY 4.0. Transactions of a UK-based online
retailer from 2009-12-01 to 2011-12-09; many customers are wholesalers. Acquisition and conversion steps are in
[`data/README.md`](data/README.md). The data is not stored in this repository.

## Key validated results

**Data quality** (details: [`docs/decision_log.md`](docs/decision_log.md))

| Finding | Result |
|---|---|
| Rows loaded (two worksheets) | 1,067,371 (525,461 + 541,910); worksheet lineage checked against the original Excel file |
| Worksheet overlap | 1,088 invoices appear in both sheets as exact copies (1-9 Dec 2010); 22,523 rows removed |
| Missing Customer ID | 243,007 rows (22.77%) |
| Valid merchandise sales kept | 1,015,148 rows (95.11%), £19,702,710.61 |
| Reconciliation | 22,523 export copies + 5,712 non-merchandise + 17,975 cancellations + 6,013 zero-price + 1,015,148 kept = 1,067,371 |

**Customers** (details: [`docs/findings.md`](docs/findings.md))

| Finding | Result |
|---|---|
| Customers analysed | 5,852 identified customers, 36,594 invoices, £16.41M net value |
| Retention, genuinely new customers | About 21% buy in any given month; about 40% return within 3 months, 48% within 6, 60% within 12 |
| Segments | 27.5% of customers (Loyal active) hold 74.7% of net value and 512 of the 586 top-decile customers |
| At risk | 405 regular customers silent for 91-365 days, £1.22M historical net value; 70 of the 586 top spenders have not bought in 90 days |
| Concentration | Top 1% of customers = 32.0% of sales; top 10% = 63.8%; top 20% = 77.1% (63.2% and 76.7% after returns) |
| Returns | Two almost-fully-cancelled orders make up 34.5% of all customer returns, so value uses net, not gross, sales |

## How the data is protected from silent errors

* **Lineage is stored, not inferred.** The conversion script writes `source_sheet` and `source_row` into the CSV.
* **Raw data is never edited.** It is loaded as text, typed into a staging table, then classified.
* **One reason per row.** Every row is either kept or excluded for exactly one documented reason.
* **Every layer reconciles to the one before it,** with the expected values written in the scripts.

## Workflow and scripts

Run the scripts in order. Each header states what it creates and what it replaces.

| Script | Purpose | Creates |
|---|---|---|
| `scripts/convert_to_csv.py` | Convert the workbook to one CSV with lineage columns | CSV (outside the repository) |
| `sql/01_setup_and_load.sql` | Load the CSV unchanged into a text table | `raw_online_retail` |
| `sql/02_staging.sql` | Validate formats and build a typed table | `stg_sales` |
| `sql/03_quality_audit.sql` | Measure data-quality problems; investigate duplicates and the overlap | `dup_groups` (helper) |
| `sql/04_clean_views.sql` | Apply the cleaning rules, one classification per row | `overlap_invoices`, `sales_classified`, views `sales_clean`, `sales_customers`, `returns_clean` |
| `sql/05_reconciliation.sql` | Prove nothing was lost or double-counted | (read-only checks) |
| `sql/06_customer_base.sql` | One row per invoice for identified customers | `customer_invoices` |
| `sql/07_cohort_retention.sql` | Monthly cohorts and retention | `customer_months`, `customer_cohorts`, `cohort_retention` |
| `sql/08_rfm_segments.sql` | RFM table, segments, concentration | `customer_rfm_base`, `customer_segments` |

## How to reproduce

1. **Prerequisites:** MySQL 8.0 or later (CTEs and window functions), MySQL Workbench, Python 3 with `pandas` and `openpyxl`.
2. **Get and convert the data** following [`data/README.md`](data/README.md).
3. **Workbench settings:** in the connection's *Advanced* tab, add `OPT_LOCAL_INFILE=1` under *Others*; under
   *Edit > Preferences > SQL Editor*, raise *DBMS connection read timeout* to 600 seconds (several queries scan over a
   million rows).
4. **Run** scripts 01 to 08 in order (*File > Open SQL Script*, then the lightning-bolt button). Edit the CSV path in
   `01_setup_and_load.sql` first. Run the statements of scripts 05 to 08 that begin with a comment such as `R1.` or `K3.`
   one at a time (click inside, then Ctrl+Enter) and compare them with the "Expected" values in the comments.

Developed on MySQL 8.0.45 for Windows with MySQL Workbench.

## Repository structure

```
README.md
LICENSE
data/README.md          source, licence, how to obtain and convert the data
scripts/convert_to_csv.py
sql/                    numbered SQL scripts (run in order)
results/                validated result tables copied from the queries (see results/README.md)
docs/decision_log.md    cleaning rules, definitions, evidence, reconciliation
docs/findings.md        data-quality and customer findings
images/                 charts
```

## Limitations

* One retailer over two years; many wholesale customers, so behaviour may differ from typical consumer retail.
* 13.1% of kept sales have no Customer ID and cannot be followed over time.
* Returns cannot be matched to the original purchase; value uses net sales per customer.
* The first month (December 2009) and the early 2010 cohorts include customers who were already active; December 2011 is a partial month.
* Retention and segments are descriptive snapshots, not forecasts; the recommendations in `docs/findings.md` are untested hypotheses.
* Amounts are in GBP and not adjusted for inflation.

## Attribution

Chen, D. *Online Retail II* [Dataset]. UCI Machine Learning Repository.
https://archive.ics.uci.edu/dataset/502/online+retail+ii. Licensed under CC BY 4.0.
This repository is released under the MIT licence (see `LICENSE`).
