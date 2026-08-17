#!/usr/bin/env python3
"""Write per-terrain Codex ImageGen prompts for the seamless floor-field tiles.

Palettes are the game's REAL un-tinted GROUND colors (art.gd GROUND[kind]) so
the CanvasModulate terrain tint still carries the mood in-engine — the tile is
authored neutral, exactly like the procedural base it replaces. One prompt file
per kind under <out>/prompts/<kind>.txt; a bash loop feeds each to `codex exec`.
"""
import sys
from pathlib import Path

# kind -> (base, dark, light) as 0-1 RGB triples, verbatim from art.gd GROUND.
PALETTE = {
    "grass":        ((0.32, 0.55, 0.30), (0.27, 0.49, 0.26), (0.38, 0.62, 0.33)),
    "forest":       ((0.28, 0.45, 0.28), (0.22, 0.37, 0.22), (0.36, 0.54, 0.34)),
    "marsh":        ((0.37, 0.43, 0.27), (0.30, 0.36, 0.22), (0.46, 0.51, 0.33)),
    "basalt":       ((0.32, 0.20, 0.18), (0.24, 0.14, 0.13), (0.42, 0.25, 0.18)),
    "snow":         ((0.82, 0.86, 0.93), (0.74, 0.79, 0.88), (0.92, 0.95, 1.00)),
    "gravedirt":    ((0.40, 0.38, 0.34), (0.33, 0.31, 0.28), (0.48, 0.46, 0.41)),
    "sand":         ((0.78, 0.67, 0.44), (0.70, 0.59, 0.38), (0.86, 0.76, 0.52)),
    "bogsoil":      ((0.28, 0.35, 0.22), (0.21, 0.28, 0.17), (0.36, 0.43, 0.27)),
    "crystalfloor": ((0.30, 0.31, 0.46), (0.24, 0.25, 0.38), (0.40, 0.42, 0.60)),
    "stormgrass":   ((0.36, 0.40, 0.46), (0.29, 0.33, 0.38), (0.44, 0.49, 0.55)),
    "voidstone":    ((0.18, 0.12, 0.24), (0.12, 0.08, 0.17), (0.28, 0.19, 0.36)),
    "holystone":    ((0.66, 0.61, 0.49), (0.58, 0.53, 0.42), (0.76, 0.71, 0.58)),
    "sporesoil":    ((0.38, 0.29, 0.38), (0.31, 0.23, 0.31), (0.48, 0.37, 0.48)),
}

# kind -> (short motif, detail clause). Kept concrete; the negatives are shared.
MOTIF = {
    "grass":        ("lush meadow grass", "short even turf of fine grass blades with a few worn bare-dirt patches and tiny pebbles; no flowers, no tall blades"),
    "forest":       ("shaded forest floor", "mossy dark earth with scattered fallen leaves, thin twigs and surface roots, patches of bare soil"),
    "marsh":        ("murky marshland ground", "wet muddy soil with shallow standing-water sheens, patches of algae and silt, a few short reed stubs flush to the ground"),
    "basalt":       ("cracked volcanic basalt", "dark hardened lava rock broken by a web of thin cracks; a few cracks hold a faint dim ember-orange glow, most of the surface cool dark stone"),
    "snow":         ("wind-packed snow and ice", "clean granular snow with subtle glassy ice sheens and faint blue shadow dips; no footprints"),
    "gravedirt":    ("packed grave-dirt", "hard-packed brown-grey earth with sparse dead-grass tufts, small stones and hairline cracks; bare and somber"),
    "sand":         ("wind-rippled desert sand", "fine dune sand with gentle parallel ripple lines and a scatter of tiny pebbles"),
    "bogsoil":      ("dark bog peat", "wet black-green peat and mud with murky puddles, rotting plant matter and a slick sheen"),
    "crystalfloor": ("crystalline cavern floor", "angular blue-violet mineral crystal facets set in smooth dark rock, faint internal sparkle catching the light"),
    "stormgrass":   ("storm-battered wet grass", "grey-green wet grass flattened by wind, shallow rain puddles reflecting a grey sky, muddy scuffed patches"),
    "voidstone":    ("void rock", "near-black obsidian-like void stone, mostly flat matte black, broken only by a few faint thin purple energy veins; keep it VERY dark and minimal"),
    "holystone":    ("sacred pale flagstone", "clean warm sandstone-and-marble flagstones with fine mortar lines, subtle worn polish and faint engraved lines; sacred and bright"),
    "sporesoil":    ("fungal spore ground", "spongy purple-grey fungal humus threaded with pale mycelium and dotted with tiny spores and small mushroom caps flush to the ground"),
}

NEG = ("Flat even lighting with NO directional light and NO cast shadows, NO props or objects, "
       "NO creatures, NO border or frame, NO text — the texture fills the entire frame edge to edge "
       "and repeats seamlessly with no single obvious landmark.")


def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in c)


def build(kind: str) -> str:
    base, dark, light = PALETTE[kind]
    motif, detail = MOTIF[kind]
    return (
        "Generate ONE image and save it, then stop. Do not write any other files, "
        "do not run any other commands.\n\n"
        f"Image: a SEAMLESS, TILEABLE top-down (orthographic, viewed straight from above) "
        f"PIXEL-ART {motif} floor texture for a fantasy action game. It MUST tile seamlessly "
        f"on all four edges (left edge matches right, top matches bottom). {detail}. {NEG} "
        f"Palette anchored to these colors: base {hexc(base)}, shadow {hexc(dark)}, "
        f"highlight {hexc(light)} — muted, slightly desaturated, cohesive. Crisp pixel-art, "
        f"1024x1024.\n\nSave the PNG to exactly this path: {{GEN}}/{kind}.png"
    )


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    gen = str(out).replace("\\", "/")
    pdir = out / "prompts"
    pdir.mkdir(parents=True, exist_ok=True)
    for kind in PALETTE:
        (pdir / f"{kind}.txt").write_text(build(kind).replace("{GEN}", gen), encoding="utf-8")
    print(f"wrote {len(PALETTE)} prompts to {pdir}")
    print("kinds:", " ".join(PALETTE.keys()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
