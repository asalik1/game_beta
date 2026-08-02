# Playable Class Base Sprite Design Review

**Decision date:** 2026-07-30  
**Scope:** Warrior, Archer, Mage, Assassin, and Warlock base character
designs after acceptance of the regenerated Paladin, the **Oathbound
Arbiter**.

This review deliberately separates three different questions:

1. **Character design:** Is the underlying costume, silhouette, palette, and
   equipment appropriate for the class's lore?
2. **Rendering quality:** Is the sprite drawn at sufficient clarity and source
   density?
3. **Animation quality:** Are directions, poses, equipment, and movement
   coherent across frames?

The decisions below concern **character design only**. A class whose design is
being kept may still need a complete sprite-sheet regeneration to bring its
rendering and animation up to the Paladin's standard.

## Lore standard

The playable characters are not generic fantasy professions. Each is carrying
a particular Ember inheritance and temptation:

| Class | Ember and narrative conflict |
|---|---|
| Warrior | Vargoth's inheritance. Protection versus tyranny: strength used to protect can become control. |
| Archer | Fangmaw's inheritance. Freedom versus severance: escaping obligation can become the destruction of every bond. |
| Mage | Mórwyn's inheritance. Clarity versus cruelty: the healer's drive to perfect a cure can make people into experiments. |
| Assassin | The erased founder's inheritance. Sacrifice versus consumption: survival bought by taking warmth, strength, or life from others. |
| Warlock | A borrowed Ember and an outside pact. Accountability versus the debt spiral: borrowing more power to repair the consequences of the last borrowing. |

A successful base design must communicate some part of that conflict while
remaining neutral enough to support all three gameplay themes. The base
character should not look permanently locked to Fury, Ice, Shadow, Curse, or
another single build.

## Final decisions

| Class | Decision | Regeneration treatment |
|---|---|---|
| Mage | **Approved** | Blighted Healer anchor preserves design and removes Ice lock |
| Archer | **Approved** | Severed-Thread Ranger with physically correct bow and grip |
| Assassin | **Approved** | Erased Name anchor preserves silhouette and adds Crownless identity |
| Warlock | **Approved** | Ledgerbound Debtor with closed tethered hip ledger and clean ink-marked hand |
| Warrior | **Approved** | Emberbound Heir with canonical self-restraint helm |

## Mage — keep

### Why the design works

The Mage's intended design is one of the strongest of the five. The white hair,
white healer's robes, exposed face, green-black lower layers, worn hem, and
restrained staff fit a former healer carrying Mórwyn's legacy. The clean outer
layer and contaminated under-layer naturally express the class conflict:
clarity and care above, perfection curdled into blight beneath.

The high-resolution class splash communicates this more successfully than the
current runtime sprite. The runtime sprite simplifies the character into a
pristine white-and-gold ice wizard and loses much of the staining, decay, and
failed-healer history. That is a translation failure, not a bad design.

### Preserve

- White hair and visible face
- White healer's outer robes
- Green-black contamination beneath the clean layers
- Elegant staff and tall caster silhouette
- Calm, controlled, exacting demeanor
- The contrast between medical purity and spreading blight

### Refine during regeneration

- Restore the stained and decaying under-robe visible in the splash
- Make the failed green healing light a restrained recurring accent
- Add a small journal, remedy pouch, or field-healer satchel
- Replace the strongly ice-coded blue crystal with a theme-neutral focus
- Keep Fire, Ice, and Wind identities in the ability effects rather than
  permanently baking one of them into the base costume

### Boundary

Do not invent a new Mage. Regenerate the existing healer-blight concept
faithfully and make the sprite sheet carry the same story as the splash.

## Archer — keep

### Why the design works

The Archer already presents a coherent grounded identity. The fur mantle
subtly connects her to Fangmaw, while the weathered green cloak, practical
leather, visible face, simple bow, and travel gear support a character defined
by distance, freedom, and severed relationships.

She looks capable of watching a home from a ridge without entering it. That is
an unusually good match for the class opening and later story material.

### Preserve

- Fur shoulder mantle
- Forest-green cloak
- Practical layered leather
- Brown hair and visible face
- Simple wooden bow and quiver
- Grounded, non-magical base appearance
- Mobile skirmisher silhouette rather than a stationary sniper

### Refine during regeneration

- Improve fidelity, material separation, and directional consistency
- Keep the bow's construction and size identical in every direction
- Preserve the cloak's broad readable shape without letting it swallow the
  legs
- Use Storm, Venom, and Hunt color language in effects, not the base costume

### Boundary

Do not redesign the Archer's costume. This is a faithful higher-resolution
recreation and animation rebuild.

## Assassin — refine

### Why the foundation works

The empty hood is appropriate for a class descended from a founder whose name
was erased. The narrow body, divided cloak, sparse armor, and blade-forward
silhouette communicate speed and anonymity immediately.

The weakness is specificity. At present the character is very close to the
default fantasy image of a faceless black rogue. The design says "assassin,"
but not yet "Crownless Assassin carrying an Ember that survives by taking."

### Preserve

- Empty, unidentified face
- Hood and lean silhouette
- Long divided cloak
- Predominantly dark palette
- Light armor and unrestricted legs
- Restrained visual language; this class should not become ornate

### Refine

- Give the main Stab weapon a visibly longer profile
- Reserve smaller knives for Fan of Knives instead of treating every blade as
  interchangeable
- Add restrained dried-blood or Ember-red bindings
- Introduce one erased insignia, cut-away nameplate, or deliberately blank
  clasp as the unique identity hook
- Improve value separation between body, cloak, arms, and weapons
- Let the consumption theme appear as a subtle consequence, not constant
  smoke or an oversized magical aura

### Boundary

Do not replace the Assassin's overall silhouette. The refinement succeeds when
the character remains immediately recognizable but can no longer be mistaken
for an unrelated stock rogue.

## Warlock — approved redesign

### Why the current design misses

The living tome is correct and should remain the centerpiece. The floating
skull, purple fire, black hood, and gold occult robes otherwise read primarily
as a conventional necromancer.

The Warlock's actual fantasy is more distinctive: a person carrying a
self-writing debt contract, borrowing power from something outside the world,
and no longer knowing precisely what has already been pledged. The current
skull distracts from the concepts of debt, accountability, collateral, and
compounding obligation.

### Preserve

- The tome as the primary carried object
- Black and aged-gold as the broad palette
- A hooded scholarly silhouette
- An unsettling magical presence
- Enough exposed humanity to show that the pact is happening to a person

### Replace or rethink

- Remove the generic floating skull from the base design
- Replace generic purple flame with self-writing script, ink, seals, or
  restrained light leaking from contractual marks
- Make the tome visibly chained, strapped, clasped, or otherwise impossible to
  discard casually
- Use countersigns, tally marks, cut contract ribbons, and rewritten pages as
  the visual vocabulary
- Show one collateralized part of the wearer: a marked hand, altered shadow,
  missing reflection, claimed voice, or another singular readable cost
- Keep Curse, Pact, and Void as effect families; the base design represents
  the debtor who can enter any of them

### Boundary

The approved replacement is the **Ledgerbound Debtor** in
`art_src/warlock_base_redesign/05_ledgerbound_debtor_clean_hand.png`. The
ledger remains closed and tethered at the left hip during neutral movement,
then is drawn and opened for casting. The floating skull is removed. The
branching contract ink communicates the cost without placing a wax seal on the
hand, where it read as a button at sprite scale.

## Warrior — redesign

### Why the current design misses

The molten black knight is visually powerful, but it reads as an endgame boss,
a permanently corrupted Fury skin, or a servant of the setting's central
villain. It does not express the base Warrior's conflict between protection and
tyranny.

The character's story includes destructive blackouts followed by years of
careful physical work: fences, wells, timber, and deliberately controlled
strength. A permanently blazing suit of monstrous plate presents the
temptation as already completed. It also competes with the Paladin's heavy
armor instead of establishing a different melee identity.

### Preserve

- Broad and physically imposing build
- Grounded melee presence
- A distinctive sword; the sword is mandatory for the base design
- Strong readable stance
- The sense that extraordinary force is always available

### Replace or rethink

- Replace molten raid-boss armor with battered, practical protection
- Show the laborer history through repaired straps, work gloves, worn cloth,
  tool marks, or an axe that could once have been used for honest work
- Leave at least part of the face visible so the player reads as a person
  resisting the Ember
- Confine Ember corruption to one scar, gauntlet, weapon seam, or repaired
  armor break
- Place the signature restraint idea in the sword, its guard/scabbard, or the
  sword arm rather than relying on generic armor
- Make the default stance controlled and protective rather than permanently
  berserk
- Distinguish the Warrior from the Paladin: utilitarian asymmetry and bodily
  strength versus judicial regalia, shield, chain, and hammer
- Keep Fury, Bulwark, and Earth as gameplay expressions rather than making the
  base costume look permanently Fury-aligned

### Boundary

This requires another Paladin-style concept pass. The first three replacement
concepts were rejected: two lacked the mandatory sword, while the remaining
armored swordsman read as a generic NPC. They are retained under
`backup/class_drafts/warrior_base_rejected_2026-07-30_npc_material/`. Preserve
the body type, not those costumes. The successful replacement should look like
someone capable of terrible force who has spent years learning not to use all
of it, and it must read unmistakably as a player hero.

A fourth attempt, **The Restrained Blade**, added the mandatory sword and a
strong containment device but still read as an elite NPC because its practical
brigandine and long veteran's coat controlled the silhouette. It is retained
under
`backup/class_drafts/warrior_restrained_blade_2026-07-30_elite_npc_material/`.
The active direction now evolves the original iconic black-iron greatsword
Warrior: open the face, remove the raid-boss helmet, reduce Ember corruption to
the sword fuller and one forearm scar, and preserve an exaggerated
player-character silhouette instead of grounding the design into another
soldier.

Owner review of the open-faced evolution found that its square-jawed masculine
face overlapped the accepted Paladin's identity. The active variant restores a
fully enclosed, unlit black-iron helmet while keeping one arm exposed and the
armor asymmetric. This treats the helmet as deliberate personal containment:
the intimidation belongs to the Warrior, while the absence of glowing eyes,
all-over Ember cracks, royal ornament, and excessive armor bulk prevents the
design from reverting to an endgame boss.

The owner approved this restrained-helmet design on 2026-07-31. Its meaning is
now canonical: the helmet is self-imposed restraint rather than Vargoth
regalia—the face the Warrior chooses because he does not trust what happens
when his memory goes dark.

## Production order

Design work and sprite production should proceed in this order:

1. **Warrior:** full concept redesign, then full regeneration
2. **Warlock:** full concept redesign, then full regeneration
3. **Assassin:** focused design refinement, then full regeneration
4. **Mage:** faithful design translation and full regeneration
5. **Archer:** faithful higher-fidelity full regeneration

This order is about design need, not merely current sprite sharpness. The Mage
may be regenerated earlier for animation reasons, but it does not require a new
character concept.

## Shared acceptance criteria

Before any full sheet is installed:

- The selected design must read as its class without ability effects
- At least one feature must connect directly to the class-specific lore
- The base costume must remain compatible with all three gameplay themes
- Its silhouette must remain distinct from the other five classes
- All eight rotations must preserve the same equipment, proportions, palette,
  handedness, and identifying feature
- Carried equipment must have an explicit continuity rule for idle, walk, run,
  attacks, abilities, and death
- Rendering quality and animation quality must be reviewed separately from
  whether the underlying design is good

## Paladin precedent

The accepted Oathbound Arbiter is the benchmark for this process:

- Lore was evaluated before generation
- Three base concepts were compared
- One identity was selected and locked
- Rotations were authored before animation production
- Directional animations were built and reviewed as families
- Equipment continuity, foot alternation, facing, and final-frame recovery
  received explicit QA

The reusable technical workflow is documented in
`tools/art/IMAGEGEN_SPRITE_PIPELINE.md`. This document owns the design
decisions for the remaining five base classes.
