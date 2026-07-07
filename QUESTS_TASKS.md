# Act 1 Side Quests — Task Board

Goal: give every Act 1 chapter 2–3 authored side quests on the new
side-quest engine (shipped 2026-07-06). Seven independent tasks, one per
chapter — fully parallelizable.

## Read these FIRST
- `CLAUDE.md` (working practices — testing order, GDScript traps)
- `game/scripts/content/README.md` (module format: SIDE_QUESTS,
  QUEST_ITEMS, `side_quest` / `gain_item` / `lose_item` choice keys,
  `req_wanderer` npc key)
- `Story.SIDE_QUESTS` in `game/scripts/story.gd` (the pilot quest
  "heron_feather" — copy its shape) and its wiring in `wander_orphan` +
  `lore_millers_hat` (accept from a choice, steps as flags, keepsake
  carried in the bag)

## Rules for parallel agents
1. **One task = one owner.** Claim it here (name + date on the task line)
   before starting. Never touch another task's files.
2. **Each task creates exactly ONE new file**: `scripts/content/chN_quests.gd`
   (plain script, NO class_name) — plus ONE preload line in
   `Story.CONTENT_MODULES`, ONE `await _test_chN_quests()` line in
   autotest's marked CONTENT-MODULE TEST HOOK, and your `_test_chN_quests`
   func appended at the END of `autotest.gd`. Nothing else in shared files.
3. **Never append zones.** The suite asserts room counts (ch1 = 25,
   ch3–ch7 = 21 each, ch2 hub chain = 10). Quests hook EXISTING rooms.
4. **Hooking an existing NPC/prop = override its convo from your module.**
   `Story.load_content` merges module CONVOS over the base — copy the
   CURRENT convo dict from its owning file into your module, then extend
   it. Note the override with a comment (`# OVERRIDES <file>'s <id>`).
   Never edit the owning file itself.
5. **Never prepend or reorder choices in a convo the full suite walks**
   (briefing/gate NPCs — autotest picks choice index 0). Append new
   choices at the END, and gate them with `req_flag`/`req_not_flag` so
   they don't appear mid-briefing.
6. **Quest steps are FLAGS set by convo choices.** Kills cannot set
   flags — no "slay N wolves" quests (that's the bounty system's job).
   Supported shapes, all proven by the pilot:
   - **Courier/offering:** giver's choice `gain_item` → destination
     prop's choice `lose_item` + final flag. Item defs go in your
     module's `QUEST_ITEMS` const.
   - **Pilgrimage:** visit 2–3 FIXED props; each overridden prop convo
     gains an appended, quest-gated choice setting its step flag.
   - **Fetch/report:** find a prop, return to a FIXED giver (gate NPCs
     persist all run; wanderers persist once rolled, but only roll in
     ~half of runs — a wanderer giver makes the quest run-conditional,
     which is fine and matches the pilot).
7. **Rewards:** `{"gold": 100..250}` base (engine level-scales it),
   optionally `"standing": {"faction": ±2..6}`. No gear, no gems —
   side quests are a small gold faucet (reward-economy doctrine: one
   faucet, one job). Resonance shifts on choices stay small (±1..4).
8. **Flags/keepsakes are run-scoped automatically** (wiped with chapter
   flags; quest items purged from the bag). Don't fight it.
9. Your `_test_chN_quests`: snapshot `game.flags` + gold, drive each
   quest's flags via `game.set_flag`, assert single payout, RESTORE
   state (see `_test_side_quests` in autotest.gd for the template).
   The convo-integrity test validates your convos automatically.
10. Iterate with `test_quick.bat`; FULL `test.bat` green before staging.
    Stage with `git add` (your module + the three shared one-liners).
    No commits, no attribution trailers.

Seeds below are grounded in each chapter's existing lore — adjust names
and details after reading your chapter's files, but keep the shapes.

---

## Q1 — Chapter 1 quests (`ch1_quests.gd`) — DONE: Claude (2026-07-06)
Surfaces: 6 wanderers + 4 lore props + 2 shrines, all in `story.gd`
(the hat pilot already covers the miller's boy).
- [x] **Osla's Debt** — override `wander_tinker`: after the axle help
      (`helped_tinker`), Osla hands over a coin pouch (`gain_item`)
      to leave in the Hollow Oak's offering hollow ("debts left with
      the old wood find their owners") → override `lore_hollow_oak`
      with a gated deposit choice (`lose_item`, final flag). ~120g.
- [x] **The Hunter's Rounds** — override `wander_hunter`: he asks you
      to check the wood's old landmarks — Ravine Edge, the Drowned
      Chapel, the Collapsed Tower (all fixed props) — appending a
      quest-gated "mark the hunter's sign" choice to each prop convo.
      Third mark completes. ~180g. (Offer comes on the SECOND talk —
      choice-0 chains stay one round deep for the suite's social walk.)
- [x] **Flame at the Window** — override `wander_pilgrim`: she gives a
      pine stick (`gain_item`) to light on the Drowned Chapel's altar
      (`lose_item`, +2 resonance). ~100g.
  (Both Q1 chapel hooks live in YOUR module — one override carrying
  both gated choices; no conflict.)

## Q2 — Chapter 2 quests (`ch2_quests.gd`) — DONE: Claude (2026-07-06)
Surfaces: fixed hub NPCs (Sera, Piet, Aldric, recruiters, cage,
pilgrim in `ch2_hub.gd`/`ch2_factions.gd`/`ch2_aldric.gd`) + act 1/2
zone NPCs and props (`ch2_zones_act1/2.gd`).
- [x] **Still Blue** — WRAP the existing mill arc as a visible quest:
      flags `mill_seen`/`mill_told` already exist. Override
      `ch2_refugee` to append an accept choice ("I'll look for the
      door"); steps = the two existing flags. Reward ~150g. Do NOT
      change her existing variant flow.
- [x] **Bread for the Road** — Sera bakes for whoever mans the far
      crossings: carry a loaf (`gain_item`) to a fixed act-2 zone NPC
      (read `ch2_zones_act2.gd` for the right one — the scholar works).
      ~150g, small `wildfang` or `accord` standing per your judgment.
      (Shipped: accord +2; delivered to Scholar Ivo in the Deeps.)
- [x] **Ash for the Old Knight** — Aldric asks for a pinch of ash from
      the Null Bastion approach ("I want to know what it burns like
      now") — a gated choice appended to a fixed act-2 prop convo
      (`gain_item`), returned to Aldric (`lose_item`). ~200g.
      (Shipped inverted: Ivo holds the jar Aldric once commissioned by
      letter — accept + `gain_item` at the scholar, hand-over choice on
      Aldric's hub gated on carrying it. Act 2 has no prop convos, and
      an Aldric-side ask would break the suite's asserted hub choice
      counts; the carry-gate keeps it invisible to every suite walk.)

## Q3 — Chapter 3 quests (`ch3_quests.gd`) — DONE: Claude (2026-07-06, QA'd)
Read `ch3_zones.gd` first (gate NPC: Cantor Ilse; kneeling congregation,
peddler, lore props).
- [x] **The Unfilled Row** — Cantor Ilse asks for the NAMES on the
      Vale's old markers: visit 2–3 fixed lore props (append gated
      "copy the name" choices), return to Ilse to report. ~180g.
      (Shipped: Bram Tallow's headstone + the reliquary placards,
      ordered chain, reported at Ilse's post-briefing hub.)
- [x] **Bread for the Kneeling** — carry bread from the Vigil Gate to
      the kneeling congregation (courier shape). Small `choir` standing
      either direction per the player's framing choice. ~120g.
      (Shipped: giver = Old Fenna, kind-path gated; two delivery
      framings at the Kneeling Field, choir ±2.)
- [x] **A Stone for the Sexton** — after the Vale quiets, someone must
      close the graves: a courier/offering chain ending at a grave
      prop. ~150g. (Shipped: giver = Old Digger Haim, wanderer; stone
      set beside Bram Tallow's plot at the Hollow Chapel.)

## Q4 — Chapter 4 quests (`ch4_quests.gd`) — DONE: Claude (2026-07-06, QA'd)
Read `ch4_zones.gd` first (gate NPC: Overseer Brann; Nix the
acquittal-seller, foundry props).
- [x] **Out of Tolerance** — Brann wants proof the foundries cool:
      collect a cooled slag core from a fixed vent-field prop
      (`gain_item`), return it (`lose_item`). ~180g.
      (Shipped: source prop = the Cold Forge — no vent-field prop
      exists; the never-lit forge is where slag actually goes cold.)
- [x] **Nix's Receipts** — Nix sold acquittals from a court that never
      acquitted; the player returns one (courier) to a fixed prop/NPC
      the module picks — the refund matters more than the coin. ~150g,
      ±resonance on the framing choices.
      (Shipped: destination = Smith Petra, crew five's survivor — the
      crews bought the charms; the refund goes to who's left.)
- [x] **The Quench Prayer** — a smith's token carried up the Judgment
      Stair approach and left at a fixed prop. ~120g.
      (Shipped: giver = Old Smith Harl, the water-quench smith;
      destination = the Ember Font — the deposit does NOT consume the
      shrine's own three-way choice.)

## Q5 — Chapter 5 quests (`ch5_quests.gd`) — DONE: Claude (2026-07-06, QA'd)
Read `ch5_zones.gd` first (gate NPC: Tracker Yri; skald Ottar, the
deserter, wagon/cairn props).
- [x] **Forty Mouths** — after Whitepelt's ridge: deliver the wagons'
      grain honestly — take a bundle at a wagon prop (`gain_item`),
      leave it at the clan's cairn (`lose_item`). `wildfang` +4. ~200g.
      (Shipped: cairn → Yri's fire; no cairn prop exists and zones are
      frozen — cache dug out at the Sleeper's Wagon, returned to Yri.)
- [x] **The Spring Song** — skald Ottar's verse (`gain_item` a written
      copy) carried back to the Last Fire so the camp hears something
      that isn't the hymn. ~120g. (Shipped: read to Ansa of the Shore.)
- [x] **Count the Sleepers** — Yri needs a census of the sleeper huts:
      pilgrimage over 2–3 fixed props, report back. ~180g. (Shipped:
      Buried Chapel congregation + the Vein of the Queen, report to Yri.)

## Q6 — Chapter 6 quests (`ch6_quests.gd`) — DONE: Claude (2026-07-06, QA'd)
Read `ch6_zones.gd` first (gate NPC: Deacon Vela; Fisher Dov, Kesh,
the schism camps, bloom props).
- [x] **The Far Shore's Door** — Fisher Dov can't row past the leaning
      reeds himself: check the far shore's door (fixed prop, gated
      choice), come back and tell him TRUE. What "true" is, is the
      player's choice. ~150g. (Brekk's blue door found grown into the
      Pale Gallery's west face; report choice = whole truth vs kind one.)
- [x] **Bread Between Camps** — the schism's stale loaf, made literal:
      carry bread from one pilgrim camp to the other (courier both
      ways or one, module's call). Small `choir` standing. ~120g.
      (One way: Vela's gate flock -> the schism table.)
- [x] **Kesh's Tally** — Kesh counts what the Bloom takes: mark 2–3
      overgrown props for the camps' maps, report to Kesh.
      `wildfang` +3. ~180g. (Marks: Sunken Shrine lintel + Cure Pool
      fence; debriefed mark-by-mark at Kesh.)

## Q7 — Chapter 7 quests (`ch7_quests.gd`) — DONE: Claude (2026-07-06, QA'd)
Read `ch7_zones.gd` first (gate NPC: Elder Maren at the Summit Camp;
Keeper Vasse, the vowstone, Korrag's cairn, the void shelf).
- [x] **The Relay Stands** — Retired Keeper Vasse can't climb anymore:
      stand a moment at the relay's three stations (vowstone, cairn,
      one more fixed prop — gated choices appended), then tell her the
      line still holds. ~220g. (Shipped: vowstone + cairn + void shelf;
      completion line delivered via Vasse's paid variant.)
- [x] **A Letter for Someone Who Will Remember** — the void shelf's
      sealed letter (`gain_item`) brought to Maren, who has outlived
      enough of Vaelscar to qualify. Do NOT open it — that's the point.
      ~200g. (Shipped: seal stays unbroken; Maren pockets it for after
      the stair.)
- [x] **Korrag's Due** — the beast-clans left offerings at the
      Stormwarden's cairn; the old order never did. Carry an order
      token from the summit camp and leave it (`lose_item`).
      `wildfang` +4. ~150g. (Shipped: giver = Apprentice Sorrel, the
      order's shift-token among the wolf teeth.)

---

QA pass (2026-07-06, post-merge): all 22 quests audited — override
fidelity vs owners, gating, suite-walk safety, cross-module collisions
(none), reward bands. One fix applied: Still Blue gains a retroactive
accept on Sera's report choice (explorer-first players used to lose the
quest). Full suite green.
