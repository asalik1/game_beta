"""Install full-object terrain prop animation strips generated on 2026-07-29.

The source sheets contain four complete props in one horizontal row. Their
backgrounds were removed with Codex's ImageGen chroma-key helper before being
archived under ``art_src/terrain_prop_anims_2026-07-29``. This builder keeps
one shared crop and one anchored canvas for all four frames, so neither the
fountain body nor any other rigid shell can wander as its active material
changes.
"""

from __future__ import annotations

from pathlib import Path
from statistics import median

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src" / "terrain_prop_anims_2026-07-29"
SPRITES = ROOT / "game" / "assets" / "sprites"
QA = ROOT / "tmp" / "terrain_prop_anims_QA"

# Large authored props retain their established source geometry. Legacy tiny
# pack sprites get a larger production canvas; Balance.SCENERY_RENDER_WIDTH
# preserves their old world-space scale.
TARGET_SIZES: dict[str, tuple[int, int]] = {
    "garden_fountain": (384, 361),
    "spore_vent": (256, 197),
    "void_rift": (165, 320),
    "storm_conductor": (175, 320),
    "capital_portal_depths": (343, 482),
    "magma_furnace": (317, 320),
    "keep_brazier": (254, 320),
    "forge_cauldron": (56, 88),
    "forge_brazier": (32, 52),
    "camp_furnace": (82, 124),
    "station_furnace_t1": (74, 98),
    "station_furnace_t2": (72, 114),
    "station_furnace_t3": (76, 118),
    "sewer_outfall": (160, 160),
}


def _split_four(sheet: Image.Image) -> list[Image.Image]:
    """Split a generated four-panel row even when its width is not /4 exact."""
    return [
        sheet.crop(
            (
                round(index * sheet.width / 4),
                0,
                round((index + 1) * sheet.width / 4),
                sheet.height,
            )
        )
        for index in range(4)
    ]


def _visible_bbox(frame: Image.Image) -> tuple[int, int, int, int]:
    mask = frame.getchannel("A").point(lambda value: 255 if value >= 64 else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("generated animation frame contains no visible prop")
    return bbox


def _shift(frame: Image.Image, dx: int, dy: int) -> Image.Image:
    shifted = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    shifted.alpha_composite(frame, (dx, dy))
    return shifted


def _align_source_frames(frames: list[Image.Image]) -> list[Image.Image]:
    """Align each full prop by its footprint centre and bottom baseline."""
    boxes = [_visible_bbox(frame) for frame in frames]
    centres = [(left + right) / 2.0 for left, _, right, _ in boxes]
    baselines = [bottom for _, _, _, bottom in boxes]
    target_centre = median(centres)
    target_baseline = median(baselines)
    return [
        _shift(
            frame,
            round(target_centre - centre),
            round(target_baseline - baseline),
        )
        for frame, centre, baseline in zip(frames, centres, baselines)
    ]


def _shared_crop(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [_visible_bbox(frame) for frame in frames]
    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    pad = max(2, round(max(right - left, bottom - top) * 0.018))
    crop = (
        max(0, left - pad),
        max(0, top - pad),
        min(frames[0].width, right + pad),
        min(frames[0].height, bottom + pad),
    )
    return [frame.crop(crop) for frame in frames]


def _production_frame(source: Image.Image, target: tuple[int, int]) -> Image.Image:
    """Pixel-normalize one frame onto a fixed bottom-centred target canvas."""
    target_w, target_h = target
    pad = 2 if min(target) < 128 else max(3, round(min(target) * 0.018))
    scale = min(
        (target_w - pad * 2) / source.width,
        (target_h - pad * 2) / source.height,
    )
    render_w = max(1, round(source.width * scale))
    render_h = max(1, round(source.height * scale))

    # Large ImageGen sheets are deliberately reduced to a coarser logical
    # canvas and nearest-expanded. This keeps Crownless's chunky pixel style
    # instead of retaining painterly sub-pixel detail.
    divisor = 2 if min(target) >= 128 else 1
    logical = (
        max(1, round(render_w / divisor)),
        max(1, round(render_h / divisor)),
    )
    resized = source.resize(logical, Image.Resampling.LANCZOS)
    resized = resized.resize((render_w, render_h), Image.Resampling.NEAREST)

    # Chroma edges must never reveal terrain colours through semi-alpha.
    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 80 else 0)
    resized.putalpha(alpha)

    output = Image.new("RGBA", target, (0, 0, 0, 0))
    output.alpha_composite(
        resized,
        ((target_w - render_w) // 2, target_h - pad - render_h),
    )
    return output


def _remove_tiny_detached_components(frame: Image.Image) -> Image.Image:
    """Drop panel-edge crumbs while retaining the prop's complete main body."""
    alpha = frame.getchannel("A")
    pixels = alpha.load()
    width, height = frame.size
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or pixels[x, y] == 0:
                continue
            visited[index] = 1
            stack = [(x, y)]
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for nx, ny in (
                    (px - 1, py),
                    (px + 1, py),
                    (px, py - 1),
                    (px, py + 1),
                ):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    neighbour = ny * width + nx
                    if visited[neighbour] or pixels[nx, ny] == 0:
                        continue
                    visited[neighbour] = 1
                    stack.append((nx, ny))
            components.append(component)
    if not components:
        return frame
    minimum = max(1, round(max(len(component) for component in components) * 0.02))
    cleaned = frame.copy()
    out = cleaned.load()
    for component in components:
        if len(component) >= minimum:
            continue
        for x, y in component:
            out[x, y] = (0, 0, 0, 0)
    return cleaned


def _write_strip(name: str, frames: list[Image.Image]) -> None:
    frame_w, frame_h = frames[0].size
    strip = Image.new("RGBA", (frame_w * 4, frame_h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * frame_w, 0))
    SPRITES.mkdir(parents=True, exist_ok=True)
    frames[0].save(SPRITES / f"{name}.png", optimize=True)
    strip.save(SPRITES / f"{name}_anim.png", optimize=True)

    QA.mkdir(parents=True, exist_ok=True)
    preview_scale = max(1, min(4, 256 // max(frame_w, frame_h)))
    preview = strip.resize(
        (strip.width * preview_scale, strip.height * preview_scale),
        Image.Resampling.NEAREST,
    )
    preview.save(QA / f"{name}.png", optimize=True)


def build(name: str, target: tuple[int, int]) -> None:
    source_path = SOURCE / f"{name}.png"
    if not source_path.exists():
        raise FileNotFoundError(
            f"missing transparent ImageGen source: {source_path}"
        )
    sheet = Image.open(source_path).convert("RGBA")
    source_frames = _split_four(sheet)
    if name in {"magma_furnace", "station_furnace_t3"}:
        source_frames = [
            _remove_tiny_detached_components(frame) for frame in source_frames
        ]
    frames = _shared_crop(_align_source_frames(source_frames))
    production = [_production_frame(frame, target) for frame in frames]
    if name in {"magma_furnace", "station_furnace_t3"}:
        production = [
            _remove_tiny_detached_components(frame) for frame in production
        ]
    if name == "capital_portal_depths":
        # Capital structure sources obey the repo-wide tight-static contract:
        # frame zero touches every canvas edge, and the matching strip uses
        # that exact rectangle.
        tight = _visible_bbox(production[0])
        production = [frame.crop(tight) for frame in production]
    _write_strip(name, production)
    boxes = [_visible_bbox(frame) for frame in production]
    baselines = [box[3] for box in boxes]
    centres = [round((box[0] + box[2]) / 2.0, 2) for box in boxes]
    print(
        f"{name}: {target[0]}x{target[1]} x4; "
        f"baseline={baselines}; centre={centres}"
    )


def main() -> None:
    for name, target in TARGET_SIZES.items():
        build(name, target)
    print(f"Wrote production strips to {SPRITES}")
    print(f"Wrote nearest-neighbour QA previews to {QA}")


if __name__ == "__main__":
    main()
