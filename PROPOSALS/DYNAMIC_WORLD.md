# Dynamic World — situations, not choices (2026-08-17)

Owner complaint, verbatim in spirit: *a lot of quests are flat — make a
choice and that's it, no consequences or real action. Some are solid (the
lost hat). The world should feel dynamic: bandits on the road, a hidden
boss you stumble on, a portal stone into a mini-dungeon that hands you
back to the chapter, easter eggs, and one day a pet that makes you beat it
at tic-tac-toe before it follows you.*

Nothing here is installed; decision document. Sibling docs it builds on
(and does not repeat): QUESTS_AND_SIDE_CHAPTERS.md (ch2 slate / capital
chains / Interludes), DAILY_DUNGEONS.md (the Seal Vigils — capital-entered
daily dungeons), BORROWED_LOOPS.md (§5 minigame-for-Renown, §6 "the door
is always open, the bank pays once"), MONETIZATION_SPLIT.md (pets are a
paid cosmetic category), DESIGN.md room palette + reward doctrine.
The XP half of "why revisit a chapter" (replays pay zero XP today) is
its own doc: REPLAY_XP.md.

---

## 0. The complaint, measured

Audit of every quest and every source of run-to-run variance (2026-08-17;
pointers are `game/scripts/...`).

**Side quests (24 total, `SIDE_QUESTS` across `content/ch*_quests.gd`,
`promises_kept.gd`, `story.gd:1441`):**

| Shape | Count | Meaning |
|---|---|---|
| Courier — take at A, walk, hand over at B | 16 | both ends are a dialogue line |
| Pilgrimage — press E at 3+ props | 5 | walk-and-press |
| Flat — accept, one prop press, done | 2 | `ch3_bread_kneeling`, `ch3_sexton_stone` |
| Combat | 1 | `ch4_nine_names` (a boss room's `clear_flag`) |

- 13 of 24 have **no branch at all**. 11 branch, but only **2** change
  anything beyond one alternate sentence (`ch3_bread_kneeling` choir ±2;
  `ch4_nine_names` swaps the `post_cinderhide` beat). The other 9 "forks"
  are ±1–3 resonance (band line is 25, `story.gd:9`) plus one line of
  reply text, set once and read once.
- **Why, structurally (`story.gd:1433-1452`, `game_base.gd:1474-1551`):**
  a step is a boolean flag and nothing else — no counters, timers,
  escorts, positions; in practice every step flag but one is set by a
  dialogue choice. Rewards read exactly two keys, `gold` + `standing`
  (`game_base.gd:1540-1546`). And **nothing a side quest sets survives the
  chapter**: `sq_*` and step flags are wiped by `_wipe_chapter_flags`
  (`game_flow.gd:667-683`); only `chose_/cap_/completed_`-prefixed flags
  persist (`game_flow.gd:645`) and **no side quest writes one**. The
  game's real consequence machinery — `chose_*` → `beat_for` variants
  (`story.gd:1304-1321`, 7 variants repo-wide) — is fed by chapter
  briefings and resonance shrines, never by quests. The quest system and
  the consequence system are wired to different things.
- **Main quests** are a `quest_key` label advanced by boss kills
  (`game_flow.gd:1082-1122`): briefing choice → boss → boss → boss.
  Faction arc steps (`ch2_factions.gd`) pay nothing. Bounties are pure
  kill/clear counters with no fiction (`balance.gd:2546-2565`).
- **The hat (`heron_feather`, `story.gd:340-478`) is the same 2-step
  courier engine.** It reads solid because of authoring: the object exists
  in the world independently of the ask (three offer sites, accept from
  either end), the item's description changes with what you already know,
  the turn-in is a three-beat recognition scene, and boy + hat share one
  wanderer roll so finding it feels like a discovery. Same 150g either
  way. That is the reproducible template (§3.3).

**World variance today (all seeded off `wander_seed`, `game_world.gd`):**
map layout, +15% pack densify, elite ambush 18% of combat rooms
(`ELITE_COMBAT_AMBUSH_CHANCE`), elite room 30% of socials, one wanderer per
social room, gamble shrine 22%, cursed chest 15% (the only spawn-on-enter
event), hidden cache 25% of dead ends, road smuggler 14%, unseeded terrain
weather; weekly Waking breach rooms; daily bounties. Every one of these
is **loot or geometry**. None is a situation with a verb in it. The room
palette reserves `Event` and `Secret` types (DESIGN.md:93-95) — **neither
is built or authored anywhere**. There is no hidden/optional boss, no
minigame, no skill check, no easter egg, no pet (the warlock's
`eldritch_familiar` is a cosmetic bob, `player_combat.gd:431`).

So the complaint is exactly right, and it has one root: the world rolls
*where the loot is*, never *what happens to you*.

---

## 1. The rule — a situation is a verb with a cost

Adopt as a standing rule for everything below (and for new quests):

1. **≥2 real verbs.** Fight / pay / bluff / run / protect / solve / wager /
   race / repair / spare. "Say the kind line or the hard line" is not two
   verbs.
2. **One verb costs something now** — gold, a potion, HP, time (rooms),
   a standing point, the reward itself.
3. **One verb leaves a MARK the same run reads later.** The consequence
   loop closes inside the hour, not at the epilogue: the bandit you paid
   turns up again; the merchant you saved is cheaper; the courier you
   robbed sends a hunter. A few marks persist (`chose_`-prefixed) and the
   world remembers across chapters.
4. **Content authored, geography rolls** (DESIGN.md:83) still holds. The
   deck is authored cards; the seed picks WHICH cards land WHERE. No
   procedurally generated fiction.
5. **No silent effects.** Every surprise has a tell before it (crows
   lift, the music drops, tracks on the floor, a rumor at the tankard)
   and a codex line after it. Ambush ≠ cheap shot.
6. **Curves, not coin flips** (DESIGN.md:244): frequencies are shaped
   (bell / diminishing per run), never a flat `randi_range` per room.

---

## 1b. Status — WHAT'S BUILT (2026-08-17)

**Only Layer A (Quest verbs) has code. Layers B–F are proposal-only, zero
code.** Precisely:

**✅ Layer A — Quest verbs: COMPLETE for the whole 24-quest roster.**
- Engine: the `kill` step kind (host-authoritative counter,
  `game_base.quest_kills`, journal shows live `(have/need)`); the
  `item`/`gem`/`kept` reward keys (`kept` persists via the `sq_kept_`
  prefix); the quest-illustration hook — a `"cinematic": true` convo
  opt-in + a `q_<base>` cue family (per-class `q_<base>_<class>` auto-wins
  when the plate exists) + a `"scene"` convo-choice key that chains an
  illustrated beat after a turn-in.
- **Completability guard** (`game_world._ensure_quest_quarry`): rooms build
  once and cleared rooms never respawn, so a kill-step whose target rooms
  were cleared before you accepted would strand — the world now tops up a
  fighting room with loose zero-reward quarry (`Enemy.from_quest`) only
  when you're short and the target is absent. Kill-quests are always
  finishable.
- Content: **all 24 side quests retrofitted, matched to tone.** 10 carry a
  `kill` objective (placed only where the location is genuinely dangerous —
  hunters_rounds, still_blue, ch3_unfilled_row, out_of_tolerance,
  forty_mouths, count_sleepers, far_shore, kesh_tally, relay_stands,
  korrags_due; + ch4_nine_names' existing boss). ~every quest pays a gem;
  **11 leave a persistent `sq_kept_` mark** (the consequence substrate).
  **5 have illustrated turn-ins** (canon-adhering Codex plates): the hat,
  facing_home, void_letter, ash_for_aldric, bread_for_the_kneeling. The
  quiet/grief quests got marks + illustrations, never bolted-on combat.
- Suite: `_test_quest_verbs` + `_test_quest_quarry` + every chapter's
  quest test (ch1–7 + promises) green; convo integrity green.
- **Not built even in Layer A:** the `hunt`/`escort`/`defend`/`timed`/
  `deliver` step kinds and the `keepsake`/`beat` reward keys (only `kill`
  + item/gem/kept shipped). No side quest forks on class yet, so the
  per-class illustration path is wired but unused.

**❌ Layers B–F — NOT built (proposal only, zero code):** the Road Deck
(§4), the Unlisted hidden bosses (§5), portal-stone pockets (§6),
pets + minigames (§7), easter eggs (§8). The sections below are the
design, not the state of the code.

## 2. The six layers (each shippable alone; §9 orders them)

| Layer | What it answers | New engine | Content |
|---|---|---|---|
| A. Quest verbs | "make a choice and that's it" | small: step kinds, reward keys, persistent marks | retrofit 8 quests, 1 authoring checklist |
| B. The Road Deck | "bandits rob him on the road" | encounter framework (deck + marks + follow-ups) | 12 cards, 6 in slice 1 |
| C. The Unlisted | "randomly encounters a hidden boss" | none (reuses `Boss.make_boss` + tells) | 4 bosses, 2 in slice 1 |
| D. Portal stones | "mini dungeon, special rewards, returns him" | pocket injection (the `_waking_inject` hook) | 6 pockets, 2 in slice 1 |
| E. Pets + minigames | "tic-tac-toe against a slime pet" | MiniGame overlay contract; pet stable + follower | 3 games, 4 pets |
| F. Easter eggs | "the world remembers" | none (reads existing flags/meta) | ~10 eggs |
| G. Reactive props | "hit a crystal and it bounces / a prop explodes" | prop state model + the projectile-impact meta hook | ~6 prop types, destructibles + 1 bounce crystal |
| H. Enterable buildings | "walk into the cottage, one room inside" | live room-append helper (or standalone route) | tiny interiors on select buildings |

---

## 3. Layer A — quest verbs (biggest reach per line of code)

### 3.1 Step kinds (`steps[].kind`, default `flag` — every existing quest keeps working)
- `flag` — today's behavior.
- `kill` — `{target, count}`; run-scoped counter (`game_base.quest_kills`,
  host-authoritative, hooked in `on_enemy_died`). **Completability guard
  (`game_world._ensure_quest_quarry`, BUILT):** rooms build once and
  cleared rooms never respawn, so counting ambient mobs alone would strand
  a quest whose target rooms were cleared before you accepted it. On
  entering a combat room while the step is short and its target isn't
  present, the world tops up with LOOSE quarry (zero XP/gold, `from_quest`
  so they still count, not sealed into the room). Natural play never
  triggers it; only the cleared/stuck case does.
- `hunt` — spawns ONE named elite (`kind` + affix + display name) into a
  seeded room ahead of the player on accept; step done on its death.
  The "there is a specific wolf" quest — cheap, huge feel.
- `escort` — a wanderer NPC follows (the pet follower from §7 reused);
  step done at a prop/room; if the NPC dies the quest FAILS with the
  abandon charge (the first quest that can be lost, not just dropped).
- `defend` — hold a prop through N seeded waves (event-spawn rule:
  zero XP, gold like a pack); fail state = the prop is destroyed.
- `timed` — deadline in ROOMS entered (not wall clock — co-op and pause
  safe): "the loaf goes stale in 6 rooms".
- `deliver` — courier as today but the item is a real bag item that a
  Road Deck card can try to take (§4, the Toll's "hand over").

### 3.2 Reward keys (beyond `gold`/`standing`)
`item` (a chapter-band roll or a named unique), `gem`, `keepsake`
(cosmetic: chroma/title/pet — identity, never power), `kept` (write a
persistent `chose_`/`sq_kept_<id>` mark), `beat` (register a `@flag:`
variant). Rule: gold stays in the chapter's replay envelope
(`econ_audit.gd` re-run when a quest gains an `item` key); a quest never
becomes the best farm in its chapter.

### 3.3 The hat template (authoring checklist, goes in `content/README.md`)
1. The OBJECT exists in the world before the ASK (accept from either end).
2. Two discovery paths (giver-first, object-first) with different item text.
3. A verb (§1) — not "hand it over": guard it, race it, choose who gets it.
4. Turn-in is a recognition SCENE (≥3 beats), not a receipt.
5. One MARK: `kept` or `beat` — the world reads it at least once later.
   (One `req_wanderer` roll for giver + object where scarcity helps.)

### 3.4 Retrofits — DONE (all 24 side quests upgraded, 2026-08-17)
The full roster was retrofitted with the built tools, matched to each
quest's TONE (combat only where the location is genuinely dangerous; the
tender/grief quests get gem + persistent mark, never bolted-on combat):

- **Combat objective (`kill` step)** — 10 quests: `hunters_rounds` (wolf),
  `still_blue` (blightwolf, the blighted mill road), `ch3_unfilled_row`
  (gravewalker), `out_of_tolerance` (slag_brute), `ch5_forty_mouths`
  (winterfang), `ch5_count_sleepers` (hushcaller, the Vein of the Queen),
  `ch6_far_shore` (root_shambler, deep root gallery), `ch6_kesh_tally`
  (bog_lurker), `ch7_relay_stands` (storm_harrier, the void's edge),
  `ch7_korrags_due` (void_shade). Plus `ch4_nine_names`, which already
  had its boss kill. Journal shows live `(0/N)`.
- **Gem reward** — added to ~every quest so completions feel worth it.
- **Persistent `sq_kept_` mark** — 11 quests (oak_debt, flame_lit,
  mill_truth, aldric_ash, sexton_stone, quench, hunter_warden,
  kesh_survey, korrag_honored, far_shore, fenna_son) — the substrate a
  later beat can read; the consequence layer starts here.
- **Illustrated turn-in** — `heron_feather` (the hat), the opener-style
  plate (§3.5). The other tender quests (facing_home, bread_kneeling,
  void_letter) are candidates for the same treatment in an art pass.

Every affected autotest chain was extended and bag snapshot/restore added
wherever a quest now pays a gem. Tone call held: the quiet quests stayed
quiet, so the variety reads as intentional, not uniform.

### 3.5 Quest illustrations — BUILT (owner ask 2026-08-17: "copy how we generated art for opening scenes")

A quest EVENT can now show an opener-style illustrated plate, reusing the
chapter-opener storybook wholesale (`cutscene.gd`, `run_cinematic_convo`).
The engine additions:
- **`"cinematic": true` on a convo** → `run_convo_id` mounts the storybook
  `Cutscene` and each node's `"cue"` stages its plate. Any quest convo
  opts in with one flag; existing quests included.
- **`q_<base>` cue family** (`Cutscene._quest_frames`) → plate
  `assets/sprites/opening/quests/quest_<base>.png`. **Per-class art is
  automatic**: if `quests/quest_<base>_<class>.png` exists it takes over
  for that class, else the shared plate serves everyone — so an "important
  enough" quest gets class-flavored art just by dropping the files, no code.
  `is_known_cue` accepts the whole `q_*` family (autotest-validated).
- **`"scene": "<convo_id>"` convo-choice key** → after a choice's path
  closes, play that cinematic convo as an illustrated beat, then continue
  (chains with `hub_action`). The clean trigger for "at this quest moment,
  show a plate."

Worked example: the Heron Feather turn-in (`wander_orphan` → the
`hat_returned_scene` cinematic, cue `q_hat`) closes the beloved quest on a
plate instead of only a toast. Art is generated via the Codex `image_gen`
lane exactly like openers (`tools/art/run_codex_batch.ps1`, brief + opener
style-refs, 1672×941, authored bright, installed under `opening/quests/`).
The wiring is art-independent (a missing plate warns and shows the backdrop
+ narration), so quests can be wired first and illustrated later.

**Next for illustrations:** decide which quests earn a cinematic beat
(taste call — not every courier should), and which earn per-class plates
(the class-refracted ones: a paladin's oath-quest, a warlock's pact debt).
The mechanism is done; the rest is authoring + art.

---

## 4. Layer B — the Road Deck

**Framework.** A seeded per-character deck (`Balance.ROAD_DECK_*`), drawn
during `_prepare_rooms` like elites/caches: 1–2 cards per chapter run on
a diminishing curve (first card ~70% of runs, second ~25%, third ~5%);
never in boss/safe rooms; a card binds to a room and materializes on
first entry (the `_offer_cursed_chest` pattern) or at a door threshold
(spine edge). Cards carry `req_flag`/`req_band`/`req_class`, and
**follow-up cards** carry `req_flag` on an earlier card's MARK and draw
with priority so the loop closes in the same run. Marks are run flags
(`rd_*`, wiped with the chapter); a few are `chose_`-prefixed and persist.
Presented with the existing convo engine (`gold`, `hub_action`,
`req_band`, `gain_item/lose_item` choice keys already exist —
`game_base.gd:1738-1841`), so a card is data + at most one `_hub_action`
verb (spawn pack / spawn elite / open pocket / start minigame).
Journal: ENCOUNTERS under WORLD. Codex: an **Encounters** section (met
cards only, spoiler-safe). Results card: "encounters" beside "secrets".

**Cards (12; ★ = slice 1).**
1. ★ **The Toll.** Bandits bar the door: *pay* (level-scaled, ~one
   potion's worth), *fight* (pack + a named leader elite, better loot),
   *bluff* (`req_band` tempted OR the class line — a warlock's pact-mark,
   an assassin's guild sign), *hand over* (a `deliver` item if carrying
   one). Marks: `rd_toll_paid` → later card *"They spend your coin"* (the
   same bandits drinking at the merchant camp; the leader sells your own
   potion back at markup — pay again or draw steel in a safe room, which
   costs standing with the camp); `rd_toll_spared` (leader yields at low
   HP; spare/kill) → the spared leader reappears in a LATER CHAPTER as a
   wanderer with a real discount (persistent `chose_toll_spared`);
   `rd_toll_slain` → a Warden's wanderer pays a head price at the next
   social room. Tell: crows lift + music drops one room before.
2. ★ **The Wounded Courier.** A dying Accord/Cinderborn runner. *Save*
   (spend a potion) → standing + a sealed letter that pays at the desk
   NPC this chapter; *take the satchel* (gold, −res) → mark → the faction
   sends a hunter elite two rooms on; *leave* → nothing, and the desk
   NPC's greet variant is colder this run.
3. ★ **The Caravan.** A merchant under attack ahead of you (`defend`
   waves). Save it → this run's road merchant is 20% cheaper and stocks
   one boss-band piece; ignore → the next merchant camp is burned (safe
   room, no shop). The first card that changes what the map has in it.
4. ★ **Bridge Out.** A spine edge is down: *repair* (gold or a
   Professions material) or *detour* (unlocks two extra side rooms —
   more loot, more time). Geometry as a verb.
5. ★ **The Cage.** A caged beastkin/choir prisoner. *Free* → they fight
   beside you for one room (escort AI) then leave, standing ± by faction;
   in Hunger band they may bite. *Leave* → a wanderer later asks if you
   saw anyone.
6. ★ **The Stranger's Wager.** A hooded gambler at a fire — the first
   minigame (§7 dice/shell); stakes gold or a gem, once per run.
7. **Footprints.** A trail of prop tracks through 2–3 rooms ending at an
   Unlisted boss lair (§5). Follow or don't.
8. **The Portal Stone** (§6).
9. **The Rival Bearer.** A shard-bearer of another class challenges you
   (a hero-mirror enemy on the PvP kit substrate). Win = that class's
   keepsake chroma; decline = nothing; lose = he takes a cut of run gold
   and vanishes. Solo only v1.
10. **The Beggar's Map.** Give N gold → he marks this run's hidden cache
    room on the map (fog stays; the pin is the gift). Refuse → nothing.
    Tempted band: rob him (−res, +his 12 coins, and he's gone from every
    later run: persistent).
11. **The Stray** (§7 — pets).
12. **The Second Hat.** ch1 only, `req_flag: hat_given` from a PREVIOUS
    character (account meta) — a scarecrow wearing a hat exactly like it,
    a wanderer who won't say where he got it. Pure easter egg (§8) with a
    tiny cache; the deck's proof that it remembers.

**Economy.** Card packs/elites pay gold + loot like elites (zero XP —
event-spawn rule); the toll's price ≈ one potion; no card is a better
farm than walking the side rooms. Re-run `econ_audit.gd` after slice 1.

---

## 5. Layer C — the Unlisted (hidden bosses)

Rare, seeded, always announced by a tell, never on the map until seen,
never `story_boss` (rogue path — no story writes; DESIGN.md:148), each
banks once per run and counts for records/achievements/codex like a boss.
Cost is data: append a zone `{type: "boss", boss: kind}` through the
inject hook and the arena/door/music/boss-bar come free
(`_try_spawn_boss`, `game_world.gd:2732`); a reused `kind` + affix is zero
kit code (`Endgame.apply_affix` already renames).

1. ★ **The Tithe-Collector** (bandit king; ch2–5 fields; ~1 in 8 runs).
   Reuses a humanoid kit + Bulwark affix, new name/splash. Tell: the Toll
   card's bandits mention "the Collector". `req_flag`: refused the toll
   twice across runs (persistent counter) → he comes for YOU (guaranteed
   next run) — the first consequence boss. Drop: boss-band roll + the
   *Tithe Ledger* keepsake (title "Untithed").
2. ★ **Old Greymantle** (the wolf that got away from Fangmaw's warband;
   ch3–6; ~1 in 10). Reuses the fangmaw beast kit at +2 affixes. Tell:
   Footprints card. Wildfang standing ±2 by outcome (spare = it limps off;
   the cure camp hears). Drop: pelt keepsake (a cloak chroma).
3. **The Man Who Did It First** — the DESIGN.md:33 "optional superboss
   homage": Aldric's shadow, flag-gated (Act 1 clear + Aldric's ch2
   "what I never told you" convo), one authored kit, one arena, L45.
   Reward: title + the ONE unique that says who you fought.
4. **Out of Season** — a Waking echo (existing boss kind from another
   god-king) standing in a dead end with one affix, outside incursion
   week (~1 in 12). Free content: pure reuse; the codex line is the tell.

Deferred idea, flagged not decided: *the Hatless Man* (the boy's father,
returned wrong, in the Darkwood) — strong, possibly too cruel for ch1's
warmest quest. Owner's call (§10).

---

## 6. Layer D — portal stones → pockets

**Mechanism — in-graph, not a world swap.** `switch_chapter` frees the
world (`game_world.gd:55`) and world swaps are hard-blocked online
(`enter_endgame`, `game_flow.gd:854`), so a standalone-chapter pocket
(the Vigils' model) cannot "return you to the same room" and breaks
co-op. Instead: when the deck rolls a stone, `_prepare_rooms` injects a
3–4 room pocket (the `_waking_inject` hook, `game_world.gd:621`) attached
off the stone's room behind an `edge_locks` `flag:portal_<id>` lock,
hidden on the map until entered. The stone is an npc def with
`"action": "portal_pocket"` (`_hub_action`, `game_world.gd:200`); the
pocket's last room holds its boss/council; killing it opens a return
stone that teleports to the origin room (fast-travel plumbing,
`fast_travel`, `:1503`). Rooms build lazily so cost is nil until entered;
seeded per character so guests rebuild the same pocket; host arms it via
`_host_ensure_active_rooms` (`:851`). BORROWED_LOOPS §6 holds: the door
is always open when it rolls; the reward banks once per run.

**Frequency.** ~25% of runs on the curve; never ch1 first run.

**Pockets (6; two per slice).** Each = a look (a `ph_*` gallery terrain
promoted or a god-king fragment), ONE twist rule posted at the stone (no
silent effects), one boss/council, one **relic keepsake** (cosmetic +
codex page) + one boss-band gear roll + a gem, then home.
1. ★ **The Molten Court** — magma fragment; twist: *the floor tithes* (a
   rhythmic lava pulse; standing still burns); council of 2 magma elites.
2. ★ **The Still Larder** — ice; twist: *no potions* (the Queen keeps
   what sleeps); one Frozen Guard captain w/ Bulwark.
3. **The Root Cellar** — bog/spore; twist: *everything you kill sprouts
   once* (Second Shape from BORROWED_LOOPS §1, scoped to the pocket).
4. **The Storm Ledger** — storm/void; twist: *the lights are out* — you
   see by your own hits (a dark shader pocket); a Stormwarden echo.
5. **The Hymn Hall** — Choir; twist: *silence* — abilities off for the
   first room, then a Hushcaller council; the Choir's own liturgy pages.
6. **The Imperial Vault** — old empire (seeds the Undercroft Interlude);
   twist: *the ledger* — every chest opened raises the boss one affix.
   Relic keepsake: the sixth-seal sigil chroma.

**Relation to the Seal Vigils (DAILY_DUNGEONS.md).** Different jobs:
Vigils are the capital-entered daily exam you choose; a stone is a
mid-run discovery you stumble on. Room templates and twist rules are
shared authoring; economies don't overlap (a pocket pays like an elite
room + one boss roll, inside the chapter's replay envelope).

---

## 7. Layer E — pets and minigames

**Pets = cosmetic, two lanes, never power (MT4 rule):** the store lane
(MONETIZATION_SPLIT — echo pets, paid) and the **discovery lane** (this
doc — earned in-world, never sold, never purchasable with Renown either;
identity like titles). A pet is one half-scale mob sprite (SOCIAL_LAYER
note) + a lagged follow (no combat, no pathing worth the name — the
Summoner's expensive "pet AI" is combat pets, not this), equipped one at
a time from a per-character **Stable** (codex Companions section; the
Wardrobe UI pattern). Build requirement from MONETIZATION_SPLIT §pets:
the equipped pet replicates over the wire or half the point dies.

**MiniGame contract.** One overlay module family `scripts/ui/minigame_*.gd`
with `start(cfg) → finished(win: bool)`; input-gated on overlay state
(`hud.choices_active`-style), because the tree does NOT pause online
(CLAUDE.md co-op trap). Games are 20–60 s, deterministic-seeded where
fairness matters, always losable, always retryable next run.

**Games (3):** *tic-tac-toe* (a slime plays a beatable minimax with one
deliberate blind spot; a draw is ITS win — the owner's example, kept);
*shell game* (a fox-kit and three cups; speed scales with tier);
*hold still* (a bog toad: don't move for 6 s while things spawn around
you — the movement game).

**The Stray card (deck #11, ~10% of runs, curve).** A creature that
cannot be caught by force: it names its game; win = it joins the Stable
with a codex line; lose = it flees (the card can re-roll a later run).
First four: **Slime** (tic-tac-toe, ch1–3), **Fox-kit** (shells, ch3–5),
**Bog Toad** (hold still, ch6), **Wisp** (a 20 s chase — it blinks; the
movement game with no overlay, ch7). Later: an owl (memory-match over
codex icons — we own 1,260) and the spin-off's echo pet (SPINOFF_GAMES §5).
The Stranger's Wager (deck #6) and BORROWED_LOOPS §5's Crownfall
Renown minigame reuse the same contract — one framework, three uses.

---

## 8. Layer F — easter eggs (rules: never gate progression or power;
may pay a title/keepsake; every one is in-fiction)
1. **The boy grows up.** `sq_kept_hat` → in ch7 a young Guard recruit
   wears a hat with a heron feather; one line if you speak to him. The
   whole complaint answered in one NPC.
2. **The Keeper remembers your other heroes.** Crownfall's Keeper Nix
   greets by the names of your other characters (account meta):
   "Your sister was here Tuesday" (class-canon genders); twins if same class.
3. **"Emberfall"** carved on a plaza wall behind the fountain (the old
   name); inspect → title "Of the Old Name".
4. **The picnic** — a dead-end room laid for exactly the party's headcount.
5. **The humming slime** — a slime that hums the village theme (a
   Sunset-track fragment); leave it alive and it follows for one room.
6. **PB ghost** — a wanderer who says "faster than last time" only when
   you're on PB pace (reads the results-card timer).
7. **The sixth grave** — a hidden barrow with six founder stones, one
   empty (Ossuary Interlude foreshadow); counts as a secret.
8. **The Second Hat** (deck #12).
9. **Late tankard** — after 02:00 trusted-clock the Keeper has one line
   about who else drinks this late.
10. **The merchant's mustache** — inspect the merchant 20 times across a
    character's life → title "Admirer". Zero code beyond a counter.

---

## G+H. The living world — reactive props, destructibles, enterable buildings (added 2026-08-22)

From a full audit of the prop / scenery / structure / room systems
(`game_world.gd`, `projectile.gd`, `ambience.gd`, room graph). **Finding:**
the world is built entirely in code from data tables, and props / buildings /
critters are inert sprites with at most a collider. Nothing is destructible or
combat-reactive (the only attackable thing is the training `Dummy`, which is an
`Enemy` subclass, `dummy.gd:1`); no building is enterable (no interior concept
exists). But the primitives to change that already exist — this is the prop
side of the same complaint the rest of this doc answers: the world is set
dressing that was never made into a system.

**The unifying seam.** Projectiles ALREADY collide with every prop — props sit
on `collision_layer=1` and projectile masks include layer 1 — but the impact
handler treats them all as an anonymous wall (`elif body is StaticBody2D:` →
burst + `queue_free`, no damage, no lookup) at a single choke point
(`projectile.gd:927`). Every prop is already tagged `set_meta("prop"/
"structure"/"building", name)` (`game_world.gd:2555, 2904, 2469`). So a
prop-reaction is a `body.get_meta(...)` branch at that one line — no new
plumbing to detect the hit.

### G1 — Combat-reactive props (owner: "hit a crystal and it bounces", "a prop explodes if attacked")
Cheapest lane, biggest instant "alive" payoff. All three reuse existing recipes:
- **Exploding props** (keg, urn, brazier): a `destructible` meta + small HP;
  on lethal hit, reuse the gate's exact "remove collider + fade + free"
  sequence (`open_edge`, `game_world.gd:3536-3548`), then `_add_hazard`
  (`game_world.gd:4210`) a fire/void pool at the spot. Positioning becomes a
  weapon. Nearly all from existing calls.
- **Bounce / reflect crystals** (the owner's crystal): projectile ricochet
  infra already exists (`_spawn_ricochet.call_deferred`, `projectile.gd:967`).
  A crystal that redirects a shot on impact lets the player bank attacks around
  cover; enemy shots bounce too (emergent). Or it reflects an incoming bolt
  back as a hazard.
- **Shootable switches**: hit a prop → open a gate / drop a cache / kill a
  hazard. Generalizes something already in the Act 2 design — Ch8 specs
  "forge machinery activatable by the player" (`ACT2_DESIGN.md` §Ch8) — into a
  game-wide verb.
- **Melee reach**: player attacks only scan `group("enemies")`
  (`player_combat.gd:994`), so props are untouchable by melee/AoE today. Two
  clean options: gate v1 to **projectiles + explosions only** (zero melee-scan
  work), or reskin the **`Dummy` template** (`dummy.gd`, already attackable
  with HP + damage numbers) for a "crystal you can melee."

### G2 — Enterable buildings (owner: "enter them, one room inside, maybe loot or an easter egg")
A room is one grid cell built lazily (`game_world.gd:975`); the interact
hotspot system (`_make_npc` → `interactables[]`, `game_world.gd:1619`) is the
door template; `Chest.drop` with an `on_open` lambda is the contents — so
"empty / loot / easter egg" is a **weighted roll on the chest**. Cheapest ship
that preserves the walk-in/walk-out feel: a tiny authored interior (the capital
ward-room recipe: `room_scale` + `landmarks` + a chest) + one hotspot + **one
small live-append-cell helper** (append to the graph, place a door, call
`_build_room`) so entering/exiting is the normal walk-across-boundary
transition with position preserved. Zero-engine-change alternative: the
standalone-mini-world route (like `enter_capital`), but it tears down the
outdoor world and needs custom "return here" logic. **Gap:** no mid-session
room injection or position-restore exists today; both are small helpers, not a
rework. Shares the `_waking_inject` pocket hook with Layer D.

### G3 — Living critters + the joke-weapon secret (the bird loop — combines Layers C + E + F + G)
The owner's "bird killer" idea, grounded: critters already exist
(`ambience.gd`) and already **flee the player** (`ambience.gd:274`) — so a
cursed joke weapon that flips them targetable gets the *hunt* for free (they
run, you chase). The loop:
1. **The joke weapon** (Layer F easter egg) — a hidden, absurdly over-serious
   cursed "bird killer" that only lets you kill critters. The comedy is the
   contrast, so it stays gated behind a secret and is never default-visible
   (default-visible critter-murder makes the somber world goofy — tone rule).
2. **A kill-count secret** (curve, with a tell: "the birds have begun to avoid
   you") summons a hidden boss — Layer C infra, `Boss.make_boss` reuse, a
   proper joke-serious fight (a vengeful Featherking), not a gag mob.
3. **Reward** — a guaranteed cosmetic + a rare **pet** (Layer E discovery-lane
   pet: cosmetic, never power, never sold — the MT4 rule). The one net-new
   system the loop needs is the pet follower/stable itself (Layer E).

This is the flagship proof of the whole thesis: set dressing (a bird) becomes a
secret hunt becomes a boss becomes a collectible.

### Shared plumbing (build once, all three reuse)
- **Prop state / damage model** — HP + a react hook (or the `Dummy` route);
  props have none today. Feeds G1 and the G3 hunt.
- **Destroyed-state persistence** — real gotcha: `zone_scenery` is fully
  rebuilt on every room entry (`game_world.gd:998, 1948`), so a smashed prop
  respawns unless flagged. Reuse `get_flag/set_flag` (`game_flow.gd`).
- **The `projectile.gd:927` meta branch** — the one hook that lights up G1.
- **The live room-append helper** — for G2 interiors and Layer D pockets.
- **Pet follower + stable** — for G3, the Layer E build.
- **MP** — prop destruction needs its own net event (impact/hazard net
  patterns exist to copy, `projectile.gd:826`, `game_flow.gd:1993`).

### Readability + contract rules (so this doesn't become noise)
- **A consistent visual language is mandatory.** A barrel must read as hittable
  and a statue as solid, or the world becomes untrustworthy noise. This is the
  prop counterpart to the "tells before surprises" rule (§1.5). No random prop
  explosions.
- **The prop motion contract still applies** (`CLAUDE.md` §World props): an
  interactive prop still animates in place, dims-not-strobes, and enters the
  `full_prop_anims` autotest.

### Build order (this addendum)
1. **G1 probe** — the prop state model + the `projectile.gd:927` hook + ONE
   exploding prop + ONE bounce crystal + the destroyed-state flag + a visual
   tell. The cheapest slice with the widest "alive" reach.
2. **G3 bird loop** — reuses Layer C (hidden boss) + Layer E (pet, build it
   here) + the joke weapon; the flagship secret.
3. **G2 enterable buildings** — the live room-append helper + 2-3 tiny
   interiors; most authoring-heavy, deepest payoff.

### Open questions (this addendum)
1. **Destructible scope** — projectiles + explosions only (cheap), or full
   melee/AoE via the `Dummy` route (richer, more work)?
2. **Prop readability language** — a subtle rim/shape convention, or an
   explicit tell (crack, glint) on hittable props?
3. **Interior route** — the in-graph live-append helper (recommended: seamless,
   position-preserving) vs the zero-engine standalone-world route (load-feel)?
4. **Bird-loop tone** — is the joke weapon in scope at all, and how hidden
   (a Road Deck find, a secret vendor, a specific easter-egg room)?

---

## 9. Guardrails and build order

**Guardrails (all existing doctrine, listed once):** every roll derives
from `wander_seed` + room idx (co-op rebuilds the world from the seed —
`net_session.gd:5-13`; an unseeded `randf()` in construction is a
desync); geometry-affecting values restore BEFORE the rebuild
(`_waking_restore` pattern); host authority on every spawn; solo-first
is acceptable for anything that injects rooms (Incursions precedent) but
in-graph pockets need no world swap so co-op is a sync task, not a
redesign; encounter spawns pay ZERO XP (event-spawn rule) and gold inside
the chapter's replay g/min; keepsakes/titles/pets are identity, never
currency; every card/boss/pocket/pet lands in the codex in the same
change (CLAUDE.md); tells before surprises; curves not coin flips.

**Slices** (each: one `content/` module + registration line + autotest
hook + codex + `Balance.*` knobs; land as NEW modules, never forks):
1. **Quest verbs** — step kinds + reward keys + `sq_kept_*` persistence +
   journal WORLD section + hat checklist + 8 retrofits. (`game_base.gd`
   `_check_side_quests`; `content/quest_verbs.gd`.) The cheapest slice
   with the widest reach: 24 quests stop being one shape.
2. **Road Deck v1** — framework + cards 1–6 with the Toll's three
   follow-ups + Encounters codex + results counter. (`content/road_deck.gd`,
   `Balance.ROAD_DECK_*`.)
3. **The Unlisted v1** — Tithe-Collector + Greymantle (kit reuse) + the
   Footprints card + persistent refuse-counter. (`content/unlisted.gd`.)
4. **Portal stones v1** — pocket injection + Molten Court + Still Larder.
   (`content/pockets.gd`; the `_waking_inject` generalization.)
5. **Minigames + pets v1** — MiniGame contract + tic-tac-toe + shells +
   Stranger's Wager + The Stray (slime, fox-kit) + Stable + wire
   replication. (`scripts/ui/minigame_*.gd`, `content/strays.gd`.)
6. Eggs 1–3 ride slice 1, 4–7 slice 2, the rest wherever they fit.

Gate after slice 2: does a first-run chapter FEEL different twice? If not,
the deck needs cards, not more layers.

---

## 10. Open questions for the owner
1. **Encounter XP** — zero (recommended; first-run XP stays a fixed
   budget) or a small authored amount for the Toll/Caravan fights?
2. **Losing to bandits** — no penalty beyond the fight (recommended; the
   death rule keeps gold intact) or they take one consumable?
3. **Pockets in-graph (recommended) vs standalone chapter** — in-graph
   returns you to the exact room and keeps co-op possible; standalone
   reuses the Vigils' build but can't do either.
4. **Discovery-lane pets stay unsellable** — including for Renown? (Yes,
   recommended: they are the one pet family money can't reach.)
5. **The Hatless Man** — build it, or leave the boy's father a mystery?
6. **Frequencies** — 1–2 cards/run, stone 25%, stray 10%, Unlisted 1-in-8
   to 1-in-12: first guesses; the slice-2 gate playtest sets them.

> Thesis: the engine can only say "pick a line", and nothing a quest
> does outlives its chapter — so of course the world reads flat. Give
> quests verbs and marks, give the road a deck that remembers, hide four
> bosses behind tells, let a stone open a room the map didn't promise,
> and make a slime demand a game before it follows you. Everything above
> is authored; only where it happens rolls.
