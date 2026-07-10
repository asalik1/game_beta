# MULTIPLAYER.md — Emberfall 4-Player Co-op: Design & Architecture

*Written 2026-07-09. Planning document — no code has been changed. This is the blueprint for adding
opt-in online co-op (2–4 players clearing chapters together) while leaving solo untouched.*

---

## 0. Decisions at a glance

| Question | Decision |
|---|---|
| Topology | **Listen server** — host is player 1, no dedicated server, no accounts, no cost |
| Transport (now) | Godot built-in high-level multiplayer (`ENetMultiplayerPeer` + `@rpc`) |
| Join flow (now) | **noray** NAT punchthrough + relay fallback via the `netfox.noray` addon — host gets a short **lobby code**, friends type it in. Free public instance for the friends phase |
| Transport (Steam later) | `SteamMultiplayerPeer` (GodotSteam) — confirmed drop-in; lobby code becomes a Steam invite. All RPC/sync code unchanged |
| Authority | Host simulates the world (enemies, bosses, loot, flags). Each client owns **its own player's** movement/abilities (trusted client — fine for PvE among friends) |
| Solo mode | **Untouched.** Co-op is opt-in from the title screen; every party scalar is 1.0 at party size 1; solo keeps pausing menus and the existing death flow |
| Difficulty | Enemy HP/damage scale with party size at spawn time, riding the existing `weekly_fx` hook in `add_enemy` |
| Saves | Host's save owns the world (flags, rooms, seed). Guests bring their own character and take home XP/gold/gems/gear + chapter-completion credit |
| Can I hand friends an .exe? | **Yes.** Godot exports are royalty-free (MIT). No Steam needed. See §7 |
| Mobile port (future) | Same netcode compiles for Android/iOS. The noray/ENet path is **kept after the Steam swap** — it's the cross-play transport for mobile (§3.2, §10) |
| Scope guard | `mobile/` stays frozen. All work in `game/`. MMO and mobile ambitions inform the architecture but are NOT this milestone |

---

## 1. Goals & non-goals

**Goals**
- Up to 4 players clear chapters together in one shared, seeded world.
- Opt-in: title screen gains a *Play Together* path (Host / Join with code). Solo flow is byte-identical.
- Difficulty scales with the number of players in the lobby; solo balance is already right and is never touched.
- Distribution without Steam for now: hand friends a zip with the .exe, they join via lobby code.
- Architecture that survives the three known futures: Steam release (transport swap), the mobile
  port (same netcode on Android/iOS, noray as the cross-play transport), and the long-term MMO
  ambition (server-authoritative habits now, dedicated headless server later as a deployment
  change, not a rewrite).

**Non-goals (this milestone)**
- PvP, rollback netcode, lag compensation for competitive play.
- Host migration (host quits ⇒ session ends; guests keep their character progress).
- Cross-play with the frozen `mobile/` snapshot (the *architecture* accounts for the future mobile
  port — see §10 — but no mobile work happens in this milestone; `mobile/` stays untouched).
- Dedicated servers, accounts, persistence beyond the existing save files.
- Player-to-player trading (v2 candidate — see §9).

---

## 2. What the codebase gives us today

Survey of the ~41.6k LOC GDScript codebase (Godot 4.4, Forward+). Full detail lives in the file
references; this is the load-bearing summary.

### 2.1 Assets — things that make co-op easier than it could be

- **The world is already a pure function of a seed.** `_generate_layout` (`game/scripts/game_world.gd:152`)
  derives the entire chapter layout — rooms, packs, elites, shrines, caches, rivers, scenery — from
  `wander_seed` + `chapter_id` via local `RandomNumberGenerator` instances. Send one integer to a
  joining client and it builds the identical world locally. No level streaming, no world-state
  download.
- **A global spawn hook with a multiplier precedent already exists.** `add_enemy`
  (`game/scripts/game_world.gd:1279`) applies `weekly_fx("hp"/"dmg"/"speed")` to every spawn.
  Party-size difficulty scalars ride the exact same hook, and `Story.enemy_stats_at`
  (`game/scripts/story.gd:603`) is the single funnel for base stats.
- **Combat objects already carry owner references.** `Projectile` has `source_player` /
  `source_enemy` (`game/scripts/projectile.gd:9,15,17`); friendly hits resolve through
  `source_player.hit_enemy(...)` so crit/lifesteal/burn attribution has a natural per-player seam.
- **No autoloads, one root.** The whole game is one `Node2D` running `game.gd`; all the
  "singletons" (`Story`, `Balance`, …) are static classes loaded identically on every peer. Nothing
  hides in engine-level global state that a client couldn't reproduce.
- **Balance discipline.** Every tuning number already lives in `balance.gd`, so party scaling is a
  table, not a scavenger hunt.

### 2.2 Blockers — the five real problems

1. **The single-player assumption.** One `var player: Player` (`game/scripts/game_base.gd:48`),
   ~170 production call sites (`enemy.gd` ×20, `boss.gd` ×17, `menus.gd` ×59, `hud.gd` ×8,
   `save.gd` ×6, content bosses, ambience, pickups…). Enemy and boss AI hardcode
   `game.player` as *the* target (`game/scripts/enemy.gd:458`, `game/scripts/boss.gd:82`); there is
   no player registry, no nearest-player query, no threat concept. Hostile projectiles collision-mask
   only the single player body (`game/scripts/projectile.gd:115`). DoT ticks explicitly assume "the
   player is the source — single-player" (`game/scripts/enemy.gd:348`).
2. **Pausing is everywhere.** Every menu (`menus.gd:60`), every dialogue line and choice
   (`hud.gd:1491`, `hud.gd:1594`), and the victory screen (`game_flow.gd:403`) set
   `get_tree().paused = true`; death stalls on a 2-second `await` (`game_flow.gd:584`). A shared
   world can never pause. Roughly a dozen distinct pause points.
3. **Input is fused into simulation.** Abilities/potions poll `Input.is_key_pressed` inside
   `player.gd:_physics_process` (`game/scripts/player.gd:214-226`); movement polls WASD in
   `player_combat.gd:12-22`; interact/menu hotkeys poll in `game.gd:379-396`. There is no
   input-intent layer to hand a remote player.
4. **Combat/loot RNG is global and unseeded.** ~419 `randf()/randi()` call sites; loot uses a
   `randomize()`d `loot_rng` (`game/scripts/game_base.gd:111`). World gen is seed-clean but combat
   rolls and drops would diverge across peers — they must resolve on one machine (the host).
5. **The save file fuses character and world.** One JSON blob per slot (`game/scripts/save.gd:24-80`)
   holds gear/level/vitals *and* flags/rooms/merchants/`wander_seed`. Co-op needs "host owns the
   world, guests own their characters" — a split, not a rewrite (see §5.7).

Secondary friction, handled in passing: only the room containing *the* player simulates
(`game/scripts/enemy.gd:319` vs `cur_room` from one position, `game.gd:305`); the camera is a child
of the player (fine — each client keeps its own local camera); the trusted wall clock for
daily/weekly/mail (`game_base.gd:325`) needs to be host-owned in a session.

---

## 3. Network architecture

### 3.1 Topology: listen server, written server-authoritative

The host's game instance is the authority: it runs the real world (enemy AI, boss brains, hazards,
loot rolls, flags, chapter flow). Guests run a mirrored presentation of that world plus their own
player character. There is no dedicated server and none is needed for 4-player PvE — but **all
gameplay code branches on `multiplayer.is_server()`, never "am I the host player."** That single
discipline is what lets a headless dedicated server exist later (the MMO path) as a deployment
change.

Bandwidth reality check (worst case: 4 players + 40 enemies + 20 projectiles ≈ 64 entities ×
~16 bytes at 20 Hz to 3 clients): **≈ 0.5 Mbps host upload, total.** Any home connection has 10×
headroom. Physics stays at 60 Hz; the network ticks at 20 Hz; remote entities render ~100–150 ms in
the past through a two-snapshot interpolation buffer. Latency, not bandwidth, is the constraint —
and among same-continent friends (<80 ms) this model feels fine without prediction machinery.

### 3.2 Transport & join flow: noray now, Steam later, one seam between them

**Now (the friends-.exe phase):** the [`netfox.noray` addon](https://github.com/foxssake/netfox)
(MIT) against a [noray](https://github.com/foxssake/noray) server. Flow:

1. Host clicks **Host** → registers with the noray server → receives a short **OID string. That OID
   *is* the lobby code** (shown on screen, one click to copy).
2. Friend clicks **Join**, types the code. noray coordinates UDP NAT punchthrough between the two
   machines; if a router/CGNAT refuses (the case where port forwarding is impossible), noray
   **automatically relays** the traffic instead. Either way the addon hands back a connected
   `ENetMultiplayerPeer` — the rest of the stack can't tell the difference.
3. No port forwarding, no public IPs shown to players (only the noray server sees them), no player
   accounts.

Hosting: start on the **free public instance (`tomfol.io:8890`)** — explicitly offered by the netfox
author for prototyping, which is exactly the friends phase. When its limits pinch or we want
reliability, self-host noray (Node.js, Docker image, ports 8890/8891 TCP + a UDP range) on a ~$5/mo
VPS; a fully-relayed 4-player session is <1 Mbps, i.e. rounding error against a 20 TB traffic
allowance. Budget: $0 now, ~$5/mo later.

Rejected alternatives, for the record: **UPnP** (best-effort, widely disabled, useless against
CGNAT — skip entirely); **IP-encoded lobby codes** (only hides the "what's my IP" step, still needs
a reachable port, and the code *is* the host's IP — a doxxing vector if ever shared beyond friends);
**GD-Sync** (proprietary relay + its own API — vendor lock-in exactly on the boundary we want to
keep open); **EOS relay** (free forever and account-less for players, but a large SDK + community
plugin targeting 4.3 — more moving parts than noray for the same result; revisit only if noray
disappoints); **W4 Cloud / Nakama** (full backend platforms — wrong tool now, credible candidates
for the MMO phase).

**Later (Steam):** GodotSteam ships prebuilt GDExtension for Godot 4.4 — no custom engine build.
`SteamMultiplayerPeer` is a real `MultiplayerPeer`: assign it to `multiplayer.multiplayer_peer` and
every `@rpc`, `MultiplayerSpawner`, and `MultiplayerSynchronizer` call runs unchanged; only
addressing differs (Steam lobby ID instead of IP). Steam Datagram Relay then gives NAT traversal +
IP privacy on Valve's network, and the overlay gives "Join Game" invites for free.

**The Steam swap is an addition, not a replacement.** The planned mobile port can never speak
`SteamMultiplayerPeer`, so the noray/ENet path stays alive permanently: all-Steam desktop parties
get lobby invites via Steam, while any party containing a mobile player rides noray codes — same
NetworkManager, same gameplay code, the lobby UI just picks the transport that fits the party.
(This is also why noray self-hosting graduates from "when the public instance pinches" to "before
the mobile port ships.")

### 3.3 The abstraction boundary

One new autoload-style module owns everything transport-shaped:

```
NetworkManager (new, game/scripts/net/)
  host(mode)        -> creates peer: ENet-direct (dev) | noray-punched ENet | SteamMultiplayerPeer
  join(code)        -> resolves code: dev IP | noray OID | Steam lobby ID
  session_code      -> what the host shows on screen
  signals           -> peer_joined(id, char_info), peer_left(id), session_ended(reason)
  version handshake -> §3.4
```

Rules that keep all three futures alive (Steam swap, dedicated server, MMO backend):
- Gameplay code speaks only Godot's 32-bit peer IDs — never IPs, never Steam IDs.
- Never assume peer 1 has a local player (a headless server won't).
- All lobby/join UI talks to NetworkManager only; nothing else touches peers.

### 3.4 Version gate

`SceneMultiplayer`'s built-in authentication phase (`auth_callback` / `send_auth` /
`complete_auth`) holds a joining peer in pre-admission until the host verifies
`{NET_VERSION, build_hash}` against its own — a mismatched client never half-joins. One
`NET_VERSION` constant (bump on any netcode/content change, or derive from the git short hash at
export), printed on the title screen so "you're on 0.3.1, I'm on 0.3.2" is readable without
debugging. Keep the handshake even after Steam auto-updates make it rare.

---

## 4. Simulation & sync model

### 4.1 Authority table

| Thing | Authority | How it syncs |
|---|---|---|
| World layout | — (deterministic) | Host sends `wander_seed` + `chapter_id` + flags snapshot on join; client rebuilds locally |
| Own player: position, facing, anim, dashes | **Owning client** | `MultiplayerSynchronizer` (on-change mode), ~20 Hz, interpolated on remotes |
| Own player: ability casts, mana/cooldowns, potions | **Owning client** (trusted) | Client executes locally, RPCs the cast event (ability id, aim point, roll seed) to everyone |
| Damage to enemies | **Host** | Client RPCs "hit enemy E with ability A" → host resolves through the existing `hit_enemy`/`take_damage` path, broadcasts result (hp, crit text) |
| Enemy/boss AI, movement, telegraphs | **Host** | Enemies: one hand-rolled ~20 Hz unreliable snapshot RPC (`PackedByteArray`: id, x, y, facing, anim, hp — ~12–20 bytes each; one packet replaces 40 synchronizers). Bosses: `MultiplayerSpawner` + `MultiplayerSynchronizer` (few of them, lots of state). `play_action` ability-strip one-shots are EVENTS, not state — they ride as reliable event RPCs beside the sync (attack-anim standing rule, ART_TASKS.md) |
| Projectiles | Spawn event only | RPC (origin, direction, speed, owner); each peer simulates the flight locally and deterministically; **hits resolve only on the authority side** (host for enemy projectiles/damage, owning client reports its own projectile's hits to host) |
| Loot rolls, chest contents, gold/XP/gem awards | **Host** | Host rolls with `loot_rng`, RPCs per-player results (§5.5) |
| Story flags, quest state, chapter transitions | **Host** | Reliable RPCs; flags snapshot on join |
| Damage to players | **Host decides, owner applies** | Host detects the hit (it runs enemy AI), RPCs `take_damage` to the owning client so mitigation/passives run on the machine that owns the stats |
| Daily/weekly/mail clocks | Host's `trusted_now` during a session | Guests' own daily/mail stay local to their own save |

**On "trusted client":** letting each client own its character's movement, costs, and cooldowns is
a deliberate scoping decision. It eliminates prediction/reconciliation entirely (the hardest 30% of
netcode) and its only cost is cheat-resistance — irrelevant in invite-only PvE with friends. The
authority *boundaries* are still drawn in the server-authoritative shape, so tightening any row of
the table later (for public matchmaking or the MMO) is a policy change per row, not a redesign.

### 4.2 RNG policy

- **World gen:** already seed-pure — untouched.
- **Loot/rewards:** host-only rolls (the `loot_rng` path), results RPC'd. Divergence impossible.
- **Combat rolls (crit/dodge/proc):** rolled by whichever side owns the resolution per the table
  above; the *result* is what syncs, so global-RNG nondeterminism stops mattering.
- **Cosmetic RNG** (particles, `art.gd`, sfx variation): stays local and unsynced, free to diverge.

### 4.3 Rooms & simulation range

Today only the single player's room simulates (`enemy.gd:319`). Co-op generalizes the gate to a set:
`active_rooms` = union of rooms currently occupied by any player. The host simulates that set;
`cur_room` stays as each client's *local* player room for camera/ambience/music. No tethering, no
leash — players may split up (the sim cost of a few extra live rooms is trivial). Boss doors keep
the existing seal mechanic: the fight arms when the first player crosses the threshold; the door
seals a few seconds later (design knob, §5.3).

### 4.4 What netfox pieces we take

Adopt **`netfox.noray`** unconditionally (the join flow). Optionally adopt netfox core's
`NetworkTime` (tick alignment) and `TickInterpolator` (remote-entity smoothing) rather than
hand-writing them. **Skip `RollbackSynchronizer`** — rollback/prediction exists for competitive
latency-sensitive PvP; among friends in PvE it buys little and taxes every gameplay system with
resimulability requirements. Revisit only if cross-ocean melee feel becomes a real complaint.

---

## 5. Co-op game design

### 5.1 Lobby flow (opt-in)

Title screen gains **Play Together** beside the solo path:

- **Host:** pick character (existing roster), pick chapter (their unlocks) → lobby screen shows the
  code + joined players (name, class, level) → **Start** launches when 1–3 friends have joined.
  Host can start solo-in-lobby too (party of 1 = literally solo numbers).
- **Join:** enter code → pick character from *your own* roster (any class, any level) → wait in
  lobby → host starts.
- Lobby locks at chapter start (no mid-run joins in v1 — see §9). Leaving mid-run is always safe
  for the leaver (their character autosaves, §5.7).
- Class stacking is allowed (four archers welcome). Level gaps are the players' problem in v1;
  the lobby shows levels so friends can self-select (§9 has the sidekick option for later).

### 5.2 Difficulty scaling

All scalars live in `balance.gd`, are **indexed by party size, and index 1 is 1.0** — solo is
untouched by construction. Applied at spawn time in `add_enemy` alongside `weekly_fx`, so they
compose with weekly challenges and automatically re-evaluate as rooms build (a mid-run disconnect
means the *next* packs spawn at the smaller party's numbers; already-spawned enemies keep theirs).

Starting values (measure-then-correct applies; these are the opening bid, tuned from the D3-style
+~75–90%-HP-per-head convention adjusted for this game's high player DPS synergy):

```gdscript
# balance.gd — party scaling (index = party_size, [0] unused)
const PARTY_HP_MULT   := [0.0, 1.0, 1.90, 2.80, 3.70]  # ~ +90% HP per extra player
const PARTY_DMG_MULT  := [0.0, 1.0, 1.10, 1.20, 1.30]  # mild: aggro splits 4 ways
const PARTY_BOSS_RATE := [0.0, 1.0, 1.10, 1.20, 1.30]  # boss cast/telegraph cadence (phase-2 knob)
```

Rationale: 4 players bring roughly 4× DPS *plus* synergy (stacked debuffs, overlapping AoE), so
enemy HP scales near-linearly but slightly under (co-op should feel a touch generous — it's a
party). Enemy damage rises only mildly because per-player incoming pressure *drops* when aggro
splits; the real 4-player threat should come from bosses keeping cadence against multiple targets,
not from mobs one-shotting.

**Boss floor rule extends to parties** (see `boss-design-principles`): every boss's non-opt-in
floor damage must reach *someone who isn't the current target*. Caster-lineage bosses pass
automatically (bolts can rotate targets); charge-lineage bosses need their second threat to pick a
non-target player at least sometimes. v1 rule of thumb: signature mechanic targets the aggro
holder, floor damage rotates among the others. This is a per-boss tuning sweep in phase 3, not a
redesign — the mechanics exist, only target selection generalizes.

**Enemy targeting v1:** nearest living player, with two dampers — sticky target (re-evaluate on a
~1 s cadence, not per frame, so packs don't oscillate) and a taunt hook (warrior/paladin kits can
force-target later; the seam is one function: `pick_target(enemy) -> Player`). Full threat tables
are MMO-phase work.

### 5.3 Death, revive, wipe

Solo keeps its existing flow. In co-op:

- A player at 0 HP enters a **downed** state: 30 s bleed-out, crawl-speed movement, no abilities.
- Any teammate channels **3 s to revive** (interrupted by taking a hit); revived at 30% HP.
  Constancy-lean healing interacting with revives is a phase-3 tuning note.
- Bleed-out expiry ⇒ that player is a ghost until the room is cleared, then auto-revives.
- **All players down ⇒ wipe**, which runs the *existing* death flow party-wide
  (`game_flow.gd:on_player_died` — gold tithe each, death-room reset, boss reset/leash, respawn at
  the safe room). The solo path becomes "a party of 1 wiping," which keeps one death code path.

### 5.4 Pause, menus, dialogue

`get_tree().paused` is **never set during a co-op session**; a `Game.coop` flag gates every current
pause point (solo keeps pausing exactly as today).

- **Menus** (inventory, skills, shop, map…): non-pausing overlay; your character stands there,
  vulnerable, with a visible "menuing" marker over their head — the standard MMO contract, and it
  synergizes with shelters already being SAFE ground (dome + warded): menu in a shelter, or accept
  the risk.
- **Dialogue:** runs as a local overlay for the player who initiated it; the world keeps moving.
  Choices move *that player's* resonance/standings (they're per-player state already,
  `player_core.gd:30`); world-mutating consequences (flags, quest acceptance, merchant states) RPC
  through the host, and other players get a one-line toast ("Ashka accepted: The Long Sleep").
  Story-critical chapter beats (the handful that gate progression) require the party within the
  beat's room and mirror the text to everyone — the initiating player drives the choices.
- **Victory/results screen** (`game_flow.gd:403`): shown to all simultaneously (chapter's over —
  it may pause, nothing left to simulate); host's continue advances the party.
- Death's `await create_timer(2.0)` is replaced by the §5.3 state machine.

### 5.5 Loot, rewards, economy

The reward-economy rule — every faucet has one job — survives by making every faucet
**per-player-instanced**, so each player's economy is exactly the tuned solo economy:

- **XP:** kills award *full* XP to every party member in the active room set. Not split — co-op
  must not be slower leveling than solo, and enemy HP scaling already normalizes kill *rate*.
- **Gold/gems/gear:** host rolls **per player** (independent rolls per head); drops are visible
  only to their owner (classic instanced loot — no ninja problem, no trade needed). Chests open
  per-player: one chest node, each opener gets their own contents roll.
- **First-clear events, exploration caches, shrines:** trigger for the party (shared moment),
  rewards instanced per player.
- **Greed/Hunger layer:** charged-coin GOLD RUSH, Constancy heals, Hunger executes — all read the
  *owning player's* lean; already per-player state, no design change.
- Forgotten-loot mailing (`flush_dropped_loot`) mails to each item's owner.

### 5.6 Camera, HUD, UI

Each client keeps its own camera (already a child of its player) and its own HUD bound to its
*local* player — the fix is `hud.update_stats(local_player)` instead of the global. Additions:
party frames (3 compact ally bars: HP, class icon, downed indicator), offscreen-ally edge arrows,
and name labels over remote players. Boss bar is shared (host syncs boss HP). Damage numbers show
your own big, allies' small — taste pass in phase 3.

### 5.7 Saves & progression

- **Host:** their existing save file *is* the session world — flags, cleared rooms, merchants,
  `wander_seed`, plus their own character. Unchanged format, co-op just plays it.
- **Guests:** their character (identity, level, gear, gold, gems, standings, resonance) loads from
  their own save file into the host's world; world-state fields in their file are simply not used
  while guesting. On autosave ticks/leave, only their character block writes back. This is the
  save-format split from §2.2(5): `save.gd` separates the blob into `character:{...}` and
  `world:{...}` sections (a mechanical regrouping — same fields, one nesting level, one
  version bump with migration on load).
- **What guests take home:** all character deltas (XP/levels, gold, gems, gear, standings,
  resonance moves) + chapter-completion credit in their own `meta.json` if the party finishes the
  chapter (unlocks their own next-chapter/replay exactly as a solo clear would). ARPG convention:
  your character travels, the world belongs to the host.
- **What guests don't get:** the host's world flags/story state. Story beats they witnessed in the
  host's world don't mark their own solo world (avoids half-progressed story states; see §9).

### 5.8 Player-facing surface checklist

- Codex: a **Co-op page** (how scaling, revives, and loot instancing work) ships with phase 3 —
  the codex goes stale silently, so it's in the plan, not an afterthought.
- Title screen version string (§3.4). Lobby UI. Downed/revive indicators. Party frames.
- Settings: a "network smoothing" toggle is *not* offered — interpolation just works; fewer knobs.

---

## 6. Refactor roadmap

Ordered so that **phase 0 is pure solo-safe groundwork** (mergeable continuously, full test suite
green throughout — compile gate → `test_quick.bat` → `test.bat` discipline unchanged), and each
later phase has a demo-able exit criterion. Sizes are honest: the survey puts ~12–13k LOC of
gameplay logic under the one-player assumption; most call sites are mechanical renames, a few
hundred are real decisions.

**Phase 0 — De-singleton the player (solo-visible behavior: none).**
- `game_base` grows `var players: Array[Player]` + `var local_player: Player`; `player` remains as
  an alias so 800+ references keep compiling while call sites migrate deliberately.
- New queries where targeting/AI needs them: `nearest_player(pos)`, `players_in_room(idx)`,
  `any_player_alive()`. Enemy/boss `_think` and every `game.player.global_position` in AI paths
  move to `pick_target()` / nearest-player (in solo these return the one player — bit-identical
  behavior, assertable by the DPS bench).
- Input intent layer: `player.gd`/`player_combat.gd` read from an `intents` struct filled by a
  local poller (solo: same keys, same frame — zero feel change). This is the seam a remote peer's
  RPCs will fill later.
- Pause gating: every `get_tree().paused = true` routes through `game.request_pause()` (solo:
  pauses as today; co-op: overlay mode). Death `await` refactored into a small state machine with
  the solo path unchanged.
- Mechanical fixes: hostile projectile mask covers a *players* physics layer; DoT ticks carry a
  `source` ref instead of assuming the player; `hud.update_stats(local_player)`.
- Save format v3: `character`/`world` split with load-time migration.
- Exit: `test.bat` fully green, DPS bench unchanged within variance, a human plays a chapter and
  feels nothing.

**Phase 1 — Session skeleton (first networked build).**
- `game/scripts/net/`: NetworkManager (host/join/code/version-gate), `netfox.noray` vendored under
  `addons/`, lobby UI in `menus.gd`'s idiom, character handoff (guests send their character block).
- Spawn N players (`MultiplayerSpawner`), client-owned movement sync + interpolation, shared
  `wander_seed` world build, flags snapshot on join, `active_rooms` set.
- Exit: **4 players walk the same generated world and see each other move smoothly.** Enemies may
  still be host-side dummies to remotes.

**Phase 2 — Combat over the wire (the risky phase).**
- Enemy swarm snapshot RPC @20 Hz; host-authoritative enemy/boss AI with `pick_target()`;
  ability-cast events; hit-resolution RPCs both directions; projectile spawn-events with local
  deterministic flight; loot instancing; party scalars in `add_enemy`; the deferred-spawn idioms
  (ricochet/chest — `projectile.gd:262`, `enemy.gd:1077`) audited so spawns happen only
  authority-side and replicate as events.
- Exit: **a full combat room clears with 4 players; kill feed, drops, XP all correct on every
  screen.**
- This phase eats the surprises. Budget accordingly; do not stack other work beside it.

**Phase 3 — Flow, story, death, UI breadth.**
- Downed/revive/wipe; non-pausing menus + dialogue overlay + beat mirroring; chapter
  transitions/victory sync; boss target-rotation sweep (§5.2) across BOSSES.md's roster; party
  frames/arrows/labels; codex co-op page; terrain events and weekly challenges in-session.
- Exit: **a chapter cleared start-to-finish by 4 players, including a wipe and a story beat.**

**Phase 4 — Hardening & the Steam seam.**
- Disconnect handling everywhere (mid-combat, mid-dialogue, host loss ⇒ graceful session end +
  guest autosave), rejoin-into-lobby (not mid-run), soak sessions on the public noray, self-hosted
  noray decision, SmartScreen-friendly zip packaging, netcode profiling pass.
- GodotSteam transport behind NetworkManager when the Steam release approaches (small, isolated by
  construction).

**Balance rounds** for `PARTY_*` tables follow the house method: play, measure (extend the DPS
bench with a party-size dummy preset), correct, and log rounds in `BALANCE_HISTORY.md`.

---

## 7. Distribution without Steam — "can I just give friends the .exe?"

**Yes, unconditionally.** Godot is MIT-licensed: exported games are royalty-free and yours to give
to anyone, commercially or privately, no Steam or any storefront required. Only obligation: include
Godot's copyright + MIT notice in the credits (we already ship a credits file — add the engine
notice there).

Practicalities:
- **Ship a .zip** (exe + .pck), tell friends to extract before running.
- **SmartScreen will warn once per build** ("Windows protected your PC") because the exe is
  unsigned and unknown: the fix is *More info → Run anyway*, once. Tell them in the same message as
  the lobby code. If an AV heuristic quarantines it (occasionally happens to Godot exports), submit
  the false positive to Microsoft — or don't bother during the friends phase.
- **Connectivity is solved by noray, not by the exe** — no port forwarding or router surgery for
  anyone; host reads out the lobby code, friends type it. Works behind CGNAT (relay fallback).
- If distribution widens before Steam: Azure Artifact Signing (né Trusted Signing) is ~$10/mo and
  open to individuals — signing shows a publisher name and speeds reputation, though even signed
  builds start cold with SmartScreen. On Steam the whole problem vanishes (Steam-installed games
  don't hit SmartScreen).

---

## 8. Testing strategy

- **The existing discipline holds:** compile gate first, `test_quick.bat` to iterate, `test.bat`
  green before staging. Phase 0 is fully covered by the existing suite by design.
- **New: `net_test.bat`** — launches two headless instances on localhost ENet (host + scripted
  client), asserts the handshake, world-seed reproduction, player spawn on both sides, a scripted
  combat exchange, and disconnect cleanup. Same snapshot/restore etiquette as autotest; same
  wall-clock-polling rule (network adds real async — never frame-count).
- **Determinism assert:** a test that builds the same `wander_seed` world twice in two processes
  and diffs the room/pack manifest — guards the seed-purity that the whole join flow leans on.
- **Human playtests are load-bearing** for feel (interpolation, revive timing, boss cadence at 4).
  Budget real sessions with real friends per phase exit — this is also the first external
  playtesting this project has ever had, worth exploiting for general feedback.

---

## 9. Gaps, risks, open questions

- **Mid-run join:** v1 locks the lobby at chapter start. Desirable later (drop-in at shelters
  between rooms is the natural design: shelters are SAFE, world state is a seed + flags snapshot).
  Deferred, not hard.
- **Host migration:** out of scope. Host quits ⇒ session ends, guests autosave. Revisit only if
  session lengths make it a felt pain.
- **Level-gap parties:** v1 shows levels in the lobby and trusts friends. If gaps hurt, the
  sidekick pattern (temporarily float low-level guests' effective stats toward the host's chapter
  band, rewards at their own level) is the known fix — a phase-4+ decision.
- **Trading:** not in v1 (instanced loot removes the need). A trade window is a v2 nicety; the
  discard-throw mechanic is NOT a trade channel (items stay owner-instanced) to keep the economy
  faucets clean.
- **Story flags for guests:** guests deliberately take no world flags home (§5.7). The cost: a
  guest who saw chapter 5's beats in co-op replays them fresh in their own world. Acceptable and
  arguably correct (it's *their* story run); revisit if playtesters hate it.
- **Dialogue lockout griefing:** one player opening dialogue doesn't stop others from playing —
  but two players talking to the same NPC simultaneously needs a simple busy-lock (first
  interactor wins, second gets a "busy" bark).
- **Cheating:** explicitly accepted under trusted-client for invite-only co-op. The authority
  table (§4.1) is the checklist of what to tighten if this ever meets strangers.
- **Melee feel over high ping:** the known worst case of the no-rollback choice. Mitigation order:
  interpolation tuning → generous host-side hit windows for client-reported melee → only then
  consider netfox rollback for melee arcs specifically.
- **`boss.gd` (2.4k LOC) target-generalization sweep** is the largest single content risk — every
  boss hand-references `game.player` in its telegraphs. The §5.2 rule keeps it mechanical, but it
  needs a per-boss verification pass against BOSSES.md.
- **Public noray instance** has no uptime guarantee — fine for friends, and the self-host escape
  hatch is one Docker evening. Decide by end of phase 4 (and self-host becomes mandatory before the
  mobile port ships — §3.2).
- **Mobile clients disconnect constantly by nature** (screen lock, app suspend, incoming calls,
  network handoff wifi↔cellular). The v1 posture — disconnect = leave, rejoin only via lobby — is
  fine for desktop friends but would feel brutal on phones. When the mobile port becomes real,
  mid-run rejoin gets promoted from "deferred" to required, and a short grace window (hold the
  character in-world ~60 s awaiting reconnect before despawning) is the likely shape. Designing the
  join flow around "seed + flags snapshot + character block" (§4.1) is what keeps that cheap.
- **Weekly/daily clocks in-session** use the host's trusted clock; a guest's own daily/mail state
  never ticks off another player's clock (no clock-cheese across saves).

---

## 10. The long game: Steam, mobile, and the MMO after it

This plan deliberately builds the three seams the future needs and nothing more:

1. **Transport seam** (NetworkManager): ENet↔noray now, `SteamMultiplayerPeer` at Steam release —
   verified drop-in, zero gameplay-code churn.
2. **Authority seam** (`multiplayer.is_server()` everywhere, no "host = player 1" assumptions):
   a headless Linux dedicated-server export becomes a deployment choice. That's the bridge from
   listen-server co-op to persistent shared worlds — at which point the backend conversation is
   W4 Cloud (AGPL, Godot-native, by Godot's founders) or Nakama, and nothing built here is thrown
   away.
3. **Data seam** (character/world save split): "your character travels between worlds" is already
   the MMO's data model in miniature — same split, bigger world registry.

**The mobile port rides these same seams.** ENet/UDP and the noray flow work identically on
Android/iOS, so a mobile build joins the same sessions through the same NetworkManager — the
transport seam is the cross-play plan (§3.2), not a parallel stack. Specifics to hold in mind now,
so the port inherits multiplayer instead of retrofitting it:

- **Build parity is enforced automatically.** The `NET_VERSION` handshake (§3.4) fences the frozen
  `mobile/` snapshot out of live sessions by construction — cross-play requires re-cutting the
  mobile snapshot from the same revision as the desktop build, which is the existing porting model
  anyway (snapshot copy of `game/`). No skew can half-join.
- **Phones join; desktops host.** A listen server on a phone dies to screen-lock, thermal
  throttling, and OS suspend. v1 of cross-play: mobile clients can join any session but hosting is
  desktop-only (or phone-hosting allowed with a loud "keep the screen on" warning). A dedicated
  headless server — the MMO seam — is what eventually makes host-device fragility moot.
- **The input-intent layer is the touch seam.** Phase 0's intents struct (§6) is exactly where the
  planned touch controls plug in: a touch poller fills the same struct the keyboard poller fills,
  and the netcode never knows the difference. Agreed control scheme (2026-07-10, Wild Rift as the
  reference layout): **left thumb = movement joystick** (fills `intent_move`); **right thumb = the
  ability cluster** — a1/a2/a3/ult arranged in a Wild Rift-style arc in the bottom-right corner,
  with potion + contextual interact beside it (each button fills its intent bool); **target lock =
  a dedicated HUD button** — tap to lock the nearest/current target, **hold and swipe away to
  release the lock** (the swipe-off gesture maps to the same unlock intent the keyboard sends).
  Because every one of these is an intent-field write, the mobile HUD is pure presentation — no
  gameplay code forks per platform.
- **Cellular data is a non-issue but not zero:** the ~20 Hz snapshot stream is tens of KB/s —
  worst case ~50–70 MB/hour, far less with on-change sync. Fine on any plan; worth a line in the
  mobile settings screen someday, not worth engineering around.
- Mobile-specific disconnect churn promotes mid-run rejoin to a requirement — logged in §9.

The meta systems already built solo-first (daily rewards, buff bar, boss records, minimap) were
designed to seed a multiplayer backend; co-op is the first consumer. Keystones/mastery
(Act-2+ layer) should assume party play exists by the time they land.

---

*Sources for §3/§4/§7 claims: Godot 4.4 MultiplayerSynchronizer/SceneMultiplayer docs, Godot
scene-replication announcement, noray + netfox repos and docs (foxssake), GodotSteam 4.16+ release
notes and MultiplayerPeer changelog, godotengine.org/license, Microsoft SmartScreen/Artifact-Signing
docs, KinematicSoup & Edgegap netcode-bandwidth references. Verified 2026-07-09.*
