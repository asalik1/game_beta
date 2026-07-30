# Lore-authored gem icon masters

These 14 masters were generated with Codex's built-in image-generation tool on
2026-07-30 from the flavor progression in
`PROPOSALS/GEAR_FLAVOR/BAGS_GEMS.md`. Each is a strict 5x2 sheet:

- row 1: levels 1-5
- row 2: levels 6-10
- shared quality rhythm: rough 1-3, cut 4-6, fine 7-9, perfected 10

The central art rule is that levels inside a band remain visually distinct.
Growth changes silhouette, mass, internal motif, and highlight language—not
only the number of facet lines.

## Family motifs

| Family | Runtime stat | Lore motif |
|---|---|---|
| Ruby | `atk_flat` | raw red chip → killing-weight jewel → held-blood drop |
| Garnet | `hp_pct` | Vale pebble → stubborn shield-boss |
| Topaz | `crit` | accidental facet → flaw-seeking unwavering point |
| Onyx | `physres` | dense nub → anvil block → mirror-dark impact boss |
| Lapis | `magres` | ward-paint lump → ward wall → closed Concord seal |
| Bloodstone | `physpen` | red-flecked green chip → seam-finding spear |
| Amethyst | `magpen` | humming snag → ward-opening key/weave |
| Jade | `eva` | slick pebble → displaced lens/crescent |
| Amber | `dex` | sap lump → trapped insect forever mid-wingbeat |
| Sunstone | `dmg_pct` | warm coal → trapped noon → captured sunrise |
| Sapphire | `cdr` | time-notch → hourglass → complete stolen hour |
| Opal | `combo` | buried flicker → cadence chain → unbroken color loop |
| Tenacity | `flat_dr` | pressure fleck → compressed strata → mountain core |
| Vampire Eye | `lifesteal` | warm dark chip → living cabochon → closed eye |

All sheets use a deliberately artificial green or magenta screen. Build and
install the native 32x32 sprites with:

```text
python tools/art/build_gem_icons.py
```

The builder preserves the authored 5x2 geometry, removes only edge-connected
chroma, writes `game/assets/icons/gem_<stat>_lv<1..10>.png`, mirrors them to
mobile, validates hard alpha and per-level uniqueness, and refreshes
`qa_contact_sheet.png`.

## Prompt contract

Shared prompt:

```text
Use case: stylized-concept
Asset type: production pixel-art game UI sprite sheet for Crownless
Layout: exactly ten isolated sprites in a strict 5-column by 2-row grid;
levels 1-5 on row one and 6-10 on row two; equal spacing and centers.
Style: crisp hand-authored 32-bit pixel art readable at 32x32; hard pixel
clusters; limited palette; charcoal one-pixel outline; upper-left lighting.
Progression: every level changes silhouette, mass, internal motif, and
highlight pattern—not merely facet count. Levels 1-3 rough, 4-6 cut, 7-9
supernatural near-flawless, 10 uniquely perfected.
Constraints: loose gemstones only; no text, numbers, labels, UI frames, logos,
watermark, jewelry mounts, shadows, gradients, or floor plane.
```

Each family prompt then supplied the ten concrete stage descriptions summarized
in the table above, using the exact lore progression from `BAGS_GEMS.md`.
