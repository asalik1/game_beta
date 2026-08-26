# Class Identity & Living NPCs — make the world respond to WHO you are (2026-08-22)

Decision document. Nothing installed, no game files touched. Grounded in a full
read of the quest / class-content / NPC systems (2026-08-22).

Owner brainstorm this seed came from: classes all run the same quest loop; the
opening/closing scenes are class-flavored but nothing between is; there are no
class-exclusive quests; NPCs are only quest-givers; and (owner idea) NPCs could
gate quests on favor / faction standing, with a traitor either locked out or
handed a consequence. Plus: repurpose the retired S-weapon "legendary/awakening"
quests into class-identity quests (owner: "worthwhile").

Sibling docs (referenced, not repeated): `ACT2_DESIGN.md` §III (the reframed
per-class founder trials), `DYNAMIC_WORLD.md` (Layer E pets, the
situation-is-a-verb doctrine, the Cage escort card), `QUESTS_AND_SIDE_CHAPTERS.md`,
`QUESTS_TASKS.md` (Q12/Q13 relationship gates, Q16 followers — the mechanics
homes), and the co-op no-healer doctrine.

---

## 0. The problem, measured

- Six classes (warrior, assassin, mage, archer, paladin, warlock,
  `classes.gd:109-177`); **the campaign journey is identical across them.**
  Class-varied content is strictly BOOKENDS: the origin prologue `open_<cls>`
  (`game.gd:400-405`, which sets the persistent flag `opened_<cls>`), Maren's
  greeting `maren_<cls>` (`game_world.gd:1058`), each chapter's opener plate
  `chN_opening_<cls>` (`chapter_openers.gd`), and each chapter's closer
  cinematic `chN_closing_<cls>` (`chapter_closers.gd`). Everything BETWEEN —
  zones, bosses, quests, NPC dialogue — is shared, keyed on resonance band /
  stance flags / faction, never class.
- **25 side quests exist; none fork on class** (`story.gd` +
  `content/chN_quests.gd`; the DYNAMIC_WORLD audit).
- NPCs accumulate `npc_favor` (`game_base.gd:771-795`) and `faction_standing`
  (`game_base.gd:763`), but **nothing gates on those numbers** — the
  relationship exists as data and drives nothing.
- **No companion / follower primitive exists** (greenfield; `QUESTS_TASKS.md`
  Q16).

Net: the world never responds to WHO the hero is (class, history with an NPC,
loyalties) beyond scripted bookends. Every fix below is content on top of
mechanisms that mostly already exist.

---

## 1. Class-identity threads (repurpose the retired legendary quests)

The S-weapon awakening quests were retired with the legendary tier (2026-07-27,
owner call; see `ACT2_DESIGN.md` §III status note). The loot gate is dead, but
the narrative shell — a per-class founder arc — survives and is exactly the
"distinctive class journey" the owner wants. Rebuild it **decoupled from loot**.

- **The shape:** one personal thread per class that runs THROUGH the campaign
  (not just the bookends), meeting the ghost/legacy of the class's Ember Guard
  founder, testing the class's IDENTITY mechanic, and paying IDENTITY (a
  keepsake / title / cosmetic + lore), never power.
- **The assassin name arc — worked example.** The owner's "the nameless
  assassin learns his name" idea is already seeded in code, just never woven:
  - ch7 boss = "the erased Guard founder... UNNAMING" (`ch7_bosses.gd:54-70`).
  - ch7 mob = "The Echo of the Unnamed... no stone, no name, no line in any
    book. The Guard saw to that" (`ch7_zones.gd:245`).
  - ch7 Apprentice Sorrel branch, gated `req_flag: opened_assassin`, reveals
    the void-boss is "your ember's own first bearer, thrown away by the Guard"
    (`ch7_zones.gd:351-357`); code comment: "the assassin ember's own history
    — endgame seed" (`ch7_zones.gd:340`).
  - elite skin id `erased_name` (`skins.gd:173`).
  The arc: a per-class thread that pays off this planted lore — the assassin
  recovers the erased name (a title/keepsake), the warlock meets the creditor,
  the paladin the chain-bearer, etc. (`ACT2_DESIGN.md` §III Founder
  Revelations table has all six.)
- **Mechanism — cheap, already load-bearing.** `opened_<cls>` is a persistent,
  per-character, co-op-local flag (in `KEPT_FLAG_PREFIXES`,
  `game_flow.gd:631`). A quest-offer dialogue choice already accepts
  `req_flag`, so `req_flag: opened_assassin` makes a quest class-exclusive with
  ZERO engine change. **This exact pattern already ships** at ch7
  (`ch7_zones.gd:351`). Multi-step chains use the standard flag/kill steps and
  `kept` rewards for cross-chapter memory.
- **Optional polish (small engine add):** a first-class `req_class` choice gate
  beside `req_band` (`game_base.gd:1855`, ~2 lines reading `player.cls`) so
  authors do not route through `opened_<cls>`; plus a `class` field on the
  SIDE_QUESTS def + a filter in the journal AVAILABLE list
  (`journal.gd:197-199`) so off-class quests are hidden. Nice-to-have once
  class quests are common; not required to start.

---

## 2. Class-refracted NPCs

The synthesis of "class identity" and "NPCs as more than quest givers": one NPC
that reacts differently to each class. The assassin's guild-sign, the warlock's
pact-mark, the paladin's oath, the archer's beast-handler bond. Same cheap
`opened_<cls>` (or `req_class`) gate on convo node `variants` — NPCs already
support `variants` keyed by flag/band (`game_base.gd:1998`). One authored NPC,
six reactions, and the world suddenly knows what you are. Especially strong on
recurring NPCs (Maren, the capital artisans, faction desks).

---

## 3. Relationship-gated quests (favor + faction standing, two-way)

Owner idea: NPCs unlock quests at a favor / standing threshold, and a traitor
is either gated out OR gets a consequence. The two-way version is the better
design — a gate that only says "no" is flat; a gate that opens a DARKER path is
a situation (the `DYNAMIC_WORLD.md` doctrine: a verb, a cost, a mark the world
reads back).

- **Positive gate:** `req_favor` / `req_standing` threshold unlocks a quest or
  a better branch. Cheap: already spec'd as `QUESTS_TASKS.md` Q12/Q13, mirrors
  the existing `req_band` gate in ~2 lines, and favor/standing already
  accumulate (`game_base.gd:763-795`). The capital artisan "gossip hub" is the
  UI shape to extend (`game_world.gd:353-424`).
- **Traitor path (the good one):** betraying a faction should not just lock the
  loyal quest — it should OPEN something. Betray the Accord → their questline
  closes, a Cinderborn "we heard what you did" quest opens, and a consequence
  lands (a colder desk greet variant; an Accord hunter-elite two rooms on).
  Grounded: `faction_standing` already goes negative; the consequence
  machinery (`chose_*` persistent marks → `beat_for` variants,
  `story.gd:1304`; the hunter-elite spawn pattern from the Road Deck) already
  exists. "Traitor" = a standing threshold or a `chose_betray_*` mark, read by
  BOTH a gate (lock the loyal quest) and a spawn/variant (the consequence).
- **Rule:** every relationship gate that closes a door opens or marks another
  one; no silent lockout. (Matches the situation-is-a-verb standing rule.)

---

## 4. Companions — NOT a permanent follower (owner ruling 2026-08-22)

The owner asked "what would a companion do?" and then answered it with a
correction: **a permanent NPC trailing the hero does not fit.** A shard-bearer's
grim solo journey with a villager jogging behind reads as silly, and a permanent
combat ally breaks both the solo fantasy and the balance. So the
persistent-follower model is REJECTED. "An NPC follows you" survives in exactly
ONE form: the single-quest ESCORT (a bounded beat that can fail, §3 /
`DYNAMIC_WORLD.md` `escort`).

The real question, then: how do you deliver the "a thing that is MINE" appeal
WITHOUT a tag-along? Two hard rules still hold — no healer (co-op covenant), no
free power (identity over parity) — so it trades in identity, utility, and
story. Three avenues, none of them "walk behind me":

- **A. The Menagerie (home-based collection) — recommended core.** Pets live in
  the capital (a stable / menagerie beside the Wardrobe), NOT in the dungeon.
  You earn them (the bird-boss pet, discovery-lane strays), house them, and they
  react to your deeds. This is where `DYNAMIC_WORLD.md` Layer E already points
  ("per-character Stable, codex Companions section, Wardrobe UI pattern").
  Optional flavor toggle: bring one out in TOWN only (a slime at your heel in
  the capital is charming; the same slime in Blightheart Bog is not).
- **B. Summon-for-a-beat (invoked, never trailing).** If the appeal is "a
  creature acts for me," make it a CALL, not a companion: a raven you send to
  scout / mark the next cache, a spirit you invoke for one strike, then gone. An
  earned ability or item, situational, no persistent body. Fits the lore (bound
  things and echoes, not hirelings) and dodges the balance/AI cost.
- **C. The bond, not the body (recurring NPCs you return to) — the richest.**
  Reframe "companion" from a body-in-tow to a RELATIONSHIP you maintain: fixed
  NPCs across chapters who remember you, evolve, and advance when you visit. The
  favor/standing system (§3) already IS this substrate; the "companion" is the
  bond, delivered by return-visits, and it reuses §2/§3 wholesale.

**Avoid:** the Summoner-style combat pet with real AI/DPS — greenfield combat AI
plus a balance/identity risk; a fighting summon belongs to a CLASS fantasy (the
warlock's familiar), not a universal companion feature.

**Cost.** Avenue C is nearly free (favor + return-visits already exist). Avenue
A is the capital menagerie UI (Wardrobe pattern) + the Layer E collection data;
the optional town-follow is a small cosmetic node, not a full follower AI. The
greenfield follower primitive (`QUESTS_TASKS.md` Q16) is now needed ONLY for the
single-quest escort.

---

## 5. Build order & open questions

**Order (cheapest reach first):**
1. **Class-refracted NPC reactions** (§2) — zero engine work, immediate
   "the world knows me" payoff on recurring NPCs.
2. **One class-identity thread** (§1) — the assassin name arc as the pilot;
   seeds already planted, mechanism proven at ch7.
3. **Relationship gates + traitor consequences** (§3) — the Q12/Q13 gate + one
   worked betrayal loop.
4. **Companions via the bond** (§4 avenue C) — reuses §2/§3, nearly free —
   then the Menagerie (avenue A) and summon-for-a-beat (avenue B). The
   greenfield follower primitive (Q16) is needed only for the single-quest
   escort now.

**Open questions (owner):**
1. **Class-quest scope** — Act 1 backfill (retrofit existing chapters) or
   Act 2 forward only? (Bookends already exist per chapter; threading them is
   the work.)
2. **`req_class` polish** — add the first-class gate + journal filter now, or
   ride `opened_<cls>` until class quests are common?
3. **Reward for the class arcs** — keepsake/title only, or a signature cosmetic
   (an assassin "true name" title, etc.)? Identity, never power (rule).
4. **Traitor depth** — one consequence beat (cheap) or a full mirror
   questline for the opposed faction (expensive)?
5. **Companion avenue** — the Menagerie (A) + the bond (C) as the core, with
   summon-for-a-beat (B) as flavor (recommended); permanent followers stay
   rejected. Confirm before any companion build.

> Thesis: the campaign knows the hero's stats and their resonance, but not
> their class, their history with an NPC, or their loyalties. Give each class a
> thread that pays off lore already in the code, let NPCs recognize what you
> are and remember what you did, and let a companion trade in identity instead
> of power. The mechanisms are mostly already here; what is missing is authored
> content that says "the world sees you."
