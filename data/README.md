# Data

The dataset is **not** stored in this repository (about 43 MB as a download, over 1 million rows).
Keep it outside the repository, for example in `C:\data\online_retail\`.

## Source

* **Online Retail II**, UCI Machine Learning Repository
* Author: Daqing Chen
* Link: https://archive.ics.uci.edu/dataset/502/online+retail+ii
* License: Creative Commons Attribution 4.0 International (CC BY 4.0)
* Content: transactions of a UK-based, registered, non-store online retailer between 01/12/2009 and 09/12/2011. Many customers are wholesalers.

## How to obtain and prepare it

1. Download and unzip the dataset from the link above. It contains an Excel workbook with two worksheets, `Year 2009-2010` and `Year 2010-2011`.
2. Convert it to a single CSV. The script adds two lineage columns, `source_sheet` and `source_row`, so every row can be traced to its worksheet:
   ```
   python scripts/convert_to_csv.py --input "C:/data/online_retail/online_retail_II.xlsx" --output "C:/data/online_retail/online_retail_II.csv"
   ```
   It needs Python 3 with `pandas` and `openpyxl` (`pip install pandas openpyxl`).
3. Check the printed summary against the original workbook:

   | Worksheet | Data rows | First date | Last date |
   |---|---:|---|---|
   | `Year 2009-2010` (source_sheet 1) | 525,461 | 2009-12-01 07:45:00 | 2010-12-09 20:01:00 |
   | `Year 2010-2011` (source_sheet 2) | 541,910 | 2010-12-01 08:26:00 | 2011-12-09 12:50:00 |
   | **Total** | **1,067,371** | | |

4. Load the CSV into MySQL with `sql/01_setup_and_load.sql` (edit the file path inside it to match your machine).

Worksheet membership is always taken from the `source_sheet` column, never inferred from database row order.
