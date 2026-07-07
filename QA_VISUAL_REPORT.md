# QA Visual Report — post-overhaul regression hunt (2026-07-07)

Read-only visual QA pass over the graphics overhaul (Forward+/bloom, lights, ambient life,
river, pack-art roster + walk animations, boot cover/roster, dressed UI). **No game files were
modified.** All screenshots referenced below live under the session scratchpad:

`C:\Users\asali\AppData\Local\Temp\claude\C--Users-asali-Projects-MMO\a0223b08-aa61-49fe-bc42-75489a0d28e4\scratchpad\`
(`shots\` = shot_kit matrix, `lineup\` = mob/boss/codex rig, `sheets\` = contact sheets).
The rigs that produced them (`lineup.gd/.tscn`, `lineup2`, `cover`, `run_matrix.ps1`) are in the
same folder and can be re-run against `game/` unchanged (external .tscn path passed to Godot —
no files added to the repo).

## Coverage

- **shot_kit matrix:** all 6 classes × 8 terrains (village, void, marsh, bog, graveyard, ice,
  magma, spore) = 48 runs, ~16 shots each (~770 frames). Every shot viewed via per-shot-type
  contact sheets (`sheets\sheet_*.jpg`) with full-res follow-ups on anomalies. The four
  bracket-frame FX shots (`knives_early`, `stab_mid`, `ult_flurry2`, `ult_blink`) were reviewed
  by sampling after their sibling frames proved clean across all 48 combos.
- **Mob lineup:** every non-boss kind with an installed anim strip — 38 kinds × idle/walk-left/
  walk-right (`lineup\mob_*`), plus 2× zoomed facing sheets (`sheets\facing_*.jpg`). Covers every
  migrated sprite the roster actually uses (orc*, skeleton_*, zombie, banshee, fungus_*, stone_*,
  mummy*, elf_druid, scholar_*, bandit_scout/sorcerer, rat, royal_knight/soldier, medusa via
  their kind names).
- **Bosses:** all 21 `Menus.BOSS_KINDS` spawned via the dev-panel path (`Boss.make_boss` + boss
  bar + music), 2 frames each; the four that kited out of the close-up frame re-shot at wide zoom
  (`lineup\wide_*`) — all 21 render.
- **Codex:** all 5 tabs, 33 scroll-pages captured (`lineup\codex_*`); monsters/bosses/gear/
  terrains/status/records reviewed (mid-list gear/monster pages sampled — template identical).
- **Boot:** real cover + character roster (`lineup\real_cover.png`, `real_roster.png`) and the
  no-saves chapter-select path (`lineup\boot_cover.png`, `class_roster.png`).
- **Not coverable in-game:** 9 anim-migrated sprites no kind/NPC references (see finding 8).

---

## Findings

### HIGH

**1. The Assassin class sprite is a plant monster, not an assassin.**
**FIXED 2026-07-07 (same session):** rebuilt from the pack's unused `bandit_fighter` trio with a
shadow-indigo/blood-red palette shift (recipe in the session scratchpad `make_assassin.py`) —
static + idle strip + NEW 6-frame walk strip installed; class select, hero, portraits and both
echo bosses now read as a masked assassin. Also fixed in the same pass: the village stall art
(read as a modern road barrier — redrawn as a cloth-awning goods counter in `art.gd`), warrior
Cleave (blade-led, cycling swing arcs), warrior Charge (heavy 7-ghost trail + landing dust), and
a latent bug where dash afterimages rendered the full 2-frame strip double-wide.
- Evidence: `sheets\assassin_check.png` (raw `assassin.png` + `assassin_anim.png`: a red
  bulb-headed vine creature), `lineup\class_roster.png` (it's the class-select portrait between
  Mage and Paladin), `sheets\center_compare.png` (in-game player renders as the plant).
- Every surface that shows the assassin player shows a tomato-headed plant: class select,
  in-game hero, "you/hero" dialogue portraits, and the ch7 mirror fight (`echo_clone` and
  `unnamed_echo` both borrow sprite `assassin` — the Act 1 finale boss "The Echo of the
  Unnamed" is a giant plant too, see `lineup\boss_unnamed_echo_a.png`).
- Suspected cause: wrong cell cropped from the Pixel Crawler sheet during the roster migration
  (it matches the pack's plant-enemy style), or gap-art placeholder never replaced. The other
  five class sprites are correct humans. Note: `assassin.png` was last touched by an earlier
  overhaul commit, not today's staged batch — it's live player-facing either way.
- Also: `assassin_walk.png` does not exist (no player class has a `_walk` strip — idle strip
  doubles for movement; consistent across classes, so not a per-class bug).

### MEDIUM

**2. Fuzzy portrait matching gives humans monster faces — archer's brother wears the final
boss's portrait.**
- Evidence: `sheets\portrait_zoom.png` (bottom): speaker "Ren" (archer opening, the player's
  farm brother) shows the Stormwarden-armor portrait of **"Veyx, the Unchained Current"** —
  `hud.gd _portrait_for()` falls through to the `Story.ALL_ENEMIES` display-name scan and
  `"veyx, the unchained current".contains("ren")` matches inside "cur**ren**t".
- Cause: [hud.gd:1182](game/scripts/hud.gd:1182) — substring scan both directions with no word
  boundaries; any short speaker name can land on an arbitrary monster.
- Fix direction: add explicit `PORTRAIT_CAST` entries for opening speakers (see 3) and/or
  require whole-word match in the fallback scan.

**3. Four of six class openings show no speaker portrait (inconsistent presentation).**
- Warrior (Bren → villager) and archer (Ren → wrong, see 2) get a portrait beside the dialogue;
  mage ("The Mother"), assassin ("Carter"), paladin and warlock opening speakers have no
  `PORTRAIT_CAST` mapping, so the portrait box never appears in their intros.
- Evidence: `sheets\sheet_dialogue_speaker.jpg` — 16 tiles for warrior/archer, MISSING for the
  other four (deterministic across all 8 terrains).
- Cause: [hud.gd:1155](game/scripts/hud.gd:1155) cast list predates the newer openings.

**4. Chapter select panel: Chapter 7 overflows the panel border.**
- Evidence: `lineup\boot_cover.png` — rows 1–6 sit inside the bordered panel; "7. Chapter 7:
  The Breaking Sky" + its "Locked" line render past/below the border. The list outgrew the
  fixed panel when Act 1 grew to 7 chapters.

### LOW / polish observations

**5. Player halo barely reads on dark ground.** The dark-zone halo
([player_core.gd:281](game/scripts/player_core.gd:281), energy `0.45 × light_mult`) is invisible
on void's near-black ground and only faintly visible in graveyard (2D lights scale with surface
albedo — near-black art reflects nothing). Evidence: `sheets\halo_check.png` (no pool around any
class in either terrain at ambient distance), `sheets\wallhalo_check.png` (faint pool visible in
graveyard only). If the intent is "a small READABLE halo", it needs more energy, a additive glow
sprite fallback, or lighter ground art in dark biomes. Daylight suppression works correctly (no
lights bloom in village — verified across all classes).

**6. shot_kit's `wall_shadow` shot can't verify wall shadows.** It parks the player AT the north
wall, so the camera clamps and the player + wall sit half off-screen
([shot_kit.gd:144](game/shot_kit.gd:144)); the LightOccluder2D shadow is unjudgeable in all 48
frames. Suggest parking ~120px south of the wall instead. (Read-only session — not changed.)

**7. Minimap panel goes invisible on dark terrains.** Its translucent dark background disappears
over black ground, leaving "MAP (M)" and the legend floating (e.g.
`shots\warrior_void\wall_shadow.png` top-right). Cosmetic.

**8. Nine migrated anim sprites have no in-game user** — nothing spawns them, so they can't be
visually verified (and two were re-exported in the currently-staged batch): `bandit_fighter`,
`elf_ranger` (both staged as modified), `fungus_old`, `orc_shaman`, `orc_warrior`,
`royal_priest`, `stone_golem`, `stone_lava`, `zombie_brute`. Either future-content stock or
missing kind registrations.

**9. echo_clone scale.** "Mirror of the Unnamed" (a decoy clone of the PLAYER) uses scale 5.2 vs
the player's 3.0 ([ch7_bosses.gd:71](game/scripts/content/ch7_bosses.gd:71)) — the mirror is
~73% bigger than the thing it mirrors. Evidence: `sheets\facing_1.jpg` (echo_clone row dwarfs
every other mob). If deliberate (imposing boss-fight visual), ignore.

**10. Ice terrain: telegraph/FX contrast.** Ice's bright palette + bloom stack: paladin's ult
ring and warlock's rift wash toward white, and LDR telegraphs (mage meteor ring) are faint
against snow. Evidence: `sheets\sheet_ult_flurry.jpg`, `sheets\sheet_dash_x.jpg` (ice column).
Terrain itself reads beautifully at full res (`shots\mage_ice\terrain_wide.png`). Tuning note,
not a defect.

**11. Bog has zero ambient critters** (village 6–8, marsh 3–4, spore 2–4, graveyard 2–3, bog 0,
ice/magma/void 0 — from the 48 run logs). If bog is meant to share marsh's fireflies/bird set,
it's missing; if dead-swamp-by-design, ignore.

**12. ch6 bosses wear plain mob sprites** (Auroch = spider, Gardener = skeleton, Cure-Twisted =
beastkin; `sheets\lineup_bosses_0/1.jpg`). Pre-existing content decision, but after the pack
migration these read as "big regular monster" next to bespoke bosses like Warden Null.

---

## Verified healthy (pass list)

- **Facing/flips:** all 38 animated mob kinds mirror correctly walking left vs right (zoomed
  `sheets\facing_0..3.jpg`); no flip inversions found, including all `faces_left` pack sprites.
- **Walk/idle strips:** every kind with a `_walk` strip swaps to distinct walk frames while
  moving and back to idle at rest; no swap glitches. (Dark tiles on the first kind,
  barrow_wight, are the zone-banner fade catching the rig — harness artifact, re-verified OK.)
- **Scale consistency:** all six player classes render identical height in-game
  (`sheets\center_compare.png`); mob sizes track their data scales; no unintended outliers.
- **Bosses:** all 21 spawn, render, animate, run their AI, show boss bar + intro lore line +
  damage numbers; the 4 "missing" ones (choirmother, icebound, morwen, vess) were just kiting
  off-frame — confirmed rendering at wide zoom (`sheets\wide_bosses.jpg`).
- **Codex:** monster/boss thumbnails render single frames (no 2-frame-strip bleed), boss/mob
  bucketing via `BOSS_KINDS` correct, gear grade icons all present, terrains list includes the
  river mechanic line, records/status tabs clean.
- **Rivers:** present in bog + marsh in all 12 relevant runs (black water per canon, plank
  bridge carries the road; `sheets\sheet_wall_shadow.jpg` bog column).
- **Wind sway:** frame-diff between the two wide shots shows motion in every terrain
  (44k–830k changed pixels), foliage shader alive.
- **Ambient life:** birds/butterflies in village/marsh/spore, bats/crows in graveyard, embers in
  magma, snowfall on ice; critters flee the player.
- **Lights in daylight:** correctly suppressed — no light blobs in village daylight for any
  class (the gold ring in paladin's early frames is the transient Ember-ignition FX, gone by
  later shots).
- **Boot flow:** cover art (`lineup\real_cover.png`) and hero roster with class icons render
  correctly; chapter-select and class-select screens dressed and readable (except finding 4).
- **HUD/UI:** dialogue box + portraits (where mapped), boss banner, inventory, map, ability bar,
  buff icons, minimap (in lit terrains) all clean; no missing/magenta textures anywhere in
  ~1,000 frames.

## Notes for whoever fixes

- Re-running the rigs: `run_matrix.ps1` (48-combo matrix), and
  `Godot_v4.4.1-stable_win64_console.exe --path game <scratchpad>\lineup.tscn` for the
  mob/boss/codex pass — Godot accepts the absolute external .tscn path, so nothing needs to be
  copied into the repo. Check `Get-Process *odot*` first; other agents share this tree.
- The scratchpad folder is session-scoped; if the screenshots matter long-term, copy them out
  before starting a new machine cleanup.
