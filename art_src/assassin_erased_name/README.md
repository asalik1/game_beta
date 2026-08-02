# Erased Name Assassin — production source and rebuild log

This directory is the complete reproducible source package for the regenerated
base Assassin. It installs the exact legacy runtime filename contract without
changing gameplay code.

## Approved design lock

- Identity: **Erased Name**.
- Face and eyes are completely unreadable inside a matte-black hood void.
- Dark layered leather/cloth armor, red forearm bindings, and a filed-blank
  clasp are retained in every facing.
- Exactly one long, narrow stabbing blade is held in the anatomical right hand.
- Exactly three small throwing knives are sheathed together at the anatomical
  left hip. `attack2` draws/casts those same three; it never creates a fourth.
- No second sword, smoke, aura, blood, or ambient magic effect.
- S, SE, E, NE, and N are authored. W, SW, and NW are deterministic mirrors.

The approved design anchor is
`../assassin_base_refinement/01_erased_name.png`. The first production source,
`v01_base_rotations_keyed.png`, locks the five authored rotation views.

## Runtime contract

The builder writes 74 character PNGs under `game/assets/sprites`:

| Family | Runtime role | Frames | Direction handling |
| --- | --- | ---: | --- |
| `assassin.png` | static base | 1 | S idle f1 |
| `assassin_anim*` | idle | 4 | 8 directions |
| `assassin_walk*` | walk | 6 | 8 directions |
| `assassin_run*` | run | 6 | 8 directions |
| `assassin_attack*` | Stab / `a1` | 7 | 8 directions |
| `assassin_attack2*` | Fan of Knives / `a3` | 7 | 8 directions |
| `assassin_dash*` | Shadow Dash / `a2` | 7 | 8 directions |
| `assassin_ult*` | Death Mark transition / `ult` | 9 | 8 directions |
| `assassin_ultidle*` | Death Mark active idle | 7 | 8 directions |
| `assassin_death.png` | death | 9 | directionless |

All installed strips share one integer cell size, hard alpha, one baseline, and
the existing names expected by `player_core.gd`.

## Source inventory

Accepted sources:

| Source | Content |
| --- | --- |
| `v01_base_rotations_keyed.png` | S, SE, E, NE, N design rotation |
| `v02_idle_front_keyed.png` | S, SE, E idle rows used by the build |
| `v03_idle_rear_keyed.png` | repaired complete NE and N idle rows |
| `v04`–`v08_walk_*` | one six-frame walk strip per authored facing |
| `v09_run_keyed.png` | five rows × six-frame run |
| `v10`–`v14_attack_stab_*` | five independently authored seven-frame stabs |
| `v15_dash_frames1-6_keyed.png` | five rows × six dash poses |
| `v17`–`v21_attack2_*` | one six-pose Fan of Knives strip per facing |
| `v22_ult_frames1-6_keyed.png` | five rows × six cloak-compression poses |
| `v23_ultidle_s_se_e_n_frames1-6_keyed.png` | active idle S/SE/E/N |
| `v24_ultidle_ne_7frames_keyed.png` | complete seven-pose NE active idle |
| `v25_death_9frames_keyed.png` | clean nine-pose directionless collapse |

Rejected iterations are deliberately retained and named `REJECTED_*` so future
work does not accidentally repeat a failed choice:

- combined stab sheets returned only six columns despite a seven-frame prompt;
- the first NE stab showed an apparent fourth hip knife;
- generated dash recovery had the wrong knife count;
- the first combined Fan of Knives had four projectiles and facing drift;
- the first SE Fan pass was too frontal;
- the attempted ult continuation reordered its facing rows.

The accepted NE stab is `v13_attack_stab_ne_keyed.png`; its wrong-count
predecessor remains `REJECTED_v13_attack_stab_ne_4knives.png`.

## Generation method

All raster generation and correction used the built-in ImageGen tool.

1. Start from the approved design anchor and request a pure `#00ff00`
   background with no labels, grid, shadows, effects, or crop.
2. Author only S/SE/E/NE/N. Explicitly say that NE/N remain rear-facing for
   every action frame.
3. Repeat the complete equipment lock in every prompt: unreadable hood, one
   right-hand blade, three left-hip knives, red bindings, blank clasp.
4. For walk/run, state the foot-contact timeline explicitly:
   left contact, left load, right pass, right contact, right load, left pass.
   Keep passes low so the result reads as walking/running, not marching.
5. For seven-frame actions, generate seven genuinely distinct poses. A
   six-column result is rejected rather than padded with a duplicate.
6. Where ImageGen's multi-row layout omitted a facing, regenerate that facing
   as a direction-locked single row.
7. Visually inspect the keyed master before installing it. Reject face
   readability, facing flips, missing blade metal, extra projectile groups, or
   a fourth hip knife.

Separately authored recovery frames are matched to the action source's raw body
height before common normalization. They are not duplicate-frame padding:

- Dash f7 and Fan f7 use the accepted direction-authored idle guard.
- Ult f7–f9 use three distinct accepted direction-authored idle breaths.
- Active-idle S/SE/E/N f7 uses a distinct accepted settle pose.

## Deterministic builder

Run from the repository root:

```powershell
& 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\art\build_erased_name_assassin.py
```

The builder:

1. hard-keys the green field and removes surviving green spill;
2. finds real row gutters;
3. uses body-weighted pose-center cuts rather than nominal equal cells;
4. lightly bridges legitimate one/two-pixel hand-to-blade gaps;
5. removes remote cloak/blade fragments leaked from adjacent montage poses;
6. retains detached Fan projectiles only in f4–f6 and only when the component
   contains the characteristic bright metal highlight;
7. uses audited manual death edges because standing and grounded poses have
   deliberately nonuniform widths;
8. normalizes each direction to one body scale and ground line;
9. mirrors E-side authored directions into W/SW/NW;
10. validates all 74 files, frame counts, geometry, hard alpha, and nonempty
    frames;
11. emits GIFs and labeled eight-direction PNG contact sheets into `qa/`.

The manual death X edges are the empty-column midpoints between the nine clean
source alpha runs:

`0, 167, 336, 514, 690, 879, 1075, 1274, 1481, 1717`.

## QA gates

Static contacts are the authoritative extraction audit:

- `qa/assassin_anim.png`
- `qa/assassin_walk.png`
- `qa/assassin_run.png`
- `qa/assassin_attack.png`
- `qa/assassin_attack2.png`
- `qa/assassin_dash.png`
- `qa/assassin_ult.png`
- `qa/assassin_ultidle.png`
- `qa/assassin_death.png`

Check each row for:

- no detached adjacent-frame sliver or cloak debris;
- one complete blade attached to the correct hand;
- no readable eyes/face;
- locked rear facings;
- exactly three Fan projectiles, never two groups/six total;
- matching body scale and baseline across all directions;
- alternating grounded walk/run contacts;
- no direction flip at the final action frame.

Then run:

```powershell
& 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\art\verify_art.py assassin
.\test_quick.bat
```

`test_quick.bat` includes the required compile gate for gameplay changes.

## Pre-replacement archive

The exact 74-file predecessor is preserved at
`backup/assassin_base_pre_erased_name_2026-07-31/` with `SHA256.csv`.
The archive hash audit completed with zero mismatches. The backup directory is
ignored by Git intentionally.
