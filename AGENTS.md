# Research Harness — Project Rules

## Data Directories
- data/originals/: Raw uploaded data (read-only, never modify)
- data/working/: Intermediate work — drafts, temp analysis, scripts, exploratory plots
- data/outputs/: Final deliverables only — polished tables, final graphs, finished reports

## File Routing Rules
Save to **data/working/** when:
- Exploring or cleaning data ("일단 정리해봐", "분석해줘")
- Generating drafts or intermediate versions
- Running test simulations or trial plots
- Any file the researcher hasn't explicitly requested as a final deliverable

Save to **data/outputs/** only when:
- The researcher explicitly asks for a final result ("최종 결과 정리해줘", "이걸로 확정")
- Producing a named deliverable (final Excel report, publication-ready figure, manuscript)
- The task is clearly a one-step final output ("이 데이터 엑셀로 변환해줘")

When unsure, default to **data/working/**. The researcher can always say "이거 최종이야" to move it to outputs.

## Key Rules
- Never modify or delete files in data/originals/
- File naming: {experiment_name}_{YYYYMMDD}_{v01}.{ext} — increment version, never overwrite
- Confirm before: deleting files, running simulations, changing experiment parameters
- MCP tools first (read_excel, analyze_data, create_plot), built-in tools supplementary
