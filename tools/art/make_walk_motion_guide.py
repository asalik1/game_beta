"""Render an animator's eight-pose profile-walk guide for ImageGen references.

The red leg is the near/foreground leg and the cyan leg is the far/background
leg.  Keeping those colors consistent across the row makes the two contacts
and two passing poses anatomically explicit without prescribing class art.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_src" / "class_corrective_pass_2026-07-31" / "guides" / "profile_walk_8_pose.png"


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        Path("C:/Windows/Fonts/seguisb.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf"),
    ):
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _limb(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: str) -> None:
    draw.line(points, fill=color, width=11, joint="curve")
    for x, y in points:
        draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=color)


def main() -> None:
    cell_w, cell_h = 190, 300
    top = 72
    image = Image.new("RGB", (cell_w * 8, cell_h + top), "#f5f2e9")
    draw = ImageDraw.Draw(image)
    title = _font(24)
    label = _font(17)
    draw.text((18, 12), "PROFILE WALK — E / SCREEN-RIGHT", font=title, fill="#17191f")
    draw.text((850, 17), "RED = near leg    CYAN = far leg", font=label, fill="#353943")

    # (caption, pelvis_y, near knee/foot, far knee/foot).  Coordinates are
    # local to a cell and deliberately use a low, ordinary walking lift.
    poses = [
        ("CONTACT A", 150, (118, 205), (145, 272), (72, 210), (44, 272)),
        ("DOWN A", 156, (112, 208), (134, 272), (76, 214), (58, 266)),
        ("PASS A", 151, (96, 212), (96, 272), (112, 205), (120, 252)),
        ("UP A", 145, (75, 210), (58, 268), (116, 202), (132, 258)),
        ("CONTACT B", 150, (72, 210), (44, 272), (118, 205), (145, 272)),
        ("DOWN B", 156, (76, 214), (58, 266), (112, 208), (134, 272)),
        ("PASS B", 151, (112, 205), (120, 252), (96, 212), (96, 272)),
        ("UP B", 145, (116, 202), (132, 258), (75, 210), (58, 268)),
    ]
    for index, (caption, pelvis_y, nk, nf, fk, ff) in enumerate(poses):
        x0 = index * cell_w
        cx = x0 + 95
        draw.rectangle((x0 + 2, top + 2, x0 + cell_w - 3, top + cell_h - 3), outline="#c8c4bb", width=2)
        draw.text((x0 + 12, top + 10), f"f{index + 1}  {caption}", font=label, fill="#17191f")
        head_y = top + pelvis_y - 92
        shoulder_y = top + pelvis_y - 58
        pelvis = (cx, top + pelvis_y)
        draw.ellipse((cx - 18, head_y - 18, cx + 18, head_y + 18), outline="#17191f", width=7)
        draw.line((cx, head_y + 18, cx, shoulder_y), fill="#17191f", width=9)
        draw.line((cx - 28, shoulder_y, cx + 28, shoulder_y), fill="#17191f", width=9)
        draw.line((cx, shoulder_y, pelvis[0], pelvis[1]), fill="#17191f", width=12)
        draw.line((cx - 28, shoulder_y, cx - 42, top + pelvis_y - 4), fill="#17191f", width=8)
        draw.line((cx + 28, shoulder_y, cx + 45, top + pelvis_y - 12), fill="#17191f", width=8)
        _limb(draw, [pelvis, (x0 + fk[0], top + fk[1]), (x0 + ff[0], top + ff[1])], "#169bb2")
        _limb(draw, [pelvis, (x0 + nk[0], top + nk[1]), (x0 + nf[0], top + nf[1])], "#d93c45")
        draw.line((x0 + 18, top + 280, x0 + cell_w - 18, top + 280), fill="#686b73", width=3)
    draw.polygon([(1490, 38), (1450, 24), (1450, 52)], fill="#17191f")
    draw.line((1360, 38, 1488, 38), fill="#17191f", width=6)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
