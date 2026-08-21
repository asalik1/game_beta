# Crownless code review report

**Review date:** 2026-08-19  
**Review mode:** Read-only review; no source-code fixes were made  
**Snapshot:** The working tree already contained uncommitted gameplay, tooling, and art changes. This review covers that on-disk snapshot and does not attribute those pre-existing changes to any particular author.

## Executive summary

The review found **11 reportable issues**:

| Severity | Count | Meaning in this report |
|---|---:|---|
| High | 5 | Data loss, host/session compromise, or a remotely triggerable crash/major integrity failure |
| Medium | 4 | Reliability, persistence, test-detection, or material feature-completeness problem |
| Low | 2 | Localized tooling or cleanup problem with limited direct player impact |

The highest-priority items are:

1. Creating a character when all 20 save slots are occupied silently reuses and overwrites slot 20.
2. Multiple multiplayer RPCs trust guest-supplied combat values and state changes, allowing a modified client to kill enemies or players, ignore normal combat rules, delete projectiles, teleport, or falsify its state.
3. Any connected guest can invoke the developer-spawn RPC on the host; a malformed enemy kind can also cause an invalid dictionary access and script error on the host.
4. Guest RPCs can directly set arbitrary host flags/quest keys and can emit beat/dialogue traffic without owning the relevant conversation claim.
5. The join handshake accepts an unvalidated character block; an invalid class identifier reaches direct `Classes.CLASSES[cls]` indexing and can break the host's join path.

## Scope and validation

The review covered the canonical `game/` implementation, mobile-specific project/configuration deltas, repository tooling, batch/PowerShell entry points, shaders, and the GitHub Actions workflow. The generated `mobile/game/` mirror was reviewed through its canonical source plus a drift check rather than treating duplicated files as independent implementations.

The snapshot contained 496 code/config files in the reviewed extensions: 310 GDScript, 155 Python, 12 batch, 12 shader, 5 PowerShell, and 2 YAML files.

Validation performed:

- Canonical Godot compile gate, including scripts outside `game/scripts/` and add-ons: **154 scripts compiled**.
- Mobile Godot compile gate, including mobile root scripts and add-ons: **156 scripts compiled**.
- Quick gameplay suite: reached `AUTOTEST QUICK PASS`.
- Full end-to-end gameplay suite: reached `AUTOTEST PASS`.
- Python AST parse: **155 files, 0 syntax failures**.
- PowerShell parser: **5 files, 0 syntax failures**.
- Mobile mirror check: **20,667 files checked, 0 drift and 0 unexpected mobile-only files**.
- Fast preflight: **0 failures**. Its 77 warnings were asset-only QA warnings on currently modified Nullwarden sprites and are not counted as code defects here.
- `git diff --check`: clean.

Passing compilation and gameplay tests do not cover malicious network payloads, process interruption during persistence, malformed local save data, or shutdown-time resource ownership. Those are the main sources of findings below.

## Findings

### CR-001 — A full save roster silently overwrites slot 20

**Severity:** High  
**Confidence:** Confirmed from direct control flow  
**Area:** Character persistence / roster UI

**Locations**

- `game/scripts/save.gd:19-21` — `MAX_SLOTS` is 20.
- `game/scripts/save.gd:396-400` — `next_free_slot()` returns `MAX_SLOTS` when no slot is free.
- `game/scripts/menus.gd:345-360` — the roster always offers **New Character**, with no capacity check.
- `game/scripts/game.gd:366-372` — a new character assigns the result of `next_free_slot()` to `save_slot`.

**What can happen**

Once slots 1 through 20 exist, starting another character assigns slot 20 to the new character. The next save/autosave writes the new character to the existing slot-20 path. There is no warning, confirmation, or explicit choice of which character to replace.

**Impact**

Permanent loss of the character previously stored in slot 20.

**Why tests missed it**

The save tests use slot 20 as scratch space, but there is no boundary test that fills every slot and then exercises `next_free_slot()` or the **New Character** UI path.

**Suggested remediation direction**

Represent “no free slot” explicitly, disable or redirect **New Character** at capacity, and require an intentional delete/replace action before any existing path is reused.

---

### CR-002 — The host accepts guest-authored combat results and player state

**Severity:** High  
**Confidence:** Confirmed protocol behavior; exploitability requires a modified or crafted client  
**Area:** Multiplayer authority / PvE / PvP

**Locations and examples**

- `game/scripts/net/net_session.gd:1128-1154` — `_rpc_hit_enemy()` accepts an arbitrary enemy ID, damage amount, direction, and crit flag. The only amount constraint is `maxf(0.0, amount)`.
- `game/scripts/net/net_session.gd:1166-1202` — `_rpc_enemy_status()` accepts arbitrary burn/toxin/bleed DPS, durations, slow multipliers, drag data, and other status payload fields.
- `game/scripts/net/net_session.gd:1655-1674` — `_rpc_consume_projectile()` lets a guest delete a host projectile by network ID without proving a valid deflection.
- `game/scripts/net/net_session.gd:2877-2900` — `_rpc_pvp_strike()` accepts arbitrary damage, damage type, and penetration while a duel is live.
- `game/scripts/net/net_session.gd:2919-2946` — `_rpc_pvp_status()` validates the status name but accepts the duration/magnitude values from the guest.
- `game/scripts/net/net_session.gd:712-723` — `_rpc_move()` accepts arbitrary position, velocity, and facing snapshots.
- `game/scripts/net/net_session.gd:1297-1314` — `_rpc_vitals()` accepts guest-supplied maximum HP, HP, and MP.
- `game/scripts/net/net_session.gd:1847-1858` — `_rpc_down_state()` accepts any integer state and does not validate the legal transition.

**What can happen**

The sender is often checked for membership in the session, but the host does not reconstruct or validate whether the claimed action was possible. A crafted client can, among other things:

- apply arbitrarily large damage or status DPS to any known enemy;
- one-shot a PvP opponent and use arbitrary penetration;
- remove hostile projectiles by guessing/observing their IDs;
- report a fabricated health pool or stand/down/ghost state;
- teleport its remote shell, affecting presentation, proximity checks, room membership, and encounter logic.

**Impact**

Loss of combat integrity, PvP integrity, encounter integrity, and potentially session stability. Severity is High for any session that may admit untrusted peers; it is still a correctness risk in friends-only play because desynchronized or buggy clients can send the same impossible values accidentally.

**Suggested remediation direction**

Move decisive combat/state validation to the host, or send bounded action intents that the host can validate against cooldowns, positions, targets, equipped abilities, expected damage envelopes, legal state transitions, and current encounter state. Rate-limit high-frequency paths independently of peer authentication.

---

### CR-003 — Any guest can invoke an unrestricted developer spawn on the host

**Severity:** High  
**Confidence:** Confirmed from direct RPC path  
**Area:** Multiplayer authorization / denial of service

**Locations**

- `game/scripts/net/net_session.gd:770-786` — `_rpc_dev_spawn()` is `any_peer` and only checks that this machine is the server and that `game` exists.
- `game/scripts/game_world.gd:3393-3411` — `dev_spawn()` trusts `what`, `kind`, `level`, and `pos` from the supplied dictionary.
- `game/scripts/game_world.gd:3405` and `game/scripts/enemy.gd:447-451` — enemy identifiers are used as direct keys into `Story.ALL_ENEMIES`.

**What can happen**

Any connected guest can call the RPC directly even when developer UI/mode is not enabled and even when the host never authorized developer controls. A guest can spawn bosses or elites at arbitrary positions and levels. Supplying an unknown `kind` reaches direct dictionary indexing during enemy setup or boss-bar setup, producing an invalid-key script error on the host.

**Impact**

Unauthorized encounter creation, disruption of fight state/music/boss UI, and a remotely triggerable host error or session denial of service.

**Suggested remediation direction**

Make developer spawn unavailable in non-development sessions, require explicit host authorization, validate the sender, allow only catalogued spawn types/kinds, and clamp level/position inputs before constructing any node.

---

### CR-004 — Guests can spoof persistent world flags, quest state, and dialogue beats

**Severity:** High  
**Confidence:** Confirmed protocol behavior; exploitability requires a modified or crafted client  
**Area:** Multiplayer story authority / progression integrity

**Locations**

- `game/scripts/net/net_session.gd:2196-2206` — `_rpc_flag_to_host()` applies an arbitrary flag name/value through `game.net_apply_flag()` and fans it to the party.
- `game/scripts/game_base.gd:1490-1504` — setting a true flag rechecks gates and side quests immediately.
- `game/scripts/game_base.gd:1525-1528` — `net_apply_flag()` does not validate the flag name, value type, or originating action.
- `game/scripts/net/net_session.gd:2414-2439` — `_rpc_beat_line()`, `_rpc_beat_end()`, and `_rpc_beat_quest()` do not verify that the sender owns the active beat/conversation claim; `_rpc_beat_quest()` directly replaces `game.quest_key` on recipients, including the host.
- `game/scripts/net/net_session.gd:2468-2474` — `_rpc_convo_toast()` accepts arbitrary text without verifying a claim or applying the normal caller's length bound.

**What can happen**

The normal local route distinguishes world flags from character-local flags, but the RPC accepts any string and bypasses that policy. A crafted guest can set gate, quest, paid/reward, or completion-shaped flags on the host, force quest-tracker keys, end or overwrite mirrored dialogue, or spam arbitrary beat/toast content. The beat RPCs are not tied to `_convo_claims`/`_beat_claims` ownership.

**Impact**

Corrupted story progression, incorrectly opened gates, incorrectly triggered side-quest checks/rewards, stuck or spoofed dialogue overlays, and persistence of invalid host state on the next save.

**Suggested remediation direction**

Have the host derive story changes from a validated conversation/choice identifier rather than accepting raw state. Bind every beat RPC to the active claim and sender, reject unknown quest/flag identifiers and invalid value types, and enforce payload/rate limits at the receiving endpoint.

---

### CR-005 — The join character block is not schema-validated and can break the host

**Severity:** High  
**Confidence:** Confirmed invalid-key path; exploitability requires a malformed or crafted join payload  
**Area:** Multiplayer join handshake

**Locations**

- `game/scripts/net/net_session.gd:434-451` — `_rpc_join_ready()` stores and rebroadcasts the raw guest block.
- `game/scripts/net/net_session.gd:477-505` — `_spawn_remote()` passes the raw class to `set_class()` and accepts unbounded level, max HP/MP, crit, crit damage, and name values.
- `game/scripts/player_core.gd:1392-1430` — `set_class()` assigns the ID without checking membership in `Classes.CLASSES`.
- `game/scripts/player_core.gd:1594-1598` — `recalc()` immediately indexes `Classes.CLASSES[cls]`.

**What can happen**

An invalid `cls` value produces an invalid dictionary-key error while the host is spawning the remote player. The player is registered before class validation, so the error can also leave partially initialized session state. Extreme numeric values are accepted into the host-side player shell and can feed combat attribution or display/state logic.

**Impact**

A malformed guest can break or destabilize the host's join flow. Less severe malformed fields can create impossible remote-player state and desynchronization.

**Suggested remediation direction**

Validate the complete handshake block before storing, rebroadcasting, or registering a player. Use a strict allowlist for class IDs, clamp numeric ranges to game limits, bound strings, reject non-finite floats, and fail the join cleanly without leaving a partial node/roster entry.

---

### CR-006 — Persistent JSON files are overwritten in place without crash-safe replacement

**Severity:** Medium  
**Confidence:** Confirmed write pattern; data loss requires interruption or I/O failure  
**Area:** Persistence reliability

**Locations**

- Character and server saves: `game/scripts/save.gd:84-86`, `187-189`, `235-237`, and `371-373`.
- Settings and account metadata: `game/scripts/game_flow.gd:37-40` and `272-277`.
- Account stash and keybinds: `game/scripts/game_base.gd:1336-1341` and `1982-1985`.

**What can happen**

Every listed path opens the final JSON file directly with `FileAccess.WRITE`, which truncates/replaces the existing content before the new document is safely committed. There is no temporary-file write, flush/sync check, atomic rename, previous-version backup, or recovery path. A process crash, device power loss, disk-full condition, or write error during serialization can leave an empty/truncated save.

**Impact**

Loss of a character, server world, account meta/stash, settings, or keybinds. The reader generally maps invalid JSON to an empty dictionary, which can make a damaged save look absent rather than recoverable.

**Suggested remediation direction**

Write and validate a sibling temporary file, close/flush it, atomically replace the final file where supported, and retain a last-known-good backup with load-time recovery.

---

### CR-007 — Save loading trusts JSON field shapes and identifiers

**Severity:** Medium  
**Confidence:** High-confidence error paths; requires syntactically valid malformed/corrupt data  
**Area:** Save compatibility / corruption handling

**Locations**

- `game/scripts/save.gd:302-309` — arbitrary JSON values are assigned directly to typed `Dictionary` variables for `character` and `world`.
- `game/scripts/save.gd:412-424` — bag entries are cast to dictionaries without per-entry validation.
- `game/scripts/save.gd:431-480` — world collections and `pos` are trusted; `pos[0]` and `pos[1]` are accessed without checking length or element type.
- `game/scripts/save.gd:495-531` — the saved class is passed directly to `set_class()`, and equipment/tree/attribute fields are trusted as dictionaries.
- `game/scripts/player_core.gd:1597` — an unknown saved class reaches direct dictionary indexing.

**What can happen**

A syntactically valid JSON save with the wrong container type, a short position array, a non-dictionary bag/item, or an unknown class can raise a script error during roster display or load. Because `SaveGame.list()` scans all occupied slots, one malformed slot can potentially disrupt access to the roster rather than failing only that character.

**Impact**

A single corrupt, hand-edited, incompatible, or partially migrated save can prevent loading and may make other valid characters difficult to access through the normal UI.

**Suggested remediation direction**

Validate/migrate into a known schema before touching live state, quarantine only the bad slot, use safe defaults for every container, validate array lengths and IDs, and surface a recoverable “damaged save” entry instead of allowing a script error.

---

### CR-008 — Test wrappers can return success despite engine failure/error output

**Severity:** Medium  
**Confidence:** Confirmed from wrapper control flow and the observed full-suite run  
**Area:** Test infrastructure / regression detection

**Locations**

- `test.bat:31-33` and `test_quick.bat:21-23` — Godot is piped into PowerShell `Tee-Object`, then `suite_verdict.ps1` is called without the Godot exit code.
- `suite_verdict.ps1:15-18` — `ExitCode` defaults to 0.
- `suite_verdict.ps1:29-52` — the log scan rejects only `SCRIPT ERROR` and `Parse Error`, then trusts the pass marker and default/optional exit code.

**What can happen**

The pipeline does not preserve the Godot process exit status for the later verdict call. The batch file records only the verdict script's result, while `suite_verdict.ps1` receives no `-ExitCode` and therefore assumes zero. Additionally, engine lines beginning with generic `ERROR:` are not treated as failures.

The reviewed full suite demonstrated the second case: it printed `AUTOTEST PASS`, then printed an engine `ERROR:` about leaked texture RIDs and leak warnings, but the batch wrapper still exited successfully.

**Impact**

CI/local validation can be falsely green when Godot exits nonzero after printing the marker or reports serious non-script engine errors during teardown.

**Suggested remediation direction**

Capture the native Godot exit code separately from the tee process and pass it explicitly to the verdict script. Decide which generic engine `ERROR:` classes must fail the suite, with narrowly documented exclusions if any are unavoidable.

---

### CR-009 — The full suite reports rendering/ObjectDB resources leaked at shutdown

**Severity:** Low  
**Confidence:** Confirmed diagnostic; source and production impact not yet localized  
**Area:** Runtime/test teardown resource ownership

**Observed output after `AUTOTEST PASS`**

- `WARNING: 6 RIDs of type "CanvasItem" were leaked.`
- `ERROR: 6 RID allocations of type ... DummyTexture ... were leaked at exit.`
- `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).`

**What can happen**

At least six canvas/texture resources and one or more ObjectDB instances remain live when the full test process exits. This may be isolated to the test harness's shutdown timing, but it can also indicate nodes/resources that accumulate across scene changes or repeated sessions.

**Impact**

Currently uncertain. If test-only, it creates noisy and misleading validation. If the same ownership pattern occurs during chapter/session transitions in a long-running build, it can cause gradual memory/resource growth.

**Suggested remediation direction**

Run the failing suite with Godot `--verbose`, identify the leaked instance types/owners, and distinguish delayed test teardown from persistent production ownership before deciding priority.

---

### CR-010 — Co-op omits the per-class chapter closing cinematics

**Severity:** Medium  
**Confidence:** Confirmed and already documented by an in-code High-priority TODO  
**Area:** Multiplayer feature parity / narrative flow

**Location**

- `game/scripts/game_flow.gd:1076-1093`, especially the `TODO(MP-24, HIGH)` at `1083-1084`.

**What can happen**

The class-specific illustrated closer runs only when `not net_online()`. Online players receive the flat epilogue path instead of each client seeing the closer for its own class.

**Impact**

Co-op players miss authored narrative/cinematic content at chapter completion, and the solo and online experiences diverge at a major story beat.

**Suggested remediation direction**

Fan a host-authoritative victory/closer event while allowing each client to resolve and play its own local class-specific closing cinematic before the shared victory/advance flow.

---

### CR-011 — Art tooling contains machine- and temporary-session-specific paths

**Severity:** Low  
**Confidence:** Confirmed  
**Area:** Tooling portability / reproducibility

**Locations**

- `tools/art/act1_brief_lib.py:22`
- `tools/art/anim_sheet.py:38`
- `tools/art/build_act1_dirset.py:25`
- `tools/art/build_walk8.py:31-33`
- `tools/art/fix_sexton_surface.py:28-32` and `62-64`
- `tools/art/install_ability.py:16`
- `tools/art/install_act1_boss.py:16`
- `tools/art/install_clip.py:24-26`
- `tools/art/install_char_anims.py:113`
- `tools/art/install_death_flat.py:58`
- `tools/art/install_dirset.py:162`

**What can happen**

These tools hard-code `C:\Users\asali\Projects\MMO` instead of deriving the repository root from `__file__` or a required argument. `fix_sexton_surface.py` also defaults to a specific ephemeral Claude scratchpad UUID. A clone in another directory or on another machine either fails, reads/writes the wrong checkout, or creates output in a stale/nonexistent session path.

**Impact**

Non-reproducible asset pipelines, failed automation/CI, and risk that an installer modifies an unintended checkout while appearing to succeed.

**Suggested remediation direction**

Derive stable repository paths from the script location, require explicit external staging directories where needed, and reject resolved targets outside the intended repository/staging roots before writing.

## Items deliberately not reported as code bugs

- The 77 fast-preflight warnings all concern the currently modified Nullwarden PNGs (clip scale, ghost bands, and anchor consistency). They are asset QA findings rather than code defects and are outside this report's requested code scope.
- Mouse-only handlers in several UI paths were not reported as mobile bugs because Godot 4.4 enables mouse-event emulation from touch by default; the mobile project is not relying on an absent engine capability there.
- The current modifications to `balance.gd` and `pickup.gd` compiled and passed both gameplay tiers; this review did not find a defensible defect specific to those changes.
- The GitHub Actions major versions in `mobile-builds.yml` were checked against their upstream action repositories and are currently valid; they were not flagged merely for being newer than older examples.

## Coverage limitations

- No hostile-peer fuzz client was connected. Multiplayer findings are established from reachable RPC code paths and missing validation, not from attacking a live public session.
- No real Android/iOS build or physical-device test was run. Mobile source parity and compilation were verified locally.
- The mobile GitHub Actions workflow was reviewed statically but not dispatched, so runner-only signing/export behavior remains unproven.
- Asset binaries and generated Godot import metadata were not manually audited as source code.

## Final note

This report is the only file added by the review. No gameplay, tooling, configuration, save, mobile-mirror, or asset source was modified to address any finding.
