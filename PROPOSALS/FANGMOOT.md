# Fangmoot — the tavern autobattler inside Crownless (design, 2026-08-17)

**Status:** design accepted by the owner 2026-08-17 (the five open questions
in §16 are decided; a sixth, the live showdown, was added by the owner). No
code yet. This doc is the single source of truth for the Fangmoot minigame;
`PROPOSALS/SPINOFF_GAMES.md` §6 is where the decision to build it inside
Crownless (the "Gwent route") was made, and this doc does not repeat that
argument.

**One paragraph.** Fangmoot is a game the Wildfang play with carved tokens of
beasts, in the galleries of Fangmoot Circle in Crownfall. You buy tokens from
the Carver's tray with a fixed ten fangs a turn, line five of them up, and
call the moot; the fight plays itself, front against front, and the tokens'
abilities do the rest. Ten crests wins the moot, four scars ends it. The
oldest law of the game is that you may only field what you have faced: your
collection is the bestiary you have catalogued in the world, so every new
monster and every felled boss becomes a piece. It pays Renown (daily-capped),
titles, cosmetics and lore, and never gold, gear or power.

Two owner rulings this design obeys and one it must be checked against:
- `PROPOSALS/BORROWED_LOOPS.md` §5: minigames pay Renown, daily-capped, and
  never pay gold or gear. Fangmoot pays no gold in either direction (§9).
- §5 scope guard: one minigame, one NPC, before deciding on a second.
  Fangmoot IS that one; the lapidary/dice candidates stay parked.
- §8: async defence-snapshot PvP was dropped because an AI-driven raid on a
  static hero loadout tests neither player's hands. In an autobattler BOTH
  warbands are static by the genre's design and the skill is entirely in the
  shop, so ghost warbands (§8 here) do not fall under that reasoning. Flagged
  as open question 3 in §16 rather than assumed.

Numbers in this doc are first-pass and belong in `balance.gd` as
`FANGMOOT_*` knobs; the bench in §14 exists to move them.

---

## 1. Design pillars (judge every later decision against these)

1. **Readable in thirty seconds.** Two stats (Bite, Hide), five slots, ten
   fangs, one button. Every ability is one line. If a rule needs a second
   sentence it does not ship in v1.
2. **The bestiary is your collection.** Tokens unlock by facing the beast.
   The codex stops going stale because players need it; every monster's
   entry shows its token line, and every new monster we ever add ships with
   a token (the same "codex first" rule CLAUDE.md already has).
3. **The codex teaches the token and the token teaches the codex.** Each
   token's ability is its in-world trait (bloat, martyr, tether, ward,
   frenzy, pounce, web, counter...). A player who learns that Casket
   Creepers burst into rot in the marsh already knows what the Casket
   Creeper token does, and the reverse.
4. **Depth from placement, bonds and triggers, never from thresholds.** No
   TFT-style "3 Wild = bonus" counters. Tribes exist as tags that abilities
   reference ("Wild allies +1 Bite"), so synergy is discovered by reading
   cards, not by memorising a table.
5. **Every fight is a small spectacle.** The tokens are our real animated
   sprites: attack clips on strikes, death clips on falls, FX on abilities.
   The moot should look like the game, not like a spreadsheet.
6. **Nothing you win is power.** Renown (capped), titles, board skins,
   gildings, trophies, lore. No gold, no gear, no gems, no XP, in or out.
7. **Deterministic and pure.** The fight is a pure function of (warband A,
   warband B, seed). The view replays a log. That is what makes it testable
   headless, sharable as a code, and playable live over the existing
   netcode without a server.

---

## 2. Fiction and framing

**What it is in the world.** A game of carved tokens the beastkin brought to
the city. Trackers once "called the moot" to settle who led a hunt: each
laid out tokens of the beasts they had personally faced, and the moot rules
imagined the fight. The oldest law survives as the game's collection rule.
Since the Waking, carvers copy every new horror ("the carvers can't keep up
with the world"), and Crownfall took to it: Sable Court nobles play for
stakes, Accord clerks play at lunch, Choir pilgrims field their own dead as
an act of remembrance (never a joke, per canon).

**The pit.** Existing flavour already says dogs fight "under Fangmoot
Circle" (`gear_flavor.gd`: Pit Fury, Brawler's Red). The pit stays
off-screen and referenced; the token game is what the galleries above play,
and the cure-camp beastkin's distaste for the pit is a line of banter, not a
quest.

**Materials (the visual grammar of tribes; also the gilding cosmetics
later).** Wild: bone and antler. Hollow: coffin-nail iron. Choir: blackened
wax. Molten: slag-glass. Still: ice-glass. Root: living root that keeps
growing. Storm: fulgurite (storm-glass). Named pieces are carved from a
felled beast's remains, which is why you must have felled the boss.

**The host: Carver Tove (new NPC).** A beastkin of the acceptance camp who
"carves what she has faced", runs the tray, keeps the callers' board, sells
nothing for gold. Needs one new 256 px 8-dir body + splash via the Scholar
Ivo recipe (`scholar-ivo-sprite`), roughly half a day of art. Skald Ottar
(already in the Circle) is the announcer and a rival; Warden Callis (also
there) is a rival. Peddler Nix comments and never plays.

**Foreshadow, do not spend.** "The first moot was called on a fen in the
west, before the city; ask a tracker where and they change the subject."
No name (the Moonfen is a held gun). No god-king is ever depicted; Named
pieces are bosses only.

**Diegetic vocabulary.** Fangs (the shop currency, carved chits), crests
(wins), scars (losses), tokens, bond (merge), Named (boss pieces), Bite and
Hide (the two stats), the Carver's tray (the shop), a caller (a player).
These are in-world words, so using them in dialogue is fine; the bible's
"no game vocabulary in fiction" rule is about resonance/XP words.

---

## 3. Glossary (the whole vocabulary; if a word is not here it is not in v1)

| Word | Meaning |
|---|---|
| Moot | One match: shop turns and fights until 10 crests or 4 scars. |
| Turn | Shop phase, then one fight. |
| Fangs | Shop currency; 10 every turn, unspent fangs vanish. |
| Token | A unit. Has Bite (attack), Hide (health), a tribe, a tier, one ability. |
| Bite | Damage it deals when it strikes. |
| Hide | Health. At 0 it Falls. |
| Tribe | Tag: Wild, Hollow, Choir, Molten, Still, Root, Storm. Abilities reference tribes; there are no tribe-count bonuses. |
| Tier | 1-5 for tokens; the tray unlocks tiers by turn. Named pieces sit outside the tiers. |
| Bond | Buying a copy of a token you own merges them. 3 copies = level 2, 6 = level 3. Levels scale the ability. |
| Named | A boss token. Costs 5, one per warband, appears in the tray from turn 7. |
| Charm | A permanent held item (gem icons), one per token. |
| Brew | A one-shot potion applied on purchase. |
| Front / rear | Slot 1 is the front; "ahead" means toward the front, "behind" toward the rear. |
| Muster | Trigger: fight start, before the first exchange. |
| Bite (trigger) | Trigger: just before this token strikes. |
| Hurt | Trigger: this token took damage and survived. |
| Fall | Trigger: this token reached 0 Hide. |
| Slay | Trigger: this token's strike or ability made an enemy Fall. |
| Ally Falls | Trigger: an ally Fell. |
| Ally Hurt | Trigger: an ally took damage and survived. |
| Ally Ahead Bites | Trigger: the ally directly ahead struck. |
| Heal n | Restore up to n Hide, never above the token's current maximum. |
| Turn End | Trigger: when you call the moot (press Fight), before the fight. Used for permanent growth. |
| Rot n | Status: whenever this token is Hurt it loses n more Hide. Stacks. |
| Burn | Status: takes 2 damage just before each of its own strikes. Does not stack. |
| Frost | Status: its next strike deals 0, then it thaws. Does not stack or refresh while frozen. |
| Ward (n) | Status: the next n instances of damage to it are 0. |
| Thorns n | Status: any token that strikes it takes n after the strike. |
| Preserved | Status: once per fight, when it would Fall it stays at 1 Hide instead. |
| Silenced | Status: its ability does not trigger this fight. |
| Crest / Scar | Win / loss marks for the moot. |
| Caller | A player. NPC callers are the opponents. |
| Ghost | A saved warband (yours from a past moot, or a friend's from a code) used as an opponent. |
| Ground | The terrain the moot is called on (one of the 14 in-play terrains). Sets the ring's look and, in v1.5, one symmetric rule. See §17. |
| Home ground | A token's native terrain (where it spawns in the world). On its home ground it musters with +1/+1. |

Reserved for v2 (not in v1 so the vocabulary stays small): Bought, Sold,
Bonded, Ally Summoned, Turn Start triggers; a Reach (ranged) keyword.

---

## 4. The moot (run structure)

- **Win: 10 crests. Out: 4 scars.** A draw marks neither. **Turns 1 and 2
  are sparring:** a loss there does not scar (early rolls are luck; the
  Super Auto Pets lesson that early losses must be cheap). Max length is
  15 turns; typical is 11-13, about 12-15 minutes at 1x fight speed.
- **Tables** (difficulty, not stakes; no gold changes hands): Copper from
  arrival; Silver after any moot of 7+ crests at Copper; Gold after a
  10-crest moot at Silver. Tables change opponent quality (§8), the Renown
  paid (§9), and nothing about the rules.
- **Concede** at any time; counts as scars filling. **Resume**: the moot
  state is pure data and is saved every turn, so quitting mid-moot resumes.
- **Fight speed** 1x / 2x / skip, remembered. Mobile defaults to 1.5x.
- **Opponent per turn:** matched by turn number (and crest count when
  possible) from the caller pool for that table (§8): NPC persona bots and
  ghosts.

---

## 5. The shop turn (the Carver's tray)

- **10 fangs a turn**, fixed. No interest, no carry-over (unspent fangs
  vanish; the flat income is what stops snowballing and keeps the maths
  legible).
- **Costs:** token 3, charm 3, brew 2, roll 1, sell +1 per level of the
  token sold (1/2/3), freeze free (a frozen tray card survives the roll and
  the turn).
- **Tray size:** turns 1-2: 3 tokens + 1 charm/brew; turns 3-6: 4 tokens +
  2; turns 7+: 5 tokens + 2. From turn 7 a **Named slot** may appear (30%
  per turn, 100% from turn 10) offering one Named piece at 5.
- **Tiers by turn:** T1 turns 1-2, T2 turns 3-4, T3 turns 5-6, T4 turns
  7-8, T5 turns 9+. When a tier unlocks it is weighted 3, the tier just
  below 2, older tiers 1 (knob `FANGMOOT_TIER_WEIGHTS`), so early tokens
  keep appearing without drowning the tray.
- **Board:** 5 slots, your warband IS the row (no separate bench). Buy →
  place in an empty slot or onto a copy to bond. Drag to reorder any time in
  the shop. Sell from the slot.
- **Bond:** a copy dropped on its twin merges: the survivor keeps the higher
  Bite and Hide, +1/+1, and levels at 3 and 6 total copies. Copies can also
  be bonded directly from the tray onto the board (buying a copy = 3 fangs).
  When a token reaches level 2 or 3 the tray sets out one token from the
  next tier ("the Carver notices").
- **Charms** attach on drop; a token holds one; a new charm replaces the old
  (no refund). **Brews** apply on drop and are gone.
- **Pool composition (the collection rule, §7 has the list):** the tray
  draws from tokens you can field. Tiers 1-2 are the **Carver's stock**,
  always available ("common pieces every child in Crownfall owns"). Tiers
  3-5 and Named require the catalogue: `kill_counts[kind] > 0` for the
  monster (`game_base.gd:398`, first kill) and the boss felled for Named.
  If a tier has fewer than 4 fieldable tokens the tray borrows the missing
  count from the tier below, never above.
- **Call the moot** = end turn. Turn End abilities fire, then the fight.

---

## 6. The fight (exact rules; the sim implements this and nothing else)

Setup: both warbands, up to 5 slots, slot 1 at the front. Empty slots are
skipped; tokens shift forward when one ahead Falls.

**Muster.** All Muster abilities on both sides resolve, ordered by Bite
descending across both sides; ties by Hide descending; remaining ties by a
seeded coin. Then exchanges begin.

**One exchange** (repeat until a side is empty):
1. **Bite triggers** of both fronts, in the same ordering rule.
2. **Strikes.** Both fronts strike simultaneously. Each takes the other's
   Bite as damage. Burn applies its 2 to the striker first; Frost makes a
   strike deal 0 and thaws; Ward absorbs; Onyx-type reductions apply; the
   Amber charm makes its holder strike first, and if the target Falls it
   does not strike back.
3. **Aftermath**, in this order: Hurt triggers and Rot extra loss; Thorns;
   Fall (Preserved is checked at the moment of lethal damage: stays at 1
   once); Slay; Ally Falls; Ally Ahead Bites (fires for the token behind
   each striker); shift forward.
4. Anything a trigger causes (damage, summons, statuses) is queued and
   resolved FIFO with the same ordering rule, **depth cap 32 per exchange**;
   past the cap, remaining queued effects are dropped (never a hang).
Ability damage ("deal X") is not a strike: it triggers Hurt, can Slay, is
absorbed by Ward, ignores Thorns and Onyx.

**End.** A side with no tokens loses. Both empty in the same aftermath =
draw. **200 strikes = draw** (anti-stall; the bench must show this fires in
under 0.5% of fights or something is broken).

**Summons** appear directly behind the summoner (or in its slot if it Fell),
shifting others back; a full row means no summon. Summon tokens are not
buyable and have no charms.

**Statuses** are per fight and cleared afterwards, except permanent stat
gains, which say "permanently" on the card.

**Determinism.** `fight(band_a, band_b, seed) -> {result, log}`; the seed is
the moot seed + turn. Same inputs, same log, on every machine (integer maths
only; the RNG is Godot's `RandomNumberGenerator` seeded explicitly).

**Log events** (what the view renders): muster, strike (a, b, dmg_a, dmg_b),
hurt, fall, summon, status_add, status_use, stat_change, ability (source,
name), draw/win. Each carries slot ids so the renderer can play the right
sprite clip (attack on strike, death on fall, `_fx_flash` on ability).

---

## 7. The pieces (v1 set: 39 tokens + 21 Named + 4 summons + 10 charms + 6 brews)

Design method: every id below is a real `Story.ALL_ENEMIES` key or boss id
(so `Art.tex(sprite)` and the codex `_enemy_icon` path work unchanged), the
tier is a moot property (not the monster's chapter), and each ability is
the monster's `enemy.gd` trait or the boss's signature move rendered in
moot terms. Stat sums per tier: T1 4-5, T2 6-8, T3 9-11, T4 12-14, T5
15-17, Named 18-22. Ability values are written L1 → L2 → L3.

Two tokens share a sprite in a few places (gravewalker uses the zombie
body, barrow_wight the skeleton_rogue body, void_shade the bandit_scout
body...). Each token gets a fixed chroma tint via the existing `chroma`
shader so twins never look identical on the board.

### 7.1 Tribes (identity, signature status, and the design lesson each teaches)

| Tribe | Who | Identity | Signature | Lesson |
|---|---|---|---|---|
| **Wild** | beasts, beastkin, Fangmaw's line | pack buffs, first strikes, "hunt the hurt" | Pounce / Pack | order the pack; the front matters |
| **Hollow** | Vargoth's dead, the Vale's unburied | gains from allies falling; things come back | Return | plan for the deaths, not against them |
| **Choir** | blight, Mórwyn's faithful | Rot, martyrdom, cheap bodies that feed the rest | Rot | attrition; the last one standing is a monster |
| **Molten** | the Judge's foundries | Burn, thorns, verdicts on the biggest enemy | Burn | punish the striker; heavy hitters pay |
| **Still** | the Queen's sleep | Frost, Preserved, walls that will not die | Frost | tempo; deny strikes rather than out-hit |
| **Root** | the Pale Root's growth | summons, permanent growth, compost on death | Grow / Summon | width; more bodies than they can kill |
| **Storm** | the Tongue's unkept word, the void | chain damage, silence, retaliation | Chain / Silence | reach past the front; turn abilities off |

### 7.2 Tokens by tier (id · Name · tribe · Bite/Hide · ability · source trait)

**Tier 1 (turns 1-2) — the Carver's stock**
- `wolf` Blighted Wolf · Wild · 2/2 · **Pack**: Muster: +1 Bite for each other Wild ally (→ +2 → +3). *pounce/pack*
- `spider` Marsh Spider · Wild · 1/3 · **Web**: Muster: Frost the enemy front (→ front two → front three). *web*
- `zombie` Risen Corpse · Hollow · 1/4 · **Refuses the ending**: Turn End: +1 Hide permanently (→ +2 → +3). *mend*
- `cultist` Blight Cultist · Choir · 1/2 · **Tend**: Muster: the ally ahead +0/+2 (→ +0/+4 → +0/+6). *channel_heal*
- `cinder_whelp` Cinder Whelp · Molten · 2/2 · **Whelp-fire**: Muster: Burn the enemy front (→ front two → front three). *pounce, vent-born*
- `cold_pilgrim` Cold Pilgrim · Still · 1/3 · **Numb**: Hurt: Frost the token that hurt it, once per fight (→ twice → three times). *mend/porter*
- `sporeshambler` Spore Shambler · Root · 1/3 · **Compost**: Fall: the ally behind +1/+1 (→ +2/+2 → +3/+3). *mend*

**Tier 2 (turns 3-4) — the Carver's stock**
- `blightwolf` Waking Wolf · Wild · 3/2 · **Pounce**: Muster: deal 2 to the enemy front (→ 4 → 6). *pounce*
- `bogspider` Greyrun Lurker · Wild · 2/4 · **Lurk**: Ally Ahead Bites: deal 1 to the enemy front (→ 2 → 3). *web*
- `skeleton` Hollow Soldier · Hollow · 3/3 · **Frenzy**: Hurt: +1 Bite (→ +2 → +3). *frenzy*
- `gravewalker` Unburied Walker · Hollow · 2/4 · **Walks its own funeral**: Fall: summon a 1/1 Risen Corpse in its place (→ 2/2 → 3/3). *mend / "the dead walk their own funerals"*
- `casket_creeper` Casket Creeper · Choir · 2/4 · **Bloat**: Fall: Rot 2 the enemy front (→ Rot 4 → Rot 6). *bloat*
- `vent_skitter` Vent Skitter · Molten · 2/3 · **Eats what falls**: Slay: +1/+1 permanently (→ +2/+2 → +3/+3). *"eats what falls"*
- `winterfang` Winterfang · Still · 3/3 · **Cold trail**: Slay: Frost the enemy that steps forward (→ and deal 2 to it → deal 4). *pounce, shepherd*
- `bog_lurker` Bog Lurker · Root · 2/4 · **Snare-roots**: Muster: Thorns 1 (→ 2 → 3). *web*
- `void_shade` Void Shade · Storm · 3/2 · **Blink**: Muster: Ward (→ Ward, and deal 1 to the first striker → deal 3). *blinker*
- `null_acolyte` Null Acolyte · Storm · 1/4 · **Null**: Muster: Silence the enemy front (→ front two → front three). *channel_heal, void*

**Tier 3 (turns 5-6) — catalogue required from here on**
- `duneprowler` Dune Prowler · Wild · 4/3 · **Hunt**: Bite: +2 damage if the target is Hurt (→ +4 → +6). *pounce*
- `beastkin_raider` Wildfang Raider · Wild · 4/4 · **Raid**: Slay: the ally behind +1/+1 (→ +2/+2 → +3/+3). *frenzy, swift*
- `stormcult` Choir Cantor · Choir · 2/5 · **Cant**: Turn End: a random Choir ally +1/+1 permanently (→ +2/+2 → +3/+3). *channel_heal*
- `plague_chanter` Plague Chanter · Choir · 2/4 · **Three words**: Muster: Rot 1 every enemy (→ Rot 2 → Rot 3). *"three words of dead cant"*
- `barrow_wight` Barrow Wight · Hollow · 4/3 · **Old bones**: Ally Falls: +2 Bite (→ +3 → +4). *frenzy*
- `forge_acolyte` Forge Acolyte · Molten · 2/5 · **Reflect**: Muster: Thorns 2 (→ 3 → 4). *reflect*
- `deep_stalker` Crystal Stalker · Still · 4/3 · **Crystal web**: Bite: Frost the target, once per fight (→ twice → three times). *web*
- `root_shambler` Root Shambler · Root · 3/5 · **Tether**: Fall: the ally behind is healed to full Hide (→ and +1/+1 → +2/+2). *tether*
- `storm_harrier` Storm Harrier · Storm · 4/3 · **Chain**: Bite: also deal 1 to the enemy behind the target (→ 2 → 3). *sower, "outran the thunder"*
- `void_husk` Voidbound Husk · Storm · 2/6 · **Void burst**: Fall: deal 2 to the enemy front and the one behind it (→ 3 → 4). *warded, mend*

**Tier 4 (turns 7-8)**
- `beastkin_howler` Wildfang Howler · Wild · 4/6 · **Howl**: Muster: all Wild allies +2 Bite (→ +3 → +4). *skirmish, pounce*
- `sun_bleached` Sun-Bleached Husk · Hollow · 3/8 · **Bleached**: Muster: Ward (→ Ward 2 → Ward 3). *warded*
- `vale_mourner` Vale Mourner · Choir · 2/6 · **Martyr**: Fall: all Choir allies +2/+2 (→ +3/+3 → +4/+4). *martyr*
- `slag_brute` Slagbound Brute · Molten · 6/5 · **Sower**: Bite: Burn the target (→ and the one behind it → all enemies). *sower*
- `frost_husk` Frost-Bound Soldier · Still · 5/6 · **Preserved**: once per fight it stays at 1 Hide instead of Falling (→ and gains Ward when it does → twice per fight). *warded, swift*
- `hushcaller` Hushcaller · Still · 3/6 · **Lullaby**: Muster: Frost the two enemies with the highest Bite (→ three → four). *snare*
- `static_caller` Static Caller · Storm · 3/6 · **Static**: Ally Hurt: deal 1 to the enemy front (→ 2 → 3). *channel_heal, snare*

**Tier 5 (turns 9+)**
- `wildkin_ranger` Wildkin Ranger · Wild · 6/6 · **Volley**: Ally Ahead Bites: deal 2 to the enemy front (→ 4 → 6). *skirmish, ranged*
- `frozen_guard` Frozen Guard · Still · 5/9 · **Frost aura**: Bite: Frost the target (→ and the one behind it → all enemies). *frost_aura*
- `grove_horror` Grove Horror · Root · 7/7 · **Overgrow**: Turn End: +2/+2 permanently (→ +3/+3 → +4/+4). *frenzy, warded*
- `bloom_acolyte` Bloom Acolyte · Root · 3/7 · **Bloom**: Ally Falls: summon a 2/2 Rootling in its place, max 3 per fight (→ 3/3 → 4/4). *spawner*
- `vow_sentinel` Vow Sentinel · Storm · 5/8 · **Counter**: Hurt: deal 3 to the striker (→ 5 → 7). *counter*

### 7.3 Named pieces (bosses; cost 5, one per warband, tray Named slot from turn 7; unlock = boss felled)

- **Wild** — `fangmaw` Fangmaw the Ravener 8/10 · **Call the Pack**: Muster: summon two 2/2 Blighted Wolves behind it (→ 3/3 → 4/4). · `whitepelt` Hrolgar Whitepelt 9/11 · **Pelt Drums**: Muster: Wild allies +3/+3 (→ +4 → +5). · `curetwisted` Kaethra Cure-Twisted 10/9 · **Cure-Twisted**: Slay: heal all allies 3 Hide (→ 5 → 7).
- **Hollow** — `vargoth` King Vargoth the Hollow 10/12 · **Blade Storm**: Bite: deal 3 to every enemy (→ 4 → 5). · `sexton` The Sexton 7/12 · **Chain-Detonating Corpses**: Ally Falls: deal 3 to the enemy front (→ 5 → 7). · `vess` Vess the Unburied 6/12 · **The Wail**: Fall: deal 4 to every enemy (→ 6 → 8).
- **Choir** — `morwen` Morwen the Blightcaller 8/10 · **Blight Rain**: Muster: Rot 2 every enemy (→ 3 → 4). · `choirmother` The Choir Mother 6/13 · **Requiem**: Ally Falls: every Choir ally +2/+2 (→ +3 → +4). · `saint_varo` Saint Varo the Unrotting 5/16 · **The Toll**: Hurt: the striker gains Rot 2 (→ 3 → 4).
- **Molten** — `forgemistress` Forgemistress Calda 8/10 · **White-Hot Slag**: Muster: Burn every enemy (→ and deal 2 to each → 4). · `cinderhide` Cinderhide the Unquenched 7/13 · **Obsidian Plating**: Muster: Ward and Thorns 3 (→ Thorns 4 → 5). · `ashpriest` Ashpriest Ordo 9/9 · **The Verdict**: Muster: deal 6 to the enemy with the highest Bite (→ 9 → 12).
- **Still** — `icebound` Serane the Icebound 7/12 · **Flash Freeze**: Muster: Frost every enemy (→ and deal 2 to each → 4). · `sleepkeeper` Mother Halla 5/14 · **The Long Sleep**: Ally Falls: it is Preserved instead, once per fight (→ twice → three times).
- **Root** — `gardener` Rotmaw the Gardener 6/14 · **Carnivorous Bloom**: Slay: summon a 2/2 Rootling behind it (→ 3/3 → 4/4). · `auroch` The Drowned Auroch 11/9 · **Gore Rush**: Bite: also deal 3 to the enemy behind the target (→ 5 → 7).
- **Storm** — `stormwarden` Korrag, Stormwarden Broken 9/10 · **The Storm Breaks**: Hurt: if at half Hide or less, +4 Bite, once per fight (→ +6 → +8). · `nullwarden` Warden Null 6/15 · **Null Field**: Muster: Silence every enemy (→ and Ward → and +2/+2). · `stormdrake_veyx` Veyx, the Unchained Current 10/9 · **Arc**: Bite: deal 3 to the enemy behind the target and 2 to the one behind that (→ 5/3 → 7/4). · `unnamed_echo` The Echo of the Unnamed 8/8 · **Splintering Void**: Muster: summon two 3/3 Mirrors behind it (→ 4/4 → 5/5). · `stormmouth` Cyrraeth, Mouth of the Storm 8/12 · **Storm Rotation**: Bite: Frost the target and deal 2 to every other enemy (→ 3 → 4).

The six dev-only placeholder bosses (cyclops, tengu, flame_giant,
great_spirit, ooze, kraken) get no pieces; they are not in the world.

### 7.4 Summon tokens (internal, not buyable, no charms)

Blighted Wolf (`wolf` art) · Risen Corpse (`zombie`) · Rootling
(`root_spiderling` art) · Mirror (`echo` art, tinted, vanishes at fight end).

### 7.5 Charms (gems; permanent held, one per token, cost 3; icons = `Items.GEM_STATS`)

| Gem | Charm |
|---|---|
| Ruby (atk_flat) | +2 Bite. |
| Garnet (hp_flat) | +3 Hide. |
| Topaz (crit) | Its first strike each fight deals double. |
| Opal (combo) | Ally Ahead Bites: +1 Bite this fight. |
| Onyx (physres) | Takes 1 less from strikes (min 1). |
| Lapis (magres) | Immune to Rot, Burn and Frost. |
| Bloodstone (physpen) | Its strikes ignore Ward. |
| Amber (dex) | Strikes first in the exchange; a target that Falls does not strike back. |
| Tenacity (flat_dr) | Preserved (once per fight). |
| Vampire Eye (lifesteal) | Heals half its Bite (rounded down) when it strikes. |

Sapphire, Sunstone, Amethyst and Jade are held back for v2 (the first three
are ability-multipliers that need the bench before they are safe; Jade
duplicates Ward).

### 7.6 Brews (one-shot, cost 2; names from `Items` potion tables and pit flavour)

Brawler's Red: +2 Hide permanently to one token. · Pit Fury: +2 Bite
permanently. · Accordmark Tonic: +1/+1 permanently. · Elixir of Warding:
Ward this fight. · Elixir of Might: +3 Bite this fight. · The Carver's
Meal: +1 Hide permanently to every token on the board.

---

## 8. Opponents (callers)

**Fair by construction.** Every opponent builds from the same pool you can
buy from, under the same tray rules and tier schedule, so their strength
scales with the turn automatically and a Ch1 player never faces Tier 5
pieces they cannot own. Signature Named pieces appear in a caller's band
only once you have felled that boss.

**Persona bots** (v1: ten). A persona is `{tribe_bias, greed, front_rule,
bond_love, noise}` and a set of quips (moot start, win, loss, first-time
beaten). Each turn the bot plays the tray: score each card = tier value ×
tribe_bias × synergy with its board (tags its abilities reference) × bond
bonus if it owns a copy; buy the best while fangs ≥ 3; roll when the best
score is under a threshold and greed allows; place by `front_rule`
(highest-Hide front, martyrs front, Ally-Ahead pieces second, growers rear);
sell its weakest when the board is full and a better card shows. `noise`
is the table knob: Copper 0.5 (half its picks are random, no rolls), Silver
0.2, Gold 0.05. Bots never peek at your board.

| Caller | Table | Bias | Voice |
|---|---|---|---|
| Fisher Dov | Copper | Wild + Root, "whatever the river gives" | gentle, first opponent in the tutorial |
| Digger Haim | Copper | Hollow | "I dig them up; I ought to know them" |
| Skald Ottar | Silver | Wild pack | boastful; the announcer |
| Cantor Ilse | Silver | Choir | solemn; the Choir is never a joke |
| Smith Petra | Silver | Molten | taciturn, one-line quips |
| Herbalist Kesh | Silver | Root | patient, greedy roller |
| Storm Chaser Ilya | Gold | Storm | quick, chain-happy |
| Warden Callis | Gold | Still + Hollow | disciplined walls |
| Old Fenna | Gold | Hollow | names every piece after someone she is forgetting; the saddest set in the room |
| Carver Tove | Gold (house) | all tribes | "she carved every one of these"; unlocks after the other nine are beaten at Gold |

**Ghosts.** After every fight your warband snapshot (turn, seed, band) goes
into a local ghost pool (cap 200, oldest out). Friends' warband codes (§11)
enter the same pool. Matchmaking per turn: 60% persona bot, 40% a ghost of
the same turn if one exists. A ghost may hold tokens you have not faced;
its card shows "You have not faced this yet" and grants nothing.

**Callers' board.** In the Circle UI: each caller's portrait, beaten/not
per table, their signature Named piece shown as a trophy once beaten at
Gold.

---

## 9. Rewards (never power; obeys BORROWED_LOOPS §5 and §7)

No gold in, no gold out. No gear, gems, XP or materials, ever. Renown is the
one wallet (account-wide, `game_flow.add_renown`), titles are the existing
achievement titles, cosmetics are bought with Renown in the existing store.

| Faucet | Amount (knobs) | Cap |
|---|---|---|
| First moot won at a table | `RENOWN_FANGMOOT_TABLE_FIRST` Copper 10 / Silver 15 / Gold 25 | once each |
| A 10-crest moot | `RENOWN_FANGMOOT_WIN` 3 | `RENOWN_FANGMOOT_DAILY_CAP` 9 per trusted-clock day (the `*_day` int-on-character idiom from `renown_cache_week`) |
| A caller beaten for the first time | `RENOWN_FANGMOOT_CALLER_FIRST` 5 | once per caller |
| Collection milestones (25/50/75/100% of pieces fieldable) | 10 / 15 / 20 / 30 | once each |

- **Titles** (`Achievements.TITLES`): *Moot-Caller* (first 10-crest moot),
  *Fangmoot Champion* (all ten callers beaten at Gold), *The Carver's
  Friend* (100% of pieces fieldable).
- **Cosmetics in the Renown store:** three board skins (Wildfang hide, Sable
  Court velvet, Choir cloth) at the chroma price (60); needs a new `kind`
  branch in `buy_cosmetic` (`game_flow.gd:492`) and a row builder in
  `ui/wardrobe.gd`. **Gildings** are earned, not bought: a token whose lore
  threshold is reached (`Lore.threshold`, 25 kills / 3 boss kills) gets a
  gilded frame and shows its codex quip on the card.
- **Trophies:** a caller's signature Named piece displayed on the Circle
  shelf when beaten at Gold.
- **Lore:** six *Moot Legends* pages (§12) unlocked at milestones.
- **Echo pet:** the pet line does not exist yet; when it does, "Fangmoot
  Champion" is the natural first earned echo pet. Parked, noted here so the
  hook is remembered.

Economy check: `game/econ_audit.gd` gains a Fangmoot row that must read
zero gold in and zero out; the Renown side is bounded by the daily cap and
the one-time grants (worst case per account ≈ 50 + 50 + 75 + 9/day).

---

## 10. Unlocks and the collection

- **Fieldable** = Tier 1-2 (Carver's stock, always) + any Tier 3-5 token
  whose monster has `kill_counts[kind] > 0` + any Named whose boss has been
  felled (same ledger). Per character, like `kill_counts` itself.
- **Mastered** (gilded) = `kill_counts[kind] >= Lore.threshold(kind)`.
- **Collection shelf** (in the Circle UI, from Tove): grid by tribe and tier,
  locked pieces greyed with "Face it in the field: <chapter/terrain>" from
  the spawn tables, Named list, charms, brews, board skins, trophies. This is
  the Pokedex screen; it exists to make a locked slot itch.
- **Codex integration** (CLAUDE.md codex rule): a Field-notes chip
  "Fangmoot" (rules in plain words) in `UICodex.NOTE_PAGES`; every monster
  and boss detail gains a "Token" line (tier, Bite/Hide, ability, fieldable
  or not). The Named list must track `Menus.BOSS_KINDS`, the same parallel
  list the codex already depends on.
- **Rule for future content:** every new monster or boss ships with its
  token row in `fangmoot_data.gd`, or preflight fails (add the check next
  to the codex/BOSS_KINDS staleness check). Act 2's chapters therefore add
  pieces for free, and thin tribes (Molten, Root) fill in naturally.

---

## 11. Friend play (no server): codes, live versus, and the duel mode

Owner direction 2026-08-17: keep the moot a pure autobattler, AND let two
friends who want a straight showdown have one over a lobby code, the way
co-op already gathers a party. Three layers, cheapest first:

- **Warband codes (v1).** "Copy warband code" on any turn produces
  `FM1-<base64>` (token ids, levels, charms, positions, turn, seed; under
  120 chars). A friend pastes it in the Circle UI (the lobby's clipboard
  copy is the precedent, `ui/lobby.gd:351`); it joins their ghost pool at
  that turn. Zero server, zero accounts.
- **Live versus (v1.5, same rules, both present).** Friend joins the lobby
  with the code (`net_manager.host/join`), both walk to the Circle, one
  challenges, both accept via the MP-20 ready-check RPC
  (`net_session.gd:2664`, `propose_content` / `answer_ready`). Both play
  their tray in parallel with a 60 s shop timer; every turn the host runs
  `fight(a, b, seed)` between the two warbands and broadcasts the log; both
  screens replay it. First to 7 crests, best of the pair's scars. Party
  members 3 and 4 spectate. Real-time in the sense that matters (both
  present, both adapting to what the other is building); the fight itself
  stays automatic. Cost ≈ one week on top of v1 because sim, data, UI and
  collection are all shared.
- **Circle rules: the duel (v2 sketch, a second rulebook on the same
  pieces).** For two players who want to actually move pieces against each
  other. Live only, over the same lobby code; never against a bot or a
  ghost, which is what makes it cheap: no AI opponent is needed. Sketch, to
  be designed properly only if people ask for it after live versus ships:
  - Board 6×5. Each caller has a **caller's stone** (a king piece, 0 Bite,
    12 Hide) that must be protected; the game ends when a stone Falls.
  - **Draft, not collections:** both players pick alternately from one
    shared tray of 12 pieces until each has 5, so the duel tests decisions,
    not who has played more chapters. Charms and brews are drafted the same
    way, two each.
  - Alternate turns; on your turn one piece moves one square orthogonally,
    or strikes an adjacent enemy for its Bite (the struck piece does not
    strike back; that is what makes it chess-like rather than a brawl), or
    uses a Named piece's ability if it has one that says "on your turn".
  - Ability re-keying is mechanical and is why the v1 data should carry a
    `grid` variant per ability from day one: Muster → "when placed"; Ally
    Ahead Bites → "an adjacent ally strikes"; "the ally behind" → "an
    adjacent ally"; "enemy front" → "the nearest enemy"; Fall / Slay /
    Hurt / Ally Falls / Turn End unchanged; Rot / Burn / Frost / Ward /
    Thorns / Preserved / Silenced identical.
  - Turn timer 45 s; host validates moves; the whole state is a small
    Dictionary, so it rides the same RPC pattern as the ready-check.
  - Cost ≈ 3-4 weeks after v1 (board UI, the re-keying pass, a duel
    balance pass by hand since there is no bench opponent). Design pass
    required before any of it is built; nothing here is committed.
- The Circle UI does not pause the world (co-op never pauses); it gates on
  `menus.is_open()` like every overlay, per CLAUDE.md.

---

## 12. Lore pages (Moot Legends), and what each caller reveals

1. **How a moot is called** (the tracker custom; the oldest law).
2. **The pit below** (the city's shame; the cure-camp's objection; the
   acceptance-camp's shrug).
3. **The carvers** (materials per tribe; a Named piece is carved only from
   a felled beast's remains).
4. **The Sable Court's game** (nobles, stakes, the Cinderborn's line that
   "order needs a table").
5. **What the Choir plays for** (remembrance; their pieces are their own
   dead; dignified).
6. **The first moot** (a fen in the west, before the city; the trackers will
   not say where).

Old Fenna's banter is the emotional centre: she names each of her Hollow
pieces after someone she is forgetting, and the game is how she keeps them.
Warden Callis plays the truce: disciplined, no gloating. Cantor Ilse
explains why the Choir fields the dead. Tove is the only one who talks about
the west, and only sideways.

---

## 13. UI and UX

**Layout (1280×720 base, landscape on mobile).**
- Top bar: turn number, crests ●●●●●●●●●● (10), scars ✕✕✕✕ (4, sparring
  turns shown hollow), opponent portrait (existing splash crop) + name +
  one-line quip, fangs counter, fight-speed toggle, Concede.
- Middle: the arena band on the `capital_wildfang` floor with a drawn moot
  ring: your five slots left of centre facing east, the opponent's five
  right of centre facing west (our sprites have both facings; single-facing
  sprites flip). Tokens render at ~100 px (heroes' 190 px sources scaled
  ~0.5, mobs by their `scale`), each on a pedestal disc with Bite/Hide
  chips (the HUD chip style, `hud.gd:899`, corner radius 11), tribe emblem,
  level pips, status glyphs, charm gem.
- Bottom: the Carver's tray: 3-5 token cards + 1-2 charm/brew cards, each
  with sprite, cost, tier pips, tribe emblem; Roll (1), Freeze toggle per
  card, **Call the moot** button. Sell bowl at the row's end.
- Inspect card (hover / long-press): name, tribe, tier, Bite/Hide, ability
  text at current level, "at level 2 / 3" preview, codex quip if mastered,
  fieldable hint if a ghost's unknown piece.
- Fight: strikes play the sprite's attack clip toward the enemy, falls play
  the death clip, abilities flash `_fx_flash` (existing FX strips: poison
  cloud for Rot, frost snowflake for Frost, rage burst for Frenzy, aegis
  dome for Ward...). Numbers float. Result banner, then "Next turn".
- Circle hub screen (before a moot): Play (table select), Collection, Callers'
  board, Legends, Codes (copy / paste), Skins.

**Interaction.** Desktop: drag cards to slots, drag tokens to reorder, drag
to the sell bowl; click Freeze. Mobile: tap card → valid slots glow → tap
slot; tap token → tap slot to swap; tap-hold Freeze; every target ≥ 44 px.
Keyboard: 1-5 buy, R roll, Space call.

**Tutorial.** The first Copper moot is scripted: Tove speaks three one-line
callouts (buy, place, call) over the first two turns against Fisher Dov;
skippable; never shown again (`fangmoot.tutorial_done`).

**Accessibility.** Statuses are glyphs, not tints; numbers are 20 px+ on the
board; text speed follows the game setting; fight speed remembered.

---

## 14. Architecture, tests, bench

**Files.**
- `game/scripts/fangmoot/fangmoot_data.gd` — `class_name FangmootData`:
  TRIBES, TOKENS, NAMED, SUMMONS, CHARMS, BREWS, CALLERS (data tables stay
  in their domain file, per CLAUDE.md). Each ability row is data, not code:
  `{trigger, effect, target, value: [L1, L2, L3], grid: {trigger, target}}`,
  where `grid` is the duel re-keying from §11 (Muster → placed, front →
  nearest, ahead/behind → adjacent). Writing it now costs one field per row
  and means the v2 duel reads the same table. Each token row also carries
  `home` (its terrain, §17) and GROUNDS holds the 14 ground rows (floor,
  tint, ambient, rule id).
- `game/scripts/fangmoot/fangmoot_host.gd` — the `FangmootHost` seam from
  §18 (fieldable / mastered / portrait / clip / reward / save / load /
  share). `fangmoot_host_crownless.gd` implements it against `kill_counts`,
  `Art`, `add_renown` and `save.gd`; nothing else in the folder may import
  `game_base`, `save.gd` or Renown directly (the test in §14 item 8 greps
  for it).
- `game/scripts/fangmoot/fangmoot_sim.gd` — `class_name FangmootSim`
  (RefCounted, pure): `static func fight(a, b, seed) -> Dictionary`.
- `game/scripts/fangmoot/fangmoot_moot.gd` — the moot state machine
  (turn, fangs, tray, board, tiers, crests/scars, opponent pick), fully
  serialisable to a Dictionary for save/resume.
- `game/scripts/fangmoot/fangmoot_bot.gd` — persona shopper.
- `game/scripts/fangmoot/fangmoot_codes.gd` — warband ⇄ `FM1-` string.
- `game/scripts/ui/fangmoot.gd` — `class_name UIFangmoot`, `static func
  open(m: Menus)` sets `m.current = "fangmoot"` (the UI-module pattern of
  `ui/wardrobe.gd`, `ui/daily.gd`); `game/scripts/ui/fangmoot_arena.gd` —
  the log renderer (Node2D with the sprites).
- `balance.gd` — `FANGMOOT_*` knobs (fangs, costs, tray sizes, tier
  weights, crests, scars, sparring turns, Named odds, caps, Renown).
- Hooks: `tools/content/gen_capital.py` (edit the generator, not
  `capital_hub.gd`): landmark use `{"ref": "fangmoot", "prompt": "E — Call
  a moot"}` on `capital_wildfang_fangmoot` (replacing the current journal
  use, which moves to a bench) + NPC Carver Tove; add `"fangmoot"` to
  `known_actions` in `CapitalHub.selftest()`; `GameWorld._hub_action`
  branch → `menus.open_fangmoot()` → `UIFangmoot.open`. `save.gd`: one key
  `fangmoot` in `_character_section` + one restore line in
  `apply_character` (unknown keys survive migration, so no version bump).
  `game_flow.gd`: Renown grants; `achievements.gd`: three titles;
  `ui/codex.gd`: NOTE_PAGES chip + token line in monster/boss detail;
  `skins.gd` + `ui/wardrobe.gd`: board-skin kind.
- New `class_name` scripts → `--import` before any headless run (CLAUDE.md
  trap).

**Tests** (`autotest.gd`, one `_test_fangmoot()` section, snapshot/restore
around it, plus the UI smoke line in the touch scan):
1. Determinism: 200 random (a, b, seed) triples, `fight` twice each,
   identical logs.
2. No stall: 2,000 random bands including summon-heavy and Preserved-heavy
   ones; every fight ends under the strike cap; depth cap never reached in
   more than 1%.
3. Fixture fights: ten hand-written bands with expected results (the rules
   in §6 written as asserts: Frost thaws after one strike, Ward absorbs
   ability damage, Thorns ignores ability damage, Amber first-strike stops
   the return blow, Preserved once).
4. Bot completes a moot headless at each table within 15 turns.
5. Codes: encode → decode round-trip; tampered code rejected.
6. UI smoke: `menus.open_fangmoot()`, `current == "fangmoot"`, close.
7. Data lint: every `ALL_ENEMIES` kind that content places and every
   `Menus.BOSS_KINDS` id has a token row (this is the preflight rule too);
   every token's `home` is a real terrain id; every in-play terrain has a
   GROUNDS row.
8. Seam lint: no file under `game/scripts/fangmoot/` except
   `fangmoot_host_crownless.gd` references `GameBase`, `Save`, `add_renown`
   or `_meta` (a text grep in the test; keeps §18 honest).

**Bench** (`game/scripts/tests/fangmoot_bench.gd` + `fangmoot_bench.bat`,
the `dps_bench` pattern): N bot-vs-bot moots per table (10k in under 90 s
headless is the target); prints per-token pick rate, fielded win rate,
average final level; per-tribe win rate; moot length distribution; fight
length distribution; draw rate; Named presence in winning bands. Flags:
token outside 40-60% fielded win rate at its tier, tribe outside ±8%,
draws over 8%, any fight over 60 strikes.

**Mobile:** touch input as in §13; after the suite, `python
tools/sync_mobile.py --apply --gate`.

---

## 15. Balance method (how the numbers get true)

Targets: per-token fielded win rate 45-55% at its tier at Silver; tribe
win rates within ±4% of each other; mean moot 11-13 turns; the Silver bot
reaches 10 crests ~40% of the time and the Gold persona ~55%; mean fight
12-25 strikes, 99% under 60; draws under 8%; Named fielded win rate under
60% (strong, not automatic).

Tuning ladder, in this order, one step at a time: base stats → ability
numbers → level scaling → tier placement → tray odds. Move nothing without a
bench run before and after; the bench output goes at the top of a
`FANGMOOT_HISTORY` block in `BALANCE_HISTORY.md` like every other round.

Things to watch specifically: summon spam (Bloom Acolyte + Rotmaw), Silence
(Null Acolyte at T2 may be too good; the fix is stats, not the effect),
permanent scalers (Grove Horror, Vent Skitter) running away in long moots,
Frost stacking on wide Still boards, and any loop between Ally Falls
retaliation and summons (the depth cap is a guard, not a fix; the bench
must show it never triggers in normal play).

---

## 16. Build plan and gates

Assumes the current cadence (owner + parallel agents), Godot 4.4.1, and that
`game/` remains the source of truth with a mobile re-sync at the end.

- **Phase 1, weeks 1-2: the sim.** Data tables (§7, with `home` and
  GROUNDS), sim (§6, plus Layer 1 home ground), bot (§8), codes (§11), the
  `FangmootHost` seam (§18), bench and tests (§14). Headless only.
  **Gate A:** 10k bot moots under 90 s across all 14 grounds; zero stalls;
  every token 40-60%; tribes ±8%; no ground moves any tribe more than ±3%
  (home ground is a nudge, not a rule).
- **Phase 2, weeks 3-4: the screen.** UI + arena renderer, capital hook,
  save/resume, Copper table with Dov and Haim, tutorial, Renown/titles.
  **Gate B:** the owner plays ten moots and wants an eleventh; a phone pass
  with the touch HUD gated correctly.
- **Phase 3, weeks 5-6: the rest.** Silver/Gold + all ten callers, ghosts,
  codes UI, charms/brews polish, collection shelf, codex pages, board skins,
  Moot Legends text, econ/renown audit row, preflight rule, mobile sync,
  full suite. **Gate C:** full suite green; preflight clean; owner review.
- **Phase 4, later (v1.5):** live versus over the ready-check RPC; ground
  rules one at a time as the bench clears them (§17 Layer 2); the daily moot
  (§17); a monthly ladder if there is an audience; Act 2 tokens as chapters
  land; the standalone re-shell (§18) behind the graduation rule from
  `SPINOFF_GAMES.md` §6.

Art and audio needed (all small; the sprites are the point): seven tribe
emblems (64 px), six status glyphs (24 px), Named crown badge, level pips,
crest/scar glyphs, one 16:9 title plate, Carver Tove body + splash, three
board skins later; music = the existing capital track or one procedural
moot theme; a crowd murmur bed; hits and falls from `sfx.gd`.

Risks and the answer to each: balance rot (the bench, run before every
tuning commit); readability (numbers ≥ 20 px, glyph statuses, phone pass in
Gate B); twin sprites (chroma tints per token); stalls (caps + the no-stall
test); scope creep (v1 is exactly §7's list; new pieces come from new
chapters); the async ruling (open question 3); the moot becoming a farm (no
gold, Renown capped).

**Decided with the owner, 2026-08-17** (were the five open questions):
1. Fiction: a game of carved tokens; the pit stays off-screen. Decided.
2. Host: Carver Tove, a new named NPC (one body + splash). Decided.
3. Ghosts and friend codes: allowed. The async-PvP ruling in
   BORROWED_LOOPS §8 was about an AI steering a hero build in a raid; here
   nothing is steered, both warbands are static by the genre's design and
   the whole skill is the shop, so both players are fully tested, only not
   at the same moment. No server, no ranking, no raiding. Decided.
4. Length: 10 crests / 4 scars with two sparring turns; no "quick moot"
   in v1, add later if asked. Decided.
5. Demo: in the demo only if finished and fun before the demo date;
   otherwise held for launch. Decided, revisit at demo time.
6. Added by the owner: keep the moot a pure autobattler AND support a live
   showdown between two friends over a lobby code. **Owner ruling: live
   versus (§11, "version A") is the first pass and ships with v1.5.** The
   chess-like duel (§11 "Circle rules", "version B") is built only if
   players ask for it once live versus exists; if the demand is not there
   it stays a sketch and the time spent was the one `grid` field per
   ability row, nothing more.
7. Added by the owner: terrain as a gameplay factor (§17) and the standalone
   path (§18). Layer 1 grounds (announced ground + home-ground +1/+1 + the
   ring's look) and the `FangmootHost` seam are in v1; ground rules and the
   daily moot are v1.5; the standalone is a later re-shell behind the
   graduation rule.

---

## 17. Grounds: terrain as a factor (owner asked 2026-08-17)

The mock happened to sit on the enclave's grass; the owner asked whether
terrain could matter. It can, cheaply, and it is a natural fit: the world
already has 14 in-play terrains with authored floors (`ground_field_*.png`
for all 14), tints and ambient FX, and every monster already has a place it
spawns. Two layers, the first in v1:

**Layer 1 (v1): the ground is announced and home ground pays.** Every moot
is *called on a ground*, chosen by the table when the moot starts (seeded;
Copper always calls on Emberfall Village for the tutorial), shown in the top
bar ("called on the Frozen Expanse") and rendered as the ring's floor,
tint and ambient FX. Each token carries `home` (its primary spawn terrain
from the spawn tables; a token that spawns in several gets the first). A
token mustering on its home ground gets +1/+1 for the fight. That is one
field per token and one line in the sim, it is symmetric, it makes the
codex's "where it lives" matter, and it steers the shop from turn 1 ("ice
ground: the Still pieces are worth a little more this moot"). Named pieces
take the home of their chapter's finale terrain.

**Layer 2 (v1.5, behind the bench): one rule per ground.** Symmetric, one
line, using only existing keywords, mirroring what the terrain does in the
world (`terrains.gd` mechanics; align on build). First pass, all knobs:

| Ground | Rule |
|---|---|
| Emberfall Village | Fair ground: no rule (the tutorial ground). |
| The Darkwood | Ambush: the first strike of the fight deals double. |
| The Blightmarsh | Fester: every piece musters with Rot 1. |
| Vargoth's Keep | Hollow ground: the first piece to Fall on each side returns as a 1/1 Risen Corpse. |
| Scorched Wastes | Cinders: both fronts are Burning at Muster. |
| Frozen Expanse | Rime: both fronts are Frozen at Muster. |
| Restless Graveyard | Compost: the ally behind any Fallen piece gains +1/+1. |
| Scorching Dunes | Glare: Frost has no effect; Burn deals 3 instead of 2. |
| Poison Bog | Mire: summons arrive with Rot 1; Thorns deal +1. |
| Crystal Caverns | Facets: every piece musters with Ward. |
| Thunder Plains | Conduction: every strike also deals 1 to the piece behind the target. |
| The Void | Null: both fronts are Silenced. |
| Sanctified Ruins | Sanctuary: both fronts are Preserved. |
| Spore Glade | Bloom: summons arrive with +2/+2. |

Rules stay symmetric so the ground never favours the player or the bot; they
favour *tribes and plans*, which is the point. In live versus the two callers
alternate ground picks per moot (map-veto style); in solo the table calls
it. NPC callers get home grounds (Ilse: Restless Graveyard; Petra: Scorched
Wastes; Kesh: Spore Glade; Ilya: Thunder Plains; Callis: Vargoth's Keep;
Fenna: Sanctified Ruins; Dov: Poison Bog; Haim: The Blightmarsh; Ottar: The
Darkwood; Tove: any).

Costs: Layer 1 ≈ two days (field, sim line, floor swap, top-bar text, bench
rotates grounds). Layer 2 ≈ one week plus bench time, because 14 rules
multiply the balance surface; ship them one at a time as the bench clears
them, Village and Darkwood first. The 22 placeholder-terrain floors
(`ground_room_*`, the codex Future tab) are grounds-in-waiting for Act 2.

Also cheap and worth doing at Layer 1: **the daily moot.** One seed per
trusted-clock day for everyone (ground, tray sequence, opponents), so two
players can compare crests on the same day's moot; a share string
(`FM-DAILY-<date>-<crests>`) costs nothing and needs no server. It is the
Wordle-shaped loop from `SPINOFF_GAMES.md` §2, and it works identically in
the standalone.

---

## 18. The standalone path (owner asked 2026-08-17: "is it feasible?")

Yes. `SPINOFF_GAMES.md` §6 already defines the graduation rule (a clear
share of session time for a month AND players asking for it outside the
game). What this section adds is how to build v1 so graduation is a
re-shell, not a rewrite, and what the standalone would actually need.

**The seam (build it this way in Phase 1; it costs nothing).** Everything
Fangmoot needs from Crownless goes through one small interface,
`FangmootHost`, and nothing in `game/scripts/fangmoot/` touches
`game_base`, `save.gd` or Renown directly:

- `fieldable(kind) -> bool` and `mastered(kind) -> bool` (Crownless:
  `kill_counts`; standalone: its own unlock ladder)
- `portrait(kind) -> Texture2D` and `clip(kind, action)` (both: `Art`,
  which the standalone ships a copy of)
- `reward(event, amount)` (Crownless: `add_renown` + titles; standalone: its
  own wallet)
- `save(dict)` / `load() -> dict` (Crownless: the `fangmoot` key in
  `save.gd`; standalone: its own file)
- `share_string(dict)` / `import_string(s)` (identical in both)

The sim, data, bot, codes, tray UI, arena renderer, hub screen, callers,
grounds and daily moot are then shared unchanged. The seam is also what
keeps the in-game version testable headless.

**What the standalone would need on top (≈ 4-6 weeks after in-game v1):**
- A shell: main menu, settings, its own save, onboarding without a
  campaign.
- A replacement for "field what you have faced": pieces unlock by
  *playing*. Proposed: **Hunts**, short PvE ladders themed by ground (five
  bot warbands on the Frozen Expanse unlock the Still pieces you beat there),
  so the moot itself becomes the way you catalogue. The codex-as-collection
  idea survives; only the source of the ledger changes.
- An online ghost store for "beat other players' teams" (a tiny bucket:
  upload warband JSON keyed by turn, fetch N; ≈ one week) plus the daily
  moot leaderboard on the same bucket. Not strictly required (codes and the
  daily seed already work offline) but it is what makes a free version
  spread.
- Store assets: capsule, trailer, screenshots (the ring on 14 grounds
  photographs well), a title plate.
- Monetisation inside the rules already set: free to play; cosmetics only
  (board skins, gildings, an echo-pet line); never power. Whether new
  tribes are sold as expansion packs (content, Super Auto Pets' model) is
  an owner ruling to take then, not now.
- Cross-promotion both ways: a "wishlist Crownless" card at the end of a
  moot; later an account link so a Fangmoot Champion carries a title into
  Crownless.

**How it plays as a standalone (owner asked 2026-08-17: "are all the mobs
unlocked?").** Not all at once, and not gated behind a grind either. The
in-game rule "field what you have faced" becomes the standalone's whole
progression spine:

- **First launch:** Tove's two-turn tutorial, then a moot at Copper with
  the Carver's stock (the 17 Tier 1-2 pieces, all available from minute
  one, so the first moot is a full game, not a demo of one).
- **The Hunts (the campaign):** a map of the 14 grounds. Each ground is a
  short ladder of five bot warbands built from that ground's tribes,
  ending in that ground's caller (Petra on the Scorched Wastes, Ilse on
  the Restless Graveyard...). Beating a warband catalogues the pieces you
  faced in it; beating the ground's caller unlocks the ground's Named piece
  and its lore page. A ground is 15-20 minutes; the full roster is about
  four to five hours of play, spread across a week if you like. This is
  the standalone's world tour of Crownless (every ground is a chapter's
  terrain, every lore page a chapter's premise), and it is where the
  cross-promotion lives naturally.
- **The Moot (the endless mode):** solo ladders at Copper/Silver/Gold
  against bots and ghosts, using your collection. This is where the
  in-game version and the standalone are the same game.
- **The daily moot and versus use the full roster for everyone**, so a
  daily comparison and a friend showdown are always fair regardless of how
  far anyone's Hunts have gone. Unlocks shape your solo collection; they
  never decide a head-to-head.
- **Rules that hold:** unlocks are earned only, never sold (power);
  cosmetics are the only purchases; nothing in a Hunt is a grind wall (five
  fights, no repeats required, a lost fight can be retried immediately).

Why not just unlock everything on day one, as Super Auto Pets does? Because
the collection itch is the one hook this game has that SAP does not, it is
what makes the standalone feel like Crownless rather than a reskin, and the
Hunts give a solo player something to *finish*. The fairness objection is
answered by the daily/versus split above.

**Assets and rights:** everything the moot renders is ours; the standalone
pulls sprites from `game/assets` by manifest at build time (`game/` stays
the source of truth, no forked copies) and carries `CREDITS.txt` for the
few CC-BY pieces.

**The honest caveat, restated from `SPINOFF_GAMES.md` §2.1-2.2:** the
standalone is the visibility bet in a thin genre, and free + short + codes
+ daily seed is the shape that has worked there. The in-game version is how
we find out whether people love it before spending the six weeks.
