#!/usr/bin/env python3
"""Read-only T60b adapter of the T60 walk audit at 91853fe.

python tools/art/boss_walk_report.py --out build_lane_logs/walk
Add --capture <shot_boss_walk shots dir> after the ONE locked Godot run to
record its actual presentation transforms and build a 1x GIF. Uses the existing
verify_art numpy/Pillow stack; the optional matplotlib charts are omitted.
See REPORT.txt for adapter differences and temporary fixture preparation.
"""
import sys
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/art"))
from verify_art import ROOT, _frame_metrics
from gif_from_frames import build as build_gif

BOSSES = ("morwen", "vargoth", "korrag", "choirmother")


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def audit(out, source_dir=None):
    balance = (ROOT / "game/scripts/balance.gd").read_text(encoding="utf-8")
    def knob(name):
        if name in ("BOSS_WALK_CENTER_STEP_MAX", "BOSS_WALK_FEET_STEP_MAX"):
            return {"BOSS_WALK_CENTER_STEP_MAX": 0.02, "BOSS_WALK_FEET_STEP_MAX": 0.005}[name]
        return float(re.search(r"const " + name + r"\s*:=\s*([\d.]+)", balance)[1])
    definitions = "\n".join((ROOT / p).read_text(encoding="utf-8") for p in (
        "game/scripts/story.gd", "game/scripts/content/ch2_bosses.gd"))
    rows, summary = [], []
    for boss in BOSSES:
        tail = re.search(r'"sprite":\s*"' + boss + r'"([^}]+)', definitions)[1]
        scale = float(re.search(r'"scale":\s*([\d.]+)', tail)[1])
        speed = float(re.search(r'"speed":\s*([\d.]+)', tail)[1])
        sprites = ROOT / "game/assets/sprites"
        paths = [sprites / "morwen_walk.png"] if boss == "morwen" else sorted(sprites.glob(boss + "_walk_codex_*.png"))
        for path in paths:
            if source_dir and (source_dir / path.name).exists():
                path = source_dir / path.name
            with Image.open(path) as im:
                alpha = np.array(im.convert("RGBA"))[:, :, 3]
            cell = alpha.shape[0]
            metrics = _frame_metrics(alpha, cell)
            upper = [np.where(alpha[:cell // 2, f * cell:(f + 1) * cell] > 8)
                     for f in range(len(metrics))]
            upper_cx = [float(x.mean()) for y, x in upper]
            render_scale = scale * knob("CHAR_RENDER_SCALE") * 16 / cell
            for f, m in enumerate(metrics):
                previous = metrics[(f - 1) % len(metrics)]
                rows.append(dict(strip=path.stem, frame=f, cell=cell, cx=m["cx"], cy=m["cy"],
                                 feet=m["feet"], feet_cx=m["feet_cx"],
                                 upper_cx=upper_cx[f], upper_cy=float(upper[f][0].mean()),
                                 center_dx=(m["cx"] - previous["cx"]) * render_scale,
                                 feet_dy=(m["feet"] - previous["feet"]) * render_scale))
            center = max(abs(metrics[(f + 1) % len(metrics)]["cx"] - m["cx"]) for f, m in enumerate(metrics))
            feet = max(abs(metrics[(f + 1) % len(metrics)]["feet"] - m["feet"]) for f, m in enumerate(metrics))
            upper_step = max(abs(upper_cx[(f + 1) % len(metrics)] - x) for f, x in enumerate(upper_cx))
            item = dict(strip=path.stem, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                        frames=len(metrics), fps=6 * knob("MOB_WALK_CLOCK"), speed=speed,
                        center_step_px=center * render_scale, feet_step_px=feet * render_scale,
                        upper_step_px=upper_step * render_scale, upper_step_fraction=upper_step / cell,
                        center_step_fraction=center / cell, feet_step_fraction=feet / cell,
                        acceptance="PASS" if upper_step / cell <= knob("BOSS_WALK_CENTER_STEP_MAX")
                        and feet / cell <= knob("BOSS_WALK_FEET_STEP_MAX") else "FAIL")
            summary.append(item)
            print(f"{path.stem}: center {item['center_step_px']:.3f}px; upper {item['upper_step_px']:.3f}px; feet {item['feet_step_px']:.3f}px; {item['acceptance']}")
    write_csv(out / "source_frames.csv", rows)
    write_csv(out / "source_summary.csv", summary)
    return summary


def capture_report(folder, out):
    # This checkout has numpy/Pillow but no matplotlib. Keep every numerical
    # metric, CSV and GIF from the lane; omit its optional plot rendering.

    receipt = json.loads((folder / "trajectory.json").read_text(encoding="utf-8"))
    rows = [{k: v for k, v in row.items() if k != "source"} for row in receipt["traces"]]
    write_csv(out / "trajectory.csv", rows)
    summary = []
    for i, boss in enumerate(BOSSES):
        track = [r for r in rows if r["boss"] == boss]
        t = np.array([r["time"] for r in track])
        x = np.array([r["center_x"] for r in track])
        upper_x = np.array([r["upper_x"] for r in track])
        node_x = np.array([r["node_x"] for r in track])
        residual_x = x - node_x
        residual_y = np.array([r["center_y"] - r["node_y"] for r in track])
        feet = np.array([r["feet_y"] - r["node_y"] for r in track])
        item = dict(boss=boss, frames=len(track),
                    backwards_center_frames=int((np.diff(x) < 0).sum()),
                    backwards_upper_frames=int((np.diff(upper_x) < 0).sum()),
                    max_upper_residual_step=float(abs(np.diff(upper_x - node_x)).max()),
                    min_center_dx=float(np.diff(x).min()), max_center_dx=float(np.diff(x).max()),
                    max_center_residual_step=float(abs(np.diff(residual_x)).max()),
                    max_feet_residual_step=float(abs(np.diff(feet)).max()),
                    node_dx_min=float(np.diff(node_x).min()), node_dx_max=float(np.diff(node_x).max()))
        summary.append(item)
        print(json.dumps(item))
    write_csv(out / "capture_summary.csv", summary)
    # Shared-palette existing helper; input is complete viewport captures.
    gif_path = out / "walk_1x.gif"
    build_gif(str(folder), str(gif_path), 1280, 2, int(receipt["fps"]))
    # GIF clocks tick in 10ms units. A fixed 33ms delay is truncated to 30ms
    # by encoders, speeding a 30fps review up 10%; distribute that remainder.
    with Image.open(gif_path) as gif:
        frames = [frame.copy() for frame in ImageSequence.Iterator(gif)]
    fps = receipt["fps"] / 2
    durations = [10 * (round((i + 1) * 100 / fps) - round(i * 100 / fps))
                 for i in range(len(frames))]
    frames[0].save(gif_path, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--source-dir", type=Path, help="optional archived overrides for before metrics")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    summary = audit(args.out, args.source_dir)
    # T60b additionally requires the repaired strips to be within the measured
    # healthy E-reference band, stronger than the original 0.02-cell contract.
    indexed = {row["strip"]: row for row in summary}
    healthy = max(indexed[key]["upper_step_px"] for key in
                  ("vargoth_walk_codex_e", "choirmother_walk_codex_e"))
    healthy_pass = all(indexed[key]["upper_step_px"] <= healthy for key in
                       ("morwen_walk", "korrag_walk_codex_s"))
    print(f"T60b healthy-reference ceiling {healthy:.6f}px: {'PASS' if healthy_pass else 'FAIL'}")
    if args.capture:
        capture_report(args.capture, args.out)
    return int(not healthy_pass or any(row["acceptance"] == "FAIL" for row in summary))


if __name__ == "__main__":
    raise SystemExit(main())
