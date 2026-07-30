# Gear Flavor — shared brief for all writers (READ FIRST)

Goal: **every acquirable item gets a lore-fitting flavor line.** This brief governs the six per-class
gear docs (WARRIOR/ARCHER/ASSASSIN/MAGE/PALADIN/WARLOCK.md) and BAGS_GEMS.md. Material flavor already
lives in PROPOSALS/MATERIALS.md; potion flavor in PROPOSALS/CONSUMABLE_GRADES.md — match their voice.

## The mandate (owner, 2026-07-29)
- **Not lazy.** Each line must FIT the item and MAKE SENSE in the world. No copy-paste templates, no
  interchangeable filler. A reader should feel the line was written for THAT piece.
- One line each, ~1 sentence (two short at most). Evocative, grounded, occasionally wry at low grades,
  weighty at the top. Same register as the material/potion S-uniques.

## Canon primer (verify against the sources below — do not invent contradictions)
- The realm fell when the **Ember Crown shattered**. The Crown is the **fifth binding instrument of the
  Concord** — the ancient pact whose seals hold back the god-kings. **Mórwyn** is the god-king of rot;
  her **blight** is the slow apocalypse, and the **Hollow Choir** is her cult (Morwen the Blightcaller
  took the goddess's name).
- **Vargoth** was the tyrant who wore the Ember Crown. **Aldric's** blow shattered it and scattered its
  shards — one into each bearer. A hero's power is a **fragment of Vargoth's will** (this matters for
  weapon/charm flavor especially).
- The **first Crown-fall was ~30 years ago**; the **Ember Guard** was the old royal order (Fangmaw was
  its beastmaster). The region is the **Vale/Ashvale**; the capital is **Crownfall**; the crafting/
  merchant faction is the **Accord** (Kesh's alchemists, Petra's forge).
- **Read for depth before writing:** `game/scripts/lore.gd` (enemy/boss lore), `game/scripts/story.gd`
  (chapters, the Crown, Aldric, Vargoth), `PROPOSALS/CHAPTER_OPENERS.md` + `PROPOSALS/ACT2_DESIGN.md`
  (the Concord, the five instruments, the falls). When unsure, prefer these over memory.

## Class identities (canonical — hold to them)
- **Warrior** (he/him): a soldier of the fallen kingdom; steel, banners, the last charge, discipline.
- **Archer** (she/her): a huntress of the wilds; wind, distance, patience, the Wildfang/beast world.
- **Mage** (she/her): an arcane scholar/archmage; stars, storms, runes, the deep arcane.
- **Paladin** (he/him): an oath-bound holy warrior; light, judgment, vows, the Choir-gone-wrong as foil.
- **Warlock** (he/him): a pact-bound curse-wielder; blood, hexes, the void, price-for-power.
- **Assassin** (they/them — neutral): a phantom of shadow and poison; silence, the first assassin's ghost.
- Use **they/them** for any person whose pronouns aren't established; never infer pronouns from a name.

## What each class doc covers (from game/scripts/items.gd)
Your class's items ONLY. Two kinds per slot:
1. **Generic shapes** — the 5 weapon shapes in `CLASS_WEAPONS[cls]` + the 5 shapes each for helmet/
   gloves/pants/armor/boots/charm in `CLASS_GEAR[cls]` (35 shapes total). Flavor is **per shape**, keyed
   by the shape's exact name (e.g. "Titan Helm", "Beastpelt", "Bloodpact Vestment"). One line, fitting
   the shape + the class's world. Grade is NOT part of generic flavor (a shape reads the same at any grade).
2. **Uniques** — every entry in `UNIQUES` where `"cls"` == your class (70: 35 A-grade + 35 S-grade,
   5 per slot × 7 slots). Flavor **keyed by the unique's exact name**, and it must FIT the unique's
   `passive` — look the passive up in `PROPOSALS/GEAR_UNIQUE_PASSIVES.md` (armor slots:
   `GEAR_ARMOR_UNIQUE_PASSIVES.md`) so the line echoes what the item DOES. S-uniques carry the heaviest
   lore (many are Crown-shard / god-king / Concord tier — lean in).

## Doc format (parseable — one row per item, name is the key)
Per slot, a Generics table then a Uniques table:

```
## Weapon
### Generic shapes
| Shape (key) | Flavor |
|---|---|
| Claymore | ... |

### Uniques
| Name (key) | Grade | Passive | Flavor |
|---|---|---|---|
| Crownfall, the Kingdom's End | S | kingsblade | ... |
```

Repeat for helmet, armor, gloves, pants, boots, charm. Keep names EXACT (copy from items.gd) — they are
the lookup keys the in-game display will use.

## Style examples (the bar)
- Generic — Claymore: "Too much sword for one man, which is exactly why the line broke where he swung it."
- Unique A — The Red Pennon: "Carried at the front of the last charge that still believed in the Crown; the banner is gone, the men who followed it are not."
- Unique S — Crownfall, the Kingdom's End: "The blade in the king's hands the moment he stopped being one; it has cut nothing smaller than a kingdom since."

## Hard rules
- Exact names as keys. Cover EVERY generic shape and EVERY unique for the class — no gaps.
- Fit the passive (uniques) and the shape+class (generics). Tie to canon where natural; never contradict it.
- Distinct lines only. If two read interchangeably, rewrite one.
- No copyrighted text, no song lyrics. Your own prose only.
