import pandas as pd
import os

# File paths
input_path = '/Users/jun/Desktop/researchcat/research-harness/data/uploads/1772259606813_Results-JH_platetensiletest_V11_-20251110-173947.xlsx'
output_dir = 'data/outputs'
output_filename = 'Results-JH_platetensiletest_V11_20251110_cleaned_v01.xlsx'
output_path = os.path.join(output_dir, output_filename)

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

try:
    # Read the Excel file
    df = pd.read_excel(input_path)
    
    # Identify rows to drop based on the first column
    # Assuming the labels are in the first column
    # We'll look for exact matches or partial matches if necessary
    
    initial_rows = len(df)
    
    # Check if first column contains the keywords
    first_col = df.columns[0]
    
    # Convert first column to string for checking
    mask = ~df[first_col].astype(str).str.contains(r'Mean|SD|Min|Max', case=False, na=False)
    
    df_cleaned = df[mask]
    
    final_rows = len(df_cleaned)
    dropped_rows = initial_rows - final_rows
    
    # Save the cleaned file
    df_cleaned.to_excel(output_path, index=False)
    
    print(f"Successfully processed file.")
    print(f"Original rows: {initial_rows}")
    print(f"Final rows: {final_rows}")
    print(f"Dropped {dropped_rows} rows containing Mean, SD, Min, Max.")
    print(f"Saved to: {output_path}")

except Exception as e:
    print(f"Error processing file: {e}")
