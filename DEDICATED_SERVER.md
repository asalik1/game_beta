# DEDICATED_SERVER.md — Crownless: Headless World Authority + World Persistence

*Written 2026-07-18. This is the review doc for MMO roadmap steps **A** (headless
dedicated server) and **B** (world persistence). Both are built, tested, and green.
It records what changed, how to run it, what the work surfaced, and where the
deliberate boundaries are before steps C/D/E.*

---

## 0. TL;DR

- **A — Dedicated mode is real.** `game.exe -- --server` boots a headless world
  authority with **no host-player**. It runs the world as pure authority; 1–4
  clients connect over ENet and see/fight the same world. The world **survives
  every client leaving** (a listen server ends when the host quits — this doesn't).
- **B — The world persists.** The server owns a `server_world.json` (the same v3
  `world` section a character save already carries). It writes on the existing
  autosave call sites + a 60 s heartbeat, and restores on boot. The world **survives
  a full server restart** — seed, flags, cleared rooms, slain bosses, merchants.
- **Zero cloud, all local, testable tonight** — exactly as scoped. Two new headless
  net-test stages (12 dedicated, 13 persistence) prove it end to end and are wired
  into `net_test.bat`.
- **The de-risking paid off.** Running the world with no `local_player` surfaced
  every lingering "there is always a player on this machine" / "host is peer 1"
  assumption. They're all found and gated now — including one **latent co-op bug**
  the exercise flushed out (elite loot would never have fanned to guests on a
  server). `boss.gd`'s ~2.4k lines of `game.player` telegraph refs — flagged in
  MULTIPLAYER.md as the single biggest risk — turned out to be **already safe**:
  they were migrated to the player-registry seam in an earlier co-op phase, so they
  read through `pick_target()` / the registry, never a hardcoded host body.

---

## 1. How to run it (local, tonight)

**Boot the server** (one terminal). Headless, no window:

```
tools\Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --server
```

`--server` listens on `0.0.0.0:9999` by default. Options:

- `--server=48400` — listen on a specific port.
- `--server=0.0.0.0:48400` — explicit interface:port.
- `--chapter=ch3` — which chapter world to roll fresh (default `ch1`).
- `--fresh` — ignore any saved `server_world.json` and roll a brand-new world.

On boot it prints the world it stood up and the listen address:

```
[server] fresh world: ch1, seed 558183
[server] world authority up — listening on 0.0.0.0:9999 (4 seats)
```

Restart it later without `--fresh` and it restores instead:

```
[server] restored world: ch1, seed 558183, 3 rooms cleared, 1 bosses down
```

**Connect a client** (another terminal, or a friend's machine). The dev join path:

```
tools\Godot_v4.4.1-stable_win64_console.exe --path game -- --mp-join=127.0.0.1:9999 --mp-cls=archer
```

Real players will join through the existing lobby UI (Play Together → Join); the
CLI join is the dev/test seam. A client joining a dedicated server behaves exactly
like joining a listen host — it rebuilds the world from the seed + flags snapshot,
its character loads from its own save — **except there is no host player in the
world**. The lobby never closes, so clients can come and go freely (drop-in).

`server_world.json` lives under the OS user data dir
(`%APPDATA%\Godot\app_userdata\Crownless\` on Windows).

---

## 2. What was built

### 2.1 The one new state flag + the one guard it implies

The whole feature hangs off a single new field and a single new predicate in the
base layer (`game_base.gd`):

- `var dedicated := false` — this process is a headless world authority. Set only
  by the `--server` CLI parse.
- `func has_local_player() -> bool` — does **this machine** drive a player body?
  True for solo, host, and guest; false **only** on a dedicated server. This is the
  guard for every "host-personal" path (own loot, own heal, own HUD beat, own
  tithe). It is deliberately a query about the *body*, not about `dedicated`, so it
  reads correctly and self-documents at every call site.

The discipline throughout: gameplay branches on `has_local_player()` /
`multiplayer.is_server()` / `net_host()` — **never** "am I the host player." That's
the exact rule MULTIPLAYER.md §3.1 said would make the dedicated server a deployment
change instead of a rewrite. It held.

### 2.2 A — Dedicated boot & the server frame loop (`game.gd`)

- **CLI**: `--server[=port|ip:port]`, `--chapter=<id>`, `--fresh` parsed in `_ready`.
- **No body**: the `Player` node is never created; the `Camera2D` parents to the
  game root instead of a hero; the world enters room 0.
- **`_server_boot()`**: listen first (guests may knock while the world builds — the
  existing snapshot handshake already waits on `play_started`), then stand the world
  up — restored from `server_world.json` if present, else a fresh `--chapter` roll —
  then `play_started = true` and an immediate persist.
- **`_server_process(delta)`**: a lean server frame — the sim-relevant subset of the
  normal per-frame driver with all presentation (HUD binding, reticle, boss bar,
  camera shake, footsteps, NPC chatter) skipped. It refreshes the sim gate off
  connected players, builds guest-reached rooms, ticks terrain events per **occupied**
  room (anchored on a player standing in it), ticks hazards (enemy half only — each
  client ticks its own player), advances the fight-report clock, and drives the
  60 s persistence heartbeat.

### 2.3 A — Server capacity & no phantom host (`net_manager.gd`, `net_session.gd`)

- `MAX_SERVER_GUESTS = 4`: with no host body, 4 guests is the same 4-player ceiling
  the party-scaling tables (MULTIPLAYER.md §5.2) are tuned for. `host()` /
  `_host_enet()` / `_host_noray()` take a `max_guests` arg (default stays 3 for
  listen servers).
- **No phantom peer-1 body**: `_rpc_join_ready` no longer spawns a host player toward
  newcomers when the server has none; `lobby_roster()` omits the host seat on a
  dedicated server (a ghost "warrior L1" would otherwise haunt every party list).
- **Host-side jobs run bodiless**: `net_session._physics_process` splits the
  owner-side jobs (movement broadcast, vitals, death watch — gated on a local body)
  from the authority-side jobs (down/wipe sweep, enemy state stream, damage-number
  fan — always run when server). Nothing simulates when the registry is empty.

### 2.4 B — World persistence (`save.gd`)

Four static functions, all reusing the existing v3 `world` section shape so a future
account backend (step C) lifts them unchanged:

- `write_server_world(game)` — the v3 world section (flags, cleared/visited/door_seen
  rooms, slain bosses, merchant zones, seed, quest key, run stats) + the server's own
  trusted-clock anchor. No player position (no body), never the weekly-run marker.
- `read_server_world()` / `exists_server_world()` — load/probe.
- `apply_server_world(game, data)` — the world half of `apply()`, player-free.
  Honors the same `load_save` contract: caller sets the seed and `switch_chapter`
  first, then this applies flags/rooms/bosses/merchants and stands the world at its
  last safe room.

`autosave()` routes to `write_server_world` whenever `dedicated`, so **every existing
autosave call site** (room clears, boss kills, story-flag changes, window close)
persists the world for free — no new bookkeeping.

### 2.5 The bodiless-flow guards (the bulk of the surface)

The dedicated frame runs the same consequence code solo does, so every host-personal
branch was gated. All of these keep solo/host/guest **byte-identical** (`has_local_player()`
is always true there):

- **`game_flow.gd`** — `on_enemy_died`, `on_boss_died`, `on_rogue_boss_died`,
  `_curse_payout`: personal drops (own pile/chest/gem/gear/bag), own full-heal, and
  the victory results card gate on `has_local_player()`; the per-guest loot fans
  (`host_elite_kill`, `host_boss_kill`, `host_mob_kill`, `host_curse_payout`,
  `host_full_heal`) run whenever `net_host()`. `_apply_hazards` binds a nullable
  local-player and skips the player half. `run_terrain_event` gained `(zone, anchor)`
  params so the server fires weather per occupied room. `net_wipe` runs the
  authoritative world reset (bosses walk home, death room re-arms) with no body to
  respawn — the reset half was extracted to `_death_world_reset()` and shared.
  `replay_chapter` / `_wipe_chapter_flags` guard their player derefs. A new
  `_server_after_victory()` auto-advances the world after a grace window (nobody
  presses ENTER on a server — after the last chapter it rerolls).
- **`game_base.gd`** — `request_pause` never pauses when dedicated (an auto-advance
  timer must keep ticking); `_expire_side_quests` and `fight_report` guard their
  player derefs.
- **`game_world.gd`** — `switch_chapter` guards the teaching-potion grant, the world
  child-index, and the start position.
- **`hud.gd`** — `dialogue()` auto-resolves immediately when dedicated (a headless
  authority has no reader; the only server-side dialogue is flow beats — post-boss
  epilogues — which must not wait on a keypress).
- **`enemy.gd`** — a freeze guard: an **empty registry** (no clients) idles every
  enemy, so an unattended server burns no cycles chasing a null target.

---

## 3. What the exercise surfaced (the de-risking value)

Running the world with `local_player == null` is a much harsher test than co-op —
co-op always has *some* body on every machine. The findings:

1. **A latent co-op bug, not just a server bug.** `on_enemy_died`'s elite block was
   gated `if e.elite and is_instance_valid(player)`. On a dedicated server that
   `is_instance_valid(player)` is false — so `host_elite_kill` (the *guest* loot
   fan) would have been skipped entirely, and **no client would get elite loot**.
   The fan is now un-gated from the body check (it needs only `net_host()`); the
   personal drops gate separately on `has_local_player()`. This was a real hole in
   the elite-loot instancing that only the bodiless run exposed.

2. **`boss.gd` was already safe.** The doc's headline risk — 2.4k lines of boss
   telegraph code hardcoding `game.player` — did not materialize. An earlier co-op
   phase already migrated boss/enemy targeting to `pick_target()` and the player
   registry, and telegraphs resolve against **every** registered player. On a server
   the registry is the connected clients, so bosses aim at whoever's there. No boss
   file needed a single edit for the server to work. (Verified: `game.player` /
   `game.local_player` appear **zero** times in `boss.gd`.)

3. **The sim gate needed un-pinning.** `active_rooms` was seeded with `cur_room`
   (the local player's room). A server has no `cur_room` that means anything, so the
   gate is now the pure union of connected players' rooms — an empty server idles
   *everything*, and a room a guest reaches first is built off that guest's presence
   (`_host_ensure_active_rooms`, which already existed for co-op).

4. **Pause is a no-op that had to become a hard no-op.** `request_pause` already
   no-ops mid-session, but victory was an exception (the results card may freeze).
   A server has no reader for that card and its auto-advance timer must keep
   ticking — so dedicated never pauses at all, victory included.

---

## 4. Tests

Two new headless stages in `net_test.bat` (compile-gate-first, log-grep verdict —
the existing MP discipline). Both **pass clean, zero script errors / freed objects**:

- **Stage 12 (dedicated).** Boots a `game.dedicated` authority and lands two real
  guests on it: (a) idle authority has no body, empty registry, empty sim gate;
  (b) guest A joins the empty server — roster is guest-only, no phantom peer-1 body,
  lobby roster carries no host entry; (c) A walks into an unbuilt combat room and
  the server builds + arms it off A's presence alone (12 pack mirrors streamed);
  (d) A's real ability lands on a server enemy with attribution intact, and a
  server-side kill fans full XP to A; (e) guest B joins mid-run (the lobby never
  closes) — party of 2, still no host body, A sees B; (f) **both leave and the world
  keeps running** — roster drains to zero, sim gate empties, session stays up.
- **Stage 13 (persistence).** Phase 1 is a throwaway server process that builds a
  fresh world, mutates it through real paths (a world flag; a combat room cleared by
  slaying its pack — which autosaves), and exits. Phase 2 boots a **new** server from
  the same `user://` and must restore the seed, the flag, and the cleared room; then
  a fresh joiner receives the persisted world in its snapshot.

Regression coverage: `test_quick.bat` green (no solo behavior change), full
`test.bat` (both chapters end to end) green, full `net_test.bat` (all 13 stages)
green. See §7 for the exact run status at commit time.

---

## 5. Deliberate boundaries (what A/B do *not* do)

These are scoped-out on purpose — they belong to C/D/E, not A/B:

- **No characters saved server-side.** The server persists the *world*; each client
  still owns its character through the existing v3 character save + guest
  `write_character_home` flow (MULTIPLAYER.md §5.7). There is no account, no
  server-held identity — that's **step C**, and it's where a real backend enters.
- **The join snapshot ships flags, not cleared-room state.** A joiner rebuilds
  geometry from the seed and gets world flags; it does not receive the server's
  `cleared`/`visited` maps. In the current mirror model this is invisible (cleared
  rooms have no live enemies to stream, so they read empty anyway), and shipping them
  risks changing co-op's "guest re-clears locally" behavior. Adding a `cleared`
  snapshot field is a clean, isolated enhancement if a persistent world later wants
  joiners to *see* cleared rooms as cleared — deferred, not hard.
- **One world per server process.** No zones/instancing/sharding — a single seeded
  world, one chapter at a time, auto-advancing on clear. Many worlds + a joinable
  internet-facing deployment is **step D** (W4 Cloud / Nakama).
- **Trusted clients, still.** The authority *boundaries* are all server-shaped now
  (the whole point), but each client still owns its own movement/costs/cooldowns
  (MULTIPLAYER.md §4.1). Tightening any row for anti-cheat is a per-row policy change,
  unchanged by this work.
- **No MMO systems** — guilds, chat, shared economy, world events are **step E**.

---

## 6. Risks & open questions

- **Auto-advance cadence is a guess.** After a chapter clears with nobody at a
  keyboard, the server waits `SERVER_VICTORY_LINGER` (10 s) for guests to read their
  synced cards, then advances (or rerolls after the last chapter). That's a taste
  knob — a persistent world might instead hold at victory until a client votes, or
  loop a single "endless" chapter. Easy to change; flagged for a design call.
- **Empty-server terrain/hazard drift.** With no clients, the server idles enemies
  (the empty-registry guard) and fires no terrain events (no occupied rooms). Hazard
  patches already spawned will expire on their own timers. No leak observed in the
  stage-12 idle window, but a very-long-lived empty server hasn't been soaked — worth
  a longer idle soak before any always-on deployment.
- **Persistence cadence vs. crash loss.** The 60 s heartbeat + event saves (room
  clears, boss kills, flags) mean a hard crash loses at most ~60 s of pure-movement
  progress (no world-state change persists only on the heartbeat; every *mutation*
  autosaves immediately). Fine for local/friends; a real deployment may want a
  shorter heartbeat or a write-ahead approach — a step-D concern.
- **No host migration / no character server-authority** are explicitly step C/D, but
  worth restating: today a client that crashes mid-run keeps its own character (its
  own save), and the server world is unaffected — which is the correct A/B behavior,
  just not yet the MMO's "your character lives on the server" model.
- **noray path untested for the server.** The dedicated boot uses ENET_DIRECT
  (`--server=ip:port`). Hosting the *dedicated* server behind noray for
  internet-facing friends-play is a one-line `Mode.NORAY` swap through the same
  `NetworkManager.host()`, but it isn't wired or tested here (local ENet was the
  scoped target). Trivial to add when D approaches.

---

## 7. Files touched

Source (all solo-safe — `has_local_player()` is always true off-server):

- `game/scripts/game.gd` — `--server`/`--chapter`/`--fresh` CLI, bodiless boot,
  `_server_boot`, `_server_process`.
- `game/scripts/game_base.gd` — `dedicated`, `has_local_player()`, sim-gate un-pin,
  pause/autosave/side-quest/fight-report guards.
- `game/scripts/game_flow.gd` — bodiless death/wipe/victory/loot/terrain/hazard
  flows, `_death_world_reset` extraction, `_server_after_victory`.
- `game/scripts/game_world.gd` — `switch_chapter` guards.
- `game/scripts/hud.gd` — dedicated dialogue auto-resolve.
- `game/scripts/enemy.gd` — empty-registry freeze guard.
- `game/scripts/net/net_manager.gd` — `MAX_SERVER_GUESTS`, `max_guests` arg.
- `game/scripts/net/net_session.gd` — bodiless host jobs, no phantom peer-1.
- `game/scripts/save.gd` — server-world write/read/apply/exists.

Tests & tooling:

- `game/scripts/tests/net_test_session.gd` — stages 12 & 13 + probes.
- `net_test.bat` — wire the two stages in.

---

*Next up the roadmap: **C — identity/accounts** (persistent player identity; where a
backend first enters), then **D — persistent shared world + scale** (W4 Cloud or
Nakama), then **E — MMO systems**. Nothing in A/B is thrown away by any of them: the
transport seam, the authority seam, and the world/character data split are exactly
the three seams those steps build on.*
