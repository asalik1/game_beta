"""Child of tools/orchestration/glock.py; work files stay within this checkout."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
mode = sys.argv[1]
env = os.environ.copy()
# APPDATA redirects Python's user-site location too. Preserve this interpreter's
# already resolved module paths for the source/GIF report subprocesses.
env["PYTHONPATH"] = os.pathsep.join(sys.path)
temp = ROOT / "build/qa/t60b/temp"
temp.mkdir(parents=True, exist_ok=True)
env["TEMP"] = env["TMP"] = str(temp)
env["APPDATA"] = str(ROOT / "build/qa/t60b" / (mode + "_profile"))
if mode in ("before", "after"):
    if mode == "after":
        imported = subprocess.run([str(ROOT / "tools/Godot_v4.4.1-stable_win64_console.exe"),
            "--headless", "--path", str(ROOT / "game"), "--editor", "--import", "--quit"], cwd=ROOT, env=env)
        if imported.returncode:
            raise SystemExit(imported.returncode)
    cmd = ["cmd.exe", "/d", "/c", str(ROOT / "shot.bat"), "t60b_walk", "--fixed-fps=60", "--timeout=240"]
    if mode == "before":
        cmd.append("--before")
elif mode in ("quick", "full", "preflight"):
    cmd = ["cmd.exe", "/d", "/c", str(ROOT / {"quick": "test_quick.bat", "full": "test.bat", "preflight": "preflight.bat"}[mode])]
elif mode == "mobile":
    cmd = [sys.executable, str(ROOT / "tools/sync_mobile.py"), "--apply", "--gate", "--paths", "assets/sprites/morwen_walk.png", "assets/sprites/korrag_walk_codex_s.png"]
elif mode == "import":
    cmd = [str(ROOT / "tools/Godot_v4.4.1-stable_win64_console.exe"), "--headless", "--path", str(ROOT / "game"), "--editor", "--import", "--quit"]
else:
    raise SystemExit("unknown validation mode")
result = subprocess.run(cmd, cwd=ROOT, env=env)
if mode in ("before", "after"):
    shots = Path(env["APPDATA"]) / "Godot/app_userdata/Crownless/shots/t60b_walk"
    if shots.exists():
        report = subprocess.run([sys.executable, str(HERE / "boss_walk_report.py"), "--out", str(HERE / (mode + "_report")), "--capture", str(shots)] + (["--source-dir", str(HERE / "before")] if mode == "before" else []), cwd=ROOT, env=env)
        if mode == "after" and report.returncode:
            raise SystemExit(report.returncode)
    elif result.returncode == 0:
        raise SystemExit("Capture output missing")
raise SystemExit(result.returncode)
