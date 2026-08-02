"""Build the approved Emberbound Heir playable-Warrior sprite family.

The built-in ImageGen masters live in
``art_src/warrior_emberbound_heir_production``.  This builder keys the green
backdrop, slices the generator's real gutters, selects approved safety-source
frames, normalizes every timeline without erasing authored motion, mirrors the
approved east half into W/SW/NW, and installs the exact legacy Warrior runtime
filename contract.

Run from the repository root:

    python tools/art/build_emberbound_warrior.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
ART_SRC = Path(
    os.environ.get(
        "CROWNLESS_ART_SRC",
        ROOT / "art_src" / "warrior_emberbound_heir_production",
    )
)
OUT_DIR = Path(
    os.environ.get(
        "CROWNLESS_GAME_SPRITES",
        ROOT / "game" / "assets" / "sprites",
    )
)
QA_DIR = ART_SRC / "qa"
DIRS = ("s", "se", "e", "ne", "n")
DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
EXPECTED_FRAMES = {
    "warrior_anim": 4,
    "warrior_walk": 6,
    "warrior_run": 6,
    "warrior_attack": 7,
    "warrior_attack2": 7,
    "warrior_dash": 7,
    "warrior_ult": 7,
    "warrior_ultidle": 4,
    "warrior_death": 9,
}
QA_FPS = {
    "anim": 6,
    "walk": 9,
    "run": 11,
    "attack": 22,
    "attack2": 22,
    "dash": 26,
    "ult": 11,
    "ultidle": 6,
    "death": 9,
}


# The Paladin regeneration established the repository's vetted chroma removal,
# real-gutter slicing, fixed-reference normalization, and staging geometry.
# Reuse those deterministic primitives rather than maintaining a divergent
# second implementation.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_oathbound_paladin as shared
import install_dirset


def _component_row(
    image: Image.Image, columns: int, bridge_size: int = 5
) -> list[Image.Image]:
    """Isolate whole generated figures instead of cutting through long swords.

    Several otherwise-approved Warrior strips have diagonally held blades
    whose X ranges overlap the next pose even though their silhouettes remain
    separated by green.  A vertical gutter cut assigns the preceding sword tip
    to the following frame.  Label the connected silhouettes on a lightly
    dilated half-resolution mask, then use each label as an isolation mask.
    """

    rgba = image.convert("RGBA")
    alpha = np.asarray(rgba.getchannel("A"), dtype=np.uint8) > 0
    if bridge_size < 1 or bridge_size % 2 == 0:
        raise ValueError("bridge_size must be a positive odd integer")
    bridge = Image.fromarray(alpha.astype(np.uint8) * 255)
    if bridge_size > 1:
        bridge = bridge.filter(ImageFilter.MaxFilter(bridge_size))
    bridged = np.asarray(bridge, dtype=np.uint8) > 0
    height, width = bridged.shape
    pooled_h = (height + 1) // 2
    pooled_w = (width + 1) // 2
    padded = np.pad(
        bridged,
        ((0, pooled_h * 2 - height), (0, pooled_w * 2 - width)),
        constant_values=False,
    )
    pooled = padded.reshape(pooled_h, 2, pooled_w, 2).max(axis=(1, 3))

    labels = np.zeros(pooled.shape, dtype=np.int32)
    components: list[tuple[int, int, int]] = []
    label = 0
    for start_y, start_x in zip(*np.where(pooled)):
        if labels[start_y, start_x] != 0:
            continue
        label += 1
        labels[start_y, start_x] = label
        queue = [(int(start_y), int(start_x))]
        min_x = int(start_x)
        pixels = 0
        for y, x in queue:
            pixels += 1
            min_x = min(min_x, x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    ny, nx = y + dy, x + dx
                    if (
                        0 <= ny < pooled_h
                        and 0 <= nx < pooled_w
                        and pooled[ny, nx]
                        and labels[ny, nx] == 0
                    ):
                        labels[ny, nx] = label
                        queue.append((ny, nx))
        if pixels >= 20:
            components.append((pixels, min_x, label))

    if len(components) < columns:
        raise ValueError(
            f"expected at least {columns} connected poses, found {len(components)}"
        )
    selected = sorted(
        sorted(components, reverse=True)[:columns],
        key=lambda component: component[1],
    )
    source = np.asarray(rgba, dtype=np.uint8)
    frames: list[Image.Image] = []
    for _, _, component_label in selected:
        coarse = labels == component_label
        mask = np.repeat(np.repeat(coarse, 2, axis=0), 2, axis=1)[
            :height, :width
        ]
        isolated = source.copy()
        isolated[~mask, :] = 0
        frames.append(Image.fromarray(isolated, "RGBA"))
    return frames


def _component_grid(path: str, rows: int, columns: int) -> list[list[Image.Image]]:
    image = shared._remove_green(Image.open(ART_SRC / path).convert("RGBA"))
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 0
    edges = shared._valley_separators(alpha, rows, axis=0)
    return [
        _component_row(image.crop((0, edges[row], image.width, edges[row + 1])), columns)
        for row in range(rows)
    ]


def _rows(path: str, row_count: int, columns: int) -> dict[str, list[Image.Image]]:
    return {
        suffix: frames
        for suffix, frames in zip(
            DIRS,
            _component_grid(path, row_count, columns),
            strict=True,
        )
    }


def _strip(path: str, columns: int, keep: int | None = None) -> list[Image.Image]:
    frames = _component_grid(path, 1, columns)[0]
    return frames[:keep] if keep is not None else frames


def _load_clips() -> dict[str, dict[str, list[Image.Image]]]:
    clips: dict[str, dict[str, list[Image.Image]]] = {}

    idle = _rows("idle_v01_keyed.png", 5, 4)
    # The combined sheet hid the profile and rear swords.  These complete
    # direction-locked strips replace the whole timelines.
    idle["e"] = _strip("idle_e_repair_v01_keyed.png", 4)
    idle["n"] = _strip("idle_n_repair_v01_keyed_5source.png", 5, 4)
    clips["warrior_anim"] = idle

    clips["warrior_walk"] = {
        "s": _strip("walk_s_v01_keyed.png", 6),
        "se": _strip("walk_se_v01_keyed.png", 6),
        "e": _strip("walk_e_v02_keyed.png", 6),
        "ne": _strip("walk_ne_v01_keyed.png", 6),
        # The seventh generated figure is a disposable outer-edge safety pose.
        "n": _strip("walk_n_v03_keyed_7source.png", 7, 6),
    }
    clips["warrior_run"] = _rows("run_v01_keyed.png", 5, 6)

    attack = _rows("attack_v01_keyed.png", 5, 7)
    clips["warrior_attack"] = attack

    attack2 = _rows("attack2_v01_keyed.png", 5, 7)
    clips["warrior_attack2"] = attack2
    clips["warrior_dash"] = _rows("dash_v01_keyed.png", 5, 7)

    # ImageGen supplied eight semantic states for the requested seven-frame
    # Berserk activation.  Drop the redundant fourth pre-peak standing state;
    # retain the crouched pressure peak and full recovery.
    ult_source = _rows("ult_v01_keyed_8source.png", 5, 8)
    ult = {
        suffix: [frames[index] for index in (0, 1, 2, 4, 5, 6, 7)]
        for suffix, frames in ult_source.items()
    }
    # The rear activation rows retained facing but staged the blade behind the
    # torso.  Berserk is a self-buff, so a restrained seven-state breathing
    # surge from the complete approved guard is more truthful than a vanishing
    # weapon.  Gameplay FX carries the power spike.
    for suffix in ("ne", "n"):
        guard = idle[suffix]
        ult[suffix] = [
            guard[0], guard[1], guard[2], guard[3],
            guard[2], guard[1], guard[0],
        ]
    clips["warrior_ult"] = ult

    ultidle = _rows("ultidle_v01_keyed.png", 5, 4)
    # The combined empowered-idle rear rows concealed the blade.  Safety
    # sources place the disposable edge pose after the four live frames.
    ultidle["ne"] = _strip("ultidle_ne_v02_keyed_5source.png", 5, 4)
    ultidle["n"] = _strip("ultidle_n_v01_keyed_5source.png", 5, 4)
    # The combined empowered SE/E rows introduced an eye-like warm visor
    # reflection.  The unlit restraint helm is binding, so use the approved
    # base-idle rows; the gameplay Berserk FX conveys empowerment.
    ultidle["se"] = idle["se"]
    ultidle["e"] = idle["e"]
    clips["warrior_ultidle"] = ultidle

    # The historical Warrior contract has one non-directional death strip.
    # It participates in shared-cell assembly, then its temporary directional
    # derivatives are removed after the flat south strip is written.
    clips["warrior_death"] = {
        "s": _strip("death_v02_keyed.png", 9),
    }
    return clips


def _validate_output(cell: int) -> list[Path]:
    required_dirs = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
    paths: list[Path] = []
    for base, count in EXPECTED_FRAMES.items():
        if base == "warrior_death":
            expected = [OUT_DIR / "warrior_death.png"]
        else:
            expected = [OUT_DIR / f"{base}.png"]
            expected.extend(OUT_DIR / f"{base}_{suffix}.png" for suffix in required_dirs)
        for path in expected:
            if not path.exists():
                raise ValueError(f"missing Warrior runtime strip: {path}")
            image = Image.open(path).convert("RGBA")
            if image.height != cell or image.width != cell * count:
                raise ValueError(
                    f"bad strip geometry/frame count: {path.name} {image.size}, "
                    f"expected {cell * count}x{cell}"
                )
            alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
            semi = int(((alpha > 0) & (alpha < 255)).sum())
            if semi:
                raise ValueError(f"semi-transparent pixels: {path.name} ({semi})")
            for frame in range(count):
                region = alpha[:, frame * cell : (frame + 1) * cell]
                if not np.any(region):
                    raise ValueError(f"empty frame: {path.name} f{frame + 1}")
            paths.append(path)

    static = OUT_DIR / "warrior.png"
    image = Image.open(static).convert("RGBA")
    if image.size != (cell, cell):
        raise ValueError(f"bad static geometry: {static.name} {image.size}")
    paths.append(static)

    installed = sorted(
        path for path in OUT_DIR.glob("warrior*.png") if path.is_file()
    )
    if len(installed) != 74:
        raise ValueError(f"expected exact 74-file Warrior PNG contract, got {len(installed)}")
    return paths


def _strip_frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    cell = strip.height
    return [
        strip.crop((index * cell, 0, (index + 1) * cell, cell))
        for index in range(strip.width // cell)
    ]


def _write_motion_qa(cell: int) -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    preview = max(96, cell // 2)
    for stem in (
        "anim", "walk", "run", "attack", "attack2", "dash", "ult", "ultidle"
    ):
        rows = {
            suffix: _strip_frames(OUT_DIR / f"warrior_{stem}_{suffix}.png")
            for suffix in DIR8
        }
        gif_frames: list[Image.Image] = []
        for frame_index in range(len(rows["s"])):
            canvas = Image.new("RGBA", (preview * 4, preview * 2), (28, 30, 36, 255))
            draw = ImageDraw.Draw(canvas)
            for direction_index, suffix in enumerate(DIR8):
                frame = rows[suffix][frame_index].resize(
                    (preview, preview), Image.Resampling.LANCZOS
                )
                x = (direction_index % 4) * preview
                y = (direction_index // 4) * preview
                canvas.alpha_composite(frame, (x, y))
                draw.text((x + 5, y + 4), suffix.upper(), fill=(255, 225, 120))
            gif_frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE))
        gif_frames[0].save(
            QA_DIR / f"warrior_{stem}.gif",
            save_all=True,
            append_images=gif_frames[1:],
            duration=round(1000 / QA_FPS[stem]),
            loop=0,
            disposal=2,
        )

    death_frames = _strip_frames(OUT_DIR / "warrior_death.png")
    death_gif = [
        frame.resize((preview, preview), Image.Resampling.LANCZOS).convert(
            "P", palette=Image.Palette.ADAPTIVE
        )
        for frame in death_frames
    ]
    death_gif[0].save(
        QA_DIR / "warrior_death.gif",
        save_all=True,
        append_images=death_gif[1:],
        duration=round(1000 / QA_FPS["death"]),
        loop=0,
        disposal=2,
    )
    title_height = 42
    contact = Image.new(
        "RGBA", (cell * len(death_frames), cell + title_height), (28, 30, 36, 255)
    )
    draw = ImageDraw.Draw(contact)
    draw.text((10, 8), "warrior - DEATH (directionless, cols = frame)", fill=(255, 225, 120))
    for index, frame in enumerate(death_frames):
        contact.alpha_composite(frame, (index * cell, title_height))
        draw.text(
            (index * cell + 6, title_height + 5),
            f"f{index + 1}",
            fill=(255, 225, 120),
        )
    contact.save(QA_DIR / "warrior_death_contact.png")


def build() -> None:
    loaded = _load_clips()
    clips = {
        name: shared._normalize_clip(directions)
        for name, directions in loaded.items()
        if name != "warrior_death"
    }
    # Safety replacements come from separate, much larger ImageGen masters.
    # Normalize each source clip first, then substitute the already-normalized
    # idle frames.  Mixing raw idle and attack frames before normalization made
    # the real north attack poses inherit the idle master's scale and shrink to
    # miniature figures that looked invisible in game.
    idle = clips["warrior_anim"]
    attack = clips["warrior_attack"]
    attack["n"][0] = idle["n"][0]
    attack["n"][5] = idle["n"][2]
    attack["n"][6] = idle["n"][3]
    attack2 = clips["warrior_attack2"]
    attack2["n"][0] = idle["n"][0]
    attack2["n"][6] = idle["n"][3]
    death_seed = loaded["warrior_death"]["s"]
    death_normalized = shared._normalize_clip(
        {suffix: death_seed for suffix in DIRS}
    )
    clips["warrior_death"] = {"s": death_normalized["s"]}
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips(
        clips,
        str(OUT_DIR),
        margin=3,
        symmetric=True,
    )

    # Preserve the pre-existing runtime contract: death is a single flat
    # south-facing strip, unlike the eight-direction live clips.
    for suffix in ("s", "se", "e", "ne", "n", "nw", "w", "sw"):
        directional = OUT_DIR / f"warrior_death_{suffix}.png"
        if directional.exists():
            directional.unlink()

    idle_s = Image.open(OUT_DIR / "warrior_anim_s.png").convert("RGBA")
    idle_s.crop((0, 0, cell, cell)).save(OUT_DIR / "warrior.png")

    paths = _validate_output(cell)
    _write_motion_qa(cell)
    print(
        "installed Emberbound Heir Warrior: "
        f"{len(EXPECTED_FRAMES)} clips, exact 74 PNGs, "
        f"shared cell={cell}px, validated={len(paths)} -> {OUT_DIR}"
    )


if __name__ == "__main__":
    build()
