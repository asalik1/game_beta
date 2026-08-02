# Borrowed loops — the SvZ2 study, sorted (2026-07-28)

Concepts mined from a decompiled **Samurai vs Zombies Defense 2** (Glu, 2014),
a game the owner played and liked, sorted against what Crownless already has.
Nothing here is installed; **decision document**.

**Boundary:** mechanics and structure only. That tree is decompiled proprietary
Glu code and art — no asset, no line of code, no data table from it may enter
this repo. Crownless ships commercially under the CC0/CC-BY-only sourcing rule
(CLAUDE.md § Asset sourcing).

Cross-links, not restatements: the Vigils live in `DAILY_DUNGEONS.md`, the
cosmetics wallet in `DESIGN.md`, gear crafting in `GEAR_UNIQUE_PASSIVES.md`.

---

## 1. Second Shape — mobs that become something else

**The gap (owner):** "I have simple mob mechanics but not any mechanics that
transform the mob into something else."

**The good news — the hook already exists.** `enemy.gd` `die()` opens with a
death-trigger trait block that already runs three of these:

- `bloat` — bursts into a lingering blight pool.
- `martyr` — its death-wail heals and enrages nearby allies.
- `tether` — one falls and the bond restores its twin to full.

A transform is the same block, one more branch. This is not new machinery; it
is a fourth entry in a pattern already carrying three. That is why this is the
cheapest big-feeling idea on the list.

### The four shapes

Each teaches a different lesson, which is the point — a transform that doesn't
change how you play is just a second health bar.

| Shape | Trigger | Becomes | The lesson it teaches |
|---|---|---|---|
| **Molt** | death | a faster, frailer crawler | don't turn your back on a corpse |
| **Brood** | death | N smalls | spend the AoE *before* it dies |
| **Rise** | death, after a delay | a hostile version of itself | finish the room, then leave |
| **Crown** | *survival timer*, not death | an elite | kill order matters — the clock is the tell |

**Crown is the interesting one** and the one SvZ2 doesn't have. It inverts the
family: instead of paying out on death, it punishes *ignoring* a mob. A trash
unit left alive for N seconds promotes. That turns a pack from a damage-sponge
queue into a target-priority puzzle, which is the kind of pressure the Depths
wants and currently gets only from the stacking curse.

### Rules it must obey

- **NO SILENT EFFECTS.** Every shape needs a tell before it happens (Crown: a
  visible charge-up; Molt/Brood/Rise: a death telegraph) and a codex line. The
  player must be able to learn the counter.
- **A curve, not a coin flip.** Per the env-distributions standing rule,
  transform frequency is a probability curve — common at the shallow end, and
  never so dense that a room becomes unclearable.
- **Codex first.** New trait → codex entry in the same change, per CLAUDE.md.
- **Depth-gated variants.** Rise and Crown are natural Depths-only traits,
  appearing past a depth threshold — new pressure that isn't another stat mult.

### Open

- Does a transformed mob pay XP/loot twice, or does the *final* form pay? (Pay
  once, on the last form — otherwise Brood becomes a farm exploit.)
- Co-op: the host owns the transform and fans it, same as `host_enemy_died`.

---

## 2. The Toll — gold buys **depth**, not power

**Owner's idea, and it's the strongest thing to come out of this study.** At the
point a Crucible run stalls, pay gold for temporary, run-scoped stats. The
choice: bank gold toward permanent power, or gamble it on reaching a drop
that's worth more than the gold spent.

**Why it fits.** Gold's only jobs today are the shop (`game_base.gd:794`,
`game_world.gd:1244`) and crafting (`items.gd` `REFORGE_COST`, 120 → 3500 by
grade). Both are *optimization* sinks. Nothing converts gold into **reach**.
This is also the SvZ2 leadership mechanic in disguise — an in-run economy where
the interesting decision is spend-now versus invest — rebuilt on a currency
that already exists and already needs another job.

### Shape

- **Run-scoped.** Bought power dies with the run. Never persists.
- **Escalating price, no flat cap.** Each purchase costs more than the last
  (geometric). The price curve *is* the limiter and *is* the decision — this is
  exactly SvZ2's leadership upgrade threshold, where the cost of the next tier
  is measured in units you didn't summon.
- **Offer points:** Crucible between bosses; Depths at checkpoint bosses (every
  10th). **Not** the Depths camp merchant — that shop is deliberately one-time
  and freed on the first dive (`endgame.gd` `descend()`); reopening it would
  undo an existing decision.

### What it should buy

Prefer **stripping the stacking curse** over adding raw damage. The Depths
already applies escalating debuffs (`_apply_player_debuffs()`, "THE DARK
PRESSES IN"). Paying gold to push one stack back is thematically exact, reads
instantly, and reuses an implemented stack list instead of inventing a buff.
For the Crucible, a survivability band (health / healing received) is the safer
purchase than a damage band.

### The skill guard — the part that matters

Owner intends the ladder to hinge on skill. Unguarded, a gold-for-stats toll
converts the Crucible ladder into a gold ladder: the deepest run belongs to
whoever farmed most, not whoever played best.

**Proposal: two ladders, one mode.** A run that takes the Toll is flagged, and
a flagged run *does not set a personal best* and does not pay the PB Renown
(`RENOWN_PB_CRUCIBLE` / `RENOWN_PB_DEPTHS`). It still pays gold, gear and
drops. So:

- **The pure ladder** — untolled. The skill record. Unbuyable.
- **The deep ladder** — tolled. The farm lane, where gold converts into loot
  depth.

This resolves the tension honestly rather than hiding it, and it makes the
choice legible at the moment of purchase: *this run stops being a record and
becomes a harvest.* That framing is the feature.

---

## 3. Stake bands — one table, three consumers

**SvZ2's trick:** `MultiplayerTweakSchema` is keyed by entry cost. Row `50`
sets hero move 0.5, hero health 0.5, helper damage 0.25, gate health 1,
starting leadership 25, attack pool 300. Row `100` shifts the whole bundle. The
stake selects an entire matchup's parameters from one row.

**Owner: "not sure where to fit it yet."** Here is the fit — it is not a
feature, it is a *shape* for three things that are otherwise three separate
tuning surfaces:

```
Balance.STAKE_BANDS = {
  0: {mob_dmg, mob_hp, player_heal, drop_grade_floor, renown_mult, gold_mult},
  1: {...},
  2: {...},
}
```

Consumers:

1. **Crucible/Depths wager** — declare a stake before the run; §2's Toll reads
   the same table for its price curve.
2. **The Vigils' daily modifier** — `DAILY_DUNGEONS.md` §5 already wants a
   modifier seeded off `day_index`. That modifier *is* a stake band, picked by
   the calendar instead of the player.
3. **Incursion tiers** — the weekly overlay's difficulty rungs.

**Precedent:** this is the `GEAR_POWER_ANCHORS` pattern — one measured table,
geometric interpolation, one call site — applied to a new axis. The argument
for doing it is that all three of the above will otherwise grow their own
private tuning constants, and the balance history says that is how knobs go
dead and unmeasured.

---

## 4. Codex completion pays Renown — **not** a new currency

**Owner:** "in the codex all u do is unearth lore when u kill enough monsters
… maybe throw in a small reward or achievement point redeemable for cosmetics."

**Half of this already exists.** `game_base.gd` `note_kill()` counts kills and
fires "LORE UNEARTHED" at `Lore.threshold(kind)`. `achievement_points()` sums
points, and `title_available()` already gates titles on `req_pts`, `req_lore`
and `req_kills`.

**Recommendation: do not make achievement points spendable.** They already have
a job — gating titles. Renown already has a job — buying cosmetics
(`RENOWN_PRICE_CHROMA` 60 / `ELITE` 240 / `MYTHIC` 600). Making points a second
cosmetic currency gives points two jobs and cosmetics two currencies, which is
the "each faucet one job" rule broken twice in one change.

**Do this instead:** the lore threshold grants a small Renown award. One
constant, one line in `note_kill`, zero new machinery, and it lands in the
wallet the cosmetics store already reads.

**The real gap this fills.** Every Renown faucet today is an *achievement*
faucet — weekly challenge (30), vault (20), tier first clear (25), Crucible PB
(3/boss), Depths PB (2/depth), Waking (25). There is **no faucet that rewards
exploration or completion**. A player who reads the world rather than races it
earns nothing. Codex completion is precisely that missing faucet.

Proposed knobs: `RENOWN_LORE_UNEARTH` (small, per kind) plus a larger
`RENOWN_CODEX_CHAPTER` for completing a chapter's bestiary.

---

## 5. Minigames — the pachinko inversion

**Owner's read, and it's the right one:** pachinko looks predatory until you
notice what it actually sells — *a moment of play with a payout*. Strip the
purchase and the moment still works.

- **Anchor:** an NPC or artifact in Crownfall (the capital is already the town
  — quests, favor, way-gates).
- **Pays Renown, daily-capped.** Keeps it entirely off the power ladder. Renown
  is already the cosmetics wallet, so this is the same faucet's same job, not a
  new one. It must never pay gold or gear, or it becomes a farm.
- **Candidates that fit the fiction:** a lapidary gem-cutting cut-and-score
  (the capital already has a lapidary quest); a bell-vigil rhythm test at a
  Warden's watch; a Warden's dice game with a favor stake.

Scope guard: **one** minigame, one NPC, before deciding whether the pattern
earns a second.

---

## 6. The dungeon gate — gate the **bank**, never the **door**

**Owner:** souls made him think a gate mechanism for the dungeon system is
worth determining.

**What SvZ2 does, and why not to copy it.** Souls are the raid entry fee
(`soulsToAttack`) and they regenerate on a real-time clock (`DecaySchema`,
`minutesPerTick = 0.8`) with paid fast-forward. That is an energy gate: it
stops you playing and sells you the right to continue. It fails
*never-freeze-the-frontier* outright.

**The Vigils already solve this correctly** — `DAILY_DUNGEONS.md` §6 puts the
limit on the **daily bank**, not the door. Worth promoting to a stated standing
rule, because it is the exact line the Toll (§2) and stake bands (§3) could
each accidentally cross:

> **The door is always open. The bank pays once.** Repetition is never blocked;
> only the *reward* is rate-limited. No mechanic may consume a resource to
> permit entry.

**If a key-like object is ever wanted**, invert it: a **Seal Key** is a reward
*multiplier* consumable, earned in play, never timed. Holding none costs you
nothing but the bonus. That keeps the frontier open and the object desirable.

---

## 7. Currency hygiene — you already have the dual currency

**Owner:** intends dual currency — a premium one that's harder to get, tied to
special rewards and events, never sold for money.

**That is Renown, and it already exists and is already clean.** Two wallets, no
more:

- `player.gold` — per character. **Power:** shop, crafting, reforge.
- `_meta["renown"]` — account-wide. **Identity:** chroma, elite/mythic skins.

(Gold Rush / `goldrush_time` is run state, not a wallet.) So the thing to guard
is not *adding* the premium currency — it's not accidentally growing a third,
and not letting the two existing ones bleed into each other.

**One crack already open, flagging it honestly:** `RENOWN_CACHE_PRICE` (25)
buys `RENOWN_CACHE_ITEMS` — `elixir_might`, `elixir_ward`, `renewal_draught`.
Those are power, however small. The identity wallet already has a toe on the
power track. Consumables are the mildest possible version and this is not a
crisis — but it is the exact seam that, widened, becomes the SvZ2 trap below.

**The trap, named so it can be checked against.** SvZ2's `SoulJar` upgrade
costs 5,000 **coins** for level 1, then 12 / 20 / 40 **gems** for levels 2–4. A
single ladder opens in soft currency and silently converts to hard currency
partway up, so the player is committed before they discover they can't climb it
by playing. It never looks predatory; it looks like a normal upgrade tree.

> **Rule to adopt:** no single upgrade or progression track may charge both
> wallets. Gold buys power; Renown buys identity. A track that needs both is a
> track that has been mispriced.

---

## 8. Dropped, and what to build first

**Async PvP — dropped (owner call).** Defense-snapshot raiding is the natural
answer to "PvP without a server," but the owner intends Crownless to hinge on
skill, and an AI-driven raid on a static loadout tests neither player's hands.
Not pursued.

*Salvage worth one line:* the same snapshot tech, pointed at yourself, gives
**ghost races** — your best Crucible run replayed as a pace target. Pure skill,
no netcode, no opponent. Parked, not proposed.

### Build order, if these advance

1. **Second Shape** (§1) — highest felt-value per line of code; the death hook
   already exists and three siblings already ship.
2. **Codex → Renown** (§4) — one constant and one line; fills a real faucet gap.
3. **The Toll + its two ladders** (§2) — the biggest design win, but it needs
   the PB-flag decision settled *before* implementation, not after.
4. **Stake bands** (§3) — worth doing before the Vigils install, so the day
   modifier is born reading the shared table instead of private constants.

§5–§7 are smaller or are guard rails rather than features.
