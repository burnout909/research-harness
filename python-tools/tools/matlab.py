"""MATLAB tools with mock mode support."""
from __future__ import annotations

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

def _find_matlab_app() -> str | None:
    """Find the MATLAB .app bundle name on macOS."""
    import glob
    patterns = ["/Applications/MATLAB_R*.app", "/Applications/MATLAB.app"]
    for pat in patterns:
        matches = sorted(glob.glob(pat), reverse=True)
        if matches:
            return Path(matches[0]).name  # e.g. "MATLAB_R2025b.app"
    return None


def matlab_open() -> dict[str, Any]:
    """Open MATLAB GUI application on the user's machine.

    Returns:
        Dict with 'success' (bool) and 'message'.
    """
    system = platform.system()
    try:
        if system == "Darwin":
            app_name = _find_matlab_app()
            if app_name:
                # Remove .app suffix for open -a
                name = app_name.replace(".app", "")
                subprocess.Popen(["open", "-a", name])
            else:
                return {
                    "success": False,
                    "message": "MATLAB app not found in /Applications/.",
                }
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

    Uses the locally installed MATLAB via subprocess (no matlab.engine needed).

    Args:
        script: MATLAB script content or path to .m file.
        work_dir: Working directory for execution.

    Returns:
        Dict with 'output' (stdout) and 'files' (created files).
    """
    wd = Path(work_dir) if work_dir else Path(tempfile.mkdtemp())
    wd.mkdir(parents=True, exist_ok=True)

    if MOCK:
        mat_path = wd / "results.mat"
        fig_path = wd / "figure.png"
        _write_mock_mat(mat_path)
        _write_mock_png(fig_path)
        return {
            "output": "[MOCK] Script executed successfully.\n"
                      f"Created: {mat_path}, {fig_path}",
            "files": [str(mat_path), str(fig_path)],
        }

    # Write script to file (name must be a valid MATLAB identifier)
    script_path = wd / "mcp_run.m"
    script_path.write_text(script)

    # Run via local MATLAB subprocess (headless / no GUI)
    matlab_base = _find_matlab_executable()
    matlab_cmd = f"cd('{wd}'); mcp_run"
    cmd = matlab_base + ["-nosplash", "-nodesktop", "-batch", matlab_cmd]

    proc = subprocess.run(
        cmd, capture_output=True, timeout=600,
    )

    files = sorted(str(f) for f in wd.iterdir() if f.name != "mcp_run.m")

    output_text = proc.stdout.decode(errors="replace") if proc.stdout else ""
    error_text = proc.stderr.decode(errors="replace") if proc.stderr else ""

    result: dict[str, Any] = {
        "output": output_text or "MATLAB execution completed.",
        "files": files,
        "returncode": proc.returncode,
    }
    if error_text:
        result["errors"] = error_text

    return result


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

# ── GUI execution (subprocess) ────────────────────────────────────────

def _find_matlab_executable() -> list[str]:
    """Find the MATLAB executable and any necessary arch flags.

    Returns a list of command parts, e.g. ["/path/to/matlab"] or
    ["/path/to/matlab", "-maci64"] when Rosetta is needed.
    """
    system = platform.system()

    if system == "Darwin":
        import glob as _glob

        for pat in ["/Applications/MATLAB_R*.app"]:
            matches = sorted(_glob.glob(pat), reverse=True)
            if matches:
                app_path = Path(matches[0])
                exe = app_path / "bin" / "matlab"
                if exe.exists():
                    # Apple Silicon without native maca64 binaries →
                    # run entire launcher under Rosetta so uname
                    # reports i386 and the script picks maci64
                    if platform.machine() == "arm64":
                        maca64_dir = app_path / "bin" / "maca64"
                        maci64_dir = app_path / "bin" / "maci64"
                        if not maca64_dir.exists() and maci64_dir.exists():
                            return ["arch", "-x86_64", str(exe)]
                    return [str(exe)]
        raise FileNotFoundError(
            "MATLAB not found in /Applications/. "
            "Install MATLAB or set MATLAB_ROOT environment variable."
        )

    elif system == "Windows":
        matlab_root = os.environ.get("MATLAB_ROOT", "")
        if matlab_root:
            exe = Path(matlab_root) / "bin" / "matlab.exe"
            if exe.exists():
                return [str(exe)]
        # Try PATH
        import shutil
        found = shutil.which("matlab")
        if found:
            return [found]
        raise FileNotFoundError("MATLAB not found. Set MATLAB_ROOT or add matlab to PATH.")

    else:  # Linux
        import shutil
        found = shutil.which("matlab")
        if found:
            return [found]
        raise FileNotFoundError("MATLAB not found in PATH.")


def matlab_run_with_gui(script: str, work_dir: str | None = None) -> dict[str, Any]:
    """Run a MATLAB script via subprocess with GUI (figure windows visible).

    Launches MATLAB GUI in the background and polls for experiment_result.json.
    No timeout — waits until the result file appears or MATLAB exits.

    Args:
        script: MATLAB script content.
        work_dir: Working directory for execution.

    Returns:
        Dict with 'output' and 'files' (created files).
    """
    import time

    wd = Path(work_dir) if work_dir else Path(tempfile.mkdtemp())
    wd.mkdir(parents=True, exist_ok=True)

    if MOCK:
        mat_path = wd / "results.mat"
        fig_path = wd / "figure.png"
        _write_mock_mat(mat_path)
        _write_mock_png(fig_path)
        return {
            "output": "[MOCK] Script executed with GUI successfully.\n"
                      f"Created: {mat_path}, {fig_path}",
            "files": [str(mat_path), str(fig_path)],
        }

    script_path = wd / "mcp_run.m"
    script_path.write_text(script)

    # Remove stale result file if it exists
    result_file = wd / "experiment_result.json"
    if result_file.exists():
        result_file.unlink()

    matlab_base = _find_matlab_executable()
    matlab_cmd = f"cd('{wd}'); mcp_run; pause(2); exit"
    cmd = matlab_base + ["-nosplash", "-r", matlab_cmd]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    # Poll for experiment_result.json — no timeout
    while True:
        if result_file.exists():
            try:
                content = result_file.read_text()
                if content.strip():
                    experiment_data = json.loads(content)
                    files = sorted(str(f) for f in wd.iterdir() if f.name != "mcp_run.m")
                    return {
                        "output": "MATLAB GUI execution completed.",
                        "experiment_result": experiment_data,
                        "files": files,
                    }
            except (json.JSONDecodeError, OSError):
                pass

        # MATLAB process exited without producing result JSON
        if proc.poll() is not None:
            stdout, stderr = proc.communicate()
            output_text = stdout.decode(errors="replace") if stdout else ""
            error_text = stderr.decode(errors="replace") if stderr else ""
            files = sorted(str(f) for f in wd.iterdir() if f.name != "mcp_run.m")
            return {
                "output": output_text or "MATLAB exited without result JSON.",
                "errors": error_text if error_text else None,
                "returncode": proc.returncode,
                "files": files,
            }

        time.sleep(1)


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
