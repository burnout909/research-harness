"""Tests for MATLAB tools (mock mode)."""

import os
import tempfile
from pathlib import Path

os.environ["MATLAB_MOCK"] = "true"

from tools.matlab import (
    matlab_generate_script,
    matlab_run,
    matlab_check_convergence,
    matlab_get_figures,
)
from tools.excel import mat_to_excel
from tools.docx_tool import manuscript_generate


def test_generate_script():
    script = matlab_generate_script("simulation", {
        "name": "test_sim",
        "n_points": 50,
        "output_mat": "out.mat",
        "output_fig": "out.png",
    })
    assert "test_sim" in script
    assert "n_points = 50;" in script
    assert "out.mat" in script
    print("generate_script PASSED")


def test_run():
    with tempfile.TemporaryDirectory() as tmpdir:
        result = matlab_run("% mock script", work_dir=tmpdir)
        assert "MOCK" in result["output"]
        assert len(result["files"]) == 2
        for f in result["files"]:
            assert Path(f).exists()
    print("matlab_run PASSED")


def test_check_convergence():
    result = matlab_check_convergence("dummy.mat", threshold=0.01)
    assert result["converged"] is True
    assert result["metric"] == 0.005
    print("check_convergence PASSED")


def test_get_figures():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create some mock figure files
        (Path(tmpdir) / "fig1.png").touch()
        (Path(tmpdir) / "fig2.svg").touch()
        (Path(tmpdir) / "data.csv").touch()  # should be excluded

        figs = matlab_get_figures(tmpdir)
        assert len(figs) == 2
        assert any("fig1.png" in f for f in figs)
        assert any("fig2.svg" in f for f in figs)
    print("get_figures PASSED")


def test_mat_to_excel():
    with tempfile.TemporaryDirectory() as tmpdir:
        # First generate a mock .mat via matlab_run
        result = matlab_run("% mock", work_dir=tmpdir)
        mat_file = [f for f in result["files"] if f.endswith(".mat")][0]

        xlsx_path = str(Path(tmpdir) / "converted.xlsx")
        out = mat_to_excel(mat_file, xlsx_path)
        assert Path(out).exists()
    print("mat_to_excel PASSED")


def test_manuscript_generate():
    with tempfile.TemporaryDirectory() as tmpdir:
        out_path = str(Path(tmpdir) / "manuscript.docx")
        result = manuscript_generate(
            sections={"Abstract": "Test abstract.", "Introduction": "Test intro."},
            output_path=out_path,
            journal_style="IEEE",
        )
        assert Path(result).exists()
    print("manuscript_generate PASSED")


if __name__ == "__main__":
    test_generate_script()
    test_run()
    test_check_convergence()
    test_get_figures()
    test_mat_to_excel()
    test_manuscript_generate()
