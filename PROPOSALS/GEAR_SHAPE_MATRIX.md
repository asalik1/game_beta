# PROPOSALS — Gear shape matrix (design spec)

**Status:** the *mechanism* shipped 2026-07-26 (§1). The *matrix* — every class
able to build toward every stat group in every slot — is what this document
specifies. §4 onward is not implemented.

Read §3 and §6 before authoring anything. Read §7 if you are generating art.

---

## 1. The rule (shipped)

**A shape never grants a stat.** It biases the roll on two axes:

| Axis | Effect | Code |
|---|---|---|
| Pool weight | a biased stat is `bias`× as likely to be drawn | `Items._weighted_take` |
| Magnitude | it rolls `bias`× bigger | `Items.roll_subs` |
| *(consequence)* | its quench **ceiling** rises with it | `Items.stat_band` |

`Items.shape_bias()` is the single reader, so roll / reforge / quench-band can
never disagree about a stat's ceiling. The magnitude axis is what makes a shape
worth farming: a crit-leaning dagger reaches a crit number a cleaver cannot.

Nothing is promised. A crit dagger that draws three defensive substats is a bad
dagger, and the bench is the way out. The shape tells you what to *farm*, not
what you *get*.

A shape's other half is `main`, the class-attribute budget multiplier. It never
rolls and never varies.

---

## 2. Stat groups

The pool is 11 stats (`Items.SUBSTATS`). They group into five, plus one flagged
addition:

| Group | Stats |
|---|---|
| **pen** | `physpen`, `magpen` |
| **atk** | `atk_pct` |
| **crit** | `crit` |
| **res** | `physres`, `magres`, `critres` |
| **defense** | `hp_pct`, `VIT` |
| **finesse** | `dex`, `eva` |

Six groups, eleven stats, nothing orphaned. Finesse matters as much as the rest:
`dex` is the *only* answer to enemy evasion (`Stats.dex_tier` — below parity a
dodge is a clean miss), and the endgame SLIPPERY affix is built around players
being able to chase it.

**Counting coverage counts GROUPS, not stats.** A three-stat shape biasing
`hp_pct` + `VIT` + `physres` covers two groups, not three — the first two are the
same group. Spending two of your three slots inside one group is usually a waste
of a shape's coverage, and the audit at the end of §5 is done in group terms.

`physpen`/`magpen` and `physres`/`magres` are independent pool entries. Biasing
one does not touch the other, and both can land on one item — intended, since
each resistance runs through its own `Stats.res_frac` curve, so splitting beats
stacking.

---

## 3. The two authoring rules

### Rule 1 — breadth costs depth, by stat count alone

A shape spends a flat budget: **`Σ (bias − 1.0) = 0.60`**.

| Stats biased | Bias each | Ceiling on any one stat |
|---|---|---|
| 1 | **1.60** | highest in the game |
| 2 | **1.30** | −19% vs focused |
| 3 | **1.20** | −25% vs focused |
| 0 (*massive*) | — | spends nothing; buys `main` instead |

Nothing else changes the tax. A shape biasing crit + pen pays exactly what a
shape biasing crit + physres pays — count is the only input. A single-stat shape
biases harder *and* quenches to a higher cap than any multi-stat shape, which is
the whole trade: specialists reach further, generalists cover more.

**Massive is a real choice, not an absence.** A shape with no bias carries its
identity in a big `main` — that is what a player picks when they want raw
attribute points. Rough guide: `main ≥ 1.2` → no bias. Keep at least one per
class per slot where a crude, heavy object makes sense.

### Rule 2 — the bias must follow from the object

The physical thing decides the stats. Weight, edge, material, make.

An **ultra-light cloak biasing physres is a bug**, not a design choice. A pike
punches through plate, so it leans pen. A spiked harness cuts back, so it leans
offense despite being armor. A cloak grown from living wood leans hp and VIT.

Code cannot check this. It is a review criterion on every entry, and it is what
keeps the art brief and the stat table describing the same object. If a name and
its bias need a paragraph to reconcile, the name is wrong.

---

## 4. The coverage contract

**Every class must be able to build toward every group, in every slot.**

Four slots × six classes × six groups. Coverage is a jigsaw, not a grid — a class
does not need one shape per group. One shape can cover three groups and another
covers one; what matters is that the class's shapes *for that slot* span all six
between them.

How the split falls varies by class, because it follows from what that class's
gear physically is. An assassin covers res with two light garments; a warrior
covers it with one slab of plate.

### What this changes structurally

Today only **weapons** have class-specific nouns (`Items.CLASS_WEAPONS`). Armor,
boots and charm draw from one shared list — every class loots the same `Plate`,
`Mail`, `Guard`. That is the lazy part: an assassin and a warrior cannot
plausibly wear the same object.

**All four slots need per-class noun lists.** `roll_item_of` currently special-
cases `slot == "weapon"`; it becomes a general per-class-per-slot lookup.

**Back-compat:** every retired noun stays in `SHAPE_STYLE` forever, even once it
leaves `SLOT_NAMES`. Saved items carry their noun, and a missing entry silently
falls back to `DEFAULT_STYLE` — the item would quietly lose its identity. `Kunai`
is the existing precedent.

---

## 5. The noun matrix

Notation: **[1]** = single stat @1.60 · **[2]** = two @1.30 · **[3]** = three
@1.20 · **[M]** = massive, no bias, high `main`.

Names are proposals. What is *not* negotiable is that each one's bias reads
obviously from the object (Rule 2).

**Five shapes per class per slot.** Four biased plus, where a crude heavy object
makes sense, one massive. Every block below covers all six groups — the coverage
column names the groups, so a hole is visible at a glance rather than needing to
be reasoned out.

### Warrior — steel, plate, brutal, martial

| Slot | Noun | Bias | Groups | Why the object justifies it |
|---|---|---|---|---|
| weapon | Pike | physpen **[1]** | pen | a spear point exists to punch plate |
| weapon | Warblade | atk, crit **[2]** | atk, crit | balanced killing steel |
| weapon | Saber | dex, eva **[2]** | finesse | light cavalry blade — a warrior's fast option |
| weapon | Bulwark Blade | physres, magres, hp_pct **[3]** | res, defense | sword-and-guard; you fight from behind it |
| weapon | Claymore | — **[M]** | — | too heavy to do anything but land |
| armor | Wardsteel Plate | magres **[1]** | res | rune-etched against spellfire |
| armor | Ironwall Plate | physres, critres **[2]** | res | thick and angled; turns a blow aside |
| armor | Skirmisher's Halfplate | dex, eva **[2]** | finesse | cut away at the joints, made to move |
| armor | Bloodforged Harness | atk, crit, physpen **[3]** | atk, crit, pen | spiked and bladed — armor that cuts back |
| armor | Titanplate | hp_pct, VIT **[2]** | defense | sheer mass |
| boots | Wardstep Greaves | magres **[1]** | res | warded plate below the knee |
| boots | Sabatons | physres, critres **[2]** | res | armored foot, braced stance |
| boots | Skirmisher's Boots | dex, eva **[2]** | finesse | stripped-down march boot |
| boots | Reaver Treads | atk, crit, physpen **[3]** | atk, crit, pen | cleated; built to charge and stomp through |
| boots | Anchorplate | hp_pct, VIT **[2]** | defense | you do not move, you endure |
| charm | Warbanner | atk **[1]** | atk | the banner drives the swing |
| charm | Oath Sigil | physres, magres **[2]** | res | a sworn ward against both |
| charm | Butcher's Token | crit, physpen **[2]** | crit, pen | a trophy of finding the gap |
| charm | Duelist's Knot | dex, eva **[2]** | finesse | a swordsman's token — footwork, not force |
| charm | Heart of the Wall | hp_pct, VIT, critres **[3]** | defense, res | endurance made an icon |

### Archer — leather, yew, feather, wind

| Slot | Noun | Bias | Groups | Why the object justifies it |
|---|---|---|---|---|
| weapon | Warbow | atk **[1]** | atk | raw draw weight, nothing clever |
| weapon | Longbow | crit, physpen **[2]** | crit, pen | long draw, heavy punch-through |
| weapon | Hunting Bow | dex, eva **[2]** | finesse | light and quick, made for moving |
| weapon | Thornbow | physres, magres, hp_pct **[3]** | res, defense | living warded wood, grown as a guard |
| weapon | Recurve | — **[M]** | — | a plain slab of horn and sinew |
| armor | Stormweave Jerkin | magres **[1]** | res | oiled and charm-woven against spell and weather |
| armor | Studded Brigandine | physres, critres **[2]** | res | riveted plates over leather |
| armor | Ranger's Leathers | dex, eva **[2]** | finesse | cut to move, not to stop a blow |
| armor | Hunter's Harness | atk, crit, physpen **[3]** | atk, crit, pen | quivers, straps, everything pointed outward |
| armor | Beastpelt | hp_pct, VIT **[2]** | defense | thick hide with the claws still on |
| boots | Piercer's Cleats | physpen **[1]** | pen | spiked; the shot starts at the ground |
| boots | Windstriders | eva, dex **[2]** | finesse | barely touch the ground |
| boots | Marksman's Stance | crit, atk **[2]** | crit, atk | planted and braced for the held shot |
| boots | Wardedsole | physres, magres, critres **[3]** | res | charm-stitched against what the ground hides |
| boots | Trailboots | hp_pct, VIT **[2]** | defense | walked a thousand miles, will walk more |
| charm | Fletcher's Token | crit **[1]** | crit | the perfect nock, every time |
| charm | Windfeather | eva, dex **[2]** | finesse | weightless, always in motion |
| charm | Hunter's Totem | atk, physpen **[2]** | atk, pen | the kill, and what it takes to reach it |
| charm | Stonebark Ward | physres, critres **[2]** | res | bark that already survived worse |
| charm | Greenheart Idol | hp_pct, VIT, magres **[3]** | defense, res | the forest's own endurance |

### Assassin — silk, shadow, leather, poison

| Slot | Noun | Bias | Groups | Why the object justifies it |
|---|---|---|---|---|
| weapon | Stiletto | physpen **[1]** | pen | a needle made only to find the gap |
| weapon | Shuriken | crit, atk **[2]** | crit, atk | thrown steel; placement is everything |
| weapon | Glasswing | dex, eva **[2]** | finesse | a paper-light blade you fight *around* with |
| weapon | Warded Fang | physres, magres, hp_pct **[3]** | res, defense | heavy parrying dagger, knuckle-guarded |
| weapon | Cleaver | — **[M]** | — | a brutal lump; the exception in the kit |
| armor | Shadowveil Cloak | magres **[1]** | res | woven to swallow a spell |
| armor | Warded Mantle | physres, critres **[2]** | res | layered and plated at the shoulder |
| armor | Gossamer Cloak | dex, eva **[2]** | finesse | you feel the draught through it |
| armor | Nightsilk Wrap | physpen, atk, crit **[3]** | pen, atk, crit | weighs nothing; every gram is a blade |
| armor | Verdant Shroud | hp_pct, VIT **[2]** | defense | living cloth, grown not sewn |
| boots | Slipsteps | eva **[1]** | finesse | purely not being there |
| boots | Prowlers | crit, dex **[2]** | crit, finesse | soft-soled; you arrive before you are heard |
| boots | Venomtread | physpen, atk **[2]** | pen, atk | needled sole, coated |
| boots | Ironsole Wraps | physres, magres, critres **[3]** | res | bound and plated under the cloth |
| boots | Grave Treads | hp_pct, VIT **[2]** | defense | heavy, patient, made to outlast |
| charm | Killer's Mark | crit **[1]** | crit | one cut, in the right place |
| charm | Poisoner's Vial | physpen **[1]** | pen | a coated needle; armour is not a barrier |
| charm | Ghostlight Charm | eva, dex **[2]** | finesse | never quite where the eye lands |
| charm | Bloodoath Cord | atk, physres **[2]** | atk, res | a debt that cuts and shields |
| charm | Wraithbone Fetish | hp_pct, VIT, magres **[3]** | defense, res | stolen endurance |

### Mage — silk, crystal, star, arcane

| Slot | Noun | Bias | Groups | Why the object justifies it |
|---|---|---|---|---|
| weapon | Scepter | magpen **[1]** | pen | shaped to bore straight through a ward |
| weapon | Starfocus | crit, atk **[2]** | crit, atk | a cut crystal concentrates the bolt |
| weapon | Zephyr Rod | dex, eva **[2]** | finesse | weightless; it moves before you decide to |
| weapon | Bloomstaff | hp_pct, VIT, magres **[3]** | defense, res | still-living wood, warded and rooted |
| weapon | Greatstaff | — **[M]** | — | a tree with a stone on it; raw capacity |
| armor | Silk Vestments | magres **[1]** | res | thread spun against spellwork |
| armor | Runeplate Robe | physres, critres **[2]** | res | sigil-plates sewn over the panels |
| armor | Featherweave Robe | dex, eva **[2]** | finesse | it never quite hangs still |
| armor | Starweave Robe | atk, crit, magpen **[3]** | atk, crit, pen | every seam an amplifier |
| armor | Earthen Robe | hp_pct, VIT **[2]** | defense | heavy clay-dyed wool, grounded |
| boots | Starstep | crit **[1]** | crit | the cast lands where the foot points |
| boots | Levitation Slippers | eva, dex **[2]** | finesse | you are not quite standing on it |
| boots | Sigil Sandals | magpen, atk **[2]** | pen, atk | the ground carries the cast |
| boots | Wardstone Shoes | physres, magres, critres **[3]** | res | three stones, three wards |
| boots | Rootbound Sandals | hp_pct, VIT **[2]** | defense | grown into you |
| charm | Arcane Orb | magpen **[1]** | pen | a single, pointed intent |
| charm | Starshard | crit, atk **[2]** | crit, atk | a fragment of something that burned |
| charm | Aegis Crystal | physres, magres **[2]** | res | a ward you carry |
| charm | Zephyr Sigil | dex, eva **[2]** | finesse | the air moves you out of the way |
| charm | Lifebloom Pendant | hp_pct, VIT, critres **[3]** | defense, res | it keeps you upright |

### Paladin — blessed plate, gold, oath, light

| Slot | Noun | Bias | Groups | Why the object justifies it |
|---|---|---|---|---|
| weapon | Lance | magpen **[1]** | pen | holy point; wards part for it |
| weapon | Oathflail | atk, crit **[2]** | atk, crit | a swung chain finds openings |
| weapon | Duelist's Blade | dex, eva **[2]** | finesse | light consecrated arming sword |
| weapon | Aegis Mace | physres, magres, hp_pct **[3]** | res, defense | mace-and-shield; the pair is the weapon |
| weapon | Warmaul | — **[M]** | — | consecrated weight, nothing more |
| armor | Templar Plate | physres **[1]** | res | plain, thick, consecrated steel |
| armor | Blessed Plate | magres, critres **[2]** | res | faith wards spell before steel |
| armor | Vigil Halfplate | dex, eva **[2]** | finesse | the watch-keeper's kit — light enough to run in |
| armor | Zealot Harness | atk, crit, magpen **[3]** | atk, crit, pen | gilded, bladed, built to advance |
| armor | Sanctified Bulwark | hp_pct, VIT **[2]** | defense | a wall that prays |
| boots | Zealot's Cleats | crit **[1]** | crit | the charge lands where it must |
| boots | Sabatons of the Oath | physres, magres **[2]** | res | you do not step back |
| boots | Vigil Steps | dex, eva **[2]** | finesse | soft-soled, for the long watch |
| boots | Radiant Greaves | magpen, atk **[2]** | pen, atk | the light goes ahead of the step |
| boots | Pilgrim's Resolve | hp_pct, VIT **[2]** | defense | miles of road, still walking |
| charm | Reliquary | magres **[1]** | res | a saint's bone against a curse |
| charm | Sunburst Icon | atk, crit **[2]** | atk, crit | the light at its sharpest |
| charm | Judgment Sigil | magpen **[1]** | pen | nothing stands between the verdict and the guilty |
| charm | Swiftvow Cord | dex, eva **[2]** | finesse | a vow of speed, not of standing |
| charm | Oathkeeper's Seal | hp_pct, VIT, physres **[3]** | defense, res | the promise that keeps you standing |

### Warlock — pact, bone, void, blood

| Slot | Noun | Bias | Groups | Why the object justifies it |
|---|---|---|---|---|
| weapon | Grimoire | magpen **[1]** | pen | the written word goes through anything |
| weapon | Hexblade | atk, crit **[2]** | atk, crit | a cursed edge, and it does cut |
| weapon | Whisper Rod | dex, eva **[2]** | finesse | thin as a finger bone, always drifting |
| weapon | Pactshield Codex | physres, magres, hp_pct **[3]** | res, defense | a book bound in something that protects |
| weapon | Grimheart Staff | hp_pct, VIT **[2]** | defense | HP is the warlock's fuel; this holds more |
| armor | Voidsilk Robe | magres **[1]** | res | it eats the spell |
| armor | Bonemail | physres, critres **[2]** | res | plated in something that used to be someone |
| armor | Shadeweave Robe | dex, eva **[2]** | finesse | more shadow than cloth |
| armor | Ruinweave | atk, crit, magpen **[3]** | atk, crit, pen | every rune is an insult to a ward |
| armor | Bloodpact Vestment | hp_pct, VIT **[2]** | defense | more fuel for the pact |
| boots | Ruinstep | crit **[1]** | crit | the curse lands hardest where you stood |
| boots | Shadowstep Wraps | eva, dex **[2]** | finesse | half in the dark already |
| boots | Hexcarved Treads | magpen, atk **[2]** | pen, atk | the ground carries the curse |
| boots | Bonewalkers | physres, magres, critres **[3]** | res | three bindings, three protections |
| boots | Gravebound Boots | hp_pct, VIT **[2]** | defense | heavy with what it took |
| charm | Soul Fetish | magpen **[1]** | pen | it has already been inside them |
| charm | Cursed Idol | crit, atk **[2]** | crit, atk | it wants the kill |
| charm | Ward of Ash | physres, magres **[2]** | res | what is left of a bigger protection |
| charm | Umbral Cord | dex, eva **[2]** | finesse | it pulls you a half-step out of the world |
| charm | Heartcage | hp_pct, VIT, critres **[3]** | defense, res | it keeps the pact solvent |

### Coverage audit

**All 24 class × slot blocks cover all six groups.** Read the Groups column down
any block: pen, atk, crit, res, defense, finesse each appear at least once.

Finesse was the hole in the first draft of this document — warrior had no
`dex`/`eva` option in weapon, armor *or* charm; mage and warlock had none in
weapon or armor; assassin had none in armor. Every one is now filled with a shape
whose *object* justifies it rather than by bolting `eva` onto plate:

- warrior → **Saber**, **Skirmisher's Halfplate/Boots**, **Duelist's Knot**
- paladin → **Duelist's Blade**, **Vigil Halfplate/Steps**, **Swiftvow Cord**
- mage → **Zephyr Rod**, **Featherweave Robe**, **Zephyr Sigil**
- warlock → **Whisper Rod**, **Shadeweave Robe**, **Umbral Cord**
- assassin → **Glasswing**, **Gossamer Cloak**

The heavy classes get finesse through a *deliberately light variant* of their own
kit — a cavalry saber, stripped halfplate, a duelist's token. That satisfies Rule
2: a warrior can plausibly own a fast, light thing, and the name says so. What is
not allowed is an "Ironwall Plate" that quietly grants evasion.

**This is the check to automate.** A coverage assertion over all 24 blocks would
have caught every one of these holes at authoring time — see §6.

### Settled: a class never biases its OFF-type pen

Every class leans only toward its own damage type's penetration — `physpen` for
warrior / archer / assassin, `magpen` for mage / paladin / warlock. **No shape in
the matrix biases both pens.**

This is a decision, not an omission — do not "fix" the asymmetry later. The
assassin's Poisoner's Vial originally carried `physpen, magpen [2]` and was the
only dual-pen shape in the game; it was cut to `physpen [1]` on 2026-07-26.
Reasons, in order:

1. An assassin takes physpen every time, so the magpen half was a dead line on a
   real build.
2. Dropping to one stat moves it from **1.30 → 1.60**, which raises the physpen
   *ceiling* by 23% — strictly better for the build anyone actually runs.
3. It makes the rule uniform across all six classes.

Off-type pen is still **rollable** on any grade below S (`roll_subs` only erases
it on an S first roll, per the 2026-07-17 rune-reroute note) — it just can never
be *chased*. Dormant, not dead, and not build-toward-able.

Coverage is unaffected: the assassin charm block still spans all six groups, with
pen carried by physpen alone.

---

## 5b. The full 7-slot lineup — helmet, gloves, pants (2026-07-26)

Owner call: the standard-gear lineup is **seven slots** —
`weapon · helmet · armor (chest) · gloves · pants · boots · charm`. Helmet,
gloves and pants are new. Two owner decisions frame them: **increase total gear
power, with a sensible distribution across all seven**, and **full matrix — every
slot lets a class build toward all six stat groups, five shapes per class per
slot** (not slot-leaning "character" pieces).

This section sets the STAT DISTRIBUTION (budgets + bias structure + shape names).
Passives (a later agent pass) and art (another) build on it. Nothing is wired into
code yet — the slots go live together with their art, exactly as weapons did.

### Slot main budgets — the 7-way rebalance

Every piece's main is the class primary attribute; the budget is how many points
it carries (× grade × shape main-mult). The existing four already sit in a sane
order (weapon dominant, chest the big armor, charm a solid stat-stick, boots
minor); the three new slots drop into that hierarchy:

| Tier | Slot | Budget | Was |
|---|---|---|---|
| dominant | weapon | 5.0 | 5.0 |
| major armor | armor (chest) | 3.0 | 3.0 |
| solid | helmet | **2.5** | — |
| solid | pants | **2.5** | — |
| solid | charm | 2.5 | 2.5 |
| minor | boots | 2.0 | 2.0 |
| minor | gloves | **2.0** | — |

**Total 12.5 → 19.5 (+56%).** The existing four are unchanged — the increase is
purely the three new slots, so no live gear loses power. The 2026-07-06 comment
pinning the L42 full-B benchmark to "~1–2% of the pre-attribute-mains envelope" no
longer holds: gear main is +56%, so the whole boss/mob curve shifts up. That is
the owner's step-4 recalibration, expected and deliberate. *(If a flatter power
jump is wanted later, trim the new slots or shave the existing ones — the ordering
is the part that should stay.)*

### The armor-family coverage template

Helmet, gloves and pants are the "defensive family." Rather than invent 6 fresh
group-mixes per class per slot, each class×slot draws **five shapes on one shared
coverage skeleton** — the same six-group span, only the *names* change per slot
and the pen is the class's on-type pen. This keeps every defensive slot fully
build-toward-able while staying legible. (Chest/boots migrate onto the same
skeleton when their matrix pass lands; today they still use the pre-matrix shared
shapes.)

| # | Covers (groups) | Bias | main-mult |
|---|---|---|---|
| A | res (magic ward) | `magres` **[1.60]** | 1.00 |
| B | res (physical) | `physres`, `critres` **[1.30]** | 1.05 |
| C | finesse | `dex`, `eva` **[1.30]** | 0.90 |
| D | atk + crit + pen (aggressor) | `atk_pct`, `crit`, `<on-type pen>` **[1.20]** | 0.95 |
| E | defense (bulwark) | `hp_pct`, `VIT` **[1.30]** | 1.10 |

`<on-type pen>` = `physpen` for warrior/archer/assassin, `magpen` for
mage/paladin/warlock. Each row spends the flat 0.60 bias budget (§3), so it passes
the budget assertion unchanged. Six groups across five shapes: res (A + B, incl.
critres), finesse (C), atk/crit/pen (D), defense (E).

### The 90 shapes (confirmed 2026-07-26)

Every name = class material + slot noun; the column is the profile (fixed A–E
coverage above; on-type pen per class). main-mult rides the profile (A 1.00 · B
1.05 · C 0.90 · D 0.95 · E 1.10). Names are first-pass — the art agent may refine
wording as long as the profile it maps to is unchanged.

**Warrior** — pen = physpen

| Slot | A ward · magres | B guard · physres+critres | C finesse · dex+eva | D aggressor · atk+crit+physpen | E bulwark · hp+VIT |
|---|---|---|---|---|---|
| helmet | Wardsteel Helm | Ironwall Helm | Skirmisher's Helm | Reaver Helm | Titan Helm |
| gloves | Wardsteel Gauntlets | Ironwall Gauntlets | Skirmisher's Gauntlets | Reaver Gauntlets | Titan Gauntlets |
| pants | Wardsteel Legplates | Ironwall Legplates | Skirmisher's Legplates | Reaver Legplates | Titan Legplates |

**Archer** — pen = physpen

| Slot | A ward · magres | B guard · physres+critres | C finesse · dex+eva | D aggressor · atk+crit+physpen | E bulwark · hp+VIT |
|---|---|---|---|---|---|
| helmet | Stormweave Hood | Studded Hood | Ranger's Hood | Hunter's Hood | Beastpelt Hood |
| gloves | Stormweave Bracers | Studded Bracers | Ranger's Bracers | Hunter's Bracers | Beastpelt Bracers |
| pants | Stormweave Leggings | Studded Leggings | Ranger's Leggings | Hunter's Leggings | Beastpelt Leggings |

**Assassin** — pen = physpen

| Slot | A ward · magres | B guard · physres+critres | C finesse · dex+eva | D aggressor · atk+crit+physpen | E bulwark · hp+VIT |
|---|---|---|---|---|---|
| helmet | Shadowveil Cowl | Warded Cowl | Gossamer Cowl | Nightsilk Cowl | Grave Cowl |
| gloves | Shadowveil Grips | Warded Grips | Gossamer Grips | Nightsilk Grips | Grave Grips |
| pants | Shadowveil Wraps | Warded Wraps | Gossamer Wraps | Nightsilk Wraps | Grave Wraps |

**Mage** — pen = magpen

| Slot | A ward · magres | B guard · physres+critres | C finesse · dex+eva | D aggressor · atk+crit+magpen | E bulwark · hp+VIT |
|---|---|---|---|---|---|
| helmet | Silkward Circlet | Runeplate Circlet | Featherweave Circlet | Starweave Circlet | Earthen Circlet |
| gloves | Silkward Handwraps | Runeplate Handwraps | Featherweave Handwraps | Starweave Handwraps | Earthen Handwraps |
| pants | Silkward Underleggings | Runeplate Underleggings | Featherweave Underleggings | Starweave Underleggings | Earthen Underleggings |

**Paladin** — pen = magpen

| Slot | A ward · magres | B guard · physres+critres | C finesse · dex+eva | D aggressor · atk+crit+magpen | E bulwark · hp+VIT |
|---|---|---|---|---|---|
| helmet | Blessed Greathelm | Templar Greathelm | Vigil Greathelm | Zealot Greathelm | Sanctified Greathelm |
| gloves | Blessed Gauntlets | Templar Gauntlets | Vigil Gauntlets | Zealot Gauntlets | Sanctified Gauntlets |
| pants | Blessed Legguards | Templar Legguards | Vigil Legguards | Zealot Legguards | Sanctified Legguards |

**Warlock** — pen = magpen

| Slot | A ward · magres | B guard · physres+critres | C finesse · dex+eva | D aggressor · atk+crit+magpen | E bulwark · hp+VIT |
|---|---|---|---|---|---|
| helmet | Voidsilk Hood | Bonemail Hood | Shadeweave Hood | Ruinweave Hood | Bloodpact Hood |
| gloves | Voidsilk Claws | Bonemail Claws | Shadeweave Claws | Ruinweave Claws | Bloodpact Claws |
| pants | Voidsilk Chausses | Bonemail Chausses | Shadeweave Chausses | Ruinweave Chausses | Bloodpact Chausses |

90 generic shapes (6 × 3 × 5), each class×slot spanning all six groups. **Uniques**
for these slots (one A + one S per shape = 180) are named at the art pass, like the
weapon uniques.

### Status & the build sequence

- **Confirmed** (owner, 2026-07-26): the +56% budget total and its tier ordering;
  the full-matrix call; the shared 5-profile coverage skeleton.
- **Chest + boots** still ride the pre-matrix shared 3-shape shapes. Folding them
  onto this same skeleton is a later pass — not blocking, since they already have
  working shapes and art.
- **Sequence from here:** art agent draws the 90 shapes + names the 180 uniques →
  passive agent → the code wiring that makes all 7 slots real. That wiring is its
  own step (SLOTS / SLOT_ICON / SLOT_MAIN_BUDGET, the equip-screen layout, save
  round-trip, gem-slot rules, `_roll_slot`, set bonuses) and lands with the art,
  exactly as weapons did. Budgets are applied to `SLOT_MAIN_BUDGET` at that point,
  not before — a half-wired slot would only muddy the current 4-slot balance.

---

## 6. Adding a shape — the checklist

Four tables must agree or the shape breaks silently:

1. **`Items.SHAPE_STYLE`** — `main`, `bias`, `tag`. Budget per §3.
2. **`Items.SLOT_NAMES[slot]`** *(becoming per-class)* — makes the noun rollable.
3. **`Items.CLASS_WEAPONS[cls]`** — which classes can loot it.
4. **`Art.GEAR_SHAPES[slot]`** — noun → sprite key.

**The silent failure:** a noun in `SLOT_NAMES` but missing from `GEAR_SHAPES` does
not error — `Art._shape_for` falls back to `shapes.values()[0]` and your new
sword renders as a Blade. **Now caught by the suite** (autotest, weapon shape
identities).

**Also enforced:** every biased stat exists in `SUBSTATS` (a bias on a non-pool
stat is dead data — that is what `hp_flat` on Hammer/Treads and `mp_flat` on
Staff/Tome were), and every roll carries exactly `sub_count_for(grade)` substats.

**Must be added with the matrix — two data assertions:**

1. **Budget** — `Σ(bias − 1.0) == 0.60` for every non-massive shape, and the
   per-stat value matches its count tier (1 → 1.60, 2 → 1.30, 3 → 1.20).
2. **Coverage** — for every class × slot, the union of its shapes' biased stats
   touches all six groups.

The coverage assertion is not optional polish. The first draft of this document
shipped holes in five of six classes — warrior had no `dex`/`eva` option in
weapon, armor or charm — and they were invisible because coverage was being
eyeballed per shape instead of computed per block. A human reading a 120-row
table will not catch this. A five-line loop will, every run.

**Codex:** the gear page lists shapes from `Art.GEAR_SHAPES` with their `tag`, so
a new shape appears with no code change. Write a `tag` that names the lean
honestly — the codex now tells players a tag means *leans*, not *grants*.

---

## 7. Art and naming

### Generic vs unique — the passive is the line (owner, 2026-07-26)

**A unique is generic-grade power PLUS a passive.** That is the entire
difference. A generic S and a named S have the same stat ceiling; the unique
additionally carries a signature passive, and it is rarer. Players chase uniques
for the passive, not for bigger numbers.

| Kind | Power | Passive | Name / art | Rarity | First drops |
|---|---|---|---|---|---|
| **Generic** F–S | grade curve, §3 bias | **none** | `PREFIXES[grade]` + noun, graded art | the baseline drop | generic **S**: **Act 2** |
| **Named A unique** | A-grade | **yes** | authored name, own sprite | rarer than generic | **Act 2** |
| **Named S unique** | S-grade | **yes** | authored name, own sprite | rarest | **Act 3** |

Drop schedule, stated plainly:

- **Act 2** — generic S becomes available *and* named A uniques begin dropping
  (at a lower rate than generic gear).
- **Act 3** — named S uniques begin dropping (rarest of all).

Every shape gets one named A and one named S (240 uniques, §"Named uniques"),
each carrying its own passive.

### PASSIVES — owner rule + the placeholder plan (2026-07-26)

**Only NAMED gear carries a passive** — the named A and named S uniques, and the
S_GEAR class legendaries. A **generic** A or S never does; it is just a
`Dragonforged`/`Emberforged <shape>` with top rolls. The plan extends passives to
**all four slots** (armor/charm/boots too, not only weapons) — so a full loadout
of named gear eventually stacks four passives, which is exactly why it needs a
dedicated **design phase + dps benchmark** before the numbers are set.

**Shipped (2026-07-27):** the weapon design phase landed — all 60 weapon
uniques carry a live signature passive (design + framework:
`PROPOSALS/GEAR_UNIQUE_PASSIVES.md`, the canonical record; knobs in
`Balance.UNIQ`, still un-benchmarked). Armor/boots/charm uniques + their
passives still await their shape matrix.

**Interim inconsistency, on purpose:** the target is generic S = no passive, but
`roll_item_of` still applies S_GEAR to *every* S weapon (the only in-game passive
source today). Ripping that out now would delete working content — the six
passives and their awakening quests — with nothing to replace it, so it waits for
the design phase, together with the generic-vs-named drop split (§8). A_NAMES,
which had no passives or quests, WAS retired now: generic A rolls a plain name.

### Already cleaned up (2026-07-26)

- **Legacy weapon shapes deleted** — Blade/Edge/Fang/Kunai/Bow/Crossbow/Staff/
  Wand/Hammer/Tome are gone from `SHAPE_STYLE`, `CLASS_WEAPONS`, `SLOT_NAMES` and
  `GEAR_SHAPES`. The matrix's 30 weapon shapes fully replace them. S_GEAR dropped
  its pinned legacy nouns (a legendary now rides whatever matrix shape rolled — its
  passive is ability-based, not shape-based), which was the last thing holding the
  legacy shapes open.
- **`A_NAMES` deleted** — generic A is a graded generic again.

Everything in this section below (art cascade, naming, the uniques record shape)
stands regardless of how the design phase resolves the passives.

### The override cascade (shipped)

`Art.item_icon` and `Art.weapon_tex` both resolve most-specific-first:

| Tier | File | Treatment |
|---|---|---|
| 0 | `item["art"]` → `assets/icons/<key>.png` | named unique, as authored |
| 1 | `assets/icons/<shape>_<grade>.png` | authored for that tier — no tint |
| 2 | `assets/icons/<shape>.png` | family sprite, gently tinted |
| 3 | *(procedural)* | built-in, hard tint + `_embellish` |

Every gear UI routes through `Art.icon_for`, so one `item["art"]` key lights up
bag, shop, mail, popovers, ground drops **and the hero's hand**. Missing files
fall through, so a unique can be declared before its art exists and a family can
be authored tier by tier.

Before 2026-07-26 `weapon_tex` read the procedural table only — authored art
changed the bag icon while the hero swung the built-in blade.

### Cost

120 shapes: 6 classes × 4 slots × 5.

| Ambition | Assets |
|---|---|
| Coverage only (tier 2, one sprite per shape) | 120 |
| Every shape at every grade (tier 1, full) | 840 |
| **Recommended: tier-1 on B/A/S, tier-2 below** | **480** |

Low grades are seen briefly and read fine tinted. B+ is where players live.

### Naming

`Items.PREFIXES` is a per-grade pool multiplied against the noun, so every new
shape inherits a name ladder for free — "Rusty Shuriken" → "Emberforged Shuriken".

**The gap is at the top.** F–B have four prefixes each; A and S have exactly one.
And **A never uses its prefix** — `roll_item_of` overwrites the name from
`A_NAMES`, so every A is nominally "named" while carrying no unique art, no
passive and no special bias. A name with nothing behind it, colliding with the
tier-2 concept.

**Recommended:** retire `A_NAMES` as an auto-override, let A roll as a graded
generic, widen the A and S prefix pools to four or five, and move the good names
(Widow's Bite, Oathbreaker, Dawnsplitter) into the unique table where they get
the art and passive the names promise.

### Named uniques

A record, not a prefix:

```gdscript
{
  "name": "End of Night", "slot": "weapon", "noun": "Shuriken", "grade": "S",
  "art": "u_end_of_night",                    # assets/icons/u_end_of_night.png
  "bias": {"crit": 1.9, "physpen": 1.5},      # over budget on purpose
  "passive": "nightfall",
}
```

- **`noun` is fixed** — stable shape, fantasy and in-hand silhouette.
- **`art` is its own sprite key** — shipped; outranks per-grade and family art.
- **`bias` may exceed §3** — suggested cap `Σ(bias−1.0) ≤ 1.20`, double the rolled
  budget. That headroom is why it is worth chasing.
- **A unique still grants nothing.** It leans harder. A bad roll is possible and
  stays the bench's problem.
- **No extra substats.** It rolls `sub_count_for(grade)` like anything else. Its
  edge is *which* stats it draws and *how high*, never *how many*.

**Still to build:** a `UNIQUES` table, a drop source (which chests, which bosses,
what rate), and `roll_item_of` teaching to emit one. `S_GEAR` is tier 3 already
and needs only `bias` and `art` fields per entry.

---

## 8. Build order

1. **Retune existing shapes to §3.** One-table edit — every current single-stat
   shape goes 1.5 → 1.60, multi-stat shapes drop to 1.30/1.20. Then a
   `dps_bench` pass, since the 2026-07-26 change already cut power and was never
   rebalanced.
2. **Per-class noun lists for armor / boots / charm.** The `roll_item_of`
   generalisation plus the four-table data for §5. Ship with the coverage
   assertion.
3. **Art, tier 2 first** — one sprite per new shape so nothing renders as a
   Blade, then tier 1 on B/A/S.
4. **Uniques** — table, drop source, then art per entry.
