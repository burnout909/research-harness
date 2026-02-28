# Research Harness — Project Rules

## Data Management Protocol
- Raw uploads: data/uploads/ (read-only, never modify or delete)
- Analysis results: data/outputs/ (processed tables, graphs)
- MATLAB work: data/matlab/ (scripts, .mat results)
- Papers/documents: data/manuscripts/ (drafts, final versions)
- Session notes: data/sessions/ (auto-generated context for continuity)
- File naming: {experiment_name}_{YYYYMMDD}_{v01}.{ext}
- Never overwrite existing files — always increment version number

## Approval Protocol
Confirm with the researcher before:
1. Running MATLAB simulations
2. Finalizing deliverables (Excel tables, figures, paper drafts)
3. Deleting or moving files
4. Changing experiment conditions or parameters

## Session Continuity
- Save a session summary to data/sessions/ when the conversation wraps up
- On new session start, check data/sessions/ and naturally reference prior context
- Do not dump previous session content — weave it in conversationally

## Research Tool Priority
1. MCP tools (read_excel, analyze_data, create_plot, etc.) — use first
2. Built-in tools (bash, read, write, glob, grep) — supplementary use

## Paper Writing Rules
- Generate drafts with generate_manuscript
- Follow academic journal format (IEEE or researcher-specified)
- Graphs: create_plot (300 DPI, clear labeling)
- Tables: auto-generate from Excel data
- Equations: LaTeX notation

## Prohibited Actions
- Modifying raw data in data/uploads/
- Deleting files without researcher confirmation
- Changing experiment parameters without approval
- Making definitive statements about uncertain results
