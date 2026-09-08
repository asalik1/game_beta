#!/usr/bin/env python3
"""Build six pet cycles from whole, separated ImageGen poses.

Uses the established key/despill and safe-gutter extraction. One scale per
cycle; a face template anchors whole frames so moving wings cannot tug the
body around. Never edits limbs, combines poses, or synthesizes motion.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
from build_mob_walk_repairs import remove_green, whole_subjects, alpha_box

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src/companion_motion_2026-09-08"
OUT = SOURCE / "built"
CELL = 512
# Face patches in frame 0 of the untouched master. They exclude moving wings
# and feet. Matching each existing face only translates a COMPLETE figure.
FACES = {
    "spore_pup": (218, 277, 289, 333),
    "hearth_hopper": (222, 218, 280, 271),
    "cinder_bat": (228, 293, 298, 346),
    "ash_crow": (251, 267, 316, 311),
    "glimmerwing": (268, 297, 317, 348),
    "pale_flutter": (280, 226, 342, 282),
}


def correlate(image, kernel):
    shape = tuple(2 ** int(np.ceil(np.log2(a + b - 1)))
                  for a, b in zip(image.shape, kernel.shape))
    result = np.fft.irfft2(np.fft.rfft2(image, shape) *
                          np.conj(np.fft.rfft2(kernel, shape)), shape)
    return result[:image.shape[0] - kernel.shape[0] + 1,
                  :image.shape[1] - kernel.shape[1] + 1]


def face_anchor(frame, template):
    im = np.array(frame).astype(np.float32)
    t = np.array(template).astype(np.float32)
    mask = (t[:, :, 3] > 200).astype(np.float32)
    assert mask.sum() > 300, "face patch lacks enough body content"
    cost = np.zeros((im.shape[0] - t.shape[0] + 1,
                     im.shape[1] - t.shape[1] + 1))
    for c in range(3):
        cost += correlate(im[:, :, c] ** 2, mask)
        cost -= 2 * correlate(im[:, :, c], t[:, :, c] * mask)
        cost += (t[:, :, c] ** 2 * mask).sum()
    # Transparent/keyed void can never match a dark eye.
    cost += correlate((255 - im[:, :, 3]) ** 2, mask)
    y, x = np.unravel_index(np.argmin(cost), cost.shape)
    error = float(cost[y, x] / (mask.sum() * 3))
    assert error < 5500, f"face drift needs review: template error {error:.0f}"
    return np.array([x + template.width / 2, y + template.height / 2]), error


def build(pet):
    im = remove_green(SOURCE / "masters" / f"{pet}.png")
    occupied = (np.array(im)[:, :, 3] > 32).any(axis=1)
    gaps = np.flatnonzero(~occupied)
    split = int(min(gaps, key=lambda y: abs(y - im.height / 2)))
    assert 0.4 * im.height < split < 0.6 * im.height, "no safe row gutter"
    frames = whole_subjects(im.crop((0, 0, im.width, split)), 4)
    frames += whole_subjects(im.crop((0, split, im.width, im.height)), 4)
    template = frames[0].crop(FACES[pet])
    measurements = [face_anchor(f, template) for f in frames]
    anchors = [m[0] for m in measurements]
    boxes = [alpha_box(f) for f in frames]
    lo = np.min([np.array(b[:2]) - a for b, a in zip(boxes, anchors)], axis=0)
    hi = np.max([np.array(b[2:]) - a for b, a in zip(boxes, anchors)], axis=0)
    factor = min((CELL - 80) / (hi - lo))
    place = np.array([CELL / 2, CELL / 2]) - (lo + hi) * 0.5 * factor
    cells = []
    for f, a in zip(frames, anchors):
        # Resize/place the entire frame at ONE common scale. All parts stay
        # attached exactly as drawn; empty gutters are never repaired.
        resized = f.resize((round(f.width * factor), round(f.height * factor)), Image.Resampling.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL))
        offset = tuple(np.rint(place - a * factor).astype(int))
        cell.alpha_composite(resized, offset)
        bb = alpha_box(cell)
        assert min(bb[0], bb[1], CELL - bb[2], CELL - bb[3]) >= 20
        cells.append(cell)
    if pet == "spore_pup":
        cells = cells[1:] + cells[:1]  # start the loop on the feet-down pose
    strip = Image.new("RGBA", (CELL * 8, CELL))
    for i, cell in enumerate(cells):
        strip.alpha_composite(cell, (i * CELL, 0))
    OUT.mkdir(parents=True, exist_ok=True)
    strip.save(OUT / f"companion_{pet}_walk.png")
    sheet = Image.new("RGB", (1024, 512), (35, 45, 39))
    for i, cell in enumerate(cells):
        thumb = cell.resize((256, 256), Image.Resampling.LANCZOS)
        sheet.paste(thumb, ((i % 4) * 256, (i // 4) * 256), thumb)
    ImageDraw.Draw(sheet).text((8, 8), pet, fill="white")
    sheet.save(OUT / f"{pet}_review.png")
    loop = []
    for cell in cells:
        canvas = Image.new("RGB", (256, 256), (35, 45, 39))
        small = cell.resize((192, 192), Image.Resampling.LANCZOS)
        canvas.paste(small, (32, 32), small)
        loop.append(canvas)
    loop[0].save(OUT / f"{pet}_loop.gif", save_all=True, append_images=loop[1:], duration=125, loop=0)
    return {"frames": 8, "scale": float(factor), "face_errors": [round(m[1], 1) for m in measurements],
            "head_anchor": place.tolist(), "source_size": im.size, "output_cell": CELL}


if __name__ == "__main__":
    report = {pet: build(pet) for pet in FACES}
    (OUT / "build_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    for pet, data in report.items():
        print(pet, "8 whole frames, face errors", data["face_errors"])
