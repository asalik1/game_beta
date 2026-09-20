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



GEAR_IDS = frozenset(("bone_f_cracked_bone", "cloth_f_frayed_scraps"))
GEAR_SOURCE_ROOT = ROOT / "art_src/materials_painted_2026-09-20"


def build_gear_pilots(approval_path: Path) -> tuple[list[dict], dict]:
    """Two source/export approvals permit a native trial, never imply acceptance."""
    approval_path = approval_path.resolve()
    if not approval_path.is_relative_to(GEAR_SOURCE_ROOT.resolve()):
        raise ValueError("Pilot approvals must be archived under art_src/materials_painted_2026-09-20")
    raw = approval_path.read_bytes()
    contract = json.loads(raw)
    rows = contract["assets"]
    if contract.get("mode") != "gear-pilots" or contract.get("canvas") != [128, 128]:
        raise ValueError("Expected gear-pilots /128-square approval contract")
    if len(rows) != 2 or {row["id"] for row in rows} != GEAR_IDS:
        raise ValueError("Pilot approvals must contain exactly Bone F and Cloth F")
    # Reuse established approval identities, not current files as their oracle.
    from material_ui_approvals import select_all_brewing
    previous = select_all_brewing(json.loads(PROVENANCE.read_bytes()), root=ROOT, source_root=SOURCE_ROOT)
    if len(previous) != 13:
        raise ValueError("Existing thirteen approvals missing")
    preserved = {}
    for row in previous:
        p = INSTALL_DIR / (row["id"] + ".png")
        if digest(p.read_bytes()) != row["approved_png_sha256"]:
            raise ValueError("Previously approved UI PNG changed: " + row["id"])
        preserved[p.relative_to(ROOT).as_posix()] = digest(p.read_bytes())
    worlds = sorted((ROOT / "game/assets/icons/materials").glob("*.png"))
    if len(worlds) != 35:
        raise ValueError("Expected35 unchanged world controls")
    for p in worlds:
        preserved[p.relative_to(ROOT).as_posix()] = digest(p.read_bytes())
    built = []
    for row in rows:
        if row.get("approved_for_native_trial") is not True or not row.get("reviews"):
            raise ValueError("Actual source/export review required before trial")
        for review in row["reviews"]:
            review_path = (ROOT / review["path"]).resolve()
            if Path(review["path"]).is_absolute() or not review_path.is_relative_to(ROOT.resolve()):
                raise ValueError("Review evidence must stay within repository")
            if digest(review_path.read_bytes()) != review["sha256"]:
                raise ValueError("Source review evidence hash mismatch")
        source = (ROOT / row["rgba_source"]).resolve()
        if Path(row["rgba_source"]).is_absolute() or not source.is_relative_to(GEAR_SOURCE_ROOT.resolve()):
            raise ValueError("Pilot source must stay in the September20 archive")
        source_bytes = source.read_bytes()
        if digest(source_bytes) != row["rgba_source_sha256"]:
            raise ValueError("Pilot source hash mismatch")
        with Image.open(BytesIO(source_bytes)) as image:
            if image.mode != "RGBA" or list(image.size) != row["source_canvas"] or image.width != image.height:
                raise ValueError("Pilot must use approved square RGBA source")
            alpha = np.asarray(image.getchannel("A"))
            if not np.any(alpha == 0) or not np.any(alpha > 128):
                raise ValueError("Pilot requires transparent background and visible subject")
            result = _resize_premultiplied(image, (CANVAS, CANVAS))
        rgba = digest(result.tobytes())
        stream = BytesIO()
        result.save(stream, format="PNG")
        png = stream.getvalue()
        if rgba != row["approved_rgba_sha256"] or digest(png) != row["approved_png_sha256"]:
            raise ValueError("Pilot export differs from reviewed RGBA/PNG")
        built.append(dict(id=row["id"], filename=row["id"] + ".png", png=png,
                          rgba_source=row["rgba_source"], rgba_source_sha256=digest(source_bytes),
                          canvas=[CANVAS, CANVAS], rgba_sha256=rgba, png_sha256=digest(png),
                          approved_png_sha256=row["approved_png_sha256"], approved_png_bytes_match=True))
    if approval_path.read_bytes() != raw:
        raise ValueError("Pilot approvals changed during validation")
    return built, dict(path=approval_path.relative_to(ROOT).as_posix(), sha256=digest(raw),
                       contract=contract, preserved=preserved, native_acceptance=False)


def gear_preserved_check(preserved: dict) -> None:
    for relative, expected in preserved.items():
        if digest((ROOT / relative).read_bytes()) != expected:
            raise ValueError("Existing material bytes changed: " + relative)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Candidate PNG/report directory")
    parser.add_argument("--install", action="store_true", help="Also install approved PNGs to game/assets/icons/materials_ui")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--grade-pairs", action="store_true", help="Require the approved three F plus four E/D sibling manifest; missing approvals fail before output")
    mode.add_argument("--all-brewing", action="store_true", help="Require unchanged seven plus six externally approved C/B/A records; fresh output and no runtime overwrites")
    mode.add_argument("--gear-pilots", action="store_true", help="Exactly two reviewed BoneF/ClothF UI additions; preserve existing13/world35")
    parser.add_argument("--pilot-approvals", type=Path, help="Archived two-pilot source/export approval JSON")
    args = parser.parse_args()
    try:
        if args.gear_pilots != (args.pilot_approvals is not None):
            raise ValueError("Use --gear-pilots and --pilot-approvals together")
        output = candidate_directory(args.output)
        provenance_raw = PROVENANCE.read_bytes() if args.all_brewing else None
        if (args.all_brewing or args.gear_pilots) and (args.output.is_symlink() or output.exists()):
            raise ValueError("--all-brewing /--gear-pilots requires a fresh candidate output directory")
        gear_record = None
        if args.gear_pilots:
            built, gear_record = build_gear_pilots(args.pilot_approvals)
        else:
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
            if args.gear_pilots:
                install_rows = []
                for row in built:
                    target = INSTALL_DIR / row["filename"]
                    if target.exists():
                        if target.read_bytes() != row["png"]:
                            raise ValueError("Refusing different existing pilot: " + row["id"])
                    else:
                        install_rows.append(row)
        if gear_record:
            gear_preserved_check(gear_record["preserved"])
        output.mkdir(parents=True, exist_ok=not (args.all_brewing or args.gear_pilots))
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
        if gear_record:
            report.update(mode="gear-pilots", approval=gear_record, selected_ids=sorted(GEAR_IDS),
                          planned_new_install_ids=[row["id"] for row in install_rows] if args.install else [])
        (output / "export-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        if args.install:
            INSTALL_DIR.mkdir(parents=True, exist_ok=True)
            for row in install_rows:
                path = INSTALL_DIR / row["filename"]
                if args.all_brewing or args.gear_pilots:
                    # Preflight covered all targets. Exclusive creation also
                    # prevents a later file from being overwritten in a race.
                    with path.open("xb") as target:
                        target.write(row["png"])
                else:
                    path.write_bytes(row["png"])
        if gear_record:
            gear_preserved_check(gear_record["preserved"])
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
