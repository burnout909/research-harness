import pandas as pd

file_path = "../../../data/uploads/1772251815979_2026_________________________2_.xlsx"

try:
    df = pd.read_excel(file_path)
    print("Last 3 rows:")
    print(df.tail(3))
except Exception as e:
    print(f"Error: {e}")
