# Emberfall — Act 2 Design Bible: The Waking War

Chapters 8–14 · L40–70 · Design companion to DESIGN.md and BOSSES.md.

Act 1 ended with a crack in the sky and a dead speaker. The Storm Tongue's
seal is broken. The other four seals feel it. Act 2 is what happens when the
locks realize they're next — and everyone in Vaelscar starts choosing sides
about what to do with the doors.

---

## I. Narrative Arc — The Waking War

### The Central Paradox

Serane told you in Chapter 5: killing her weakened the very seal she guarded.
Cyrraeth's death proved it — the seal cracked as he fell. Act 2 makes this
the core dramatic tension: every herald and vessel you destroy strips another
lock from a god-king's prison. The factions split on how to answer this. The
Accord says rebind the seals (requires sacrifice — bearers must voluntarily
burn their Embers to forge new locks). The Cinderborn say *control* the
god-kings through the old imperial binding techniques (hubris, but they have
the texts). The player's choice between these is Act 2's load-bearing
decision.

### The Five Seals — Status Entering Act 2

| God-King | Domain | Seal Status | Act 2 Role |
|---|---|---|---|
| **The Storm Tongue** | Storm / void | **CRACKED** | Loose power bleeds through; no vessel needed — it speaks directly |
| **The Molten Judge** | Fire / verdicts | Straining | Vessel: Cinderborn forge-lord. First seal to break in Act 2 |
| **The Still Queen** | Ice / preservation | Straining | Vessel: the blacksmith's daughter (the one Mórwyn's awakening orphaned) |
| **The Pale Root** | Growth / bog | Straining | Vessel: Kaethra's body (if spared) or the land itself (if killed) |
| **Mórwyn, the Hollow Flame** | Blight / decay | Already woken | The blacksmith vessel fully consumed; she IS the Act 2 finale |

### The Vessel Rule

Each god-king needs a mortal vessel to act in the physical world — the
Concord bound them INTO people, so they can only emerge THROUGH people. A
vessel is a tragedy: a person slowly losing themselves to a god they didn't
invite. Act 2's boss fights are against the VESSELS, never the god-kings
directly. Killing a vessel frees the god-king's power to seek a new host (or
break free entirely if the seal is cracked enough). This is why Act 3 exists —
Act 2 buys time; Act 3 is the reckoning.

### The True Name Quests

600 years of the Concord meant 600 years of not speaking the god-kings'
names. Act 2 is where the player learns them — one per god-king, each a quest
chain that digs into the pre-Concord history. Knowing a true name is
mechanically meaningful: +8% damage bonus against that god-king's domain
enemies (the name is power over them) and a resonance choice about what to DO
with the name (share freely = Accord-aligned; hoard as leverage =
Cinderborn-aligned; destroy the knowledge = Wildfang proposal). Three names
are learnable in Act 2 (Judge, Queen, Root); the Storm Tongue's name is the
Act 2 finale's reward; Mórwyn's true name is the Act 3 inciting quest.

---

## II. Endgame Modes

### Boss Rush — The Crucible

Pure combat sprint. 10 random bosses, back to back.

- 10 random bosses from the full roster (any chapter the player has cleared),
  scaled to player level
- Each boss gets a random elite affix (Frenzied, Bulwark, Vampiric, etc.) —
  familiar bosses play differently every run
- **No healing between fights** — HP/MP carry over. Potions are the only
  resource; the per-room drink cap resets each fight
- Rewards scale with how far you get: guaranteed gem per boss killed,
  escalating gold, milestone chests at 3/6/10. The 10-boss clear pays a
  boss-band gear piece + a fat gem bundle
- Weekly leaderboard seed: fastest 10-clear time per class, feeds into the
  PB/records system
- Unlocks after Ch7 clear (Act 1 complete)
- **Push or cash out:** you can exit at any boss. Die = rewards at a 25%
  penalty (the death gold tithe extended). Always a "one more?" tension.

Mechanically cheap — boss.gd handles scaling, the arena is one reused room,
randomization is a seeded shuffle of cleared-boss list.

### Waking Depths — The Marathon

Infinite combat dungeon. How deep can you go?

- **First room is the only safe room:** merchant, stash access, loadout prep.
  After that, combat only.
- Rooms pull from the full terrain/mob pool of cleared chapters. Terrain
  rotates every few rooms for visual variety.
- Mobs start at player level, scale +1 per room. By room 20 they're +20
  levels above you. The compound growth curve does the work.
- **Every 4th room is a boss** from the cleared roster, scaled to that
  depth's level. Seeded shuffle — no repeats until the pool cycles.

**Escalation tiers:**

| Depth | What happens |
|---|---|
| 1–12 | Mobs scale, straightforward. Learning the mode. |
| 13–24 | Mobs gain 1 random elite affix each. |
| 25–36 | Mobs gain 2 affixes. Bosses gain 1 affix. |
| 37–48 | **Player debuffs start.** One stacking debuff every 4 rooms: −10% healing received, then −10% damage dealt, then +10% damage taken, cycling. |
| 49+ | Mobs 3 affixes, bosses 2 affixes, player debuffs keep stacking. The "how far can you really go" zone. |

**Rewards — paid at the END (death or voluntary exit at any boss checkpoint):**

- Gold scales linearly with depth
- Gems: 1 per boss killed, quality scaling with depth
- Milestone chests at depth 12 / 24 / 36 / 48 (boss-band gear rolls)
- **Depth record** per class in codex Records — the brag number
- No XP (same rule as chapter replays)
- Exit at any boss checkpoint = full rewards. Die = 25% penalty.

### Waking Incursions — Weekly World Events

Weekly rotating events that overlay onto existing chapters.

- Each week (trusted clock), one cleared chapter is marked as **Waking**. The
  chapter's map gets 3 bonus rooms injected off the spine —
  exploration-only, seeded for the week (same for all players).
- Each bonus room contains a **Waking Mini-Boss**: a boss from a DIFFERENT
  god-king's domain than the chapter's native terrain. Magma chapter gets an
  ice boss. The terrain mismatch IS the story — the Waking smears domain
  boundaries.
- Mini-bosses scaled to chapter level + 5, with one random elite affix.
- **Rewards:** guaranteed A-grade gem per mini-boss + bonus gold. All 3 in
  one run = a Waking Chest (boss-band gear roll + weekly cosmetic token when
  those exist).
- The weekly challenge seed and incursion rotate to the SAME chapter —
  double the reason to visit that week's chapter.
- Mini-bosses are subsets of existing boss kits dropped into the wrong
  terrain. Cheap to author.

**Multiplayer seed:** in co-op, incursion rooms are shared. In a future MMO
context, these become the world boss rotation — same infrastructure, different
scale.

---

## III. S-Weapon Awakening Quests

The dormant flag already exists (round 51b) — a dropped S-weapon sleeps until
`s_awakened_<cls>` is set. The quests set it.

Each class meets the **ghost of their Ember Guard founder** — the first time
the player sees the person whose power they carry. The ghost appears at a
shrine in any chapter after the S-weapon drops (not gated to a specific
chapter — the weapon IS the trigger).

**Structure (shared scaffold, like class openings):**

1. **The Shrine** — a resonance room variant. The founder's ghost
   materializes when carrying a dormant S-weapon. Opening dialogue reads
   resonance band (three variants).
2. **The Trial** — a solo combat encounter testing the class's IDENTITY
   mechanic. Not a DPS check — a mastery check. Failure resets the trial.
3. **The Revelation** — the founder tells you one thing about the god-kings.
   Seeds Act 3 lore. The weapon awakens.

### Per-Class Trials

**Warrior — The Unbreakable Line**
- Founder: Vargoth's lieutenant (the loyal one, unnamed)
- An NPC squad of 4 soldiers stands behind you. A horde pushes toward them —
  if ANY mob reaches the soldiers, trial resets. You are the wall. Mobs come
  from one direction (a corridor/chokepoint). You cannot chase — stepping off
  the line lets mobs through. Grit stacks keep you alive as you tank the wave
  head-on. Threat management in a tiny space: which mob first, when to
  Berserk, how to handle ranged mobs arcing past.
- **Tests:** facetank identity, threat prioritization, holding ground.
- Pass: hold the line for 90s.

**Assassin — The Marked Hunt**
- Founder: The Erased (the betrayer — no name, that's the point)
- 5 high-value targets across a dark arena, each with a brief visibility
  window (flash visible 2s, vanish 4s). 30s total. Each kill extends the
  timer by 3s. Targets don't fight — but patrol mobs fill the arena and
  hitting one slows you for 1s (no damage, time is the HP bar). Shadow Dash,
  Death Mark, Fan of Knives — every tool closes distance and executes before
  the window closes. Miss a window = waste seconds waiting.
- **Tests:** dash-chain mobility, target prioritization, weaving through
  danger.
- Pass: kill all 5.

**Paladin — The Chain's Burden**
- Founder: The Chain-Bearer (forged the Concord's binding)
- Protect an NPC for 90s. Mobs attack the NPC, not you. You cannot kill the
  mobs — only knock them back and heal the NPC through stance-swapping. Holy
  mends the NPC, Retribution's knockback clears space. The swap cadence IS
  the skill.
- **Tests:** Conviction stance mastery, protection identity.
- Pass: NPC survives 90s.

**Archer — The Storm of Arrows**
- Founder: Fangmaw's handler (before corruption — a Stormwarden beastmaster)
- A bullet-hell arena. Projectiles rain from all directions on randomized
  patterns. Every projectile that HITS you spawns 2 more on a short delay —
  one mistake cascades. Second Wind (heal by NOT being hit) is the sustain.
  Clean dodging heals you; getting clipped spirals into more projectiles.
  The skill ceiling is perfect play where you're regenerating while the sky
  falls.
- **Tests:** positioning mastery, Second Wind identity, reading patterns.
- Pass: survive 60s.

**Mage — The Shifting Floor**
- Founder: Mórwyn's apprentice (the last student who left before it went
  wrong)
- An arena with no safe floor — everything is hazard patches. Safe spots
  exist but shift every 3s. Cast from the safe spots, deal enough damage to
  pass. Standing still kills you; reading the floor lets you thrive.
- **Tests:** positioning + element-weaving, the kiting caster identity.
- Pass: survive 60s.

**Warlock — The Debt Collector**
- Founder: The Debt-Writer (the entity on the other side of the pact — not a
  god-king, something ELSE)
- You start at 25% max HP (−75% HP debuff at trial start). Adds flood in
  continuously for 60s — relentless volume, not elite-grade. You cannot raise
  max HP. Pact lifesteal, wither stacks, hex damage, Dark Pact burst heal —
  every warlock sustain tool is the answer. Razor-thin health bar against
  constant pressure through smart rotation and positioning.
- **Tests:** Pact management, sustain-under-pressure identity.
- Pass: survive 60s.

### Founder Revelations (seeds Act 3)

| Class | Founder | Revelation |
|---|---|---|
| Warrior | The Lieutenant | "The Crown was never meant to be worn. It was a CAGE." |
| Assassin | The Erased | "I didn't betray the Guard. I tried to destroy the Crown before Vargoth found it. They erased my name for failing." |
| Paladin | The Chain-Bearer | "The Concord didn't bind five god-kings. It bound six. The sixth one agreed to it." |
| Archer | The Handler | "Fangmaw was my partner. The corruption didn't change what she was — it showed what she'd always been." |
| Mage | The Apprentice | "Mórwyn didn't fall. She SUCCEEDED. The blight is exactly what her spell was meant to do. She just lied about what the spell was for." |
| Warlock | The Debt-Writer | "The pact isn't with me. I'm just the broker. You'll meet the creditor in the Throne." |

---

## IV. Faction Evolution

Act 1 introduced four factions. Act 2 makes allegiance **consequential**.

### Joinable Factions

**Ember Accord — The Rebinding:**
Maren's plan crystallizes — bearer-volunteers burn their Embers to forge new
seals, but each rebinding costs the bearer permanently (massive stat
reduction; they become "burned out" like Aldric). The Accord needs four
volunteers — one per seal. The player's Accord questline is recruiting them,
and the horror is that they go willingly. Resonance beats ask: is asking
someone to sacrifice themselves for the world a virtue or a cruelty?

**Cinderborn — The Binding Texts:**
The old imperial archives contain the original Concord ritual — not to
re-seal the god-kings, but to bind them to a new ruler's will. The Cinderborn
heir (introduced Ch4, named **Vassik**) is assembling the ritual components.
The player's Cinderborn questline secures these artifacts, each guarded by one
god-king's forces. The catch: the ritual requires a vessel — someone must host
the bound god-king. Vassik volunteers himself.

### Ambient Factions — Escalation

**Wildfang Tribes — The Schism Breaks Open:**
Kaethra's fate catalyzed the split. Cure-seekers dive into the Pale Root's
domain; the acceptance camp sabotages them. Both offer quests with standing
shifts. By Ch12, accumulated standing determines which camp leads the Wildfang
into Act 3. Promotion to joinable: deferred to expansion per DESIGN.md.

**Hollow Choir — The Waking Validates Them:**
The Choir preached decay is the land's truth. The god-kings waking is exactly
what they predicted. Recruitment surges. Moderate wing (grief-faith) and
radical wing (Mórwyn worshippers) split. The radical wing's leader becomes a
Ch14 sub-boss.

### Faction-Gated Content Rules

- 2 unique rooms per chapter swap based on joinable faction allegiance
- 3 faction-exclusive side quests per chapter (same content, different
  perspective)
- Ambient faction standing gates dialogue and rewards, never rooms or bosses
- The Act 2 finale has two approach paths based on faction, converging at the
  same boss

---

## V. Chapters 8–14

**Pacing:** L40–70 = 30 levels across 7 chapters = ~4.3 levels per chapter.
Chapters are DENSER — more mechanics per room, more blended terrains, longer
first-run time (~60–90 min vs Act 1's 45–75). Room count stays 20–30.

**Terrain rule:** Act 2 chapters blend 2–3 terrain families. The corruption
merging IS the story.

**Loot:** Act 2 cap = A. S drops begin at Ch12+. Boss channel: A@1/5,
S@1/10 (ch12+).

---

### Chapter 8 — The Ashfall Foundries
**Terrain:** magma + castle hall blend · L40–46 · The Molten Judge's seal

The Cinderborn's industrial heart — foundries built over the Molten Judge's
seal. Forge-lords hear verdicts in the fire. Metal refuses to cool. Workers
walk into furnaces and come out improved. Act 1 showed the Cinderborn pitch;
Act 2 shows the cost.

**WoW ref:** Blackrock Foundry zone + Firelands approach.

**Terrain mechanic:** *Slag Vents* — floor grates periodically erupt
(telegraphed), leaving temporary lava patches. Castle-hall interiors have
forge machinery activatable by the player (environmental damage to bosses,
limited uses). **New hazard:** `molten_metal` — slows instead of speeding
enemies (cooling metal grabs at feet).

**Faction content:** Cinderborn players get insider access (alternate route).
Accord players infiltrate — social rooms are tense negotiations with
defecting Cinderborn smiths.

#### Smelter-Lord Thrain — The One Who Wouldn't Stop
**L42 · mid boss · melee brute · phys**
*"He wanted the perfect alloy. The Judge whispered the temperature. It's
still climbing."*

- **Molten Fists (signature):** weapon heats over time (Calda lineage). Max
  heat = attacks leave permanent lava trails. Player can lure him through
  water troughs to quench — resets heat but +10% attack speed per quench
  (stacks). Quench often (safer, slower) or let him cook (riskier, faster).
- **Foundry Slam:** Vargoth shockwave ring + floor vent activation.
- **Cast Metal:** thrown molten boulder → persistent lava zone.
- 30% — **Meltdown:** heat maxes permanently, attack speed doubles, lava
  trails every step. Race to finish.

#### The Verdant Anvil — Judgment Made Metal
**L44 · mid boss · ranged caster · magic**
*"The anvil speaks the Judge's verdicts now. It doesn't need a hand to swing
the hammer."*

- **Verdict Echo (signature):** Ashpriest Ordo's half-arena verdicts matured —
  arena divides into THIRDS (two guilty + one safe, rotating every 4s).
- **Forge Constructs:** two animated weapon-adds (sword = glass cannon, shield
  = warded tank). While both live, the Anvil channels heal. At 40%, the first
  to die is RE-FORGED at half HP. Kill simultaneously (±2s) or fight the
  rebuild.
- **Hammer Fall:** telegraphed slam → shockwave + stun in guilty zone.

#### Archon Vassik, Vessel of the Molten Judge — Chapter Finale
**L46 · chapter finale · two-phase caster · magic + phys**
*"He opened the foundry to prove the Cinderborn could master the old fire.
The fire agreed — on its terms."*

- **Phase 1 — The Forge-Lord (100–50%):** Ashpriest DNA. Half-arena verdicts,
  brand volleys, Sons interceptors. The fight you know, faster, at L46.
- **Phase 2 — The Vessel Speaks (50–0%):** the Judge takes over. **Binding
  Verdict** — 2s cast, if it completes: root + ticking fire 4s. Break LOS
  behind a pillar (4 in arena, each cracks per use — Varo lineage). Between
  Verdicts: continuous magma rain + pursuing lava wave across the floor.
- **On death:** faction-divergent moment. Accord: Maren's volunteer steps
  forward to rebind (resonance choice). Cinderborn: Vassik tries to contain
  the Judge — partially succeeds, diminished (Act 3 setup).

---

### Chapter 9 — The Drowned Reaches
**Terrain:** bog + sewer blend · L46–51 · The Pale Root's domain expands

The Pale Root's influence has flooded an old imperial undercity. Wildfang
cure-seekers study the growth. Kaethra's fate echoes — if she lived, her body
is here, still growing, still lucid, the Root using her as a relay.

**WoW ref:** Underbog + Vashj'ir.

**Terrain mechanic:** *Rising Water* — water level rises and falls on a timer.
Submerged = slowed + poison tick. Elevated platforms are safe but limited.
**New hazard:** `spore_cloud` — drifting clouds applying the Drowse mechanic
from Mother Halla.

#### Broodmother Yskara — The Thing in the Cistern
**L48 · mid boss · spawner/zone control · phys**
*"She was a sewer spider before the Root found her. Now her web is made of
roots, and her eggs hatch flowers."*

- **Root Web (signature):** web-lines across the arena (visible, breakable).
  Walking through = root (Serane lineage). She walks freely. Pattern
  reshuffles every 20s.
- **Egg Sacs:** spawner adds on timer. Each hatches 3 spiderlings (weak, fast,
  tether-linked in pairs — Ch6 mechanic). Destroy before hatch to prevent.
- **Venom Spit:** poison-patch cone (Rotmaw garden miniature).
- 25% — all webs become TOXIC (proximity poison). Pathfinding through gaps IS
  the fight.

#### Overgrown Gatewarden — The Door That Grew Shut
**L50 · mid boss · stationary tank · phys + magic**
*"The empire built a gate. The Root grew through it. Now the gate guards the
Root's side."*

- **Immovable (signature):** speed 0, blocks the passage. A siege fight.
  Destroy root-anchors on either side while it rains area denial.
- **Root Slam:** arena-wide shockwave on timer. Jump to elevated platforms to
  dodge (verticality — raised terrain as dodge space).
- **Vine Reach:** root-tendrils track and lash at range.
- **3 root-anchors:** each destroyed = −25% damage + opens passage. Third
  anchor death = vulnerability. Final 25% is a DPS race.

#### The Pale Nursery — Kaethra's Echo — Chapter Finale
**L51 · chapter finale · conditional two-form · magic**
*"If you spared her, she kneels here still. If you killed her, the Root found
another shape — and this one doesn't talk back."*

- **Kaethra spared:** she IS the boss — Ch6 Cure-Twisted form, stronger. She
  fights the Root's commands. Every 30s she regains control for 5s — stops
  attacking, speaks. Mid-fight resonance choice: end her (resonance shift) or
  cut the root-tether (destroys the Root's relay, she loses power forever —
  Wildfang standing shift).
- **Kaethra killed:** the Pale Nursery is a root-construct. No dialogue. Pure
  mechanics: bloom-form, dreamer-adds (Halla lineage), poison-cloud arena,
  growing root zones. Harder mechanically, easier emotionally.
- Both: **Spore Burst** — Halla sleep pulse. **Root Eruption** — line
  telegraphs leaving permanent root-walls (arena shrinks). The Root can't be
  killed here, only slowed.

---

### Chapter 10 — The Singing Ice
**Terrain:** ice + crystal blend · L51–56 · The Still Queen's seal

The Frozen Expanse has deepened — Crystal Caverns beneath the ice shelf are
singing. The Still Queen's vessel: **Elara**, the blacksmith's daughter. She
walked into the ice to escape the blight that killed her father. She sleeps,
and the ice grows. The Long Sleep cult sees her as proof the Queen protects
her chosen. The Still Queen's true name is learnable here.

**WoW ref:** Icecrown approach + Hodir's legacy.

**Terrain mechanic:** *Resonance Crystals* — amplify magic: +15% spell damage
near one, but +15% incoming magic damage. Risk/reward positioning anchors.
**New hazard:** `deep_freeze` — patches that freeze SOLID (3s stun) instead
of ice-speed-boost. Darker blue color to distinguish.

#### Choir of Frost — The Hymn That Froze
**L53 · mid boss · council fight (3 casters) · magic**
*"Three Long Sleep acolytes who sang the Queen's lullaby so long they became
part of it. They harmonize."*

- **Harmony (signature):** three linked casters — while all live, spells
  CHAIN (each triggers a lesser copy from the others). Kill order matters:
  each death = discordant (faster, angrier, no chains). **WoW ref:** Illidari
  Council / Iron Maidens.
- **Lullaby:** one singer channels Halla sleep pulse every 12s. Singer
  rotates.
- **Flash Freeze:** Serane callback — arena-wide, safe zones, but each singer
  generates a frozen zone at their position.

#### Glacius, the Unmelting — The Mountain That Walked
**L55 · mid boss · armored golem · phys**
*"It was a cave. Then the Queen dreamed of a guard, and the cave stood up."*

- **Crystal Armor (signature):** Cinderhide plate INVERTED — instead of
  luring into lava, lure Glacius AWAY from crystal formations that regen
  its plating. 4 crystal clusters; destroy them (~8s focused DPS each) to
  remove regen zones permanently. Resource management: how many to destroy vs.
  how long to kite.
- **Avalanche:** charge leaving deep_freeze patches. On crystal-free ground,
  no patches — reward for cluster destruction.
- **Shatter Stomp:** radial crystal burst on plate break + 10s vuln window.

#### Elara, Vessel of the Still Queen — Chapter Finale
**L56 · chapter finale · three-phase tragedy · magic**
*"She is fifteen. She walked into the ice because everything warm had been
taken from her."*

- **Phase 1 — The Dream (100–65%):** Elara sleeps in a crystal cocoon.
  Nightmare projections (shadow-copies of Act 1 bosses at reduced stats)
  manifest one at a time. Destroy the cocoon to advance. Crystals amplify
  the Queen's healing of the cocoon — destroy crystals to slow heal, but each
  spawns a deep_freeze zone.
- **Phase 2 — The Waking (65–25%):** cocoon cracks; Elara half-wakes,
  confused. Casts Serane's kit badly (wider, slower telegraphs). A cultist
  runs in and tries to sing her back to sleep — protect or kill (resonance).
- **Phase 3 — The Queen Attends (25–0%):** the Queen in full control. Arena
  crystallizes from edges (Serane P2 callback). Flash Freeze with DECOY safe
  zones (Vess Keening callback). The first fight that feels like god-king
  power — filtered through a child.
- **On death:** Elara wakes permanently. Ice doesn't stop. True Name payoff:
  if learned, speak it — ice PAUSES, seal holds longer.

---

### Chapter 11 — The Ember Crusade
**Terrain:** holy + storm blend · L56–60 · Faction war

The political chapter. Accord and Cinderborn mobilize. The Sanctified Ruins
(old Ember Guard fortress) are contested ground. Faction allegiance COSTS
something — you fight alongside your faction against the other's champions.

**WoW ref:** Battle for Light's Hope + Wrathgate.

**Faction-divergent rooms:** 4 rooms swap based on allegiance (highest ratio
in Act 2).

#### Commander Drayce / High Artificer Maeven — Faction Champion
**L58 · mid boss · faction-dependent · phys or magic**
*"You fight the other side's best. Both of you are right."*

- **Drayce (Cinderborn fights):** warrior-kit boss — Grit, shockwave rings,
  tracking charge. Accord NPC squad heals him; kill healers or out-DPS.
- **Maeven (Accord fights):** mage-kit boss — fire/ice alternation, Blink,
  Frost Nova. Cinderborn construct-adds reflect ranged damage (Ch4 mechanic).
- Both: at 30%, attempts parley. Resonance choice: accept (they retreat, gain
  standing with THEIR faction, lose with yours) or refuse (the kill). The
  first boss where mercy costs standing with your own people.

#### The Shattered Vow — A Broken Seal Fragment
**L59 · mid boss · environmental hazard · magic**
*"A piece of the Storm Tongue's seal. It speaks in incomplete sentences. Each
sentence is a lightning bolt."*

- **Seal Fragment (signature):** stationary, unkillable. Survive 90s while an
  NPC performs a binding ritual. The fragment cycles Act 1 terrain events:
  lightning → magma rain → ice burst → grave spawn → void slow, 15s each. The
  vocabulary exam.
- **Between cycles:** whisper-adds (Echo lineage) try to interrupt the ritual.
  Intercept them.
- If ritual fails (NPC dies): fragment explodes, permanently empowers the
  chapter's remaining enemies. **First persistent failure state.**

#### Aldric, the Burned-Out Ember — Chapter Finale
**L60 · chapter finale · scripted duel · phys**
*"He burned his Ember killing Vargoth. No power, no fire — just forty years of
knowing exactly how you fight."*

- **No abilities. No magic. No telegraphs.** Mundane sword, mundane speed.
  His kit is READS — dodges your most-used ability, counters your opener
  (after 10s, anticipates most-cast ability), punishes predictable patterns.
- **Single mechanic:** abilities he hasn't seen = stagger (2s vuln + damage
  amp). Abilities seen 3+ times = parry (50% reflect). Rewards variety and
  unpredictability.
- **No phases, no enrage.** Speed decreases slowly (fatigue). ~60s if played
  well.
- **At 10%:** he yields. Teaches the Storm Tongue's partial true name. "I
  never finished the sentence. That's why it woke."

---

### Chapter 12 — The Roothold
**Terrain:** spore + bog + forest triple blend · L60–64 · The Pale Root's vessel

The Pale Root never needed a human vessel — the LAND is its vessel. The
Blooming Deep has become a full biome: a living landscape that rewrites itself
as you walk. S-tier loot begins dropping.

**WoW ref:** Emerald Nightmare + Val'sharah.

**Terrain mechanic:** *Living Growth* — root/vine walls grow across cleared
rooms over time, potentially blocking exits until cut. **New hazard:**
`entangle` — roots erupt after 2s standing in one spot (Halla's stillness
detection on the terrain).

#### The Rootweaver — The Forest's Favorite
**L62 · mid boss · summoner/puzzle · magic**
*"A Wildfang druid who communed with the Root and didn't flinch."*

- **Living Arena (signature):** the arena changes shape during the fight.
  Root-walls grow/retreat on a cycle, creating shifting corridors and
  bottlenecks every 20s. Boss phases through walls; player tracks the cycle.
- **Thorn Barrage:** rapid-fire through root-wall gaps (walls create firing
  lanes).
- **Bloom Trap:** seeds at the player's position → 4s later, healing bloom
  FOR THE BOSS. Destroy or kite.
- 25% — root-walls become toxic.

#### Thornfather Grael — The Cure That Worked
**L63 · mid boss · tank/healer hybrid · phys**
*"Cure-seekers asked the Root to undo their beast-blood. It replaced it with
something that grows instead of howling."*

- **Regrowth (signature):** regenerates 3%/s. The ONLY counter: **healing
  reduction debuts here.** The Blight debuff (50% reduced healing for 8s,
  applied by per-class abilities or arena Blight Bomb pickups).
- **Root Lash:** melee sweeps leaving entangle hazard.
- **Thorn Shield:** reflects 30% damage while active. Dropped to cast
  Regrowth — the DPS window is while he's healing AND Blighted.

#### The Heart of the Root — Chapter Finale
**L64 · chapter finale · multi-target / environmental · magic**
*"There is no vessel. The land IS the vessel. You're standing inside the
god-king."*

- **The Root Itself (signature):** 5 root-hearts embedded in walls/floor.
  Destroy all 5 to win. Each has its own HP bar and defense mechanic (one
  spawns adds, one fires thorns, one grows poison clouds, one heals the
  others, one roots the player). Priority order is the puzzle.
- **Pulse:** every 30s, all surviving hearts pulse — arena-wide damage
  proportional to surviving hearts. The soft timer.
- **The Garden:** between pulses, poison patches and entangle zones fill any
  unoccupied space. Movement is life.
- **True Name payoff:** if learned, speaking the Pale Root's name makes one
  heart go dormant for 20s.

---

### Chapter 13 — The Storm Scar
**Terrain:** storm + void + desert triple blend · L64–68 · The Storm Tongue speaks

The cracked seal has torn wider. The Thunder Plains are a wound in the world
where void shows through weather. Lightning speaks in sentences. Sand is
being pulled into the scar. Korrag's Stormwarden survivors know the
recitation. The Storm Tongue's true name is the prize.

**WoW ref:** Throne of Thunder + N'Zoth void breaches.

**Terrain mechanic:** *Void Tears* — ground rifts teleporting the player to a
random room position. **New hazard:** `storm_word` — telegraphed line showing
a WORD. Hit = silenced (abilities disabled 3s).

#### The Unfinished Sentence — Storm Fragment
**L65 · mid boss · storm elemental · magic**
*"Cyrraeth died mid-sentence. The sentence didn't."*

- Veyx matured: 6 conductor rods, arcs CHAIN between rods. Exploded rods
  leave void tears (permanent).
- **The Word:** periodic storm_word telegraphs. Hit = 3s silence. The text is
  a fragment of the Concord recitation — learning the words IS the True Name
  quest (dodge the knowledge you need, read each word while dodging).
- 20% — all rods shatter. Pure storm.

#### Korrag Reborn — The Broken Mended Wrong
**L67 · mid boss · storm warrior · phys + magic**
*"The storm that broke him in Ch2 was the seal straining. The seal is open
now. The storm put him back together — with extras."*

- Korrag's Ch2 kit at L67 stats and 2× speed. Then the new layers hit.
- **Storm Tongue's Gift (signature):** every 20s, Korrag SPEAKS (2s channel).
  The word manifests as a shockwave reshaping the arena — void tears open,
  sand dunes rise, lightning rods materialize. Each word changes the layout.
  The fight never plays the same twice.
- **Storm Wolves:** pack wolves with lightning auras. If two die near each
  other, chain lightning between corpses (corpse-bloom logic). Kill spread.
- 15% — falls to knees. Storm Tongue speaks through him. Listen 10s (no
  combat, learn true name piece) or attack (faster, less lore). Resonance.

#### The Mouth of the Storm — Chapter Finale
**L68 · chapter finale · environmental raid boss · magic**
*"There is no vessel. The crack in the seal IS the boss. You are fighting a
hole in the world."*

- **The Scar Itself (signature):** three Stormwarden relic ANCHORS hold the
  breach partly closed. Defend anchors while damaging the exposed seal-edge
  (boss HP bar). Broken anchor = wider breach + more hazards.
- **Storm Cycle:** LIGHTNING (Veyx density) → VOID (slow + teleporter tears)
  → SAND (gust + reduced visibility). Each phase favors different positioning.
- **Speakers:** Stormwarden NPCs chant at anchors, healing them. Storm
  Tongue sends word-adds (storm_word) to silence the speakers. Intercept.
- **On victory:** breach narrows, doesn't close. True name assembled from
  words dodged across two fights. Speaking it calms the storm.

---

### Chapter 14 — The Hollow Crown
**Terrain:** all terrains blend · L68–70 · ACT 2 FINALE

Mórwyn's vessel is consumed. The Hollow Flame walks for the first time in 600
years, heading for the Hollow Throne. Every faction converges on the old
capital. The terrain is ALL terrains — the Waking has smeared reality.

**WoW ref:** Icecrown Citadel + Broken Shore.

**Terrain mechanic:** *Waking Flux* — terrain shifts mid-combat (lava →
ice → poison). Hazards transform. Keeps the player reading the ground.

#### The Choir Ascendant — Herald of the Hollow Flame
**L69 · mid boss · ranged support + adds · magic**
*"The Choir's radical wing has a leader now. She has seen the Hollow Flame
walking and decided this is what holiness looks like."*

- Choir Mother kit fully realized: requiem rings, verse volleys, hymn heal +
  blight aura (soft timer) + Choir adds that sing healing hymns.
  Adds are invulnerable while singing, interrupted by body-blocking their
  circle. Solo: prioritize. Co-op: one player per singer.
- At 50%: reveals Mórwyn's position (story beat). Remaining rooms shift to
  blight terrain.

#### The Burned King's Echo — What Vargoth Left Behind
**L70 · mid boss · shadow duelist · phys + magic**
*"The Hollow Throne remembers the man who sat on it."*

- Vargoth's Ch1 kit at L70, 2× speed. PLUS he samples every god-king's
  vocabulary: verdicts (Ashpriest), flash-freezes (Serane), root-walls (Pale
  Root), storm-words (Storm Tongue). The CURRICULUM EXAM.
- At 50%: manifests a shadow-copy of the PLAYER (Echo lineage). The copy uses
  the player's most-used abilities against them.

#### Mórwyn, the Hollow Flame — ACT 2 FINALE
**L70 · act 2 finale · four-phase god-king · magic**
*"She was a battle-healer who believed in perfection. Six hundred years of
imprisonment refined her argument."*

- **Phase 1 — The Healer (100–75%):** she HEALS — not herself, the arena.
  Blight patches bloom into healing zones for her minions. Choir adds stream
  in. Kill adds or destroy healing zones (targetable, Varo censer logic).
  Deliberately gentle — showing what she was before the Fall. Morwen Ch1 kit
  (nostalgic).
- **Phase 2 — The Perfectionist (75–40%):** healing zones become blight zones.
  Adds become blight-zombies. Bolts leave DOT trails. Triple blink sequence,
  each leaving a blight pool. The arena fills with rot. Class-targeted
  dialogue — mage hears "You know exactly what I mean, spellwright."
- **Phase 3 — The Hollow Flame (40–10%):** stops talking, stops blinking.
  Walks toward you slowly. An expanding death aura (5% max HP/s within
  range). The arena decays — scenery crumbles, ground cracks. Kite and burn
  before the arena runs out. She IS the mechanic.
- **Phase 4 — The Remnant (10–0%):** she falls. The blacksmith's face shows
  through. One line: "I remember the forge." Resonance choice: **End her**
  (power dissipates; blight lingers) or **Seal her** (requires Accord
  rebinding OR Cinderborn binding text — faction-gated; needs a new vessel,
  and the player is the strongest candidate). This choice is Act 3's
  inciting incident.

---

## VI. Mob Escalation Curve

Act 1's vocabulary ran ch1 (pounce/web/channel_heal) → ch7 (blinker/counter).
Act 2 continues with compound mechanics — two simple behaviors combining into
emergent tactics. One headline mechanic per chapter; earlier verbs baseline.

| Ch | Headline | Description | Counterplay |
|---|---|---|---|
| 8 | **Empowered** | Stacking damage buff every 5s. Heavy hit resets stacks. | Prioritize or interrupt. A sleeping empowered mob is a time bomb. |
| 8 | **Sentry** | Deploys a stationary turret (0 speed, low HP, fires bolts). Retreats while turret lives. | Kill turret first (priority target). |
| 9 | **Mimic** | Disguised as chest/scenery until melee range. Ambush hit (heavy). Subtle shimmer tell every 3s. | Watch for glint. Ranged attacks on suspicious objects reveal safely. |
| 9 | **Burrow** | Submerges and repositions (Sexton tech on trash). Surfaces with eruption telegraph. | Keep moving when a mob vanishes. |
| 10 | **Crystallize** | On death → crystal obstacle (blocks movement + projectiles, 10s). Chokes tight spaces. | Kill order matters. Don't crystallize in doorways. |
| 10 | **Resonance Pulse** | Periodic pulse heals allies + damages player. Amplified near crystals. | Pull away from crystals. Priority target. |
| 11 | **Banner** | Plants battle-standard: +25% dmg + CC immunity to allies in range. Destructible. | Kill the banner. Area denial. |
| 11 | **Zealot** | Charges lowest-HP player (ignores aggro). Wall impact = stun (Whitepelt lineage). | Stay healthy or bait into walls. |
| 12 | **Parasite** | On death → 2 smaller versions (half stats, don't split again). | AoE. Effective count ~1.5× visible. |
| 12 | **Root Anchor** | Immobile. Extends entangle hazard across floor. More anchors = more denied floor. | Ranged priority. Clearing opens the floor. |
| 13 | **Phase Shift** | Flickers targetable/untargetable (1.5s on / 1s off). | Time burst. DoTs tick through off-phase. |
| 13 | **Storm Word** | Channels storm_word line. Hit = 3s silence. Vulnerable during channel. | Interrupt or dodge. Channel = DPS window. |
| 14 | **Waking** | COMPOUND: each mob carries TWO mechanics from the full pool. | Read both traits. Apply both counterplays. The final exam. |

### Elite Affixes — Act 2 Additions

Act 1: Frenzied, Bulwark, Vampiric, Stormtouched, Splitting. Act 2 adds:

- **Plaguebearer:** on death → large persistent blight zone (15s). Room gets
  dangerous AFTER the elite dies.
- **Warded (elite-grade):** Ch2 mob mechanic, but ward REGENERATES after 10s.
  Must be re-broken.
- **Commanding:** all trash gains +15% damage while this elite lives.
  Kill-priority affix.
- **Volatile:** explodes on death (3s telegraph, heavy). Kite before killing
  blow. Punishes melee burst.

---

## VII. New Systems

### Healing Reduction — The Mid-Game Check

Debuts Ch12 (Thornfather Grael), standard tool thereafter.

- **Blight debuff:** −50% enemy healing received for 8s. Applied by per-class
  abilities (~12s cd) or environmental Blight Bomb arena pickups.
- **Per-class sources:** Warrior Rending Strike (bleed + Blight), Assassin
  Envenom, Paladin Holy Flame (Retribution auto-applies), Archer Blight Arrow
  (new ability), Mage Frost Shatter (proc also Blights), Warlock Wither (at
  5+ stacks).
- **Boss rule:** every Act 2+ boss with healing is balanced around Blight
  uptime — doable without (longer), designed for it.

### Difficulty Tiers

- **Nightmare (+20 levels):** unlocked per chapter after first clear. Same
  map, scaled stats. Loot floor rises one grade.
- **Torment (+40 levels):** unlocked after Nightmare clear. S-tier guaranteed
  from bosses. Elite density +50%. Bullet-hell density starts here.
- Each tier = separate PB/grade track in Records.

---

## VIII. Engine Toolbox — Build Once, Reuse

| Primitive | Debuts | Reused by |
|---|---|---|
| Healing reduction debuff (Blight) | Ch12 Thornfather | All Act 2+ healing bosses |
| Arena terrain shift mid-fight | Ch14 Waking Flux | Depths Waking Bosses |
| Living arena walls (grow/retreat) | Ch12 Rootweaver | Depths root rooms |
| Silence debuff (abilities disabled) | Ch13 Storm Word mobs | Ch13 finale, Depths |
| Player-ability tracking | Ch11 Aldric | Ch14 Echo (player-clone) |
| Mimic object (disguised enemy) | Ch9 Mimic mobs | Depths, cursed chest variant |
| Council fight framework | Ch10 Choir of Frost | Act 3 raids |
| Elevated terrain / verticality | Ch9 Gatewarden | Ch10 ice shelves, Ch14 ruins |
| Faction-divergent room swap | Ch8 (2 rooms) | Ch11 (4), Ch14 (2) |
| Mid-fight resonance choice | Ch9 Nursery | Ch10, Ch11, Ch14 |
| True Name mechanical bonus | Ch10 (Queen) | Ch12 (Root), Ch13 (Storm) |

### Build Order

1. **Boss Rush (The Crucible)** — cheapest mode, reuses boss.gd + one arena
2. **Waking Depths** — procedural rooms, rising difficulty, checkpoint bosses
3. **Difficulty Tiers** — Normal/Nightmare/Torment scaling, per-chapter unlock
4. **S-Weapon Awakening Quests** — per-class trials, founder ghosts
5. **Waking Incursions** — weekly chapter overlay, cross-domain mini-bosses
6. **Ch8 vertical slice** — full chapter, faction rooms, mob mechanics, rune drops
7. **Healing reduction system** — Blight debuff, per-class sources (before Ch12)
8. **Remaining chapters** — Ch9–14 in order
9. **True Name quest system** — +8% bonus, per-god-king flags, boss integration

---

> **The Act 2 thesis:** Act 1 taught you how to fight. Act 2 teaches you that
> fighting isn't enough — every seal you break, every vessel you kill, frees
> the thing you're trying to stop. The mechanics mirror the narrative: bosses
> that heal when you hit them, arenas that decay as you succeed, choices where
> mercy and cruelty both have costs. The player arrives at Act 3 with mastery,
> with a faction's trust, with three god-kings' true names — and with the
> knowledge that the Hollow Throne is calling. The question is whether they
> sit on it.
