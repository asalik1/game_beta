#!/usr/bin/env python3
"""Post-install sprite verifier -- the install-README checks, as one command.

After installing/replacing sprite art, run this on the base name. It runs
the checks that are otherwise scattered snippets in tools/art/README.md
(and therefore get skipped):

  GEOMETRY   strips use square cells by default. An *_anim strip may instead
             use rectangular cells when a matching static sprite has the same
             height and evenly tiles the strip (art.gd _strip_info). -> FAIL
  DIR8       a directional set with SOME of the 8 facings missing. The
             engine falls back to south, so it renders -- but a partial set
             is almost always an install slip.                  -> WARN
  DIRSTRIP   *_dir.png aim strips must hold 8*K frames (E,NE,N,NW,W,SW,S,SE
             direction-major).                                  -> FAIL
  BLEED      semi-transparent pixels (0<alpha<255). The green-bleed bug:
             extracted sprites must be fully solidified. Generated/PixelLab
             art may carry a few AA pixels legitimately.        -> WARN
  IMPORT     source md5 vs Godot's import sidecar -- catches "installed the
             PNG, forgot --import" (headless then uses STALE art). -> FAIL

Content-geometry gates (2026-08-13, built from the owner's mob QA pass:
the sheets TILED perfectly yet mobs slid, shrank, ghosted and lost limbs --
all defects INSIDE the cells, invisible to the tiling check):

  ANCHOR     locomotion strips (anim/walk; cx also on run): the figure's
             centroid / feet line / bbox height wanders across frames.
             The engine draws every cell on one fixed anchor, so in-cell
             drift IS the on-screen slide ("assembled off the frame grid",
             repair: tools/art/recenter_strip.py).             -> WARN
  GHOST      a frame whose content splits into vertically disjoint bands --
             a stray chunk of another pose baked into the cell (the Frozen
             Guard "second frame below his feet").              -> WARN
  EDGECUT    content within 1px of a cell's left/right boundary -- limbs
             clipped at the frame cut, or bleed from the neighbour cell
             ("part of hands get cut off").                     -> WARN
  RIGIDDRIFT a rectangular prop cell (tight-cropped from its static) that
             touches a cell edge AND whose L/R silhouette edge translates
             across frames: the rigid body wanders into the cut and shifts on
             screen (capital_portal_depths drifted 10px). A prop whose edge
             touch is STABLE (<=RIGID_DRIFT_PX) is inherited from the static's
             framing, clips nothing new, and no longer trips EDGECUT. Fix:
             derive the anim from the static so the shell is geometry-locked.
                                                                -> WARN
  CLIPSCALE  clip's median body height, normalized the way the engine
             scales it (actions + MOB_BODY_SCALE_WALK walks ride the idle
             cell, plain locomotion its own cell), vs the idle strip's.
             Catches "turns smaller in walk/attack".            -> WARN

Content gates are judged lints, WARN by design: squash-stretch blobs,
fliers/hoppers and flame-type creatures trip ANCHOR/GHOST legitimately,
and one-shot swing arcs deform legitimately (which is why attack strips
are exempt from the drift checks -- a broken swing and a good lunge are
indistinguishable by bbox stats; that class stays a human review via
anim_sheet.py). Calibrated 2026-08-13 over all 1,978 body-clip strips so
the owner's QA complaints trip while reviewed hero/skin kits stay quiet.

Boss ability strips (<base>_ability / dedicated action names like
auroch_minotaur_slam) are swept into the base's family -- the action
vocabulary is parsed live from play_action("...") in boss.gd/enemy.gd, so
new abilities join automatically. They get every file check (GEOMETRY/
BLEED/IMPORT/DIR8; before 2026-08-13 they were invisible to this tool)
and the ACTION-class content gates (GHOST/EDGECUT/CLIPSCALE, no drift).
Cast-type abilities may GHOST on detached spell fx -- judge those by eye.

Intentional coverage gaps are NOT flagged: static idles, kit-matched clip
subsets and flat single-facing death strips are design decisions -- this
tool only judges the files that exist.

Usage:
    python tools/art/verify_art.py warrior [mage ...]
    python tools/art/verify_art.py skins/elite/assassin_blade_dancer
    python tools/art/verify_art.py --all          # whole sprites dir (IMPORT+DIR8 only)
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
GAME = ROOT / "game"

DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
CLIPS = ("anim", "walk", "attack", "attack2", "attackb", "attackc", "cast", "dash",
         "ult", "ultidle", "death", "stab", "throw", "dir")

# Content-geometry gates (see module docstring). Thresholds calibrated
# 2026-08-13 against the owner's mob QA pass over the full sprites corpus.
# ("attackb" = the hero's alternate basic swing, Art.HERO_CLIP_FILES; gated
# exactly like "attack".)
BODY_GATE_CLIPS = ("anim", "walk", "attack", "attack2", "attackb", "attackc")
LOCO_CLIPS = ("anim", "walk")

# Boss ability strips (<base>_<action>[_<dir>].png, engine seam
# Art.action_info / enemy _apply_strip is_action=true). The action
# vocabulary is parsed live from play_action("...") literals in boss.gd +
# enemy.gd -- self-maintaining, like the MOB_BODY_SCALE_WALK parse -- plus
# the generic "ability" fallback strip every boss ships. Tokens already in
# CLIPS (cast/stab/throw/...) keep their existing treatment; ability strips
# are swept into the base's family and content-gated as ACTION clips
# (GHOST/EDGECUT/CLIPSCALE, no drift gates -- one-shot motions legitimately
# shift mass).
_ability_tokens_cache: set | None = None


def ability_tokens() -> set:
    global _ability_tokens_cache
    if _ability_tokens_cache is None:
        names = {"ability"}
        for script in ("boss.gd", "enemy.gd"):
            try:
                txt = (GAME / "scripts" / script).read_text(errors="replace")
                names |= set(re.findall(r'play_action\("(\w+)"', txt))
            except OSError:
                pass
        _ability_tokens_cache = names - set(CLIPS)
    return _ability_tokens_cache
A_SOLID = 8            # alpha above this counts as body content
ANCHOR_CX = 0.08       # centroid-x drift, fraction of frame width (anim/walk)
ANCHOR_CX_RUN = 0.10   # runs sway more legitimately (airborne stride)
ANCHOR_CY = 0.08       # centroid-y drift, fraction of cell height
ANCHOR_FEET = 0.07     # lowest-opaque-row drift (the engine's anchor line)
ANCHOR_H = 0.12        # bbox-height drift within a locomotion strip
GHOST_GAP = 0.06       # vertical content gap, fraction of cell height
RIGID_DRIFT_PX = 3     # a full-bleed prop whose L/R bbox edge moves more than
                       # this is a rigid body wandering (capital_portal_depths
                       # drifted 10px); benign edge-filling statics measure 0
# Clip body height vs idle reference. Actions tolerate more: crouch/lunge
# frames legitimately pull an attack's median (reviewed paladin 0.84, wolf
# pounce 0.85); the defect band below 0.82 (cultist 0.80) stays caught, and
# 0.82-0.88 defects carry EDGECUT/GHOST signatures instead. Runs are exempt
# outright -- a sprint lean is legitimately shorter (archer run 0.74-0.78).
SCALE_LO_LOCO, SCALE_LO_ACTION, SCALE_HI = 0.88, 0.82, 1.18

# Hero render (player_core _measure_hero_frame) locks a strip's scale to its
# FIRST frame's body height: on-screen height of frame i = target * bh_i/bh_0.
# So a clip whose body height VARIES frame to frame renders as a size PULSE.
# This gate is scoped to DASH: it is a LOCOMOTION clip (a fast reposition), so a
# size swing reads as a scaling glitch, and every accepted base-hero dash holds
# body height constant -- the archer Tumble dash that swings 188..316px against
# a 235px frame 0 (0.80x..1.42x on screen) is the sole offender. Attack/ult/cast
# legitimately lunge/draw and the owner accepts that pulse, so they are NOT
# gated here (they trip >0.22 across accepted art). FRAMEDEV 0.22 = a frame
# rendering >22% larger/smaller than frame 1.
HERO_BASES = {"warrior", "archer", "mage", "assassin", "paladin", "warlock"}
FRAMEDEV = 0.22
# Detached-content + butchered-frame gates for HERO ability clips (cast/dash/ult)
# and basic attacks -- these clips are NOT in BODY_GATE_CLIPS, so GHOST/HSPLIT
# never ran on them and baked-projectile mis-slices (archer arrow-storm specks in
# the CAST clip, warrior dash fragment, warlock shadowbolt chunk) shipped. The
# game spawns projectiles, so a detached component off a hero figure is almost
# always a slice artifact. Advisory WARN -- a genuinely detached authored fx is
# rare on heroes; judge those by eye.
# STRAY runs only on clips that should be ONE clean figure -- idle, walk, and the
# single-target basic swings. attack2/cast/dash/ult legitimately bake AoE/FX
# (base-hero casts carry 2-3k px of authored effect), so gating them floods; their
# baked-projectile strays are an eyes-only review item (despur before install).
STRAY_CLIPS = ("anim", "walk", "attack", "attackb", "attackc")
# PARTIAL (butchered / projectile-only frame) is safe on the FX clips too -- it
# measures the FIGURE shrinking, not the effect.
PARTIAL_CLIPS = ("attack", "attack2", "attackb", "attackc", "cast", "ult")
STRAY_MIN_COMP = 240      # a single detached component this big = a stray
STRAY_MIN_TOTAL = 380     # or this much detached mass across a frame (speck swarms)
PARTIAL_FRAC = 0.35       # a frame whose figure MASS is <this of the clip median =
                          # a butchered / cut-off frame (warlock hex f5/f8)

FAIL, WARN = [], []

# stem-keyed per-strip stats collected by check_file, consumed by
# check_clip_scale once a base's whole family has been measured.
_strip_stats: dict[str, dict] = {}


def _clip_of(stem: str) -> str | None:
    """walk for goblin_walk_ne, slam for auroch_minotaur_slam_e;
    None for goblin_death / plain goblin."""
    parts = stem.split("_")
    if parts[-1] in DIR8:
        parts = parts[:-1]
    # "codex" is a GENERATION TAG, not a clip token: "<base>_anim_codex" is the
    # live Codex-regen idle (art.gd BOSS_IDLE_STRIP_BASE) and
    # "<base>_walk_codex_<dir>" the Codex directional walk (BOSS_DIRECTIONAL_WALK).
    # Strip the tag so both are stat'd under their real clip — the idle then
    # serves as the CLIPSCALE reference and the walks get gated at all.
    if len(parts) >= 2 and parts[-1] == "codex":
        parts = parts[:-1]
    if len(parts) >= 2 and (parts[-1] in BODY_GATE_CLIPS
                            or parts[-1] in ability_tokens()):
        return parts[-1]
    return None


_body_scale_walk_cache: set | None = None


def body_scale_walk_keys() -> set:
    """Mobs whose walk rides the idle cell (art.gd MOB_BODY_SCALE_WALK)."""
    global _body_scale_walk_cache
    if _body_scale_walk_cache is None:
        try:
            txt = (GAME / "scripts" / "art.gd").read_text(errors="replace")
            m = re.search(r"MOB_BODY_SCALE_WALK\s*:?=\s*\{(.*?)\}", txt, re.S)
            _body_scale_walk_cache = set(re.findall(r'"(\w+)"\s*:', m.group(1))) if m else set()
        except OSError:
            _body_scale_walk_cache = set()
    return _body_scale_walk_cache


def _frame_metrics(a: np.ndarray, frame_width: int) -> list[dict | None]:
    """Per-cell body stats for a horizontal strip's alpha channel."""
    h = a.shape[0]
    out: list[dict | None] = []
    for i in range(a.shape[1] // frame_width):
        region = a[:, i * frame_width:(i + 1) * frame_width]
        ys, xs = np.where(region > A_SOLID)
        if len(xs) == 0:
            out.append(None)
            continue
        occupied = np.unique(ys)
        gaps = np.diff(occupied)
        occupied_x = np.unique(xs)
        xgaps = np.diff(occupied_x)
        out.append({
            "bh": int(ys.max() - ys.min() + 1),
            "cx": float(xs.mean()), "cy": float(ys.mean()),
            "feet": int(ys.max()),
            "xmin": int(xs.min()), "xmax": int(xs.max()),
            "left": bool((xs <= 0).any()),
            "right": bool((xs >= frame_width - 1).any()),
            "vgap": int(gaps.max()) - 1 if len(gaps) else 0,
            "hgap": int(xgaps.max()) - 1 if len(xgaps) else 0,
        })
    return out


def _frame_components(reg: np.ndarray) -> tuple[int, int, list[int]]:
    """4-connected components of one cell's alpha>A_SOLID mask via row-run
    union-find (fast: O(runs), not O(pixels)). Returns (largest_size,
    largest_bbox_height, other_component_sizes) for the hero STRAY/PARTIAL gates."""
    mask = reg > A_SOLID
    h = mask.shape[0]
    parent = [0]
    size = [0]
    ymin = [0]
    ymax = [0]

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
            size[ra] += size[rb]
            ymin[ra] = min(ymin[ra], ymin[rb])
            ymax[ra] = max(ymax[ra], ymax[rb])

    prev: list[tuple[int, int, int]] = []   # (x0, x1 exclusive, root)
    for y in range(h):
        row = mask[y]
        if not row.any():
            prev = []
            continue
        d = np.diff(np.concatenate(([0], row.view(np.int8), [0])))
        starts = np.flatnonzero(d == 1)
        ends = np.flatnonzero(d == -1)
        runs: list[tuple[int, int, int]] = []
        for x0, x1 in zip(starts, ends):
            lab = len(parent)
            parent.append(lab)
            size.append(int(x1 - x0))
            ymin.append(y)
            ymax.append(y)
            root = lab
            for px0, px1, proot in prev:
                if px0 < x1 and px1 > x0:
                    union(root, proot)
                    root = find(root)
            runs.append((int(x0), int(x1), root))
        prev = runs
    roots: dict[int, bool] = {}
    for i in range(1, len(parent)):
        roots[find(i)] = True
    comps = sorted(((size[r], ymax[r] - ymin[r] + 1) for r in roots), reverse=True)
    if not comps:
        return 0, 0, []
    return comps[0][0], comps[0][1], [c[0] for c in comps[1:]]


def belongs(stem: str, base: str) -> bool:
    """warrior_attack2_ne belongs to warrior; warrior_captain_anim does not.
    Boss ability strips (nullwarden_ability_ne, auroch_minotaur_slam) belong
    via the parsed play_action vocabulary."""
    if stem == base:
        return True
    if not stem.startswith(base + "_"):
        return False
    ok = set(CLIPS) | set(DIR8) | ability_tokens()
    # "codex" is a generation tag riding a real clip token (anim_codex /
    # walk_codex_<dir>), not a clip itself — without dropping it here the LIVE
    # Codex idle is excluded from the stats table and CLIPSCALE falls back to
    # the legacy low-res <base>_anim (every new clip then reads ~4x, spurious).
    return all(t in ok for t in stem[len(base) + 1:].split("_") if t != "codex")


def check_import(png: Path) -> None:
    rel = png.relative_to(GAME)
    imp = png.with_name(png.name + ".import")
    if not imp.exists():
        FAIL.append(f"[IMPORT] {rel}: never imported -- headless runs will not see it")
        return
    m = re.search(r'path="res://(\.godot/imported/[^"]+)"', imp.read_text(errors="replace"))
    if not m:
        return
    dest = GAME / m.group(1)
    sidecar = dest.with_suffix(".md5")
    if not dest.exists():
        FAIL.append(f"[IMPORT] {rel}: import artifact missing -- run --import")
        return
    if sidecar.exists():
        m5 = re.search(r'source_md5="([0-9a-f]+)"', sidecar.read_text(errors="replace"))
        if m5 and hashlib.md5(png.read_bytes()).hexdigest() != m5.group(1):
            FAIL.append(f"[IMPORT] {rel}: changed since last import -- headless uses the STALE "
                        "version; run --import (close the editor first)")


def check_file(png: Path) -> None:
    rel = png.relative_to(SPRITES)
    img = Image.open(png).convert("RGBA")
    w, h = img.size
    stem = png.stem
    a = np.asarray(img)[:, :, 3]

    # Authored room surfaces are deliberately rectangular, loaded directly by
    # Art._ground_room_surface(), and never pass through the square-strip
    # decoder. Do not misclassify their descriptive suffix as animation.
    is_ground_room = stem.startswith("ground_room_")
    suffixes = CLIPS + DIR8
    is_strip = not is_ground_room and any(stem.endswith(f"_{suffix}") for suffix in suffixes)
    frame_width = h
    frames = w // h if h > 0 else 0
    if stem.endswith("_anim"):
        static_png = png.with_name(f"{stem.removesuffix('_anim')}.png")
        if static_png.exists():
            static_w, static_h = Image.open(static_png).size
            if static_h == h and static_w > 0 and w % static_w == 0:
                frame_width = static_w
                frames = w // static_w
    if is_strip and (frame_width <= 0 or w % frame_width != 0):
        FAIL.append(
            f"[GEOMETRY] {rel}: {w}x{h} -- strip does not tile its "
            f"{frame_width} px frame width; art.gd _strip_info would shear frames"
        )
    if stem.endswith("_dir") and frame_width > 0 and w % frame_width == 0 and frames % 8 != 0:
        FAIL.append(f"[DIRSTRIP] {rel}: {frames} frames -- aim strips must be 8*K frames, "
                    "direction-major E,NE,N,NW,W,SW,S,SE (tools/art/README.md)")

    # A non-empty frame can still be effectively invisible when a mixed-source
    # normalizer shrinks the body to a miniature.  Catch catastrophic body-box
    # collapse on ordinary full-body clips; effects/death/dash are excluded
    # because deliberate vanish/transform frames are valid there.
    body_clips = ("anim", "walk", "attack", "attack2", "attackb")
    is_body_clip = any(
        re.search(rf"_{clip}(?:_|$)", stem) for clip in body_clips
    )
    if is_body_clip and frame_width > 0 and frames > 1 and w % frame_width == 0:
        heights: list[int] = []
        for frame_index in range(frames):
            region = a[:, frame_index * frame_width : (frame_index + 1) * frame_width]
            ys = np.where(region > 0)[0]
            heights.append(int(ys[-1] - ys[0] + 1) if len(ys) else 0)
        positive = [height for height in heights if height > 0]
        if positive:
            # Use the upper quartile rather than the median: a broken row can
            # contain a majority of miniature frames (the Warrior north cleave
            # had four tiny middles and three full-size bookends).
            reference_height = float(np.percentile(positive, 75))
            for frame_index, height in enumerate(heights):
                if height < max(8.0, reference_height * 0.45):
                    FAIL.append(
                        f"[BODYSCALE] {rel}: f{frame_index + 1} alpha height {height}px "
                        f"vs {reference_height:.0f}px upper-quartile reference -- "
                        "likely mixed-source shrink/cut"
                    )

    # ---- content-geometry gates (module docstring) --------------------
    clip = _clip_of(stem)
    in_fx = png.parent.name == "fx"
    if clip and not in_fx and not is_ground_room \
            and frame_width > 0 and w % frame_width == 0:
        metrics = _frame_metrics(a, frame_width)
        live = [m for m in metrics if m]
        if live:
            _strip_stats[str(png.parent / stem)] = {
                "clip": clip, "cell": h,
                "med_h": float(np.median([m["bh"] for m in live])),
            }
        if len(live) >= 2:
            if clip in LOCO_CLIPS:
                drift = []
                cx_span = (max(m["cx"] for m in live) - min(m["cx"] for m in live)) / frame_width
                cx_lim = ANCHOR_CX_RUN if clip == "run" else ANCHOR_CX
                if cx_span >= cx_lim:
                    drift.append(f"centroid-x {cx_span:.0%}")
                if clip != "run":
                    cy_span = (max(m["cy"] for m in live) - min(m["cy"] for m in live)) / h
                    feet_span = (max(m["feet"] for m in live) - min(m["feet"] for m in live)) / h
                    h_span = (max(m["bh"] for m in live) - min(m["bh"] for m in live)) \
                        / max(m["bh"] for m in live)
                    if cy_span >= ANCHOR_CY:
                        drift.append(f"centroid-y {cy_span:.0%}")
                    if feet_span >= ANCHOR_FEET:
                        drift.append(f"feet line {feet_span:.0%}")
                    if h_span >= ANCHOR_H:
                        drift.append(f"body height {h_span:.0%}")
                if drift:
                    WARN.append(f"[ANCHOR] {rel}: figure wanders inside its cells "
                                f"({', '.join(drift)} of cell) -- plays as an on-screen "
                                "slide/wobble; off-grid assembly, repair: "
                                "tools/art/recenter_strip.py")
                # A locomotion frame must be ONE connected silhouette; a
                # horizontally-disjoint band beside the figure is a mis-slice --
                # a stray chunk (held weapon, neighbour's limb) pulled in from the
                # adjacent cell. GHOST (below) only detects VERTICAL splits, so a
                # bow floating to the archer's side sits in the same rows as the
                # body and slips past it -- this is the lateral counterpart.
                hsplit = [(i + 1, m["hgap"]) for i, m in enumerate(metrics)
                          if m and m["hgap"] >= max(6.0, GHOST_GAP * frame_width)]
                if hsplit:
                    htxt = ", ".join(f"f{i} ({g}px gap)" for i, g in hsplit)
                    WARN.append(f"[HSPLIT] {rel}: {htxt} -- content splits into "
                                "horizontally disjoint bands; a stray chunk beside the "
                                "figure (mis-slice from the neighbour cell)")
            ghost_frames = [
                (i + 1, m["vgap"]) for i, m in enumerate(metrics)
                if m and m["vgap"] >= max(4.0, GHOST_GAP * h)]
            if ghost_frames:
                gtxt = ", ".join(f"f{i} ({g}px gap)" for i, g in ghost_frames)
                WARN.append(f"[GHOST] {rel}: {gtxt} -- content splits into vertically "
                            "disjoint bands; stray chunk of another pose in the cell "
                            "(legit only for fliers/flames/detached fx)")
            cut = [i + 1 for i, m in enumerate(metrics) if m and (m["left"] or m["right"])]
            if cut:
                # For rectangular prop cells (frame_width != cell height -- the
                # tight-cropped-from-static path), an edge-touch that is STABLE
                # across frames is inherited from the static's own framing: the
                # animation clips nothing new, so it is benign (void_monolith and
                # the capital gates fill the cell; the standing stone sits flush
                # to one edge -- both trip every frame identically). Only when the
                # silhouette's L/R edge TRANSLATES is the animation pushing a
                # rigid body into the cut -- capital_portal_depths drifted 10px
                # and visibly shifted on screen. Mob strips use square cells
                # (frame_width == h) and keep the original EDGECUT behaviour.
                edge_drift = max(
                    max(m["xmin"] for m in live) - min(m["xmin"] for m in live),
                    max(m["xmax"] for m in live) - min(m["xmax"] for m in live))
                if frame_width != h and edge_drift <= RIGID_DRIFT_PX:
                    pass  # stable edge-touch inherited from the static; benign
                elif frame_width != h:
                    WARN.append(f"[RIGIDDRIFT] {rel}: silhouette L/R edge translates "
                                f"{edge_drift}px across frames -- a rigid prop wandering "
                                "into the cell edge shifts on screen and clips; derive the "
                                "anim from its static (geometry-locked): derive_prop_anim.py "
                                "<name> --motion swirl|pulse (ignore if the whole body is "
                                "meant to move, e.g. cloth/energy)")
                else:
                    WARN.append(f"[EDGECUT] {rel}: f{cut} content touches a left/right cell "
                                "edge -- limb clipped at the frame cut, or bleed from the "
                                "neighbour cell")

    # Hero body-scale + stray-content gates (hero strips only). Run independent
    # of _clip_of so they cover dash/ult/cast -- the clips that are otherwise
    # content-unchecked. See FRAMEDEV / HERO_BASES above.
    is_hero = (png.parent == SPRITES or "skins" in png.parent.parts) \
        and stem.split("_")[0] in HERO_BASES
    if is_hero and is_strip and not in_fx and frame_width > 0 \
            and w % frame_width == 0 and frames >= 3:
        hm = _frame_metrics(a, frame_width)
        hlive = [m for m in hm if m]
        parts = stem.split("_")
        clip_tok = parts[-2] if parts[-1] in DIR8 else parts[-1]
        if clip_tok == "dash" and len(hlive) >= 3 and hm[0] and hm[0]["bh"] > 0:
            b0 = hm[0]["bh"]
            devs = [(i + 1, m["bh"] / b0) for i, m in enumerate(hm) if m]
            worst = max(devs, key=lambda t: abs(t[1] - 1.0))
            if abs(worst[1] - 1.0) >= FRAMEDEV:
                WARN.append(f"[FRAMEDEV] {rel}: f{worst[0]} body renders {worst[1]:.2f}x frame 1 "
                            f"(bh {hm[worst[0] - 1]['bh']}px vs {b0}px) -- the hero renderer locks "
                            "the dash scale to frame 1, so an uneven body height plays as an "
                            "on-screen size pulse; hold body height ~constant across the dash")
        # Detached-content + butchered-frame gates for hero ability/attack clips.
        if clip_tok in (STRAY_CLIPS + PARTIAL_CLIPS) and frames >= 3:
            comps = [_frame_components(a[:, i * frame_width:(i + 1) * frame_width])
                     for i in range(frames)]
            if clip_tok in STRAY_CLIPS:
                stray_hits = []
                for i, (_big, _bh, others) in enumerate(comps):
                    if others and (max(others) >= STRAY_MIN_COMP or sum(others) >= STRAY_MIN_TOTAL):
                        stray_hits.append(f"f{i + 1} ({max(others)}px)")
                if stray_hits:
                    WARN.append(f"[STRAY] {rel}: {', '.join(stray_hits)} -- a detached chunk sits off "
                                "the figure (baked projectile / mis-slice from a neighbour cell). The "
                                "game spawns projectiles; keep the character strip figure-only")
            # Butchered / cut-off frames: the figure (largest component) has far
            # less MASS than the clip's typical frame -- a thin sliver, a partial
            # cut-off body, or a projectile-only cell counted as a frame (the
            # warlock hex). Mass, not height, because a vertical sliver keeps full
            # height. PARTIAL_CLIPS excludes dash (blink near-vanishes) / death.
            if clip_tok in PARTIAL_CLIPS:
                masses = [c[0] for c in comps if c[0] > 0]
                med = float(np.median(masses)) if masses else 0.0
                cut = [f"f{i + 1}" for i, (sz, _bh, _o) in enumerate(comps)
                       if 0 < sz < PARTIAL_FRAC * med]
                if med > 0 and cut:
                    WARN.append(f"[PARTIAL] {rel}: {', '.join(cut)} -- figure mass far below the "
                                f"clip's typical frame (~{med:.0f}px); a butchered slice (partial "
                                "cut-off body or a projectile-only cell counted as a frame)")

    semi = int(((a > 0) & (a < 255)).sum())
    if semi:
        WARN.append(f"[BLEED] {rel}: {semi} semi-transparent pixel(s) -- extracted sprites must "
                    "be 0 (green-bleed); small counts on generated art may be benign AA")

    check_import(png)


def check_clip_scale(files: list[Path]) -> None:
    """Cross-clip: each clip's median body height vs the idle strip's, both
    normalized the way the engine scales them (enemy _apply_strip: actions and
    MOB_BODY_SCALE_WALK walks ride the idle cell, plain locomotion its own).
    The idle STRIP is the reference -- it is what the owner accepted on
    screen; statics are not rendered once an anim exists."""
    scale_walk = body_scale_walk_keys()
    for png in files:
        key = str(png.parent / png.stem)
        stat = _strip_stats.get(key)
        if stat is None or stat["clip"] in ("anim", "run"):
            continue
        parts = png.stem.split("_")
        d = parts[-1] if parts[-1] in DIR8 else None
        core = parts[:-1] if d else parts
        base = "_".join(core[:-1])
        ref = None
        # Codex-regen bosses run off <base>_anim_codex (art.gd BOSS_IDLE_STRIP_BASE),
        # and their clips were built against it — compare to it, not the legacy
        # low-res <base>_anim, or every clip reads as a spurious ~4x CLIPSCALE.
        candidates = ([f"{base}_anim_codex_{d}"] if d else []) + [f"{base}_anim_codex"] \
            + ([f"{base}_anim_{d}"] if d else []) + [f"{base}_anim", f"{base}_anim_s"]
        for cand in candidates:
            ref = _strip_stats.get(str(png.parent / cand))
            if ref:
                break
        if not ref or ref["med_h"] <= 0 or ref["cell"] <= 0:
            continue
        is_action = stat["clip"] in ("attack", "attack2", "attackb", "attackc") \
            or stat["clip"] in ability_tokens()
        action_like = is_action or (stat["clip"] == "walk" and base in scale_walk)
        denom = ref["cell"] if action_like else stat["cell"]
        ratio = (stat["med_h"] / denom) / (ref["med_h"] / ref["cell"])
        lo = SCALE_LO_ACTION if is_action else SCALE_LO_LOCO
        if ratio < lo or ratio > SCALE_HI:
            WARN.append(f"[CLIPSCALE] {png.relative_to(SPRITES)}: renders at "
                        f"{ratio:.2f}x the idle body height "
                        f"(clip {stat['med_h']:.0f}px/{denom}, idle "
                        f"{ref['med_h']:.0f}px/{ref['cell']}) -- clip plays "
                        "smaller/larger than the body")


def check_dir_sets(files: list[Path]) -> None:
    groups: dict[str, set[str]] = {}
    for f in files:
        m = re.match(r"^(.*)_(" + "|".join(DIR8) + r")$", f.stem)
        if m:
            groups.setdefault(str(f.parent / m.group(1)), set()).add(m.group(2))
    for stem, dirs in sorted(groups.items()):
        gap = [d for d in DIR8 if d not in dirs]
        if gap:
            WARN.append(f"[DIR8] {Path(stem).relative_to(SPRITES)}_*: missing facing(s) "
                        f"{gap} -- engine falls back to south; usually an install slip")


def main() -> int:
    ap = argparse.ArgumentParser(description="post-install sprite checks")
    ap.add_argument("bases", nargs="*", help="sprite base names (subpaths ok: skins/elite/...)")
    ap.add_argument("--all", action="store_true", help="IMPORT + DIR8 across the whole sprites dir")
    args = ap.parse_args()
    if not args.bases and not args.all:
        ap.error("give one or more base names, or --all")

    if args.all:
        pngs = sorted(SPRITES.rglob("*.png"))
        for p in pngs:
            check_import(p)
        check_dir_sets(pngs)
    for base in args.bases:
        base = base.replace("\\", "/").strip("/")
        parent = SPRITES / Path(base).parent
        name = Path(base).name
        mine = sorted(p for p in parent.glob("*.png") if belongs(p.stem, name))
        if not mine:
            FAIL.append(f"[FILES] no sprites found for base '{base}' under assets/sprites/")
            continue
        print(f"{base}: {len(mine)} file(s)")
        for p in mine:
            check_file(p)
        check_clip_scale(mine)
        check_dir_sets(mine)

    for f in FAIL:
        print("FAIL " + f)
    for w in WARN:
        print("WARN " + w)
    if not FAIL and not WARN:
        print("VERIFY OK")
    else:
        print(f"\nVERIFY: {len(FAIL)} fail, {len(WARN)} warn")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
