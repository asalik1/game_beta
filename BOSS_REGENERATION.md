# Boss Regeneration Document

Working plan for replacing the boss sprite set with Codex built-in ImageGen
assets. Each boss is QA-tested in game before the next boss is regenerated.

## Phase 1 — non-bipedal, robe-covered, legless, floating, or rooted forms

These are the first-run candidates because their silhouettes avoid or reduce
the difficult bipedal leg-animation problem.

### Non-bipedal

- [ ] Fangmaw the Ravener — quadruped grave-hound
- [ ] Cinderhide the Unquenched — quadruped Cerberus target design
- [ ] The Drowned Auroch — non-bipedal drowned beast route
- [ ] Veyx, the Unchained Current — floating storm elemental / quadruped drake route

### Robes or garments covering the legs

- [ ] Morwen the Blightcaller — soaked layered robes and mist hem
- [ ] The Choir Mother — deep layered habit concealing the lower body
- [ ] The Sexton — long grave cloak covering most of the legs
- [ ] Vess the Unburied — tattered widow robe concealing the legs
- [ ] Forgemistress Calda — long gown covering most of the legs
- [ ] Serane the Icebound — long icebound robe silhouette
- [ ] Mother Halla — deep hooded robes covering the legs
- [ ] Ashpriest Ordo — redesign the robes so the legs are fully covered

### No visible legs, floating, or rooted

- [ ] Warden Null — armor plates floating over nothing
- [ ] Saint Varo — throne form only; fused into the reliquary throne
- [ ] Kaethra Cure-Twisted — rooted Bloom form

## Phase 2 — bipedal follow-up forms

These forms are intentionally deferred until the Phase 1 test run is complete.

- [ ] Saint Varo — bipedal standing form
- [ ] Kaethra Cure-Twisted — Huntress form

The remaining clearly bipedal bosses will be scheduled after the Phase 1 QA
results are reviewed: Vargoth, Korrag, Hrolgar, Rotmaw, Echo, and Cyrraeth.

## Regeneration and QA rules

1. Use Codex built-in ImageGen for every new boss asset.
2. Choose the generation dimensions from the boss's intended rendered height;
   avoid generating a small sprite that must be enlarged substantially in game.
3. Preserve a clean, free-standing character silhouette with transparent
   background and no scenery baked into the sprite.
4. QA each regenerated boss at its actual in-game render size before moving to
   the next boss.
5. Record the generation size, render size, asset path, and QA result for each
   boss.

## Decisions locked for this first run

- Saint Varo's throne form is Phase 1; his standing form is Phase 2.
- Ashpriest Ordo is Phase 1; his replacement design must have robes covering
  the legs fully.
- Kaethra's rooted Bloom form is Phase 1; her Huntress form is Phase 2.

## DIRECTIONAL WALKS (2026-08-15, owner: "work on the walking animation next")

The last deferred piece. All 17 non-rooted Act-1 bosses now have a full
8-direction Codex WALK (`<sprite>_walk_codex_<dir>`), matching the directional
attacks — a boss walks and faces the way it moves instead of idle-sliding.

- **9 leg-walkers** (vargoth, korrag, sexton, hrolgar, auroch, rotmaw, kaethra,
  echo, stormmouth): a 4-frame alternating-leg cycle (f1 left-leads, f3
  right-leads, planted feet, no march). **8 gliders** (choirmother, vess, serane,
  forgemistress, ashpriest, halla, veyx, nullwarden — robed/floating): cloth-sway
  + bob, no leg cycle. **saint_varo** stays rooted (no walk).
- Built by `build_act1_dirset.py --outclip walk_codex` with the **head-band
  anchor** (a walk's bbox shifts as legs extend; pinning the head keeps the body
  from sliding — verified with onion-skin overlays). S/N/E generated, W=mirror E,
  diagonals copy E/W. kaethra's N (six-armed back view) kept drifting → dropped,
  `dir_set` south-fills it (radially symmetric, reads fine).
- **Engine change** (`enemy.gd` + `Art.BOSS_DIRECTIONAL_WALK`): a new gate makes
  `_dir_walk` read `<sprite>_walk_codex` even for a flat-idle boss, plus a
  render-loop fix that restores the flat breathing idle on the walk→stop
  transition (the old `not _strip_walk.is_empty()` guard would freeze an
  idle-only body on its last walk frame). Traced regression-safe across all four
  enemy locomotion cases; the legacy `<sprite>_walk_<dir>` PixelLab sheets are
  left in place and bypassed (same pattern as the idle `_anim_codex`).
- 48 facings, 3 waves × ~16 parallel Codex jobs; `scan_drift.py` caught the
  cross-boss drifts (whitepelt/n→minotaur, echo/s→robe, curetwisted/n→ice-mage);
  hardened re-rolls fixed them. Both trees synced, both compile gates green,
  import clean. **Wired into the dev-morph "Transform" rig** (2026-08-15): its
  locomotion now mirrors enemy.gd (flat idle when stopped, `walk_codex`
  directional walk when moving, directional attacks) + the same stop-transition
  fix — so the Transform button previews walks + attacks exactly as a real spawn.
  Owner in-game QA pending (watch: glider motion reading as enough movement;
  walk cadence).

## DIRECTIONAL ATTACKS + projectile-free clips (2026-08-15, owner follow-up)

Owner rejected front-only attacks and baked-in projectiles ("choirmother has a
literal bolt... the bolts are generated separately in our game"; "nullwarden
attack is just a south slash — we need north, east, west"). Fixed both across
all 18 bosses:

- **Every aimed clip is now an 8-direction set** — the basic attack plus every
  clip that aims at the target (bolt/cast/beam/arc/throw/stab/melee/lash/blade/
  slam/charge/piston). 38 clips total. Scheme (owner's): generate S(front) /
  N(back) / E(right profile); `build_act1_dirset.py` mirrors E→W and copies
  E→{ne,se}, W→{nw,sw}; N stands alone. Weapon-swings reuse the installed front
  strip as S (only N,E generated); projectile-casters regenerate S/N/E. The
  engine picks the strip by facing via `Art.dir_set("<sprite>_<clip>")` +
  `dir8_suffix_for` — **no wiring needed**, named-action dir_sets auto-activate.
- **No baked projectiles**: every regenerated clip shows the cast/swing MOTION
  and at most a faint spark at the hand/weapon; the game draws the bolt/beam/
  ring/zone. (Radial self-clips — enrage/summon/ring/storm/rain/freeze/blink/
  etc. — stay front-facing; they're not aimed.)
- ~88 facings, 5 waves, ~20 headless Codex jobs each. `scan_drift.py` reads each
  job's self-report to flag the ~10% identity drifts (worst on N/back views:
  drifted to a generic armored-swordsman or lost signature gear); hardened
  IDENTITY-LOCK re-rolls fixed all. nullwarden slam/piston N left as S-fallback
  (faceless symmetric plated golem — front≈back). Saint Varo skipped (throne-
  rooted, front only). Both trees synced, both compile gates green, import clean.
  Owner in-game QA pending.

## ALL ACT 1 BOSSES COMPLETE (2026-08-15)

Every Act 1 boss (chapters 1–7, 21 bosses) now has a Codex idle + a Codex strip
for **every action its `boss.gd` kit plays** — the fully-animated fight. Built
with the `build_codex_2x2_strip.py` pipeline; each boss's existing installed
`_anim` was the identity reference (re-animate the approved design, no
redesign). Wired via `Art.BOSS_FLAT_ANIMATION_LOCOMOTION` / `BOSS_IDLE_STRIP_BASE`
(idle → `<sprite>_anim_codex`, legacy sheets preserved + bypassed) /
`BOSS_ACTION_FALLBACK` / `MOB_IDLE_ONLY_LOCOMOTION`, with `Balance.BOSS_ACTION_FPS`
slowing roars/summons/blinks/plunges. Desktop + mobile compile gates green,
`verify_art` 0 fail on all 18 (every content-gate WARN is on a legacy bypassed
directional sheet, not a new clip). Owner in-game QA pending.

Harness + per-boss sources: `tools/art/act1_brief_lib.py`,
`art_src/bosses_codex_wave1/<sprite>/` (masters, briefs, ALL_qa contact sheet),
`art_src/bosses_codex_wave1/ACT1_PROGRESS.md`.

**Scoped out (one item), per the phase plan:** WALK regeneration is deferred for
all 18 (bipedal leg-cycle walks are the Phase-2 risk); each boss is idle-only, so
it idle-breathes while repositioning instead of showing a stale flat walk. Also
Phase 2 untouched: Saint Varo's *standing* form (throne form done), Kaethra's
Huntress form. Minor: echo's `split` reads as a fire-cast rather than a literal
duplication (functional — the game spawns the copies); a re-roll could sharpen it.

| Boss (sprite) | clips | notes |
|---|---|---|
| choirmother | enrage summon bolt cast blink ring | |
| forgemistress | attack throw lash quench | |
| vess | enrage ring blink bolt wail | bolt re-rolled (row overlap) |
| ashpriest | enrage rain bolt summon verdict | fire-pillar verdict |
| icebound (serane) | enrage bolt blink freeze beam | frost nova |
| sleepkeeper (halla) | enrage bolt freeze hymn summon | moth-wing, butterfly summon |
| gardener (rotmaw) | enrage bolt summon lash | vine-whip |
| sexton | attack summon slam surface | rise-from-ground surface |
| nullwarden | attack enrage beam slam piston | beam re-rolled (identity drift) |
| saint_varo | attack enrage slam blade summon toll | throne-seated (form only) |
| auroch (auroch_minotaur) | attack melee slam charge | bull charge |
| curetwisted (kaethra) | ring bolt stab throw slam shift | keeps all six arms |
| veyx | enrage ring storm arc summon | floating storm elemental |
| vargoth | attack enrage slam blade | flaming greatsword |
| stormwarden (korrag) | attack pack storm lash | chain-whip lash |
| whitepelt (hrolgar) | attack pack slam melee charge | antlered berserker |
| echo | attack enrage blink throw split | split = generic cast |
| stormmouth (cyrraeth) | enrage cast bolt | enrage re-rolled (identity drift) |

## Codex animation pilot status

| Boss | Idle | Walk | Attack | In-game wire | Owner QA |
|---|---|---|---|---|---|
| Fangmaw | ready | ready | ready | ready | pending |
| Cinderhide | ready | ready | ready | ready | pending |
| Morwen | ready | ready | ready | ready | pending |

### Wave-1 QA repair pass

Morwen and Cinderhide now resolve their idle clips through explicit Codex
strip names, normalize legacy fallback-action cells against the authored body
scale, and bypass the inconsistent directional PixelLab fallback views for a
flat strip with normal left/right facing. Desktop and mobile gates passed;
owner in-game QA remains pending.

Third repair pass (2026-08-15, owner QA: Morwen "shifts side to side" idle and
attack; attack "looks like only 1 frame"): every 2026-08-14 Morwen strip was
a quadrant slice of a 2x2 ImageGen master, so frames 1/3 and 2/4 sat at two
different x offsets (idle 20px, walk 29px, attack 60px) — an on-screen slide
each loop. Idle + walk re-centred deterministically on the halo/hood crown
(`recenter_strip.py --anchor head`), no regeneration. The attack master had
three identical standing frames plus one burst frame, and its body was drawn
15% smaller than the idle (she shrank mid-cast); regenerated headlessly with
Codex ImageGen (four distinct poses: hands-in wind-up → arms-raised gather →
leftward release → half-lowered recovery) and built with the new
`build_codex_2x2_strip.py` (seam-gutter gate, one-factor scale to the idle
body, crown-band anchor, cell grown 627→758 so the burst fits). Sources,
brief and QA sheet: `art_src/bosses_codex_wave1/morwen/`. Fangmaw and
Cinderhide were measured and are already bbox-centred (≤4px) — untouched.
Owner in-game QA pending.

Dedicated signature clips (2026-08-15, owner asked for direct clips): Morwen
now ships `morwen_ring` (12-bolt ring, T-pose release on f3), `morwen_rain`
(overhead call-down), `morwen_blink` (teleport ARRIVAL — condense from hem
mist, halo fixed; the strip plays at the destination because the position
jumps in the same frame), plus the rebuilt `morwen_attack`. Three parallel
headless Codex sessions; all four built by `build_codex_2x2_strip.py
--anchor halo` (idle-halo template match — motes/hands above the head can't
skew it). `Art.BOSS_ACTION_FALLBACK` "attack" now only catches unnamed
moves. Both trees synced; verify_art 0 fail; owner in-game QA pending.

| Boss | Idle | Walk | Attack | Ring | Rain | Blink | Owner QA |
|---|---|---|---|---|---|---|---|
| Morwen | recentred | recentred | v3 regen | v1 | v1 | v1 | pending |

Fangmaw + Cinderhide signature clips (2026-08-15, owner: "do the same"):
eight more headless Codex sessions (4 + 4 in parallel; Cinderhide's rain
re-rolled once — v1 grew a fourth head), all built with
`build_codex_2x2_strip.py`. Quadruped anchoring differs from Morwen: hind-paw
anchor for planted-rear moves (howl, slam, roar, breath, rain), body-bbox
anchor for the charge/pounce where every leg moves; `--valign rows` keeps the
pounce's airborne frame in the air; per-row vertical seams (breath's rows had
no shared gutter). New knob `Balance.BOSS_ACTION_FPS` slows the one-shots whose
gameplay window is longer than 0.29s (pounce 5fps = its 0.8s tween, charge
7fps = the 0.58s telegraph, howl/roar 6fps, breath 8fps); enemy.gd + dev_morph
read it. Sources/briefs/QA sheets: `art_src/bosses_codex_wave1/{fangmaw,cinderhide}/`.
Both trees synced; verify_art 0 fail; owner in-game QA pending.

| Boss | Attack | Signature clips (fps) | Owner QA |
|---|---|---|---|
| Fangmaw | (2026-08-14) | pack 6 · slam 14 · charge 7 · leap 5 | pending |
| Cinderhide | (2026-08-14) | enrage 6 · breath 8 · rain 14 · charge 7 | pending |

Second repair pass: the codex Transform (dev morph) review rig now follows
the same wave-1 gate as a real spawn — it no longer picks up the legacy
directional idle/walk sheets (the east/west idle frames), and the retired
PixelLab ability family is excluded from clip discovery and playback, so the
morph preview cannot drift from what the arena fight renders. The real-spawn
"ability" block in enemy.gd was also simplified to one guard with an accurate
comment (the previous pass left a dead second guard whose comment claimed the
flat legacy ability strip still played).
