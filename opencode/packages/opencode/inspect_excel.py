import pandas as pd
import os

file_path = "../../../data/uploads/1772251477055_2026_________________________2_.xlsx"

try:
    df = pd.read_excel(file_path)
    print("Columns:", df.columns.tolist())
    print("Last 3 rows:")
    print(df.tail(3))
except Exception as e:
    print(f"Error: {e}")
