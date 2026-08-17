# Spin-off games from the Crownless asset library (2026-08-16)

Owner ask: look through the visual assets and propose a SECOND game built
mostly by reusing them. Bar: fun, well designed, real viral potential; ideally
it opens new corners of Crownless lore; new art is allowed where it makes the
new game feel like its own thing.

This doc is the proposal. It has three parts: what we actually have (§1), the
concepts ranked with complexity (§2 to §4), and a recommendation with a build
sequence (§5), the multi-genre-inside-Crownless route (§6), and canon
guardrails for any spin-off writing (§7).
`STORY_BIBLE.md` (webnovel/, local-only) stays the lore SoT; `DESIGN.md` stays
the main-game SoT. Nothing here changes either.

---

## 1. What we have to work with (measured 2026-08-16)

`game/assets/sprites/` = 3,724 PNGs, ~1,090 distinct sprite bases;
`game/assets/icons/` = 4,467 PNGs. Style: dark-fantasy pixel art for
everything that moves, painted illustration for portraits/plates/cover. All
top-down, feet-anchored, 8-direction.

| Pool | Count | State | Reuse verdict |
|---|---|---|---|
| Hero looks | **24** (6 classes × base + Elite + Mythic + Mythic-awakened) | idle/walk/run/dash/attack/attackb/attack2/cast/ult/ultidle/death, all 8 dirs, ~190 px source | The single richest pool. Any top-down or grid game gets a 24-character roster for free. |
| Bosses | **21** (Act 1 roster + 3 designed-not-built bodies: Korrag Reborn, Burned King's Echo, Saint Varo standing) | idle + walk + 2-4 ability strips each, per-boss FX (`fx_boss_*`, `<boss>_bolt/slam/ring`), portrait | Boss fights or "raid" units in any genre. |
| Mobs | **~100** distinct | ~60 are 8-dir + attack + death + walk (192-386 px masters); ~40 are legacy 16/32 px pack sprites (cyclops, medusa, kraken, tengu, ooze...) | The 60 regenerated ones are portfolio quality and cover every biome (blight, fire, ice, root, storm/void, undead, beast, human). The legacy 40 read as a different game; leave them out. |
| Named NPCs | **~70** with 8-dir sets + ~10 legacy 32 px | 256 px masters | Card faces, shopkeepers, quest givers, advisors. |
| Portraits | **238** `splash_*` + 12 `class_splash_*` at 1254×1254 | painted, consistent palette | Card art, dialogue busts, store capsules. Enough for a whole card game with zero new art. |
| Opening plates | 21 (3 per class + 3 crown) at 16:9; 2 covers at 2560×1440 | painted | Cutscene / storybook plates via `cutscene.gd`. |
| Terrain | 22 `ground_room_*` full-room surfaces, 12 wall sets, 4 tile floors, ~25 trees, ~35 rocks/plants/mushrooms, graves, crops, camp/forge/library/hideout/sewer furniture, 26 capital buildings, 4 crafting stations × 3 tiers | mixed sizes | Any top-down map. The capital set alone is a city-builder's starter kit. |
| Gear icons | **1,260** codex icons (7 slots × 6 classes × grade variants) at 128 px + 420 unique-item icons + ~150 `rv_*` armory/food/potion/material pack icons | painted, uniform framing | Cards, shop tiles, inventory grids. |
| Gems / consumables / materials | 150 gem icons (14 stat families in `Items.GEM_STATS` × 10 grades, plus spares), 92 consumables, 35 materials | pixel, 32-64 px | Merge games, socketing, crafting. |
| Ability / talent icons | 96 + 72 at 64 px | painted rings | Level-up choice tiles, autobattler ability badges. |
| FX | 52 strips in `fx/` + ~40 flat FX + hazard strips (192 px cells) | pixel | Any action game. |
| Audio | 37 music, 49 sfx files + a fully procedural `music.gd`/`sfx.gd` fallback | | Zero audio needed for a prototype. |

Reusable code (all Godot 4.4.1): the six class kits and `enemy.gd`/`boss.gd`
AI, `art.gd`'s PNG-override loader (drop a PNG by name and it works), the
cutscene plate player, save system, netcode (ENet, 2-4 players, NAT punch),
the intent-based input layer with touch HUD, and the mobile export pipeline
(GH Actions signed APK + iOS ipa). A spin-off in Godot inherits all of it.

Licensing: everything we generated is ours. Third-party CC-BY pieces
(`assets/*/CREDITS.txt`) carry their attribution file into the new game;
verify per pack before shipping. Nothing here is share-alike or NC.

---

## 2. What "viral" actually needs (the filter every concept below is judged by)

1. **A share loop built into the game**, not bolted on: an async "beat my
   X", a daily seed with a share string, or an end-of-run card people post.
2. **Sessions under 15 minutes** and a first run that teaches itself in 30
   seconds. Streamers and phones both punish anything slower.
3. **Screen chaos or screen drama** that clips well: hordes and FX, or a
   shop roll that makes a streamer shout.
4. **Personality**: a look people recognise in a thumbnail. Our dark
   painted-pixel look is distinctive; the Halls of Torment lane proved that
   exact aesthetic sells at scale (over 1M copies).
5. **Cheap to try**: free or under $5, or a free tier on mobile.

Constraints from our side: solo owner + parallel agents, no appetite for a
live server beyond something tiny (see `social-layer` rulings), never sell
power, and the main game's marketing plan (`MARKET_STRATEGY.md`) already
wants a demo + Next Fest + wishlist funnel; a spin-off is worth most if it
FEEDS that funnel (cross-unlock a cosmetic in Crownless, see §5).

### 2.1 Market reality check (owner asked "are autobattlers really that popular?", 2026-08-16)

Checked, not remembered:

- **Autobattlers are a boom-bust niche with a few outliers.** The 2019 wave
  (Auto Chess, Dota Underlords, TFT) collapsed except Riot's TFT. Steam
  concurrents in Aug 2026: Mechabellum ~1k, Dota Underlords ~500, The
  Bazaar ~5k average and shrinking after its monetization blow-up. The two
  indie hits: Backpack Battles (640k copies in month one, 36.5k peak CCU,
  15th biggest Steam launch of 2024; hook = inventory tetris) and Super
  Auto Pets (blew up when Northernlion and Ludwig streamed it). Two or three
  hits in five years, each on a twist or streamer luck.
- **Survivors-likes are a far bigger, still-live market, in our exact art
  lane.** Megabonk: 1M copies in two weeks (Sept 2025), out-drew Borderlands
  4 on daily players. Halls of Torment (the Diablo-look one): 1M+ and console
  ports. Vampire Survivors and Brotato in the millions. Many more entrants
  than autobattlers, but the ceiling and the number of hits are an order of
  magnitude higher, and streamers still pick them up.

Consequence: the first draft of this doc ranked Fangmoot #1 on asset fit and
low competition. Weighted by market size and precedent, the survivors-like
is the better viral bet; Fangmoot stays as the mobile-first, lower-
competition alternative whose upside depends on a twist. §5 reflects this.
Sources: gameworldobserver.com (Backpack Battles 2024-04-25),
newsletter.gamediscover.co (Backpack Battles), wasdland.com auto-battler
popularity Aug 2026, pcgamer.com (Megabonk 2025-10; The Bazaar 2025),
tweaktown.com (Halls of Torment 1M).

### 2.2 Competition (owner asked, 2026-08-17)

**Survivors-like.** Hundreds on Steam; Steam gave "Bullet Heaven" its own
tag on 2026-05-18 and the 2026 release calendar is the genre's busiest ever
(choostgames.com 2026 roundup). The "made it" bucket is small: 10
action-roguelikes earned 1,000+ reviews in 2022, 17 in 2023
(howtomarketagame.com Q2 2024). Read that as 15-25 real successes a year
against hundreds of releases; the median release sells a few thousand
copies (estimate, not sourced). What the winners had, every time: a hook
you can say in five words (Megabonk = 3D + sword-surfing + memes; Halls of
Torment = Diablo look + real bosses + gear; Brotato = potato + 40 characters
+ 20-wave runs; 20 Minutes Till Dawn = aiming; Deep Rock Survivor = IP), a
week-one streamer pickup, feel in the first 30 seconds, a $5-10 price, and
a demo before launch. Our specific problem: the Diablo-look lane already
has an incumbent (HoT, 1M+, console ports). "HoT but ours" is not a hook.
The hooks that ARE ours: the virtue/temptation pick (a moral mechanic in a
horde game is new), "hold until the Concord is signed" as the run frame, 24
heroes with real 8-dir animation and a real ultimate each, painted bosses
with kits. On mobile the incumbent is Survivor.io (Habby, nine-figure
revenue, ad-funded); do not plan to win mobile head-on with this genre.

**Autobattler.** Fewer competitors but the incumbents are free: TFT (Riot),
Super Auto Pets (free), The Bazaar (F2P), plus Backpack Battles at $. A
paid indie autobattler competes with free games in a small genre. The
hook has to be structural (Backpack Battles' inventory tetris was).

**Reign cards.** Reigns (Nerial/Devolver) owns the shape and there are
dozens of small imitators; tiny market, tiny cost, so competition matters
less than writing quality.

**The base-rate lesson.** In every genre the median outcome is "a few
thousand copies". So pick the option whose DOWNSIDE still helps Crownless:
shared assets, shared code, shared lore, and a wishlist funnel. That is the
argument for §6 (build the genre inside Crownless first).

---

## 3. The concepts (in the order first drafted; the ranking after the §2.1 market check is in §5)

Complexity scale used below: **S** = 1-3 weeks to a shippable toy,
**M** = 6-10 weeks to a Steam/mobile demo and 4-5 months to 1.0,
**L** = 10-12 weeks to a demo and 6-9 months to 1.0. Estimates assume the
owner + agents at the current cadence, Godot, and heavy asset reuse.

### 3.1 FANGMOOT: async monster autobattler (lower-competition alternative; see §2.1)

**Pitch.** Super Auto Pets / Backpack Battles shape, but your team is the
Crownless bestiary. Buy monsters from a rolling shop, line up five, socket
gems into them, hit Fight; the fight resolves itself against another
player's saved warband. Win 10 before you lose 3.

**Loop (one run = 10-15 min).** Shop phase: 3 gold buys a unit or a gem,
1 gold rerolls, three copies of a unit merge into a stronger one (uses the
higher-grade gem icons as the level badge). Fight phase: front unit hits
front unit, on-hit/on-death/on-summon triggers fire. Between fights the
opponent is a *ghost*: a warband some real player saved at the same wins/
losses count. No live matchmaking, no realtime netcode.

**Why it fits our assets better than anything else.** The 60 regenerated
mobs already have idle + attack + death + walk in 8 directions and read
beautifully at board scale (192-386 px masters). Every one already has a
codex identity AND a death-trigger trait in `enemy.gd` (bloat, martyr,
tether, summon-on-death) which is literally the SAP trigger vocabulary. The
21 bosses become the PvE "gauntlet" ladder and the rare shop units. Gems
(150 icons, 10 grades) are the item layer. Ability icons (96) are the
trigger badges. NPCs are the shopkeepers. Zero new units required for v1.

**Faction identity (the design spine).** Six tribes, each a synergy:
Choir/blight (rot stacks, martyr on death), Molten (burn, forge buffs on
adjacent), Still/ice (freeze, preservation: units revive once), Root
(summon spiderlings, growth: +stats per turn), Storm/void (chain, riftlings
that split), Hollow (Vargoth's dead: hollow knights, oathbound, sleepwalkers;
gain stats from allies dying). Beasts (wolves, hounds, aurochs) are the
neutral pack tribe. That is the god-king pantheon rendered as a meta, and
it teaches the world's cosmology to people who have never played Crownless.

**Lore reveal.** Framed as *the Waking* (Ch2's premise: the map tearing
open and every biome's things spilling together). You play a moot-caller
binding waking things into a warband. Between ladders, a short storybook
(cutscene.gd plates + portraits) tells the Wildfang side: the Fangmoot
circle, the split between cure-camp and acceptance-camp, and it can
FORESHADOW (not spend) the Moonfen and "beast-blood was the Root's first
cure". Coordinate with the bible so this doesn't fire the main game's guns.

**Viral mechanics.** Async ghost fights are the SAP engine of virality:
"my warband went 10-0" screenshots, share codes for a warband, and a weekly
seeded ladder where everyone faces the same shop sequence (a shared-seed
week is a share string by itself). Rounds are 60-90 seconds and the shop
roll is streamer drama. Free on mobile, $5 on Steam, or free everywhere and
funnel to Crownless.

**New art worth making.** A board frame + shop tray + tribe emblems (6),
"pedestal" ring under units, level-badge overlays, one title plate. Maybe
10-15 gap units so each tribe reaches ~12 members (Molten and Still are the
thinnest). ImageGen for the UI, our mob pipeline for units. Roughly 2-3
weeks of art across the whole project.

**Complexity: M.** Prototype (local vs bot warbands, 30 units, 1 tribe): 2
weeks. Demo (60 units, 6 tribes, gems, PvE boss gauntlet, offline ghosts):
6-8 weeks. 1.0 with async ladder + mobile: 4-5 months. The hard parts are
(a) balance, this genre lives or dies on unit design and the owner would
tune it at his own skill like everything else, and (b) the ghost store: a
tiny HTTPS bucket (upload warband JSON, fetch N by rank) or Steam
leaderboards' attachment slot. Start with shipped bot warbands and add the
async store when there is an audience. No realtime multiplayer at all.

**Risks.** Balance rot (needs a bench like `dps_bench`); readability at 5v5
scale needs strong silhouettes (we have them); SAP's shadow (must feel like
its own thing: gems + tribes + bosses do that).

### 3.2 THE WAR OF CINDERS: survivors-like (recommended flagship: biggest live market, most code reuse, most lore)

**Pitch.** Halls of Torment / Vampire Survivors shape in our exact art lane:
one hero, one stick, thousands of enemies, level-up picks, 20-minute runs.
Set 600 years before Crownless, during the war the Concord ended. Canon
says that war ended by *binding*, not victory, so a run does not end by
killing everything: you **hold until the Concord is signed** (the survive-N-
minutes format, made thematically true), and the last two minutes bring a
god-king's herald as the finale boss.

**Loop.** Pick one of 24 hero looks (the six kits × skins as unlockables,
the survivors staple "24 characters to unlock" is free here). Auto-attack,
choose 1 of 3 upgrades on level-up (ability icons + gear icons as tiles),
weapon evolutions from the 1,260 gear icons and the S-grade uniques.
Resonance is the twist: every level-up offers a **virtue pick or a
temptation pick** (the temptation is bigger now, taxes you later); a run's
end card shows how tempted you ran. Bosses (21 existing) arrive on a clock.

**Lore reveal.** The most lore-rich option: the war itself is unplayed, the
six founders of the Ember Guard (six graves, five bodies), the Erased, the
drafting of the Concord. Between-run "Chronicle" plates unlock per hero and
per minute-survived; the founder framing gives every class an origin story
without touching Act 1-3 beats. Keep the god-kings off-screen (heralds and
casualties only, per canon); their *domains* are the map biomes.

**Viral mechanics.** Clip-able chaos (this genre is the most streamed
roguelite shape of the decade), 24 heroes, daily seed with a share string,
end-of-run card. Steam demo + Next Fest is exactly the funnel the market doc
already wants. Mobile-portable with the intent input layer.

**New art worth making.** Six "First Guard" founder skins if the owner wants
the era to look its own (or reuse Mythic looks as "aspects", zero art). Two
or three big open arenas built from `ground_room_*` + walls (the room
builder does this). One title plate. Chronicle plates (ImageGen 16:9, same
style as `opening_*`), maybe 12-18. Weapon-evolution icons exist.

**Complexity: M+ (leans L for the engine).** Reuse of kits, enemy AI, FX,
HUD and mobile input is enormous, BUT the current enemy is a full Area2D
node; a survivors-like needs 500-2,000 live enemies, so enemies must be
rewritten data-oriented (arrays + MultiMesh or a Server-API path, one
collision query per hero attack, no per-enemy nodes). That rewrite is the
real cost: 3-4 weeks of engineering before it feels right. Prototype 3
weeks; demo (4 heroes, 2 maps, 6 bosses, 40 upgrades) 8-10 weeks; 1.0
5-7 months.

**Risks.** Saturated genre (1,400+ roguelike releases in 2026 per the market
doc); differentiation must come from bosses with real kits, the temptation
pick, and the look. Feel must be nailed (juice code exists in
`player_combat`). Co-op survivors on ENet is a stretch goal, not v1.

### 3.3 THE HOLLOW THRONE: swipe-decision reign game (cheapest, best lore per hour)

**Pitch.** Reigns shape: you are the regent of the old capital sixty years
before Crownless. Cards are people (our 238 portraits), swipe left or right,
four meters move, every reign ends and the throne empties. Canon fixes the
OUTCOME (the city burns, the throne is emptied) but not the HOW, so the game
is free to invent the court while never contradicting the bible.

**Loop.** 3-5 minute reigns, hundreds of cards, chains that persist across
reigns (an advisor's daughter returns in the next reign), a hidden fifth
meter (Resonance: how you relate to the Crown's wanting) that picks which of
6-8 endings you get. Meters: Court (the nobles who become the Cinderborn),
Hearth (the people who become the Accord), Choir (blight petitioners), Wild
(Wildfang envoys). Endings all empty the throne; what differs is why, and
one ending shows the sixth-seal masonry without explaining it.

**Lore reveal.** Very high and safe: the burning of the capital is
"referenced constantly, never played". Portraits of Maren, Aldric, Petra,
Fenna as young people or as their parents. Foreshadows the Undercroft.

**Viral mechanics.** Reigns sold millions on mobile; the swipe format is
TikTok-native; the end-of-reign card ("Regent Ilse, 14 years, ended by fire,
tempted 62%") is the share unit. Free with one $3 unlock, or free forever as
a Crownless prologue.

**New art.** A card frame, a throne-room backdrop, 6-8 ending plates, and
30-50 new era-specific portraits (ImageGen in the splash style, the pipeline
exists). Portrait crops of the existing 238 cover the rest.

**Complexity: S for engine, M for content.** Engine 1-2 weeks (it is a card
stack, four bars, a save file). The work is WRITING 400-600 cards in canon
voice with the bible's guardrails (no game vocabulary, Choir never a joke,
god-kings unnamed). Demo 3-4 weeks; 1.0 in 2-3 months, mostly text.

**Risks.** Lower ceiling than 3.1/3.2; less streamable; lives on writing
quality.

### 3.4 THE HONOR GUARD: grid-tactics roguelike (best lore, highest design load)

Into the Breach shape: three heroes on an 8×8 grid, enemies telegraph
next turn, perfect information, 20-minute runs. Set in the Ossuary: the
five revenant founders as the run's bosses, your own class's founder yields
(the Interlude I4 idea, which is main-game content; a spin-off would need
the bible to release it or invent a parallel tomb). Assets fit perfectly
(8-dir heroes on tiles, bosses as end-of-run). Viral shape is weak
(tactics games earn reviews, not clips). **Complexity L**: the design is
the product and it does not reuse the action combat code. Keep as a
future option, not a first pick.

### 3.5 CROWNFALL RISING: idle city rebuild (mobile retention, low virality)

Rebuild Crownfall in the sixty-year gap after the burning: 26 capital
buildings, NPCs returning one by one, expeditions send hero looks into the
old chapters and return with materials (the 35 material icons + gems).
Strong mobile retention shape, weak share loop. Lore medium (the gap years).
**Complexity M-** (5-6 weeks demo; the tuning is spreadsheets). Best as a
later companion once Crownless has an audience to retain.

### 3.6 HOLD THE VALE: tower defense

Kingdom Rush shape: mobs walk the Unburied Vale's roads (walk cycles exist),
heroes are the towers, bosses are wave finales. Assets fit; genre is
evergreen but not viral; complexity M. Not a first pick.

### 3.7 LAPIDARY: gem-merge physics toy (marketing toy)

Suika Game shape: drop gems, same grade + same family merge into the next
grade; 14 families × 10 grades are already drawn. Trivially cheap
(**S, 1-2 weeks**), genuinely viral-shaped (Suika went everywhere in 2023),
zero lore. Worth building only as a free web/mobile toy that ends every run
on a "wishlist Crownless" card. Do not confuse it with "the new game".

### 3.8 CROWNLESS-DLE: daily codex guessing (post-launch companion)

Wordle/Loldle shape: guess today's monster from progressively revealed codex
fields, share an emoji grid. **S**, one static page. Needs an audience that
already knows the bestiary, so it is a post-launch tool, not a spin-off.

---

## 4. Side-by-side

| # | Concept | Viral shape | Lore reveal | Asset reuse | New art | Server needed | Mobile fit | Complexity |
|---|---|---|---|---|---|---|---|---|
| 3.1 | Fangmoot (autobattler) | HIGH: async ghosts, share codes, weekly seed | Medium (Waking, Wildfang, pantheon-as-tribes) | Mobs, bosses, gems, ability icons, NPCs, portraits | UI frame, 6 emblems, ~15 gap units | Tiny bucket, later; bots first | Native | **M** |
| 3.2 | War of Cinders (survivors) | HIGH: clips, 24 heroes, daily seed | HIGH (the war, founders, the Erased) | Kits, enemy/boss AI, FX, HUD, mobs, bosses, gear icons | 6 founder skins optional, 2-3 arenas, chronicle plates | None | Good | **M+ / L** (enemy rewrite) |
| 3.3 | Hollow Throne (reign cards) | MEDIUM: end-of-reign card, swipe format | VERY HIGH (the burning, the court) | 238 portraits, plates, cutscene player | Card frame, backdrop, 30-50 portraits, endings | None | Native | **S engine / M writing** |
| 3.4 | Honor Guard (tactics) | LOW-MED | VERY HIGH | Heroes, bosses, tiles | Grid UI | None | OK | **L** |
| 3.5 | Crownfall Rising (idle) | LOW-MED | Medium | Capital set, NPCs, materials | Progress UI | None | Native | **M-** |
| 3.6 | Hold the Vale (TD) | LOW-MED | Low | Mobs, heroes, terrain | Path/tower UI | None | Good | **M** |
| 3.7 | Lapidary (merge toy) | MED-HIGH, fleeting | None | Gems | Bowl + frame | None | Native | **S** |
| 3.8 | Crownless-dle | MED (post-launch only) | None | Codex data | None | Static page | Web | **S** |

---

## 5. Recommendation and sequence

**Flagship: 3.2 War of Cinders (survivors-like).** Revised after the §2.1
check. It is the biggest live market that fits our assets, its precedent
(Halls of Torment) is in our exact art lane, it inherits the most code
(kits, `enemy.gd`/`boss.gd`, FX, HUD, mobile input), and it carries the most
lore (the war, the six founders, the Erased). Its differentiators against
the crowd are real and already drawn: 24 fully animated heroes, 21 bosses
with actual kits, painted portraits, and the virtue/temptation pick at
level-up. Its tax is the data-oriented enemy rewrite, so that is the first
thing to prove.

**Alternative: 3.1 Fangmoot** if the owner wants mobile-first, async, and a
less crowded field, accepting that autobattler virality has depended on a
twist (Backpack Battles) or streamer luck (Super Auto Pets) and the genre's
tail is thin. Our twist would be gems + tribes + bosses; whether that is
enough is a bet.

**Cheap lore vehicle: 3.3 Hollow Throne** can be built by a writing-heavy
agent lane in parallel with either flagship and shipped free as a prologue.
It costs almost no engineering and it is the best way to put the burning of
the capital on a screen.

Suggested sequence:
1. Three-week War of Cinders prototype in a fresh Godot project that pulls
   sprites by name from `game/assets/` (no copy; a manifest of what it uses
   so the final build ships only what it needs). Scope: one hero, one arena,
   500+ live enemies at 60 fps on the owner's machine AND a mid phone, three
   upgrades, one boss on a clock. Gate: the enemy rewrite holds frame rate,
   and after ten runs the owner wants an eleventh.
2. If yes: 8-10 week demo (4 heroes, 2 maps, 6 bosses, 40 upgrades, daily
   seed, end-of-run card). Steam page + Next Fest. If the enemy rewrite is
   the blocker or the feel is not there, run the same gate on a 2-week
   Fangmoot prototype (30 units, 1 tribe, bot warbands).
3. Hollow Throne runs as a side lane whenever a writing agent is free; its
   engine is a week.
4. Cross-unlock: finishing the spin-off's ladder/prologue grants an
   interface-prestige reward in Crownless (a title or codex border, earned
   only, per the cosmetic rule) and an **echo pet** later when pets exist.
   Never power. The spin-off ends every session on a wishlist card.
5. Lapidary and Crownless-dle only after there is an audience to point at.

Repo shape: a sibling repo (like `Projects\Autonomy`), not a folder in
this one; import assets by manifest with the same CREDITS.txt policy; keep
`game/` the source of truth for any sprite that both games use.

---

## 6. The multi-genre route: build the genres INSIDE Crownless first (owner's idea, 2026-08-17)

Owner asked whether Crownless itself could offer gameplay from multiple
genres. Yes, and there is a precedent that answers the whole thread:
**Gwent.** It was a tavern minigame inside The Witcher 3, players loved it
more than CD Projekt expected, and it became a standalone game (and
Thronebreaker). Final Fantasy VII Rebirth's Queen's Blood did the same
thing on a smaller scale. Multi-genre single games work when every mode
shares ONE hero, ONE save and ONE progression, and each mode feeds the
others (Dave the Diver: dive + restaurant; Cult of the Lamb: roguelite +
base; Stardew: farm + mine + fight + fish; Yakuza's minigames as identity).
They fail when a mode is padding (the "minigame tax") or half-baked.

Why this beats a standalone spin-off first:
- **It answers §2.2.** Nobody competes with "the ARPG whose tavern game is a
  monster autobattler". Steam multi-tag discovery, and the downside of a
  weak mode is a weak mode, not a dead SKU.
- **It de-risks the spin-off decision.** Ship one mode, watch play-time
  share; the mode players actually live in is the one that graduates to a
  standalone with a shared unlock. Gwent's route exactly.
- **It serves the retention metric** `MARKET_STRATEGY.md` says matters
  ("do players say let's play again"), and the dynamic-world proposal's
  complaint that there is not enough to DO in the world.
- **The assets are already loaded.** No sibling repo, no manifest, no
  double CREDITS.

The mapping (each mode = a Crownfall place; each optional; each pays the
SAME earned economy: gold buys depth, Renown and cosmetics, never power):

| Mode | Where | The Crownless-only hook | Cost |
|---|---|---|---|
| **Fangmoot** (autobattler tavern game) | Ashen Tankard / Fangmoot Circle (building exists) | You can only field monsters you have CATALOGUED in the codex: kills and entries unlock units, so the bestiary becomes a collection you carry around the world (the Gwent/Pokemon hook), and the codex stops going stale silently because players need it. Opponents = named NPC moot-callers with signature warbands; wager gold; friend challenge via the existing lobby code = PvP with zero server. | 4-6 wk (UI, sim, ~40 units from codex traits, 8 NPC decks, wagers) |
| **The Tide** (horde / survivors mode) | An Incursion or Depths variant, one arena | Same hero, same kit, but auto-attack + run-local level-up picks + the temptation pick + a 20-minute hold with a boss on a clock. Rewards on the Incursion tables (free for everyone, per the monetization ruling). | 6-8 wk (data-oriented enemy rewrite 3-4 wk, which also buys main-game perf headroom; mode 3-4 wk) |
| **The Regent's Ledger** (reign cards) | Codex Field notes / Story Theatre (WANTED already) | Swipe through the last regent's reign sixty years ago; each ending unlocks a lore page; portraits are the cards. Optional, replayable, choices never saved (Story Theatre's rule). | 2-3 wk engine + first 150 cards |
| Ward-contract defense, lapidary merge, expedition idle | Capital desk / lapidary NPC / professions | Small; the dynamic-world proposal already lists pet minigames. | 1-3 wk each, later |

Rules so it does not become a mess:
1. One mode at a time, each behind the same gate as everything else: after
   ten runs the owner wants an eleventh.
2. A mode teaches itself in 30 seconds or it does not ship.
3. Never market Crownless as "five games in one" (the "never call it an
   MMO" ruling has the same root: promise one thing). Market the ARPG; let
   the tavern game be the discovered delight, the way Gwent was. A demo
   that hides a good tavern game gets talked about.
4. Modes never grant power; they grant depth, Renown, cosmetics,
   keepsakes, lore.
5. Sequence after the core loop's demo gate (`MARKET_STRATEGY.md` risk #3:
   do not build a live-service feature set before strangers enjoy the core
   loop), unless the owner wants the tavern game IN the demo as the
   surprise.

Recommended first mode: **Fangmoot in the tavern**, because it is the
cheapest, it makes the codex matter, it needs no engine rewrite, and it is
the one whose standalone graduation (§3.1) is otherwise the hardest to
justify on market size. The Tide second, because its enemy rewrite is
useful even if the mode is cut. The Ledger whenever a writing lane is free.

**Owner decision 2026-08-17: build Fangmoot.** Its full design is
`PROPOSALS/FANGMOOT.md` (rules, the 60-piece v1 set, callers, rewards,
architecture, tests, build plan); that doc is the SoT for the minigame and
this section does not repeat it.

Spin-off graduation rule: a mode graduates to a standalone (§3) when it
holds a clear share of session time for a month AND players ask for it
outside the game (Discord/Steam threads). Until then, no sibling repo.

---

## 7. Canon guardrails for any spin-off writing (from the bible; do not relitigate)

- Never print a god-king's true name; the four kept gods are never fought as
  bosses; heralds and casualties only.
- Mórwyn (goddess) is not Morwen (the cultist who took her name).
- Aldric is never playable and never gets a sword fight.
- The Hollow Choir is never a joke.
- No game vocabulary in fiction ("lean/steady/tempted", never "resonance").
- Do not fire the main game's held guns: the sixth-seal reveal, the taken
  Storm Tongue name, the Erased's true act, the Moonfen. Foreshadow only.
- Class gender canon holds (mage F, archer F, paladin/warlock/warrior M,
  assassin neutral); no dedicated healer; no rim glows on heroes.
