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
worktree `gameplay-polish`; **everything below through P5.2 / P0.9 is on `main`**
(each block fast-forwarded after its own full-suite PASS — see "Gates status").

**Status at a glance (2026-08-19 08:30):** P0–P3, P5.1–P5.3 (corner bites = P7.C),
P2.5, P6.2 (7 PC mobs, one walk re-roll outstanding), P6.3, P7.A–G and P8, plus the
play-flag rounds P0.7–P0.9, are BUILT (each block full-suite green; on main after its
ff). OPEN: P4.2/4.3 (owner route call), P6.1 (owner-eyes mob QA), the capital kit repaint
(owner names the pieces), and the owner's in-game verdict on everything — the review
pack for that is `C:\Users\asali\Downloads\UPSCALE_OWNER_REVIEW\` (images + DECISIONS.md).

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
| 8 | Capital plaza + gate dressing (benches, urns, pots, lanterns) | `tools/content/gen_capital.py` FURNISHINGS → `content/capital_hub.gd`; `terrains.gd` STRUCTURES `garden_urns`, `clay_pot` | R S (`capgap` 0 blocked, 2026-08-19) |
| flag | Hazard pools shift during animation | 6 strips re-aligned on frame 0's equator; `Balance.HAZARD_POOLS_DRIFT false` | R (align) / C (flag) |
| flag | Mushroom shifting / well + shrine dimming | wind sway = vegetation allow-list (`_wind_scenery`); 11 glow strips at amp 0.10 | C |
| flag | Campfire, chain-rig, fountains, braziers, banners drifting | `audit_prop_anims.py`: outline band drift, `is_derived`, TOP_ANCHOR banners, RIGID_MASK void_rift, band lock; chain-rig swing strip removed + `ACCENT_PROFILES max 1`. **60 prop strips, 0 flagged.** | C |
| flag | Door torches cartoon + "only stems" at a north door | `torch_pillar` strip at 64 px; `_door_torches(zi, pos, vertical)` anchors on the PLAY-RECT edge (small rooms put the door at the cell edge behind a corridor the camera never shows) then steps `DOOR_TORCH_INSET` into the OWNING room (both rooms of a shared door build a pair on their side; before, both pairs stacked on one spot and the play-rect camera limit clipped the top) | R (darkwood road + bailey N doors, 18:17) |
| flag | "These bricks look cartoonish" (capital south wall cap, 18:40) | round-2 wall fields for wallblock / wall_castle / wall_sand / wall_sewer were uniform brick grids → re-rolled as weathered irregular masonry (`tools/art/style_unify/make_wall_briefs.py`), installed 128 px game + mobile | R (Sable Court west, bailey N wall, 18:51) |
| tour | Capital plaza read as one huge shadow wedge | the contrasting castletile path at α 0.72 over the BRIGHT holystone plaza, feathered → `_mark_roads` uses α 0.30 on `bright` terrains (a tone, not a shadow) | R (plaza, 18:31) |
| rig | Review lane: `shot.bat polish [--fixed-fps=30] [--gif]` + `tools/art/gif_from_frames.py` → `~/Downloads/crownless_polish_gifs/` | `game/shot_polish.gd`, `tools/shot_rig.ps1` | R |
| rule | Standing rule for prop style + motion | CLAUDE.md "World props", `CODING_GUIDELINES.md` §40, `audit_prop_anims.py`, memory | — |
| suite | Flake hardening: capital lapidary section lends the WHOLE inventory + asserts the training gem by identity; materials section snapshots `loose_bags` | `autotest.gd` | S |

**Gates status:** the round-1–3 pass merged 2026-08-18 19:40 (59ff165 + b1b924a; full suite
PASS ×3, preflight 0 fail, mobile synced). Since then, each block below landed on `main` by
fast-forward with its own compile → quick → FULL suite PASS → mobile sync: P0.7 (7ebbba4),
P1 (ef58081), P2 (960b67e), P3 + P5.1 (f7414c5), P2.5-dialogue + P6.3 (503355d), room-clear
reconcile (5cda8c2; a sibling agent's NaN-position root-cause fixes 7ee11c4..62bf1c7 sit
beside it), P0.9 (8da473a), P5.2 + P2.5-rooms (9c0eab0). Capital passability rig
(`shot.bat capgap`) re-run after the curtain change: 0 blocked routes.
Worktree quirk: after a `git checkout -- '**/*.import'` the next `--import` re-imports all
20k files (~16 min) and `git status` lists them modified with EMPTY diffs (identical blobs);
harmless — don't loop on it.

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
  weathered sand cap + face). **UPDATE 2026-08-19 02:50: almost certainly the SAME bug as
  P0.9's grey band — `Art.ground()` painted a `wallblock` brick row at every cell's top/bottom
  edge regardless of terrain, so a sand-walled inset room showed grey stone bricks right
  beside its sand walls. Removed with P0.9; owner: one more look at the desert.**
- [x] **Gold coins cartoonish** → hi-res painterly `coin.png` (64 px) rendered at
  `Pickup.COIN_W` 20 px / `GOLDRUSH_COIN_W` 34 px via `Art.scale_for` (was the 8px glyph
  at 2.5×/4.2×). Landed 7ebbba4.
- [x] **Crown Plaza fountain too cartoonish** → `capital_crown_fountain` repainted (same
  silhouette — the tight-crop landmark contract + its 4-frame water strip depend on it —
  muted stone, pale water, no neon cyan, no glowing figure), 366×478 tight + despilled,
  shimmer strip re-derived (amp 0.10), audits + tight-crop tests green. Landed 7ebbba4.
- [ ] **"Some other plaza structures need an update"** → contact-sheet second look at the
  `capital_*` kit beside the cast; the owner names the offenders → repaint rows here.
  Candidates from the sheet: the two portals' neon plasma, the wellspring's cyan.

### P0.8 — play-flags round 2 (2026-08-19)
- [x] **"Killed everything, room says 1 monster left, can't find it" (Blightheart Bog)** —
  `zone_alive` is a counter kept by spawn/death events; anything that removes a monster
  without its `die()` leaves a phantom count that seals the room. `game_flow._tick_room_clear`
  (every second while the player stands in a room with a positive count): RECONCILE the
  counter to the living, non-dying, non-mirror monsters of that room (`_alive_in_room`) —
  0 → the same `_room_cleared` path a kill uses (extracted from `on_enemy_died`); after
  `STRAGGLER_IDLE` 12 s with no kill, wake whatever still lives, nudge one standing in a wall
  to open floor and pull one that strayed OUTSIDE the room (shoved/chased through a door)
  back home. Both print `[room-clear] …` diagnostics naming the kind/position so the root
  cause is learnable from a log next time. Autotest section `_test_room_clear_reconcile`
  (drift 2→1 + straggler wake/pull). Full suite PASS.

### P0.9 — play-flags round 3 (2026-08-19 ~02:00)
- [x] **Market stall drawn ON TOP of a big oak's crown** ("shouldn't the stand be below the
  bush?"). Y-sort was right — the oak's trunk stood ~100 px north of the stall, so it sorted
  behind and the awning cut a clean rectangle out of the canopy; a crown that close reads as
  hanging OVER a low building, so a building drawn over it looks pasted. Fixed by PLACEMENT,
  not sorting: `game_world._canopy_conflict` — a scatter/accent tree (centre AND clump
  members) is rejected when its rendered art rect would overlap a building/landmark that sorts
  in FRONT of it (tree base north of the front's base); a tree standing SOUTH of a building may
  overhang it (the natural read). Fronts = `_add_building` + non-tree `_add_structure` bodies
  (`_front_of`, base sprite `wpx/hpx` meta — buildings now carry it too). Bodies now tagged
  (`prop` / `building` / `structure` meta). Guard: autotest `_test_canopy_fronts` rebuilds every
  room's seeded scenery and asserts the invariant (quick run: 188 trees / 22 fronts / 25 rooms).
- [x] **New Character showed the chapter selector** — a new hero always begins at Chapter 1
  (owner ruling). `menus.new_character()` → `pick_chapter(first chapter)` → class select; the
  selector stays for REPLAY (pause menu, per-hero `completed_` flags), the co-op lobby's host
  pick, and tests/dev (`open_chapter_select`). The account-wide `unlocked_` meta flags still
  gate those two. DESIGN.md line added.
- [x] **"Cartoonish grey bricks" along the LOWER edge of the Darkwood Road (zoomed out)** —
  reproduced in the rig at zoom 0.55: NOT the wall sprite (moss field, dark) but the
  `Art.ground()` legacy border — a 16 px `wallblock` brick row painted along the cell's top and
  bottom edge, 3x chunky, grey whatever the terrain — showing below the inset room's real wall
  (combat arenas shrink on a bell curve, so most have a margin). Removed from `ground()`;
  the cell edge is now closed by `game_world._cell_curtain`: real `_wall()` segments in the
  room's OWN wall field (N/S when the vertical inset ≥ 72 px, W/E when the horizontal one is;
  door corridor gaps kept; north band throws its face; repaint-tracked). Rig re-shot: dark
  moss curtain, no grey band.

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
- [x] **P2.5 Transitions** — dialogue box slides up + fades in (0.14 s, pause-safe, not
  headless) — done 2026-08-19 00:40. Room-enter + title card done 04:15: the title card
  SETTLES down 14 px as it appears (cubic ease-out) with the sub-line a beat behind, and
  both drift up as they leave (`hud.flash_title`, `TITLE_RISE`/`TITLE_SUB_DELAY`; end
  screen resets the rest position); a REVISITED room eases in from part-black
  (`hud.room_dip`, `Balance.ROOM_DIP_A` 0.55 over `ROOM_DIP_T` 0.28 s) instead of
  jump-cutting — first visits keep the full fade-from-black + card. Never on headless,
  never over a fade already in flight (title flash / death dim own the overlay). Hooked
  in `_enter_room` for `play_started and not first_visit`. The hitch worry: the dip does
  not ADD a stall — it hides the cut after one.

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
- [x] **P4.1 Idle loops — ALREADY THERE (checked 2026-08-19 00:15).** All six heroes carry
  4-5-frame breathing idles per facing (`<cls>_anim_<dir>.png`, frames measurably differ), and
  18 of the 20 live skin idles animate (only two ARCHIVED archer skins are static). The round-1
  "static idle" read came from the trailer frames, where the breath is subtle; the idle bob
  (`IDLE_BREATH_PX`) now sits on top. Nothing to generate.
- [ ] **P4.2 Turn/lean frames** on direction change (2 frames) and **anticipation
  frames** on heavy swings/casts (1–2 frames before the swing frame). Owner call on the
  route: ImageGen one-row recipe (cheap, drift risk on PixelLab bodies) vs PixelLab
  `animate_character` (needs explicit authorization).
- [ ] **P4.3 Skins inherit** whatever P4.2 ships (skin change scope rule: per skin
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
- [x] **P5.2 Asymmetric insets + wall-hug clusters** (BUILT 2026-08-19 04:10) —
  `game_base.room_inset_lt/rb`: each axis's shrink is split (1±ASYM·h) per room hash
  (`Balance.ROOM_INSET_ASYM` 0.6; the play rect's SIZE is unchanged, so every size test
  holds), so a shrunken room sits off-centre in its cell AROUND its door lanes (which stay
  on the cell's centre lines — `door_pos`, roads, seals, gates untouched); the corridor on
  the near side shortens, the far side lengthens. Authored-scale rooms (capital) stay
  symmetric. `lane_local()` replaces every `pw/2, ph/2` door-lane assumption in
  `_spawn_scenery` (buildings, landmark, obstacles, clumps, accents, bridge); walls, curtains,
  canopy spans and pilasters cut their gaps at the lane; hazard pools roll inside the play
  rect. Wall-hug composition: `Balance.SCENERY_WALL_HUG` 0.4 of decor + prop placements
  sample the band 60-200 px off a wall (`_scatter_point`) and a clump that hugs a wall
  stretches ALONG it 1.6× / squeezes across 0.45× (`_clump_jitter`) — hedges, rock lines,
  mushroom fringes; open middles stay open. Rig-shot at 0.5 (Hollow Oak, Stilt Camp,
  Wolfpaths): rooms visibly off-centre, tree lines along the west walls. Full suite PASS.
- [x] **P5.3** non-rectangular room footprints — the first, cheap form shipped as P7.C
  (corner bites: 0/1/2 solid corner blocks per combat room, hashed, door lanes kept clear).
  True L/T footprints in world-gen stay long-term.

### P6 — cast consistency (ART, separate lane; see mob-sheet-qa memory)
- [ ] **P6.1** the 8 flagged mob sheets + recenter sweep. NOTE 2026-08-19 01:10: a
  `recenter_strip.py` dry-run over all 59 placed enemy bases' idle/walk strips reported big
  "drift" (casket_creeper walk 155 px, spider walk 63, greyrun_lurker 55, grove_horror 46 …) —
  filmstrips with cell lines show those cells correctly assembled: multi-legged bodies whose
  legs cross cell borders confuse the tool's column-band segmentation (false positives). NOT
  applied. Leave for a hands-on mob-QA session with the mobqa rig (owner-reviewed lane); the
  8 flagged sheets were "gates only for now" per the owner on 08-13.
- [x] **P6.2** the 32px `pc_extra_mobs` bodies BEFORE any zone places them (today
  none is placed — checked 2026-08-18). BUILT 2026-08-19 08:00: the seven Pixel
  Crawler mobs (Bloated Dead, Grave Cutter, Tomb Warden, Sporeling, Wildkin Skirmisher,
  Gutter Cutter, Warren Breaker; the Plague Chanter already had its 192 px body) →
  192 px bodies in the mob house style (Plague Chanter = style/scale benchmark), headless
  Codex in two phases (idle 2x2 → then walk row-of-8 + attack 2x2 bound to the NEW idle),
  `tools/art/style_unify/make_pcmob_briefs.py` + `tools/art/build_pc_extra_mobs.py`
  (reuses the 08-08 repair builder's keying / gutter-safe extraction / torso-locked
  normalization; 192 cell, the old body share kept so on-screen size is unchanged; masters
  archived under `art_src/Custom/PcExtraMobs_2026-08-19/`, old sprites under `old/`).
  Idle + walk + attack installed for all seven (14:58). Warren Breaker (`rat_warrior`) took
  four walk rolls: row-of-8 ×2 came back with touching gait cells, the 2x4 grid v3 had two
  cells with the tail stretched out (the builder's width clamp shrank the whole clip to
  0.84x the idle body — verify_art CLIPSCALE), v4 with an explicit "tail curled tight, tip
  never past the rear heel" clause installed clean at the idle's body height. Contact
  sheets: `UPSCALE_OWNER_REVIEW/14_pc_mobs_sheet.png`, `14b_rat_warrior_idle_walk_attack.png`.
  Lesson for the mob recipe: name the TAIL (or any trailing appendage) as a width budget
  in the brief, or one stretched cell shrinks every frame. OUT OF SCOPE on purpose: the salvaged
  tick ×5 / verdant ×3 / scholar ×2 placeholders ("awaiting a home") — regenerate when a
  zone places them.
- [x] **P6.3** `villager` (32px) still cast in ch3/5/7 zones AND the fallback dialogue portrait
  for Sera / Bren / Carter / the mother / Ren / Osric → 256² roster body (village woman in a
  faded blue shawl; `make_npc_briefs.py` "villager", `build_npcs.py`), installed 2026-08-19 00:40,
  suite PASS.

### P7 — the reference-gap pass (owner review 2026-08-19 05:40, after playing the merged P0–P5 build)
Owner verdict on the pass so far: "polish pass is ok generally", with three named
misses (coins, chests, "the room shape can also be asymmetric") and a feel that "some parts
are still missing … in many MMOs the text isn't something flat — like the LORE UNEARTHED
text; it's not the words, it's how they appear". Four reference screenshots were
compared (two World-of-Kings-style 3D mobile MMO HUDs: party frames, ornate portrait ring
with level badge, boss bar with badge, radial cooldown medallions, rolling "Personal: You
got 92 EXP (+69)" log; two web-hub pages: glass panels with thin tinted borders, paper-doll
equipment slots in rarity frames, small-caps label / bold value / green-delta stat grids,
ability cards, portrait card carousels, panel particles; then a bag screen (3D hero between
two columns of equipment slots, bag grid with locked rows, currency chips top bar) and a
class-select screen (class icon rail at the bottom → the chosen character's MODEL centre
stage with name/type/specialty/difficulty/lore panel, toggleable against the splash art).
**Owner: "this is all accurate and should be documented."** Agreed gaps, in the order to
attack them (A → B → C → D → E → F → G); each lands by the same gate ritual as P1–P5.

- [x] **P7.A Announcements + event log** (BUILT 2026-08-19 06:00, suite PASS).
  `hud.announce(text, color, hold, kind)`: a glass plaque (560×56, dark, 1 px gold
  border, two hairline rules) under the boss-bar zone, an icon glyph by kind
  (`announce_kind`: lore → ui_book, quest → ui_quest, victory → ui_daily sunburst, item →
  ui_bag, gold/renown → coin, party → ui_party), the header face in caps whose
  `FontVariation.spacing_glyph` EASES 7 → 2 px, a soft light sweep across the plaque, a
  sparkle puff, scale-pop → settle, the call site's hold (≥ 2.2 s), drift-out; long lines
  split at their dash into title + sub-line; plaques stack. `hud.log_event`: the rolling feed
  bottom-left above the hints (last 5, icon chip + line, slide-in, 6.5 s life), and "+12 XP" /
  "+3 gold" streams COALESCE into one growing line. Routing: `game_base.spawn_text` sends any
  kind-0 line that asked for reading time (`hold > 0` — LORE UNEARTHED, X UNLOCKED, +N RENOWN,
  CHAPTER CONQUERED, THE CURSE LIFTS, weekly/Waking lines) to the plaque and mirrors every
  "+…" pickup/XP line into the feed; the room-clear "THE BLIGHT BREAKS" (owner renamed it
  off "recedes" 2026-08-19) calls `announce`
  directly; coin pickups log "+N gold". Numbers, crits and short callouts keep floating.
- [x] **P7.B Coins + chests** (code BUILT 06:05; ART INSTALLED 08:20 — all ten chests +
  their open strips + the 6-frame coin spin, contact sheet
  `UPSCALE_OWNER_REVIEW/08_loot_chests_coins_sheet.png`; `CHEST_GRADE_TINT` dropped to
  0.12 because the painted chests carry their grade in the wood/metal already; the
  builder clamps the frame scale so a wide-open lid never overflows its cell — chest_d's
  did on the first pass).
  CODE — coin (`pickup.gd`): `_coin_visual` uses the SPIN strip `coin_anim.png` when it ships
  (6-frame turn, `Art.anim_prop` seam, fps 6) else the disc; coins now spawn at the death
  spot and ARC out to a scattered rest point with two bounces (`COIN_ARC_H/SCATTER/BOUNCE`),
  pool a soft gold glow, keep the glint wink, and on pickup burst three chips + the HUD gold
  line pops (`hud.pulse_gold`) + the feed logs "+N gold"; the Gold-Rush coin shares the
  visual. Chest (`chest.gd`): `_open_moment` — lid FRAMES when `<art>_open.png` ships (a
  row of square cells closed → cracking → open → at rest, played once and held,
  `CHEST_OPEN_FRAME_T`), a white-gold light burst that blooms past the box, a sparkle
  fountain (22 chips, grade-tinted), the telegraph halo flares then dies; the opened chest
  HOLDS `CHEST_OPEN_HOLD` 2.4 s (it used to vanish in 0.3 s) then fades. ART —
  `tools/art/style_unify/make_loot_briefs.py` (10 chests: ONE ROW of FIVE closed→open in the
  painterly house style, refs = hideout_barrel + coffin, subject = the old 32px chest; coin:
  ONE ROW of SIX, a 60°-per-frame turn about the vertical axis, diameter constant) +
  `tools/art/build_loot.py` (row split at real gutters, one scale + bottom-centre anchor for
  the chest frames → `chest_<key>.png` + `chest_<key>_open.png`; coin frames centred →
  `coin.png` + `coin_anim.png`; masters/old art archived under
  `art_src/Custom/Loot_2026-08-19/`). Unopened-glow pulse: the existing B+ halo breathes
  already (scale 1.35↔1.55); left as is.
- [x] **P7.C Corner bites = P5.3 pulled forward** (BUILT 06:10, suite PASS).
  `game_base.room_notches(i)`: a combat room (never boss / safe / authored-scale) carves
  0 / 1 / 2 corners (`Balance.ROOM_NOTCH_CHANCE` [.4 .4 .2]) as SOLID blocks, 170–330 ×
  120–230 px (hashed per room — co-op-safe), always `ROOM_NOTCH_LANE_CLEAR` 90 px short of a
  door lane's gap. Built by `_build_room_walls` through `_wall()` in the room's own field
  (relief by corner: NW = south face + east shadow "SE" — `_wall_relief` now stacks both —
  NE = face, SW = east shadow, SE = cap), colliders + light occluders included; pilasters
  skip a bite's span and the corner foot moves to the bite's inner corner; scenery gets a
  run of reservation circles per bite; hazard pools reroll off them (`_pool_blocked`);
  authored spawns / NPCs / landmarks are pushed out by `room_pos` → `notch_clear`;
  `free_spawn_pos` already sees them as walls through physics. Autotest `_test_corner_bites`
  (lanes clear, spawns + scenery out, inside the play rect).
- [x] **P7.D Boss bar + portrait chrome** (BUILT 06:15, suite PASS). Boss bar: the boss's
  FACE — a circular masked crop of its splash (the hero-portrait crop rules) in a crimson ring
  at the bar's left (`boss_badge`, `_dress_boss_badge`), "Lv N" under it, numeric HP
  "2.3K / 4.4K" at the bar's right (`track_target_bar`). Hero portrait: a gold-rimmed LEVEL
  BADGE disc on the ring's lower-right (`avatar_level_badge`) that pops on level-up. Ally
  nameplates: already drawn in co-op (`party_names`); left as is.
- [x] **P7.E Paper-doll character sheet** (BUILT 2026-08-19 07:30, rig-verified
  `UPSCALE_OWNER_REVIEW/15_paper_doll.png`).
  The Stats tab opens with a PAPER-DOLL band above the ledger: the hero as they stand in the
  game (live idle strip, breathing, on a floor glow), their seven pieces as rarity-framed
  icon wells flanking the body (three left / four right, click = the piece's card), name /
  class / level / Combat Rating / HP-MP / themes beside it, and the four ACTIVE ABILITIES as
  icon plates with name + cost line on the band's right half (`_paper_doll`, `_pd_well`).
  The three-column ledger (already the label / value language) stays below. Not done: green
  stat deltas in the ledger, panel particles.
- [x] **P7.F Bag / inventory layout** (slice BUILT 07:20, rig-verified
  `UPSCALE_OWNER_REVIEW/16_bag_locked_row.png`). The bag grid already had fixed
  cells, empties and a capacity bar; added the reference's LOCKED ROW — when fewer than
  `MAX_BAGS` bags are equipped, one row of dim padlock cells (drawn from shapes, no glyph
  dependency) closes the grid with a tooltip that says how to earn it (`_bag_locked`).
  Hero-between-columns and the currency top bar were NOT done — the owner called the bag
  "pretty solid"; the Stats tab's paper-doll (P7.E) carries the hero + slots view instead.

### P0.10 — play-flags round 4 (owner, 2026-08-19 16:20, on the review pack build)
- [x] **Event log misaligned** — a line without a glyph ("+21 XP") started at the panel
  edge while its neighbours were indented past their icons → the icon column is ALWAYS
  reserved (`hud.log_event` text x 22 for every line).
- [x] **"One of the chests looks cut off"** — `chest._open_moment` derived the cell count
  as width ÷ height; the painted chests are taller than wide (128 × ~150) so a 5-cell
  strip read as 4 cells of 160 px and the lid played half a chest. The cell is the CLOSED
  art's width now (the closed sprite is one cell of the same strip).
- [x] **Class-select medallions** — the VBox stretched the ring to the label's width (a
  pill, the face in its left half) → `SIZE_SHRINK_CENTER` keeps it a 72 px circle and the
  face fills it flush inside the border (64 px at 4,4).
- [x] **Paper-doll model off-centre** — the hero stood at x 210 with the well columns at
  18..62 and 236..280 → on the midline (149), and the BODY is centred (alpha centroid of
  frame 0), not the padded cell (`PD_WELL_*` consts).
- [x] **Shadows everywhere** — (a) every prop above `CAST_SHADOW_MIN_H` (70 → 26 px)
  casts, and every non-building structure (landmarks / accents: statues, wells, fountains,
  stalls, shrines, grove trees; `w` ≤ `CAST_SHADOW_STRUCT_MAX_W` 280, a def may opt out
  with `"cast": false`) casts through the shared `_prop_cast_shadow` (animated bases
  frame-synced); (b) LIVING bodies cast a real figure: `Game.CastShadow` (inner class in
  game_base) mirrors its source Sprite2D every frame — texture, strip cell, frame, flip,
  offset, scale, alpha — flipped, sheared to the lower-right and squashed on the feet
  line; `cast_shadow_for(parent, sprite, strength)` is attached to the hero
  (player_core), every Enemy/Boss (0.7 strength for big bodies), every `_make_npc`
  person, and flitting critters (ambience.gd). The contact ellipse stays as the feet's
  grounding. Cast copies carry meta `cast_shadow`; autotest's "exactly one animated
  part" counts (fountains, capital fire landmarks) skip them. Never headless.
- [x] **Warren Breaker walk** (owner: "no proper leg crossover") — v5 roll with a per-cell
  foot-gap storyboard (wide → half → CLOSED/crossing → half, then mirrored with the
  other leg in front; "frames 1/3/5/7 must have four different lower-body silhouettes")
  installed at the idle's body height; v4 (same pose in every cell) archived.
- [x] **Class-select clip size jump + splash decapitation + text redundancy** (owner,
  ~17:45) — (a) ability clips scale by the first frame's ALPHA BODY (`CS_MODEL_BODY_H`,
  cached), not the cell, so an attack strip's tall sword-arc cell no longer shrinks the
  hero mid-swing; (b) the Splash view uses an explicit cover rect biased to the painting's
  measured face line (`_cs_fit_splash`, `AVATAR_FOCUS` at 28 % of the stage) — heads stay
  in frame; (c) ability + passive text render IN FULL (autowrap, whitespace was there) —
  the length trims and the same-text tooltips are gone.
- [~] **In-game ability DEMOS on the stage** (owner: "none of the class animations play
  any of the fx… maybe an in game gif of the attack anim to completion") — new
  `shot_csdemo.gd` rig casts every class × slot through the real `use_ability` at a
  frozen wolf pack under `--fixed-fps=30` and dumps frames;
  `tools/art/build_csdemo.py` encodes them to `assets/videos/csdemo_<class>_<slot>.ogv`
  (libtheora, 640×400, **yuv420p — MANDATORY**, ~130–500 KB each, 5 MB all 24);
  `menus._cs_play_demo` plays the take to completion on the stage (VideoStreamPlayer;
  knives fly, dashes travel, ults roar), then the live model returns; body-clip fallback
  when a video is absent or headless. TWO TRAPS: (1) ffmpeg picks yuv444p from PNG input
  and Godot's theora decoder renders 444 as macroblock garbage — force
  `-pix_fmt yuv420p`; keep both dimensions multiples of 16; (2) headless `load()` of an
  .ogv can HANG the process — `_cs_play_demo` returns false under the headless
  DisplayServer (the suite opens this screen). VERIFY-IN-WINDOW STILL OWED: after ~60
  windowed engine launches today the AMD driver started dying at boot with "Vulkan
  device was lost" (0xC000001D, even with the videos quarantined) — the playback look
  needs one owner-side open of the class select after a reboot/driver recovery. Suite
  PASS headless.

### P0.11 — capital flow round (owner, 2026-08-19 evening)
- [x] **Duplicate exit rooms** — the Emberward Gate's "Leave Crownfall" duplicated the
  Wayfinder Sanctum's Story Gate. The gate is the MUSTER POINT now ("E — Muster your
  party (Play Together)" → the party lobby; the Sergeant's line sells it and points the
  road itself at the Wayfinder). Changed in `tools/content/gen_capital.py` and
  regenerated — never edit `capital_hub.gd` by hand.
- [x] **Story Gate → chapter selector** — solo it opens `open_chapter_select(true)`
  (replay picker with NG+ tiers) instead of throwing you into the last chapter; the
  party paths (host reprise picker / guest message) unchanged.
- [x] **Crucible + Depths sealed until Chapter 7 is cleared** —
  `game_world.endgame_gates_open()` = `completed_ch7` (per character; dev mode keeps its
  key). `_hub_action` refuses with "The gate is sealed — clear Chapter 7 to open it."; the
  hotspot prompt reads "Sealed — clear Chapter 7…"; `_seal_portal` freezes the portal's
  strip on frame 0, kills its lights and goes cold-dark (meta `sealed`) — animated =
  unlocked, exactly the owner's ruling. Rig beats: `shot.bat polish --capital`
  (sealed / open / muster).
- [x] **Endgame death → Crownfall** — the run-result card's exit is "Return to
  Crownfall" (endgame_active off, `enter_capital()`, live state) instead of "Return to
  title"; covers Crucible AND Depths (both settle through one path).
- [x] **City directory routes to the Wayfinder** — `service_rooms["portals"]` is
  first-wins (the three-gate room indexes before any later single door).

### P0.12 — resolution audit + fire-on-the-move seam (owner, 2026-08-19 night)
- [x] **Resolution-vs-rendered-size audit** (owner: "compare the classes to the
  mobs/npcs/bosses") — measured every placed kind's ART body height against its on-screen
  body (source-px-per-screen-px; ≥1 = downscaled/crisp). Results: classes 1.89× (warrior)
  – 2.33× (mage); NPC roster 2.0–2.6×; placed mobs 2.3–5.5× (wolf 4.7, cultist 5.5);
  codex bosses 3.0–4.4× (Vargoth 3.0, Morwen 4.4). Roster median 2.28×. NOTHING placed
  renders upscaled — the only <1.0 entries are the UNPLACED pc_bosses/pc_extra salvage
  kinds (ticks/verdant/scholars/cyclops/kraken/flame_giant/tengu/bats/ooze/great_spirit,
  0.33–0.76×), already ruled "regenerate when a zone places them". The "class sprites
  look lower quality" observation = the CLASS-SELECT stage upscaling the ~180 px body
  ~1.7× with NEAREST (uneven doubled pixels beside 2048 px paintings) — fixed with a
  LINEAR filter on the selector stage + paper-doll preview models only (in-game rendering
  keeps the global NEAREST). Audit scripts in the session scratchpad; sheet =
  `UPSCALE_OWNER_REVIEW/27_resolution_audit_equal_zoom.png`.
- [x] **Per-CLIP addendum** (owner: "did u look at the crispness of the attack anim") —
  measured every hero clip, not just idles. The basic ATTACK clips (attack/attackb/
  attack2) match their idles everywhere: warrior 1.89×, paladin 1.94×, assassin 2.00×,
  warlock 2.04×, archer 2.14×, mage 2.33×. But four classes carry an OLDER small-body
  clip generation (~104–117 px bodies) for some strips, and several LIVE abilities play
  them: archer Tumble (dash 1.39×) + Arrow Storm (cast 1.44×) + run; assassin Shadow
  Dash + Death Mark + run/death (1.15–1.16×); warlock Hex (ult) + Void Rift (cast) +
  run/death (1.18×); mage death (1.20×). Warrior + paladin are uniform. At 1× game zoom
  the dip is subtle (sheet: `UPSCALE_OWNER_REVIEW/28_ability_clip_crispness.png`);
  REGEN SHORTLIST (14 strips, 4 classes) parked until the owner unfreezes generation.
- [~] **Fire-on-the-move** (owner: spamming a low-cd shot while moving locks the standing
  pose) — the CODE SEAM is in: `attack_walk` is a registered hero clip
  (`<art>_attack_walk.png`, 12 fps, single facing + mirror); `use_ability` swaps a moving
  basic attack onto it and a re-cast mid-cycle lets the cycle finish (gait continuity);
  contact timing unchanged (swing_delay reads the base delay). Art-driven: no strip = the
  standing swing exactly as before. ART NOT GENERATED — owner said "don't generate
  anything for now" (2026-08-19); when he gives the word, the archer brief = walk strip
  as gait/scale ref + attack strip as bow identity, row-of-8 facing LEFT, no baked
  arrows, install via normalize against the idle cell (install_clip.py anchor invariant).

### P8 — readability / depth / life (the owner's review prompts, 2026-08-19 07:00)
- [x] **Mob readability vs detailed floors** — decision: NO outline (house style, §40);
  a soft dark GROUND-AO pool under every mob and the hero (`Balance.CHAR_GROUND_AO` 0.30,
  width 1.7× body), so a body reads by value against a busy field. Knob to 0 = "the mob
  wearing the biome's shade is intended".
- [x] **Cast shadows (the 3D illusion)** — tall static scatter props (and animated sway
  strips, frame-synced) throw a flipped, sheared, squashed dark copy of themselves to the
  lower-right, anchored on their base (`Balance.CAST_SHADOW_A/SKEW/SQUASH/MIN_H`); the
  first cut leaned the copy UP behind the prop — fixed to lie on the floor (rig-verified on
  a grave cross). Buildings keep their wall faces.
- [x] **Foot dust** — running heroes puff floor-coloured dust every 0.22 s
  (`game_base.foot_dust`, `Balance.FOOT_DUST_*`; never headless).
- [x] **Ground fog** — misty terrains (ambient "mist": graveyard, fen, bog, Choir ward) lay
  a drifting low-fog quad over the floor, under the actors (`shaders/ground_fog.gdshader`,
  `_ground_fog`, `Balance.GROUND_FOG_A` 0.14); rig-verified (graveyard paint).
- [x] **NPC breath** — single-frame roster villagers rise/settle 1 px with a random rest
  between breaths (`Balance.NPC_BREATH_PX`; never headless).
- [x] **Dialogue typewriter** — lines REVEAL at `Balance.DIALOG_TYPE_CPS` 42 chars/s
  (punctuation holds a beat); the first confirm press completes the line, the next
  advances — the modern-RPG read rhythm instead of a wall appearing at once (`hud._type_tw`,
  `_show_line`; instant when headless / in tests).
- [x] **Custom cursor** — a painted arrow (`assets/icons/cursor_arrow.png`) and a hand for
  hover (`cursor_hand.png`) replace the OS cursor on desktop (`game.gd`,
  `Input.set_custom_mouse_cursor`; never on touch builds).
- [x] **Roster faces** — the Roster / save rows and the class medallions share one face crop
  of the class painting (`Menus._splash_face_crop`, the `Hud.AVATAR_FOCUS` rules) instead
  of the 32 px in-game thumbnail (`18_roster_faces.png`).
- [x] **Loot banner** moved to `Hud.LOOT_BANNER_Y` 262 so it never sits on the minimap / the
  boss bar / the announce plaque.
- [x] **Repaint hygiene** — `_canopy_overhang` frees the old forest canopy BEFORE the
  terrain check, so a room repainted away from a forest drops its leaves (was left hanging
  over a desert repaint in the rig).
- [x] **Boss intro title plate** (`hud._boss_splash_intro`) — NAME in tracked Cinzel
  (ivory-gold, crimson under-shadow, tracking eases 12 → 3), the epithet split off at
  " the " / " of " / ", " as a crimson caps line, two gold hairlines growing outward, a
  dark foot gradient; hold 1.05 s. It was one red 48 px line in the body sans.
  `UPSCALE_OWNER_REVIEW/21_boss_intro_title_plate.png`.
- [x] **Remains stains** (`game_base.death_stain`, `Balance.DEATH_STAIN_A/LIFE/MAX`) — a
  kill stamps a soft dark blotch in the creature's palette + a splash along the killing
  blow (`Enemy.last_hit_dir`), z -8, fades over 28 s, capped at 48; never headless.
- [x] **Interact prompt pills** — `_make_npc` prompts sit in a dark rounded StyleBox pill
  with a gold hairline, measured after styling so they centre on the anchor.
- [x] **Minimap title** in the Cinzel header face + hairline rule; **roster faces** lifted
  1.14× (dark paintings at 60 px); **cover cycle** opens on the painterly painting
  (`cover.png` ↔ `cover_2.png` swapped; the pixel crown follows at 10 s), the "press any
  key" prompt in Cinzel, sine-eased; **chapter map** vellum mottle under the grid;
  **Settings** panel 400 px on desktop (520 only in touch mode); **shop cards** one icon
  size (`expand_icon`, 60 px rows) instead of 32 px gear beside 128 px potions.
- [x] **P7.G Class select v2** (BUILT 2026-08-19 06:20, suite PASS; owner's eyes owed —
  this one is taste; `UPSCALE_OWNER_REVIEW/02_class_select_v2.png` + `02b_…ult_clip.png`). `menus.open_class_select` is now: a medallion RAIL of the six classes
  (the class painting's face in a bronze ring, gold + 1.08× when selected, number key under
  each); the pick fills the STAGE (690×430 glass panel) with the hero as they stand in the
  game — the live idle strip as an AnimatedSprite2D at up to 3× on a soft floor glow — with
  a Splash / Model toggle against the class painting; the INFO panel: name (Cinzel 30),
  role line, Type (Melee/Ranged) + Difficulty pips (`CS_DIFFICULTY`, a presentation table —
  retune at will), theme chips, the passive; the ABILITY SHOWCASE: four cards (icon + name +
  slot tag) that on hover/tap PLAY the hero's own clip on the stage (a1 → swing, a charge/dash
  word → dash clip, otherwise cast, ult → ult; one-shot, back to idle when done) and write
  the ability's text + scaling line under the row. Number keys PREVIEW, Enter/Space or the
  "Choose <Class>" plate commits (`choose_class` → the splash reveal → name entry, as before;
  `pick_class` untouched for tests/rigs). The old six-card layout is kept as
  `_open_class_cards()` (unwired) for reference.

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
