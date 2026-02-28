"""MATLAB tools with mock mode support."""

import json
import os
import platform
import struct
import subprocess
import tempfile
from pathlib import Path
from typing import Any

MOCK = os.environ.get("MATLAB_MOCK", "").lower() in ("true", "1", "yes")


def _get_engine():
    """Get MATLAB engine, or raise if not available and not in mock mode."""
    if MOCK:
        return None
    try:
        import matlab.engine
        return matlab.engine.start_matlab()
    except ImportError:
        raise RuntimeError(
            "MATLAB Engine for Python is not installed. "
            "Set MATLAB_MOCK=true to use mock mode."
        )


# ── Open MATLAB GUI ──────────────────────────────────────────────────

def matlab_open() -> dict[str, Any]:
    """Open MATLAB GUI application on the user's machine.

    Returns:
        Dict with 'success' (bool) and 'message'.
    """
    system = platform.system()
    try:
        if system == "Darwin":
            subprocess.Popen(["open", "-a", "MATLAB"])
        elif system == "Windows":
            matlab_root = os.environ.get("MATLAB_ROOT", "")
            if matlab_root:
                exe = Path(matlab_root) / "bin" / "matlab.exe"
                subprocess.Popen([str(exe)])
            else:
                subprocess.Popen(["matlab"])
        else:  # Linux
            subprocess.Popen(["matlab", "-desktop"])

        return {"success": True, "message": f"MATLAB GUI launched on {system}."}
    except FileNotFoundError:
        return {
            "success": False,
            "message": "MATLAB not found. Please ensure MATLAB is installed and available in PATH.",
        }
    except Exception as e:
        return {"success": False, "message": f"Failed to launch MATLAB: {e}"}


# ── Script generation ────────────────────────────────────────────────

_TEMPLATES: dict[str, str] = {
    "simulation": (
        "%% Simulation: {name}\n"
        "% Parameters\n"
        "{param_lines}\n"
        "\n"
        "%% Run simulation\n"
        "results = struct();\n"
        "results.data = randn({n_points}, 1);\n"
        "results.converged = true;\n"
        "\n"
        "%% Save results\n"
        "save('{output_mat}', '-struct', 'results');\n"
        "figure; plot(results.data); saveas(gcf, '{output_fig}');\n"
    ),
    "analysis": (
        "%% Analysis: {name}\n"
        "{param_lines}\n"
        "\n"
        "%% Load and analyze data\n"
        "data = load('{input_mat}');\n"
        "results = struct();\n"
        "results.mean_val = mean(data.data);\n"
        "results.std_val = std(data.data);\n"
        "\n"
        "save('{output_mat}', '-struct', 'results');\n"
    ),
}


def matlab_generate_script(
    experiment_type: str,
    parameters: dict[str, Any],
) -> str:
    """Generate a MATLAB .m script from a template.

    Args:
        experiment_type: One of "simulation", "analysis".
        parameters: Dict of parameter names to values.

    Returns:
        The generated MATLAB script content.
    """
    template = _TEMPLATES.get(experiment_type)
    if not template:
        raise ValueError(
            f"Unknown experiment_type: {experiment_type}. "
            f"Available: {list(_TEMPLATES.keys())}"
        )

    param_lines = "\n".join(f"{k} = {v};" for k, v in parameters.items())
    name = parameters.get("name", experiment_type)
    n_points = parameters.get("n_points", 100)
    output_mat = parameters.get("output_mat", "results.mat")
    output_fig = parameters.get("output_fig", "figure.png")
    input_mat = parameters.get("input_mat", "data.mat")

    return template.format(
        name=name,
        param_lines=param_lines,
        n_points=n_points,
        output_mat=output_mat,
        output_fig=output_fig,
        input_mat=input_mat,
    )


# ── Script execution ─────────────────────────────────────────────────

def matlab_run(script: str, work_dir: str | None = None) -> dict[str, Any]:
    """Run a MATLAB script and return the result.

    Args:
        script: MATLAB script content or path to .m file.
        work_dir: Working directory for execution.

    Returns:
        Dict with 'output' (stdout) and 'files' (created files).
    """
    wd = Path(work_dir) if work_dir else Path(tempfile.mkdtemp())
    wd.mkdir(parents=True, exist_ok=True)

    if MOCK:
        # Create mock output files
        mat_path = wd / "results.mat"
        fig_path = wd / "figure.png"

        # Write a minimal mock .mat file (Level 5 MAT header)
        _write_mock_mat(mat_path)
        # Write a minimal mock PNG
        _write_mock_png(fig_path)

        return {
            "output": "[MOCK] Script executed successfully.\n"
                      f"Created: {mat_path}, {fig_path}",
            "files": [str(mat_path), str(fig_path)],
        }

    eng = _get_engine()
    try:
        eng.cd(str(wd))
        script_path = wd / "_run.m"
        script_path.write_text(script)
        out = eng.eval(f"run('{script_path}')", nargout=0)

        files = [str(f) for f in wd.iterdir() if f.name != "_run.m"]
        return {"output": str(out) if out else "Completed.", "files": files}
    finally:
        eng.quit()


# ── Convergence check ────────────────────────────────────────────────

def matlab_check_convergence(
    mat_file: str,
    threshold: float = 0.01,
) -> dict[str, Any]:
    """Check if simulation results have converged.

    Args:
        mat_file: Path to .mat file with results.
        threshold: Convergence threshold.

    Returns:
        Dict with 'converged' (bool), 'metric' (float), 'threshold'.
    """
    if MOCK:
        return {
            "converged": True,
            "metric": 0.005,
            "threshold": threshold,
            "message": "[MOCK] Convergence check passed.",
        }

    from scipy.io import loadmat
    import numpy as np

    data = loadmat(mat_file)
    # Look for a 'data' or 'results' array
    arr = None
    for key in ("data", "results", "x", "y"):
        if key in data:
            arr = np.array(data[key]).flatten()
            break

    if arr is None:
        raise ValueError(f"No recognized data array in {mat_file}")

    # Simple convergence: check if the last 10% variation is below threshold
    tail = arr[int(len(arr) * 0.9):]
    metric = float(np.std(tail) / (np.abs(np.mean(tail)) + 1e-10))

    return {
        "converged": metric < threshold,
        "metric": metric,
        "threshold": threshold,
    }


# ── Figure listing ───────────────────────────────────────────────────

def matlab_get_figures(work_dir: str = ".") -> list[str]:
    """List all figure files in the working directory.

    Args:
        work_dir: Directory to scan.

    Returns:
        List of figure file paths (.png, .fig, .jpg, .svg).
    """
    wd = Path(work_dir)
    exts = {".png", ".fig", ".jpg", ".jpeg", ".svg"}

    if MOCK and not wd.exists():
        return ["[MOCK] No work_dir found — would list figures here."]

    return sorted(
        str(f) for f in wd.iterdir() if f.suffix.lower() in exts
    ) if wd.exists() else []


# ── Mock helpers ─────────────────────────────────────────────────────

def _write_mock_mat(path: Path) -> None:
    """Write a minimal valid MAT-file v5 header."""
    header = b"MATLAB 5.0 MAT-file, mock data" + b"\x00" * (116 - 30)
    header += b"\x00" * 8  # subsys offset
    header += struct.pack("<H", 0x0100)  # version
    header += b"IM"  # endian
    path.write_bytes(header)


def _write_mock_png(path: Path) -> None:
    """Write a minimal 1x1 white PNG."""
    import zlib

    def _chunk(ctype: bytes, data: bytes) -> bytes:
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    raw = zlib.compress(b"\x00\xff\xff\xff")
    path.write_bytes(
        sig + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", raw) + _chunk(b"IEND", b"")
    )
