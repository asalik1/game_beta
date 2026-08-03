#!/usr/bin/env python3
"""Enforce true A/B lower-limb alternation in Act 1 directional walk strips.

Image generators are good at identity and a single readable pose, but often
repeat the same leading foot across a four-frame sheet.  Front/back cycles get
an articulated lower-body reflection.  Side/diagonal cycles retain all four
authored poses and only correct the low trailing-foot band so a boot never
points opposite the torso's travel direction.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
KEYS = (
    "bandit_scout", "elf_druid", "elf_ranger", "fungus_heavy",
    "fungus_long", "mummy", "mummy_mage", "null_acolyte", "orc",
    "orc_rogue", "royal_knight", "skeleton", "skeleton_mage",
    "skeleton_rogue", "skeleton_warrior", "static_caller", "stone_base",
    "stone_broken", "vow_sentinel", "zombie",
)
DIRS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
WEST_DIRS = {"w", "nw", "sw"}
EAST_DIRS = {"e", "ne", "se"}

# Where articulated legs/roots begin, as a fraction of the alpha-box height.
# Broad, low bodies need more of the silhouette reflected than humanoids.
LOW_BODY = {
    "fungus_heavy": (0.55, 0.00),
    "fungus_long": (0.55, 0.00),
    "stone_base": (0.48, 0.00),
    "stone_broken": (0.52, 0.00),
}
# Humanoid gear often hangs beside the thighs.  Restrict reflection to the
# shin/boot band and the central body lane so swords, shields and hems stay put.
DEFAULT_LOW_BODY = (0.70, 0.16)


def alpha_box(frame: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(frame.getchannel("A")) > 32
    ys, xs = np.where(alpha)
    if not len(xs):
        raise ValueError("empty walk frame")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def lower_distance(a: Image.Image, b: Image.Image, cut_ratio: float) -> float:
    box_a, box_b = alpha_box(a), alpha_box(b)
    top = min(box_a[1], box_b[1])
    bottom = max(box_a[3], box_b[3])
    cut = round(top + (bottom - top) * cut_ratio)
    aa = np.asarray(a.getchannel("A"))[cut:] > 32
    bb = np.asarray(b.getchannel("A"))[cut:] > 32
    union = np.logical_or(aa, bb).sum()
    return float(np.logical_xor(aa, bb).sum() / max(1, union))


def strongest_order(frames: list[Image.Image], cut_ratio: float) -> tuple[int, int]:
    """Pick two authored phases with the clearest lower-body difference."""
    best = (0.0, 0, 1)
    for i in range(len(frames)):
        for j in range(i + 1, len(frames)):
            score = lower_distance(frames[i], frames[j], cut_ratio)
            if score > best[0]:
                best = (score, i, j)
    return best[1], best[2]


def lower_region(frame: Image.Image, cut_ratio: float,
                 inset_ratio: float) -> tuple[int, int, int, int, int]:
    """Return an even-width shin/foot region plus alpha-box body height."""
    x0, y0, x1, y1 = alpha_box(frame)
    width, height = x1 - x0, y1 - y0
    inset = round(width * inset_ratio)
    rx0, rx1 = max(0, x0 + inset), min(frame.width, x1 - inset)
    if (rx1 - rx0) % 2:
        rx1 -= 1
    cut = round(y0 + height * cut_ratio)
    if rx1 <= rx0 or y1 <= cut:
        raise ValueError("invalid lower-body articulation region")
    return rx0, cut, rx1, y1, height


def paste_lower(frame: Image.Image, transformed: Image.Image,
                coords: tuple[int, int, int, int, int]) -> Image.Image:
    out = frame.copy()
    rx0, cut, rx1, y1, height = coords
    blend_h = max(4, round(height * 0.07))
    mask = np.full((y1 - cut, rx1 - rx0), 255, dtype=np.uint8)
    ramp = np.linspace(0, 255, min(blend_h, mask.shape[0]), dtype=np.uint8)
    mask[:len(ramp), :] = ramp[:, None]
    out.paste(transformed, (rx0, cut), Image.fromarray(mask, "L"))
    # The runtime art contract is hard alpha.  Feathering is only used to pick
    # source pixels at the articulation seam; it must not leak partial alpha.
    pixels = np.asarray(out).copy()
    pixels[..., 3] = np.where(pixels[..., 3] >= 96, 255, 0).astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def reflected_lower(frame: Image.Image, cut_ratio: float, inset_ratio: float) -> Image.Image:
    coords = lower_region(frame, cut_ratio, inset_ratio)
    rx0, cut, rx1, y1, _ = coords
    region = frame.crop((rx0, cut, rx1, y1))
    return paste_lower(frame, region.transpose(Image.Transpose.FLIP_LEFT_RIGHT), coords)


def orient_side_feet(frame: Image.Image, direction: str, cut_ratio: float,
                     inset_ratio: float) -> Image.Image:
    """Make the trailing boot face with the torso, without moving its pose."""
    coords = lower_region(frame, cut_ratio, inset_ratio)
    rx0, cut, rx1, y1, _ = coords
    region = frame.crop((rx0, cut, rx1, y1))
    half = region.width // 2
    left = region.crop((0, 0, half, region.height))
    right = region.crop((half, 0, region.width, region.height))
    if direction in WEST_DIRS:
        right = right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    elif direction in EAST_DIRS:
        left = left.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    fixed = Image.new("RGBA", region.size)
    fixed.alpha_composite(left, (0, 0))
    fixed.alpha_composite(right, (half, 0))
    return paste_lower(frame, fixed, coords)


def frame_strip(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    if strip.width % strip.height:
        raise ValueError(f"{path.name}: not a horizontal square-cell strip")
    count = strip.width // strip.height
    if count < 2:
        raise ValueError(f"{path.name}: needs at least two authored phases")
    return [strip.crop((i * strip.height, 0, (i + 1) * strip.height, strip.height))
            for i in range(count)]


def save_strip(frames: list[Image.Image], path: Path) -> None:
    cell = frames[0].width
    strip = Image.new("RGBA", (cell * 4, cell))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * cell, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(path, optimize=True)


def build_one(source: Path, target: Path, key: str,
              direction: str) -> tuple[float, float]:
    cut_ratio, inset_ratio = LOW_BODY.get(key, DEFAULT_LOW_BODY)
    authored = frame_strip(source)
    if direction in WEST_DIRS or direction in EAST_DIRS:
        if len(authored) != 4:
            raise ValueError(f"{source.name}: side/diagonal cycle needs four authored frames")
        # Preserve the generator's complete side gait.  Reflecting an entire
        # lower body reverses the trailing boot and makes a west-facing body
        # appear to step east.  Only the low toe/boot band is canonicalized;
        # roots and quadruped paws keep their authored shapes.
        if key not in LOW_BODY:
            foot_cut = max(cut_ratio, 0.80)
            foot_inset = min(inset_ratio, 0.08)
            built = [orient_side_feet(frame, direction, foot_cut, foot_inset)
                     for frame in authored]
        else:
            built = authored
        contact_motion = lower_distance(built[0], built[2], cut_ratio)
        passing_motion = lower_distance(built[1], built[3], cut_ratio)
        if contact_motion < 0.055 or passing_motion < 0.055:
            raise ValueError(
                f"{source.name}: authored directional gait too subtle "
                f"(contact={contact_motion:.3f}, passing={passing_motion:.3f})"
            )
        save_strip(built, target)
        return contact_motion, passing_motion

    first, passing = strongest_order(authored, cut_ratio)
    a_contact = authored[first]
    b_pass = authored[passing]
    b_contact = reflected_lower(a_contact, cut_ratio, inset_ratio)
    a_pass = reflected_lower(b_pass, cut_ratio, inset_ratio)
    contact_motion = lower_distance(a_contact, b_contact, cut_ratio)
    passing_motion = lower_distance(b_pass, a_pass, cut_ratio)
    if contact_motion < 0.055 or passing_motion < 0.055:
        raise ValueError(
            f"{source.name}: lower-limb alternation too subtle "
            f"(contact={contact_motion:.3f}, passing={passing_motion:.3f})"
        )
    save_strip([a_contact, b_pass, b_contact, a_pass], target)
    return contact_motion, passing_motion


def audit_one(path: Path, key: str, direction: str) -> tuple[float, float]:
    cut_ratio, _ = LOW_BODY.get(key, DEFAULT_LOW_BODY)
    frames = frame_strip(path)
    if len(frames) != 4:
        raise ValueError(f"{path.name}: expected exactly four frames")
    contact_motion = lower_distance(frames[0], frames[2], cut_ratio)
    passing_motion = lower_distance(frames[1], frames[3], cut_ratio)
    if direction not in WEST_DIRS and direction not in EAST_DIRS:
        boxes = [alpha_box(frame) for frame in frames]
        top = min(box[1] for box in boxes)
        bottom = max(box[3] for box in boxes)
        cut = round(top + (bottom - top) * cut_ratio)
        pixels = [np.asarray(frame) for frame in frames]
        if not np.array_equal(pixels[0][:cut], pixels[2][:cut]):
            raise ValueError(f"{path.name}: contact phases changed above articulation mask")
        if not np.array_equal(pixels[1][:cut], pixels[3][:cut]):
            raise ValueError(f"{path.name}: passing phases changed above articulation mask")
    if contact_motion < 0.055 or passing_motion < 0.055:
        raise ValueError(
            f"{path.name}: installed alternation too subtle "
            f"(contact={contact_motion:.3f}, passing={passing_motion:.3f})"
        )
    return contact_motion, passing_motion


def audit_spider(path: Path) -> tuple[float, float]:
    frames = frame_strip(path)
    if len(frames) != 4:
        raise ValueError(f"{path.name}: expected exactly four spider frames")
    masks = [np.asarray(frame.getchannel("A")) > 32 for frame in frames]
    union = np.logical_or.reduce(masks)
    ys, xs = np.where(union)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    xx, yy = np.meshgrid(np.arange(union.shape[1]), np.arange(union.shape[0]))
    # Ignore the central head/abdomen core; score articulated peripheral legs.
    limb_zone = ((xx < x0 + (x1 - x0) * 0.30)
                 | (xx > x0 + (x1 - x0) * 0.70)
                 | (yy > y0 + (y1 - y0) * 0.52))

    def delta(a: int, b: int) -> float:
        ma, mb = masks[a] & limb_zone, masks[b] & limb_zone
        return float(np.logical_xor(ma, mb).sum()
                     / max(1, np.logical_or(ma, mb).sum()))

    contact, passing = delta(0, 2), delta(1, 3)
    if contact < 0.10 or passing < 0.10:
        raise ValueError(
            f"{path.name}: spider leg groups do not alternate enough "
            f"(contact={contact:.3f}, passing={passing:.3f})"
        )
    return contact, passing


def save_qa_pages(out: Path, qa: Path, keys: list[str]) -> None:
    """Write proof rows for every direction; each row exposes all four phases."""
    qa.mkdir(parents=True, exist_ok=True)
    row_h, label_w, strip_w = 170, 180, 680
    rows = [(key, direction) for key in keys for direction in DIRS]
    for page_index in range(0, len(rows), 12):
        page_rows = rows[page_index:page_index + 12]
        page = Image.new("RGBA", (label_w + strip_w, row_h * len(page_rows)),
                         (24, 25, 29, 255))
        draw = ImageDraw.Draw(page)
        for row, (key, direction) in enumerate(page_rows):
            strip = Image.open(out / f"{key}_walk_{direction}.png").convert("RGBA")
            strip.thumbnail((strip_w, row_h - 10), Image.Resampling.LANCZOS)
            y = row * row_h
            draw.text((12, y + 12), f"{key}  {direction.upper()}", fill="white")
            page.alpha_composite(strip, (label_w, y + (row_h - strip.height) // 2))
        page.save(qa / f"gait_v4_{page_index // 12 + 1}.png", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SPRITES)
    parser.add_argument("--out", type=Path, default=ROOT / "tmp" / "act1_gait_v2")
    parser.add_argument("--qa-out", type=Path,
                        help="optional QA-page directory (kept outside live assets)")
    parser.add_argument("--audit-only", action="store_true",
                        help="verify installed A/B motion and upper-body lock; write nothing")
    parser.add_argument("--audit-spider", action="store_true",
                        help="also verify peripheral eight-leg motion in installed spider strips")
    parser.add_argument("--keys", nargs="*", default=list(KEYS))
    args = parser.parse_args()
    reports = []
    for key in args.keys:
        for direction in DIRS:
            name = f"{key}_walk_{direction}.png"
            if args.audit_only:
                contact, passing = audit_one(args.source / name, key, direction)
            else:
                contact, passing = build_one(args.source / name, args.out / name,
                                             key, direction)
            reports.append((name, contact, passing))
    if args.qa_out:
        qa_source = args.source if args.audit_only else args.out
        save_qa_pages(qa_source, args.qa_out, list(args.keys))
    verb = "audited" if args.audit_only else "built"
    print(f"{verb} {len(reports)} gait-enforced strips")
    print(f"minimum lower-limb delta: {min(min(a, b) for _, a, b in reports):.3f}")
    if args.audit_spider:
        spider = [audit_spider(args.source / f"spider_walk_{direction}.png")
                  for direction in DIRS]
        print("audited 8 spider cycles")
        print(f"minimum spider leg-group delta: "
              f"{min(min(a, b) for a, b in spider):.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
