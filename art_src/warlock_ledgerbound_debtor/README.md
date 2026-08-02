# Ledgerbound Debtor — production sprite sources

Built with Codex's built-in ImageGen tool on 2026-07-31 from the owner-approved
identity anchor:

`art_src/warlock_base_redesign/05_ledgerbound_debtor_clean_hand.png`

The deterministic installer is:

`tools/art/build_ledgerbound_warlock.py`

Run it from the repository root with the bundled Pillow/NumPy Python:

```powershell
& 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  tools/art/build_ledgerbound_warlock.py
```

## Binding identity and equipment contract

- Lean adult with the approved tired pale face, dark hair, and black hood.
- Soot-black scholar coat, aged-gold edges/geometric contract stitching,
  parchment-colored torn inner panels, muted burgundy lining, black boots.
- Branching contract ink and countersign bands stay on the character's
  **anatomical right** hand/forearm (viewer-left in the S/front view).
- No circular wax seal, button, gem, or other object on either hand.
- Exactly one battered ledger.
- Idle, walk, and run: ledger CLOSED and vertical at anatomical-left hip,
  attached to the same belt point by one short chain.
- Attacks/casts: that same tethered ledger is deliberately drawn and opened;
  recovery visibly closes and returns it to anatomical-left hip.
- Death: ledger stays closed, tethered, and visibly beside anatomical-left hip
  through the held corpse.
- No skull, floating companion, staff, flames, tentacles, or generic
  necromancer redesign.

The body gate authors S, SE, E, NE, and N. The builder derives W, SW, and NW
one frame at a time from E, SE, and NE, preserving frame order.

## Runtime contract

Existing base name remains `warlock`; no class-data or GDScript mapping changed.

| Runtime stem | Frames | Source action |
|---|---:|---|
| `warlock_anim` | 5 | restrained idle |
| `warlock_walk` | 7 | ordinary alternating two-step walk |
| `warlock_run` | 7 | compact committed run |
| `warlock_attack` | 9 | Shadowbolt |
| `warlock_attack2` | 9 | Dark Pact |
| `warlock_cast` | 9 | Void Rift |
| `warlock_ult` | 9 | Hex |
| `warlock_death` | 9 | directionless collapse |

Ability mapping already present in `player_core.gd`:

- `a1` Shadowbolt -> `attack`
- `a2` Hex -> `ult`
- `a3` Dark Pact -> `attack2`
- class ultimate Void Rift -> `cast`

`warlock_eldritch_bolt.png` and `warlock_shadowbolt.png` are separate effect
sprites. The builder deliberately does not alter them.

## Accepted sources and row mapping

| Source | Use |
|---|---|
| `v01_base_rotations_keyed.png` | approved S/SE/E/NE/N identity gate |
| `v02_idle_main_keyed.png` | S/SE/E/NE idle |
| `v03_idle_n_source_keyed.png` | full N idle row; replaces v02's edge-touching N |
| `v04`–`v08_walk_<dir>_keyed.png` | direction-locked S/SE/E/NE/N walks |
| `v09_run_keyed.png` | S/SE/E/NE/N run |
| `v10_attack_shadowbolt_main_keyed.png` | S/SE/E/N Shadowbolt |
| `v11_attack_shadowbolt_ne_keyed.png` | direction-locked NE Shadowbolt |
| `v12_attack2_pact_main_keyed.png` | visually returned E/SE/S/N; builder maps explicitly |
| `v13_attack2_pact_ne_keyed.png` | direction-locked NE Dark Pact |
| `v14_ult_hex_main_keyed.png` | S/SE/E/N Hex |
| `v15_ult_hex_ne_keyed.png` | direction-locked NE Hex |
| `v16_cast_rift_main_keyed.png` | S/SE/E/N Void Rift |
| `v17_cast_rift_ne_keyed.png` | direction-locked NE Void Rift |
| `v18_death_keyed.png` | superseded death; final ledger was too occluded |
| `v19_death_visible_ledger_keyed.png` | active death repair with visible tethered ledger |

The multi-row Shadowbolt and Hex masters returned eight visible authored
columns despite nine being requested. Their eighth frame is already the
complete closed-book recovery. The builder retains all eight real poses and
duplicates only that final held recovery as runtime f9; it never cuts eight
figures into nine cells.

Effect-bearing source grids use body-weighted gutter detection so a detached
bolt, countersign, or rift cannot be mistaken for an extra character. The
death repair uses its verified full-height empty gutter coordinates because
the progressively widening collapse is intentionally not an equal grid.

## Prompt log

All calls used the built-in ImageGen tool, flat `#00ff00` chroma, no
floor/shadow/text/grid, premium hand-pixeled Crownless rendering, low top-down
orthographic/isometric camera, full-body padding, and the complete binding
identity/equipment contract above.

### `v01` rotation

Image 1 was the approved concept anchor. Requested exactly five rotations,
left-to-right S, SE, E, NE, N, with identical scale, proportions, palette,
ground line, anatomical-right ink hand, anatomical-left closed chained ledger,
and no hand button/seal.

### `v02` / `v03` idle

Five columns: neutral rest, subtle inhale, gentle exhale, opposite coat/chain
settle, return near f1. Feet planted. `v02` returned all five direction rows
but its N row touched the lower edge. `v03` was the earlier four-row result;
its full fourth/back row is used as the N repair.

### `v04`–`v08` walk

One seven-frame call per authored direction. Timeline:

1. anatomical-left foot contact;
2. left load;
3. anatomical-right leg passes with low knee;
4. neutral crossover;
5. right foot contact, visibly opposite f1;
6. right load;
7. left leg passes and flows into f1.

Prompts explicitly required planted feet, modest bob, ordinary travel, and no
march, parade step, high knees, shuffle, or run.

### `v09` run

Five rows, seven columns: left contact, compression, drive, passing/brief
flight, opposite right contact, compression, drive to loop. Faster and more
committed than walk, with ledger and chain reacting to weight without opening.

### `v10` / `v11` Shadowbolt

Closed left-hip ledger -> reach -> draw tethered ledger -> open -> right ink
hand gathers a compact charcoal-violet bolt -> release -> recoil/fade -> close
and return. The combined source omitted NE; `v11` is the locked NE repair.

### `v12` / `v13` Dark Pact

Closed ledger -> reach/draw/open -> anatomical-right inked palm toward sternum
-> restrained black/burgundy contract lines join book, wrist, and chest ->
lines retract/recoil -> close/return. `v13` repairs the omitted NE row.

### `v14` / `v15` Hex

Closed ledger -> reach/draw/open -> anatomical-right finger traces one small
abstract burgundy-black countersign -> cast -> sign fades -> close/return.
No readable writing or generic necromancy. `v15` repairs NE.

### `v16` / `v17` Void Rift

Closed ledger -> reach/draw/open -> right hand rises -> forceful downward tear
with one narrow blue-black rift sliver -> contraction/recoil -> close/return.
No portal background or giant aura. `v17` repairs NE.

### `v18` / `v19` death

One-way collapse: weakened stand -> knees soften -> fold -> one knee -> lose
balance -> ground contact -> side settle -> cloth/chain settle -> held corpse.
`v18` was rejected because the ledger became too occluded. `v19` used v01 as
identity and v18 only as timing reference, requiring the same CLOSED ledger to
drag visibly beside anatomical-left hip and remain visibly chained through f9.

## Archive and QA

The exact 65 pre-replacement character PNGs are preserved locally under the
ignored folder:

`backup/warlock_base_pre_ledgerbound_debtor_2026-07-31/`

`SHA256.csv` records every original hash. Post-copy comparison result:
65 files archived, zero mismatches.

Labeled contact sheets and eight-facing motion GIFs are under `qa/`. Death has
its own directionless labeled contact sheet/GIF. The final visual pass checked
direction labels, book/chain continuity, ink-hand sidedness, walk alternation,
non-marching cadence, recovery facing, and the held corpse.
