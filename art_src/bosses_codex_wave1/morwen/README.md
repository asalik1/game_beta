# Morwen the Blightcaller — Codex ImageGen wave-1 sources

Runtime base: `morwen`. Live clips (all flat 4-frame strips, L/R flip; the
legacy PixelLab 8-direction sheets stay in the tree but are gated off by
`Art.BOSS_FLAT_ANIMATION_LOCOMOTION` / `BOSS_IDLE_STRIP_BASE`):

| clip | file | cell | source master | build |
|---|---|---|---|---|
| idle | `morwen_anim_codex.png` (+ identical `morwen_anim.png`) | 627 | `idle_master_2x2_v2.png` | quadrant slice by the 2026-08-14 Codex session, then `recenter_strip.py --anchor head --apply` (2026-08-15) |
| walk (glide) | `morwen_walk.png` | 627 | `walk_master_2x2_v3.png` | same as idle |
| attack (3-bolt spread, `_strike("attack")`; also the `Art.BOSS_ACTION_FALLBACK` for any unnamed move) | `morwen_attack.png` | 764 (grown from 627 so the release burst fits) | `attack_master_2x2_v3.png` → `_keyed.png` | `build_codex_2x2_strip.py --anchor halo` (2026-08-15) |
| ring (12-bolt ring, `_strike("ring")`; bolts leave on f3 = `BOSS_STRIKE_DELAY` 0.16s @ 14fps) | `morwen_ring.png` | 714 | `ring_master_2x2_v1.png` → `_keyed.png` | same |
| rain (Blight Rain call-down, `play_action("rain")`; the zones are telegraphed separately) | `morwen_rain.png` | 732 (grown for the overhead arms + motes) | `rain_master_2x2_v1.png` → `_keyed.png` | same |
| blink (teleport ARRIVAL — `play_action("blink")` fires and `global_position` jumps in the same frame, so the strip plays at the destination: hem-mist → skirt → torso → rest pose, halo fixed) | `morwen_blink.png` | 670 | `blink_master_2x2_v1.png` → `_keyed.png` | same + `--scale-ref halo --scale-frame 4 --valign top --floor-clip` |

## 2026-08-15 repair pass (owner QA: "idle shifts side to side, same when she attacks, attack looks like one frame")

Root cause of the slide: every 2026-08-14 strip was a **quadrant slice of a
2x2 master**, so frames 1/3 (left column) and 2/4 (right column) inherited two
different x offsets — idle 20px, walk 29px, attack up to 60px on a 627px cell.
Fixed deterministically, no regeneration: `recenter_strip.py --anchor head`
(halo + hood crown is the stable landmark on a hovering caster; the feet band is
her mist hem, which sweeps on purpose).

Root cause of the one-frame attack: `attack_master_2x2_v2.png` frames 1, 2 and 4
were the same standing pose; only frame 3 added a burst (and slid the body
right to make room). It was also drawn 15% smaller than the idle body, so she
shrank mid-cast. Regenerated headlessly with Codex's built-in ImageGen from
`attack_v3_codex_brief.txt` (identity refs: the installed idle strip + static;
the old master as a negative timing reference), storyboard = hands-in wind-up →
arms-raised gather → leftward release burst → half-lowered recovery, then built
with `build_codex_2x2_strip.py` (seam-gutter gate, one-factor scale
normalization to the idle body, crown-band x anchor, hem baseline).

## Dedicated signature clips (2026-08-15, owner: "yes i want direct clips")

Ring / rain / blink were generated in three parallel headless Codex sessions
from `ring_v1_codex_brief.txt`, `rain_v1_codex_brief.txt`,
`blink_v1_codex_brief.txt` (identity refs: installed idle strip + static; the
approved attack strip as a spell-colour style ref only). All four action clips
are anchored the same way — `--anchor halo` template-matches the idle's halo,
so raised hands or motes above the head (rain f3) cannot skew the anchor the
way a crown-band bbox did. Every frame-0 hem and halo lands on the idle's
screen rows (checked with the `_apply_strip` simulation: hem +274.5, halo
−272.5 in texture px for all clips).

Blink notes: the model's mist pool spread ~70px below the robe hem; the engine
reads frame 0's lowest opaque row as the feet line, so the pool is
`--floor-clip`ped flat at the idle baseline and the clip is `--valign top`
(halo row) with `--scale-ref halo --scale-frame 4` (the only frame with a full
body). Its pool vanishes when the strip hands back to idle — a one-shot FX
moment; watch for whether that pop reads badly in-game.

Reproduce (all four):

```
B="python tools/art/build_codex_2x2_strip.py"; A=art_src/bosses_codex_wave1/morwen
R="--ref-idle game/assets/sprites/morwen_anim_codex.png --anchor halo"
$B $A/attack_master_2x2_v3_keyed.png --out game/assets/sprites/morwen_attack.png $R
$B $A/ring_master_2x2_v1_keyed.png   --out game/assets/sprites/morwen_ring.png   $R
$B $A/rain_master_2x2_v1_keyed.png   --out game/assets/sprites/morwen_rain.png   $R
$B $A/blink_master_2x2_v1_keyed.png  --out game/assets/sprites/morwen_blink.png  $R \
   --scale-ref halo --scale-frame 4 --valign top --floor-clip
```

QA sheets: `attack_v3_qa_sheet.png`, `ring_v1_qa_sheet.png`,
`rain_v1_qa_sheet.png`, `blink_v1_qa_sheet.png` (strip + onion overlay).

`installed_v1_prerecenter/` holds the four strips exactly as installed on
2026-08-14 (pre-recenter, old attack) for comparison; the legacy PixelLab flats
are recoverable with `git show HEAD:game/assets/sprites/morwen_<clip>.png`.
