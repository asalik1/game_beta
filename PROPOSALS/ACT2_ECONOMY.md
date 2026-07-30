# Act 2 Economy — calibration plan, drop ladder, new consumables (2026-07-27)

The money-and-drops half of the Act 2 build: what each faucet pays across
L40–70, when the named channels light up, what the new consumables are, and
the calibration process that keeps it honest. Companion to
PROPOSALS/ACT2_BOSS_KITS.md, DAILY_DUNGEONS.md, PROFESSIONS.md. Nothing
installed; decision document.

The standing doctrine is assumed, not restated (DESIGN.md "Reward economy"):
one faucet one job, measure with econ_audit before touching numbers, no new
currencies, endless/dungeon content pays like a chapter replay at its band.

---

## 1. XP — the story currency, budgeted once

- 30 levels across 7 chapters ≈ **4.3 levels/chapter**, first run only,
  fixed totals (the Act 1 parity-budget process rerun at Act 2 scale).
- Chapters are longer (60–90 min first run), so per-minute XP FEELS slower
  at identical budgets — accept it (density of mechanics is the
  compensation) but flag it for the pacing playtest.
- Side chapters (Interludes), Vigils, and all Act 2 replays/tiers pay 0 XP.
  One open question below on Interlude XP.

## 2. Gold — extend the measured line, then re-measure

- The audited replay curve runs ~39 → 181 g/min ch1→ch7 on
  `REWARD_PER_LEVEL 0.12` linear. Projecting the same law over L40–70
  anchors: **ch8 ≈ 200 → ch11 ≈ 250 → ch14 ≈ 320 g/min replay**. These are
  TARGETS to verify, not numbers to inline — build ch8, run `econ_audit`,
  write the measured row.
- `CHAPTER_ECON` gains rows ch8–ch14 with `"act": 2` — this is also the
  switch that lights the named-A channel (§4), so the rows must land WITH
  the chapters, not after.
- First-clear package keeps its shrinking-share law (15–25% of the run's
  own gold; at ch14 that's a big absolute number and a small relative
  one — correct, the frontier farm must dominate).
- Death tithe, shrine costs, gamble pricing all scale off the measured
  rows automatically — no new laws needed.

## 3. Sink sizing at Act 2 scale

Keep the farm-minute ratios, not the gold numbers (DESIGN.md sink table):
potion ≈ 30–40s of frontier farm, a meaningful build step ≈ 2–4 replays.
At ~250 g/min mid-act that prices, e.g., an A-grade reforge sub-roll
(~1.4k) at ~6 min — currently correct by the S-cost table; verify each
bench op lands in its ratio band after the ch8 audit and adjust the
per-grade constants, never the law. New Act 2 sinks (all sized in
farm-minutes in their own proposals): profession ranks + recipes
(PROFESSIONS.md §6), Vigil consumable pull (below).

## 4. The gear drop ladder, L40–70 — reconciled

Three systems already encode most of this; the job is making them agree:

- **Generic grades:** `CHAPTER_GEAR_WEIGHTS`/`CHAPTER_BOSS_WEIGHTS` need
  authored rows ch8–ch11. **SUPERSEDED 2026-07-29 (BOSS_LOOT.md):** S is now
  **boss-only** — `CHAPTER_GEAR_WEIGHTS` (the general band: shop / world chest
  / elite chest / spoils) **caps at A**, and generic S moves to the boss gear
  chest (`CHAPTER_BOSS_WEIGHTS`, S from ch12). Ladder for the general band:
  ch8–9 A-heavy/B-tail, ch10–11 A standard, ch12–14 A cap. Named S stays Act 3.
- **Named uniques:** `UNIQUE_A_ACT := 2` / `UNIQUE_S_ACT := 3` already
  gate on `act`, and `act_of()`/`chapter_act()` resolve ch8–14 to 2
  automatically once the chapters and their `CHAPTER_ECON` rows exist. So:
  **named-A uniques (all 7 slots, bespoke passives) begin dropping in ch8
  with zero code changes** — the channel is live and waiting for content.
  Named S stays endgame-mail-only until Act 3 (deliberate: Act 2's chase
  is named-A breadth + generic-S vessels; Act 3 opens the named-S finds).
- **Bible line to update:** ACT2_DESIGN.md §V "Loot" (A@1/5, S@1/10
  ch12+) predates the shipped channel (10% on boss kills at gate). Keep
  the shipped `UNIQUE_A_CHANCE/UNIQUE_S_CHANCE 0.10` and let the bench
  phase move them if the named-A flow feels thin across 7 slots × 6
  classes; the bible's fractions read as first guesses, not rulings.
- **Difficulty-tier interaction:** Nightmare/Torment Act 1 already farms
  the ch8+ bands via `tier_chapter` shift — when real ch8–14 rows land,
  Torment ch7+8 = ch15/16 ids fall back to `RICHEST_CH` until Act 3
  authors them. Verify the fallback still points at the richest AUTHORED
  row (ch14 after this lands) — one-constant change.
- **Vigil caches** roll inside these same bands (tier-shifted chapter
  ids) — no Vigil-exclusive gear, ever.

## 5. Gems — count flat, quality chases the frontier

- Count stays ~17/replay-hour; no changes.
- **Gem sources** (confirmed 2026-07-29, folded into the mob/boss redesign): **trash mobs drop none**
  (materials only — gems stay a reward, not a trash-flood); **elites drop 1** at the act-floor level;
  **bosses drop 1 guaranteed** via a supply chest (BOSS_LOOT.md — level ceiling Bronze L2 / Silver L3 /
  Gold L4, ceiling rare, low levels phase out, first-clear +1 level); shop + synthesis unchanged.
- Quality: `gem_lv2_chance` is capped 65% — Act 2 extends the quality
  ladder upward instead: boss gems Lv3 baseline from ch10, Lv4 from ch13
  (first-clear bundles one level higher, the existing bonus law). Exact
  gates = bench work; the law is "quality lives at the frontier."
- Special gems (cdr/lifesteal/combo/flat_dr/dmg_pct) already drop ch6+;
  no new special stats proposed for Act 2 (the S-socket special slot
  stays scarce — it's the identity slot, not a treadmill).

## 6. Potion slots and the consumable pull

- `POTION_SLOTS_ACT2 := 4` (ch8–11) and `_ACT3 := 5` are latent in code —
  Act 2 activates them; confirm the 5-slot line starts where intended
  (code comment says ch12+; the act3 naming is historical) and rename the
  knob if it confuses (`POTION_SLOTS_LATE_ACT2`).
- The slot growth is the demand side of the consumable economy: 4–5
  drinks/room at Act 2 boss density makes the alchemist shelf (and later
  the Alchemy profession) a real per-run budget line, which is exactly the
  gold sink Act 2 wants at 250 g/min.

## 7. New consumables — the catalog

Design rules applied: visible numbers on every card (NO SILENT EFFECTS);
counters REDUCE new mechanics, never immunize them (mechanic-skips aren't
for sale); nothing grants free buildable stats passively; everything is
bought/crafted — consumables stay an investment, never a grant.

**Slottable (join `ROTATION_POTIONS`):**

| Item | Effect (first guess) | Price anchor | Notes |
|---|---|---|---|
| **Antivenin** | Cleanse active DoTs + 50% DoT resist 6s | ~110g | The bog/spore/blight act needs a DoT answer; resist, not immunity |
| **Stoneblood Draught** | +20% max-HP overheal shell for 8s (decays) | ~140g | The burst-window defensive; pairs with P3-style aura phases |
| **Greater Health Potion** | Restores 22% of missing HP | ~150g, ch10+ shelf | The Act 2 potion tier; same missing-HP law |

**Bag-clicked utilities (not slottable, the elixir_ward precedent):**

| Item | Effect | Price anchor | Notes |
|---|---|---|---|
| **Thaw Salve** | deep_freeze arms 2× slower + freeze duration −50%, 60s | ~90g | Counters ch10/White Vigil pressure; reduction, not immunity |
| **Clarity Tonic** | Silence duration −50%, 60s | ~90g | Counters ch13/Speaking Spire; the silence stays a threat |
| **Blight Bomb** | Thrown: applies Blight (−50% healing 8s) to enemies in a small radius | ~120g, craft-primary | The carried version of the ch12 arena pickup; every build's healing-boss answer |
| **Field Kit** | One reforge/quench operation at any safe room (consumed) | ~350g | Convenience good; the capital stays the bench home, the Kit is the road exception |
| **Warding Candle** | Placed: a 4s-radius light that suppresses hazard-patch ticks in it for 10s | ~130g | The "hold this ground" tool; boss-imposed floors (churned etc.) excluded — boss mechanics don't sell counters |

**Explicitly not proposed:** stat food (free buildable stats — rejected per
the earned-not-passive rule), potions of XP/gold (faucet corruption), any
consumable that skips a boss mechanic outright.

Acquisition: all merchant-shelf at the anchors above EXCEPT Blight Bomb and
Field Kit, which are **craft-primary** (Alchemy/Smithing make them at
~0.7× shelf cost; the shelf carries them at a premium from ch12) — the
deterministic-acquisition job crafting is sanctioned for. Renown weekly
cache adds Antivenin + Thaw Salve to its list (collected-not-farmed).

## 8. Calibration process — the checklist that ships with ch8

1. Build the ch8 vertical slice with placeholder numbers ONLY in
   balance.gd knobs.
2. Run `econ_audit` (first run + replay) → write the measured
   `CHAPTER_ECON` ch8 row; repeat per chapter as built.
3. Re-verify the sink table ratios at each act-2 price point (§3).
4. Vigil preset in econ_audit before cache numbers freeze
   (DAILY_DUNGEONS.md §11).
5. Re-run the boss-TTK bench against A-gear (not S) for ch8–11 pools,
   S-included from ch12.
6. Update DESIGN.md's calibration table + BALANCE_HISTORY round narrative
   per the docs split; CHAPTER_ECON header rule (re-run on any reward
   change) stands.

## 9. Open questions for the owner

1. **Interlude XP** (side chapters): 0 XP proposed (pacing integrity).
   Alternative: a fixed one-time XP grant budgeted INSIDE the act's 30
   levels, making Interludes a leveling shortcut path. Owner call —
   affects Interlude pull strongly.
2. **Named-A flow at 10%/boss** across 7 slots: with ~60 named-A per
   class, is the 10% channel enough for Act 2's chase, or should
   first-clears guarantee one named-A (mail package rider)? Proposal:
   add the first-clear rider, keep 10% on repeats.
3. **Greater potion tier** — one new tier (proposed) or scale
   POTION_HEAL_FRAC by act instead (no new item, less shelf clutter)?
4. **Field Kit** — is a road bench-op acceptable at all, or does it dilute
   the capital-is-the-shop ruling? (It's priced as an exception, but the
   ruling is recent and deliberate — easy cut.)
