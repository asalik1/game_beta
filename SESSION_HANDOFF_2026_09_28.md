# Crownless — September 28 session handoff

Owner-authorized orchestrator round on `codex/crownless-wayfinder`
(`C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder`), 2026-09-28 from 07:00 UTC, before
the 21:00 UTC (17:00 America/New_York) deadline. Starting HEAD `1282013`. The final state is at the end
of this file. No push or merge. The 46 unrelated files (two tracked `shot_road_hunt.gd` edits and 44
untracked files) were left alone and verified byte-identical against
`build/qa/session-sept26/initial-preservation.json`.

## How the work was done
The root session acted only as orchestrator. Codex (headless `codex exec`) implemented 24 tasks, each in
its own sparse lane worktree. Every lane then went through a Claude Workflow: independent read-only
reviewers, a fixer that verified and applied their findings, and an independent verifier that re-ran the
gates and could reject the lane for another fix round. Reviewers found and fixed real defects in most
lanes. The root squash-applied accepted lanes onto the branch and ran batch gates. DeepSeek did ideation
and one implementation attempt until its API balance ran out ($0.13 left; a top-up needs the owner). The
kit, costs and traps are in `tools/orchestration/README.md`. How to improve the workflow is in
`tools/orchestration/ARCHITECTURE.md`: a living doc with a scorecard of this run, a recommended v2, model
tiering, and an experiment log to append each session.

## Delivered
- **Touch co-op** (`640277b`): holding Act revives a downed ally on phones. The touch button editor is
  modal and returns to where it was opened.
- **Consumables** (`89bd866`, `4a8cdee`): potions follow the same rules from Q and the Inventory, with no
  drinking in duels or sealed pockets and no wasting at full HP/MP. Use and Drop act on the exact bag
  item. Every refusal shows inside the open menu.
- **Loot** (`379e26b`, `8a0ce4f`, `e0c3d79`, `e092ab3`):
  - Loot you are standing on pays once when you get back up.
  - Restarting a chapter retires old caches and Gold Rush coins.
  - The chapter gift potion can't be banked or dropped.
  - A lapsed co-op curse offer can't be accepted.
  - "Claim what fits" in mail takes partial material stacks and names what it took.
- **Death and story safety** (`6eed418`, `4a8cdee`): HUD icons, Escape, hotkeys and pad menus can't open
  menus during the death beat, dialogue, choices or a cutscene's closing fade. A win during the death
  beat ends it cleanly. Deleting a hero asks first, with Cancel focused. The Depths entry copy is honest.
- **Feedback** (`4c6bd52`, `27c1a24`, `e0c3d79`, `e092ab3`):
  - A level-up plaque, with a matching log line.
  - The potion slot and touch potion button pulse at low HP when a drink is usable.
  - Green upgrade marks on the loot banner and in the bag.
  - Frozen, Rooted and Chilled chips with countdowns; sleep and stagger show as Asleep and Staggered.
  - Grouped gold amounts across trial results, the forge, merchants, synthesis, road choices and the journal.
- **Co-op and controller** (`25963a1`, `2bf6e29`, `ad3c385`):
  - Off-screen ally arrows stay clear of the HUD at any screen size, at about 2 ms a frame.
  - Controller Y answers ready checks and B declines them.
  - The online pause menu lists the party with full names.
  - Stale trial notices and "left the party" plaques no longer show up in the wrong run or after a rejoin.
- **Dedicated server** (`566b24e`): story bosses rise, including in arenas cleared while empty, and side
  quests settle without a local player.
- **Online cinematics** (`916fd04`): refused, cancelled or orphaned cinematic requests tear down their
  storybook layer. Chapter openers play for every hero in a party, including two of the same class.
- **Depths camp** (`eb88b92`): descending without opening the one-time camp shop asks "Leave the camp?"
  first, with Cancel focused.
- **Onboarding** (`72248ff`, `08fa8ea`): Elder Maren gets an objective marker, barred gates explain what
  opens them, and dialogue and prop prompts show remapped keys.
- **Combat correctness** (`435a23e`, `44bef05`, `e092ab3`):
  - DoT strength resets when it expires.
  - An enemy can't bite or shoot after a lethal DoT tick.
  - Bleed breaks wards.
  - Mage gear bonuses reach Blink, Meteor and Starfall.
  - The Wind Cuts wound uses armor in PvE, and in duels it keeps the striker's penetration.
  - Warlock spells read their own damage knobs; live values are unchanged.
  - A boss reset clears its burn and bleed.
  - BALANCE_HISTORY.md records the damage changes.
- **Wide screens and cinematics** (`39a86c8`, `ccdc2c9`, `f9bddb2`): shades, the death dim, speaker and
  boss splashes and cinematic covers fill wide phones. Desktop plates now show the whole painting: a
  sizing-order bug had cropped them to their top-left three quarters since they landed. On Forward+, the
  dialogue box, choice panel and backlog read near-black with a gold border instead of olive, and they
  stay centred on wide screens.
- **Event feed** (`416b516`): feed lines wrap and show in full inside a fixed height budget. Inventory
  stat names stay on the same line as their values.
- **Tooling** (`1a241e2`, `d328df9`, `9734f6b`): shot rigs run on an isolated per-checkout profile and
  never touch the owner's real settings or keybinds. The orchestration kit is in `tools/orchestration`,
  with `ARCHITECTURE.md` and the session evidence.
- **Mobile** (`38ef242`, `3ffa4db`, `5d35470` and the final sync below): each sync is scoped to the
  changed `game/` files.

## Validation
Each lane ran the compile gate, the quick suite and its targeted rigs, through the machine lock, first by
the fixer and again by the independent verifier.

On the integrated branch:
- Full desktop suite PASS on `1a241e2`, `2bf6e29`, `e0c3d79` and the final HEAD.
- Strict preflight PASS on `5d35470` and the final HEAD.
- Mobile import, compile and quick PASS on every mobile sync.
- Quick PASS after each late integration.

One cross-task break was caught by the batch full run and fixed before anything else landed: the opening
guidance test ran inside the cutscene fade that the overlay work now treats as blocking input
(`08fa8ea`, test-only).

Limits:
- Coverage is headless suites plus ShotRig captures.
- No physical phone, controller or live multi-process dedicated server was used. The dedicated-server
  fixes use an in-process fixture.
- Reviewers and root judged visuals from rig captures; the owner has not reviewed them in-game.
- The usual ObjectDB and renderer shutdown warnings remain.

## Owner should look at
- Desktop cinematic plates now show the full painting, centred (`39a86c8`). This is a deliberate framing
  change from the old top-left crop.
- The damage changes in `44bef05` and `e092ab3`: Mage gear bonuses now apply, and the Wind Cuts wound
  uses armor and penetration.

## Remaining follow-ups (found by reviewers, not done)
- **Ally markers:** arrows and name tags use different eligibility points (feet vs head); this is a
  policy call. An ally straight above slides far along the edge, with no hysteresis.
- **Impairment labels:** PvP stuns still show as Frozen. Sleep and stagger now have their own labels.
  The new "STAGGERED!" callout keeps the all-caps callout family; moving that family to sentence case
  would be a separate copy pass.
- **Quest scene cinematics:** a refused quest "scene" cinematic still drops its parent conversation's
  continuation. This is unlikely, since no scene convo is a beat.
- **Layout:** on a 4:3 expand view the dialogue box keeps its authored y. On tall phone canvases the
  co-op chat still overlaps the top of the event feed.
- **Gold and PvP DoTs:** profession refusal strings still show ungrouped gold. PvP burn and toxin ticks
  still forward no penetration.
- **Test gaps:** the dedicated boss path has no real multi-process ENet test yet (net_test stage 12
  could cover it). One road-choice test line lost its line continuations, which is a style nit only.

## Final state
Lane worktrees `cw-lane-a` … `cw-lane-k` were removed after integration. Each `.godot` junction was
unlinked first, and the main asset count was checked after every removal. Branches `sept28/lane-*`
remain; they are squash-integrated and safe to delete. Evidence, logs, briefs, provider outputs and the
orchestrator's notes are local under the ignored `build/qa/session-sept28/`.
