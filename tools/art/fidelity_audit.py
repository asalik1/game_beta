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
  boss       : cell renders at  scale * CHAR_RENDER_SCALE(1.7) * 16
               (CORRECTED 2026-08-25: enemy.gd:312 applies CHAR_RENDER_SCALE
               unconditionally — "mobs AND bosses". The old "bosses skip 1.7"
               came from a stale var comment and understated every boss's
               render size by 1.7x. The veyx def's own sizing comment
               confirms the 1.7: 22*1.7*16*0.556 = the documented ~332px.)
  npc        : body_target>0: body renders at body_target * 1.7 * nsize
               body_target=0 (legacy): frame WIDTH renders at
               NPC_RENDER_SCALE(3.0) * 1.7 * nsize * 16
  critter    : cell renders at  cell * _scale()          (direct texture scale)
  prop       : width renders at SCENERY_RENDER_WIDTH[family]  (width-normalized;
               every VARIANT in the family renders at the family width, so
               variants are audited too — the tall "*3" slivers hid here)

classes/props/critters need no runtime data. mobs/bosses/npcs need each
entity's `scale`/sprite -> pass --entities <json> from tools/fidelity_dump.gd.

  python fidelity_audit.py [--entities e.json] [--csv out.csv] [--min 2.0] [--only classes,props,structures]
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
NPC_RENDER = 3.0     # Balance.NPC_RENDER_SCALE (legacy no-body-target NPCs)
MOB_MULT, BOSS_MULT = CHAR, CHAR   # enemy.gd:312: 1.7 for mobs AND bosses
CLASSES = ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]
DIR8 = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
# mirrors ambience.gd Critter._scale() (2026-08-25 hi-res critter cells)
CRITTER_SCALE = {"butterfly": 0.3, "dragonfly": 0.25, "bat": 0.2625, "hawk": 0.375,
                 "crow": 0.375, "wisp": 1.1, "fog": 11.0, "debris": 1.3,
                 "bird": 0.31875, "dove": 0.31875, "bird_perched": 0.31875}


def _num_dict(name: str) -> dict[str, float]:
    m = re.search(name + r"\s*:?=\s*\{(.*?)\n\}", BALANCE, re.S)
    if not m:
        return {}
    return {k: float(v) for k, v in re.findall(r'"([\w]+)"\s*:\s*([0-9.]+)', m.group(1))}


SCENERY_W = _num_dict("const SCENERY_RENDER_WIDTH")
NPC_H = _num_dict("const NPC_HEIGHT_BY_SPRITE")


def _prop_families() -> dict[str, list[str]]:
    """terrains.gd PROP_VARIANT_GROUPS: family base -> [base, variant2, ...]."""
    src = (GAME / "scripts" / "terrains.gd").read_text(errors="replace")
    m = re.search(r"const PROP_VARIANT_GROUPS := \[(.*?)\n\]", src, re.S)
    fams: dict[str, list[str]] = {}
    if m:
        for row in re.findall(r"\[([^\]]+)\]", m.group(1)):
            names = re.findall(r'"([\w]+)"', row)
            if names:
                fams[names[0]] = names
    return fams


PROP_FAMILIES = _prop_families()


def _structures() -> dict:
    """terrains.gd STRUCTURES: sprite -> the def's authored world width `w`.

    THE GAP THIS CLOSES (2026-09-06): a prop is scored at its SCENERY_RENDER_WIDTH,
    but `_add_structure` scales the SAME PNG to the structure def's `w` when the
    piece is placed as an ecology landmark -- 84-190px against scatter widths of
    71-122 -- so twelve masters passed the audit at 2.2-2.5x while rendering at
    1.02-1.65x as landmarks. Nobody could see it because this lane did not exist.
    When one sprite backs several defs, the LARGEST width wins (the worst case)."""
    src = (GAME / "scripts" / "terrains.gd").read_text(errors="replace")
    out = {}
    for blk in re.finditer(r'"([a-z_0-9]+)":\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', src, re.S):
        body = blk.group(2)
        sm = re.search(r'"sprite":\s*"([a-z0-9_]+)"', body)
        wm = re.search(r'"w":\s*([0-9.]+)', body)
        if sm and wm:
            out[sm.group(1)] = max(out.get(sm.group(1), 0.0), float(wm.group(1)))
    return out


STRUCTURES_W = _structures()


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


def audit(entities: dict | None, mn: float, only: set[str] | None, include_unplaced: bool = False):
    rows = []   # (category, asset, authored, rendered, ratio, verdict, note)
    skipped_unplaced = 0

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
            if not e.get("placed", True) and not include_unplaced:
                skipped_unplaced += 1
                continue
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
                bt = float(npc.get("body_target", 0.0))
                nsize = float(NPC_H.get(spr, 1.0)) or 1.0
                if bt > 0.0:
                    # authored-body path: alpha body height -> body_target world px
                    _, body = cell_and_body(p)
                    rendered = bt * CHAR * nsize * ZOOM
                    rows.append(("npc", spr, body, round(rendered, 1), round(body / rendered, 2),
                                 verdict(body / rendered, mn), f"nsize {nsize:.2f} body"))
                else:
                    # legacy path (no NPC_BODY_TARGETS entry): frame WIDTH
                    # renders at NPC_RENDER_SCALE * CHAR * nsize * 16 world px
                    im = Image.open(p)
                    w, h = im.size
                    fw = w // max(1, round(w / h)) if w >= h else w
                    rendered = NPC_RENDER * CHAR * nsize * 16.0 * ZOOM
                    rows.append(("npc", spr, fw, round(rendered, 1), round(fw / rendered, 2),
                                 verdict(fw / rendered, mn), f"nsize {nsize:.2f} legacy-w"))

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
    # Every VARIANT in a PROP_VARIANT_GROUPS family renders at the FAMILY's
    # width (game_world resolves prop_base() before _scenery_render_scale), so
    # each variant file is audited against the family width too — the tall
    # "*3" tree slivers (tree_autumn3 at 0.51x) hid behind base-only auditing.
    if want("props"):
        seen = set()
        for fam, rw in sorted(SCENERY_W.items()):
            if fam in seen:
                continue
            seen.add(fam)
            rendered = rw * ZOOM
            for member in PROP_FAMILIES.get(fam, [fam]):
                p = SPRITES / f"{member}.png"
                if not p.exists():
                    continue
                native_w = Image.open(p).size[0]
                label = member if member == fam else f"{member} ({fam})"
                rows.append(("prop", label, native_w, round(rendered, 1),
                             round(native_w / rendered, 2),
                             verdict(native_w / rendered, mn), f"render_w {rw:.0f}"))

    # ---- STRUCTURES (ecology landmarks): the same PNG scaled to the def's `w` ----
    if want("structures"):
        for sprite, w in sorted(STRUCTURES_W.items()):
            p = SPRITES / f"{sprite}.png"
            if not p.exists():
                continue
            rendered = w * ZOOM
            native_w = Image.open(p).size[0]
            rows.append(("structure", sprite, native_w, round(rendered, 1),
                         round(native_w / rendered, 2),
                         verdict(native_w / rendered, mn), f"def w {w:.0f}"))

    audit.skipped_unplaced = skipped_unplaced
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--entities", type=Path, default=None)
    ap.add_argument("--csv", type=Path, default=None)
    ap.add_argument("--min", type=float, default=2.0)
    ap.add_argument("--only", default="")
    ap.add_argument("--include-unplaced", action="store_true",
                    help="audit enemies defined but never placed in a zone (default: skip — they're not seen)")
    args = ap.parse_args()
    ents = json.loads(args.entities.read_text()) if args.entities and args.entities.exists() else None
    only = {s.strip() for s in args.only.split(",") if s.strip()} or None
    rows = audit(ents, args.min, only, args.include_unplaced)

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
    for cat in ("class", "skin", "mob", "boss", "npc", "critter", "prop", "structure"):
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
        print("\n(no --entities json: mob/boss/npc skipped — run game/fidelity_dump.gd first)")
    elif getattr(audit, "skipped_unplaced", 0):
        print(f"\n(skipped {audit.skipped_unplaced} enemies DEFINED but never placed in a zone — "
              "not seen in game; --include-unplaced to audit them anyway)")
    print(f"\nTOTAL under {args.min}x: {total_bad} / {len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
