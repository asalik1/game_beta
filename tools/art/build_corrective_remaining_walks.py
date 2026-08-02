"""Build unwired Warrior/Mage/Archer/Assassin V2 walk QA candidates."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import install_dirset
import build_blighted_mage as mage_builder
import build_emberbound_warrior as warrior_builder
import build_erased_name_assassin as assassin_builder
import build_severed_thread_archer as archer_builder

SRC = ROOT / "art_src" / "class_corrective_pass_2026-07-31"
QA = SRC / "qa"
DIR8 = ("s", "se", "e", "ne", "n", "nw", "w", "sw")
LABELS = {
    "s": "S / front",
    "se": "SE / front-right",
    "e": "E / right profile",
    "ne": "NE / rear-right",
    "n": "N / back",
    "nw": "NW / rear-left",
    "w": "W / left profile",
    "sw": "SW / front-left",
}


def _font(size: int) -> ImageFont.ImageFont:
    for path in (Path("C:/Windows/Fonts/arialbd.ttf"), Path("C:/Windows/Fonts/segoeuib.ttf")):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _remove_green(image: Image.Image) -> Image.Image:
    data = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = data[..., :3].astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    green = (g > 72.0) & (g > r * 1.14 + 12.0) & (g > b * 1.14 + 12.0)
    data[..., 3] = np.where(green, 0, 255).astype(np.uint8)
    visible = ~green
    cap = np.maximum(data[..., 0], data[..., 2]).astype(np.uint16) + 10
    data[..., 1] = np.where(visible, np.minimum(data[..., 1].astype(np.uint16), cap), 0).astype(np.uint8)
    data[green, :3] = 0
    return Image.fromarray(data, "RGBA")


def _grid(path: Path, rows: int, cols: int) -> list[list[Image.Image]]:
    image = Image.open(path).convert("RGBA")
    x_edges = [round(index * image.width / cols) for index in range(cols + 1)]
    y_edges = [round(index * image.height / rows) for index in range(rows + 1)]
    output: list[list[Image.Image]] = []
    for row in range(rows):
        cells: list[Image.Image] = []
        for col in range(cols):
            # Drop the generator's occasional one-pixel white cell rules.
            pad = 2
            cell = image.crop((x_edges[col] + pad, y_edges[row] + pad, x_edges[col + 1] - pad, y_edges[row + 1] - pad))
            cells.append(_remove_green(cell))
        output.append(cells)
    return output


def _drop_edge_rules(frame: Image.Image, band: int = 5) -> Image.Image:
    """Remove only near-white generator cell rules touching a crop edge."""
    data = np.asarray(frame.convert("RGBA"), dtype=np.uint8).copy()
    white = (
        (data[..., 0] > 228)
        & (data[..., 1] > 228)
        & (data[..., 2] > 228)
    )
    edge = np.zeros(white.shape, dtype=bool)
    edge[:band, :] = True
    edge[-band:, :] = True
    edge[:, :band] = True
    edge[:, -band:] = True
    remove = white & edge
    data[remove, :] = 0
    return Image.fromarray(data, "RGBA")


def _clean_rows(rows: list[list[Image.Image]]) -> list[list[Image.Image]]:
    return [[_drop_edge_rules(frame) for frame in row] for row in rows]


def _component_grid_nominal(
    path: Path,
    rows: int,
    cols: int,
    *,
    remove_rules: bool = False,
    bridge_size: int = 5,
) -> list[list[Image.Image]]:
    """Split rows nominally, then isolate whole connected figures per row."""
    image = warrior_builder.shared._remove_green(
        Image.open(path).convert("RGBA")
    )
    if remove_rules:
        data = np.asarray(image, dtype=np.uint8).copy()
        near_white = (
            (data[..., 0] > 228)
            & (data[..., 1] > 228)
            & (data[..., 2] > 228)
        )
        rule = np.zeros(near_white.shape, dtype=bool)
        for index in range(0, cols + 1):
            x = round(index * image.width / cols)
            rule[:, max(0, x - 3) : min(image.width, x + 4)] = True
        for index in range(0, rows + 1):
            y = round(index * image.height / rows)
            rule[max(0, y - 3) : min(image.height, y + 4), :] = True
        data[near_white & rule, :] = 0
        image = Image.fromarray(data, "RGBA")
    y_edges = [round(index * image.height / rows) for index in range(rows + 1)]
    return [
        warrior_builder._component_row(
            image.crop((0, y_edges[row], image.width, y_edges[row + 1])),
            cols,
            bridge_size=bridge_size,
        )
        for row in range(rows)
    ]


def _normalize(directions: dict[str, list[Image.Image]], target: int) -> dict[str, list[Image.Image]]:
    stage = 512
    baseline = 468
    result: dict[str, list[Image.Image]] = {}
    for suffix, frames in directions.items():
        boxes = [frame.getbbox() for frame in frames]
        if any(box is None for box in boxes):
            raise ValueError(f"empty frame in {suffix}")
        heights = [box[3] - box[1] for box in boxes if box is not None]
        # One fixed scale per direction preserves authored vertical motion.
        scale = target / float(max(heights))
        normalized: list[Image.Image] = []
        for frame, box in zip(frames, boxes):
            assert box is not None
            figure = frame.crop(box)
            size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
            figure = figure.resize(size, Image.Resampling.LANCZOS)
            data = np.asarray(figure, dtype=np.uint8).copy()
            data[..., 3] = np.where(data[..., 3] > 24, 255, 0).astype(np.uint8)
            data[data[..., 3] == 0, :3] = 0
            figure = Image.fromarray(data, "RGBA")
            canvas = Image.new("RGBA", (stage, stage), (0, 0, 0, 0))
            canvas.alpha_composite(figure, ((stage - figure.width) // 2, baseline - figure.height))
            normalized.append(canvas)
        result[suffix] = normalized
    return result


def _strip_frames(path: Path) -> list[Image.Image]:
    strip = Image.open(path).convert("RGBA")
    cell = strip.height
    return [strip.crop((i * cell, 0, (i + 1) * cell, cell)) for i in range(strip.width // cell)]


def _write_qa(class_name: str, rows: dict[str, list[Image.Image]], contact_index: int) -> None:
    QA.mkdir(parents=True, exist_ok=True)
    count = len(rows["s"])
    preview, left, top = 148, 190, 42
    contact = Image.new("RGBA", (left + preview * count, top + preview * 8), (27, 30, 36, 255))
    draw = ImageDraw.Draw(contact)
    draw.text((10, 8), f"{class_name.upper()} V2 WALK — OBSERVED FACING; OPPOSING CONTACTS HIGHLIGHTED", font=_font(18), fill=(255, 224, 126, 255))
    for col in range(count):
        draw.text((left + col * preview + 6, 20), f"f{col + 1}", font=_font(14), fill=(255, 224, 126, 255))
    for row_index, suffix in enumerate(DIR8):
        y = top + row_index * preview
        draw.rectangle((0, y, left - 1, y + preview - 1), fill=(45, 49, 58, 255))
        draw.text((10, y + 58), LABELS[suffix], font=_font(15), fill=(235, 238, 243, 255))
        for frame_index, frame in enumerate(rows[suffix]):
            contact.alpha_composite(frame.resize((preview, preview), Image.Resampling.LANCZOS), (left + frame_index * preview, y))
            if frame_index in (0, contact_index):
                color = (97, 219, 145, 255) if frame_index == 0 else (99, 176, 255, 255)
                draw.rectangle((left + frame_index * preview + 2, y + 2, left + (frame_index + 1) * preview - 3, y + preview - 3), outline=color, width=3)
    contact.save(QA / f"{class_name}_v2_walk_contact.png")

    grid_cell = 180
    pages: list[Image.Image] = []
    for frame_index in range(count):
        page = Image.new("RGBA", (grid_cell * 4, grid_cell * 2), (27, 30, 36, 255))
        for direction_index, suffix in enumerate(DIR8):
            frame = rows[suffix][frame_index].resize((grid_cell, grid_cell), Image.Resampling.LANCZOS)
            page.alpha_composite(frame, ((direction_index % 4) * grid_cell, (direction_index // 4) * grid_cell))
        pages.append(page.convert("P", palette=Image.Palette.ADAPTIVE))
    pages[0].save(QA / f"{class_name}_v2_walk.gif", save_all=True, append_images=pages[1:], duration=110, loop=0, disposal=2)


def _install(class_name: str, directions: dict[str, list[Image.Image]], target: int, contact_index: int) -> None:
    normalized = _normalize(directions, target)
    out = SRC / f"{class_name}_candidate_runtime"
    out.mkdir(parents=True, exist_ok=True)
    cell = install_dirset.assemble_clips({f"{class_name}_walk": normalized}, str(out), margin=3, symmetric=False)
    rows = {suffix: _strip_frames(out / f"{class_name}_walk_{suffix}.png") for suffix in DIR8}
    _write_qa(class_name, rows, contact_index)
    print(f"unwired {class_name} V2 walk: cell={cell}px -> {out}")


def build_warrior() -> None:
    warrior_builder.ART_SRC = SRC
    right = warrior_builder._component_grid("warrior_walk_s_se_e_ne_v01.png", 4, 6)
    left = warrior_builder._component_grid("warrior_walk_n_nw_w_sw_v01.png", 4, 6)
    dirs = {"s": right[0], "se": right[1], "e": right[2], "ne": right[3], "n": left[0], "nw": left[1], "w": left[2], "sw": left[3]}
    _install("warrior", dirs, 180, 3)


def build_mage() -> None:
    right = _component_grid_nominal(
        SRC / "mage_walk_n_ne_e_se_v01_se_rejected_double_staff.png",
        4,
        8,
        bridge_size=1,
    )
    se = _component_grid_nominal(
        SRC / "mage_walk_se_v02.png", 1, 8, bridge_size=1
    )[0]
    s = _component_grid_nominal(SRC / "mage_walk_s_v02.png", 1, 8, bridge_size=1)[0]
    sw = _component_grid_nominal(SRC / "mage_walk_sw_v02.png", 1, 8, bridge_size=1)[0]
    w = _component_grid_nominal(SRC / "mage_walk_w_v02.png", 1, 8, bridge_size=1)[0]
    nw = _component_grid_nominal(SRC / "mage_walk_nw_v02.png", 1, 8, bridge_size=1)[0]
    dirs = {"s": s, "sw": sw, "w": w, "nw": nw, "n": right[0], "ne": right[1], "e": right[2], "se": se}
    _install("mage", dirs, 180, 4)


def build_archer() -> None:
    left = _component_grid_nominal(
        SRC / "archer_walk_s_sw_w_nw_v01.png",
        4,
        6,
        remove_rules=True,
        bridge_size=1,
    )
    right = _component_grid_nominal(
        SRC / "archer_walk_n_ne_e_se_v01.png",
        4,
        6,
        remove_rules=True,
        bridge_size=1,
    )
    # The W/NW rows in the first grid were clipped by the generated row
    # boundaries, so those directions are deliberately sourced from clean,
    # independently generated strips instead of trying to repair lost pixels.
    w = _component_grid_nominal(
        SRC / "archer_walk_w_v02.png", 1, 6, bridge_size=1
    )[0]
    nw = _component_grid_nominal(
        SRC / "archer_walk_nw_v02.png", 1, 6, bridge_size=1
    )[0]
    dirs = {"s": left[0], "sw": left[1], "w": w, "nw": nw, "n": right[0], "ne": right[1], "e": right[2], "se": right[3]}
    _install("archer", dirs, 180, 3)


def build_assassin() -> None:
    # The apparent 4x6 grid is irregular vertically: nominal row cuts clip a
    # hood and pull a neighbouring hood into another cell.  Locate the six
    # bodies in each authored row and assign every detached component to the
    # nearest body.  Crucially, do NOT pass these frames through _clean_frame;
    # the cape's disconnected dark panels are valid authored pixels.
    right = assassin_builder._component_grid(
        SRC / "assassin_walk_s_se_e_ne_v01.png", 4, 6
    )
    left = assassin_builder._component_grid(
        SRC / "assassin_walk_n_nw_w_sw_v01.png", 4, 6
    )
    dirs = {"s": right[0], "se": right[1], "e": right[2], "ne": right[3], "n": left[0], "nw": left[1], "w": left[2], "sw": left[3]}
    _install("assassin", dirs, 190, 3)


def build() -> None:
    build_warrior()
    build_mage()
    build_archer()
    build_assassin()


if __name__ == "__main__":
    build()
