# Results

Small tables copied from the result grids of the SQL queries in `sql/` (the query is named in the table below).
They are the validated outputs on the full dataset and are provided so the findings can be read without
re-running the project. Re-running the scripts reproduces them; the expected values are also written in
the SQL comments.

| File | Produced by |
|---|---|
| `cleaning_reconciliation.csv` | `sql/05_reconciliation.sql`, R2 |
| `cohort_retention_selected_months.csv` | `sql/07_cohort_retention.sql`, K3 |
| `retention_average_new_cohorts.csv` | `sql/07_cohort_retention.sql`, K4 |
| `returned_within_months.csv` | `sql/07_cohort_retention.sql`, K5 |
| `rfm_distributions_gross.csv` | `sql/08_rfm_segments.sql`, D1 and D2 |
| `spend_deciles_gross.csv` | `sql/08_rfm_segments.sql`, D3 |
| `segment_summary.csv` | `sql/08_rfm_segments.sql`, T2 |
| `concentration_gross.csv` | `sql/08_rfm_segments.sql`, X1 |
| `concentration_gross_vs_net.csv` | `sql/08_rfm_segments.sql`, X2 |
| `top_returners.csv` | `sql/08_rfm_segments.sql`, X3 |

Amounts are in GBP. Empty cells in the cohort table mean "not yet observable", not zero.
