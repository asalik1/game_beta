"""Resolve the installed Codex CLI binary (codex.exe) -- the ONE place that knows where it is.

The Codex desktop app installs the CLI under a HASHED directory that changes on every app
update (`%LOCALAPPDATA%\\OpenAI\\Codex\\bin\\<hash>\\codex.exe`; three different hashes between
2026-07-30 and 2026-08-17). A hard-coded path silently breaks on the next update, so every
driver resolves it through here (or the same three-step order in tools/art/run_codex_batch.ps1):

  1. `CODEX_CLI_PATH` in ~/.codex/config.toml -- the app writes it (SINGLE-quoted TOML string,
     inside the [mcp_servers.node_repl.env] block).
  2. the newest codex.exe under %LOCALAPPDATA%\\OpenAI\\Codex\\bin (config can lag an update).
  3. `codex` on PATH (an npm install; not the case on this machine).

Usage:
  python tools/codex_bin.py            -> prints the path (bash: CODEX=$(python tools/codex_bin.py))
  python tools/codex_bin.py --version  -> also runs `codex --version`
  from codex_bin import resolve         -> resolve() -> str, raises FileNotFoundError

Full calling guide (flags, stdin rule, batching limits, image_gen quirks):
  C:\\Users\\asali\\Projects\\CODEX_HEADLESS.md (machine-wide, every project) + tools/CODEX_HEADLESS.md
  (the MMO layer). Other projects: copy this file or call it by absolute path.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys

_CFG_RE = re.compile(r"""^\s*CODEX_CLI_PATH\s*=\s*['"]([^'"]+)['"]""", re.M)


def resolve() -> str:
    cfg = os.path.join(os.path.expanduser("~"), ".codex", "config.toml")
    if os.path.isfile(cfg):
        with open(cfg, encoding="utf-8", errors="replace") as fh:
            m = _CFG_RE.search(fh.read())
        if m:
            p = m.group(1)
            if os.path.isfile(p):
                return p
            print(f"WARN codex_bin: config CODEX_CLI_PATH is stale ({p}); using newest install",
                  file=sys.stderr)
    local = os.environ.get("LOCALAPPDATA", "")
    bin_dir = os.path.join(local, "OpenAI", "Codex", "bin") if local else ""
    if bin_dir and os.path.isdir(bin_dir):
        found: list[tuple[float, str]] = []
        for root, _dirs, files in os.walk(bin_dir):
            if "codex.exe" in files:
                p = os.path.join(root, "codex.exe")
                found.append((os.path.getmtime(p), p))
        if found:
            found.sort(reverse=True)
            return found[0][1]
    on_path = shutil.which("codex")
    if on_path:
        return on_path
    raise FileNotFoundError(
        "codex.exe not found: no CODEX_CLI_PATH in ~/.codex/config.toml, nothing under "
        "%LOCALAPPDATA%\\OpenAI\\Codex\\bin, nothing on PATH")


if __name__ == "__main__":
    path = resolve()
    print(path)
    if "--version" in sys.argv[1:]:
        subprocess.run([path, "--version"], check=False)
