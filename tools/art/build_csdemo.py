"""Encode the shot_csdemo rig's frame dumps into the class-select ability demo
videos: user://shots/csdemo/<class>_<slot>/f###.png  ->
game/assets/videos/csdemo_<class>_<slot>.ogv (+ the mobile mirror).

Theora (.ogv) is the one video codec Godot 4 plays natively (VideoStreamPlayer),
every platform included. The stage shows them at 640x400-ish, so the encode
crops the rig's 1280x720 to the action (a 840x520 window biased toward the
hero+pack midpoint the rig framed on) and scales to 640x396 (theora wants /4).

Usage: python tools/art/build_csdemo.py [class ...] [--src <shots/csdemo>]
       (default: all six classes)

shot.bat runs rigs on this checkout's own profile (tools/shot_rig.ps1), never
the owner's real %APPDATA%, and keeps its shots/ across runs, so one
`shot.bat csdemo --class=<id>` per class builds up the set in SHOTS below.
A run with a caller-supplied APPDATA prints its own RIG SHOTS DIR: pass it
as --src.
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SHOTS = REPO / "build/qa/shot_profile/Godot/app_userdata/Crownless/shots/csdemo"
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


def encode(shots: Path, cls: str, slot: str) -> bool:
    src = shots / f"{cls}_{slot}"
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
    ap = argparse.ArgumentParser(description="Encode shot_csdemo frames into class-select videos.")
    ap.add_argument("classes", nargs="*", help="class ids (default: all six)")
    ap.add_argument("--src", type=Path, default=SHOTS,
                    help="the rig's shots/csdemo folder (default: this checkout's shot profile)")
    a = ap.parse_args()
    if not a.src.is_dir():
        print(f"no csdemo frames at {a.src}: run `shot.bat csdemo --fixed-fps=30 --class=<id>` "
              "first, or pass --src with the RIG SHOTS DIR the runner printed")
        return 1
    done = 0
    for cls in a.classes or CLASSES:
        for slot in SLOTS:
            if encode(a.src, cls, slot):
                done += 1
    print(f"done: {done} videos")
    return 0 if done else 1


if __name__ == "__main__":
    raise SystemExit(main())
