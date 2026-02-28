"""Data analysis and plotting tools using pandas and matplotlib."""
from __future__ import annotations

import json
from io import StringIO
from pathlib import Path
from typing import Any

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


def pandas_analyze(file_path: str, query: str) -> str:
    """Run a pandas query/expression on a data file and return the result.

    Supported file types: .csv, .xlsx, .json

    Args:
        file_path: Path to the data file.
        query: A pandas expression to evaluate. The DataFrame is available as `df`.
               Examples: "df.describe()", "df.groupby('col').mean()", "df.shape"

    Returns:
        String representation of the query result.
    """
    p = Path(file_path)
    ext = p.suffix.lower()

    if ext == ".csv":
        df = pd.read_csv(p)
    elif ext in (".xlsx", ".xls"):
        df = pd.read_excel(p)
    elif ext == ".json":
        df = pd.read_json(p)
    else:
        raise ValueError(f"Unsupported file type: {ext}")

    result = eval(query, {"__builtins__": {}}, {"df": df, "pd": pd})

    if isinstance(result, pd.DataFrame):
        return result.to_string()
    elif isinstance(result, pd.Series):
        return result.to_string()
    return str(result)


def plot_create(
    data: list[dict[str, Any]],
    chart_type: str,
    output_path: str,
    title: str = "",
    x_col: str | None = None,
    y_col: str | None = None,
) -> str:
    """Create a chart and save it as a PNG image.

    Args:
        data: List of row dicts to plot.
        chart_type: One of "bar", "line", "scatter", "hist", "pie".
        output_path: Destination PNG path.
        title: Optional chart title.
        x_col: Column name for x-axis.
        y_col: Column name for y-axis.

    Returns:
        The path of the saved PNG.
    """
    df = pd.DataFrame(data)
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)

    fig, ax = plt.subplots(figsize=(10, 6))

    plot_kwargs: dict[str, Any] = {"ax": ax}
    if x_col:
        plot_kwargs["x"] = x_col
    if y_col:
        plot_kwargs["y"] = y_col

    if chart_type == "bar":
        df.plot.bar(**plot_kwargs)
    elif chart_type == "line":
        df.plot.line(**plot_kwargs)
    elif chart_type == "scatter":
        if not x_col or not y_col:
            raise ValueError("scatter requires both x_col and y_col")
        df.plot.scatter(**plot_kwargs)
    elif chart_type == "hist":
        df.plot.hist(**plot_kwargs)
    elif chart_type == "pie":
        col = y_col or df.columns[0]
        df[col].plot.pie(ax=ax, autopct="%1.1f%%")
    else:
        raise ValueError(f"Unsupported chart_type: {chart_type}")

    if title:
        ax.set_title(title)

    fig.tight_layout()
    fig.savefig(out, dpi=150)
    plt.close(fig)

    return str(out)
