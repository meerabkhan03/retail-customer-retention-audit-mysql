# Data

The dataset is **not** stored in this repository (about 43 MB as a download, over 1 million rows).

## Source

- **Online Retail II**, UCI Machine Learning Repository
- Author: Daqing Chen
- Link: https://archive.ics.uci.edu/dataset/502/online+retail+ii
- License: Creative Commons Attribution 4.0 International (CC BY 4.0)
- Content: transactions of a UK-based, registered, non-store online retailer between 01/12/2009 and 09/12/2011. Many customers are wholesalers.

## How to obtain and prepare it

1. Download and unzip the dataset from the link above. It contains an Excel workbook with two sheets (2009-2010 and 2010-2011).
2. Convert it to a single CSV:
   ```
   python scripts/convert_to_csv.py --input "C:/data/online_retail/online_retail_II.xlsx" --output "C:/data/online_retail/online_retail_II.csv"
   ```
3. Load the CSV into MySQL with `sql/01_setup_and_load.sql`.

Expected row counts: 525,461 (sheet 1) + 541,910 (sheet 2) = 1,067,371 data rows.
