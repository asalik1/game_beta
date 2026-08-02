"""Submit the resized Assassin east cycle for a coherent second-dagger edit."""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

from PIL import Image

from build_preservation_walk_candidate import _write_qa


ENDPOINT = "https://api.pixellab.ai/v2/edit-animation-v2"
PHASE_ORDER = (2, 3, 4, 5, 6, 1)
RUNTIME_CELL = 277


def _image_payload(path: Path) -> tuple[dict[str, object], tuple[int, int]]:
    image = Image.open(path).convert("RGBA")
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return (
        {
            "image": {"type": "base64", "base64": encoded, "format": "png"},
            "size": {"width": image.width, "height": image.height},
        },
        image.size,
    )


def _assemble(input_dir: Path, output_dir: Path, stem: str) -> None:
    # Group A supplies aligned f1-f4. Group B supplies aligned f5-f6; its first
    # and last images are overlap anchors for f4 and f1, respectively.
    edited_paths = [
        output_dir / "group_a_01.png",
        output_dir / "group_a_02.png",
        output_dir / "group_a_03.png",
        output_dir / "group_a_04.png",
        output_dir / "group_b_02.png",
        output_dir / "group_b_03.png",
    ]
    missing = [str(path) for path in edited_paths if not path.exists()]
    if missing:
        raise FileNotFoundError(f"missing PixelLab result frames: {missing}")

    offsets: list[tuple[int, int]] = []
    for number in range(1, 7):
        source_number = PHASE_ORDER[number - 1]
        tight = Image.open(
            input_dir / f"assassin_walk_e_f{source_number:02d}_pixellab_resize.png"
        ).convert("RGBA")
        normalized = Image.open(
            input_dir / f"assassin_walk_e_f{source_number:02d}_normalized.png"
        ).convert("RGBA")
        tight_box = tight.getbbox()
        normalized_box = normalized.getbbox()
        if tight_box is None or normalized_box is None:
            raise ValueError(f"empty source frame for aligned f{number}")
        offsets.append(
            (normalized_box[0] - tight_box[0], normalized_box[1] - tight_box[1])
        )
    if len(set(offsets)) != 1:
        raise ValueError(f"source normalization offsets differ: {offsets}")
    paste_x, paste_y = offsets[0]

    frames: list[Image.Image] = []
    for number, edited_path in enumerate(edited_paths, start=1):
        edited = Image.open(edited_path).convert("RGBA")
        if edited.size != (133, 192):
            raise ValueError(f"{edited_path.name} has unexpected size {edited.size}")
        frame = Image.new("RGBA", (RUNTIME_CELL, RUNTIME_CELL), (0, 0, 0, 0))
        frame.alpha_composite(edited, (paste_x, paste_y))
        frame.save(output_dir / f"assassin_walk_e_second_dagger_f{number:02d}.png")
        frames.append(frame)

    strip = Image.new(
        "RGBA", (RUNTIME_CELL * len(frames), RUNTIME_CELL), (0, 0, 0, 0)
    )
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * RUNTIME_CELL, 0))
    strip.save(output_dir / f"{stem}_candidate.png")
    _write_qa(
        output_dir,
        stem,
        "Assassin East - PixelLab Two-Dagger Edit",
        frames,
        fps=9.0,
        opposite_contact=4,
    )
    print(f"assembled {stem}; normalization offset={(paste_x, paste_y)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--seed", type=int, default=20260802)
    parser.add_argument("--assemble-only", action="store_true")
    parser.add_argument(
        "--stem",
        default="assassin_walk_e_pixellab_second_dagger_v01",
        help="output stem used by --assemble-only",
    )
    parser.add_argument(
        "--tail-only",
        action="store_true",
        help="submit only aligned frames 5-6 for a stricter rear-hand dagger retry",
    )
    args = parser.parse_args()

    if args.assemble_only:
        _assemble(args.input_dir, args.output_dir, args.stem)
        return

    token = os.environ.get("PIXELLAB_SECRET") or os.environ.get("PIXELLAB_API_TOKEN")
    if not token:
        raise RuntimeError("PIXELLAB_SECRET/PIXELLAB_API_TOKEN is not available")

    frame_payloads: list[dict[str, object]] = []
    sizes: list[tuple[int, int]] = []
    for number in PHASE_ORDER:
        path = args.input_dir / f"assassin_walk_e_f{number:02d}_pixellab_resize.png"
        payload, size = _image_payload(path)
        frame_payloads.append(payload)
        sizes.append(size)
    if len(set(sizes)) != 1:
        raise ValueError(f"input frame sizes differ: {sizes}")
    width, height = sizes[0]

    description = (
        "Add one matching short curved silver dagger to the Assassin's currently "
        "empty REAR hand in every frame. The added dagger's complete silver blade "
        "must be clearly visible as a separate silhouette projecting to the LEFT of "
        "the body, while the existing front-hand dagger remains visible projecting "
        "to the RIGHT. Every frame must visibly show exactly two separate daggers "
        "total, one in each hand; no hidden, sheathed, merged, or overlapping second "
        "dagger. Preserve everything else exactly: the complete six-frame walking "
        "motion and foot positions, anatomy, pose, silhouette, hood shape and cool "
        "charcoal color, cyan eye, armor, burgundy straps, cape, palette, scale, "
        "existing primary dagger, transparency, and pixel-art style. Do not change "
        "the gait, legs, body, costume, expression, camera, or frame order."
    )
    # 192px outputs support four frames per edit.  Overlap the true contacts
    # and loop boundary so the two jobs share temporal identity anchors.
    groups = (
        {"tail_f5_f6": (4, 5)}
        if args.tail_only
        else {
            "a_f1_f4": (0, 1, 2, 3),
            "b_f4_f6_f1": (3, 4, 5, 0),
        }
    )
    results: dict[str, object] = {}
    for name, indices in groups.items():
        body: dict[str, object] = {
            "description": description,
            "frames": [frame_payloads[index] for index in indices],
            "image_size": {"width": width, "height": height},
            "seed": args.seed,
            "no_background": True,
        }
        request = urllib.request.Request(
            ENDPOINT,
            data=json.dumps(body).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                results[name] = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"PixelLab edit-animation {name} HTTP {error.code}: {detail}"
            ) from error

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "submission.json").write_text(
        json.dumps(
            {
                "request": {
                    "description": description,
                    "phase_order": PHASE_ORDER,
                    "groups": groups,
                    "image_size": {"width": width, "height": height},
                    "seed": args.seed,
                },
                "responses": results,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps(results))


if __name__ == "__main__":
    main()
