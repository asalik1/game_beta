# Boss Loot — the gear chest + supply chest system (PROPOSAL)

Status: DRAFT v1 for owner red-pen (2026-07-29). Nothing installed. Owner-specced this session.
Cross-cutting loot redesign — supersedes the boss-drop wiring in game_flow/chest.gd and the
S-in-general-band line of ACT2_ECONOMY.md §4. Companion to PROFESSIONS.md (materials feed the
trades) and CONSUMABLE_GRADES.md (potion grades/lanes).

## 0. The rulings this encodes (owner, 2026-07-29)

- **S is boss-only.** S-tier **gear, bags, and potions** drop ONLY from a boss — never shop, never
  renown, never world/elite chests. Everything else caps at A.
- A boss always drops its gear in a **grade-matched chest (F→S)** — the chest wears the gear's grade.
- On top of the gear, the boss drops **1–3 supply chests**, tiered by ACT: **Bronze (Act 1) / Silver
  (Act 2) / Gold (Act 3)**.
- Supply chests are a **crafting-materials faucet first, finished-goods faucet second** — the common
  pull is materials (feeding the professions); finished bags/potions are the rarer upside.
- **Black-market (laced) potions can drop from chests** (overturns the old "drops are clean-lane only").

## 1. The two chest kinds a boss drops

| Kind | Count | Grade axis | Holds |
|---|---|---|---|
| **Gear chest** | 1, guaranteed | grade-matched **F→S** (boss gear band) | the boss's guaranteed gear piece |
| **Supply chest** | **1–3** | act-tiered **Bronze/Silver/Gold** | materials, gems, bags/potions (mostly materials) |

- The **gear chest** replaces today's wiring: the boss's direct gear is currently a 1/3 roll
  (`BOSS_GEAR_CHANCE`) plus a gold chest that pulls gear from the general band. New: the gear is
  **guaranteed**, delivered in a chest whose colour/tier matches its grade (the grade-telegraphed chest
  already exists, chest.gd — the grade is rolled at drop and shown on the sprite). S only at Act 3
  (boss band has S from ch12).
- The **supply chests** are the new thing — see §2–§4.

## 2. Supply chest tiers (by act) and their ceilings

| Chest | Act | Bags up to | Gems up to | Potions up to | Materials up to |
|---|---|---|---|---|---|
| **Bronze** | 1 | B | Lv2 | B | B-grade |
| **Silver** | 2 | A | Lv3 | A | A-grade |
| **Gold** | 3 | S | Lv4 | S | S-grade |

- The **ceiling is rare**: a Bronze chest *can* give a B bag / Lv2 gem / B potion, but those sit at the
  top of its table and rarely land — you mostly pull mid and low.
- **Higher tiers phase out the low end.** A Gold chest stops dropping the junk grades entirely — low-tier
  gems, low-grade materials, low-tier bags and potions all fall off its table, so its floor rises with
  its ceiling.
- **Drop rates scale with the boss** — a stronger boss shifts the whole table toward its ceiling.

## 3. Materials first, finished goods second

The load-bearing rule: a supply chest usually pays **crafting materials**, not the finished item — this
is what makes the professions (PROFESSIONS.md) the primary way to get bags and good potions.

- **Bags:** a finished bag is a **rare** chest drop (bag drops are not guaranteed). The common pull is
  **bag materials** (cloth/leather) so a Tailor crafts the bag.
- **Potions:** a chest won't always hold finished potions — it **usually holds potion materials**
  (herbs/reagents) so an Alchemist brews them. Finished potions are the rarer upside.
- **Gems:** exactly one of the boss's supply chests is **guaranteed to contain a gem**; the ceiling-level
  gem within it is the rare roll.
- **Laced potions:** black-market (laced) potions **can drop from chests** — the world's loot can be cut
  with blightwater after all (this reverses CONSUMABLE_GRADES.md §10's old "drops = clean lane only").
- Materials are grade/level-scaled by the boss's strength and phase out at the low end in higher tiers,
  same curve as everything else in the chest.

## 4. The 1–3 count — missing chests become materials

The boss yields **three supply slots**. Each slot is either an actual supply chest or, if it doesn't roll
one, a **bundle of raw crafting materials** whose grade scales with the boss's strength. So:

- **Best case:** 3 supply chests.
- **Common case:** 1–2 chests + material bundles filling the rest.
- **Floor:** at least 1 supply chest, the other two slots paid out as materials.

Nobody ever walks away with nothing — a light chest-luck run still hands you the materials to craft what
the chest would have given, which is the professions loop by design.

## 5. Where S actually comes from (the whole map)

| Source | Max gear | Max bag | Max potion | Max gem |
|---|---|---|---|---|
| Shop | A | A | A | (per gem shelf) |
| World / elite chest | A | — | — | — |
| Boss gear chest | **S** (Act 3) | — | — | — |
| Boss Gold supply chest | — | **S** (Act 3) | **S** (Act 3) | **Lv4** |
| Renown | — (never gear) | — | — (cache = low-grade only) | — |
| Craft | A | A | A | (gem synth, existing) |

**Consequence:** `CHAPTER_GEAR_WEIGHTS` (the general band shared by shop / world chest / elite chest /
clear-spoils) **loses its ch12 S entry — caps at A.** S gear moves entirely to the boss gear chest. This
supersedes ACT2_ECONOMY.md §4 ("generic S enters at ch12 in the general band").

## 6. Reconciliations / build notes

- **chest.gd**: gains a chest KIND (gear vs supply) and a supply-content roller (materials/gems/bags/
  potions with the tier ceilings + phase-out). The existing grade-at-drop telegraph stays for the gear chest.
- **game_flow.gd `roll_boss_pack`**: drops the general-band gold chest; emits 1 grade-matched gear chest
  (gear guaranteed — `BOSS_GEAR_CHANCE` retired for bosses) + the 3-slot supply payout (chests ∪ material
  bundles).
- **balance.gd**: `CHAPTER_GEAR_WEIGHTS` loses S (caps at A); new knobs for supply-chest tier tables
  (per-act ceilings, phase-out floors, boss-scaled rates), the 1–3 chest odds, and the material-vs-
  finished-good split. All knobs, no inline numbers.
- **Materials schema**: supply-chest materials are the same `kind:"material"` as PROFESSIONS.md §4. Open
  detail: are chest materials trade-gated (only your locked trade's) or ungated by item-type like salvage?
  Proposed **ungated** (you get the material, use it if your trade matches, else hold/sell/swap) — the
  chest is a found cache, not a gather node. Confirm.
- **Consumable doc**: CONSUMABLE_GRADES.md §10 "drops = clean lane only" is reversed here (laced can drop);
  update that line.
- **Elite chests** keep giving gear from the general band (now A-capped) — only *boss* chests split into
  gear + supply (owner: "only boss chests specifically"). Full elite loot: gear chest (≤A) + 1 gem
  (act-floor level) + a guaranteed material drop (+1 grade over trash) + a **small chance at a finished
  potion/bag (≤A)**. Trash mobs: a small chance at 1–2 low-grade materials, no gems. Both detailed in
  PROFESSIONS.md §4; gem sourcing in ACT2_ECONOMY.md §5.

## 7. Open calls

1. **Chest materials trade-gated or ungated?** (§6) — proposed ungated like salvage.
2. **Supply-chest count odds** — what shifts a boss from 1 chest to 3? Pure boss strength, first-clear
   bonus, difficulty tier, or a mix?
3. **Laced potion drop rate from chests** — a small side-chance, or a dedicated "cut" slot? And do laced
   potions drop from world/elite chests too, or boss chests only?
4. **Finished-good rates** — rough odds for a finished bag vs bag-materials, finished potion vs potion-
   materials (needs econ_audit once Act 2 income exists).
