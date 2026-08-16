# Skin ability-FX review — 2026-08-15

**Status 2026-08-16 — FIXED PASS APPLIED (owner: "fix them starting from the top",
judging quality as well as overlap).** Ranked items 2–8 and the runners-up are
done; see `art_src/Custom/SkinFX_2026-08-15/README.md` for the strips + wiring.
**Owner ruling: Umbral Phantom (#1) and Arcane Warlock are PROTOTYPES** — noted in
`skins.gd`; deliberately not worked on (Arcane still inherits the shared warlock
pact/rift strips because those code paths are common). Everything below is the
review as written before the fixes.

Owner asked, after the base-kit FX pass landed today, to "review for the skins,
don't make changes there as of yet". This is that review: every one of the 13
skins was shot in the muted rigs (`shot_kit` per skin on keep terrain, plus
`shot_fx_series --skin=… --ability=… --pin` for the skin-owned abilities) and its
presentation code was read against two yardsticks:

1. **Simplistic primitives** — the thing fixed for the base kits today: thin
   `_ring_fx` rings, `game.burst` square particles, bare `glow` blobs and
   `_beam_fx` bars standing in for an effect (rated FINE / MIXED / BARE).
2. **FX layering rule** (DESIGN.md standing rules, owner 2026-08-15): actors draw
   above effects; whatever engulfs them is a ≤50 % ghost, never opaque.

Contact sheets sit next to this file (`kit_<class>_<skin>_unthemed.png`, half
size; `series_key_frames.png` = pinned-dummy time series of the worst cases).
Full-size sheets can be regenerated with the rigs (commands at the end).

**Headline:** no skin path uses the new `_fx_flash`/`_fx_loop` layering
helpers — every skin composition is hand-rolled `Sprite2D` + `z_index`, so the
layering rule is only honoured where a skin falls through to a base path.
Two skins are visibly poorer than base after today (Dreadknight/Stormforged
Berserk are gated OFF the new rage burst and keep the old ring), one skin has no
FX identity at all (Umbral Phantom), and three skins draw big opaque art over
the actors they're hitting (Voidwraith tentacles, Crystal Archmage prism,
Eclipse Knight corona).

## Ranked — what I'd fix first

| # | Skin / ability | What the rig shows | Fix (same recipe as today's base pass) |
|---|---|---|---|
| 1 | **Umbral Phantom — whole kit** | Every branch tests `skin == "phantom"` exactly (`player_kit_assassin.gd:130/219/253/397`, `player_combat.gd:2304/2325/2519/2527`), so it plays the base assassin: red Zed shadows, `_execution_slash` slashlines, ring + squares, no ambient. Sheet: `series_key_frames` row 6. | Widen the tests to `skin in ["phantom","phantom_umbral"]`, add it to `_sync_skin_ambient` (`player_combat.gd:675`) with an umbral-violet palette. Zero art needed. |
| 2 | **Voidwraith — Void Maw tentacles** | Eight opaque ~105 px tentacles at `z 11–13` ring the storm centre for ~3 s and strike THROUGH mobs (`player_kit_archer.gd:490-520`, comment says so on purpose). Sheet: `kit_archer_voidwraith` ult_payoff, series row 3. | `VoidTentacle` root to `z −1` + a 0.4-alpha duplicate child at `z 9` (the ghost pattern). Also: `_dismiss_void_tentacles` (`archer.gd:548-560`) fires 3.14 s after cast and clears the SHARED array — a re-cast inside that window loses its fresh tentacles. |
| 3 | **Crystal Archmage — Meteor prism + missing landing** | Pre-impact prism lotus is ~370 px, alpha 0.98, `z 18` over every actor on the mark for 0.62 s (`player_kit_mage.gd:1046-1047`); it does drop to `z −4` on impact — the only skin that does — but the skin early-returns before `_meteor_impact_fx` (`mage.gd:833-835`), so its landing is frame 6 + flash + 10 squares (`:1090`). Sheet: `kit_mage_crystal_archmage` ult_convergence/payoff. | Start the sequence at `z −1` with a 0.45 ghost at `over_z 9`; call `_meteor_impact_fx` with the crystal hue material on the judgment frame. |
| 4 | **Dreadknight + Stormforged — Berserk** | Both skins are gated off today's `rage_burst` (`player_kit_warrior.gd:214`) and keep a 72 px thin ring + banner / storm eye (`:226-228`). Sheet: series rows 4–5 (the big thin ring at t = 0.15). Also Stormforged's LIVE tell (aura pulse + sprite tint, `player.gd:335/367`) is base RED while its rage is storm-blue. | Drop the gate; hue-shift `rage_burst` per skin (dread-red / storm-blue) under the banner/eye; give the aura + tint a per-skin colour. |
| 5 | **Eclipse Knight — Aegis ward + Conviction disc** | `fx_eclipse_corona` ward at alpha 0.68, `z 6`, ~163 px sits over the paladin for the whole guard (`player_kit_paladin.gd:373-381`); the Retribution swap parks another corona disc at `z 8` on him (`:154-173`). Sheet: `kit_paladin_eclipse_knight` knives_*/dash_x (paladin behind a dark disc), ult_midbeat/payoff. | Ward alpha ≤ 0.45 or move the disc under (`z −1`) with a ghost; the new `aegis_dome` already draws under him — the corona could become the dome's tint/decal. |
| 6 | **Both paladin skins — Consecration** | The class's most-cast button is `_ring_fx` + `game.burst` + untextured square motes + 8 stretched glow shards + one `_light_pillar` (glow shaft + ring + burst) PER victim (`player_kit_paladin.gd:267-337`, `:217-218`) — for base and both skins. | Generate a `consecration_bloom` 8-frame loop, `_fx_loop(z −1, ghost 0.4)`; drop the shard halo and the per-victim pillar ring/burst. (Base paladin benefits too.) |
| 7 | **Golden Ronin — Death Mark / Gilded Iai** | Mythic-tier payoff is entirely procedural: 4 slashline strokes + 10 glow "petals" + gold `game.burst` squares (`player_kit_assassin.gd:237-238`, `:349-389`). Sheet: series row 7 (t = 0.5). Reads OK as a cross-cut, cheap on the glints. | An 8-frame `gilded_iai` cross-cut strip via `_fx_flash(z −1, ghost 0.45)`; keep the thin slashlines above as the accent; textured glints. |
| 8 | **Stormforged — Cleave conduct + charge break** | a1 = 3 glow beads + one `_beam_fx`; a2 = 4 beams + 2 square bursts + a body-fade that never renders (`player_kit_warrior.gd:311-329`, `:348-360`). | Small `storm_conduct` / `storm_break` strips; gate the vanish on `sprite.visible` (see below). |

Runners-up (worth a line, not a rework):
- **Both elite warlock ults** (Hellfire / Arcane) inherit the shared Void Rift
  burst body: 3 `slash` blades, a glow heart, 2 rings, 2 square bursts, 10 glow
  rays, glow scar (`player_kit_warlock.gd:682-796`). Sheet: `kit_warlock_arcane_warlock` ult_aftermath (thin green ring + white blob + specks). Base warlock has the same body — one `void_rift_burst` strip would serve all three.
- **Frostfall Ranger — Lance Blizzard** flakes/lances at `z 21–30`, alpha to 0.92, dozens per tick → an opaque curtain over the field for 3 s (`player_kit_archer.gd:434`, `:453`). Reads well; halve alpha or ghost the near flakes.
- **Eclipse sky hammer** `z 30`, scale 3.2, opaque, landing on the dragged pile (`player_kit_paladin.gd:552-554`).
- **Eldritch Warlock — Dark Pact** unravel ring is `z 8`, alpha 1.0, ~419 px, on the caster (`player_kit_warlock.gd:479-496`). Visually it's a RING (open centre — the caster stays visible, sheet row 1), so I'd rate this "fine as a ring", not a violation; but it also skips today's `dark_pact_burst`, and if it ever gets a filled body it needs the ghost split.

## Per-skin table

Rating = worst ability's primitive rating; layering = any large opaque sprite over actors.

| Skin | Rating | Layering | Notes |
|---|---|---|---|
| Warrior · Dreadknight | MIXED | greatswords `z 6` sweep over him (fine — blades) | Cleave soul-cut + Whirlwind greatswords are FINE; charge ends on a `_ring_fx`; Berserk = 72 px ring + banner (gated off rage_burst); `_soul_wisps` are untextured squares |
| Warrior · Stormforged | BARE (a1/a2) | storm eye `z 8` ~173 px above the head (not over the body) | Whirlwind FINE; a1/a2 beads + beams + squares; charge fade is a no-op (`player.gd:324` re-asserts alpha every frame); Berserk ring + eye; RED aura/tint on a blue skin |
| Archer · Frostfall Ranger | FINE | flake/lance curtain `z 21–30` | Best archer skin: authored arrows, snowflake casts, lances; a few square bursts on lance impact; `sprite.offset += …` in Tumble accumulates (`archer.gd:252`) |
| Archer · Voidwraith | FINE (art) | **tentacles `z 11–13` opaque over mobs** | Eye portals + ground eye are strong; per-contact `game.burst` + `_ring_fx` (34 px); body-fade no-op (same `player.gd:324` bug); shared-array dismiss timer race |
| Mage · Crystal Archmage | FINE | **prism `z 18` opaque for 0.62 s** | Richest skin; correct `sprite.visible` blink; loses the new meteor landing (early return) |
| Assassin · Golden Ronin | BARE (ult) | — | Shuriken + echo FINE; dash = base squares + solid gold ghosts; ult = slashlines + glow + squares |
| Assassin · Phantom | FINE | — | Blade storm, charge shader, ribbons all authored; the dash ALSO draws the generic square burst + glow bar under its ribbon (`skin_owned_dash` only covers crystal_archmage, `player_combat.gd:2526`) |
| Assassin · Umbral Phantom | **BARE (all)** | — | No FX identity at all — body sheet + splash only |
| Paladin · Eclipse Knight | BARE (a2) | **corona ward 0.68 `z 6`; Conviction disc `z 8`; hammer `z 30`** | Consecration is ring/squares/glow; Aegis got today's dome under it; Judgment ring on target |
| Paladin · Fallen Arbiter | BARE (a2) | verdict ward `z 6` alpha 0.42 (OK), 3 hammers `z 29` 0.78 | Same Consecration; tribunal staged rings + tethers are decent; dome + verdict rune reads well |
| Warlock · Hellfire Inquisitor | BARE (ult burst) | pyre rift art over the target | Bolt + brand + pact FINE (pact eruption hue-shifted orange today); ult burst = ring/squares/rays |
| Warlock · Arcane Warlock | BARE (ult burst) | — | Eye bolt/tethers FINE; pact eruption green today; ult burst = thin green ring + white blob + specks |
| Warlock · Eldritch Warlock | FINE | unravel ring `z 8` (open centre) | Cast eye, curse eyes, thread rift are FINE; hex uses the BASE cast rune (no eldritch branch at `warlock.gd:268-271`) |

## Cross-cutting (code, not art)

- **`player.gd:324` re-asserts `sprite.modulate.a` every physics frame** — kills
  both skin "vanish" tells (Stormforged charge `warrior.gd:349`, Voidwraith
  tumble `archer.gd:344`). Crystal Archmage's Blink uses `sprite.visible`
  (`mage.gd:695-704`) — that's the pattern.
- **`_staged_segment_ring` hard-codes `pivot.z_index = 7`** (`player_combat.gd:745`);
  six skins inherit "always over the actors" with no opt-out. A `z` parameter
  (default 7) would let ground rings go under.
- **`skin_owned_dash` covers only `crystal_archmage`** (`player_combat.gd:2526`)
  → Phantom's ribbon dash and Golden Ronin's gold-ghost dash both draw the
  generic square burst + glow bar underneath.
- **Untextured `CPUParticles2D` (squares) still in five skin paths:**
  `warrior.gd:409-424`, `paladin.gd:293-309`, `warlock.gd:72-84`,
  `warlock.gd:287-304`, `archer.gd:152-164` — one `texture = Art.tex("glow")` +
  scale each (as `_mist` did today).
- **Live-buff tells ignore skin colour**: Berserk aura/tint (`player.gd:335`,
  `:367`) are red for Stormforged; worth a per-skin colour map like `_wl_skin_col`.
- Parity (presentation never delays the base hit) is respected everywhere I
  read — every skin prelude spawns before the shared `await`; the mage/void ult
  scenes resolve damage on explicit timers.

## What I did NOT do

No code, art or asset changed for this review (the only edit was the rig itself:
`shot_fx_series.gd` learned `--skin=` and tags its files with it). The
rankings above are the recommendation; each fix is one strip + one `_fx_flash`
/`_fx_loop` call under today's helpers, or a one-line z / gate change.

## Reproduce

```
godot --audio-driver Dummy --path game res://shot_kit.tscn       -- --class=<cls> --skin=<skin> --terrain=keep
godot --audio-driver Dummy --path game res://shot_fx_series.tscn -- --class=<cls> --skin=<skin> --ability=<slot> --theme=none --terrain=keep --pin
```
