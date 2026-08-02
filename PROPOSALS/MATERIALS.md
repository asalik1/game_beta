# Crafting Materials — the five families, grade names, and the mob drop map (PROPOSAL)

Status: DRAFT v1, owner-approved structure + naming style (2026-07-29). Nothing installed.
Naming + drop companion to PROFESSIONS.md §4 (which owns the materials economy) and BOSS_LOOT.md
(boss chest materials). This doc owns only the material NAMES and the mob→material map.

## 1. The five families

| Family | Used by | Dropped by (body type) | Node source |
|---|---|---|---|
| **Metal** | Blacksmith — weapon, helmet | armored / construct / elemental mobs; undead scrap | ore seams |
| **Cloth** (cloth + leather) | Tailor — armor/pants/boots/bags; Alchemist — gloves | beasts, humanoids | fiber/hide clusters |
| **Bone** | Alchemist — charm | undead, beasts | (none — mob-only) |
| **Reagent** | Alchemist — potion *active* | most mobs (gland/venom/essence) | (none — mob-only) |
| **Herb** | Alchemist — potion *base* | plant/fungal mobs | growth clusters |

- **Grade scales with the source's act/tier:** Act 1 → F/E, Act 2 → D/C, Act 3 → B/A. **Mob and node
  materials cap at A** — **S-grade materials come only from a boss's Gold supply chest** (BOSS_LOOT.md).
  So every family's S entry exists but is boss-only.
- **Ungated** (PROFESSIONS §4): you always get the material a source yields by type; use it if your trade
  wants it, else discard/sell. Only nodes are trade-gated.

## 2. Grade name ladders + flavor (F→S)

F/E read as junk, D as the common working stock, C/B as good, A as the master grade, S as the unique
legend. Flavor hooks canon (the Ember Guard, the Vale, the Choir, the Concord's seals, the blight, the
first Crown-fall) — no copy-paste templates, same rule as the potion shelf.

### Metal — Blacksmith (weapon, helmet)
| Grade | Name | Flavor |
|---|---|---|
| F | Rusted Scrap | Corroded plate pried off the fallen. It remembers being armor, barely. |
| E | Pitted Iron | Pig-iron with the slag still in it. Holds an edge for one good swing. |
| D | Plain Ingot | Honest soldier's steel — the metal the Ember Guard marched in. |
| C | Tempered Steel | Folded and quenched proper. A smith will nod at this. |
| B | Fine Steel | Blue-sheened and true — the bar a master reaches for without looking. |
| A | Mastercrafted Alloy | Alloyed to a recipe two generations refined and one smith died guarding. |
| S | Starforged Ingot | Metal that fell burning the night the first Crown broke. It has never once rusted. |

### Cloth — Tailor (armor/pants/boots/bags), Alchemist (gloves)
| Grade | Name | Flavor |
|---|---|---|
| F | Frayed Scraps | Rag-ends off a dead man's hem. Sewn together, they cover something. |
| E | Coarse Cloth | Homespun, itchy, warm enough. Half the Vale is dressed in it. |
| D | Plain Bolt | A clean bolt of undyed weave — the tailor's daily bread. |
| C | Tanned Weave | Hide worked soft or linen woven tight; either takes a stitch well. |
| B | Fine Silk | Thread so fine it whispers. The capital's seamsters hoard it. |
| A | Gilded Weave | Cloth shot through with drawn gold, light as breath and twice as dear. |
| S | Moonweave | Spun, they say, on a loom that only turns by moonlight. No needle has ever torn it. |

### Bone — Alchemist (charm)
| Grade | Name | Flavor |
|---|---|---|
| F | Cracked Bone | Splintered and grey. The graves give up so many it's barely worth stooping for. |
| E | Bleached Bone | Sun-scoured clean. Holds a carved sigil if your hand is steady. |
| D | Whole Bone | Unbroken and sound — the charm-maker's working stock. |
| C | Runed Bone | Already scored with an old ward-mark. Half the work is done, if you trust who did it. |
| B | Blessed Relic | Bone of someone the Choir once called holy, before the Choir went wrong. |
| A | Saintbone | A true saint's finger, they swear. It stays warm in a cold room. |
| S | Concordium Relic | A shard of the Concord's seal-keepers, interred with the fifth binding. It hums near the blight. |

### Reagent — Alchemist (potion active)
| Grade | Name | Flavor |
|---|---|---|
| F | Foul Residue | Scraped from something's gland. It reeks, and it works, a little. |
| E | Crude Extract | Boiled down in a field pot. Cloudy, sharp, unreliable. |
| D | Clean Extract | Filtered twice — a journeyman's honest reagent. |
| C | Potent Essence | Distilled to a bright, biting clarity. The working alchemist's staple. |
| B | Pure Essence | Not a mote of dross left in it. It glows faintly in the dark. |
| A | Radiant Essence | So concentrated it warms the vial. A master measures it by the single drop. |
| S | Quintessence | The fifth essence — what the old alchemists chased, and mostly died pretending to have found. |

### Herb — Alchemist (potion base)
| Grade | Name | Flavor |
|---|---|---|
| F | Wilted Sprig | Half-dead already. Steeps into something bitter and weak. |
| E | Common Weed | Roadside green, plucked by the fistful. Every remedy starts here. |
| D | Fresh Herb | Cut this morning, still holding its scent — the daily base of every brew. |
| C | Verdant Herb | Grown deep where the soil never soured. Rich, green, potent. |
| B | Rare Bloom | Flowers a week a year in places the blight hasn't reached. Gather fast. |
| A | Pristine Bloom | Perfect, unblemished, glowing with its own faint life. A master's prize. |
| S | Sunpetal | A blossom that turns to face a sun it remembers from before the ash. Rarer than an honest king. |

## 3. Mob → material drop map

Each mob drops its body-type material(s); grade = the mob's act band (§1). **Bold = Act 1, built.**
Elites of the same type drop the same families, one grade higher (PROFESSIONS §4).

### Beasts → Cloth + Reagent
**wolf (Blighted Wolf), spider (Marsh Spider), bat (Cave Bat), direbat (Blightbat)**, blightwolf
(Waking Wolf), bogspider (Greyrun Lurker), duneprowler (Dune Prowler), winterfang, storm_harrier, kraken

### Humanoids / cultists → Cloth + Reagent
**cultist (Blight Cultist)**, stormcult (Choir Cantor), beastkin_raider (Wildfang Raider),
beastkin_howler (Wildfang Howler), wildkin_ranger, null_acolyte, forge_acolyte, bloom_acolyte,
cold_pilgrim, hushcaller, static_caller, vow_sentinel

### Undead → Bone + Metal (scrap)
**skeleton (Hollow Soldier), zombie (Risen Corpse)**, sun_bleached (Sun-Bleached Husk),
frost_husk (Frost-Bound Soldier), gravewalker, barrow_wight, vale_mourner, casket_creeper,
bloated_dead, grave_cutter, frozen_guard, great_spirit (Hollow Revenant)

### Construct / elemental → Metal
slag_core (Cold Slag Core), cinder_whelp, slag_brute, flame_giant (Cinder Colossus),
cyclops (Cyclopean Horror), deep_stalker (Crystal Stalker), tengu (Crimson Tengu)

### Plant / fungal → Herb
sporeshambler (Spore Shambler), root_shambler, bog_lurker, grove_horror

### Void / aberration → Reagent (essence)
void_husk (Voidbound Husk), void_shade, ooze (Devouring Ooze), null-touched variants

## 4. Notes

- **Two-material droppers** (beasts, humanoids, undead) roll one or the other per drop, not both at once —
  which one is a weighted per-drop roll, so the family you want still takes farming.
- **Bosses** don't use this map — their gear/gems/materials come via BOSS_LOOT.md chests (the Gold chest
  is the sole S-material source).
- **Herbs and Reagents are potion inputs** (CONSUMABLE_GRADES §11): a recipe needs a Herb base + a Reagent
  active; the higher of the two roughly sets the potion grade.
- **Metal has two mob sources** (construct/elemental primary, undead scrap secondary) — undead scrap rolls
  a grade lower than a construct of the same act (armor rust, not fresh ore).
- Open: exact per-family names are red-pennable (esp. the five S uniques: Starforged Ingot / Moonweave /
  Concordium Relic / Quintessence / Sunpetal); whether Herb should also drop from a few beast-adjacent
  grazers; per-drop weighting between a two-material mob's two families.
