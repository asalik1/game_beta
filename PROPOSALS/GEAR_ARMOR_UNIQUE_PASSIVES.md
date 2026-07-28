# PROPOSALS — Armor + gear unique passives (helmet/gloves/pants + armor/boots/charm)

**Status (2026-07-27, final): SHIPPED — all 360 gear uniques live.** The art
pass delivered names + icons for the §5b armor family (180) AND the migrated
armor/boots/charm matrix slots (180 more); every row is in `Items.UNIQUES`
with a live bespoke passive (verb + class beat; ids
`<cls>_<slot>_<profile><lane>`, knobs in `Balance.UNIQ`, beats run by the
engine's beat executor). The named drop channel is slot-generic, so all six
gear slots drop their uniques at the weapon gates (named A Act 2+, named S
Act 3+). Owner call honored throughout: **bespoke per unique** on the shared
verb library. FIRST-WIRE SIMPLIFICATIONS: a handful of catalog clauses
shipped as their nearest engine primitive (marked-prey/pierce/full-Meteor
riders on a few S rows read plainer in Balance than the §4 prose — the
bench phase trues them up); every card line matches what actually fires.
**DPS-BENCH PASS RAN 2026-07-27** (round narrative: BALANCE_HISTORY.md top):
two wiring gaps found and fixed — the unweave S-lanes' "shredx" beat was
declared but NO engine site ever fired it (replaced by an honest data
mechanic: S tears STACK to a `cap` of 2x, card lines rewritten), and the six
`*_charm_Ea` BARGAIN sustain taxes (verb helm_bulwark) were never charged
(recalc + mage Nova now read both bulwark verbs). Magnitudes were measured
BiS-loadout-vs-L100-finale; survivors kept their placeholder values (they
priced sanely under the new GEAR-ramp curve).

Companion to `PROPOSALS/GEAR_UNIQUE_PASSIVES.md` (the shipped weapon pass,
2026-07-27). The A/S framework carries over unchanged: **S = full effect; A =
LESSER (~60–70% / narrower trigger) or BARGAIN (S-power with a printed
drawback that taxes the META build harder than the shape's own build).**
Standing rules likewise: movement speed sovereign (pants especially — see
§2), gem-only specials untouched, crit earned not granted, no silent effects,
placeholders marked.

---

## 1. The stacking doctrine — the decision that shapes everything

The weapon pass never faced this: weapons are exclusive, so its 60 passives
can each be a signature. Armor is not exclusive — helmet + gloves + pants
stack **three named passives on top of the weapon's**, and once chest/boots/
charm migrate, a full named loadout wears **seven**. Seven weapon-grade
signatures would be seven rotations — unreadable and untunable.

Doctrine proposed (three rules):

1. **The weapon is the sentence; armor is a clause.** Armor passives never
   add a new rotation beat. They are triggers-that-support: wards, counters,
   riders, floors, windows. Power tier per piece ≈ the slot's main-budget
   tier (helmet/pants 2.5 "solid" > gloves 2.0 "minor" — gloves passives run
   ~20% leaner).
2. **BESPOKE, not templates (owner call, 2026-07-27 — supersedes this doc's
   first-pass template recommendation).** All **180 passives are individually
   designed**, one per unique, exactly like the weapon 60: each expresses its
   shape's profile *through its class's kit* (a warrior guard-helmet blunts
   crits INTO Grit; a mage one blunts them INTO mana). Legibility is kept a
   different way: every bespoke design is built from the shared **verb
   library** (§3 — the wired engine mechanics and their ICD families), so
   180 identities ride ~a dozen tested systems, the same way the weapon 60
   ride the hook library. §4 is the full catalog.
3. **Proc governance — ICD families across the loadout.** Every proc
   template belongs to a family with ONE shared internal cooldown on the
   player, exactly like the shipped `evade_icd`:
   - `evade_icd` (exists) — **one evade proc per window across the whole
     loadout, weapon first.** An armor evade clause only fires when the
     weapon didn't — so a finesse weapon + finesse armor do not machine-gun,
     and armor evade clauses matter MOST on non-finesse weapons (a built-in
     diversity incentive, not a nerf).
   - `struck_icd` (new) — the on-hit-taken family (counters, thorns,
     surges): one proc per window, weapon first, then helmet > pants >
     gloves.
   - Passive-state templates (stat floors, standing wards, riders) don't
     proc and stack freely — they're budgeted by magnitude instead.

---

## 2. Slot domains — what each new slot is ABOUT

So stacked clauses read as one body, each slot owns a mechanical domain; all
five of its profile templates live inside it:

| Slot | Domain | Beats it may touch | Never |
|---|---|---|---|
| **Helmet** — the head | perception, will, warding | openers/first-reads, anti-crit, anti-magic wards, focus states | rotations |
| **Gloves** — the hands | delivery | riders on hits you land, basic-cadence seasoning, shred | new attacks |
| **Pants** — the base | footing, stance | answers to being hit/CC'd, floors, commit-windows after mobility | movement speed, EVER (sovereign) |

---

## 3. The verb library (WIRED 2026-07-27 — the engine behind §4)

The armor-passive ENGINE shipped ahead of the items: `uniq_armor` (the
equipped non-weapon passive cache), the `struck_icd` proc family (weapon
procs stamp it; armor clauses require it clear — weapon-first, then
helmet > pants > gloves), the armor lane of the shared evade ICD, and these
verbs, each live in code and suite-covered:

| Verb | Mechanic (where) |
|---|---|
| magic ward | typed magic-DR window on being hit (`uniq_mward_*`, take_damage) |
| unweave | res_shred rider on your hits (shipped enemy clock) |
| grounded | incoming slow/root/freeze duration × `uniq_cc_mult` (apply_freeze/root/chill) |
| blunt | first enemy crit per icd sheds its bonus (take_damage resolve) |
| iron answer | melee counter-strike on being hit (struck family) |
| anchor | Grit-style flat-DR stacks from blows taken (`uniq_guard_*`) |
| expose | evade marks the attacker EXPOSED (evade family, weapon-first) |
| true-aim | every Nth basic cannot miss or graze (eva-0 resolve, `uniq_gcount`) |
| slip | being hit grants a Tumble-rail evasion surge (struck family) |
| opener | first hit on unwounded prey amplified (hit_enemy mod chain) |
| tear | crits leave a class-typed dot (hit_enemy follow-up) |
| advance | COMMIT ability arms a next-damaging-cast window (use_ability; paladin = the Judgment leap, gated on it firing) |
| pool | overheal → shield on the Transfusion rail (recalc) |
| grip | flat per-hit damage from max HP (`uniq_hit_flat`) |
| bastion | below-threshold standing DR floor (take_damage mitigation) |

The 30 `helm_/glove_/pants_*` ids currently in `Balance.UNIQ`/`Items.PASSIVES`
are this library's ENGINE STAND-INS (dev-injectable, suite-tested). No item
ever drops with them; the 180 bespoke ids of §4 replace them at item wiring,
each composing these verbs plus its own class beat. Magnitudes everywhere are
placeholders for the dps-bench phase.

## 4. The 180 bespoke passives — the catalog

Wiring ids are STRUCTURAL: `<class>_<slot>_<profile><lane>` (e.g.
`warrior_helmet_Bs` = the warrior guard-helmet's S unique). Names and art
come from the art pass; ids are stable now so wiring is mechanical. Every
row: **A lane first, S lane second** — A is LESSER unless marked BARGAIN
(its printed cost chosen, as always, to tax the META build harder than the
build the shape serves). Verbs in *italics* are §3 engine mechanics; the
rest of each sentence is that item's bespoke class beat (wired per-id at
item time). All magnitudes placeholders.

One bespoke dividend up front: a template-model BARGAIN like "Second Wind
never triggers" is a dead cost on the four classes without Second Wind —
bespoke lets each class pay in ITS OWN sustain (warrior: Grit regen;
assassin: Elusive regen; mage: Nova's restore; paladin: Holy-stance mend;
warlock: Soulthirst lifesteal).

### Warrior — the grind feeds him

| Slot | Shape (profile) | A unique | S unique |
|---|---|---|---|
| helmet | Wardsteel Helm (ward) | *magic ward* 15% | *magic ward* 30%, and the warded blow still builds a GRIT stack — spellfire feeds the grind |
| helmet | Ironwall Helm (guard) | *blunt* half | *blunt* full, and the blunted blow grants a free Grit stack |
| helmet | Skirmisher's Helm (finesse) | *expose* 1.5s | *expose* 3s, and the dodge refunds 1.5s of Whirlwind |
| helmet | Reaver Helm (aggressor) | *opener* +15% | *opener* +25%, and an opening Cleave staggers |
| helmet | Titan Helm (bulwark) | *pool* 4% | *pool* 8%, and Berserk's lifesteal overflow pools at double rate |
| gloves | Wardsteel Gauntlets (ward) | *unweave* small | *unweave*, and Shield Bash tears the ward twice as wide |
| gloves | Ironwall Gauntlets (guard) | *iron answer* 15% | *iron answer* 25%, and the counter-cut staggers |
| gloves | Skirmisher's Gauntlets (finesse) | *true-aim* every 8th Cleave | every 5th, and the sure cut's knockback doubles |
| gloves | Reaver Gauntlets (aggressor) | *tear* 0.10 | *tear* 0.15, and Whirlwind crits tear twice |
| gloves | Titan Gauntlets (bulwark) | *grip* lesser | *grip*, doubled while Berserk runs |
| pants | Wardsteel Legplates (ward) | BARGAIN: *grounded* 50%, −10% healing received | *grounded* 30%, and shaking off a CC grants a Grit stack |
| pants | Ironwall Legplates (guard) | *anchor* 2 stacks | *anchor* 3, and at full stacks Shield Bash's stun runs +0.5s |
| pants | Skirmisher's Legplates (finesse) | BARGAIN: deeper *slip*, Grit regen −0.2%/s | *slip*, and Whirlwind cast while slippery strikes +20% |
| pants | Reaver Legplates (aggressor) | *advance* +12% (commit: Shield Bash) | *advance* +20%, and an advanced Whirlwind drags enemies inward |
| pants | Titan Legplates (bulwark) | BARGAIN: *bastion* 25%, but Grit regen halved | *bastion* 15%, and below the threshold Grit's cap rises +2 |

### Archer — spacing is the sustain

| Slot | Shape (profile) | A unique | S unique |
|---|---|---|---|
| helmet | Stormweave Hood (ward) | *magic ward* 15% | *magic ward* 30%, and a warded hit does not reset Second Wind's clock |
| helmet | Studded Hood (guard) | *blunt* half | *blunt* full, and the blunted attacker is EXPOSED |
| helmet | Ranger's Hood (finesse) | *expose* 1.5s | *expose* 3s, and the dodge ticks the hunt rhythm by one |
| helmet | Hunter's Hood (aggressor) | *opener* +15% | *opener* +25%, and an opening Quick Shot cannot miss |
| helmet | Beastpelt Hood (bulwark) | *pool* 4% | *pool* 8%, and Second Wind's overshoot pools too |
| gloves | Stormweave Bracers (ward) | *unweave* small | *unweave*, and Multishot tears every victim |
| gloves | Studded Bracers (guard) | *iron answer* 15% | *iron answer* 25% as a point-blank arrow that shoves the attacker back |
| gloves | Ranger's Bracers (finesse) | *true-aim* every 8th | every 5th, and the sure arrow PIERCES |
| gloves | Hunter's Bracers (aggressor) | *tear* 0.10 | *tear* 0.15, deeper on EXPOSED prey |
| gloves | Beastpelt Bracers (bulwark) | *grip* lesser | *grip*, and Arrow Storm arrows each carry half of it |
| pants | Stormweave Leggings (ward) | BARGAIN: *grounded* 50%, −10% healing received | *grounded* 30%, and a shrugged CC refunds 1s of Tumble |
| pants | Studded Leggings (guard) | *anchor* 2 stacks | *anchor* 3, and at full stacks Second Wind's delay drops 0.5s |
| pants | Ranger's Leggings (finesse) | BARGAIN: deeper *slip*, Second Wind waits +0.5s | *slip*, and Tumble rolled while slippery re-arms its perfect window |
| pants | Hunter's Leggings (aggressor) | *advance* +12% (commit: Tumble) | *advance* +20%, and an advanced Multishot fans one extra arrow |
| pants | Beastpelt Leggings (bulwark) | BARGAIN: *bastion* 25%, Second Wind never triggers | *bastion* 15%, and below the threshold Tumble returns 1s sooner |

### Assassin — the blood pays forward

| Slot | Shape (profile) | A unique | S unique |
|---|---|---|---|
| helmet | Shadowveil Cowl (ward) | *magic ward* 15% | *magic ward* 30%, and a warded hit keeps the blood surge alive +0.5s |
| helmet | Warded Cowl (guard) | *blunt* half | *blunt* full, and the blunted attacker takes a 0.4x riposte-cut |
| helmet | Gossamer Cowl (finesse) | *expose* 1.5s | *expose* 3s, and the dodge extends a live Death Mark's amp window 0.5s |
| helmet | Nightsilk Cowl (aggressor) | *opener* +15% | *opener* +25%, and an opening Stab arms the blood surge instantly |
| helmet | Grave Cowl (bulwark) | *pool* 4% | *pool* 8%, and surge-lifesteal overflow pools |
| gloves | Shadowveil Grips (ward) | *unweave* small | *unweave*, and every Fan knife tears its own thread |
| gloves | Warded Grips (guard) | *iron answer* 15% | *iron answer* 25%, and a landed counter feeds the blood surge |
| gloves | Gossamer Grips (finesse) | *true-aim* every 8th Stab | every 5th, and the sure Stab's surge runs +1s |
| gloves | Nightsilk Grips (aggressor) | *tear* 0.10 | *tear* 0.15, ticking double on MARKED prey |
| gloves | Grave Grips (bulwark) | *grip* lesser | *grip*, doubled while the blood surge runs |
| pants | Shadowveil Wraps (ward) | BARGAIN: *grounded* 50%, −10% healing received | *grounded* 30%, and a shrugged CC refunds 1s of Shadow Dash |
| pants | Warded Wraps (guard) | *anchor* 2 stacks | *anchor* 3, and full stacks harden Elusive +5% evasion |
| pants | Gossamer Wraps (finesse) | BARGAIN: deeper *slip*, Elusive regen −0.4%/s | *slip*, and dashing through a foe while slippery refreshes it |
| pants | Nightsilk Wraps (aggressor) | *advance* +12% (commit: Shadow Dash) | *advance* +20%, and an advanced Fan of Knives converges |
| pants | Grave Wraps (bulwark) | BARGAIN: *bastion* 25%, Elusive regen halved | *bastion* 15%, and below the threshold the blood surge never expires |

### Mage — the arcane meters everything

| Slot | Shape (profile) | A unique | S unique |
|---|---|---|---|
| helmet | Silkward Circlet (ward) | *magic ward* 15% | *magic ward* 30%, and the warded hit refunds 5 mana |
| helmet | Runeplate Circlet (guard) | *blunt* half | *blunt* full, and the blow refunds 1s of Blink |
| helmet | Featherweave Circlet (finesse) | *expose* 1.5s | *expose* 3s, and the dodge grants 10 mana |
| helmet | Starweave Circlet (aggressor) | *opener* +15% | *opener* +25%, and an opening Firebolt cracks the ward (one shred stack) |
| helmet | Earthen Circlet (bulwark) | *pool* 4% | *pool* 8%, and Frost Nova's restore overflow pools |
| gloves | Silkward Handwraps (ward) | *unweave* small | *unweave*, and Frost Nova tears everything it catches |
| gloves | Runeplate Handwraps (guard) | *iron answer* 15% | *iron answer* 25% as an arcane snap that also CHILLS the attacker |
| gloves | Featherweave Handwraps (finesse) | *true-aim* every 8th Firebolt | every 5th, and the sure bolt echoes at 25% |
| gloves | Starweave Handwraps (aggressor) | *tear* 0.10 | *tear* 0.15, deeper on ward-cracked prey |
| gloves | Earthen Handwraps (bulwark) | *grip* lesser | *grip*, and it rides Meteor at full weight |
| pants | Silkward Underleggings (ward) | BARGAIN: *grounded* 50%, −10% healing received | *grounded* 30%, and a shrugged CC restores 5% of missing mana |
| pants | Runeplate Underleggings (guard) | *anchor* 2 stacks | *anchor* 3, and full stacks deepen Blink's Arcane Ward +10% |
| pants | Featherweave Underleggings (finesse) | BARGAIN: deeper *slip*, Nova's restore −5% | *slip*, and Blink's shock strikes +20% while slippery |
| pants | Starweave Underleggings (aggressor) | *advance* +12% (commit: Blink) | *advance* +20%, and an advanced Frost Nova roots 0.5s |
| pants | Earthen Underleggings (bulwark) | BARGAIN: *bastion* 25%, Nova's restore halved | *bastion* 15%, and below the threshold Nova's restore doubles |

### Paladin — the stance decides

| Slot | Shape (profile) | A unique | S unique |
|---|---|---|---|
| helmet | Blessed Greathelm (ward) | *magic ward* 15% | *magic ward* 30%, and the warded blow banks holy charge |
| helmet | Templar Greathelm (guard) | *blunt* half | *blunt* full, and the blunted blow banks holy charge |
| helmet | Vigil Greathelm (finesse) | *expose* 1.5s | *expose* 3s, and the dodge extends a raised Aegis 0.3s |
| helmet | Zealot Greathelm (aggressor) | *opener* +15% | *opener* +25%, and an opener thrown in Retribution staggers |
| helmet | Sanctified Greathelm (bulwark) | *pool* 4% | *pool* 8%, and Holy-stance mending overflow pools |
| gloves | Blessed Gauntlets (ward) | *unweave* small | *unweave*, and Consecration tears all it sanctifies |
| gloves | Templar Gauntlets (guard) | *iron answer* 15% | *iron answer* 25% as a smite that mends you 1% |
| gloves | Vigil Gauntlets (finesse) | *true-aim* every 8th Judgment | every 5th, and the sure Judgment mends 1% |
| gloves | Zealot Gauntlets (aggressor) | *tear* 0.10 | *tear* 0.15 of holy fire, deeper in Retribution |
| gloves | Sanctified Gauntlets (bulwark) | *grip* lesser | *grip*, doubled while Aegis holds |
| pants | Blessed Legguards (ward) | BARGAIN: *grounded* 50%, −10% healing received | *grounded* 30%, and a shrugged CC banks holy charge |
| pants | Templar Legguards (guard) | *anchor* 2 stacks | *anchor* 3, and casting Aegis at full stacks holds it +0.5s |
| pants | Vigil Legguards (finesse) | BARGAIN: deeper *slip*, Holy-stance mend −1% | *slip*, and a leaping Judgment while slippery lands +20% |
| pants | Zealot Legguards (aggressor) | *advance* +12% (commit: the Judgment leap) | *advance* +20%, and an advanced Conviction swap drags its chains wider |
| pants | Sanctified Legguards (bulwark) | BARGAIN: *bastion* 25%, Holy-stance mend halved | *bastion* 15%, and below the threshold the Holy mend doubles |

### Warlock — everything is fuel

| Slot | Shape (profile) | A unique | S unique |
|---|---|---|---|
| helmet | Voidsilk Hood (ward) | *magic ward* 15% | *magic ward* 30%, and 3% of what the ward eats returns as life |
| helmet | Bonemail Hood (guard) | *blunt* half | *blunt* full, and the blunted attacker is WITHERED |
| helmet | Shadeweave Hood (finesse) | *expose* 1.5s | *expose* 3s, and the dodge extends every live hex +1s |
| helmet | Ruinweave Hood (aggressor) | *opener* +15% | *opener* +25%, and an opening Shadowbolt withers |
| helmet | Bloodpact Hood (bulwark) | *pool* 4% | *pool* 8%, and Dark Pact's surge overheal pools at double rate |
| gloves | Voidsilk Claws (ward) | *unweave* small | *unweave*, and Hex tears all it curses |
| gloves | Bonemail Claws (guard) | *iron answer* 15% | *iron answer* 25%, and the counter BINDS (slows) the attacker |
| gloves | Shadeweave Claws (finesse) | *true-aim* every 8th Shadowbolt | every 5th, and the sure bolt drains 2% life |
| gloves | Ruinweave Claws (aggressor) | *tear* 0.10 | *tear* 0.15, ticking double on HEXED prey |
| gloves | Bloodpact Claws (bulwark) | *grip* lesser | *grip*, doubled for 5s after Dark Pact |
| pants | Voidsilk Chausses (ward) | BARGAIN: *grounded* 50%, −10% healing received | *grounded* 30%, and a shrugged CC refunds 3% max HP |
| pants | Bonemail Chausses (guard) | *anchor* 2 stacks | *anchor* 3, and at full stacks Dark Pact's blood price drops a third |
| pants | Shadeweave Chausses (finesse) | BARGAIN: deeper *slip*, Soulthirst −1% | *slip*, and a Void Rift opened while slippery pulls harder |
| pants | Ruinweave Chausses (aggressor) | *advance* +12% (commit: Dark Pact) | *advance* +20%, and an advanced Hex ramps its wither twice as fast |
| pants | Bloodpact Chausses (bulwark) | BARGAIN: *bastion* 25%, Soulthirst halved | *bastion* 15%, and below the threshold Dark Pact costs nothing |

### Chest / boots / charm — the migrated slots (2026-07-27)

The armor/boots/charm §5 shapes migrated onto the matrix with their art
pass; their 180 uniques take the same verb+beat treatment (chest = the
wall, boots = the road, charm = the will; the hp/VIT row's A lane pays
the class-native sustain BARGAIN). Verb lanes as §3; class beats below.

### Warrior — armor / boots / charm

| Slot | Shape | A unique | S unique |
|---|---|---|---|
| armor | Wardsteel Plate | *ward* lesser | *ward*, and the warded blow builds Grit |
| armor | Ironwall Plate | *anchor* lesser | *anchor*, and a full-stack blow staggers |
| armor | Skirmisher's Halfplate | *slip* lesser | *slip*, and slipping a blow hastens Shield Bash |
| armor | Bloodforged Harness | *answer* lesser | *answer*, and the harness's spikes stagger |
| armor | Titanplate | *bastion* lesser — BARGAIN: BUT Grit's regen is halved | *bastion*, and below the threshold blows mend you |
| boots | Wardstep Greaves | *ward* lesser | *ward*, and warded ground feeds Grit |
| boots | Sabatons | *anchor* lesser | *anchor*, and the planted stance staggers attackers |
| boots | Skirmisher's Boots | *expose* lesser | *expose*, and the dodge hastens Shield Bash |
| boots | Reaver Treads | *advance* lesser | *advance*, and the charge returns sooner |
| boots | Anchorplate | *bastion* lesser — BARGAIN: BUT Grit's regen is halved | *bastion*, and below the threshold the ground holds you |
| charm | Warbanner | *opener* lesser | *opener*, and the banner's first blow staggers |
| charm | Oath Sigil | *ward* lesser | *ward*, and the sworn ward feeds Grit |
| charm | Butcher's Token | *tear* lesser | *tear*, deeper while Berserk runs |
| charm | Duelist's Knot | *expose* lesser | *expose*, and the feint hastens Whirlwind |
| charm | Heart of the Wall | *pool* lesser — BARGAIN: BUT Grit's regen is halved | *pool*, pooling double while Berserk runs |

### Archer — armor / boots / charm

| Slot | Shape | A unique | S unique |
|---|---|---|---|
| armor | Stormweave Jerkin | *ward* lesser | *ward*, and a warded hit keeps Second Wind's clock |
| armor | Studded Brigandine | *anchor* lesser | *anchor*, and the riveted plates hold |
| armor | Ranger's Leathers | *slip* lesser | *slip*, and slipping a blow ticks the hunt rhythm |
| armor | Hunter's Harness | *answer* lesser | *answer*, as barbs that throw the attacker back |
| armor | Beastpelt | *bastion* lesser — BARGAIN: BUT Second Wind never triggers while worn | *bastion*, and below the threshold the pelt mends you |
| boots | Piercer's Cleats | *advance* lesser | *advance*, and Tumble returns sooner |
| boots | Windstriders | *expose* lesser | *expose*, and the dodge ticks the hunt rhythm |
| boots | Marksman's Stance | *opener* lesser | *opener*, and the held shot feeds the rhythm |
| boots | Wardedsole | *grounded* lesser | *grounded*, and a shrugged CC refunds Tumble |
| boots | Trailboots | *bastion* lesser — BARGAIN: BUT Second Wind never triggers while worn | *bastion*, and below the threshold Tumble hastens |
| charm | Fletcher's Token | *trueaim* lesser | *trueaim*, and the perfect nock feeds the rhythm |
| charm | Windfeather | *expose* lesser | *expose*, and the feather marks the attacker longer |
| charm | Hunter's Totem | *opener* lesser | *opener*, harder on EXPOSED prey |
| charm | Stonebark Ward | *ward* lesser | *ward*, and the bark keeps Second Wind's clock |
| charm | Greenheart Idol | *pool* lesser — BARGAIN: BUT Second Wind never triggers while worn | *pool*, — the grove's endurance pools |

### Assassin — armor / boots / charm

| Slot | Shape | A unique | S unique |
|---|---|---|---|
| armor | Shadowveil Cloak | *ward* lesser | *ward*, and a warded hit feeds the surge |
| armor | Warded Mantle | *anchor* lesser | *anchor*, and a full-stack blow EXPOSES the attacker |
| armor | Gossamer Cloak | *slip* lesser | *slip*, and slipping a blow feeds the surge |
| armor | Nightsilk Wrap | *answer* lesser | *answer*, and the wrap's blades feed the surge |
| armor | Verdant Shroud | *bastion* lesser — BARGAIN: BUT Elusive's regen is halved | *bastion*, and below the threshold the shroud mends you |
| boots | Slipsteps | *slip* lesser | *slip*, and slipping a blow feeds the surge |
| boots | Prowlers | *opener* lesser | *opener*, and the pounce arms the surge |
| boots | Venomtread | *advance* lesser | *advance*, and the dash returns sooner |
| boots | Ironsole Wraps | *grounded* lesser | *grounded*, and a shrugged CC refunds the dash |
| boots | Grave Treads | *bastion* lesser — BARGAIN: BUT Elusive's regen is halved | *bastion*, and below the threshold the surge holds |
| charm | Killer's Mark | *trueaim* lesser | *trueaim*, and the perfect cut feeds the surge |
| charm | Poisoner's Vial | *unweave* lesser | *unweave*, and the poison eats deeper |
| charm | Ghostlight Charm | *expose* lesser | *expose*, and the dodge extends a live Death Mark |
| charm | Bloodoath Cord | *answer* lesser | *answer*, and the sworn debt feeds the surge |
| charm | Wraithbone Fetish | *pool* lesser — BARGAIN: BUT Elusive's regen is halved | *pool*, pooling double while the surge runs |

### Mage — armor / boots / charm

| Slot | Shape | A unique | S unique |
|---|---|---|---|
| armor | Silk Vestments | *ward* lesser | *ward*, and the warded hit refunds mana |
| armor | Runeplate Robe | *anchor* lesser | *anchor*, and full plates hasten Blink |
| armor | Featherweave Robe | *slip* lesser | *slip*, and slipping a blow grants mana |
| armor | Starweave Robe | *answer* lesser | *answer*, as star-fire that CHILLS the attacker |
| armor | Earthen Robe | *bastion* lesser — BARGAIN: BUT Frost Nova's restore is halved | *bastion*, and below the threshold the clay mends you |
| boots | Starstep | *opener* lesser | *opener*, and the opening cast cracks the ward |
| boots | Levitation Slippers | *expose* lesser | *expose*, and the dodge grants mana |
| boots | Sigil Sandals | *advance* lesser | *advance*, and Blink returns sooner |
| boots | Wardstone Shoes | *grounded* lesser | *grounded*, and a shrugged CC restores mana |
| boots | Rootbound Sandals | *bastion* lesser — BARGAIN: BUT Frost Nova's restore is halved | *bastion*, and below the threshold blows restore mana |
| charm | Arcane Orb | *unweave* lesser | *unweave*, and the orb's intent bores deeper |
| charm | Starshard | *tear* lesser | *tear*, deeper on ward-cracked prey |
| charm | Aegis Crystal | *ward* lesser | *ward*, and the carried ward refunds mana |
| charm | Zephyr Sigil | *expose* lesser | *expose*, and the sigil pays the dodge in mana |
| charm | Lifebloom Pendant | *pool* lesser — BARGAIN: BUT Frost Nova's restore is halved | *pool*, — the bloom's overflow pools |

### Paladin — armor / boots / charm

| Slot | Shape | A unique | S unique |
|---|---|---|---|
| armor | Templar Plate | *anchor* lesser | *anchor*, and full stacks bank holy charge |
| armor | Blessed Plate | *ward* lesser | *ward*, and the warded blow banks holy charge |
| armor | Vigil Halfplate | *slip* lesser | *slip*, and slipping a blow mends the watcher |
| armor | Zealot Harness | *answer* lesser | *answer*, burning harder in Retribution |
| armor | Sanctified Bulwark | *bastion* lesser — BARGAIN: BUT your class regen is halved | *bastion*, and below the threshold the Holy mend doubles |
| boots | Zealot's Cleats | *opener* lesser | *opener*, and the charge's first blow staggers |
| boots | Sabatons of the Oath | *grounded* lesser | *grounded*, and a shrugged CC banks holy charge |
| boots | Vigil Steps | *expose* lesser | *expose*, and the watch mends the dodger |
| boots | Radiant Greaves | *advance* lesser | *advance*, and the leap rearms sooner |
| boots | Pilgrim's Resolve | *bastion* lesser — BARGAIN: BUT your class regen is halved | *bastion*, and below the threshold the road mends you |
| charm | Reliquary | *ward* lesser | *ward*, and the relic banks holy charge |
| charm | Sunburst Icon | *tear* lesser | *tear*, of dawn-fire, deeper in Retribution |
| charm | Judgment Sigil | *unweave* lesser | *unweave*, and the verdict bores through wards |
| charm | Swiftvow Cord | *expose* lesser | *expose*, and the vow hastens Aegis |
| charm | Oathkeeper's Seal | *pool* lesser — BARGAIN: BUT your class regen is halved | *pool*, pooling double in Holy stance |

### Warlock — armor / boots / charm

| Slot | Shape | A unique | S unique |
|---|---|---|---|
| armor | Voidsilk Robe | *ward* lesser | *ward*, and the ward pays you back in life |
| armor | Bonemail | *anchor* lesser | *anchor*, and a full-stack blow WITHERS |
| armor | Shadeweave Robe | *slip* lesser | *slip*, and slipping a blow deepens every hex |
| armor | Ruinweave | *answer* lesser | *answer*, and the script curses the attacker |
| armor | Bloodpact Vestment | *bastion* lesser — BARGAIN: BUT Soulthirst is halved | *bastion*, and below the threshold blows repay in blood |
| boots | Ruinstep | *opener* lesser | *opener*, and the opening curse withers |
| boots | Shadowstep Wraps | *expose* lesser | *expose*, and the dodge deepens every hex |
| boots | Hexcarved Treads | *advance* lesser | *advance*, and the advance deepens every hex |
| boots | Bonewalkers | *grounded* lesser | *grounded*, and a shrugged CC refunds max health |
| boots | Gravebound Boots | *bastion* lesser — BARGAIN: BUT Soulthirst is halved | *bastion*, and below the threshold blows repay in blood |
| charm | Soul Fetish | *unweave* lesser | *unweave*, and the fetish has been inside them |
| charm | Cursed Idol | *tear* lesser | *tear*, ticking deeper on HEXED prey |
| charm | Ward of Ash | *ward* lesser | *ward*, and the ash pays you back in life |
| charm | Umbral Cord | *expose* lesser | *expose*, and the cord deepens every hex |
| charm | Heartcage | *pool* lesser — BARGAIN: BUT Soulthirst is halved | *pool*, pooling double after Dark Pact |

**Catalog audit:** 6 classes x 30 shapes x 2 lanes = 360 (armor family + migrated slots); every row leads
with a §3 verb (tested engine) and closes with a class beat (bespoke,
per-id wiring at item time); every BARGAIN cost is class-native sustain the
shape's own build barely uses; slot domains hold (helmets perceive and
ward, gloves deliver, pants stand — no movement speed anywhere).

## 5. New code mechanics — STATUS (engine wired 2026-07-27)

1. **CC-duration modifier on the player** — WIRED (`uniq_cc_mult` scaling
   apply_freeze/apply_root/apply_chill). Not Tenacity, and doesn't read as it.
2. **Player knock-resist** — DORMANT by finding: nothing knocks the player
   today (verified — no knockback source targets the hero). The knob exists
   in Balance; the seam waits for the first player-knock mechanic. The old
   pants-guard BARGAIN built on it moved to a LESSER lane meanwhile.
3. **No-graze / true-aim** — WIRED (per-hit eva-0 resolve; no Stats change
   needed; cap-exempt by nature, like hunt rhythm).
4. **`struck_icd` family** — WIRED, including the shipped weapon on-hit
   passives stamping it (their own behavior unchanged — the stamp only
   stands armor clauses down, weapon-first by construction).

Everything else in §4 composes shipped verbs; each row's class BEAT is
per-id wiring at item time.

---

## 6. Open questions / needs owner call

1. ~~Template model vs bespoke~~ — **SETTLED (owner, 2026-07-27): 180
   BESPOKE.** §4 is the catalog; the §3 verb library is engine substrate.
2. **One-evade-proc, weapon-first** (§1.3) — wired as recommended; flag if
   per-piece ICDs are preferred instead.
3. **Gloves at minor budget** — the catalog runs glove passives ~20% leaner
   (grip/tear/answer magnitudes); flatten if that reads wrong in play.
4. **Drop split extension** — wired slot-generic: the named channel already
   filters by slot, so helmet/gloves/pants uniques start dropping (named A
   Act 2+, named S Act 3+) the moment their rows enter `Items.UNIQUES`.
5. **No legendaries for the new slots** — recommended: skip; 18 new
   legendaries would dilute the awakening rite. (S_GEAR has no entries for
   the new slots, so this is already the code's behavior.)
6. **Chest/boots/charm migration** — when those slots fold onto the §5b
   skeleton, their uniques get the same treatment: bespoke rows on the verb
   library (chest = the wall, boots = the road, charm = the will).
7. **Loadout cap** — no cap recommended (doctrine + ICD families); the
   fallback if seven clauses still read noisy is a chosen-active cap, priced
   only if playtest demands it.

---

## 7. Build order — STATUS

1. ~~Framework calls~~ — settled (bespoke; weapon-first ICDs; leaner gloves).
2. **Engine** — WIRED 2026-07-27 (§3): verbs, ICD families, CC modifier,
   true-aim, caches, suite coverage via injected pieces. Slots themselves
   went live in the 7-slot wiring commit.
3. **NEXT — art pass**: names + icons for the 180 (the suite pins every
   UNIQUES row to an existing icon file, so the rows land WITH the art).
   Then per-id wiring: 180 `Items.UNIQUES` rows + `Items.PASSIVES` lines +
   `Balance.UNIQ` knobs + each row's class BEAT on the verb dispatch.
4. dps-bench phase then owns every magnitude, armor and weapon alike.
