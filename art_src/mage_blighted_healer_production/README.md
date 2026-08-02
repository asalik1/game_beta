# Blighted Healer Mage — production regeneration

Generated with Codex's built-in ImageGen tool and installed on 2026-07-31.
The binding concept was approved by the owner as:

`art_src/mage_base_refinement/01_blighted_healer.png`

This directory contains the high-resolution generation masters, rejected
iterations retained for auditability, and the visual-QA artifacts used to
install the playable `mage` base family.

## Binding art contract

- the same composed adult woman and distinctive face in every visible facing;
- extremely long loose white hair with stable part, length, and volume;
- ivory healer outer robes over green-black contaminated/decaying underlayers,
  always in that layer order;
- brown practical footwear;
- exactly one natural twisted dark-wood staff, consistently gripped on the
  same physical side;
- unchanged staff length and forked wooden head around one cloudy colorless
  focus;
- only one tiny, dim failed-healing green inclusion inside the focus;
- exactly one weathered remedy satchel and one slim closed treatment journal
  together on the same hip;
- no permanent fire, ice/blue, wind, generic elemental aura, or costume
  redesign;
- low top-down orthographic/isometric action-RPG camera;
- mature proportions, readable color masses, deliberate pixel clusters, and
  controlled texture that remain clear at the 52 px rendered-body target.

Firebolt, Frost Nova, Blink, Meteor, and theme variants retain their runtime
effects. The base body animation is deliberately theme-neutral.

## Runtime contract preserved

The existing `mage` contract is authoritative:

| logical clip | installed stem | frames | directions |
|---|---|---:|---|
| static | `mage.png` | 1 | base |
| idle | `mage_anim` | 5 | base + S/SE/E/NE/N/NW/W/SW |
| walk | `mage_walk` | 8 | base + S/SE/E/NE/N/NW/W/SW |
| run | `mage_run` | 7 | base + S/SE/E/NE/N/NW/W/SW |
| Firebolt body | `mage_attack` | 7 | base + S/SE/E/NE/N/NW/W/SW |
| Nova/Meteor body | `mage_cast` | 7 | base + S/SE/E/NE/N/NW/W/SW |
| Blink body | `mage_dash` | 7 | base + S/SE/E/NE/N/NW/W/SW |
| death | `mage_death.png` | 9 | existing base-only contract |

That is 56 character PNGs. These existing ancillary effect assets are not
character frames and were not regenerated or overwritten:

- `mage_crystal_bolt.png`
- `mage_crystal_decree.png`
- `mage_firebolt.png`
- `mage_prism_monolith.png`
- `mage_void_bullet.png`
- `mage_void_needle.png`
- `mage_void_spindle.png`

Ability wiring was already correct and remains unchanged:

- `a1` Firebolt -> `attack`
- `a2` Frost Nova -> `cast`
- `a3` Blink -> `dash`
- `ult` Meteor -> `cast`

## Authored directions and mirroring

ImageGen authored S, SE, E, NE, and N. The deterministic builder mirrors:

- E -> W
- SE -> SW
- NE -> NW

Mirroring is frame-local and preserves timeline order. All eight installed
directions were inspected on labeled sheets. The approved NE source is truly
rear-right; NW is its controlled mirror rather than an inverted source label.

## Accepted production masters

| source | layout | use |
|---|---|---|
| `regen_base_rotations_v1.png` | 1x5 | binding S, SE, E, NE, N identity |
| `regen_idle_v1.png` | 5x5 | five-direction idle |
| `regen_walk_s_se_e_ne_v1.png` | 4x8 | S/SE/E/NE two-step walk |
| `regen_walk_n_v3_2x4.png` | 2x4 | N eight-frame walk, flattened row-major |
| `regen_run_s_se_e_ne_v1.png` | 4x7 | S/SE/E/NE run |
| `regen_run_n_v1.png` | 1x7 | N run |
| `regen_attack_s_se_e_ne_v1.png` | 4x7 | S/SE/E/NE staff-point attack |
| `regen_attack_n_v1.png` | 1x7 | direction-locked N attack |
| `regen_cast_s_se_e_v2.png` | 3x7 | counted S/SE/E cast replacement |
| `regen_cast_ne_v2.png` | 1x7 | direction-locked NE cast |
| `regen_cast_n_v1_row2.png` | 2x7 | N cast is the second row |
| `regen_dash_se_e_v1_rows1_4_rejected.png` | 4x7 | only approved source rows 2-3: SE/E |
| `regen_dash_s_v3.png` | 1x7 | direction-locked S dash |
| `regen_dash_ne_v2_row2.png` | 2x7 | NE dash is the second row |
| `regen_dash_n_v2_4plus3.png` | 4+3 | N seven-frame dash, flattened top then bottom |
| `regen_death_v1_3x3.png` | 3x3 | nine-frame base death |

The dash filename records that its outer source rows are rejected; the builder
selects only the explicitly approved SE and E rows. No rejected row reaches
runtime output.

## Rejected iterations and repairs

- `regen_walk_n_v1_rejected_7frames.png`: requested eight but returned seven.
- `regen_walk_n_v2_rejected_7frames.png`: second one-row request also returned
  seven. It was not padded or duplicated. A real 2x4 eight-pose repair replaced
  it.
- `regen_cast_s_se_e_v1_row4_rejected_crop.png`: the fourth row was cropped,
  and deeper contact-sheet inspection proved the first three rows also
  contained only six bodies despite a seven-frame request. The builder never
  manufactures a seventh frame; the true counted 3x7 v2 master replaced it.
- `regen_dash_se_e_v1_rows1_4_rejected.png`: S allowed the staff to float
  separately at peak and NE drifted. Only its sound SE/E rows are selected.
- `regen_dash_n_v1_rejected_6frames.png`: returned six figures. The 4+3
  direction-locked source replaced it.

These rejections are intentionally preserved beside accepted masters so a
future model can audit what failed and why.

## Prompt log

Every accepted call used the built-in ImageGen tool, a perfectly flat
`#00ff00` field, generous gutters, no shadows/floor/text/grid/watermark, and
the approved repository copy as the binding reference.

### Rotation

Requested exactly five rotations in order S, SE, E, NE, N. Repeated the full
identity/equipment contract; required identical scale, camera, baseline,
staff construction/side, satchel/journal side, robe layer order, face, hair,
hands, and footwear; prohibited elemental effects and redesign.

### Idle

Requested a 5x5 grid. Timeline: grounded neutral -> subtle inhale -> neutral ->
subtle exhale/opposite cloth settling -> loop closure. Feet planted; no spell
or staff raise.

### Walk

S/SE/E/NE used a 4x8 grid. N used a counted 2x4 repair because two one-row
attempts returned only seven bodies. Timeline:

1. left-foot contact;
2. left-foot load;
3. right leg passes with low knee;
4. left-foot advance/heel-toe release;
5. right-foot contact, visibly opposite frame 1;
6. right-foot load;
7. left leg passes with low knee, visibly opposite frame 3;
8. right-foot advance into frame 1.

The prompt explicitly prohibited a march, parade step, high-knee run, shuffle,
float, sliding feet, or unrelated idle poses.

### Run

S/SE/E/NE used 4x7; N used 1x7. Timeline: left contact/load -> right pass ->
low crossover -> right contact/load -> left pass into loop. Required an urgent
but controlled caster run, real alternation, planted feet, modest bob, stable
staff and attached kit.

### Attack

S/SE/E/NE used 4x7; N used 1x7. Timeline: ready -> weight/staff draw -> forward
aim -> decisive staff-point release peak -> recoil -> lower -> idle recovery.
No projectile or colored effect was baked in. The cloudy focus could catch
only a tiny neutral highlight at the peak.

### Cast

The accepted S/SE/E repair explicitly demanded three rows, seven complete
bodies in every row, and 21 total figures. NE and N were direction-locked.
Timeline: ready -> free hand opens -> staff inward -> staff raised/anticipation
-> decisive plant/command -> release -> idle recovery. The prompt prohibited
flame, ice, snow, blue glow, wind, lightning, meteor, projectile, aura, or
rune circle.

### Dash

Direction-locked repairs emphasized that the staff must remain physically
gripped in every frame—never floating or separated. Timeline: ready -> compress
-> lean -> longest low phase-step -> trailing foot gathers -> brake -> idle.
The body stays present; no trail, ghost duplicate, transparency, aura, rune,
smoke, or elemental effect is baked in.

### Death

Requested a counted 3x3 grid: weakened standing -> knees buckle -> hand slips
lower -> one knee -> sideways loss of balance -> shoulder/hip reaches ground ->
fully prone -> hair/hem settles -> held grounded corpse. Required no reversal,
gore, disappearance, teleporting/broken staff, or detached healer kit.

## Deterministic conversion

Run:

```powershell
$py = 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py tools\art\build_blighted_mage.py
& $py tools\art\anim_sheet.py mage all art_src\mage_blighted_healer_production\qa 2
& $py tools\art\qa_blighted_mage.py
```

`tools/art/build_blighted_mage.py`:

1. removes the bright green field while retaining the intended dark
   green-black blighted textiles;
2. finds real gutters and encodes every irregular accepted source layout;
3. normalizes a whole direction/clip from its first reference pose rather than
   independently scaling frames;
4. stages at a common baseline;
5. derives west mirrors frame-by-frame;
6. assembles a shared 298 px square runtime cell;
7. writes only the exact existing 56-file character contract;
8. validates expected frame counts, geometry, hard alpha, and nonempty cells.

The larger source cell changes texture density, not gameplay size.
`player_core.gd` still measures the idle body and renders the Mage against the
existing 52 px hero-body target.

## Archive and QA

The exact pre-replacement character family is preserved under the ignored:

`backup/mage_base_pre_blighted_healer_2026-07-31/`

`sha256_manifest.json` records all 56 old files and reports a successful
source/archive match for each.

Visual QA lives in `qa/`:

- labeled PNG sheets for idle, walk, run, dash, attack, cast;
- eight-direction simultaneous GIFs for those same clips;
- labeled nine-frame death sheet and death GIF.

QA result: stable identity/equipment, correct authored and mirrored facings,
natural alternating walk, controlled run, complete staff through actions,
direction-locked recoveries, theme-neutral spell body motions, and coherent
grounded death.

Automated result after import:

- `python tools/art/verify_art.py mage`: `VERIFY OK`
- standalone compile gate: `COMPILE OK (97 scripts)`
- `test_quick.bat`: `AUTOTEST QUICK PASS`

No files were staged or committed.
