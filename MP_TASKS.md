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

### MP-09: Enemy/boss mirror + telegraphs to guests — OWNER: agent-M — status: DONE (host announces every enemy at Enemy._ready — ONE choke point under add_enemy/boss factories/summons/dev spawns; reliable spawn{id,kind,level,zone,pos,elite,boss,hp}/death/despawn/elite/play_action events + ~20 Hz unreliable StreamPeerBuffer state packet 14 B/enemy (id u32, pos 2xf32, flip+walk u8, hp-frac u8) for the active_rooms set; guests build REAL Enemy.make/Boss.make_boss nodes hard-gated by enemy.gd net_mirror — no AI/damage/collision, snapshot-lerped, strip clock live; telegraph+telegraph_safe broadcast from their game_base definitions and replay guest-side flagged net_visual (full visuals incl. decoys+dread ramp, zero damage); boss mirrors ride game.bosses so the existing per-frame bar shows/updates on guests, session hides it on mirror death; party_hp/party_dmg applied in make_boss + PARTY_BOSS_RATE consumed at the one shared cd tick in Boss._think — party of 1 skips both; late joiners get a full live-enemy snapshot at join-ready; net_test stage 3 (--net-stage=3, port 48215) proves census/gating, position tracking, hp sync, play_action strip, boss bar, telegraph render, kill-frees-mirror; test_quick + net_test all 3 stages + full test.bat green)
Host streams enemy state for active rooms: spawn/despawn/death events + ~20 Hz snapshot
(id/pos/facing/anim/hp), guests render non-simulating mirror enemies; play_action one-shots as
event RPCs; telegraph/telegraph_safe mirrored as visual events (co-op dodging!); boss mirror +
boss-bar sync; party scalars applied to BOSS stats at spawn + PARTY_BOSS_RATE cadence knob consumed.
net_test stage 3 proves: guest sees mirrors tracking host positions, telegraph event renders, boss
bar syncs. DO NOT touch chest.gd / shot_chests.* (owner's active session).

### MP-10: Ability casts + hit resolution over the wire — OWNER: agent-X — status: DONE (guest runs its FULL kit vs mirrors, trusted-client: the funnel is Enemy.take_damage's net_mirror branch — optimistic local juice (number/flash/bar/predicted hp; silent env ticks excluded so guest hazard copies never double-bill) + _rpc_hit_enemy{id, RAW amount, dir, crit} → host re-resolves vuln/ward/plate authoritatively with the guest's SHELL as hit_src (reflect/counter answer the attacker; victim turns on it for one MOB_RETARGET_EVERY window — solo bit-identical since striker==THE player); every rider has ONE door (apply_burn/bleed/toxin/slow/stun + NEW apply_vuln/apply_knock(crush)/chains-"drag") forwarding as _rpc_enemy_status w/ shell as DoT src, mirror keeps local timer bookkeeping (ticked in _net_mirror_tick, no damage) so marked_crit/Killing-Frost/Serpent's-Due/crush math reads like solo; mirrors now carry enemy LAYER 4 / mask 0 — guest projectiles detect them + body-block feels solo; enemy→guest = Player.take_damage/apply_freeze/root/chill forward to owner ("host decides, owner applies", heavy flag intact, attacker rides as net_id and re-resolves vs the owner's mirror; chill throttled 150ms); telegraph/telegraph_safe resolutions sweep ALL players (solo loop == old single read); vitals {hp,max_hp,mp} on-change ≤2 Hz reliable ~25 B + immediate on hp drop, sets shell dead flag so AI drops fallen guests; projectiles both ways as ~200 B spawn-event dicts → net_visual copies (deferred spawn, no damage, hostile ids + Mirrorstep consume RPC frees the host's REAL bolt); dynamic hazards (sower/bloat + all 10 boss patch sites) broadcast via Enemy._hazard — each machine's _apply_hazards ticks its OWN player; kill XP fans FULL to guests in active rooms (elites/summons 0 never wire); untargetable rides state-flag bit 2 (burrow/blink gate guest auto-aim); guest death respawn triggers a host enemy-resync sweep (the local death flow frees mirrors as if the world were its own); net_test stage 4 (--net-stage=4, port 48217, assassin guest) proves: intent-driven stab → host hp drop == RPC'd amount exactly + mirror converges, burn rider ticks host-side w/ shell src, host hit on shell → owner's REAL hp drops + vitals return, fan-of-knives kills a slivered mob through the physics layer → death event + kill XP + host saw the visual copies, hostile spawn event renders, phase-flag round-trips; KNOWN GAPS: game_flow:679 terrain-event lava + ch4_bosses:157 cinder flicker stay host-only (files out of scope), hex rune X-mark visuals are caster-local, DoT tick numbers don't render on guests; test_quick + net_test ALL 4 stages + full test.bat green)
Guest kit runs locally vs mirrors (trusted client: costs/cooldowns/juice); hit_enemy funnel RPCs
{net_id, amount, crit, riders} to host, host applies through real paths w/ shell as source;
enemy->shell damage forwards to owner ("host decides, owner applies") incl. heavy flag; shell
vitals sync; projectile spawn-events both directions (visual copies); kit audit for off-funnel
enemy touches; XP-on-kill to party in active rooms; net_test stage 4.

### MP-11: Loot/reward instancing — OWNER: agent-G — status: DONE (every faucet pays per head via a personal-event layer in net_session.gd: trash kills fan _rpc_mob_kill{pos, BASE gold, host-rolled-per-head Gold Rush} — the owner spawns its own pile and applies its OWN Hunger/weekly/greed (mob_kill_share also rolls the chest chance owner-side, the one roll that reads the owner's unsynced greed); boss/elite/curse payouts are host-rolled per player from loot_rng (one full independent sequence per head, gear rolls the RECEIVER's class, curse gem odds the receiver's level) and ship as _rpc_award event arrays (schema documented at game_flow's roll_*_pack block — gold/chest/gem/item/stone/bag/sfx/toast) applied deferred through the owner's normal award paths (give_loot bag-or-ground + own dropped_loot registry, acquire_bag); rogue-boss brawls fan chest+pile via host_award_all; bounty/vault credit fans as _rpc_credit (boss→boss_kills+vault_note_boss, elite, room) gated like the XP fan-out — counters are character-owned and ride the guest's save home; final boss fans _rpc_flush_loot (each guest's strays → ITS mailbox) + _rpc_first_clear (full beat rolled+mailed owner-side, host-first-clear trigger per §5.5); pickups gated to the LOCAL player in pickup.gd (a shell never eats your pile); CHESTS instanced from OUTSIDE chest.gd (file untouched): every machine spawns its own copy (world-gen/cache/shrine chests already exist per machine via seed purity; kill-flow chests ride the award events) and net_session._gate_chest rewraps chest.body_entered with a local-player filter via game.child_entered_tree — each copy rolls its own contents for its own opener; net_test stage 5 (--net-stage=5, port 48219) proves: solo kill pays EXACTLY the coin math once, party kill grows both wallets independently (host holds exactly its own pile; the guest's shell standing on host coins eats nothing), boss kill = two chests two independent rolls (guest opening ITS copy leaves the host's shut, both items logged), crafted award pack lands in guest bags, guest stray flushes to the GUEST's mailbox with the host's untouched; test_quick + net_test ALL 5 stages + full test.bat green)
Host rolls per player (gold piles, gems, gear, bags), pickups visible/collectable by owner only,
mail flush per owner, first-clear/shrine/cache events instanced. Scope AWAY from chest.gd (owner's
uncommitted work) — instance at the roll/award seams in game_flow; if chest-open instancing needs
chest.gd, keep the edit minimal, leave it UNSTAGED, and flag it.
KNOWN GAPS (MP-11, deliberate): guests don't get the boss-kill full-heal (vitals flow = MP-12's
downed/revive territory); weekly-challenge completion reward + victory-screen flow pay host-only
until MP-14/15 wire victory/weekly in-session; note_kill codex tallies + achievements don't fan to
guests (records, not economy — decide at the codex co-op page, phase 3); shrines/caches/curse-offers
exist per machine off the shared seed (each head pays and collects its own) but their once-per-room
FLAGS are per-machine until MP-13 syncs world flags — a guest's shrine feed doesn't consume the
host's shrine; side-quest/convo payouts pay whichever machine runs the convo (MP-13).

**PHASE 2 COMPLETE** — mirrors (MP-09) + combat (MP-10) + loot instancing (MP-11).

## Wave 6 — Phase 3: flow, story, death, UI breadth (parallel again after MP-11)

### MP-12: Downed/revive/wipe — status: PLANNED
Files: game_flow.gd, player chain (downed state), hud (downed indicator), net_session (down/revive
RPCs). §5.3: 30s bleed-out crawl, 3s interruptible channel revive at 30% HP, ghost-until-clear on
expiry, all-down = existing wipe flow party-wide. Solo keeps its exact current flow.

### MP-13: Dialogue overlay + story sync — status: PLANNED
Files: hud.gd (dialogue), game_base.gd (convo engine), net_session. §5.4: convo runs as local
overlay (world live), choices move initiator's resonance, world flags RPC through host, toast to
others; busy-lock per NPC; chapter-critical beats gate on party-in-room and mirror text to all.

### MP-14: Party UI — status: PLANNED
Files: hud.gd, net_session (reads shell vitals from MP-10). §5.6: 3 compact ally frames (HP, class
icon, downed marker), offscreen-ally edge arrows, name labels over remotes, own damage numbers big /
allies' small. Victory/results + chapter-transition sync (host advances the party) lands here too.

### MP-15: Boss target rotation + world events in-session — status: PLANNED
Files: boss.gd, content bosses, game_flow.gd (terrain events), codex co-op page expansion.
§5.2 floor rule: signature targets aggro holder, floor damage rotates non-targets — per-boss sweep
against BOSSES.md; terrain events + weekly challenge verified/wired in-session.

## Wave 7 — Phase 4: hardening — status: PLANNED
MP-16 disconnects/rejoin (graceful everywhere, guest autosave on drop, host-loss session end);
MP-17 soak + flake hunt (0xC0000005 shutdown flake, ObjectDB leak warning, long-session drift);
MP-18 packaging (export/zip/SmartScreen README for friends; noray self-host decision = OWNER).

## PLAYTEST NOTES — taste calls defaulted while the owner was away (review these!)
- PARTY scalars: HP x1.9/2.8/3.7, dmg x1.1/1.2/1.3, boss cadence x1.1/1.2/1.3 (balance.gd) — opening
  bids from MULTIPLAYER.md §5.2, untested at real 2-4p. Measure-then-correct.
- Mirror smoothing: enemies lerp at the move-sync cadence (MP-09) — check pack motion doesn't read
  "floaty" vs solo; knob is the lerp in enemy._net_mirror_tick.
- Guest hit feel: damage numbers play optimistically on the guest, authoritative hp converges via
  snapshot — watch for visible "kill lag" on low-HP enemies at real latency.
- MP-10 aggro-turn: ANY player damage snaps the victim's target to the attacker for one sticky
  window (~1s, MOB_RETARGET_EVERY) — bosses included. Feels like tank-trading; if taps stealing
  boss aggro reads wrong at 2-4p, the knob is the striker block at the top of Enemy.take_damage.
- MP-10 guest fidelity quirks: a warded mob shows FULL numbers on the attacking guest until the
  bar corrects (ward state isn't mirrored); enemy DoT ticks show no numbers on guests (hp bar
  moves only); hex rune / Death-Mark X ride only the caster's own screen.
- MP-11 loot feel defaults (taste calls, review at real 2-4p): every kill spawns a pile on EVERY
  screen with no room gating — a guest AFK in the village accumulates piles at the host's farm
  spots and can sweep them later (collection is the gate, per-head economy holds; if that reads as
  free money, gate _rpc_mob_kill on the XP fan-out's room rule). Bounty/vault credit IS gated like
  XP. Boss gear for guests rolls THEIR class (no cross-class trash), first-clear beat fires off the
  HOST's first clear (a veteran guest re-earns it in a friend's fresh world — blueprint's call).
- MP-11 chest reads: both players see "their" chest at the same spot and each opens their own copy
  — watching a friend's chest stay shut after they loot "the same" chest is the classic instanced-
  loot look; a grade-halo may differ per screen (grade rolls per machine at drop). If that reads
  wrong, the fix is shipping the host's grade in the award event, not sharing contents.
- (grows as waves land)

## Integration gate (orchestrator) — PASSED 2026-07-10
- [x] Full `test.bat` green on the combined tree (AUTOTEST PASS, exit 0, zero SCRIPT ERRORs)
- [x] DPS bench sanity: 18/18 specs within variance of freshest references (archer hunt/storm
      match the post-mana-round recorded values to <0.4%; TIERLIST rows for those were already
      flagged stale pre-phase-0 — see BALANCE_HISTORY top entry)
- [x] Phase-0 paths staged (path-scoped; index also carries prior sessions' sprite/UI staging —
      any future commit must path-scope or describe the union)
