# Decision log

Every cleaning decision, the evidence behind it, and its measured effect.
All figures were produced by the scripts in `sql/` and verified by the reconciliation checks in
`sql/05_reconciliation.sql`. Amounts are in GBP.

## 1. Method correction: worksheet lineage

Worksheet membership was first inferred from the order in which MySQL stored rows. A boundary check
showed this was unreliable (rows dated January 2011 appeared in "sheet 1", and the Excel file disagreed).
Lineage is now written into the data itself: `scripts/convert_to_csv.py` adds `source_sheet` and
`source_row`, and the per-sheet row counts, date ranges and boundary rows were checked against the original
workbook. **Rule: provenance is stored, never inferred from storage order.** All overlap results below use
the explicit lineage columns.

## 2. Rules, in the order they are applied

Each raw row receives exactly **one** classification: the first rule that matches. The order matters
for the counts, because a row that breaks several rules is counted only once.

| # | Rule | Rationale | Evidence |
|---|---|---|---|
| 1 | Exclude the **worksheet-2 copy** of any invoice that also appears in worksheet 1 | The workbook exports 1-9 Dec 2010 twice; a copy is not a second business event | 1,088 invoices in both sheets, all identical in line count and value; line-by-line proof: 22,202 distinct lines, 22,202 matching, 0 mismatching; the window is fully covered (0 rows outside the overlap in either sheet) |
| 2 | Exclude **non-merchandise stock codes** (explicit list below) | Postage, fees, adjustments and test codes are not customers buying products | Codes reviewed one by one with counts and amounts; the kept data contains only genuine products, gift vouchers and the shop's `DCGS` items |
| 3 | Classify **cancellations** (invoice starts with `C`) as returns, kept in a separate view | A return is not a purchase, and subtracting it inside the sales table would hide the original purchase | 19,494 cancellation rows in the raw data |
| 4 | Exclude rows with **price of zero or below** | No sale value; 4,261 of the 6,013 rows have no description and 5,935 have no customer, which points to stock adjustments rather than sales | 6,225 rows (6,220 zero, 5 negative) |
| 5 | Exclude rows with **non-positive quantity** (safety net) | A sale needs a positive quantity | Matched 0 rows: every negative-quantity row without a `C` was already caught by an earlier rule |

Stock codes are tidied with `UPPER(TRIM())` (for example `85123a` and `47503J ` are normalised), and
descriptions are trimmed (213,035 raw rows had leading or trailing spaces).

## 3. Result of the rules

| Category | Line items | Share of raw | Amount (GBP) |
|---|---:|---:|---:|
| 1 Export duplicate (sheet-2 copy) | 22,523 | 2.11% | £377,488.45 |
| 2 Non-merchandise code | 5,712 | 0.54% | -£73,186.01 |
| 3 Cancellation (return) | 17,975 | 1.68% | -£719,762.50 |
| 4 Zero or negative price | 6,013 | 0.56% | £0.00 |
| **Kept: valid merchandise sales** | **1,015,148** | **95.11%** | **£19,702,710.61** |
| **Total (raw)** | **1,067,371** | **100%** | **£19,287,250.55** |

Check: the line items add up to the raw row count, and the amounts add up to the raw total.
The raw total of £19,287,250.55 is a **mixed gross line total** (merchandise, returns, fees, postage, duplicates).
It must not be called revenue.

## 4. Non-merchandise codes excluded (rule 2)

| Stock code | Meaning | Line items | Amount (GBP) |
|---|---|---:|---:|
| `POST` | Postage | 2,086 | £110,430.41 |
| `DOT` | Dotcom postage | 1,425 | £309,844.10 |
| `M` | Manual | 1,403 | -£82,935.57 |
| `C2` | Carriage | 277 | £13,136.00 |
| `D` | Discount | 173 | -£12,879.63 |
| `S` | Samples | 102 | -£6,000.85 |
| `BANK CHARGES` | Bank charges | 100 | -£35,482.25 |
| `ADJUST` | Adjustment | 67 | £6,835.24 |
| `AMAZONFEE` | Amazon fee | 36 | -£221,520.50 |
| `CRUK` | Commission | 16 | -£7,933.43 |
| `TEST001` | Test product | 15 | £202.50 |
| `B` | Adjust bad debt | 6 | -£147,614.08 |
| `ADJUST2` | Adjustment | 3 | £731.05 |
| `TEST002` | Test product | 2 | £1.00 |
| `C3` | (blank) | 1 | £0.00 |

These counts are lower than in the raw audit for some codes (for example `AMAZONFEE`: 43 rows in the audit,
36 here) because rows already removed as export duplicates are not counted again.

## 5. Decisions about problems that are NOT excluded

| Issue | Rows | Decision | Why |
|---|---:|---|---|
| Missing Customer ID | 243,007 (22.77% of raw) | **Keep** in merchandise sales totals; **exclude from customer-level analysis** | A missing ID does not make a sale invalid, but the buyer cannot be followed over time. 226,959 kept lines (£2,577,769.63, 13.08% of kept sales value) have no ID |
| Repeated identical lines inside one invoice | 11,731 surplus lines, £57,092.82 (0.29% of kept sales value) | **Keep** | Cannot be shown to be errors (a customer can scan an item twice). They cannot change cohort membership or retention, frequency counts distinct invoices, and the effect on monetary value is at most 0.29% |
| Missing description | 4,382 | No separate rule | All of them are zero-price rows (rule 4) or were removed by rules 1 and 2 |
| Invoices with more than one timestamp | 82 of 39,516 kept invoices | Resolved at invoice level in the customer analysis | Each invoice has one customer and one country; only the timestamp can differ between lines |
| Gift vouchers (`GIFT_0001_*`), shop items (`DCGS*`) | 7 voucher codes, £1,756.17 | **Keep** | Customers buy them; the amount is immaterial either way |

## 6. Remaining limitations

* 226,959 kept lines (22.36%) cannot be attributed to a customer; customer analytics cover
  86.92% of kept merchandise amount and 5,852 identified customers.
* Cancellations cannot be matched to the original purchase, so returns are measured, not netted line by line.
* The dataset covers one UK retailer, many of whose customers are wholesalers, from 2009-12-01 to 2011-12-09.
  December 2009 may contain customers who were already active earlier, and December 2011 is a partial month.
* An early check suggested that six overlapping invoices differed between the sheets. That came from the
  unreliable lineage method (section 1); with correct lineage all 1,088 are identical.

---

# Customer analysis decisions

## 7. Definitions

| Item | Decision | Why |
|---|---|---|
| Population | Customers with at least one valid merchandise invoice (`sales_customers`): 5,852 | Customers without an ID cannot be followed; customers with only returns have no purchase to analyse |
| Unit of analysis | The invoice (`customer_invoices`: 36,594 invoices) | Retention and frequency count shopping trips, not lines; repeated lines cannot distort them |
| Invoice date | Earliest line timestamp | 64 of these invoices have more than one timestamp (at most 2 minutes apart) and none crosses a month boundary |
| Cohort | Month of the first valid invoice | Standard definition; observed window December 2009 to November 2011 |
| Retention at month k | Share of the cohort with at least one invoice in month cohort+k | Customers order irregularly, so "bought every month" would be misleading |
| "Returned within N months" | At least one invoice in months 1 to N; only cohorts with N fully observable months | Fair comparison across cohorts of different age |
| December 2011 | Activity ignored; 28 customers whose first purchase was in December 2011 have no cohort | The month has only 9 days of data |
| December 2009 | Labelled the opening cohort | Includes customers already active before the data starts |
| RFM reference date | 2011-12-10 | The day after the last data point |
| Frequency | Count of valid merchandise invoices | |
| Monetary | **Net** value: gross sales plus the customer's returns | See section 8 |
| Segments | Rule-based on recency (90 and 365 days) and frequency (5 invoices), not quintile scores | Many customers share the same frequency, so tied quintile scores would be arbitrary |

## 8. Change of definition: net instead of gross monetary

Monetary was first defined as gross sales, with returns stored separately. The ten largest returners showed that customers
16446 and 12346 had placed orders worth £168,472.50 and £77,352.96 that were almost entirely cancelled (returns of
-£168,469.60 and -£77,183.60). Gross monetary counted them as top customers although their net value was £2.90 and £169.36,
and they made returns look abnormally high in the Developing and Cooling segments.

**Decision:** value measures (segment value, spend deciles) use net monetary. Gross is reported next to it.
**Effect:** segment sizes are unchanged (recency and frequency are unaffected); total value falls from £17,124,940.98 to £16,413,300.86;
the concentration conclusion barely moves (top 10%: 63.8% gross, 63.2% net).
**Limitation:** returns cannot be matched to the purchase they reverse, so 20 customers have a net value of zero or below;
they remain in the population.

## 9. Validation of the customer layer

Each table was reconciled to the layer before it: `customer_invoices` equals `sales_customers` (788,189 lines, £17,124,940.98,
5,852 customers); the retention grid counts every customer-month exactly once (24,889 cells for 24,889 customer-months);
cohort sizes add up to 5,824 plus 28 excluded customers; segments contain every customer exactly once and add up to the
net total (£16,413,300.86); segment returns add up to -711,640.12.

