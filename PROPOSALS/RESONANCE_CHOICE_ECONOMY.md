# Resonance Choice Economy — greed pays now, virtue pays later (2026-08-22)

Decision document. Nothing NEW installed. This captures a design PRINCIPLE for
how moral choices should pay out, grounded in the SHIPPED resonance layer, and
names the extension that makes the per-choice ACT carry the tension the meter
already carries. It is the connective tissue for this session's other proposals.

Sibling docs (referenced, not repeated): `DYNAMIC_WORLD.md` (situation = a verb
with a cost and a mark), `CLASS_IDENTITY.md` (§3 relationship gates + traitor
consequences, §2 class-refracted NPCs), `DESIGN.md` (per-Ember Virtue /
Temptation), `BALANCE_HISTORY.md` (the shipped leans, commit 41fb281), and the
resonance-greed-mechanical-layer notes.

---

## 0. The principle

> **Greed pays in currency, now. Virtue pays in relationships and time.**

Two payoffs in different denominations, so both genuinely tempt and neither
strictly dominates. Greed is a loan against the world's goodwill: an immediate,
consumable gain you spend at once, against a later cost the world reads back.
Virtue is the quieter deposit: sustain, thrift, trust, and marks that compound.
The greedy option should be tempting in the moment; the virtuous one is what a
hero would do and carries its OWN utility, just denominated differently.

---

## 1. What is SHIPPED — the meter layer (verified 2026-08-22)

Resonance is a per-character meter (−100..+100, Virtue vs Temptation), and it
already has real mechanical leans that ramp with conviction from the band line
(±25, `RES_LEAN_START`) to full at ±100 (`RES_LEAN_FULL`). Live constants
(`balance.gd:2600-2633`, funcs on `player_core.gd`):

- **Hunger (greedy / negative), at full lean:** +10% damage vs mobs under the
  25% wound line (`RES_HUNGER_EXEC_MAX` 0.10 / `RES_HUNGER_EXEC_AT` 0.25, mobs
  only, paying prey only) and +15% kill gold (`RES_HUNGER_GOLD_MAX` 0.15). Pure
  short-term farming power.
- **Constancy (virtuous / positive), at full lean:** +25% potion healing
  (`RES_CONSTANCY_HEAL_MAX` 0.25) plus the steady shop haggle. Sustain and
  thrift.
- **Favor converts by lean:** NPC favor cashes out at **1.25× for steady,
  0.75× for tempted** (`FAVOR_RES_STEADY_MULT` / `FAVOR_RES_TEMPTED_MULT`).
  Virtue literally turns relationships into more gold; greed less. This is the
  "virtue pays in relationships" denomination, already in code.
- **Greed is temporary by rule:** its only surge source is Gold Rush (+0.30
  greed for 150s from a rare paying-kill drop, `GOLDRUSH_*`), and greed is
  capped (`CAP_GREED` 0.40). There is a standing rule that **greed must never
  gain a permanent power source** — exactly the owner's "short-term / small
  benefit."
- **Conviction, not virtue:** fence-sitting near 0 gets NOTHING; you must commit
  to a side to be paid. Benchmarks pin resonance to 0 by convention.
- **Tuned to tie:** measured economically, the bands trade blows (greed earns
  more, virtue spends less and converts favor better), so neither is the
  obvious pick.

So the axis exists and is balanced to the owner's principle. The gap is where it
is expressed.

---

## 2. The gap — the CHOICE act carries no denomination

The leans are a PASSIVE meter effect: they scale off the resonance number in the
background. The per-CHOICE act does not carry the tension. Two symptoms:

- **Choices barely branch.** Of 24 side quests, 13 do not branch at all; the
  ones that do hand ±1-3 resonance plus one line of reply text
  (`DYNAMIC_WORLD.md` §0). The moral fork has no immediate, differentiated
  payoff.
- **The current per-choice reward is direction-BLIND.** A resonance delta pays a
  small flat gold/chest either way (`RES_REWARD_GOLD_BASE` 8 + 2/point; wood
  chest at |Δ|≥5, silver at ≥8 — `balance.gd:2612-2615`). So a greedy choice and
  a virtuous choice of the same magnitude pay the SAME thing. That is exactly
  the flatness to fix: the reward should differ by which way you leaned.

---

## 3. The extension — denominate every real fork

Make each genuine moral fork pay in its own currency, and nudge the meter that
already rewards that currency:

- **The greedy option** gives an IMMEDIATE, consumable gain — gold now, a
  skipped fight, a one-room buff, the loot kept — and nudges Hunger (which is
  itself short-term farming power). Spent at once.
- **The virtuous option** gives COMPOUNDING, relational utility — favor (which
  converts at 1.25× for the steady), an unlocked quest or better branch (the
  §3 relationship gates), an ally who returns later, a persistent `sq_kept_` /
  `chose_` mark the world reads back — and nudges Constancy (sustain, thrift).
  Deferred, but it accrues.

The rule: a fork is only real if BOTH sides carry utility. "Say the kind line or
the hard line" for the same reward is not a fork (the `DYNAMIC_WORLD.md` §1 verb
rule). And greed's benefit always carries a later cost or a mark, so it reads as
a loan, not a free lunch.

---

## 4. Why this is the keystone — it ties the session together

The greed/virtue choice economy is the connective tissue under every other
proposal from this thread:

- **Per-choice greedy/virtuous forks ARE** the `DYNAMIC_WORLD.md` doctrine "a
  situation is a verb with a cost and a mark."
- **Virtue's relational payoff IS** the `CLASS_IDENTITY.md` §3 favor/standing
  gates — the world helping you back.
- **Greed's deferred cost IS** the §3 traitor consequence (a closed door plus a
  darker one opening, a hunter sent, a colder greet).
- **It is class-refracted for free.** Each Ember already has a Virtue and a
  Temptation in lore (the assassin's is Sacrifice vs Consumption, "take what
  keeps you strong" — `DESIGN.md`). Leaning greedy means leaning into YOUR
  class's specific temptation, so the same fork reads differently per class.
  That is the answer to "every class runs the same journey": the greed/virtue
  fork, flavored per Ember, IS a distinctive journey. Route it through the
  `opened_<cls>` gate (`CLASS_IDENTITY.md` §1-2).

---

## 5. Guardrails (existing doctrine, kept)

- **Conviction, not virtue.** Fence-sitting stays unrewarded; both extremes feel
  earned; neutrality is leaving value on the table.
- **Greed never gains a permanent power source.** Immediate/consumable/temp
  only (`CAP_GREED`, Gold Rush is a 150s window). This is what keeps it a
  "short-term benefit."
- **No silent effects.** Every greedy consequence has a tell before and a codex
  line after (`DYNAMIC_WORLD.md` §1.5).
- **Gold stays in the chapter's replay envelope** (`econ_audit.gd`); a choice
  never becomes the best farm in its chapter.
- **Benchmarks pin resonance to 0** — never bench a class at a resonance
  extreme.

---

## 6. Build order & open questions

**Order:**
1. **Differentiate the per-choice reward by lean** (§2 fix) — the cheapest, most
   direct: a greedy fork pays immediate/consumable, a virtuous fork pays
   favor/mark, instead of the same flat gold either way.
2. **Author a handful of real forks** on the `DYNAMIC_WORLD.md` verb template,
   one per chapter, class-refracted where it fits.
3. **Wire the deferred marks** so greed's cost and virtue's compounding actually
   land later in the run/campaign (reuses `sq_kept_`/`chose_` + the traitor
   consequence).

**Open questions (owner):**
1. **How hard should greed's later cost bite** — a mark the world merely
   references (cheap), or a real consequence spawn (a hunter, a closed shop)?
2. **Virtue's headline currency** — favor/relationships (recommended, it is
   already denominated at 1.25×), unlocked content, or a small sustain boon?
3. **Should the meter leans get stronger** once choices carry their own payoff,
   or stay as the quiet background layer they are now?
4. **Neutral path** — keep "conviction, not virtue" (undecided gets nothing), or
   give the fence-sitter a small distinct utility of its own?

> Thesis: the game already pays greed in short-term power and virtue in sustain,
> and it already refracts both through each Ember's temptation. What it does not
> do is make the MOMENT of choice carry that. Denominate the fork — currency now
> for greed, relationships and time for virtue — and every other system this
> session touched (situations, relationship gates, class threads, traitor
> consequences) becomes one economy instead of five features.
