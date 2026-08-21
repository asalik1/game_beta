"""clay_pot re-roll install (2026-08-21, owner flag: old art warped off-axis).

clay_pot_v1_keyed.png (Codex image_gen, magenta key) -> assets/sprites/clay_pot.png
at the ORIGINAL 142x151 canvas + bbox position, so every width table and
consumer stays untouched. Steps: hard magenta key + rim despill, tone-match
toward the old pot (it came back more saturated than the muted palette),
LANCZOS downscale into the old bbox, backup of the replaced original beside
this script. Reproduce:  python process_pot.py
"""
from PIL import Image
import numpy as np, os, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEST = os.path.join(REPO, "game", "assets", "sprites", "clay_pot.png")
MOBILE = os.path.join(REPO, "mobile", "game", "assets", "sprites", "clay_pot.png")

src = Image.open(os.path.join(HERE, "clay_pot_v1_keyed.png")).convert("RGB")
a = np.asarray(src).astype(np.int16)
r, g, b = a[..., 0], a[..., 1], a[..., 2]

# Hard key: magenta = strong R+B, weak G. Feather via the magenta-ness score.
mag = np.minimum(r, b) - g                      # high on key, low on ceramic
alpha = np.clip((80 - mag) * (255 / 60.0), 0, 255).astype(np.uint8)
alpha[mag < 20] = 255                            # solid ceramic
alpha[mag > 80] = 0                              # solid key

# Rim despill: where alpha is soft, pull R/B down to the green-anchored tone.
soft = (alpha > 0) & (alpha < 255)
neutral = g
rr = np.where(soft, np.minimum(r, neutral + 40), r)
bb = np.where(soft, np.minimum(b, neutral + 20), b)

rgba = np.dstack([rr, g, bb, alpha]).astype(np.uint8)
img = Image.fromarray(rgba, "RGBA")

# Tone match toward the old pot: sample both pots' opaque means.
old = Image.open(os.path.join(HERE, "refs", "subject_old_clay_pot.png")).convert("RGBA")
oa = np.asarray(old).astype(np.float32)
omask = oa[..., 3] > 200
omean = oa[..., :3][omask].mean(axis=0)
na = np.asarray(img).astype(np.float32)
nmask = na[..., 3] > 200
nmean = na[..., :3][nmask].mean(axis=0)
gain = np.clip(omean / np.maximum(nmean, 1), 0.6, 1.2)   # gentle, channelwise
na[..., :3] = np.clip(na[..., :3] * gain, 0, 255)
img = Image.fromarray(na.astype(np.uint8), "RGBA")

# Fit into the OLD canvas at the old bbox (footprint + anchor parity).
obox = old.getbbox()
nbox = img.getbbox()
crop = img.crop(nbox)
ow, oh = obox[2] - obox[0], obox[3] - obox[1]
scale = min(ow / crop.width, oh / crop.height)
nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
crop = crop.resize((nw, nh), Image.LANCZOS)
out = Image.new("RGBA", old.size, (0, 0, 0, 0))
# centre inside the old bbox, feet on the old bbox's bottom line
px = obox[0] + (ow - nw) // 2
py = obox[3] - nh
out.paste(crop, (px, py), crop)

bak = os.path.join(HERE, "replaced_clay_pot_original.png")
if not os.path.exists(bak):
    shutil.copy2(DEST, bak)
out.save(DEST)
print("installed", DEST, out.size, "| old bbox", obox, "-> new content", (px, py, px + nw, py + nh))
if os.path.exists(os.path.dirname(MOBILE)):
    out.save(MOBILE)
    print("mobile copy", MOBILE)
