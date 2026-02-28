# Research Harness — Project Rules

## Data Management Protocol
- data/originals/: Raw uploaded data (read-only, never modify or delete)
- data/working/: Intermediate work — drafts, temp analysis, scripts, exploratory plots
- data/outputs/: Final deliverables only — polished tables, final graphs, finished reports

### File Routing Rules
Save to **data/working/** when:
- Exploring or cleaning data
- Generating drafts or intermediate versions
- Running test simulations or trial plots
- Any file the researcher hasn't explicitly requested as a final deliverable

Save to **data/outputs/** only when:
- The researcher explicitly asks for a final result ("최종 결과 정리해줘", "이걸로 확정")
- Producing a named deliverable (final Excel report, publication-ready figure, manuscript)
- The task is clearly a one-step final output ("이 데이터 엑셀로 변환해줘")

When unsure, default to **data/working/**.

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
- Modifying raw data in data/originals/
- Deleting files without researcher confirmation
- Changing experiment parameters without approval
- Making definitive statements about uncertain results
