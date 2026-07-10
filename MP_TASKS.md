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

### MP-12: Downed/revive/wipe — OWNER: agent-D — status: DONE (§5.3 in full, owner-authoritative: a lethal hit ONLINE converts to DOWNED in the owner's take_damage — 30 s bleed-out (`down_t`), crawl at 0.35x, actions/potions/interact zeroed at the intents poll, un-hittable (take_damage early-outs downed/ghost bodies, gated BEFORE the shell-forward so bites never wire) — state rides a tiny reliable `_rpc_down_state` broadcast (0 up/1 downed/2 ghost) beside the vitals; shells mirror prone/dim + a depleting bleed-out ring and `nearest_player` skips downed/ghost prey WITHOUT reading them dead (best_any fallback intact — solo picks bit-identical, and agent-R's `_floor_target` `get("downed")` read wired up for free); REVIVE = hold INTERACT within 60 px, 3.0 s channel on the REVIVER's clock, host-arbitrated claim (first wins, later hopefuls silently no-op), interrupted by ANY landed hit (take_damage) or release/move/range, completion = host-validated -> owner-confirmed stand-up at 30% max (`net_stand_up`), channel bar over BOTH heads + local DOWNED/GHOST banner in hud.gd (lazily built, solo allocates nothing; MP-14 absorbs into party frames); BLEED-OUT EXPIRY = GHOST (spectral, collision_layer 0/mask walls-only, walk speed, no interact) until the host's 0.5 s sweep sees NO active room hot (_room_hot — the door-seal truth) then owner-confirms a 30% stand-up where they stand; WIPE = host census (downed/ghost/dead all count down, latch re-arms when anyone stands) -> `_rpc_wipe{death_room, respawn_room}` -> EVERY machine runs game_flow.net_wipe = the solo flow verbatim (_death_begin tithe/flash, 2.0 s, _death_respawn w/ NEW forced_room so guests obey the host's room decision — their cleared maps are mirrors), guests' mirror resets ride the MP-10 ST_DEAD-watcher resync, party-of-1-online collapses to the solo flow (asserted); FOLD-INS: (a) terrain events now host-only in-session (guests no longer roll their own weather; magma-lava fans via the MP-10 host_hazard pattern, telegraphs already broadcast — aiming events at guest positions stays MP-15 terrain-sweep territory, gusts/screen-flashes stay host-local feel), (b) boss-kill full-heal fans to every head via _rpc_full_heal (downed/ghost bodies skip it — the §5.3 paths own standing up; the host's own inline heal gets the same guard), (c) victory screen verified NO guest soft-lock (request_pause no-ops online; guests get the chapter-clear beat as a toast through the award machinery — real victory/results sync is MP-14's), plus agent-R's weekly finding folded: _send_snapshot now ships weekly_active/weekly_week and _rpc_world_snapshot applies them post-switch_chapter; net_test stage 6 (--net-stage=6, port 48221) proves (a) downed-not-dead visible on the shell + wolf retargets away, (b) 3 s channel -> 31% max + shell bar follows, (c) a landed hit breaks the channel (no revive), (d) all-down wipe: both tithed 10%, both at the host's respawn room, wounded ARENA boss (zone_idx>=0) leash-reset to full, (d2) lone-host-online down = immediate wipe = death flow, (e) solo-OFFLINE lethal = the exact old flow (dead instantly, no downed branch); test_quick + net_test ALL 6 stages + full test.bat green)
Files: game_flow.gd, player chain (downed state), hud (downed indicator), net_session (down/revive
RPCs). §5.3: 30s bleed-out crawl, 3s interruptible channel revive at 30% HP, ghost-until-clear on
expiry, all-down = existing wipe flow party-wide. Solo keeps its exact current flow.

### MP-13: Dialogue overlay + story sync — OWNER: agent-V — status: DONE (§5.4 in full. LIVE WORLD-FLAG SYNC: game_base.set_flag now routes every WORLD flag through the host — guest→host RPC→host applies+fans to all guests (setter included, idempotent under a `_net_flag_apply` loop guard); host-set flags fan directly. Quest state, opened ways, one-time reveals, pay-once desks and the MP-11-gap shrine/cache/curse/hidden once-per-room marks all stay consistent on every machine + ride the join snapshot (they're in game.flags, which _send_snapshot ships wholesale). CLASSIFICATION rule = game_flow._flag_is_local: the SAME KEPT_FLAG_PREFIXES/KEPT_FLAGS list that survives a chapter wipe because it's character history (opened_/chose_/completed_/s_awakened_<cls> + the moral KEPT_FLAGS) stays LOCAL to its owner — a guest's awakening/opening never rewrites the host's. DIALOGUE ETIQUETTE: run_convo_id routes online convos through net_session.begin_convo — a host-arbitrated per-NPC BUSY-LOCK (`_convo_claims`, the revive-claim idiom: first interactor wins, a second gets a local floating "Someone's already speaking with them" bark and NO dialogue; freed on convo-end or holder disconnect); solo-in-session (opening beats before guests spawn, or a lone party) collapses to a plain overlay. CONSEQUENCE ROUTING confirmed owner-side by construction — resonance/standings/keepsakes/temptation-gold all hit `player`=local_player, so a guest's choice moves ONLY the guest (the MP-11 "convo payouts pay the machine running the convo" note is the CORRECT §5.4 design — gap closed); the one shared consequence is the world flag (routed via the sync) + a one-line TOAST to the other players ("<name> accepted: <quest>" / "<name> chose: <label>", riding spawn_text). CHAPTER-CRITICAL BEATS (conservative: ONLY quest_key-advancing convos, _convo_is_beat) gate on all living party within the initiator's room or BEAT_GATHER_RADIUS (1200px) — "Wait for the party to gather" bark if blocked — and mirror their lines read-only to a compact top-center hud transcript (mirror_begin/line/end) while the initiator drives the choices; quest_key follows on the party for in-session HUD consistency (cosmetic; guests never persist world state, §5.7). EFFECT SWEEP of _convo_node: set_flag=world→routed (covers merchant-unlock/way-open/reveal/desk-paid/side-quest-accept, all flag-driven); resonance/faction/gain_item/lose_item/gold/quest = player-owned or beat-lifecycle, no routing. net_test STAGE 7 (--net-stage=7, port 48223) proves: guest→host + host→guest world-flag sync w/ a fresh late-joiner snapshot carrying both, per-character flag stays local, NPC busy-lock (no 2nd dialogue) + release + re-claim, beat mirrored to a spectator w/ quest sync on end, a guest payout choice pays ONLY the guest (host wallet/resonance untouched) while the flag routes + the host is toasted, and solo-offline convo end-to-end w/ no RPC. test_quick + net_test ALL 7 stages + full test.bat green)
Files: hud.gd (dialogue + mirror transcript), game_base.gd (set_flag routing, run_convo_id, toast
hook, _convo_is_beat), game_flow.gd (_flag_is_local), net_session (flag sync + busy-lock + beat
+ toast RPCs), net_test_session (stage 7). §5.4: convo runs as local overlay (world live), choices
move initiator's resonance, world flags RPC through host, toast to others; busy-lock per NPC;
chapter-critical beats gate on party-in-room and mirror text to all.

### MP-14: Party UI — status: DONE (§5.6 in full + synced victory/advance. PARTY FRAMES: up to 3 compact ally frames in a left column under the player's own panel (name from net_name, class icon via Classes.CLASSES sprite, HP bar+text from the vitals sync, and a state banner that REPLACES the name row — DOWNED with the bleed-out countdown / GHOST / DEAD, dimming the icon+HP); built lazily on the first online frame with >=2 players, freed on session end (hud.reset_party_ui from net_session._on_session_ended), solo allocates NOTHING — the whole party path early-outs on net_online()/party_frame_data() emptiness; the DATA MODEL is exposed as hud.party_frame_data() (one row per remote, read live off game.players) so tests drive vitals/downed and assert the model, not pixels. MP-12's downed banner + overhead revive channel bar are KEPT (local banner is the local player's own state; the channel bar stays over the reviver/downed pair) — the FRAME carries the ally-state read. OFFSCREEN ARROWS: a pooled Polygon2D triangle per offscreen living ally, clamped to the screen edge on the center->ally ray, class-tinted, with a red/blue PULSE (alpha+scale) when downed/ghost (finding your downed friend is the #1 use); dead allies skip. NAME LABELS: small class-tinted tags over ON-screen remotes (offscreen ones are the arrows' job), dimmable via hud.party_names_alpha knob (0 hides). DAMAGE NUMBERS: your own stay big (spawn_text); ALLIES' show small (game.spawn_ally_damage — font 11, dim cool tint, z under your own). The host is authority for every hit it applies — ONE guarded hook in enemy.take_damage's non-silent branch (game.net_host() gates it, solo untouched) calls net_session.host_fan_damage(net_id, amount, crit, striker); numbers COALESCE per enemy over one 20 Hz window (multi-hit bursts merge) and fan UNRELIABLE to every party member EXCEPT the striker (the attacker already showed its own optimistic big number; a guest hit re-resolved on the host fans to the OTHER guests). Measured rate: bounded to <= live-enemy-count packets per 50 ms, ~one 6-8 B number per struck enemy per window (net_test stage 8(b): a single host blow -> exactly one ally-number of the applied amount on the non-attacking guest; zero to the attacker). DoT ticks are already silent in solo (no number), so they're not fanned — guests see the hp bar move, consistent with solo (documented, not a regression). SYNCED VICTORY: the final-boss death fans host_victory(vtext, has_next) from end_it (BEFORE the pause, so the reliable RPC queues while the sim is live) — every guest runs game.net_victory: its OWN run_results + record_chapter_result (per-character PB), sets completed_<ch> (a KEPT/character flag, local, rides its save home), meta_unlock's its OWN next chapter, claims its OWN weekly reward via _finish_weekly when weekly_active (closes the MP-11 weekly-completion-host-only gap — per-player through the owner's own paths), autosaves the credit WHILE still ST_PLAYING (autosave gates on it), THEN shows show_end_screen + show_results and pauses. request_pause now PAUSES all machines during ST_VICTORY only (game_base: the one in-session exception — chapter's over, nothing to simulate; RPCs are event-driven so the advance/end handshake flows while paused; solo + non-victory online unchanged). MP-12's placeholder VICTORY toast is REMOVED (host_award_all toast dropped; loot flush + first-clear still fan via host_chapter_end). ADVANCE: the host's ENTER drives advance_chapter (guests gated out via net_guest()); it rebuilds the next chapter locally, re-homes the remote shells to the new start, and host_advance_party() briefs each guest -> net_advance rebuilds the SAME next chapter through switch_chapter (the join-flow path, reused — NOT a second path), keeping the LIVE progressed character (no save re-apply) and its own kept flags (_wipe_chapter_flags), guest_world preserved. EXIT-to-title (R on the final card): host_end_session -> guests net_session_over (write_character_home + graceful leave); _on_session_ended also belt-and-braces autosaves any guest whose session ends (victory-exit autosave; full drop/rejoin is MP-16). net_test stage 8 (--net-stage=8, port 48225) proves: (a) party_frame_data tracks an ally's vitals+downed/up via the accessor, (b) a host hit fans exactly one small ally-number of the applied amount to the non-attacker, (c) a forced final-boss death puts BOTH machines on the card with the guest's own chapter credit + meta unlock + weekly reward (+808g), (d) host advance carries the guest into ch2 rebuilt on the host's seed, (e) solo-OFFLINE final-boss death is the exact old flow. test_quick + net_test ALL 8 stages + full test.bat green)
Files: hud.gd (party frames + arrows + name labels + party_frame_data accessor + reset_party_ui),
net_session.gd (host_fan_damage/_rpc_ally_damage + host_victory/_rpc_victory + host_advance_party/
_rpc_advance_world + host_end_session/_rpc_session_over + last_ally_dmg), game_flow.gd (net_victory/
net_advance/net_session_over guest handlers + host_victory/host_advance_party hooks + advance_chapter
guest gate), game_base.gd (spawn_ally_damage + request_pause ST_VICTORY exception), enemy.gd (ONE
guarded host_fan_damage hook in take_damage's non-silent branch — out of the listed file set but the
one authoritative host-hit choke; flagged), hud.gd victory-R co-op end, net_test_session.gd + net_test.bat (stage 8).

### MP-15: Boss target rotation + world events in-session — OWNER: agent-R — status: DONE (boss half: `Boss._floor_target(alternate)` primitive — cycling pick over live un-downed NON-targets, never the same victim back-to-back while another stands, `alternate` keeps every other cast on the sticky target, downed read defensively via `get("downed")` ahead of MP-12, solo collapses to `_get_target()` bit-identically; per-boss sweep of all 21 bosses per the new "Party floor rotation" verdict table in BOSSES.md — r51 imposed-floor items ROT, dueling bolt pokes ALT, signatures/radials untouched; Calda's quench body-block + Halla's lullaby aura generalized to sweep ALL players (solo = the old single read); codex Playing Together page expanded with the boss fight contract + §5.3 downed/revive blueprint rules; net_test stage 4(g) asserts the rotation picks the non-target shell and the alternate coin splits; WEEKLY FINDING — the MP-07 join snapshot does NOT carry weekly_active/weekly_week, so a guest in a weekly run misses weekly_fx gold + journal weekly state: fix is 2 small edits in net_session.gd — add both fields to `_send_snapshot`'s dict and apply them in `_rpc_world_snapshot` AFTER switch_chapter (the flag is cleared by switch_chapter's CALLERS, not switch_chapter itself) — reported NOT implemented (net_session.gd = agent-D's file this wave); terrain-event lava in-session remains the MP-10 known gap at game_flow:679, also outside these files)
Files: boss.gd, content bosses (untouched — no target reads there), ui/codex.gd, BOSSES.md,
net_test_session.gd (stage-4 append). §5.2 floor rule: signature targets aggro holder, floor
damage rotates non-targets — per-boss sweep against BOSSES.md.

**PHASE 3 COMPLETE** — downed/revive/wipe (MP-12) + dialogue/story sync (MP-13) + party UI &
synced victory/advance (MP-14) + boss target rotation (MP-15). The co-op loop is now playable end
to end: join → fight (mirrors + combat + instanced loot) → talk (synced story) → fall & revive →
clear the chapter together → advance as a party. Remaining: Phase 4 hardening (disconnect/rejoin,
soak/flake hunt, packaging).

## Wave 7 — Phase 4: hardening — status: PLANNED
MP-16 disconnects/rejoin (graceful everywhere, guest autosave on drop, host-loss session end);
MP-17 soak + flake hunt (0xC0000005 shutdown flake, ObjectDB leak warning, long-session drift, MP-10 stage-4 XP room-gating intermittent, net_test.bat PS exit-code masking — grep NET TEST FAIL not exit code, INTERMITTENT full-suite "entering a room should wake nobody (per-pack aggro)" seen once at the phase-3 gate then green on rerun — likely timing-marginal vs the sticky-retarget changes, bench warrior/earth 1987 single-run low read needs a 6-run mean);
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
- MP-15 floor rotation (§5.2, taste calls — review at real 2-4p): in a party, boss FLOOR pressure
  now hunts the NON-target — ground rakes (Fangmaw), rains/strays (Cinderhide ember + tantrum,
  Ashpriest enrage rain, Serane icicle, Korrag broken-storm, Veyx static field, Cyrraeth P3),
  aimed lanes (Null's beam spoke), marks (Choir Mother's hymn), Sexton's tell cluster + grave-spawn
  anchor, Varo's falling blades (per blade), Calda's slag lob, Kaethra's thrown spear, Auroch's
  submerge eruptions, Halla's hymnal + dreamer patches — while dueling bolt POKES alternate 50/50
  (Morwen / Choir verse / Vess grief / Ordo brand / Halla lull / Rotmaw spore / Kaethra bloom fan /
  Echo daggers / Cyrraeth bolts+arcs / Calda hammer lines / Serane shatter lance). Tanks will feel
  bosses "look away" more; backliners eat real pressure now. In a 2p party the one non-target IS
  every rotation pick (at 1.1x cadence) — all floor casts are fused tells, but if it reads as
  machine-gunning, the knobs are _floor_target's cycle and PARTY_BOSS_RATE.
- MP-15 party-wide reads: Calda's quench is denied by ANY hero standing the pool (not just the
  aggro holder), and Halla's lullaby aura stacks Drowse PER PLAYER (nobody bench-camps her hymn;
  she mends off the drowsiest head). Safe-zone exams (Vess / Varo / Serane / Ordo / Cyrraeth)
  still ANCHOR their shelters to the aggro holder — a spread party can find shadows/vents
  geometrically hard to reach inside the fuse; if that reads unfair at 2-4p, anchor the ring to
  the party centroid (solo-identical) rather than rotating a SIGNATURE.
- MP-12 §5.3 taste defaults (knobs are consts at the top of player_core.gd's MP-12 block —
  promote to balance.gd in a follow-up pass, the file was owner-locked this wave): crawl 0.35x
  move speed (DOWN_CRAWL_MULT), bleed-out 30 s (DOWN_BLEEDOUT), revive reach 60 px (REVIVE_REACH),
  channel 3.0 s (REVIVE_CHANNEL), stand-up at 30% max HP (REVIVE_HP_FRAC — ghost room-clear
  revives use the same floor).
- MP-12 down/ghost looks (taste, player_combat._refresh_down_visual + the DownRing inner class):
  downed = sprite tipped prone 90° toward its facing, drained dusk-red tint, a red ring arc over
  the body that empties with the bleed-out (the HUD banner carries the exact seconds); ghost =
  upright, spectral blue at 40% alpha, collision dropped (walks through enemies, walls still
  hold). Revive channel = small green bar over BOTH heads (hud.gd pool, minimal until MP-14's
  party frames). A dodged/0-damage hit still counts as "a hit" for channel interruption (hurt_cd
  arming is the trigger) — strict §5.3 reading; loosen at the _revive_interrupt call in
  take_damage if it feels unfair under chip spam.
- MP-12 interrupt-then-rehold: after a hit breaks a channel, a held key re-requests within ~0.4 s
  (request throttle) — deliberate, so a reviver under fire doesn't need to re-tap; the enemy's job
  is to keep hitting. Multiple revivers: first claim wins, others get a silent no-op (no busy
  toast yet — MP-14 can add one if playtests want it).
- MP-12 terrain events in-session: guests no longer roll their OWN weather (host-only sim now,
  lava pools fan as hazard events, telegraphs already mirrored) — but events still aim around the
  HOST's position/room only; a guest alone in an event room sees no weather until MP-15's terrain
  sweep aims events per-room/per-player. Gusts + lightning screen-flash remain host-local feel.
- MP-12 victory in co-op (until MP-14): the final-boss victory card/results/pause show on the
  HOST only; guests get their chapter-end loot flush + first-clear mail + a gold "VICTORY" toast
  and keep playing in the live world (nothing soft-locks — request_pause no-ops online). The
  host's world keeps simulating behind its victory screen (menuing-while-vulnerable rule).
- MP-13 §5.4 taste defaults (review at real 2-4p):
  * BUSY BARK — a 2nd player interacting with a claimed NPC gets a 1.5 s floating "Someone's
    already speaking with them" (warm-grey), no dialogue opens. Wording/duration are the knobs
    (net_session._busy_bark). A guest learns "busy" on the host's deny (~1 RTT); the host reads
    its own claim map instantly — asymmetric but invisible at LAN latency.
  * TOASTS — a private-overlay choice that touches SHARED state floats a 2.5 s pale-blue line to
    the OTHER players ("<name> accepted: <quest>" / "<name> chose: <label>", label truncated to
    ~40 chars). The initiator isn't toasted (they made the choice). Beats aren't toasted (the
    party already reads the mirror). Rides spawn_text at each recipient's own player.
  * BEAT GATING — a chapter beat (quest_key-advancing convo) starts only once every LIVING party
    member is in the initiator's room OR within BEAT_GATHER_RADIUS = 1200px (~half a room) of it;
    otherwise "Wait for the party to gather" (gold, 1.5 s) and it doesn't open. Downed/ghost count
    as present (they're in the fight). If gathering feels fussy at 2-4p, widen the radius or gate
    on same-room only (net_session._party_gathered / BEAT_GATHER_RADIUS).
  * BEAT MIRROR — spectators see the driven beat as a compact read-only transcript top-center
    (cooler-toned frame than your own gold box: "▸ <name> is speaking with someone…" + the live
    speaker/text + options shown "deciding: …"), the initiator drives the choices. quest_key
    follows on the whole party for tracker consistency (cosmetic; guests never persist it, §5.7).
  * FLAG CLASSIFICATION — world flags sync; per-character flags (KEPT_FLAG_PREFIXES/KEPT_FLAGS:
    opened_/chose_/completed_/s_awakened_<cls> + the moral choice flags) stay local. A shared
    side-quest whose steps are world flags completes per-machine — each party member on it gets
    their OWN reward once (sq_paid_ is set directly, never routed), matching §5.5 per-head
    instancing; the completion toast/sfx fires on each machine that's on the quest. Watch this at
    2-4p — if a host getting a phantom side-quest reward for a guest-accepted quest reads wrong,
    the fix is to gate _check_side_quests' payout on local acceptance rather than synced sq_on_.
- MP-14 §5.6 taste defaults (review at real 2-4p — knobs are consts/vars at the top of hud.gd's
  party-UI block):
  * FRAME PLACEMENT/SIZE — a left column UNDER the player's own stat panel (x=12, first frame
    y=228, 214x42 each, 6px gap), stacked top-down. Reads as "my bars, then my party's". Chosen
    over top-right (minimap) and bottom (ability bar / controls hint). If it crowds the left rail
    at 4p, move to top-right under the minimap or shrink to 34 px tall (PARTY_FRAME_W/H).
  * CLASS ICON + TINT — the class portrait (Classes.CLASSES sprite) in a 30px slot + a per-class
    accent rail (CLASS_TINT: warrior red / archer green / mage blue / assassin+warlock violet /
    paladin gold). No class color lives in Classes, so CLASS_TINT is the party UI's own; unify it
    into Classes if other UI wants it.
  * STATE BANNER — downed/ghost/dead REPLACE the name row (not overlay), the HP bar stays as the
    vitals read; downed shows "DOWNED 12s — reviving" (bleed-out + reviver hint). It dims the icon.
  * ARROW STYLE — a thin flat Polygon2D triangle at the screen edge (42px margin), class-tinted,
    pointing along center->ally; downed/ghost allies PULSE (red/blue, alpha+scale breathing) to
    scream "come find me". Dead allies get no arrow. If the pulse is too loud, drop the scale term.
  * NAME-LABEL VISIBILITY — small class-tinted tags over ON-screen remotes only, dimmable via
    hud.party_names_alpha (default 0.85; 0 hides them entirely). No settings toggle is wired yet —
    a "show ally names" checkbox would just drive this var. Offscreen allies get the arrow instead.
  * SMALL-NUMBER SCALE — allies' damage numbers are font 11 + a dim cool tint (own are font 15
    white/orange), rise faster/shorter, and sit one z-index under yours so your own always win the
    stack. If a friend's farm still drowns your numbers at 4p, drop spawn_ally_damage's font/alpha
    or gate the fan to same-room allies.
  * DAMAGE-FAN RATE — coalesced per enemy over one 20 Hz window and sent UNRELIABLE (a dropped
    number is a non-event; the hp bar carries truth). Bounded to <= live-enemy-count small packets
    per 50 ms. The host shows a NORMAL-size number for a GUEST's hit it applies (take_damage can't
    be silenced without losing reflect/counter) — a minor asymmetry: on the host, an ally's hit
    reads full-size; on guests it reads small. Acceptable; the fix would need an enemy.gd size knob.
  * VICTORY-SCREEN SYNC FEEL — the card lands on EVERY machine at the same beat (when the host
    confirms its epilogue), and ALL machines PAUSE (chapter's over). Each player sees THEIR OWN run
    stats + PB callouts (honest per-character grade), not the host's — the "shared" part is the
    simultaneity, not the numbers. Guests keep playing during the host's private epilogue read (no
    soft-lock), then the card appears together. First-clear beat still fires off the HOST's first
    clear (a veteran guest in a fresh host world re-earns it — blueprint's call, unchanged). If the
    "everyone freezes" reads wrong for a guest mid-trash-fight in another room when the host kills
    the final boss, the knob is the ST_VICTORY pause exception in game_base.request_pause.
- (grows as waves land)

## Integration gate (orchestrator) — PASSED 2026-07-10
- [x] Full `test.bat` green on the combined tree (AUTOTEST PASS, exit 0, zero SCRIPT ERRORs)
- [x] DPS bench sanity: 18/18 specs within variance of freshest references (archer hunt/storm
      match the post-mana-round recorded values to <0.4%; TIERLIST rows for those were already
      flagged stale pre-phase-0 — see BALANCE_HISTORY top entry)
- [x] Phase-0 paths staged (path-scoped; index also carries prior sessions' sprite/UI staging —
      any future commit must path-scope or describe the union)
