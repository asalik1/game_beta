"""T60b: whole existing square-cell translations only; never edit figure parts.

Run from this checkout. Reuses install_gait_row.anchor_x(torso), but deliberately
skips its extraction, scaling, keying, tone matching and orphan removal.
Y is identically zero: each authored feet baseline is preserved exactly.
"""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art"))
from install_gait_row import anchor_x
from verify_art import _frame_metrics

OUT = Path(__file__).resolve().parent
NAMES = ("morwen_walk", "korrag_walk_codex_s")


def main():
    receipt = []
    for name in NAMES:
        original = OUT / "before" / (name + ".png")
        src = np.array(Image.open(original).convert("RGBA"))
        cell = src.shape[0]
        frames = [src[:, i:i + cell].copy() for i in range(0, src.shape[1], cell)]
        anchors = [anchor_x(f[:, :, 3], "torso") for f in frames]
        shifts = [int(round(anchors[0] - x)) for x in anchors]
        dest = np.zeros_like(src)
        for i, (frame, dx) in enumerate(zip(frames, shifts)):
            ys, xs = np.nonzero(frame[:, :, 3] > 0)
            assert xs.min() + dx >= 0 and xs.max() + dx < cell, "clipped content"
            translated = np.zeros_like(frame)
            # Move the complete cell's visible RGBA pixels as one rigid object.
            translated[ys, xs + dx] = frame[ys, xs]
            assert np.array_equal(translated[ys, xs + dx], frame[ys, xs])
            assert np.count_nonzero(translated[:, :, 3]) == len(xs)
            dest[:, i * cell:(i + 1) * cell] = translated
        old_metrics = _frame_metrics(src[:, :, 3], cell)
        new_metrics = _frame_metrics(dest[:, :, 3], cell)
        assert [m["feet"] for m in old_metrics] == [m["feet"] for m in new_metrics]
        target = OUT / "candidate" / (name + ".png")
        target.parent.mkdir(exist_ok=True)
        Image.fromarray(dest).save(target)
        receipt.append(dict(strip=name, before_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),
                            after_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                            dx=shifts, dy=[0] * len(frames), torso_x=anchors,
                            feet_before=[m["feet"] for m in old_metrics],
                            feet_after=[m["feet"] for m in new_metrics],
                            visible_rgba_lossless=True, clipped_pixels=0))
        sheet = Image.new("RGB", (320 * len(frames), 680), (37, 42, 38))
        draw = ImageDraw.Draw(sheet)
        loops = []
        for i in range(len(frames)):
            pair = Image.new("RGB", (640, 340), (37, 42, 38))
            pd = ImageDraw.Draw(pair)
            for row, data in enumerate((src, dest)):
                frame = Image.fromarray(data[:, i * cell:(i + 1) * cell]).resize((320, 320), Image.Resampling.LANCZOS)
                sheet.paste(frame, (i * 320, row * 340 + 20), frame)
                draw.text((i * 320 + 5, row * 340 + 4), f'{"before" if row == 0 else "candidate"} f{i} dx={0 if row == 0 else shifts[i]}', fill="white")
                pair.paste(frame, (row * 320, 20), frame)
                pd.text((row * 320 + 5, 4), "before" if row == 0 else "candidate", fill="white")
                pd.line((row * 320, 20 + old_metrics[i]["feet"] * 320 / cell, row * 320 + 319, 20 + old_metrics[i]["feet"] * 320 / cell), fill=(100, 100, 100))
            loops.append(pair)
        sheet.save(OUT / (name + "_contact.png"))
        loops[0].save(OUT / (name + "_compare.gif"), save_all=True, append_images=loops[1:],
                      duration=[80, 90, 80, 80], loop=0)
    (OUT / "translations.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
