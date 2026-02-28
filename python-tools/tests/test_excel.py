"""Tests for Excel tools."""

import tempfile
from pathlib import Path

from tools.excel import excel_read, excel_write


def test_roundtrip():
    data = [
        {"name": "Alice", "score": 95},
        {"name": "Bob", "score": 87},
        {"name": "Charlie", "score": 72},
    ]

    with tempfile.TemporaryDirectory() as tmpdir:
        path = str(Path(tmpdir) / "test.xlsx")

        # Write
        result = excel_write(path, data, sheet="Scores")
        assert Path(result).exists()

        # Read back
        rows = excel_read(path, sheet="Scores")
        assert len(rows) == 3
        assert rows[0]["name"] == "Alice"
        assert rows[0]["score"] == 95
        assert rows[2]["name"] == "Charlie"

    print("Excel roundtrip test PASSED")


if __name__ == "__main__":
    test_roundtrip()
