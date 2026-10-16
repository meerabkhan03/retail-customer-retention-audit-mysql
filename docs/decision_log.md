# Decision log

Every cleaning decision is recorded here with its evidence and its effect.
Rows marked *pending* are waiting for audit results; no decision is made before the numbers are in.

## Findings so far

| Issue | Rows | Share | Observation | Decision | Rationale |
|---|---:|---:|---|---|---|
| Missing Customer ID | 243,007 | 22.77% | 242,257 are normal sales (GBP 3,070,489.25); the rest are cancellations | *pending* | Customers cannot be tracked without an ID, so retention and RFM are likely affected |
| Missing description | 4,382 | 0.41% | Profile being checked (zero price? no customer?) | *pending* | |
| Exact duplicate rows | 34,335 surplus (32,907 groups) | 3.22% | About two-thirds of surplus rows fall on 1-9 Dec 2010, consistent with the two sheets overlapping | *pending* verification (query J) | |
| Leading/trailing spaces in descriptions | to be counted | | Seen in sample rows | Trimmed in staging | Prevents the same product appearing as two descriptions |
| Cancellations | 19,494 | 1.83% | Invoice numbers start with "C"; revenue GBP -1,526,667.86 | *pending* | |
| Zero / negative price | to be completed | | | *pending* | |
| Non-product stock codes | to be completed | | | *pending* | |
| Description inconsistencies | to be completed | | | *pending* | |

## Reconciliation (in progress)

| Category | Line items | Revenue (GBP) |
|---|---:|---:|
| Identified customer sale | 805,620 | 17,743,429.16 |
| No customer ID (not cancelled) | 242,257 | 3,070,489.25 |
| Cancellation | 19,494 | -1,526,667.86 |
| **Total** | **1,067,371** | **19,287,250.55** |

The line-item total equals the raw row count. Revenue here includes every stock code (postage, fees and adjustments included) and is therefore not yet product revenue.
