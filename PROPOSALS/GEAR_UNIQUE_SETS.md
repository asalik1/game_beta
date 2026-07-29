# PROPOSALS — Unique gear SETS

**Status: WIRED 2026-07-28 (owner-approved); fix round + first bench SAME
DAY.** The legacy per-class `Items.SET_BONUSES` is retired (it counted ANY
class-locked S piece and read "7/4 pieces worn" in the 7-slot world); the 30
profile sets below are live — membership by VERB family
(`Items.set_profile_of`), bonuses in `Balance.UNIQ_SETS` (2pc stats fold in
recalc; 4pc/6pc clauses at their seams), names resolved from the S-triad
families (`Items.uniq_set_name`), the item-card panel shows n/6 with live
tiers. The aggressor lane is BENCHED (2026-07-28 rounds: archer band held
with the 4pc live; assassin 2pc runs hot for the crown; the audit fix
round re-measured the ladders — archer D4 58.0k < D6 60.5k, mage D4 55.2k
< D6 56.4k, assassin D6 72.5k — see BALANCE_HISTORY.md); the defensive
lanes' magnitudes remain placeholders pending playtests, EXCEPT the shapes
the 2026-07-28 audit fix round repaired (ward_amp's window, the ward 4pc
riders, cloak_stacks' nesting — noted per row below).

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
  coverage tables, so position can lie there. The A and S lanes BOTH count
  (the Act-2 A pieces are the on-ramp). Weapons never count: the weapon
  stays the free signature choice, per the stacking doctrine. The old
  caveat (doubled verb families capping 12 of the 30 sets at 4-5 pieces)
  is CLOSED: the 2026-07-28 re-verb (17 rows, GEAR_ARMOR_UNIQUE_PASSIVES.md
  §5b) gives every class×profile a piece in all six slots, and an autotest
  section pins the 6/6 coverage.
- **Sets self-carry their machinery** (2026-07-28): clauses that ride one
  carrier verb's proc would otherwise read live on the card while doing
  nothing without that exact piece. The guard set ANCHORS on its own at 4pc
  (struck-accrual to `Balance.SET_ANCHOR_STACKS` when no pants_guard carrier
  is worn) and the ward set arms a baseline magic ward at 4pc
  (`Balance.SET_WARD`) — a worn carrier's own knobs always win.
- **Capstones must exist in boss fights** (2026-07-28): the aggressor 6pc
  opener clauses RE-ARM on a cadence (`Balance.SET_OPENER_REARM`) since a
  boss never offers a second unwounded moment, and the assassin 6pc accepts
  a Stab CRIT as the kill-stand-in on bosses (`Balance.SET_SURGE_CRIT_ICD`).
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

2pc is per-profile stats (ward +8 MagRes · guard +8 PhysRes +4 CritRes ·
finesse +6 DEX +3% EVA · aggressor +3% ATK +2% Crit · bulwark +8 VIT) —
no longer strictly uniform: since the 2026-07-28 bench, a class's aggressor
2pc/4pc may run hotter or leaner as the ENDGAME board-ordering dial (the
owner's called class gaps live partly here because set tiers only exist on
endgame kits — at-level, set-less pacing never moves). Current deviations
(2026-07-29 ordering retune): warrior 2pc +2.5%/+2% (the 4/2.5 fury dial
eased back — tree drift + the item-opener re-arm had pushed fury near
mage), assassin 4pc amp 0.25 (priced for ~1/6 Death-Mark uptime), warlock
4pc amp 0.04 (down from 0.16 — the class's no-amp baseline alone sits ~5.6%
under mage on the current tree, so the face-value amp is priced at exactly
the displaced-passive band).

### Warrior

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| Nullward (ward) | [weakness: magres is the plate's soft side] taking MAGIC damage builds a Grit stack | +10% damage for 6s from the ward's ARMING (audit fix 2026-07-28: "while it holds" was 2s-in-8 — the condemned Tempest Crown shape) |
| Unbroken (guard) | [identity] Grit cap +2 | at full Grit stacks, blows you take are answered at 0.3× |
| No Horizon (finesse) | [off-meta: the eva duelist] EVADING builds a Grit stack — the dodge feeds the grind | +10% damage while slippery |
| Warhowl (aggressor) | [identity] Berserk runs +3s (eased from +4s, 2026-07-29 ordering retune) | your openers stagger and CRUSH (+12% while the foe reels), re-arming every 12s — the crush window is the one warrior knockbacks and the crush talent already read |
| Stonefather (bulwark) | [identity] +8% max HP | the bastion floor deepens +10% |

### Archer

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| Tempest Crown (ward) | [weakness: no answer to spell chip] magic damage doesn't reset Second Wind (redesigned 2026-07-28 — the warded-hit-only version paid ~2s in 8, noise in any pack) | Second Wind regen +2%/s |
| Ironwood Witness (guard) | [off-meta: the thorn tank] being hit ticks the hunt rhythm (converts to the rhythm crit for EVERY a1 theme — the counter's conversion no longer requires hunt) | anchor stacks also return 0.15× thorns per blow |
| White Wind (finesse) | [identity] Tumble cd −1s | a perfect dodge grants one guaranteed-crit shot |
| Last Hunt (aggressor) | [identity] EXPOSED prey takes +8% from you | three-part capstone (audit fix 2026-07-28 — the re-armed EXPOSE alone measured ~0 on hunt, redundant under hunt's own permanent marks): EXPOSED prey takes a further +5%, the hunt rhythm converts one beat sooner, and the re-armed opening EXPOSE stays for off-hunt themes. Measured: D4 58.0k < D6 60.5k (+4.3%) |
| First Beast (bulwark) | [off-meta] +8% max HP and Second Wind's delay −0.5s | below 30% HP, blows you take SLOW the attacker 20% (the wiring answers being struck — the old "your shots slow" text lied) |

### Assassin

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [weakness: magic chip bypasses Elusive] a warded magic hit feeds the blood surge +1.5s (audit fix 2026-07-28: 0.5s per ≥8s proc was sub-noise) | +10 MagRes and the ward's DR +10% |
| guard triad | [off-meta: the parry fencer] full anchor stacks add +10% parry-family proc chance | blows taken while surging are answered at 0.3× |
| finesse triad | [identity] Elusive +3% evasion | evading extends a live Death Mark +0.3s |
| aggressor triad | [identity] Death-Marked prey takes +25% from you (audit fix 2026-07-28: re-keyed onto the ULT window + the mark — bare vuln_time let armor EXPOSE pieces run the Death-Mark-priced amp near-permanently; still ~1/6 uptime as priced) | while the blood surge runs, your blades bite +15% (redesigned 2026-07-28: the kill/crit surge EXTENSION was saturated — stab cadence already maintains the surge — so the full six measured under the 4pc kit). Measured D6 72.5k |
| bulwark triad | [off-meta: the bulk fencer] +8% max HP | below 30% HP the blood surge never expires |

### Mage

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [identity] warded hits refund 15 mana (audit fix 2026-07-28: 5 per ≥8s proc was under a second of base regen) | +10 MagRes and Blink's Arcane Ward +10% DR |
| guard triad | [weakness: the glass body] the crit-blunt icd −3s | anchor stacks ward you 5% each (audit fix 2026-07-28: un-nested from Blink's ~0.8s dr window — the triple gate was unobservable) |
| finesse triad | [off-meta: the eva mage] evading grants 10 mana | Blink cd −0.5s |
| aggressor triad | [identity] ward-cracked prey takes +8% from you, and every 8th Firebolt cracks the ward itself (audit fix 2026-07-28: at exactly 4pc the only shred source was the once-per-fight opener beat — ~8s uptime per boss, a possible D3>D4 inversion) | the crack quickens to every 4th Firebolt. Measured: D4 55.2k < D6 56.4k (the old accepted tie now escalates) |
| bulwark triad | [off-meta: the battle-mage] +8% max HP, Nova restore +5% | Frost Nova roots 0.5s |

### Paladin

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [identity] warded blows bank holy charge (0.8× atk) | +10 MagRes; +10% damage for 6s from the ward's arming (same audit-fix shape as Nullward) |
| guard triad | [identity] blunted crits bank holy charge | Aegis holds +0.5s |
| finesse triad | [off-meta: the duelist paladin] evading mends 2% | Judgment's leap rearms 1s sooner |
| aggressor triad | [off-meta: the INT lance] +4 MagPen; openers in Retribution bank charge (0.6× atk), re-arming every 12s (audit fix 2026-07-28: fresh-only banked exactly once per boss fight) | in Retribution your blows strike +10% harder (retri_amp, 2026-07-29 ordering retune — the endgame share of paladin's called gap, and the capstone that ends the accepted D6=D4 tie); Conviction's swap slam +15% stays for the off-meta swapper |
| bulwark triad | [identity] Holy-stance mend +1% | below 30% HP the Holy mend doubles |

### Warlock

| Set (profile) | 4pc — the lens | 6pc — capstone |
|---|---|---|
| ward triad | [identity] the arming ward mends 3% of your health (audit fix 2026-07-28: the "3% of what it eats" framing was never the wiring, and the old 1% was sub-noise) | +10 MagRes; hexes on your attackers run +1s |
| guard triad | [weakness: the squishy channeler] full anchor stacks cut Dark Pact's cost a third | blows taken WITHER the attacker |
| finesse triad | [off-meta: the eva warlock] evading extends every live hex +1s | Void Rift pulls harder |
| aggressor triad | [identity] HEXED prey takes +4% from you (2026-07-29 ordering retune, from 0.16 — see the deviations note above) | hex detonations +15% — OWNER-ACCEPTED AS-IS (2026-07-29, closed, don't reopen): measured level with D4 single-target AND in --aoe; a completion ladder cannot escalate past the called −4%-under-mage while the class baseline sits ~−5.6%, and the owner ruled the flat capstone acceptable — warlock's completion payoff is the pack-mode detonation identity, not a bench rung |
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
