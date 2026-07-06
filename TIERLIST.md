# Emberfall — Class & Theme Tier List

Living balance document. This is the first documented edition; update it
whenever a balance pass lands, and replace letter grades with measured
numbers as fight-report benchmarks (`[fight]` console lines) accumulate.

**Frame (re-anchored 2026-07-06):** level 42, **full B-tier gear + four
Lv3 gems** (Act 1's realistic ceiling — the act loot clamp caps Act 1
drops at B, and 4 sockets × Lv3 is what the gem economy pays by 40),
talents allocated optimally, no potions. The old frame (full A,
gemless) is numerically within a few percent of this one, so historic
grades stay comparable. Bosses above L32 now carry the gem-expectation
ramp (`Balance.BOSS_GEM_*`) — benchmark against LIVE `enemy_stats_at`
numbers, never raw tables. Grades are static analysis (cadence ×
multipliers × crit/vuln math, adjusted for realistic uptime); the
fight-report instrument exists to verify them.

**Two axes, graded separately:**
- **Boss** — solo boss doors: sustained single-target output, sustain
  under telegraph pressure, ult value against one large health pool.
- **Rooms** — packs, elites, add fights: AoE, chain-clear speed,
  sustain under swarm chip. Rooms are most of the playtime; bosses gate
  progression.

## Mechanical ground rules the grades rest on

- **Bosses are CC-immune.** Stuns and slows do not land on bosses at
  all; they work at full strength on mobs and elites. Displacement
  (knockback, pulls, drags) is physics, not CC — it works on everyone.
- **Concussion:** a stun that fails against a CC-immune target converts
  to bonus damage (failed duration × `CONCUSSION_MULT` × ATK). Stun
  riders therefore keep a small, uniform boss value.
- **DoTs resolve like hits — there is no hidden true damage.** A DoT's
  tick rate is mitigated by the target's resistance minus the caster's
  penetration, snapshot at application (fast refresh cadences
  re-snapshot within a beat; no excess-pen flat bonus on ticks). Ticks
  **crit**, rolled per tick on the caster's sheet crit and shaved by
  the target's critres exactly like a hit — per-ability crit bonuses
  never ride into ticks, and nothing snapshots, so there is no fishing
  for a locked-in crit burn. True damage remains Death Mark's exclusive
  identity.
- **DoTs do not stack** (strongest wins, durations refresh) — **except
  toxin**: poison/venom-themed DoTs add stacks that deepen the tick
  (`TOXIN_PER_STACK`, cap `TOXIN_MAX_STACKS`). Fast hit cadences ramp
  toxin fastest.
- **Brittle** (ice theme): ice hits stack brittle; each stack amplifies
  **ice damage only** — theme-internal, so it rewards committing to ice
  across slots rather than borrowing one.
- **Crush** (void theme): void hits deal bonus damage to targets
  recently displaced hard (above ordinary hit-flinch). Void's own
  shoves and pulls open the windows; rift pull ticks chain them.
- **Wither** (warlock base kit): a *maintained* Hex deepens — stacks
  accrue per second of hex uptime (`WITHER_*` knobs, cap +48%) and die
  if the curse lapses. Trash never lives long enough to stack; long
  boss fights pay the warlock's patience.
- **EXPOSED (vuln)** is a debuff, not CC: +50% damage taken, works on
  bosses, and is therefore the premier boss rider.
- **Aegis answers arrows:** while the paladin's shield is up, blocked
  projectiles smite their shooter (half the melee reflect, capped per
  cast) — the reflect kit works into both melee and ranged bosses.
- **Boss stun-resist design intent:** boss counterplay lives in
  encounter mechanics (censers, rods, safe zones), not in player CC.

## Buildcraft: the pen/crit fork

Because DoTs respect resistance and crit on the sheet stat, the two
offensive substats serve different masters and stat allocation forks
per build:

- **Penetration** relieves mitigation on hits AND dots, and its excess
  converts to flat bonus damage on hits only. Direct-damage builds
  (Fury, Wrath, Wind, Storm, Hunt, Blood) get the most from it.
- **Crit** multiplies hits AND every dot tick. DoT builds (Venom,
  Poison, Curse, Fire) double-dip on crit, making crit-heavy gem
  loadouts their scaling route — the classes with dot access (archer,
  assassin, warlock, mage) genuinely diverge from the plate classes'
  tank-vs-damage allocation question.
- The fork lives mostly in **gems** (the benchmark frame is gemless),
  which ties build divergence to the boss-gem farming economy: socket
  progression is where a dot build and a direct build of the same class
  part ways.

## The board

Overall tier weighs the two axes evenly. Meta builds (per-slot theme
mixes) are listed alongside mono builds — mixes are the real endgame,
monos are the baseline identities.

| Tier | Build | Boss | Rooms | Reasoning |
|---|---|---|---|---|
| **S** | **Assassin mix** — Blood a1/a2/a3 · Shadow ult | S- | A- | Echo (35–45%) and blood-amp ride every part of the real loop — dash-in surge, knife-fan sustain, stab windows — and the execute ult finishes low targets with true damage. The highest ceiling in the game, priced in melee risk pulses and pilot skill. |
| **S** | **Archer loadout swap** — full Hunt at boss doors, full Storm in rooms | S- | A+ | Theme swaps are free outside combat, and the archer's two themes are each best-in-class on one axis: Hunt's near-permanent EXPOSED off a 0.36s cadence plus the Focus ult (~16× ATK into one target) at zero melee risk; Storm's fork/pierce/splash shreds packs. |
| **A** | Assassin · Blood (mono) | S- | B+ | The boss kit without the swap discipline: 45% echo on the fastest cadence in the game, and missing health converts to damage on top of the surge lifesteal it already funds. Room clear is honest but knife-chip-bound. |
| **A** | **Warrior mix** — Fury a1/a3 · Bulwark a2 · Fury ult | A | A | Fury's wave2 backhand nearly doubles Cleave and the echo cyclone shreds rooms; Bulwark's bash converts the gap-closer into a heal-and-harden button. The tankiest chassis in the game with top-three damage. |
| **A** | **Warlock mix** — Curse a1/a2 · Pact a3 · Curse ult | A- | A | Guaranteed EXPOSED from Hex, wither ramping beneath it, blood-pact burst on a 9s cycle, and the vuln-soaked rift. In add fights, one slot flips to Pact and every cursed death heals 8% max HP. The insurance class with a real engine. |
| **A** | **Mage mix** — Wind a1/a3 · Fire ult (a2 theme to taste) | A- | A | Twin bolts with 35% echo are the mage's single-target truth; the burn meteor beats Starfall solo (three comets need three targets). Frost Nova's heal/knockback utility is base-kit, so the a2 slot is a free farm pick. |
| **A** | Archer · Hunt (mono) | S- | B | The safe boss killer: ~50% crit, 25%-chance EXPOSED per shot ≈ permanent uptime, narrow Multishot landing all five arrows on one target. Pays for it in rooms, where precision riders do nothing for crowds. |
| **A** | Mage · Fire (mono) | B+ | S | The farm king: 40–45% splash on every cast turns each bolt into AoE, and the widened burning ult erases packs. On a lone boss half the damage budget splashes into empty ground, and the mage's modest crit keeps the burn slice honest. |
| **A** | Warrior · Fury (mono) | A | A- | wave2 Cleave, reckless charge, echoing whirlwind, deeper-longer Berserk — the best pure-melee damage welded to 80 physres, 15% flat DR and passive regen. Simple and brutally effective everywhere. |
| **A-** | **Paladin mix** — Wrath a1/a3/ult · Holy a2 | A- | A- | The burning backswing hammer with the 2.0× reflect Aegis, kept honest by Holy Consecration's per-enemy mending. Reflect answers melee bosses in kind and smites shooters through their own arrows. |
| **B+** | Warlock · Curse (mono) | B+ | A | The class's boss theme: withering DoT, EXPOSED on bolt and Hex, harder death-detonations, and the wither ramp underneath. Capped by the slowest a1 cadence on the lowest ATK curve — and by the class's low natural crit, which leaves its dot slice waiting on crit gems to scale. |
| **B+** | Archer · Storm (mono) | B+ | A+ | Forked arrows, piercing volleys, lightning splash on everything — packs evaporate. Solo bosses waste most of the chain budget. |
| **B+** | Assassin · Shadow (mono) | A- | A- | +15–20% crit riders, the phantom dash whose kills refund the cooldown (room-chaining heaven), and the true-damage execute. Opportunist's auto-crit needs slowed or stunned prey, which makes it a mob-and-elite tool. |
| **B+** | Paladin · Wrath (mono) | A- | B+ | Double Judgment, an erupting pulling Consecration, retribution reflect at double strength, a 40% harder verdict. The paladin's damage identity; gives up Holy's deeper sustain. |
| **B+** | Mage · Wind (mono) | A- | B+ | Twin echoing bolts and slipstream mobility make it the mage's duelist theme; Starfall wants multiple targets, so its ult is the weak slot solo. |
| **B+** | Paladin · Holy (mono) | B+ | A- | Damage mid, sustain absurd: 12% heal on shield-drop, 3.5% per enemy on double Consecration waves, mending chains. The attrition build — aura fights and marathon encounters are where it belongs. |
| **B+** | Assassin · Poison (mono) | B+ | B+ | The 0.3s cadence is the fastest toxin stacker in the game — the DoT ramps to full depth in under two seconds and stays pinned, and AGI's natural crit makes every tick a coin-flip for double. The slow half of the theme is mob/elite utility; the mist wake and venom bloom control packs. The class's crit-gem dot build. |
| **B+** | Archer · Venom (mono) | B+ | A- | Heavy stacking DoTs from every volley, toxin clouds on the dodge roll, and full-strength slows that make kiting mobs trivial. The archer's natural crit double-dips into every tick, making Venom the class's crit-scaling route and its safest solo theme. |
| **B** | Warlock · Pact (mono) | B- | A+ | An engine that runs on corpses: 8% max HP per cursed death, deeper blood pacts, a rift that feeds. Immortal wherever things die in numbers; starved on a lone boss where nothing dies until the end. |
| **B** | Warrior · Earth (mono) | B | A- | Quake waves, slam-stuns, and a whirlwind that drags packs into the blade — a room-control monster. On bosses the stuns convert to concussion damage and the a3 pull still positions adds; serviceable, not special. |
| **B** | Warrior · Bulwark (mono) | B | A- | Every button heals and hardens; a Whirlwind inside a pack is a full heal. The cannot-die build — its damage floor is the price, and bosses make you pay it slowly. |
| **B** | Mage · Ice (mono) | B | A- | Full-strength slows and freezes trivialize mobs and elites; on bosses the theme runs on brittle — self-stacking amplification that rewards committing every slot to ice — plus concussion off its freeze riders. Control paid for in raw DPS. |
| **B** | Paladin · Aegis (mono) | B | B+ | The shield answers everything: melee attackers eat the smite, shooters eat it through their own projectiles, and casting hardens the paladin's guard. A defensive identity whose damage arrives only when the enemy swings. |
| **B-** | Warlock · Void (mono) | B- | B+ | Gravity as a weapon: shove, pull, then crush whatever is still tumbling — the rift's pull ticks chain crush windows into the burst. Demands displacement choreography for its damage and offers the safest panic buttons in the class; the floor of the boss board, but a playable one. |

## Axis extremes worth remembering

- **Best boss killers:** Assassin Blood mix, Hunt Archer — one is the
  ceiling, the other is the ceiling you can reach from your couch.
- **Best room clearers:** Fire Mage, Storm Archer, Pact Warlock — splash,
  chains, and corpse-fueled immortality respectively.
- **Widest identity split:** the Archer — its best boss theme is its
  worst room theme and vice versa, which is why it plays as a
  loadout-swap class.
- **Most matchup-sensitive:** Paladin Aegis — strongest into fights that
  attack you constantly, weakest into fights that make you chase.
- **Attrition insurance:** Warlock (unconditional lifesteal, wither,
  corpse heals) and Holy Paladin — classes whose value rises as fights
  refuse to go cleanly.

## Standing balance watch items

- **Nightfang + slow themes** (S-dagger auto-crits slowed/stunned prey):
  boss-irrelevant under CC immunity, but on mobs/elites it is a
  permanent-crit farm engine once S gear drops (L40–70). Revisit when
  Act 2 tuning starts.
- **Warlock cadence and crit:** the slowest a1 (0.55s) on the lowest ATK
  base and growth, plus the game's lowest natural crit — at the gemless
  benchmark its dot slice pays full mitigation with little crit relief.
  Wither compensates on long fights, and crit gems are its designed
  scaling route; if Act 2 finale HP pools stretch warlock TTK past
  tedium anyway, the cadence is the knob, not the ramp.
- **Crit-gem dot builds** (Venom archer, Poison assassin): the crit
  double-dip on toxin-stacked ticks is the intended payoff, but it has
  the steepest gem scaling on the board — re-grade these rows on a
  gemmed frame before Act 2 ships, in case "gemless B+" is hiding a
  "gemmed S-".
- **Melee boss safety:** boss CC immunity removes bash/chain interrupts;
  concussion repays the damage but not the defensive beat. If melee
  boss fights start feeling worse in playtests, the fix belongs on
  Shield Bash / Chains (e.g., a self-guard rider on boss hits), not in
  re-opening boss CC.
- **All grades are paper until benchmarked.** The fight-report
  instrument prints `[fight]` lines (TTK, realized dps, damage taken,
  potions, wipes) per boss kill. Replace letters with minutes as runs
  accumulate.
