"""Run DeepSeek as an agentic coder via Claude Code's Anthropic-compatible backend.

usage: python ds_agent.py <workdir> <prompt_file> <out_dir> [--model deepseek-v4-pro] [--timeout 1800] [--readonly]
Writes <out_dir>/result.json (claude -p json output), stderr.txt, receipt.json.
The environment is scrubbed of parent CLAUDE*/ANTHROPIC* vars so the child
authenticates with the DeepSeek key, not the host session's OAuth token.
"""
import argparse, datetime as dt, json, os, subprocess, sys, winreg
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("workdir"); ap.add_argument("prompt_file"); ap.add_argument("out_dir")
ap.add_argument("--model", default="deepseek-v4-pro")
ap.add_argument("--timeout", type=int, default=1800)
ap.add_argument("--readonly", action="store_true")
a = ap.parse_args()

key = os.environ.get("DEEPSEEK_API_KEY")
if not key:
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
        key = winreg.QueryValueEx(h, "DEEPSEEK_API_KEY")[0]

env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("CLAUDE", "ANTHROPIC"))}
env.update({
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_API_KEY": key,
    "ANTHROPIC_MODEL": a.model,
    "ANTHROPIC_SMALL_FAST_MODEL": "deepseek-flash",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-flash",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": a.model,
    "ANTHROPIC_DEFAULT_OPUS_MODEL": a.model,
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_AUTOUPDATER": "1",
})
out = Path(a.out_dir); out.mkdir(parents=True, exist_ok=True)
claude = r"C:/Users/asali/AppData/Roaming/npm/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
args = [claude, "-p", "--model", a.model, "--output-format", "json",
        "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
        "--settings", '{"disableAllHooks":true}']
if a.readonly:
    args += ["--permission-mode", "dontAsk", "--allowedTools", "Read,Grep,Glob"]
else:
    args += ["--permission-mode", "bypassPermissions"]
prompt = Path(a.prompt_file).read_text(encoding="utf-8")
start = dt.datetime.now(dt.timezone.utc)
timed_out = False
with (out / "result.json").open("w", encoding="utf-8") as so, (out / "stderr.txt").open("w", encoding="utf-8") as se:
    p = subprocess.Popen(args, cwd=a.workdir, env=env, stdin=subprocess.PIPE, stdout=so, stderr=se,
                         text=True, encoding="utf-8")
    try:
        p.communicate(prompt, timeout=a.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True; p.kill(); p.wait()
rec = {"provider": "deepseek", "model": a.model, "workdir": a.workdir, "started": start.isoformat(),
       "finished": dt.datetime.now(dt.timezone.utc).isoformat(), "returncode": p.returncode, "timed_out": timed_out}
try:
    r = json.loads((out / "result.json").read_text(encoding="utf-8"))
    rec.update({"is_error": r.get("is_error"), "num_turns": r.get("num_turns"), "result_head": str(r.get("result"))[:600]})
except Exception as e:
    rec["parse_error"] = str(e)
(out / "receipt.json").write_text(json.dumps(rec, indent=2), encoding="utf-8")
print(json.dumps(rec))
