"""Convert the UCI Online Retail II Excel workbook into a single CSV file.

Usage:
    python scripts/convert_to_csv.py --input online_retail_II.xlsx --output online_retail_II.csv

Notes:
- Every source column is read as text so identifiers (e.g. Customer ID) are not altered.
- Completely empty rows are dropped.
- Two lineage columns are added so every row can be traced back to the workbook:
    source_sheet : 1 or 2, the position of the sheet in the workbook
    source_row   : the row's position within its sheet (first data row = 1)
  Lineage is stored IN the data. Do not infer it from load order in the database.
- Per-sheet date ranges are printed so they can be checked against the Excel file.
"""
import argparse
from pathlib import Path

import pandas as pd


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Path to the .xlsx file")
    parser.add_argument("--output", required=True, type=Path, help="Path for the CSV to create")
    args = parser.parse_args()

    sheets = pd.read_excel(args.input, sheet_name=None, dtype=str)

    frames = []
    for position, (name, df) in enumerate(sheets.items(), start=1):
        df = df.dropna(how="all").copy()
        df["source_sheet"] = position
        df["source_row"] = df.index + 1
        dates = df["InvoiceDate"]
        print(f"Sheet {position} '{name}': {len(df)} data rows, "
              f"dates {dates.min()} to {dates.max()}")
        frames.append(df)

    combined = pd.concat(frames, ignore_index=True)
    print(f"Total data rows: {len(combined)}")
    print("Columns:", list(combined.columns))

    combined.to_csv(args.output, index=False, lineterminator="\n", encoding="utf-8")
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()
