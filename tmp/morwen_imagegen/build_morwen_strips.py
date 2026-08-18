from pathlib import Path

from PIL import Image


ROOT = Path(r"C:\Users\asali\Projects\MMO")
TMP = ROOT / "tmp" / "morwen_imagegen" / "revised"
OUT = ROOT / "game" / "assets" / "sprites"


def build_strip(source_name: str, output_name: str) -> None:
    source = Image.open(TMP / source_name).convert("RGBA")
    width, height = source.size
    if width != height or width % 2:
        raise ValueError(f"{source_name} must be an even square, got {source.size}")

    cell = width // 2
    frames = [
        source.crop((0, 0, cell, cell)),
        source.crop((cell, 0, width, cell)),
        source.crop((0, cell, cell, height)),
        source.crop((cell, cell, width, height)),
    ]

    # Keep the robe hem on one shared anchor while retaining the generous
    # transparent padding supplied by the generated square cells.
    bottoms = []
    for frame in frames:
        alpha = frame.getchannel("A")
        bottom = 0
        for y in range(cell - 1, -1, -1):
            if sum(1 for x in range(cell) if alpha.getpixel((x, y)) > 32) >= 12:
                bottom = y
                break
        bottoms.append(bottom)
    target_bottom = max(bottoms)

    strip = Image.new("RGBA", (cell * 4, cell), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        alpha = frame.getchannel("A")
        bottom = 0
        for y in range(cell - 1, -1, -1):
            if sum(1 for x in range(cell) if alpha.getpixel((x, y)) > 32) >= 12:
                bottom = y
                break
        aligned = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        aligned.alpha_composite(frame, (0, target_bottom - bottom))
        strip.alpha_composite(aligned, (index * cell, 0))
    destination = OUT / output_name
    try:
        strip.save(destination, "PNG", optimize=False)
    except OSError:
        destination = TMP / f"built_{output_name}"
        strip.save(destination, "PNG", optimize=False)
        print(f"direct save was unavailable; wrote staging copy: {destination}")
    print(f"{output_name}: {strip.size}, frames=4, cell={cell}, bottom_anchor={target_bottom}, source_bottoms={bottoms}")


build_strip("idle_alpha.png", "morwen_anim.png")
build_strip("walk_alpha.png", "morwen_walk.png")
build_strip("attack_alpha.png", "morwen_attack.png")
