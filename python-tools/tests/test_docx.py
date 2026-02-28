"""Tests for DOCX tools."""

import tempfile
from pathlib import Path

from tools.docx_tool import docx_read, docx_write


def test_roundtrip():
    content = "Hello World\nThis is a test document.\nThird paragraph."

    with tempfile.TemporaryDirectory() as tmpdir:
        path = str(Path(tmpdir) / "test.docx")

        # Write
        result = docx_write(path, content)
        assert Path(result).exists()

        # Read back
        text = docx_read(path)
        assert "Hello World" in text
        assert "Third paragraph." in text

    print("DOCX roundtrip test PASSED")


if __name__ == "__main__":
    test_roundtrip()
