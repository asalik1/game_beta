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

## 2. Grade name ladders (F→S)

| Grade | Metal | Cloth | Bone | Reagent | Herb |
|---|---|---|---|---|---|
| **F** | Rusted Scrap | Frayed Scraps | Cracked Bone | Foul Residue | Wilted Sprig |
| **E** | Pitted Iron | Coarse Cloth | Bleached Bone | Crude Extract | Common Weed |
| **D** | Plain Ingot | Plain Bolt | Whole Bone | Clean Extract | Fresh Herb |
| **C** | Tempered Steel | Tanned Weave | Runed Bone | Potent Essence | Verdant Herb |
| **B** | Fine Steel | Fine Silk | Blessed Relic | Pure Essence | Rare Bloom |
| **A** | Mastercrafted Alloy | Gilded Weave | Saintbone | Radiant Essence | Pristine Bloom |
| **S** | Starforged Ingot | Moonweave | Concordium Relic | Quintessence | Sunpetal |

- F/E read as junk, D as the common working stock, C/B as good, A as the master grade, S as the unique
  legend (lore-tied: Concordium Relic → the Concord's seals; the others evocative).

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
