"""Travel-GIF: render an animation strip over ground scrolling at REAL game
speed -- the review artifact for foot-ground coupling (stride vs skate).

WHY THIS EXISTS (2026-08-27, robotic-walk round 5): a marching-in-place walk
looks perfect on every static loop (ba_gifs, contact sheets) -- the skate only
exists under node translation, so three review rounds passed strips whose feet
cover ~15% of the ground they travel. This composes what the game actually
shows: character fixed at center (camera-follow), checkered ground and
world-anchored tick posts scrolling beneath at --speed, the art advancing at
--fps on its own clock. If a planted foot glides across the checkers, you see
it in two seconds.

    python tools/art/travel_gif.py archer_walk_e
    python tools/art/travel_gif.py skins/elite/archer_severed_thread_walk_e
    python tools/art/travel_gif.py old_walk_e new_walk_e     # stacked compare
    options: --speed 250 (hero world px/s)  --fps 9 (Art.HERO_CLIP_FPS walk)
             --zoom 2  --cycles 3  --out ~/Downloads/travel_gifs

Bases resolve under game/assets/sprites/ like verify_art (subpaths ok); a
bare existing file path works too. Output: <out>/<stem>_travel.gif (compare
mode: <stem1>__vs__<stem2>_travel.gif). GIF runs at real-time pacing.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"

HERO_BODY_TARGET = 52.0 * 1.7  # HERO_TARGET_BODY x CHAR_RENDER_SCALE (screen px)

PANE_W, PANE_H = 340, 150
GROUND_Y = 118                # ground line inside a pane
CHECKER = 24                  # ground tile size, screen px
GIF_DT = 0.04                 # 25 fps compositing clock (translation is continuous)

GRASS_A = (86, 110, 62)
GRASS_B = (74, 96, 54)
POST = (52, 44, 36)
SKY = (34, 38, 33)


def resolve(base: str) -> Path:
    p = Path(base)
    if p.exists():
        return p
    q = SPRITES / (base.replace("\\", "/").strip("/") + ".png")
    if q.exists():
        return q
    sys.exit(f"no strip found for '{base}' (looked at {q})")


def load_frames(path: Path) -> tuple[list[Image.Image], float]:
    """Split a horizontal strip into frames; return (frames, render_scale)."""
    im = Image.open(path).convert("RGBA")
    fw = im.height
    n = max(1, im.width // fw)
    frames = [im.crop((f * fw, 0, (f + 1) * fw, fw)) for f in range(n)]
    a = np.asarray(frames[0])[:, :, 3]
    ys = np.nonzero(a > 40)[0]
    content_h = int(ys.max() - ys.min() + 1) if len(ys) else fw
    # Approximates the hero renderer's body-height normalization; --scale overrides.
    return frames, HERO_BODY_TARGET / max(1.0, float(content_h))


def draw_pane(canvas: Image.Image, top: int, frames: list[Image.Image],
              scale: float, t: float, speed: float, fps: float, label: str) -> None:
    d = ImageDraw.Draw(canvas)
    d.rectangle([0, top, PANE_W, top + PANE_H], fill=SKY)
    # Scrolling ground: checkers + world-anchored posts (the slip reference).
    off = speed * t
    gy = top + GROUND_Y
    d.rectangle([0, gy, PANE_W, top + PANE_H], fill=GRASS_A)
    first = int(off // CHECKER)
    for k in range(first, first + PANE_W // CHECKER + 2):
        x0 = k * CHECKER - off
        if k % 2 == 0:
            d.rectangle([x0, gy, x0 + CHECKER, top + PANE_H], fill=GRASS_B)
    for k in range(int(off // 96), int(off // 96) + PANE_W // 96 + 2):
        x0 = k * 96 - off
        d.rectangle([x0, gy - 16, x0 + 3, gy], fill=POST)
    # Character: fixed at center (camera-follow), art on its own clock.
    fr = frames[int(t * fps) % len(frames)]
    w, h = fr.size
    sw, sh = max(1, int(w * scale)), max(1, int(h * scale))
    fr = fr.resize((sw, sh), Image.LANCZOS)
    a = np.asarray(fr)[:, :, 3]
    ys = np.nonzero(a > 40)[0]
    feet = int(ys.max()) if len(ys) else sh - 1
    px = PANE_W // 2 - sw // 2
    py = gy - feet - 1
    d.ellipse([PANE_W // 2 - 16, gy - 4, PANE_W // 2 + 16, gy + 4], fill=(0, 0, 0, 70))
    canvas.alpha_composite(fr, (px, py))
    d.text((6, top + 4), label, fill=(210, 205, 190))


def main() -> int:
    ap = argparse.ArgumentParser(description="strip over scrolling ground at game speed")
    ap.add_argument("bases", nargs="+", help="strips to stack (each its own row)")
    ap.add_argument("--speed", type=float, default=250.0, help="world px/s (hero walk 250)")
    ap.add_argument("--fps", type=str, default="14",
                    help="anim clock (hero walk 14); comma list = per row, e.g. 9,12,14")
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--cycles", type=float, default=3.0)
    ap.add_argument("--scale", type=float, default=None, help="override render scale")
    ap.add_argument("--out", default=str(Path.home() / "Downloads" / "travel_gifs"))
    args = ap.parse_args()
    if len(args.bases) > 4:
        ap.error("at most 4 rows")
    fps_list = [float(x) for x in args.fps.split(",")]
    if len(fps_list) == 1:
        fps_list = fps_list * len(args.bases)
    if len(fps_list) != len(args.bases):
        ap.error("--fps must be one value or one per strip")

    rigs = []
    for b, fps in zip(args.bases, fps_list):
        p = resolve(b)
        frames, scale = load_frames(p)
        rigs.append((f"{p.stem} @{fps:g}fps", frames, args.scale or scale, fps))

    total = args.cycles * max(len(r[1]) / r[3] for r in rigs)
    steps = max(2, int(total / GIF_DT))
    H = PANE_H * len(rigs)
    shots = []
    for s in range(steps):
        t = s * GIF_DT
        canvas = Image.new("RGBA", (PANE_W, H))
        for i, (stem, frames, scale, fps) in enumerate(rigs):
            draw_pane(canvas, i * PANE_H, frames, scale, t, args.speed, fps, stem)
        if args.zoom != 1:
            canvas = canvas.resize((PANE_W * args.zoom, H * args.zoom), Image.LANCZOS)
        shots.append(canvas.convert("P", palette=Image.ADAPTIVE))

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stems = [r[0].split(" @")[0] for r in rigs]
    name = stems[0] if len(rigs) == 1 else f"{stems[0]}__vs__{len(rigs) - 1}more"
    out = out_dir / f"{name}_travel.gif"
    shots[0].save(out, save_all=True, append_images=shots[1:],
                  duration=int(GIF_DT * 1000), loop=0)
    print(f"wrote {out}  ({steps} frames, {total:.1f}s real-time, speed {args.speed:.0f}px/s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
