# POLISH_TASKS — "the game looks beta" board (opened 2026-08-18)

**Trigger.** The owner showed the promo trailers to friends/family (2026-08-17).
Verdict on the GAME, not the cut: "gameplay felt a bit beta … like RuneScape",
"realistic RPG mixed with a 2D Soul Knight game" (art mismatch), intro too short,
not dramatic, wants an ElevenLabs VO. Owner ruling: **the game looking
unpolished at the gameplay level is priority #1, above the trailer.**

**Goal.** A polished, modern-reading action RPG in motion — not just in stills.
Same etiquette as the other boards: **one owner per task, claim before starting**,
gates green before staging, in-game look = the owner's (agents rig-verify).
This file is the single source of truth for the effort; CLAUDE.md "World props"
and `CODING_GUIDELINES.md` §40 hold the standing art rules it produced;
`tools/art/style_unify/README.md` holds the generation lane. Branch:
worktree `gameplay-polish` (off main a12f236); nothing merged yet.

## 1. What "polished" is (the bar we measure against)

From Hades, Halls of Torment, Death's Door / Cult of the Lamb and the classic
"juice" material, four ingredients recur:

1. **A feedback stack on every hit** — hit-stop (2–4 frame freeze), DIRECTIONAL
   screen shake along the hit vector with exponential decay, impact particles at
   the contact point, all synchronized. Shake ranks #1 and hit-stop #2 by
   impact-per-hour.
2. **Animation as the "invisible force"** — cast and UI both move with intent
   (Hades: "motion design is detailed and purposeful, from title screen to menu").
3. **One art language across cast + world + UI**, colour-coded for readability.
4. **Moody, layered environments** — torch-lit, flickering shadows, ambient
   particles that say what a space is made of, weather/fog/light shafts.

Sources: game-feel guide (aiopenlibrary.com/prompts/game-feel-juice-polish-guide),
salivity "Maximizing game feel", GDC "Juice it or lose it" (gdcvault 1016487),
tech4gamers "Analyze Hades for design lessons", Nat Rowley "How Hades creates a
responsive underworld", Don X "UI Noir: Hades", Game UI Database (Hades),
PC Gamer + Rogueliker Halls of Torment reviews, RMCAD "Environmental effects",
80.lv "Dynamic lighting & shadows in 2D".

## 2. Diagnosis (2026-08-18, from raw shot_cine frames + code)

| # | Cause of the "beta" read | Root |
|---|---|---|
| 1 | World = tint rectangles | roads = white sprite rect α 0.6; walls = flat 48px strips |
| 2 | Floor texel scale wrong | field tile 1:1 → cobbles 80-120px beside an 88px hero |
| 3 | Three art densities | painterly cast vs chunky 16-48px pack props vs procedural grids |
| 4 | Nothing grounded | shadow 20×9 @0.30 invisible on dark floors; lava/braziers light nothing (PointLight2D scales with albedo) |
| 5 | Engine-default UI/combat text | plain 15px Labels piling, bare 30×4 red HP rects, "Lv N" reticle |
| 6 | Dark/muddy | cast + floor in one value band |
| 7 | No motion | static idles, white flash only on hit |
| 8 | Empty rooms | nothing between props; plaza bare |

## 3. Done (this pass) — where it lives, and how far it is verified

Verification key: **R** = rig-shot/GIF-checked (`shot.bat polish`), **S** = full
suite green at the time, **C** = compile-gate only (in-engine look still owed).

| Row | What | Where | Ver. |
|---|---|---|---|
| 1 | Shader roads (union of arm rects, sd_box, feather + noise wobble + mottle) | `game/shaders/road_band.gdshader`, `game_world._mark_roads/_road_shader` | R S |
| 1 | Wall FACES + floor shadow (north face 0.56, softshadow 30px; west thin east shadow), retexture-safe | `game_world._wall(rect,tex,relief)`, `_wall_relief`, `Art.tex("softshadow")` | R S |
| 1 | Native-res wall tiles for the 10 wall kinds, drawn 1:1 | `wall_field_<kind>.png` ×10, `_wall_dress`, `Art.wall_field`, `install_ground_field.py --prefix wall_field_` | R S |
| 2 | Floor feature scale (1 texel = 1 world px; hero ≈ 2 cobbles) | `install_ground_field.py SIZE_BY_KIND`; 6 field tiles re-installed; `Art.ground()` skips on-path patches for field kinds | R S |
| 3 | Prop style-unify batch A: 24 ch1/village props + gate + fence | `tools/art/style_unify/` lane; `gate.png` 96px square tile + `_tile_scale` | S (props) / C (gate, fence) |
| 3 | Batch B: 52 interior/village/station props (50 installed, clay_pot2 + candelabra re-rolled in D); 8 animated statics re-derived at §40c amps | same lane; `derive_stage.py` | C |
| 3 | Batch C: 9 `npc_*` wanderer archetypes → 256² roster-style bodies (Snarehand Ott flag); the MILL → 384px painterly override at cottage footprint | `build_npcs.py`; `Balance.NPC_HEIGHT_BY_SPRITE/NPC_BODY_TARGETS` (+ `"mill": 2.3`), `_make_npc` mill shadow + `MILL_CHIMNEY` smoke | C |
| 3 | Batch D: 33 hi-res-but-cartoon props from the sibling contact-sheet review (cactus/cactus2/desert set, cartoon trees/grass/cattails, grave crosses, furnaces) + 2 re-rolls; 6 furnace strips re-derived (rigid pulse 0.09–0.12) | same lane; installed 17:45 | C |
| 4 | Contact shadows 0.30 → 0.60; additive floor glow pools under lava/poison/heal hazards, structure sockets, door torches | `Art._make_shadow`, `game_world._floor_glow`, `GLOW_*` consts | R S |
| 5 | Combat text rework (world face 21/27, scale-pop, lean, eased rise), framed enemy HP bars hung from the head row, reticle tag under brackets, "Lv N" moved into the HUD target bar (threat-tinted), HUD/cooldown numbers on the world face | `game_base.spawn_text`, `enemy.gd` HP_BAR_*, `_strip_head_y`, `hud.mob_level` | R S |
| 5 | Fonts: Cinzel (world/header, FontVariation wght 700) + Alegreya Sans (body); Pixelify only for the compass glyph | `ui/theme.gd` `world_font/body_font/header_font`, `assets/fonts/*` + OFL + CREDITS | R S |
| 5 | HUD chips (CR/Resonance pills), identity line bold, hint lines fade after 75 s; class-select = splash header + Cinzel name + chips + ability names + tooltip | `hud.gd _chip()`, `HINT_FADE_AFTER`, `menus.gd` | R (class select) / C (HUD) |
| 6 | Value separation: floor layers modulated darker/cooler; saturation 1.06; **contrast stays 1.0** (linear-light trap) | `Balance.WORLD_CONTRAST/WORLD_SATURATION/FLOOR_LAYER_MODULATE`, `game.gd` Environment | R S |
| 7 | Hit squash (1.10/0.90 → 0.12 s), per-hit camera kick (1.4 / crit 3.0), idle breath bob (1.6 px @ 0.75 Hz), camera look-ahead 44 px + combat zoom 1.08 | `Enemy._hit_squash`, `Balance.HIT_SHAKE*`, `IDLE_BREATH_*`, `CAMERA_*`, `game.gd _process` | R S (squash/kick) / C (breath, camera) |
| 8 | Floor-wear blotch layer per room (z −9) | `game_world._spawn_floor_wear` | R S |
| 8 | Capital plaza + gate dressing (benches, urns, pots, lanterns) | `tools/content/gen_capital.py` FURNISHINGS → `content/capital_hub.gd`; `terrains.gd` STRUCTURES `garden_urns`, `clay_pot` | C (`shot.bat capgap` owed) |
| flag | Hazard pools shift during animation | 6 strips re-aligned on frame 0's equator; `Balance.HAZARD_POOLS_DRIFT false` | R (align) / C (flag) |
| flag | Mushroom shifting / well + shrine dimming | wind sway = vegetation allow-list (`_wind_scenery`); 11 glow strips at amp 0.10 | C |
| flag | Campfire, chain-rig, fountains, braziers, banners drifting | `audit_prop_anims.py`: outline band drift, `is_derived`, TOP_ANCHOR banners, RIGID_MASK void_rift, band lock; chain-rig swing strip removed + `ACCENT_PROFILES max 1`. **60 prop strips, 0 flagged.** | C |
| flag | Door torches cartoon + "only stems" at a north door | `torch_pillar` strip at 64 px; `_door_torches(zi, pos, vertical)` anchors on the PLAY-RECT edge (small rooms put the door at the cell edge behind a corridor the camera never shows) then steps `DOOR_TORCH_INSET` into the OWNING room (both rooms of a shared door build a pair on their side; before, both pairs stacked on one spot and the play-rect camera limit clipped the top) | R (darkwood road + bailey N doors, 18:17) |
| flag | "These bricks look cartoonish" (capital south wall cap, 18:40) | round-2 wall fields for wallblock / wall_castle / wall_sand / wall_sewer were uniform brick grids → re-rolled as weathered irregular masonry (`tools/art/style_unify/make_wall_briefs.py`), installed 128 px game + mobile | R (Sable Court west, bailey N wall, 18:51) |
| tour | Capital plaza read as one huge shadow wedge | the contrasting castletile path at α 0.72 over the BRIGHT holystone plaza, feathered → `_mark_roads` uses α 0.30 on `bright` terrains (a tone, not a shadow) | R (plaza, 18:31) |
| rig | Review lane: `shot.bat polish [--fixed-fps=30] [--gif]` + `tools/art/gif_from_frames.py` → `~/Downloads/crownless_polish_gifs/` | `game/shot_polish.gd`, `tools/shot_rig.ps1` | R |
| rule | Standing rule for prop style + motion | CLAUDE.md "World props", `CODING_GUIDELINES.md` §40, `audit_prop_anims.py`, memory | — |
| suite | Flake hardening: capital lapidary section lends the WHOLE inventory + asserts the training gem by identity; materials section snapshots `loose_bags` | `autotest.gd` | S |

**Gates status (19:20):** everything above on one tree: `--import` clean, COMPILE OK
(game 107 + mobile 107), `test_quick` PASS, FULL suite AUTOTEST PASS ×3 (the third
after the evening torch/road/wall edits), preflight 0 fail / 75 warn (presentation
literals, fire-strip GHOST/ANCHOR heuristics), 60 prop strips audit-clean, mobile in
sync (20,659 files, 0 drift) + mobile quick PASS. Staged via
`scratchpad/stage_polish.ps1` (path-listed; `.import` churn reverted). Nothing committed;
branch `gameplay-polish` not merged.

## 4. Open board — this pass (P0) and the next pass (P1–P6)

Claim by adding your name. Acceptance = the listed rig/gate evidence, not "it
should work".

### P0 — close out this pass (owner: gameplay-polish session)
- [x] **P0.1** Batch D lands → `vet_sheet` → `install_stage.py` → `derive_stage.py`
  (6 furnaces) → `audit_prop_anims.py` 0 flagged → `verify_art.py` on every touched base.
  (17:45: 35/35 generated, 0 re-rolls needed, all installed game + mobile; 60 strips 0 flagged;
  verify_art = IMPORT-stale only.)
- [x] **P0.2** `--import` (~16 min, exit 139 is normal) → compile gate → `test_quick`
  → full `test.bat` (2 runs) → `preflight.bat`. Never beside a Codex batch.
  (17:57: import exit 0, verify_art 0 fail; COMPILE OK 107; QUICK PASS; FULL AUTOTEST PASS ×2;
  preflight 0 fail / 75 warn — BALANCE presentation literals, GHOST/ANCHOR on the fire strips.)
- [x] **P0.3** `sync_mobile.py --apply --gate` (5 script drifts + every asset; the
  removed `npc_*_walk` strips must leave mobile too) → mobile compile + test_quick.
  (18:05: 26 synced + 18 pruned with `--prune`; mobile COMPILE OK + quick PASS; re-synced
  after the evening edits — 20,659 files, 0 drift.)
- [x] **P0.4** `.import` churn revert (`git checkout -- ':(glob)**/*.import'`, in the
  background — foreground times out and leaves index.lock) → `git add` the
  reviewed paths → `git status` read-back (serialized-commit etiquette).
  (19:25: 986 files staged — 592 M / 353 A / 30 D / 10 R — game + mobile mirrors, tools,
  docs; 0 unstaged; only two other-lane `.import` strays left untracked. NOT committed.)
- [x] **P0.5** Rig re-check + GIFs to Downloads (`shot.bat polish --tour`, new): village,
  darkwood road (N door), outer bailey (N door), Greyrun Mills (mill), Sporewood (pools),
  Scorching Dunes (cactus/sandstone/drifts), Choir's Hollow (crosses), Maren's Camp,
  Crown Plaza, Ashen Tankard + the 6 fight/walk beats re-recorded on the final build →
  `~/Downloads/crownless_polish_gifs/` (16 GIFs) + `stills/` (46 frames). Found and fixed:
  torches still in the corridor of inset rooms; plaza "shadow wedge" = the road quad;
  brick-grid wall caps (owner flag). `shot.bat capgap`: 0 blocked on the re-run — the first
  run reported the Sable Court north route ending short at (636,192) with the same
  content: the walker is timing-sensitive; the suite's geometric guard passed ×3.
- [x] **P0.6** Merged (19:40): committed 5444f61 → rebased onto main 0b22c1e (one conflict,
  `mobile/game/scripts/game_flow.gd` = main's mobile mirror was STALE behind game/; resolved by
  re-running `sync_mobile.py --apply`, follow-up commit b1b924a) → main fast-forwarded to
  b1b924a with `merge --ff-only --autostash` because a sibling lane had uncommitted WIP in the
  main checkout (mob-avoidance fan, boss art) — verified byte-identical before/after; the two
  entries in the shared stash are not ours. **Owner in-game review pending** — flags reopen
  here as new rows.

### P0.7 — owner's first in-game pass on the merged build (2026-08-18 ~21:20)
- [x] **HUD stat block overlaps** (CR chip on the gold line's descenders, chips fixed-width) →
  block laid out from MEASURED label heights, chips hug their text (`hud.gd`, `CHIP_H`);
  rig-verified `--hud`.
- [x] **"A fire pit sitting on a log"** → `signal_fire` STRUCTURE was a `camp_bonfire` decal
  pasted on the `log` prop (fine when `log` was a 16px log stack; nonsense once `log`
  became a real fallen trunk). Base is now the bonfire itself + `lights` + fire audio.
- [x] **Plaza torch pillar "fire looks fake af"** → `torch_pillar` STRUCTURE was the tall
  `pillar` prop + a 23px `flame` decal at mid-height. Base is now the integrated
  `torch_pillar` strip (pillar + fire in one loop; static = frame 0), `lights`; the pad probe
  in `_add_structure` handles a strip-only base. Rig-verified (Emberward Gate).
- [x] **Forgemistress Calda's shadow pixelated** → the 20×9 shadow texture scaled 8-10× under
  a boss. `Art._make_shadow` renders at 8× and `tex("shadow")` size-overrides it back to 20×9,
  so every caller is unchanged and boss-scale samples are 1:1.
- [x] **Import-race hardening** — `Art.tex()` / `Art.wall_field()` no longer pin a procedural /
  legacy fallback for the session when the override PNG is on disk but not yet imported
  (a fresh pull opened in the editor imports ~600 files for minutes; rooms built in that
  window wore legacy tiles until relaunch). Likely the "cartoonish bricks between the new
  desert bricks" — not reproducible on a settled cache (rig: Scorching Dunes N wall =
  weathered sand cap + face). **Owner: relaunch once; if it persists, name the room.**
- [ ] **Gold coins cartoonish** → hi-res painterly `coin.png` (Codex, running) rendered at
  `Pickup.COIN_W` 20 px / `GOLDRUSH_COIN_W` 34 px via `Art.scale_for` (was the 8px glyph
  at 2.5×/4.2×).
- [ ] **Crown Plaza fountain too cartoonish** → `capital_crown_fountain` repaint (Codex,
  running: same silhouette — the tight-crop landmark contract + its 4-frame water strip
  depend on it — muted stone, pale water, no neon cyan, no glowing figure) → re-derive
  the strip (shimmer, amp 0.10) → audit + `capital_fire_structures`/tight-crop tests.
- [ ] **"Some other plaza structures need an update"** → contact-sheet second look at the
  `capital_*` kit beside the cast; the owner names the offenders → repaint rows here.
  Candidates from the sheet: the two portals' neon plasma, the wellspring's cyan.

### P1 — hit-feedback stack (code, ~1 day) — the cheapest big win left (BUILT 2026-08-18 23:00)
- [x] **P1.1 Hit-stop.** `game.hit_stop(sec)`: a REAL-TIME freeze (`Engine.time_scale` 0,
  restored to whatever it was — dev slow-mo aware; overlapping stops extend), SOLO only
  (`net_online()` → no-op, §5.4), never headless (the suite would only slow), never under a
  pause. Crit `HIT_STOP_CRIT` 45 ms, kill `HIT_STOP_KILL` 70 ms, `effects.heavy`
  `HIT_STOP_HEAVY` 60 ms; ordinary hits don't stop (a fast class would stutter). Note: the
  plan said per-actor pause; a real freeze reads far better and is safe with the gates above.
- [x] **P1.2 Directional shake.** `game.shake(amount, dir, kick)` adds `_shake_kick` px along
  the hit vector, exponential decay (`HIT_SHAKE_KICK` 3 / crit ×1.8 / kill ×1.4,
  `HIT_SHAKE_KICK_DECAY` 14 s⁻¹) on top of the old jitter; holds through the freeze.
- [x] **P1.3 Impact sparks.** `game.impact(pos, dir, color, crit)`: chips flung AWAY from the
  striker (`HIT_SPARKS` 5 / crit ×1.8), white-hot over the theme colour, gravity, 0.26 s. All
  `game.burst()` particles now draw `Art.tex("spark")` (12px soft chip) instead of the engine's
  1px squares — the "2004 particles" tell, fixed everywhere at once. (Per-damage-type strip
  sparks deferred: the soft chips + the existing crit `fx_impact` strip cover it.)
- [x] **P1.4 Knockback + sync.** Already true: `take_damage` sets `knock = dir × 160/220` and
  the flash + squash + number land in the same call as damage; sparks/kick/stop now fire in
  `hit_enemy` on that same frame.
- [x] **P1.5 Kill punctuation.** Kill = the longest stop + a ×1.4 kick; the death burst wears
  the mob's own palette (`Enemy._death_color()`, mean of the frame's opaque pixels, cached per
  sprite key, over a blood-red core) with 14 chips (host + guest-mirror paths). Boss
  phase-change pulse: not done (bosses have their own tells; revisit with P6).

### P2 — UI motion + presentation (code/theme, ~1 day) (BUILT 2026-08-18 23:25)
- [x] **P2.1 Panel open/close tween** — `menus._open` eases the shell in (fade + 0.97→1
  settle around the screen centre, `SHELL_IN` 0.13 s, TRANS_BACK) and `close()` fades the old
  root out (`SHELL_OUT` 0.10 s, clicks ignored on the ghost). Tweens run PAUSE-ALWAYS (a menu
  pauses the tree). Off when headless and in rigs (`Menus.shell_motion`; `ShotRig.boot_game`
  clears it) so a screen shot the frame it opens is never a translucent ghost.
- [x] **P2.2 Hover / pressed states** — the theme already had hover (gold border) / pressed
  (darker) boxes; added the hand cursor and a 0.97 press squeeze that springs back
  (`_press_squeeze`) on every `_btn`/`_tab`.
- [x] **P2.3 HP damage chip + XP ease + level-up** — a pale trail under the red fill holds
  `CHIP_HOLD` 0.32 s then drains at `CHIP_DRAIN`; heals snap it. XP eases toward its value
  (`XP_EASE`) and wraps on level-up (snap to empty, refill), with the bar flashing white and
  the identity line popping gold (`_level_up_flourish`). Enemy-bar chip not done (the framed
  36×5 bar is too small to read a trail).
- [x] **P2.4 Ready pulse** — the medallion ring + icon spring 1.14→1 the instant an ability
  comes back up (`_pulse_slot`), on top of the existing white ring flash. Tooltip fade: not
  done (engine tooltips).
- [ ] **P2.5 Transitions** — room enter fade / title-card easing / dialogue slide: not done
  (kept for the next pass; a room fade risks reading as a hitch on every door).

### P3 — atmosphere layer (code + a few strips, ~1 day) (BUILT 2026-08-18 23:45)
- [x] **P3.1 Per-terrain ambient particles** — the layer already existed (`Terrains.AMBIENTS`
  ×12 kinds, every terrain mapped) but drew the engine's 1px square scaled 1.2-7× — squares
  drifting past the hero. Now leaves are spinning soft ellipses (`Art.tex("leaf")`, random
  angle + angular velocity), rain is streaks (`"streak"`), everything else a soft chip
  (`"spark"`); the AMBIENTS scale numbers keep their pixel meaning (`_setup_ambient_fx`).
- [x] **P3.2 Emissive bloom** — `EMISSIVE_BLOOM_LIFT` 1.16 on hazard-pool sprites, their floor
  glows (×1.15) and the door-torch strips: only their hottest pixels cross the 1.1 glow
  threshold, so lava pools get a soft halo and yellow bubbles pop; actors untouched (no
  hero rim glows — mythic pass ruling). Rig: magma_room.
- [x] **P3.3 Flickering floor pools** — already true: `_floor_glow(pulse)` breathes every pool
  (`GLOW_PULSE_LOW/PERIOD`), the player carries a light with wall occluders. No change.
- [x] **P3.4 Foreground overhang** — `canopy_forest.png` (Codex, seamless L→R, keyed at 512×128)
  hangs along the north edge of forest/hedge-walled rooms ABOVE the actors (`_canopy_overhang`,
  z 20, α 0.92, `CANOPY_*`), left/right of the door lane with the torch pair clear
  (`CANOPY_DOOR_CLEAR`). Rig: darkwood road N door. Eaves for keep rooms: not done.
- [x] **P3.5 Vignette** — already true (`hud.vignette`, low-HP pulse rides it). No change.

### P4 — hero animation coverage (ART, the real cost)
- [ ] **P4.1 4-frame idle loops** for the 6 heroes via the ImageGen ONE-ROW-OF-
  FRAMES recipe (CLAUDE.md, the raider-walk fix): breath + weapon settle, per
  facing (8-dir sets where the hero has them). Body height constant, one ground
  line, `verify_art` clip-vs-idle gate. **PixelLab only if the owner authorizes.**
- [ ] **P4.2 Turn/lean frames** on direction change (2 frames) and **anticipation
  frames** on heavy swings/casts (1–2 frames before the swing frame).
- [ ] **P4.3 Skins inherit** whatever P4.1 ships (skin change scope rule: per skin
  unless "all classes").

### P5 — room composition (code, medium)
- [x] **P5.1 Wall silhouette variety** (BUILT 2026-08-18 23:55) — stone wall kinds
  (`POST_WALLS`: wallblock/castle/sand/sewer/volcanic/ice/grave) grow pilasters cut from the
  wall's own field every ~224 px (per-room seeded jitter), stepping `POST_DROP` 14 px into the
  room with their own shaded face + floor shadow on the north run, sideways on E/W, and a
  `CORNER_W` 44 px block at each corner (`_wall_posts`/`_post`, `zone_posts`; rebuilt on a
  terrain repaint). Door lanes + torch pairs stay clear. Colliders untouched. Vegetation
  walls keep their organic edge (they carry the canopy instead). Subtle by design — read at 1×
  in the bailey rig frame.
- [ ] **P5.2 Asymmetric insets** for small rooms; decor clusters along walls
  (`env-diversity` fill-vs-accent).
- [ ] **P5.3 (long-term)** non-rectangular room footprints in world-gen.

### P6 — cast consistency (ART, separate lane; see mob-sheet-qa memory)
- [ ] **P6.1** the 8 flagged mob sheets + recenter sweep.
- [ ] **P6.2** the 32px `pc_extra_mobs` bodies BEFORE any zone places them (today
  none is placed — checked 2026-08-18).
- [ ] **P6.3** `villager` (32px) still cast in ch3/5/7 zones → roster body.

### Not in this board
Trailer v2 + ElevenLabs VO (owner's account, marketing lane); grid-rectangle
world-gen beyond P5.1–2; prop re-densify (owner's anti-litter ruling stands).

## 5. Traps this pass hit (so the next owner doesn't)
- `Environment.adjustment_contrast` with hdr_2d runs in LINEAR light: 1.06 halved
  a dark floor. Contrast 1.0; saturation only; judge in-game.
- Pixelify's "2" reads as "S" at 21 px → Cinzel/emboldened default for numbers.
- `Art.ground()` on-path patches over FIELD kinds = blocky tan blobs on dirt roads.
- A hi-res canvas is not a style pass; a contact-sheet-visible pulse (0.35) strobes
  in-game; wind sway on non-vegetation "shifts"; a 4-frame swing reads fake.
- `ensure_alpha` skipped keying when the PNG already had alpha → green field
  behind a feathered subject (sand_drift). Fixed: chroma-green corners key anyway.
- Codex `-i` with the old asset as the SUBJECT reproduces an unreadable 16px shape
  faithfully (shard, cross) → description-led brief, no subject ref.
- `gen_capital.py` OUT was hard-coded to the MAIN checkout → clobbered main while
  the owner played (restored byte-identical). Generators write checkout-relative.
- Suite flakes are loot-luck: lend the whole inventory / snapshot `loose_bags`.
- Codex batches: serial, `-MinFreeGB 1.3`, never beside a Godot suite (OOM 08-17).
