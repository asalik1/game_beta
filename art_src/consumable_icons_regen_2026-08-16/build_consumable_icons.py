#!/usr/bin/env python3
"""Premium 128px consumable icons from Codex ImageGen green-screen sheets.

Two modes:
  --briefs   write one job dir per sheet (codex_brief.txt + refs/) under jobs/
  (default)  cut every generated master under jobs/*/ into 128px icons and install

Cutting mirrors build_gem_icons.py's BLESSED blob-cut + recenter approach (never
fixed-grid slice a generated sheet - cells drift in x and scale). Differences:

- the chroma screen is pure green (#00FF00); it is removed by BORDER-CONNECTED
  flood ONLY, so the intentional blightwater-green INSIDE laced bottles survives
  (build_gem_icons' global green-neutralize branch would have eaten it - none of
  ITS families used green, but our laced lane does).
- each grid cell = the largest connected foreground blob whose centroid lands in
  that cell; recentred on a 128px canvas with an even margin and LANCZOS-
  downsampled for a crisp premium finish (masters are ~1000-1300px).
"""

from __future__ import annotations

import argparse
from collections import deque
import os
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME_OUT = ROOT / "game" / "assets" / "icons" / "consumables"
MOBILE_OUT = ROOT / "mobile" / "game" / "assets" / "icons" / "consumables"
JOBS = HERE / "jobs"
REFS = HERE / "refs"
QA = HERE / "qa"

TARGET = 128
# Fraction of the 128 canvas the bottle's longest span should fill (rest = margin).
FILL = 0.86
LABEL_POOL = 4

# ---------------------------------------------------------------- subjects ---
# family, shape, lane, grade  (+ optional unique clause for the S peaks / relic)
COLORS = {
    "health": "deep glowing crimson-red",
    "mana": "brilliant luminous azure-blue",
    "might": "molten amber-orange",
    "warding": "cold steel grey-blue",
    "renewal": "radiant golden",
}
VESSEL = {
    ("health", "instant"): "a round, full-bodied blown-glass flask",
    ("health", "tonic"): "a tall, slender glass bottle",
    ("mana", "instant"): "a faceted, angular crystal flask",
    ("mana", "tonic"): "a tall, graceful long-necked glass bottle",
    ("might", "elixir"): "a robust, bulging heavy vial",
    ("warding", "elixir"): "a squat, armoured bottle",
    ("renewal", "draught"): "an ornate rounded ceremonial flask",
}
LANE_TREATMENT = {
    "accord": "pristine Accord-chartered glass, clean and clear",
    "laced": "grimy, chipped, back-alley glass; the liquid is cut with a sickly swirl of blightwater-green rot",
    "grand": "flawless gilded white-gold crystal, immaculate and radiant",
}
GRADE_ACCORD = {
    "F": "GRADE F crudest quality: cloudy cheap glass, the liquid visibly separated into murky layers, a plain jammed cork, no ornament, humble and a little grimy, no glow",
    "E": "GRADE E low quality: simple plain glass, a basic cork, a small blank paper tag on a string, modest, only the faintest glow",
    "D": "GRADE D decent: sturdier glass, a wax-dipped cork, a plain pewter collar, workmanlike, a faint steady glow",
    "C": "GRADE C good: clean chartered glass, a neat stamped wax seal and a polished metal band, respectable, a soft steady inner glow",
    "B": "GRADE B fine: elegant glass, a decorated stopper, an engraved silver collar, a clear bright inner glow",
    "A": "GRADE A exquisite masterwork: flawless crystal, ornate gold filigree, a jeweled stopper, a bright radiant inner glow",
    "S": "GRADE S legendary and unique: perfect flawless crystal, brilliant radiant inner light, an elaborate gold filigree cradle and a jeweled stopper, and a faint magical aura hugging the glass",
}
GRADE_LACED = {
    "F": "GRADE F gutter-cheap: the filthiest chipped vial, a rag-stuffed neck, heavy grime, the rot-green taint obvious",
    "E": "GRADE E cheap: a rough mismatched bottle, a dirty cork, grimy",
    "D": "GRADE D: smuggler's glass under a crude forged wax seal, murky",
    "C": "GRADE C: a cellar brew, cloudy glass, a sloppy dripping wax-blob stopper",
    "B": "GRADE B potent: a darker stronger brew, the blightwater-green heavier and swirling, a tar-sealed cork",
    "A": "GRADE A the fence's deadliest: dark and dangerous, thick green rot-swirl, a corroded iron stopper, a sickly faint glow",
}
GRAND_DESC = (
    "a GRAND synthesis potion - a modest step above legendary and utterly drawback-free: "
    "brilliant clean {color} light glowing pure inside flawless gilded white-gold crystal, "
    "elaborate sunburst gold filigree and a jeweled crown stopper, radiant and immaculate"
)
UNIQUE = {
    "heartsblood": "the crimson liquid glows from within like a living, beating heart",
    "everbloom": "delicate golden vines and a blooming-flower motif on the collar; the red light is soft and alive like dawn roses",
    "stormglass": "the blue mana crackles with tiny white lightning arcs inside; a lightning-bolt-shaped stopper",
    "starwater": "the deep-blue liquid is full of drifting starlight motes and a tiny swirling galaxy; a star-capped stopper",
    "giantsblood": "molten amber elixir churns with fiery inner light behind bronze banded straps; a horned bronze stopper",
    "adamant": "liquid like molten steel behind riveted steel plating and a gilded guard band; a fortress-like stopper",
    "dawnmend": "radiant gold liquid pure as sunrise pours brilliant white-gold light; a rayed sun stopper and a holy glow",
}
CODEX_DESC = (
    "an ancient gilded alchemical formulary BOOK - a thick closed leather tome, NOT a bottle. "
    "Bound in deep oxblood leather with elaborate antique-gold corners, clasps and a central "
    "alembic-and-flask emblem embossed in gold on the cover; faint radiant golden light leaks "
    "from between the closed page edges and tiny alchemical glyphs glint in the gold. A legendary, "
    "sacred, radiant S-tier relic. Rich, arcane, masterfully hand-painted."
)


def _families():
    """Yield (stem, family, shape, lane, grade) for the accord+laced ladders."""
    ladders = [
        ("health", "instant", "accord",
         ["defective_health_potion", "apprentices_health_potion", "journeymans_health_potion",
          "accordmark_health_potion", "masters_health_potion", "masterwork_health_potion", "heartsblood"]),
        ("health", "instant", "laced",
         ["gutter_red", "brawlers_red", "dockside_red", "thinners_red", "bleakvein_red", "hollowbone_red"]),
        ("health", "tonic", "accord",
         ["defective_health_tonic", "apprentices_health_tonic", "journeymans_health_tonic",
          "accordmark_health_tonic", "masters_health_tonic", "masterwork_health_tonic", "everbloom"]),
        ("health", "tonic", "laced",
         ["gutter_rust", "beggars_rust", "smugglers_rust", "cheapstitch_rust", "scarseal_rust", "deadflesh_rust"]),
        ("mana", "instant", "accord",
         ["defective_mana_potion", "apprentices_mana_potion", "journeymans_mana_potion",
          "accordmark_mana_potion", "masters_mana_potion", "masterwork_mana_potion", "stormglass"]),
        ("mana", "instant", "laced",
         ["vein_burn_blue", "backalley_blue", "smugglers_blue", "furnace_blue", "stormsick_blue", "heartscorch_blue"]),
        ("mana", "tonic", "accord",
         ["defective_mana_tonic", "apprentices_mana_tonic", "journeymans_mana_tonic",
          "accordmark_mana_tonic", "masters_mana_tonic", "masterwork_mana_tonic", "starwater"]),
        ("mana", "tonic", "laced",
         ["gutter_haze", "poppyfield_haze", "backalley_haze", "syrup_haze", "lotus_haze", "dreamers_haze"]),
        ("might", "elixir", "accord",
         ["defective_elixir_of_might", "apprentices_elixir_of_might", "journeymans_elixir_of_might",
          "accordmark_elixir_of_might", "masters_elixir_of_might", "masterwork_elixir_of_might", "giantsblood"]),
        ("might", "elixir", "laced",
         ["pit_fury", "dogfight_fury", "cutthroat_fury", "warpit_fury", "blooddebt_fury", "deathwish_fury"]),
        ("warding", "elixir", "accord",
         ["defective_elixir_of_warding", "apprentices_elixir_of_warding", "journeymans_elixir_of_warding",
          "accordmark_elixir_of_warding", "masters_elixir_of_warding", "masterwork_elixir_of_warding", "adamant"]),
        ("warding", "elixir", "laced",
         ["gutterhide", "mules_hide", "ironmongers_hide", "bricklayers_hide", "millstone_hide", "gravestone_hide"]),
        ("renewal", "draught", "accord",
         ["accordmark_draught_of_renewal", "masters_draught_of_renewal", "masterwork_draught_of_renewal", "dawnmend"]),
        ("renewal", "draught", "laced",
         ["graverobbers_mercy", "sawbones_miracle", "deathbed_bargain"]),
    ]
    grades_full = ["F", "E", "D", "C", "B", "A", "S"]
    grades_laced = ["F", "E", "D", "C", "B", "A"]
    grades_ren = ["C", "B", "A", "S"]
    grades_ren_laced = ["C", "B", "A"]
    for family, shape, lane, stems in ladders:
        if family == "renewal":
            gr = grades_ren if lane == "accord" else grades_ren_laced
        else:
            gr = grades_full if lane == "accord" else grades_laced
        for stem, grade in zip(stems, gr):
            yield stem, family, shape, lane, grade


SUBJECTS: dict[str, dict] = {}
for stem, family, shape, lane, grade in _families():
    SUBJECTS[stem] = {"family": family, "shape": shape, "lane": lane, "grade": grade}
# Grand synthesis flasks (share the base family shape, gilded treatment).
for stem, family, shape in [
    ("grand_heartsblood", "health", "instant"), ("grand_everbloom", "health", "tonic"),
    ("grand_stormglass", "mana", "instant"), ("grand_starwater", "mana", "tonic"),
    ("grand_giantsblood", "might", "elixir"), ("grand_adamant", "warding", "elixir"),
    ("grand_dawnmend", "renewal", "draught"),
]:
    SUBJECTS[stem] = {"family": family, "shape": shape, "lane": "grand", "grade": "S"}
SUBJECTS["alkahest_codex"] = {"family": "relic", "shape": "book", "lane": "relic", "grade": "S"}


def describe(stem: str) -> str:
    s = SUBJECTS[stem]
    if s["lane"] == "relic":
        return CODEX_DESC
    color = COLORS[s["family"]]
    vessel = VESSEL[(s["family"], s["shape"])]
    if s["lane"] == "grand":
        body = f"{vessel} - {GRAND_DESC.format(color=color)}"
    else:
        treat = LANE_TREATMENT[s["lane"]]
        grade_txt = (GRADE_ACCORD if s["lane"] == "accord" else GRADE_LACED)[s["grade"]]
        body = f"{vessel} of {color} liquid - {treat}. {grade_txt}"
    if stem in UNIQUE:
        body += f". {UNIQUE[stem]}"
    return body + "."


# ------------------------------------------------------------------ sheets ---
ANCHOR_SHEETS = [
    ("anchor_a", ["heartsblood", "everbloom", "stormglass", "starwater"], 2, 2),
    ("anchor_b", ["giantsblood", "adamant", "dawnmend", "alkahest_codex"], 2, 2),
    ("anchor_c", ["defective_health_potion", "gutter_red", "defective_mana_potion", "pit_fury"], 2, 2),
]
ANCHOR_STEMS = [s for _, stems, _, _ in ANCHOR_SHEETS for s in stems]


def mass_sheets():
    rest = [s for s in SUBJECTS if s not in ANCHOR_STEMS]
    sheets = []
    i = 0
    for start in range(0, len(rest), 6):
        chunk = rest[start:start + 6]
        cols = 3 if len(chunk) >= 3 else len(chunk)
        rows = 2 if len(chunk) > 3 else 1
        sheets.append((f"mass_{i:02d}", chunk, rows, cols))
        i += 1
    return sheets


def all_sheets():
    return ANCHOR_SHEETS + mass_sheets()


def _pos_labels(rows: int, cols: int) -> list[str]:
    rlab = {1: [""], 2: ["Top", "Bottom"], 3: ["Top", "Middle", "Bottom"]}[rows]
    clab = {1: [""], 2: ["left", "right"], 3: ["left", "center", "right"]}[cols]
    out = []
    for r in range(rows):
        for c in range(cols):
            out.append((rlab[r] + "-" + clab[c]).strip("-").replace("-", "-"))
    return out


STYLE = """ORIGINAL premium hand-painted fantasy action-RPG inventory icons - glass POTION BOTTLES.

Match the finish of the two reference images: rich hand-painted rendering, dramatic
high-contrast jewel-colored magical lighting, deep shadows, glossy blown glass with
bright specular highlights, painterly (NOT pixel-art, NOT photographic), readable when
shrunk small. Reference 1 (the contact sheet of round medallions) shows the target PAINT
QUALITY and lighting only. Reference 2 (the bright-green sheet) shows the target OUTPUT
FORMAT: subjects centered on a flat pure-green background with crisp clean edges.

CRITICAL - the subject is a free-standing GLASS BOTTLE / FLASK, upright and centered.
Do NOT draw any circular medallion frame, gold ring, coin, or border around it. No
medallion. Just the bottle itself, standing on nothing.

Universal rules:
- Solid PURE GREEN #00FF00 background, perfectly flat: no gradient, no vignette, no
  shadow cast on the background, no props.
- One subject per grid cell, upright, centered in its own cell, filling most of the
  cell height, with clear green margin on all sides. Subjects must NOT touch each
  other or the cell dividers.
- Glossy glass with visible glowing liquid inside, a cork or stopper, strong rim-light
  and specular highlights.
- Any glow/mist/sparkle stays tight around the bottle, contained within crisp edges -
  never bleeding to the cell border.
- NO text, letters, numbers, logos, trademarks, labels-with-writing, or watermark
  anywhere in the image.

Save the finished picture as a PNG file in this folder."""


def write_briefs(which: str) -> None:
    if which == "anchor":
        sheets = ANCHOR_SHEETS
    elif which == "mass":
        sheets = mass_sheets()
    else:
        sheets = all_sheets()
    JOBS.mkdir(parents=True, exist_ok=True)
    for sid, stems, rows, cols in sheets:
        d = JOBS / sid
        (d / "refs").mkdir(parents=True, exist_ok=True)
        for r in REFS.glob("*.png"):
            shutil.copy2(r, d / "refs" / r.name)
        labels = _pos_labels(rows, cols)
        lines = [STYLE, "", f"Layout: a {rows}x{cols} grid ({len(stems)} subject(s)), reading order:"]
        for lab, stem in zip(labels, stems):
            lines.append(f"\n[{lab}] {describe(stem)}")
        (d / "codex_brief.txt").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {len(sheets)} job dir(s) under {JOBS}")
    print("stages:", ",".join(str(JOBS / sid) for sid, *_ in sheets))


# ------------------------------------------------------------------- cut ---
def _flood_border_green(green: np.ndarray) -> np.ndarray:
    """Coarse-pool BFS: return the part of the green mask connected to the border."""
    h, w = green.shape
    ch = -(-h // LABEL_POOL)
    cw = -(-w // LABEL_POOL)
    pad = np.zeros((ch * LABEL_POOL, cw * LABEL_POOL), dtype=bool)
    pad[:h, :w] = green
    coarse = pad.reshape(ch, LABEL_POOL, cw, LABEL_POOL).any(axis=(1, 3))
    seen = np.zeros_like(coarse)
    q: deque[tuple[int, int]] = deque()
    for x in range(cw):
        for y in (0, ch - 1):
            if coarse[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(ch):
        for x in (0, cw - 1):
            if coarse[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < ch and 0 <= nx < cw and coarse[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    fine = np.repeat(np.repeat(seen, LABEL_POOL, axis=0), LABEL_POOL, axis=1)[:h, :w]
    return fine & green


def key_green(master: Image.Image) -> np.ndarray:
    """Remove the pure-green screen (border-connected only) + despill the rim.

    Interior blightwater-green (murky, mixed with red/blue) is NOT strict-green and
    is never border-connected, so it survives."""
    px = np.asarray(master.convert("RGBA")).astype(np.int16).copy()
    r, g, b = px[..., 0], px[..., 1], px[..., 2]
    # Strict chroma-screen test: bright, green-dominant, low red+blue.
    screen = (g > 150) & (r < 150) & (b < 150) & (g - np.maximum(r, b) > 55)
    bg = _flood_border_green(screen)
    out = px.copy()
    out[..., 3][bg] = 0
    # Despill: for surviving pixels near the removed screen, clamp green spill.
    alpha = out[..., 3]
    trans = alpha == 0
    ring = trans.copy()
    for _ in range(3):
        p = np.pad(ring, 1, constant_values=False)
        ring = np.logical_or.reduce([p[dy:dy + master.height, dx:dx + master.width]
                                     for dy in range(3) for dx in range(3)])
    fringe = ring & ~trans & (out[..., 1] - np.maximum(out[..., 0], out[..., 2]) > 24)
    out[..., 1][fringe] = np.maximum(out[..., 0], out[..., 2])[fringe]
    return out.astype(np.uint8)


def label_fg(mask: np.ndarray) -> tuple[np.ndarray, int]:
    h, w = mask.shape
    ch = -(-h // LABEL_POOL)
    cw = -(-w // LABEL_POOL)
    pad = np.zeros((ch * LABEL_POOL, cw * LABEL_POOL), dtype=bool)
    pad[:h, :w] = mask
    coarse = pad.reshape(ch, LABEL_POOL, cw, LABEL_POOL).any(axis=(1, 3))
    labels = np.zeros((ch, cw), dtype=np.int32)
    count = 0
    for y in range(ch):
        for x in range(cw):
            if not coarse[y, x] or labels[y, x]:
                continue
            count += 1
            labels[y, x] = count
            q: deque[tuple[int, int]] = deque([(y, x)])
            while q:
                cy, cx = q.popleft()
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < ch and 0 <= nx < cw and coarse[ny, nx] and not labels[ny, nx]:
                            labels[ny, nx] = count
                            q.append((ny, nx))
    fine = np.repeat(np.repeat(labels, LABEL_POOL, axis=0), LABEL_POOL, axis=1)[:h, :w]
    return np.where(mask, fine, 0), count


def cut_cells(keyed: np.ndarray, n: int) -> list[Image.Image]:
    """Orientation-agnostic: take the n largest blobs and order them in reading
    order (rows top->bottom by y-centroid clustering, left->right within a row).

    Codex reads "2x3 grid" as EITHER 3-wide x 2-tall OR 2-wide x 3-tall, but it
    always FILLS the described cells row-major (left-to-right, top-to-bottom), so
    reading-order recovery matches the brief regardless of the grid's shape."""
    labels, count = label_fg(keyed[..., 3] >= 128)
    blobs = []
    for lab in range(1, count + 1):
        ys, xs = np.nonzero(labels == lab)
        if xs.size < 600:  # speck
            continue
        blobs.append({"lab": lab, "x0": xs.min(), "x1": xs.max() + 1,
                      "y0": ys.min(), "y1": ys.max() + 1, "area": int(xs.size),
                      "cx": (xs.min() + xs.max()) / 2, "cy": (ys.min() + ys.max()) / 2,
                      "h": ys.max() - ys.min()})
    blobs = sorted(blobs, key=lambda b: b["area"], reverse=True)[:n]
    if len(blobs) < n:
        raise RuntimeError(f"found {len(blobs)} blob(s), expected {n} (bottles may have merged)")
    med_h = float(np.median([b["h"] for b in blobs]))
    row_tol = 0.45 * med_h
    rows_grp: list[list[dict]] = []
    for bl in sorted(blobs, key=lambda b: b["cy"]):
        if rows_grp and bl["cy"] - rows_grp[-1][-1]["cy"] <= row_tol:
            rows_grp[-1].append(bl)
        else:
            rows_grp.append([bl])
    ordered: list[dict] = []
    for row in rows_grp:
        ordered.extend(sorted(row, key=lambda b: b["cx"]))
    if len(ordered) != n:
        raise RuntimeError(f"ordered {len(ordered)} blobs, expected {n}")
    return [_recenter(keyed, labels, bl) for bl in ordered]


def _recenter(keyed: np.ndarray, labels: np.ndarray, bl: dict) -> Image.Image:
    h, w = labels.shape
    only = keyed.copy()
    only[..., 3] = np.where(labels == bl["lab"], only[..., 3], 0)
    span = max(bl["x1"] - bl["x0"], bl["y1"] - bl["y0"])
    window = int(np.ceil(span / FILL))
    left = int(round(bl["cx"] - window / 2))
    top = int(round(bl["cy"] - window / 2))
    canvas = np.zeros((window, window, 4), dtype=np.uint8)
    sx0, sy0 = max(left, 0), max(top, 0)
    sx1, sy1 = min(left + window, w), min(top + window, h)
    canvas[sy0 - top:sy1 - top, sx0 - left:sx1 - left] = only[sy0:sy1, sx0:sx1]
    img = Image.fromarray(canvas, "RGBA").resize((TARGET, TARGET), Image.Resampling.LANCZOS)
    return img


def _master_png(job: Path) -> Path | None:
    cands = [p for p in job.glob("*.png")]
    if not cands:
        return None
    return max(cands, key=lambda p: p.stat().st_size)


def save_atomic(image: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".tmp")
    image.save(tmp, format="PNG", optimize=True)
    os.replace(tmp, dest)


def cut_and_install(only_sheets: list[str] | None, mobile: bool) -> None:
    sheets = {sid: (stems, rows, cols) for sid, stems, rows, cols in all_sheets()}
    done = []
    for sid, (stems, rows, cols) in sheets.items():
        if only_sheets and sid not in only_sheets:
            continue
        job = JOBS / sid
        master_path = _master_png(job)
        if master_path is None:
            print(f"  SKIP {sid}: no master png yet")
            continue
        master = Image.open(master_path).convert("RGBA")
        keyed = key_green(master)
        try:
            icons = cut_cells(keyed, len(stems))
        except RuntimeError as e:
            print(f"  FAIL {sid}: {e}")
            continue
        for stem, icon in zip(stems, icons):
            save_atomic(icon, GAME_OUT / f"{stem}.png")
            if mobile:
                save_atomic(icon, MOBILE_OUT / f"{stem}.png")
            done.append(stem)
        # per-sheet alpha proof
        save_atomic(Image.fromarray(keyed, "RGBA"), QA / f"{sid}_alpha.png")
        print(f"  cut {sid}: {', '.join(stems)}")
    print(f"installed {len(done)} icons -> {GAME_OUT}" + (" (+mobile)" if mobile else ""))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--briefs", choices=["anchor", "mass", "all"])
    ap.add_argument("--sheets", help="comma list of sheet ids to cut (default: all present)")
    ap.add_argument("--no-mobile", action="store_true")
    args = ap.parse_args()
    if args.briefs:
        write_briefs(args.briefs)
        return 0
    only = args.sheets.split(",") if args.sheets else None
    cut_and_install(only, mobile=not args.no_mobile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
