"""Read-only approval validation for the optional thirteen-material UI lane.

Upper record shape follows the existing required-upper-approvals.schema.json
(SHA256 f22e10eaeb5081c7578d81d5561b928bcb6d4cd37f035be7d76a33639a3b278c).
No upper-grade approval values live here. Matching files/records is necessary;
the caller's real visual approval receipt remains the approval authority.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
from io import BytesIO
import json
from pathlib import Path, PureWindowsPath
import re

from PIL import Image


UPPER_IDS = (
    "herb_c_verdant_herb", "reagent_c_potent_essence",
    "herb_b_rare_bloom", "reagent_b_pure_essence",
    "herb_a_pristine_bloom", "reagent_a_radiant_essence",
)
# Actual seven accepted approvals; copied from the frozen accepted-seven.json.
EXISTING_PNG_SHA256 = {
    "herb_f_wilted_sprig": "002cde309b10aaa2bb371ea8b8fc33dd2b31f6b8d8b1984555c8809b5f2184e7",
    "reagent_f_foul_residue": "616fe29b361901e9aa73fe5809ea2295e62d260a7541bbe7f5944273a5f9154c",
    "metal_f_rusted_scrap": "ef2d42a90dc14248726c771e4b4f4954ae251c20bf8028acd01184665eeaba31",
    "herb_e_common_weed": "b53be4ebf6967d3cd5956e82aa6dde9c341c75027ef8b26bfda1eaa570e62ebe",
    "herb_d_fresh_herb": "10f87dc1f86f9eee91b1b562b9b6a01cfd8fa0b654d833f75e50ddbf9a9acdbe",
    "reagent_e_crude_extract": "06b5fc7301307d2ecb7df18a21e1a99b9f62ce3558d2b61650d5d4d1595bb9a4",
    "reagent_d_clean_extract": "8947011c48a311a9f5fb600da47b587d3f9098aa149a8f919c322167d49e9446",
}
# Sorted-key, compact JSON SHA of the entire real seven-row ui_export block.
# This preserves its metadata, row order and all source/pixel/file approvals.
EXISTING_CONTRACT_SHA256 = "f0c86ed993699dc368c1e14059128aea18d76474acf48874616782d01ca61543"
UPPER_FIELDS = frozenset((
    "id", "status", "rgba_source", "rgba_source_sha256", "source_canvas",
    "approved_export", "approved_png_sha256", "approved_rgba_sha256",
    "approval_receipt", "approval_receipt_sha256",
))


def _digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _file(root: Path, relative: object, within: Path) -> Path:
    if not isinstance(relative, str) or not relative:
        raise ValueError("Approval paths must be nonempty repository-relative strings")
    given = Path(relative)
    resolved = (root / given).resolve()
    if given.is_absolute() or PureWindowsPath(relative).drive or not resolved.is_relative_to(within.resolve()):
        raise ValueError(f"Approval path escapes its allowed repository directory: {relative}")
    if not resolved.is_file():
        raise ValueError(f"Required approved file is missing: {relative}")
    return resolved


def _verified_bytes(root: Path, row: dict, path_key: str, hash_key: str, within: Path) -> bytes:
    expected = row[hash_key]
    if not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None:
        raise ValueError(f"A real SHA256 is required for {row['id']} / {hash_key}")
    raw = _file(root, row[path_key], within).read_bytes()
    if _digest(raw) != expected:
        raise ValueError(f"Approved file hash differs: {row['id']} / {path_key}")
    return raw


def validate_upper_approvals(payload: object, *, root: Path, source_root: Path) -> list[dict]:
    """Validate the exact existing {assets:[six rows]} schema and actual files.

    Returns detached records in their supplied order. Reads only; no exports,
    writes, synthesis of hashes, or inference of approval from generated art.
    """
    if not isinstance(payload, dict) or set(payload) != {"assets"}:
        raise ValueError("Upper approvals must contain only the required assets array")
    rows = payload["assets"]
    if not isinstance(rows, list) or len(rows) != 6:
        raise ValueError("Exactly six real approved C/B/A records are required")
    ids = []
    for row in rows:
        if not isinstance(row, dict) or set(row) != UPPER_FIELDS:
            raise ValueError("Upper record fields must match required-upper-approvals.schema.json exactly")
        if row["id"] not in UPPER_IDS or row["status"] != "approved":
            raise ValueError("Upper material id/status is not an approved C/B/A identity")
        ids.append(row["id"])
        dims = row["source_canvas"]
        if not isinstance(dims, list) or len(dims) != 2 or any(type(v) is not int or v < 1 for v in dims) or dims[0] != dims[1]:
            raise ValueError(f"Expected a positive square full source canvas: {row['id']}")
        expected_rgba = row["approved_rgba_sha256"]
        if not isinstance(expected_rgba, str) or re.fullmatch(r"[0-9a-f]{64}", expected_rgba) is None:
            raise ValueError(f"A real decoded RGBA SHA256 is required: {row['id']}")
    if len(set(ids)) != 6 or set(ids) != set(UPPER_IDS):
        raise ValueError("Upper approvals must name each of the six C/B/A identities exactly once")
    # Validate the whole schema before reading any source; validate every file
    # before returning rows to the builder or native QA preparation.
    for row in rows:
        source = _verified_bytes(root, row, "rgba_source", "rgba_source_sha256", source_root)
        exported = _verified_bytes(root, row, "approved_export", "approved_png_sha256", root)
        _verified_bytes(root, row, "approval_receipt", "approval_receipt_sha256", root)
        with Image.open(BytesIO(source)) as image:
            if image.mode != "RGBA" or list(image.size) != row["source_canvas"]:
                raise ValueError(f"Approved source is not its recorded RGBA canvas: {row['id']}")
            lo, hi = image.getchannel("A").getextrema()
            if lo != 0 or hi <= 128:
                raise ValueError(f"Source needs transparent space and a visible subject: {row['id']}")
        with Image.open(BytesIO(exported)) as image:
            if image.format != "PNG" or image.mode != "RGBA" or image.size != (128, 128):
                raise ValueError(f"Reviewed export must be a 128px RGBA PNG: {row['id']}")
            if _digest(image.tobytes()) != row["approved_rgba_sha256"]:
                raise ValueError(f"Reviewed export decoded pixels differ: {row['id']}")
    return deepcopy(rows)


def select_all_brewing(provenance: dict, *, root: Path, source_root: Path) -> list[dict]:
    """Select unchanged seven plus exactly six verified real approval records."""
    existing = provenance.get("ui_export")
    raw = json.dumps(existing, sort_keys=True, separators=(",", ":")).encode("utf-8")
    if _digest(raw) != EXISTING_CONTRACT_SHA256:
        raise ValueError("The entire accepted seven-row ui_export contract must remain unchanged")
    upper = provenance.get("ui_export_upper_brewing")
    if not isinstance(upper, dict):
        raise ValueError("--all-brewing requires ui_export_upper_brewing with six real external approvals; none may be invented")
    if upper.get("canvas") != [128, 128] or upper.get("processing") != existing["processing"]:
        raise ValueError("Upper export must retain the 128px full-canvas processing contract")
    rows = validate_upper_approvals({"assets": upper.get("assets")}, root=root, source_root=source_root)
    return deepcopy(existing["assets"]) + rows


def verify_existing_seven(directory: Path) -> None:
    """Read current runtime bytes; the optional lane never rewrites these files."""
    for name, expected in EXISTING_PNG_SHA256.items():
        path = directory / (name + ".png")
        if not path.resolve().is_relative_to(directory.resolve()) or not path.is_file() or _digest(path.read_bytes()) != expected:
            raise ValueError(f"An accepted existing material PNG changed or is missing: {name}")


def new_install_rows(directory: Path, built: list[dict]) -> list[dict]:
    """Preflight all thirteen bytes/targets; return only absent new six paths."""
    ids = [row["id"] for row in built]
    if len(ids) != 13 or set(ids) != set(EXISTING_PNG_SHA256) | set(UPPER_IDS):
        raise ValueError("All-brewing installation requires exactly thirteen identities")
    if any(row["filename"] != row["id"] + ".png" for row in built):
        raise ValueError("Material install filenames must match their exact approved identities")
    if any(not row["approved_png_bytes_match"] for row in built):
        raise ValueError("All-brewing installation requires all thirteen exact approved PNG encodings")
    verify_existing_seven(directory)
    missing = []
    for row in built:
        if row["id"] not in UPPER_IDS:
            continue
        path = directory / row["filename"]
        if not path.resolve().is_relative_to(directory.resolve()):
            raise ValueError(f"Install target points outside its destination: {path}")
        if path.is_symlink() and not path.exists():
            raise ValueError(f"Broken install target symlink: {path}")
        if path.exists():
            if not path.is_file() or _digest(path.read_bytes()) != row["approved_png_sha256"]:
                raise ValueError(f"Refusing to overwrite an existing upper material: {row['id']}")
        else:
            missing.append(row)
    return missing
