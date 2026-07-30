# Terrain/scenery art to fix

Low-res, flat props that clash with the game's high-res painterly bar. Replace them to match the good props (`capital_*`, flora, `rock_volcanic`, statues). Files: `game/assets/sprites/<name>.png`.

## Tier 1 — worst, most visible (village + overworld)

| Asset | Native | Defect |
|---|---|---|
| `cottage_a`  | 48×34   | Flat low-res thatched house (the reported one). |
| `cottage_a2` | 48×34   | Thatched house variant — same. |
| `cottage_b`  | 48×28   | Stone house — same. |
| `stall`      | 48×24   | Crude flat market stall. |
| `rock3`      | 384×384 | Flat cel-shaded + **magenta fringe around the silhouette** (chroma bleed). |
| `crypt`      | 48×48   | Crude low-res mausoleum. |
| `signpost`   | 11×13   | Tiny crude signpost. |

## Tier 2 — low-res props clashing with neighbours

| Asset | Native | Defect |
|---|---|---|
| `keep_arch`      | 48×48 | Crude blocky stone arch. |
| `camp_workbench` | 48×40 | Cartoony flat, heavy black outlines. |
| `cook_grill`     | 64×64 | Awkward/unfinished, floating elements. |
| `camp_bonfire`   | 32×32 | Simple/flat, reads cheap. |
| `pillar`         | 16×16 | Crude stone nub. |

## Tier 3 — minor dressing (lowest priority)

`banner_blue` / `banner_green` / `banner_red` (10×21), `hideout_poster` (10×7), `hideout_table` (40×40), `amphora` (10×20), `station_alchemy_t3` (80×72), `station_anvil_t3` (96×83).
