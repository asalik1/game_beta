"""Run serial validation under ONE outer glock; keep per-gate receipts."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
receipts = []
for mode in ("before", "after", "quick", "full", "mobile", "preflight"):
    if mode == "preflight":
        # Only our explicitly named temporary fixtures, never sibling rigs.
        for name in ("t60b_metrics.gd", "t60b_metrics.gd.uid", "shot_t60b_walk.gd",
                     "shot_t60b_walk.gd.uid", "shot_t60b_walk.tscn"):
            target = (ROOT / "game" / name).resolve()
            assert target.is_relative_to(ROOT / "game")
            target.unlink(missing_ok=True)
    print("T60b validation:", mode, flush=True)
    log = HERE / ("gate_" + mode + ".log")
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run([sys.executable, str(HERE / "run_validation.py"), mode],
                                cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    output = log.read_text(encoding="utf-8", errors="replace")
    rc = result.returncode
    markers = {"before": "BOSS WALK REGRESSION FAIL", "after": "BOSS WALK REGRESSION PASS", "quick": "AUTOTEST QUICK PASS",
               "full": "AUTOTEST PASS", "mobile": "GATE OK: mobile quick suite passed",
               "preflight": "PREFLIGHT: 0 fail"}
    passed = rc == (1 if mode == "before" else 0) and markers[mode] in output
    passed = passed and "SCRIPT ERROR" not in output and "SHADER ERROR" not in output
    receipts.append({"gate": mode, "exit": rc, "marker": markers[mode], "pass": passed})
    (HERE / "validation.json").write_text(json.dumps(receipts, indent=2) + "\n", encoding="utf-8")
    print("\n".join(output.splitlines()[-12:]), flush=True)
    if not passed:
        raise SystemExit(f"T60b {mode} failed: see {log}")
print("T60b ALL VALIDATION GATES PASS", flush=True)
