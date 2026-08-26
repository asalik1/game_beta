# Mob Variety — new archetypes, and the free wins first (2026-08-22)

Decision document. Nothing installed. Grounded in the mob-mechanics map of
`enemy.gd` (2026-08-22). Owner note: mobs lack variety (in looks AND behavior).
Seeds given: mounted mobs (a skeleton knight), flying mobs, a dragon boss, "and
more."

Sibling docs (referenced, not repeated): `ACT2_BOSS_KITS.md` (13 per-chapter mob
verbs already specced — empowered/sentry/mimic/burrow/banner/zealot/parasite/
phase_shift/etc.), `DYNAMIC_WORLD.md`, `COMBAT_LANES.md` (§7 pack-composition).
Art pipelines: the top-down mob recolor + Pixel Crawler + Codex mob lanes.

---

## 0. The gap, measured

- **Every regular mob is a GROUND-BOUND walker or kiter.** The trait vocabulary
  is ~25 verbs (melee, ranged, skirmish, pounce, blinker, spawner, channel_heal,
  martyr, bloat, counter, reflect, web, snare, frost_aura, sower, tether,
  frenzy, swift...) and **not one is fly, mount, aerial, or burrow** (burrow is
  boss-only, Sexton). `enemy.gd:196` (TRAIT_DESC), `enemy.gd:287` (traits set).
- **A mob is a DATA ROW; a new BEHAVIOR is code.** Adding a row that reuses
  existing traits is free; a genuinely new archetype = a branch in `enemy.gd`
  (`_think`/`_tick_traits`/`take_damage`/`die`) + a `TRAIT_DESC` entry + a
  `MOB_*` balance knob. So new movement archetypes are cheap-ish in code but
  need ART.
- **~20 placeholder mobs already exist** (`pc_extra_mobs.gd`, `"placeholder":
  true`) and are NEVER spawned — variety sitting on the shelf.
- **crit / DEX / penetration are dormant on mobs** (rows leave them 0), so mob
  hits never crit and no mob makes DEX matter.

So "lack of variety" is two problems: too few LOOKS (art + an unplaced roster)
and too few MOVEMENT/BEHAVIOR archetypes (everything walks). Both below.

---

## 0.5 Fairness cuts both ways (owner ruling 2026-08-23)

Melee is already the handicapped, kiteable class: it eats the risk of closing
distance and cannot fight from safety. So **no mob or boss may be un-hittable by
a whole class's toolkit.** This is the mirror of the standing kiter-floor rule
(every boss must land non-opt-in damage on a ranged kiter, `boss-design-
principles`): the melee-reach ceiling says every enemy must be reachable by
melee without a hard gate on that toolkit.

- **BANNED:** sustained "melee-immune while airborne / ranged-only" states. They
  double-tax the class that is already disadvantaged.
- **ALLOWED:** brief, class-AGNOSTIC untargetable frames during a reposition
  (the blinker frame, equal for everyone); movement that is hard to pin; and
  hazard-immunity (which costs the KITER their hazard-lure, not the meleer their
  damage).

Flight, burrow, and blink all express as MOVEMENT and TIMING, never as a
one-class damage gate.

**The OTHER half (owner ruling 2026-08-23): mobs must punish kiters too.** The
kiter-floor is a standing rule for BOSSES; MOBS have no equivalent, so a ranged
player farms packs risk-free by backpedaling — free safety, which violates the
safety→skill rule. Mobs must impose non-opt-in pressure on a kiter, but WITHOUT
double-taxing melee (the ceiling above). The reconciling trick: **range-GATE the
anti-kite tools** so they fire when the player is FAR or retreating, which
targets the kiter specifically and leaves the in-melee player alone. Note the
inversion — for a boss, `if dist < X` is the opt-in anti-pattern a kiter dodges;
for a kiter-punish, **`if dist > X` is CORRECT**, because it reaches the person
who opted out of melee. Deliver it at the PACK level (§3.5), not per-mob (a
single mob strong enough to punish a kiter is oppressive to a meleer).

---

## 1. Free variety first (zero or near-zero art)

Do these before authoring anything new — they are the cheapest variety per
minute:
- **Place the ~20 unplaced placeholder mobs** into spawn tables. Instant look
  variety, zero new art or code (they exist and are rated, just roster-only).
- **Recombine existing traits into new rows.** A "reaver" = pounce + frenzy; a
  "hexer" = ranged + snare; a "warden" = counter + martyr; a "packlord" =
  spawner + a buff. New identities from the shipped vocabulary, data only.
- **Reactivate dormant knobs.** Give a few mobs real crit, or a DEX/evasion
  identity (the "only-dodgeable, high-accuracy" mob) so those stats finally
  matter. Data only (mind the free-crit-earned rule for the player side).

---

## 2. New MOVEMENT archetypes (the real gap)

### 2a. Mounted mobs (owner: skeleton knight) — the two-stage mob
The mount is a fast, committed CHARGE platform; the mechanic that makes it feel
different from "a fast mob" is the DISMOUNT. On the mount's death the RIDER is
thrown clear and continues as a slower melee mob (a sprite swap + dropping the
cavalry trait — the same shape as Kaethra's `form_stage` boss swap, applied to a
mob). You can kill the mount OR the rider first, and each reads differently.
- **Kit:** a `cavalry` trait = a telegraphed high-speed charge along a
  wall-cleared lane (reuse the boss `_do_charge` lane-clear, `boss.gd:504-554`),
  overshoot on a whiff (the pounce punish window). Dismount = swap to the
  on-foot sprite + drop `cavalry`.
- **Variants:** skeleton knight on a skeletal horse (undead), boar-reaver
  (wildfang), storm-lancer (storm terrain).
- **Cost:** medium code (the two-stage swap) + composite rider/mount art.

### 2b. Flying mobs — always hittable, never a melee lockout
Flight is expressed as MOVEMENT and hazard-immunity, NOT as damage immunity (the
fairness rule, §0.5). Two flavors:
- **Hover-flyer (cheap):** visually hovers (reuse the boss `hover_amp`,
  `enemy.gd:134`) and is immune to your ground hazards and terrain slows (it
  flies over lava, so kiting it into your hazard zones stops working). Moves
  erratically/fast so it is hard to pin. Fully melee- AND ranged-targetable.
  Wisp, carrion bird, mote.
- **Diver (medium) — the archetype the roster is missing:** spends its time
  swooping in and out on a telegraphed dive-and-climb, harassing from angles a
  ground mob cannot. The dive IS its attack AND its exposure — it is always
  hittable, and the climb is at most a brief, class-AGNOSTIC untargetable
  reposition (the blinker frame every class already handles, `enemy.gd:1607`),
  never a sustained melee-only immunity. Melee fights it on the dive; ranged
  tags it between. Harpy, gargoyle, stirge. **Cost:** medium code + winged art.

### 2c. Burrower (the trash version of Sexton)
Submerge (untargetable), reposition, surface with an eruption tell. Ports the
boss burrow tech (untargetable + collision off + invisible) down to a trait.
Sandworm, mole, root-lurker. **Cost:** low-medium (the boss code already exists).

### 2d. Sapper / exploder-runner
RUNS at you and detonates on a short telegraph — punishes melee clumping and
turtling. The agent audit found **no suicide-runner exists** today (only `bloat`,
a death-trigger poison pool). Reuse `bloat` + a charge. **Cost:** low.

---

## 3. New TACTICAL archetypes (change the fight, not just the movement)

- **Flank pack** — members approach the SIDES, one bays to pin you head-on while
  the rest circle. Reuses `pack_id` aggro (`game_world.gd:1236`). Ties to
  `COMBAT_LANES.md` §7 pack-composition puzzles.
- **Siege / artillery** — stationary, lobs slow arcing AOE across the whole
  room; you close distance or break LOS. Reuses the sentry/turret idea + a
  telegraph. Ballista-skeleton, bombard.
- **Commander / standard-bearer** — buffs its pack, kill-priority. This is the
  ACT2 `banner`/`commanding` verb, promoted to a campaign mob.
- **Mimic** — a disguised prop that ambushes at melee range. The ACT2 ch9
  `mimic` verb (and it dovetails with the DYNAMIC_WORLD false-room idea).

---

## 3.5 Kiter pressure — the mob-pack floor (owner ruling 2026-08-23)

The complement of §0.5's melee-reach ceiling: mobs must reach a KITER. Today a
ranged player backpedals a pack for free (melee mobs never catch up, ranged
bolts are dodgeable, pounce overshoots, blinker is rare). The fix is pack
composition plus a few range-gated tools, so kiting becomes positioning skill,
not a free-safety button. Every tool below is range-gated (fires on the far /
retreating player) so it never touches the in-melee player:

- **A gap-closer that actually lands** — a hound that pounces to your PREDICTED
  spot (lead the target, not your current position), or a blinker that appears
  on your retreat side. The goal is not to catch you; it is to deny free
  backpedaling.
- **Zoning lobber** — drops a hazard/root patch WHERE you are retreating (reuse
  `sower` / `snare`), so backing into a corner or your own hazard field costs
  you. Punishes thoughtless kiting, not kiting itself.
- **Aimed / fast ranged** — a mob whose shot leads the target or flies fast, so
  a lazy straight-line backpedal eats it. Slow bolts are free to dodge.
- **Flankers** — a pack that splits to your sides (reuse `pack_id`), so
  retreating in a straight line runs you into the cut-off.
- **The far-gate zoner** — a mob that fires a long-range attack ONLY when you
  are beyond melee range (`if dist > X`). The literal mob kiter-floor, and it is
  FAIR because it never touches the player who is in the fight.

**Tuning first.** Audit current pack ranged / gap-closer density before adding
tools — the fix may be composition, not new mobs (an econ_audit-style pass on
what a kiter actually faces). Keep it fair (§0.5): the punish reaches the kiter,
never the meleer.

---

## 4. Elemental / terrain-native mobs

Per-domain elementals that USE the terrain they live in, mostly by recombining
shipped traits (variety with little new code):
- **Magma** — leaves a lava trail (reuse `sower`).
- **Frost** — freezes the ground it stands on + chills nearby (reuse `snare` +
  `frost_aura`).
- **Storm** — chains lightning between nearby mobs (a `tether`-style bond as
  offense).
This is strong for Act 2's blended terrains (the corruption merging IS the
story) and cheap because the verbs exist.

---

## 5. The dragon (and other BIG bosses)

The marquee ask, and the roster's clear ceiling: current bosses top out at
humanoid/beast scale (even the "colossal" nullwarden is ~547px). A dragon is the
first true SPECTACLE boss. It is a bespoke boss (`boss.gd` `match kind`) but
reuses a lot:
- **Breath cone** — reuse Cinderhide `_vent_breath` (cone hazard laydown,
  `boss.gd:1709`).
- **Slam / wing-buffet** — the shockwave-ring slam + a knockback on landing.
- **Flight** — the `hover` render, and the SIGNATURE: SHORT, telegraphed
  swoop-runs (melee-hittable as it strafes the ground) plus a brief fire-rain
  beat everyone survives, NOT a sustained melee-dead sky (fairness rule, §0.5).
  The ground ballistae are a shared spectacle tool, not a melee requirement.
  Baiting or forcing the landing = the `COMBAT_LANES.md` §3 interrupt beat; the
  ACT2 ch13 anchor-defend frame supplies the survive-the-beat rhythm.
- **Adds** — drakelings between breaths (the summon primitive).

Other "big" candidates in the same reuse-heavy vein: a kraken/tentacle
multi-target boss (the Heart-of-the-Root 5-bar frame), a leviathan, a colossus.
**Cost:** boss-tier (bespoke kit + large art), but low RISK because every beat
reuses an existing primitive.

---

## 6. Cost table, build order, open questions

| Archetype | Reuses | New code | Art |
|---|---|---|---|
| Place placeholder mobs | everything | none | none (exists) |
| Recombined trait rows | traits | none | none/reskin |
| Mounted (2-stage) | `_do_charge`, form-swap | medium | composite rider+mount |
| Hover-flyer | `hover_amp`, hazard flag | low | winged/hover sprite |
| Diver (flying) | telegraphed dive + brief blinker frame | medium | winged sprite |
| Burrower | Sexton burrow | low-med | surface/dive frames |
| Sapper | `bloat` + charge | low | reskin + telegraph |
| Flank pack | `pack_id` | low-med | none/reskin |
| Siege/artillery | sentry + telegraph | low-med | stationary sprite |
| Elemental (per domain) | sower/snare/frost_aura/tether | low | element sprites |
| Kiter-punish pack tools (§3.5) | pounce/blinker/sower/snare/pack_id, range-gated | low-med | reskin |
| Dragon (+big bosses) | cone/slam/hover/adds/anchor frame | boss-tier | large boss sheet |

**Build order (cheapest reach first):**
1. Free wins (§1) — place the shelf roster + a few recombined rows. Immediate.
2. ONE movement archetype as the proof — **mounted** (owner-named, most
   evocative) or **the diver** (a flyer that dives in and out, variety without
   taxing melee, §0.5). Pick one, ship it, learn from it.
3. The remaining movement/tactical archetypes as art allows.
4. The dragon as the marquee spectacle boss.

**Open questions (owner):**
1. **Art budget / lane** — mob variety is as much an ART problem as a code one
   (mounted = composite art, flying = winged sheets, dragon = a large boss
   sheet). Codex lane, and at what volume?
2. **First archetype** — mounted (the named seed) or the diver flyer?
3. **Flying depth** — is the hover-flyer (hazard-immune, erratic) enough for v1,
   or is the diver's dive-and-climb worth the extra code? Neither is
   melee-immune (§0.5).
4. **Dragon scope** — a one-off marquee, or the first of a "big boss" tier
   (kraken, leviathan, colossus)?

> Thesis: the roster is deep in stats and shallow in silhouettes — everything
> walks. The cheapest variety is already on the shelf (unplaced mobs, recombined
> traits); the real growth is one new axis of MOVEMENT (something that rides,
> something that flies), and the payoff at the top of that axis is a dragon that
> makes you look up.
