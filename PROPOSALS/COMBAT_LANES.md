# Combat Lanes — mechanics the Act 2 design set doesn't reach (2026-08-21)

A decision document. Nothing here is installed and no game files were touched.
These are combat-mechanic lanes discovered by auditing the LIVE engine
(`boss.gd`, `enemy.gd`, `game_base.gd` telegraph engines) against the existing
Act 2 design docs, then looking for territory neither one covers. Each lane
names the engine SEAM it exploits (with file refs), the design, an engine spec,
a build-cost read, and its theme fit. Magnitudes are placeholders; the
dps-bench phase owns numbers and every value lands as a `balance.gd` knob (§38).

Companion to: `ACT2_DESIGN.md` (the narrative + chapter bible), `ACT2_BOSS_KITS.md`
(the 21 boss kits + 13 mob verbs already specced), `PVP_BALANCE.md`,
`DIFFICULTY_TIERS.md`.

---

## 0. The three structural facts these lanes exploit

From a full read of the combat engine (2026-08-21):

1. **Mobs are data, bosses are bespoke code.** A mob is a `Story.ENEMIES` row
   whose `traits[]` array is read against a fixed ~25-verb vocabulary
   (`enemy.gd:287-288`, branched all through `_think`/`_tick_traits`); adding a
   mob is a spawn-table line. A boss is a hand-written `_<kind>()` method
   dispatched by `match kind` (`boss.gd:381-423`) — there is NO ability table,
   no cooldown list, no composable verb schema. The per-boss `mechanics[]`
   tell/counter array is INERT: bestiary text the AI never reads
   (`ch3_bosses.gd:23-42`).
2. **Boss counterplay is dodge-only.** All boss attacks resolve through three
   engines — aimed bolt (`boss.gd:67-73`), radial ring (`BOSS_BOLT_RING=300`),
   and ground telegraph (`game_base.gd:2976-3216`). Telegraph damage passes
   `attacker==null`, which SKIPS the evasion roll (`player.gd:949` vs `980`) —
   pure positional dodge, no eva cheese. There is NO interrupt, parry, reflect,
   or cast-punish anywhere; grep confirms it. Player dash grants a timed
   evasion buff, not i-frames, so it does nothing against telegraphs.
3. **Combat debuffs are one-directional.** The player has a rich status kit
   against enemies — burn, toxin, bleed, vuln, res-shred, hobble, crush
   (`enemy.gd:1829-1929`, fields `enemy.gd:137-159`). Enemies can apply to the
   PLAYER only root, freeze, and chill (`player.gd:491-531`). Bosses stay
   CC-immune by covenant. The whole "enemies pressure your kit the way you
   pressure theirs" axis is empty.

Plus dormant seams: no enrage/soft-timer of any kind (a stalling player is
never wiped); the `regen` trait is orphaned (`enemy.gd:1488-1489`, zero users);
~20 placeholder mobs are roster-only, never spawned (`pc_extra_mobs.gd`);
DEX/crit/penetration are effectively unused on mobs (`story.gd` rows leave them
0); Aldric's player-ability ledger (`ACT2_BOSS_KITS.md` §ch11) is a one-off
boss gimmick with no reuse.

## 1. Ground rules every lane honors

- **No-healer covenant** (2026-07-27): no fight assumes a dedicated healer in
  co-op. Sustain checks are per-head; burst checks are dodgeable per-head.
- **Sustain is never taxed** (Depths precedent): healing output is class design,
  not a difficulty dial. Lane 1 below reduces healing as a DODGEABLE debuff the
  player can cleanse or play around — never a flat aura tax.
- **Tiers stay "levels only, no hidden multipliers."**
- **Floor vs ceiling** (`ACT2_BOSS_KITS.md` §1): any new boss pressure must
  reach a KITER; `if dist<X` tells are opt-in, not a floor.
- **CC-immunity conversions**: bosses stay CC-immune. New player-facing CC
  (Rot, silence) applies to the PLAYER from mobs/bosses but the reverse
  (player → boss) still converts to `CONCUSSION_MULT` damage / hobble marks.

---

## 2. Lane A — Enemies get the debuff kit (combat symmetry)

**PICK. Highest untapped axis, theme-perfect, machinery half-exists.**

### The seam
Player-inflicted status is a whole subsystem (`enemy.gd:1829-1929`) that only
runs player → enemy. Enemies can put root/freeze/chill on the player and
nothing else (`player.gd:491-531`). The game already teaches the player that
DoTs, healing-reduction and armor-shred are how you win; enemies never speak
that language back.

### The design
Give the blight/decay faction — and Act 2+ generally — a small, thematically
scoped enemy status vocabulary, mirroring the player's:

- **Rot (headline):** a stacking DoT that ALSO reduces the player's healing
  received per stack (caps at, say, −50% at 5 stacks). This is the exact
  INVERSE of the Act 2 Blight mechanic the player uses on healing bosses
  (`ACT2_DESIGN.md` §VII). Sustain classes must now play AROUND healing denial
  instead of being immune to the concept. Cleansable (dash/tumble strips 1
  stack? a cleanse consumable? owner call) so it stays counterable, never a
  flat tax. Applied by a new mob verb `rot_touch` and by blight hazard pools.
- **Corrode (armor):** temporary phys-res shred on the player — makes the next
  hits hurt more, rewards not eating chip. Mirrors player res-shred.
- **Ember-mark (delayed burst):** a mob paints a mark that detonates after Ns
  unless the player breaks line-of-sight or out-ranges it. A soft repositioning
  demand that reaches a kiter (the mark travels with the player).

### Engine spec
- New PLAYER status fields on `player.gd` beside `frozen_time`/`chill_time`:
  `rot_stacks`/`rot_time`, `corrode_time`, `mark_time` + tick handlers in the
  player per-frame (mirror `apply_chill` refresh pattern, `player.gd:519-531`).
- Heal-reduction reads `rot_stacks` in whatever central heal path the player
  uses (find the single `heal()` chokepoint; if none, add one — needed anyway).
- New mob verbs `rot_touch`/`corrode`/`ember_mark` in `enemy.gd` trait vocab
  (each = a `traits.has()` branch + a `TRAIT_DESC` entry `enemy.gd:196-216`)
  and `MOB_ROT_*` knobs in `balance.gd`.
- Blight hazard pools apply Rot on the existing hazard-tick path
  (`game_flow.gd:2100-2113`).

**Cost:** medium (new player-side status plumbing, but it reuses the chill/root
refresh shape). **Theme:** perfect — "the blight cuts both ways" is the entire
Act 2 thesis made symmetric.

**Open Q:** does Rot apply to bosses' healing too (it's a PLAYER-inflicted
mechanic there) — or is the enemy Rot a distinct player-only debuff that just
shares the name and art? Proposal: distinct debuff, shared visual language.

---

## 3. Lane B — Interrupt windows (the first non-dodge counterplay)

**PICK. Fills the single biggest hole in boss design, cheap, reuses `vuln_time`.**

### The seam
Every boss cast is a dodge check and nothing else. There is no interrupt,
parry, or reflect (§0.2). `vuln_time` — "takes extra damage while marked" —
already exists (`enemy.gd:150,1966`) and is currently used only by Whitepelt
self-stunning into a wall (`boss.gd:2015-2023`).

### The design
Add a "throat" beat to select big casts: while a boss channels a heavy
telegraph, a marked weak point (a glowing zone on the body, or simply "land X
damage during the 2s wind-up") can INTERRUPT the cast — cancelling the nuke AND
opening a `vuln_time` window. This creates the risk decision the game never
asks: dive into melee/burst range to interrupt (high reward, exposes you) vs.
play safe and eat the mechanic (survivable, slower). Ranged classes get a
tighter interrupt window than melee, so it's a real build-expression axis, not
a free "always interrupt."

Not every cast is interruptible — it's a designed beat on 1-2 casts per boss
(the heal channel is the obvious first target: interrupt the heal or out-DPS
it, a classic decision the game currently lacks). Bosses stay CC-immune; this
is a scripted cast-cancel, not a stun.

### Engine spec
- A boss field `interruptible_until` + `interrupt_hp` (damage-to-break) set at
  cast start in the relevant `_<kind>` method; checked in `take_damage`
  override on `Boss`. On break: cancel the queued telegraph/await chain, set
  `vuln_time`, play a stagger FX.
- The tricky part is cancelling an in-flight `await` chain (blade-storm-style
  casts use sequential awaits, `boss.gd:633-647`). Cleanest is a per-cast
  `cast_token` int the method checks after each await and bails if bumped — a
  small refactor to the await-driven casts, worth it.
- A HUD tell (the cast bar the game doesn't have yet — a thin ring on the boss
  during interruptible casts). Reuses the telegraph pulse art.

**Cost:** low-medium. **Theme:** neutral-to-good — "the god-king's voice can be
cut off mid-sentence" fits the Storm Tongue / recitation motif exactly.

**Open Q:** should the S-Weapon Awakening trials (`ACT2_DESIGN.md` §III) test
interrupt timing for one class? It's a natural identity beat.

---

## 4. Lane C — The world learns your build (run-level adaptation)

**PICK. Freshest loop-layer idea, cheap, generalizes Aldric.**

### The seam
Aldric (`ACT2_BOSS_KITS.md` §ch11) reads the player's ability usage for ONE
fight (the ledger: track IDs, react). It's a one-off. Nothing else in the game
reacts to HOW you fight over time.

### The design
A per-RUN (Depths / Incursion, not campaign) light adaptation: count ability /
element usage across the run; when it's lopsided, bias the NEXT rooms' mob
affixes toward resisting or countering it. Lean all-fire and the deeper rooms
seed fire-resistant or Rot-heavy packs; spam one ability and mobs start
carrying the counter to it. NOT per-fight (that's Aldric), NOT a hard wall — a
nudge that rewards build variety and makes the "the Waking smears reality /
reality reacts to you" theme mechanical at the loop level.

Key: it biases which AFFIXES/traits roll on mobs the engine already spawns — it
does not author new content. And it never touches the campaign (readability
rule); it lives in the endgame loop where variety is the whole point.

### Engine spec
- A per-run dict `Endgame.ability_ledger` incremented wherever the player fires
  an ability (one call site in `use_ability`).
- At room-gen in Depths/Incursion, read the ledger and shift the affix-roll
  weights (`endgame.gd:497-513` affix application already exists; this just
  biases the pool). Reuses `AFFIXES` / `WAKING_AFFIXES` (`balance.gd:3302-3323`).
- Surface it: one line of run text ("The deep is learning your fire.") so the
  adaptation is legible, not a silent difficulty spike (NO SILENT EFFECTS rule).

**Cost:** low (biases an existing roll; no new content). **Theme:** strong —
loop-first, identity-forward, on-thesis.

**Open Q:** ledger granularity — element buckets (cheap, 5-6 keys) or per-ability
(spookier, more keys)? Proposal: element buckets at v1.

---

## 5. Lane D — Corpse economy (the battlefield remembers every kill)

### The seam
Sexton already tracks summon-corpse positions and detonates paired corpses
within 180px (`_track_corpses`, `boss.gd:1034-1056`). The "passive channel add"
primitive (`choir_censer`: speed 0, aggro 0 — "scenery that bleeds") is reused
across four bosses. Neither is generalized to the trash layer, and the warlock
has no corpse identity.

### The design
Corpses persist briefly as interactable battlefield objects:
- The **Pale Root / blight factions reanimate** nearby corpses (a spawner that
  costs the player nothing to prevent except killing away from prior kills, or
  moving) — makes positioning your kills matter.
- **Blight zones bloom from corpse clusters** — kill everything in one spot and
  the floor turns against you. Movement-in-combat pressure with no timer.
- The **warlock can consume/detonate corpses** for a burst heal or an AoE — an
  identity beat that class is currently missing, and a natural fit for its pact
  fantasy.

This makes Act 2's core thesis — every kill frees the god-king — TRUE at the
trash level, not just in boss cutscenes.

### Engine spec
- A lightweight `corpse` marker dropped on `Enemy.die()` (position + faction +
  short TTL), pooled. Most mobs never interact with it; specific verbs do:
  `reanimate` (blight spawner reads corpse markers), warlock ability reads the
  nearest marker.
- Blight-bloom = the existing `_hazard`/`_add_hazard` path seeded off corpse
  density (`enemy.gd:1471-1477` sower pattern).

**Cost:** medium. **Theme:** it IS the thesis. **Risk:** corpse spam +
performance; TTL + pool cap it.

---

## 6. Lane E — Stalling wakes the world (pressure without a wall)

### The seam
There is deliberately no enrage timer (a design choice: "sustain is class
design, not a tax"). Consequence: a careful player can stall a room forever.
The Waking Flux terrain-shift primitive (`ACT2_DESIGN.md` §ch14) and the Depths
re-theme already exist as ways to change a room.

### The design
Don't add a timer. Make LINGERING summon the Waking: sit in a room past a
generous threshold and the terrain begins to shift (Waking Flux at the trash
level) or a single hunter-add stalks in and grows more insistent. Soft,
escapable pressure that never wipes a moving player — fully compatible with the
no-timer philosophy, and it solves the stall problem the philosophy created. A
kiter who keeps kiting is fine; a player who has genuinely stopped progressing
gets nudged, not punished.

### Engine spec
- A per-room `time_in_room` clock in `game_flow`; past a threshold, trigger the
  existing Waking Flux re-theme on a slow cadence, or `add_enemy` one hunter
  scaled to room level.
- Resets on room clear / meaningful damage dealt (so active fighting never
  triggers it — it targets STALLING specifically, measured by "no enemy died
  in N seconds", not raw time).

**Cost:** low (reuses Waking Flux / add_enemy). **Theme:** strong; the world
literally waking is the act's name.

---

## 7. Smaller seams (cheap variety, no new systems)

- **Pack-composition puzzles.** Pack aggro is real (`wake_pack`,
  `game_world.gd:1236-1244`) but shared buffs key off `zone_idx`, not species —
  there's no synergy design. Author packs where KILL ORDER is the fight: a
  Banner-carrier + Zealots, a Warder body-blocking a caster, a Tether pair that
  must die together. Turns trash from "AoE everything" into micro-puzzles.
  Pure spawn-table authoring on verbs `ACT2_BOSS_KITS.md` already specs.
- **Reactivate the dead machinery.** The orphaned `regen` trait
  (`enemy.gd:1488-1489`), the ~20 unplaced placeholder mobs (`pc_extra_mobs.gd`),
  and the dormant DEX axis (`balance.gd:3314-3322`) are built-and-unused. Cheap
  content/variety wins; the DEX one needs a "only-dodgeable, high-accuracy" mob
  type to make the stat matter (touches the free-crit-earned philosophy — flag).
- **The false room.** Mimic is a mob verb (`ACT2_BOSS_KITS.md` §ch9). Scale it
  to an ENCOUNTER: a room that reads as cleared, chest and all, then turns. One
  good horror beat per act; reuses the mimic reveal + a scripted spawn.
- **Data-driven boss abilities (long-term refactor).** The inert `mechanics[]`
  array (§0.1) could become a real ability schema — cooldown + telegraph
  preset + delivery engine — so new bosses are data, like mobs. Large, not for
  Act 2, but the single highest-leverage engine investment if boss count keeps
  growing. Noted so it isn't rediscovered later.

---

## 8. Contra-lanes — checked and NOT recommended

- **Affixes in the campaign.** The affix system is endgame-only by a standing
  rule that keeps campaign readable (`endgame.gd`, campaign uses elite-promotion
  only, `enemy.gd:1782-1824`). Deliberate; leave it.
- **Hard enrage / DPS-check timers.** Directly against the no-wipe philosophy.
  Lane E is the philosophy-safe version.
- **Damage-taken auras / healing debuffs by difficulty tier.** Excluded by
  "levels only, no hidden multipliers" (`ACT2_BOSS_KITS.md` §11).

---

## 9. Recommendation & build order

Highest depth-per-effort, in order:

1. **Lane B — Interrupt windows.** Cheapest real depth; fills the biggest hole;
   reuses `vuln_time`. Build the cast-token cancel + one interruptible heal on a
   single existing boss as a probe before generalizing.
2. **Lane C — World learns your build.** Cheap (biases an existing roll), fresh,
   loop-first. Ships inside the endgame loop with no campaign risk.
3. **Lane A — Enemy debuff kit (Rot).** Most theme-load-bearing; medium cost.
   Do it before Ch12 so the player-Blight and enemy-Rot symmetry lands together.
4. **Lane E — Stalling wakes the world.** Low cost, solves a real philosophy gap.
5. **Lane D — Corpse economy.** Biggest theme payoff, highest risk; sequence
   after the warlock corpse ability is scoped.

Smaller seams (§7) slot in opportunistically.

## 10. Open questions for the owner

1. **Lane A cleanse model** — dash strips a Rot stack, a cleanse consumable, or
   time-only decay? Decides how punishing healing-denial feels.
2. **Lane B interrupt reward** — cancel-only, or cancel + `vuln` window? And
   melee vs ranged interrupt-window asymmetry: yes or keep it uniform?
3. **Lane C granularity** — element buckets vs per-ability ledger.
4. **Lane D corpse warlock beat** — is this the right class, and heal vs AoE?
5. **Scope** — are these Act-2-gated, or do B (interrupt) and A (Rot) backfill
   into Act 1 replays / endgame too? (They're not act-specific mechanically.)

> Thesis: Act 1 taught the vocabulary and Act 2 speaks in sentences — but the
> conversation has only ever gone one way. These lanes let the enemy answer:
> cut off its cast, feel its rot, watch the deep learn your name.
