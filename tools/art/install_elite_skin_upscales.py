"""Validate and install approved Elite-skin upscale candidates.

The command is a dry run unless ``--apply`` is supplied.  Installation is
atomic per file, archives both desktop and mobile originals, derives legacy
directionless aliases from the south candidate, and keeps both runtimes byte
identical.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


REPO = Path(__file__).resolve().parents[2]
CANDIDATES = REPO / "art_src/elite_skin_upscale_2026-08-10"
ARCHIVE = REPO / "backup/elite_skin_pre_upscale_2026-08-10"
CELL = 352
DIRECTIONS = ("s", "se", "e", "ne", "n", "nw", "w", "sw")


@dataclass(frozen=True)
class Skin:
    key: str
    base: str


SKINS = {
    skin.key: skin
    for skin in (
        Skin("dreadknight", "warrior_dreadknight"),
        Skin("golden_ronin", "assassin_blade_dancer"),
        Skin("eclipse_knight", "paladin_eclipse_knight"),
        Skin("hellfire_inquisitor", "warlock_hellfire_inquisitor"),
    )
}


def _split(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(
        dir=destination.parent, prefix=f".{destination.name}.", suffix=".tmp"
    )
    os.close(handle)
    temporary = Path(temporary_name)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def _discover_clips(base: str) -> list[str]:
    directory = REPO / "game/assets/sprites/skins/elite"
    pattern = re.compile(rf"^{re.escape(base)}_(.+)_s\.png$")
    clips = []
    for path in directory.glob(f"{base}_*_s.png"):
        match = pattern.match(path.name)
        if match:
            clips.append(match.group(1))
    return sorted(set(clips))


def _candidate(skin: Skin, clip: str, direction: str) -> Path:
    return CANDIDATES / skin.key / clip / direction / "candidate.png"


def _validate_strip(candidate: Path, original: Path) -> None:
    if not candidate.exists():
        raise FileNotFoundError(f"missing candidate: {candidate.relative_to(REPO)}")
    with Image.open(candidate) as generated, Image.open(original) as source:
        if generated.mode != "RGBA":
            raise ValueError(f"candidate is not RGBA: {candidate.relative_to(REPO)}")
        if generated.height != CELL or generated.width % CELL:
            raise ValueError(
                f"bad candidate geometry {generated.size}: {candidate.relative_to(REPO)}"
            )
        source_frames = source.width // source.height
        candidate_frames = generated.width // generated.height
        if source.width % source.height or source_frames != candidate_frames:
            raise ValueError(
                f"frame-count drift {source_frames}->{candidate_frames}: "
                f"{candidate.relative_to(REPO)}"
            )
        if generated.getbbox() is None:
            raise ValueError(f"empty candidate: {candidate.relative_to(REPO)}")


def _validate_static(candidate: Path) -> None:
    if not candidate.exists():
        raise FileNotFoundError(f"missing candidate: {candidate.relative_to(REPO)}")
    with Image.open(candidate) as generated:
        if generated.mode != "RGBA" or generated.size != (CELL, CELL):
            raise ValueError(
                f"bad static candidate geometry/mode {generated.size}/{generated.mode}: "
                f"{candidate.relative_to(REPO)}"
            )
        if generated.getbbox() is None:
            raise ValueError(f"empty candidate: {candidate.relative_to(REPO)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skins", default=",".join(SKINS))
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    selected = _split(args.skins)
    unknown = sorted(set(selected) - set(SKINS))
    if unknown:
        raise ValueError(f"unknown skins: {unknown}")

    installs: list[tuple[Path, Path, Path]] = []
    for key in selected:
        skin = SKINS[key]
        game_dir = REPO / "game/assets/sprites/skins/elite"
        static_candidate = _candidate(skin, "static", "s")
        _validate_static(static_candidate)
        for runtime_root in ("game", "mobile/game"):
            destination = REPO / runtime_root / "assets/sprites/skins/elite" / f"{skin.base}.png"
            installs.append((static_candidate, destination, REPO / runtime_root))

        for clip in _discover_clips(skin.base):
            for direction in DIRECTIONS:
                candidate = _candidate(skin, clip, direction)
                original = game_dir / f"{skin.base}_{clip}_{direction}.png"
                _validate_strip(candidate, original)
                for runtime_root in ("game", "mobile/game"):
                    destination = (
                        REPO
                        / runtime_root
                        / "assets/sprites/skins/elite"
                        / f"{skin.base}_{clip}_{direction}.png"
                    )
                    installs.append((candidate, destination, REPO / runtime_root))

            south = _candidate(skin, clip, "s")
            for runtime_root in ("game", "mobile/game"):
                destination = (
                    REPO
                    / runtime_root
                    / "assets/sprites/skins/elite"
                    / f"{skin.base}_{clip}.png"
                )
                installs.append((south, destination, REPO / runtime_root))

    print(f"validated {len(installs)} desktop/mobile installs", flush=True)
    if not args.apply:
        print("dry run only; pass --apply after visual approval", flush=True)
        return

    manifest: list[dict[str, str]] = []
    for source, destination, runtime_root in installs:
        relative = destination.relative_to(runtime_root)
        runtime_name = "mobile" if runtime_root.name == "game" and runtime_root.parent.name == "mobile" else "desktop"
        archived = ARCHIVE / runtime_name / relative
        if not archived.exists():
            _atomic_copy(destination, archived)
        _atomic_copy(source, destination)
        manifest.append(
            {
                "candidate": str(source.relative_to(REPO)).replace("\\", "/"),
                "destination": str(destination.relative_to(REPO)).replace("\\", "/"),
                "sha256": _sha256(destination),
            }
        )

    ARCHIVE.mkdir(parents=True, exist_ok=True)
    manifest_path = ARCHIVE / "install_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"installed {len(installs)} files; manifest={manifest_path.relative_to(REPO)}")


if __name__ == "__main__":
    main()
