"""Melee swing ALTERNATION art pipeline (2026-08-16).

Builds the ALTERNATE basic swing strips (`<class>_attackb[_<dir>].png`) that
`player_core._alt_basic_clip` flips with `attack` every a1 cast, so Cleave /
Judgment / Stab stop replaying one identical motion.

Three subcommands, one class at a time:

  briefs  <class>   stage `art_src/melee_alt_swing_2026-08-16/<class>/attackb_<dir>/`
                    with a Codex ImageGen brief (codex_brief.txt) + refs/ for
                    tools/art/run_codex_batch.ps1. Warrior: 8 authored dirs.
                    Paladin: 5 authored (S SE E NE N); W side mirrored at build,
                    matching its every other clip.
  build   <class>   every `attackb_<dir>/*_source.png` (newest version wins, or
                    --pick dir=vNN / rNN) -> border-connected key + hard alpha +
                    rim despill -> figures sliced by CONNECTED COMPONENTS (a
                    level sword's extent interleaves the neighbour's column, so
                    gutter cuts miscount) -> body normalised to 180px from
                    frame 1 (feet on one baseline; `--even-body` = every frame's
                    dense-body height, sword excluded, to 180 — upright swings)
                    -> `--stretch dir=f,f` axial blade stretch of listed frames
                    to the row's longest level blade (owner: "blade changes
                    size"; explicit lists only, see the pass README) -> dense-body
                    X anchor in a square cell that auto-grows to the arc ->
                    `<dir>/<class>_attackb_<dir>_candidate.png` + contact sheet
                    + 22fps GIFs + per-frame body_h/blade metrics. Mirrors the
                    W side for the paladin. Reports the CONTACT frame.
  install <class>   copies accepted candidates into game/assets/sprites as
                    `<class>_attackb_<dir>.png` + the flat `<class>_attackb.png`
                    South alias, backing up anything it replaces under
                    `<pass>/<class>/runtime_pre_install/` with SHA256SUMS.txt.
                    Mobile is synced afterwards by tools/sync_mobile.py.

Assassin alt strips come from PixelLab (owner-authorised for this task):
animate_character v3 on Assassin v2 (S/E/N, 8 frames + reference) -> pick 8
runtime frames (pixellab_raw/<dir>_sel) -> pixellab_resize_assassin_attack.py
per direction (same description/palette/seed as the base stab; `--runtime-cell
336` for N, whose arms-wide follow-through outgrows 277) -> `assassin-assemble`
(E also serves NE/SE, W side mirrored — the base stab's layout) -> `install
assassin`.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import re
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageOps

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import _hard_alpha  # noqa: E402
from build_preservation_walk_candidate import _write_qa  # noqa: E402
from rebuild_preservation_archer_alpha import _connected_key  # noqa: E402

ROOT = TOOLS.parents[1]
SPRITES = ROOT / "game" / "assets" / "sprites"
PASS = ROOT / "art_src" / "melee_alt_swing_2026-08-16"

DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
AUTHORED = {
    "warrior": DIRS,                       # every base attack dir is authored
    "paladin": ("s", "se", "e", "ne", "n"),  # W side mirrored (paladin convention)
    "assassin": ("s", "e", "n"),           # PixelLab: E authored, W mirrored
}
MIRROR = {"w": "e", "sw": "se", "nw": "ne"}
FRAMES = {"warrior": 7, "paladin": 7, "assassin": 8}
FPS = 22.0
BODY = 180
BASE_CELL = 277
WIDE_CELL = 352
BASELINE = 255          # feet row + 1 inside a 277 cell (build_preservation _normalize)
SAFE_MARGIN = 8
DENSE_FRACTION = 0.35
MIN_COLUMN_PIXELS = 20

FACING = {
    "s": "FRONT view (south): the figure faces the camera",
    "se": "FRONT-RIGHT three-quarter view (southeast): the figure faces toward the camera and toward the viewer's right",
    "e": "RIGHT PROFILE (east): the figure faces the viewer's right",
    "ne": "REAR-RIGHT three-quarter view (northeast): the figure faces away from the camera and toward the viewer's right",
    "n": "BACK view (north): the figure faces directly away from the camera; we see the back of the helmet/head, backplate and cloak",
    "nw": "REAR-LEFT three-quarter view (northwest): the figure faces away from the camera and toward the viewer's left",
    "w": "LEFT PROFILE (west): the figure faces the viewer's left",
    "sw": "FRONT-LEFT three-quarter view (southwest): the figure faces toward the camera and toward the viewer's left",
}

# ------------------------------------------------------------------ briefs ---

WARRIOR_IDENTITY = (
    "the exact Crownless Warrior of Image 1: broad, stocky fully-armoured knight in "
    "black/dark-steel plate with ember-orange accent lines, compact crowned black "
    "helmet with a narrow orange visor and fully enclosed face, chest harness, hip "
    "armour, heavy gauntlets and boots, one two-handed flaming greatsword (dark blade "
    "with orange ember wisps) — no shield, no cape, no other weapon"
)
PALADIN_IDENTITY = (
    "the exact Oathbound Arbiter Paladin of Image 1: visible weathered middle-aged "
    "face, short dark hair and beard, pale steel and warm ivory plate, deep "
    "judicial-blue tabard and one-shoulder mantle, brass oath-chain crossing a large "
    "round seal over the heart, square-headed war hammer in the RIGHT hand, tall "
    "battered pale shield on the LEFT arm"
)

STYLE = (
    "Camera and medium: low top-down orthographic/isometric action-RPG camera; "
    "authentic premium hand-pixeled rendering; deliberate square pixel clusters; "
    "selective dark outlines; bold readable colour masses; simplified material seams; "
    "controlled texture; legible after reduction to about 88 pixels tall. "
    "Do not render smooth digital painting, vector art, 3D or splash illustration."
)
LAYOUT = (
    "Layout: ONE horizontal row of exactly {n} isolated full-body figures, left to "
    "right = frames f1..f{n}, in a wide 3:1 landscape image (about 2172 x 724 px). "
    "Every figure is the SAME character at the SAME scale, proportions, equipment "
    "dimensions, palette, camera and facing, feet on ONE shared ground line. "
    "Generous flat pure #00ff00 gutters between figures (at least a torso width): "
    "no figure or effect may touch, overlap or cross into a neighbour's space or be "
    "cropped by the image edge — keep the whole weapon, effect, head and feet inside "
    "each figure's own space. Frame f1 must be a full-height standing pose."
)
BACKDROP = (
    "Backdrop: perfectly flat solid #00ff00 only; no floor, cast/contact shadow, "
    "gradient, reflection, scenery, text, labels, frame numbers, arrows, grid lines, "
    "panels, border or watermark. No green (#00ff00 or near it) inside the character "
    "or the effect."
)
DELIVERY = (
    "Deliverable: generate with the built-in image_gen tool, then COPY the raw "
    "generated PNG (do NOT key, crop, resize or edit it) into the current working "
    "directory as `{stem}_v01_source.png`. Inspect it at full resolution: if the row "
    "does not hold exactly {n} clearly separated figures on green, if any figure or "
    "effect crosses into a neighbour, if the facing drifts from the assigned "
    "direction in ANY frame, or if the motion reproduces the primary swing instead "
    "of the alternate one described, generate again (save as `_v02_source.png`, "
    "`_v03_source.png`, ...; keep every attempt) — at most 3 attempts. Do not "
    "write anywhere except the current working directory. Finish with a short "
    "report: which version you consider best, and per frame f1..f{n} one line "
    "describing weapon position/height and the figure's facing."
)


def _warrior_brief(d: str) -> str:
    n = FRAMES["warrior"]
    return f"""Asset type: production high-resolution pixel-art animation source row for Crownless (Godot action-RPG).

Image 1 is the BINDING identity, scale, camera and facing reference: it is this Warrior's EXISTING primary Cleave (an overhead raise into a downward diagonal chop) seen from the {d.upper()} facing. Reproduce exactly that same character — {WARRIOR_IDENTITY} — at exactly the same body size, camera and {d.upper()} facing. Do NOT reproduce its motion: that overhead chop is the primary swing; you are authoring the ALTERNATE swing that alternates with it.

Create one {n}-frame ALTERNATE CLEAVE timeline: a LEVEL HORIZONTAL SWEEP of the greatsword at waist-to-chest height. The blade stays roughly parallel to the ground for the whole swing — it is never raised above the shoulders and never chops downward. Facing: {FACING[d]} in EVERY frame, f1 through f{n}, including the recovery. Both hands stay on the hilt.

f1  guard: standing full height, greatsword held low and level in front of the hips, weight centred (this frame sets the body scale).
f2  windup: hips and shoulders coil AWAY from the target, the sword drawn back to the character's weapon side, blade level, pointing backward, ember wisps gathering along the edge.
f3  swing: the blade whips forward at waist height, mid-arc beside the body, a short ember trail following the edge.
f4  CONTACT — the peak: arms fully extended, the sword pointing straight ahead of the character at chest height, blade level, the strongest ember trail sweeping behind the edge; the widest, most readable frame.
f5  follow-through: the blade continues past the front to the character's OFF side, torso twisted with the swing, trail thinning.
f6  recovery: the sword swings back toward centre, level, torso unwinding, wisps fading.
f7  settle: back to a guard nearly identical to f1 (sword low and level), so the loop closes.

The ember effect is a compact trail attached to the blade edge only — no detached rings, waves, projectiles, ground cracks or fire pools, nothing that leaves the figure's own space.

{STYLE}

{LAYOUT.format(n=n)}

{BACKDROP}

Negative constraints: no overhead raise, no downward chop, no thrust/stab, no spin; no shield, cape, second weapon or extra limbs; no change of helmet, armour or blade design between frames; no leg recolouring, no duplicated frames, no size drift between frames, no frame that turns toward a different direction.

{DELIVERY.format(stem=f"warrior_attackb_{d}", n=n)}
"""


def _paladin_brief(d: str) -> str:
    n = FRAMES["paladin"]
    return f"""Asset type: production high-resolution pixel-art animation source row for Crownless (Godot action-RPG).

Image 1 is the BINDING identity reference (five rotations of the Oathbound Arbiter). Image 2 is the same Paladin's EXISTING primary Judgment — an overhead hammer slam — seen from the {d.upper()} facing; use Image 2 ONLY for scale, camera and facing, and do NOT reproduce its motion: that overhead slam is the primary swing; you are authoring the ALTERNATE swing that alternates with it. Reproduce exactly that same character — {PALADIN_IDENTITY} — at exactly Image 2's body size, camera and {d.upper()} facing. Do not redesign, simplify away, add, remove or swap equipment; the hammer stays in the right hand and the shield on the left arm in every frame.

Create one {n}-frame ALTERNATE JUDGMENT timeline: a LEVEL SIDEWAYS HAMMER SWING at waist-to-chest height, the square hammer head leading. The hammer never rises above the shoulders and never slams downward. Facing: {FACING[d]} in EVERY frame, f1 through f{n}, including the recovery. The shield stays on the left forearm the whole time and does not swing.

f1  guard: standing full height, hammer hanging at the right side, shield forward, weight centred (this frame sets the body scale).
f2  windup: shoulders and hips coil, the hammer drawn back behind the right hip, shaft level, head pointing backward.
f3  swing: the hammer sweeps forward at waist height, mid-arc, right arm extending.
f4  CONTACT — the peak: right arm fully extended, the hammer head straight ahead of the character at chest height, shaft level, a compact golden impact spark at the square head; the widest, most readable frame.
f5  follow-through: the hammer continues across the front toward the shield side, torso twisted with the swing, spark fading.
f6  recovery: the hammer swings back toward the right hip, torso unwinding.
f7  settle: back to a guard nearly identical to f1, so the loop closes.

The golden spark is a compact effect attached to the hammer head only — no detached rings, ground seals, beams or auras, nothing that leaves the figure's own space.

{STYLE}

{LAYOUT.format(n=n)}

{BACKDROP}

Negative constraints: no overhead raise, no downward slam, no thrust, no spin; no shield swing or shield loss; the complete square metal hammer head and shaft stay visible in every frame; no change of face, hair, armour, tabard or hammer between frames; no duplicated frames, no size drift, no frame that turns toward a different direction.

{DELIVERY.format(stem=f"paladin_attackb_{d}", n=n)}
"""


def _green_composite(strip: Path, out: Path) -> None:
    """Runtime (transparent) strip -> flat #00ff00 reference PNG for Codex."""
    im = Image.open(strip).convert("RGBA")
    bg = Image.new("RGBA", im.size, (0, 255, 0, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(out)


def cmd_briefs(cls: str) -> None:
    if cls == "warrior":
        acc = ROOT / "art_src" / "class_attack_regen_imagegen_2026-08-02" / "warrior"
        accepted = {"s": "v01", "se": "v03", "e": "v01", "ne": "v02",
                    "n": "v04", "nw": "v01", "w": "v03", "sw": "v01"}
        for d in AUTHORED[cls]:
            stage = PASS / cls / f"attackb_{d}"
            refs = stage / "refs"
            refs.mkdir(parents=True, exist_ok=True)
            src = acc / f"attack_{d}" / f"warrior_attack_{d}_{accepted[d]}_source.png"
            shutil.copy2(src, refs / f"1_identity_facing_{d}_existing_cleave.png")
            (stage / "codex_brief.txt").write_text(_warrior_brief(d), encoding="utf-8")
            print(f"staged {stage.relative_to(ROOT)}")
    elif cls == "paladin":
        rot = ROOT / "art_src" / "paladin_oathbound_arbiter" / "regen_base_rotations.png"
        for d in AUTHORED[cls]:
            stage = PASS / cls / f"attackb_{d}"
            refs = stage / "refs"
            refs.mkdir(parents=True, exist_ok=True)
            shutil.copy2(rot, refs / "1_identity_rotations.png")
            _green_composite(SPRITES / f"paladin_attack_{d}.png",
                             refs / f"2_facing_{d}_existing_judgment.png")
            (stage / "codex_brief.txt").write_text(_paladin_brief(d), encoding="utf-8")
            print(f"staged {stage.relative_to(ROOT)}")
    else:
        raise SystemExit("briefs: warrior|paladin only (assassin = PixelLab)")
    print("run: powershell -File tools/art/run_codex_batch.ps1 -Stages \"<dir>,<dir>,...\"")


# ------------------------------------------------------------------- build ---

def _despill_rim(image: Image.Image) -> Image.Image:
    """Drop / desaturate the 2px green antialias rim every ImageGen key leaves
    (build_mob_walk_repairs.remove_green, edge band only)."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = rgba[..., 3] > 0
    core = np.asarray(Image.fromarray((opaque * 255).astype(np.uint8))
                      .filter(ImageFilter.MinFilter(5))) > 0
    rim = opaque & ~core
    r, g, b = (rgba[..., i].astype(np.int16) for i in range(3))
    spill = g - np.maximum(r, b)
    rgba[..., 3][rim & (spill > 40)] = 0
    fix = rim & (spill > 8) & (rgba[..., 3] > 0)
    cap = np.maximum(r[fix], b[fix]).clip(0, 255)
    rgba[..., 1][fix] = np.minimum(g[fix], cap).astype(np.uint8)
    rgba[~(rgba[..., 3] > 0), :3] = 0
    return Image.fromarray(rgba, "RGBA")


def _dense_anchor(frame: Image.Image) -> float:
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8) > 0
    occ = alpha.sum(axis=0)
    thr = max(MIN_COLUMN_PIXELS, int(occ.max()) * DENSE_FRACTION)
    cols = np.flatnonzero(occ >= thr)
    if cols.size == 0:
        raise ValueError("no dense body columns")
    w = occ[cols].astype(np.float64)
    return float(np.dot(cols, w) / w.sum())


def _body_height(frame: Image.Image) -> int:
    """Helmet-to-feet height of the DENSE body columns (thin sword/arm
    protrusions excluded) — the height the eye reads as 'the character'."""
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8) > 0
    occ = alpha.sum(axis=0)
    thr = max(MIN_COLUMN_PIXELS, int(occ.max()) * DENSE_FRACTION)
    cols = np.flatnonzero(occ >= thr)
    rows = np.flatnonzero(alpha[:, cols[0]:cols[-1] + 1].any(axis=1))
    return int(rows[-1] - rows[0] + 1)


def _normalize_frames(frames: list[Image.Image], body: int,
                      even_body: bool = False, even_tol: float = 0.12) -> list[Image.Image]:
    """Frame-1 body -> `body` px, feet on BASELINE. Default = ONE scale for
    every frame (frame 1's), so authored crouch/recoil keeps its size.
    even_body = per-frame scale so every frame's DENSE-BODY height (sword
    excluded) equals frame 1's — for an upright swing whose generator drew the
    mid frames a few % smaller (owner: 'sprite size not consistent'). Frames
    that differ by more than even_tol are treated as a real crouch and keep the
    shared scale."""
    boxes = [f.getbbox() for f in frames]
    if any(b is None for b in boxes):
        raise ValueError("empty frame")
    scale = body / float(boxes[0][3] - boxes[0][1])
    ref_body = _body_height(frames[0])
    figures: list[Image.Image] = []
    for f, b in zip(frames, boxes, strict=True):
        fig = f.crop(b)
        s = scale
        if even_body:
            ratio = ref_body / float(_body_height(fig))
            if abs(ratio - 1.0) <= even_tol:
                s = scale * ratio
        size = (max(1, round(fig.width * s)), max(1, round(fig.height * s)))
        figures.append(_hard_alpha(fig.resize(size, Image.Resampling.LANCZOS)))
    return figures


def _fit_cell(figures: list[Image.Image], minimum: int) -> int:
    """Smallest square cell (multiple of 16, >= minimum) that holds every
    figure centred on its dense-body X with SAFE_MARGIN to spare. A level
    full-extension sword needs more than the 352 the base cleave used."""
    need = minimum
    for fig in figures:
        ax = _dense_anchor(fig)
        half = max(ax, fig.width - ax) + SAFE_MARGIN + 1
        need = max(need, int(2 * half) + 1, fig.height + (BASE_CELL - BASELINE) + SAFE_MARGIN + 1)
    return ((need + 15) // 16) * 16


def _anchor_cells(figures: list[Image.Image], cell: int) -> list[Image.Image]:
    """Place each figure so its dense-body X sits at cell/2 and its feet on the
    shared baseline (cell - (277 - BASELINE))."""
    baseline = cell - (BASE_CELL - BASELINE)
    out: list[Image.Image] = []
    for i, fig in enumerate(figures):
        ax = _dense_anchor(fig)
        x = round(cell / 2.0 - ax)
        y = baseline - fig.height
        if x < SAFE_MARGIN or x + fig.width > cell - SAFE_MARGIN or y < SAFE_MARGIN:
            raise ValueError(f"f{i + 1} breaches the {cell}px cell (x={x}, w={fig.width}, y={y}, h={fig.height})")
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(fig, (x, y))
        out.append(canvas)
    return out


def _contact_frame(cells: list[Image.Image]) -> int:
    """1-based frame whose silhouette reaches furthest from the dense body —
    the weapon's max extension = the swing's contact frame."""
    best, best_i = -1.0, 1
    for i, c in enumerate(cells):
        alpha = np.asarray(c.getchannel("A"), dtype=np.uint8) > 0
        cols = np.flatnonzero(alpha.any(axis=0))
        ax = _dense_anchor(c)
        reach = max(abs(cols[0] - ax), abs(cols[-1] - ax))
        if reach > best:
            best, best_i = reach, i + 1
    return best_i


def _label8(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """8-connected component labels (row-run union-find; ~1.5 Mpx in <2 s).
    Returns (labels 1..n, n); background 0."""
    h, w = mask.shape
    parent: list[int] = [0]

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    labels = np.zeros((h, w), dtype=np.int32)
    prev_runs: list[tuple[int, int, int]] = []   # (x0, x1 exclusive, label)
    for y in range(h):
        row = mask[y]
        if not row.any():
            prev_runs = []
            continue
        d = np.diff(np.concatenate(([0], row.astype(np.int8), [0])))
        starts = np.flatnonzero(d == 1)
        ends = np.flatnonzero(d == -1)
        runs: list[tuple[int, int, int]] = []
        for x0, x1 in zip(starts, ends):
            lab = len(parent)
            parent.append(lab)
            # 8-connectivity: overlap with previous row runs allowing 1px diagonal
            for px0, px1, plab in prev_runs:
                if px0 < x1 + 1 and px1 + 1 > x0:
                    union(lab, plab)
            runs.append((int(x0), int(x1), lab))
            labels[y, x0:x1] = lab
        prev_runs = runs
    # flatten
    roots = np.array([find(i) for i in range(len(parent))], dtype=np.int32)
    flat = roots[labels]
    uniq = np.unique(flat[flat > 0])
    remap = np.zeros(int(roots.max()) + 1, dtype=np.int32)
    remap[uniq] = np.arange(1, len(uniq) + 1)
    return remap[flat], len(uniq)


def _split_figures(keyed: Image.Image, n: int) -> tuple[list[Image.Image], list[int], str]:
    """Slice ONE row of `n` figures whose horizontal extents may interleave
    (a level sword reaching past the neighbour's column) by connected
    components: the n largest components are the bodies (weapon attached);
    every smaller island (ember wisp, spark) joins the body whose bbox is
    nearest. Frames come out as tight RGBA crops, left to right. Returns
    (frames, per-frame stray-pixel counts, note). Raises when the n largest
    components are not n distinct figures (two figures fused = real overlap)."""
    alpha = np.asarray(keyed.getchannel("A"), dtype=np.uint8) > 0
    labels, count = _label8(alpha)
    if count < n:
        raise ValueError(f"only {count} components — figures fused")
    areas = np.bincount(labels.ravel())[1:]
    order = (np.argsort(areas)[::-1] + 1).tolist()
    # sanity: the n-th body must be a real figure, not a big spark
    if areas[order[n - 1] - 1] < 0.35 * areas[order[0] - 1]:
        raise ValueError(f"{n}th largest component is only "
                         f"{areas[order[n-1]-1]/areas[order[0]-1]:.0%} of the largest — figures fused or missing")
    bodies = sorted(order[:n], key=lambda l: float(np.nonzero(labels == l)[1].mean()))
    boxes: dict[int, tuple[int, int, int, int]] = {}
    for l in bodies:
        ys, xs = np.nonzero(labels == l)
        boxes[l] = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    assign = {l: l for l in bodies}
    strays = {l: 0 for l in bodies}
    for l in range(1, count + 1):
        if l in assign:
            continue
        ys, xs = np.nonzero(labels == l)
        cx, cy = float(xs.mean()), float(ys.mean())
        best, bd = None, 1e18
        for b, (x0, y0, x1, y1) in boxes.items():
            dx = max(x0 - cx, 0.0, cx - x1)
            dy = max(y0 - cy, 0.0, cy - y1)
            dist = dx * dx + dy * dy
            if dist < bd:
                best, bd = b, dist
        assign[l] = best
        strays[best] += int(xs.size)
    rgba = np.asarray(keyed.convert("RGBA"), dtype=np.uint8)
    frames: list[Image.Image] = []
    counts: list[int] = []
    for b in bodies:
        members = [l for l, a in assign.items() if a == b]
        m = np.isin(labels, members)
        ys, xs = np.nonzero(m)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        cell = rgba[y0:y1, x0:x1].copy()
        cell[..., 3] = np.where(m[y0:y1, x0:x1], cell[..., 3], 0)
        cell[cell[..., 3] == 0, :3] = 0
        frames.append(Image.fromarray(cell, "RGBA"))
        counts.append(strays[b])
    # frames sorted by body centre x already (bodies sorted); guard order
    centres = [(f.width, i) for i, f in enumerate(frames)]
    note = f"{count} components; strays/frame={counts}"
    return frames, counts, note


def _pick_source(stage: Path, forced: str | None) -> Path | None:
    """Newest `*_vNN_source.png` / `*_rNN_source.png` (r = Codex repair pass),
    or the forced version tag (`v01`, `r02`)."""
    srcs = sorted(stage.glob("*_v*_source.png")) + sorted(stage.glob("*_r*_source.png"))
    if not srcs:
        return None
    if forced:
        for s in srcs:
            if f"_{forced}_" in s.name:
                return s
        raise SystemExit(f"{stage.name}: no {forced} source")
    return srcs[-1]


# ---- blade-length evening (owner 2026-08-16: "warrior's blade changes size") ----
# ImageGen draws each figure independently, so a held prop's length drifts frame
# to frame (the E row: level windup blade ~100px, contact blade ~185px at the
# same body scale) and a Codex repair pass could not hold it either. This
# measures the blade as the protrusion beyond the dense body on the weapon side,
# split at the GAUNTLET block (a run of cross-sections wider than ARM_W near the
# body) so the length is grip->tip, and stretches short blades along their own
# axis about the grip. Only LEVEL frames (axis within LEVEL_DEG of horizontal —
# the sweep frames whose root is visible) are touched: a diagonal-down guard
# blade has its root inside the body columns, so its visible length says nothing.
BLADE_BIN = 3
ARM_W = 55
LEVEL_DEG = 28.0
BLADE_MIN_FACTOR = 1.06     # below this the difference is noise
BLADE_MAX_FACTOR = 2.0


def _blade_geom(a: np.ndarray) -> dict | None:
    occ = a.sum(axis=0)
    thr = max(MIN_COLUMN_PIXELS, int(occ.max()) * DENSE_FRACTION)
    cols = np.flatnonzero(occ >= thr)
    bx0, bx1 = int(cols[0]), int(cols[-1])
    ys, xs = np.nonzero(a)
    left, right = xs < bx0 - 1, xs > bx1 + 1
    side_right = right.sum() >= left.sum()
    side = right if side_right else left
    if side.sum() < 80:
        return None
    px, py = xs[side].astype(float), ys[side].astype(float)
    mx, my = px.mean(), py.mean()
    X = np.stack([px - mx, py - my], 1)
    w, v = np.linalg.eigh(X.T @ X)
    u = v[:, int(np.argmax(w))]
    if (u[0] > 0) != side_right:
        u = -u
    n = np.array([-u[1], u[0]])
    t = X @ u
    s = X @ n
    tmin = float(t.min())
    t = t - tmin
    nb = int(t.max() // BLADE_BIN) + 1
    binidx = (t // BLADE_BIN).astype(int)
    cnt = np.bincount(binidx, minlength=nb)
    prof = np.zeros(nb)
    for b in range(nb):
        m = binidx == b
        if m.sum() >= 2:
            ss = s[m]
            prof[b] = np.percentile(ss, 95) - np.percentile(ss, 5)
    tip = int(np.flatnonzero(cnt > 0)[-1])
    lim = int(tip * 0.45)
    arm = [b for b in range(lim + 1) if prof[b] > ARM_W]
    grip = (arm[-1] + 1) if arm else 0
    ang = math.degrees(math.atan2(u[1], u[0]))
    level = min(abs(ang) % 180.0, 180.0 - abs(ang) % 180.0) <= LEVEL_DEG
    origin = np.array([mx, my]) + u * tmin           # body-edge point on the axis (t = 0)
    return {"u": u, "n": n, "origin": origin, "grip_t": grip * BLADE_BIN,
            "tip_t": tip * BLADE_BIN, "L": (tip - grip + 1) * BLADE_BIN,
            "arm": bool(arm), "level": level, "ang": ang, "side_right": side_right}


def _stretch_blade(fig: Image.Image, g: dict, factor: float) -> Image.Image:
    """Axial stretch of the pixels beyond the grip about the grip point, along
    the blade axis (a pure scale along u; the lateral coordinate is untouched,
    so the blade keeps its width and its own direction). Body pixels stay
    pristine: only the blade layer is resampled (bilinear, then hard alpha)."""
    u, n = g["u"], g["n"]
    O = g["origin"] + u * g["grip_t"]              # grip point on the axis
    rgba = np.asarray(fig.convert("RGBA"), dtype=np.uint8)
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    trel = (xx - O[0]) * u[0] + (yy - O[1]) * u[1]
    alpha = rgba[..., 3] > 0
    occ = alpha.sum(axis=0)
    thr = max(MIN_COLUMN_PIXELS, int(occ.max()) * DENSE_FRACTION)
    cols = np.flatnonzero(occ >= thr)
    beyond = (xx > cols[-1] + 1) if g["side_right"] else (xx < cols[0] - 1)
    blade = alpha & beyond & (trel > 0)
    layer = rgba.copy()
    layer[~blade] = 0
    body = rgba.copy()
    body[blade] = 0
    # grow the canvas so the stretched blade fits: pad on every side by the extra length
    extra = int(math.ceil((factor - 1.0) * (g["tip_t"] - g["grip_t"]))) + 8
    W, H = w + 2 * extra, h + 2 * extra
    Ox, Oy = O[0] + extra, O[1] + extra
    layer_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer_img.paste(Image.fromarray(layer, "RGBA"), (extra, extra))
    # PIL affine takes the OUTPUT->INPUT map: p_in = O + M (p_out - O), M = I + (1/f - 1) u u^T
    k = 1.0 / factor - 1.0
    a, b = 1 + k * u[0] * u[0], k * u[0] * u[1]
    d, e = k * u[1] * u[0], 1 + k * u[1] * u[1]
    c = Ox - (a * Ox + b * Oy)
    f_ = Oy - (d * Ox + e * Oy)
    stretched = layer_img.transform((W, H), Image.Transform.AFFINE, (a, b, c, d, e, f_),
                                    resample=Image.Resampling.BILINEAR)
    st = np.asarray(stretched, dtype=np.uint8).copy()
    keep = st[..., 3] > 96
    st[..., 3] = np.where(keep, 255, 0).astype(np.uint8)
    st[~keep, :3] = 0
    out = np.zeros((H, W, 4), dtype=np.uint8)
    out[extra:extra + h, extra:extra + w] = body
    m = st[..., 3] > 0
    out[m] = st[m]
    res = Image.fromarray(out, "RGBA")
    return res.crop(res.getbbox())


def _even_blades(figures: list[Image.Image], only: set[int] | None
                 ) -> tuple[list[Image.Image], list[str]]:
    """Per row: target = the longest blade among LEVEL frames (the contact
    frame); every frame in `only` (0-based) shorter than target/BLADE_MIN_FACTOR
    is stretched to it. `only` is EXPLICIT (per direction, from inspecting the
    source: frames whose blade is level and whose root — hands at or beyond
    the body edge — is visible). No automatic guessing: a diagonal guard blade
    has its root inside the body columns, so its visible length says nothing
    (an automatic level-angle rule stretched E's guard blades x1.8 — wrong).
    Returns (figures, per-frame notes)."""
    geoms = [_blade_geom(np.asarray(f.convert("RGBA"))[:, :, 3] > 0) for f in figures]
    ref = [g["L"] for g in geoms if g and g["level"]]
    notes = ["-" if g is None else f"{g['L']}@{g['ang']:.0f}deg" for g in geoms]
    if not ref or not only:
        return figures, notes
    target = max(ref)
    out: list[Image.Image] = []
    for i, (f, g) in enumerate(zip(figures, geoms, strict=True)):
        if i not in only or g is None:
            out.append(f)
            continue
        factor = target / float(g["L"])
        if factor < BLADE_MIN_FACTOR:
            out.append(f)
            notes[i] += " ok"
            continue
        factor = min(factor, BLADE_MAX_FACTOR)
        out.append(_stretch_blade(f, g, factor))
        notes[i] += f" x{factor:.2f}"
    return out, notes


def _blade_metric(fig: Image.Image) -> int:
    """Length (px, principal-axis extent) of the biggest protrusion beyond the
    dense body — the weapon (+ extended arm). Not a true blade length, but a
    like-for-like drift metric across the frames of ONE pose family."""
    a = np.asarray(fig.getchannel("A"), dtype=np.uint8) > 0
    occ = a.sum(axis=0)
    thr = max(MIN_COLUMN_PIXELS, int(occ.max()) * DENSE_FRACTION)
    cols = np.flatnonzero(occ >= thr)
    ys, xs = np.nonzero(a)
    left, right = xs < cols[0] - 1, xs > cols[-1] + 1
    side = right if right.sum() >= left.sum() else left
    if side.sum() < 30:
        return 0
    px, py = xs[side].astype(float), ys[side].astype(float)
    X = np.stack([px - px.mean(), py - py.mean()], 1)
    w, v = np.linalg.eigh(X.T @ X)
    proj = X @ v[:, int(np.argmax(w))]
    return int(round(proj.max() - proj.min()))


def _mirror_strip(strip: Image.Image) -> Image.Image:
    h = strip.height
    n = strip.width // h
    out = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for i in range(n):
        out.paste(ImageOps.mirror(strip.crop((i * h, 0, (i + 1) * h, h))), (i * h, 0))
    return out


def cmd_build(cls: str, picks: dict[str, str], cell_override: int | None,
              source_dir: Path | None, even_body: bool = False,
              stretch: dict[str, set[int]] | None = None,
              mirror_override: dict[str, str] | None = None) -> None:
    n = FRAMES[cls]
    root = source_dir or (PASS / cls)
    built: dict[str, Image.Image] = {}
    report: list[str] = []
    mirror_override = mirror_override or {}
    for d in AUTHORED[cls]:
        if d in mirror_override:
            continue  # this direction is a mirror of another (see below)
        stage = root / f"attackb_{d}"
        src = _pick_source(stage, picks.get(d))
        if src is None:
            report.append(f"{d}: NO SOURCE yet")
            continue
        ver = re.search(r"_([vr]\d+)_source", src.name).group(1)
        stem = f"{cls}_attackb_{d}"
        keyed, key, removed = _connected_key(Image.open(src).convert("RGBA"))
        keyed = _despill_rim(_hard_alpha(keyed))
        keyed.save(stage / f"{stem}_{ver}_keyed.png")
        try:
            frames, strays, note = _split_figures(keyed, n)
        except ValueError as err:
            report.append(f"{d}: {src.name} — REJECT ({err})")
            continue
        figures = _normalize_frames(frames, BODY, even_body=even_body)
        blade_notes: list[str] = []
        if stretch is not None:
            figures, blade_notes = _even_blades(figures, stretch.get(d))
        cell = cell_override or _fit_cell(figures, BASE_CELL)
        cells = _anchor_cells(figures, cell)
        strip = Image.new("RGBA", (cell * n, cell), (0, 0, 0, 0))
        for i, c in enumerate(cells):
            strip.alpha_composite(c, (i * cell, 0))
        strip.save(stage / f"{stem}_candidate.png", optimize=True)
        contact = _contact_frame(cells)
        _write_qa(stage, f"{stem}_{ver}", f"{stem} {ver} ({n}f @ {FPS:g}fps, contact f{contact})",
                  cells, FPS, contact)
        heights = [f.getbbox()[3] - f.getbbox()[1] for f in figures]
        bodies = [_body_height(f) for f in figures]
        blades = [_blade_metric(f) for f in figures]
        report.append(f"{d}: {src.name} key={key} {note} "
                      f"cell={cell} body_h={bodies} blade={blades} contact=f{contact} "
                      f"(t={(contact - 1) / FPS:.3f}s)"
                      + (f"\n    blade-even: {blade_notes}" if blade_notes else ""))
        built[d] = strip
    for d, srcd in list(MIRROR.items()) + list(mirror_override.items()):
        if d in AUTHORED[cls] and d not in mirror_override:
            continue
        if srcd in built:
            stage = root / f"attackb_{d}"
            stage.mkdir(parents=True, exist_ok=True)
            m = _mirror_strip(built[srcd])
            m.save(stage / f"{cls}_attackb_{d}_candidate.png", optimize=True)
            built[d] = m
            report.append(f"{d}: mirrored from {srcd}")
    print("\n".join(report))
    if built:
        _all_dirs_sheet(cls, built, root)


def _all_dirs_sheet(cls: str, built: dict[str, Image.Image], root: Path) -> None:
    """One contact sheet: rows = directions, cols = frames, at ~gameplay+ scale."""
    show = 128
    dirs = [d for d in DIRS if d in built]
    n = FRAMES[cls]
    sheet = Image.new("RGBA", (show * n + 40, show * len(dirs)), (25, 28, 34, 255))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(sheet)
    for r, d in enumerate(dirs):
        s = built[d]
        h = s.height
        dr.text((6, r * show + 6), d.upper(), fill=(255, 224, 126, 255))
        for i in range(n):
            f = s.crop((i * h, 0, (i + 1) * h, h)).resize((show, show), Image.Resampling.LANCZOS)
            sheet.alpha_composite(f, (40 + i * show, r * show))
    (root / f"{cls}_attackb_all_directions_contact.png").parent.mkdir(exist_ok=True)
    sheet.save(root / f"{cls}_attackb_all_directions_contact.png")
    # synced gif
    frames = []
    for i in range(n):
        page = Image.new("RGBA", (show * len(dirs), show), (25, 28, 34, 255))
        for c, d in enumerate(dirs):
            s = built[d]
            h = s.height
            page.alpha_composite(s.crop((i * h, 0, (i + 1) * h, h)).resize((show, show), Image.Resampling.LANCZOS), (c * show, 0))
        frames.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
    frames[0].save(root / f"{cls}_attackb_all_directions_{FPS:g}fps.gif", save_all=True,
                   append_images=frames[1:], duration=round(1000 / FPS), loop=0, disposal=2)


def cmd_assassin_assemble() -> None:
    """PixelLab lane: the Resize upscaler wrote
    attackb_{s,e,n}/assassin_alt_slash_<direction>_pixellab_resize_v01_candidate.png.
    Lay them out the way the base stab is: E also serves NE and SE, the W side
    is the exact mirror (w<-e, sw<-se, nw<-ne), and every direction lands as
    attackb_<d>/assassin_attackb_<d>_candidate.png for `install`."""
    root = PASS / "assassin"
    longname = {"s": "south", "e": "east", "n": "north"}
    built: dict[str, Image.Image] = {}
    for d, ln in longname.items():
        src = root / f"attackb_{d}" / f"assassin_alt_slash_{ln}_pixellab_resize_v01_candidate.png"
        if not src.exists():
            raise SystemExit(f"missing {src}")
        im = Image.open(src).convert("RGBA")
        n = im.width // im.height
        if n != FRAMES["assassin"]:
            raise SystemExit(f"{src.name}: {n} frames, need {FRAMES['assassin']}")
        built[d] = im
    built["se"] = built["e"]
    built["ne"] = built["e"]
    for d, srcd in MIRROR.items():
        built[d] = _mirror_strip(built[srcd])
    for d, im in built.items():
        stage = root / f"attackb_{d}"
        stage.mkdir(parents=True, exist_ok=True)
        im.save(stage / f"assassin_attackb_{d}_candidate.png", optimize=True)
        cells = [im.crop((i * im.height, 0, (i + 1) * im.height, im.height)) for i in range(im.width // im.height)]
        print(f"{d}: cell={im.height} contact=f{_contact_frame(cells)}"
              + ("" if d in longname else f"  ({'mirror of ' + MIRROR[d] if d in MIRROR else 'copy of e'})"))
    _all_dirs_sheet("assassin", built, root)


# ----------------------------------------------------------------- install ---

def _sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def cmd_install(cls: str, source_dir: Path | None, apply: bool) -> None:
    root = source_dir or (PASS / cls)
    plan: list[tuple[Path, Path]] = []
    for d in DIRS:
        cand = root / f"attackb_{d}" / f"{cls}_attackb_{d}_candidate.png"
        if not cand.exists():
            raise SystemExit(f"missing candidate: {cand}")
        plan.append((cand, SPRITES / f"{cls}_attackb_{d}.png"))
    plan.append((root / "attackb_s" / f"{cls}_attackb_s_candidate.png", SPRITES / f"{cls}_attackb.png"))
    backup = root / "runtime_pre_install"
    sums: list[str] = []
    for src, dst in plan:
        state = "REPLACE" if dst.exists() else "NEW"
        print(f"{state} {dst.relative_to(ROOT)} <- {src.relative_to(ROOT)}")
        if not apply:
            continue
        if dst.exists():
            backup.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, backup / dst.name)
            sums.append(f"{_sha(dst)}  {dst.name}")
        tmp = dst.with_suffix(".png.tmp")
        shutil.copy2(src, tmp)
        tmp.replace(dst)
        assert _sha(dst) == _sha(src)
    if apply and sums:
        (backup / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    if apply:
        print(f"installed {len(plan)} files for {cls}; run --import + verify_art.py {cls}")
    else:
        print("dry run — pass --apply to write")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("briefs"); b.add_argument("cls")
    u = sub.add_parser("build"); u.add_argument("cls")
    u.add_argument("--pick", action="append", default=[], help="dir=vNN (default newest)")
    u.add_argument("--cell", type=int, default=None)
    u.add_argument("--source-dir", type=Path, default=None)
    u.add_argument("--even-body", action="store_true",
                   help="per-frame dense-body height normalisation (upright swings only)")
    u.add_argument("--mirror", action="append", default=[],
                   help="dir=src: ship this authored direction as the exact mirror of another "
                        "(warrior w=e: the authored W rows came back in blacker plate)")
    u.add_argument("--stretch", action="append", default=[],
                   help="dir=f,f,... (1-based frames) whose level blade is stretched to the row's "
                        "longest level blade; e.g. --stretch e=2,3 --stretch w=1,3,6,7 (warrior)")
    i = sub.add_parser("install"); i.add_argument("cls")
    i.add_argument("--source-dir", type=Path, default=None)
    i.add_argument("--apply", action="store_true")
    sub.add_parser("assassin-assemble")
    a = ap.parse_args()
    if a.cmd == "briefs":
        cmd_briefs(a.cls)
    elif a.cmd == "assassin-assemble":
        cmd_assassin_assemble()
    elif a.cmd == "build":
        picks = dict(p.split("=", 1) for p in a.pick)
        stretch = None
        if a.stretch:
            stretch = {}
            for spec in a.stretch:
                d, fr = spec.split("=", 1)
                stretch[d] = {int(x) - 1 for x in fr.split(",") if x}
        mirror_override = dict(m.split("=", 1) for m in a.mirror) if a.mirror else None
        cmd_build(a.cls, picks, a.cell, a.source_dir, a.even_body, stretch, mirror_override)
    elif a.cmd == "install":
        cmd_install(a.cls, a.source_dir, a.apply)


if __name__ == "__main__":
    main()
