#!/usr/bin/env python3
"""Submit a short Assassin attack segment for PixelLab dagger continuity repair."""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

from PIL import Image


ENDPOINT = "https://api.pixellab.ai/v2/edit-animation-v2"


def _payload(path: Path) -> tuple[dict[str, object], tuple[int, int]]:
    image = Image.open(path).convert("RGBA")
    return (
        {
            "image": {
                "type": "base64",
                "base64": base64.b64encode(path.read_bytes()).decode("ascii"),
                "format": "png",
            },
            "size": {"width": image.width, "height": image.height},
        },
        image.size,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--frames", default="5,6,7", help="one-based source frames")
    parser.add_argument("--direction", default="east")
    parser.add_argument("--seed", type=int, default=20260802)
    args = parser.parse_args()

    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN")
    if not token:
        raise RuntimeError("PIXELLAB_SECRET/PIXELLAB_API_TOKEN is not available")

    numbers = [int(value) for value in args.frames.split(",") if value]
    if not 1 <= len(numbers) <= 4:
        raise ValueError("PixelLab attack repairs support one to four frames per job")
    frames: list[dict[str, object]] = []
    sizes: list[tuple[int, int]] = []
    for number in numbers:
        payload, size = _payload(args.input_dir / f"frame_{number - 1:03d}.png")
        frames.append(payload)
        sizes.append(size)
    if len(set(sizes)) != 1:
        raise ValueError(f"input frame sizes differ: {sizes}")
    width, height = sizes[0]

    description = (
        f"Repair dagger continuity only in this {args.direction}-facing Assassin attack segment. "
        "Every frame must visibly show exactly TWO separate short thin silver daggers total, "
        "one firmly gripped in each hand. Restore the missing dagger in any empty hand and keep "
        "both blades short, identical, distinct, and readable. Change nothing else: preserve the "
        "exact attack motion, arm and leg poses, foot positions, anatomy, frame order, scale, "
        "cool charcoal hood and cloak, pitch-black face shadow, cyan eye, armor, burgundy straps, "
        "existing dagger, palette, transparency, and pixel-art style. Do not merge, lengthen, "
        "hide, sheath, or swap the daggers. No sword, spear, staff, third blade, FX, trail, glow, "
        "extra limb, duplicate character, background, or camera change."
    )
    body: dict[str, object] = {
        "description": description,
        "frames": frames,
        "image_size": {"width": width, "height": height},
        "seed": args.seed,
        "no_background": True,
    }
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"PixelLab attack repair HTTP {error.code}: {detail}") from error

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "submission.json").write_text(
        json.dumps(
            {
                "request": {
                    "description": description,
                    "source_frames": numbers,
                    "direction": args.direction,
                    "image_size": {"width": width, "height": height},
                    "seed": args.seed,
                },
                "response": result,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps(result))


if __name__ == "__main__":
    main()
