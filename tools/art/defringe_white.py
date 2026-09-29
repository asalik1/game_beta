#!/usr/bin/env python3
"""Detect pale mattes, then extend opaque RGB into a narrow silhouette band.

Scan is read-only; repair requires explicit paths. Alpha and ALL alpha=255
pixels are immutable. Light interior content refuses repair, with no override.
This is RGB edge dilation for straight-alpha PNGs, not alpha premultiplication.
Requires Pillow, numpy and scipy. Examples:
  python tools/art/defringe_white.py --scan game/assets/sprites --json scan.json
  python tools/art/defringe_white.py game/assets/sprites/tree_teal.png --apply

The 4px silhouette band follows despill_rim; donors must be fully opaque and
within 8px. At least 60 pale, locally contrasting pixels and 8% of the partial
alpha rim are required. Interior light mass greater than the suspect rim is
content, not a matte. These conservative heuristics require visual review.
Animation cells with a matching static canvas are isolated (no cross-frame
donors). Protected skins are scanned for reporting but never repaired.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import tempfile
import os

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

from despill_rim import _rim_mask

BAND = 4
DONOR_RADIUS = 8


def cells(path: Path, width: int, height: int) -> list[slice]:
    """Use authored static dimensions for prop strips, square cells otherwise."""
    static = path.with_name(path.stem.removesuffix('_anim') + '.png')
    fw = width
    if path.stem.endswith('_anim') and static != path and static.exists():
        with Image.open(static) as im:
            if im.height == height and width % im.width == 0:
                fw = im.width
    elif width >= 2 * height and width % height == 0:
        fw = height
    return [slice(x, x + fw) for x in range(0, width, fw)]


def inspect_cell(a: np.ndarray, repair: bool = False) -> tuple[dict, np.ndarray]:
    alpha = a[..., 3]
    rgb = a[..., :3].astype(np.float32)
    light = (rgb @ np.array([.2126, .7152, .0722], dtype=np.float32) >= 185) & (rgb.min(2) >= 160)
    rim = _rim_mask(alpha, BAND)
    partial = rim & (alpha < 255)
    m = dict(rim_partial=int(partial.sum()), pale_rim=0,
             light_interior=int((light & (alpha > 0) & ~rim).sum()), changed=0)
    out = a.copy() if repair else a
    if not (alpha == 255).any() or not (light & partial).any():
        return m, out
    distance, indices = distance_transform_edt(alpha != 255, return_indices=True)
    donor = a[tuple(indices)][..., :3]
    luma_delta = (rgb - donor) @ np.array([.2126, .7152, .0722], dtype=np.float32)
    suspect = partial & light & (distance <= DONOR_RADIUS) & (luma_delta >= 35)
    m['pale_rim'] = int(suspect.sum())
    if repair:
        # Include invisible RGB immediately outside the silhouette for LINEAR.
        outside = (alpha == 0) & (distance_transform_edt(alpha == 0) <= BAND)
        mask = (partial | outside) & (distance <= DONOR_RADIUS)
        changed = mask & np.any(a[..., :3] != donor, axis=2)
        out[..., :3][changed] = donor[changed]
        m['changed'] = int(changed.sum())
    return m, out


def verdict(m: dict) -> str:
    if m['pale_rim'] < 60:
        return 'clean'
    if m['light_interior'] > m['pale_rim']:
        return 'content'
    if m['pale_rim'] / max(1, m['rim_partial']) < .08:
        return 'trace'
    return 'HALO'


def measure(path: Path) -> dict:
    with Image.open(path) as im:
        a = np.array(im.convert('RGBA'))
    result = dict(path=path.as_posix(), rim_partial=0, pale_rim=0, light_interior=0)
    for sl in cells(path, a.shape[1], a.shape[0]):
        m, _ = inspect_cell(a[:, sl])
        for key in ('rim_partial', 'pale_rim', 'light_interior'):
            result[key] += m[key]
    result['verdict'] = verdict(result)
    result['protected'] = 'skins' in path.parts
    return result


def defringe(path: Path, apply: bool = False) -> dict:
    m = measure(path)
    m['changed'] = 0
    if m['protected'] or m['verdict'] != 'HALO':
        return m
    with Image.open(path) as im:
        before = np.array(im.convert('RGBA'))
    after = before.copy()
    for sl in cells(path, before.shape[1], before.shape[0]):
        cell_m, repaired = inspect_cell(before[:, sl], repair=True)
        # A mixed strip may include a light-content frame: refuse the entire file.
        if verdict(cell_m) == 'content':
            m['verdict'] = 'content'
            return m
        after[:, sl] = repaired
    assert np.array_equal(before[..., 3], after[..., 3])
    assert np.array_equal(before[before[..., 3] == 255], after[before[..., 3] == 255])
    m['changed'] = int(np.any(before != after, axis=2).sum())
    if apply and m['changed']:
        # Atomic replacement breaks asset hardlinks instead of mutating another checkout.
        fd, name = tempfile.mkstemp(prefix='.' + path.stem, suffix='.png', dir=path.parent)
        os.close(fd)
        tmp = Path(name)
        try:
            Image.fromarray(after).save(tmp, optimize=True)
            os.replace(tmp, path)
        finally:
            tmp.unlink(missing_ok=True)
    return m


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('paths', nargs='*', type=Path)
    ap.add_argument('--scan', type=Path)
    ap.add_argument('--json', type=Path)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    if args.scan and (args.apply or args.paths):
        ap.error('--scan is read-only and cannot be combined with paths/--apply')
    if not args.scan and not args.paths:
        ap.error('give --scan directory or explicit PNG paths')
    paths = sorted(args.scan.rglob('*.png')) if args.scan else args.paths
    rows, errors = [], []
    for p in paths:
        try:
            m = measure(p) if args.scan else defringe(p, args.apply)
            rows.append(m)
            if m['verdict'] == 'HALO' or not args.scan:
                print(json.dumps(m), flush=True)
        except (OSError, ValueError) as exc:
            errors.append(dict(path=str(p), error=str(exc)))
            print(f'ERROR {p}: {exc}', flush=True)
    summary = dict(scanned=len(rows), verdicts=dict(Counter(m['verdict'] for m in rows)),
                   protected=sum(m['protected'] for m in rows), errors=errors)
    print(json.dumps(summary), flush=True)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(dict(summary=summary, files=rows), indent=2) + '\n', encoding='utf-8')
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
