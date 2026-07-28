# PROPOSALS — Unique gear SETS

**Status: WIRED 2026-07-28 (owner-approved).** The legacy per-class
`Items.SET_BONUSES` is retired (it counted ANY class-locked S piece and read
"7/4 pieces worn" in the 7-slot world); the 30 profile sets below are live —
membership by VERB family (`Items.set_profile_of`), bonuses in
`Balance.UNIQ_SETS` (2pc stats fold in recalc; 4pc/6pc clauses at their
seams), names resolved from the S-triad families (`Items.uniq_set_name`),
the item-card panel shows n/6 with live tiers. All magnitudes are
placeholders — the dps-bench phase owns numbers.

---

## 1. The shape of a set

**A set is a PROFILE, worn across the body.** The six gear slots each field
five shapes on the same profile skeleton (ward / guard / finesse / aggressor
/ bulwark), and the art pass named each class's S pieces in profile families
(warrior ward = *Nullward* helm/hands/legplates; archer finesse = *White
Wind*; etc.). So: **6 classes × 5 profiles = 30 sets of SIX pieces** (helmet,
chest, gloves, pants, boots, charm — the slot's unique whose passive id
carries that profile letter).

Rules:

- **Membership is SEMANTIC — by verb family** (wired 2026-07-28): a piece
  belongs to the profile its engine verb serves (ward verbs → A, guard → B…),
  not its positional id letter — the armor/boots/charm rows order by the §5
  coverage tables, so position lies there (an archer's pen-cleats sit in row
  A but fight like an aggressor piece). The A and S lanes BOTH count (the
  Act-2 A pieces are the on-ramp). Weapons never count: the weapon stays the
  free signature choice, per the stacking doctrine. CAVEAT: because a few
  slots double a verb family (every chest's aggressor row is an iron-answer
  = guard piece), some class×profile sets top out at 4-5 available pieces —
  their 6pc is aspirational until the bench phase re-verbs those rows.
- **Set names resolve from the S-triad's shared prefix at wiring time**
  (Nullward, Warhowl, White Wind…), so the art pass's naming does the
  flavor work — no new names invented here.
- **Thresholds 2 / 4 / 6.** 2pc = modest in-profile stats. 4pc = the LENS
  payoff (below). 6pc = one clean standing capstone — a clause, never a new
  rotation (sets stack on top of up to six passives; they must read as one
  build, not six more procs).
- **One legacy retirement**: `SET_BONUSES`/`count_set_pieces` go; generic S
  pieces no longer form a set. The "7/4" display dies with it.

**The lens rule (owner, 2026-07-28):** every set's 4pc is deliberately ONE
of — *complements the playstyle* (deepens the profile's identity),
*covers a weakness* (the class's known hole), or *rewards the off-meta
build* (feeds the established off-meta axes from the weapon pass). Tagged
per row below as [identity] / [weakness] / [off-meta].

---

## 2. The 30 sets

2pc is uniform per profile (in-profile stats, placeholder sizes):
ward +8 MagRes · guard +8 PhysRes +4 CritRes · finesse +6 DEX +3% EVA ·
aggressor +3% ATK +2% Crit · bulwark +8 VIT.

### Warrior

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| Nullward (ward) | [weakness: magres is the plate's soft side] taking MAGIC damage builds a Grit stack | your magic-ward verb also pays +10% damage while it holds — spellfire feeds the war |
| Unbroken (guard) | [identity] Grit cap +2 | at full Grit stacks, blows you take are answered at 0.3× |
| No Horizon (finesse) | [off-meta: the eva duelist] EVADING builds a Grit stack — the dodge feeds the grind | +10% ability damage while slippery |
| Warhowl (aggressor) | [identity] Berserk runs +2s | your openers stagger |
| Stonefather (bulwark) | [identity] +8% max HP | the bastion floor deepens +10% |

### Archer

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| Tempest Crown (ward) | [weakness: no answer to spell chip] a warded magic hit doesn't reset Second Wind | Second Wind regen +2%/s |
| Ironwood Witness (guard) | [off-meta: the thorn tank] being hit ticks the hunt rhythm | anchor stacks also return 0.15× thorns per blow |
| White Wind (finesse) | [identity] Tumble cd −1s | a perfect dodge grants one guaranteed-crit shot |
| Last Hunt (aggressor) | [identity] EXPOSED prey takes +8% from you | your first shot on unwounded prey is always EXPOSING |
| First Beast (bulwark) | [off-meta] +8% max HP and Second Wind's delay −0.5s | below 30% HP your shots slow attackers 20% |

### Assassin

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [weakness: magic chip bypasses Elusive] a warded magic hit feeds the blood surge +0.5s | +10 MagRes and the ward's DR +10% |
| guard triad | [off-meta: the parry fencer] full anchor stacks add +10% parry-family proc chance | blows taken while surging are answered at 0.3× |
| finesse triad | [identity] Elusive +3% evasion | evading extends a live Death Mark +0.3s |
| aggressor triad | [identity] MARKED prey takes +8% from you | Stab kills extend the surge +1s |
| bulwark triad | [off-meta: the bulk fencer] +8% max HP | below 30% HP the blood surge never expires |

### Mage

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [identity] warded hits refund 5 mana | +10 MagRes and Blink's Arcane Ward +10% DR |
| guard triad | [weakness: the glass body] the crit-blunt icd −3s | anchor stacks harden Blink's cloak +5% each |
| finesse triad | [off-meta: the eva mage] evading grants 10 mana | Blink cd −0.5s |
| aggressor triad | [identity] ward-cracked prey takes +8% from you | every 4th Firebolt cracks the ward |
| bulwark triad | [off-meta: the battle-mage] +8% max HP, Nova restore +5% | Frost Nova roots 0.5s |

### Paladin

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [identity] warded blows bank holy charge | +10 MagRes; the ward pays +10% while it holds |
| guard triad | [identity] blunted crits bank holy charge | Aegis holds +0.5s |
| finesse triad | [off-meta: the duelist paladin] evading mends 2% | Judgment's leap rearms 1s sooner |
| aggressor triad | [off-meta: the INT lance] +4 MagPen; openers in Retribution bank charge | Conviction's swap slam +15% |
| bulwark triad | [identity] Holy-stance mend +1% | below 30% HP the Holy mend doubles |

### Warlock

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [identity] the ward feeds 3% of what it eats back as life | +10 MagRes; hexes on your attackers run +1s |
| guard triad | [weakness: the squishy channeler] full anchor stacks cut Dark Pact's cost a third | blows taken WITHER the attacker |
| finesse triad | [off-meta: the eva warlock] evading extends every live hex +1s | Void Rift pulls harder |
| aggressor triad | [identity] HEXED prey takes +8% from you | hex detonations +15% |
| bulwark triad | [off-meta: the blood tank] +8% max HP; Dark Pact surge +1s | below 30% HP Dark Pact costs nothing |

---

## 3. Wiring sketch

Membership: parse the profile letter from the equipped piece's structural
passive id (`<cls>_<slot>_<P><lane>`) — no new data table needed for
counting. Bonuses: one `Balance.UNIQ_SETS[cls][profile]` record (2/4/6
knobs); 2pc/4pc stat lines fold into recalc like the old set bonuses; 4pc/
6pc clauses reuse the shipped verb/beat seams (Grit stacks, surge/hex
extends, holy banking, ward amps — nothing new except the thorn return and
parry-chance-add). Set UI: the equip-screen panel that produced the
screenshot re-reads from the new source and shows `n/6`; codex Rules shelf
updates. Old saves: generic S pieces simply stop forming a set.

## 4. Open questions

1. Set names from S-triad prefixes — confirm, or hand-name the 30.
2. A-lane pieces counting toward sets (recommended: yes, the on-ramp).
3. Chest/boots/charm S one-off names don't carry the triad prefix — display
   the set under the triad name regardless (recommended), or rename art.
4. Mixed-profile loadouts get no set — intended (the set IS the commitment);
   confirm.
