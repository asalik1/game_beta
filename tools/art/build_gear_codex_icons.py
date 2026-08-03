"""Build dual-resolution Crownless gear icons from approved transparent masters.

Generation writes one transparent high-resolution master per runtime key to::

    art_src/gear_codex_128/<slot>/alpha/<key>.png

This builder never generates art. It normalizes approved masters into 128x128
smooth-alpha codex candidates, separately optimized 32x32 gameplay candidates,
and labelled contact sheets. Runtime assets change only with ``--install``.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ART_GD = ROOT / "game" / "scripts" / "art.gd"
UNIQUE_MANIFEST = ROOT / "PROPOSALS" / "GEAR_UNIQUE_ART_MANIFEST.md"
SOURCE_ROOT = ROOT / "art_src" / "gear_codex_128"
CANDIDATE_ROOT = ROOT / "tmp" / "gear_codex_128"
RUNTIME_ICONS = ROOT / "game" / "assets" / "icons"
CODEX_ICONS = RUNTIME_ICONS / "codex"

SLOTS = ("weapon", "helmet", "armor", "gloves", "pants", "boots", "charm")
SLOT_PREFIX = {
    "weapon": "w", "helmet": "h", "armor": "a", "gloves": "g",
    "pants": "p", "boots": "b", "charm": "c",
}
GRADES = ("B", "A", "S")
CODEX_CANVAS = 128
CODEX_EXTENT = 116
GAMEPLAY_CANVAS = 32
GAMEPLAY_EXTENT = 29
PREBRIGHTEN_GAMMA = 0.78


@dataclass(frozen=True)
class Asset:
    slot: str
    key: str
    kind: str
    noun: str
    grade: str = ""
    name: str = ""
    cls: str = ""


def _gear_shapes_block() -> str:
    text = ART_GD.read_text(encoding="utf-8")
    try:
        return text.split("const GEAR_SHAPES := {", 1)[1].split(
            "\n}\n\n# All currently rollable", 1
        )[0]
    except IndexError as exc:
        raise RuntimeError("could not locate Art.GEAR_SHAPES") from exc


def _shape_assets() -> list[Asset]:
    block = _gear_shapes_block()
    result: list[Asset] = []
    for index, slot in enumerate(SLOTS):
        marker = f'\n\t"{slot}": {{'
        if marker not in block:
            raise RuntimeError(f"missing GEAR_SHAPES slot: {slot}")
        section = block.split(marker, 1)[1]
        next_markers = [
            section.find(f'\n\t"{later}": {{')
            for later in SLOTS[index + 1:]
            if f'\n\t"{later}": {{' in section
        ]
        if next_markers:
            section = section[:min(next_markers)]
        prefix = SLOT_PREFIX[slot] + "_"
        pairs = re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', section)
        # icon_armor/icon_boots/icon_charm are old-save fallbacks, not one of
        # the 30 per-class rollable families in the generation contract.
        pairs = [(noun, key) for noun, key in pairs if key.startswith(prefix)]
        if len(pairs) != 30:
            raise RuntimeError(
                f"{slot}: expected 30 rollable family keys, found {len(pairs)}"
            )
        for noun, key in pairs:
            result.append(Asset(slot, key, "family", noun))
            for grade in GRADES:
                result.append(Asset(slot, f"{key}_{grade}", "grade", noun, grade))
    return result


def _unique_assets() -> list[Asset]:
    result: list[Asset] = []
    for raw in UNIQUE_MANIFEST.read_text(encoding="utf-8").splitlines():
        if not raw.startswith("|"):
            continue
        cols = [part.strip() for part in raw.strip().strip("|").split("|")]
        if len(cols) != 6:
            continue
        # Weapons/helmets/gloves/pants use one row per unique.
        if cols[2] in SLOTS and cols[4] in {"A", "S"}:
            name, cls, slot, noun, grade, key = cols
            key = key.strip("`")
            if key.startswith("u_"):
                result.append(Asset(slot, key, "unique", noun, grade, name, cls))
            continue
        # Armor/boots/charms use a compact family row carrying independent A
        # and S designs. The surrounding class heading is documentary only;
        # generation/build identity is completely captured by the runtime key.
        if cols[0] in {"armor", "boots", "charm"}:
            slot, noun, a_name, a_key, s_name, s_key = cols
            a_key = a_key.strip("`")
            s_key = s_key.strip("`")
            if a_key.startswith("u_") and s_key.startswith("u_"):
                result.append(Asset(slot, a_key, "unique", noun, "A", a_name))
                result.append(Asset(slot, s_key, "unique", noun, "S", s_name))
    counts = {slot: sum(asset.slot == slot for asset in result) for slot in SLOTS}
    bad = {slot: count for slot, count in counts.items() if count != 60}
    if bad:
        raise RuntimeError(f"expected 60 named uniques per slot, got {bad}")
    return result


def manifest() -> list[Asset]:
    assets = _shape_assets() + _unique_assets()
    assets.sort(key=lambda a: (SLOTS.index(a.slot), a.kind, a.noun, a.grade, a.key))
    if len(assets) != 1260:
        raise RuntimeError(f"expected 1,260 gear assets, found {len(assets)}")
    return assets


def write_manifest(assets: list[Asset]) -> Path:
    path = SOURCE_ROOT / "manifest.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "contract": {
            "total": 1260, "per_slot": 180, "family_per_slot": 30,
            "grade_variants_per_slot": 90, "uniques_per_slot": 60,
            "codex_canvas": CODEX_CANVAS, "gameplay_canvas": GAMEPLAY_CANVAS,
        },
        "assets": [asdict(asset) for asset in assets],
    }
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return path


def _alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.where(alpha > threshold)
    if len(xs) == 0:
        raise ValueError("master contains no visible subject")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _apply_gamma(image: Image.Image, gamma: float) -> Image.Image:
    arr = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    visible = arr[..., 3] > 0
    rgb = arr[..., :3].astype(np.float32) / 255.0
    rgb[visible] = np.power(rgb[visible], gamma)
    arr[..., :3] = np.clip(np.rint(rgb * 255.0), 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def _resize_premultiplied(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premul = rgba[..., :3] * alpha
    resized_channels: list[np.ndarray] = []
    for channel in range(3):
        layer = Image.fromarray(premul[..., channel], mode="F").resize(
            size, Image.Resampling.LANCZOS
        )
        resized_channels.append(np.asarray(layer, dtype=np.float32))
    alpha_layer = Image.fromarray(alpha[..., 0], mode="F").resize(
        size, Image.Resampling.LANCZOS
    )
    out_alpha = np.clip(np.asarray(alpha_layer, dtype=np.float32), 0.0, 1.0)
    out_premul = np.stack(resized_channels, axis=-1)
    out_rgb = np.zeros_like(out_premul)
    np.divide(
        out_premul, out_alpha[..., None], out=out_rgb,
        where=out_alpha[..., None] > 1.0e-5,
    )
    out = np.dstack((np.clip(out_rgb, 0.0, 1.0), out_alpha))
    return Image.fromarray(np.rint(out * 255.0).astype(np.uint8), "RGBA")


def _normalize(image: Image.Image, canvas: int, extent: int) -> Image.Image:
    image = image.convert("RGBA")
    left, top, right, bottom = _alpha_bbox(image)
    crop = image.crop((left, top, right, bottom))
    scale = min(extent / crop.width, extent / crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    crop = _resize_premultiplied(crop, size)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(crop, ((canvas - size[0]) // 2, (canvas - size[1]) // 2))
    return out


def _pixel_optimize(image: Image.Image) -> Image.Image:
    out = _normalize(image, GAMEPLAY_CANVAS, GAMEPLAY_EXTENT)
    # A straight 1024->32 reduction keeps silhouette truth but softens every
    # internal seam. Restore one small-radius edge pass before palette reduction;
    # stronger sharpening produces white ringing on bright metal at true size.
    out = out.filter(ImageFilter.UnsharpMask(radius=0.75, percent=150, threshold=2))
    arr = np.asarray(out, dtype=np.uint8).copy()
    hard_alpha = np.where(arr[..., 3] >= 96, 255, 0).astype(np.uint8)
    rgb = Image.fromarray(arr[..., :3], "RGB").quantize(
        colors=24, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).convert("RGB")
    result = rgb.convert("RGBA")
    result.putalpha(Image.fromarray(hard_alpha, "L"))
    return result


def _source_path(asset: Asset) -> Path:
    return SOURCE_ROOT / asset.slot / "alpha" / f"{asset.key}.png"


def _validate_master(asset: Asset, image: Image.Image) -> None:
    if min(image.size) < 128:
        raise ValueError(
            f"{asset.key}: {image.size} master has no high-resolution headroom"
        )
    alpha = image.getchannel("A")
    corners = (
        alpha.getpixel((0, 0)), alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    )
    if max(corners) > 8:
        raise ValueError(f"{asset.key}: opaque corner remains after chroma removal")
    left, top, right, bottom = _alpha_bbox(image)
    if left == 0 or top == 0 or right == image.width or bottom == image.height:
        raise ValueError(f"{asset.key}: subject touches the master edge")


def _validate_outputs(asset: Asset, codex: Image.Image, gameplay: Image.Image) -> None:
    if codex.size != (CODEX_CANVAS, CODEX_CANVAS):
        raise ValueError(f"{asset.key}: invalid codex size {codex.size}")
    if gameplay.size != (GAMEPLAY_CANVAS, GAMEPLAY_CANVAS):
        raise ValueError(f"{asset.key}: invalid gameplay size {gameplay.size}")
    if not codex.getchannel("A").getbbox() or not gameplay.getchannel("A").getbbox():
        raise ValueError(f"{asset.key}: normalized output is empty")
    alpha_values = set(np.unique(np.asarray(gameplay.getchannel("A"))).tolist())
    if not alpha_values.issubset({0, 255}):
        raise ValueError(f"{asset.key}: gameplay output does not have hard alpha")


def _build_one(asset: Asset) -> tuple[Path, Path]:
    with Image.open(_source_path(asset)) as opened:
        transparent = opened.convert("RGBA")
        _validate_master(asset, transparent)
        master = _apply_gamma(transparent, PREBRIGHTEN_GAMMA)
    codex = _normalize(master, CODEX_CANVAS, CODEX_EXTENT)
    gameplay = _pixel_optimize(master)
    _validate_outputs(asset, codex, gameplay)
    slot_root = CANDIDATE_ROOT / asset.slot
    codex_path = slot_root / "codex" / f"{asset.key}.png"
    gameplay_path = slot_root / "gameplay" / f"{asset.key}.png"
    codex_path.parent.mkdir(parents=True, exist_ok=True)
    gameplay_path.parent.mkdir(parents=True, exist_ok=True)
    codex.save(codex_path, optimize=True)
    gameplay.save(gameplay_path, optimize=True)
    return codex_path, gameplay_path


def _contact_sheet(slot: str, assets: list[Asset], kind: str) -> Path | None:
    built: list[tuple[Asset, Path]] = []
    for asset in assets:
        path = CANDIDATE_ROOT / slot / kind / f"{asset.key}.png"
        if path.exists():
            built.append((asset, path))
    if not built:
        return None
    columns = 6
    icon_box = 100 if kind == "codex" else 96
    label_h = 34
    cell_w = 180
    cell_h = icon_box + label_h + 12
    rows = math.ceil(len(built) / columns)
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), (18, 17, 24, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (asset, path) in enumerate(built):
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        with Image.open(path) as opened:
            icon = opened.convert("RGBA")
        if kind == "gameplay":
            icon = icon.resize((icon_box, icon_box), Image.Resampling.NEAREST)
        else:
            icon.thumbnail((icon_box, icon_box), Image.Resampling.LANCZOS)
        sheet.alpha_composite(icon, (x + (cell_w - icon.width) // 2, y + 4))
        label = f"{asset.key}\n{asset.noun}{' ' + asset.grade if asset.grade else ''}"
        draw.multiline_text(
            (x + 5, y + icon_box + 7), label[:52], fill=(225, 222, 232, 255),
            font=font, spacing=2,
        )
    path = CANDIDATE_ROOT / slot / f"qa_{kind}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)
    return path


def _install(asset: Asset) -> None:
    codex_candidate = CANDIDATE_ROOT / asset.slot / "codex" / f"{asset.key}.png"
    gameplay_candidate = CANDIDATE_ROOT / asset.slot / "gameplay" / f"{asset.key}.png"
    if not codex_candidate.exists() or not gameplay_candidate.exists():
        raise FileNotFoundError(f"build candidates before install: {asset.key}")
    archive = RUNTIME_ICONS / "archive" / f"{date.today().isoformat()}_pre_codex_128"
    current = RUNTIME_ICONS / f"{asset.key}.png"
    if current.exists():
        archive.mkdir(parents=True, exist_ok=True)
        backup = archive / current.name
        if not backup.exists():
            shutil.copy2(current, backup)
    CODEX_ICONS.mkdir(parents=True, exist_ok=True)
    shutil.copy2(gameplay_candidate, current)
    shutil.copy2(codex_candidate, CODEX_ICONS / codex_candidate.name)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slot", choices=SLOTS, help="build only one gear slot")
    parser.add_argument("--key", help="build only one exact runtime icon key")
    parser.add_argument("--manifest", action="store_true", help="write manifest.json")
    parser.add_argument("--check", action="store_true", help="report source coverage only")
    parser.add_argument("--install", action="store_true", help="archive and install built assets")
    args = parser.parse_args()

    assets = manifest()
    manifest_path = write_manifest(assets)
    selected = [asset for asset in assets if not args.slot or asset.slot == args.slot]
    selected = [asset for asset in selected if not args.key or asset.key == args.key]
    if args.key and not selected:
        raise SystemExit(f"unknown gear key: {args.key}")
    present = [asset for asset in selected if _source_path(asset).exists()]
    missing = [asset for asset in selected if not _source_path(asset).exists()]
    print(f"manifest: {manifest_path}")
    print(f"coverage: {len(present)}/{len(selected)} transparent masters")
    if missing:
        by_slot = {slot: sum(asset.slot == slot for asset in missing) for slot in SLOTS}
        print("missing:", ", ".join(
            f"{slot}={count}" for slot, count in by_slot.items() if count
        ))
    if args.check or args.manifest:
        return 0
    for asset in present:
        _build_one(asset)
        if args.install:
            _install(asset)
    for slot in SLOTS:
        slot_assets = [asset for asset in selected if asset.slot == slot]
        if slot_assets:
            for kind in ("codex", "gameplay"):
                sheet = _contact_sheet(slot, slot_assets, kind)
                if sheet:
                    print(f"qa: {sheet}")
    if args.install:
        print(f"installed {len(present)} dual-resolution assets; mobile sync still required")
    elif present:
        print(f"built {len(present)} candidate assets (runtime untouched)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
