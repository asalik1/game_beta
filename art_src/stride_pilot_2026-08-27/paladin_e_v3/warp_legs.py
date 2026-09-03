from math import hypot

from PIL import Image, ImageDraw


SRC = r"C:\Users\asali\.codex\generated_images\01a05455-f941-7b83-9f83-a6b71451313d\exec-d7d3aebe-85ce-45db-818b-893dea4b7509.png"
OUT = r"C:\Users\asali\.codex\generated_images\01a05455-f941-7b83-9f83-a6b71451313d\warp_test.png"


def is_green(pixel):
    r, g, b, _ = pixel
    return g >= 80 and g >= r + 18 and g >= b + 18


def make_mask(image, polygon, neutral_only=True):
    region = Image.new("L", image.size, 0)
    ImageDraw.Draw(region).polygon(polygon, fill=255)
    rp = region.load()
    ip = image.load()
    xs = [p[0] for p in polygon]
    ys = [p[1] for p in polygon]
    for y in range(min(ys), max(ys) + 1):
        for x in range(min(xs), max(xs) + 1):
            if not rp[x, y]:
                continue
            pixel = ip[x, y]
            if is_green(pixel):
                rp[x, y] = 0
                continue
            if neutral_only:
                r, g, b, _ = pixel
                hi, lo = max(r, g, b), min(r, g, b)
                # Greaves are neutral/warm silver plus near-black ink edges.
                # This rejects the saturated blue cloak and brown hammer when
                # erasing the old legs.
                neutral_armor = hi - lo <= max(8, int(hi * 0.23))
                if not neutral_armor:
                    rp[x, y] = 0
    return region


def affine_from_segments(source_a, source_b, dest_a, dest_b, width_scale=1.0):
    sx, sy = source_b[0] - source_a[0], source_b[1] - source_a[1]
    dx, dy = dest_b[0] - dest_a[0], dest_b[1] - dest_a[1]
    sl = hypot(sx, sy)
    dl = hypot(dx, dy)
    # Source/destination orthonormal bases. Length changes along the shin,
    # while width_scale keeps the greave from becoming unnaturally thick.
    sux, suy = sx / sl, sy / sl
    snx, sny = -suy, sux
    dux, duy = dx / dl, dy / dl
    dnx, dny = -duy * width_scale, dux * width_scale
    along = dl / sl
    # A = D * S^T because S is orthonormal.
    a = dux * along * sux + dnx * snx
    b = dux * along * suy + dnx * sny
    d = duy * along * sux + dny * snx
    e = duy * along * suy + dny * sny
    tx = dest_a[0] - a * source_a[0] - b * source_a[1]
    ty = dest_a[1] - d * source_a[0] - e * source_a[1]
    det = a * e - b * d
    ia, ib = e / det, -b / det
    id_, ie = -d / det, a / det
    ic = -(ia * tx + ib * ty)
    iff = -(id_ * tx + ie * ty)
    return ia, ib, ic, id_, ie, iff


def warp(image, mask, source_a, source_b, dest_a, dest_b, width_scale=1.0):
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    layer.paste(image, (0, 0), mask)
    coeff = affine_from_segments(source_a, source_b, dest_a, dest_b, width_scale)
    return layer.transform(
        image.size,
        Image.Transform.AFFINE,
        coeff,
        resample=Image.Resampling.BICUBIC,
    )


original = Image.open(SRC).convert("RGBA")
base = original.copy()

# Tight masks around the four original greaves only. Boots, knees, skirt,
# hammer, and shield remain in the unmodified base layer.
f3_swing = make_mask(original, [(804, 424), (843, 423), (849, 448), (831, 477), (818, 508), (785, 509), (791, 478), (803, 449)])
f3_plant = make_mask(original, [(902, 442), (932, 438), (942, 463), (953, 506), (919, 509), (909, 480)])
f4_swing = make_mask(original, [(1136, 424), (1177, 421), (1187, 449), (1169, 478), (1154, 508), (1118, 509), (1124, 478), (1136, 449)])
f4_plant = make_mask(original, [(1255, 439), (1285, 438), (1293, 464), (1308, 507), (1275, 509), (1264, 480)])
clean_greave = make_mask(original, [(218, 480), (234, 479), (239, 507), (217, 509)], neutral_only=False)

for mask in (f3_swing, f3_plant, f4_swing, f4_plant):
    base.paste((0, 255, 0, 255), (0, 0), mask)

# Background planted greaves first.
base.alpha_composite(warp(original, clean_greave, (227, 483), (228, 504), (909, 442), (805, 504), 0.86))
base.alpha_composite(warp(original, clean_greave, (227, 483), (228, 504), (1168, 442), (1295, 504), 0.86))
# Foreground swinging greaves last, so they visibly occlude the planted legs.
base.alpha_composite(warp(original, clean_greave, (227, 483), (228, 504), (821, 438), (931, 504), 0.94))
base.alpha_composite(warp(original, clean_greave, (227, 483), (228, 504), (1270, 438), (1137, 504), 0.94))

# Enforce the requested exact chroma-key background without touching armor.
pixels = list(base.getdata())
pixels = [(0, 255, 0, 255) if is_green(p) else p for p in pixels]
base.putdata(pixels)
base.convert("RGB").save(OUT, format="PNG")
print(OUT)
