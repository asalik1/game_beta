# Gear codex 128px regeneration

This tree holds approved high-resolution source masters for the complete gear
replacement pass. The runtime contract is intentionally dual-resolution:

- `game/assets/icons/codex/<key>.png`: 128x128 detailed codex art;
- `game/assets/icons/<key>.png`: 32x32 pixel-optimized gameplay art.

Each of the seven independently owned slots contains exactly 180 assets: 30
neutral family masters, 90 authored B/A/S variants, and 60 named uniques. The
complete set is 1,260 regenerated assets.

## Per-slot layout

```text
art_src/gear_codex_128/<slot>/
  generated/  original built-in ImageGen outputs on a flat chroma field
  alpha/      approved transparent masters named exactly like the runtime key
  prompts/    prompt records and generation notes
```

Do not place resized 32px art in `alpha/`. These files must contain genuine
authored detail at substantially higher resolution. Upscaling an existing
runtime icon does not satisfy the contract.

The built-in ImageGen tool is the authorized generator. PixelLab is not
authorized for this task. Generate one opaque item on a perfectly uniform key
background with no floor, shadow, text, frame, or watermark. Use magenta for
green/cyan items and green for purple/magenta items. Remove the background with
the installed imagegen skill helper, then inspect the transparent result before
putting it in `alpha/`.

## Build candidates

Use the bundled Python runtime, which provides Pillow and NumPy:

```powershell
$py = 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py tools/art/build_gear_codex_icons.py --manifest --check
& $py tools/art/build_gear_codex_icons.py --slot weapon
```

Candidate 128px/32px outputs and labelled QA sheets land under
`tmp/gear_codex_128/<slot>/`. Runtime assets remain untouched until an approved
run explicitly uses `--install`. Installation backs up every replaced 32px PNG
before copying either resolution. Sync `game/` to `mobile/game/` only after the
complete desktop pass is approved and tested.
