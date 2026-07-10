"""flux_draft — free concept-draft rounds via HuggingFace FLUX.1-schnell.

THE PIPELINE RULE (owner, 2026-07-10): every non-trivial asset (bosses,
mobs, characters) gets FLUX drafts reviewed by the owner BEFORE a PixelLab
brief is written. Drafts are concept art — big single renders for judging
anatomy/silhouette/mood — never installed in the game.

Usage:  python flux_draft.py <out_dir> <name> "prompt A" ["prompt B" ...]
Each prompt renders once; a numbered contact sheet <name>_sheet.png is
written beside the renders. HF_TOKEN comes from env or HKCU registry.
"""
import os, sys, json, urllib.request

def hf_token():
    t = os.environ.get("HF_TOKEN")
    if t:
        return t
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
        return winreg.QueryValueEx(k, "HF_TOKEN")[0]

STYLE = ("dark fantasy game boss concept art, full body, strong readable "
         "silhouette, muted somber palette, plain dark background, no text")

def render(prompt, path):
    body = json.dumps({"inputs": f"{prompt}, {STYLE}"}).encode()
    req = urllib.request.Request(
        "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell",
        data=body, method="POST",
        headers={"Authorization": "Bearer " + hf_token(),
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        data = r.read()
    with open(path, "wb") as f:
        f.write(data)

def sheet(out, name, paths):
    from PIL import Image, ImageDraw, ImageFont
    try:
        F = ImageFont.load_default(size=18)
    except TypeError:
        F = ImageFont.load_default()
    thumbs = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        im.thumbnail((420, 420))
        thumbs.append(im)
    w = sum(t.size[0] + 10 for t in thumbs) + 10
    h = max(t.size[1] for t in thumbs) + 40
    s = Image.new("RGB", (w, h), (30, 30, 36))
    d = ImageDraw.Draw(s)
    x = 10
    for i, t in enumerate(thumbs):
        s.paste(t, (x, 30))
        d.text((x, 6), "variant %d" % (i + 1), fill=(230, 220, 180), font=F)
        x += t.size[0] + 10
    p = os.path.join(out, "%s_sheet.png" % name)
    s.save(p)
    return p

if __name__ == "__main__":
    out, name = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    prompts = sys.argv[3:]
    paths = []
    for i, prompt in enumerate(prompts):
        p = os.path.join(out, "%s_v%d.png" % (name, i + 1))
        try:
            render(prompt, p)
            paths.append(p)
            print("drafted", p)
        except Exception as e:
            print("FAILED variant", i + 1, e)
    if paths:
        print("sheet:", sheet(out, name, paths))
