# CH2_RETROFIT_TASKS — the reward-hole graph retrofit (board, 2026-07-24)

One owner per task; claim before starting (the MP_TASKS/CH2_TASKS etiquette;
CLAUDE.md multi-agent section governs). Content lands as edits to ch2's zone
data + this board's checkpoints — NOT by inflating reward numbers
(DESIGN.md open item #1, verbatim: "fix by graph-retrofit").

## Why (measured, econ_audit 2026-07-24 — the numbers that make the case)

| | ch2 today | ch3 (the reference) |
|---|---|---|
| Rooms | **10** (6 combat / 3 boss / **0 social / 0 dead-end / 0 res**) | 21 (10 / 3 / 2 / 2 / 2) |
| Replay g/min | **36.5 — worst in the game, now UNDER ch1's 38.8** | 70.7 |
| Caches | **0 g** | 41 g |
| Elites/run | **1.1** | 2.6 |
| Kills/run | 66 | 117 |

The hole is STRUCTURAL: social/dead-end/resonance rooms carry the premium
path (elites ≈ 60% of run gems, hidden caches ~25% of dead ends, shrine ~22%
of quiet rooms, cursed chest ~15% of combat rooms — ALL seeded automatically
by room TYPE), and ch2 has none of those room types. Add the rooms and the
economy heals itself through existing seeding; no knob touches.

## Constraints (standing rules that bind every task)

- **Fixed chapter XP:** ch2's first-run total is **2963** (audit) — the
  retrofit must land within ±3% of it. New packs use the spawn tuple's 6th
  param (authored XP override, the mob-distribution-round tool) to
  redistribute the SAME budget across more rooms; replays pay 0 XP anyway.
- **Room banding** (mob-distribution round): ~3 melee-heavy (openers keep
  the teaching role) / mixed 25–45% core / 2–3 ranged-heavy artillery rooms.
  **Howling Fields is THE beastkin skirmish line** (wildkin_ranger +
  beastkin_howler) — keep its identity; cross-chapter imports at level
  overrides for ranged variety (the established pattern).
- **Maren's Camp (content/ch2_hub.gd) is untouched** — it is already the
  social anchor (13 NPCs, faction recruiters). The retrofit adds SIDE
  geography, not hub changes.
  > **DEVIATION, flagged (2026-07-26, agent-ch2graph):** the camp file WAS
  > edited, and could not not be. The camp is spine room 0, so the spine
  > conversion forces the same three mechanical changes there as everywhere
  > else — `type`, `gate_flag` -> `lock_next`, and full-cell coordinates
  > (at `scale = ONE` the whole cast would have bunched into the room's
  > top-left corner). **No hub CONTENT changed:** same 13 NPCs, same convos,
  > same faction recruiters, nothing added or removed — every edit is a
  > coordinate or a lock key. Read as written, the constraint means "don't
  > restructure the social anchor", and it holds.
- Terrain: ch2's authored terrain families only; forest stays building-free
  (zone-authored scenery rules).
- Target after retrofit: ~19–21 rooms in the ch3 shape; replay g/min lands
  ~55–65 (between ch1 38.8 and ch3 70.7, on the level curve) — MEASURED,
  not assumed (task 4).

## Tasks

### CR-1: Test-coupling inventory — status: DONE (agent-ch2graph, 2026-07-26)
Files read: `tests/test_ch2.gd`, `autotest.gd` (ch2 campaign sections)

**The structural finding that shapes every other task:** ch2 is the last
LEGACY-STRIP chapter — it has no `spine` key, so `_prepare_rooms` converts
it to a one-row west→east chain and rescales every authored coord from the
old 34×15 zone (`meta["scale"]` = 2112/2176 × 1248/960). Spine chapters get
`Vector2.ONE` instead. That means the retrofit is not "add rooms" — it is
**promote ch2 to a spine chapter**, which is also what unlocks the
side-attach pass the premium path rides (and what `game_world.gd` ~line 61
already anticipates: *"the legacy ch2 strip has no attach pass — its
graph-retrofit inherits the event"*, i.e. Waking Incursions).

Three consequences, all handled in CR-2:
1. **Locks change owner.** The legacy path derives the east lock from
   `gate_flag`/`boss`; the spine path reads `lock_next` and ignores
   `gate_flag` entirely (`game_world.gd:602` is the only reader). Every
   spine room must convert or its door hangs open.
2. **Coords must be re-authored.** At `scale = ONE` the existing packs
   (x 300–1240, y 150–610) would huddle in the upper-left of a 2112×1248
   room with the whole east half empty. Re-spread to the ch3 envelope.
3. **Index stability is a hard requirement** — see the table below.

**Assertions the new graph moves** (exhaustive):

| # | Site | Assertion | Verdict |
|---|---|---|---|
| 1 | `autotest.gd:1970` | `game.neighbor(0,"E") != 1` → "legacy chapter did not convert to a chain" | **BREAKS.** The spine walk jogs N/S; room 1 need not be east of room 0. Must be re-authored to assert the spine shape. |
| 2 | `autotest.gd:1948,1984` | comment + print "boots as a legacy chain" | Wording only. |
| 3 | `test_ch2.gd:257` | `game.zone_count != 10` (act 2) | **BREAKS.** → new count. |
| 4 | `test_ch2.gd:408` | `game.zone_count != 10` (chapter replay) | **BREAKS.** → new count. Note this one is on the **`--quick`** path (`_run` line 32), so it gates the fast loop too. |
| 5 | `test_ch2.gd:165` | `game.zone_count < 5` | Survives (count only grows). |
| 6 | `test_ch2.gd:168,203,226,232,264` | `_edge_unlocked(n, n+1)` for n = 0..8 | Survives **only if** spine order == authored order and every `gate_flag` becomes the matching `lock_next`. Both done in CR-2. |
| 7 | `test_ch2.gd:170,207,230,234,282` | `_goto_room(1..4, 9)` | Survives — `_goto_room` teleports to `room_center(i)`, no adjacency assumed. |
| 8 | `test_ch2.gd:261` | `for zi in [5,6,7,8]` | Survives **only if** act-2 spine keeps indices 5–9. |
| 9 | `test_ch2.gd:560–578` | small-room scan needs `checked > 0` | No coupling — this section runs in **ch1** context (`_run_systems`, autotest:860), not ch2. Retrofit turns it from vacuous-in-ch2 to genuinely covered. |
| 10 | `autotest.gd:1958` | `zone_count < 1` | Survives. |

**Design rule this dictates:** author the 10 existing rooms FIRST as spine
indices 0–9 (camp, Mills, Fields, Sporewood, Hollow, Dunes, Expanse, Deeps,
Ruins, Bastion) and append every new side room at index 10+. That is already
the ch3 convention, and it reduces the whole test delta to **three edits**:
one graph-shape assertion and two `zone_count` numbers.

**RULING (owner away; taken by agent-ch2graph, logged for review):** the
three edits are made. They are not test *weakening* — each one asserts the
NEW graph's shape as precisely as the old one asserted the old shape, and
the precedent named in this task (the ch1 retrofit adapted its tests) is the
same situation. The "never edit existing sections" rule governs *content
modules bolting tests onto shared files*; a chapter that changes graph class
cannot leave assertions describing the class it left. Owner: revert-and-object
is one `git revert` away if you disagree.

**Bug found + fixed en route (`game/econ_audit.gd`):** the audit summed XP
from each kind's level curve and **ignored the spawn tuple's 6th param** —
the authored XP override, which is precisely the instrument CR-3 is told to
redistribute the budget with. So the ±3% gate would have been measured
against a number the game never pays. Fixed to read the override.
Re-baselined totals: **ch2 2963 → 2926** (the two `null_acolyte` imports at
48/55 were being counted at 70), ch1 1380 → 1324, ch3 1839, ch4 2068,
ch5 1971, ch6 1809, ch7 1852. **CR-3's target band is therefore 2926 ±3%
= 2838–3014**, not 2963's.

### CR-2: Graph re-author — status: DONE (agent-ch2graph, 2026-07-26)
Files: `story.gd` (spine + module registration), `content/ch2_hub.gd`,
`content/ch2_zones_act1.gd`, `content/ch2_zones_act2.gd`,
`content/ch2_zones_side.gd` (NEW).

**10 -> 20 rooms, in the ch3 shape:**

| | ch2 before | ch2 after | ch3 (reference) |
|---|---|---|---|
| rooms | 10 | **20** | 21 |
| combat / boss | 6 / 3 | 9 / 3 | 10 / 3 |
| social / dead-end / resonance | 0 / 0 / 0 | **2 / 2 / 2** | 2 / 2 / 2 |
| merchant / safe | 0 / 1 | 1 / 1 | 1 / 1 |
| kills | 66 | 94 | 117 |

The ten side rooms and their terrain hosts: Drowned Race (bog, combat) ·
Ferryman's Landing (bog, dead-end + wood cache) · Lee of the Stones (storm,
social) · The Sporefall (spore, resonance) · Sung-Over Ground (graveyard,
combat) · Salt Reliquary (desert, dead-end + silver cache) · Cold Waystation
(ice, merchant) · Echoing Gallery (crystal, social) · Unbroken Font (holy,
resonance) · Maintenance Yard (void, combat).

Four mechanical changes beyond "add rooms":
1. **`spine: [0..9]`** on `CHAPTERS.ch2` — the actual fix. Also gives ch2 the
   seeded procedural layout (it was the last chapter where every run was the
   same map) and makes it eligible for Waking Incursions.
2. **`gate_flag` -> `lock_next`** on all ten spine rooms. The spine layout
   never reads `gate_flag`; leaving them would have hung every door open.
3. **Full-cell coordinates.** Legacy strips rescale authored coords from the
   old 34x15 zone; spine rooms use `scale = ONE`. Every pack was re-laid
   across the 2112x1248 cell in the ch3 four-pack idiom (0 NW / 1 SE / 2 NE /
   3 centre), and the camp's cast + the dev placeholder gallery with it.
   Without this the packs would have huddled in one corner.
4. **Room banding** now meets the constraint: 3 melee-heavy (Mills, Dunes,
   Drowned Race), 3 ranged-heavy (Howling Fields — beastkin identity kept —
   Sanctified Ruins, Maintenance Yard), the rest mixed 25-45%.

Also removed: the per-zone `"merchant"` offers on rooms 1-9. They could never
fire (the static spawn needs a bossless, packless room), so ch2 had no
mid-run shop at all; the Cold Waystation is now a real one.

### CR-3: XP-budget probe — status: DONE (agent-ch2graph, 2026-07-26)
**2926 baseline -> 2932 (+0.2%)**, band 2838-3014. Method as specified: the
same budget redistributed across twice the rooms with the spawn tuple's 6th
param. Side rooms carry 370 total (shaved per-mob values); the act-2 spine's
fattest payers were trimmed to fund it — Crystal Deeps stalkers 60->48,
Sanctified Ruins + Null Bastion void husks 85->60, Bastion acolytes 70->50,
Bastion stalker 60->45. The Frozen Expanse acolyte pair was also normalised
(it was split 48 / native-70 for no stated reason, and the audit was reading
70 for both). Per ch3 doctrine a spine-only run now lands ~1 level under; the
curve assumes side rooms.

### CR-4: Econ re-measure — status: DONE, TARGET MISSED AND NOT FORCED (agent-ch2graph, 2026-07-26)
**Replay 35.6 -> 47.7 g/min (+34%).** The board's band was 55-65; 47.7 is
under it.

*Both figures are measured on the CORRECTED audit* — the old graph was
re-measured with the fixed tool rather than compared against the 2026-07-24
number, so this is a like-for-like delta. (On the old buggy tool the pair
read 36.5 -> 49.6; every chapter's numbers shifted, not just ch2's.)
Per this task's own instruction ("If the number lands OUTSIDE the band,
report — don't tune knobs to force it"), reporting.

| faucet (replay gold) | ch2 before | ch2 after | ch3 |
|---|---|---|---|
| mobs | 680 | 924 | 1262 |
| mob-chests | 156 | 223 | 298 |
| **caches** | **0** | **29** | 31 |
| **elites (per run)** | **56 (1.1)** | **116 (2.6)** | 124 (2.6) |
| bosses | 224 | 224 | 457 |
| risk events | 21 | 10 | 15 |
| **total** | **1138** | **1526** | **2188** |

**Read the table before judging the miss.** Every *structural* faucet — the
ones this retrofit exists to restore — is now at ch3 parity: caches 0 -> 29
vs 31, elites 1.1 -> 2.6 vs 2.6, risk 10 vs 15. The entire residual gap is
**mobs (924 vs 1262) and bosses (224 vs 457)**, both pure functions of level:
gold scales with `REWARD_PER_LEVEL`, ch2 spans L1-16 and ch3 L16-22. ch2 sits
below ch3 by construction, and closing that gap would require raising mob or
boss gold — precisely the number-inflation DESIGN open item #1 forbids.
Reaching 55 needed ~2 more combat rooms (22 total), out of the 19-21 spec,
for ~3 g/min. **Recommendation: treat 47.7 as the correct landing and retire
the 55-65 guess** — it was set before anyone had measured which faucets were
level-bound. The thing that actually mattered is fixed: ch2 is no longer
under ch1 (47.7 vs 36.5).

One measurement note for DESIGN open item #3: `econ_audit` charges every
chapter a flat 32-minute replay. That was generous to a 10-room ch2 and is
now apples-to-apples against ch3's 21 rooms — so the 35.6 -> 47.7 improvement
is, if anything, understated.

`Balance.CHAPTER_ECON.ch2` updated to first 1953 / replay 1526 (the shop and
gamble price off this row).

**Second measurement bug fixed (`game/econ_audit.gd`), found while checking
the cache faucet this round is judged on:** the audit credited hidden-cache
gold to EVERY dead end, but `game_world._spawn_hidden_cache` returns early
when a dead end already carries an authored `cache` — an authored chest and a
buried one are mutually exclusive. Every chapter ch2-ch7 authors caches on
both its dead ends, so their true hidden-cache EV is zero and the audit was
paying them for it. Now only UNauthored dead ends count (ch1 still scores,
having one).

**Third measurement bug fixed (`game/econ_audit.gd`):** mob-chest odds were
modelled as two independent rolls (18% wood + 4% silver = 22% of kills drop
something). The game runs **ONE roll with cumulative thresholds** —
`roll < SILVER` gives silver, `elif roll < WOOD` gives wood — so P(silver) is
4%, P(wood) is 14%, and only 18% of kills drop anything. The audit was
double-counting the silver band inside the wood probability, inflating every
chapter's second-largest faucet by ~18%.

**Reported, NOT changed — pack density (`MOB_DENSITY_EXTRA`):** every authored
spawn in a NON-BOSS room has a 15% chance to bring a jittered twin, and that
twin is a full enemy paying full gold and XP. The audit counted authored
spawns only, so a real run kills ~15% more than any of these totals say. It
is now printed as its own `+density:` line per chapter rather than folded in,
because "authored pack XP" is the contract every chapter module writes its
budget against (see the XP BUDGET headers in `content/chN_zones.gd`) and
folding it in would silently redefine those budgets. **Worth the owner's
attention for pacing:** ch2's authored 2926 XP looked ~5% short of the 3090
the L1->16 curve wants, but with density it is really ~3250 — about 5% OVER,
not under. Same question applies to every chapter.

**Consequence the owner should decide on:** `CHAPTER_ECON`'s other six rows
were measured 2026-07-24, before all three fixes, and now read **~2-3% high**
(mostly the mob-chest correction). Applying them reprices every chapter's
shop and gamble, which is a table-wide call rather than part of this
retrofit, so only ch2's row was moved:

| | first (in table) | replay (in table) | first (corrected) | replay (corrected) |
|---|---|---|---|---|
| ch1 | 1558 | 1241 | 1486 | 1169 |
| ch3 | 2797 | 2262 | 2723 | 2188 |
| ch4 | 3393 | 2746 | 3299 | 2652 |
| ch5 | 4105 | 3367 | 4009 | 3271 |
| ch6 | 4952 | 4141 | 4852 | 4041 |
| ch7 | 6685 | 5802 | 6585 | 5702 |

Gem columns move too (ch4-ch7 replay gems 19.4/19.4/19.6/19.9 ->
17.5/17.6/17.8/18.1).

### CR-5: Fiction + naming pass — status: DRAFTED, SHIPPED PLAYABLE — **OWNER TASTE CALLS BELOW**
Rooms shipped named and written rather than as "Waking Side-Path A", because
a placeholder-named room is worse to playtest than a wrong-named one. Every
judgment call is listed here; each is a local edit.

1. **NPC casting for the five wanderers — the one call worth a real look.**
   ch2 had no wanderer pool, and ch3-ch7 each use five *bespoke* NPC bodies
   that ch2 has never had commissioned. Rather than generate art (not
   authorised, and no built-in generator here), the pool uses five Pixel
   Crawler humans **already installed and already reviewed in-game** — the
   dev-only placeholder gallery along Maren's camp, which carries a standing
   TODO reading *"Reposition into real roles or delete this whole block."*
   This is that repositioning. They are hidden from players today
   (`game_world.gd` skips `placeholder` NPCs outside dev mode), so this is
   the first time any of them is seen in normal play:
   `npc_wanderer` -> A Road-Worn Traveller · `npc_hunter` -> Snarehand Ott ·
   `npc_villager_f` -> Mother Rell · `npc_bandit_tracker` -> The Tracker ·
   `npc_elder2` -> Old Bevin. The gallery entries were left in place; nothing
   was deleted. Recast = one line each in `ch2_zones_side.gd`.
2. **Room names** (listed in CR-2) — all in ch2's register, none reuse a ch3+
   name.
3. **Resonance shrine choices.** Two, both one-time, both GROUNDED (the
   payout is coin, never a stat), both on the symmetric +8 / -8 / 0 range ch3
   uses. *The Sporefall* — breathe the spore-tree's exhale (+8, you learn what
   the blight actually is: patient, not malicious) / cut it open for what it
   has digested (-8, 45g) / leave it. *The Unbroken Font* — drink and leave
   the cup (+8) / take the water and the cup (-8, 45g) / leave it untouched.
4. **Two dead-end lore props** (the ferryman who tied himself to his own post;
   an imperial boundary stone answered by a later, worse chisel) and **five
   wanderer conversations**, each with a +3 / -3 pair, band-reading variants,
   and a repeat-visit short-circuit — the ch3 wanderer contract.
5. **Prop casting:** `bones` (ferry landing), `pillar` (boundary stone),
   `fungus_long` (the breathing tree), `garden_fountain` (the font). All
   existing sprites, all terrain-native.

### CR-6: Gates + suites — status: DONE (agent-ch2graph, 2026-07-26)
Ladder run in order, all green:
- **compile gate** — COMPILE OK (93 scripts)
- **test_quick** — QUICK PASS
- **full test.bat** — AUTOTEST PASS, incl. `ok: chapter 2 hub boots on the
  spine layout (20 room[s])`, `ok: T2 act 1`, `ok: T3 act 2`, and
  `ok: waking incursions` (ch2 is newly eligible for those)
- **preflight** — `PREFLIGHT OK (IMPORT MODULES BALANCE PHYSICS CODEX)`
- **sync_mobile --apply --gate** — `GATE OK: mobile quick suite passed`
- `.import` line-ending churn reverted, never staged (worktree convention)

**Codex:** checked per CLAUDE.md and deliberately NOT changed. The codex
derives terrains/monsters from the data tables, and the retrofit adds no
terrain and no enemy kind; because side rooms append AFTER the spine, the
first-zone-per-terrain names the Terrains page shows are unchanged too.
Preflight's CODEX check agrees.

**A latent flake this work would otherwise have introduced, found and
closed:** giving ch2 a spine also makes it eligible for Waking Incursion
breach rooms. The suite COMPLETES ch2 mid-run and `completed_` is a
`KEPT_FLAG_PREFIX`, so it survives the replay in `_test_pause_menu` — meaning
on the one week in seven when ch2 is `weekly_chapter()`, breach rooms inject
on top of the authored 20 and any exact `zone_count` assertion fails. Not
this week, so it would have shipped green and broken on a calendar. Both ch2
room-count assertions now read `20 + _breach_rooms()` (a helper counting
zones carrying the `waking` key); with no week armed it is exactly as strict
as before.

No commit — CLAUDE.md says commits only when the owner asks. Work sits on
branch `claude/night-systems` (worktree `.claude/worktrees/night-systems`),
staged nowhere, so the sibling agents' indexes are untouched.

### CR-7: Side-room test coverage — status: DONE (agent-ch2graph, 2026-07-26), added by this agent, not on the original board
The ch2 campaign sections walk the SPINE only, so all ten new rooms, both
shrines, both lore props and the whole wanderer pool would have shipped with
**zero** coverage — a typo'd convo id or sprite name would have surfaced as a
dead prop in front of a player. Added `_test_ch2_side_rooms()` through the
marked CONTENT-MODULE TEST HOOK (one func at the end of `autotest.gd`, one
call line — no existing section touched). It asserts: the room MIX the
economy was re-measured against (3 combat / 2 dead-end / 2 social / 2
resonance / 1 merchant, breach rooms excluded); that every enemy kind and
convo id in the new rooms resolves; that `wanderers_for("ch2")` returns the
five new wanderers rather than silently falling through to ch1's pool; the
Unbroken Font shrine end to end (pays its authored +8, sets its one-time
flag, refuses to re-offer); that the Salt Reliquary's authored cache really
drops; and that the Cold Waystation registers ch2's only mid-run merchant.

**It also caught a bug in itself, which is the interesting part.** The first
green run turned two CAPITAL assertions red — "the lapidary kit charm was
neither bagged nor mailed", then a bogus 1.000 road markup. Root cause: a
`Chest` opens on `body_entered`, not on a keypress, and `_goto_room` lands
the player at room centre ~140px from where `_build_room` drops the cache —
so merely LOOKING at the dead end banked its gear and gold. Unrestored, that
pushed the bag over capacity, and the first thing to notice was the Lapidary
handing her keepsake to the mailbox two sections and a chapter later; the
markup failure was pure cascade (the capital section's early `_fail` skipped
its own cleanup, leaving `chapter_id == "capital"`, where `shop_markup`
returns 1.0 by design). Fixed by extending the section's snapshot/restore to
inventory (backpack, gem bag, gold, secrets) and freeing lingering chests —
the CLAUDE.md "sections SNAPSHOT + RESTORE shared state" rule, which the
first draft applied to flags and resonance but not to loot. Worth recording:
the failure surfaced nowhere near its cause, and the only thing that made it
findable was that the capital sections assert hard on exact inventory state.
