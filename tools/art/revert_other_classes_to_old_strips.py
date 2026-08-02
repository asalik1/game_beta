"""Restore Archer, Mage, Assassin, and Warlock pre-redesign sprite families.

Every archived source is checksum-validated before use. Current runtime PNGs are
archived with their own SHA-256 manifest, then only the exact source filenames
are replaced. Paladin, Warrior, skins, and class-specific projectile art are
outside the target set by construction.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "game" / "assets" / "sprites"
PASS = ROOT / "art_src" / "class_preservation_upscale_2026-08-01"
ARCHIVE_ROOT = PASS / "runtime_pre_old_design_revert_2026-08-01"

SOURCES = {
    "archer": ROOT
    / "art_src"
    / "archer_severed_thread_ranger_production"
    / "archive_original_runtime_2026-07-31",
    "mage": ROOT / "backup" / "mage_base_pre_blighted_healer_2026-07-31",
    "assassin": ROOT / "backup" / "assassin_base_pre_erased_name_2026-07-31",
    "warlock": ROOT / "backup" / "warlock_base_pre_ledgerbound_debtor_2026-07-31",
}

MANIFESTS = {
    "archer": "SHA256SUMS.txt",
    "mage": "sha256_manifest.json",
    "assassin": "SHA256.csv",
    "warlock": "SHA256.csv",
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def _manifest_entries(class_name: str) -> dict[str, str]:
    root = SOURCES[class_name]
    manifest = root / MANIFESTS[class_name]
    if class_name == "archer":
        entries: dict[str, str] = {}
        for line in manifest.read_text(encoding="ascii").splitlines():
            digest, name = line.strip().split(maxsplit=1)
            entries[name] = digest.upper()
        return entries
    if class_name in ("assassin", "warlock"):
        with manifest.open(newline="", encoding="utf-8-sig") as handle:
            return {
                row["File"]: row["SHA256"].upper()
                for row in csv.DictReader(handle)
            }
    data = json.loads(manifest.read_text(encoding="utf-8-sig"))
    return {item["file"]: item["sha256"].upper() for item in data}


def _validated_sources(class_name: str) -> list[Path]:
    root = SOURCES[class_name]
    sources = sorted(root.glob(f"{class_name}*.png"), key=lambda p: p.name)
    entries = _manifest_entries(class_name)
    source_names = {path.name for path in sources}
    if source_names != set(entries):
        missing = sorted(source_names - set(entries))
        extra = sorted(set(entries) - source_names)
        raise ValueError(
            f"{class_name}: manifest/source mismatch missing={missing}, extra={extra}"
        )
    for source in sources:
        actual = _sha256(source)
        expected = entries[source.name]
        if actual != expected:
            raise ValueError(
                f"{class_name}: checksum mismatch {source.name}: "
                f"expected {expected}, got {actual}"
            )
    return sources


def _archive_runtime(class_name: str, targets: list[Path]) -> Path:
    archive = ARCHIVE_ROOT / class_name
    archive.mkdir(parents=True, exist_ok=True)
    for target in targets:
        archived = archive / target.name
        if not archived.exists():
            shutil.copy2(target, archived)
    lines = [
        f"{_sha256(path)}  {path.name}"
        for path in sorted(archive.glob(f"{class_name}*.png"), key=lambda p: p.name)
    ]
    (archive / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")
    return archive


def _atomic_copy(source: Path, target: Path) -> None:
    temporary = target.with_name(f"{target.stem}.restoring.png")
    shutil.copy2(source, temporary)
    os.replace(temporary, target)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    prepared: dict[str, list[Path]] = {}
    for class_name in ("archer", "mage", "assassin", "warlock"):
        sources = _validated_sources(class_name)
        targets = [SPRITES / source.name for source in sources]
        missing = [target for target in targets if not target.exists()]
        if missing:
            raise FileNotFoundError("missing runtime targets:\n" + "\n".join(map(str, missing)))
        if any(not source.name.startswith(f"{class_name}") for source in sources):
            raise ValueError(f"{class_name}: unsafe source name")
        prepared[class_name] = sources
        unchanged = sum(
            _sha256(source) == _sha256(SPRITES / source.name) for source in sources
        )
        print(
            f"{class_name}: {len(sources)} archived PNGs verified; "
            f"{unchanged} already match, {len(sources) - unchanged} will change"
        )

    if not args.apply:
        print("audit passed; runtime untouched (use --apply to restore)")
        return

    for class_name, sources in prepared.items():
        targets = [SPRITES / source.name for source in sources]
        archive = _archive_runtime(class_name, targets)
        for source, target in zip(sources, targets, strict=True):
            _atomic_copy(source, target)
        for source, target in zip(sources, targets, strict=True):
            if _sha256(source) != _sha256(target):
                raise ValueError(f"post-restore mismatch: {target}")
        print(f"{class_name}: restored {len(sources)} files; prior runtime -> {archive}")

    print("restore complete; Paladin, Warrior, skins, and projectile-only files untouched")


if __name__ == "__main__":
    main()
