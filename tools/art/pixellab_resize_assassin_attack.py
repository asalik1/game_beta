"""Upscale approved Assassin attack frames with PixelLab Resize.

Candidate-only: this script writes review assets under ``art_src`` and never
touches runtime sprites.  Every frame is tightly cropped independently, then
placed back using its original 212 px animation coordinates.  That avoids
paying for transparent motion padding and preserves attack travel exactly.
"""

from __future__ import annotations

import argparse
import base64
from collections import Counter
import io
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request

from PIL import Image

from build_preservation_walk_candidate import _write_qa


SOURCE_CELL = 212
FRAMES = 8
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


def _palette_image(images: list[Image.Image]) -> Image.Image:
    colors = Counter(
        pixel[:3]
        for image in images
        for pixel in image.getdata()
        if pixel[3] > 0
    )
    selected = [color for color, _ in colors.most_common(256)]
    selected.extend([(0, 0, 0)] * (256 - len(selected)))
    palette = Image.new("RGB", (16, 16))
    palette.putdata(selected)
    return palette


def _post(token: str, request_body: dict[str, object]) -> dict[str, object]:
    for attempt in range(1, 4):
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
            with urllib.request.urlopen(request, timeout=300) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            if error.code not in {502, 503, 504} or attempt == 3:
                raise RuntimeError(
                    f"PixelLab resize HTTP {error.code}: {detail}"
                ) from error
            print(f"PixelLab resize HTTP {error.code}; retry {attempt}/3")
            time.sleep(attempt * 2)
        except (TimeoutError, urllib.error.URLError) as error:
            if attempt == 3:
                raise RuntimeError(
                    f"PixelLab resize network failure after {attempt} attempts: {error}"
                ) from error
            print(f"PixelLab resize network timeout; retry {attempt}/3")
            time.sleep(attempt * 2)
    raise AssertionError("unreachable")


def _load_frames(source_dir: Path) -> list[Image.Image]:
    paths = [source_dir / f"frame_{index:03d}.png" for index in range(FRAMES)]
    missing = [str(path) for path in paths if not path.exists()]
    if missing:
        raise FileNotFoundError(f"missing source attack frames: {missing}")
    frames = [Image.open(path).convert("RGBA") for path in paths]
    if any(frame.size != (SOURCE_CELL, SOURCE_CELL) for frame in frames):
        raise ValueError("all source attack frames must be 212x212")
    return frames


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--direction", required=True)
    parser.add_argument(
        "--palette-dir",
        type=Path,
        required=True,
        help="canonical rotation directory used to lock the original palette",
    )
    parser.add_argument(
        "--frames",
        default="1,2,3,4,5,6,7,8",
        help="comma-separated one-based frames to submit",
    )
    parser.add_argument("--seed", type=int, default=20260802)
    parser.add_argument("--request-body", type=int, default=DEFAULT_REQUEST_BODY)
    parser.add_argument("--assemble-only", action="store_true")
    args = parser.parse_args()

    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN") or ""
    if not token and not args.assemble_only:
        raise RuntimeError("PIXELLAB_SECRET/PIXELLAB_API_TOKEN is not available")

    frames = _load_frames(args.source_dir)
    boxes = [frame.getbbox() for frame in frames]
    if any(box is None for box in boxes):
        raise ValueError("source contains an empty frame")
    resolved = [box for box in boxes if box is not None]
    source_baseline = max(box[3] for box in resolved)
    reference_height = resolved[0][3] - resolved[0][1]
    scale = args.request_body / float(reference_height)

    palette_sources = [
        Image.open(path).convert("RGBA")
        for path in sorted(args.palette_dir.glob("*.png"))
    ]
    if not palette_sources:
        raise FileNotFoundError(f"no canonical palette PNGs in {args.palette_dir}")
    palette = _palette_image(palette_sources)
    palette_payload = {"type": "base64", "base64": _png_b64(palette), "format": "png"}

    requested = [] if args.assemble_only else sorted(
        {int(value) for value in args.frames.split(",") if value}
    )
    if any(number < 1 or number > FRAMES for number in requested):
        raise ValueError(f"frame selection outside 1..{FRAMES}: {requested}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    palette.save(args.output_dir / "assassin_canonical_palette.png")
    manifest_path = args.output_dir / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = {
            "source_dir": str(args.source_dir),
            "direction": args.direction,
            "source_cell": SOURCE_CELL,
            "source_baseline": source_baseline,
            "target_body": TARGET_BODY,
            "request_body": args.request_body,
            "seed": args.seed,
            "frames": {},
        }

    description = (
        "Exact same grim hooded Assassin from the reference, intelligently redrawn at "
        "higher native pixel resolution: cool charcoal-gray tattered hood and cloak, "
        "pitch-black void face, cyan eye only when this facing naturally shows it, "
        "gray-black armor, burgundy straps and belt, black gloves, silver guards, and "
        "EXACTLY TWO separate short thin straight silver daggers, one in each hand. "
        "Preserve this exact attack pose, anatomy, silhouette, hand positions, foot "
        "placement, cloak shape, weapon positions, palette, and facing. Do not redesign, "
        "re-pose, recolor, rotate, expose skin, merge or remove a dagger, add equipment, "
        "or add effects. Transparent background."
    )

    for number in requested:
        frame = frames[number - 1]
        box = resolved[number - 1]
        crop_box = (
            max(0, box[0] - 2),
            max(0, box[1] - 2),
            min(SOURCE_CELL, box[2] + 2),
            min(SOURCE_CELL, box[3] + 2),
        )
        crop = frame.crop(crop_box)
        target_size = (
            round(crop.width * scale),
            round(crop.height * scale),
        )
        if max(target_size) > 256:
            raise ValueError(f"PixelLab Resize target exceeds 256px: {target_size}")
        # /v2/resize hard-limits each requested edge to 200 px.  Preserve the
        # source-derived final geometry by letting PixelLab redraw at the
        # largest accepted size and only then restoring a capped edge with
        # nearest-neighbour sampling.  This keeps the 180 px body scale and
        # does not ask the model to shorten wide attack weapons.
        api_size = (min(target_size[0], 200), min(target_size[1], 200))

        crop_path = args.output_dir / f"assassin_stab_{args.direction}_f{number:02d}_input.png"
        crop.save(crop_path)
        image_payload = {"type": "base64", "base64": _png_b64(crop), "format": "png"}
        request_body: dict[str, object] = {
            "description": description,
            "reference_image": image_payload,
            "reference_image_size": {"width": crop.width, "height": crop.height},
            "target_size": {"width": api_size[0], "height": api_size[1]},
            "view": "low top-down",
            "direction": args.direction,
            "no_background": True,
            "color_image": palette_payload,
            "seed": args.seed,
        }
        response = _post(token, request_body)
        resized = _decode_image(response)
        if resized.size != api_size:
            raise ValueError(f"frame {number} returned {resized.size}, expected {api_size}")
        api_path = args.output_dir / f"assassin_stab_{args.direction}_f{number:02d}_pixellab_api.png"
        resized.save(api_path)
        if api_size != target_size:
            resized = resized.resize(target_size, Image.Resampling.NEAREST)
        tight_path = args.output_dir / f"assassin_stab_{args.direction}_f{number:02d}_pixellab_resize.png"
        resized.save(tight_path)

        runtime = Image.new("RGBA", (RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0))
        paste_x = RUNTIME_CELL // 2 + round((crop_box[0] - SOURCE_CELL // 2) * scale)
        paste_y = RUNTIME_BASELINE + round((crop_box[1] - source_baseline) * scale)
        runtime.alpha_composite(resized, (paste_x, paste_y))
        normalized_path = args.output_dir / f"assassin_stab_{args.direction}_f{number:02d}_normalized.png"
        runtime.save(normalized_path)

        manifest["frames"][str(number)] = {
            "source_box": box,
            "crop_box": crop_box,
            "target_size": target_size,
            "api_size": api_size,
            "input": str(crop_path),
            "api_output": str(api_path),
            "resized": str(tight_path),
            "normalized": str(normalized_path),
            "usage": response.get("usage", {}),
        }
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print(
            f"frame {number}: PixelLab {crop.size} -> {api_size}; "
            f"normalized geometry={target_size}; usage={response.get('usage', {})}"
        )

    normalized_paths = [
        args.output_dir / f"assassin_stab_{args.direction}_f{number:02d}_normalized.png"
        for number in range(1, FRAMES + 1)
    ]
    if all(path.exists() for path in normalized_paths):
        normalized = [Image.open(path).convert("RGBA") for path in normalized_paths]
        stem = f"assassin_stab_{args.direction}_pixellab_resize_v01"
        strip = Image.new("RGBA", (RUNTIME_CELL * FRAMES, RUNTIME_CELL), (0, 0, 0, 0))
        for index, frame in enumerate(normalized):
            strip.alpha_composite(frame, (index * RUNTIME_CELL, 0))
        strip.save(args.output_dir / f"{stem}_candidate.png")
        _write_qa(
            args.output_dir,
            stem,
            f"Assassin Stab {args.direction.title()} - PixelLab Resize",
            normalized,
            fps=12.0,
            opposite_contact=5,
        )
        heights = [frame.getbbox()[3] - frame.getbbox()[1] for frame in normalized]
        print(f"assembled eight-frame candidate; visible heights={heights}")


if __name__ == "__main__":
    main()
