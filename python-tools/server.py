"""MCP Server entry point — registers all tools and runs the server."""

import json
from typing import Any

from mcp.server.fastmcp import FastMCP

from tools.excel import excel_read, excel_write, mat_to_excel
from tools.docx_tool import docx_read, docx_write, manuscript_generate
from tools.analysis import pandas_analyze, plot_create
from tools.matlab import (
    matlab_open,
    matlab_generate_script,
    matlab_run,
    matlab_check_convergence,
    matlab_get_figures,
)

mcp = FastMCP("research-harness")


# ── Excel tools ──────────────────────────────────────────────────────

@mcp.tool()
def read_excel(file_path: str, sheet: str | None = None) -> str:
    """Read an Excel (.xlsx) file and return its contents as JSON.

    Args:
        file_path: Path to the Excel file.
        sheet: Optional sheet name. Defaults to the active sheet.
    """
    rows = excel_read(file_path, sheet)
    return json.dumps(rows, ensure_ascii=False, default=str)


@mcp.tool()
def write_excel(file_path: str, data: list[dict[str, Any]], sheet: str | None = None) -> str:
    """Write data to an Excel (.xlsx) file.

    Args:
        file_path: Destination path for the Excel file.
        data: List of row objects. Keys become column headers.
        sheet: Optional sheet name.
    """
    path = excel_write(file_path, data, sheet)
    return f"Written to {path}"


# ── DOCX tools ───────────────────────────────────────────────────────

@mcp.tool()
def read_docx(file_path: str) -> str:
    """Read a Word (.docx) file and return its text content.

    Args:
        file_path: Path to the DOCX file.
    """
    return docx_read(file_path)


@mcp.tool()
def write_docx(file_path: str, content: str, template: str | None = None) -> str:
    """Create or overwrite a Word (.docx) file.

    Args:
        file_path: Destination path for the DOCX file.
        content: Text content. Each line becomes a paragraph.
        template: Optional path to a .docx template.
    """
    path = docx_write(file_path, content, template)
    return f"Written to {path}"


# ── Analysis tools ───────────────────────────────────────────────────

@mcp.tool()
def analyze_data(file_path: str, query: str) -> str:
    """Run a pandas query on a data file (.csv, .xlsx, .json).

    The DataFrame is available as `df` in the query expression.
    Examples: "df.describe()", "df.groupby('col').mean()", "df.shape"

    Args:
        file_path: Path to the data file.
        query: A pandas expression to evaluate.
    """
    return pandas_analyze(file_path, query)


@mcp.tool()
def create_plot(
    data: list[dict[str, Any]],
    chart_type: str,
    output_path: str,
    title: str = "",
    x_col: str | None = None,
    y_col: str | None = None,
) -> str:
    """Create a chart and save it as a PNG image.

    Args:
        data: List of row objects to plot.
        chart_type: One of "bar", "line", "scatter", "hist", "pie".
        output_path: Destination PNG path.
        title: Optional chart title.
        x_col: Column name for x-axis.
        y_col: Column name for y-axis.
    """
    path = plot_create(data, chart_type, output_path, title, x_col, y_col)
    return f"Chart saved to {path}"


# ── MATLAB tools ─────────────────────────────────────────────────────

@mcp.tool()
def open_matlab() -> str:
    """Open the MATLAB GUI application on the user's computer.

    Use this when the user asks to open, launch, or start MATLAB.
    """
    result = matlab_open()
    return json.dumps(result, ensure_ascii=False)


@mcp.tool()
def generate_matlab_script(experiment_type: str, parameters: dict[str, Any]) -> str:
    """Generate a MATLAB .m script from a template.

    Args:
        experiment_type: One of "simulation", "analysis".
        parameters: Dict of parameter names and values.
    """
    return matlab_generate_script(experiment_type, parameters)


@mcp.tool()
def run_matlab(script: str, work_dir: str | None = None) -> str:
    """Run a MATLAB script and return the result.

    Args:
        script: MATLAB script content or path to .m file.
        work_dir: Optional working directory.
    """
    result = matlab_run(script, work_dir)
    return json.dumps(result, ensure_ascii=False)


@mcp.tool()
def check_convergence(mat_file: str, threshold: float = 0.01) -> str:
    """Check if simulation results in a .mat file have converged.

    Args:
        mat_file: Path to the .mat results file.
        threshold: Convergence threshold (default 0.01).
    """
    result = matlab_check_convergence(mat_file, threshold)
    return json.dumps(result)


@mcp.tool()
def get_figures(work_dir: str = ".") -> str:
    """List all figure files (.png, .fig, .jpg, .svg) in a directory.

    Args:
        work_dir: Directory to scan for figures.
    """
    return json.dumps(matlab_get_figures(work_dir))


@mcp.tool()
def convert_mat_to_excel(mat_file: str, output_path: str) -> str:
    """Convert a MATLAB .mat file to Excel (.xlsx).

    Args:
        mat_file: Path to the .mat file.
        output_path: Destination .xlsx path.
    """
    path = mat_to_excel(mat_file, output_path)
    return f"Converted to {path}"


@mcp.tool()
def generate_manuscript(
    output_path: str = "manuscript.docx",
    excel_path: str | None = None,
    figures: list[str] | None = None,
    sections: dict[str, str] | None = None,
    template: str | None = None,
    journal_style: str | None = None,
) -> str:
    """Generate a manuscript draft as a Word document.

    Args:
        output_path: Destination .docx path.
        excel_path: Optional data Excel file for auto tables.
        figures: Optional list of figure image paths.
        sections: Optional dict of section_name to content.
        template: Optional .docx template path.
        journal_style: Optional journal style name.
    """
    path = manuscript_generate(excel_path, figures, sections, template, journal_style, output_path)
    return f"Manuscript generated at {path}"


if __name__ == "__main__":
    mcp.run()
