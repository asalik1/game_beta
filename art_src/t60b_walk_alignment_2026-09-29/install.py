"""Back up exact outgoing desktop/mobile strips, then install reviewed candidates."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BACKUP = ROOT / "art_src/_backups/t60b_walk_alignment_2026-09-29"
for row in json.loads((HERE / "translations.json").read_text()):
    name = row["strip"] + ".png"
    target = ROOT / "game/assets/sprites" / name
    assert hashlib.sha256(target.read_bytes()).hexdigest() == row["before_sha256"], "outgoing changed"
    candidate = HERE / "candidate" / name
    assert hashlib.sha256(candidate.read_bytes()).hexdigest() == row["after_sha256"]
    for platform in ("game", "mobile/game"):
        old = ROOT / platform / "assets/sprites" / name
        saved = BACKUP / platform / "assets/sprites" / name
        saved.parent.mkdir(parents=True, exist_ok=True)
        assert not saved.exists(), "never overwrite an original backup"
        shutil.copy2(old, saved)
    temporary = target.with_suffix(".t60b.tmp.png")
    shutil.copyfile(candidate, temporary)
    temporary.replace(target)
    print("installed", target.relative_to(ROOT))
print("Mobile install: tools/sync_mobile.py --apply --paths assets/sprites/morwen_walk.png assets/sprites/korrag_walk_codex_s.png")
