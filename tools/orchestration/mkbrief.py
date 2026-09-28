"""Compose an implementer brief from scout proposals.

usage: python mkbrief.py <task_id> "<task title>" <idx> [<idx> ...] [--note "extra guidance"]
Reads ideate/claude_scouts.json, writes briefs/<task_id>.prompt.md = _header.md + task body.
"""
import argparse, json
from pathlib import Path

Q = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument("task_id"); ap.add_argument("title"); ap.add_argument("idx", nargs="+", type=int)
ap.add_argument("--note", default="")
a = ap.parse_args()
props = json.loads((Q / "ideate/claude_scouts.json").read_text(encoding="utf-8"))
body = [f"## Task {a.task_id} — {a.title}\n",
        "An independent read-only scout reported the problem(s) below with file:line evidence. Line numbers may "
        "have drifted. VERIFY each claim against the current code before changing anything; if a claim is wrong "
        "or already fixed, say so in your final report and skip that part rather than forcing a change.\n"]
for n, i in enumerate(a.idx, 1):
    p = props[i]
    files = [f for f in p["files"] if not f.startswith("mobile/")]
    body.append(f"### Part {n}: {p['title']}\n")
    body.append(f"**Problem:** {p['problem']}\n")
    body.append(f"**Evidence (scout's reading):** {p['evidence']}\n")
    body.append(f"**Suggested change (adapt if you find a simpler/more robust way):** {p['change']}\n")
    body.append(f"**Likely files:** {', '.join(files)}\n")
    body.append(f"**Suggested verification:** {p['verification']}\n"
                "(Ignore any mobile/ steps — the integrator handles mobile sync and mobile gates.)\n")
if a.note:
    body.append(f"### Orchestrator notes\n{a.note}\n")
out = Q / "briefs" / f"{a.task_id}.prompt.md"
out.write_text((Q / "briefs/_header.md").read_text(encoding="utf-8") + "\n" + "\n".join(body), encoding="utf-8")
print(out)
