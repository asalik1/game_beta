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

Line numbers are deliberately omitted for `items.gd` — it is the file this whole
arc rewrites, so any number pinned here is wrong by the next commit (it already
happened once). Symbols are greppable and don't rot.

| System | Entries | Rule-changers |
|---|---|---|
| Skill tree (`Skills.TREES`) | 72 cells | **1** (Last Rites) |
| Gear substats (`Items.SUBSTATS`) | 12 | **0** |
| Gems (`Items.GEM_STATS`) | 14 | **0** |
| Set bonuses (`Items.SET_BONUSES`) | 6 | **0** |
| S-weapon passives (`Items.PASSIVES`) | 6 | **6** |

Seven things in the whole game change how you play. The loot pool isn't small —
it's **one-dimensional**: every drop is a point on a single axis (power), which is
why it can't surprise you. DESIGN.md calls the build chase "the glue"; today the
glue is arithmetic.

## Cost truth (what the code actually says)

An earlier claim in conversation — "the mechanism exists, it needs a table and a
roll" — **is wrong.**

- `Items.PASSIVES` is **UI text only** — rendered once in `describe`, read nowhere
  else. Not a behavior registry.
- `passive` is only ever written onto `Items.S_GEAR[cls]["weapon"]` (in the S
  special path of `roll_item_of`). **Armor/boots/charm cannot carry one.**
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

### Why S survives L (settled 2026-07-17)

**L outscales S, freely.** L is the grind trophy; making it the top of the stat
ladder is the point. An earlier draft of this doc treated `GRADE_MULT` for L as
the load-bearing number — "does S stay worth carrying?" — which was the wrong
frame. It assumed S competes on stats, a fight S loses by definition.

**S survives on rune flexibility, not numbers.** L's passive is LOCKED and fixed;
S's is ROLLED. So the choice per slot is L's raw stats + a fixed keystone against
an S carrying the rune your build actually wants. Self-balancing: a build-defining
rune is worth eating a stat loss for, a mediocre one isn't. The L/S gap doesn't
need to be tuned so S stays "competitive" — S is a *sidegrade with a reason*.

### Rune tiers (settled 2026-07-17)

**Every grade B through L carries a rune.** What differs is whether it's rolled or
locked, and what job it does:

| Tier | Rune | Job |
|---|---|---|
| B / A / S | **rolled** | weaker, OR carries a drawback, OR supports an alternative playstyle |
| **L** | **locked, fixed** | strong, and **covers that class's endgame weakness** |

**All four L slots carry a locked rune — 24 total (4 slots × 6 classes).**

**Six of the 24 already exist and already do exactly this job.** `Items.PASSIVES`
is, read honestly, a weakness-fixer table with one entry per class:

| passive | the weakness it covers |
|---|---|
| `kingsblade` | warrior has no **range** → Cleave hurls a wave |
| `windward` | archer has no **sustain** → Second Wind at 1.5s (from 3s) |
| `wellspring` | mage is **mana-starved** → +50% regen |
| `mirrorstep` | assassin is **fragile** → dash reflects projectiles, softens AoE |
| `dawnbreaker` | paladin has no **AoE** → Judgment splashes |
| `voidmaw` | warlock gets **swarmed** → curse-wave shoves the room off |

All six are built and dispatched today (`player_kit_*.gd`). They become the L
**weapon** runes unchanged. L is not a new idea — it is this pattern, extended
from one slot to four.

**The FRAMEWORK for L already exists — it's the owner's own S-passive rule.** Ruled
2026-07-07: each passive is *"its class's bullet-hell DENSITY ADAPTER for endgame —
the ceiling is still there, just a bit more forgiving if the player farms for the
gear; forgiveness purchased with time, never granted."* Each channels power into
that class's UNCONSTRAINED axis, never a raw damage/mobility crank. That IS "covers
the class weakness in endgame." L inherits the rule whole; it does not need a new one.

Two standing rulings that constrain L authoring:
- **Parity is not a bug (2026-07-09).** kingsblade/dawnbreaker out-damage
  wellspring/windward *intentionally* — plate scales less from damage stats, so the
  legendary is plate's scaling compensation. **Do not re-flag in audits.**
- **Gate crit CONDITIONALLY** (warlock Nightfall crits only on `crush`-tagged
  abilities) so a rune never feeds a DoT double-dip.

**THE REAL GATE is still design input, not authoring**, but it's narrower than it
looks: the framework names the *shape* (density adapter on the unconstrained axis);
what's missing is **18 specific weaknesses** — armor/boots/charm × 6 classes.
`TIERLIST.md` won't supply them; it's a power ladder, not a weakness inventory
(fragments only: assassin "squishy, manaless", paladin/warrior Bulwark "easiest
pilots, lowest ceilings"). Answer "what are this class's other three endgame
falloffs?" ×6 and the runes write themselves — the existing six are ~7 lines each.
Skip it and L is 18 stat sticks wearing a passive's clothes.

**Bonus: the B→L rune call closes a flagged watch-item.** The same 2026-07-07 note
warns that *"the L40-70 pre-S window is where avoidance classes are weakest (adapter
not yet farmable, density rising) — the ACQUISITION timing of each passive is the
real tuning knob, more than its numbers."* Adapters used to exist ONLY at S, so that
window had none. Rolled runes at B/A/S now fill it with partial ones. Note the
inverse: moving locked adapters from S up to L *lengthens* that window — the rolled
tiers are what keep it survivable, so they are not optional decoration.

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
- **It inverts which pen you stack** (physpen ↔ magpen) — the whole gearing path
  flips, not one number.
- **It changes which enemy resist you fight** (physres ↔ magres) — good into some
  rooms, bad into others. A build with *matchups*.
- **It's felt** (NO SILENT EFFECTS) — damage numbers visibly change per enemy.

**The roll-pool question this section used to raise is now closed.** It asked
whether `roll_subs` should keep erasing the off-type pen by class — which would
have made a damage-type rune carry a gearing tax (you'd flip to magic and then be
unable to *roll* magpen). The pen un-gate shipped 2026-07-17 settles it: below S
the pool is class-agnostic, so a Stormcalled archer simply rolls the pen they now
need. The un-gate isn't merely compatible with damage-type runes — it's the thing
that makes them gearable at all. S's first roll stays class-usable, so a legendary
still drops sane for the default build.

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
5. ~~**L power delta** — does S stay worth carrying?~~ **Resolved 2026-07-17:** L
   outscales freely; S survives on rune flexibility, not stats. See "Why S survives
   L" above. The live question is now how many L slots carry a locked passive
   (weapon only = 6 authored, all four = 24).
