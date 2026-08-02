class_name PvpDuel extends Node
## THE PROVING GROUNDS — the 1v1 duel controller (PvP v1, owner spec 2026-08-01).
##
## Rides the co-op transport unchanged: lobby code, host-authoritative session,
## owner-applied damage. The world is the 3-room pvp_arena chapter (content/
## pvp_arena.gd): west gatehouse (host), center arena, east gatehouse (guest),
## both center edges barred by the ordinary locked-edge gate bodies.
##
## Match flow — the HOST decides every transition, everyone renders:
##   warmup     both duelists sealed in their gatehouses, a big HUD countdown
##              (Balance.PVP_COUNTDOWN_FIRST round 1, _ROUND after) over a
##              freshly rerolled arena terrain. The host names the terrain id;
##              scenery/hazard patches are seeded by (zone, terrain) alone
##              (game_world), so both machines rebuild the arena identically.
##   fight      the host fans the gate-open. Player-vs-player damage flows
##              through each machine's invisible proxy Enemy (pvp_proxy.gd —
##              every existing targeting/melee/projectile path hits it
##              natively) into net_session.pvp_strike, landing as the
##              defender's own owner-side take_damage (their armor/evasion).
##   a fall     the owner's lethal branch (player.gd) reports it; the host
##              scores it and fans either the round reset (both heroes stand
##              fresh at their gates) or the match end at PVP_DEATHS_TO_LOSE.
##
## NO STAKES in v1 (owner call): no rewards, no gold tithe, no saves (autosave
## skips pvp worlds entirely), potions barred. Iron out the system first.
##
## Created/freed by game_flow.ensure_pvp_controller — switch_chapter raises it
## with the arena world on EVERY machine (host launch, guest brief/advance).

const ROOM_WEST := 0    # the host's gatehouse
const ROOM_ARENA := 1
const ROOM_EAST := 2    # the guest's gatehouse

var game: Game

var state := "idle"        # idle | warmup | fight | round_end | done
var match_started := false
var round_no := 0
var scores := {}           # peer id -> falls taken (PVP_DEATHS_TO_LOSE ends it)
var deadline_ms := 0       # warmup: when the gates open (local render clock)
var arena_terrain := ""    # current arena terrain id (rerolled every round)
var winner_pid := 0
var proxy: Node = null     # my invisible rival-shadow (pvp_proxy.gd)
var _walkover := false     # the rival's machine left mid-match
var _count_shown := -1     # last whole second rendered (countdown tick sfx edge)


## Fresh arena world (switch_chapter re-raise): a clean slate.
func arm() -> void:
	state = "idle"
	match_started = false
	round_no = 0
	scores = {}
	winner_pid = 0
	arena_terrain = ""
	_walkover = false
	_free_proxy()


## Per-frame from game._process (the endgame.tick slot). The host rings the
## bell when both duelists stand in the arena world, and owns the warmup ->
## fight transition; guests only render their local countdown.
func tick(_delta: float) -> void:
	if game == null or not game.pvp_active:
		return
	match state:
		"idle":
			if not match_started and game.net_online() and game.net_host() \
					and _foe_shell() != null:
				_start_match()
		"warmup":
			var left := maxf(0.0, float(deadline_ms - Time.get_ticks_msec()) / 1000.0)
			game.hud.pvp_countdown(left)
			var whole := int(ceil(left))
			if whole != _count_shown:
				_count_shown = whole
				if whole > 0 and whole <= 5:
					game.sfx("blink", 0.7)
			if left <= 0.0 and game.net_host():
				game.net_session().pvp_fan_fight()
		_:
			pass


## The strike gate every damage forward checks: only a live FIGHT lands blows —
## sealed-gate warmups, the kill beat and the end card are all cease-fires.
func combat_live() -> bool:
	return state == "fight"


# ------------------------------------------------------------ host truth ---

## HOST: both heroes are in — round 1, the long countdown.
func _start_match() -> void:
	match_started = true
	var foe: Player = _foe_shell()
	scores = {1: 0, foe.peer_id: 0}
	game.net_session().pvp_fan_round(1, _pick_terrain(),
		Balance.PVP_COUNTDOWN_FIRST, scores)


## HOST: an owner reported its hero's fall (player.gd lethal branch, routed
## through net_session.pvp_report_death). Score it; third fall ends the match,
## anything earlier savors the kill for a beat and then resets the round.
func host_report_death(victim_pid: int) -> void:
	if game == null or not game.net_host() or state != "fight":
		return
	scores[victim_pid] = int(scores.get(victim_pid, 0)) + 1
	var sess: Node = game.net_session()
	if int(scores[victim_pid]) >= Balance.PVP_DEATHS_TO_LOSE:
		sess.pvp_fan_end(_other_pid(victim_pid), scores)
		return
	sess.pvp_fan_kill(victim_pid, scores)
	var expect_round := round_no
	get_tree().create_timer(Balance.PVP_ROUND_END_BEAT).timeout.connect(func() -> void:
		if game != null and is_instance_valid(game) and game.pvp_active \
				and state == "round_end" and round_no == expect_round:
			game.net_session().pvp_fan_round(round_no + 1, _pick_terrain(),
				Balance.PVP_COUNTDOWN_ROUND, scores))


## HOST: a random arena terrain, never the one already painted.
func _pick_terrain() -> String:
	var pool: Array = Balance.PVP_TERRAINS
	var t: String = String(pool[randi() % pool.size()])
	if t == arena_terrain and pool.size() > 1:
		t = String(pool[(pool.find(t) + 1) % pool.size()])
	return t


## A duelist's machine left (quit, crash, kick) — a walkover for whoever is
## still here. Local-only: there is nobody left on the wire to tell.
func on_peer_left(_pid: int) -> void:
	if game == null or not game.pvp_active or state == "done":
		return
	_walkover = true
	_apply_end(_my_pid(), scores)


# ------------------------------------- fanned transitions (every machine) ---

## Round reset: both heroes stand fresh behind rebuilt gates, the arena wears
## a new terrain, the countdown arms. Fired by the host's round fan; the host
## runs its own copy inline (net_session.pvp_fan_round).
func _apply_round(rn: int, terrain: String, secs: float, sc: Dictionary) -> void:
	if game == null or not game.pvp_active:
		return
	match_started = true
	round_no = rn
	scores = sc.duplicate()
	state = "warmup"
	deadline_ms = Time.get_ticks_msec() + int(secs * 1000.0)
	_count_shown = -1
	# Leftover shots never cross a round boundary (the _death_begin rule).
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()
	# My hero: stand fresh in my gatehouse, kit reset — a round is a clean slate.
	var p: Player = game.local_player
	if p != null and is_instance_valid(p):
		p.revive()
		for k in p.cds:
			p.cds[k] = 0.0
		p.global_position = game.room_center(_my_room())
		game._enter_room(_my_room())
	# The rival's shell snaps home too (cosmetic — the move stream re-truths it,
	# the net_advance re-home precedent).
	var foe: Player = _foe_shell()
	if foe != null:
		foe.global_position = game.room_center(_foe_room())
		foe.dead = false
	_seal_gates()
	game.apply_terrain(ROOM_ARENA, terrain)
	arena_terrain = terrain
	_ensure_proxy()
	_update_score_hud()
	game.hud.flash_title("ROUND %d" % rn, _score_line(), 1.2, false)
	game.sfx("gate")


## The countdown ran out on the HOST's clock: gates open, blades out.
func _apply_fight() -> void:
	if game == null or not game.pvp_active or state != "warmup":
		return
	state = "fight"
	game.hud.pvp_countdown_hide()
	_open_gates()
	game.hud.flash_title("FIGHT!", "", 0.9, false)
	game.sfx("boss")
	game.shake(5.0)


## A fall that did NOT end the match: cease fire, savor the beat; the host's
## reset timer brings the next round.
func _apply_kill(victim_pid: int, sc: Dictionary) -> void:
	if game == null or not game.pvp_active:
		return
	state = "round_end"
	scores = sc.duplicate()
	_update_score_hud()
	if victim_pid == _my_pid():
		game.hud.flash_title("YOU FELL", _score_line(), 1.6, false)
		game.sfx("pdie")
	else:
		game.hud.flash_title("%s FALLS" % _foe_name().to_upper(), _score_line(), 1.6, false)
		game.sfx("victory", 0.6)


## Third fall (or a walkover): the match is over. Show the card, then walk
## both machines home to the title — nothing is banked either way (v1).
func _apply_end(w_pid: int, sc: Dictionary) -> void:
	if game == null or not game.pvp_active or state == "done":
		return
	state = "done"
	winner_pid = w_pid
	scores = sc.duplicate()
	_free_proxy()
	game.hud.pvp_countdown_hide()
	_update_score_hud()
	var won: bool = w_pid == _my_pid()
	var sub: String
	if _walkover:
		sub = "%s left the proving grounds — the match is yours." % _foe_name()
	elif won:
		sub = "%s fell %d times first. No spoils yet — the proving grounds pay nothing but pride." \
			% [_foe_name(), Balance.PVP_DEATHS_TO_LOSE]
	else:
		sub = "You fell %d times first. No tithe, no loss — sharpen up and call a rematch." \
			% Balance.PVP_DEATHS_TO_LOSE
	game.state = game.ST_VICTORY
	game.set_music("")
	game.sfx("victory" if won else "pdie")
	game.hud.show_end_screen("VICTORY" if won else "DEFEAT", sub,
		Color(1.0, 0.85, 0.4) if won else Color(1.0, 0.4, 0.35))
	# The guest lingers a beat longer so the host's session-over fan (character
	# home + clean leave) lands before its own reboot.
	var linger := Balance.PVP_END_LINGER + (0.0 if game.net_host() else 1.0)
	get_tree().create_timer(linger).timeout.connect(_finish_exit)


## After the card: the host ends the session for everyone, then each machine
## reboots to the title. Under the net-test harness the Game is a CHILD of the
## harness scene — reloading would restart the harness (the net_host_lost
## precedent), so the reload only runs when the Game IS the scene.
func _finish_exit() -> void:
	if game == null or not is_instance_valid(game) or not game.pvp_active:
		return
	var net: Node = get_node_or_null("/root/NetworkManager")
	if net != null and bool(net.is_online()):
		if game.net_host():
			game.net_session().host_end_session()
		net.leave()
	if get_tree().current_scene == game:
		game.exit_to_title()


# ------------------------------------------------------- gates + proxy ---

## Rebuild both gate bodies (round reset). The pvp_gates flag is cleared so
## _edge_unlocked reads the bar as real again; open_edge freed the old nodes.
func _seal_gates() -> void:
	game.flags.erase("pvp_gates")
	for spec in [[ROOM_WEST, "E"], [ROOM_EAST, "W"]]:
		var room: int = spec[0]
		var dir: String = spec[1]
		var nb: int = game.neighbor(room, dir)
		if nb < 0:
			continue
		var key: String = game._edge_key(room, nb)
		if not game.gates.has(key):
			game.gates[key] = game._build_gate(room, dir)


## Drop both gates (fight signal). The flag keeps any later room rebuild from
## re-barring an open round.
func _open_gates() -> void:
	game.flags["pvp_gates"] = true
	game.open_edge(ROOM_WEST, ROOM_ARENA)
	game.open_edge(ROOM_ARENA, ROOM_EAST)


## My machine's invisible rival-shadow: the Enemy every existing combat path
## can see. One per machine, per match; rounds reuse it.
func _ensure_proxy() -> void:
	var foe: Player = _foe_shell()
	if foe == null:
		return
	if proxy != null and is_instance_valid(proxy):
		proxy.foe = foe
		return
	var pr = preload("res://scripts/pvp_proxy.gd").new()
	pr.setup_proxy(game, foe)
	game.world.add_child(pr)
	proxy = pr


func _free_proxy() -> void:
	if proxy != null and is_instance_valid(proxy):
		proxy.queue_free()
	proxy = null


# ---------------------------------------------------------------- lookups ---

func _my_pid() -> int:
	return multiplayer.get_unique_id()


func _my_room() -> int:
	return ROOM_WEST if multiplayer.is_server() else ROOM_EAST


func _foe_room() -> int:
	return ROOM_EAST if multiplayer.is_server() else ROOM_WEST


## The rival's shell: the one registered player that is not my own hero.
func _foe_shell() -> Player:
	for q in game.players:
		if q != null and is_instance_valid(q) and q != game.local_player:
			return q
	return null


func _foe_pid() -> int:
	var foe: Player = _foe_shell()
	if foe != null:
		return foe.peer_id
	for pid in scores:   # shell already gone (walkover end card)
		if int(pid) != _my_pid():
			return int(pid)
	return 0


func _other_pid(pid: int) -> int:
	for k in scores:
		if int(k) != pid:
			return int(k)
	return 1


func _foe_name() -> String:
	var foe: Player = _foe_shell()
	if foe != null:
		var nm := String(foe.get_meta("net_name", ""))
		if nm != "":
			return nm
	return "your rival"


func _score_line() -> String:
	if scores.is_empty():
		return ""
	return "falls — you %d : %d %s  (first to %d loses)" % [
		int(scores.get(_my_pid(), 0)), int(scores.get(_foe_pid(), 0)),
		_foe_name(), Balance.PVP_DEATHS_TO_LOSE]


func _update_score_hud() -> void:
	game.hud.pvp_score(_score_line() if match_started and state != "done" else "")
