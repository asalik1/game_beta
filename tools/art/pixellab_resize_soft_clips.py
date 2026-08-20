"""Upscale the OLD-generation hero action strips with PixelLab Resize (owner
authorized 2026-08-19: "yes lets fix that", all 94 strips).

The audit (POLISH_TASKS P0.12): assassin run/dash/ult, warlock run/cast/ult and
archer run/dash/cast/ult (each flat + 8 directions) plus the four flat deaths
carry ~104-121 px bodies while every other clip carries 180+ (mage 202) — those
older strips were installed straight from the PixelLab exports and never went
through the /v2/resize redraw that gave attack/walk/idle their crisp bodies.

This driver replays `pixellab_resize_assassin_attack.py`'s proven contract on
the INSTALLED runtime strips (the owner-accepted frames, order and all):
  per frame: tight crop -> /v2/resize (identity description from the character
  zip's creation prompt + preserve-pose boilerplate, palette LOCKED to the
  class's crisp runtime strips, view low top-down, fixed seed; API edges cap at
  200 px -> NEAREST restore to the exact target geometry) -> paste back at the
  original coordinates x scale in a fresh runtime cell (baseline = cell - 22).

Idempotent: frames with a saved normalized PNG are skipped, so a killed run
resumes. Staging under art_src/Custom/HeroClipResize_2026-08-19/; --install
backs up the live strips there and writes game/ + mobile/.

Usage:
  python tools/art/pixellab_resize_soft_clips.py run      [cls ...]  # resize (spends generations)
  python tools/art/pixellab_resize_soft_clips.py install  [cls ...]  # assemble + install
  python tools/art/pixellab_resize_soft_clips.py status              # per-strip progress
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from pixellab_resize_assassin_attack import (  # noqa: E402
    _decode_image, _palette_image, _png_b64, _post,
)

REPO = Path(__file__).resolve().parents[2]
SPR = REPO / "game/assets/sprites"
MOBILE = REPO / "mobile/game/assets/sprites"
STAGE = REPO / "art_src/Custom/HeroClipResize_2026-08-19"
SEED = 20260819
RUNTIME_CELL_DEFAULT = 277
FEET_MARGIN = 22
WORKERS = 4          # PixelLab account job slots
TIMEOUT = 300
ATTEMPTS = 4

DIR_WORD = {"e": "east", "ne": "north-east", "n": "north", "nw": "north-west",
            "w": "west", "sw": "south-west", "s": "south", "se": "south-east"}
DIRS8 = ["e", "ne", "n", "nw", "w", "sw", "s", "se"]

# target painted body height = the class's crisp-generation body (+3 request
# headroom, the assassin script's proven margin).
BODY = {"assassin": 180, "warlock": 180, "archer": 180, "mage": 202}

JOBS = {
    "assassin": {"run": DIRS8 + [""], "dash": DIRS8 + [""], "ult": DIRS8 + [""], "death": [""]},
    "warlock": {"run": DIRS8 + [""], "cast": DIRS8 + [""], "ult": DIRS8 + [""], "death": [""]},
    "archer": {"run": DIRS8 + [""], "dash": DIRS8 + [""], "cast": DIRS8 + [""],
               "ult": DIRS8 + [""], "death": [""]},
    "mage": {"death": [""]},
}

# Identity text: the character zip's ORIGINAL creation prompt (read-metadata
# rule) + the assassin script's proven preserve-pose boilerplate.
PROMPT = {
    "assassin": "grim cutthroat assassin, dark grey tattered ragged hooded robes and cloak, "
        "face entirely lost in pitch-black shadow beneath the deep hood with only two small "
        "glowing blue eyes showing, black gloved hands with no bare skin visible, twin thin "
        "straight daggers held low in reverse grip, lean and gaunt, muted dark palette, "
        "somber dark fantasy, no smoke",
    "warlock": "a menacing gaunt hooded warlock, FULL tall standing figure with visible legs "
        "and boots, near-black tattered robes with dark tarnished gold trim and heavy iron "
        "chains, a detailed cracked bone skull familiar wreathed in dark violet flame floating "
        "beside his shoulder (a real sinister skull, NOT cartoonish), an open glowing pact-tome "
        "in one hand, hollow shadowed eye-sockets, imposing and vicious, somber dark fantasy",
    "archer": "weathered female ranger huntress, dark brown fitted leather armor with buckled "
        "straps across chest, heavy grey fur mantle draped over both shoulders, dark green "
        "tattered cloak hanging from shoulders to calves, face visible with sharp narrow "
        "features and short dark brown hair swept back behind ears, dark leather bracers on "
        "forearms, large wooden longbow held low in left hand, leather quiver packed with "
        "arrows strapped diagonally across back, small bone skull pendant at neck, lean and "
        "tall, muted dark palette, somber dark fantasy, no hood",
    "mage": "mature elegant woman mage, lean and tall, a graceful refined feminine face with "
        "calm serene features, very long white hair parted and flowing loose past her waist, a "
        "long floor-length white and pale grey robe trailing to the ground with a ragged "
        "tattered decayed hem, faded gold trim and a grey sash, brown leather belt with hip "
        "pouch, holding a tall dark wooden staff topped with a pale blue crystal, muted "
        "palette, somber dark fantasy",
}
BOILER = (" Exact same character from the reference, intelligently redrawn at higher native "
          "pixel resolution. Preserve this exact pose, anatomy, silhouette, hand positions, "
          "foot placement, cloak and robe shape, weapon and prop positions, palette, and "
          "facing. Do not redesign, re-pose, recolor, rotate, add equipment, or add effects. "
          "Transparent background.")

_palettes: dict[str, dict] = {}


def class_palette(cls: str) -> dict:
    if cls not in _palettes:
        sources = []
        for ref in ["anim", "attack", "walk"]:
            p = SPR / f"{cls}_{ref}.png"
            if p.exists():
                sources.append(Image.open(p).convert("RGBA"))
        pal = _palette_image(sources)
        (STAGE / cls).mkdir(parents=True, exist_ok=True)
        pal.save(STAGE / cls / "canonical_palette.png")
        _palettes[cls] = {"type": "base64", "base64": _png_b64(pal), "format": "png"}
    return _palettes[cls]


def strip_name(cls: str, clip: str, d: str) -> str:
    return f"{cls}_{clip}" + (f"_{d}" if d else "") + ".png"


def split_frames(png: Path) -> list[Image.Image]:
    im = Image.open(png).convert("RGBA")
    cell = im.height
    n = im.width // cell
    return [im.crop((i * cell, 0, (i + 1) * cell, cell)) for i in range(n)]


def job_dir(cls: str, clip: str, d: str) -> Path:
    return STAGE / cls / (clip + (f"_{d}" if d else "_flat"))


def resize_strip(cls: str, clip: str, d: str, token: str) -> int:
    """Resize every frame of one strip; returns API calls actually made."""
    src = SPR / strip_name(cls, clip, d)
    frames = split_frames(src)
    cell = frames[0].width
    boxes = [f.getbbox() for f in frames]
    if any(b is None for b in boxes):
        raise ValueError(f"{src.name}: empty frame")
    baseline = max(b[3] for b in boxes)
    ref_h = boxes[0][3] - boxes[0][1]
    request_body = BODY[cls] + 3
    scale = request_body / float(ref_h)
    out = job_dir(cls, clip, d)
    out.mkdir(parents=True, exist_ok=True)
    desc = PROMPT[cls] + BOILER
    direction = DIR_WORD.get(d, "west")   # flat hero strips face LEFT
    palette = class_palette(cls)
    manifest = {"source": str(src), "cell": cell, "baseline": baseline,
                "scale": scale, "frames": {}}
    calls = 0

    def one(i: int) -> str:
        f = frames[i]
        b = boxes[i]
        norm_p = out / f"f{i:02d}_normalized.png"
        if norm_p.exists():
            return f"f{i} cached"
        crop_box = (max(0, b[0] - 2), max(0, b[1] - 2),
                    min(cell, b[2] + 2), min(cell, b[3] + 2))
        crop = f.crop(crop_box)
        target = (round(crop.width * scale), round(crop.height * scale))
        api = (min(target[0], 200), min(target[1], 200))
        body = {
            "description": desc,
            "reference_image": {"type": "base64", "base64": _png_b64(crop), "format": "png"},
            "reference_image_size": {"width": crop.width, "height": crop.height},
            "target_size": {"width": api[0], "height": api[1]},
            "view": "low top-down",
            "direction": direction,
            "no_background": True,
            "color_image": palette,
            "seed": SEED,
        }
        resized = _decode_image(_post(token, body, TIMEOUT, ATTEMPTS))
        if resized.size != api:
            raise ValueError(f"{src.name} f{i}: got {resized.size}, want {api}")
        if api != target:
            resized = resized.resize(target, Image.Resampling.NEAREST)
        # runtime cell: default 277, grown when the scaled art cannot fit
        need = max(target[0], target[1] + FEET_MARGIN)
        rc = max(RUNTIME_CELL_DEFAULT, need + 4)
        runtime = Image.new("RGBA", (rc, rc), (0, 0, 0, 0))
        paste_x = rc // 2 + round((crop_box[0] - cell / 2.0) * scale)
        paste_y = (rc - FEET_MARGIN) + round((crop_box[1] - baseline) * scale)
        runtime.alpha_composite(resized, (max(0, paste_x), max(0, paste_y)))
        runtime.save(norm_p)
        manifest["frames"][str(i)] = {"box": list(b), "target": list(target), "rc": rc}
        return f"f{i} ok {crop.size}->{target}"

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futs = {pool.submit(one, i): i for i in range(len(frames))}
        for fut in as_completed(futs):
            msg = fut.result()
            if "ok" in msg:
                calls += 1
            print(f"  {src.name}: {msg}", flush=True)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")
    return calls


def assemble_and_install(cls: str, clip: str, d: str) -> str:
    out = job_dir(cls, clip, d)
    norms = sorted(out.glob("f*_normalized.png"))
    src = SPR / strip_name(cls, clip, d)
    n_src = Image.open(src).width // Image.open(src).height
    if len(norms) != n_src:
        return f"SKIP {src.name}: {len(norms)}/{n_src} frames resized"
    imgs = [Image.open(p).convert("RGBA") for p in norms]
    # one shared cell: the largest any frame needed (they were built bottom-
    # anchored at cell-22, so re-anchor smaller cells into the big one)
    rc = max(im.width for im in imgs)
    strip = Image.new("RGBA", (rc * len(imgs), rc), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        dx = (rc - im.width) // 2
        dy = rc - im.height          # keeps every feet line at rc - 22
        strip.alpha_composite(im, (i * rc + dx, dy))
    rel = strip_name(cls, clip, d)
    backup = STAGE / "runtime_pre_install" / rel
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(SPR / rel, backup)
    strip.save(SPR / rel)
    if (MOBILE / rel).exists() or True:
        strip.save(MOBILE / rel)
    return f"INSTALLED {rel}: {len(imgs)}x{rc}"


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "status"
    classes = sys.argv[2:] or list(JOBS.keys())
    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN") or ""
    total_calls = 0
    for cls in classes:
        for clip, dirs in JOBS[cls].items():
            for d in dirs:
                src = SPR / strip_name(cls, clip, d)
                if not src.exists():
                    print(f"MISSING {src.name}")
                    continue
                n = Image.open(src).width // Image.open(src).height
                done = len(list(job_dir(cls, clip, d).glob("f*_normalized.png")))
                if mode == "status":
                    print(f"{strip_name(cls, clip, d):<28} {done}/{n}")
                elif mode == "run":
                    if done == n:
                        print(f"{strip_name(cls, clip, d):<28} complete")
                        continue
                    print(f"RESIZE {strip_name(cls, clip, d)} ({done}/{n} done)", flush=True)
                    total_calls += resize_strip(cls, clip, d, token)
                elif mode == "install":
                    print(assemble_and_install(cls, clip, d))
    if mode == "run":
        print(f"API calls made this run: {total_calls}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
