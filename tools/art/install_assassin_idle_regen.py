#!/usr/bin/env python3
"""Build and install the approved full-regeneration Assassin idle set."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

from build_preservation_walk_candidate import _font, _shown, _write_qa


ROOT = Path(__file__).resolve().parents[2]
CELL = 277
FRAMES = 4
BASE = (
    ROOT
    / "art_src/class_preservation_upscale_2026-08-01/assassin"
    / "idle_regen_2026-08-02"
)
FINAL = BASE / "final"
BACKUP = FINAL / "runtime_pre_full_idle_regen_2026-08-02"
GAME = ROOT / "game/assets/sprites"
MOBILE = ROOT / "mobile/game/assets/sprites"
SOURCE = {
    "s": BASE / "south/assassin_idle_s_regen_v01_candidate.png",
    "se": BASE / "southeast/assassin_idle_se_regen_v01_candidate.png",
    "e": BASE / "east/assassin_idle_e_regen_v01_candidate.png",
    "ne": BASE / "northeast/assassin_idle_ne_regen_v01_candidate.png",
    "n": BASE / "north/assassin_idle_n_regen_v01_candidate.png",
}
MIRROR_OF = {"nw": "ne", "w": "e", "sw": "se"}
ORDER = ("s", "se", "e", "ne", "n", "nw", "w", "sw")


def _load(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != (CELL * FRAMES, CELL):
        raise ValueError(f"{path}: expected {(CELL * FRAMES, CELL)}, got {image.size}")
    for index in range(FRAMES):
        frame = image.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        box = frame.getbbox()
        if box is None:
            raise ValueError(f"{path}: empty frame {index + 1}")
        height = box[3] - box[1]
        if not 178 <= height <= 182:
            raise ValueError(f"{path}: frame {index + 1} body height {height}")
        if frame.getchannel("A").getextrema() not in ((0, 255), (255, 255)):
            raise ValueError(f"{path}: frame {index + 1} has soft alpha")
    return image


def _mirror(strip: Image.Image) -> Image.Image:
    output = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for index in range(FRAMES):
        frame = strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        output.alpha_composite(ImageOps.mirror(frame), (index * CELL, 0))
    return output


def _copy_if_changed(source: Path, target: Path) -> None:
    payload = source.read_bytes()
    if target.exists() and target.read_bytes() == payload:
        return
    temporary = target.with_name(f"{target.stem}.codex-tmp{target.suffix}")
    temporary.write_bytes(payload)
    os.replace(temporary, target)


def _write_overview(strips: dict[str, Image.Image]) -> None:
    cell, header, columns = 200, 30, 4
    pages: list[Image.Image] = []
    for frame_index in range(FRAMES):
        page = Image.new("RGBA", (cell * columns, (cell + header) * 2), (25, 28, 34, 255))
        draw = ImageDraw.Draw(page)
        for index, direction in enumerate(ORDER):
            x = (index % columns) * cell
            y = (index // columns) * (cell + header)
            draw.text((x + 8, y + 5), direction.upper(), font=_font(16), fill=(255, 224, 126, 255))
            frame = strips[direction].crop(
                (frame_index * CELL, 0, (frame_index + 1) * CELL, CELL)
            )
            page.alpha_composite(_shown(frame, 160, cell), (x, y + header))
        pages.append(page)
    pages[0].save(FINAL / "assassin_idle_full_regen_8dir_contact.png")
    paletted = [page.convert("P", palette=Image.Palette.ADAPTIVE) for page in pages]
    paletted[0].save(
        FINAL / "assassin_idle_full_regen_8dir_6fps.gif",
        save_all=True,
        append_images=paletted[1:],
        duration=[160, 170, 170, 170],
        loop=0,
        disposal=2,
    )


def main() -> None:
    FINAL.mkdir(parents=True, exist_ok=True)
    strips = {direction: _load(path) for direction, path in SOURCE.items()}
    strips.update(
        {direction: _mirror(strips[source]) for direction, source in MIRROR_OF.items()}
    )

    candidates: dict[str, Path] = {}
    for direction in ORDER:
        path = FINAL / f"assassin_idle_{direction}_full_regen_candidate.png"
        strips[direction].save(path)
        candidates[direction] = path
        frames = [
            strips[direction].crop((index * CELL, 0, (index + 1) * CELL, CELL))
            for index in range(FRAMES)
        ]
        _write_qa(
            FINAL,
            f"assassin_idle_{direction}_full_regen",
            f"Assassin {direction.upper()} Idle - Full Regen",
            frames,
            fps=6.0,
            opposite_contact=3,
        )
    _write_overview(strips)

    runtime_sources = {direction: candidates[direction] for direction in ORDER}
    runtime_sources[""] = candidates["s"]
    for runtime_dir in (GAME, MOBILE):
        backup_dir = BACKUP / runtime_dir.relative_to(ROOT)
        backup_dir.mkdir(parents=True, exist_ok=True)
        for direction, source in runtime_sources.items():
            suffix = f"_{direction}" if direction else ""
            target = runtime_dir / f"assassin_anim{suffix}.png"
            backup = backup_dir / target.name
            if target.exists() and not backup.exists():
                shutil.copy2(target, backup)
            _copy_if_changed(source, target)

    for runtime_dir in (GAME, MOBILE):
        assert (runtime_dir / "assassin_anim.png").read_bytes() == candidates["s"].read_bytes()
        for direction in ORDER:
            target = runtime_dir / f"assassin_anim_{direction}.png"
            assert target.read_bytes() == candidates[direction].read_bytes()
    print("installed full Assassin idle regen in game + mobile")


if __name__ == "__main__":
    main()
