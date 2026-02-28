import pandas as pd
import sys

file_path = "/Users/minseongkim/Desktop/research-harness/data/uploads/1772255736584_2026_________________________2_.xlsx"

try:
    xls = pd.ExcelFile(file_path)
    print(f"Sheet names: {xls.sheet_names}\n")

    for sheet_name in xls.sheet_names:
        print(f"--- Sheet: {sheet_name} ---")
        df = pd.read_excel(xls, sheet_name=sheet_name)

        if df.empty:
            print("Sheet is empty.\n")
            continue

        print(f"Shape: {df.shape}")
        print(f"Columns: {list(df.columns)}\n")
        print("First 5 rows:")
        print(df.head().to_string())
        print("\n")

        # Simple summary stats if numeric columns exist
        numeric_cols = df.select_dtypes(include=["number"]).columns
        if not numeric_cols.empty:
            print("Numeric Summary:")
            print(df[numeric_cols].describe().to_string())
            print("\n")

except Exception as e:
    print(f"Error reading file: {e}")
