from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).with_name("mage_idle_s_transparent_soft.png")
ORIGINAL = ROOT / "game/assets/sprites/mage_anim_s.png"
OUT = Path(__file__).with_name("mage_idle_s_candidate_808x202.png")
PREVIEW = Path(__file__).with_name("mage_idle_s_preview.gif")

CELL = 202
FRAME_COUNT = 4
SOURCE_SCALE = 0.25

source = Image.open(SRC).convert("RGBA")
original = Image.open(ORIGINAL).convert("RGBA")
sheet = Image.new("RGBA", (CELL * FRAME_COUNT, CELL), (0, 0, 0, 0))
preview_frames = []

for index in range(FRAME_COUNT):
    source_left = round(index * source.width / FRAME_COUNT)
    source_right = round((index + 1) * source.width / FRAME_COUNT)
    frame = source.crop((source_left, 0, source_right, source.height))
    frame = frame.resize(
        (round(frame.width * SOURCE_SCALE), round(frame.height * SOURCE_SCALE)),
        Image.Resampling.NEAREST,
    )

    # The generated sheet uses a four-times pixel grid. Collapse its soft
    # chroma-removal matte back to hard sprite pixels after the exact 1/4 resize.
    alpha = frame.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    frame.putalpha(alpha)
    generated_bbox = alpha.getbbox()
    target = original.crop((index * CELL, 0, (index + 1) * CELL, CELL))
    target_bbox = target.getchannel("A").getbbox()
    if generated_bbox is None or target_bbox is None:
        raise RuntimeError(f"Missing frame content at index {index}")

    generated_center_x = (generated_bbox[0] + generated_bbox[2]) / 2.0
    target_center_x = (target_bbox[0] + target_bbox[2]) / 2.0
    paste_x = round(target_center_x - generated_center_x)
    paste_y = target_bbox[3] - generated_bbox[3]
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    cell.alpha_composite(frame, (paste_x, paste_y))
    sheet.alpha_composite(cell, (index * CELL, 0))

    # In-game-scale animated proof on a simple terrain-colored backdrop.
    zoom = 3
    backdrop = Image.new("RGB", (CELL * zoom, CELL * zoom), (137, 105, 64))
    ground_y = 170 * zoom
    ground = Image.new("RGB", (CELL * zoom, CELL * zoom - ground_y), (77, 134, 72))
    backdrop.paste(ground, (0, ground_y))
    enlarged = cell.resize((CELL * zoom, CELL * zoom), Image.Resampling.NEAREST)
    backdrop.paste(enlarged.convert("RGB"), (0, 0), enlarged.getchannel("A"))
    preview_frames.append(backdrop)

sheet.save(OUT)
preview_frames[0].save(
    PREVIEW,
    save_all=True,
    append_images=preview_frames[1:] + [preview_frames[2], preview_frames[1]],
    duration=165,
    loop=0,
    disposal=2,
)

print(OUT)
print(PREVIEW)

