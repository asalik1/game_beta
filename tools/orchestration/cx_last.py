"""Extract the final agent message from a codex --json events.jsonl into last_message.md (if -o failed)."""
import json, sys
from pathlib import Path
d = Path(sys.argv[1])
last = None
for line in (d / "events.jsonl").read_text(encoding="utf-8", errors="replace").splitlines():
    try: e = json.loads(line)
    except Exception: continue
    item = e.get("item") or {}
    if item.get("type") in ("agent_message", "assistant_message") and item.get("text"):
        last = item["text"]
    elif e.get("type") == "item.completed" and isinstance(item.get("content"), list):
        pass
if last and not (d / "last_message.md").exists():
    (d / "last_message.md").write_text(last, encoding="utf-8")
print(last if last else "NO AGENT MESSAGE FOUND")
