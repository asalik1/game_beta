"""Run Codex headless (`codex exec`) as an agentic coder.

usage: python cx_agent.py <workdir> <prompt_file> <out_dir> [--model M] [--effort high] [--timeout 2400] [--readonly]
Writes <out_dir>/last_message.md (-o), events.jsonl (--json), stderr.txt, receipt.json.
Binary resolved from ~/.codex/config.toml CODEX_CLI_PATH / tools/codex_bin.py (hash drifts).
"""
import argparse, datetime as dt, json, subprocess, sys
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("workdir"); ap.add_argument("prompt_file"); ap.add_argument("out_dir")
ap.add_argument("--model", default=None)
ap.add_argument("--effort", default="high")
ap.add_argument("--timeout", type=int, default=2400)
ap.add_argument("--readonly", action="store_true")
a = ap.parse_args()

repo = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(repo / "tools"))
from codex_bin import resolve  # noqa: E402
codex = str(resolve())

out = Path(a.out_dir).resolve(); out.mkdir(parents=True, exist_ok=True)
args = [codex, "exec", "-C", a.workdir, "--skip-git-repo-check", "--json",
        "-o", str(out / "last_message.md"), "-c", f'model_reasoning_effort="{a.effort}"']
if a.model:
    args += ["-m", a.model]
if a.readonly:
    args += ["-s", "read-only"]
else:
    args += ["--dangerously-bypass-approvals-and-sandbox"]
args += ["-"]
prompt = Path(a.prompt_file).read_text(encoding="utf-8")
start = dt.datetime.now(dt.timezone.utc)
timed_out = False
with (out / "events.jsonl").open("w", encoding="utf-8") as so, (out / "stderr.txt").open("w", encoding="utf-8") as se:
    p = subprocess.Popen(args, cwd=a.workdir, stdin=subprocess.PIPE, stdout=so, stderr=se, text=True, encoding="utf-8")
    try:
        p.communicate(prompt, timeout=a.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
        p.wait()
lm = out / "last_message.md"
rec = {"provider": "codex", "model": a.model or "config-default", "effort": a.effort, "workdir": a.workdir,
       "started": start.isoformat(), "finished": dt.datetime.now(dt.timezone.utc).isoformat(),
       "returncode": p.returncode, "timed_out": timed_out,
       "result_head": lm.read_text(encoding="utf-8")[:600] if lm.exists() else None}
(out / "receipt.json").write_text(json.dumps(rec, indent=2), encoding="utf-8")
print(json.dumps(rec))
