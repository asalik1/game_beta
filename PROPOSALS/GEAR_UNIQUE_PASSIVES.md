# PROPOSALS — Named-unique signature passives (first pass)

**Status: IMPLEMENTED 2026-07-27 (owner-approved as designed); BENCHED same
day.** All 60 passives are wired and live (`Items.UNIQUES` / `Items.PASSIVES`,
knobs in `Balance.UNIQ`), the drop split is in (`roll_item_of` named channels:
named A Act 2+, named S Act 3+, legendary = rare Act 2+ S roll via
`make_legendary`; generic S carries no passive), and the §9 reconciliation
shipped as recommended. **The dps-bench phase ran 2026-07-27** (full round
narrative + measured board: BALANCE_HISTORY.md top entry): design review of
all 60 + the 360 gear passives, four redesigns landed (hartsbreath's
perfect-dodge-only trigger → any-Tumble base + perfect topper; herald gains a
kill re-arm; dirge's tax now rings on both heavy swings; thegate's counter
throttled 0.25s), decree's cadence moved onto a knob, and the boss/mob GEAR
ramp recalibrated the endgame curve for the new power (60s perfect-kit TTK pin
on the L100 Act-1 finale). The §10 owner calls were
resolved per the recommendations (uniques live on pickup, awakening stays
legendary-only, forced-crit procs cap-exempt, shared on-evade ICD in
`Balance.UNIQ.evade_icd`, root approximated as a near-total slow, proc
feedback via floating text).

Original first-pass design below, kept as the design record. Scope: the 60 named
weapon uniques from `PROPOSALS/GEAR_UNIQUE_ART_MANIFEST.md` (30 A + 30 S, one
A + one S per shape, 6 classes × 5 shapes). Armor/boots/charm uniques wait for
their shape matrix.

Quality bar and style reference: the six shipped S_GEAR passives
(`kingsblade` / `windward` / `wellspring` / `mirrorstep` / `dawnbreaker` /
`voidmaw`) — each one hooks a **real ability** and adds a beat to the rotation
rather than a stat line. Every passive below follows that shape.

Standing rules honored throughout:

- **Movement speed is sovereign** — no passive grants it (ability-cd refunds on
  dashes follow the `wellspring` precedent and are not speed).
- **Haste/Lifesteal/Combo/Tenacity/Damage% stay gem-only as stats.** Passives
  may modify a *specific ability's* damage/cooldown (the `wellspring` /
  `dawnbreaker` precedent) but never hand out the raw stat.
- **Crit is earned, not passive** (owner rule, hunt-rhythm precedent): no
  passive grants flat crit chance. Guaranteed-crit *procs* earned through play
  are the allowed currency, same as the archer's hunt rhythm.
- **No silent effects:** every passive names its trigger and shows a visible
  beat (proc text / ring / counter pip). The HUD cost of counter-pips is an
  open question (§10).
- Weapons are exclusive — one weapon passive at a time, so weapon passives can
  never stack with each other or with the class legendary. Stacking only
  becomes a question once armor/boots/charm uniques exist.

---

## 1. The A-vs-S power framework

**S is the full signature. A is the same build axis, paid for.** Every A/S
pair on a shape serves the *same* build (the shape's bias), so the A reads as
the apprentice piece of the S — you farm the A in Act 2, it teaches you the
build, and the S in Act 3 is the graduation.

An A-grade passive takes exactly one of two lanes, named in its row:

- **Lane 1 — LESSER:** the same design axis at reduced magnitude or behind a
  narrower trigger (~60–70% of the S's swing, or gated behind one specific
  ability/window). No drawback.
- **Lane 2 — BARGAIN:** power comparable to an S passive, but with a stated
  cost. **The recommended cost is one that taxes the META build harder than
  the build the shape supports.** Ashrider disables warrior Grit — a dodge
  warrior barely misses it, a face-tank loses their engine. Briar Covenant
  halves Second Wind — a kiting archer bleeds, a thorn-tank never procced it
  anyway. Vowspike demotes STR — fatal to a STR paladin, free to an INT one.
  A bargain drawback is how an A unique *steers* players into the off-meta
  build instead of merely permitting it. Drawbacks are printed on the item
  tooltip in full (no-silent-effects rule applies to costs too).

S passives are unconditional or earned-through-play (counters, dodges,
stances) — never taxed. Rough power ordering: **A (lane 1) < A (lane 2) ≈ S**,
where the lane-2 "≈" only holds inside the build the shape supports.

---

## 2. Off-meta axis per class

Each class gets at least one A and one S passive that specifically reward a
build the class's primary attribute does not point at. The designated shape is
the one whose bias already leans that way (§5 of the shape matrix). Latent
scaling hooks from `Classes.ATTR_SCALE` are noted where they exist.

| Class | Off-meta axis | Carrier shape (A + S) | What makes it latent today |
|---|---|---|---|
| Warrior | Evasion duelist (dex/eva, dodge-triggered offense) | Saber — Ashrider / Red Horizon | Saber bias is the only finesse lean in the kit; Grit actively punishes not being hit, so the passives must replace that engine |
| Archer | Bulk thorn-tank (hp/res, stand and take it) | Thornbow — Briar Covenant / Green Ruin | Second Wind pays only the untouched; nothing currently pays an archer for eating a hit |
| Assassin | Defensive parry fencer (res/hp, catch blades instead of slipping them) | Warded Fang — Parryshade / The Hand That Refused Death | Kit is all offense-dodge; the parrying-dagger shape exists with no mechanic behind it |
| Mage | VIT battle-mage (hp/VIT, fights inside Frost Nova range) | Bloomstaff — Springwake / Verdancy | Nova/Blink are melee-radius tools; VIT converts to nothing offensive for a mage today |
| Paladin | INT caster-paladin (magpen/INT) | Lance — Vowspike / Noonday | **The owner's example.** Holy damage already checks magres; `ATTR_SCALE` gives paladin INT→atk 0.6 — a real latent second primary |
| Warlock | Blood-tank (hp/VIT as ammunition) | Grimheart Staff — Veinroot / Red Reliquary | VIT already rates higher for warlock (Dark Pact spends HP); max-HP never feeds damage directly |

Secondary off-meta support (marked in the tables): the finesse shapes of the
heavy classes (Duelist's Blade paladin, Whisper Rod warlock, Zephyr Rod mage)
all key off a shared **on-evade trigger hook** — an evasion build on those
classes is off-meta by itself.

---

## 3. Warrior

| Unique | Grade | Shape | Bias | Passive name | Effect | Rough magnitude (placeholder) | Off-meta? | New mechanic or reuse? | A-drawback (if any) |
|---|---|---|---|---|---|---|---|---|---|
| The Red Pennon | A | Pike | physpen [1] | `pennon` | Shield Bash plants the pennon in everything it rams: SUNDERED enemies lose physical resistance for a spell. | −25% physres, 4s | no | Reuse — brittle-style debuff via `hit_enemy` rider | Lane 1: gated behind Shield Bash's 4.5s cd |
| Crownspike, the Last Decree | S | Pike | physpen [1] | `decree` | Every 3rd Cleave (riding the existing `cleave_seq` cycle) lands as the DECREE — a piercing thrust that ignores physical resistance outright and staggers. | 1.15× coeff, full armor ignore, 0.35s stagger | no | Reuse — cleave cycle + `_melee_arc`; needs a full-pen flag on the hit | — |
| Marchbreaker | A | Warblade | atk+crit [2] | `warpath` | While Berserk runs, your crits echo a ghost-blade arc behind the real one. | 0.6× echo arc, only during Berserk's 8s | no | Reuse — wave2/echo follow-up pattern | Lane 1: full effect, Berserk-window only |
| Throneless, Edge of the Last Host | S | Warblade | atk+crit [2] | `lasthost` | Your crits raise the Last Host: a spectral blade-arc follows every critical swing. | 0.6× echo arc, ~0.3s internal cd so Whirlwind multi-crits don't chain-loop | no | Reuse — same follow-up pattern, unconditional | — |
| Ashrider | A | Saber | dex+eva [2] | `outrider` | When an attack misses you, you ride the opening: your next Cleave within 2s strikes twice. | 2nd strike at 1.0×, 2s window | **yes** | **New — shared on-evade hook** (§11.1) + echo swing | Lane 2 BARGAIN: **Grit never stacks** — the saber rides too light for the grind (taxes the face-tank, not the duelist) |
| Red Horizon | S | Saber | dex+eva [2] | `horizon` | Every dodge sharpens the line: your next Cleave is a guaranteed crit, and each dodge refunds part of Shield Bash. | earned guaranteed crit + 1.5s Bash refund per evade | **yes** | **New — on-evade hook**; force_crit rider exists | — |
| Bastion's Tooth | A | Bulwark Blade | res+res+hp [3] | `reprisal` | Blows that land on you risk the tooth: a chance the attacker is instantly counter-cut. | 30% chance, 0.6× counter, melee attackers only | no | Reuse — Aegis smite-back pattern in `take_damage` | Lane 1: chance-gated, melee-only |
| The Gate That Walks | S | Bulwark Blade | res+res+hp [3] | `thegate` | Shield Bash raises the Gate: a short massive guard, and every blow you take while it holds is answered — the attacker is staggered and counter-cut. | +80 phys/magres for 2.5s, 0.8× counter + 0.5s stagger | no | Reuse — theme_guard numbers + Aegis smite | — |
| Gravesong | A | Claymore | massive | `dirge` | The dirge swings heavy: Cleave and Whirlwind hit harder, but Cleave tolls slower. | +20% Cleave/Whirlwind damage; Cleave cd +15% | no | Reuse — ability-scoped mults (berserk precedent) | Lane 2 BARGAIN: the cd tax is the weight |
| Crownfall, the Kingdom's End | S | Claymore | massive | `aftershock` | Everything falls twice: Whirlwind leaves a collapsing ring that detonates a beat later. | 0.6× AoE echo, 0.5s delay, staggers | no | Reuse — end_slam delayed-AoE pattern + `_ring_fx` | — |

---

## 4. Archer

| Unique | Grade | Shape | Bias | Passive name | Effect | Rough magnitude (placeholder) | Off-meta? | New mechanic or reuse? | A-drawback (if any) |
|---|---|---|---|---|---|---|---|---|---|
| Siegebough | A | Warbow | atk [1] | `siegebolt` | Multishot looses siege bolts that punch straight through their victims. | unlimited pierce, Multishot only (the shipped card/engine; this row's old "into a second" framing was stale) | no | Reuse — projectile `pierce` flag | Lane 1: one ability, no bonus damage |
| Tempest Yew, Bow of the Last Gale | S | Warbow | atk [1] | `gale` | Every 5th Quick Shot looses the gale — a free 3-arrow fan rides the shot. | 3 arrows at 0.55× each, light knockback | no | Reuse — hunt-rhythm counter pattern + Multishot fan spawn | — |
| Far-Witness | A | Longbow | crit+physpen [2] | `farsight` | Arrows loosed from far afield shear a third of the prey's armor. | targets ≥380px: physres treated at 65% (audit fix 2026-07-28: 240px was the default kiting band — a near-permanent 50% ignore out-damaged the shape's own S) | no | Reuse — conditional pen on the hit | Lane 1: range-gated |
| Skyline, the Arrow Before Dawn | S | Longbow | crit+physpen [2] | `herald` | The first arrow decides: your opening hit on any unwounded enemy is a guaranteed crit and marks the prey; kills re-arm the dawn, and against a boss it re-arms every 12s. | force_crit on full-HP targets + vuln; kill re-arm 3s; boss re-arm 12s (audit fix 2026-07-28 — one proc per boss fight was ~1-2% on an S) | no | Reuse — force_crit + vuln riders | — |
| Foxfire String | A | Hunting Bow | dex+eva [2] | `foxfire` | Slipping an attack draws the fox's shot: your next Quick Shot fires twin arrows. | 2 arrows at 0.85× each, 1s internal cd | secondary | **New — on-evade hook** (shared, §11.1) | Lane 1: one proc per dodge |
| The White Hart's Last Breath | S | Hunting Bow | dex+eva [2] | `hartsbreath` | A perfect dodge (Tumble timed into a hit) grants the Hart's Breath: your next 3 shots are guaranteed crits and Multishot returns at once. | 3 forced crits + Multishot cd reset | secondary | Reuse — Tumble's perfect-dodge window + hunt-rhythm counter | — |
| Briar Covenant | A | Thornbow | res+res+hp [3] | `briar` | The covenant answers blood with thorns: enemies that strike you are briar-lashed — torn and slowed. | 0.2× atk DoT + 30% slow, 3s | **yes** | Reuse — on-hit-taken hook (Aegis pattern) + dot/slow riders | Lane 2 BARGAIN: **Second Wind regen halved** — the covenant replaces spacing-sustain (taxes the kiter, costs the tank nothing) |
| Green Ruin, Root of the First Wild | S | Thornbow | res+res+hp [3] | `bramble` | While the wild has your blood (hit within the last 3s), your arrows grow thorns — added tearing and slow — and a landed blow on you vents a root-burst nova. | +0.25× atk DoT + 20% slow on arrows; root-burst: 0.5s root around you, 6s internal cd | **yes** | Reuse — `since_hurt` inverse-window; **root as an enemy rider is new** (§11.7) | — |
| Hornsong | A | Recurve | massive | `warhorn` | The horn calls a wider volley: Multishot fans 7 arrows instead of 5, but takes longer to return. | +2 arrows; Multishot cd +1.5s | no | Reuse — hits count + cd mult | Lane 2 BARGAIN: the cd tax |
| Moonturn, Bow of Returning Night | S | Recurve | massive | `moonturn` | Night returns: after Arrow Storm ends, a half-strength storm falls again unbidden. | echo storm 2s later, ~10 arrows at 0.8× | no | Reuse — re-invoke storm at scale | — |

---

## 5. Assassin

| Unique | Grade | Shape | Bias | Passive name | Effect | Rough magnitude (placeholder) | Off-meta? | New mechanic or reuse? | A-drawback (if any) |
|---|---|---|---|---|---|---|---|---|---|
| Silkneedle | A | Stiletto | physpen [1] | `gapfinder` | The needle finds the gap that's already open: Stab ignores half the armor of staggered, stunned, slowed, hobbled or MARKED enemies. | 50% armor ignore (audit fix 2026-07-28: bosses never hold stun/slow — stuns concuss, slows hobble — so the old gate was dead on every boss door; hobble and the mark are conditions a boss can wear) | no | Reuse — conditional pen on `hit_enemy` | Lane 1: needs a setup first |
| Quietus, the King's Final Thought | S | Stiletto | physpen [1] | `quietus` | Against the nearly-dead, the needle is a verdict: Stab strikes as TRUE damage below the threshold, and a Stab kill hastens Death Mark. | true damage vs ≤20% HP; +2s Death Mark refund per Stab kill | no | Reuse — "true" damage type exists (Death Mark); cd refund | — |
| Widow's Compass | A | Shuriken | crit+atk [2] | `compass` | Every knife points the same way: Fan of Knives converges — all three blades seek your current target. | 3×0.16 on one target (single-target Fan) | no | Reuse — retarget the fan spread | Lane 2 BARGAIN: the fan loses its spread — no pack coverage |
| End of Night | S | Shuriken | crit+atk [2] | `midnight` | A critical knife doesn't stop: Fan of Knives crits ricochet to the nearest second enemy — and while the blood surge runs, the ricochet keeps the doubled bite. | ricochet at 0.7× of the knife's hit | no | Reuse — projectile ricochet exists | — |
| Mothknife | A | Glasswing | dex+eva [2] | `mothdust` | Slipping a blow shakes dust from the wing: a small slowing mist blooms where you stood. | 30% slow mist, ~90px, 2s; 1s internal cd | secondary | **New — on-evade hook** + `_mist` reuse | Lane 1: utility only, no damage |
| Pale Flight, Blade Between Heartbeats | S | Glasswing | dex+eva [2] | `heartbeat` | Each dodge falls between heartbeats: half of Shadow Dash's remaining cooldown vanishes and the next dash cuts deeper. | 50% remaining-cd refund + next dash +30%, 2s internal cd | secondary | **New — on-evade hook**; dash cd/mult plumbing exists | — |
| Parryshade | A | Warded Fang | res+res+hp [3] | `parry` | The fang catches what the body would have slipped: a chance to PARRY a melee blow outright — negated, and answered with a riposte. | 30% parry chance, 0.8× riposte | **yes** | **New — parry (negate + counter on melee hit)** (§11.2) | Lane 2 BARGAIN: **passive evasion halved** (15%→7.5%) — you catch blades instead of slipping them (taxes the eva build, not the res/hp fencer) |
| The Hand That Refused Death | S | Warded Fang | res+res+hp [3] | `refusal` | Death is refused: a killing blow leaves you at 1 HP instead, untouchable for a breath, with the blood surge at full — and Death Mark ready. | cheat-death: 1 HP + 1s i-frame + full stab surge + Death Mark reset; once per 90s | **yes** | **New-ish — cheat-death** (paladin `last_rites` pattern generalized, §11.3) | — |
| Red Arithmetic | A | Cleaver | massive | `arithmetic` | The sum comes due: every 4th Stab lands with cleaver weight — heavier and staggering. | 4th Stab +60% + 0.3s stagger | no | Reuse — hunt-rhythm counter pattern | Lane 1: counter-gated weight |
| Headsman's Mercy | S | Cleaver | massive | `headsman` | Mercy is quick: Stab and Shadow Dash BEHEAD enemies below the threshold outright, and each beheading feeds the blood surge — a boss refuses the blade, but critical Stabs/Dashes against it feed the surge all the same. | execute at ≤12% HP (never bosses); +1.5s stab-surge per execution; boss stand-in: crit Stab/Dash feeds the surge on a 3s icd (audit fix 2026-07-28 — the whole S was 0 vs bosses; the set round's crit-as-kill precedent, extended) | no | Reuse-adjacent — execute logic exists (Death Mark rider / Hunger resonance) (§11.6) | — |

---

## 6. Mage

| Unique | Grade | Shape | Bias | Passive name | Effect | Rough magnitude (placeholder) | Off-meta? | New mechanic or reuse? | A-drawback (if any) |
|---|---|---|---|---|---|---|---|---|---|
| Wardpiercer | A | Scepter | magpen [1] | `wardcrack` | Each Firebolt cracks the ward a little wider: stacking magic-resistance shred on the target. | −8 magres per hit, stacks to 3, 3s | no | Reuse — brittle-style stacking debuff | Lane 1: ramp per target, decays |
| Axiom, Scepter of the Broken Law | S | Scepter | magpen [1] | `axiom` | The law is broken everywhere at once: a fraction of ALL your ability damage resolves as TRUE damage. | 15% of ability damage becomes true | no | Reuse — Meteor's `true_frac` generalized to the kit | — |
| Comet's Eye | A | Starfocus | crit+atk [2] | `cometfall` | A critical Firebolt bursts like a cometfall: splash damage around the victim. | 30% splash on Firebolt crits | no | Reuse — splash rider | Lane 1: crit-gated, one ability |
| The Ninth Star, Unblinking | S | Starfocus | crit+atk [2] | `ninthstar` | The ninth bolt is the Star: every 9th Firebolt is a guaranteed crit that bursts and cracks the ward. | forced crit + 40% splash + one `wardcrack` stack | no | Reuse — hunt-rhythm counter + force_crit + splash | — |
| Quickweather | A | Zephyr Rod | dex+eva [2] | `squall` | Blink stirs a squall: your next Firebolt after a Blink strikes twice. | echo at 50%, 2s window after Blink | secondary | Reuse — echo fx + post-Blink window | Lane 1: Blink-gated |
| Breathless, Rod of the Empty Sky | S | Zephyr Rod | dex+eva [2] | `breathless` | The sky empties where you stood: evading a hit resets Blink, and the next Blink's shock strikes doubled. | Blink cd reset on evade + next Blink shock +100%; 2s internal cd | **secondary (eva mage)** | **New — on-evade hook** (§11.1) | — |
| Springwake | A | Bloomstaff | hp+VIT+magres [3] | `springwake` | The bloom drinks deeper: Frost Nova's restore swells, and each enemy caught in the nova mends you. | restore 20%→30% of missing HP/MP; +1.5% max HP heal per enemy struck | **yes** | Reuse — Nova `restore` rider + Consecration heal-per-enemy pattern | Lane 1: sustain only, no damage |
| Verdancy, Staff of the Worldroot | S | Bloomstaff | hp+VIT+magres [3] | `worldroot` | Your life IS your power: gain attack from your bonus max HP, and Frost Nova roots what it catches. | +1 atk per ~12 bonus max HP (≈+25 atk on a bulk build vs ~160 base); Nova roots 1s | **yes** | **New — HP→power conversion** (§11.5); root rider (§11.7) | — |
| Atlas Branch | A | Greatstaff | massive | `atlas` | The branch bears more of heaven's weight: Meteor burns truer. | Meteor true_frac 0.25→0.40; no tax (audit fix 2026-07-28: the +6s cd out-taxed the gain at every resistance level — a strictly losing equip; now a plain LESSER) | no | Reuse — `true_frac` | Lane 2 |
| Firmament, the Heaven-Bearing Staff | S | Greatstaff | massive | `skyfall` | Heaven answers twice: casting Meteor calls a second, half-weight meteor onto the next-nearest enemy. | 2nd meteor at 50% (≈5.0 coeff) on next-nearest | no | Reuse — `_meteor_at(pos, scale)` exists (distinct from the Archmage skin's Starfall recursion — see §10) | — |

---

## 7. Paladin

| Unique | Grade | Shape | Bias | Passive name | Effect | Rough magnitude (placeholder) | Off-meta? | New mechanic or reuse? | A-drawback (if any) |
|---|---|---|---|---|---|---|---|---|---|
| Vowspike | A | Lance | magpen [1] | `vow` | The vow re-orders the soul: **INT converts to attack at 0.9 — but STR falls to 0.6.** Faith first, arm second. | ATTR_SCALE swap: INT 0.6→0.9, STR 0.9→0.6, held-weapon only | **yes — THE INT-paladin enabler** | **New — per-item attribute-scale override** (§11.4) | Lane 2 BARGAIN: the STR demotion — fatal to the meta STR paladin, free to the INT convert |
| Noonday, Lance of the Unshadowed | S | Lance | magpen [1] | `noonday` | At noon nothing shades you: INT converts at 0.9 *alongside* full STR — twin primaries — and every 4th Judgment lances THROUGH the target, searing the lane behind it. | INT→atk 0.9 (STR untouched); 4th Judgment: 0.8× beam through the lane | **yes** | **New — attr-scale override** + `_beam_fx` lane hit; hunt-rhythm counter | — |
| Bell of Censure | A | Oathflail | atk+crit [2] | `censure` | A critical blow tolls the bell: the chime staggers and splashes around the victim. | 30% splash + 0.3s stagger on crits | no | Reuse — splash/stagger riders | Lane 1: crit-gated |
| Absolution, the Last Toll | S | Oathflail | atk+crit [2] | `absolution` | Every 3rd kill rings the Last Toll: a free Consecration wave breaks from you, mending you for every enemy it touches — against a boss, your crits count as tolls. | free Consecration at 0.9×, heals per enemy struck; boss stand-in: crits toll on a 4s icd (audit fix 2026-07-28 — kill-gated alone, the S paid zero across a whole boss fight) | no | Reuse — Consecration invoked whole; kill counter | — |
| Mercy in Measure | A | Duelist's Blade | dex+eva [2] | `measure` | A measured step earns a measured answer: evading arms your next Judgment with extra weight and a sliver of mending. | next Judgment +40% + 2% max-HP heal, 2s window | secondary | **New — on-evade hook** (§11.1) | Lane 1: one armed swing per dodge |
| First Light, Edge of the Vigil | S | Duelist's Blade | dex+eva [2] | `vigil` | The vigil rewards the watchful: a dodge instantly rearms Judgment's leap, and the next Judgment lands as a guaranteed crit. | leap rider rearmed (skips `JUDGMENT_LEAP_CD`) + force_crit | secondary | **New — on-evade hook**; leap-cd and force_crit plumbing exist | — |
| Chapel Knell | A | Aegis Mace | res+res+hp [3] | `knell` | Each answered blow is a knell that mends: Aegis's smite-backs heal you. | +1% max HP per Aegis smite | no | Reuse — Aegis smite counter + heal | Lane 1: Aegis-window only |
| The Bastion's Answer | S | Aegis Mace | res+res+hp [3] | `answer` | The wall keeps accounts: a share of all damage you take is banked as holy charge, spent by your next Judgment's SMITE. | 30% of damage taken → `holy_charge` bank (existing SMITE spend path) | no | Reuse — `holy_charge` bank exists (overheal→SMITE); new deposit source | — |
| Pilgrim's Burden | A | Warmaul | massive | `burden` | The burden makes the blow: Judgment strikes heavier but swings slower. | Judgment +25% damage; Judgment cd +15% (audit fix 2026-07-28: 15/15 was an exact wash — sustained contribution 0; net ≈ +8.7% on the lane now) | no | Reuse — ability-scoped mults | Lane 2 BARGAIN: the cd tax |
| Dawnfall, Hammer of the Final Oath | S | Warmaul | massive | `dawnfall` | The last oath falls like dawn: Conviction's stance-swap slam hits harder, and everything it strikes is left burning and slowed in the light. | ult slam +30%; 0.3× atk holy burn + 30% slow, 3s | no | Reuse — ult coeff mult + burn/slow riders (dawnbreaker's burn convention) | — |

---

## 8. Warlock

| Unique | Grade | Shape | Bias | Passive name | Effect | Rough magnitude (placeholder) | Off-meta? | New mechanic or reuse? | A-drawback (if any) |
|---|---|---|---|---|---|---|---|---|---|
| Ink of Teeth | A | Grimoire | magpen [1] | `inkteeth` | The ink bites: Shadowbolt leaves stacking teeth-marks that gnaw. | 0.15× atk DoT, 2s, stacks to 3 | no | Reuse — dot rider, stacking | Lane 1: ramp per target |
| The Book That Remembers You | S | Grimoire | magpen [1] | `remembrance` | Whoever wounds you is written down: any enemy that damages you is automatically HEXED — exposed, withered, primed to explode. | full `_hex_mark` on your attacker; 3s per-enemy internal cd | no | Reuse — `_hex_mark` + on-hit-taken hook | — |
| Debtcollector | A | Hexblade | atk+crit [2] | `collection` | Debts accrue interest: crits against hexed enemies collect — bonus damage and a little mana back. | +30% crit damage vs hexed + 2 MP refund | no | Reuse — conditional-on-hex crit bonus | Lane 1: needs Hex up first |
| Black Clause, Edge of the Final Bargain | S | Hexblade | atk+crit [2] | `clause` | The clause can be invoked early: a crit against a hexed enemy detonates its hex at half strength — without consuming it. | early `_hex_detonate` at 50%, hex stays; 1s internal cd | no | Reuse — `_hex_detonate` at partial scale (needs a scale param) | — |
| Hushbone | A | Whisper Rod | dex+eva [2] | `hush` | What misses you feeds the silence: after an evade, your next Shadowbolt strikes twice. | echo at 50%, 2s window | secondary | **New — on-evade hook** (§11.1) | Lane 1: one echo per dodge |
| The Name Beneath All Names | S | Whisper Rod | dex+eva [2] | `truename` | Dodge a blow and you have heard the attacker's true name: they are hexed on the spot and lashed by shadow. | attacker hexed (full `_hex_mark`) + 0.8× shadow lash (`_beam_fx`) | **secondary (eva warlock)** | **New — on-evade hook**; hex/beam reuse | — |
| Bound Witness | A | Pactshield Codex | res+res+hp [3] | `witness` | The book sees who struck you: attackers are BOUND — withered and slowed. | 0.2× atk DoT + 40% slow, 3s; 1s internal cd | no | Reuse — on-hit-taken hook + dot/slow riders | Lane 1: the lesser cousin of `remembrance` (no expose, no death-explosion) |
| The Cover Between Worlds | S | Pactshield Codex | res+res+hp [3] | `thecover` | When a blow would break you, the cover opens: heavy damage reduction and a repulsing void-wave that shoves the room off you. | on a hit that would drop you below 30% HP: 50% DR for 2s + voidmaw-style shove (no curse); 25s internal cd | no | Reuse — `dr_time` + `_voidmaw_wave` shove geometry | — |
| Veinroot | A | Grimheart Staff | hp+VIT [2] | `veinroot` | The root drinks from your own reserve: Dark Pact's blast draws extra force from your max HP, and its surge lingers. | Pact blast +4% of max HP as damage; surge +2s | **yes** | Reuse-adjacent — small HP→damage on one ability (§11.5) | Lane 1: one ability, small conversion |
| Red Reliquary, Staff of the Last Pulse | S | Grimheart Staff | hp+VIT [2] | `lastpulse` | Every pulse of stored blood is power: your abilities gain attack from your bonus max HP — and for a spell after Dark Pact, the conversion runs doubled. | +1 atk per ~15 bonus max HP; ×2 conversion for 5s after Dark Pact | **yes** | **New — HP→power conversion** (shared mechanic with `worldroot`, §11.5) | — |

---

## 9. Reconciling S_GEAR class legendaries with the named-S uniques

**SUPERSEDED (owner call, 2026-07-27, after ship):** there is NO legendary
tier and NO awakening questline. The six flagship passives were TRANSPLANTED
onto fitting named-S uniques — kingsblade → Crownfall, windward → Tempest
Yew, wellspring → Firmament, mirrorstep → Pale Flight, dawnbreaker →
Dawnfall, voidmaw → The Book That Remembers You — live on pickup like every
unique. The displaced six designs (aftershock, gale, skyfall, heartbeat,
dawnfall, remembrance) stay wired and dev-injectable, unreferenced by any
item, re-homeable whenever wanted. Old-save legendaries grandfather in live.
The awakened-skin forms retired with the flag (the Phantom defaults to its
awakened body; the blue body is its own parked elite skin). The section
below is kept as the superseded recommendation record.

Each class now has **one S_GEAR weapon legendary** (Kingsbane etc., with the six
real passives and their awakening quests) **and five named-S weapon uniques**.
Today `roll_item_of` still stamps S_GEAR onto *every* S weapon (§7 of the shape
matrix calls this the interim inconsistency). Recommendation:

1. **The legendary becomes the class's 6th named-S weapon** — same tier, not a
   tier above. It keeps what makes it special: it is **shape-agnostic** (rides
   whatever matrix shape rolled, per the 2026-07-26 noun drop), its passive
   keys the class's *core identity* rather than one shape's build, and it alone
   keeps the **awakening quest** (dormant until awakened). Named uniques' new
   passives are live on pickup — the quest gate stays a legendary-exclusive
   prestige beat, not a 60-quest content debt.
2. **Generic S drops its passive** at the same moment the uniques gain theirs —
   the drop-source split (`roll_item_of` emitting generic vs named) and this
   passive pass should land as ONE change, exactly as items.gd's comment
   already plans.
3. **Power target: legendary ≈ named-S unique.** The legendary trades shape
   specificity for kit-wide fit and the quest story. If the bench later shows
   the six legendaries lagging the best shape uniques, buff the legendary
   rather than nerfing the unique — the quest should never gate a worse item.
4. **Known adjacencies to watch at the bench** (same-slot, so never stacking,
   but they compete for the same build): `windward` vs Green Ruin (both touch
   Second-Wind-adjacent sustain — one pays the untouched, one pays the hit;
   opposite builds, fine); `dawnbreaker` vs Dawnfall (pillar-on-Judgment vs
   ult-slam burn — different beats, fine); `wellspring` vs Squall/Breathless
   (cd economy vs proc windows); `mirrorstep` vs Pale Flight (both dash-economy
   — Pale Flight must not out-dash the legendary); `voidmaw` vs The Cover
   (offensive room-curse vs defensive panic shove); `kingsblade` vs Throneless
   (wave-on-Cleave vs echo-on-crit — Throneless is the crit-build's sidegrade,
   as intended).

---

## 10. Open questions / needs owner call

1. **Awakening gate:** confirm named uniques' passives are live on pickup with
   no quest (recommendation §9.1). If the owner wants gates on named-S too,
   that is 30 quests of content debt — flagging the cost.
2. **Attribute-scale override (Vowspike/Noonday):** a weapon that rewrites
   INT/STR conversion changes what the character sheet means while held. It is
   the single strongest off-meta enabler in this pass — and the most invasive
   mechanic. Bless or veto before anything else is built on the pattern.
3. **Guaranteed-crit procs vs CAP_CRIT:** hunt rhythm's forced crit is the
   precedent — confirm forced crits from passives are likewise cap-exempt
   (they are earned procs, not stat). Affects Red Horizon, Skyline, White
   Hart, Ninth Star, First Light.
4. **On-evade hook ICD:** one shared internal cooldown value (suggest 1–2s) or
   per-passive? A 50%-eva endgame build procs a LOT; the hook needs one global
   answer before six passives ride it.
5. **Cheat-death overlap:** The Hand That Refused Death shares the pattern
   with paladin `last_rites`. OK for two classes to have cheat-death, or
   should the assassin version become something else?
6. **Firmament vs Crystal Archmage's Starfall:** the second-meteor design was
   deliberately kept simpler than the skin ult's recursion, but they rhyme.
   Close enough to bother? (The skin is presentation-tier; this is gear-tier.)
7. **Visible-cue budget:** counter passives (Ninth Star's 9-count, Decree's
   3-cycle, Arithmetic's 4-count) want a small HUD pip to honor NO SILENT
   EFFECTS. One shared "passive counter" pip on the weapon slot, or per-proc
   floating text only?
8. **A-bargain tooltips:** confirm drawbacks print on the item card in full
   (assumed yes per no-silent-effects; affects tooltip layout for lane-2 As).
9. **Root as an enemy state (§11.7):** add a true root rider, or approximate
   with a 90% slow? Green Ruin and Verdancy both want it.
10. **Execute thresholds:** Quietus (20% true-damage band) and Headsman (12%
    behead) introduce sub-ult execute lines. Comfortable with executes living
    on gear, or reserve executes for ults/resonance (Hunger)?

---

## 11. Needs new code mechanics

Ordered by how many passives ride each; everything not listed reuses existing
riders/patterns as noted per row.

1. **On-evade trigger hook** — a single dispatch point where an evaded hit
   (passive eva or ability dodge) notifies the equipped passive, with a shared
   ICD. Consumers: `outrider`, `horizon`, `foxfire`, `mothdust`, `heartbeat`,
   `breathless`, `measure`, `vigil`, `hush`, `truename` (10 passives — build
   once, the whole finesse column lights up).
2. **Parry** (`parry`) — negate an incoming melee hit + riposte counter. New
   verb; nothing negates-with-answer today (Tumble negates, Aegis answers —
   this fuses them on a chance roll).
3. **Cheat-death generalization** (`refusal`) — the paladin `last_rites`
   pattern extracted so a weapon can grant it.
4. **Per-item ATTR_SCALE override** (`vow`, `noonday`) — held-weapon modifies
   the class's attribute conversion table. Most invasive item in the pass
   (§10.2).
5. **HP→power conversion** (`worldroot`, `lastpulse`, lite: `veinroot`) — atk
   derived from bonus max HP, recomputed with gear/level changes. One
   mechanic, two flagship off-meta items.
6. **Execute threshold on gear** (`headsman`, adjacent: `quietus`) — the
   Death-Mark/Hunger execute logic exposed as a passive-driven kill rule.
7. **Enemy root rider** (`bramble`, `worldroot`) — a held-in-place state
   distinct from slow/stun, or an owner-approved 90%-slow stand-in.
8. **Full-pen / armor-ignore hit flag** (`decree`, `gapfinder`, `farsight`) —
   per-hit "treat physres as X%" modifier (magres cousin already implied by
   `axiom`'s true-damage share, which reuses `true_frac`).
9. **Partial-scale hex detonation** (`clause`) — `_hex_detonate` gains a scale
   param and a no-consume path.
10. **Damage-taken → holy_charge deposit** (`answer`) — new deposit source
    into the existing bank/spend path.

Everything else in the tables is riders (`dot`/`slow`/`stun`/`splash`/`burn`/
`vuln`/`force_crit`/`knock`), counters on the hunt-rhythm pattern, ability-cd
scoped mults on the `wellspring` precedent, and whole-ability re-invocations
(Consecration, Arrow Storm echo, `_meteor_at`) — all existing machinery.
