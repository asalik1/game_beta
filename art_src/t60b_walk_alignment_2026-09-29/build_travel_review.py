"""Existing travel_gif helper at measured enemy scale, with taller boss panes."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageSequence

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/art"))
import travel_gif

travel_gif.PANE_H = 320
travel_gif.GROUND_Y = 285
for name, speed, scale in [("morwen_walk", 120, 9 * 1.7 * 16 / 627),
                           ("korrag_walk_codex_s", 170, 9.5 * 1.7 * 16 / 627)]:
    sys.argv = ["travel_gif", str(HERE / "before" / (name + ".png")),
                str(HERE / "candidate" / (name + ".png")), "--speed", str(speed),
                "--fps", "12", "--scale", str(scale), "--zoom", "1", "--cycles", "6", "--out", str(HERE)]
    travel_gif.main()
    with Image.open(HERE / (name + "__vs__1more_travel.gif")) as gif:
        frames = [f.convert("RGB") for f in ImageSequence.Iterator(gif)]
    sheet = Image.new("RGB", (1360, 650), (30, 30, 30))
    draw = ImageDraw.Draw(sheet)
    for i, index in enumerate([0, 3, 5, 7]):
        sheet.paste(frames[index], (i * 340, 10))
        draw.text((i * 340 + 5, 0), f"t={index * .04:.2f}s; before ABOVE / after BELOW", fill="white")
    sheet.save(HERE / (name + "_travel_decoded.png"))
