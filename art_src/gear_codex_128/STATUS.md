# Gear codex regeneration status

Each slot owns 180 exact assets: 30 neutral families, 90 B/A/S variants, and 60
named uniques. The full 1,260-asset pass is complete.

| Slot | Benchmark family | Benchmark | Approved alpha | Full slice |
|---|---|---:|---:|---:|
| Weapon | Pike | approved after family + unique card-mass revisions | 180 / 180 | 180 / 180 |
| Helmet | Blessed Greathelm | approved | 180 / 180 | 180 / 180 |
| Armor | Wardsteel Plate | approved | 180 / 180 | 180 / 180 |
| Gloves | Ironwall Gauntlets | approved | 180 / 180 | 180 / 180 |
| Pants | Stormweave Leggings | approved | 180 / 180 | 180 / 180 |
| Boots | Radiant Greaves | approved | 180 / 180 | 180 / 180 |
| Charm | Starshard | approved | 180 / 180 | 180 / 180 |

Shared implementation status:

- `manifest.json` validates all 1,260 source masters and runtime keys.
- `tools/art/build_gear_codex_icons.py` produces non-destructive 128px codex and
  separately sharpened/quantized 32px gameplay candidates with QA sheets.
- `Art.codex_item_icon()` and the codex gear views use high-resolution variants
  when present and safely fall back to current 32px runtime art.
- All 1,260 dual-resolution assets are installed in runtime, with dated
  pre-regeneration backups retained under `game/assets/icons/archive/`.
- Mobile was re-synced with `tools/sync_mobile.py --apply --gate`; its compile
  gate and quick suite passed.
- Desktop import completed; both `test_quick.bat` and `test.bat` passed.
