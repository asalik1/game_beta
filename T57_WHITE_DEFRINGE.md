# T57 — white source mattes on trees

The teal tree family and `grave_deadtree` carried pale RGB in partially
transparent silhouette pixels. The scenery factory uses LINEAR for these
painterly PNGs (`Art.prop_texture_filter`), exposing that matte over grass.
This change repairs source RGB; it does not change sampling or opacity.

## Repaired files

Paths are relative to `game/assets/sprites/`; the same six PNGs are synced,
byte for byte, to `mobile/game/assets/sprites/`.

| PNG | Suspect pale rim pixels before → after | RGB pixels changed, including invisible padding |
|---|---:|---:|
| `grave_deadtree.png` | 4,978 → 0 | 51,609 |
| `tree_teal.png` | 7,165 → 0 | 51,962 |
| `tree_teal2.png` | 2,057 → 0 | 26,961 |
| `tree_teal2_anim.png` | 8,087 → 0 | 111,463 |
| `tree_teal3.png` | 5,784 → 0 | 46,071 |
| `tree_teal_anim.png` | 29,352 → 0 | 211,133 |

Total: **57,423 suspect rim pixels removed; 499,199 RGB pixels rewritten**.
Every alpha value, every fully opaque RGBA pixel, every canvas dimension and
every animation cell remains unchanged. A second application leaves all six
PNG files byte-identical. The repaired statics and all eight animation cells
were visually reviewed on grass-colored backgrounds before committing.

The large moss-draped tree is `tree_teal`; the twisted teal pine is
`tree_teal3`. `tree_teal2` is the rounded teal sibling. Some pale drawing is
fully opaque: `tree_teal` retains 2,579 light opaque pixels and `tree_teal3`
retains 1,749. Those highlights/moss marks are deliberately untouched. This
is not a claim that every pale line in the original painting has disappeared.

## Detection and repair contract

`tools/art/defringe_white.py` uses a four-pixel silhouette band, luminance
>=185, minimum RGB channel >=160, and a luminance excess >=35 over the
nearest fully opaque donor within eight pixels. A candidate needs >=60 such
pixels and >=8% of the partially transparent rim. Greater light-pixel mass
inside the silhouette causes a **content refusal**, without a force option.
Sparse findings remain **trace**. Protected skins can be counted read-only
but cannot be repaired by this tool.

For a reviewed candidate, RGB in the partial-alpha rim and the adjacent
transparent padding is copied from the nearest fully opaque donor; alpha is
never rewritten. No donor beyond eight pixels is accepted. Prop strips use
their static sibling's cell width, so donors cannot cross frame boundaries.
Mixed strips with a content frame are refused before any write. Atomic PNG
replacement breaks hardlinks instead of modifying another checkout's inode.

This is a conservative heuristic, not a semantic classifier: glowing FX,
fire, and narrow highlights still need visual triage. Scanning never writes
and there is no batch scan-and-apply mode.

```powershell
python tools/art/defringe_white.py --scan game/assets/sprites --json build/qa/t57/scan.json
python tools/art/defringe_white.py game/assets/sprites/tree_teal.png --apply
python tools/art/test_defringe_white.py
```

Snow/winter trees were left intact. `tree_snow` and all winter sprites are
content refusals; the other snow trees have too few locally contrasting
pixels to qualify. `tree_spore` and `tree_spore3` are content; `tree_spore2`
and its animation are sparse trace findings, not an automatic repair.

## Validation and evidence

**Whole-corpus result:** 5,350 PNGs read, zero read errors; 1,785 protected
skin files included read-only. Before repair: **22 HALO candidates**, 604
content refusals, 26 traces, 4,698 clean. After the six tree repairs: **16
candidates**, with the same content/trace counts and 4,704 clean. The corpus
scan encountered the already-repaired trees; the six saved original
measurements supply their pre-repair counts. Full candidate measurements and
repair hashes are in [findings.json](docs/qa/t57/findings.json).

The remaining candidates were visually inspected and retained, rather than
being declared confirmed white-matte bugs:

| Files under `game/assets/sprites/` | Disposition |
|---|---|
| `auroch_minotaur_walk_codex_n.png` | Metal/armor highlights; no tree-like continuous white ring confirmed |
| `fangmaw_anim_codex.png` | Teeth, bone and edge highlights; retained authored content |
| `halla_walk_codex_e.png`, `halla_walk_codex_ne.png`, `halla_walk_codex_se.png` | Luminous butterflies, candle and wing detail; retained authored content |
| `fx/void_contact.png` | White core of a glow sprite; retained FX |
| `camp_bonfire.png`, `camp_bonfire_anim.png` | Bright fire edges; retained FX |
| `camp_furnace.png`, `camp_furnace_anim.png` | Light stone edges/bevels; no continuous white matte confirmed |
| `station_alchemy_t3.png`, `station_alchemy_t3_anim.png` | Stone/metal edge highlights; no continuous white matte confirmed |
| `void_monolith.png`, `void_monolith_anim.png`, `void_obelisk.png`, `void_obelisk_anim.png` | Lit stone bevels and purple glow; no continuous white matte confirmed |

This count is a **candidate count**, not a claim that 16 further defective
assets are established. [Retained candidate sheet](docs/qa/t57/retained_candidates.jpg).

Validation completed:

- `verify_art.py grave_deadtree tree_teal tree_teal2 tree_teal3`: **0 FAIL,
  8 WARN before and after**. Warning lines match exactly: six BLEED counts
  (alpha is deliberately unchanged) and two existing RIGIDDRIFT warnings
  for foliage sway (8px / 7px). **WARN delta: 0.**
- `audit_prop_anims.py --only tree_teal,tree_teal2`: **2 strips, 0 flagged**,
  unchanged motion metrics (base drift 0px; pulse 2% / 0%).
- Python regression fixtures: **7 passed**. Actual-file invariant checks:
  all six have unchanged alpha/opaque bytes, idempotent PNG bytes and
  identical mobile copies.
- Post-import `preflight.py --fast`: **0 FAIL, 2 WARN**, both the same
  existing foliage RIGIDDRIFT warnings. Its earlier six stale-import findings
  were cleared by the bundled import.
- Locked import + screenshot job: **exit 0**, `COMPILE OK (348 scripts)`,
  `WHITE DEFRINGE PASS`, **8 captures**. Lock wait 430s; job occupancy 125s;
  renderer capture 51s. Only the runner's established texture-RID /
  RenderingServer shutdown exemptions appeared; no script/parse failures.

The owner's two cases are shown at native screenshot pixels in the
[in-game comparison](docs/qa/t57/owner_tree_comparison.png). The hugging pale
outline is reduced; opaque highlight tips/moss remain. All repaired sprites
and all animation frames were also reviewed in the
[sprite comparison](docs/qa/t57/trees_comparison.jpg) and
[animation comparison](docs/qa/t57/animations_comparison.jpg).

Local working evidence is under `build/qa/t57/`: original PNGs in `before/`,
`trees_scan.json`, `invariants.json`, `trees_comparison.jpg`, and
`animations_comparison.jpg`. The seven Python regression fixtures cover
immutable alpha/opaque pixels, idempotence, dry-run behavior, interior snow,
missing opaque donors, frame isolation, mixed-strip refusal, and protected
skins.

The reusable `shot_white_defringe` rig boots the actual game on village grass
and creates the four tree cases through `_add_obstacle`. It checks LINEAR,
uses production scale/tint/camera rendering, freezes wind and animation
frame zero, and swaps saved originals against the imported repaired texture
in the same engine session. The originals receive Godot's alpha-border
import treatment. Captures are controlled fixtures, not a live playthrough.

The single locked job bundles desktop import and all eight before/after
captures. No full gameplay suite or mobile engine run is scheduled here:
the task's one-heavy-run limit reserves those for the integrator's normal
batch gates. Mobile source PNGs are already synced.
