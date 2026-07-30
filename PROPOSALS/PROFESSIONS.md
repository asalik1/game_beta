# Professions — three trades, mastery, and earned gear crafting (2026-07-29 redesign)

A profession layer for Crownless: **three trades**, each a self-contained gather-and-craft
identity a character LOCKS into. You gather your trade's materials, hunt its blueprints,
and grind mastery by crafting — and the payoff is being able to craft gear (capped at A),
with a small chance for a generic A craft to promote into a random NAMED A unique. Nothing
installed; decision document. Supersedes the 2026-07-27 draft.

**Governing ruling — REVISED (owner, 2026-07-29).** The old law was "crafting targets
consumables and cosmetics — never gear power" (from SOCIAL_LAYER §2). The owner overturned
it: **crafting DOES make gear, but power is EARNED, never sold.** Gold buys nothing but the
right to switch trades — every piece of crafted power sits behind a profession lock, a
mastery climb, a material hunt, a blueprint, and (for named gear) a low promotion roll. This
keeps the deeper principle the old ruling was protecting — *deterministic, effort-gated
acquisition, never a pay-to-win shortcut* — while letting professions chase the thing players
actually want: a named A passive. Gems still own build quality; reforge still owns fix-this-item;
S-tier and S-named gear stay **drop-only**, uncraftable.

---

## 1. The three trades

Gathering is no longer separate — each trade gathers its OWN materials. Six professions
collapse to three unified identities.

| Trade | Crafts gear slots | Crafts consumables | Gathers | Trainer (capital) |
|---|---|---|---|---|
| **Alchemist** | charm, gloves | the potion shelf (CONSUMABLE_GRADES.md) | herbs + reagents (potions), cloth (gloves), bone/relic (charms) | Herbalist Kesh |
| **Blacksmith** | weapon, helmet | reforge / upgrade stones (gold-substitutes for the bench ops) | ore / metal | Smith Petra |
| **Tailor** | armor, pants, boots + **bags** | — | cloth / leather | Seamster Suli |

- All seven gear slots are covered exactly once: weapon/helmet (Blacksmith), armor/pants/boots
  (Tailor), charm/gloves (Alchemist). A locked character can only ever craft their trade's
  2–3 slots — the rest come from drops, alts, or swapping trades. That reliance IS the identity.
- **Cut from the old draft** (owner): bombs (not real), elixirs (folded into potions — same thing),
  and all cosmetics (dyes / weapon finishes / outfits — cosmetics don't belong in a craft trade;
  they stay with wardrobe + Renown).
- **Salvaging** is no longer a profession — see §4 (it becomes a universal break-down action).

## 2. Locking a trade + the swap economy

- A character **locks a single trade**. While locked you can gather ONLY that trade's materials,
  receive ONLY that trade's blueprint/material drops, and craft ONLY that trade's outputs. The
  world's gatherable content and loot reads your active trade (the WoW gathering-gate pattern,
  now the whole layer's spine).
- **Swap anytime for gold.** Cost starts at **5,000g**, **doubles each swap** (5k → 10k → 20k → 40k…),
  and **resets to 5k at the weekly epoch** (the trusted-clock weekly, same as Vigils/renown). So one
  rotation a week is cheap; churning trades in a single week is punishing.
- **Mastery persists per trade across swaps** — locking sets which trade is ACTIVE, it does not
  reset progress. Swap back to Blacksmith next week and your smithing mastery is exactly where you
  left it. This makes the weekly 5k a soft rotation lever, not a progress wipe.
- Materials are **stash-shared account-wide** (unchanged), so an alt on a different trade is the
  intended way to cover the slots your main can't craft.

## 3. Mastery — the tier climb

Each trade has its own **mastery points**, earned by crafting. Mastery is the gate on WHAT tier you
can attempt; higher-grade crafts pay more mastery, so the climb accelerates as you invest.

| Mastery band | Unlocks crafting | Also needs |
|---|---|---|
| Novice (start) | F, E | — |
| Adept | D | — |
| Expert | C | — |
| Artisan | B | generic **B blueprint** (drop/shop) |
| Master | A | generic **A blueprint** (drop/shop) |

- Mastery unlocks the tier's ACCESS; blueprints (§5) are the specific recipe at B and A. F–D need
  no blueprint — mastery alone.
- The climb is a companion to play, sized in farm-minutes (§9), every threshold shown on the trade
  card (MT4 legibility rule).

## 4. Materials — gathered + dropped, both trade-gated

One schema kind: `kind:"material"`, stackable (cap 99), stash-legal, sellable at flat base (anti-haul
law), never rollable. Materials are keyed to **what gear is physically made of**, NOT to a trade — so
a material can feed more than one trade, and which trade can *use* a given material is just whichever
trade's recipes call for it (owner, 2026-07-29). **Per-grade material NAMES and the full mob→material
drop map live in MATERIALS.md** — this section owns the economy, that doc owns the catalog.

| Material | Salvaged from (gear type) | Crafts | Trades that use it |
|---|---|---|---|
| **Ore / metal** | weapon, helmet | weapons, helmets | Blacksmith |
| **Cloth / leather** | armor, pants, boots, **gloves** | armor/pants/boots, bags, **gloves** | Tailor **and** Alchemist |
| **Bone / relic** | charm | charms | Alchemist |
| **Herbs + reagents** | — (gathered only) | the potion shelf | Alchemist |

So cloth is shared: a Tailor uses it for armor/pants/boots, an Alchemist uses the same cloth for gloves —
salvaging a glove gives cloth, and an Alchemist can use it. Charms are trinket-work, not brewing: they
salvage into **bone/relic** (fang, bone, sealed relic — sourced from undead, skeletons, and beasts, on
theme with the Concord's restless dead). Herbs + reagents are the potion feedstock only. Ore stays
Blacksmith-only; bone/relic and herbs/reagents stay Alchemist-only.

Four faucets fill the pool. **Only nodes are trade-gated** — a node is a deliberate gather your trade
unlocks. Everything incidental (mob kills, chests, salvage) is **ungated**: you get the material the
source yields by type, pick it up if your trade wants it, else discard or sell.

1. **Nodes (trade-gated)** — zone-authored props rolled on curves not uniforms (env-distribution rule):
   ~2–3/room on friendly terrain, rare rich rooms, hard-capped. An E-prompt channel (~2s). Respawn per
   RUN. A node appears/interacts only for a character whose **active trade uses that material** (a cloth
   node is workable by Tailor or Alchemist; an ore node only by Blacksmith).
2. **Mob drops (ungated, thematic)** — a mob drops the material its **body** yields, by type, regardless of
   your trade (a wolf always drops some grade of **cloth/leather, never ore**); take it if your trade uses
   it, else discard/sell. Mob-type → material: **beasts** → leather + reagent, **undead** → bone + scrap
   metal, **humanoids/cultists** → cloth + reagent, **armored/construct** → ore. Amounts:
   - **Trash mob:** a **small chance** (not guaranteed) at 1–2 units of low-grade material.
   - **Elite:** a **guaranteed** material drop, more units and **one grade higher**, ON TOP of its gear
     chest + gem — plus a **small chance at a complete finished item** (a potion or bag, **≤A**, since S
     is boss-only, BOSS_LOOT.md).
   - **Grade scales with mob tier + act:** Act 1 → F/E, Act 2 → D/C, Act 3 → B/A. **Mob materials cap at
     A** — S materials are boss-Gold-chest-only. (Blueprints/gems don't come from trash — see §5, and gems
     ride the elite/boss channel per ACT2_ECONOMY §5.)
3. **Boss chests (ungated)** — the supply-chest materials/goods, speced in BOSS_LOOT.md §3.
4. **Salvage (ungated breakdown)** — break any gear piece and you always get the material for
   **that gear's type**, quality matching **its grade**: an E weapon → low-grade ore, an A robe → high-grade
   cloth. That material crafts the same kind and tier of gear. Salvaging **off-profession still yields the
   material** — break a weapon while you're a Tailor and you keep the ore; you just can't use it until you
   swap to Blacksmith (5k), so you hold it, swap, or **sell it for gold**. Yield is below sell price in gold
   terms (selling stays the money move; salvage feeds the craft pipeline).

## 5. Blueprints + the named promotion

- **Generic blueprints** gate the B and A recipes, and come **only from boss drops or the shop** — no
  ordinary-mob source. One blueprint = one generic recipe (e.g. "Generic A Helmet"). F–D need none
  (mastery alone). A lucky shop roll on an A blueprint is a legit windfall — the reward for being lucky.
- **Blueprint prices** (owner, 2026-07-29). The **midpoint-power slot is the baseline**: sort the seven
  slots by main-stat budget (`SLOT_MAIN_BUDGET`, items.gd) and the median is 2.5 — helmet/pants/charm.
  That slot sets baseline: **B = 30,000g, A = 75,000g**. Every other slot scales in direct proportion,
  **multiplier = slot budget ÷ 2.5** — below the midpoint costs less, above costs more, straight off the
  power number, no fudging.

  | Slot(s) | Main-stat budget | ×mult (budget ÷ 2.5) | B blueprint | A blueprint |
  |---|---|---|---|---|
  | Weapon | 5.0 | ×2.0 | 60,000g | 150,000g |
  | Armor | 3.0 | ×1.2 | 36,000g | 90,000g |
  | Helmet / pants / charm | 2.5 | ×1.0 (baseline) | 30,000g | 75,000g |
  | Gloves / boots | 2.0 | ×0.8 | 24,000g | 60,000g |

  Boss-dropped blueprints are the free-but-rare path; these prices are the shop/deterministic path. The
  weapon blueprint (A 150k) is the priciest in the game by design — it is the biggest power lever, so it
  correctly sits above the 100k Codex; the power math, not a cap, decides the order.
- **There is NO named blueprint.** You cannot target a specific unique. Named gear is a **promotion
  roll**: when you craft a **generic A** piece, there's a **small chance it promotes to a random NAMED
  A** unique of that slot/class — with its passive (owner's Q2+Q3 answer). Craft generic A's, and
  occasionally one comes out named.
- **The chase, stated plainly:** you grind mastery to Master, hunt the generic A blueprint (boss/shop) +
  the rare materials, then craft generic A pieces over and over hoping for the promotion — and a
  promoted named A feels earned because everything upstream was. Named A + all S remain much rarer as
  drops too, so both paths to a named A are a real achievement.
- **Ceiling: A.** No craft reaches S, and the promotion only ever yields named **A** (never named S).
  S and S-named are **drop-only — never craftable AND never sold in any shop** (owner, 2026-07-29: the
  gear shop caps at A, same as the potion shelf). The vanished-legend prestige tier, earned from
  boss/elite loot alone.

## 6. What each trade makes

**Alchemist** — charms, gloves, and the sustain shelf:
- Gear: charm + gloves (generic F→A; named-A promotion).
- Consumables: the full potion matrix (CONSUMABLE_GRADES.md) — grades gated by mastery, B+ potions
  need generic potion blueprints, S potions uncraftable. The Alkahest Codex synthesis (that doc §9)
  is the Alchemist capstone.

**Blacksmith** — weapon, helmet, and the bench-stone line:
- Gear: weapon + helmet (generic F→A; named-A promotion).
- Consumables: **reforge stones, upgrade stones, and kin** — a stone is a **gold-substitute for a bench
  operation** (owner): instead of paying the gold cost to reforge (re-roll substats at Petra's bench,
  live) or upgrade (the masterwork/upgrade bench, MASTERWORK.md if built), you spend the matching stone.
  Crafted from smithing materials, tiered to the gear grade they service, priced by the 0.7×-cost rule
  (§9) so they're a time-for-gold trade, never a free reforge. No whetstones / room-buff kits — those
  were an old-draft invention and are cut.

**Tailor** — armor, pants, boots, and inventory:
- Gear: armor + pants + boots (generic F→A; named-A promotion).
- **Bags**: craftable bag tiers (bags currently drop only) — deterministic inventory space, the least
  balance-sensitive utility in the game.

## 7. Capital integration

- Trainers teach the trade, sell a rotating blueprint or two, and host the craft station (capital-is-the-shop
  law: Kesh's bench, Petra's forge, Suli's table). Crafting happens at the station.
- **Favor** (existing npc_favor) keeps its small role: a discount on the craft/gather fees and the swap
  cost at high standing — a convenience, never a power or mastery shortcut.
- Codex: a Professions shelf (active trade, mastery band, known blueprints) — codex staleness rule.

## 8. Schema + save surface

- `kind:"material"` (nodes + drops + salvage), `kind:"blueprint"` (learn-on-craft-access, generic B/A).
- `player.profession` = the single locked trade; `player.mastery` = {trade: points} (persists across swaps);
  `player.blueprints` = known generic recipes; `player.swap_cost_step` (weekly-reset counter).
- Crafting = station UI: pick a known recipe, consume materials + gold fee, gain mastery, roll promotion
  on generic A. Per-character (materials stash-shared is the account glue).
- Named promotion reuses the existing UNIQUES table (items.gd) — a promoted craft is literally that
  named item; no new art, no new passive wiring.

## 9. Economy sizing (first guesses, all knobs)

- Mastery in farm-minutes: Adept ≈ 3 min of crafting, Expert ≈ 8, Artisan ≈ 20, Master ≈ 45 — plus the
  materials, which is the real time cost. The climb rides alongside play, never a second job.
- Craft cost of a consumable ≈ 0.7× shelf price (materials + gold) — deterministic and cheaper than
  buying, but you spent the gathering time; the shelf stays honest for non-crafters.
- Named A promotion chance on a generic A craft: small (first guess ~3–5%), tuned so a Master with a
  steady A-material supply lands a named A on the order of a long session, not a single afternoon.
- Swap: 5k base, ×2 per swap, **no cap** (self-limiting — the 6th swap in a week is 160k), weekly reset (§2).
- Salvage yield: gold-equivalent ≈ 0.6× sell price (selling stays the money move).

## 10. Interlocks

- **Gear system**: crafting is a THIRD acquisition path beside drops and shops; gems + reforge unchanged
  (you socket/reforge a crafted piece exactly like a dropped one). S/S-named untouched — still drop-only.
- **Consumables**: CONSUMABLE_GRADES.md §11 is the Alchemist's potion recipe ladder; this doc owns the
  trade/mastery/gear frame, that doc owns the potion specifics (no duplication).
- **Bosses**: the sole source (with the shop) of B/A blueprints, plus the rarest materials — the reason
  the A-craft chase routes through boss content.
- **Capital / favor / Vigils**: trainers + stations + discounts; Vigil satchels a daily material faucet.
- **Future market**: materials + consumables are the sanctioned tradable set; crafted GEAR is NOT tradable
  (it's the earned-not-sold line) — revisit if a market ever lands.

## 11. Build order

1. `kind:"material"` + node gathering (trade-gated) + universal salvage — the material economy first.
2. Mob-drop materials + blueprints (trade-gated loot tables; boss weighting).
3. Mastery + tier unlocks + the craft station UI (generic F→A, no promotion yet) — proves the loop.
4. Named-A promotion roll (reuses UNIQUES) — the endgame chase.
5. Consumable recipes (Alchemist potions; Blacksmith kits) + Tailor bags.
6. Swap economy + weekly reset; favor discounts; capital polish.

## 12. Locked calls + remaining open questions

Owner-confirmed (2026-07-29):
- **Three unified trades**, gathering folded into each (single-lock, gather only your trade's material).
- **Mastery persists across swaps** — locking sets the active trade, never resets progress.
- **Salvage** is not a trade; it is the one ungated breakdown, yielding the salvaged item's physical
  material at its grade (usable by whichever trade's recipes call for it, else hold/swap/sell). §4.
- **Materials are physical, not tribal** — keyed to what gear is made of, shared across trades (cloth
  feeds both Tailor and Alchemist). §4.
- **Essence CUT.** A-craft = materials + generic-A blueprint + Master mastery, nothing else.
- **B/A blueprints from boss drops or shop only.** §5.
- **Named promotion: generic A only, class-matched** (gear is class-locked, so a promoted named A must be
  the crafter's class — forced, not a choice). No named S ever crafted.
- **Swap cost: unbounded doubling, weekly reset** (self-limiting).

Remaining open call:
1. **Two trades ever?** Single-lock is the call; if late game feels slot-starved, an earned (not bought)
   second slot is the pressure valve — parked, not proposed.
