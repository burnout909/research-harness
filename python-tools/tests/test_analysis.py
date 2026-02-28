"""Tests for analysis tools."""

import csv
import tempfile
from pathlib import Path

from tools.analysis import pandas_analyze, plot_create


def test_pandas_analyze():
    with tempfile.TemporaryDirectory() as tmpdir:
        csv_path = str(Path(tmpdir) / "data.csv")
        with open(csv_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["name", "value"])
            writer.writeheader()
            writer.writerows([
                {"name": "A", "value": 10},
                {"name": "B", "value": 20},
                {"name": "C", "value": 30},
            ])

        result = pandas_analyze(csv_path, "df.shape")
        assert "(3, 2)" in result

        result = pandas_analyze(csv_path, "df['value'].mean()")
        assert "20" in result

    print("pandas_analyze test PASSED")


def test_plot_create():
    data = [
        {"x": 1, "y": 10},
        {"x": 2, "y": 20},
        {"x": 3, "y": 15},
    ]

    with tempfile.TemporaryDirectory() as tmpdir:
        out_path = str(Path(tmpdir) / "chart.png")
        result = plot_create(data, "bar", out_path, title="Test Chart")
        assert Path(result).exists()
        assert Path(result).stat().st_size > 0

    print("plot_create test PASSED")


if __name__ == "__main__":
    test_pandas_analyze()
    test_plot_create()
