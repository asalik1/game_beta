#!/usr/bin/env python
"""UNUSED ART scan (2026-09-06): which sprite strips can the engine never show?

WHY (owner, 2026-09-06): "skeleton mage unused art being surfaced is a concern
wondering what other unused art is causing agents to not realize and waste time
on them". Wave 3 of the walk regens spent four subjects on strips the renderer
suppresses, and nobody noticed because nothing measured reachability. This does.

Three classes, each decided from the ENGINE's own tables, not from a guess:

  DEAD BY TABLE      `Art.MOB_IDLE_ONLY_LOCOMOTION` blanks BOTH `_strip_walk` and
                     `_dir_walk` (enemy.gd), so every `<sprite>_walk*.png` for
                     those bodies is unreachable -- they glide on their idle.
                     `Art.MOB_FLAT_WALK_LOCOMOTION` blanks only the 8-dir set, so
                     the flat walk is live and `<sprite>_walk_<dir>.png` is not.
                     A boss in `BOSS_DIRECTIONAL_WALK` reads `_walk_codex_<dir>`
                     instead, so ITS plain `_walk` is the dead one.
  DEAD BY PLACEMENT  an enemy defined in Story but placed in no zone: its strips
                     are unreachable in a normal playthrough (dev spawns and the
                     codex still render it). NOISY and opt-in (`--placement`):
                     the scan reads zone tables textually, so a kind spawned
                     through a code path rather than a table row reads as
                     unplaced. Treat a hit as a question, never as a verdict --
                     the authority is `fidelity_audit.py --entities` with a live
                     `fidelity_dump.gd` run behind it. Prop names that terrains.gd
                     places as scenery are filtered out.

    python tools/art/unused_art_scan.py [--csv out.csv] [--class dead-by-table]

Read it BEFORE planning an art batch: regenerating a strip in the first class is
pure waste, and worse, it ships art nobody can see and therefore nobody checks
(three of the four wave-3 subjects had drifted off-model by the time the owner
caught it).
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPR = ROOT / "game" / "assets" / "sprites"
SCRIPTS = ROOT / "game" / "scripts"
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")


def _table(src: str, name: str) -> set[str]:
    m = re.search(r"const %s\s*:?=\s*\{(.*?)\n\}" % name, src, re.S)
    if not m:
        return set()
    return set(re.findall(r'"([a-z0-9_]+)"\s*:\s*true', m.group(1)))


def dead_by_table() -> list[tuple[str, str, str]]:
    art = (SCRIPTS / "art.gd").read_text(encoding="utf-8", errors="replace")
    idle_only = _table(art, "MOB_IDLE_ONLY_LOCOMOTION")
    flat_only = _table(art, "MOB_FLAT_WALK_LOCOMOTION")
    boss_dir = _table(art, "BOSS_DIRECTIONAL_WALK")
    out: list[tuple[str, str, str]] = []
    for b in sorted(idle_only):
        if b in boss_dir:
            p = SPR / f"{b}_walk.png"
            if p.exists():
                out.append((b, "boss reads _walk_codex; plain _walk dead", p.name))
            continue
        for name in [f"{b}_walk.png"] + [f"{b}_walk_{d}.png" for d in DIRS]:
            if (SPR / name).exists():
                out.append((b, "MOB_IDLE_ONLY_LOCOMOTION (it glides; no walk plays)", name))
    for b in sorted(flat_only):
        for d in DIRS:
            name = f"{b}_walk_{d}.png"
            if (SPR / name).exists():
                out.append((b, "MOB_FLAT_WALK_LOCOMOTION (flat walk plays; dir set dead)", name))
    return out


def placed_enemies() -> set[str]:
    """Every enemy kind a zone can spawn, read from the zone tables + content modules."""
    kinds: set[str] = set()
    files = [SCRIPTS / "story.gd"] + sorted((SCRIPTS / "content").glob("*.gd"))
    for f in files:
        try:
            src = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for key in ("packs", "enemies", "elites", "boss", "adds", "spawn"):
            for blk in re.findall(r'"%s"\s*:\s*\[([^\]]*)\]' % key, src):
                kinds |= set(re.findall(r'"([a-z0-9_]+)"', blk))
            for one in re.findall(r'"%s"\s*:\s*"([a-z0-9_]+)"' % key, src):
                kinds.add(one)
    return kinds


def enemy_sprites() -> dict[str, str]:
    """kind -> sprite name, from Story.ALL_ENEMIES-style rows."""
    out: dict[str, str] = {}
    for f in [SCRIPTS / "story.gd"] + sorted((SCRIPTS / "content").glob("*.gd")):
        try:
            src = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for kind, body in re.findall(r'"([a-z0-9_]+)"\s*:\s*\{([^{}]{0,400}?)\}', src, re.S):
            m = re.search(r'"sprite"\s*:\s*"([a-z0-9_]+)"', body)
            if m:
                out[kind] = m.group(1)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", type=Path, default=None)
    ap.add_argument("--class", dest="cls", default="", help="dead-by-table | dead-by-placement")
    ap.add_argument("--placement", action="store_true",
                    help="also run the NOISY placement class (off by default: see the docstring)")
    args = ap.parse_args()
    rows: list[tuple[str, str, str, str]] = []

    if args.cls in ("", "dead-by-table"):
        for sub, why, name in dead_by_table():
            rows.append(("dead-by-table", sub, name, why))

    if args.cls == "dead-by-placement" or (args.placement and args.cls == ""):
        placed = placed_enemies()
        sprites = enemy_sprites()
        try:    # a name terrains.gd scatters is a PROP row, not an enemy
            terr = (SCRIPTS / "terrains.gd").read_text(encoding="utf-8", errors="replace")
            props = set(re.findall(r'"([a-z0-9_]+)"', terr))
        except OSError:
            props = set()
        for kind, sprite in sorted(sprites.items()):
            if kind in placed or kind in props or sprite in props:
                continue
            owned = sorted(p.name for p in SPR.glob(f"{sprite}_*.png"))
            if owned:
                rows.append(("dead-by-placement", kind,
                             f"{len(owned)} file(s) e.g. {owned[0]}",
                             "defined in Story but no zone spawns it (dev/codex only)"))

    by_class: dict[str, list] = {}
    for r in rows:
        by_class.setdefault(r[0], []).append(r)
    for cls, rs in by_class.items():
        subs = sorted({r[1] for r in rs})
        print(f"\n== {cls.upper()}  ({len(rs)} entries over {len(subs)} subjects)")
        seen: dict[str, int] = {}
        for _, sub, name, why in rs:
            seen[sub] = seen.get(sub, 0) + 1
        for sub in subs:
            why = next(r[3] for r in rs if r[1] == sub)
            print(f"  {sub:22s} {seen[sub]:2d} file(s)   {why}")
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["class", "subject", "file", "why"])
            w.writerows(rows)
        print(f"\n-> {args.csv}")
    print(f"\n{len(rows)} unreachable entries in total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
