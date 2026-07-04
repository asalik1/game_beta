# Emberfall — Story & Design Bible

## Phase Plan (agreed 2026-07)

This document is the north star; not all of it ships at once.

**Phase 1 — launch (solo, Chapter 2):**
- **Six classes**: Warrior, Assassin, **Paladin** (new melee) / Archer, Mage,
  **Warlock** (new ranged). Three melee, three ranged. The LoL balance rule
  extends: Paladin gets bruiser base stats, Warlock pays the ranged damage tax
  like Mage.
- **Two joinable factions**: Ember Accord and Cinderborn carry the political
  questlines, recruitment arcs, and ending stakes. **Wildfang Tribes and Hollow
  Choir become ambient factions** — standing is tracked and they react to you
  through zone and side content, but you cannot pledge to them at launch. Their
  lore stays fully canon; it is what justifies repeatable beastkin/blight zones.
- **Resonance ships whole.** It is the hook. Nothing about the trim touches it.
- All four existing classes get their openings retrofitted from this document.

**Phase 2:** co-op, then the Hollow Throne raid.

**Expansion (deferred by design, not cut):**
- **Death Knight** — mechanically cheap but crowds the Warrior/Assassin
  identities at launch; the grave opening is the expansion's marketing beat
  ("the update where you claw out of your own grave"), and by then co-op gives
  its Hollow Choir alignment people to argue with.
- **Summoner** — the most expensive class in the book (pet AI, pet pathing,
  eventually pet netcode). Headline addition later, not launch class #6.
- Promoting an ambient faction to joinable is an expansion's political plot.

---

## Setting: Vaelscar

Vaelscar was never at peace — it was held together by a lie. Six hundred years
ago, the **Concord of Ash** bound five warring god-kings into mortal vessels,
stripping them of divinity to end the War of Cinders. The world spent centuries
pretending those gods were gone. They weren't. They were old, weak, and hiding
inside people.

The Concord is failing. One of the five — **Mórwyn, the Hollow Flame** — has
fully reawakened inside her vessel, a peasant blacksmith who never asked for any
of this. Her reawakening is cracking the seals on the other four.

---

## The Ember Crown — Origin of Classes

The Ember Crown wasn't one artifact. It was four Embers — primal fragments
carried by the founders of the original Ember Guard — bound together inside
whoever wore the crown. Vargoth didn't steal a crown. He stole four Embers and
forced them to burn as one inside him. When Aldric's killing blow shattered it,
the Embers scattered separately, each reverting to its own nature and rooting in
people with old Guard bloodlines.

A shard-bearer isn't choosing a class at character creation. They're discovering
which Ember caught in them. That Ember comes with its own virtue, its own
temptation, and its own dead founder whose sins they inherited along with their
power.

---

## Bridge From Solo to Multiplayer

In Chapter 1 (solo), Aldric kills Vargoth and reclaims the Ember Crown. That
ending stands. The twist: Vargoth, in his final enrage, pours his own will into
the Crown and shatters it rather than let anyone else wear it. The shards scatter
across Ashvale and root in ordinary people with Guard bloodlines.

Years later, that's the player base. Every player character is someone whose
shard just awakened. The power they carry literally comes from a fragment of the
tyrant the Guard died fighting.

**Aldric** survived but spent his own ember in the killing blow. He's a
burned-out legend who can't fight anymore but knows exactly what's coming. He
functions as a late-game lore NPC, a "here's what I never told you" quest, or
optionally a superboss homage fight.

**Elder Maren** survives into the multiplayer era. She trained under Aldric,
watched the Guard fall, and now spends her days finding newly-awakened
shard-bearers before the factions do. She's the onboarding NPC across all eight
classes — same role, aged into a mentor, but reading each new recruit
differently depending on what she sees in them.

**Fangmaw and Mórwyn** weren't just monsters. They were corrupted Guard
commanders — Fangmaw a Stormwarden beastmaster, Mórwyn an Emberwright
battle-healer whose fire-healing curdled into blight. Killing them didn't cure
the corruption. It cut off the head. The beastkin warbands and blight-plague are
still spreading years later — justification for repeatable zone content and the
game's 14 terrain types.

---

## Progression Trackers

**Resonance** (per character, -100 to +100): every major choice nudges toward
your Ember's Virtue or its Temptation. Not a good/evil meter — specifically
tracks how you relate to the same power that destroyed your class's founder.
Stored on the player object (not world state) so it persists when a solo
character enters co-op.

**Faction Standing** (four independent values, one per faction): shifts
independently of Resonance. In single player, functions as a personal reputation
system. In co-op, the group's combined standings create table tension — two
Accord players and one Cinderborn player will not agree on everything. Also
stored per character.

These six numbers together gate all major story branches and ending eligibility.
Resonance should be felt in NPC dialogue and reactions before the player ever
sees a number, if they see one at all.

---

## The Four Factions

Two are joinable at launch (Accord, Cinderborn); two are ambient at launch
(Wildfang, Hollow Choir) — standing tracked, reactions real, no pledging.

### Ember Accord — joinable (Phase 1)
Maren's loyalists. Goal: gather the shards, destroy the hollow throne for good.
No one should ever wear the Crown again. They are asking shard-bearers to
voluntarily become less than they are. They are not wrong, but they are asking a
hard thing.

### Cinderborn — joinable (Phase 1)
Old regime nobles who prospered under Vargoth. Goal: find a worthy heir,
re-crown the throne, restore the empire. They believe order requires a crown and
that the chaos of the Waking proves it. Not cartoonishly evil — people who lived
well under tyranny and convinced themselves it wasn't tyranny.

### Wildfang Tribes — ambient at launch
Fangmaw's broken beastkin descendants. Internally fractured: one camp wants the
blight cured and seeks alliance with the Accord; the other has made peace with
what they are and sees "curing" as conquest dressed in mercy. Player choices can
influence which camp gains dominance.

### Hollow Choir — ambient at launch
Mórwyn's blight-plague survivors turned cultists. They don't see the rot as a
curse — they see it as the land's honest truth. Some are grieving people who
found meaning in horror. Some are genuinely dangerous. The line is hard to find.

---

## The Three-Act Player Journey

**Act 1 (low level):** Something personal triggers your shard. You don't know
what you are yet. Every class has a different emotional entry point but the same
structural shape: Ember activates → consequence you have to live with → Maren
finds you.

**Act 2 (mid level):** Factions start recruiting because they can sense what you
are. You choose alignment — not permanently locked, but consequential. The world
map opens as the Waking spreads: corrupted zones, refugee crises, old ruins
reactivating.

**Act 3 (endgame):** Direct confrontation with the awakening god-kings. In
single player, you assemble the pieces through NPC shard-bearer questlines. In
co-op, four players bring their own classes and Resonance scores into the Hollow
Throne raid together.

---

## The Eight Classes

Eight are designed; **six ship in Phase 1** (Warrior, Paladin, Assassin, Archer,
Mage, Warlock). Death Knight and Summoner are expansion classes.

All classes share the same tutorial structure: combat encounter →
consequence scene → Maren recruitment. Only the dialogue trees and consequence
scene content differ per class. Reuse the same quest scaffolding in `story.gd`.

### Warrior — Melee — STR — Sword/Axe — Phase 1 (live)
**Ember:** Vargoth's own.
**Virtue:** Protection — standing between harm and those who can't protect
themselves.
**Temptation:** Tyranny — "I'll control them for their own good."
**Themes:** Fury (rage-stacking burst), Bulwark (damage reduction and reflect),
Earth (CC and zone control).
**Opening:** You wake mid-blackout having hurt someone while protecting them. The
first quest is the aftermath — not the fight. Maren finds you scared of your own
hands.
**Maren's read:** Brisk and professional. She's trained people carrying Vargoth's
Ember before. She doesn't say it out loud until Act 2.

---

### Paladin — Melee — STR/INT — Hammer — Phase 1 (NEW at launch)
**Ember:** Not a god's power. A fragment of the Concord's binding magic itself —
the force that chained the gods. The only class whose Ember resists corruption
rather than embodying it.
**Virtue:** Defiance — the power to refuse what the Ember demands of you.
**Temptation:** Righteousness — "I know better than you what you need saving
from."
**Themes:** Holy (heal-on-hit, Consecration stacks that burst-heal allies or
cleanse debuffs), Aegis (Bulwark charges that redirect incoming damage as
reflected magic), Wrath (tether abilities that root, slow, or drag enemies into
melee range — high damage, low sustain).
**Opening:** You're a village arbitrator mid-hearing on a grain-hoarding case
when blight-touched raiders attack. You pick up a fallen guard's hammer, the
Ember ignites, the raiders flee. Then you go back inside and finish the trial.
The man is guilty. The Ember wants you to let him go — you protected him, the
chain says he's yours to shield. Do you deliver the verdict? Maren recruits you
not because you fought well, but because you chose correctly when the Ember told
you not to.
**Maren's read:** Quietly hopeful in a way she doesn't show with others. The
Concord's chain producing a shard-bearer is new. She thinks it might be good.

---

### Assassin — Melee — AGI — Daggers — Phase 1 (live)
**Ember:** The unnamed founder. Betrayed the Guard before Vargoth even rose. The
histories buried their name entirely.
**Virtue:** Sacrifice — giving up something of yourself so others don't have to.
**Temptation:** Consumption — "Take what keeps you strong."
**Themes:** Poison (DoTs and attrition), Shadow (mobility, evasion, burst from
stealth), Blood (lifesteal-centric, self-harming abilities that hit harder the
lower your HP).
**Opening:** Your Ember activates by taking something from someone else to
survive — morally gray rather than outright evil. The first quest is finding out
your survival had a price you didn't see coming.
**Maren's read:** Careful, not suspicious. She knows this bloodline produces
people who survive by taking. She wants to know what they took before she offers
trust.

---

### Death Knight — Melee — STR — Greatsword — EXPANSION
**Ember:** A shard-bearer who died holding their fragment and came back wrong.
What happens when a Warrior's Ember refuses to let them stay dead.
**Virtue:** Persistence — continuing despite having already paid the highest
price.
**Temptation:** Consumption — "I am already dead. What I take from others costs
me nothing."
**Themes:** Plague (blight-rot DoTs that spread on kill, farming kills for
stacking buffs), Ruin (abilities reduce enemy max HP temporarily — they shrink,
not just take damage; pairs with lifesteal), Frost (layer Frost stacks until the
enemy goes Brittle, then shatter with an amplified crit — rhythm-based burst).
**Opening:** The game opens on your grave, three days after burial. You claw out.
Your family bars the door — they think you're a blight-creature. You clear the
raid hitting the farm alone (tutorial combat), then choose: knock on the door
again, or walk away to spare them? Maren is watching from the treeline. She
recruits you based on which choice you made at the door.
**Maren's read:** Waits until they've made their choice, then steps out of the
treeline. She needs to see the choice first.

---

### Mage — Ranged — INT — Staff — Phase 1 (live)
**Ember:** Mórwyn's. The battle-healer whose desire for perfection curdled into
blight.
**Virtue:** Clarity — seeing what is true without forcing it to be what you want.
**Temptation:** Cruelty — "I'll perfect them whatever it costs."
**Themes:** Fire (burst damage, ignite DoTs), Ice (roots, slow, shatter combos),
Wind (mobility, pushback, echo hits that chain to nearby enemies).
**Opening:** Your Ember activates while trying to heal someone, and it doesn't
heal clean. Something goes wrong in a way that's hard to explain and impossible
to undo. The first quest is whether you tell the truth about what happened.
Maren finds you either way, but her read depends on what you chose.
**Maren's read:** Collegial but watchful. She knew Mórwyn's record. She's looking
for early signs of the same pattern.

---

### Archer — Ranged — AGI — Bow — Phase 1 (live)
**Ember:** Fangmaw's. The beastkin corruption is this Ember's temptation taken
all the way to its end.
**Virtue:** Freedom — moving through the world without owing it anything.
**Temptation:** Severance — "Cut ties. Owe no one."
**Themes:** Storm (lightning-infused arrows, chain lightning on crit), Venom
(stacking poison, slowing fields), Hunt (tracking mechanics, damage bonuses
against marked targets, attack speed scaling).
**Opening:** Your Ember activates by cutting you off from something before you
understand why — a bond snaps, a home feels wrong, a person you loved looks at
you like a stranger. The first quest is about what that severance cost,
immediately, before you have any framework for what's happening.
**Maren's read:** Most casual of the eight. Archers tend to run. She doesn't
chase. She makes sure they know the door is open.

---

### Warlock — Ranged — INT — Tome — Phase 1 (NEW at launch)
**Ember:** Not inherited — borrowed. A pact with something ancient that exists
just outside the edge of what the world is made of. The Ember is on loan. There
is a debt.
**Virtue:** Accountability — knowing exactly what you owe and to whom.
**Temptation:** Debt spiral — borrowing more power to solve the problems the last
borrowing caused.
**Themes:** Curse (hex enemies so all damage they take is amplified; stacks
explode on death for AoE), Pact (sacrifice HP to empower spells; lifesteal is
your only recovery), Void (open brief rifts that deal delayed burst damage when
they close — high skill ceiling).
**Opening:** You wake up knowing you already made the pact. You don't remember
doing it. The tome is in your hands and the debt is real. Your first quest is
figuring out what you agreed to, pieced together through journal fragments and
conversations with people who knew you before. The picture: you traded something
you haven't lost yet. You don't know what. Maren recruits you with a warning,
not hope.
**Maren's read:** Says yes and then immediately says she's not sure she should
have. Watches Warlocks more closely than any other class.

---

### Summoner — Ranged — INT — Orb — EXPANSION
**Ember:** Fractured — split across their summons. The Summoner's power doesn't
live inside them. A Summoner who loses their summons is mechanically and
narratively weakened at the same moment.
**Virtue:** Communion — sharing power genuinely rather than wielding others as
tools.
**Temptation:** Hollowing — offloading so much of yourself into your summons that
nothing remains inside.
**Themes:** Beasts (feral animal companions in melee range; losing a beast deals
a small HP penalty to the Summoner as the Ember fragment recalls), Spirits
(ethereal shades that phase through terrain, drain enemy mana, apply debuffs),
Constructs (ember-automatons — slow, tanky, abilities channelled through them;
rewards preparation over reaction).
**Opening:** A wounded wolf died near you and didn't leave. Not alive — but
stayed. Tutorial combat is fought alongside your first summon, who has its own
behavior you have to learn to work with rather than command. Maren doesn't tell
you what you are. She asks what the wolf's name is. If you named it, she smiles.
If you didn't, she looks worried.
**Maren's read:** Asks about the wolf.

---

## Class × Faction Natural Pull

Ambient factions still exert pull — it surfaces through side quests and
standing, not pledged membership. Death Knight and Summoner rows apply at
expansion.

| Class | Natural pull | Dramatic against-type |
|---|---|---|
| Warrior | Ember Accord (atone for Vargoth's bloodline) | Cinderborn — "maybe the empire was right" |
| Paladin | Ember Accord (the chain was made to bind, not rule) | Hollow Choir — "maybe decay is honest" |
| Assassin | Unaligned (owes nothing, trusts no one) | Ember Accord — choosing to trust for the first time |
| Death Knight | Hollow Choir (already dead, already past caring) | Wildfang Tribes — kinship with others who were corrupted |
| Mage | Ember Accord (Mórwyn's mistake was caring too much; correct it) | Cinderborn — the empire valued knowledge |
| Archer | Wildfang Tribes (freedom, no masters) | Ember Accord — choosing to be accountable to something |
| Warlock | Hollow Choir (the debt already makes them dangerous) | Ember Accord — trying to repay rather than borrow more |
| Summoner | Wildfang Tribes (creatures, not kingdoms) | Cinderborn — constructs as imperial engineering |

---

## Endgame: The Hollow Throne

Vargoth's throne sits in the ruined capital — cursed, empty, and quietly calling
to whichever shard-bearer is powerful or greedy enough to sit in it. The throne
will crown someone eventually. It doesn't care who.

**The raid:** Four players enter the ruined capital. An echo of Vargoth forms
from the throne using the shard-power the players brought with them. He carries
the same 30% enrage mechanic as the Chapter 1 boss — a deliberate callback.
This is what he always did when he was losing.

**In single player:** The echo forms from your Resonance score and the
shard-power of NPC allies you've built relationships with through Act 2
questlines. The resolution paths are the same; the inputs are different.

### Resolution Paths

**Destroy the throne** (Ember Accord ending): Shatter the throne before the echo
fully forms. Cost: all shard-bearers present lose a significant portion of their
power permanently. The world is safer. You are less.

**Claim the throne** (Cinderborn ending at launch; the Hollow Choir variant —
the rot becomes sovereign — arrives when the Choir becomes joinable): A chosen
champion sits. The empire returns. Mechanically successful. Morally
catastrophic in ways that become the next expansion's problem.

**The council ending** (requires high positive Resonance; in co-op, requires
multiple Ember bloodlines represented in the raid group): Shard-bearers from
multiple bloodlines simultaneously refuse the throne's pull and fuse just enough
of their fragments to seal it without destroying themselves. The hardest to
achieve. The only ending where something genuinely new exists afterward. In
single player, triggered by high Resonance plus completing questlines for at
least two other Ember bloodlines through NPC shard-bearers.

**The hollow ending** (requires deeply negative Resonance across the group, or
solo): The echo fully forms and crowns itself using the shard-power the players
brought with them. A loss state. Rare. Brutal. Sets up a recovery arc for the
next expansion. **Must be loudly signposted well in advance** — diegetically
(Maren withdraws, NPCs recoil, the Ember's whispers get gleeful), never as a
surprise at hour 40. Players who lose a campaign finale without warning refund;
players who watched themselves earn it tell stories about it.

---

## Technical Notes for story.gd

- Resonance and Faction Standing are stored on the **player object**, not world
  state. They must survive the transition from local single player to networked
  co-op without requiring migration.
- The opening sequence for all eight classes reuses the same quest scaffolding:
  combat encounter → consequence scene → Maren recruitment dialogue. Branch on
  class first, then check `first_choice_flag` set during the consequence scene.
  This flag shapes Maren's tone for the entire game.
- Resonance should surface in NPC dialogue and reactions before the player sees
  a number — ideally they feel it for a full act before any UI exposes it.
- To keep that affordable, author dialogue variants by Resonance **band**, not
  value: three bands (tempted / neutral / steady) tagged per line is enough for
  the player to feel watched. Per-value variants are a cost explosion.
- Canon spelling pass needed when Chapter 2 is authored: the shipped game says
  "Morwen"; this bible says "Mórwyn" (same character — standardize), and
  "Ashvale" vs "Vaelscar" need a settled relationship (suggest: Ashvale is the
  Chapter 1 region, Vaelscar the world).
- The four Chapter 1 bosses (Fangmaw, Mórwyn, Vargoth, Hollow Throne echo) share
  mechanical DNA: telegraphed red danger zones, enrage thresholds. The boss.gd
  architecture doesn't need to change for the multiplayer versions — just scale
  the numbers.
- Faction Standing in co-op is per-character. The group's combined standings
  create natural tension. No forced consensus mechanic needed — the disagreement
  is the content.
- The Hollow Throne raid is designed for exactly four players, one per Ember
  bloodline ideally. Class composition affects which resolution paths are
  available to the group.