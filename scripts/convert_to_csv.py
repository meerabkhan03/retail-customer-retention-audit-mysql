"""Convert the UCI Online Retail II Excel workbook into a single CSV file.

Usage:
    python scripts/convert_to_csv.py --input online_retail_II.xlsx --output online_retail_II.csv

Notes:
- Every column is read as text so identifiers (e.g. Customer ID) are not altered.
- Completely empty rows are dropped.
- Sheets are concatenated in workbook order, so the rows of sheet 1 come first.
  The SQL scripts rely on this order to recover which sheet a row came from.
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
    for name, df in sheets.items():
        df = df.dropna(how="all")
        print(f"Sheet '{name}': {len(df)} data rows")
        frames.append(df)

    combined = pd.concat(frames, ignore_index=True)
    print(f"Total data rows: {len(combined)}")

    combined.to_csv(args.output, index=False, lineterminator="\n", encoding="utf-8")
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()
