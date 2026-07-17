# PROPOSALS — Runes + the Legendary tier (decision document)

Design + cost document. Owner picks; build happens in a follow-up task.

**Status (2026-07-17): the itemization groundwork is BUILT; the rune system is not.**

Shipped (full suite green):
- Substat pens **un-gated** for every grade below S (`roll_subs`), and un-gated for
  all grades at the bench (`reforge_affix`). Round 15's "no dead stats" is now
  narrowed to S's first roll only.
- **S first-roll guarantee** — a legendary still drops class-usable; what the
  player reforges it into afterward is their own risk.
- **Transmute main** — new bench op (`Items.transmute_main`, `Balance.TRANSMUTE_MAIN_COST`).
  Mains still ROLL as class primary (power envelope untouched, no bricks); the
  player pays to point that budget at another attribute, keeping the rolled
  magnitude. This is the half of an off-meta build that gear has to supply.

Not built: runes themselves, the L tier, the S name pool. Open questions below
still stand.

## The problem, measured

Every source of player power, sorted into "makes a number bigger" vs "changes a rule":

| System | Entries | Rule-changers |
|---|---|---|
| Skill tree (`skills.gd`) | 72 cells | **1** (Last Rites) |
| Gear substats (`items.gd:392`) | 12 | **0** |
| Gems (`items.gd:185`) | 14 | **0** |
| Set bonuses (`items.gd:732`) | 6 | **0** |
| S-weapon passives (`items.gd:159`) | 6 | **6** |

Seven things in the whole game change how you play. The loot pool isn't small —
it's **one-dimensional**: every drop is a point on a single axis (power), which is
why it can't surprise you. DESIGN.md calls the build chase "the glue"; today the
glue is arithmetic.

## Cost truth (what the code actually says)

An earlier claim in conversation — "the mechanism exists, it needs a table and a
roll" — **is wrong.**

- `Items.PASSIVES` (`items.gd:159`) is **UI text only** — rendered at `:827`, read
  nowhere else. Not a behavior registry.
- `passive` is only ever written onto `S_GEAR[cls]["weapon"]` (`items.gd:534`).
  **Armor/boots/charm cannot carry one.**
- `player_core.s_passive()` (`:760`) reads **only `equipment["weapon"]`** and
  returns **one String**. Singular by construction.
- Dispatch is 8 hardcoded literals (`if s_passive() == "kingsblade"` at
  `player_kit_warrior.gd:36`, `== "voidmaw"` at `player_kit_warlock.gd:338`, …).

**Runes cannot be rolled from a table.** Each is a hand-authored branch at the
point the rule bends. The pool is bounded by authoring effort, not data. The
consolation: `kingsblade` is 7 lines. The pattern is proven — it just isn't plural.

---

## Tier restructure (owner direction, 2026-07-17)

| Tier | Halo | Source | Runes | Role |
|---|---|---|---|---|
| F–C | — | dropped | none | early game stays clean and teachable |
| B | purple | dropped | chance to roll | first rune moment (~ch4–5) |
| A | orange | dropped | rolls | build starts forming |
| **S** | **red** | dropped | rolls | **many named items**, mid → early-late |
| **L — Legendary** | **gold** | **quest only** | **exactly one, fixed** | one set per class, the very endgame |

**The key move:** the six existing S passives (`kingsblade`, `windward`,
`wellspring`, `mirrorstep`, `dawnbreaker`, `voidmaw`) are **by design** —
quest-gated endgame-fixers, hand-tailored per class. They move to **L untouched.
Zero rework.** That frees S from being a single fixed item per slot into a *pool*
of many named items — which is what actually attacks the one-dimensionality.

**S becomes many named items.** Today `S_GEAR[cls][slot]` is exactly one name.
`A_NAMES` is already a list-per-slot — that's the pattern S needs, but class-scoped.

**L is quest-gated, therefore never dropped** — so it skips `CHEST_TIERS`, the
per-chapter loot weights, and `GRADE_FLOORS` entirely, and needs no `BAG_SLOTS`/
`BAG_NAMES` entry (no legendary bags). That removes most of the grade-table churn.

---

## Rune categories (owner direction)

### 1. Generic
Always-fine, no conditions. The floor of the pool.
> **Broken Oath** *(warrior)* — Cleave stops being an arc and becomes a single
> ranged sword-wave. The melee opener turns into a poke tool.

### 2. Drawback — a gain worth considering
The category Diablo/PoE actually run on. A rune with a cost is a *decision*; a rune
without one is a bigger number wearing a hat. This is also the existing standing
rules ("safety→skill", "reward curve climbs with skill/risk") finally expressed as
loot instead of doctrine.
> **Weight of the Mountain** — +35% damage; you cannot dash and cannot be staggered.

### 3. Variant-gated (theme-specific)
Only live while the ability runs a given theme. Ties runes to the theme system
without duplicating it — themes own *elemental identity*, runes own *ability shape*.
> **Toxin Bloom** *(archer, Venom only)* — poison stacks spread from anything that
> dies while poisoned.

### 4. Mono-spec reward
Pays for committing every ability to one theme — currently a choice with **no
payoff**, since per-ability theme assignment is free and unrewarded.
> **The Single Path** — if all four abilities run the same theme, that theme's `fx`
> values +40%.

Cheap to implement: reads straight off `Classes.THEMES[cls][n]["fx"]`.

### 5. Off-meta reward — build it on DAMAGE TYPE, not attributes

**The attribute axis is thin.** All four attributes converge on one scalar:

```
attr_points[attr] × ATTR_SCALE[cls][attr] → atk_flat → atk
                                                     ↓
                            ability_coeff(slot) × atk → damage
```

`ability_coeff` (`player_combat.gd:528`) reads a flat per-ability float that has no
knowledge of attributes. **Quick Shot does not scale off AGI** — AGI is one of four
faucets into ATK, and STR is another at a worse rate. So an "attribute swap" rune
can only shuffle the *riders*: `hp_flat` (STR), `crit` (AGI), `dex` (INT). That's
one rune shape, repeated once per class:

> **Ironwood Draw** *(archer)* — STR converts to ATK at your primary's rate; AGI's
> crit rider is disabled. *(= trade all your crit for a pile of HP at equal ATK.)*

Real, and a genuine cost given how crit-centric archer is — but it's **one idea, not
a category.**

**The rich axis is damage type, and the seam already exists:**

```gdscript
# player_combat.gd:553
var dmg_type: String = effects.get("type", Classes.CLASSES[cls]["dmg_type"])
```

Damage type is **already overridable per-hit** via `effects["type"]`, and `_tfx`
(theme fx) already merges into that same dict at `:550`. A rune injecting
`effects["type"]` is nearly free.

> **Stormcalled** *(archer)* — your arrows deal magic damage instead of physical.

Why this is a build reroute and not a stat tweak:
- **It inverts which pen you stack.** `items.gd:566` already erases the off-type pen
  from the substat roll pool per `CLASSES_DMG_TYPE`. The whole gearing path flips.
- **It changes which enemy resist you fight** (physres ↔ magres) — good into some
  rooms, bad into others. A build with *matchups*.
- **It's felt** (NO SILENT EFFECTS) — damage numbers visibly change per enemy.

Open interaction: `roll_subs` erases the off-type pen based on the **class**, not
the equipped runes. A damage-type rune makes dead physpen substats live and live
magpen dead. Decide whether the roll pool follows the rune (complex, correct) or
stays class-keyed (simple — the rune carries a gearing tax by design).

---

## Where runes roll

**Any gear slot** (owner direction). Up to 4 active + 1 legendary.

Consequence worth accepting knowingly: this is D3-chaotic by design, and it takes
`dps_bench` partly blind — its `PRESETS` are fixed loadouts, so a 4-rune
combinatorial space won't be covered by the existing roster. The bench stays valid
for *baseline* class/theme DPS; it won't catch rune-stack outliers. That's a
tooling follow-up, not a blocker.

## Enabling refactor (once, small — first)

1. `s_passive() -> String` → `passives() -> Array` / `has_passive(id) -> bool`,
   scanning all four slots. Keep the awakened/dormant gate (`:764`) intact.
2. Mechanical rename at the 8 dispatch sites: `s_passive() == "x"` → `has_passive("x")`.
   **Required for correctness** — `== "kingsblade"` breaks silently the moment two
   passives are equipped.
3. `roll_item_of` gains a rune roll at B+; `stats_of` untouched — runes are
   behavior, not stats, and must never enter the scalar path.
4. Add `"L"` to `GRADES`, `GRADE_MULT`, `GRADE_COLOR` (gold), `LOOT_SOUND`,
   `MAX_PLUS`, `UPGRADE_GRADE_FACTOR`, `QUENCH_COST_BASE`, `GEM_SLOTS`/
   `GEM_SPECIAL_SLOTS`/`GEM_LEVEL_LIMIT`, `REFORGE_COST`. **Skip** `CHEST_TIERS`,
   `BAG_*`, chapter loot weights, `GRADE_FLOORS` (L is never dropped).
   Note `sub_count_for` uses `GRADES.find()` index math — appending L is safe.

Then per-rune authoring at ~5–15 lines each.

## Constraints these are written against

- **NO SILENT EFFECTS** (standing rule) — every rune must be visible or audible on
  trigger. A rune that can't be *felt* doesn't ship.
- **Identity-over-parity / non-identity-axis differentiation** — themes own the
  elemental axis, runes own ability shape. Keep them apart or both flatten.
- **Never inline a bare tuning number** — all magnitudes to `balance.gd`.
- **Free stats that saturate a buildable stat are unhealthy** — drawback and
  off-meta runes must not hand out a stat the player was already buying.

## The bench: gold buys certainty, stones buy gambles (settled 2026-07-17)

The three bench ops differ on **random vs chosen**, not on which slot they touch:

| op | which stat | magnitude | slots | price |
|---|---|---|---|---|
| `quench` | keeps | rerolls, never regresses | main + subs | gold, escalating |
| `reforge_affix` | **rerolls at random** | rerolls | subs only | gold, flat |
| `transmute_main` | **you choose** | keeps | main only | gold, flat |

**Transmute stays gold and deterministic.** Mains are quantitative and
load-bearing (12.5 × grade-mult across four slots), and an off-meta build is
already a raw-ATK sidegrade. Make the main a gamble and building one costs ~a
dozen rare stones for something that isn't even stronger — that kills off-meta
builds instead of enabling them.

**A Transmute Stone (planned, not built) is the right home for PASSIVE rerolls.**
Passives are qualitative — no "better" roll, just a different one — so a random
reroll is a fun gamble rather than a tax. Scarcity is the balance, which is a
better answer than the earlier "no rune rerolls at v1". Precedent exists:
`reset_stone` (talents) and `Palimpsest of the Path` (skill tree,
`ELITE_TOME_CHANCE` 0.15) are already elite-drop resets.

**Ship it as a bench CURRENCY, not a bag-click.** `use_consumable`
(`player_core.gd:1376`) is global and untargeted — every stone in the game fires
on bag-click with no target, so there is no "use this on that item's slot" flow to
reuse. The item panel's Reforge tab already targets an item and lists per-slot
buttons; a "Reroll passive — 1 Transmute Stone" button sits next to the gold ones
and inherits that targeting for free.

## Open questions for the owner

1. **Rune exclusivity.** Generic runes stack fine. Off-meta runes are
   build-*defining* — two conflicting scaling swaps on one character is incoherent.
   Do off-meta/mono-spec runes need a "one active" rule, or a dedicated slot?
2. **Rune count per class at v1?** ~7 per class × 6 = ~42 authored branches. Off-meta
   adds ~2 per class (one damage-type flip, one attribute-rider swap), not the
   12–18 an earlier draft of this doc claimed.
3. **Do runes reroll at the reforge bench?** Natural gold sink, but it deletes the
   "found it" moment. Suggest: no at v1.
4. **How many named S items per class per slot?** `A_NAMES` carries 5–7 per slot as
   precedent.
5. **L power delta.** `GRADE_MULT` S = 3.2. What's L — 3.6? 4.0? This is the "end
   all be all" dial, and it decides whether S stays worth carrying.
