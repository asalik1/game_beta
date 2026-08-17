"""Restore archived old-design Warrior run/dash/ult/ultidle/death at 180px body.

Companion to install_preservation_warrior_attacks.py. On 2026-07-31 the
Emberbound Heir redesign (asymmetric half-plate, one bare scarred arm) was
wired as all 74 Warrior PNGs; on 2026-08-01 the owner had the old plate-and-
ember identity restored clip by clip (idle/walk redrawn, attack/attack2 from
the archive) -- but run, dash, ult, ultidle and death were never restored, so
Berserk (ult -> ultidle standing / run moving), Shield Bash (dash) and the
death collapse still played the Heir body over the plate idle (owner report
2026-08-16: "warrior ult uses the prototype base with one arm exposed").

The archived poses and timing are preserved exactly:
  * one frame-1-derived scale per strip (180px visible opening body, the same
    contract as the idle/walk/attack installs);
  * ONE placement transform per strip -- frame 1's silhouette is centred on
    the cell and grounded on the family baseline, every other frame keeps its
    archived offset relative to frame 1. (Per-frame bbox re-anchoring would
    yank the body upward on the ult's burst frames, whose flames reach 20-34
    source px below the feet, and would flatten the run bob.)
  * hard alpha + the 2px green-rim despill the 2026-08-15 sweep applied to the
    rest of the Warrior family (the archive predates it);
  * a square cell per family sized so no frame touches an edge; the engine
    grounds every strip from its own frame 1 (player_core _with_render_meta),
    so cell size is free per strip.

Current redesign files are archived before the guarded install.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import os
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from build_ledgerbound_warlock import _hard_alpha  # noqa: E402
from build_preservation_walk_candidate import _write_qa  # noqa: E402


BACKUP = ROOT / "backup" / "warrior_base_pre_emberbound_heir_2026-07-31"
WARRIOR = (
    ROOT / "art_src" / "class_preservation_upscale_2026-08-01" / "warrior"
)
OUTPUT = WARRIOR / "states_old_normalized"
SPRITES = ROOT / "game" / "assets" / "sprites"
ARCHIVE = WARRIOR / "runtime_pre_state_restore_2026-08-16"

DIRECTIONS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
SOURCE_CELL = 182
TARGET_BODY = 180
EDGE_MARGIN = 2   # px kept clear of every cell edge (verify_art EDGECUT)

# family -> (frames, directional?, runtime cell, baseline row of frame 1's
# feet, playback fps for the QA gif). Cells/baselines were sized from the
# archive's worst-case extents under the fixed per-strip transform:
#   run     widest 238, 189 above / 7 below the feet
#   dash    widest 266, 182 above / 8 below
#   ult     widest 332, 221 above / 58 below (the burst wraps under the feet)
#   ultidle widest 173, 183 above / 2 below (matches the 244 idle cell)
#   death   widest 260, 180 above / 8 below
FAMILIES = {
    "run":     (6, True,  256, 243, 11.0),
    "dash":    (7, True,  288, 275, 26.0),
    "ult":     (7, True,  352, 288, 11.0),
    "ultidle": (4, True,  244, 239, 6.0),
    "death":   (9, False, 288, 275, 9.0),
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _stem(family: str, direction: str | None) -> str:
    return f"warrior_{family}" if direction is None else f"warrior_{family}_{direction}"


def _source(family: str, direction: str | None) -> Path:
    return BACKUP / f"{_stem(family, direction)}.png"


def _runtime(family: str, direction: str | None) -> Path:
    return SPRITES / f"{_stem(family, direction)}.png"


def _verify_backup_manifest() -> None:
    manifest = BACKUP / "SHA256SUMS.txt"
    if not manifest.exists():
        raise FileNotFoundError(manifest)
    recorded: dict[str, str] = {}
    # PowerShell-written manifest: UTF-8 BOM + CRLF.
    for line in manifest.read_text(encoding="utf-8-sig").splitlines():
        if line.strip():
            digest, name = line.split(maxsplit=1)
            recorded[name.strip()] = digest.upper()
    for family, (_, directional, *_rest) in FAMILIES.items():
        for direction in (DIRECTIONS if directional else (None,)):
            name = _source(family, direction).name
            if name not in recorded:
                raise ValueError(f"{name} missing from {manifest}")
            actual = _sha256(_source(family, direction))
            if actual != recorded[name]:
                raise ValueError(f"{name}: archive SHA-256 mismatch")


def _despill_green_rim(image: Image.Image) -> Image.Image:
    """The 2px edge despill from build_mob_walk_repairs.remove_green, without
    its border-key pass (the strip is already transparent; keying off the
    zeroed border colour would eat the black armour)."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    opaque = rgba[..., 3] > 0
    core = np.asarray(Image.fromarray((opaque * 255).astype(np.uint8))
                      .filter(ImageFilter.MinFilter(5))) > 0
    rim = opaque & ~core
    r, g, b = (rgba[..., i].astype(np.int16) for i in range(3))
    spill = g - np.maximum(r, b)
    rgba[..., 3][rim & (spill > 40)] = 0
    rgba[~(rgba[..., 3] > 0), :3] = 0
    fix = rim & (spill > 8) & (rgba[..., 3] > 0)
    rgba[..., 1][fix] = np.maximum(r, b)[fix].astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _normalize(source: Path, family: str) -> list[Image.Image]:
    count, _, cell, baseline, _ = FAMILIES[family]
    strip = Image.open(source).convert("RGBA")
    expected = (count * SOURCE_CELL, SOURCE_CELL)
    if strip.size != expected:
        raise ValueError(f"{source}: expected {expected}, got {strip.size}")
    source_frames = [
        strip.crop((i * SOURCE_CELL, 0, (i + 1) * SOURCE_CELL, SOURCE_CELL))
        for i in range(count)
    ]
    boxes = [frame.getbbox() for frame in source_frames]
    for index, box in enumerate(boxes):
        if box is None:
            raise ValueError(f"{source}: empty frame {index + 1}")
    first = boxes[0]
    scale = TARGET_BODY / float(first[3] - first[1])
    scaled_cell = max(1, round(SOURCE_CELL * scale))
    # One transform for the whole strip: frame 1's silhouette centre lands on
    # the cell centre and its feet on the baseline; the archived offsets of
    # every other frame relative to frame 1 survive untouched.
    first_cx = (first[0] + first[2]) / 2.0 * scale
    first_bottom = first[3] * scale
    dx = cell / 2.0 - first_cx
    dy = baseline - first_bottom
    for index, box in enumerate(boxes):
        left = box[0] * scale + dx
        right = box[2] * scale + dx
        top = box[1] * scale + dy
        bottom = box[3] * scale + dy
        if (left < EDGE_MARGIN or right > cell - EDGE_MARGIN
                or top < EDGE_MARGIN or bottom > cell - EDGE_MARGIN):
            raise ValueError(
                f"{source}: frame {index + 1} spans x {left:.0f}-{right:.0f} "
                f"y {top:.0f}-{bottom:.0f} in a {cell}px cell -- enlarge the "
                f"family cell in FAMILIES"
            )

    frames: list[Image.Image] = []
    for frame in source_frames:
        resized = frame.resize((scaled_cell, scaled_cell), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(resized, (int(round(dx)), int(round(dy))))
        frames.append(_despill_green_rim(_hard_alpha(canvas)))
    # Frame 1 must still measure the 180px contract after hard alpha (the
    # engine scales the strip from this box).
    box = frames[0].getbbox()
    height = box[3] - box[1]
    if abs(height - TARGET_BODY) > 3:
        raise ValueError(f"{source}: frame 1 normalized to {height}px, expected {TARGET_BODY}")
    return frames


def _strip(frames: list[Image.Image]) -> Image.Image:
    cell = frames[0].width
    output = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        output.alpha_composite(frame, (index * cell, 0))
    return output


def _archive_runtime(paths: list[Path]) -> None:
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(path)
        archived = ARCHIVE / path.name
        if not archived.exists():
            shutil.copy2(path, archived)
    lines = [
        f"{_sha256(path)}  {path.name}"
        for path in sorted(ARCHIVE.glob("warrior_*.png"), key=lambda p: p.name)
    ]
    (ARCHIVE / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")


def _atomic_save(image: Image.Image, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.installing.png")
    image.save(temporary, optimize=True)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument(
        "--family", choices=sorted(FAMILIES), action="append",
        help="restrict to one family (repeatable); default = all five",
    )
    args = parser.parse_args()
    families = args.family or list(FAMILIES)

    _verify_backup_manifest()

    prepared: dict[Path, Image.Image] = {}
    for family in families:
        count, directional, cell, _, fps = FAMILIES[family]
        family_out = OUTPUT / family
        family_out.mkdir(parents=True, exist_ok=True)
        keys = DIRECTIONS if directional else (None,)
        south: Image.Image | None = None
        for direction in keys:
            source = _source(family, direction)
            target = _runtime(family, direction)
            if not source.exists() or not target.exists():
                raise FileNotFoundError(source if not source.exists() else target)
            frames = _normalize(source, family)
            strip = _strip(frames)
            prepared[target] = strip
            if direction == "s":
                south = strip
            stem = f"{_stem(family, direction)}_old_normalized"
            label = (f"Warrior archived {family}"
                     + (f" {direction.upper()}" if direction else "")
                     + f" normalized (180px, {cell}px cell)")
            _write_qa(family_out, stem, label, frames, fps, 1)
            print(f"{family} {direction or 'flat'}: {source.name} -> {strip.size}")
        if directional:
            # The flat file is the South alias in the runtime contract.
            flat = _runtime(family, None)
            if not flat.exists():
                raise FileNotFoundError(flat)
            prepared[flat] = south

    if not args.apply:
        print("audit and QA build passed; runtime untouched (use --apply to install)")
        return

    _archive_runtime(sorted(prepared))
    for target, strip in prepared.items():
        _atomic_save(strip, target)
    print(f"archived redesign states under {ARCHIVE}")
    for target in sorted(prepared, key=lambda p: p.name):
        print(f"installed {target.name}: {target.stat().st_size} bytes {_sha256(target)}")


if __name__ == "__main__":
    main()
