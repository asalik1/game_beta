"""Build a Crownless elite-skin animation family from Codex ImageGen masters.

Generalizes build_emberbound_warrior.py to every era-3 class concept wired as an
elite skin (owner ruling 2026-08-21). One config per skin below; run:

    python tools/art/build_skin_family.py <skin_id>        # e.g. erased_name

Masters live under art_src/skins/<class>_<skin_id>/ named <class>_<clip>_v1.png
(idle sheet, walk_<dir> per-direction rows, other clips 5-row S/SE/E/NE/N sheets,
death a flat S row). Each skin installs at a 235px body (the premium tier) and
mirrors the east half into W/SW/NW (the shipped Arbiter precedent). Death is a
flat single-facing strip like the base sprites.

GAMMA (default 1.0): CROWNLESS_SKIN_GAMMA=0.85 pre-brightens for Forward+ if the
in-game shot reads dark. Judge in-game before baking it in (art-ingame-tonemap).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "game" / "assets" / "sprites" / "skins" / "elite"
TARGET_STANDING_BODY = 235.0
STAGING_CELL = 600
STAGING_BASELINE = 540
GAMMA = float(os.environ.get("CROWNLESS_SKIN_GAMMA", "1.0"))
DIRS = ("s", "se", "e", "ne", "n")

# clips: runtime_clip -> (master_stem, cols). Rows are always 5 (S/SE/E/NE/N).
# walk is per-direction (walk_<dir>, `walk` cols). death is flat (`death` cols).
SKIN_CONFIGS = {
    # run sheets removed 2026-08-21 (owner: no run clip anywhere -- walk covers
    # all movement). Masters may still exist under art_src but are never built or
    # installed.
    "emberbound_heir": {"cls": "warrior", "name": "Emberbound Heir",
        "sheets": {"anim": ("idle", 4), "attack": ("attack", 7),
                   "attack2": ("attack2", 7), "attackb": ("attackb", 7), "dash": ("dash", 7),
                   "ult": ("ult", 7), "ultidle": ("ultidle", 4)}, "walk": 6, "death": 9},
    "erased_name": {"cls": "assassin", "name": "the Erased Name",
        "sheets": {"anim": ("idle", 4), "attack": ("attack", 8),
                   "attack2": ("attack2", 8), "attackb": ("attackb", 8), "attackc": ("attackc", 8),
                   "dash": ("dash", 7), "ult": ("ult", 9), "ultidle": ("ultidle", 7)}, "walk": 6, "death": 9},
    "ledgerbound": {"cls": "warlock", "name": "Ledgerbound Debtor",
        "sheets": {"anim": ("idle", 4), "attack": ("attack", 9),
                   "attack2": ("attack2", 9), "cast": ("cast", 9), "ult": ("ult", 9)},
        "walk": 7, "death": 9},
    "severed_thread": {"cls": "archer", "name": "Severed-Thread Ranger",
        "sheets": {"anim": ("idle", 4), "attack": ("attack", 9),
                   "attack2": ("attack2", 9), "cast": ("cast", 9), "dash": ("dash", 6),
                   "ult": ("ult", 9), "ultidle": ("ultidle", 5)}, "walk": 6, "death": 9},
    "blighted_healer": {"cls": "mage", "name": "the Blighted Healer",
        "sheets": {"anim": ("idle", 5), "attack": ("attack", 7),
                   "cast": ("cast", 7), "dash": ("dash", 7)}, "walk": 8, "death": 9},
}


def _valley_separators(mask, count, axis):
    extent = mask.shape[axis]
    if count == 1:
        return [0, extent]
    projection = mask.sum(axis=1 - axis).astype(np.float64)
    coords = np.arange(extent, dtype=np.float64)
    total = projection.sum()
    if total <= 0:
        return [round(index * extent / count) for index in range(count + 1)]
    cumulative = np.cumsum(projection)
    centers = np.array([np.searchsorted(cumulative, total * (index + 0.5) / count) for index in range(count)], dtype=np.float64)
    for _ in range(24):
        assignment = np.argmin(np.abs(coords[:, None] - centers[None, :]), axis=1)
        updated = centers.copy()
        for index in range(count):
            selected = assignment == index
            weight = projection[selected].sum()
            if weight > 0:
                updated[index] = (coords[selected] * projection[selected]).sum() / weight
        if np.max(np.abs(updated - centers)) < 0.05:
            centers = updated
            break
        centers = updated
    separators = [0]
    for index in range(1, count):
        target = round((centers[index - 1] + centers[index]) / 2.0)
        lo = max(separators[-1] + 1, round(centers[index - 1]))
        hi = min(extent - 1, round(centers[index]))
        empty = projection[lo:hi + 1] == 0
        runs, start = [], None
        for offset, is_empty in enumerate(empty):
            if is_empty and start is None:
                start = offset
            elif not is_empty and start is not None:
                runs.append((lo + start, lo + offset - 1)); start = None
        if start is not None:
            runs.append((lo + start, hi))
        if runs:
            a, b = max(runs, key=lambda run: (-abs(((run[0] + run[1]) / 2.0) - target), run[1] - run[0] + 1))
            split = round((a + b) / 2.0)
        else:
            local = projection[lo:hi + 1]
            candidates = np.flatnonzero(local == local.min()) + lo
            split = int(candidates[np.argmin(np.abs(candidates - target))])
        separators.append(split)
    separators.append(extent)
    return separators


def _remove_green(image):
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = arr[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    keyed = (green > 72.0) & (green > red * 1.14 + 12.0) & (green > blue * 1.14 + 12.0)
    arr[..., 3] = np.where(keyed, 0, 255).astype(np.uint8)
    visible = ~keyed
    neutral_green = np.maximum(arr[..., 0], arr[..., 2]).astype(np.uint16) + 10
    arr[..., 1] = np.where(visible, np.minimum(arr[..., 1].astype(np.uint16), neutral_green), 0).astype(np.uint8)
    arr[keyed, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _grid(path, rows, cols):
    image = _remove_green(Image.open(path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0
    y_edges = _valley_separators(alpha, rows, axis=0)
    x_edges = _valley_separators(alpha, cols, axis=1)
    out = []
    for row in range(rows):
        y0, y1 = y_edges[row], y_edges[row + 1]
        out.append([image.crop((x_edges[c], y0, x_edges[c + 1], y1)) for c in range(cols)])
    return out


def _hard_alpha(image):
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = arr[..., 3] > 24
    arr[..., 3] = np.where(opaque, 255, 0).astype(np.uint8)
    arr[~opaque, :3] = 0
    return Image.fromarray(arr, "RGBA")


def _apply_gamma(image):
    if GAMMA == 1.0:
        return image
    arr = np.asarray(image.convert("RGBA")).astype(np.float32)
    a = arr[..., 3:4] / 255.0
    arr[..., :3] = np.clip((np.clip(arr[..., :3] / 255.0, 0, 1) ** GAMMA) * 255.0, 0, 255) * (a > 0)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def _normalize_clip(directions):
    scales = {}
    for suffix in DIRS:
        bbox = directions[suffix][0].getbbox()
        if bbox is None:
            raise ValueError(f"empty first frame in {suffix}")
        scales[suffix] = TARGET_STANDING_BODY / float(bbox[3] - bbox[1])
    normalized = {}
    for suffix, frames in directions.items():
        scale = scales[suffix]
        out_frames = []
        for index, frame in enumerate(frames):
            bbox = frame.getbbox()
            if bbox is None:
                raise ValueError(f"empty frame {suffix}:{index}")
            figure = frame.crop(bbox)
            width = max(1, round(figure.width * scale))
            height = max(1, round(figure.height * scale))
            figure = _hard_alpha(figure.resize((width, height), Image.Resampling.LANCZOS))
            if width > STAGING_CELL - 8 or height > STAGING_BASELINE - 4:
                raise ValueError(f"frame {suffix}:{index} does not fit staging cell: {width}x{height}")
            canvas = Image.new("RGBA", (STAGING_CELL, STAGING_CELL), (0, 0, 0, 0))
            canvas.alpha_composite(figure, ((STAGING_CELL - width) // 2, STAGING_BASELINE - height))
            out_frames.append(_apply_gamma(canvas))
        normalized[suffix] = out_frames
    return normalized


def build(skin_id):
    cfg = SKIN_CONFIGS[skin_id]
    cls = cfg["cls"]
    base = f"{cls}_{skin_id}"
    art_src = ROOT / "art_src" / "skins" / base
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import install_dirset

    raw = {}
    for rt_clip, (stem, cols) in cfg["sheets"].items():
        raw[f"{base}_{rt_clip}"] = {DIRS[i]: rows for i, rows in enumerate(_grid(art_src / f"{cls}_{stem}_v1.png", 5, cols))}
    raw[f"{base}_walk"] = {d: _grid(art_src / f"{cls}_walk_{d}_v1.png", 1, cfg["walk"])[0] for d in DIRS}

    clips = {name: _normalize_clip(dirs) for name, dirs in raw.items()}
    for name, dirs in clips.items():
        print(f"  {name}: {len(dirs['s'])}f x 5 dirs")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips(clips, str(OUT_DIR), margin=3, symmetric=True)

    # flat death (base-sprite convention), same shared cell
    frames = _grid(art_src / f"{cls}_death_v1.png", 1, cfg["death"])[0]
    dscale = TARGET_STANDING_BODY / float(frames[0].getbbox()[3] - frames[0].getbbox()[1])
    cells = []
    for fr in frames:
        bb = fr.getbbox()
        fig = _apply_gamma(_hard_alpha(fr.crop(bb).resize(
            (max(1, round((bb[2] - bb[0]) * dscale)), max(1, round((bb[3] - bb[1]) * dscale))),
            Image.Resampling.LANCZOS)))
        c = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        c.alpha_composite(fig, ((cell - fig.width) // 2, cell - fig.height - 3))
        cells.append(c)
    strip = Image.new("RGBA", (cell * len(cells), cell), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        strip.alpha_composite(c, (i * cell, 0))
    strip.save(OUT_DIR / f"{base}_death.png")

    Image.open(OUT_DIR / f"{base}_anim_s.png").convert("RGBA").crop((0, 0, cell, cell)).save(OUT_DIR / f"{base}.png")
    print(f"installed {base}: {len(clips)} clips + flat death, 8 dirs, cell={cell}px, "
          f"body={int(TARGET_STANDING_BODY)}px, gamma={GAMMA}")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in SKIN_CONFIGS:
        print("usage: build_skin_family.py <skin_id>  where skin_id in:", ", ".join(SKIN_CONFIGS))
        sys.exit(2)
    build(sys.argv[1])
