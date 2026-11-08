# Findings

Part A (sections 1-7) describes what is in the data and how it was cleaned; part B (sections 8-14) describes
the customers. Everything is reproduced by `sql/03_quality_audit.sql` to `sql/08_rfm_segments.sql`; small result
tables are in [`../results/`](../results/). Amounts are in GBP.

## 1. The workbook contains the same data twice

The two worksheets overlap on **1-9 December 2010**. 1,088 invoices appear in both sheets, and every one is
an exact copy (22,202 distinct lines, all with identical counts in both sheets). Removing the second copy
removes **22,523 rows (£377,488.45)**, 2.11% of the raw rows. Without this step, the 1-9 December 2010 sales
would be counted twice.

## 2. Exact duplicates are mostly, but not only, the overlap

There are 32,907 groups of identical lines, with 34,335 surplus rows (3.22% of raw). 22,844 of those surplus
rows sit in the overlap window (identical copies in both sheets); 11,491 are repeats inside a single worksheet.
Removing the sheet-2 overlap copy (22,523 rows) leaves 11,812 surplus lines. 11,731 of them are in the kept data
(£57,092.82, 0.29% of kept sales value) and the other 81 belong to rows excluded by other rules. The remaining
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

---

# Part B: customers

## 8. Who is analysed

The customer analysis covers the **5,852 customers** with at least one valid merchandise invoice (36,594 invoices,
£17,124,940.98 of sales before returns, £16,413,300.86 after returns). Rows without a Customer ID cannot be followed
over time and are outside this analysis (13.1% of kept sales value, 22.4% of kept lines). Every measure counts invoices, not lines.

## 9. Retention: customers come back, but irregularly

Customers are grouped into monthly cohorts by the month of their first valid invoice (December 2009 to November 2011;
December 2011 is a partial month).

* **In any single month, about one new customer in five buys again** (21.0% in month 1, 21.5% in month 2, 21.1% in month 3,
  falling to 18.4% in month 6 and 15.0% in month 9). The month-9 and month-12 averages use different sets of cohorts,
  so they are not directly comparable.
* **Over a window, far more come back:** among genuinely new customers (cohorts from July 2010), about **40% return within
  3 months, 48% within 6 and 60% within 12**. About 60% of new customers did not come back within three months.
  The 12-month figure rests on five autumn cohorts (1,288 customers).
* **The early 2010 cohorts look better than they probably are.** Cohorts from January to June 2010 return more
  (45.0%, 64.4%, 76.3% within 3, 6, 12 months), which is consistent with some of them being existing customers who simply
  had not bought yet in the data. The December 2009 opening cohort returns most (63.0%, 77.5%, 88.4%).
* **Single-month rates can be misleading:** many cohorts return more in months 2 and 3 than in month 1, which suggests
  customers who order in bursts rather than monthly. Retention also follows the calendar: in the audit's invoice counts by month, November is the busiest
  month and January and February are among the quietest, so cohorts measured at the same age are measured in different seasons.
* Cohorts from winter 2010-11 are small (72 to 125 customers), so their percentages are volatile.

## 10. Customer segments (RFM)

Recency is measured at 10 December 2011, frequency is the number of invoices, and value is **net** of the customer's returns.
Segments use thresholds rather than quintile scores: 90 days, 365 days (one seasonal cycle) and 5 invoices
(36.6% of customers produce 83.4% of gross sales).

| Segment | Rule | Customers | % of customers | Net value | % of net value | Avg invoices | Avg net value per customer | Avg days since last order | Top-decile customers |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 Loyal active | within 90 days, 5+ invoices | 1,611 | 27.5% | £12,263,762.23 | 74.7% | 15.3 | £7,613 | 27 | 512 |
| 2 Developing | within 90 days, 2-4 invoices | 907 | 15.5% | £891,509.26 | 5.4% | 2.9 | £983 | 36 | 4 |
| 3 Recent first-time | within 90 days, 1 invoice | 367 | 6.3% | £135,953.64 | 0.8% | 1.0 | £370 | 45 | 0 |
| 4 At risk | 91-365 days, 5+ invoices | 405 | 6.9% | £1,223,407.90 | 7.5% | 8.5 | £3,021 | 182 | 48 |
| 5 Cooling | 91-365 days, 1-4 invoices | 971 | 16.6% | £718,751.38 | 4.4% | 2.1 | £740 | 216 | 5 |
| 6 Lost regular | over 365 days, 5+ invoices | 125 | 2.1% | £432,348.56 | 2.6% | 9.2 | £3,459 | 444 | 12 |
| 7 Lost occasional | over 365 days, 1-4 invoices | 1,466 | 25.1% | £747,567.89 | 4.6% | 1.6 | £510 | 506 | 5 |

* **Loyal active customers are the business:** 27.5% of customers, 74.7% of net value, and 512 of the 586 top-decile customers.
* **At risk and lost regular customers** (530 customers who bought often but have been silent for 91 days or more) represent
  £1,655,756.46 of historical net value (10.1%).
* **70 of the 586 top-decile customers (11.9%) have not bought within the last 90 days.**
* **Developing customers** (907) average 2.9 invoices and £983 each and are the pool from which new regulars could come.
* **Lost occasional customers are numerous (25.1%) but low in value** (4.6% of net value).
* Half of all customers (49.3%) bought in the last 90 days, but the snapshot falls right after the autumn peak.

## 11. Concentration

| Top share of customers | Customers | Share of gross sales to identified customers |
|---|---:|---:|
| 1% | 59 | 32.0% |
| 5% | 293 | 51.9% |
| 10% | 586 | 63.8% |
| 20% | 1,171 | 77.1% |
| 50% | 2,926 | 93.5% |

After subtracting returns, the top 10% hold 63.2% and the top 20% hold 76.7%, so the conclusion does not depend on how
returns are treated. The bottom half of customers account for 6.5% of gross sales. The largest customer alone is
£580,987.04 (3.4% of gross sales).

## 12. Returns: two almost-fully-cancelled orders

Returns are concentrated: customers 16446 (-£168,469.60) and 12346 (-£77,183.60) account for
34.5% of the returns of identified customers, and the ten largest returners for 51.3%. Both customers' large orders
(gross £168,472.50 and £77,352.96) were almost entirely cancelled, so their net values are £2.90 and £169.36.
They sat in the Developing and Cooling segments and made returns look unusually large there (18.0% and 13.8% of sales);
without these two customers the ratios are 3.0% and 5.0%, in line with the other segments. For this reason value
measures use net monetary rather than gross. Returns cannot be matched to the purchase they reverse, and 20 customers
have a net value of zero or below.

## 13. Hypotheses for action

These follow from the numbers but have not been tested; the data contains no information about costs, campaigns or response.

1. **Protect the loyal core.** Assign account owners to the top-decile customers and watch days since last order for them.
2. **Contact the 70 silent top-decile customers first**, then the other at-risk regulars (405 customers, £1.22M historical net value).
3. **Move Developing customers towards regular status** with reminders timed before the autumn peak.
4. **Aim a second-purchase prompt at new customers within their first 90 days:** most return, if at all, within three months, and about 60% do not.
5. **Use low-cost automation for Cooling and Lost occasional customers;** they are many but low in value.
6. **Capture the Customer ID on every order** (13.1% of kept sales value, or 22.4% of kept lines, has no customer ID) **and link returns to the original invoice.**

## 14. What these results cannot say

* They describe one retailer with many wholesale customers over two years; they are not forecasts.
* Retention is descriptive: it says who came back, not why.
* The first month (December 2009) and the early 2010 cohorts are contaminated by existing customers; December 2011 is a partial month.
* Returns are measured at customer level only; they cannot be matched to purchases.
