# PROPOSALS — Social layer: hub, guilds, crafting, market, events (decision doc)

Captures the owner's decisions from the 2026-07-17 design discussion. **Nothing
here is built.** These are agreed directions + the constraints they must respect,
so the work starts from settled intent instead of re-litigating it.

The framing that ties all five together: the game today has ONE loop — clear
chapters — and every reward faucet and balance pass is tuned against it. A pure
ladder game has a terminal state (veterans top out and leave). The social layer
is the second loop that gives a reason to log in beyond story/depth grind. Owner's
words: "if there's no social backbone the game will just be a grind to see who
climbs farthest, which ends when veterans hit endgame and lose motivation."

---

## The hard constraint everything sits under (verified against code)

There is **no server, no accounts, and no persistence beyond local JSON save
files.** Multiplayer is a 4-player, invite-only, session-scoped listen-server
over noray:

- `MAX_GUESTS := 3` (host + 3), baked into the party-scaling arrays, not just a
  constant — `net_manager.gd:48`, `balance.gd:654-662`.
- Lobby locks at chapter start; host quit ends the session; no host migration.
- `MULTIPLAYER.md:44` non-goal, verbatim: *"Dedicated servers, accounts,
  persistence beyond the existing save files."* `:45`: *"Player-to-player
  trading (v2 candidate)."*
- `MULTIPLAYER.md:496`: the trusted-client security model *"assumes it never
  meets strangers"* and names the authority table as the checklist to redo if
  it ever does.
- noray has **never been tested against a live server** (`net_manager.gd:347`);
  all green net tests run over localhost.

**So anything needing shared persistent state (a real hub with strangers, a
guild roster that outlives a session, an auction house) is a NEW PHASE of the
project — a server + database — not a feature increment.** That is the single
biggest unpriced cost in this whole layer, and it's the part that can't be
walked back once servers are running.

## The gating doctrine (owner may overrule, but should do so deliberately)

`DESIGN.md:163`: *"no new meta systems until the content multipliers exist — the
retention layer is already ahead of the content it retains players in."* Three
of the five topics below are meta systems. The multiplier the doc names as next
and cheapest — **difficulty tiers / NG+ (Normal / Nightmare +20 / Torment +40)**
— is still **unbuilt** (`DESIGN.md:199`). Owner leaning: unlock Nightmare after
Act 3 is done. The honest first question before any social build is whether
difficulty tiers come first. This doctrine was written when the game was
single-player; "social backbone" is a legitimate reason to revisit it.

---

## 1. Hub — the container. **Async first, presence later.**

**Reality:** every chapter's zone 0 is ALREADY a safe hub with a merchant and
NPCs. Ch2's Maren's Camp (`content/ch2_hub.gd:10-51`) is a 13-NPC camp with two
faction recruiters and a gate flag — the reference implementation. You never
drop straight into combat. All the machinery (data-driven NPC placement taking
an arbitrary Callable, branching convos, merchants, seeded social wanderers,
shelter integrity) already ships and is reusable.

**The real question isn't "add a hub" — it's "move the hub OUTSIDE a chapter and
put OTHER PLAYERS in it."** First half is a data-schema change. Second half needs
the server (see constraint above).

**Decision (owner):** the hub is the destination where players interact and do
"other things"; the story becomes ONE activity (lone-wolf players can just
progress solo). Neither playstyle is privileged. Guilds are the retention hook.

**Recommended path:** build guilds **asynchronously first** — membership, shared
weekly objectives, a guild ladder, crests are all STATE, not PRESENCE. They don't
need players standing in a room together, only a place to store a roster and tally
contributions. Presence is the expensive part; identity + progression aren't.
This tests whether the social layer actually retains people BEFORE committing to
running servers (the irreversible step).

## 2. Crafting — a distinct job, not a duplicate faucet

**Reality:** the reforge bench exists (`items.gd:577-713`) — gold-in / RNG-out,
FOUR crafts (sub / affix / socket / quench), **zero materials**. There is **no
material / resource / ingredient item kind anywhere** in the schema. A crafted
item fits the existing gear schema trivially (`roll_gear_of_grade` with a material
cost instead of gold) — the schema isn't the blocker, the economy is.

**Decision (owner):** crafting targets **consumables, cosmetics, and things that
minimize balance impact** — NOT gear power. By `DESIGN.md`'s "each faucet has one
job" rule, gems already own "build quality" and reforge owns "fix this item," so
crafting needs a non-overlapping job: deterministic acquisition of the
low-balance-impact goods above.

**Mineable terrains:** owner is open to making terrains interactable to mine
resources. Caveat from recon: terrains are per-zone THEMES (look + hazard), not
discrete places with inventory (`terrains.gd:2-4`); obstacles are bare
StaticBody2D with no health/ID (`game_world.gd:1085`). BUT a mineable node is
placeable TODAY as an authored per-zone interactable — the `rock`-with-an-`E`-prompt
pattern already ships (`story.gd:731,751`), and `_make_npc` takes an arbitrary
Callable. The mining VERB is cheap; the material's WORTH is the economy problem.

## 3. Market — hostile to the design; narrow version only

**Reality:** nothing exists. No trade / auction / market string anywhere. Trading
is a written non-goal (`MULTIPLAYER.md:45,487`) precisely because instanced loot
keeps each wallet the tuned solo economy. The mailbox (`game_base.gd:586`) is the
closest reusable delivery pipe, but it's a local array in a local JSON file.

**The design tension:** an auction house is a balance solvent — it collapses every
player's tight economy into one global economy and kills drop scarcity (the rarest
item becomes merely expensive). It's the most efficient machine ever built for
converting **identity into parity**, and owner's stated value is identity over
parity. This is why D3 killed its AH, PoE friction-gates trade, WoW binds good
gear on pickup.

**Decision (owner):** market is for consumables, cosmetics, crafted/looted
low-impact goods only — **gear never trades.** Gate behind real multiplayer
persistence (needs the server). Investigate "as we get closer to multiplayer
completion." A LOCAL NPC-consignment version is buildable now on merchant +
mailbox + trusted-clock, but that's a gold sink with extra steps, not a player
market, and it collides with `DESIGN.md:188` (time-gated ≠ farmable).

## 4. Events — the login-reason loop. **Segregated currency.**

**Reality already shipped, all paying into the SAME economy (no XP):** daily
login, bounties, weekly vault, weekly challenge (5 mods, rotating chapter), the
Crucible (endless), the Waking Depths (endless), records/PBs/titles. The endless
modes obey `DESIGN.md:193` — *"No new currency, no separate economy to
calibrate."*

**Owner's concern:** the economy is "strict" because balance was built around
chapters — easier to tune but restrictive. That strictness is a DELIBERATE
standing decision with a written rationale (`DESIGN.md:180-193`: each faucet one
job; time-gated faucets collected-not-farmed; achievements pay identity not
currency).

**Decision (owner):** events get a **second earned currency** (NOT real-money)
that buys **consumables + cosmetics only.** This reconciles with the "no new
currency" rule rather than overruling it: the doctrine's fear is *an economy to
calibrate*, and a currency that buys only zero-balance-impact goods needs zero
calibration. Story gold stays tuned tight; the event currency runs a parallel
horizontal track that can't leak into power. **This is currency segregation and
it's the key that makes the whole layer safe.**

**Cheap for this project specifically:**
- The horizontal reward axis already exists — 12 Elite/Mythic skins + the
  awakened-skin mechanism (`s_awakened_<cls>` gate) touch ZERO balance. Events
  can pay skins/awakenings day one.
- The event infra already exists — an "event" is arguably a content module
  (`scripts/content/`, format in `content/README.md`) behind a date gate. Plays
  to the project's strength (authored content over procedural filler).
- **Waking Incursions** are already spec'd on paper (`ACT2_DESIGN.md:116-140`):
  weekly, one cleared chapter marked *Waking*, 3 injected bonus rooms with
  mini-bosses from the WRONG god-king's domain, rewards incl. *"a weekly
  cosmetic token when those exist."* Explicitly seeded as *"the world boss
  rotation"* for a future MMO. **This is the owner's own shelved answer to
  topic 4 — pick it up.**

## 5. Status — the reward category the owner was missing

Owner named cosmetics + consumables as event/craft/market targets. The third
category is **status**: titles, guild crests/tabards, ladder rank, achievement
displays, a decorated guild hall, pets. Its properties solve the exact problem:

- **Nearly free to author** — a title is a string + a flag, hung on the existing
  records/achievements system. `DESIGN.md:189` already says *"achievements/titles
  pay IDENTITY, never currency, by construction unfarmable"* — the rule exists
  and is underused.
- **Infinitely repeatable** — can't ship a skin weekly; CAN ship a title weekly
  forever.
- **Worthless without an audience** — which is why it fits NOW and didn't before:
  a title in a single-player game is for you; a title in a hub is for everyone
  else. The hub unlocks this category.
- **Collective status** (guild hall that levels, guild weekly objective, guild
  ladder) is what actually retains a guild — the reward is the GROUP's, i.e.
  systems + numbers, not art.

**Cosmetics are expensive the bespoke way, cheap the combinatorial way** (the
owner's cosmetic-cost complaint): dyes (`_grade_tint` / `silhouette.gdshader` —
awakened Phantom was literally a blue→teal repaint), FX packages (Golden Ronin's
gold shuriken/dash/ult — shaders not sprites), composable crests (shape × emblem
× 2 colors = thousands from ~30 authored pieces). Housing = placing props already
on disk; pets = existing mob sprites at half scale.

## 6. PvP — accepted, with a caveat

**Decision (owner):** PvP is wanted; parity pressure is fine because classes can
be **tuned PvP-exclusively** (e.g. nerf a class's stats in PvP only). That
per-mode tuning is the standard answer and does dissolve the identity-vs-parity
objection. Caveat: PvP is still the single largest ongoing parity pressure a game
can carry, and it needs the server. Lowest priority of the six; sequence it last.

---

## Suggested build order (dependency, not priority)

1. **Difficulty tiers / NG+** — resolve the `DESIGN.md:163` gate first (owner:
   after Act 3). Cheapest content multiplier; unblocks the "meta systems" freeze.
2. **Status rewards + segregated event currency** — no server needed. Titles on
   the existing achievement system; event currency buying skins/awakenings that
   already exist. Highest value-per-effort.
3. **Waking Incursions** — the login-reason loop, already spec'd; pays the event
   currency. No server needed.
4. **Async guilds** — roster/ladder/crests as STATE. The retention test before
   committing to servers. Needs lightweight persistence (could ride meta.json
   short-term) but not full presence.
5. **Crafting (consumables/cosmetics)** + **local NPC market** — gold/material
   sinks; no player-to-player transfer yet.
6. **Server phase** — shared hub with strangers, real player market, PvP. The
   irreversible, expensive step. Everything above is designed to validate demand
   before paying for it.

## Codex reminder

Per `CLAUDE.md`, any player-facing feature here must update the in-game codex
(`scripts/ui/codex.gd`) in the same change, plus hand-maintained gates like
`menus.gd BOSS_KINDS`. Budget for it in each proposal.
