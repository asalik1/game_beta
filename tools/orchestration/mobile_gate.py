"""Mobile gates in the main worktree: --import, compile gate, quick suite on mobile/game.
Run under glock:  python glock.py --priority --cwd <main> --log <log> -- python mobile_gate.py
Exit 0 only if COMPILE OK and AUTOTEST QUICK PASS are seen and no SCRIPT ERROR appears."""
import os, subprocess, sys, tempfile
from pathlib import Path

M = Path(r"C:\Users\asali\Projects\MMO\.codex\worktrees\crownless-wayfinder")
GODOT = str(M / "tools" / "Godot_v4.4.1-stable_win64_console.exe")
env = os.environ.copy()
appdata = Path(tempfile.mkdtemp(prefix="crownless_mobile_gate_"))
env["APPDATA"] = str(appdata)


def run(args, timeout):
    print("$", " ".join(args), flush=True)
    p = subprocess.run(args, cwd=M, env=env, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=timeout)
    out = p.stdout + p.stderr
    print(out[-4000:], flush=True)
    return p.returncode, out


rc, _ = run([GODOT, "--headless", "--import", "--quit", "--path", "mobile/game"], 600)
rc, out = run([GODOT, "--headless", "--path", "mobile/game", "--script", "res://check_compile.gd"], 300)
if "COMPILE OK" not in out:
    print("MOBILE GATE FAIL: compile"); sys.exit(1)
log = appdata / "mobile_quick.log"
rc, out = run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(M / "run_suite.ps1"),
               "-Godot", GODOT, "-GamePath", str(M / "mobile" / "game"), "-Scene", "res://scenes/test.tscn",
               "-ExtraArgs", "-- --quick", "-Log", str(log)], 900)
raw = log.read_bytes() if log.exists() else b""
text = (raw.decode("utf-16", errors="replace") if raw[:2] in (bytes([255, 254]), bytes([254, 255])) else raw.decode("utf-8", errors="replace")) + out
bad = [l for l in text.splitlines() if "SCRIPT ERROR" in l or "AUTOTEST FAIL" in l]
if "AUTOTEST QUICK PASS" in text and not bad:
    print("MOBILE GATE PASS"); sys.exit(0)
print("MOBILE GATE FAIL:", bad[:10]); sys.exit(1)
