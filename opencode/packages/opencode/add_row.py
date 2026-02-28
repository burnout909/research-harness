import openpyxl
import os

file_path = "../../../data/uploads/1772251815979_2026_________________________2_.xlsx"

try:
    wb = openpyxl.load_workbook(file_path)
    sheet = wb.active

    # Check if the last row is completely empty. If not, append.
    # Actually, we should just append to be safe.

    new_row = ["이동", "인천", "2024-08-16"]
    sheet.append(new_row)

    wb.save(file_path)
    print(f"Added row {new_row} to {file_path}")

except Exception as e:
    print(f"Error: {e}")
