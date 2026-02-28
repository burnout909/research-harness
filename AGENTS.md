# Research Harness — Project Rules

## Data Directories
- data/uploads/ (original): Raw data (read-only)
- data/working/: Intermediate work files, edited spreadsheets
- data/outputs/ (result): Final analysis results, tables, graphs
- data/matlab/: MATLAB scripts, .mat results
- data/manuscripts/: Paper drafts
- data/sessions/: Session context notes

## Key Rules
- Never modify or delete files in data/uploads/
- File naming: {experiment_name}_{YYYYMMDD}_{v01}.{ext} — increment version, never overwrite
- Confirm before: deleting files, running simulations, changing experiment parameters
- MCP tools first (read_excel, analyze_data, create_plot), built-in tools supplementary
