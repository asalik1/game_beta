# Special Abilities — two branches, two slots (v1 spec)

**Status: proposal — system agreed with owner 2026-08-04 (design calls
1–6 below are RULINGS, not open questions). Nothing installed.**

Origin: the Knell discussion in `RESONANCE_ACT1_DIALOGUE.md` §9.3,
generalized by the owner from the MT4 precedent — MT4 gave every class
two special-ability slots fed by leveling (e.g. assassin's *Shadow
Clone*: decoy + stealth dash, 45s; *Ghost*: move-speed burst, 60s).
Utility on long cooldowns; a dimension, not a number. This doc keeps
that shape and splits the feed into two branches so that **by endgame,
your specials are partly what you are (class) and partly what you did
(story)** — the kit becomes the story's mechanical memory.

Lives in the **shared combat core**; ships with HEARTH first. Explicitly
NOT in Crownless's shot-1 launch (scope discipline, portfolio doc §9);
Crownless adopts it post-launch as a content update.

---

## 1. Rulings (owner-agreed 2026-08-04)

1. **Two slots, hard-mapped to the branches.** Left slot = leveling
   branch, right slot = story branch. They never compete for a slot —
   this is what guarantees the story is present in every endgame kit
   and keeps the system legible: two buttons, two stories.
2. **Leveling branch = class-specific; story branch = class-agnostic.**
   Leveling specials express the class; story specials express the deed
   (the bell doesn't care what class drank it). Caps authoring; keeps
   the cross-stream comparison legible ("he took the bell too, on a
   mage").
3. **Story specials key to CHOICES, not band.** Permanent once earned —
   deeds don't fluctuate. Pocket exception (rare, deliberate): a
   pole-band special that deactivates if you leave the pole
   (must-maintain pressure; same design language as the Crownless
   keystone plan). Default is choice-keyed.
4. **Cadence: every 20 levels; fixed ability per threshold in v1**
   (choose-from-a-pool is a v2 upgrade, not v1 — legibility budget is
   spent). HEARTH cap: **~L40 working assumption** (accepted
   2026-08-04; cheap to change until the XP-curve doc) → leveling
   unlocks at **L20 and L40** = 2 per class, 12 authored abilities.
   Each branch introduces its own slot with its first unlock: the
   leveling slot at L20; the story slot at the Sunken Bell — the
   system debuts at the Act 1 climax.
5. **Earned, never sold — ever.** When Crownless mobile F2P sells class
   expansions, a new class's kit is fine; specials never appear in any
   store, any platform. (MT4 postmortem rule, pinned here so it can't
   drift.)
6. **PvP: specials are FREE in duels.** Owner ruling: the Proving
   Grounds is experimental — if a special is duel-defining, so be it.
   No barring, no separate tuning pass for now; revisit only if PvP
   ever gains stakes.

**Shape constraints (all abilities, both branches):** utility, not
damage — zero or trivial damage numbers, so the DPS bench stays
untouched (verify neutrality with the existing `dps_bench` presets).
Long cooldowns (30–90s). Visible cooldown on the slot button — the
no-silent-effects rule applies. Tuning knobs live in `balance.gd` as
`SPECIAL_*` per CLAUDE.md.

**What specials do NOT attach to:** interpersonal pivots. The Jorin
choice grants nothing mechanical by design — attaching a toy to a
cruelty would put wiki-optimal loot pressure on the game's drama
choices. Specials attach only to beats authored as POWER moments (the
bell). Power choices and drama choices stay separate instruments.

---

## 2. Leveling branch — the 12 (HEARTH v1)

All class-specific, fixed per threshold. Names are working. Format:
**Name** (threshold, cooldown) — effect / the dimension it adds.

| Class | L20 | L40 |
|---|---|---|
| **Warrior** | **Juggernaut** (45s): 3s of stagger/knockback immunity; walk through bodies, shoving enemies aside. The unstoppable-force button — reposition THROUGH the pack instead of around it. | **Last Stand** (90s): 3s where HP cannot drop below 1. The blackout made loyal — melee risk-comp as a planned decision, not a death. |
| **Archer** | **Disengage** (40s): backward vault + slow/root immunity for 2s. The distance-keeper's answer to being cornered. | **Hawk's Eye** (60s): 10s — elites, secrets and unentered exits pulse on the minimap. Exploration utility; feeds the hidden-cache economy. |
| **Mage** | **Blink** (35s): short teleport to cursor. The classic; precise repositioning as identity. | **Suspension** (60s): enemy projectiles in a radius hang mid-air for 2s, then drop dead. Precision as area denial — walk through the frozen volley. |
| **Assassin** | **Shade** (45s): leave a mimicking decoy, go unseen, short dash. *The MT4 homage, verbatim on the class that had it.* Enemies waste key abilities on the clone. | **Ghost** (60s): large move-speed burst, short duration. *The second MT4 homage.* Speed as escape OR as the engage nobody expected. |
| **Paladin** | **Aegis** (60s): 4s projected dome — enemy projectiles break on it, allies' pass through. The shield made spatial. | **Sanctuary** (75s): consecrate ground for 4s; enemies cannot enter the circle. A verdict about territory — carve the safe ground yourself. |
| **Warlock** | **Borrowed Time** (45s): damage taken in the next 4s is delayed, then paid as one lump — *with 10% interest*. The debt identity as a defensive gamble. | **The Advance** (75s): reset class-kit cooldowns; pay 25% current HP. One more borrow; it's only sensible. |

Design notes: Warlock's pair is the identity showcase (both are debt
instruments). Assassin's pair is the deliberate MT4 double-homage.
Every ability has counterplay or cost — nothing here is a free stat
(the free-crit rule generalized).

---

## 3. Story branch — HEARTH's schedule

The three lanes reach specials on **different schedules** — this is the
different-currencies argument matured: tempted pays power NOW, steady
pays power through STANDING, balanced pays power through FUTURES.

- **Act 1, tempted — KNELL** (the flagship, `a1_bell_taken`): bell-toll
  AoE stagger, 60s. Story slot unlocks with it. At ink bands the toll
  sounds faintly in your footsteps town-wide (the cost is ambience, not
  numbers). *The "story rewrote my kit" clip.*
- **Act 2, steady — seed:** the Warden line (deputy stave / ward
  standing) matures into a protective special. Named and designed in
  the Act 2 doc; earned via the standing thread, not a single scene.
- **Act 3, balanced — seed:** the bound bell is a load-bearing IOU
  (`a1_bell_bound`). When it rings again, whoever bound it may claim
  what breaking OR taking would have given — a late, larger payoff
  for the lane that deferred. Designed in the Act 3 doc.
- Target across the game: **~5–8 story specials** (matches the
  portfolio doc's pivot budget), more than one per lane by the end, so
  endgame loadouts visibly diverge by path taken.
- **Codex (door-not-room):** unearned story specials show as sealed
  entries — name, silhouette, and the pearl where the door was; never
  the mechanics. A locked toy is the strongest replay driver we have.

---

## 4. Integration notes (build-time)

- **HUD:** two new slot buttons with visible cooldown sweeps; mobile
  touch HUD gains the same two — and per the co-op-pause trap
  (CLAUDE.md), their input gates on OVERLAY STATE (`menus.is_open()` /
  `hud.dialogue_active`), not on pause or `ST_PLAYING`.
- **Save shape:** unlocked sets + equipped story pick persist on the
  player object (survives solo→co-op, same as resonance). Story-slot
  swap UI only matters once a second story special exists (Act 2+);
  v1 can hard-equip Knell.
- **Co-op/net:** host-authoritative like all abilities; landing this is
  a `NET_VERSION` bump.
- **Autotest:** content-module test hook pattern — unlock-at-threshold,
  choice-grants-Knell, bench-neutrality (dps within tolerance with
  specials used on cooldown), and the §9.6 delta-walk from the Act 1
  doc extended to assert Knell's grant fires only on `a1_bell_taken`.
- **Codex:** specials get a codex tab section (player-facing reference
  rule from CLAUDE.md — update in the same change that lands them).

## 5. Open

- The 12 names/numbers above are working values — red-pen by taste;
  cooldowns tune in `balance.gd` after a play pass.
- HEARTH level cap confirmation when the XP-curve doc exists (rulings
  hold at any cap; thresholds are `every 20`).
- Act 2/3 story specials designed in their act docs, not here.
