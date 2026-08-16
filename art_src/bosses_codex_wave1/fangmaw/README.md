# Fangmaw the Ravener — Codex ImageGen wave-1 signature clips

Runtime base: `fangmaw` (left-facing side profile; flat strips, L/R flip). Idle /
walk / attack came from the 2026-08-14 session (landscape 1x4 masters, already
bbox-centred). The four signature clips below were added 2026-08-15 (owner:
"do the same for fangmaw and cinderhide") — four parallel headless Codex
sessions from `<clip>_v1_codex_brief.txt`, built with
`tools/art/build_codex_2x2_strip.py`.

| clip | fires from | file | cell | fps (`Balance.BOSS_ACTION_FPS`) | storyboard | build |
|---|---|---|---|---|---|---|
| pack | `play_action("pack")` at 50% hp (wolf summon) | `fangmaw_pack.png` | 552 | 6 (0.67s howl) | stance → head lifting → howl (muzzle to the sky) → settle | `--anchor hindfeet --valign hem` |
| slam | `play_action("slam")` ground rake (fissure telegraphs 0.4–0.9s later) | `fangmaw_slam.png` | 584 | 14 | stance → REAR up on hind legs → forepaws crash down → recover | `--anchor hindfeet --valign hem` |
| charge | `_do_charge` telegraph (0.58s red flash, then dash) | `fangmaw_charge.png` | 564 | 7 (0.57s) | alert → crouch → coiled → first stride | `--anchor bbox --valign hem` |
| leap | `_pounce` (0.8s position tween, impact telegraph at 0.76s) | `fangmaw_leap.png` | 544 | 5 (0.8s) | tense → crouch → AIRBORNE stretch → landing | `--anchor bbox --valign rows` |

All: `--ref-idle game/assets/sprites/fangmaw_anim_codex.png --scale-ref area
--scale-frame 1` (frame 1 is the idle stance in every brief; sqrt-area is the
scale landmark that survives head/tail pose on a quadruped).

Anchor choice per clip matters: the **hind paws** stay planted while the front
howls/rears/slams (pack, slam), but in a charge crouch or a pounce every leg
moves — the paws tuck under the body, and a paw anchor yanked the body 146px
backward on the coil and made the landing hop backward — so those two use the
body-mass **bbox** anchor. `--valign rows` on the leap keeps frame 3 airborne
(top row aligned by frame 1's paws, bottom row by frame 4's; the 2x2 model
drifts rows ~20–65px).

Reproduce:

```
B="python tools/art/build_codex_2x2_strip.py"; A=art_src/bosses_codex_wave1/fangmaw
R="--ref-idle game/assets/sprites/fangmaw_anim_codex.png --scale-ref area --scale-frame 1"
$B $A/pack_master_2x2_v1_keyed.png   --out game/assets/sprites/fangmaw_pack.png   $R --anchor hindfeet --valign hem
$B $A/slam_master_2x2_v1_keyed.png   --out game/assets/sprites/fangmaw_slam.png   $R --anchor hindfeet --valign hem
$B $A/charge_master_2x2_v1_keyed.png --out game/assets/sprites/fangmaw_charge.png $R --anchor bbox --valign hem
$B $A/leap_master_2x2_v1_keyed.png   --out game/assets/sprites/fangmaw_leap.png   $R --anchor bbox --valign rows
```

QA sheets: `<clip>_v1_qa_sheet.png` (strip + onion overlay). Engine check
(`_apply_strip` simulation): every clip's frame-0 paw line lands on the idle's
screen row (+210.5 texture px). Owner in-game QA pending.
