"""clean_sprite — turn a FLUX/Pollinations render into a clean pixel sprite.

The naive corner flood-fill in polligen leaves an un-keyed halo of
background pixels around the silhouette (and fails outright when the
render's background is close in value to the subject). This does it
properly:

  1. sample the background colour from the border ring
  2. key by COLOUR DISTANCE (not connectivity), so interior-adjacent
     fringe pixels die too
  3. drop stray components, keep the largest blob
  4. downscale with LANCZOS, then hard-threshold alpha -> crisp edges
  5. quantize to a small palette (the chunky-pixel medium)
  6. draw a 1px dark outline around the silhouette (house style)
  7. gamma pre-brighten for the Forward+ tonemap

Usage: import and call clean(src_png, out_png, size=32, colors=12)
"""
from PIL import Image, ImageFilter
from collections import Counter


def _bg_color(im):
    w, h = im.size
    px = im.load()
    ring = []
    for x in range(w):
        ring += [px[x, 0][:3], px[x, h - 1][:3]]
    for y in range(h):
        ring += [px[0, y][:3], px[w - 1, y][:3]]
    return Counter(ring).most_common(1)[0][0]


def _dist(a, b):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def _key_bg(im, thresh=78, key=None):
    """Key the background out.

    Pass `key` (e.g. magenta) when the render used a chroma-key backdrop —
    then it is safe to remove EVERY pixel near that colour, halo included.
    Otherwise fall back to a border FLOOD limited by colour distance: a
    dark subject on a dark backdrop must never be keyed globally, or the
    subject's own shadows get eaten (learned the hard way on the chests).
    """
    px = im.load()
    w, h = im.size
    if key is not None:
        for y in range(h):
            for x in range(w):
                if _dist(px[x, y][:3], key) < thresh:
                    px[x, y] = (0, 0, 0, 0)
        return im
    bg = _bg_color(im)
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] \
        + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][3] and _dist(px[x, y][:3], bg) < thresh:
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def _largest_blob(im, min_size=12):
    px = im.load()
    w, h = im.size
    seen = set()
    blobs = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 8 and (x, y) not in seen:
                stack, cur = [(x, y)], []
                while stack:
                    a, b = stack.pop()
                    if (a, b) in seen or not (0 <= a < w and 0 <= b < h):
                        continue
                    if px[a, b][3] <= 8:
                        continue
                    seen.add((a, b))
                    cur.append((a, b))
                    stack += [(a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)]
                blobs.append(cur)
    if not blobs:
        return im
    blobs.sort(key=len, reverse=True)
    keep = set(blobs[0])
    for blob in blobs[1:]:
        if len(blob) < min_size:
            for a, b in blob:
                px[a, b] = (0, 0, 0, 0)
        else:
            keep |= set(blob)
    return im


def _despill(im, key="magenta", strength=1.0):
    """Remove chroma-key colour cast bled onto the subject.

    A magenta screen tints edge and mid pixels toward R+B. Without this,
    quantization bakes the cast into the palette and greens turn lavender
    (learned on the conifers). Standard suppression: where the key's two
    channels exceed the third, pull them down to it.
    """
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if key == "magenta":
                lim = (r + b) / 2.0
                if lim > g:
                    tgt = g + (lim - g) * (1.0 - strength)
                    r = int(min(r, max(g, tgt)))
                    b = int(min(b, max(g, tgt)))
            elif key == "green":
                lim = (r + b) / 2.0
                if g > lim:
                    g = int(lim + (g - lim) * (1.0 - strength))
            px[x, y] = (r, g, b, a)
    return im


def _fill_holes(im):
    """Re-solidify transparent pixels fully enclosed by the subject.

    Chroma spill on bright trim (the A-grade chest's gold) can let the key
    punch pinholes through the body. Anything transparent that the outside
    can't reach is a hole: paint it with the median of its solid
    neighbours so the material reads continuous.
    """
    px = im.load()
    w, h = im.size
    outside = set()
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] \
        + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        if (x, y) in outside or not (0 <= x < w and 0 <= y < h):
            continue
        if px[x, y][3] > 8:
            continue
        outside.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    holes = [(x, y) for y in range(h) for x in range(w)
             if px[x, y][3] <= 8 and (x, y) not in outside]
    for x, y in holes:
        neigh = []
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                a, b = x + dx, y + dy
                if 0 <= a < w and 0 <= b < h and px[a, b][3] > 8:
                    neigh.append(px[a, b][:3])
        if neigh:
            neigh.sort()
            px[x, y] = neigh[len(neigh) // 2] + (255,)
    return im


def _outline(im, color=(24, 16, 12, 255)):
    """1px dark rim around the silhouette, grown outward into free alpha."""
    w, h = im.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.alpha_composite(im, (1, 1))
    px = out.load()
    solid = [[px[x, y][3] > 8 for y in range(h + 2)] for x in range(w + 2)]
    rim = []
    for x in range(w + 2):
        for y in range(h + 2):
            if solid[x][y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = x + dx, y + dy
                if 0 <= a < w + 2 and 0 <= b < h + 2 and solid[a][b]:
                    rim.append((x, y))
                    break
    for x, y in rim:
        px[x, y] = color
    return out


def _gamma(im, g=0.78):
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, gg, b, a = px[x, y]
            if a:
                px[x, y] = (int(255 * (r / 255) ** g), int(255 * (gg / 255) ** g),
                            int(255 * (b / 255) ** g), a)
    return im


def clean(src, out, size=32, colors=12, thresh=78, gamma=0.78, key=None,
          despill=None, despill_strength=1.0):
    im = Image.open(src).convert("RGBA")
    im = _key_bg(im, thresh, key)
    if despill:
        im = _despill(im, despill, despill_strength)
    im = _largest_blob(im, min_size=max(20, (im.size[0] // 12) ** 2))
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    # fit inside (size-2) so the outline has room
    inner = size - 2
    r = min(inner / im.size[0], inner / im.size[1])
    im = im.resize((max(1, round(im.size[0] * r)), max(1, round(im.size[1] * r))),
                   Image.LANCZOS)
    # crisp edges: hard alpha threshold
    a = im.split()[3].point(lambda v: 255 if v > 140 else 0)
    im.putalpha(a)
    im = _largest_blob(im, min_size=4)
    im = _fill_holes(im)
    # quantize colour, keep alpha
    rgb = im.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    rgb.putalpha(im.split()[3])
    im = _outline(rgb)
    # AFTER the outline too: the 1px rim seals narrow bays that were still
    # open to the outside during the first pass, turning them into holes.
    im = _fill_holes(im)
    im = _gamma(im, gamma)
    # square, feet-anchored
    cell = max(im.size) if max(im.size) >= size else size
    c = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    c.alpha_composite(im, ((cell - im.size[0]) // 2, cell - im.size[1]))
    c.save(out)
    return c.size
