"""Band-normalize every hero clip into the owner's 2.2-2.35x source-per-screen
band (owner-authorized PixelLab, 2026-08-20; ratio = painted body px / on-screen
body px, screen = 52 * class_height * CHAR_RENDER_SCALE).

Discovery: every `<cls>_<clip>[_<dir>].png` whose frame-0 body ratio < 2.2.
Targets sit mid-band (2.28x): warrior 218, paladin 212, assassin 206,
warlock 202, archer 191. The mage (2.33x) is already in band.

Per frame, the lessons from HeroClipResize_2026-08-19 are BUILT IN:
  - FX-DOMINANT frames (saturated px > 2000) never touch the API — the model
    breaks on effect-heavy frames and they read fine plainly upscaled. Saves
    calls too.
  - Other frames: /v2/resize redraw (identity prompt + runtime palette lock,
    reference capped at 200 px) -> then the deterministic repair: restore any
    original alpha the redraw dropped (hue-agnostic — black smoke, pale
    rings), and full-replace the frame when >35 % of the original is missing
    or the silhouette disagrees (IoU < 0.55).
Assembly: shared max cell per strip, feet at cell-22; originals backed up under
art_src/Custom/HeroBand_2026-08-20/runtime_pre_install; installs game+mobile.
Resumable: fNN_final.png caches finished frames; re-run to continue.

Usage:
  python tools/art/pixellab_resize_band.py status
  python tools/art/pixellab_resize_band.py run   [cls ...]
"""
from __future__ import annotations

import os
import shutil
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
from pixellab_resize_assassin_attack import (  # noqa: E402
    _decode_image, _palette_image, _png_b64, _post,
)
from pixellab_resize_soft_clips import PROMPT, BOILER, DIR_WORD  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
SPR = REPO / "game/assets/sprites"
MOBILE = REPO / "mobile/game/assets/sprites"
STAGE = REPO / "art_src/Custom/HeroBand_2026-08-20"
SEED = 20260820
FEET_MARGIN = 22
# Concurrency, MEASURED (2026-08-20): /v2/resize sustains ~4 in flight clean
# (the whole 94-strip run: zero 429s). 24 in flight thrashed it into constant
# 429s (2.3 frames/min) and appears to trip a lingering account cooldown —
# even 8 stayed rate-limited right after. The tier's "20 workers" is the
# generation queue, NOT this endpoint. Stay at 4, strips serial.
WORKERS = 4
STRIP_WORKERS = 1
TIMEOUT = 300
ATTEMPTS = 4
CRS = 1.7
HEIGHT = {"warrior": 1.08, "paladin": 1.05, "assassin": 1.02, "warlock": 1.0, "archer": 0.95}
TARGET_BODY = {"warrior": 218, "paladin": 212, "assassin": 206, "warlock": 202, "archer": 191}
CLIPS = ["anim", "walk", "run", "attack", "attackb", "attack2", "cast", "dash",
         "ult", "ultidle", "death"]
DIRS = ["", "e", "ne", "n", "nw", "w", "sw", "s", "se"]
# Warrior/paladin identity = the ORIGINAL creation prompts from their character
# zips (read-metadata rule; Warrior 2f5dbe25, Paladin 54e9c3a8).
PROMPT = dict(PROMPT)
PROMPT["warrior"] = ("battle-worn ember war-knight in heavy dark blackened plate armor, "
    "veins of glowing molten ember-orange running through every crack and seam of the "
    "armor, a heavy greatsword with a molten glowing edge, weathered helm with a faint "
    "ember glow in the visor slit, grim and imposing, ash drifting, somber dark fantasy")
PROMPT["paladin"] = ("grim hooded hammer-paladin in dark tarnished plate armor, heavy gold "
    "binding-chains coiling from the waist, a glowing chain-flail warhammer, ash-grey torn "
    "cloak, restrained pale-gold light only at the chain-links, stern and weary, no bright "
    "colors, somber dark fantasy")

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


def split_frames(png: Path) -> list[Image.Image]:
    im = Image.open(png).convert("RGBA")
    cell = im.height
    return [im.crop((i * cell, 0, (i + 1) * cell, cell)) for i in range(im.width // cell)]


def f0_ratio(png: Path, cls: str) -> float:
    im = Image.open(png).convert("RGBA")
    c = im.height
    a = np.array(im.crop((0, 0, c, c)))[:, :, 3]
    ys = np.where((a > 40).any(axis=1))[0]
    bh = int(ys.max() - ys.min() + 1) if len(ys) else 0
    return bh / (52.0 * HEIGHT[cls] * CRS)


def sat_count(arr) -> int:
    vis = arr[:, :, 3] > 40
    mx = arr[:, :, :3].max(axis=2).astype(int)
    mn = arr[:, :, :3].min(axis=2).astype(int)
    return int(((mx - mn > 60) & (mx > 90) & vis).sum())


def discover(classes) -> list[tuple[str, str]]:
    jobs = []
    for cls in classes:
        for clip in CLIPS:
            for d in DIRS:
                rel = f"{cls}_{clip}" + (f"_{d}" if d else "") + ".png"
                p = SPR / rel
                if p.exists() and f0_ratio(p, cls) < 2.2:
                    jobs.append((cls, rel, d))
    return jobs


def process_strip(cls: str, rel: str, d: str, token: str) -> str:
    src = SPR / rel
    frames = split_frames(src)
    cell = frames[0].width
    boxes = [f.getbbox() for f in frames]
    if any(b is None for b in boxes):
        return f"SKIP {rel}: empty frame"
    baseline = max(b[3] for b in boxes)
    ref_h = boxes[0][3] - boxes[0][1]
    scale = (TARGET_BODY[cls] + 3) / float(ref_h)
    out = STAGE / cls / Path(rel).stem
    out.mkdir(parents=True, exist_ok=True)
    desc = PROMPT[cls] + BOILER
    direction = DIR_WORD.get(d, "west")
    palette = class_palette(cls)
    calls = 0

    def geometry(i):
        b = boxes[i]
        cb = (max(0, b[0] - 2), max(0, b[1] - 2), min(cell, b[2] + 2), min(cell, b[3] + 2))
        crop = frames[i].crop(cb)
        target = (round(crop.width * scale), round(crop.height * scale))
        need = max(target[0], target[1] + FEET_MARGIN)
        rc = max(277, need + 4)
        px = max(0, rc // 2 + round((cb[0] - cell / 2.0) * scale))
        py = max(0, (rc - FEET_MARGIN) + round((cb[1] - baseline) * scale))
        return cb, crop, target, rc, px, py

    def lanczos_frame(i):
        cb, crop, target, rc, px, py = geometry(i)
        img = Image.new("RGBA", (rc, rc), (0, 0, 0, 0))
        img.alpha_composite(crop.resize(target, Image.Resampling.LANCZOS), (px, py))
        return img

    def one(i: int) -> str:
        nonlocal calls
        final_p = out / f"f{i:02d}_final.png"
        if final_p.exists():
            return f"f{i} cached"
        arr = np.array(frames[i])
        # FX-dominant = saturation covers a large SHARE of the visible pixels,
        # not just a large count — the warrior's ember-veined armor is saturated
        # all over his body and must still get the real redraw.
        vis_n = int((arr[:, :, 3] > 40).sum())
        if sat_count(arr) > 2000 and sat_count(arr) > 0.35 * max(1, vis_n):
            lanczos_frame(i).save(final_p)
            return f"f{i} fx-dominant (no api)"
        cb, crop, target, rc, px, py = geometry(i)
        api = (min(target[0], 200), min(target[1], 200))
        ref = crop
        if max(crop.width, crop.height) > 200:
            rk = 200.0 / max(crop.width, crop.height)
            ref = crop.resize((max(1, round(crop.width * rk)), max(1, round(crop.height * rk))),
                              Image.Resampling.LANCZOS)
        body = {
            "description": desc,
            "reference_image": {"type": "base64", "base64": _png_b64(ref), "format": "png"},
            "reference_image_size": {"width": ref.width, "height": ref.height},
            "target_size": {"width": api[0], "height": api[1]},
            "view": "low top-down",
            "direction": direction,
            "no_background": True,
            "color_image": palette,
            "seed": SEED,
        }
        resized = _decode_image(_post(token, body, TIMEOUT, ATTEMPTS))
        calls += 1
        if resized.size != api:
            raise ValueError(f"{rel} f{i}: got {resized.size}, want {api}")
        if api != target:
            resized = resized.resize(target, Image.Resampling.NEAREST)
        redrawn = Image.new("RGBA", (rc, rc), (0, 0, 0, 0))
        redrawn.alpha_composite(resized, (px, py))
        expect = lanczos_frame(i)
        ea, na = np.array(expect), np.array(redrawn)
        e_vis, n_vis = ea[:, :, 3] > 40, na[:, :, 3] > 20
        missing = e_vis & ~n_vis
        shrunk = np.array(Image.fromarray((missing * 255).astype(np.uint8), "L")
                          .filter(ImageFilter.MinFilter(3))) > 0
        inter = (e_vis & (na[:, :, 3] > 40)).sum()
        union = (e_vis | (na[:, :, 3] > 40)).sum()
        iou = inter / union if union else 1.0
        if iou < 0.55 or shrunk.sum() > e_vis.sum() * 0.35:
            expect.save(final_p)
            return f"f{i} redraw rejected (iou {iou:.2f})"
        if shrunk.sum() > 150:
            grown = np.array(Image.fromarray((shrunk * 255).astype(np.uint8), "L")
                             .filter(ImageFilter.MaxFilter(5))
                             .filter(ImageFilter.GaussianBlur(1.0))).astype(float) / 255.0
            add = ea.copy()
            add[:, :, 3] = (add[:, :, 3].astype(float) * grown).astype(np.uint8)
            redrawn.alpha_composite(Image.fromarray(add), (0, 0))
        redrawn.save(final_p)
        return f"f{i} ok {crop.size}->{target}"

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for fut in as_completed({pool.submit(one, i): i for i in range(len(frames))}):
            print(f"  {rel}: {fut.result()}", flush=True)

    finals = sorted(out.glob("f*_final.png"))
    if len(finals) != len(frames):
        return f"INCOMPLETE {rel}: {len(finals)}/{len(frames)}"
    imgs = [Image.open(p).convert("RGBA") for p in finals]
    rc = max(im.width for im in imgs)
    strip = Image.new("RGBA", (rc * len(imgs), rc), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        strip.alpha_composite(im, (i * rc + (rc - im.width) // 2, rc - im.height))
    backup = STAGE / "runtime_pre_install" / rel
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(src, backup)
    strip.save(SPR / rel)
    strip.save(MOBILE / rel)
    return f"INSTALLED {rel}: {len(imgs)}x{rc} ({calls} calls)"


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "status"
    classes = sys.argv[2:] or list(TARGET_BODY.keys())
    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN") or ""
    jobs = discover(classes)
    if mode == "status":
        done = sum(1 for cls, rel, d in jobs
                   if len(list((STAGE / cls / Path(rel).stem).glob("f*_final.png")))
                   == Image.open(SPR / rel).width // Image.open(SPR / rel).height)
        print(f"{len(jobs)} strips below band; {done} staged complete")
        return 0
    for cls in classes:
        if any(j[0] == cls for j in jobs):
            class_palette(cls)   # prime once, before threads race on it
    with ThreadPoolExecutor(max_workers=STRIP_WORKERS) as strip_pool:
        futs = {strip_pool.submit(process_strip, cls, rel, d, token): rel
                for cls, rel, d in jobs}
        done_n = 0
        for fut in as_completed(futs):
            done_n += 1
            print(f"[{done_n}/{len(jobs)}] {fut.result()}", flush=True)
    print("BAND_RUN_DONE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
