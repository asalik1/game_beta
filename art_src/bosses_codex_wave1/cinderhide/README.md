# Cinderhide the Unquenched — Codex ImageGen wave-1 signature clips

Runtime base: `cinderhide` (left-facing three-headed obsidian hound; flat
strips, L/R flip). Idle / walk / attack came from the 2026-08-14 session. The
four signature clips below were added 2026-08-15 — four parallel headless Codex
sessions from `<clip>_v1_codex_brief.txt`, built with
`tools/art/build_codex_2x2_strip.py`.

| clip | fires from | file | cell | fps (`Balance.BOSS_ACTION_FPS`) | storyboard | build |
|---|---|---|---|---|---|---|
| enrage | plate shed (`melt >= 2.5`) and the 30% enrage | `cinderhide_enrage.png` | 668 | 6 (0.67s roar) | stance → heads rear → all three heads ROAR skyward, cracks blazing → settle | `--anchor hindfeet --valign hem` |
| breath | `_vent_breath` (cone telegraphs 0.5s+ out) | `cinderhide_breath.png` | 844 (the gout reaches far left) | 8 (0.5s) | heads turn → inhale (throats glowing) → heads thrust forward + short magma gout from the central maw → recover | `--anchor hindfeet --valign hem` |
| rain | `play_action("rain")` ember rain (telegraphed spatter) | `cinderhide_rain.png` | 722 | 14 | stance → hunch, back plates flaring → ERUPTION of magma globules off the back → settling embers | `--anchor hindfeet --valign hem` |
| charge | `_do_charge` telegraph (0.58s, then dash) | `cinderhide_charge.png` | 752 | 7 (0.57s) | alert → crouch → deep coil → first stride | `--anchor bbox --valign hem` |

All: `--ref-idle game/assets/sprites/cinderhide_anim_codex.png --scale-ref area
--scale-frame 1`. Same anchor logic as Fangmaw's README: hind paws for
planted-rear moves, bbox for the charge where every leg moves.

**Rain v1 was REJECTED** (`rain_master_2x2_v1_REJECTED_four_heads.png`): frame 1
had a fourth head and a stray ember below the paws (which would also have
corrupted the paw-line alignment). v2 (`rain_master_2x2_v2.png`) regenerated
with "EXACTLY THREE heads in every frame" and a no-stray-particles clause; keep
both clauses in any future Cinderhide brief.

**Breath needed per-row seams**: the top row's empty gutter was x 571–637 and
the bottom row's 641–664 — no single column was empty over the whole sheet, so
the builder now finds the vertical seam per row (`seams:` line in its output).

Reproduce:

```
B="python tools/art/build_codex_2x2_strip.py"; A=art_src/bosses_codex_wave1/cinderhide
R="--ref-idle game/assets/sprites/cinderhide_anim_codex.png --scale-ref area --scale-frame 1"
$B $A/enrage_master_2x2_v1_keyed.png --out game/assets/sprites/cinderhide_enrage.png $R --anchor hindfeet --valign hem
$B $A/breath_master_2x2_v1_keyed.png --out game/assets/sprites/cinderhide_breath.png $R --anchor hindfeet --valign hem
$B $A/rain_master_2x2_v2_keyed.png   --out game/assets/sprites/cinderhide_rain.png   $R --anchor hindfeet --valign hem
$B $A/charge_master_2x2_v1_keyed.png --out game/assets/sprites/cinderhide_charge.png $R --anchor bbox --valign hem
```

QA sheets: `<clip>_v*_qa_sheet.png`. Engine check: every clip's frame-0 paw
line lands on the idle's screen row (+226.5 texture px). Owner in-game QA
pending.
