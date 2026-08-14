"""Reference-preserving PixelLab Resize pass for approved Elite skins.

This is deliberately candidate-only.  It reads the currently wired desktop
strips, redraws each authored frame at a 180 px standing-body scale, and writes
normalized candidates plus audit manifests under ``art_src``.  Runtime assets
are not changed here.

The pipeline is resumable: source crops, API results, normalized frames, and
per-direction manifests have stable names.  Re-running skips completed frames
whose source hash and geometry still match.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from pixellab_resize_assassin_attack import (
    _decode_image,
    _palette_image,
    _png_b64,
    _post,
)


REPO = Path(__file__).resolve().parents[2]
SPRITES = REPO / "game/assets/sprites"
DEFAULT_OUTPUT = REPO / "art_src/elite_skin_upscale_2026-08-10"
TARGET_BODY = 180
RUNTIME_CELL = 352
RUNTIME_BASELINE = 326
API_MAX_EDGE = 200
SEED = 20260810
SEED_OVERRIDES = {
    # The base seed washed the torso gray and collapsed the cape in this frame.
    ("golden_ronin", "anim", "se", 3): 20260813,
    # The base seed punched transparent holes through the torso armor.
    ("eclipse_knight", "anim", "se", 7): 20260817,
    # The base seed changed the cape/arm/staff silhouette in these east idles.
    ("hellfire_inquisitor", "anim", "e", 2): 20260819,
    ("hellfire_inquisitor", "anim", "e", 3): 20260823,
    ("hellfire_inquisitor", "anim", "e", 4): 20260829,
    ("hellfire_inquisitor", "anim", "e", 5): 20260831,
    ("hellfire_inquisitor", "anim", "e", 6): 20260837,
    ("hellfire_inquisitor", "anim", "e", 7): 20260841,
}

# Some legacy strips are intentionally more front-facing than their filename.
# Supplying a semantic direction for these frames makes Resize re-pose them;
# the reference image alone is the authoritative orientation.
REFERENCE_ONLY_RESIZE = {
    ("golden_ronin", "anim", "se", 3),
    *(("hellfire_inquisitor", "anim", "e", frame) for frame in range(2, 8)),
}

DIRECTION_NAMES = {
    "s": "south",
    "se": "south-east",
    "e": "east",
    "ne": "north-east",
    "n": "north",
    "nw": "north-west",
    "w": "west",
    "sw": "south-west",
}
DIRECTIONS = tuple(DIRECTION_NAMES)

# Resize is excellent at preserving character poses but consistently treats a
# few detached spell wisps as background, even when prompted otherwise.  Keep
# those authored pixels exact and scale them with the same transform as their
# source crop.  Coordinates are in the stable ``frame_*_input.png`` crop.
PRESERVE_REGIONS: dict[tuple[str, str, str, int], tuple[tuple[int, int, int, int], ...]] = {
    ("dreadknight", "anim", "e", 6): ((78, 18, 98, 43),),
    ("dreadknight", "anim", "e", 7): ((78, 18, 116, 43),),
    ("dreadknight", "anim", "ne", 3): ((75, 15, 95, 40),),
    ("dreadknight", "anim", "ne", 4): ((78, 15, 118, 55),),
    ("dreadknight", "anim", "ne", 5): ((85, 12, 135, 55),),
    ("dreadknight", "anim", "ne", 6): ((80, 12, 135, 60),),
    ("dreadknight", "anim", "nw", 6): ((8, 25, 48, 96),),
    ("dreadknight", "anim", "nw", 7): ((8, 25, 48, 96),),
}


@dataclass(frozen=True)
class Skin:
    key: str
    label: str
    base: str
    identity: str


SKINS = {
    skin.key: skin
    for skin in (
        Skin(
            "dreadknight",
            "Dreadknight",
            "skins/elite/warrior_dreadknight",
            "black iron death-knight plate, horned skull helm, tattered black cape, "
            "pale ice-blue runes and highlights, and the same broad runic greatsword; "
            "the cape remains neutral charcoal-black and must never shift green or teal",
        ),
        Skin(
            "golden_ronin",
            "Golden Ronin",
            "skins/elite/assassin_blade_dancer",
            "black-and-gold lamellar assassin armor, the same closed dark hood opening and "
            "opaque gold face mask with no exposed skin, gold trim, dark cape, and the same "
            "slim dueling blades and belt weapons",
        ),
        Skin(
            "eclipse_knight",
            "Eclipse Knight",
            "skins/elite/paladin_eclipse_knight",
            "jet-black heavy plate with brilliant solar-gold eclipse emblems and trim, "
            "dark cape, closed helm, and the same eclipse-themed chained holy weapon whose "
            "head always has a perfectly black circular void at its center surrounded by a "
            "bright gold corona; never fill the black eclipse center with gold or yellow",
        ),
        Skin(
            "hellfire_inquisitor",
            "Hellfire Inquisitor",
            "skins/elite/warlock_hellfire_inquisitor",
            "charred black and deep-red inquisitorial robes and armor, orange hellfire, "
            "the same pale skull-like hooded face with dark eye sockets, chains, and the "
            "same burning occult staff",
        ),
    )
}


@dataclass
class FrameTask:
    skin: Skin
    clip: str
    direction: str
    frame_number: int
    frames: int
    source_strip: Path
    source_sha256: str
    source_cell: int
    source_baseline: int
    source_box: tuple[int, int, int, int]
    crop_box: tuple[int, int, int, int]
    input_path: Path
    palette_path: Path
    api_path: Path
    normalized_path: Path
    manifest_path: Path
    target_size: tuple[int, int]
    api_size: tuple[int, int]
    paste: tuple[int, int]
    scale: float


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def _atomic_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2), encoding="utf-8")
    temporary.replace(path)


def _alpha_iou(source: Image.Image, output: Image.Image) -> float:
    expected = source.getchannel("A").resize(output.size, Image.Resampling.NEAREST)
    expected_mask = expected.point(lambda value: 255 if value >= 16 else 0)
    output_mask = output.getchannel("A").point(lambda value: 255 if value >= 16 else 0)
    a = expected_mask.load()
    b = output_mask.load()
    intersection = 0
    union = 0
    for y in range(output.height):
        for x in range(output.width):
            av = a[x, y] > 0
            bv = b[x, y] > 0
            intersection += int(av and bv)
            union += int(av or bv)
    return intersection / float(max(1, union))


def _fit_preview(frame: Image.Image, size: int) -> Image.Image:
    box = frame.getbbox()
    canvas = Image.new("RGBA", (size, size), (27, 27, 34, 255))
    if box is None:
        return canvas
    crop = frame.crop(box)
    scale = min((size - 8) / crop.width, (size - 8) / crop.height)
    fitted = crop.resize(
        (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas.alpha_composite(fitted, ((size - fitted.width) // 2, size - fitted.height - 4))
    return canvas


def _write_compare(
    directory: Path,
    title: str,
    old_frames: list[Image.Image],
    new_frames: list[Image.Image],
) -> None:
    thumb = 128
    label_h = 22
    sheet = Image.new(
        "RGBA", (thumb * len(old_frames), label_h + thumb * 2), (18, 18, 24, 255)
    )
    draw = ImageDraw.Draw(sheet)
    draw.text((4, 4), f"{title} | OLD above / PIXELLAB RESIZE below", fill=(238, 222, 166, 255))
    for index, frame in enumerate(old_frames):
        sheet.alpha_composite(_fit_preview(frame, thumb), (index * thumb, label_h))
    for index, frame in enumerate(new_frames):
        sheet.alpha_composite(
            _fit_preview(frame, thumb), (index * thumb, label_h + thumb)
        )
    sheet.save(directory / "comparison.png")


def _discover_clips(skin: Skin) -> list[str]:
    source = SPRITES / f"{skin.base}.png"
    stem = source.stem
    found: set[str] = set()
    for path in source.parent.glob(f"{stem}_*_s.png"):
        middle = path.stem[len(stem) + 1 : -2]
        if middle and not middle.startswith("awakened_"):
            found.add(middle)
    return sorted(found)


def _source_path(skin: Skin, clip: str, direction: str) -> Path:
    base = SPRITES / skin.base
    if clip == "static":
        return base.with_suffix(".png")
    return base.parent / f"{base.name}_{clip}_{direction}.png"


def _load_strip(path: Path) -> tuple[list[Image.Image], int]:
    image = Image.open(path).convert("RGBA")
    cell = image.height
    if cell <= 0 or image.width % cell:
        raise ValueError(f"not a square-cell strip: {path} ({image.size})")
    frames = image.width // cell
    return [image.crop((index * cell, 0, (index + 1) * cell, cell)) for index in range(frames)], cell


def _prepare_direction(
    skin: Skin,
    clip: str,
    direction: str,
    output_root: Path,
    scale: float,
    manifests: dict[Path, dict[str, Any]],
) -> list[FrameTask]:
    source = _source_path(skin, clip, direction)
    if not source.exists():
        raise FileNotFoundError(source)
    frames, source_cell = _load_strip(source)
    boxes = [frame.getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError(f"empty frame in {source}")
    resolved = [box for box in boxes if box is not None]
    source_baseline = max(box[3] for box in resolved)
    source_hash = _sha256(source)

    out_dir = output_root / skin.key / clip / direction
    out_dir.mkdir(parents=True, exist_ok=True)
    palette_path = out_dir / "palette.png"
    if not palette_path.exists():
        static = Image.open(SPRITES / f"{skin.base}.png").convert("RGBA")
        _palette_image([static, *frames]).save(palette_path)

    manifest_path = out_dir / "manifest.json"
    previous: dict[str, Any] = {}
    if manifest_path.exists():
        try:
            previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            previous = {}
    same_source = previous.get("source_sha256") == source_hash
    manifest: dict[str, Any] = {
        "skin": skin.key,
        "label": skin.label,
        "clip": clip,
        "direction": direction,
        "source_strip": str(source.relative_to(REPO)),
        "source_sha256": source_hash,
        "source_cell": source_cell,
        "source_baseline": source_baseline,
        "target_body": TARGET_BODY,
        "scale": scale,
        "runtime_cell": RUNTIME_CELL,
        "runtime_baseline": RUNTIME_BASELINE,
        "seed": SEED,
        "frames": previous.get("frames", {}) if same_source else {},
    }
    manifests[manifest_path] = manifest

    tasks: list[FrameTask] = []
    for index, (frame, box) in enumerate(zip(frames, resolved), 1):
        crop_box = (
            max(0, box[0] - 2),
            max(0, box[1] - 2),
            min(source_cell, box[2] + 2),
            min(source_cell, box[3] + 2),
        )
        crop = frame.crop(crop_box)
        target_size = (round(crop.width * scale), round(crop.height * scale))
        api_factor = min(1.0, API_MAX_EDGE / float(max(target_size)))
        api_size = (
            max(1, round(target_size[0] * api_factor)),
            max(1, round(target_size[1] * api_factor)),
        )
        paste = (
            RUNTIME_CELL // 2 + round((crop_box[0] - source_cell // 2) * scale),
            RUNTIME_BASELINE + round((crop_box[1] - source_baseline) * scale),
        )
        if (
            paste[0] < 0
            or paste[1] < 0
            or paste[0] + target_size[0] > RUNTIME_CELL
            or paste[1] + target_size[1] > RUNTIME_CELL
        ):
            raise ValueError(
                f"{source.name} frame {index} exceeds {RUNTIME_CELL}px runtime cell: "
                f"paste={paste}, target={target_size}"
            )

        input_path = out_dir / f"frame_{index:03d}_input.png"
        api_path = out_dir / f"frame_{index:03d}_api.png"
        normalized_path = out_dir / f"frame_{index:03d}_normalized.png"
        if not same_source or not input_path.exists():
            # The manifest/source hash remains the authority.  Always rewriting a
            # changed crop is safe because this directory is candidate-only.
            crop.save(input_path)

        record = manifest["frames"].get(str(index), {})
        record.update(
            {
                "source_box": box,
                "crop_box": crop_box,
                "target_size": target_size,
                "api_size": api_size,
                "paste": paste,
                "input": str(input_path.relative_to(REPO)),
                "api_output": str(api_path.relative_to(REPO)),
                "normalized": str(normalized_path.relative_to(REPO)),
            }
        )
        manifest["frames"][str(index)] = record
        tasks.append(
            FrameTask(
                skin,
                clip,
                direction,
                index,
                len(frames),
                source,
                source_hash,
                source_cell,
                source_baseline,
                box,
                crop_box,
                input_path,
                palette_path,
                api_path,
                normalized_path,
                manifest_path,
                target_size,
                api_size,
                paste,
                scale,
            )
        )
    _atomic_json(manifest_path, manifest)
    return tasks


def _description(task: FrameTask) -> str:
    return (
        f"Exact same {task.skin.label} pixel-art character from the reference, "
        f"intelligently redrawn at higher native pixel resolution: {task.skin.identity}. "
        "Preserve the exact current design, pose, anatomy, silhouette, facing, expression, "
        "handedness, number and placement of visible weapons and props, costume construction, "
        "palette, effects, foot positions, and frame composition. Every visible magical "
        "particle, smoke curl, flame, orb, rune, glow, and detached pixel cluster in the "
        "source frame is intentional animation art: preserve its exact shape, color, and "
        "screen position; never erase it as an artifact. Change resolution only. "
        "Do not redesign, re-pose, rotate, recolor, change the face, add or remove equipment, "
        "swap hands, alter the motion phase, duplicate the character, add text, or add a "
        "background. Transparent background, crisp detailed dark-fantasy pixel art."
    )


def _normalize_api_result(
    task: FrameTask, source: Image.Image, api: Image.Image
) -> tuple[tuple[int, int, int, int], int]:
    tight = api
    if api.size != task.target_size:
        tight = api.resize(task.target_size, Image.Resampling.NEAREST)
    if tight.getbbox() is None:
        raise ValueError("PixelLab returned an empty frame")

    # Resize can invent small hue shifts between otherwise-identical frames.
    # Retain its higher-resolution shading detail, but derive chroma from the
    # spatially corresponding source pixel.  Adding the luminance delta to the
    # source RGB keeps new highlights/shadows without turning charcoal capes
    # teal or changing gold, steel, cloth, skin, and flame identities.
    exact = source.resize(task.target_size, Image.Resampling.NEAREST)
    output_pixels = tight.load()
    source_pixels = exact.load()
    for y in range(tight.height):
        for x in range(tight.width):
            out_r, out_g, out_b, out_a = output_pixels[x, y]
            src_r, src_g, src_b, src_a = source_pixels[x, y]
            if src_a >= 16 and out_a < 16:
                # The reference silhouette is authoritative.  Resize
                # occasionally punches transparent holes through capes/armor;
                # restore only those omitted pixels from the exact source.
                output_pixels[x, y] = (src_r, src_g, src_b, src_a)
                continue
            if out_a < 16 or src_a < 16:
                continue
            output_luma = (54 * out_r + 183 * out_g + 19 * out_b) // 256
            source_luma = (54 * src_r + 183 * src_g + 19 * src_b) // 256
            delta = max(-24, min(24, output_luma - source_luma))
            output_pixels[x, y] = (
                max(0, min(255, src_r + delta)),
                max(0, min(255, src_g + delta)),
                max(0, min(255, src_b + delta)),
                max(out_a, src_a),
            )

    regions = PRESERVE_REGIONS.get(
        (task.skin.key, task.clip, task.direction, task.frame_number), ()
    )
    if regions:
        scale_x = task.target_size[0] / float(source.width)
        scale_y = task.target_size[1] / float(source.height)
        for left, top, right, bottom in regions:
            scaled = (
                max(0, round(left * scale_x)),
                max(0, round(top * scale_y)),
                min(task.target_size[0], round(right * scale_x)),
                min(task.target_size[1], round(bottom * scale_y)),
            )
            if scaled[2] <= scaled[0] or scaled[3] <= scaled[1]:
                raise ValueError(f"empty preserved region after scaling: {scaled}")
            tight.alpha_composite(exact.crop(scaled), (scaled[0], scaled[1]))

    normalized = Image.new("RGBA", (RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0))
    normalized.alpha_composite(tight, task.paste)
    box = normalized.getbbox()
    if box is None or box[0] <= 0 or box[1] <= 0 or box[2] >= RUNTIME_CELL or box[3] >= RUNTIME_CELL:
        raise ValueError(f"normalized result is empty or clipped: {box}")
    normalized.save(task.normalized_path)
    return box, len(regions)


def _process(task: FrameTask, token: str, timeout: int, attempts: int) -> dict[str, Any]:
    source = Image.open(task.input_path).convert("RGBA")
    palette = Image.open(task.palette_path).convert("RGB")
    key = (task.skin.key, task.clip, task.direction, task.frame_number)
    request: dict[str, object] = {
        "description": _description(task),
        "reference_image": {
            "type": "base64",
            "base64": _png_b64(source),
            "format": "png",
        },
        "reference_image_size": {"width": source.width, "height": source.height},
        "target_size": {"width": task.api_size[0], "height": task.api_size[1]},
        "no_background": True,
        "color_image": {
            "type": "base64",
            "base64": _png_b64(palette),
            "format": "png",
        },
        "seed": SEED_OVERRIDES.get(key, SEED),
    }
    if key not in REFERENCE_ONLY_RESIZE:
        request["view"] = "low top-down"
        request["direction"] = DIRECTION_NAMES[task.direction]
    response = _post(
        token,
        request,
        timeout,
        attempts,
    )
    api = _decode_image(response)
    if api.size != task.api_size:
        raise ValueError(
            f"{task.skin.key}/{task.clip}/{task.direction}/f{task.frame_number}: "
            f"returned {api.size}, expected {task.api_size}"
        )
    api.save(task.api_path)
    box, preserved_regions = _normalize_api_result(task, source, api)
    return {
        "usage": response.get("usage", {}),
        "alpha_iou": round(_alpha_iou(source, api), 4),
        "output_box": box,
        "preserved_regions": preserved_regions,
    }


def _assemble(manifests: dict[Path, dict[str, Any]]) -> int:
    assembled = 0
    overview_groups: dict[Path, list[tuple[str, Path]]] = {}
    for manifest_path, manifest in manifests.items():
        records = manifest["frames"]
        ordered = [records[str(index)] for index in range(1, len(records) + 1)]
        normalized_paths = [REPO / record["normalized"] for record in ordered]
        if not normalized_paths or not all(path.exists() for path in normalized_paths):
            continue
        frames = [Image.open(path).convert("RGBA") for path in normalized_paths]
        strip = Image.new(
            "RGBA", (RUNTIME_CELL * len(frames), RUNTIME_CELL), (0, 0, 0, 0)
        )
        for index, frame in enumerate(frames):
            strip.alpha_composite(frame, (index * RUNTIME_CELL, 0))
        out_dir = manifest_path.parent
        strip.save(out_dir / "candidate.png")

        preview_frames: list[Image.Image] = []
        for frame in frames:
            preview = Image.new("RGB", (RUNTIME_CELL, RUNTIME_CELL), (18, 18, 24))
            preview.paste(frame.convert("RGB"), (0, 0), frame.getchannel("A"))
            preview_frames.append(preview.resize((176, 176), Image.Resampling.NEAREST))
        duration = 140 if manifest["clip"] in {"static", "anim", "ultidle"} else 95
        preview_frames[0].save(
            out_dir / "preview.gif",
            save_all=True,
            append_images=preview_frames[1:],
            duration=duration,
            loop=0,
            disposal=2,
            optimize=False,
        )

        source_frames, _ = _load_strip(REPO / manifest["source_strip"])
        _write_compare(
            out_dir,
            f"{manifest['label']} {manifest['clip']} {manifest['direction']}",
            source_frames,
            frames,
        )
        overview_groups.setdefault(out_dir.parent, []).append(
            (manifest["direction"], out_dir / "comparison.png")
        )
        assembled += 1

    direction_order = {direction: index for index, direction in enumerate(DIRECTIONS)}
    for clip_dir, entries in overview_groups.items():
        existing = [entry for entry in entries if entry[1].exists()]
        if not existing:
            continue
        ordered = sorted(existing, key=lambda entry: direction_order[entry[0]])
        sheets = [Image.open(path).convert("RGB") for _, path in ordered]
        overview = Image.new(
            "RGB",
            (max(sheet.width for sheet in sheets), sum(sheet.height for sheet in sheets)),
            (18, 18, 24),
        )
        y = 0
        for sheet in sheets:
            overview.paste(sheet, (0, y))
            y += sheet.height
        overview.save(clip_dir / "overview.png")
    return assembled


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skins", default=",".join(SKINS))
    parser.add_argument(
        "--clips",
        default="all",
        help="comma-separated clip suffixes, static, or all",
    )
    parser.add_argument("--directions", default=",".join(DIRECTIONS))
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        help="per-attempt timeout; Resize can legitimately take more than five minutes",
    )
    parser.add_argument("--attempts", type=int, default=3)
    parser.add_argument(
        "--max-calls",
        type=int,
        default=0,
        help="cap new API calls for a review batch; 0 means unlimited",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--assemble-only", action="store_true")
    parser.add_argument("--verbose", action="store_true", help="print every completed frame")
    parser.add_argument(
        "--rebuild-normalized",
        action="store_true",
        help="reapply local preservation/normalization to existing API outputs",
    )
    args = parser.parse_args()

    selected_skin_keys = _split_csv(args.skins)
    unknown_skins = sorted(set(selected_skin_keys) - set(SKINS))
    if unknown_skins:
        raise ValueError(f"unknown skins: {unknown_skins}")
    directions = _split_csv(args.directions)
    unknown_directions = sorted(set(directions) - set(DIRECTIONS))
    if unknown_directions:
        raise ValueError(f"unknown directions: {unknown_directions}")
    if args.workers < 1 or args.workers > 10:
        raise ValueError("workers must be within 1..10 (PixelLab's observed job cap)")

    manifests: dict[Path, dict[str, Any]] = {}
    tasks: list[FrameTask] = []
    for skin_key in selected_skin_keys:
        skin = SKINS[skin_key]
        static = Image.open(SPRITES / f"{skin.base}.png").convert("RGBA")
        static_box = static.getbbox()
        if static_box is None:
            raise ValueError(f"empty static sprite: {skin.base}")
        reference_body = static_box[3] - static_box[1]
        scale = TARGET_BODY / float(reference_body)
        discovered = _discover_clips(skin)
        requested_clips = _split_csv(args.clips)
        clips = (["static", *discovered] if "all" in requested_clips else requested_clips)
        unknown_clips = sorted(set(clips) - ({"static"} | set(discovered)))
        if unknown_clips:
            raise ValueError(f"{skin.key} does not have clips: {unknown_clips}")
        for clip in clips:
            clip_directions = ["s"] if clip == "static" else directions
            for direction in clip_directions:
                tasks.extend(
                    _prepare_direction(
                        skin, clip, direction, args.output_root, scale, manifests
                    )
                )

    pending = [
        task
        for task in tasks
        if not task.api_path.exists() or not task.normalized_path.exists()
    ]
    completed = len(tasks) - len(pending)
    if args.max_calls:
        pending = pending[: args.max_calls]
    print(
        f"prepared {len(tasks)} frames; completed={completed}; "
        f"pending_this_run={len(pending)}; manifests={len(manifests)}",
        flush=True,
    )
    if args.dry_run:
        return

    if args.rebuild_normalized:
        rebuilt = 0
        for task in tasks:
            if not task.api_path.exists():
                continue
            source = Image.open(task.input_path).convert("RGBA")
            api = Image.open(task.api_path).convert("RGBA")
            box, preserved_regions = _normalize_api_result(task, source, api)
            manifest = manifests[task.manifest_path]
            manifest["frames"][str(task.frame_number)].update(
                {"output_box": box, "preserved_regions": preserved_regions}
            )
            _atomic_json(task.manifest_path, manifest)
            rebuilt += 1
        print(f"rebuilt {rebuilt} normalized frames from existing API outputs", flush=True)
        assembled = _assemble(manifests)
        print(f"assembled {assembled}/{len(manifests)} direction candidates", flush=True)
        return

    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN") or ""
    if pending and not args.assemble_only and not token:
        raise RuntimeError("PIXELLAB_SECRET/PIXELLAB_API_TOKEN is not available")

    failures: list[tuple[FrameTask, BaseException]] = []
    if pending and not args.assemble_only:
        processed = 0
        with ThreadPoolExecutor(max_workers=min(args.workers, len(pending))) as pool:
            futures = {
                pool.submit(_process, task, token, args.timeout, args.attempts): task
                for task in pending
            }
            for future in as_completed(futures):
                task = futures[future]
                processed += 1
                try:
                    result = future.result()
                except BaseException as error:
                    failures.append((task, error))
                    print(
                        f"FAILED {task.skin.key}/{task.clip}/{task.direction}/"
                        f"f{task.frame_number}: {error}",
                        flush=True,
                    )
                    continue
                manifest = manifests[task.manifest_path]
                manifest["frames"][str(task.frame_number)].update(result)
                _atomic_json(task.manifest_path, manifest)
                if args.verbose or processed % 10 == 0 or processed == len(pending):
                    print(
                        f"progress {processed}/{len(pending)}; last="
                        f"{task.skin.key}/{task.clip}/{task.direction}/"
                        f"f{task.frame_number}/{task.frames} "
                        f"iou={result['alpha_iou']} usage={result['usage']}",
                        flush=True,
                    )

    assembled = _assemble(manifests)
    print(f"assembled {assembled}/{len(manifests)} direction candidates", flush=True)
    if failures:
        summary = "; ".join(
            f"{task.skin.key}/{task.clip}/{task.direction}/f{task.frame_number}: {error}"
            for task, error in failures[:12]
        )
        raise RuntimeError(f"{len(failures)} PixelLab resize failures: {summary}")


if __name__ == "__main__":
    main()
