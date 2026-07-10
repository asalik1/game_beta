# MP_TASKS — Multiplayer implementation board (blueprint: MULTIPLAYER.md)

One owner per task. Claim before starting. File ownership is STRICT — never edit a file another
wave-mate owns; if the compile gate fails in a file you don't own, wait and retry (sibling mid-edit).
No commits. Staging happens once, by the orchestrator, after the integration gate.

## Wave 1 — Phase 0 groundwork (parallel, zero file overlap)

### MP-01: Player registry + targeting seam — OWNER: agent-A — status: DONE
Files: `game_base.gd`, `enemy.gd`, `boss.gd`, `projectile.gd`, `content/ch*_bosses.gd`
`players` array + `local_player` kept in sync via `player` setter; `nearest_player()` /
`pick_target()` seam; enemy+boss AI reads target via seam; DoT ticks carry a source ref;
projectile identity checks become `body is Player`. Solo behavior bit-identical.

### MP-02: Input intent layer — OWNER: agent-B — status: DONE
Files: `player_core.gd` (vars live in base layer), `player_combat.gd`, `player.gd`, `game.gd`
Gameplay inputs (move, abilities, potions, interact) poll into an intents struct each frame;
simulation reads only intents. Pure-UI hotkeys (open menus) stay local. Same keys, same frame — zero
feel change.

### MP-03: Save format v3 — character/world split — OWNER: agent-E — status: DONE
Files: `save.gd` (+ narrowly, any direct save-JSON readers found by grep)
`character:{...}` / `world:{...}` nesting, VERSION 3, load-time migration from v2. No field lost.

## Wave 2 — Phase 0 remainder (after wave 1; overlapping files now free)

Orchestrator stitch (post-wave-1): DoT `src` wired at all 6 application sites
(player_combat.gd:250-259,882; player_kit_assassin.gd:140) — test_quick green.

### MP-04: Pause gating + death state machine + HUD local binding — OWNER: agent-C — status: DONE
Files: `game_base.gd`, `menus.gd`, `hud.gd`, `game_flow.gd`, `game.gd`
All `get_tree().paused` sites route through `request_pause()`; death `await` becomes a state
machine (solo timing identical); `hud.update_stats(local_player)`.
Carry-over from MP-02: Tab/Space target-lock lives in `hud.gd:_unhandled_input` — the one gameplay
input still outside the intents layer; route it into the player's intents (it's simulation-affecting).
Model it as device-agnostic intent fields (e.g. `intent_lock` / `intent_lock_release` or a
lock-request enum), NOT keyboard echoes: the mobile port drives the same intents from a HUD button
(tap = lock, hold-and-swipe-away = release — see MULTIPLAYER.md §10 control scheme).
Carry-over from wave 1: verify the non-fatal "cast a freed object" at game_flow.gd:773 (grass rustle
over stale zone_scenery) seen during a mid-edit suite run — confirm gone on the settled tree, or fix.

### MP-06: Party difficulty scalars — OWNER: orchestrator — status: DONE (pulled forward, zero-conflict)
`Balance.PARTY_HP_MULT/PARTY_DMG_MULT/PARTY_BOSS_RATE` + `party_hp()/party_dmg()` (balance.gd,
beside the aggro knobs); applied in `add_enemy` before weekly_fx (game_world.gd) — a party of 1
skips the block entirely. Bosses get their scaling in phase 2 (they don't route through add_enemy).
test_quick green.

## Wave 3 — Phase 1 scaffolding (after wave 2; needs --import, runs alone)

### MP-05: NetworkManager + noray vendor + net_test harness — status: DONE (netfox v1.35.3 vendored w/ MIT attribution in game/addons/CREDITS.txt incl. the Godot engine notice; NetworkManager autoload w/ NET_VERSION auth gate; net_test.bat green — accept/reject/clean-leave all asserted; NOTE: bare `NetworkManager` identifier breaks check_compile — use get_node("/root/NetworkManager"))
Files: NEW `game/scripts/net/`, `game/addons/netfox.noray/` (vendored, MIT + attribution),
`project.godot` (autoload), `net_test.bat`, `game/scripts/tests/net_test.gd`
host()/join(code), NET_VERSION auth handshake, localhost ENet two-headless-instance test.

## Wave 4 — Phase 1 completion

### MP-07: Session gameplay bridge — OWNER: agent-S — status: DONE (net_session.gd bridge under the NetworkManager autoload; join = seed/flags/spawn-room snapshot -> guest rebuilds via switch_chapter -> ready -> spawn fan-out; 20 Hz unreliable {pos,vel,look} sync w/ 120 ms two-snapshot lerp; remotes presentation-gated in player.gd; active_rooms union sim gate; guest enemy/boss spawns no-op; request_pause no-ops online; --mp-host/--mp-join dev CLI; net_test.bat stage 2 green — seed+layout match, 2 players both sides, movement seen host-side, clean leave; test_quick + full test.bat green)
Files: `game.gd`, `game_base.gd`, `game_world.gd`, `enemy.gd`, player chain (minimal remote gating),
`game/scripts/net/*`, net_test extension. NOT menus.gd (that's MP-08).
Multi-player spawn on join (owner-authoritative movement), 20 Hz movement sync + interpolation,
seed/flags snapshot join flow (guest rebuilds world locally), `active_rooms` union gate, guest
enemy-spawn suppression (# MP: phase-2 snapshot mirror replaces), request_pause no-ops online,
CLI `--host`/`--join` dev entry. Exit: net_test proves two instances, two players, movement seen.

### MP-08: Lobby UI + character handoff — OWNER: agent-L — status: DONE (Play Together on the roster screen -> ui/lobby.gd static module: host = hero pick -> chapter pick (continue-as-saved or replay any meta-unlock) -> code shown big + copy + live party list + Start; join = code -> own-roster hero pick -> wait-in-lobby; guest ships its REAL character — save.gd v3 apply_character loads the joiner's character section at snapshot time, _rpc_join_ready carries {cls, level, name, hp/max_hp, mp/max_mp}, remotes get true vitals; guest autosaves route to new SaveGame.write_character_home via game_base.guest_world (host world never colonizes the guest's save — probed both directions); NET_VERSION printed on the title cover; lobby locks at chapter start (net_manager.lobby_open auth check, readable refusal; dev CLI/harness sessions stay join-anytime); codex Co-op page stub + autotest hook smoke; test_quick + net_test both stages + full test.bat green)
Files: NEW `game/scripts/ui/lobby.gd`; `menus.gd`, `ui/codex.gd`, `net/net_manager.gd`,
`net/net_session.gd`, `save.gd`, `game_base.gd`, `game.gd`, `autotest.gd` (marked hook only).

**PHASE 1 COMPLETE — USER-VALIDATED 2026-07-10** (owner ran a live two-instance session: "WORKS!")

## Wave 5 — Phase 2: combat over the wire (sequential — net_session.gd is the shared choke point)

### MP-09: Enemy/boss mirror + telegraphs to guests — OWNER: agent-M — status: IN PROGRESS
Host streams enemy state for active rooms: spawn/despawn/death events + ~20 Hz snapshot
(id/pos/facing/anim/hp), guests render non-simulating mirror enemies; play_action one-shots as
event RPCs; telegraph/telegraph_safe mirrored as visual events (co-op dodging!); boss mirror +
boss-bar sync; party scalars applied to BOSS stats at spawn + PARTY_BOSS_RATE cadence knob consumed.
net_test stage 3 proves: guest sees mirrors tracking host positions, telegraph event renders, boss
bar syncs. DO NOT touch chest.gd / shot_chests.* (owner's active session).

### MP-10: Ability casts + hit resolution over the wire — status: QUEUED (after MP-09)
### MP-11: Loot/reward instancing + XP to party — status: QUEUED (chest.gd needs owner coordination)

## Integration gate (orchestrator) — PASSED 2026-07-10
- [x] Full `test.bat` green on the combined tree (AUTOTEST PASS, exit 0, zero SCRIPT ERRORs)
- [x] DPS bench sanity: 18/18 specs within variance of freshest references (archer hunt/storm
      match the post-mana-round recorded values to <0.4%; TIERLIST rows for those were already
      flagged stale pre-phase-0 — see BALANCE_HISTORY top entry)
- [x] Phase-0 paths staged (path-scoped; index also carries prior sessions' sprite/UI staging —
      any future commit must path-scope or describe the union)
