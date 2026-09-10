# Party quest progress and live Journal refresh

Guests now receive shared partial side-quest counts in an open Journal and the
tracked HUD. Shared beat and boss main-text updates reach the other party
members, while counter-only updates preserve a guest's local main objective.

## Player-visible behavior

Guests see the host world's partial side-quest kill counts in the Quests tab and
their tracked HUD objective. For example, Thin the pack shows 2/3 before its
completion flag arrives. An already open Journal refreshes when that shared work
or its main objective changes. It uses the existing board watcher and view
restoration, retaining scroll position and the named focused control when that
control remains available. Tracking remains the local character's choice.

A shared kill does not author a main objective. After a guest finishes Maren's
private Mage conversation, that guest can be on Fangmaw while the host remains
on Talk. Subsequent partial hunter counts update the guest's counter without
resetting Fangmaw to Talk. This preserves the private callback's result; it does
not make private Maren main text identical across the party. The same counter
delivery also preserves an active shared dialogue driver's pending main key.

An initial world brief, party travel and an explicit readiness rebrief replace
the displayed main key and counter table with the host's state. An empty table
is a real reset. The readiness rebrief supplies work completed after the initial
snapshot was sent but before the new guest finished building its world. Normal
host main-text updates from completed shared beats and both nonfinal/final boss
transitions use the same reliable host fanout.

## State ownership and delivery

`game_base.gd::quest_kill_note` keeps its existing guest early return. Only the
host advances shared kill work and sends changed counters. Its counter-only
fanout marks `counts_only: true`; receipt applies counters while retaining a
guest's existing main key. A normal main update also retains the key while that
guest is broadcasting a shared beat. `rebrief: true` takes precedence and
deliberately replaces both fields after world readiness.

The new `quest_progress.gd` projects a detached table of authored side-quest
kill-step flags and their declared bounds. It excludes local-history keys and
unknown fields. Projection tolerates finite whole-number floats restored from
JSON saves, clamps them before integer conversion, and never mutates the saved
table. Network receipt is stricter: each count must already be an integer from
zero through its authored target. A main key must be empty or a bounded key in
`Story.ALL_QUESTS`.

The live authority RPC requires a ready guest and matching chapter and integer
world seed. It validates both display fields before applying either, and rejects
a nonboolean `counts_only` marker. Malformed count/key data leaves the existing
display intact. The host sends only to character peers that remain in the
admitted peer registry. This is a chapter/seed context check, not a new session
epoch, packet revision system or general story-conflict resolver.

Shared beat completion now sends the guest driver's main-key request to the
host, before releasing its live claim. The host requires an admitted sender,
an existing live beat claim owned by that sender, and a valid authored main key,
then publishes the accepted state to registered siblings. The existing claim
test is ownership of a live beat; it does not prove that a particular quest key
was produced by a particular dialogue line. No broader security claim is made.

The live display receiver assigns counters/main text and calls `refresh_quest`.
It does not set completion flags, roll loot, pay rewards or save. Existing flag,
quest-payment, boss-award and character-home save paths retain those jobs.
Duplicate state can still reach `refresh_quest`; an unchanged Journal signature
does not rebuild the shell. This is not a new network duplicate filter.
Guest session teardown clears the transient counter mirror while the existing
home-world save separation remains in force.

## UI and code touchpoints

| Source | Responsibility |
|---|---|
| `game/scripts/game_base.gd` | Host kill accounting and counter-only fanout. |
| `game/scripts/quest_progress.gd` | Authored bounds, detached save projection, strict wire fields and context checks. |
| `game/scripts/net/net_session.gd` | Initial/readiness/live/travel fields; admitted host fanout; claimed guest beat request; guest mirror cleanup. |
| `game/scripts/game_flow.gd` | Apply travel fields and publish both actual boss main-key assignments. |
| `game/scripts/quest_guide.gd` | Include mirrored counts in guest objective descriptions. |
| `game/scripts/ui/journal.gd` | Include mirrored counts on unfinished kill cards. |
| `game/scripts/ui/activity_rewards.gd` | Extend the existing watcher signature with chapter/seed/flags and Quests main/counters/room/tracked state; reuse named focus and scroll restoration. |
| `game/scripts/net/net_manager.gd` | Protocol `0.3.16` → `0.3.17`. |
| `game/scripts/tests/test_quest_progress.gd` | Shared headless projection/validation/description/signature checks with captured state restored. |

The protocol bump is required for the added quest fields/RPC and changed beat
completion route. Production admission compares the version exactly; mixed
`0.3.16`/`0.3.17` peers receive the existing version-mismatch refusal. The
separate production-manager admission fixture verifies that boundary below.

## Validated checkpoint — 2026-09-10

The checkpoint was run from material commit
`8a67fddb69b3abd1c1e29a05ab2df3ea4ee1b576` with the reviewed Party changes
installed. This records the tested source, not a future Party commit hash.
The ordered source manifest is
`build/qa/session-sept10/party-quest-current-review/ordered-apply-manifest.json`.
Its safe native patches 1–3 and the recorded fixture corrections formed the
`0.3.16` baseline; patches 4–8 supplied the final production, protocol,
headless, boss/active-driver and private-Maren counter-only changes. The
protected road-hunt draft was excluded.

| Accepted lane | Suites | Native result and full originals |
|---|---|---|
| Guarded desktop baseline, `0.3.16` | Quick 143 | 30 observations: 13 strict passes, 15 exact expected findings, 2 uncovered; 10 PNGs. |
| Desktop after-1, `0.3.17` | Quick 144, full 224 | Party 38/38 and admission 34/34; 10+3 PNGs. |
| Mobile-source after-1, `0.3.17` | Quick 144 | Party 38/38 and admission 34/34; 10+3 PNGs. |

The guarded baseline had zero strict failures. Its two uncovered observations
were readiness rebrief and the new live mirror's atomic rejection; seven
individual malformed-packet observations and the duplicate control were not
available on `0.3.16`. Private Maren main-key retention already passed there:
missing counter delivery was the finding. The overwritten private main key
was a regression in the incomplete proposed fanout, not an existing baseline
failure. The final counter-only composition delivered both the count and the
retained local objective.

All 31 after-run stages exited 0. Both Party reports had 38 passes, no findings,
empty fatal text and inner/outer restoration; separate production-manager
admission had 34 passes each for current `0.3.17` and rejected prior `0.3.16`.
The measured baseline compile counts were 255 ordinary/257 native scripts;
after counts were 257 ordinary/259 for both Party and admission, on each
project. Strict preflight passed all seven categories: IMPORT, MODULES,
BALANCE, PHYSICS, RIGS, ARTQA and CODEX. Source-before/after checks and the
scoped 14-source mobile comparison passed; the 46 preserved files and isolated
save/meta boundaries stayed intact. Existing UIDs were preserved and new owned
scripts received project-local import UIDs.

Root and an independent reviewer examined all ten accepted baseline originals
and all 26 after originals (Party 10 plus admission 3 per project). The
report/image/source/restore adapters are in `party-quest-root-review/` and
`party-quest-independent-review/` under the session evidence directory.
The runner's automatic receipt keeps visual acceptance false; the separate
human/agent review receipts supply that evidence.

Three earlier baseline attempts remain rejected and preserved:

- `8a67fddb69b3`: compile failed on two multiline inline lambdas; no gameplay
  evidence was accepted. The lambdas were folded without changing semantics.
- `8a67fddb69b3-lambda-fix`: native stopped before observations because the
  real opening dialogue left earned reward drops. Pair-only
  `Recovery.recover_live` now collects those actual drops before the guest
  home/save/snapshot ledger, logs the recovered amounts and verifies none
  remain. The generic no-pending-rewards precondition was retained.
- `8a67fddb69b3-opening-recovery`: all 30 rows and 10 images were produced, but
  restoration read a freed remote Player before checking validity. The script
  error rejected the run despite its inner `restored=true`. The accepted
  `8a67fddb69b3-freed-peer` fixture checks validity before the typed assignment.

The accepted evidence lanes, relative to `build/qa/session-sept10/`, are:

- Baseline: `party-quest-refresh-candidate/checkpoint-post-tumble-baseline/preparations/8a67fddb69b3-freed-peer/baseline-1/`.
- After: `party-quest-refresh-candidate/checkpoint-after-crlf-template/preparations/material-8a67fdd-guarded/after-1/`.
- Review adapters: `party-quest-{root,independent}-review/baseline-freed-peer.json`
  and `{desktop,mobile}-after1-{native,admission}.json` in those directories.

Each lane retains its preparation, runner, source, contract and raw log files.
Party reports/images are below `native/appdata` for baseline and
`{desktop,mobile}-native/appdata` for after, followed by
`Godot/app_userdata/Crownless/shots/party_quests/`. Admission uses the after
lane's separate `network-admission-candidate/{desktop,mobile}/appdata` tree.
The corrected after template normalizes CRLF in decoded log text before exact
marker comparisons; raw evidence bytes and strict verdicts remain unchanged.

## Native fixture limits

`shot.bat party_quests --timeout=300` uses one engine with two rendered Game
readers and actual local ENet sockets. The pair manually seeds admission; it
does not exercise production-manager authentication. A lightweight third
Game/socket carries an explicitly posed live beat claim to test host ordering
and sibling delivery. Quest acceptance, landmarks, counters and several main
keys are controlled setup, and body physics is disabled. This is not ordinary
quest acquisition, combat or a mouse/keyboard conversation playthrough.

The private-Maren control invokes the real village interaction entry, obtains
the actual private claim and uses bounded `ShotRig.skip_dialogue` to complete
authored HUD callbacks. The retained reward ledger begins after that callback.
Boss controls call production `on_boss_died` at authored room indices with no
live Boss entity; existing fallback-level payouts run and are restored. They
prove neither combat victory nor a normal boss-level award. The travel control
rebuilds the same seeded chapter with explicit empty counts; it is not an
authored chapter exit, changed-seed journey or reconnect test.

The guest-home control compares the saved home world across the tested briefs,
travel and guest save routes. Independent Game meta caches still share one
isolated process-level `meta.json`; this is not two physical account files.
Both fixture layers restore owned save/meta bytes, and the outer entry refuses
APPDATA outside a `party-quest-refresh-candidate` directory. These controls do
not establish every disconnect or failure-recovery path.

The separate `network_admission` rig uses production NetworkManagers and real
ENet to test current/prior version admission and lifecycle cleanup. It uses its
own required `network-admission-candidate` APPDATA namespace. Those diagnostic
boards are not player lobby screenshots; it does not run Game snapshots,
Noray or a gameplay save roundtrip. Mobile-source Compatibility captures and a
touch-layout fixture do not establish physical Android/iOS input behavior.
