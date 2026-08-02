"""AI-resize the untouched 104 px Assassin east walk with PixelLab.

This is a candidate-only source builder.  It never writes runtime assets.  All
six frames use one union crop and one source-derived palette so the original
gait coordinates, bob, and design remain the conditioning authority.
"""

from __future__ import annotations

import argparse
import base64
from collections import Counter
import io
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

from PIL import Image

from build_preservation_walk_candidate import _write_qa


CELL = 166
FRAMES = 6
RUNTIME_CELL = 277
RUNTIME_BASELINE = 255
TARGET_BODY = 180
DEFAULT_REQUEST_BODY = 183
ENDPOINT = "https://api.pixellab.ai/v2/resize"


def _png_b64(image: Image.Image) -> str:
    data = io.BytesIO()
    image.save(data, format="PNG")
    return base64.b64encode(data.getvalue()).decode("ascii")


def _decode_image(payload: dict[str, object]) -> Image.Image:
    image = payload.get("image")
    if not isinstance(image, dict) or not isinstance(image.get("base64"), str):
        raise ValueError(f"PixelLab response has no base64 image: {payload.keys()}")
    encoded = image["base64"]
    if encoded.startswith("data:"):
        encoded = encoded.split(",", 1)[1]
    return Image.open(io.BytesIO(base64.b64decode(encoded))).convert("RGBA")


def _palette_image(strip: Image.Image) -> Image.Image:
    colors = Counter(pixel[:3] for pixel in strip.getdata() if pixel[3] > 0)
    selected = [color for color, _ in colors.most_common(256)]
    selected.extend([(0, 0, 0)] * (256 - len(selected)))
    palette = Image.new("RGB", (16, 16))
    palette.putdata(selected)
    return palette


def _post(token: str, request_body: dict[str, object]) -> dict[str, object]:
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(request_body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"PixelLab resize HTTP {error.code}: {detail}") from error


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument(
        "--frames",
        default="1,2,3,4,5,6",
        help="comma-separated one-based frames to submit",
    )
    parser.add_argument("--seed", type=int, default=20260802)
    parser.add_argument(
        "--request-body",
        type=int,
        default=DEFAULT_REQUEST_BODY,
        help="PixelLab request proxy; 183 landed at roughly 180 visible pixels in calibration",
    )
    parser.add_argument(
        "--assemble-only",
        action="store_true",
        help="assemble previously returned normalized frames without calling PixelLab",
    )
    args = parser.parse_args()

    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN") or ""
    if not token and not args.assemble_only:
        raise RuntimeError("PIXELLAB_SECRET/PIXELLAB_API_TOKEN is not available")

    strip = Image.open(args.source).convert("RGBA")
    if strip.size != (CELL * FRAMES, CELL):
        raise ValueError(f"expected {FRAMES} {CELL}px cells, got {strip.size}")
    frames = [
        strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        for index in range(FRAMES)
    ]
    boxes = [frame.getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("source contains an empty frame")
    resolved = [box for box in boxes if box is not None]
    union = (
        max(0, min(box[0] for box in resolved) - 2),
        max(0, min(box[1] for box in resolved) - 2),
        min(CELL, max(box[2] for box in resolved) + 2),
        min(CELL, max(box[3] for box in resolved) + 2),
    )
    first_height = resolved[0][3] - resolved[0][1]
    scale = args.request_body / float(first_height)
    source_size = (union[2] - union[0], union[3] - union[1])
    target_size = (
        round(source_size[0] * scale),
        round(source_size[1] * scale),
    )
    if max(target_size) > 200:
        raise ValueError(f"PixelLab Resize target exceeds 200px: {target_size}")

    requested = [] if args.assemble_only else sorted(
        {int(value) for value in args.frames.split(",") if value}
    )
    if any(number < 1 or number > FRAMES for number in requested):
        raise ValueError(f"frame selection outside 1..{FRAMES}: {requested}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    palette = _palette_image(strip)
    palette.save(args.output_dir / "assassin_walk_e_original_palette.png")
    palette_payload = {"type": "base64", "base64": _png_b64(palette), "format": "png"}

    manifest: dict[str, object] = {
        "source": str(args.source),
        "source_cell": CELL,
        "source_union_crop": union,
        "source_size": source_size,
        "target_size": target_size,
        "target_body": TARGET_BODY,
        "request_body": args.request_body,
        "seed": args.seed,
        "frames": {},
    }
    description = (
        "Exact same hooded male Assassin sprite from the reference: cool charcoal-gray "
        "hood, black void face, cyan eye, gray-black armor, burgundy straps and belt, "
        "torn dark cape, silver guards, and the same daggers. Intelligently redraw at "
        "higher native pixel resolution. Preserve the exact pose, anatomy, silhouette, "
        "leg positions, foot placement, cape shape, weapons, palette, and facing. Do not "
        "redesign, re-pose, recolor, add or remove equipment, or change the gait."
    )

    for number in requested:
        crop = frames[number - 1].crop(union)
        crop_path = args.output_dir / f"assassin_walk_e_f{number:02d}_input.png"
        crop.save(crop_path)
        image_payload = {"type": "base64", "base64": _png_b64(crop), "format": "png"}
        request_body: dict[str, object] = {
            "description": description,
            "reference_image": image_payload,
            "reference_image_size": {"width": source_size[0], "height": source_size[1]},
            "target_size": {"width": target_size[0], "height": target_size[1]},
            "view": "low top-down",
            "direction": "east",
            "no_background": True,
            "color_image": palette_payload,
            "seed": args.seed,
        }
        response = _post(token, request_body)
        resized = _decode_image(response)
        if resized.size != target_size:
            raise ValueError(f"frame {number} returned {resized.size}, expected {target_size}")
        tight_path = args.output_dir / f"assassin_walk_e_f{number:02d}_pixellab_resize.png"
        resized.save(tight_path)

        runtime = Image.new("RGBA", (RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0))
        bottom_padding = round((union[3] - max(box[3] for box in resolved)) * scale)
        paste_y = RUNTIME_BASELINE - (target_size[1] - bottom_padding)
        paste_x = (RUNTIME_CELL - target_size[0]) // 2
        runtime.alpha_composite(resized, (paste_x, paste_y))
        runtime_path = args.output_dir / f"assassin_walk_e_f{number:02d}_normalized.png"
        runtime.save(runtime_path)

        usage = response.get("usage", {})
        manifest["frames"][str(number)] = {
            "input": str(crop_path),
            "resized": str(tight_path),
            "normalized": str(runtime_path),
            "usage": usage,
        }
        print(f"frame {number}: PixelLab {source_size} -> {target_size}; usage={usage}")

    if not args.assemble_only:
        (args.output_dir / "manifest.json").write_text(
            json.dumps(manifest, indent=2), encoding="utf-8"
        )

    normalized_paths = [
        args.output_dir / f"assassin_walk_e_f{number:02d}_normalized.png"
        for number in range(1, FRAMES + 1)
    ]
    if all(path.exists() for path in normalized_paths):
        normalized = [Image.open(path).convert("RGBA") for path in normalized_paths]
        strip_out = Image.new(
            "RGBA", (RUNTIME_CELL * FRAMES, RUNTIME_CELL), (0, 0, 0, 0)
        )
        for index, frame in enumerate(normalized):
            strip_out.alpha_composite(frame, (index * RUNTIME_CELL, 0))
        stem = "assassin_walk_e_pixellab_resize_v02"
        strip_out.save(args.output_dir / f"{stem}_candidate.png")
        _write_qa(
            args.output_dir,
            stem,
            "Assassin East — PixelLab Resize of Original Gait",
            normalized,
            fps=9.0,
            opposite_contact=4,
        )
        heights = [frame.getbbox()[3] - frame.getbbox()[1] for frame in normalized]
        print(f"assembled six-frame candidate; visible heights={heights}")

        # The untouched legacy clip's two wide contact poses are old f2/f5.
        # A cyclic phase rotation changes neither adjacency nor playback, but
        # puts those contacts at review/runtime f1/f4 as expected by QA.
        phase_order = (2, 3, 4, 5, 6, 1)
        aligned = [normalized[number - 1] for number in phase_order]
        aligned_stem = "assassin_walk_e_pixellab_resize_v03_contact_aligned"
        aligned_strip = Image.new(
            "RGBA", (RUNTIME_CELL * FRAMES, RUNTIME_CELL), (0, 0, 0, 0)
        )
        for index, frame in enumerate(aligned):
            aligned_strip.alpha_composite(frame, (index * RUNTIME_CELL, 0))
        aligned_strip.save(args.output_dir / f"{aligned_stem}_candidate.png")
        _write_qa(
            args.output_dir,
            aligned_stem,
            "Assassin East — PixelLab Resize, Contacts Aligned",
            aligned,
            fps=9.0,
            opposite_contact=4,
        )
        print(f"phase-aligned contact order={phase_order}; contacts=new f1/f4")


if __name__ == "__main__":
    main()
