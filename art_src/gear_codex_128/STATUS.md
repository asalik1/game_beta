# Gear codex regeneration status

Each slot owns 180 exact assets: 30 neutral families, 90 B/A/S variants, and 60
named uniques. Benchmarks establish the visual and processing bar before any
agent spends the full 180-generation slice.

| Slot | Benchmark family | Benchmark | Approved alpha | Full slice |
|---|---|---:|---:|---:|
| Weapon | Pike | approved after family + unique card-mass revisions | 6 / 6 | 6 / 180 |
| Helmet | Blessed Greathelm | approved | 6 / 6 | 6 / 180 |
| Armor | Wardsteel Plate | approved | 6 / 6 | 6 / 180 |
| Gloves | Ironwall Gauntlets | approved | 6 / 6 | 6 / 180 |
| Pants | Stormweave Leggings | approved | 6 / 6 | 6 / 180 |
| Boots | Radiant Greaves | approved | 6 / 6 | 6 / 180 |
| Charm | Starshard | approved | 6 / 6 | 6 / 180 |

Shared implementation status:

- `manifest.json` validates all 1,260 runtime keys.
- `tools/art/build_gear_codex_icons.py` produces non-destructive 128px codex and
  separately sharpened/quantized 32px gameplay candidates with QA sheets.
- `Art.codex_item_icon()` and the codex gear views use high-resolution variants
  when present and safely fall back to current 32px runtime art.
- Compile gate and `test_quick.bat` pass with the fallback resolver.
- All 42 seven-slot benchmark candidates are installed in runtime with
  dated backups. Forward+ verification sent both named Pike icons through a
  compact-composition revision; the corrected files are now installed. Mobile
  sync is pending.
