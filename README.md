# Customer Retention & Data-Quality Audit of a UK Online Retailer (MySQL)

> **Status:** data loading, quality audit, duplicate investigation, cleaning and reconciliation are complete and
> validated. Customer analytics (cohort retention, RFM segmentation, revenue concentration) is in progress; its
> results are added here when finished.

An end-to-end SQL analysis of 1,067,371 real retail transaction lines. The project first proves what is in the
data and documents every cleaning decision, so that the customer analysis that follows rests on a defined,
reconciled population.

## Business questions

1. How well does each monthly customer cohort keep buying over time?
2. Which customers and segments (recency, frequency, monetary value) matter most, and which are at risk?
3. How concentrated is revenue among the highest-value customers?

## Dataset

**Online Retail II**, UCI Machine Learning Repository (Daqing Chen), CC BY 4.0. Transactions of a UK-based online
retailer from 2009-12-01 to 2011-12-09; many customers are wholesalers. Acquisition and conversion steps are in
[`data/README.md`](data/README.md). The data is not stored in this repository.

## Key validated results so far

| Finding | Result |
|---|---|
| Rows loaded (two worksheets) | 1,067,371 (525,461 + 541,910); worksheet lineage checked against the original Excel file |
| Worksheet overlap | 1,088 invoices appear in both sheets, all exact copies (1-9 Dec 2010); 22,523 rows removed |
| Exact duplicates | 32,907 groups, 34,335 surplus rows (3.22%); 22,844 are the overlap |
| Missing Customer ID | 243,007 rows (22.77%) |
| Cancellations | 19,494 rows (1.83%) |
| Valid merchandise sales kept | 1,015,148 rows (95.11%), £19,702,710.61 |
| Identified customers among kept sales | 5,852 customers, covering 86.92% of kept amount |

Every raw row is accounted for: 1,067,371 raw rows = 22,523 export copies + 5,712 non-merchandise rows + 17,975
cancellations + 6,013 zero-price rows + 1,015,148 kept rows. The full reconciliation, the cleaning rules and their
evidence are in [`docs/decision_log.md`](docs/decision_log.md); the data-quality findings are in
[`docs/findings.md`](docs/findings.md).

## How the data is protected from silent errors

* **Lineage is stored, not inferred.** The conversion script writes `source_sheet` and `source_row` into the CSV.
* **Raw data is never edited.** It is loaded as text, then typed into a staging table, then classified.
* **One reason per row.** Every row is either kept or excluded for exactly one documented reason.
* **Reconciliation is built in.** `sql/05_reconciliation.sql` checks that rows and amounts add up at every stage.

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

Customer analytics scripts (cohort retention, RFM) follow once that phase is complete.

## How to reproduce

1. **Prerequisites:** MySQL 8.0 or later (CTEs and window functions), MySQL Workbench, Python 3 with `pandas` and `openpyxl`.
2. **Get and convert the data** following [`data/README.md`](data/README.md).
3. **Workbench settings:** in the connection's *Advanced* tab, add `OPT_LOCAL_INFILE=1` under *Others*; under
   *Edit > Preferences > SQL Editor*, raise *DBMS connection read timeout* to 600 seconds (the duplicate and
   reconciliation queries scan over a million rows).
4. **Run** scripts 01 to 05 in order (*File > Open SQL Script*, then the lightning-bolt button). Edit the CSV path
   in `01_setup_and_load.sql` first.
5. **Check** the "Expected" values written in the comments of each script and in `05_reconciliation.sql`.

Developed on MySQL 8.0.45 for Windows with MySQL Workbench.

## Repository structure

```
README.md
LICENSE
data/README.md          source, licence, how to obtain and convert the data
scripts/convert_to_csv.py
sql/                    numbered SQL scripts (run in order)
docs/decision_log.md    cleaning rules, evidence, reconciliation
docs/findings.md        data-quality findings
images/                 charts (added with the customer analysis)
```

## Limitations

* One retailer over two years; many wholesale customers, so behaviour may differ from typical consumer retail.
* 22.36% of kept lines have no Customer ID and cannot be followed over time.
* Returns cannot be matched to the original purchase.
* The first month (December 2009) may include customers who were already active; the last month (December 2011) is partial.
* Amounts are in GBP and not adjusted for inflation.

## Attribution

Chen, D. *Online Retail II* [Dataset]. UCI Machine Learning Repository.
https://archive.ics.uci.edu/dataset/502/online+retail+ii. Licensed under CC BY 4.0.
This repository is released under the MIT licence (see `LICENSE`).
