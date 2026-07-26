#!/usr/bin/env python3
"""Crownless VISUAL ASSET GALLERY + quality audit.

One command builds a single HTML page showing EVERY visual asset the game
actually renders -- terrains, bosses, mobs, classes, skins, NPCs, props,
structures, gear, gems, consumables, ability icons, FX, UI -- each with its
files, metrics, in-game exposure, and a 0-10 quality rating.

Two jobs, one page:
  1. GALLERY   - look at everything the game ships, grouped and zoomable.
  2. AUDIT     - ratings + measured signals rank the weak points by how much
                 of the game they actually cover (bad x everywhere = fix first).

The only hand-managed input is the ratings file:
    tools/art/asset_ratings.csv      (id, rating, notes, rated_by)
Everything else is discovered on each run. Rate in the CSV, or rate inside
the page and hit "Export CSV" -- same file either way.

Pipeline:
    game/asset_dump.gd   walks the live data tables in the real engine and
                         renders procedural art (item icons, gems, ground
                         tiles, FX) that has no file on disk
    this script          assembles each key's file family (strips, 8-dir
                         sets), measures every image, finds orphans, merges
                         ratings, writes the page

Usage:
    python tools/art/asset_gallery.py              # full run, opens nothing
    python tools/art/asset_gallery.py --open       # ... and open the page
    python tools/art/asset_gallery.py --no-dump    # reuse the last engine dump
    python tools/art/asset_gallery.py --embed      # self-contained (shareable)
"""
from __future__ import annotations

import argparse
import csv
import html
import json
import math
import os
import subprocess
import sys
import webbrowser
from collections import Counter, defaultdict

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow required:  pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
OUT = os.path.join(ROOT, "build", "asset_gallery")
RATINGS = os.path.join(ROOT, "tools", "art", "asset_ratings.csv")
GODOT = os.path.join(ROOT, "tools", "Godot_v4.4.1-stable_win64_console.exe")

SPRITES = os.path.join(GAME, "assets", "sprites")
ICONS = os.path.join(GAME, "assets", "icons")

# Sub-trees that are working material, not shipped art -- their files are
# reported separately so they never read as "the game has 400 orphans".
NONSHIP_DIRS = ("placeholders/", "skins/archive/", "auroch_minotaur_refs/")

# Category display order + one-line "what am I looking at".
CATEGORIES = [
    ("classes", "Playable classes", "The six hero bodies and their full clip families."),
    ("skins", "Skins", "Elite/mythic wardrobe bodies and their awakened forms."),
    ("chromas", "Chromas", "Palette-swap colorways (shader recolor, no art of their own)."),
    ("bosses", "Bosses", "Every boss body, with its ability strips."),
    ("mobs", "Mobs", "Trash and elite enemy bodies."),
    ("npcs", "NPCs", "Non-combat bodies standing in authored rooms."),
    ("splash", "Splash / portraits", "Dialogue and intro art (speaker portraits, class covers)."),
    ("terrains", "Terrains", "Room floors, rendered through the live ground generator."),
    ("props", "Props / scenery", "Scatter obstacles, decor and rare accents."),
    ("structures", "Structures", "Authored landmarks, buildings and backdrops."),
    ("walls", "Walls", "The tiled room-perimeter art, per biome."),
    ("chests", "Chests", "Loot containers by tier and grade."),
    ("gear", "Gear icons", "One card per weapon/armor shape; the F-S grade ladder is its frames."),
    ("gems", "Gems", "Cut ladder Lv1-10 and the per-stat colorways."),
    ("consumables", "Consumables", "Potions, elixirs, scrolls and tomes."),
    ("quest_items", "Quest items / curios", "Bag icons for quest objects (many still placeholder-tagged)."),
    ("projectiles", "Projectiles", "Everything the combat code launches: arrows, bolts, boss shots."),
    ("abilities", "Ability icons", "Per class, per slot, plus themed variants."),
    ("glyphs", "UI glyphs", "Procedural stencils that back every un-painted icon."),
    ("fx", "FX", "Combat textures, impact strips and projectile art."),
    ("ui", "UI / HUD", "Buttons and overlays drawn by the HUD."),
    ("orphan", "Unwired art", "Files on disk that no wired key resolves. Dead art or a missed hookup."),
]
CAT_ORDER = {c[0]: i for i, (c) in enumerate(CATEGORIES)}

# Strip/clip suffixes, so a family's files sort into a sensible order.
CLIP_ORDER = ["", "anim", "idle", "walk", "run", "attack", "attack2", "cast",
              "dash", "ult", "ultidle", "death", "hit", "ability", "slam",
              "stab", "throw", "throne"]
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


# ---------------------------------------------------------------- engine ---

def run_dump() -> None:
    """Walk the live data tables in the real engine (see game/asset_dump.gd)."""
    os.makedirs(OUT, exist_ok=True)
    if not os.path.exists(GODOT):
        sys.exit("engine not found: %s" % GODOT)
    cmd = [GODOT, "--headless", "--path", GAME, "--script", "res://asset_dump.gd",
           "--", OUT.replace("\\", "/")]
    res = subprocess.run(cmd, capture_output=True, text=True)
    out = (res.stdout or "") + (res.stderr or "")
    if "ASSET DUMP:" not in out:
        sys.exit("engine dump failed:\n" + out[-3000:])
    print("  " + [l for l in out.splitlines() if "ASSET DUMP:" in l][0].strip())


# ----------------------------------------------------------------- files ---

def scan_files(root: str, prefix: str) -> dict:
    """Every shipped PNG under a root, keyed by its extension-less name."""
    found = {}
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if not f.lower().endswith(".png"):
                continue
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, root).replace("\\", "/")
            found[rel[:-4]] = {
                "key": rel[:-4],
                "path": (prefix + "/" + rel).replace("\\", "/"),
                "abs": full,
                "nonship": any(rel.startswith(d) for d in NONSHIP_DIRS),
            }
    return found


def assign_files(files: dict, keys: list) -> dict:
    """Map each PNG to the LONGEST wired key it belongs to.

    Longest-wins is what keeps `rock2.png` and `rock_ice.png` off `rock`
    while still handing `rock_anim.png` to it: a file joins key K when it IS
    K or starts with `K_`, and no longer wired key also claims it.
    """
    by_len = sorted(keys, key=len, reverse=True)
    owned = defaultdict(list)
    for name, info in sorted(files.items()):
        for k in by_len:
            if name == k or name.startswith(k + "_"):
                owned[k].append(info)
                info["owner"] = k
                break
    return owned


def code_refs() -> dict:
    """Asset names mentioned as string literals anywhere in the game's code.

    The data tables cover most wiring, but plenty of art is reached by a bare
    literal instead -- `Art.ui_icon("ui_mail")`, the buff-icon map, cover
    rotation, prop colorway variants. Scanning game/scripts for names that
    match a shipped file is how those stop reading as dead art.
    """
    import re
    lit = re.compile(r'"([a-z0-9_][a-z0-9_/]{2,})"')
    refs = defaultdict(list)
    root = os.path.join(GAME, "scripts")
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if not f.endswith(".gd"):
                continue
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, GAME).replace("\\", "/")
            try:
                text = open(full, encoding="utf-8").read()
            except Exception:
                continue
            for i, line in enumerate(text.splitlines(), 1):
                for m in lit.findall(line):
                    if len(refs[m]) < 4:
                        refs[m].append("%s:%d" % (rel, i))
    return refs


# Name prefix -> the category a code-referenced asset belongs in.
REF_CATEGORY = [
    ("splash_", "splash"), ("class_splash_", "splash"), ("cover", "splash"),
    ("fx_", "fx"), ("mob_", "projectiles"), ("arrow_", "projectiles"),
    ("ui_", "ui"), ("buff_", "ui"), ("icon_", "gear"), ("w_", "gear"),
    ("gem", "gems"), ("ground_", "terrains"), ("wall_", "walls"),
    ("chest_", "chests"), ("skins/", "skins"),
]


def guess_category(name: str) -> str:
    stem = name.split("/")[-1]
    for pre, cat in REF_CATEGORY:
        if name.startswith(pre) or stem.startswith(pre):
            return cat
    return "props"


def orphan_base(name: str, pool: dict) -> str:
    """Family head for an unwired file.

    8-direction sets always collapse to their base; a clip suffix collapses
    only when the shorter name is itself a shipped file — so `auroch_anim_e`
    folds into `auroch`, while `fx_boss_earth_fang` stays whole.
    """
    head, _sep, stem = name.rpartition("/")
    toks = stem.split("_")
    while len(toks) > 1 and toks[-1] in DIRS:
        toks = toks[:-1]
    while len(toks) > 1 and toks[-1] in CLIP_ORDER:
        shorter = "_".join(toks[:-1])
        if (head + "/" + shorter if head else shorter) not in pool:
            break
        toks = toks[:-1]
    base = "_".join(toks)
    return head + "/" + base if head else base


def clip_of(name: str, key: str) -> tuple:
    """(clip, direction) for one file of a family. ('', '') is the base art."""
    rest = name[len(key):].lstrip("_")
    if not rest:
        return ("", "")
    parts = rest.split("_")
    direction = ""
    if len(parts) > 1 and parts[-1] in DIRS:
        direction = parts[-1]
        parts = parts[:-1]
    elif parts[-1] in DIRS and len(parts) == 1:
        direction = parts[-1]
        parts = []
    return ("_".join(parts), direction)


# --------------------------------------------------------------- metrics ---

_METRIC_CACHE = {}


def dimensions(path: str) -> dict:
    """Width/height only (header read, no pixels) — cheap enough for 4000 files.

    Frame count follows from it: these strips are horizontal runs of square
    cells, so a 7:1 image is a 7-frame clip, and the gallery can play it.
    """
    try:
        with Image.open(path) as im:
            w, h = im.size
    except Exception:
        return {"w": 0, "h": 0, "frames": 1}
    frames = max(1, round(w / h)) if h and w > h * 1.5 else 1
    return {"w": w, "h": h, "frames": frames}


def measure(path: str) -> dict:
    """Objective signals for one image. These are evidence, not a verdict."""
    if path in _METRIC_CACHE:
        return _METRIC_CACHE[path]
    m = {"w": 0, "h": 0, "colors": 0, "fill": 0.0, "semi": 0.0,
         "native": 0, "value": 0.0, "sat": 0.0}
    try:
        im = Image.open(path).convert("RGBA")
    except Exception:
        _METRIC_CACHE[path] = m
        return m
    w, h = im.size
    m["w"], m["h"] = w, h
    # Downsample only enormous sources -- metrics stay representative and a
    # 4000-file sweep stays interactive.
    work = im
    if w * h > 512 * 512:
        work = im.resize((min(w, 512), min(h, 512)), Image.NEAREST)
    raw = work.tobytes()
    px = [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]
    opaque = [p for p in px if p[3] > 8]
    if not opaque:
        _METRIC_CACHE[path] = m
        return m
    m["fill"] = round(len(opaque) / float(len(px)), 3)
    m["semi"] = round(sum(1 for p in px if 8 < p[3] < 248) / float(len(px)), 3)
    m["colors"] = len(set((p[0], p[1], p[2]) for p in opaque))
    vals, sats = [], []
    for r, g, b, _a in opaque[::max(1, len(opaque) // 4000)]:
        mx, mn = max(r, g, b), min(r, g, b)
        vals.append(mx / 255.0)
        sats.append(0.0 if mx == 0 else (mx - mn) / float(mx))
    m["value"] = round(sum(vals) / len(vals), 3)
    m["sat"] = round(sum(sats) / len(sats), 3)
    m["native"] = native_res(im)
    _METRIC_CACHE[path] = m
    return m


def native_res(im: Image.Image) -> int:
    """Modal horizontal run length = the source pixel size before upscaling.

    A 4 here on a 128px file means the art is really 32px blown up 4x, which
    is exactly the "why does this look chunky" question the gallery answers.
    """
    w, h = im.size
    if w > 256 or h > 256:
        im = im.resize((min(w, 256), min(h, 256)), Image.NEAREST)
        w, h = im.size
    px = im.load()
    runs = Counter()
    for y in range(0, h, max(1, h // 48)):
        run, prev = 1, None
        for x in range(w):
            c = px[x, y]
            if c[3] < 8:
                if prev is not None and prev[3] >= 8:
                    runs[min(run, 16)] += 1
                prev, run = c, 1
                continue
            if prev is not None and c == prev:
                run += 1
            else:
                if prev is not None and prev[3] >= 8:
                    runs[min(run, 16)] += 1
                run = 1
            prev = c
    if prev is not None and prev[3] >= 8:
        runs[min(run, 16)] += 1
    return runs.most_common(1)[0][0] if runs else 1


def status_of(rec: dict) -> tuple:
    """Is this asset SHIPPED, or is it known-provisional? And why.

    A weak score means nothing until you know whether players see it. Most of
    the roster's worst art is deliberately tagged placeholder -- mined ahead
    of a home, dev-launcher only -- and lumping it in with shipped art turns
    the fix-first list into noise.
    """
    meta = rec.get("meta") or {}
    if meta.get("nonship"):
        return "placeholder", "working file (placeholders / archive / refs tree)"
    if rec["source"] == "unwired":
        return "unwired", "no wired key resolves this file"
    if meta.get("placeholder"):
        return "placeholder", "tagged `placeholder: true` in its data table — dev launcher / codex Future tab only"
    if rec["category"] == "terrains" and rec["key"].startswith("terrain_ph_"):
        return "placeholder", "ph_* terrain — mined ahead of a chapter, not in shipped play"
    used = rec.get("used_in") or []
    if used and all(str(u).startswith("terrain: ph_") for u in used):
        return "placeholder", "only ever placed by placeholder (ph_*) terrains"
    if meta.get("placeholder_terrain") and not used:
        return "placeholder", "only reachable through placeholder terrains"
    if meta.get("grid_only"):
        return "unreferenced", "procedural grid in art.gd that no data table references"
    if rec["exposure"] == 0 and rec["category"] not in ("gems", "consumables", "glyphs",
                                                        "chromas", "gear", "ui", "chests"):
        return "unreferenced", "wired name with no reference found — verify before polishing"
    return "shipped", ""


def auto_score(rec: dict) -> tuple:
    """Technical health, 0-10, from measured signals ONLY.

    This is deliberately NOT an opinion about whether the art is good -- it
    flags the failure modes that are machine-visible (AA mush under
    nearest-neighbour magnification, baked upscales, empty canvases,
    wired-but-absent art) so an unrated catalogue still sorts weak-first.
    A human rating always wins where one exists.

    Returns (score, flags, breakdown) where breakdown is the arithmetic --
    every deduction with its reason -- so the page can show its working
    instead of asserting a number.
    """
    flags = []
    work = [["base", 7.5, "every measurable asset starts here"]]
    if rec["source"] == "missing":
        return 0.0, ["no art — wired name resolves to nothing"], \
            [["no art", 0.0, "the wired name resolves to nothing on disk"]]
    if rec["source"] in ("palette",):
        return None, [], []
    m = rec.get("metrics") or {}
    if not m.get("w"):
        return None, [], []
    score = 7.5

    def hit(delta: float, label: str, why: str) -> None:
        nonlocal score
        score += delta
        work.append([label, delta, why])
        flags.append(why)
    area = max(1, m["w"] * m["h"])
    op = max(1.0, m["fill"] * area)
    cpp = m["colors"] / op

    # Whether smooth art is a DEFECT depends on which way the art is scaled.
    # A 192px painterly mob drawn at 90px on screen is supersampled and reads
    # crisp; a 24px source blown up 3x turns its gradients to mush. Use the
    # measured on-screen magnification where the render path gives us one
    # (mobs/bosses), else fall back to source size.
    mag = rec.get("magnify")
    magnified = (mag > 1.6) if mag is not None else (m["w"] < 64)
    if magnified:
        if cpp > 0.35 and m["colors"] > 60:
            hit(-2.5, "AA-gradient art",
                "AA-gradient art (%d colors) magnified %s — turns to mush"
                % (m["colors"], ("%.1fx" % mag) if mag else "on screen"))
        elif cpp > 0.2 and m["colors"] > 40:
            hit(-1.2, "noisy palette",
                "noisy palette (%d colors for %d opaque px) at magnification"
                % (m["colors"], int(op)))
        if m["semi"] > 0.25:
            hit(-1.0, "soft edges",
                "soft/AA edges (%.0f%% semi-alpha) — will blur when scaled up"
                % (m["semi"] * 100))
    elif mag is not None and mag < 1.0:
        flags.append("supersampled (%.2fx on screen) — renders crisp by design" % mag)
        work.append(["supersampled", 0.0,
                     "renders at %.2fx — smooth shading is correct here, not a defect" % mag])
    # A baked upscale is a defect either way: the file is bigger than its art.
    # Skip tiny sources, where run-length detection is not reliable.
    if m["w"] >= 32:
        if m["native"] >= 3:
            hit(-1.8, "baked upscale",
                "baked %dx upscale — real detail is only ~%dpx"
                % (m["native"], m["w"] // m["native"]))
        elif m["native"] == 2:
            hit(-0.6, "baked upscale", "baked 2x upscale")
    if m["fill"] < 0.08:
        hit(-1.5, "empty canvas",
            "nearly empty canvas (%.0f%% opaque) — padding or a thin shape" % (m["fill"] * 100))
    if m["w"] < 20 and rec["category"] in ("bosses", "mobs", "npcs", "classes", "skins"):
        hit(-1.5, "tiny character source",
            "%dpx source for a character — will magnify hard" % m["w"])
    if m["value"] < 0.18:
        hit(-0.5, "very dark",
            "very dark (mean value %.2f) — check it reads on dark floors" % m["value"])
    if m["sat"] > 0.72:
        hit(-0.5, "very saturated",
            "highly saturated (%.2f) — check it fits the muted palette" % m["sat"])
    if rec["source"] == "procedural" and rec["category"] not in ("glyphs", "fx", "ui"):
        hit(-1.0, "no override art",
            "procedural ASCII-grid art — no hand-drawn override installed")
    return max(0.0, min(10.0, round(score, 1))), flags, work


# --------------------------------------------------------------- ratings ---

def load_ratings() -> dict:
    if not os.path.exists(RATINGS):
        return {}
    out = {}
    with open(RATINGS, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            rid = (row.get("id") or "").strip()
            if not rid:
                continue
            raw = (row.get("rating") or "").strip()
            try:
                rating = float(raw) if raw else None
            except ValueError:
                rating = None
            out[rid] = {"rating": rating,
                        "notes": (row.get("notes") or "").strip(),
                        "rated_by": (row.get("rated_by") or "").strip()}
    return out


def save_ratings(records: list, ratings: dict) -> int:
    """Rewrite the CSV so every discovered asset has a row to fill in.

    Existing ratings and notes are preserved verbatim; new assets land with
    an empty rating. Category/label/exposure ride along as read-only context
    so the file is editable in a spreadsheet without the gallery open.
    """
    added = 0
    with open(RATINGS, "w", newline="", encoding="utf-8") as fh:
        wr = csv.writer(fh)
        wr.writerow(["id", "rating", "notes", "rated_by",
                     "category", "label", "exposure", "status"])
        for r in sorted(records, key=lambda x: (CAT_ORDER.get(x["category"], 99), x["key"])):
            have = ratings.get(r["id"])
            if have is None:
                added += 1
            wr.writerow([
                r["id"],
                "" if not have or have["rating"] is None else ("%g" % have["rating"]),
                have["notes"] if have else "",
                have["rated_by"] if have else "",
                r["category"], r["label"], r["exposure"], r.get("status", ""),
            ])
    return added


# ------------------------------------------------------------------ build ---

def build(records: list) -> list:
    """Attach files, metrics, auto-score and priority to every asset."""
    sprite_files = scan_files(SPRITES, "game/assets/sprites")
    icon_files = scan_files(ICONS, "game/assets/icons")
    refs = code_refs()

    sprite_keys = [r["key"] for r in records if r["source"] in ("sprite", "procedural", "rendered")]
    icon_keys = [r["key"] for r in records
                 if r["source"] in ("icon", "rendered", "procedural")]
    owned_sprites = assign_files(sprite_files, sprite_keys)
    owned_icons = assign_files(icon_files, icon_keys)

    for r in records:
        fam = owned_sprites.get(r["key"], []) + owned_icons.get(r["key"], [])
        variants = []
        for f in fam:
            clip, direction = clip_of(f["key"], r["key"])
            variants.append({"name": f["key"], "src": f["path"], "clip": clip,
                             "dir": direction, "abs": f["abs"],
                             **dimensions(f["abs"])})
        variants.sort(key=lambda v: (
            CLIP_ORDER.index(v["clip"]) if v["clip"] in CLIP_ORDER else 50,
            v["clip"], DIRS.index(v["dir"]) if v["dir"] in DIRS else -1))
        r["files"] = len(variants)
        r["clips"] = sorted({v["clip"] for v in variants if v["clip"]})
        r["dirs"] = sorted({v["dir"] for v in variants if v["dir"]})

        # The card image: the engine's render if there is one, else the base
        # file, else the first variant.
        if r["source"] in ("rendered",) and r["src"]:
            rep_abs = os.path.join(OUT, r["src"].replace("/", os.sep))
        else:
            base = next((v for v in variants if not v["clip"]), None)
            pick = base or (variants[0] if variants else None)
            if pick:
                rep_abs = pick["abs"]
                if not r["src"]:
                    r["src"] = pick["src"]
            else:
                rep_abs = os.path.join(OUT, r["src"].replace("/", os.sep)) if r["src"] else ""
        r["metrics"] = measure(rep_abs) if rep_abs and os.path.exists(rep_abs) else {}
        r["variants"] = [{k: v[k] for k in ("name", "src", "clip", "dir", "w", "h", "frames")} for v in variants]

        # Mobs and bosses carry a scale stat, so their on-screen chunkiness is
        # computable: screen pixels per source texel (enemy.gd render path).
        meta = r.get("meta") or {}
        if r["category"] in ("mobs", "bosses") and r["metrics"].get("w"):
            cell = r["metrics"]["h"] or r["metrics"]["w"]
            r["magnify"] = round(float(meta.get("scale", 3.0)) * 27.2 / cell, 2)

    # Orphans: shipped files no wired key claims. Grouped into families the
    # same way wired art is, so a dead 18-strip boss is ONE finding, not 18.
    for pool, prefix in ((sprite_files, "sprite"), (icon_files, "icon")):
        loose = {n: i for n, i in pool.items() if not i.get("owner")}
        fams = defaultdict(list)
        for name in sorted(loose):
            fams[orphan_base(name, loose)].append(name)
        for base, names in sorted(fams.items()):
            # Reached by a bare literal in the game code? Then it is wired --
            # just not through a data table. Numbered colorway variants
            # (cottage_a2, cover_3) inherit their base name's wiring.
            hits = refs.get(base) or refs.get(base.rstrip("0123456789")) or []
            if not hits:
                for n in names:
                    hits = refs.get(n, [])
                    if hits:
                        break
            variants = []
            for n in names:
                clip, direction = clip_of(n, base)
                variants.append({"name": n, "src": loose[n]["path"], "clip": clip,
                                 "dir": direction, "abs": loose[n]["abs"],
                                 **dimensions(loose[n]["abs"])})
            variants.sort(key=lambda v: (
                CLIP_ORDER.index(v["clip"]) if v["clip"] in CLIP_ORDER else 50,
                v["clip"], DIRS.index(v["dir"]) if v["dir"] in DIRS else -1))
            rep = variants[0]
            nonship = loose[names[0]]["nonship"]
            cat = "orphan"
            note = ("working file (placeholders / archive / refs)" if nonship
                    else "no wired key resolves this — dead art, or a missed hookup")
            if hits and not nonship:
                cat = guess_category(base)
                note = ""
            records.append({
                "id": "%s/%s" % (cat, base), "category": cat, "key": base,
                "label": base.split("/")[-1].replace("_", " "),
                "source": ("unwired-nonship" if nonship else
                           ("code" if hits else "unwired")),
                "src": rep["src"], "exposure": len(hits), "used_in": hits,
                "meta": {"root": prefix, "nonship": nonship, "files": len(names)},
                "notes": note,
                "files": len(names),
                "clips": sorted({v["clip"] for v in variants if v["clip"]}),
                "dirs": sorted({v["dir"] for v in variants if v["dir"]}),
                "variants": [{k: v[k] for k in ("name", "src", "clip", "dir", "w", "h", "frames")}
                             for v in variants],
                "metrics": measure(rep["abs"]),
            })

    for r in records:
        auto, flags, work = auto_score(r)
        r["auto"] = auto
        r["auto_work"] = work
        r["flags"] = flags + ([r["notes"]] if r.get("notes") else [])
        r["status"], r["status_why"] = status_of(r)
    return records


def contact_sheets(records: list, dest: str, cols: int = 8, cell: int = 132) -> list:
    """Labelled grids, one per category — the format a human rates from.

    Same job the gallery page does interactively, in a form you can open in
    an image viewer, print, or hand to a reviewer. Every cell is numbered
    `<category>#<n>` so a note maps back to an exact asset.
    """
    from PIL import ImageDraw
    os.makedirs(dest, exist_ok=True)
    pad, lab = 6, 22
    written = []
    by_cat = defaultdict(list)
    for r in records:
        by_cat[r["category"]].append(r)
    for cat, _name, _blurb in CATEGORIES:
        rows = sorted(by_cat.get(cat, []), key=lambda x: (-x["exposure"], x["key"]))
        if not rows:
            continue
        for page in range(0, len(rows), cols * 8):
            chunk = rows[page:page + cols * 8]
            nrows = (len(chunk) + cols - 1) // cols
            W = cols * (cell + pad) + pad
            H = nrows * (cell + lab + pad) + pad
            sheet = Image.new("RGBA", (W, H), (106, 111, 125, 255))
            draw = ImageDraw.Draw(sheet)
            for i, r in enumerate(chunk):
                cx = pad + (i % cols) * (cell + pad)
                cy = pad + (i // cols) * (cell + lab + pad)
                draw.rectangle([cx, cy, cx + cell, cy + cell], fill=(60, 63, 72, 255))
                src = r["src"]
                path = (os.path.join(OUT, src.replace("/", os.sep)) if src.startswith("img/")
                        else os.path.join(ROOT, src.replace("/", os.sep)))
                if src and os.path.exists(path):
                    try:
                        im = Image.open(path).convert("RGBA")
                        # Multi-frame strips: show frame 0 only, or the grid
                        # reads as a smear of every animation at once.
                        if im.width > im.height * 1.6:
                            im = im.crop((0, 0, im.height, im.height))
                        sc = min(cell / im.width, cell / im.height)
                        sc = max(1, int(sc)) if sc >= 1 else sc
                        im = im.resize((max(1, int(im.width * sc)),
                                        max(1, int(im.height * sc))), Image.NEAREST)
                        if im.width > cell or im.height > cell:
                            im.thumbnail((cell, cell), Image.NEAREST)
                        sheet.alpha_composite(
                            im, (cx + (cell - im.width) // 2, cy + (cell - im.height) // 2))
                    except Exception:
                        pass
                tag = "%d %s" % (page + i, r["key"].split("/")[-1])
                draw.text((cx + 2, cy + cell + 4), tag[:24], fill=(240, 242, 248))
            out = os.path.join(dest, "%s_%d.png" % (cat, page // (cols * 8)))
            sheet.convert("RGB").save(out)
            written.append(out)
    return written


def priority(r: dict) -> float:
    """How badly this asset needs work = how weak x how much of the game it covers.

    SHIPPED art only. Placeholder and unwired art is provisional by decision,
    not by neglect -- ranking it here would bury the things players see under
    a hundred known-temporary mannequins.
    """
    score = r.get("rating")
    if score is None:
        score = r.get("auto")
    if score is None or r["category"] == "orphan" or r.get("status") != "shipped":
        return 0.0
    return round((10.0 - score) * math.log2(1 + max(0, r["exposure"])), 2)


# ------------------------------------------------------------------ HTML ---

EMBED_MAX_PX = 192
_EMBED_CACHE = {}


def to_data_uri(abs_path: str) -> str:
    """Inline a THUMBNAIL, never the source file.

    The sprite tree is ~620 MB; inlining it verbatim would produce an HTML no
    browser opens. Downscaling to EMBED_MAX_PX (nearest-neighbour, so pixel
    art stays pixel art) keeps a shareable page in the tens of megabytes.
    """
    import base64
    import io as _io
    if abs_path in _EMBED_CACHE:
        return _EMBED_CACHE[abs_path]
    try:
        im = Image.open(abs_path).convert("RGBA")
        if max(im.size) > EMBED_MAX_PX:
            im.thumbnail((EMBED_MAX_PX, EMBED_MAX_PX), Image.NEAREST)
        buf = _io.BytesIO()
        im.save(buf, "PNG", optimize=True)
        uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")
    except Exception:
        uri = ""
    _EMBED_CACHE[abs_path] = uri
    return uri


def resolve_src(src: str, embed: bool) -> str:
    """Gallery-relative URL for an asset (or an inlined thumbnail with --embed)."""
    if not src:
        return ""
    if src.startswith("img/"):
        return to_data_uri(os.path.join(OUT, src.replace("/", os.sep))) if embed else src
    abs_path = os.path.join(ROOT, src.replace("/", os.sep))
    if embed:
        return to_data_uri(abs_path) if os.path.exists(abs_path) else ""
    return os.path.relpath(abs_path, OUT).replace("\\", "/")


def write_html(records: list, embed: bool, dest: str) -> None:
    for r in records:
        r["url"] = resolve_src(r["src"], embed)
        # A portable page carries card thumbnails only -- inlining every clip
        # strip and 8-dir set would be the whole 620 MB sprite tree again.
        if embed:
            r["variants"] = []
        for v in r["variants"]:
            v["url"] = resolve_src(v["src"], embed)
        r["priority"] = priority(r)

    payload = []
    for r in records:
        m = r.get("metrics") or {}
        payload.append({
            "id": r["id"], "c": r["category"], "k": r["key"], "l": r["label"],
            "s": r["source"], "u": r["url"], "e": r["exposure"],
            "r": r.get("rating"), "a": r.get("auto"), "p": r["priority"],
            "n": r.get("rnotes", ""), "by": r.get("rated_by", ""),
            "w": m.get("w", 0), "h": m.get("h", 0), "col": m.get("colors", 0),
            "fill": m.get("fill", 0), "nat": m.get("native", 0),
            "val": m.get("value", 0), "sat": m.get("sat", 0),
            "mag": r.get("magnify"),
            "st": r.get("status", "shipped"), "why": r.get("status_why", ""),
            "aw": r.get("auto_work", []),
            "f": r["flags"], "used": r["used_in"][:12], "meta": r.get("meta", {}),
            "v": [{"n": v["name"], "u": v["url"], "c": v["clip"], "d": v["dir"],
                   "w": v.get("w", 0), "h": v.get("h", 0), "fr": v.get("frames", 1)}
                  for v in r["variants"]][:96],
            "nv": len(r["variants"]),
        })

    cats = [{"id": c, "name": n, "blurb": b} for c, n, b in CATEGORIES]
    doc = HTML_TEMPLATE.replace("__DATA__", json.dumps(payload, separators=(",", ":")))
    doc = doc.replace("__CATS__", json.dumps(cats, separators=(",", ":")))
    doc = doc.replace("__GENERATED__", html.escape(
        "%d assets  ·  %s" % (len(records), os.path.basename(RATINGS))))
    with open(dest, "w", encoding="utf-8") as fh:
        fh.write(doc)


HTML_TEMPLATE = r"""<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Crownless — Visual Asset Gallery</title>
<style>
:root{
  --bg:#0d0e12; --panel:#15171d; --panel2:#1b1e26; --line:#282c37;
  --ink:#e7e9f0; --dim:#9aa0b0; --gold:#d8b25c; --bad:#e2564a; --mid:#e0a13c;
  --ok:#6fbf73; --accent:#7aa2f7;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font:13px/1.5 "Segoe UI",system-ui,sans-serif}
a{color:var(--accent)}
header{position:sticky;top:0;z-index:20;background:linear-gradient(180deg,#12141a,#0d0e12);
  border-bottom:1px solid var(--line);padding:10px 16px}
h1{margin:0;font-size:16px;letter-spacing:.06em;text-transform:uppercase;color:var(--gold)}
.sub{color:var(--dim);font-size:11px;margin-top:2px}
.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:9px}
input,select,button{background:var(--panel2);color:var(--ink);border:1px solid var(--line);
  border-radius:5px;padding:5px 8px;font:inherit;font-size:12px}
input:focus,select:focus{outline:1px solid var(--accent)}
button{cursor:pointer}
button:hover{border-color:var(--gold)}
button.on{border-color:var(--gold);color:var(--gold)}
.stats{display:flex;gap:14px;flex-wrap:wrap;color:var(--dim);font-size:11px;margin-top:8px}
.stats b{color:var(--ink)}
main{padding:14px 16px 80px}
.cat{margin:26px 0 10px;border-bottom:1px solid var(--line);padding-bottom:5px}
.cat h2{margin:0;font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--gold)}
.cat p{margin:2px 0 0;color:var(--dim);font-size:11px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(var(--cardw,150px),1fr));gap:10px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:7px;
  padding:8px;cursor:pointer;position:relative;transition:border-color .12s}
.card:hover{border-color:var(--gold)}
.thumb{height:var(--thumbh,104px);display:flex;align-items:center;justify-content:center;
  border-radius:5px;overflow:hidden;margin-bottom:6px}
.thumb img{image-rendering:pixelated;max-width:100%;max-height:100%;
  transform:scale(var(--zoom,1));transform-origin:center}
.bg-checker{background-image:linear-gradient(45deg,#2a2d36 25%,transparent 25%),
  linear-gradient(-45deg,#2a2d36 25%,transparent 25%),
  linear-gradient(45deg,transparent 75%,#2a2d36 75%),
  linear-gradient(-45deg,transparent 75%,#2a2d36 75%);
  background-size:12px 12px;background-position:0 0,0 6px,6px -6px,-6px 0;background-color:#1e2028}
.bg-dark{background:#07080b}.bg-mid{background:#6a6f7d}.bg-light{background:#e9ebf0}
.bg-grass{background:#3c5233}
.name{font-size:12px;font-weight:600;line-height:1.25;overflow:hidden;
  text-overflow:ellipsis;white-space:nowrap}
.key{font-size:10px;color:var(--dim);font-family:ui-monospace,Consolas,monospace;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row{display:flex;gap:5px;align-items:center;margin-top:5px;flex-wrap:wrap}
.pill{font-size:9.5px;padding:1px 5px;border-radius:999px;border:1px solid var(--line);
  color:var(--dim);white-space:nowrap}
.score{position:absolute;top:6px;right:6px;font-size:11px;font-weight:700;
  padding:1px 6px;border-radius:4px;background:#000a;border:1px solid var(--line)}
.s-bad{color:var(--bad);border-color:var(--bad)}
.s-mid{color:var(--mid);border-color:var(--mid)}
.s-ok{color:var(--ok);border-color:var(--ok)}
.s-none{color:var(--dim)}
.auto{opacity:.62;font-weight:500}
.warn{position:absolute;top:6px;left:6px;font-size:11px}
#detail{position:fixed;inset:0;background:#000d;z-index:50;display:none;
  padding:24px;overflow:auto}
#detail.open{display:block}
.sheet{max-width:1180px;margin:0 auto;background:var(--panel);border:1px solid var(--line);
  border-radius:9px;padding:0 18px 18px}
/* The close control STAYS reachable no matter how large the art is — a
   full-bleed splash used to cover the whole overlay with no way out. */
.sheetbar{position:sticky;top:0;z-index:5;display:flex;justify-content:space-between;
  align-items:center;gap:12px;padding:12px 0 10px;margin-bottom:2px;
  background:var(--panel);border-bottom:1px solid var(--line)}
.sheetbar b{font-size:16px}
.close{white-space:nowrap}
.kbd{font-size:10px;border:1px solid var(--line);border-radius:3px;padding:0 4px;color:var(--dim)}
.sheet .key{font-size:12px;margin-bottom:12px}
/* Art is CONTAINED: zoom scales inside the box and the box scrolls. */
.big{min-height:200px;max-height:64vh;padding:14px;border-radius:7px;display:flex;
  align-items:center;justify-content:center;overflow:auto}
.big img{image-rendering:pixelated;max-width:100%;max-height:60vh;object-fit:contain;
  width:calc(100% * var(--bigzoom,1));flex:none}
.prov{margin-top:14px;border:1px solid var(--line);border-radius:6px;padding:10px 12px;
  background:var(--panel2)}
.prov p{margin:6px 0}
.prov .quote{color:var(--gold);font-style:italic}
.sub2{color:var(--dim);font-size:11px;line-height:1.45}
table.work{width:100%;border-collapse:collapse;margin-top:6px;font-size:11.5px}
table.work td{padding:3px 6px;border-top:1px solid var(--line);vertical-align:top}
table.work td:first-child{width:38px;text-align:right;font-weight:700}
.st-placeholder{color:#e0a13c;border-color:#e0a13c}
.st-unwired{color:#e2564a;border-color:#e2564a}
.st-unreferenced{color:#9aa0b0;border-color:#6a7080}
.cols{display:grid;grid-template-columns:1fr 300px;gap:18px}
@media(max-width:860px){.cols{grid-template-columns:1fr}}
table.meta{width:100%;border-collapse:collapse;font-size:12px}
table.meta td{padding:3px 6px;border-bottom:1px solid var(--line);vertical-align:top}
table.meta td:first-child{color:var(--dim);width:38%}
.vgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(88px,1fr));gap:7px;margin-top:10px}
.vcell{border:1px solid var(--line);border-radius:5px;padding:5px;text-align:center}
.vcell img{image-rendering:pixelated;max-width:100%;height:56px;object-fit:contain}
/* Horizontal clip strips PLAY instead of squeezing: one frame wide, stepped
   through the sheet so an 8-dir walk cycle is reviewable, not a smear. */
.vcell .strip{image-rendering:pixelated;height:56px;margin:0 auto;
  background-repeat:no-repeat;background-size:calc(var(--fr)*100%) 100%;
  animation:play var(--dur) steps(var(--fr)) infinite}
@keyframes play{from{background-position:0 0}to{background-position:100% 0}}
.vgrid.paused .strip{animation-play-state:paused}
.vcell div{font-size:9.5px;color:var(--dim);margin-top:3px;overflow:hidden;
  text-overflow:ellipsis;white-space:nowrap}
.rate{display:flex;gap:3px;flex-wrap:wrap;margin:8px 0}
.rate button{width:29px;padding:5px 0;text-align:center}
.flag{font-size:11.5px;color:#f0c674;background:#3a2f16;border-left:2px solid var(--mid);
  padding:5px 8px;border-radius:0 4px 4px 0;margin-top:5px}
.flag.err{color:#ffb3ab;background:#3a1a16;border-color:var(--bad)}
textarea{width:100%;background:var(--panel2);color:var(--ink);border:1px solid var(--line);
  border-radius:5px;padding:6px;font:inherit;font-size:12px;min-height:60px;resize:vertical}
.close{float:right}
#worst td{padding:4px 7px;border-bottom:1px solid var(--line);font-size:12px}
#worst{width:100%;border-collapse:collapse;margin-top:8px}
#worst tr{cursor:pointer}
#worst tr:hover td{background:var(--panel2)}
.tag{display:inline-block;font-size:10px;padding:0 5px;border-radius:3px;
  background:var(--panel2);border:1px solid var(--line);color:var(--dim)}
.hidden{display:none!important}
</style></head><body>

<header>
  <h1>Crownless — Visual Asset Gallery</h1>
  <div class="sub">__GENERATED__ · every wired visual asset, measured. Click a card to rate it.</div>
  <div class="bar">
    <input id="q" placeholder="search name, key, biome…" style="min-width:210px">
    <select id="cat"><option value="">all categories</option></select>
    <select id="sort">
      <option value="priority">sort: fix-first (weak × exposure)</option>
      <option value="cat">sort: category</option>
      <option value="score">sort: rating (low→high)</option>
      <option value="scored">sort: rating (high→low)</option>
      <option value="exp">sort: exposure</option>
      <option value="col">sort: color count</option>
      <option value="size">sort: source size</option>
      <option value="name">sort: name</option>
    </select>
    <select id="status">
      <option value="">status: everything</option>
      <option value="shipped">shipped only (players see it)</option>
      <option value="placeholder">placeholders only</option>
      <option value="unreferenced">unreferenced only</option>
      <option value="unwired">unwired files only</option>
    </select>
    <button id="fUnrated">unrated only</button>
    <button id="fWeak">weak (≤5)</button>
    <button id="fFlag">has flags</button>
    <span class="pill">bg</span>
    <button class="bgb on" data-bg="checker">checker</button>
    <button class="bgb" data-bg="dark">dark</button>
    <button class="bgb" data-bg="mid">mid</button>
    <button class="bgb" data-bg="light">light</button>
    <button class="bgb" data-bg="grass">grass</button>
    <span class="pill">zoom</span>
    <button class="zb on" data-z="1">1×</button>
    <button class="zb" data-z="2">2×</button>
    <button class="zb" data-z="3">3×</button>
    <button id="export">⭳ Export ratings CSV</button>
    <button id="toggleWorst">▾ fix-first list</button>
  </div>
  <div class="stats" id="stats"></div>
  <div id="worstWrap" class="hidden"><table id="worst"></table></div>
</header>

<main id="out"></main>

<div id="detail"><div class="sheet" id="sheet"></div></div>

<script>
const DATA = __DATA__;
const CATS = __CATS__;
const LS = "crownless_asset_ratings_v1";
let local = JSON.parse(localStorage.getItem(LS) || "{}");
DATA.forEach(d => { if (local[d.id]) { d.r = local[d.id].r; d.n = local[d.id].n || d.n; } });

const $ = s => document.querySelector(s);
const state = {q:"", cat:"", sort:"priority", unrated:false, weak:false,
               flag:false, status:"", bg:"checker", zoom:1};
const ST_LABEL = {shipped:"", placeholder:"PLACEHOLDER",
                  unreferenced:"UNREFERENCED", unwired:"UNWIRED"};

function score(d){ return d.r !== null && d.r !== undefined ? d.r : d.a; }
function prio(d){
  const s = score(d);
  if (s === null || s === undefined || d.c === "orphan") return 0;
  return (10 - s) * Math.log2(1 + Math.max(0, d.e));
}
function cls(v){ return v === null || v === undefined ? "s-none"
  : v < 5 ? "s-bad" : v < 7.5 ? "s-mid" : "s-ok"; }

function filtered(){
  const q = state.q.toLowerCase();
  return DATA.filter(d => {
    if (state.cat && d.c !== state.cat) return false;
    if (state.unrated && d.r !== null && d.r !== undefined) return false;
    if (state.weak && !(score(d) !== null && score(d) <= 5)) return false;
    if (state.flag && !(d.f && d.f.length)) return false;
    if (state.status && d.st !== state.status) return false;
    if (!q) return true;
    return (d.l + " " + d.k + " " + d.c + " " + (d.used||[]).join(" ")).toLowerCase().includes(q);
  });
}

function sortRows(rows){
  const s = state.sort;
  const catIdx = c => CATS.findIndex(x => x.id === c);
  return rows.sort((a,b) => {
    if (s === "priority") return prio(b) - prio(a) || b.e - a.e;
    if (s === "score") return (score(a) ?? 99) - (score(b) ?? 99);
    if (s === "scored") return (score(b) ?? -1) - (score(a) ?? -1);
    if (s === "exp") return b.e - a.e;
    if (s === "col") return b.col - a.col;
    if (s === "size") return (b.w*b.h) - (a.w*a.h);
    if (s === "name") return a.l.localeCompare(b.l);
    return catIdx(a.c) - catIdx(b.c) || a.k.localeCompare(b.k);
  });
}

function card(d){
  const s = score(d);
  const human = d.r !== null && d.r !== undefined;
  const badge = s === null || s === undefined ? "—" : s.toFixed(1);
  return `<div class="card" data-id="${d.id}">
    <div class="score ${cls(s)} ${human?"":"auto"}">${badge}</div>
    ${d.f && d.f.length ? '<div class="warn" title="'+esc(d.f.join(" · "))+'">⚑</div>' : ''}
    <div class="thumb bg-${state.bg}">${d.u ? `<img loading="lazy" src="${d.u}" alt="">`
      : '<span style="color:#666;font-size:11px">no art</span>'}</div>
    <div class="name" title="${esc(d.l)}">${esc(d.l)}</div>
    <div class="key">${esc(d.k)}</div>
    <div class="row">
      ${ST_LABEL[d.st] ? `<span class="pill st-${d.st}" title="${esc(d.why)}">${ST_LABEL[d.st]}</span>` : ''}
      <span class="pill">${d.w}×${d.h}</span>
      ${d.e ? `<span class="pill">×${d.e}</span>` : ''}
      ${d.nv > 1 ? `<span class="pill">${d.nv} files</span>` : ''}
    </div></div>`;
}

function esc(s){ return String(s).replace(/[&<>"]/g, c =>
  ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }

function render(){
  const rows = sortRows(filtered());
  document.documentElement.style.setProperty("--zoom", state.zoom);
  let html = "";
  if (state.sort === "cat"){
    CATS.forEach(c => {
      const sub = rows.filter(r => r.c === c.id);
      if (!sub.length) return;
      html += `<div class="cat"><h2>${c.name} <span class="tag">${sub.length}</span></h2>
        <p>${c.blurb}</p></div><div class="grid">${sub.map(card).join("")}</div>`;
    });
  } else {
    html = `<div class="grid">${rows.map(card).join("")}</div>`;
  }
  $("#out").innerHTML = html || '<p style="color:#888">nothing matches.</p>';
  stats(rows);
}

function stats(rows){
  const ship = DATA.filter(d => d.st === "shipped");
  const rated = ship.filter(d => d.r !== null && d.r !== undefined);
  const avg = rated.length ? (rated.reduce((a,d)=>a+d.r,0)/rated.length) : 0;
  const weak = ship.filter(d => score(d) !== null && score(d) <= 5);
  const ph = DATA.filter(d => d.st === "placeholder");
  const unref = DATA.filter(d => d.st === "unreferenced");
  const orph = DATA.filter(d => d.st === "unwired");
  $("#stats").innerHTML =
    `<span>showing <b>${rows.length}</b> / ${DATA.length}</span>
     <span>SHIPPED <b>${ship.length}</b></span>
     <span>rated (shipped) <b>${rated.length}</b> (${(100*rated.length/ship.length).toFixed(0)}%)</span>
     <span>avg SHIPPED rating <b>${avg ? avg.toFixed(2) : "—"}</b>/10</span>
     <span>weak &amp; shipped (≤5) <b>${weak.length}</b></span>
     <span>placeholders <b>${ph.length}</b></span>
     <span>unreferenced <b>${unref.length}</b></span>
     <span>unwired files <b>${orph.length}</b></span>`;
}

function worstList(){
  const rows = DATA.filter(d => prio(d) > 0)
    .sort((a,b) => prio(b) - prio(a)).slice(0, 40);
  $("#worst").innerHTML = "<tr><td colspan=6 style='color:#9aa0b0'>" +
    "Ranked by (10 − rating) × log₂(1 + rooms using it): weak art that covers " +
    "a lot of the game comes first. <b>SHIPPED art only</b> — placeholders and " +
    "unwired files are provisional by decision, so they never rank here.</td></tr>" +
    rows.map(d => `<tr data-id="${d.id}"><td>${esc(d.l)}</td>
      <td class="key">${esc(d.k)}</td><td class="tag">${d.c}</td>
      <td class="${cls(score(d))}">${score(d).toFixed(1)}</td>
      <td>×${d.e}</td><td style="color:#9aa0b0">${esc((d.f||[])[0]||"")}</td></tr>`).join("");
}

function open(id){
  const d = DATA.find(x => x.id === id); if (!d) return;
  const s = score(d);
  const metaRows = Object.entries(d.meta || {}).filter(([k,v]) =>
      v !== "" && v !== null && !(Array.isArray(v) && !v.length))
    .map(([k,v]) => `<tr><td>${esc(k)}</td><td>${esc(Array.isArray(v)?v.join(", "):v)}</td></tr>`).join("");
  const swatch = (d.meta && d.meta.swatch) ? `<div class="big bg-dark" style="min-height:120px">
      ${d.meta.swatch.map(c=>`<div style="width:74px;height:74px;background:#${c};
        border:1px solid #333"></div>`).join("")}</div>` : "";
  // Big art (splash/cover) must FIT the viewport by default -- a 1024px
  // painting at 2x used to overflow the sheet and swallow the close button.
  const huge = d.w > 320 || d.h > 320;
  bigZoom(huge ? 1 : 3);
  $("#sheet").innerHTML = `
    <div class="sheetbar">
      <div><b>${esc(d.l)}</b> <span class="${cls(s)}">
        ${s===null||s===undefined?"unrated":s.toFixed(1)+"/10"}</span>
        ${ST_LABEL[d.st] ? `<span class="pill st-${d.st}">${ST_LABEL[d.st]}</span>` : ''}</div>
      <button class="close" onclick="closeDetail()">✕ close &nbsp;<span class="kbd">Esc</span></button>
    </div>
    <div class="key">${esc(d.id)} · ${esc(d.s)}${d.nv?` · ${d.nv} file(s)`:""}</div>
    ${d.why ? `<div class="flag">${esc(ST_LABEL[d.st])}: ${esc(d.why)}</div>` : ""}
    <div class="cols"><div>
      ${d.u ? `<div class="big bg-${state.bg}"><img src="${d.u}"></div>` : swatch ||
        '<div class="big bg-dark" style="color:#888">no art on disk</div>'}
      <div class="row" style="margin-top:8px">
        <span class="pill">zoom</span>
        ${[1,2,3,4,6].map(z=>`<button onclick="bigZoom(${z})">${z}×</button>`).join("")}
        <span class="pill">${d.w}×${d.h} source</span>
      </div>
      ${(d.f||[]).map(f => `<div class="flag ${/no art|WIRED BUT NO ART/.test(f)?"err":""}">${esc(f)}</div>`).join("")}
      ${d.v && d.v.length ? `<div class="vgrid">${d.v.map(v=>`<div class="vcell bg-${state.bg}">
        ${v.fr > 1
          ? `<div class="strip" style="--fr:${v.fr};--dur:${(v.fr/9).toFixed(2)}s;
               background-image:url('${v.u}');
               aspect-ratio:${v.w/v.fr}/${v.h}"></div>`
          : `<img src="${v.u}" loading="lazy">`}
        <div title="${esc(v.n)}">${esc(v.c||"base")}${v.d?" · "+v.d:""}${
          v.fr>1?` · ${v.fr}f`:""}</div>
        </div>`).join("")}</div>` : ""}
      ${d.nv > (d.v||[]).length ? `<p class="key">…and ${d.nv-(d.v||[]).length} more files</p>` : ""}
    </div><div>
      <b style="font-size:12px">Your rating</b>
      <div class="rate">${[1,2,3,4,5,6,7,8,9,10].map(n=>
        `<button onclick="setRating('${d.id}',${n})" class="${d.r===n?'on':''}">${n}</button>`).join("")}
        <button onclick="setRating('${d.id}',null)">clear</button></div>
      <textarea id="note" placeholder="what's wrong / what to do"
        onchange="setNote('${d.id}', this.value)">${esc(d.n||"")}</textarea>

      <div class="prov">
        <b>How this score was reached</b>
        ${d.r !== null && d.r !== undefined ? `
          <p><span class="${cls(d.r)}">${d.r.toFixed(1)}/10</span> — human rating,
             by <b>${esc(d.by||"unknown")}</b>.
             ${/\(group\)/.test(d.by||"") ? "This is the <b>category baseline</b>: the "
               + "reviewer scored the family as a whole, not this card individually. "
               + "Rate it here to override." : "Scored individually."}</p>
          ${d.n ? `<p class="quote">“${esc(d.n)}”</p>` : ""}
        ` : `<p>No human rating yet — the badge shows the <b>auto</b> score below.</p>`}
        <p class="sub2">Auto score = measured signals only, never an opinion about
           whether the art is <i>good</i>. It starts at 7.5 and deducts for
           machine-visible failure modes:</p>
        <table class="work">${(d.aw||[]).map(w=>`<tr>
            <td class="${w[1]<0?'s-bad':'s-none'}">${w[1]>0?"":""}${w[1]?w[1].toFixed(1):"7.5"}</td>
            <td><b>${esc(w[0])}</b><br><span class="sub2">${esc(w[2])}</span></td>
          </tr>`).join("") || '<tr><td colspan=2 class="sub2">not measurable (no image)</td></tr>'}
          <tr><td class="${cls(d.a)}"><b>${d.a===null||d.a===undefined?"—":d.a.toFixed(1)}</b></td>
              <td><b>auto total</b></td></tr>
        </table>
      </div>

      <table class="meta" style="margin-top:12px">
        <tr><td>source</td><td>${esc(d.s)}</td></tr>
        <tr><td>status</td><td>${esc(d.st)}${d.why?" — "+esc(d.why):""}</td></tr>
        <tr><td>size</td><td>${d.w}×${d.h}${d.nat>1?` (native ~${Math.round(d.w/d.nat)}px, ${d.nat}× upscale)`:""}</td></tr>
        <tr><td>unique colors</td><td>${d.col}</td></tr>
        <tr><td>opaque fill</td><td>${(d.fill*100).toFixed(0)}%</td></tr>
        <tr><td>mean value / sat</td><td>${d.val} / ${d.sat}</td></tr>
        ${d.mag?`<tr><td>on-screen magnify</td><td>${d.mag}× (hero ≈0.8×)</td></tr>`:""}
        <tr><td>exposure</td><td>${d.e} reference(s)</td></tr>
        ${metaRows}
      </table>
      ${d.used && d.used.length ? `<p class="key" style="margin-top:10px">used in:<br>${
        d.used.map(esc).join("<br>")}</p>` : ""}
    </div></div>`;
  $("#detail").classList.add("open");
}
function closeDetail(){ $("#detail").classList.remove("open"); }
function bigZoom(z){ document.documentElement.style.setProperty("--bigzoom", z); }

function setRating(id, n){
  const d = DATA.find(x => x.id === id); d.r = n;
  local[id] = local[id] || {}; local[id].r = n; local[id].n = d.n || "";
  localStorage.setItem(LS, JSON.stringify(local));
  open(id); render(); worstList();
}
function setNote(id, txt){
  const d = DATA.find(x => x.id === id); d.n = txt;
  local[id] = local[id] || {}; local[id].n = txt; local[id].r = d.r ?? null;
  localStorage.setItem(LS, JSON.stringify(local));
}

function exportCSV(){
  const esc2 = s => `"${String(s == null ? "" : s).replace(/"/g,'""')}"`;
  const lines = ["id,rating,notes,rated_by,category,label,exposure"];
  DATA.slice().sort((a,b)=>a.id.localeCompare(b.id)).forEach(d => lines.push([
    esc2(d.id), d.r ?? "", esc2(d.n || ""), esc2(d.by || (d.r!=null?"owner":"")),
    esc2(d.c), esc2(d.l), d.e].join(",")));
  const blob = new Blob([lines.join("\n")], {type:"text/csv"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob); a.download = "asset_ratings.csv"; a.click();
}

$("#q").oninput = e => { state.q = e.target.value; render(); };
$("#cat").onchange = e => { state.cat = e.target.value; render(); };
$("#sort").onchange = e => { state.sort = e.target.value; render(); };
["fUnrated","fWeak","fFlag"].forEach(id => {
  const k = {fUnrated:"unrated", fWeak:"weak", fFlag:"flag"}[id];
  $("#"+id).onclick = e => { state[k] = !state[k]; e.target.classList.toggle("on", state[k]); render(); };
});
$("#status").onchange = e => { state.status = e.target.value; render(); };
document.querySelectorAll(".bgb").forEach(b => b.onclick = () => {
  state.bg = b.dataset.bg;
  document.querySelectorAll(".bgb").forEach(x => x.classList.toggle("on", x === b));
  render();
});
document.querySelectorAll(".zb").forEach(b => b.onclick = () => {
  state.zoom = +b.dataset.z;
  document.querySelectorAll(".zb").forEach(x => x.classList.toggle("on", x === b));
  render();
});
$("#export").onclick = exportCSV;
$("#toggleWorst").onclick = () => $("#worstWrap").classList.toggle("hidden");
document.addEventListener("click", e => {
  const c = e.target.closest(".card"); if (c) return open(c.dataset.id);
  const r = e.target.closest("#worst tr[data-id]"); if (r) return open(r.dataset.id);
  if (e.target.id === "detail") closeDetail();
});
document.addEventListener("keydown", e => { if (e.key === "Escape") closeDetail(); });

CATS.forEach(c => {
  if (!DATA.some(d => d.c === c.id)) return;
  const o = document.createElement("option");
  o.value = c.id; o.textContent = c.name + " (" + DATA.filter(d=>d.c===c.id).length + ")";
  $("#cat").appendChild(o);
});
$("#sort").value = "cat"; state.sort = "cat";
render(); worstList();
</script></body></html>"""


# ------------------------------------------------------------------ main ---

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-dump", action="store_true",
                    help="reuse the last engine dump (skip the Godot pass)")
    ap.add_argument("--embed", action="store_true",
                    help="one shareable file: card thumbnails inlined, no clip strips")
    ap.add_argument("--open", action="store_true", help="open the page when done")
    ap.add_argument("--sheets", action="store_true",
                    help="also write labelled per-category contact sheets")
    ap.add_argument("--out", default=os.path.join(OUT, "index.html"))
    args = ap.parse_args()

    if not args.no_dump:
        print("engine pass: walking the live data tables…")
        run_dump()
    src = os.path.join(OUT, "wired_assets.json")
    if not os.path.exists(src):
        sys.exit("no engine dump at %s — run without --no-dump" % src)
    records = json.load(open(src, encoding="utf-8"))["assets"]

    print("assembling file families + measuring…")
    records = build(records)

    ratings = load_ratings()
    for r in records:
        got = ratings.get(r["id"])
        r["rating"] = got["rating"] if got else None
        r["rnotes"] = got["notes"] if got else ""
        r["rated_by"] = got["rated_by"] if got else ""
    added = save_ratings(records, ratings)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    if args.sheets:
        sheets = contact_sheets(records, os.path.join(OUT, "sheets"))
        print("  contact sheets : %d -> %s" % (
            len(sheets), os.path.relpath(os.path.join(OUT, "sheets"), ROOT)))
    write_html(records, args.embed, args.out)

    shipped = [r for r in records if r["status"] == "shipped"]
    rated = [r for r in shipped if r["rating"] is not None]
    def eff(r):
        return r["rating"] if r["rating"] is not None else r["auto"]
    weak = [r for r in shipped if eff(r) is not None and eff(r) <= 5]
    by_status = Counter(r["status"] for r in records)
    counts = Counter(r["category"] for r in records)
    avg = sum(r["rating"] for r in rated) / len(rated) if rated else 0.0

    print()
    print("  catalogued     : %d families   (%s)" % (
        len(records), ", ".join("%s %d" % (c, counts[c])
                                for c, _n, _b in CATEGORIES if counts.get(c))))
    print("  SHIPPED        : %d   placeholder %d · unreferenced %d · unwired %d" % (
        by_status["shipped"], by_status["placeholder"],
        by_status["unreferenced"], by_status["unwired"]))
    print("  rated (shipped): %d / %d   avg %.2f/10" % (len(rated), len(shipped), avg))
    print("  weak & shipped : %d  (<=5 — these are the fix-first list)" % len(weak))
    print("  wired, no art  : %d" % len([r for r in records if r["source"] == "missing"]))
    print("  new CSV rows   : %d  -> %s" % (added, os.path.relpath(RATINGS, ROOT)))
    print("  gallery        : %s  (%.1f MB)" % (
        os.path.relpath(args.out, ROOT), os.path.getsize(args.out) / 1048576.0))
    if args.open:
        webbrowser.open("file:///" + args.out.replace("\\", "/"))


if __name__ == "__main__":
    main()
