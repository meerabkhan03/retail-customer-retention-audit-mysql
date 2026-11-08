"""Create the charts in images/ from the validated result tables in results/.

Usage (from the repository root):
    pip install pandas matplotlib
    python scripts/make_charts.py

The charts only read the small CSV files in results/ (copied from the SQL query results),
so they can be regenerated without MySQL.
"""
from pathlib import Path

import matplotlib
import matplotlib.ticker
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RES, IMG = ROOT / "results", ROOT / "images"
IMG.mkdir(exist_ok=True)

BLUE, ORANGE, GREY, DARK = "#2b6cb0", "#dd8452", "#9aa5b1", "#222222"
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.titleweight": "bold", "axes.titlesize": 12, "figure.dpi": 150})
SOURCE = "Source: UCI Online Retail II (CC BY 4.0); results of sql/ scripts"


def save(fig, name):
    fig.savefig(IMG / name, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("saved", name)


# 1. Where the 1,067,371 raw rows went ------------------------------------------------
rec = pd.read_csv(RES / "cleaning_reconciliation.csv")
raw_rows = int(rec["line_items"].sum())
excl = rec[~rec["category"].str.startswith("KEPT")].copy()
kept = int(rec.loc[rec["category"].str.startswith("KEPT"), "line_items"].iloc[0])
excl["label"] = excl["category"].str.replace(r"^\d ", "", regex=True)
excl = excl.sort_values("line_items")
fig, ax = plt.subplots(figsize=(9, 3.8))
bars = ax.barh(excl["label"], excl["line_items"], color=GREY)
for b, n in zip(bars, excl["line_items"]):
    ax.text(n + 250, b.get_y() + b.get_height() / 2, f"{n:,}  ({100 * n / raw_rows:.2f}% of raw rows)",
            va="center", fontsize=9)
ax.set_xlim(0, excl["line_items"].max() * 1.6)
ax.set_xlabel("Rows excluded")
ax.set_title(f"Of {raw_rows:,} raw rows, {kept:,} ({100 * kept / raw_rows:.1f}%) are kept; the rest are excluded")
ax.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{int(v):,}"))
fig.text(0.01, -0.04, "Each row has exactly one reason (first rule that applies). " + SOURCE, fontsize=8, color="#555")
save(fig, "01_rows_excluded_by_reason.png")

# 2. Cohort retention heatmap ----------------------------------------------------------
c = pd.read_csv(RES / "cohort_retention_selected_months.csv")
cols = ["m1_pct", "m2_pct", "m3_pct", "m6_pct", "m9_pct", "m12_pct"]
mat = np.ma.masked_invalid(c[cols].to_numpy(dtype=float))
fig, ax = plt.subplots(figsize=(8.2, 8.6))
cmap = plt.get_cmap("YlGnBu").copy()
cmap.set_bad("#f1f3f5")
im = ax.imshow(mat, cmap=cmap, vmin=0, vmax=45, aspect="auto")
ax.set_xticks(range(6), ["Month 1", "Month 2", "Month 3", "Month 6", "Month 9", "Month 12"])
ax.set_yticks(range(len(c)), [f"{m}  (n={n})" for m, n in zip(c["cohort_month"], c["cohort_size"])])
ax.xaxis.tick_top()
for i in range(mat.shape[0]):
    for j in range(mat.shape[1]):
        if not mat.mask[i, j]:
            ax.text(j, i, f"{mat[i, j]:.0f}", ha="center", va="center", fontsize=7,
                    color="white" if mat[i, j] > 27 else DARK)
ax.axhline(0.5, color="white", lw=3)
ax.set_title("Share of each cohort that bought again in month k (%)", pad=34)
cb = fig.colorbar(im, ax=ax, shrink=0.5, pad=0.02)
cb.set_label("% of cohort")
fig.text(0.01, 0.045, "Grey = not yet observable. December 2009 (top row) is the opening cohort and includes customers\n"
         "who were already active; early 2010 cohorts may too. Cohorts of 72-125 customers are volatile.\n" + SOURCE,
         fontsize=8, color="#555")
save(fig, "02_cohort_retention_heatmap.png")

# 3. Returned within N months ----------------------------------------------------------
r = pd.read_csv(RES / "returned_within_months.csv")
groups = [("a: opening cohort (Dec 2009)", "Opening cohort (Dec 2009)", GREY),
          ("b: new cohorts Jan-Jun 2010", "New cohorts Jan-Jun 2010", ORANGE),
          ("c: new cohorts Jul 2010 onward", "New cohorts Jul 2010 onward", BLUE)]
fig, ax = plt.subplots(figsize=(8.5, 4.8))
x = np.arange(3)
w = 0.26
for k, (key, label, color) in enumerate(groups):
    vals = r[r["cohort_group"] == key].sort_values("within_months")["returned_pct"].to_numpy()
    bars = ax.bar(x + (k - 1) * w, vals, w, label=label, color=color)
    for b, v in zip(bars, vals):
        ax.text(b.get_x() + b.get_width() / 2, v + 1, f"{v:.1f}%", ha="center", fontsize=9)
ax.set_xticks(x, ["within 3 months", "within 6 months", "within 12 months"])
ax.set_ylim(0, 100)
ax.set_ylabel("% of customers who bought again")
ax.legend(frameon=False, loc="upper left")
ax.set_title("How many customers came back at least once?")
fig.text(0.01, -0.06, "Only customers whose full window is observable. July 2010 onward is the best estimate for genuinely new\n"
         "customers (12-month bar: five autumn cohorts, 1,288 customers). " + SOURCE, fontsize=8, color="#555")
save(fig, "03_customers_returning_within_n_months.png")

# 4. Segments: share of customers vs share of net value --------------------------------
s = pd.read_csv(RES / "segment_summary.csv")
s["name"] = s["segment"].str.replace(r"\s*\(.*\)$", "", regex=True)
pc = 100 * s["customers"] / s["customers"].sum()
pv = 100 * s["net_monetary"] / s["net_monetary"].sum()
fig, ax = plt.subplots(figsize=(9, 5))
y = np.arange(len(s))[::-1]
ax.barh(y + 0.19, pc, 0.38, color=GREY, label="% of customers")
ax.barh(y - 0.19, pv, 0.38, color=BLUE, label="% of net value")
for yy, a, b in zip(y, pc, pv):
    ax.text(a + 0.8, yy + 0.19, f"{a:.1f}%", va="center", fontsize=8)
    ax.text(b + 0.8, yy - 0.19, f"{b:.1f}%", va="center", fontsize=8)
ax.set_yticks(y, s["name"])
ax.set_xlim(0, 85)
ax.set_xlabel("%")
ax.legend(frameon=False, loc="lower right")
ax.set_title("Customer segments: share of customers vs share of net value")
fig.text(0.01, -0.07, "Net value = sales minus the customer's returns. Recency measured at 10 Dec 2011; 5,852 identified customers.\n"
         "Active = bought within 90 days; At risk / Cooling = 91-365 days; Lost = over 365 days; regular = 5+ invoices.\n" + SOURCE,
         fontsize=8, color="#555")
save(fig, "04_segments_customers_vs_value.png")

# 5. Concentration curve ---------------------------------------------------------------
d = pd.read_csv(RES / "spend_deciles_gross.csv").sort_values("decile")
k = pd.read_csv(RES / "concentration_gross.csv")
dec_x = np.arange(10, 101, 10)
dec_y = 100 * d["gross_monetary"].cumsum().to_numpy() / d["gross_monetary"].sum()
extra = k[k["top_pct_of_customers"] < 10]                      # top 1% and top 5% sharpen the steep start
pts = sorted([(0.0, 0.0)] + list(zip(dec_x, dec_y)) + list(zip(extra["top_pct_of_customers"], extra["pct_of_total"])))
xs, cum = zip(*pts)
fig, ax = plt.subplots(figsize=(7.5, 5.6))
ax.plot([0, 100], [0, 100], color=GREY, ls="--", lw=1, label="Equal spending")
ax.plot(xs, cum, color=BLUE, marker="o", lw=2, label="Actual (customers ranked by spend)")
ax.scatter(k["top_pct_of_customers"], k["pct_of_total"], color=ORANGE, zorder=5, label="Exact shares from the SQL query")
for _, row in k.iterrows():
    ax.annotate(f"top {int(row['top_pct_of_customers'])}%: {row['pct_of_total']:.1f}%",
                (row["top_pct_of_customers"], row["pct_of_total"]), textcoords="offset points",
                xytext=(10, -12), fontsize=8)
ax.set_xlim(0, 100)
ax.set_ylim(0, 102)
ax.set_xlabel("Top x% of customers (highest-spending first)")
ax.set_ylabel("Cumulative % of gross sales")
ax.legend(frameon=False, loc="lower right")
ax.set_title("A small group of customers drives most of the sales")
fig.text(0.01, -0.04, "Gross sales of 5,852 identified customers (before returns). After returns the top 10% hold 63.2%.\n" + SOURCE,
         fontsize=8, color="#555")
save(fig, "05_sales_concentration.png")

# 6. The two "top customers" whose orders were almost fully cancelled -------------------
tr = pd.read_csv(RES / "top_returners.csv").head(2)          # the two largest returners
gross = tr["gross_monetary"].to_numpy(dtype=float)
net = gross + tr["returns_amount"].to_numpy(dtype=float)
threshold = float(pd.read_csv(RES / "spend_deciles_gross.csv").sort_values("decile")["min_gross_monetary"].iloc[0])
labels = [f"Customer {int(c)}" for c in tr["customer_id"]]
fig, ax = plt.subplots(figsize=(7.5, 5))
x = np.arange(len(labels))
w = 0.34
b1 = ax.bar(x - w / 2, gross, w, color=GREY, label="Gross spend (before returns)")
b2 = ax.bar(x + w / 2, net, w, color=BLUE, label="Net spend (after returns)")
for bars in (b1, b2):
    for b in bars:
        y = max(b.get_height(), threshold) + 3500            # keep labels clear of the dashed line
        ax.text(b.get_x() + b.get_width() / 2, y, f"£{b.get_height():,.2f}", ha="center", fontsize=9)
ax.axhline(threshold, color=ORANGE, ls="--", lw=1.2, label=f"Top 10% of customers start at £{threshold:,.2f} gross spend")
ax.set_xticks(x, labels)
ax.set_ylim(0, gross.max() * 1.15)
ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"£{int(v):,}"))
ax.legend(frameon=False, loc="upper right")
ax.set_title("Two apparent top customers were almost fully cancelled orders")
fig.text(0.01, -0.05, "Together these two customers account for 34.5% of the returns of identified customers.\n" + SOURCE,
         fontsize=8, color="#555")
save(fig, "06_two_top_customers_gross_vs_net.png")
