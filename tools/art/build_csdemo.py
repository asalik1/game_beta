"""Encode the shot_csdemo rig's frame dumps into the class-select ability demo
videos: user://shots/csdemo/<class>_<slot>/f###.png  ->
game/assets/videos/csdemo_<class>_<slot>.ogv (+ the mobile mirror).

Theora (.ogv) is the one video codec Godot 4 plays natively (VideoStreamPlayer),
every platform included. The stage shows them at 640x400-ish, so the encode
crops the rig's 1280x720 to the action (a 840x520 window biased toward the
hero+pack midpoint the rig framed on) and scales to 640x396 (theora wants /4).

Usage: python tools/art/build_csdemo.py [class ...]   (default: all six)
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SHOTS = Path.home() / "AppData/Roaming/Godot/app_userdata/Crownless/shots/csdemo"
OUT = REPO / "game/assets/videos"
MOBILE_OUT = REPO / "mobile/game/assets/videos"
CLASSES = ["warrior", "archer", "mage", "assassin", "paladin", "warlock"]
SLOTS = ["a1", "a2", "a3", "ult"]
FPS = 30
# crop x:y from the 1280x720 frame — the rig framed the action on the centre,
# hero left of it; keep a wide window so dashes and volleys stay in frame.
# BOTH output dimensions must be multiples of 16: Godot's Theora decoder
# renders non-mult-16 videos as corrupted macroblock soup (hit 2026-08-19 at
# 640x396; 640x400 decodes clean).
CROP = "960:600:160:60"   # w:h:x:y  (1.6 aspect, matches 640x400)
SCALE = "640x400"


def encode(cls: str, slot: str) -> bool:
    src = SHOTS / f"{cls}_{slot}"
    if not src.is_dir() or not any(src.glob("f*.png")):
        print(f"SKIP {cls}_{slot}: no frames under {src}")
        return False
    OUT.mkdir(parents=True, exist_ok=True)
    MOBILE_OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"csdemo_{cls}_{slot}.ogv"
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-framerate", str(FPS),
        "-i", str(src / "f%03d.png"),
        "-vf", f"crop={CROP},scale={SCALE}",
        # yuv420p EXPLICITLY: from PNG input ffmpeg picks yuv444p, which
        # Godot's theora decoder renders as macroblock garbage at best and
        # crashes on (0xC000001D) at worst — 4:2:0 is the one safe profile.
        # -g 1 = INTRA-ONLY: with normal keyframe spacing, Godot's decoder
        # corrupts the inter-predicted (moving) blocks of ffmpeg-encoded
        # theora — the owner saw green macroblock soup exactly where the hero
        # casts. All-keyframes costs ~2-3x the bytes and decodes clean.
        "-pix_fmt", "yuv420p", "-g", "1",
        "-c:v", "libtheora", "-q:v", "6",
        "-an", str(out),
    ]
    subprocess.run(cmd, check=True)
    (MOBILE_OUT / out.name).write_bytes(out.read_bytes())
    kb = out.stat().st_size // 1024
    print(f"OK   {out.name}  {kb} KB")
    return True


def main() -> int:
    classes = sys.argv[1:] or CLASSES
    done = 0
    for cls in classes:
        for slot in SLOTS:
            if encode(cls, slot):
                done += 1
    print(f"done: {done} videos")
    return 0 if done else 1


if __name__ == "__main__":
    raise SystemExit(main())
