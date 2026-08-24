#!/usr/bin/env python3
"""Fidelity audit: authored art resolution vs on-screen render size (2026-08-21).

Owner rule: a master sprite should be AT LEAST 2x the size it renders at in
game (classes render ~100px on-screen from ~235px art = 2.35x). This flags
DIVERGENCE — anything authored below 2x its render size will look soft/mushy
(gems shipped 32px authored and rendered ~40px = 1.0x, the review's catch).

metric per asset:  ratio = authored_px / rendered_screen_px   (flag if < 2.0)

Render formulas reverse-engineered from the engine (all x camera base zoom
1.12; SCREEN px = world px x zoom):
  hero/class : body renders at HERO_TARGET_BODY(52) * CHAR_RENDER_SCALE(1.7)
  mob        : cell renders at  scale * CHAR_RENDER_SCALE(1.7) * 16
  boss       : cell renders at  scale * 1.0 * 16         (bosses skip 1.7)
  npc        : body renders at  NPC body_target * 1.7 * nsize
  critter    : cell renders at  cell * _scale()          (direct texture scale)
  prop       : width renders at SCENERY_RENDER_WIDTH[family]  (width-normalized)

classes/props/critters need no runtime data. mobs/bosses/npcs need each
entity's `scale`/sprite -> pass --entities <json> from tools/fidelity_dump.gd.

  python fidelity_audit.py [--entities e.json] [--csv out.csv] [--min 2.0] [--only classes,props]
"""
from __future__ import annotations
import argparse, csv, json, re, sys
from pathlib import Path
import numpy as np
from PIL import Image

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
SPRITES = GAME / "assets" / "sprites"
ICONS = GAME / "assets" / "icons"
BALANCE = (GAME / "scripts" / "balance.gd").read_text(errors="replace")

ZOOM = 1.12          # game.gd camera.zoom base
CHAR = 1.7           # Balance.CHAR_RENDER_SCALE
HERO_BODY = 52.0     # player_core HERO_TARGET_BODY
MOB_MULT, BOSS_MULT = CHAR, 1.0
CLASSES = ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]
DIR8 = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
CRITTER_SCALE = {"butterfly": 0.6, "dragonfly": 0.5, "bat": 0.7, "hawk": 1.5,
                 "crow": 1.0, "wisp": 1.1, "fog": 11.0, "debris": 1.3,
                 "bird": 0.85, "dove": 0.85}


def _num_dict(name: str) -> dict[str, float]:
    m = re.search(name + r"\s*:?=\s*\{(.*?)\n\}", BALANCE, re.S)
    if not m:
        return {}
    return {k: float(v) for k, v in re.findall(r'"([\w]+)"\s*:\s*([0-9.]+)', m.group(1))}


SCENERY_W = _num_dict("const SCENERY_RENDER_WIDTH")
NPC_H = _num_dict("const NPC_HEIGHT_BY_SPRITE")


def cell_and_body(png: Path) -> tuple[int, int]:
    """(square cell px, frame-0 opaque body height px) for a sprite/strip."""
    im = Image.open(png).convert("RGBA")
    w, h = im.size
    n = max(1, round(w / h)) if w >= h else 1     # square-cell strip
    cw = w // n
    a = np.asarray(im.crop((0, 0, cw, h)))[..., 3]
    ys = np.where((a > 24).any(axis=1))[0]
    body = int(ys[-1] - ys[0] + 1) if len(ys) else h
    return h, body


def _idle_png(base: str) -> Path | None:
    for cand in (f"{base}_anim_codex.png", f"{base}_anim.png", f"{base}.png"):
        p = SPRITES / cand
        if p.exists():
            return p
    return None


def verdict(ratio: float, mn: float) -> str:
    if ratio >= mn:
        return "OK"
    if ratio >= mn * 0.75:
        return "THIN"
    return "LOW"


def audit(entities: dict | None, mn: float, only: set[str] | None):
    rows = []   # (category, asset, authored, rendered, ratio, verdict, note)

    def want(c):
        return not only or c in only

    # ---- classes + skins (all render through the hero body target) ----
    rendered = HERO_BODY * CHAR * ZOOM
    if want("classes"):
        for c in CLASSES:
            p = _idle_png(c)
            if not p:
                continue
            _, body = cell_and_body(p)
            rows.append(("class", c, body, round(rendered, 1), round(body / rendered, 2),
                         verdict(body / rendered, mn), "body vs 52*1.7*zoom"))
    if want("skins"):
        # one idle strip per skin: skins/<tier>/<class>_<skin>_anim.png (flat idle,
        # not the _anim_<dir> directional set). Same hero render (99px body).
        for p in sorted(SPRITES.glob("skins/*/*_anim.png")):
            if re.search(r"_anim_(" + "|".join(DIR8) + r")$", p.stem):
                continue
            tier = p.parent.name
            if tier == "archive":
                continue
            _, body = cell_and_body(p)
            rows.append(("skin", f"{tier}/{p.stem[:-5]}", body, round(rendered, 1),
                         round(body / rendered, 2), verdict(body / rendered, mn), tier))

    # ---- mobs / bosses / npcs (need runtime scale) ----
    if entities:
        for kind, e in entities.get("enemies", {}).items():
            spr = e.get("sprite", "")
            p = _idle_png(spr)
            if not p:
                continue
            cell, _ = cell_and_body(p)
            is_boss = e.get("boss", False)
            mult = BOSS_MULT if is_boss else MOB_MULT
            rendered = float(e["scale"]) * mult * 16.0 * ZOOM
            cat = "boss" if is_boss else "mob"
            if want(cat):
                rows.append((cat, spr, cell, round(rendered, 1), round(cell / rendered, 2),
                             verdict(cell / rendered, mn), f"scale {e['scale']} x{mult}"))
        if want("npc"):
            for spr, npc in entities.get("npcs", {}).items():
                p = _idle_png(spr)
                if not p:
                    continue
                _, body = cell_and_body(p)
                nsize = float(NPC_H.get(spr, 1.0)) or 1.0
                bt = float(npc.get("body_target", 46.0))
                rendered = bt * CHAR * nsize * ZOOM
                rows.append(("npc", spr, body, round(rendered, 1), round(body / rendered, 2),
                             verdict(body / rendered, mn), f"nsize {nsize:.2f}"))

    # ---- critters ----
    if want("critters"):
        for p in sorted(SPRITES.glob("critter_*.png")):
            kind = p.stem.replace("critter_", "")
            sc = CRITTER_SCALE.get(kind, 0.85)
            cell, _ = cell_and_body(p)
            rendered = cell * sc * ZOOM
            rows.append(("critter", kind, cell, round(rendered, 1), round(cell / rendered, 2),
                         verdict(cell / rendered, mn), f"scale {sc}"))

    # ---- props / landmarks / accents (width-normalized) ----
    if want("props"):
        seen = set()
        for fam, rw in sorted(SCENERY_W.items()):
            p = SPRITES / f"{fam}.png"
            if not p.exists() or fam in seen:
                continue
            seen.add(fam)
            native_w = Image.open(p).size[0]
            rendered = rw * ZOOM
            rows.append(("prop", fam, native_w, round(rendered, 1), round(native_w / rendered, 2),
                         verdict(native_w / rendered, mn), f"render_w {rw:.0f}"))

    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--entities", type=Path, default=None)
    ap.add_argument("--csv", type=Path, default=None)
    ap.add_argument("--min", type=float, default=2.0)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    ents = json.loads(args.entities.read_text()) if args.entities and args.entities.exists() else None
    only = {s.strip() for s in args.only.split(",") if s.strip()} or None
    rows = audit(ents, args.min, only)

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["category", "asset", "authored_px", "rendered_px", "ratio", "verdict", "note"])
            w.writerows(rows)

    by_cat: dict[str, list] = {}
    for r in rows:
        by_cat.setdefault(r[0], []).append(r)
    print(f"FIDELITY AUDIT — authored / rendered, flag < {args.min}x  (zoom {ZOOM})")
    total_bad = 0
    for cat in ("class", "skin", "mob", "boss", "npc", "critter", "prop"):
        cr = by_cat.get(cat)
        if not cr:
            continue
        bad = [r for r in cr if r[5] != "OK"]
        total_bad += len(bad)
        rat = [r[4] for r in cr]
        print(f"\n== {cat.upper()}  ({len(cr)} assets, min {min(rat):.2f}x / median {sorted(rat)[len(rat)//2]:.2f}x, {len(bad)} under {args.min}x) ==")
        for r in sorted(cr, key=lambda x: x[4])[:14]:
            flag = "" if r[5] == "OK" else f"  <-- {r[5]}"
            print(f"  {r[4]:5.2f}x  {r[1]:<26} {r[2]:>4}px -> {r[3]:>5}px  ({r[6]}){flag}")
        if len(cr) > 14:
            print(f"  ... {len(cr)-14} more")
    if not ents:
        print("\n(no --entities json: mob/boss/npc skipped — run tools/fidelity_dump.gd first)")
    print(f"\nTOTAL under {args.min}x: {total_bad} / {len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
