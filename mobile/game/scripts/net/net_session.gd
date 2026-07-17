extends Node
## NET SESSION — the gameplay bridge (MP-07, wave 4). A child of the
## NetworkManager autoload named "Session", so every peer shares the
## stable node path /root/NetworkManager/Session — the one requirement
## for the @rpc calls below to resolve identically everywhere.
##
## Owns three things, in the order a session needs them:
##   1. JOIN FLOW (MULTIPLAYER.md §4.1 row 1): on admission the host
##      sends {chapter, wander_seed, flags, spawn_room} — the world is a
##      pure function of the seed, so the guest REBUILDS it locally via
##      the same switch_chapter path a save-load uses. No node state
##      ships. The guest confirms readiness with its character block;
##      only then does spawning proceed (both directions).
##   2. SPAWN FAN-OUT: every instance spawns a presentation Player for
##      every other peer ({cls, level} dev block — MP-08 hands over the
##      full character). peer_left frees it everywhere.
##   3. MOVEMENT SYNC (§3.1): each peer broadcasts its OWN player's
##      {pos, velocity, look} at MOVE_HZ over an unreliable RPC; remotes
##      buffer snapshots and render ~NET_LERP_MS in the past
##      (player.gd _remote_present).
##   4. ENEMY MIRROR (MP-09, §4.1 enemies row): the host streams its
##      combat outward — reliable spawn/death/despawn/elite/play_action
##      events plus one ~20 Hz unreliable state packet (net_id, pos,
##      facing/walk, hp fraction; 14 bytes an enemy). Guests build REAL
##      Enemy/Boss nodes gated as presentation mirrors (enemy.gd
##      net_mirror), and telegraphs/telegraph_safe mirror as visual-only
##      events so a guest sees every tell the host's sim aims — co-op
##      dodging.
##   5. COMBAT OVER THE WIRE (MP-10, §4.1): the damage rows. Guest→enemy:
##      the guest runs its FULL kit against mirrors (trusted client) and
##      every landing hit/rider funnels here as an RPC the host applies
##      through the real take_damage/apply_* paths, with the guest's
##      host-side shell as source (aggro + reflect attribution). Enemy→
##      guest: any host-side hit on a remote shell forwards to the OWNING
##      peer, whose real take_damage runs mitigation/dodge/death ("host
##      decides, owner applies"). Plus: owner vitals broadcast (~2 Hz, on
##      change/damage), projectile spawn events (visual copies + local
##      flight), dynamic hazard events, and full kill XP to the party.
##   6. LOOT INSTANCING (MP-11, §5.5): every reward faucet pays PER HEAD.
##      The host triggers (its kill flows stay authoritative) and events
##      each guest a PERSONAL share — kill gold as a base amount (the
##      owner applies its own Hunger/weekly/greed), boss/elite/curse
##      packages host-rolled per player from loot_rng, bounty/vault
##      credit, chapter-end mail flush + first-clear. Owners apply
##      through their normal award paths (game_flow.apply_award_events /
##      mob_kill_share), so bags, mail and multipliers are theirs.
##      Chests are personal instances: every machine spawns its own copy
##      and _gate_chest filters its open trigger to the LOCAL player —
##      from OUTSIDE chest.gd (the owner's file stays untouched).
##   7. DOWNED/REVIVE/WIPE (MP-12, §5.3): owner-authoritative down states
##      (the owner's take_damage converts death into DOWNED and broadcasts
##      it here; shells mirror it and host AI drops downed prey), host-
##      arbitrated revive channels (first wins), the host's ghost/wipe
##      sweep (ghosts stand when no active room is hot; nobody standing
##      broadcasts the party-wide wipe that replays the solo death flow).
##
## game.gd hands this node its Game instance at boot. Everything here
## no-ops offline — solo never enters this file.
##
## GATE TRAP (MP-05): never reference the `NetworkManager` global by
## name — the autoload doesn't exist under check_compile's --script
## mode. The parent node IS the autoload; use get_parent().

## The lobby roster changed (someone announced, joined or left) — the
## lobby UI redraws its party list off lobby_roster() (MP-08).
signal lobby_changed
## GUEST-side: the host's snapshot landed, the world is rebuilt and play
## has begun — any pre-session UI (the lobby wait screen) should close.
signal session_started

const MOVE_HZ := 20.0    # owner movement broadcast rate (§3.1)
## MP-16: after briefing a guest, the host gives it this long to finish its
## world build and announce readiness (_rpc_join_ready). A peer that never
## gets there — killed mid-build, or wedged but still ENet-connected — is a
## ghost; the host drops it (the auth timeout, MP-05, only covers the PRE-
## admission window, so this closes the post-auth pre-ready gap). Generous:
## a real world build is seconds, and the transport timeout is the backstop.
const READY_TIMEOUT := 20.0
## MP-10: owner vitals cadence (s). Change-gated at this rate; an hp DROP
## (damage) sends immediately so shell bars and host-side AI reads never
## trail a fight by more than a beat.
const VITALS_EVERY := 0.5

## The Game instance (set by game.gd _ready). The setter hooks the game's
## direct children so every Chest — ANY spawn site, chest.gd untouched —
## gets its open trigger re-filtered to the local player while online
## (MP-11 personal chests). Scene reloads re-assign; the old hook dies
## with the old Game node.
var game: Node = null:
	set(value):
		game = value
		if value != null and not value.child_entered_tree.is_connected(_on_game_child):
			value.child_entered_tree.connect(_on_game_child)
## The LOCAL identity this machine announces (MP-08). The lobby UI sets
## {slot, cls, level, name}: slot is the joiner's OWN roster save — its
## character section loads when the host's snapshot arrives (§5.7). The
## dev CLI (--mp-join) still sets the minimal {cls, level} block; empty
## falls back to the live player.
var local_char := {}
## peer id -> character block, for every REMOTE player this instance
## has spawned. The host also uses it to brief newcomers.
var peer_chars := {}
## LOBBY-phase roster: peer id -> {name, cls, level}, announced on
## admission (before any world exists). Host-authoritative; mirrored to
## every guest so both lobby screens draw the same party (MP-08 §5.1).
var lobby_chars := {}
## Guest: the host's snapshot has been applied and the world rebuilt.
var world_ready := false
## Guest: the last snapshot received (tests assert against it).
var last_snapshot := {}
## MP-09: net_id -> Enemy. On the HOST these are the live announced
## enemies (the fan-out registry); on a GUEST they are the mirrors.
var net_enemies := {}
var _net_id_counter := 0
## MP-10, HOST: net projectile id -> live HOSTILE Projectile. Only hostile
## shots get ids — a guest's Mirrorstep must be able to consume the REAL
## bolt, not just its local copy. Entries erase themselves on tree exit.
var net_projectiles := {}
var _net_proj_counter := 0
## MP-10, HOST: the most recent guest hit applied through _rpc_hit_enemy
## ({id, peer, amount, crit}) — tests assert against it (last_snapshot idiom).
var last_hit := {}
## MP-11, GUEST: the most recent personal award package received —
## tests log/assert against it (last_snapshot idiom).
var last_award: Array = []
## MP-14, RECIPIENT: the most recent ally-damage number received ({net_id,
## amount, crit}) — the small-number data assert (last_snapshot idiom).
var last_ally_dmg := {}
## MP-10: what this machine last broadcast for its OWN player's vitals.
var _vitals_sent := {}
var _vitals_accum := 0.0
var _status_throttle := {}  # "pid:kind" -> last send ms (per-frame chill refresh)
## MP-10, GUEST: the local death flow ran (game_flow resets rooms/frees
## homeless enemies AS IF this were its world) — on respawn we ask the
## host for a fresh enemy sweep so the lost mirrors rebuild.
var _guest_was_dead := false
## MP-12 (§5.3), HOST: downed pid -> the reviver pid holding its channel.
var _revive_claims := {}
## MP-12, HOST: one wipe broadcast per fall — re-arms once anyone stands.
var _wipe_fired := false
## MP-12, HOST: room of the most recent fall (the wipe's reset target).
var _last_down_room := -1
var _down_sweep_t := 0.0   # HOST: 0.5 s ghost-revive / wipe sweep cadence
## MP-13 (§5.4), HOST: convo/NPC id -> the peer holding its busy-lock. First
## interactor wins; a second interactor is denied a local "busy" bark (no
## dialogue). Freed when the convo ends or the holder disconnects.
var _convo_claims := {}
## Wave-1 co-op fix, HOST: convo id -> initiator pid, for claims that are an
## ACTIVE BEAT (a mirrored transcript is open on the spectators). Tracked so a
## mid-beat DISCONNECT of the initiator can close the stuck overlay everywhere
## (the normal end path never runs — the driver is gone). Cleared with the claim.
var _beat_claims := {}
## MP-13, GUEST: the convo this machine asked the host to claim, awaiting a
## grant/deny — {id, convo, on_done, is_beat}. One at a time (the interact
## talk_cd debounces the request that opens it).
var _pending_convo := {}
## MP-13: the convo id this machine is currently RUNNING — the claim to free
## when its overlay closes. "" = none.
var _active_convo_id := ""
## MP-13 (§5.4): a chapter-critical beat starts only once every living party
## member stands in the initiator's room OR within this radius of it — a
## generous half-room gather so nobody misses the story (taste default,
## logged in PLAYTEST NOTES; the knob is here).
const BEAT_GATHER_RADIUS := 1200.0

## MP-14 (§5.6): damage-number etiquette. The host is authority — every hit
## it applies (its own AND a guest's, both land through enemy.take_damage)
## fans a COMPACT number to the party members who did NOT strike, who render
## it SMALL (own numbers stay big, per screen). Coalesced per enemy over one
## 20 Hz window (multi-hit bursts merge into one number) and sent unreliable —
## a dropped number just doesn't show; the hp bar carries the truth.
## net_id -> {"amt": accumulated, "crit": any-crit, "attacker": last striker peer}.
var _dmg_fan := {}

var _move_accum := 0.0


func _net() -> Node:
	return get_parent()  # the NetworkManager autoload (see header)


func _ready() -> void:
	var net := _net()
	net.peer_joined.connect(_on_peer_joined)
	net.peer_left.connect(_on_peer_left)
	net.session_ended.connect(_on_session_ended)


# ------------------------------------------------------------ join flow ---

func _on_peer_joined(id: int, _char_info: Dictionary) -> void:
	if multiplayer.is_server():
		_gate_existing_chests()  # MP-11: pre-session chests answer only their owner now
		lobby_changed.emit()  # the party list shows the knock immediately
		_send_snapshot(id)  # a guest was admitted: brief it (async)
	elif id == 1:
		if game != null and game.local_player != null:
			# WE were admitted: our own player is ours under our session id
			# from this moment (before the snapshot lands and re-stamps it).
			game.local_player.peer_id = multiplayer.get_unique_id()
		# Announce who's knocking (MP-08): name/class/level for the host's
		# lobby list, long before any world snapshot flows.
		_rpc_lobby_hello.rpc_id(1, _lobby_block())


# ------------------------------------------------- lobby roster (MP-08) ---

## GUEST -> HOST: a freshly admitted joiner announces its lobby identity.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_lobby_hello(block: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	lobby_chars[pid] = {"name": String(block.get("name", "Hero")),
		"cls": String(block.get("cls", "warrior")),
		"level": maxi(1, int(block.get("level", 1)))}
	_rpc_lobby_roster.rpc(lobby_roster())  # everyone sees the party assemble
	lobby_changed.emit()


## HOST -> GUESTS: the full lobby roster (host entry included).
@rpc("authority", "call_remote", "reliable")
func _rpc_lobby_roster(roster: Dictionary) -> void:
	if multiplayer.is_server():
		return
	lobby_chars = roster
	lobby_changed.emit()


## The party as the lobby shows it: peer id -> {name, cls, level}. On the
## host this is authoritative (its own entry + every hello); on guests it
## is the mirrored broadcast.
func lobby_roster() -> Dictionary:
	if not multiplayer.is_server():
		return lobby_chars  # already de-duped: the host broadcasts this shape
	var out := {1: _lobby_block()}
	for pid in lobby_chars:
		out[int(pid)] = lobby_chars[pid]
	return dedup_roster(out)


## Session-local name de-dup (DISPLAY only): when party members share a name,
## the host — authoritative for the roster — suffixes the later ones "#2",
## "#3"… so the lobby/party list stays legible. Stored names (lobby_chars)
## are never touched; a global, server-assigned #tag waits on the account
## backend. Stable by ascending peer id, so the host (id 1) and earlier
## joiners keep the bare name and only the collisions grow a suffix.
static func dedup_roster(roster: Dictionary) -> Dictionary:
	var seen := {}   # lower-cased name -> how many already assigned
	var out := {}
	var ids := roster.keys()
	ids.sort()
	for pid in ids:
		var src: Dictionary = roster[pid]
		var block := src.duplicate()
		var base := String(block.get("name", "Hero"))
		var key := base.to_lower()
		var n := int(seen.get(key, 0))
		seen[key] = n + 1
		if n > 0:
			block["name"] = "%s #%d" % [base, n + 1]
		out[int(pid)] = block
	return out


## This machine's lobby identity: what the lobby UI picked, else the live
## player (dev CLI hosts), else a level-1 warrior.
func _lobby_block() -> Dictionary:
	var nm := String(local_char.get("name", os_name()))
	if local_char.has("cls"):
		return {"name": nm, "cls": String(local_char.get("cls", "warrior")),
			"level": maxi(1, int(local_char.get("level", 1)))}
	if game != null and game.local_player != null:
		return {"name": nm, "cls": String(game.local_player.cls),
			"level": int(game.local_player.level)}
	return {"name": nm, "cls": "warrior", "level": 1}


## Best available player-recognizable name until characters are named:
## the OS account name (what friends will recognize), else "Hero".
func os_name() -> String:
	for env in ["USERNAME", "USER"]:
		var n := OS.get_environment(env)
		if n != "":
			return n.substr(0, 16)
	return "Hero"


## HOST: ship the world snapshot to a freshly admitted guest. The host
## may still be in the title flow (--mp-host lets guests join the lobby
## before the roster pick) — wait for play_started; every lap re-checks
## that the session and the guest still exist, so this never outlives
## either.
func _send_snapshot(id: int) -> void:
	while game == null or not bool(game.play_started):
		await get_tree().create_timer(0.2).timeout
		if not _net().is_online() or not (id in _net().peers):
			return
	_rpc_world_snapshot.rpc_id(id, {
		"chapter": game.chapter_id,
		"wander_seed": game.wander_seed,
		"flags": game.flags,
		"spawn_room": game.cur_room,
		# Wave-1 co-op fix: boss_done gates the chapter-blocking "boss" edge
		# locks — ship it so a late joiner's already-cleared arenas build/leave
		# their gates OPEN (applied before the post-rebuild _recheck_gates below).
		"boss_done": game.boss_done,
		# Wave-1 co-op fix: dynamic (post-clear/post-boss) merchants are host-
		# rolled and NOT seed-pure, so a late joiner would miss them — ship the
		# roster (built rooms re-spawn the node, unbuilt ones spawn on entry).
		"merchant_zones": game.merchant_zones,
		# MP-15 finding (agent-R): a weekly-challenge host must brief the
		# guest, or weekly_fx gold and the journal's weekly state go dark
		# on its machine (applied after switch_chapter below — the flag is
		# cleared by switch_chapter's CALLERS, never by switch_chapter).
		"weekly_active": game.weekly_active,
		"weekly_week": game.weekly_week,
	})
	_watch_ready(id)  # MP-16: bounded ghost-peer drop if it never gets ready


## HOST: after briefing a guest, give it a bounded window to finish its
## world build and announce readiness (_rpc_join_ready populates peer_chars).
## A peer that never gets there is a ghost holding a seat — drop it, so the
## session and the seat stay clean. The transport's own timeout is the
## backstop; this also catches the wedged-but-connected case (MP-16).
func _watch_ready(id: int) -> void:
	var deadline := Time.get_ticks_msec() + int(READY_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.25).timeout
		if not _net().is_online() or not multiplayer.is_server():
			return
		if not (id in _net().peers):
			return  # already gone (clean leave, or a transport drop)
		if peer_chars.has(id):
			return  # became ready — the normal path
	if (id in _net().peers) and not peer_chars.has(id):
		_net().drop_peer(id)


## GUEST: the host's world arrives. Seed purity (§2.1) makes this SMALL:
## set the seed, rebuild through the same path a save-load uses, apply
## the flags, stand in the host's room. Then confirm readiness.
@rpc("authority", "call_remote", "reliable")
func _rpc_world_snapshot(snap: Dictionary) -> void:
	if game == null or multiplayer.is_server():
		return
	last_snapshot = snap
	var g: Node = game
	var p: Node = g.local_player
	p.peer_id = multiplayer.get_unique_id()
	# The world: seed first, then the same rebuild a load performs.
	g.wander_seed = int(snap.get("wander_seed", 0))
	var fl: Dictionary = snap.get("flags", {})
	g.flags = fl.duplicate()
	g.switch_chapter(String(snap.get("chapter", "ch1")), true)
	# Wave-1 co-op fix: switch_chapter CLEARS boss_done + merchant_zones, so
	# restore the host's from the snapshot right after the rebuild — BEFORE the
	# _recheck_gates and spawn-room _enter_room below read them. An already-
	# cleared boss arena then leaves its gate open (the gate-construction guard
	# reads boss_done), and dynamic merchants respawn for the joiner.
	var bd: Dictionary = snap.get("boss_done", {})
	g.boss_done = bd.duplicate()
	var mz: Array = snap.get("merchant_zones", [])
	g.merchant_zones = mz.duplicate()
	# A weekly-run host briefs the guest (MP-15 finding): weekly_fx and the
	# journal read these — set AFTER switch_chapter, which never clears them.
	g.weekly_active = bool(snap.get("weekly_active", false))
	g.weekly_week = int(snap.get("weekly_week", g.weekly_week))
	g.guest_world = true  # from here on autosaves are character-only (§5.7)
	g._host_lost_handled = false  # MP-16: a fresh session can lose its host anew
	# The character (MP-08, §5.7): the lobby put the joiner's OWN roster
	# slot in local_char — load that save's CHARACTER section (identity,
	# gear, wallet, records) onto our player, after the rebuild exactly
	# like a solo load (so e.g. saved potions_free overwrites the teaching
	# grant). Its world half stays home: nothing of the guest's world ever
	# touches the host's, and ground-drop positions from another geometry
	# are never spawned here — they ride to the mailbox instead. The dev
	# CLI (--mp-join) still rides the minimal {cls, level} block below.
	var slot: int = int(local_char.get("slot", 0))
	var applied := false
	if slot > 0:
		var data: Dictionary = SaveGame.read(slot)
		if not data.is_empty():
			g.save_slot = slot  # autosaves write the character home (§5.7)
			SaveGame.apply_character(g, SaveGame.character_of(data), false)
			applied = true
	if not applied:
		var cls := String(local_char.get("cls", p.cls))
		if p.cls != cls:
			p.set_class(cls)
		p.level = maxi(1, int(local_char.get("level", p.level)))
		p.recalc()
		p.hp = p.max_hp
		p.mp = p.max_mp
	g._recheck_gates()  # flag-locked gates react to the host's story state
	var spawn: int = clampi(int(snap.get("spawn_room", 0)), 0, int(g.zone_count) - 1)
	p.global_position = g.room_center(spawn)
	g._enter_room(spawn)
	_gate_existing_chests()  # MP-11: the rebuilt world's chests are OURS alone
	g.play_started = true
	g.request_pause(false)
	g.hud.visible = true
	world_ready = true
	# Readiness confirmed — only now does spawning proceed (§4.1).
	_rpc_join_ready.rpc_id(1, _char_block())
	session_started.emit()  # the lobby wait screen closes itself on this


## HOST: a guest finished its world build and announced its character.
## Spawn it here, brief IT about everyone already present, and brief
## everyone already present about IT.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_ready(block: Dictionary) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	# The newcomer learns the roster so far: the host's player...
	_rpc_spawn_player.rpc_id(pid, 1, _char_block())
	# ...and every guest that is already standing in the world.
	for q in peer_chars:
		if int(q) != pid:
			_rpc_spawn_player.rpc_id(pid, int(q), peer_chars[q])
			_rpc_spawn_player.rpc_id(int(q), pid, block)
	peer_chars[pid] = block
	_spawn_remote(pid, block)
	# MP-09: brief the newcomer about every LIVE enemy standing in the
	# world (the ongoing spawn events cover everything after this line;
	# the dupe guard in _rpc_spawn_enemy absorbs the overlap window).
	host_sweep_unregistered()
	for id in net_enemies:
		var e: Enemy = net_enemies[id]
		if e != null and is_instance_valid(e) and not e.dying:
			_rpc_spawn_enemy.rpc_id(pid, _spawn_block(e))


## EVERYONE: peer pid's player exists — spawn its presentation body.
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_player(pid: int, block: Dictionary) -> void:
	if game == null:
		return
	peer_chars[pid] = block
	_spawn_remote(pid, block)


## Build the remote Player from the owner's character block (MP-08):
## class + level drive the sprite/kit, then the owner's REAL vitals
## overwrite the class-default recalc so its bars read true. Full
## combat-stat fidelity (gear, talents) is phase 2 — these are the
## visible parts. Owner gets peer_id + multiplayer authority;
## game.register_remote_player parents it and takes the roster slot.
func _spawn_remote(pid: int, block: Dictionary) -> void:
	if game == null or pid == multiplayer.get_unique_id():
		return
	var p := Player.new()
	p.game = game
	p.peer_id = pid
	p.name = "NetPlayer%d" % pid
	p.set_multiplayer_authority(pid)
	# Stand near the local room's heart until the first movement
	# snapshot (~1 tick) snaps it onto the owner's real position.
	p.global_position = game.room_center(game.cur_room) + Vector2(40.0 * (pid % 5), 30.0)
	game.register_remote_player(p)
	p.set_class(String(block.get("cls", "warrior")))
	p.level = maxi(1, int(block.get("level", 1)))
	p.recalc()
	p.max_hp = maxf(1.0, float(block.get("max_hp", p.max_hp)))
	p.max_mp = maxf(0.0, float(block.get("max_mp", p.max_mp)))
	p.hp = clampf(float(block.get("hp", p.max_hp)), 1.0, p.max_hp)
	p.mp = clampf(float(block.get("mp", p.max_mp)), 0.0, p.max_mp)
	# Wave-2 co-op fix #7: overwrite the class-default crit with the owner's real
	# values so a DoT this guest applies (host re-sources it to this shell) ticks
	# its crit off the RIGHT sheet. Offensive-only — the shell never resolves its
	# own attacks or defense host-side (incoming hits forward to the owner), so
	# nothing else reads these. Absent (dev {cls,level} block) keeps the default.
	p.crit = maxf(0.0, float(block.get("crit", p.crit)))
	p.crit_dmg = maxf(1.0, float(block.get("crit_dmg", p.crit_dmg)))
	# The owner's display name rides as metadata until name labels land
	# (§5.6, phase 3) — nothing renders it yet, everything can reach it.
	p.set_meta("net_name", String(block.get("name", "")))


## The character block this machine announces to the session (MP-08):
## the LIVE player — by _rpc_join_ready time a joiner has already applied
## its roster character, and a host is mid-play — so class, level and the
## real vitals travel. Falls back to the dev {cls, level} block pre-boot.
func _char_block() -> Dictionary:
	var nm := String(local_char.get("name", os_name()))
	if game != null and game.local_player != null \
			and is_instance_valid(game.local_player):
		var p: Node = game.local_player
		# Wave-2 co-op fix #7: crit/crit_dmg ride so the host-side SHELL DoT
		# source ticks off the owner's REAL crit, not a class-default shell (a
		# crit-stacked burn/bleed build otherwise silently underperforms in co-op).
		return {"cls": String(p.cls), "level": int(p.level), "name": nm,
			"hp": float(p.hp), "max_hp": float(p.max_hp),
			"mp": float(p.mp), "max_mp": float(p.max_mp),
			"crit": float(p.crit), "crit_dmg": float(p.crit_dmg)}
	return {"cls": String(local_char.get("cls", "warrior")),
		"level": int(local_char.get("level", 1)), "name": nm}


# -------------------------------------------------------- peer lifecycle ---

func _on_peer_left(id: int) -> void:
	# MP-16: name the leaver for the party toast BEFORE the roster erases it.
	var gone_name := ""
	if peer_chars.has(id):
		gone_name = String(peer_chars[id].get("name", ""))
	elif lobby_chars.has(id):
		gone_name = String(lobby_chars[id].get("name", ""))
	peer_chars.erase(id)
	lobby_chars.erase(id)
	if multiplayer.is_server() and _net().is_online():
		_rpc_lobby_roster.rpc(lobby_roster())  # guests' lists shrink too
	lobby_changed.emit()
	if game != null:
		game.unregister_player(id)
	# MP-12: a leaver takes its down state and any channel it held with it;
	# the wipe re-checks (everyone left standing may now be down).
	if multiplayer.is_server() and game != null:
		_revive_claims.erase(id)
		for k in _revive_claims.keys():
			if int(_revive_claims[k]) == id:
				_revive_claims.erase(k)
				_broadcast_revive_end(int(k))
		# MP-13: a leaver frees any NPC busy-lock it held (others can talk).
		# Wave-1 co-op fix: if that claim was an ACTIVE BEAT the leaver drove,
		# its mirrored transcript is stuck open on every spectator — close it
		# everywhere (the normal end path can't run now, the driver is gone).
		for ck in _convo_claims.keys():
			if int(_convo_claims[ck]) == id:
				_convo_claims.erase(ck)
				if _beat_claims.has(ck):
					_beat_claims.erase(ck)
					_rpc_beat_end.rpc()
					if game.hud != null:
						game.hud.mirror_end()
		_check_wipe()
	# MP-16: mid-run, tell the party in plain words that a friend dropped (a
	# lobby-time leave already shows in the lobby list). Fires on EVERY
	# remaining machine — host and sibling guests alike.
	if game != null and bool(game.play_started) \
			and game.local_player != null and is_instance_valid(game.local_player):
		var who := gone_name if gone_name != "" else "A hero"
		game.spawn_text(game.local_player.global_position + Vector2(0, -92),
			"%s left the party" % who, Color(1.0, 0.8, 0.55), 2.5)


func _on_session_ended(reason: String) -> void:
	world_ready = false
	if game != null:
		# MP-16: restore a FALLEN guest to a safe, ALIVE state BEFORE the
		# autosave. A downed/ghost body sits at hp<=0 (§5.3), and writing that
		# home would land the hero at 1 HP on their next solo load (apply_character
		# clamps to >=1). §5.3's stand-up floor (30% max) is the taste default
		# for "the session died under me" — the same value a channel/room-clear
		# revive uses. Offline now (peer already swapped): net_stand_up broadcasts
		# nothing. This runs BEFORE the write below, so the home save reads alive.
		if game.local_player != null and is_instance_valid(game.local_player):
			game.local_player.peer_id = 1  # back to the solo default
			if game.local_player.downed or game.local_player.ghost:
				game.local_player.net_stand_up(game.local_player.REVIVE_HP_FRAC)
			game.local_player.net_clear_down_local()
		# MP-14 (§5.7): a guest whose session ends (host advanced-to-exit, host
		# loss, or its own leave) takes its character home — belt-and-braces
		# beside net_session_over's explicit write, so a lost end-RPC or a
		# vanished host never costs the guest its progress. Now that vitals are
		# safe (above), the home save captures an alive hero at the revive floor.
		if game.guest_world and game.save_slot > 0 \
				and game.local_player != null and is_instance_valid(game.local_player) \
				and not game.local_player.dead:
			SaveGame.write_character_home(game, game.save_slot)
		for id in peer_chars:
			game.unregister_player(int(id))
	peer_chars.clear()
	lobby_chars.clear()
	last_snapshot = {}
	# MP-09: mirrors are phantoms without their host — free them. The
	# host's own enemies just drop their session ids (they keep living
	# their solo lives; a future session re-announces them).
	for id in net_enemies:
		var e: Enemy = net_enemies[id]
		if e == null or not is_instance_valid(e):
			continue
		if e.net_mirror:
			e.queue_free()
		else:
			e.net_id = 0
	net_enemies.clear()
	_net_id_counter = 0
	# MP-10: visual projectile copies are phantoms too; host ids and the
	# vitals ledger reset with the session.
	for node in get_tree().get_nodes_in_group("projectiles"):
		var pr := node as Projectile
		if pr != null and pr.net_visual:
			pr.queue_free()
	net_projectiles.clear()
	_net_proj_counter = 0
	last_hit = {}
	last_award = []
	last_ally_dmg = {}
	_dmg_fan.clear()  # MP-14: no session, no ally-number fan
	_vitals_sent = {}
	_vitals_accum = 0.0
	_status_throttle.clear()
	_guest_was_dead = false
	_revive_claims.clear()
	_wipe_fired = false
	_last_down_room = -1
	# MP-13: no session, no dialogue etiquette — drop any claim/beat state
	# and close a mirror transcript left open under the party.
	_convo_claims.clear()
	_beat_claims.clear()  # Wave-1: no session, no live beats
	_pending_convo = {}
	_active_convo_id = ""
	if game != null:
		game.beat_broadcasting = false
		if game.hud != null:
			game.hud.mirror_end()
			game.hud.reset_party_ui()  # MP-14: party frames/arrows/labels freed
	_guest_boss_gone.call_deferred()  # a mirror's bar must not outlive it
	lobby_changed.emit()
	# MP-16: a GUEST that lost its host mid-run returns to the title with a
	# plain-words notice (its character is already saved above). No-ops on the
	# host, in the lobby, and on the graceful victory-exit — net_host_lost gates
	# on guest_world / play_started / ST_VICTORY. Runs LAST, after teardown.
	if game != null:
		game.net_host_lost(reason)


# --------------------------------------------------------- movement sync ---

func _physics_process(delta: float) -> void:
	if game == null or not _net().is_online() or not bool(game.play_started):
		return
	if multiplayer.get_peers().is_empty():
		return
	var p: Node = game.local_player
	if p == null or not is_instance_valid(p):
		return
	# MP-10: the death watcher and the vitals sender ride every physics
	# frame (both rate-limit themselves; the move gate below is 20 Hz).
	_watch_guest_death()
	_tick_vitals(delta, p)
	# MP-12: the host's ghost-revive / wipe sweep (rate-limits itself).
	if multiplayer.is_server():
		_down_sweep_t += delta
		if _down_sweep_t >= 0.5:
			_down_sweep_t = 0.0
			_host_down_sweep()
	_move_accum += delta
	var step := 1.0 / MOVE_HZ
	if _move_accum < step:
		return
	_move_accum = fmod(_move_accum, step)
	_rpc_move.rpc(p.global_position, p.velocity, float(p.look_sign))
	# MP-09: the host's enemy state rides the same ~20 Hz tick.
	# MP-14: the coalesced ally-damage numbers ride it too.
	if multiplayer.is_server():
		_stream_enemy_state()
		_flush_dmg_fan()


## The owner's 20 Hz movement snapshot: ~24 payload bytes over an
## unreliable channel (a lost tick is replaced 50 ms later — §3.1).
## Remotes stamp arrival time and interpolate (player_core.net_push_snapshot).
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_move(pos: Vector2, vel: Vector2, look: float) -> void:
	if game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0:
		return
	for q in game.players:
		if q != null and is_instance_valid(q) and q != game.local_player \
				and q.peer_id == pid:
			q.net_push_snapshot(pos, vel, look)
			return


# ------------------------------------------------ enemy mirror (MP-09) ---
# The host's combat, visible to guests (§4.1 enemies row). Reliable
# lifecycle events (spawn / death / despawn / elite / play_action) plus
# one ~20 Hz unreliable state packet; guests hold non-simulating mirror
# Enemy/Boss nodes (enemy.gd net_mirror). Telegraphs mirror at the end
# of this section. All host_* entry points are called under a
# game.net_host() guard (enemy.gd / game_base.gd) — solo never lands here.

## HOST: announce a freshly tree-entered enemy/boss to the session.
## Called from Enemy._ready() — the ONE choke point every spawn path
## (room packs, boss factories, trait summons, dev panel) crosses.
## Idempotent: net_id != 0 means it was already announced.
func host_register_enemy(e: Enemy) -> void:
	if game == null or e.net_id != 0 or e.net_mirror or e.dying:
		return
	if not _net().is_online() or not multiplayer.is_server():
		return
	_net_id_counter += 1
	e.net_id = _net_id_counter
	net_enemies[e.net_id] = e
	# Silent frees (room resets, teardown) fan out as despawns. A real
	# death erases the registry entry FIRST (host_enemy_died), so the
	# exit hook never double-fires for a kill.
	e.tree_exited.connect(_on_host_enemy_gone.bind(e.net_id))
	_rpc_spawn_enemy.rpc(_spawn_block(e))


## HOST: register any live enemy that predates the session going online
## (harness/CLI boots can order world-before-guests). Already-announced
## enemies (net_id != 0) skip inside host_register_enemy.
func host_sweep_unregistered() -> void:
	if game == null:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dying and e.net_id == 0:
			host_register_enemy(e)


## Everything a guest needs to rebuild this enemy with the REAL
## constructors: sprites, strips, HP bar and elite ring all come out
## right because Enemy.make/Boss.make_boss build the mirror too.
func _spawn_block(e: Enemy) -> Dictionary:
	# "gold" rides along (MP-10): boss summons / spawner sprouts zero it
	# host-side AFTER make(), and the guest's Hunger-execute math must see
	# the same "this prey pays nothing" the host does.
	# Wave-2 fix #3: "plated" so a guest joining DURING a cinderhide plated phase
	# builds its mirror with the plate wall already up (the 20 Hz stream keeps it
	# in sync thereafter; this just closes the spawn-to-first-packet gap).
	return {"id": e.net_id, "kind": e.kind, "level": e.level,
		"zone": e.zone_idx, "pos": e.global_position, "elite": e.elite,
		"boss": e is Boss, "hp": clampf(e.hp / maxf(e.max_hp, 0.001), 0.0, 1.0),
		"gold": e.gold_value, "plated": e.plate_dr > 0.0}


## HOST: a registered enemy died a REAL death (Enemy.die) — guests play
## the die juice on their mirror and free it.
func host_enemy_died(id: int) -> void:
	net_enemies.erase(id)
	_rpc_kill_enemy.rpc(id)


## HOST: a play_action one-shot fired — mirrors play the same strip.
## Wired at the play_action definition (enemy.gd), so every boss call
## site broadcasts for free.
func host_enemy_action(id: int, action: String) -> void:
	_rpc_enemy_action.rpc(id, action)


## HOST: a post-spawn elite promotion (room-ambush rolls promote after
## add_enemy) — mirrors get the ring/scale too.
func host_enemy_elite(id: int) -> void:
	_rpc_enemy_elite.rpc(id)


## HOST: a combat-tell tint fired (bite windup, pounce, guard, reflect —
## enemy.gd _net_tell) — mirrors tint their body for the window so a guest
## reads the same warning the host's sim shows (Wave-2 co-op fix #2).
func host_enemy_tell(id: int, color: Color, dur: float) -> void:
	_rpc_enemy_tell.rpc(id, color, dur)


## HOST: a registered enemy left the tree without dying (room reset,
## despawn) — guests free the mirror, no juice.
func _on_host_enemy_gone(id: int) -> void:
	if not net_enemies.has(id):
		return  # its death already fanned out, or session cleanup cleared it
	net_enemies.erase(id)
	# Teardown-safe: at quit the whole tree exits together and this node's
	# multiplayer accessor is already null — nothing left to fan out to.
	if not is_inside_tree() or multiplayer == null:
		return
	if _net().is_online() and multiplayer.is_server():
		_rpc_free_enemy.rpc(id)


## HOST: one ~20 Hz packet for every live enemy inside the sim gate
## (active_rooms, plus zone -1 homeless spawns — exactly the set whose
## _physics_process runs, so mirrors freeze on the same rule). Layout
## per enemy: net_id u32 | pos x f32 | pos y f32 | flags u8 (bit0 flip,
## bit1 walking, bit2 untargetable — burrow/submerge/blink phases gate
## guest auto-aim; bit3 hidden — Wave-2 fix #1 sprite invisible; bit4
## plated — Wave-2 fix #3 cinderhide plate wall up; bits 5-7 free) | hp u8
## (fraction x255) = 14 bytes; a 40-enemy worst case is ~560 B (§4.1 budget).
func _stream_enemy_state() -> void:
	if net_enemies.is_empty():
		return
	var buf := StreamPeerBuffer.new()
	var stale: Array = []
	var n := 0
	for id in net_enemies:
		var e: Enemy = net_enemies[id]
		if e == null or not is_instance_valid(e):
			stale.append(id)
			continue
		if e.dying:
			continue  # the death event owns the ending
		if e.zone_idx >= 0 and not game.active_rooms.has(e.zone_idx):
			continue  # frozen rooms don't stream
		buf.put_u32(int(id))
		buf.put_float(e.global_position.x)
		buf.put_float(e.global_position.y)
		var flags := 0
		if e.sprite != null and e.sprite.flip_h:
			flags |= 1
		if e._moving_anim:
			flags |= 2
		if e.untargetable:
			flags |= 4
		# Wave-2 fix #1: a burrowed/submerged boss goes invisible host-side —
		# carry it so the mirror doesn't stand visible in the open.
		if e.sprite != null and not e.sprite.visible:
			flags |= 8
		# Wave-2 fix #3: the cinderhide plate wall — the mirror's think never
		# raises plate_dr, so ship the bit and let net_set_plated match the cut.
		if e.plate_dr > 0.0:
			flags |= 16
		buf.put_u8(flags)
		buf.put_u8(int(clampf(e.hp / maxf(e.max_hp, 0.001), 0.0, 1.0) * 255.0))
		n += 1
	for id in stale:
		net_enemies.erase(id)
	if n > 0:
		_rpc_enemy_state.rpc(buf.data_array)


## GUEST: build the mirror. Real Enemy.make/Boss.make_boss construction,
## then hard-gate it as a presentation clone: no AI, no damage, no
## player collision (# MP: contact damage arrives via MP-10's
## player-damage RPC — a mirror must never body-block or hurt).
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_enemy(block: Dictionary) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	var id: int = int(block.get("id", 0))
	if id <= 0:
		return
	if net_enemies.has(id):
		var old: Enemy = net_enemies[id]
		if old != null and is_instance_valid(old) and not old.dying:
			return  # the join-snapshot overlap window (already built)
		# A stale entry: the local death flow (game_flow) freed this mirror
		# as if the world were its own — the host's resync rebuilds it.
		net_enemies.erase(id)
	var kind := String(block.get("kind", ""))
	if not Story.ALL_ENEMIES.has(kind):
		return
	var pos: Vector2 = block.get("pos", Vector2.ZERO)
	var lvl: int = maxi(1, int(block.get("level", 1)))
	var e: Enemy
	if bool(block.get("boss", false)):
		e = Boss.make_boss(game, kind, pos, lvl)
	else:
		e = Enemy.make(game, kind, pos, lvl)
	e.net_mirror = true
	e.net_id = id
	e.zone_idx = int(block.get("zone", -1))
	e.gold_value = int(block.get("gold", e.gold_value))
	# MP-10: mirrors keep the enemy LAYER bit (solo enemies live on layer
	# 4) so a guest's friendly projectiles detect them and its player
	# body-blocks against them — combat and movement feel like solo. The
	# zero MASK keeps the mirror itself from ever processing collisions.
	e.collision_layer = 4
	e.collision_mask = 0
	if bool(block.get("elite", false)):
		e.promote_elite()
	e.net_apply_state(pos, false, false, clampf(float(block.get("hp", 1.0)), 0.0, 1.0),
		false, false, bool(block.get("plated", false)))
	net_enemies[id] = e
	if e is Boss:
		# The per-frame boss bar (game.gd) reads this roster — a live
		# boss mirror shows/updates the bar exactly like the host's own.
		game.bosses.append(e)
	# Deferred: the RPC can land mid physics flush, and a collider
	# entering the tree there trips the flush guard (CLAUDE.md).
	game.world.add_child.call_deferred(e)


## GUEST: unpack the ~20 Hz state onto the mirrors. Unknown ids are
## skipped — their reliable spawn event is still in flight.
@rpc("authority", "call_remote", "unreliable")
func _rpc_enemy_state(data: PackedByteArray) -> void:
	if game == null or multiplayer.is_server():
		return
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	while buf.get_available_bytes() >= 14:
		var id := buf.get_u32()
		var px := buf.get_float()
		var py := buf.get_float()
		var flags := buf.get_u8()
		var frac := buf.get_u8() / 255.0
		var e: Enemy = net_enemies.get(id)
		if e == null or not is_instance_valid(e) or e.dying:
			continue
		e.net_apply_state(Vector2(px, py), (flags & 1) != 0, (flags & 2) != 0,
			frac, (flags & 4) != 0, (flags & 8) != 0, (flags & 16) != 0)


## GUEST: the original died — die juice on the mirror, then free.
@rpc("authority", "call_remote", "reliable")
func _rpc_kill_enemy(id: int) -> void:
	if game == null or multiplayer.is_server():
		return
	var e: Enemy = net_enemies.get(id)
	net_enemies.erase(id)
	if e != null and is_instance_valid(e):
		e.net_mirror_die()
		if e is Boss:
			_guest_boss_gone.call_deferred()


## GUEST: the original despawned silently (room reset) — just vanish.
@rpc("authority", "call_remote", "reliable")
func _rpc_free_enemy(id: int) -> void:
	if game == null or multiplayer.is_server():
		return
	var e: Enemy = net_enemies.get(id)
	net_enemies.erase(id)
	if e != null and is_instance_valid(e):
		if e is Boss:
			_guest_boss_gone.call_deferred()
		e.queue_free()


## GUEST: play the one-shot ability strip the host's enemy just played.
@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_action(id: int, action: String) -> void:
	if game == null or multiplayer.is_server():
		return
	var e: Enemy = net_enemies.get(id)
	if e != null and is_instance_valid(e) and not e.dying:
		e.play_action(action)


## GUEST: mirror a post-spawn elite promotion (ring, scale, name).
@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_elite(id: int) -> void:
	if game == null or multiplayer.is_server():
		return
	var e: Enemy = net_enemies.get(id)
	if e != null and is_instance_valid(e) and not e.dying:
		e.promote_elite()


## GUEST: a combat-tell tint fired on the host's enemy — apply it to the
## mirror for the window (Wave-2 co-op fix #2).
@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_tell(id: int, color: Color, dur: float) -> void:
	if game == null or multiplayer.is_server():
		return
	var e: Enemy = net_enemies.get(id)
	if e != null and is_instance_valid(e) and not e.dying:
		e.net_apply_tell(color, dur)


## GUEST: a boss mirror is gone — stop drawing the bar once no live boss
## remains (the HOST runs the real kill flow with its banners; this is
## presentation cleanup only). Deferred so _live_bosses sees the death.
func _guest_boss_gone() -> void:
	if game == null:
		return
	if game._live_bosses().is_empty() and game.hud != null:
		game.hud.hide_boss_bar()
		game.current_boss = null


# --------------------------------------------- telegraph mirror (MP-09) ---
# Ground tells are the co-op dodging language: the host broadcasts the
# same parameters its own telegraph renders from (game_base hooks), and
# guests re-enter the SAME functions flagged net_visual — full visuals
# (pulse, sword/fireball, beacons, decoys, dread ramp), zero damage.

## HOST -> GUESTS: a danger telegraph formed (game_base.telegraph).
func host_telegraph(pos: Vector2, radius: float, delay: float, opts: Dictionary) -> void:
	_rpc_telegraph.rpc(pos, radius, delay, opts)


## HOST -> GUESTS: a safe-spot exam began (game_base.telegraph_safe).
func host_telegraph_safe(centers: Array, radius: float, delay: float, opts: Dictionary) -> void:
	_rpc_telegraph_safe.rpc(centers, radius, delay, opts)


@rpc("authority", "call_remote", "reliable")
func _rpc_telegraph(pos: Vector2, radius: float, delay: float, opts: Dictionary) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	var o: Dictionary = opts.duplicate()
	o["net_visual"] = true
	game.telegraph(pos, radius, delay, 0.0, o)


@rpc("authority", "call_remote", "reliable")
func _rpc_telegraph_safe(centers: Array, radius: float, delay: float, opts: Dictionary) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	var o: Dictionary = opts.duplicate()
	o["net_visual"] = true
	game.telegraph_safe(centers, radius, delay, 0.0, o)


# ------------------------------------ boss callouts + verdict wash (Wave-2 #8) ---
# The mechanical dodge info already mirrors (telegraph tiles); these carry the
# READABILITY aids a guest's silent boss mirror never learned — standalone
# spawn_text banners (enrage / intercept / verdict) and Ordo's half-wash glow
# that paints which half is guilty. Host-only fans; no-ops offline.

## HOST -> GUESTS: a boss/world callout banner at a world position. Fanned by
## game.spawn_text_all (the host renders its own copy inline). Guests render the
## SAME text at the same world point — their boss mirror sits there.
func host_spawn_text(pos: Vector2, text: String, color: Color, hold: float) -> void:
	_rpc_spawn_text.rpc(pos, text, color, hold)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_text(pos: Vector2, text: String, color: Color, hold: float) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.spawn_text(pos, text, color, hold)


## HOST -> GUESTS: Ordo's verdict half-wash (boss.gd _half_wash) — the guilty
## half glows for its fuse. The geometry is seed-pure (room_rect off the mirror's
## zone), so the guest re-runs _half_wash on its own boss mirror to paint the
## same half. Keyed by net_id; skipped if the mirror isn't up yet.
func host_boss_wash(id: int, west: bool, dur: float, muted: bool) -> void:
	_rpc_boss_wash.rpc(id, west, dur, muted)


@rpc("authority", "call_remote", "reliable")
func _rpc_boss_wash(id: int, west: bool, dur: float, muted: bool) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	var b := net_enemies.get(id) as Boss
	if b != null and is_instance_valid(b) and not b.dying:
		b._half_wash(b._arena_rect(), west, dur, muted)


# --------------------------------------- combat over the wire (MP-10) ---
# The §4.1 damage rows. Formats: hit/status/vitals RPCs are small typed
# arg lists or short-key dicts (~30-90 B on the wire); projectile spawn
# events are one short-key dict (~200 B, reliable, spawn-rate bounded);
# the 14 B/enemy state packet is untouched (bit 2 of its flag byte now
# carries untargetable).

## The registered player owned by peer pid, or null (host shells and
## guest-side remotes both resolve through here).
func _player_of(pid: int) -> Player:
	if game == null:
		return null
	for q in game.players:
		if q != null and is_instance_valid(q) and q.peer_id == pid:
			return q
	return null


# ---- guest -> enemy damage (trusted client computes, host applies) ----

## GUEST -> HOST: a locally-computed hit landed on a mirror. `amount` is
## PRE-take_damage (the host's take_damage re-applies vuln/ward/plate
## against authoritative state); the guest already played its juice.
func guest_hit_enemy(id: int, amount: float, from_dir: Vector2, crit: bool) -> void:
	if id <= 0 or game == null or not _net().is_online() or multiplayer.is_server():
		return
	_rpc_hit_enemy.rpc_id(1, id, amount, from_dir, crit)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hit_enemy(id: int, amount: float, from_dir: Vector2, crit: bool) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	var e: Enemy = net_enemies.get(id)
	if e == null or not is_instance_valid(e) or e.dying:
		return  # died/despawned while the hit was in flight — the guest's
		        # kill event (or free) is already on its way back
	# The guest's host-side shell is the SOURCE: reflect/counter answer it,
	# aggro turns on it, and the kill's death flow attributes normally.
	e.hit_src = _player_of(pid)
	e.take_damage(maxf(0.0, amount), from_dir, crit)
	last_hit = {"id": id, "peer": pid, "amount": maxf(0.0, amount), "crit": crit}


## GUEST -> HOST: a rider/status a guest's kit applied to a mirror — the
## host re-applies through the REAL apply_* paths with the guest's shell
## as DoT source (phase-0 src seam), so ticks crit off the right sheet.
func guest_enemy_status(id: int, kind: String, d: Dictionary) -> void:
	if id <= 0 or game == null or not _net().is_online() or multiplayer.is_server():
		return
	_rpc_enemy_status.rpc_id(1, id, kind, d)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_enemy_status(id: int, kind: String, d: Dictionary) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	var e: Enemy = net_enemies.get(id)
	if e == null or not is_instance_valid(e) or e.dying:
		return
	var src: Player = _player_of(pid)
	match kind:
		"burn":
			e.apply_burn(float(d.get("dps", 0.0)), float(d.get("dur", 3.0)),
				d.get("color", Color(1.4, 0.8, 0.6)), src)
		"toxin":
			e.apply_toxin(float(d.get("dps", 0.0)), float(d.get("dur", 3.0)),
				d.get("color", Color(0.5, 1.2, 0.5)), src)
		"bleed":
			e.apply_bleed(float(d.get("dps", 0.0)), float(d.get("dur", 3.0)), src)
		"slow":
			e.apply_slow(float(d.get("mult", 0.5)), float(d.get("dur", 2.0)))
		"stun":
			e.apply_stun(float(d.get("dur", 0.5)))
		"vuln":
			e.apply_vuln(float(d.get("dur", 3.0)), float(d.get("mult", -1.0)))
		"brittle":
			e.add_brittle()
		"knock":
			e.apply_knock(d.get("v", Vector2.ZERO), bool(d.get("crush", false)))
		"drag":
			# Chains of Wrath: the host tweens its REAL enemy to the guest's
			# computed drag point; the mirror follows through the stream.
			var dest: Vector2 = d.get("dest", e.global_position)
			var tw := e.create_tween()
			tw.tween_property(e, "global_position", dest, float(d.get("dur", 0.28))) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ---- enemy -> guest damage ("host decides, owner applies", §4.1) ----

## HOST -> OWNER: a host-side hit landed on peer pid's shell (contact
## bite, windup, boss swing, hostile projectile, telegraph resolution,
## reflect). The owner runs its REAL take_damage — mitigation, dodge,
## hurt_cd (incl. the heavy-pierce rule) and death happen on the machine
## that owns the stats. attacker_id names the enemy so the owner resolves
## crit/pen/dex/Enfeeble against its own mirror, exactly like solo.
func host_player_hit(pid: int, amount: float, dmg_type: String, attacker_id: int, heavy: bool) -> void:
	if not _net().is_online() or not multiplayer.is_server():
		return
	if not (pid in _net().peers):
		return
	_rpc_player_hit.rpc_id(pid, amount, dmg_type, attacker_id, heavy)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_hit(amount: float, dmg_type: String, attacker_id: int, heavy: bool) -> void:
	if game == null or multiplayer.is_server():
		return
	var p: Node = game.local_player
	if p == null or not is_instance_valid(p):
		return
	var attacker: Enemy = null
	if attacker_id > 0:
		var m: Enemy = net_enemies.get(attacker_id)
		if m != null and is_instance_valid(m) and not m.dying:
			attacker = m  # the mirror: real kind/level stats resolve the hit
	p.take_damage(maxf(0.0, amount), dmg_type, attacker, heavy)


## HOST -> OWNER: a control effect a host-side source put on the shell
## (telegraph freeze/root riders, webber snare, counter stagger, frost
## aura chill) — the owner applies the REAL state. Chill refreshes every
## FRAME while an aura holds (enemy.gd) — throttle it; its 0.35 s local
## duration bridges the gaps. One-shots (freeze/root) always pass.
func host_player_status(pid: int, kind: String, a: float, b := 0.0) -> void:
	if not _net().is_online() or not multiplayer.is_server():
		return
	if not (pid in _net().peers):
		return
	if kind == "chill":
		var key := "%d:chill" % pid
		var now := Time.get_ticks_msec()
		if now - int(_status_throttle.get(key, -9999)) < 150:
			return
		_status_throttle[key] = now
	_rpc_player_status.rpc_id(pid, kind, a, b)


@rpc("authority", "call_remote", "reliable")
func _rpc_player_status(kind: String, a: float, b: float) -> void:
	if game == null or multiplayer.is_server():
		return
	var p: Node = game.local_player
	if p == null or not is_instance_valid(p):
		return
	match kind:
		"freeze":
			p.apply_freeze(a)
		"root":
			p.apply_root(a)
		"chill":
			p.apply_chill(a, maxf(0.05, b))


# ---- vitals sync (owner broadcasts, shells display) ----

## Owner-side: broadcast {hp, max_hp, mp} when they changed — capped at
## VITALS_EVERY, except a DROP in hp (damage) which sends immediately.
## Shells apply it for bars, host-side threshold reads, and the `dead`
## flag that steers enemy AI off a fallen guest. ~25 B reliable.
func _tick_vitals(delta: float, p: Node) -> void:
	_vitals_accum += delta
	var hp := float(p.hp)
	var mhp := float(p.max_hp)
	var mpv := float(p.mp)
	var dropped: bool = _vitals_sent.has("hp") and hp < float(_vitals_sent["hp"]) - 0.01
	if _vitals_accum < VITALS_EVERY and not dropped:
		return
	if not dropped and _vitals_sent.has("hp") \
			and absf(hp - float(_vitals_sent["hp"])) < 0.5 \
			and absf(mhp - float(_vitals_sent["max_hp"])) < 0.5 \
			and absf(mpv - float(_vitals_sent["mp"])) < 1.0:
		return  # nothing worth a packet changed
	_vitals_accum = 0.0
	_vitals_sent = {"hp": hp, "max_hp": mhp, "mp": mpv}
	_rpc_vitals.rpc(hp, mhp, mpv)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_vitals(hp: float, max_hp: float, mp: float) -> void:
	if game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0:
		return
	var q: Player = _player_of(pid)
	if q == null or q == game.local_player:
		return
	q.max_hp = maxf(1.0, max_hp)
	q.hp = clampf(hp, 0.0, q.max_hp)
	q.mp = maxf(0.0, mp)
	# MP-12: a DOWNED/GHOST shell is NOT dead — the §5.3 state (which the
	# owner broadcasts before this hp=0 lands on the same reliable channel)
	# already steers AI off it via nearest_player's downed filter. `dead`
	# now only marks the wipe flow's real deaths.
	q.dead = q.hp <= 0.0 and not q.downed and not q.ghost


# ---- XP on kill (§5.5: full XP to every party member) ----

## HOST: an enemy died — fan the SAME full award to every guest whose
## player stands in the active-room set (the host's own award stays in
## Enemy.die, untouched). Elites/summons pay 0 and never reach the wire.
func host_award_xp(amount: int) -> void:
	if amount <= 0 or game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		var q: Player = _player_of(int(pid))
		if q == null:
			continue
		var r: int = game.room_at_pos(q.global_position)
		if r >= 0 and not game.active_rooms.has(r):
			continue
		_rpc_award_xp.rpc_id(int(pid), amount)


@rpc("authority", "call_remote", "reliable")
func _rpc_award_xp(amount: int) -> void:
	if game == null or multiplayer.is_server():
		return
	var p: Node = game.local_player
	if p != null and is_instance_valid(p):
		p.gain_xp(maxi(0, amount))


# ------------------------------------------- loot instancing (MP-11) ---
# §5.5: every faucet pays per head. The host's own share stays inline in
# game_flow's kill flows; these fan each GUEST a personal copy. Rolls
# that depend on owner-side stats (chest-chance greed) ride to the owner
# unrolled; everything else is host-rolled per player from loot_rng (one
# full independent sequence per head — roll_*_pack in game_flow.gd).
# Owners apply DEFERRED (award packages spawn Area2Ds; RPCs can land mid
# physics flush — CLAUDE.md).

## HOST: a trash (non-elite) kill — each guest gets its personal kill
## event: the BASE pile + a host-rolled Gold Rush coin chance (per head,
## §5.5 point 6; the paying-kill gate is the enemy's own gold_value).
## The owner rolls its chest chance itself (it reads the OWNER's greed).
func host_mob_kill(e: Enemy) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		var gr: bool = e.gold_value > 0 \
			and game.loot_rng.randf() < Balance.GOLDRUSH_DROP_CHANCE
		_rpc_mob_kill.rpc_id(int(pid), e.global_position, e.gold_value, gr)


## HOST: an elite fell — one personal, host-rolled pinata per guest +
## their elite bounty credit.
func host_elite_kill(e: Enemy) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		_rpc_award.rpc_id(int(pid), game.roll_elite_pack(e))
		_credit_peer(int(pid), "elite")


## HOST: a story boss fell — one personal package per guest (gear rolls
## THEIR class) + boss bounty/vault credit.
func host_boss_kill(kind: String, boss_pos: Vector2, boss_lv: int, first_clear: bool) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		var q: Player = _player_of(int(pid))
		var cls: String = q.cls if q != null else String(peer_chars[pid].get("cls", "warrior"))
		_rpc_award.rpc_id(int(pid), game.roll_boss_pack(kind, boss_pos, boss_lv, first_clear, cls))
		_credit_peer(int(pid), "boss")


## HOST: the same award package to every guest (rogue-boss chest + pile,
## dev gifts). No per-head rolls inside — positions/tiers only; anything
## random lands as a base the owner rolls or multiplies itself.
func host_award_all(evs: Array) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		_rpc_award.rpc_id(int(pid), evs)


## HOST: a cursed room paid out — a personal hoard per guest (the Lv2
## gem odds read each head's own level, like solo reads yours).
func host_curse_payout(zi: int) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		var q: Player = _player_of(int(pid))
		var lv: int = q.level if q != null else 1
		_rpc_award.rpc_id(int(pid), game.roll_curse_pack(zi, lv))


## HOST: a shared clear moment credited everyone's boards ("room" today;
## "boss"/"elite" ride their kill fan-outs).
func host_party_credit(kind: String) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		_credit_peer(int(pid), kind)


## HOST: the chapter ended — every guest flushes ITS OWN ground strays
## into ITS OWN mailbox, and a first clear pays each head its beat.
## Wave-1 co-op fix (design #9): first-clear is the RECIPIENT's beat, not the
## host's. The old fan gated on the HOST's first_clear, so a first-timer guest
## under a veteran host got NOTHING and a veteran guest under a first-timer host
## was double-paid. Fan to EVERY guest unconditionally; each self-gates on its
## OWN completed_<ch> at receipt (before net_victory records it). `_first_clear`
## is now advisory (kept for the call signature).
func host_chapter_end(_first_clear: bool, boss_lv: int) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		_rpc_flush_loot.rpc_id(int(pid))
		_rpc_first_clear.rpc_id(int(pid), boss_lv)


## HOST: bounty/vault credit to one peer, gated like the XP fan-out
## (host_award_xp): present in the active-room set or it doesn't count.
func _credit_peer(pid: int, kind: String) -> void:
	var q: Player = _player_of(pid)
	if q != null:
		var r: int = game.room_at_pos(q.global_position)
		if r >= 0 and not game.active_rooms.has(r):
			return
	_rpc_credit.rpc_id(pid, kind)


## OWNER: a personal award package — apply through the normal paths.
@rpc("authority", "call_remote", "reliable")
func _rpc_award(evs: Array) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	last_award = evs
	game.apply_award_events.call_deferred(evs)


## OWNER: a personal trash-kill event (base pile + own chest roll + a
## host-rolled Gold Rush coin).
@rpc("authority", "call_remote", "reliable")
func _rpc_mob_kill(pos: Vector2, base_gold: int, goldrush: bool) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.mob_kill_share.call_deferred(pos, base_gold, goldrush)


## OWNER: advance the OWN bounty board / weekly vault (character-owned
## counters — they ride this player's save home, §5.5/§5.7).
@rpc("authority", "call_remote", "reliable")
func _rpc_credit(kind: String) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	match kind:
		"boss":
			game.bounty_progress.call_deferred("boss_kills")
			game.vault_note_boss.call_deferred()
		"elite":
			game.bounty_progress.call_deferred("elite_kills")
		"room":
			game.bounty_progress.call_deferred("rooms_cleared")


## OWNER: first clear of the chapter — the same legible beat solo pays,
## rolled (own class) and mailed (own mailbox) on this machine.
@rpc("authority", "call_remote", "reliable")
func _rpc_first_clear(boss_lv: int) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	# Per-head gate (design #9): only a guest that hasn't completed this chapter
	# earns the bundle — decided HERE, synchronously, before net_victory (a later
	# reliable RPC) records the completion. The host's own share stays inline in
	# game_flow.on_boss_died.
	if game.get_flag("completed_" + game.chapter_id, false):
		return
	game._first_clear_reward.call_deferred(boss_lv)


## OWNER: chapter-end flush — MY strays into MY mailbox.
@rpc("authority", "call_remote", "reliable")
func _rpc_flush_loot() -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.flush_dropped_loot.call_deferred()


# ---- personal chests (no chest.gd edits — the owner's file) ----

## Any node joining the game: while online, a fresh Chest gets its open
## trigger re-filtered to the LOCAL player. Chests parent directly under
## game (Chest.drop), and their signal is connected BEFORE add_child, so
## the rewrap here always finds it. Offline this is a no-op check.
func _on_game_child(node: Node) -> void:
	if node is Chest and _net().is_online():
		_gate_chest(node as Chest)


## Session start (host: first knock; guest: world rebuilt): chests that
## predate the session get the same filter. Idempotent — a rewrapped
## chest no longer holds its original connection.
func _gate_existing_chests() -> void:
	if game == null:
		return
	for node in game.get_children():
		if node is Chest:
			_gate_chest(node as Chest)


## The filter: swap the chest's own body_entered connection for a
## local-player gate that forwards to the same open logic (deferred,
## like the original — opening spawns Area2Ds). §5.5: one chest MOMENT,
## every machine holds its own copy with its own contents roll — so a
## remote's shell gliding over YOUR copy must never pop it.
func _gate_chest(c: Chest) -> void:
	if not c.body_entered.is_connected(c._on_body_entered):
		return  # already rewrapped (or chest.gd rewired itself)
	c.body_entered.disconnect(c._on_body_entered)
	c.body_entered.connect(_chest_touch.bind(c), CONNECT_DEFERRED)


func _chest_touch(body: Node, c: Chest) -> void:
	if game != null and body == game.local_player and is_instance_valid(c):
		c._on_body_entered(body)


# ---- projectiles both ways (§4.1: spawn event + local flight) ----

## OWNER -> EVERYONE: a real projectile left this machine (a guest's own
## shot, or the host's — friendly AND hostile). Everyone else spawns a
## VISUAL-ONLY copy that flies the same line; damage never rides a copy
## (guest hits funnel through _rpc_hit_enemy, hostile hits through
## _rpc_player_hit when the host's REAL bolt connects).
func announce_projectile(p: Projectile) -> void:
	if game == null or not _net().is_online():
		return
	var block := {
		"pos": p.global_position, "vel": p.vel, "tex": p.tex_kind,
		"f": p.friendly, "pi": p.pierce, "ho": p.homing, "li": p.life,
		"mo": p.modulate, "gl": p.glow_color, "sp": p.spin, "sc": p.scale,
		"ri": p.rise,
	}
	if not p.friendly and multiplayer.is_server():
		_net_proj_counter += 1
		p.net_id = _net_proj_counter
		net_projectiles[p.net_id] = p
		p.tree_exited.connect(_forget_projectile.bind(p.net_id))
		block["id"] = p.net_id
		if p.source_enemy is Enemy:
			block["src"] = (p.source_enemy as Enemy).net_id
	_rpc_spawn_projectile.rpc(block)


func _forget_projectile(id: int) -> void:
	net_projectiles.erase(id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_projectile(block: Dictionary) -> void:
	if game == null or not bool(game.play_started):
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0:
		return
	if not bool(block.get("f", true)) and pid != 1:
		return  # hostile spawns are host-only business
	# Deferred: the RPC can land mid physics flush, and a fresh Area2D's
	# enter-tree there trips the flush guard (CLAUDE.md).
	_spawn_projectile_visual.call_deferred(block)


func _spawn_projectile_visual(block: Dictionary) -> void:
	if game == null or not _net().is_online():
		return
	var friendly := bool(block.get("f", true))
	var p := Projectile.spawn(game, block.get("pos", Vector2.ZERO),
		block.get("vel", Vector2.ZERO), 0.0, friendly, String(block.get("tex", "bolt")))
	p.net_visual = true
	p.net_id = int(block.get("id", 0))
	p.pierce = bool(block.get("pi", false))
	p.homing = bool(block.get("ho", false))
	p.life = float(block.get("li", 2.5))
	p.modulate = block.get("mo", Color(1, 1, 1))
	p.glow_color = block.get("gl", p.glow_color)
	p.spin = bool(block.get("sp", true))
	p.scale = block.get("sc", Vector2.ONE)
	p.rise = float(block.get("ri", 0.0))
	var src_id := int(block.get("src", 0))
	if src_id > 0:
		var m: Enemy = net_enemies.get(src_id)
		if m != null and is_instance_valid(m):
			p.source_enemy = m  # Mirrorstep lashes the right shooter's mirror


## GUEST -> HOST: Mirrorstep turned a hostile shot aside — consume the
## REAL one too, or the deflected bolt still lands via the damage RPC.
func guest_consume_projectile(id: int) -> void:
	if id <= 0 or game == null or not _net().is_online() or multiplayer.is_server():
		return
	_rpc_consume_projectile.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_consume_projectile(id: int) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	var p: Projectile = net_projectiles.get(id)
	net_projectiles.erase(id)
	if p != null and is_instance_valid(p):
		game.burst(p.global_position, Color(0.7, 0.5, 1.0), 5)
		p.queue_free()


# ---- dynamic hazards (combat ground the sim writes mid-fight) ----

## HOST -> GUESTS: a dynamic hazard formed (sower trail, bloat pool, boss
## slag/ice/poison) — guests paint the same patch locally, and each
## machine's own _apply_hazards ticks its OWN player (owner applies; no
## per-tick traffic). World-gen hazards are seed-pure and never come here.
func host_hazard(zi: int, type: String, pos: Vector2, radius: float, dur: float, drift := Vector2.ZERO) -> void:
	if not _net().is_online() or not multiplayer.is_server():
		return
	_rpc_hazard.rpc(zi, type, pos, radius, dur, drift)


@rpc("authority", "call_remote", "reliable")
func _rpc_hazard(zi: int, type: String, pos: Vector2, radius: float, dur: float, drift: Vector2) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	if zi < 0 or zi >= int(game.zone_count):
		return
	game._add_hazard(zi, type, pos, radius, dur, drift)


# ------------------------------------ world consistency (Wave-1 co-op fixes) ---
# Three host-authoritative world facts that a guest's silent mirrors / early-
# return weather never learned on their own: a boss gate opening, a wandering
# merchant arriving, and a sandstorm gust. Each fans from a game-side hook under
# a net_host() guard; late-joiner-durable state (boss_done, merchant_zones) also
# rides the join snapshot. All no-op offline — solo never enters this file.

## HOST -> GUESTS: a story boss fell (game_flow.on_boss_died). boss_done gates
## the "boss" edge locks; a guest's mirror death runs no triggers, so without
## this the guest stays WALLED inside the arena. Late joiners get boss_done in
## the snapshot; this covers everyone already in the session.
func host_boss_done(kind: String) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	_rpc_boss_done.rpc(kind)


@rpc("authority", "call_remote", "reliable")
func _rpc_boss_done(kind: String) -> void:
	if game == null or multiplayer.is_server():
		return
	game.net_apply_boss_done(kind)


## HOST -> GUESTS: a wandering merchant set up camp (game_world._merchant_arrives,
## a host-only post-clear/post-boss roll). Guests re-enter the same arrival so
## the node + fanfare land owner-side (a built room spawns it now, an unbuilt one
## marks merchant_zones and spawns on entry). Deferred: _make_npc is safe, but
## the RPC-context defer keeps us consistent with the other spawn fan-outs.
func host_merchant_arrives(zi: int) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	_rpc_merchant_arrives.rpc(zi)


@rpc("authority", "call_remote", "reliable")
func _rpc_merchant_arrives(zi: int) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	if zi < 0 or zi >= int(game.zone_count):
		return
	game._merchant_arrives.call_deferred(zi)


## HOST -> GUESTS: a sandstorm gust (game_flow.run_terrain_event, host-only
## weather). Guests set the same push vector/timer so it shoves their player and
## enemies too; game.gd's per-frame decays it on every machine.
func host_gust(vec: Vector2, dur: float) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	_rpc_gust.rpc(vec, dur)


@rpc("authority", "call_remote", "reliable")
func _rpc_gust(vec: Vector2, dur: float) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.gust_vec = vec
	game.gust_t = dur


## HOST -> GUESTS: a room curse was accepted (game_world._apply_room_curse). The
## host buffs + tints only ITS enemies; guests fight the same host-buffed pack
## (real host damage) but saw no tint/text. Fan the visual so a guest's mirror
## enemies in that zone go violet and the party reads WHY the pack got crueler.
func host_curse_applied(zi: int) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	_rpc_curse_applied.rpc(zi)


@rpc("authority", "call_remote", "reliable")
func _rpc_curse_applied(zi: int) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	# Tint this zone's mirror enemies to match the host's _apply_room_curse cast
	# (guarded by the same "cursed" meta so a rebuild/re-fan never double-tints).
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying or e.zone_idx != zi:
			continue
		if e.has_meta("cursed"):
			continue
		e.set_meta("cursed", true)
		e.modulate = e.modulate * Color(0.85, 0.65, 1.1)
	if game.local_player != null and is_instance_valid(game.local_player):
		game.spawn_text(game.local_player.global_position + Vector2(0, -78),
			"THE PACK STIRS, CRUELER — purge the room to claim the hoard",
			Color(0.85, 0.6, 1.0), 3.5)


# ------------------------------------------- downed / revive / wipe (MP-12) ---
# §5.3. State ownership: DOWN transitions belong to the fallen player's
# OWNER (its take_damage/_down_tick run them and broadcast here); the
# revive CHANNEL belongs to the reviver's machine (its clock, its
# movement/damage interrupts) with the HOST as claim arbiter (first
# channel wins); GHOST-revive and the WIPE belong to the HOST (it owns
# the room-clear truth and the party census). The stand-up itself is
# always owner-applied: request -> host validate -> owner confirm.

## OWNER -> EVERYONE: this machine's player changed §5.3 state.
## st: 0 = standing (revived), 1 = downed, 2 = ghost.
func send_down_state(st: int) -> void:
	if game == null or not _net().is_online():
		return
	_rpc_down_state.rpc(st)
	if multiplayer.is_server():
		_host_note_down(1, st)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_down_state(st: int) -> void:
	if game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0:
		return
	var q: Player = _player_of(pid)
	if q != null and q != game.local_player:
		q.net_set_down(st)
	if multiplayer.is_server():
		_host_note_down(pid, st)


## HOST bookkeeping on every state change: remember where the fall
## happened (the wipe resets that room), free lapsed channels, and
## re-check the wipe condition.
func _host_note_down(pid: int, st: int) -> void:
	if st == 1:
		var q: Player = _player_of(pid)
		if q != null:
			var r: int = game.room_at_pos(q.global_position)
			if r >= 0:
				_last_down_room = r
	else:
		# Stood up or ghosted: any channel on this body is over.
		if _revive_claims.has(pid):
			_revive_claims.erase(pid)
			_broadcast_revive_end(pid)
	_check_wipe()


# ---- the revive channel (reviver clock, host arbitration) ----

## REVIVER -> HOST: ask to open the channel on downed_pid.
func request_revive(downed_pid: int) -> void:
	if game == null or not _net().is_online():
		return
	if multiplayer.is_server():
		_host_revive_request(downed_pid, 1)
	else:
		_rpc_revive_request.rpc_id(1, downed_pid)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_revive_request(downed_pid: int) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	_host_revive_request(downed_pid, pid)


## HOST: grant the claim if the body is downed and unclaimed — first
## channel wins; a later hopeful gets NOTHING back (the §5.3 busy no-op).
func _host_revive_request(downed_pid: int, reviver_pid: int) -> void:
	var q: Player = _player_of(downed_pid)
	if q == null or not is_instance_valid(q) or not (q.downed or q.ghost):
		return  # channel revives a downed OR ghosted body (§5.3, owner 2026-07-10)
	var holder: int = int(_revive_claims.get(downed_pid, 0))
	if holder != 0 and holder != reviver_pid:
		return
	_revive_claims[downed_pid] = reviver_pid
	_rpc_revive_begin.rpc(downed_pid, reviver_pid)
	_apply_revive_begin(downed_pid, reviver_pid)


## HOST -> EVERYONE: a channel opened (both parties show the bar; the
## granted reviver starts its clock).
@rpc("authority", "call_remote", "reliable")
func _rpc_revive_begin(downed_pid: int, reviver_pid: int) -> void:
	if game == null or multiplayer.is_server():
		return
	_apply_revive_begin(downed_pid, reviver_pid)


func _apply_revive_begin(downed_pid: int, reviver_pid: int) -> void:
	var q: Player = _player_of(downed_pid)
	if q != null:
		q.being_revived_by = reviver_pid
		q.revive_bar_ms = Time.get_ticks_msec()
	if reviver_pid == multiplayer.get_unique_id() and q != null \
			and game.local_player != null and is_instance_valid(game.local_player):
		game.local_player.revive_target = q
		game.local_player.revive_t = 0.0


## REVIVER -> HOST: the channel broke (release / moved / range / a hit).
func cancel_revive(downed_pid: int) -> void:
	if game == null or not _net().is_online():
		return
	if multiplayer.is_server():
		_host_revive_cancel(downed_pid, 1)
	else:
		_rpc_revive_cancel.rpc_id(1, downed_pid)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_revive_cancel(downed_pid: int) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	_host_revive_cancel(downed_pid, pid)


func _host_revive_cancel(downed_pid: int, reviver_pid: int) -> void:
	if int(_revive_claims.get(downed_pid, 0)) != reviver_pid:
		return  # not the holder — nothing to free
	_revive_claims.erase(downed_pid)
	_broadcast_revive_end(downed_pid)


## HOST -> EVERYONE: the channel on downed_pid ended (cancel, stand-up,
## or completion) — bars down, claim freed.
func _broadcast_revive_end(downed_pid: int) -> void:
	_rpc_revive_end.rpc(downed_pid)
	_apply_revive_end(downed_pid)


@rpc("authority", "call_remote", "reliable")
func _rpc_revive_end(downed_pid: int) -> void:
	if game == null or multiplayer.is_server():
		return
	_apply_revive_end(downed_pid)


func _apply_revive_end(downed_pid: int) -> void:
	var q: Player = _player_of(downed_pid)
	if q != null:
		q.being_revived_by = 0
	var lp: Player = game.local_player
	if lp != null and is_instance_valid(lp) and q != null and lp.revive_target == q:
		lp.revive_target = null
		lp.revive_t = 0.0


## REVIVER -> HOST: the 3 s channel completed.
func finish_revive(downed_pid: int) -> void:
	if game == null or not _net().is_online():
		return
	if multiplayer.is_server():
		_host_revive_done(downed_pid, 1)
	else:
		_rpc_revive_done.rpc_id(1, downed_pid)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_revive_done(downed_pid: int) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	_host_revive_done(downed_pid, pid)


## HOST: validate the completion against the claim, then owner-confirm
## the stand-up (§5.3: revived at 30% max HP, applied by the OWNER).
func _host_revive_done(downed_pid: int, reviver_pid: int) -> void:
	if int(_revive_claims.get(downed_pid, 0)) != reviver_pid:
		return  # lapsed/foreign claim — no revive
	var q: Player = _player_of(downed_pid)
	if q == null or not is_instance_valid(q) or not (q.downed or q.ghost):
		return
	_revive_claims.erase(downed_pid)
	_broadcast_revive_end(downed_pid)
	_stand_up_peer(downed_pid, q.REVIVE_HP_FRAC)


## HOST: stand a peer's player up at frac (channel revive, ghost clear).
func _stand_up_peer(pid: int, frac: float) -> void:
	if pid == 1 or pid == multiplayer.get_unique_id():
		if game.local_player != null and is_instance_valid(game.local_player):
			game.local_player.net_stand_up(frac)
	elif pid in _net().peers:
		_rpc_stand_up.rpc_id(pid, frac)


## HOST -> OWNER: stand up at frac of max HP (owner-applied, §5.3).
@rpc("authority", "call_remote", "reliable")
func _rpc_stand_up(frac: float) -> void:
	if game == null or multiplayer.is_server():
		return
	var p: Player = game.local_player
	if p != null and is_instance_valid(p) and (p.downed or p.ghost):
		p.net_stand_up(frac)


# ---- ghost revive + wipe (host truth) ----

## HOST, 0.5 s cadence (physics tick): ghosts auto-revive once NO active
## room is HOT — the same room-clear truth the door seals already track
## (_room_hot: live packs or a live boss). Also re-checks the wipe so a
## missed edge can never wedge a session.
func _host_down_sweep() -> void:
	if game == null or not bool(game.play_started):
		return
	# §5.3 (owner call 2026-07-10): a GHOST stands when THEIR OWN room clears —
	# not when the whole party's rooms are quiet. So a fighter who clears the
	# room an ally ghosted in brings them back, even while a boss still rages
	# next door. Downed players are NOT auto-stood here — the 30 s downed window
	# is the CHANNEL's job (a teammate holds INTERACT); ghost is the passive
	# room-clear recovery after it lapses.
	for p in game.players:
		if p == null or not is_instance_valid(p) or not p.ghost:
			continue
		var r: int = game.room_at_pos(p.global_position)
		if r >= 0 and not game._room_hot(r):
			_stand_up_peer(p.peer_id, p.REVIVE_HP_FRAC)
	_check_wipe()


## HOST: §5.3 wipe — nobody standing (downed/ghost/dead all count as
## down). Broadcast the host's room decision and run the shared death
## flow everywhere. A party of 1 online collapses to the solo flow: its
## only player downs, the census hits zero, the wipe fires immediately.
func _check_wipe() -> void:
	if game == null or not multiplayer.is_server() or not bool(game.play_started):
		return
	if game.state != game.ST_PLAYING:
		return
	var total := 0
	var standing := 0
	for p in game.players:
		if p == null or not is_instance_valid(p):
			continue
		total += 1
		if not p.dead and not p.downed and not p.ghost:
			standing += 1
	if total == 0:
		return
	if standing > 0:
		_wipe_fired = false  # someone is up — the latch re-arms
		return
	if _wipe_fired:
		return
	_wipe_fired = true
	var dr: int = _last_down_room if _last_down_room >= 0 else game.cur_room
	var rr: int = game.respawn_room(dr)
	_rpc_wipe.rpc(dr, rr)
	game.net_wipe(dr, rr)


## HOST -> GUESTS: the party fell — replay the solo death flow locally,
## respawning at the HOST's respawn-room decision (guests' cleared maps
## are mirrors, not truth).
@rpc("authority", "call_remote", "reliable")
func _rpc_wipe(death_room: int, safe_room: int) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.net_wipe(death_room, safe_room)


# ---- boss-kill full heal (MP-12 fold-in b) ----

## HOST: the boss-kill heal reaches every head (§5.5 vitals row). Downed/
## ghost owners skip it — the §5.3 paths own how a fallen body stands.
func host_full_heal() -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		_rpc_full_heal.rpc_id(int(pid))


@rpc("authority", "call_remote", "reliable")
func _rpc_full_heal() -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	var p: Player = game.local_player
	if p == null or not is_instance_valid(p) or p.dead or p.downed or p.ghost:
		return
	p.hp = p.max_hp
	p.mp = p.max_mp


# ---- guest death resync ----

## GUEST: the solo death flow (game_flow) resets rooms and frees homeless
## enemies AS IF this world were its own — which orphans mirrors. Watch
## for the respawn edge and ask the host for a fresh sweep; the spawn
## guard rebuilds exactly what was lost (survivors dupe-skip).
func _watch_guest_death() -> void:
	if multiplayer.is_server() or not world_ready:
		return
	if game.state == game.ST_DEAD:
		_guest_was_dead = true
	elif _guest_was_dead:
		_guest_was_dead = false
		_rpc_resync_enemies.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_resync_enemies() -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	host_sweep_unregistered()
	for id in net_enemies:
		var e: Enemy = net_enemies[id]
		if e != null and is_instance_valid(e) and not e.dying:
			_rpc_spawn_enemy.rpc_id(pid, _spawn_block(e))


# ------------------------------------------ dialogue & story sync (MP-13) ---
# §5.4. Dialogue is a LOCAL overlay — the world never pauses online
# (request_pause already no-ops in a session). This section adds the
# etiquette layer around it:
#   * WORLD FLAG SYNC — game_base.set_flag routes every world flag here, so
#     quest state, opened ways, one-time reveals, pay-once desks and once-
#     per-room marks stay consistent on every machine. Per-character flags
#     (game_flow._flag_is_local) stay local to their owner.
#   * BUSY-LOCK — the first interactor of an NPC wins a host-arbitrated
#     claim (the revive-claim idiom); a second gets a local "busy" bark and
#     no dialogue. Freed when the convo ends or the holder disconnects.
#   * TOASTS — a private-overlay choice that mutates shared state tells the
#     other players in one line (game_base._convo_node -> convo_toast).
#   * BEAT MIRRORING — quest-advancing convos gate on the party being
#     present and mirror their lines read-only to everyone; the initiator
#     drives the choices.
# Everything here no-ops offline — solo never routes a flag or claims an NPC.

# ---- world flag sync ----

## game_base.set_flag -> here for every WORLD flag. Any setter announces it;
## the HOST is the authority that fans it to all guests, so a flag set
## anywhere lands everywhere exactly once. The setter's own optimistic apply
## already ran (set_flag applies before routing); the host's fan re-confirms
## it, harmless under net_apply_flag's loop guard. A late joiner needs none
## of this — the flag is already in game.flags, which the join snapshot
## ships wholesale (_send_snapshot).
func route_flag(flag_name: String, value) -> void:
	if game == null or not _net().is_online():
		return
	if multiplayer.is_server():
		_rpc_set_flag.rpc(flag_name, value)          # host set it: fan out
	else:
		_rpc_flag_to_host.rpc_id(1, flag_name, value)  # guest set it: tell host


## GUEST -> HOST: a world flag a guest set. The host applies it (guarded) and
## fans it to every guest — the setter included, for confirmation.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_flag_to_host(flag_name: String, value) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	game.net_apply_flag(flag_name, value)
	_rpc_set_flag.rpc(flag_name, value)


## HOST -> GUESTS: apply a world flag (loop-guarded; gates and side quests
## react on each machine, so opened ways and reveals land everywhere).
@rpc("authority", "call_remote", "reliable")
func _rpc_set_flag(flag_name: String, value) -> void:
	if game == null or multiplayer.is_server():
		return
	game.net_apply_flag(flag_name, value)


# ---- busy-lock + beat orchestration ----

## game_base.run_convo_id -> here when online. Solo-in-session (the opening
## beats before any guest has spawned, or a lone party) collapses to a plain
## local overlay — the etiquette below only matters with company. Flag
## routing is independent (set_flag), so a lone host's story still syncs on
## the next join.
func begin_convo(id: String, convo: Dictionary, on_done: Callable) -> void:
	if game == null:
		return
	if game.players.size() <= 1:
		game.run_convo(convo, on_done)
		return
	var is_beat: bool = game._convo_is_beat(convo)
	var me := multiplayer.get_unique_id()
	# Busy already? The host reads its authoritative claim map for an instant
	# bark; guests learn on the host's deny.
	if multiplayer.is_server() and _convo_claims.has(id) \
			and int(_convo_claims[id]) != me:
		_busy_bark()
		return
	# Beats wait for the party to gather (initiator-local — every machine
	# sees every player's position through the movement sync).
	if is_beat and not _party_gathered():
		_beat_waiting_bark()
		return
	if multiplayer.is_server():
		_grant_convo(id, me, convo, on_done, is_beat)
	else:
		_pending_convo = {"id": id, "convo": convo, "on_done": on_done, "is_beat": is_beat}
		_rpc_convo_request.rpc_id(1, id, is_beat)


## GUEST -> HOST: claim an NPC's dialogue. First wins; a later hopeful is
## denied. Grant tells the spectators (a beat) and then the initiator.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_convo_request(id: String, is_beat: bool) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0 or not (pid in _net().peers):
		return
	if _convo_claims.has(id) and int(_convo_claims[id]) != pid:
		_rpc_convo_deny.rpc_id(pid, id)
		return
	_convo_claims[id] = pid
	if is_beat:
		_begin_beat_spectate(id, pid)
	_rpc_convo_grant.rpc_id(pid, id)


## HOST self-grant (the host is the initiator): no round trip.
func _grant_convo(id: String, pid: int, convo: Dictionary, on_done: Callable, is_beat: bool) -> void:
	_convo_claims[id] = pid
	if is_beat:
		_begin_beat_spectate(id, pid)
	_execute_convo(id, convo, on_done, is_beat)


## GUEST: the host granted our claim — run the convo locally now.
@rpc("authority", "call_remote", "reliable")
func _rpc_convo_grant(id: String) -> void:
	if game == null or String(_pending_convo.get("id", "")) != id:
		return
	var convo: Dictionary = _pending_convo.get("convo", {})
	var on_done: Callable = _pending_convo.get("on_done", Callable())
	var is_beat: bool = bool(_pending_convo.get("is_beat", false))
	_pending_convo = {}
	_execute_convo(id, convo, on_done, is_beat)


## GUEST: the NPC was already taken — a local busy bark, no dialogue.
@rpc("authority", "call_remote", "reliable")
func _rpc_convo_deny(id: String) -> void:
	if String(_pending_convo.get("id", "")) == id:
		_pending_convo = {}
	_busy_bark()


## Run the claimed convo on THIS machine (host self, or a granted guest). The
## bound end handler frees the claim and closes the mirror when it ends.
func _execute_convo(id: String, convo: Dictionary, on_done: Callable, is_beat: bool) -> void:
	_active_convo_id = id
	if is_beat:
		game.beat_broadcasting = true
	game.run_convo(convo, _on_convo_ended.bind(id, is_beat, on_done))


func _on_convo_ended(id: String, is_beat: bool, on_done: Callable) -> void:
	if is_beat and game != null:
		game.beat_broadcasting = false
		_rpc_beat_end.rpc()
		if game.hud != null:
			game.hud.mirror_end()  # no-op on the driver (never showed one)
		# In-session HUD consistency: the party's quest tracker follows the
		# beat's advance. Cosmetic — guests never persist world state (§5.7).
		_rpc_beat_quest.rpc(game.quest_key)
	_release_convo(id)
	if on_done.is_valid():
		on_done.call()


## Free a claim when its overlay closes (host erases; guest tells the host).
func _release_convo(id: String) -> void:
	if _active_convo_id == id:
		_active_convo_id = ""
	if game == null or not _net().is_online():
		return
	if multiplayer.is_server():
		_convo_claims.erase(id)
		_beat_claims.erase(id)  # Wave-1: normal beat end retires its beat mark
	else:
		_rpc_convo_release.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_convo_release(id: String) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid <= 0:
		return
	if int(_convo_claims.get(id, 0)) == pid:
		_convo_claims.erase(id)
		_beat_claims.erase(id)  # Wave-1: a guest-driven beat's normal end


# ---- beat mirroring ----

## Every living party member in the initiator's room, or within a generous
## radius of it — the gate a beat waits on (§5.4). Downed/ghost bodies count
## as present (they're in the fight, just can't act); only the dead don't gate.
func _party_gathered() -> bool:
	var me: Player = game.local_player
	if me == null or not is_instance_valid(me):
		return true
	var room: int = game.room_at_pos(me.global_position)
	for p in game.players:
		if p == null or not is_instance_valid(p) or p == me:
			continue
		if p.dead:
			continue
		if game.room_at_pos(p.global_position) == room:
			continue
		if p.global_position.distance_to(me.global_position) <= BEAT_GATHER_RADIUS:
			continue
		return false
	return true


## HOST: tell the spectators (everyone but the initiator) a beat began — their
## screens show the mirrored transcript. The host itself spectates when a
## GUEST drives (authority RPCs never echo to the host, so it calls locally).
func _begin_beat_spectate(id: String, initiator_pid: int) -> void:
	# Wave-1 co-op fix: remember this claim is a live beat so a mid-beat
	# disconnect of the initiator can close the spectators' stuck overlay.
	_beat_claims[id] = initiator_pid
	var nm := _initiator_name(initiator_pid)
	_rpc_beat_start.rpc(initiator_pid, nm)
	if initiator_pid != multiplayer.get_unique_id() and game.hud != null:
		game.hud.mirror_begin(nm)


func _initiator_name(pid: int) -> String:
	if pid == multiplayer.get_unique_id():
		return local_name()
	if lobby_chars.has(pid):
		return String(lobby_chars[pid].get("name", "A hero"))
	if peer_chars.has(pid):
		return String(peer_chars[pid].get("name", "A hero"))
	return "A hero"


## This machine's display name (what the party sees on toasts and beats).
func local_name() -> String:
	return String(local_char.get("name", os_name()))


@rpc("authority", "call_remote", "reliable")
func _rpc_beat_start(initiator_pid: int, nm: String) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	if initiator_pid == multiplayer.get_unique_id():
		return  # I'm the driver, not a spectator
	if game.hud != null:
		game.hud.mirror_begin(nm)


## INITIATOR -> spectators: the current dialogue line (+ any options, shown
## read-only). Called by hud while game.beat_broadcasting holds.
func beat_line(speaker: String, text: String, options: Array) -> void:
	if game == null or not _net().is_online():
		return
	_rpc_beat_line.rpc(speaker, text, options)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_beat_line(speaker: String, text: String, options: Array) -> void:
	# play_started (not world_ready): the initiator may be a guest, so the
	# HOST is a legitimate spectator too — and world_ready is never set on
	# the host. play_started is true once ANY machine's world is built, and
	# false for a still-in-lobby guest (which must ignore beat traffic).
	if game == null or not game.play_started:
		return
	if game.hud != null:
		game.hud.mirror_line(speaker, text, options)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_beat_end() -> void:
	if game != null and game.hud != null:
		game.hud.mirror_end()


## INITIATOR -> everyone: the beat advanced the quest tracker; the party's
## HUD follows (cosmetic in-session consistency — guests never persist it).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_beat_quest(qk: String) -> void:
	if game == null or not game.play_started:  # host is a recipient too
		return
	game.quest_key = qk
	game.refresh_quest()


# ---- barks + toast ----

func _busy_bark() -> void:
	if game != null and game.local_player != null and is_instance_valid(game.local_player):
		game.spawn_text(game.local_player.global_position + Vector2(0, -70),
			"Someone's already speaking with them", Color(0.85, 0.8, 0.7), 1.5)


func _beat_waiting_bark() -> void:
	if game != null and game.local_player != null and is_instance_valid(game.local_player):
		game.spawn_text(game.local_player.global_position + Vector2(0, -70),
			"Wait for the party to gather", Color(1.0, 0.85, 0.4), 1.5)


## A private-overlay choice touched shared state — one line to the others
## ("<name> accepted: <quest>" / "<name> chose: <label>"). call_remote, so the
## initiator (who made the choice) is not toasted.
func convo_toast(verb: String, label: String) -> void:
	if game == null or not _net().is_online():
		return
	var lab := label
	if lab.length() > 42:
		lab = lab.substr(0, 40).strip_edges() + "…"
	_rpc_convo_toast.rpc("%s %s: %s" % [local_name(), verb, lab])


@rpc("any_peer", "call_remote", "reliable")
func _rpc_convo_toast(text: String) -> void:
	if game == null or not game.play_started:  # host is a recipient too
		return
	if game.local_player != null and is_instance_valid(game.local_player):
		game.spawn_text(game.local_player.global_position + Vector2(0, -84),
			text, Color(0.7, 0.85, 1.0), 2.5)


# ------------------------------------------ party UI + victory/advance (MP-14) ---
# §5.6. Three additive layers over the existing HUD, all host-authoritative
# where the wire is involved and all no-ops offline:
#   * ally damage numbers — the host fans each hit's number to the party
#     members who didn't strike (own big / allies' small);
#   * synced victory — the host RPCs the final-boss victory so EVERY machine
#     shows the results card at once (each renders its OWN run from local
#     state; per-player credit — completed_/meta/weekly — is applied owner-side);
#   * chapter advance — the host's continue drives the party into the next
#     chapter through the SAME world-snapshot rebuild the join flow uses (the
#     live character stays; only the world rebuilds), or ends the session
#     gracefully (everyone autosaves) on an exit-to-title.

# ---- ally damage numbers (host authority, coalesced, unreliable) ----

## enemy.take_damage (host, non-silent hits) -> here. `striker` is the player
## whose blow this was (its host-side shell for a guest hit, the host's own
## player otherwise). Accumulate per enemy for this 20 Hz window; the flush
## fans one number to every party member OTHER than the striker.
func host_fan_damage(net_id: int, amount: int, crit: bool, striker) -> void:
	if net_id <= 0 or amount <= 0 or game == null or not _net().is_online() \
			or not multiplayer.is_server():
		return
	if multiplayer.get_peers().is_empty():
		return  # nobody to fan to — solo-online skips the bookkeeping entirely
	var pid := 1
	if striker != null and is_instance_valid(striker):
		pid = int(striker.peer_id)
	var cur: Dictionary = _dmg_fan.get(net_id, {"amt": 0, "crit": false, "attacker": pid})
	cur["amt"] = int(cur["amt"]) + amount
	cur["crit"] = bool(cur["crit"]) or crit
	cur["attacker"] = pid
	_dmg_fan[net_id] = cur


## HOST, 20 Hz: send each pending number to the party members who didn't land
## it (the striker already showed its own big one). Unreliable — a lost number
## is a non-event.
func _flush_dmg_fan() -> void:
	if _dmg_fan.is_empty():
		return
	for net_id in _dmg_fan:
		var d: Dictionary = _dmg_fan[net_id]
		var attacker: int = int(d["attacker"])
		for pid in _net().peers:
			if int(pid) == attacker:
				continue
			_rpc_ally_damage.rpc_id(int(pid), int(net_id), int(d["amt"]), bool(d["crit"]))
	_dmg_fan.clear()


## RECIPIENT: an ally's blow landed on this enemy — a small floating number
## over its mirror (own hits stay big; this reads as "someone else's damage").
@rpc("authority", "call_remote", "unreliable")
func _rpc_ally_damage(net_id: int, amount: int, crit: bool) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	last_ally_dmg = {"net_id": net_id, "amount": amount, "crit": crit}
	var e: Enemy = net_enemies.get(net_id)
	if e == null or not is_instance_valid(e) or e.dying:
		return
	game.spawn_ally_damage(e.global_position, amount, crit)


# ---- synced victory (the final boss falls — everyone sees the card) ----

## HOST: the chapter's final boss died — every guest shows the results card
## simultaneously (§5.4). vtext is the shared victory blurb; has_next drives
## the guest's meta unlock. Each guest renders its OWN run stats and applies
## its OWN chapter-completion credit / weekly reward (§5.7) in net_victory.
func host_victory(vtext: String, has_next: bool) -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	for pid in peer_chars:
		_rpc_victory.rpc_id(int(pid), vtext, has_next)


@rpc("authority", "call_remote", "reliable")
func _rpc_victory(vtext: String, has_next: bool) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.net_victory(vtext, has_next)


# ---- chapter advance (host's continue drives the party) ----

## HOST: after advance_chapter rebuilt the next chapter locally, brief every
## guest so it follows through the SAME switch_chapter rebuild the join flow
## uses — but the guest keeps its LIVE, progressed character (no save re-apply).
func host_advance_party() -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	var snap := {
		"chapter": game.chapter_id,
		"wander_seed": game.wander_seed,
		"weekly_active": game.weekly_active,
		"weekly_week": game.weekly_week,
	}
	for pid in peer_chars:
		_rpc_advance_world.rpc_id(int(pid), snap)


@rpc("authority", "call_remote", "reliable")
func _rpc_advance_world(snap: Dictionary) -> void:
	if game == null or multiplayer.is_server() or not world_ready:
		return
	game.net_advance(snap)


# ---- graceful session end (exit-to-title after victory) ----

## HOST: the host chose to leave the run (replay / title) rather than advance —
## tell every guest to autosave its character home and drop out cleanly, then
## the host itself leaves (game.gd / caller). No host-loss scramble (that is
## MP-16): this is a deliberate, announced end.
func host_end_session() -> void:
	if game == null or not _net().is_online() or not multiplayer.is_server():
		return
	_rpc_session_over.rpc()


@rpc("authority", "call_remote", "reliable")
func _rpc_session_over() -> void:
	if game == null or multiplayer.is_server():
		return
	game.net_session_over()
