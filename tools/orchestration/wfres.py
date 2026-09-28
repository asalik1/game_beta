"""Print the final verifier verdict (and fixer summary) from a review_fix workflow journal.
usage: python wfres.py <wf_run_id>"""
import json, sys
from pathlib import Path
J = Path(r"C:/Users/asali/.claude/projects/C--Users-asali-Projects-AlgoTrading/647ede47-4203-4273-882d-88fd8784582a/subagents/workflows") / sys.argv[1] / "journal.jsonl"
res = []
for line in J.read_text(encoding="utf-8").splitlines():
    d = json.loads(line)
    if d.get("type") == "result":
        v = d.get("result", d.get("value"))
        if isinstance(v, str):
            try: v = json.loads(v)
            except Exception: pass
        res.append(v)
ver = [r for r in res if isinstance(r, dict) and "accept" in r]
fix = [r for r in res if isinstance(r, dict) and "applied" in r]
if fix: print("FIX commits:", fix[-1].get("commits")); print("FIX quick:", str(fix[-1].get("quick_suite"))[:300])
if ver:
    v = ver[-1]
    print("ACCEPT:", v["accept"])
    for b in v["blockers"]: print(f" - [{b['severity']}] {b['title']} @ {b['location']}\n     {b['detail'][:400]}")
    print("PLAYER:", v["player_summary"]); print("TESTS:", v["tests_run"][:700]); print("RISK:", v["risk_notes"][:1200])
else:
    print("no verdict yet;", len(res), "results")
