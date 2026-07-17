"""polligen — free texture/prop generation via pollinations.ai + pixel normalize.

Fetches a 512px FLUX render, downscales to the true pixel grid (LANCZOS),
quantizes to a limited palette (forces the chunky voice), boosts contrast,
and for sprites strips the background to alpha (corner flood fill).
Characters/animations do NOT belong here (no frame consistency) — this is
the walls/trees/props lane. Outputs go to a staging dir for the taste gate,
never straight into assets/.

Usage:  python polligen.py <out_dir>            # run the TARGETS batch
        python polligen.py <out_dir> name "prompt" size tile|sprite [seed]
"""
import os, sys, urllib.parse, urllib.request
from PIL import Image, ImageEnhance

STYLE = ("pixel art game asset, chunky pixels, thick dark outline, muted "
         "desaturated somber dark fantasy RPG palette, flat orthographic view, "
         "no text, no watermark, plain solid background")

# name, subject prompt, target px, kind (tile = opaque texture, sprite = alpha)
TARGETS = [
    ("wall_wood", "wooden palisade wall texture, horizontal aged dark oak planks, "
     "plank seams, iron nail dots, weathered", 32, "tile"),
    ("wall_volcanic", "dark basalt brick wall texture, near-black stone courses, "
     "thin dim ember-orange glow in a few mortar cracks", 32, "tile"),
    ("wall_sand", "sandstone block wall texture, sun-bleached tan blocks, "
     "chiseled mortar lines, worn edges", 32, "tile"),
    ("wall_ice", "glacial ice block wall texture, pale blue-white frozen blocks, "
     "faint internal fractures, frosted mortar seams", 32, "tile"),
    ("tree_green", "single dark green conifer pine tree, thick trunk, layered "
     "boughs, solid black background, full tree centered", 48, "sprite"),
    ("tree_teal", "single dark teal-needled conifer tree, twisted trunk, gloomy, "
     "solid black background, full tree centered", 48, "sprite"),
    ("tree_autumn", "single autumn tree with deep rust-orange canopy, dark "
     "gnarled trunk, a few falling leaves, solid black background, centered", 48, "sprite"),
    ("mushroom", "single squat forest mushroom, dull red-brown cap with pale "
     "flecks, thick earthy beige stem, solid black background, centered", 32, "sprite"),
]

BACKEND = os.environ.get("POLLIGEN_BACKEND", "pollinations")  # or "hf"

def fetch(prompt, seed):
    if BACKEND == "hf":
        # FLUX.1-schnell via HF inference (free tier w/ HF_TOKEN; higher
        # quality than pollinations; seed not supported — vary the prompt).
        import json
        body = json.dumps({"inputs": f"{prompt}, {STYLE} (variation {seed})"}).encode()
        req = urllib.request.Request(
            "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell",
            data=body, method="POST",
            headers={"Authorization": "Bearer " + os.environ["HF_TOKEN"],
                     "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=180) as r:
            data = r.read()
    else:
        q = urllib.parse.quote(f"{prompt}, {STYLE}")
        url = f"https://image.pollinations.ai/prompt/{q}?width=512&height=512&nologo=true&seed={seed}"
        req = urllib.request.Request(url, headers={"User-Agent": "crownless-polligen"})
        with urllib.request.urlopen(req, timeout=90) as r:
            data = r.read()
    tmp = os.path.join(OUT, "_raw.png")
    with open(tmp, "wb") as f:
        f.write(data)
    return Image.open(tmp).convert("RGB")

def strip_bg(img):
    """Corner flood fill -> alpha (sprites are prompted on solid black)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = max(set((c[0] // 24, c[1] // 24, c[2] // 24) for c in corners),
             key=[(c[0] // 24, c[1] // 24, c[2] // 24) for c in corners].count)
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if (r // 24, g // 24, b // 24) == bg or (r + g + b) < 90:
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return img

def normalize(img, size, kind, colors=12):
    small = img.resize((size, size), Image.LANCZOS)
    q = small.quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    q = ImageEnhance.Contrast(q).enhance(1.22)
    if kind == "sprite":
        q = strip_bg(q)
    return q

def run(name, prompt, size, kind, seeds=(7, 23)):
    outs = []
    for i, seed in enumerate(seeds):
        raw = fetch(prompt, seed)
        out = normalize(raw, size, kind)
        p = os.path.join(OUT, f"{name}__s{seed}.png")
        out.save(p)
        outs.append(p)
        print("made", p)
    return outs

if __name__ == "__main__":
    OUT = sys.argv[1] if len(sys.argv) > 1 else "polli_staging"
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) >= 5:
        run(sys.argv[2], sys.argv[3], int(sys.argv[4]),
            sys.argv[5] if len(sys.argv) > 5 else "tile",
            (int(sys.argv[6]),) if len(sys.argv) > 6 else (7, 23))
    else:
        for name, prompt, size, kind in TARGETS:
            try:
                run(name, prompt, size, kind)
            except Exception as e:
                print("FAILED", name, e)
