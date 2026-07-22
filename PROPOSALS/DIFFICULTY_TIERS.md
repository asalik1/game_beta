# Difficulty Tiers — design investigation (2026-07-21)

Expands DESIGN.md's one-line sketch ("Normal / Nightmare (+20 levels) / Torment
(+40), loot-grade floors rising per tier") into a composition-checked design.
Build-order step 2, "the next cheap multiplier." Everything here is proposal;
DESIGN.md absorbs only what survives the owner's read.

## Why tiers, and why the design must be exactly this shape

The MT4 lesson: the deadliest retention failure was **freezing the frontier** —
the L40 wall today is a mini cap-freeze (nothing past L40 grants XP until Act 2;
gear tops at A; a capped character has no gradient to climb). Tiers are the fix
that costs nearly nothing, because every hard part is already built:

- Level scaling to 100 exists and holds parity at any level (`GROWTH_SCALE`
  0.55 — whose own comment already sizes the tiers: "+10 ≈ 2× dmg; **+20
  Nightmare = ~3× = brutal**", balance.gd:189-197).
- No-downscaling is law, so revisited content scales UP for free.
- Replay is a first-class flow (`replay_chapter`, game_flow.gd:59 — fresh seed,
  no XP, standings reset). A tier run IS a replay with a modifier.
- The weekly challenge already proves the whole "run-scoped modifier" pattern
  end to end: applied at spawn/drop seams (`weekly_fx`), briefed to guests on
  join (MP-15, net_session.gd:372), PB'd in meta. Tiers ride the same rails.

## The design

**Three tiers, account-unlocked, chosen per run at chapter select.**

| Tier | Level offset | Loot table read as | Elite pressure | Unlock |
|---|---|---|---|---|
| Normal | +0 | `chN` | ×1.0 | — |
| Nightmare | +20 | `chN+4` | ×1.4, elites may carry a 2nd affix | clear the Act 1 finale (same flag family as `endgame_unlocked`) |
| Torment | +40 | `chN+8` | ×1.8, elite packs may promote two | clear the Act 1 finale ON Nightmare |

All numbers are `Balance.TIER_*` knobs (`TIER_LEVEL_OFFSET := [0, 20, 40]`,
`TIER_LOOT_SHIFT := [0, 4, 8]`, `TIER_ELITE_MULT := [1.0, 1.4, 1.8]`) — no
inline tuning numbers, per §38f.

### The frontier gradient (the actual point)

At the L40 Act-1 cap, Nightmare turns the seven chapters into a *ladder* again
instead of a flat farm. Chapter anchors ~L1-5 (ch1) → ~L36-41 (ch7):

| Content | Nightmare level | vs a L40 player |
|---|---|---|
| NM ch1-3 | ~L21-38 | comfortable farm — pays like ch5-7 |
| NM ch4-5 | ~L42-50 | the working frontier (+2..+10 — "2 mistakes" territory) |
| NM ch6-7 | ~L52-61 | the aspirational wall (+12..+21 — gear/gem/skill checks) |
| Torment | ~L41-81 | opens meaningfully only as Act 2 raises the cap |

That's the MT4 antidote in one table: **there is always a next fight that
out-levels you by a little and one that out-levels you by a lot**, without a
single new room authored. Torment being mostly unreachable pre-Act-2 is a
feature — it's the standing promise that the ladder continues, and it ships
already-tuned content for the Act 2/3 level bands (the ×2-3 hour multiplier
DESIGN.md budgeted).

### Loot: shift the chapter pointer, don't invent tables

`CHAPTER_GEAR_WEIGHTS`/`CHAPTER_BOSS_WEIGHTS` are keyed `ch1..ch11` with a
`RICHEST_CH` fallback (balance.gd:284-318). A tier run of `chN` reads the table
for `ch(N + TIER_LOOT_SHIFT[tier])`, clamped to the richest authored key.
Consequences, all free:

- NM ch1 pays like ch5 (C/D band) — replaying the graveyard at 40 is worth it.
- The gem-quality curve needs NOTHING: `gem_lv2_chance` keys off content
  LEVEL, so +20-level spawns pay better gems automatically. Same for boss gem
  ramps (`BOSS_GEM_*` rides `enemy_stats_at`).
- Gold needs NOTHING: rewards are linear per level; higher-level kills out-pay
  by the existing curve, keeping "the frontier always out-pays" true.

**The one real content decision:** S-grade lives in `ch12+` tables that are
"set when built." With shift +8, Torment ch4+ would read ch12+ — i.e. **Torment
is the natural S-gear faucet** ("S is comfort + tier headroom" — the doctrine
line was already pointing here). Either author the ch12+ band table when
Torment ships (one dict; recommended), or clamp Torment at ch11 (A-band) and
keep S exclusive to Act 3 chapters. Owner's call; recommendation: author it —
Torment ch6-7 at L76-81 is *earned* S territory, and an S-drop event is exactly
the carrot that tier deserves. (Torment ships alongside/after Act 2 anyway —
Normal+Nightmare alone are the v1.)

### XP: tiers pay zero, permanently

Replays already pay no XP, and tiers are replays. Keep it absolute — even after
Act 2 raises the cap. The faucet doctrine ("XP = story currency; the story
can't be farmed and farming can't outlevel the story") only survives tiers if
tier kills never grant XP; the moment NM ch1 pays XP, it becomes the optimal
way to skip Act 2's opening chapters. Tiers pay in gold, gear band, gem
quality, and first-clears — the farm currencies. (If Mastery ever needs a
non-story trickle, that's a separate faucet decision to take deliberately, not
a default.)

### First-clear per tier

First-clear is "the event" faucet. Each chapter's first clear AT EACH TIER pays
the first-clear beat once (banner + `FIRST_CLEAR_GOLD` at the tier's level mult
+ mailed spoils rolled from the TIER-shifted band). 21 chapters' worth of
one-time events become 63 without becoming farmable. Keys extend the existing
flags: `first_clear_<ch>` → `first_clear_<ch>_nm` / `_t`.

### Records

Per-tier PBs: `pb_<ch>_<cls>` → `pb_<ch>_<cls>_nm` / `_t` (existing key shape,
game_flow.gd:211). Results card shows the tier beside the chapter name; codex
Records tab grows a tier column. Ladder-first: a NM ch7 time is a different
brag than a Normal one and must never overwrite it.

## Composition matrix (checked against the code, not vibes)

| System | Interaction | Verdict |
|---|---|---|
| **Enemy scaling** | offset applies where spawn level resolves (spec level / `ALL_ENEMIES` fallback, game_world.gd:582), THROUGH `enemy_stats_at` — codex stays honest, no hidden multipliers | one seam, same shape as party scaling + weekly_fx (game_world.gd:1806-1815) |
| **Elites/affixes** | density × `TIER_ELITE_MULT` at the two existing `weekly_fx("elite")` sites | "double-feeds tiers" was the affix pool's design intent |
| **Weekly challenge** | weekly stays **Normal-only** in v1 — one comparable ladder; `weekly_active` and tier>0 are mutually exclusive at start | revisit if the weekly ever wants a "NM week" |
| **Endgame arenas** | orthogonal. Crucible/Depths have their own controllers and ramps; tier applies to CAMPAIGN runs only. `enter_endgame` ignores tier | no coupling in v1 |
| **Co-op** | tier is HOST-authoritative world state: picked by host at chapter select (guests see it, can't set it), briefed on join exactly like the weekly mod (MP-15 pattern), carried in the join snapshot beside `boss_done`. Cross-product rule: the tier picker UI must gate on `net_host()`, not merely on being online | the audit's lesson pre-applied |
| **Save format** | `world_tier` rides the world save beside `chapter_id`/`wander_seed`; `tiers_unlocked` + per-tier PBs in meta.json. Old saves read tier 0 — no migration | additive, backward-safe |
| **Mastery/keystones (Act 2)** | tiers are where 60-point Mastery builds get *proven* — NM/T ch6-7 are the natural keystone benchmark fights. No mechanical coupling needed now | design synergy, zero code |
| **Resonance** | leans apply as-is (they scale with |resonance|, not content) | none needed |
| **Dedicated server (MMO)** | tier is world state on the authority; `write_server_world` persists it like everything else. A future server just hosts N worlds at N tiers | migration-safe by construction |
| **Mobile** | pure re-sync, no deltas | — |
| **Potions/sustain** | `potion_slots` act-2/3 bands (4/5) are latent; NM ch5-7 at L52-61 is act-2-band content — tie the slot band to EFFECTIVE level (chapter + offset), not chapter id | one-line decision, flagging it |

## MT4 antipattern audit

- **Never sell power:** tiers are gated by clears only. Nothing about them is
  purchasable, and nothing should ever be.
- **Never freeze the frontier:** the ladder above the cap (NM wall → Torment →
  Act 2 raises the cap → Torment matures → Act 3) means the frontier moves at
  every stage of the roadmap, including the gaps between acts.
- **Legibility (the named blind spot):** the tier card at chapter select states
  its effects in plain numbers — "+20 enemy levels · loot from 4 chapters ahead
  · elites 40% denser" — the same no-silent-effects rule the balance feedback
  memory enforces. No hidden modifiers, no cryptic skull icons.

## Implementation sketch (when greenlit — deliberately not started)

1. `balance.gd`: `TIER_*` tables + `tier_name()`; `gear_weights`/`boss_weights`
   grow a tier-aware lookup (`effective_chapter`).
2. `game_base.gd`: `var world_tier := 0`; save/load + join-snapshot line.
3. Spawn seam: offset at the game_world.gd:582 level resolution (+ boss spawn
   path); elite sites multiply by `TIER_ELITE_MULT`.
4. `menus.gd` chapter select: tier row (locked tiers greyed with the unlock
   hint), host-only in-session; results card + Records tier column.
5. `game_flow.gd`: per-tier first-clear flags + PB keys.
6. Tests: autotest section (offset applied, loot shift, zero XP, save
   roundtrip, tier-0 legacy load), net_test brief/snapshot coverage, and an
   `econ_audit --tier` + `dps_bench` NM preset BEFORE the tuning pass — sim the
   L40/A-gear player against NM ch4-7 so the wall lands where intended
   (the +12..+21 band), not somewhere accidental.

Order: Normal+Nightmare first (v1); Torment + the ch12 S-band question ship
with/after Act 2.

## Owner decisions (recommendation attached, nothing blocked)

1. **Torment's S-band**: author the ch12+ table for Torment (recommended) vs
   clamp at ch11 and reserve S for Act 3.
2. **Weekly × tier**: Normal-only v1 (recommended) vs per-tier weekly ladders.
3. **Potion slots**: keyed to effective level (recommended) vs chapter id.
4. **Names/flavor**: Normal/Nightmare/Torment are working names; Crownless
   flavor (e.g. the Hollow King's memory deepening) can reskin them any time —
   pure presentation.
5. **Tier XP = zero forever** (recommended, argued above) — confirm so it can
   graduate to DESIGN.md as doctrine.
