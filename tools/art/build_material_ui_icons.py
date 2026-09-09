"""Export approved painted material UI icons from archived RGBA sources.

Default: build/material_ui_icons (candidates and a hash report).
--output DIR selects another candidate directory. --install additionally writes
only the approved PNGs to game/assets/icons/materials_ui. No mobile writes.
"""
from __future__ import annotations

import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re

import numpy as np
import PIL
from PIL import Image

from build_gear_codex_icons import _resize_premultiplied


ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = ROOT / "art_src/materials_painted_2026-09-09"
PROVENANCE = SOURCE_ROOT / "provenance.json"
DEFAULT_OUTPUT = ROOT / "build/material_ui_icons"
INSTALL_DIR = ROOT / "game/assets/icons/materials_ui"
CANVAS = 128


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if Path(relative).is_absolute() or not path.is_relative_to(SOURCE_ROOT.resolve()):
        raise ValueError(f"RGBA source must be a repository-relative archived source: {relative}")
    return path


def candidate_directory(path: Path) -> Path:
    path = path.resolve()
    for protected in (ROOT / "game", ROOT / "mobile", ROOT / "art_src"):
        if path.is_relative_to(protected.resolve()):
            raise ValueError("--output must be outside game, mobile and art_src; use --install for runtime PNGs")
    return path


def build() -> list[dict]:
    """Validate and render the whole approved manifest before writing anything."""
    contract = json.loads(PROVENANCE.read_text(encoding="utf-8"))["ui_export"]
    if contract["canvas"] != [CANVAS, CANVAS]:
        raise ValueError("Material UI export contract must remain 128 square")
    rows = contract["assets"]
    if not rows:
        raise ValueError("No approved material sources")
    built = []
    seen = set()
    for row in rows:
        name = row["id"]
        if not re.fullmatch(r"[a-z][a-z0-9_]*", name) or name in seen:
            raise ValueError(f"Invalid or repeated material id: {name}")
        seen.add(name)
        source = source_path(row["rgba_source"])
        raw = source.read_bytes()
        if digest(raw) != row["rgba_source_sha256"]:
            raise ValueError(f"Archived source hash differs from approval: {row['rgba_source']}")
        with Image.open(BytesIO(raw)) as image:
            if image.mode != "RGBA" or list(image.size) != row["source_canvas"]:
                raise ValueError(f"Expected approved RGBA canvas for {name}, got {image.mode} {image.size}")
            if image.width != image.height:
                raise ValueError(f"Expected square full canvas for {name}; do not stretch or crop a new source")
            alpha = np.asarray(image.getchannel("A"))
            if not np.any(alpha == 0) or not np.any(alpha > 128):
                raise ValueError(f"Expected visible subject and true transparent space for {name}")
            # Keep every source pixel in its authored position. In particular,
            # sparse alpha dust must never become a crop/scale normalization box.
            result = _resize_premultiplied(image, (CANVAS, CANVAS))
        pixel_hash = digest(result.tobytes())
        if pixel_hash != row["approved_rgba_sha256"]:
            raise ValueError(f"Rebuilt RGBA differs from the approved export: {name}; review before updating approval")
        stream = BytesIO()
        result.save(stream, format="PNG")
        png = stream.getvalue()
        png_hash = digest(png)
        built.append(dict(id=name, filename=name + ".png", png=png,
                          rgba_source=row["rgba_source"], rgba_source_sha256=digest(raw),
                          canvas=[CANVAS, CANVAS], rgba_sha256=pixel_hash, png_sha256=png_hash,
                          approved_png_sha256=row["approved_png_sha256"],
                          approved_png_bytes_match=png_hash == row["approved_png_sha256"]))
    return built


def validate_targets(directory: Path, filenames: list[str]) -> None:
    # Prevent an existing per-file symlink from redirecting a candidate write.
    for name in filenames:
        if not (directory / name).resolve().is_relative_to(directory.resolve()):
            raise ValueError(f"Output file points outside its destination: {directory / name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Candidate PNG/report directory")
    parser.add_argument("--install", action="store_true", help="Also install approved PNGs to game/assets/icons/materials_ui")
    args = parser.parse_args()
    try:
        output = candidate_directory(args.output)
        built = build()
        filenames = [row["filename"] for row in built]
        validate_targets(output, filenames + ["export-report.json"])
        if args.install:
            # Unlike --output, the install destination cannot be selected or
            # redirected to the mobile mirror/source archive by a directory link.
            if INSTALL_DIR.resolve() != ROOT.resolve() / "game/assets/icons/materials_ui":
                raise ValueError("Install directory must resolve to game/assets/icons/materials_ui")
            validate_targets(INSTALL_DIR, filenames)
        output.mkdir(parents=True, exist_ok=True)
        for row in built:
            (output / row["filename"]).write_bytes(row["png"])
        report = dict(provenance=PROVENANCE.relative_to(ROOT).as_posix(),
                      processing="Full canvas to 128 square; existing premultiplied LANCZOS only",
                      resize_helper="tools/art/build_gear_codex_icons.py:_resize_premultiplied",
                      resize_helper_sha256=digest((ROOT / "tools/art/build_gear_codex_icons.py").read_bytes()),
                      pillow=PIL.__version__, numpy=np.__version__,
                      assets=[{k: v for k, v in row.items() if k != "png"} for row in built])
        (output / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        if args.install:
            INSTALL_DIR.mkdir(parents=True, exist_ok=True)
            for row in built:
                (INSTALL_DIR / row["filename"]).write_bytes(row["png"])
        encoding_changes = sum(not row["approved_png_bytes_match"] for row in built)
        print(f"Built {len(built)} approved 128px RGBA material icons in {output}")
        if encoding_changes:
            print(f"{encoding_changes} PNG encodings differ; decoded RGBA still matches approved pixels exactly")
        if args.install:
            print(f"Installed {len(built)} PNGs in {INSTALL_DIR}; mobile synchronization is separate")
    except (KeyError, OSError, TypeError, ValueError) as exc:
        parser.exit(1, f"Material icon export failed: {exc}\n")


if __name__ == "__main__":
    main()
