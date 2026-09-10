"""Export approved painted material UI icons from archived RGBA sources.

Default: build/material_ui_icons (candidates and a hash report).
--output DIR selects another candidate directory. --install additionally writes
only the approved PNGs to game/assets/icons/materials_ui. No mobile writes.
--all-brewing additionally requires six real C/B/A approval records, fresh
candidate output, and leaves every existing runtime PNG untouched.
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

# Optional acceptance mode for the reviewed F family plus planned E/D pairs.
F_PNG_SHA256 = {'herb_f_wilted_sprig': '002cde309b10aaa2bb371ea8b8fc33dd2b31f6b8d8b1984555c8809b5f2184e7', 'reagent_f_foul_residue': '616fe29b361901e9aa73fe5809ea2295e62d260a7541bbe7f5944273a5f9154c', 'metal_f_rusted_scrap': 'ef2d42a90dc14248726c771e4b4f4954ae251c20bf8028acd01184665eeaba31'}
GRADE_PAIR_IDS = frozenset(F_PNG_SHA256) | frozenset(['herb_e_common_weed', 'reagent_e_crude_extract', 'herb_d_fresh_herb', 'reagent_d_clean_extract'])


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


def build(*, grade_pairs: bool = False, all_brewing: bool = False) -> list[dict]:
    """Validate and render the whole approved manifest before writing anything."""
    if grade_pairs and all_brewing:
        raise ValueError("--grade-pairs and --all-brewing are separate selection modes")
    provenance = json.loads(PROVENANCE.read_text(encoding="utf-8"))
    contract = provenance["ui_export"]
    if contract["canvas"] != [CANVAS, CANVAS]:
        raise ValueError("Material UI export contract must remain 128 square")
    rows = contract["assets"]
    if all_brewing:
        from material_ui_approvals import select_all_brewing
        rows = select_all_brewing(provenance, root=ROOT, source_root=SOURCE_ROOT)
    if not rows:
        raise ValueError("No approved material sources")
    if grade_pairs:
        ids = [row["id"] for row in rows]
        if len(ids) != 7 or set(ids) != GRADE_PAIR_IDS:
            raise ValueError("--grade-pairs requires exactly the three approved F and four approved E/D manifest rows; pending sources are not approval")
        for row in rows:
            if row["id"] in F_PNG_SHA256 and row["approved_png_sha256"] != F_PNG_SHA256[row["id"]]:
                raise ValueError("The three accepted F PNG approvals must remain unchanged")
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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--grade-pairs", action="store_true", help="Require the approved three F plus four E/D sibling manifest; missing approvals fail before output")
    mode.add_argument("--all-brewing", action="store_true", help="Require unchanged seven plus six externally approved C/B/A records; fresh output and no runtime overwrites")
    args = parser.parse_args()
    try:
        output = candidate_directory(args.output)
        provenance_raw = PROVENANCE.read_bytes() if args.all_brewing else None
        if args.all_brewing and (args.output.is_symlink() or output.exists()):
            raise ValueError("--all-brewing requires a fresh candidate output directory")
        built = build(grade_pairs=args.grade_pairs, all_brewing=args.all_brewing)
        if args.all_brewing and PROVENANCE.read_bytes() != provenance_raw:
            raise ValueError("Approval provenance changed during validation; no output written")
        filenames = [row["filename"] for row in built]
        validate_targets(output, filenames + ["export-report.json"])
        install_rows = built
        if args.all_brewing:
            from material_ui_approvals import verify_existing_seven, new_install_rows
            if INSTALL_DIR.resolve() != ROOT.resolve() / "game/assets/icons/materials_ui":
                raise ValueError("Existing icons must resolve to game/assets/icons/materials_ui")
            verify_existing_seven(INSTALL_DIR)
        if args.install:
            if args.grade_pairs and any(not row["approved_png_bytes_match"] for row in built):
                raise ValueError("Grade-pair installation requires exact approved PNG bytes; keep the accepted F files byte-stable")
            # Unlike --output, the install destination cannot be selected or
            # redirected to the mobile mirror/source archive by a directory link.
            if INSTALL_DIR.resolve() != ROOT.resolve() / "game/assets/icons/materials_ui":
                raise ValueError("Install directory must resolve to game/assets/icons/materials_ui")
            validate_targets(INSTALL_DIR, filenames)
            if args.all_brewing:
                install_rows = new_install_rows(INSTALL_DIR, built)
        output.mkdir(parents=True, exist_ok=not args.all_brewing)
        for row in built:
            (output / row["filename"]).write_bytes(row["png"])
        report = dict(provenance=PROVENANCE.relative_to(ROOT).as_posix(),
                      processing="Full canvas to 128 square; existing premultiplied LANCZOS only",
                      resize_helper="tools/art/build_gear_codex_icons.py:_resize_premultiplied",
                      resize_helper_sha256=digest((ROOT / "tools/art/build_gear_codex_icons.py").read_bytes()),
                      pillow=PIL.__version__, numpy=np.__version__,
                      assets=[{k: v for k, v in row.items() if k != "png"} for row in built])
        if args.all_brewing:
            approved = json.loads(provenance_raw)
            report.update(mode="all-brewing", provenance_sha256=digest(provenance_raw),
                          provenance_blocks={key: approved[key] for key in ("ui_export", "ui_export_upper_brewing")},
                          selected_ids=[row["id"] for row in built],
                          planned_new_install_ids=[row["id"] for row in install_rows] if args.install else [],
                          existing_seven_untouched=True)
        (output / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        if args.install:
            INSTALL_DIR.mkdir(parents=True, exist_ok=True)
            for row in install_rows:
                path = INSTALL_DIR / row["filename"]
                if args.all_brewing:
                    # Preflight covered all targets. Exclusive creation also
                    # prevents a later file from being overwritten in a race.
                    with path.open("xb") as target:
                        target.write(row["png"])
                else:
                    path.write_bytes(row["png"])
        encoding_changes = sum(not row["approved_png_bytes_match"] for row in built)
        print(f"Built {len(built)} approved 128px RGBA material icons in {output}")
        if encoding_changes:
            print(f"{encoding_changes} PNG encodings differ; decoded RGBA still matches approved pixels exactly")
        if args.install:
            print(f"Installed {len(install_rows)} PNGs in {INSTALL_DIR}; mobile synchronization is separate")
    except (KeyError, OSError, TypeError, ValueError) as exc:
        parser.exit(1, f"Material icon export failed: {exc}\n")


if __name__ == "__main__":
    main()
