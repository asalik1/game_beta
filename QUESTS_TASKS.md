# Quest Framework — Task Board

Phase 1 (Q1–Q7, DONE 2026-07-06): every Act 1 chapter got 2–3 authored
side quests on the side-quest engine. Phase 2 (Q8–Q16, planned
2026-08-21) carries the rest of the quest framework: onboarding, the
remaining quest verbs, the ch2 slate, the capital's contracts and
chains, the Interludes, and the Dynamic World layers. Design lives in
`PROPOSALS/QUESTS_AND_SIDE_CHAPTERS.md` and `PROPOSALS/DYNAMIC_WORLD.md`;
this board holds only the build steps, files, tests and order.

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


## Q8 - Onboarding: talents + gear after the FIRST room clear (OPEN - owner request 2026-08-19)
The player is never TAUGHT the two systems that carry the whole power curve.
After clearing the first combat room of a new hero's Chapter 1:
1. A guided beat teaches ALLOCATING TALENT POINTS (the first point lands about
   then; point at Skills > Talents, let them spend it before moving on).
2. A guided beat teaches EQUIPPING GEAR (the first drops have landed by then;
   open the bag, equip something).
3. AUTO-EQUIP button in the inventory - BUILT AS PART OF THIS TASK (owner):
   one button that fills empty slots and takes strict upgrades from the bag
   (reuse the _diff_tip comparison; never swap a piece a build might prefer -
   strict upgrades and empty slots only). The teaching beat can then close
   with "or press Auto-equip".
Shape: NOT a side-quest module - this belongs in the ch1 flow (a one-time
beat after _room_cleared, or a line from Elder Maren), gated on
tut_talents_done / tut_gear_done flags, skippable, never in chapter replays
and never on co-op guests.

---

# Phase 2 — implementation plan (2026-08-21, verified against main 5beaba3)

## BUILD LOG (2026-08-21) — what has actually landed on main's tree

- **Q8 — DONE (full suite green).** `Items.strictly_better()` +
  `Player.auto_equip()` + the ⚖ Auto-equip button in the inventory chip
  row; the onboarding beats (`_onboard_due`/`_onboard_maybe_queue`/
  `_run_tutorial_beat` in game_flow, drained in game.gd behind the overlay
  composite), `tut_` added to `KEPT_FLAG_PREFIXES`, per-character. Tests:
  `_test_auto_equip`, `_test_onboarding`.
- **Q9 — DONE for the seams Q10/Q11/Q12 need (full suite green).** Shipped:
  (c) `scope` field + `Story.quest_scoped()` wired through accept /
  availability / expiry / wipe + journal CAPITAL/WORLD sections;
  (d) `ZONE_PROPS` module const (second-pass merge by zone NAME, mutable
  deep-copy so it never writes a module's read-only const zone);
  (e) npc `req_flag`/`req_not_flag` gates; (f) `add_standing()` seam (convo
  forks folded onto it). Tests: `_test_quest_schema`, `_test_quest_scope`.
  DEFERRED (no consumer in the buildable set / decision-gated): (a) `hunt`
  and (b) `timed` step kinds → build with their first users (Q15 / Q14);
  (g) charge abandon on pause-menu replay → owner decision 3; (h) `keepsake`
  reward → its users are Q13/Q15 (art). `escort`/`defend` stay with Q16/Q14.
- **Q10 — 3 of 6 quests DONE (full suite green), all in `ch2_quests.gd`.**
  The Second Bell (Piet + ZONE_PROPS bell on the Howling Fields), The Salt
  Reliquary (Choir pilgrim + courier to the existing reliquary prop, choir
  +2), A Straight Answer (Ivo + ZONE_PROPS logs in the Null Bastion +
  `chose_ivo_truth` fork). These exercise every Q9 seam. `_test_ch2_quests`
  extended to 6 chains + ZONE_PROPS-attach + choir-standing asserts.
  REMAINING: What the Cage Holds (needs the cage free/water/walk fork
  interleave thought through so the quest can't strand), The Ferryman's Due
  (ch2 WANDERERS pool re-list + a 3-mark bog pilgrimage), Widow's Arithmetic
  (a `ch2_mill` override that reroutes the mill_seen revisit variant so the
  ledger is takeable on a return trip), arc step 2 (recruiter convos are
  suite-walked — append gated, keep index 0). Bell art is a `watch_brazier`
  stand-in until a bell sprite exists.
- **Q11+ — NOT STARTED.** Contracts (Q11) is the next buildable; it needs
  the gen_capital.py desk-ref rework + a new contracts UI + save schema +
  the ward-desk autotest assertion (autotest.gd ~6877) updated — a full
  task, not a tail-of-session add.

- **Q10 — DONE (full suite green).** All six ch2 quests built + illustrated +
  faction arc step 2. Commits 4c090f1 / 82ea9bc / 081c977 (content, plates,
  arc-2). Six turn-in plates + salt_token/fallen_bell sprites.
- **Q11 — v1 DONE (full suite green).** Ward contracts as a bounty-shaped
  per-ward daily deed board (the 4 wards = the 4 factions): auto-progress off
  the same events as bounties, CLAIM in the journal (capped 4/day), paying
  gold + ward standing + Kesh favor (Accord). `Balance.WARD_CONTRACT_*` +
  `game_base` refresh_contracts/contract_progress/claim_contract + save fields
  + journal ACTIVITIES section + `_test_ward_contracts`. NOTE: kept the ward
  DESKS on their existing `journal` ref (no gen_capital regen — the generator
  is stale vs the committed capital_hub.gd, would revert the amphora change);
  contracts surface in the journal the desks open. A dedicated per-ward desk
  UI is the deferred v2 (needs the generator resynced first).

Every line below was checked against the code the day it was written;
`file:line` refs drift, grep the symbol if a number is off. Engine facts
the plan leans on:
- A side quest is four flags: `sq_on_<id>`, `sq_paid_<id>`, `sq_pledge_<id>`
  + its step flags. `quest_kills[step_flag]` is the only counter
  (`game_base.gd:316-319`). Payout = `_check_side_quests`
  (`game_base.gd:1557`), entered from `set_flag` (`:1505`).
- The `"chapter"` field gates accept (`game_base.gd:1865`), availability
  (`:1712`), expiry (`:1652`) and the journal (`ui/journal.gd:181/219/604`).
  `_check_side_quests` itself does NOT look at chapter.
- `_expire_side_quests` (`game_base.gd:1647`) runs ONLY on the victory
  path (`game_flow.gd:1019`). `replay_chapter` (`:66`) and `start_weekly`
  (`:90`) wipe without charging — an inconsistency Q9 closes.
- Kept across the wipe and local in co-op: `KEPT_FLAG_PREFIXES`
  (`game_flow.gd:631`) — one list feeds both `_wipe_chapter_flags` and
  `_flag_is_local`; `autotest.gd:5323` asserts on it.
- Content merge (`story.gd:1259-1274`): every table is dict-merge with
  overwrite, INCLUDING `WANDERERS` (keyed by chapter — a module adding one
  ch2 wanderer must re-list the whole ch2 pool, override-with-comment).
  Nothing lets a module add a PROP to an existing zone; Q2/Q5 worked
  around it ("Act 2 has no prop convos"). Q9 adds `ZONE_PROPS`.
- NPC defs gate only on `req_wanderer` (`game_world.gd:1009`). No
  follower/escort/pet primitive exists anywhere (greenfield). No title
  system, no silence system; cosmetics are `own_<kind>_<cls>_<id>` meta
  keys with no free-grant path (`game_flow.gd:427/478`).
- Standalone worlds: `Story.chapter()` (`story.gd:1284`) special-cases
  `capital`/`pvp_arena`; `is_standalone` is literally `id == "capital"`
  (`:1316`); `switch_chapter` admits on that (`game_world.gd:60`). The
  Vigils (DAILY_DUNGEONS.md) are NOT built — Interludes can't reuse them.

Build order (→ = hard dependency, ∥ = parallel-safe):
`Q8 ∥ Q9` → `Q10 ∥ Q11` → `Q12` → `Q14` → `Q15` → `Q13` → `Q16`.
Q9 is small and unblocks everything; land it first with one owner.

Owner decisions needed before the task they block (ask once, in a batch):
1. QUESTS_AND_SIDE_CHAPTERS §5.1 interlude exclusivity, §5.2 Moonfen's
   band-read boss, §5.4 the Voss fork — block Q13 / Q12.
2. DYNAMIC_WORLD §10.1-2, 6 (encounter XP, bandit loss penalty,
   frequencies) — block Q14. §10.5 the Hatless Man — Q15 content.
3. Q9: should replaying a chapter from the pause menu charge the abandon
   penalty like victory does? (Recommended: yes, logged quietly, no card.)
4. Q8: teaching beats on co-op HOSTS (recommended: yes, host only, guests
   never) and on dev/`--touch` runs (recommended: same rules).

---

## Q8 — implementation sketch (design above; OPEN, unclaimed)
Estimated: 1 agent-day. No new modules.

**Auto-equip (build first — the beats' closing line needs it).**
- `Player.auto_equip() -> int` in `player_core.gd`, next to
  `auto_synthesize()` (`:2794`) and shaped like it (loop, one `recalc()`,
  one `sfx`). Per `backpack` item: skip if `cls` lock mismatches or the
  special-gem rule would refuse (`equip()` refuses SILENTLY —
  `player_core.gd:2642-2660` — so pre-check, never call-and-hope).
  Empty slot → equip. Occupied → equip only on STRICT dominance: every
  key of `Items.stats_of(new)` ≥ the old piece's and at least one >,
  AND the old piece carries no socketed gems / `passive` / unique flag
  (a build might prefer it). `Items.diff_text` (`items.gd:2752`) renders
  arrows but decides nothing — write the dominance check beside it as
  `Items.strictly_better(new, old) -> bool` so the tooltip and the
  button agree.
- Button: category chip row beside `⚒ Auto-synthesize`
  (`menus.gd:2153-2162`), same size/tooltip idiom, ends with
  `open_inventory("gear", cat)`. Label copy passes the touch lint
  (`autotest.gd:2058` banned words). Float `"%d EQUIPPED"` / `"NOTHING BETTER"`.
- Test `_test_auto_equip()` beside `_test_equip_unequip` (`autotest.gd:3424`,
  copy its snapshot/restore): empty slots fill; a strictly worse piece is
  left; a sidegrade (one stat up, one down) is left; a gemmed equipped
  piece is never swapped; class-locked item skipped; returns the count.

**Teaching beats.**
- Gate helper `_onboard_due(step: String) -> bool` in `game_flow.gd`:
  `chapter_id == "ch1"`, `has_local_player()`, `not net_guest()`,
  `not get_flag("completed_ch1")`, `not menus.chapter_replay`
  (`menus.gd:28`), `not get_flag("tut_" + step + "_done")`.
- Fire point: `_room_cleared` (`game_flow.gd:1246-1247`), the bossless +
  `zi == cur_room` branch that already calls `_purge_fx()` — ch1's first
  combat room is zone index 2 (`story.gd:788`; indices are stable, only
  coords reseed), but gate on `room_type(zi) == "combat"` + the flags,
  not the index. Don't run the beat inline: set
  `pending_tutorial = "talents"` and drain it in `game.gd` beside the
  `pending_theme_note` drain (`:750-755`) using the FULL overlay
  composite from `game.gd:767` (that older drain omits `choices_active`).
- Talents beat: `hud.dialogue([["Elder Maren", ...]])` (one line, casual
  voice per the 08-18 ruling), then `menus.open_skills("talents")`.
  `skill_points` starts at 1 (`player_core.gd:76`) so the point is
  always there. `tut_talents_done` is set by `add_tree_point`
  (`player_core.gd:2962` already does this for `cap_q_talent_done` —
  mirror it) OR when the menu closes (skippable: closing counts).
- Gear beat: queued when `tut_talents_done` and `backpack` is non-empty
  (first drops land in that same room; if not, it waits for the next
  clear — the drain re-checks). Line + `open_inventory("gear")` with the
  hint text "or press Auto-equip"; `tut_gear_done` set by `equip()`,
  `auto_equip()`, or close.
- Flags: add `"tut_"` to `KEPT_FLAG_PREFIXES` (per-character persistent
  + co-op-local for free); update the assert at `autotest.gd:5323`.
  Per-hero, not account: a new hero is taught again (owner's wording).
- Touch copy via `game.control_hint` / `menus._hint(vbox, text, touch)`.
- Test `_test_onboarding()`: under a snapshot, assert `_onboard_due`
  is false on a guest / replay / completed_ch1 / done flag, true on a
  fresh ch1; drive the drain once and assert the flag lands and a second
  `_room_cleared` does not re-queue. Existing suite walks ch1 — the beat
  must not add a dialogue the autotest's room-clear path can't dismiss:
  gate on `not autotest` like the openers do, or dismiss in `test_ch1`.
- Mobile: sync after (touch_hud.gd is byte-identical; nothing to delta).

## Q9 — engine: quest verbs II + persistence + authoring seams (OPEN)
Estimated: 2 agent-days. One owner; everything else waits on (c)+(d).
Spec: DYNAMIC_WORLD §3.1-3.2; QUESTS_AND_SIDE_CHAPTERS §3.

a. **`hunt` step** — `{"kind":"hunt","target":<kind>,"name":"Old
   Greymantle","flag":...}` (optional `"affix"`). On accept
   (`_convo_node` side_quest branch, `game_base.gd:1862`) pick a room:
   seeded from `wander_seed + sid.hash()`, among combat rooms ahead on
   the spine that are unvisited and bossless; store
   `quest_hunts[flag] = room_idx` (new dict beside `quest_kills`, saved
   in the WORLD section at `save.gd:98-103` / restored `:526-529`,
   cleared in `_wipe_chapter_flags`). In `_enter_room` next to
   `_ensure_quest_quarry(i)` (`game_world.gd:862`): if `quest_hunts`
   names this room and no `hunt_flag == flag` enemy lives, spawn:
   `Enemy.make` → `promote_elite()` (`enemy.gd:1782`) → `display_name =
   name` → optional `Endgame.apply_affix` → `from_quest = true`,
   `force_aggro = true`, gold like an elite, `xp_value = 0`. New Enemy
   var `hunt_flag := ""`; `on_enemy_died` (`game_flow.gd:1141`) sets it.
   Nameplates already read `display_name` (elites show "Elite X"); the
   boss bar is not involved. Fallback: if every candidate room is
   visited, bind to the NEXT combat room entered (the quarry rule).
   Journal: "◇ Hunt: Old Greymantle — Howling Fields" (room name known).
b. **`timed` step** — `{"kind":"timed","rooms":6,"flag":...}`: the step
   is satisfied while the deadline holds; `quest_timers[flag]` counts
   down on FIRST entry of a room (`visited[i]` false) in `_enter_room`;
   at 0 → `_fail_side_quest(sid)`: sets `sq_failed_<id>`, applies the
   abandon charge via the `_expire_side_quests` math factored into
   `_charge_abandon(q)` (so victory-expiry and failure share one body),
   floater + log line. Journal card status `✗ FAILED`; `_active_side_count`
   excludes failed. Co-op: host-authoritative like kills.
c. **`persistent`/`scope`** — quest field `"scope": "chapter"`
   (default) | `"capital"` | `"world"`; helper `Story.quest_scoped(q) ->
   bool` (true = chapter-scoped). The five gates read it: accept
   (`game_base.gd:1865`) and availability (`:1712`) skip the chapter
   compare when unscoped; `_expire_side_quests` (`:1652`) skips
   unscoped; `_wipe_chapter_flags` (`game_flow.gd:654`) keeps
   `sq_on_/sq_paid_/sq_pledge_<id>` for any unscoped id, and unscoped
   quests must use `cap_`/`sq_kept_`-prefixed step flags (enforced by a
   `_test_quest_schema` assert); the journal gets `_scoped_section
   (m, list, scope, title)` used three times (SIDE QUESTS / CAPITAL /
   WORLD) and drops the deadline line for unscoped quests.
d. **`ZONE_PROPS`** — module const `{"ch2": {"Howling Fields": [npc
   defs]}}` merged in `load_content` (`story.gd:1271`) by zone NAME onto
   the matching zone's `"npcs"` (append; unknown name = push_warning +
   `_test_convo_integrity` failure). Lets a quest module drop a prop
   into an owner's room without editing the owner or appending zones
   (rules 3 + 4 above stay true). Document in `content/README.md`.
e. **NPC def gates** — `req_flag` / `req_not_flag` on npc defs beside
   `req_wanderer` (`game_world.gd:1009`): quest-gated props, interlude
   overlays and capital chain NPCs all need it.
f. **`add_standing(faction, delta)`** in `game_base.gd` next to
   `favor_add` (`:760`); fold the four inline writes (`:1575`, `:1667`,
   `:1854`; keep the replay resets at `game_flow.gd:68/91`).
   Key is `cinderborn`, not `cinder`.
g. **Abandon on replay/weekly** — call `_expire_side_quests()` in
   `replay_chapter` and `start_weekly` before the wipe, log-line only
   (owner decision 3).
h. **Reward `keepsake`** — `{"keepsake": {"kind":"chroma","id":...}}` →
   new `grant_cosmetic(kind, cls, id)` in `game_flow.gd` beside
   `buy_cosmetic` (`:478`): writes the `own_` meta key free, toasts,
   never touches Renown. Drop the proposed `beat` key: `kept` + an
   authored `@flag:` beat already does exactly that (`story.gd:1337`).
i. **Defer** `escort`/`defend`: escort needs the follower primitive
   (Q16); `defend` ships inside Q14 with the Caravan card (its first
   user) as `{"kind":"defend","waves":N}` over the loose-spawn pattern.
j. **Per-class plates** — mechanism is done; authoring only. Pick two
   class-refracted turn-ins (proposal: a paladin oath, a warlock debt)
   when Q10/Q12 add a quest that actually forks on `player.cls`.
Tests: extend `_test_quest_verbs` (hunt spawn in a fake room, timed
fail charges once, scope gates), `_test_quest_quarry` unchanged,
new `_test_quest_schema` (every SIDE_QUESTS entry: known kinds/keys,
unscoped ⇒ kept-prefixed step flags), journal smoke for the three
sections. Update `content/README.md` + `CODING_GUIDELINES.md §38` refs.

## Q10 — Chapter 2 slate (content; OPEN; needs Q9 d+e)
Estimated: 1.5 agent-days, one owner. Spec: QUESTS_AND_SIDE_CHAPTERS §1
(the retrofit it depended on IS merged: `ch2_zones_side.gd`, 10 rooms).
All in `ch2_quests.gd` (extend; it already overrides `ch2_refugee`,
`ch2_scholar`, `ch2_aldric`). Surfaces, verified:
1. **The Second Bell** — override `ch2_sentry` (`ch2_hub.gd:31`); bell
   prop via `ZONE_PROPS["ch2"]["Howling Fields"]`; BEATS
   `pre_stormwarden@flag:bell_heard` (promises_kept.gd pattern, :52-89).
2. **What the Cage Holds** — override `ch2_beastkin_cage`
   (`ch2_factions.gd ~:115`); listening prop = the existing
   `ch2_shrine_sporefall` Breathing Tree (`ch2_zones_side.gd:77`),
   appended gated choice. Truth/lie fork = `add_standing` + resonance.
3. **The Salt Reliquary** — override `ch2_choir_pilgrim` (`~:140`);
   prop `ch2_lore_reliquary` (`ch2_zones_side.gd:103`); courier shape
   (`QUEST_ITEMS.salt_token`); retroactive accept on the prop side.
4. **A Straight Answer** — extend the `ch2_scholar` override; logs prop
   via `ZONE_PROPS` in Null Bastion (`ch2_zones_act2.gd:70`, void);
   fork writes `chose_ivo_truth` (kept prefix, read by Q13 I1).
5. **The Ferryman's Due** — wanderer: re-list the ch2 pool
   (`ch2_zones_side.gd:163-167`) + `ch2_wander_ferryman` with an
   OVERRIDES comment; pilgrimage over three bog marks = `ZONE_PROPS`
   in The Drowned Race / Ferryman's Landing / Greyrun Mills; giver is
   `req_wanderer`-gated so the journal stays honest.
6. **Widow's Arithmetic** — extend `ch2_refugee` override, gated
   `req_flag: mill_seen`; ledger = appended choice on `ch2_mill`
   (`ch2_zones_act1.gd:39`); fork writes `chose_sera_page`.
7. **Arc step 2** — `QUESTS` strings `ch2_accord2`/`ch2_cinder2`;
   override recruiter convos `ch2_accord_recruit`/`ch2_cinder_recruit`
   (`ch2_factions.gd:20/~66`) appending gated choices behind
   `accord_arc1_done`/`cinder_arc1_done`; waypoints via `ZONE_PROPS`
   (Lee of the Stones + Drowned Race for the blight-line walk; the
   Echoing Gallery for the seal assay).
Rules: the suite asserts hub choice COUNTS on ch2 (Q2 note) — every new
choice sits behind `req_flag`/`req_not_flag` so index-0 walks are
unchanged; rewards stay in the §1 bands; one `kill` step at most where
the road is genuinely dangerous (Ferryman's bog, the Bastion).
Tests: extend `_test_ch2_quests` (chain arrays + bag snap/restore for
gems); `_test_convo_integrity` covers the overrides; full suite.
Illustrations: the cage fork + Ivo's fork are the two beats worth a
plate (canon refs: `splash_scholar_ivo`, the cage sprite); Codex lane.

## Q11 — capital engine + Layer 1 ward contracts (OPEN; needs Q9 c+f)
Estimated: 2 agent-days, one owner. Spec: QUESTS_AND_SIDE_CHAPTERS §2
Layer 1 + §3.
- **Module** `content/capital_quests.gd` (register in
  `Story.CONTENT_MODULES` after `capital_hub.gd`, `story.gd:1173`):
  `CONTRACT_POOL` per ward (`wildfang`/`choir`/`accord`/`cinderborn`)
  of `{type, target, desc, gold, favor_npc}`. Types are DEEDS the game
  already counts: `boss_kills` / `rooms_cleared` / `elite_kills` (the
  `bounty_progress` emitters, `game_flow.gd:919/1151/1238`) plus new
  emitters `salvaged` (`menus.gd` salvage action), `socketed`
  (`player_core.gd:2768` area), and a flag-check type
  `{"type":"flag","target":"<chapter prop flag>"}` (a courier step
  into live content, e.g. "lay flowers at a named prop").
- **State** mirrors bounties exactly: `contracts: Array`,
  `contract_day`, `contract_claims_day` on the character section
  (`save.gd:220` neighbours; list at `:399-403`); `refresh_contracts()`
  beside `refresh_bounties` (`game_base.gd:1190`) rolling
  `_roll_contracts(ward, Balance.WARD_CONTRACT_PER_WARD, day*2 +
  ward.hash() % 9973)` with the seeded Fisher-Yates at `:1233`.
  Contracts flip `done` on progress but PAY ONLY AT THE DESK (`claimed`),
  capped by `Balance.WARD_CONTRACT_DAILY_CAP` (4) account-wide per day.
- **Desk UI** — static module `scripts/ui/contracts.gd`
  (`UIContracts.open(menus, ward)`): list, claim buttons, "N/4 today".
  Wire: `_hub_action("contracts_<ward>")` (`game_world.gd:223`) — the
  hub file is GENERATED: add the four refs to `tools/content/
  gen_capital.py` `HUB_ACTIONS` (:32-45) + `LANDMARK_USES` (:204-207),
  regenerate, and update `capital_hub.gd`'s `known_actions` (:173), the
  city-map directory (`menus.gd:5376-5397`) and the autotest that
  asserts the four ● rooms point at `journal` (`autotest.gd:6877-6912`).
- **Pay** at claim: gold × `Balance.daily_gold_mult`, `add_standing
  (ward_faction, Balance.WARD_CONTRACT_STANDING=1)`, `favor_add
  (favor_npc, Balance.WARD_CONTRACT_FAVOR=5)` — new favor keys `kesh`,
  `suli` (only `petra`/`lapidary` exist today, `game_world.gd:420`).
  No Renown.
- **Balance block** `WARD_CONTRACT_*` between the abandon knobs
  (`balance.gd:2671`) and the daily block (`:2679`).
- **Journal** CAPITAL section (Q9c's `_scoped_section`) shows active
  contracts everywhere + any `scope: capital` quest; tab badge counts them.
- **Co-op:** per-character like bounties; progress local; desks exist
  only in the party town, which is fine.
Tests: `_test_ward_contracts` — same day same seed → same roll;
rollover rerolls; progress flips `done` without paying; desk claim pays
once; 5th claim refused; `daily_gold_mult` applied; all character
state, so snapshot/restore without `_meta`. Capital selftest: refs exist.

## Q12 — Layer 2 personal chains + Layer 3 "The Crown Below" (OPEN; needs Q11)
Estimated: 3 agent-days (content-heavy), one owner; can split chains
across agents ONLY by NPC (one module each: `capital_chain_<npc>.gd`).
Spec: QUESTS_AND_SIDE_CHAPTERS §2 Layers 2-3.
- **Migrate `cap_q_*`** onto the engine first: three `scope: capital`
  SIDE_QUESTS whose step flags ARE the existing `cap_q_<x>_done` flags
  (already set by `menus.gd:3366`, `player_core.gd:2768/2963`); accept
  via `"side_quest"` from `_cap_artisan_choice` / `_cap_drill_choice`
  convos (convert the code-built prompts in `game_world.gd:353-469` to
  CONVOS in the module; `cap_q_<x>_paid` becomes `sq_paid_`); delete the
  hand-rolled pay code; `CAP_ARTISANS` shrinks to greet strings.
  Mark the ❢ via `_mark_quest_giver` instead of `_mark_capital_npc`.
- **Rule for every capital chain:** step flags are `cap_`-prefixed
  (kept + local), set by gated choices on props in live chapters (Q9e
  `req_flag` on the prop def, Q9d `ZONE_PROPS` where the room has no
  prop). Retroactive accept where a player may have seen the prop first.
- **Chains** (one 3-step each, `req_flag` on act progress =
  `completed_ch7` until Act 2 exists; favor-tier gates need a new
  `req_favor: {"npc":..,"tier":N}` choice gate beside `req_band`,
  `game_base.gd:1834`):
  Petra "A Blade Worth Naming" (final step writes `cap_petra_elara`);
  Old Fenna "Names of the Fire" (three grave props across ch3/ch5/ch6,
  ends in a STORY-tab memorial page = one `log_story_line` block);
  Clerk Voss "The Alms Ledger" (Voss has NO convo today — add
  `cap_voss` in gen_capital.py; fork writes `cap_voss_kept`; the
  "colder clerk" = a convo variant on that flag, not an NPC swap, v1);
  Marshal Corin "The Drill Yard" (Corin has no convo either; drills =
  loose-spawn waves in the plaza using Q14's `defend` step — schedule
  after Q14 or ship as two talk-steps first);
  Nix "What the Tankard Hears" (weekly rumor = convo `variants` keyed
  on a transient `weekly_is_<chid>` flag set in `refresh_bounties`'s
  week rollover — not kept, recomputed);
  ward leads ×4 (Callis/Ilse/Maren/Aldric+Vessa), final steps write
  the Act-2-read kept flags named in §2.
- **The Crown Below**: v1 ships step 1 only (Act 1 clear) + the sealed
  Undercroft door landmark in the Sable Court; steps 2-5 are gated on
  chapters that don't exist yet — leave the flags named, not authored.
Tests: `_test_capital_quests` — chain flags survive `_wipe_chapter_flags`
and a `replay_chapter` cycle; the journal CAPITAL section lists them
from inside ch3; `cap_q_*` migration: a save with the OLD flags still
reads as done (same flag names, so this is a no-op assert).
Codex: NPC section entries for Voss/Corin once they gain convos (the
`npcs` shelf reads convos). Illustrations: Petra's final step (canon
`splash_smith_petra`) and Fenna's memorial are the two plates.

## Q13 — Interludes I1 Undercroft + I2 Moonfen (OPEN; needs Q12 step 1 + owner decisions 1)
Estimated: 5+ agent-days each incl. art; one owner per interlude after
a shared engine slice. I3/I4 are blocked on Act 2 — do not start.
Spec: QUESTS_AND_SIDE_CHAPTERS §4.
**Engine slice (shared, ~1 day):**
- Generalize standalone: `Story.STANDALONE: Dictionary` filled from
  modules' `CHAPTER` const (new merge line at `story.gd:1259`);
  `chapter()` (`:1284`) and `is_standalone()` (`:1316`) read it;
  `switch_chapter` admission (`game_world.gd:60`) then just works.
  Audit the other `is_standalone` readers: lobby-open rule
  (`game_world.gd:82`), `shop_markup` (`game_base.gd:720`),
  `chapter_parity_level` (`story.gd:1301` — interludes DO have a
  `final_boss`; keep them out of `CHAPTER_LIST` so chapter select and
  `advance_chapter` never see them).
- Finale routing: `on_boss_died` → `victory_dismiss` (`game_flow.gd:194`)
  branch on `is_standalone` → set `completed_<id>`, fire `epilogue_<id>`
  beats, return to the capital (the endgame run-end pattern,
  `menus.gd:816-824`), never `advance_chapter`. Zones' enemies authored
  with xp 0 (6th positional field, `content/README.md:76`); gold/gems
  on the replay law via `loot_cap`.
- Entry: `_hub_action("portal_interlude")` bound with the id from a
  capital landmark use (gen_capital.py); locked until the unlock flags
  (`I1`: Crown Below step; `I2`: `completed_ch7` + wildfang ≥ 2 via a
  new `req_standing` use-gate) — sealed-portal visual = `_seal_portal`
  (`game_world.gd:190`).
- Journal WORLD section (Q9c) lists unlocked interludes + their
  `scope: world` quests; the replay row lives there, not in chapter select.
- Divergence = overlays, never two builds: `@flag:` beats, convo
  `variants`, Q9e `req_flag` NPC defs, per-sponsor SIDE_QUESTS gated on
  `joined_accord`/`joined_cinderborn` (I1) and `chose_kaethra_*` (I2).
**Per interlude:** `content/interlude_<id>.gd` (CHAPTER 8-12 zones with
coords + spine, ENEMIES incl. the boss, BEATS, CONVOS, SIDE_QUESTS,
WANDERERS) + `Menus.BOSS_KINDS` row (`menus.gd:5613`) + codex boss/
terrain entries (terrains auto-list via `Terrains.catalog_ids`, but
promote the `ph_*` profile: `preview_isolated` off, `AMBIENT_LOOPS`/
`WALL`/`WALL_TINT`/`LANDMARK_POOLS` rows). I1 uses `ph_sewer`/`ph_crypt`
(exist, `terrains.gd:423/489`); I2 needs a NEW `ph_moonfen` (base it on
`ph_fae`, `:433`). Boss mechanics that are new engine: Archivist's
*Redaction* = `player.locked_slot` honoured by the ability dispatch in
`player.gd` (+ HUD slot dimming); First Howl's band read = on spawn,
`Story.res_band(player.resonance)` picks a speed/dmg variant +
`Balance.FIRST_HOWL_TEMPTED_GOLD` (+10%). Art: boss body + splash
(Codex lane; PixelLab only with explicit authorization), terrain
props from the ph_ gallery, 1-2 Future-tab adoptions.
Tests: module selftest (spawns the boss, drives the signature);
autotest plays the interlude end to end (`tests/test_ch2` harness
pattern: enter from capital, walk spine, kill boss, assert
`completed_<id>` + back in capital + replay re-entry); room-count
asserts untouched (not in CHAPTER_LIST); co-op: entry blocked online v1
(interludes swap worlds like endgame — `enter_endgame`'s `net_online()`
guard, `game_flow.gd:842`).

## Q14 — Road Deck v1 (OPEN; needs Q9 a; owner decisions 2)
Estimated: 3 agent-days. Spec: DYNAMIC_WORLD §4 (cards 1,2,3,4,6 in v1;
card 5 The Cage waits for Q16's follower; 7/8/11 ride Q15/Q16).
- `content/road_deck.gd`: `CARDS` (convo id, `req_flag`/`req_band`/
  `req_class`, follow-ups by mark, room filter), `Balance.ROAD_DECK_*`
  (curve 0.70/0.25/0.05, never ch1 first run).
- Draw in `_prepare_rooms` (`game_world.gd:666`) from `wander_seed`
  (co-op rebuilds from the seed — no `randf()`); bind to non-boss,
  non-safe spine rooms; store `road_deck: {room_idx: card_id}` in the
  WORLD save section beside `quest_kills`; marks are run flags `rd_*`
  (a few `chose_`-prefixed persist).
- Materialize on first `_enter_room` via the `_offer_cursed_chest`
  pattern (`:1296`): `run_convo_id(card.convo)`. Verbs are existing
  choice keys + four `hub_action`s: `spawn_pack`, `spawn_hunt` (Q9a's
  spawner with a name), `defend_waves` (the `defend` step, built here:
  N seeded waves off the loose-spawn pattern, zero XP, prop HP bar,
  fail = prop destroyed flag), `wager` (seeded roll, gold/gem stake —
  the minigame upgrade lands in Q16).
- Caravan's "burned camp" = a `merchant_zones` edit for this run
  (`save.gd:103` field exists); Bridge Out = `edge_locks` `flag:` lock
  on a side edge (`:724`), repair choice = `gold` key / a Professions
  material `lose_item`.
- Codex **Encounters** section (one `UICodex.SECTIONS` row + `_rows`/
  `_detail`, met cards only) + journal WORLD "Encounters" lines +
  results card counter beside "secrets".
Tests: `_test_road_deck` — seed determinism (same seed same bindings),
curve bounds over N seeds, never boss/safe/ch1-first, a card's
follow-up draws when its mark is set, `defend` fail path, Toll's
`lose_item` on a carried quest item. Re-run `econ_audit.gd`.

## Q15 — The Unlisted + portal-stone pockets (OPEN; needs Q14)
Estimated: 3 agent-days. Spec: DYNAMIC_WORLD §5 (Tithe-Collector,
Greymantle) + §6 (Molten Court, Still Larder).
- **Unlisted**: `content/unlisted.gd` roster; `_unlisted_inject(zones,
  chid)` modelled on `_waking_inject` (`game_world.gd:649`, returns a
  NEW array) appending `{type:"boss", boss: kind, unlisted: true}` on a
  seeded 1-in-N from `wander_seed`; tells = `@flag:`/variant lines on
  the preceding room's convo (the Toll's bandits for the Collector; the
  Footprints card for Greymantle). Kits reused + `Endgame.apply_affix`
  + `display_name` (`game_world.gd:3631-3641` pattern); NOT `story_boss`;
  banks once per run via an `unlisted_banked` list (the
  `waking_banked` shape, `game_base.gd:377-384`). Persistent refuse
  counter: flags `chose_toll_refused_1/2` (kept prefix; no counter
  type exists). `Menus.BOSS_KINDS` + codex bosses + lore kill counts.
- **Pockets**: `content/pockets.gd`; `_pocket_inject` appends 3-4 zones
  attached off the stone's room behind an `edge_locks` `flag:portal_<id>`
  lock (`game_world.gd:724`), hidden on the map until entered; stone =
  npc def `action: "portal_pocket"`; last room's boss kill opens a
  return stone → `fast_travel(origin)` (`:1594`). Twist rules = one flag
  each read by an existing system (`no potions` → a `potions_locked`
  gate in the potion path; `floor tithes` → a terrain event). Host arms
  via `_host_ensure_active_rooms` (`:851`); guests rebuild from seed.
  Relic keepsake = Q9h `keepsake` reward.
Tests: inject determinism; an Unlisted room never spawns on the spine
or in ch1 first run; pocket rooms hidden until the lock lifts; return
stone lands in the origin room; banked-once. Codex rows present.

## Q16 — pets, minigames, the follower primitive, eggs (OPEN; last)
Estimated: 4 agent-days. Spec: DYNAMIC_WORLD §7-8.
- **Follower primitive** (greenfield; unlocks `escort`, the Cage card,
  and pets): `scripts/follower.gd` Node2D under the world, lagged lerp
  to the local player, re-parented across rooms in `_enter_room`
  (enemies leash per `zone_idx`, `enemy.gd:1151`; a follower is not an
  Enemy), no collision, half-scale mob sprite. Wire: equipped pet id in
  `peer_chars` so guests draw it (MONETIZATION_SPLIT's requirement).
- **MiniGame contract** `scripts/ui/minigame_*.gd`: `start(cfg) →
  finished(win)`, input-gated on the overlay composite (`game.gd:767`
  — the tree does NOT pause online); tic-tac-toe (minimax + one blind
  spot), shells; `wager` hub_action upgrades from Q14's seeded roll.
- **Stable** UI (wardrobe pattern) + codex Companions section; The
  Stray card (deck #11) + `escort` step kind landing on the follower.
- **Eggs** that are nearly free and can ride ANY earlier task: #1 the
  boy grows up (`sq_kept_`-gated ch7 recruit line — the hat quest
  currently pays no `kept`; add `sq_kept_hat`), #2 Nix greets other
  heroes (account `_meta` character names), #3 "Emberfall" wall
  (`_inspect_landmark` + a kept flag), #10 the mustache counter.
Tests: follower survives a room change and a chapter replay; minigame
can't receive input under a menu; Stable equip replicates (net test
pattern); egg flags.

---
Cross-cutting for every task: compile gate → `test_quick` → full
`test.bat` → `preflight.bat` → `git add` (path-scoped; commit only when
the owner asks); codex updated in the same change (CLAUDE.md); mobile
re-sync (`sync_mobile.py --apply --gate`) after the tree is committed;
new tuning numbers go in `balance.gd`, never inline; casual dialogue
voice (ruling 2026-08-18); any plate through the Codex lane with canon
sprite + splash as the design ref.
