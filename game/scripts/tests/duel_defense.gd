extends RefCounted
## Quick duel tier: private ENet branches, disposable actors, real hit/receive
## math. No campaign state is borrowed; the caller always frees both branches.

class WireRoot extends Node:
	var peers: Array[int] = []
	func is_online() -> bool: return true

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class QuietHud extends Hud:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func flash_screen(_color: Color, _strength := 0.4, _dur := 0.3) -> void: pass

class ProbeGame extends Game:
	var session: Node
	var numbers: Array = []
	var texts: Array[String] = []
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func net_session() -> Node: return session
	func sfx(_name: String, _pitch := 1.0, _cutoff := 0.0, _vol_db := 0.0) -> void: pass
	func shake(_amount: float, _dir := Vector2.ZERO, _kick := 0.0) -> void: pass
	func spawn_damage_number(_target: Node2D, amount: int, crit := false, _dot := false, _ally := false) -> void:
		numbers.append([amount, crit])
	func spawn_text(_pos: Vector2, text: String, _color: Color, _hold := 0.0) -> void:
		texts.append(text)
	func fight_note_damage(_amount: float, _attacker: Node) -> void: pass
	func stat_taken(_p: Player, _amount: float) -> void: pass

class ProbePlayer extends Player:
	var received := 0
	var receive_seed := 0
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func take_damage(amount: float, kind := "phys", attacker: Node = null,
			heavy := false, pen := 0.0, dexterity := 0.0, true_amount := 0.0) -> void:
		# Async ENet delivery must not depend on unrelated frame RNG consumers.
		seed(receive_seed)
		super.take_damage(amount, kind, attacker, heavy, pen, dexterity, true_amount)
		received += 1


static func suite(g: Game) -> String:
	var roots: Array[Node] = [WireRoot.new(), WireRoot.new()]
	var apis: Array[MultiplayerAPI] = []
	var sessions: Array[Node] = []
	var games: Array[ProbeGame] = []
	for i in range(2):
		var root := roots[i]
		root.name = "DuelDefenseHost" if i == 0 else "DuelDefenseGuest"
		g.add_child(root)
		var api := MultiplayerAPI.create_default_interface()
		g.get_tree().set_multiplayer(api, root.get_path())
		apis.append(api)
		var session := WireSession.new()
		session.name = "Session"
		root.add_child(session)
		sessions.append(session)
		var world := ProbeGame.new()
		world.session = session
		world.pvp_active = true
		world.pvp = PvpDuel.new()
		world.pvp.state = "fight"
		world.hud = QuietHud.new()
		world.add_child(world.hud)
		root.add_child(world)
		games.append(world)
		session.game = world
		for j in range(2):
			var p := ProbePlayer.new()
			p.game = world
			p.cls = "mage"
			p.atk = 100.0
			p.max_hp = 10000.0
			p.hp = p.max_hp
			p.crit_dmg = 2.0
			world.add_child(p)
			world.players.append(p)
		world.local_player = world.players[i]
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var error := ""
	if server.create_server(0, 2) != OK:
		error = "ENet bind failed"
	else:
		apis[0].multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "ENet connect failed"
		else:
			apis[1].multiplayer_peer = client
	if error == "":
		var deadline := Time.get_ticks_msec() + 3000
		while apis[0].get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await g.get_tree().create_timer(0.01).timeout
		if apis[0].get_peers().is_empty():
			error = "ENet handshake timed out"
		else:
			var guest_id := apis[1].get_unique_id()
			roots[0].peers.append(guest_id)
			roots[1].peers.append(1)
			for world in games:
				world.players[0].peer_id = 1
				world.players[1].peer_id = guest_id
			error = await _checks(g, games, sessions)
	for i in range(2):
		games[i].pvp.free()
		apis[i].multiplayer_peer = null
	client.close()
	server.close()
	for root in roots:
		g.get_tree().set_multiplayer(null, root.get_path())
		root.free()
	# Global RNG has no snapshot API; leave subsequent sections unseeded.
	randomize()
	if error == "":
		print("ok: duel defense ENet (both directions, current CritRes, join-block CritRes, seeded crits, guaranteed crits, mixed true damage, damage-taken amps, true cap, one hit/number, no DODGE! on landed true damage, shields, legacy defaults, host gate)")
	return error


static func _checks(g: Game, games: Array[ProbeGame], sessions: Array[Node]) -> String:
	for side in range(2):
		var offense := games[side]
		var defense := games[1 - side]
		var p: ProbePlayer = offense.local_player
		var q: ProbePlayer = offense.players[1 - side]
		var victim: ProbePlayer = defense.local_player
		var sender: Node = sessions[side]
		var owner: Node = sessions[1 - side]
		# Same HP/MP for both broadcasts: CritRes alone must refresh the shell.
		var counts: Array[int] = []
		for cr in [0.0, 1000.0]:
			victim.critres = cr
			victim.hp = victim.max_hp
			q.critres = -1.0
			owner._tick_vitals(1.0, victim)
			var deadline := Time.get_ticks_msec() + 3000
			while q.critres != cr and Time.get_ticks_msec() < deadline:
				await g.get_tree().create_timer(0.01).timeout
			if q.critres != cr: return "CritRes-only sync failed, side %d" % side
			var crits := 0
			p.crit = 0.6
			for n in range(32):
				seed(n)
				var expected := randf() < Stats.effective_crit(p.crit, 0.1, cr)
				var error := await _hit(g, offense, defense, p, q, {"crit_bonus": 0.1}, n,
					100.0 * (p.crit_dmg if expected else 1.0) * Balance.PVP_DMG_MULT)
				if error != "": return "ordinary crit side %d, seed %d: %s" % [side, n, error]
				if bool(offense.numbers[0][1]) != expected: return "CritRes roll disagrees with effective_crit"
				crits += int(expected)
			counts.append(crits)
		if counts[0] <= counts[1]:
			return "seed fixture must cover resisted ordinary crits"
		# Vitals resend only changes, so the join block seeds a new shell's CritRes.
		var block: Dictionary = owner._char_block()
		if float(block.get("critres", -1.0)) != victim.critres:
			return "join block lacks the owner's CritRes, side %d" % side
		# Guaranteed crits hold against the high CritRes still on the shell.
		p.crit = 0.0
		for guaranteed in ["force_crit", "next_crit", "marked_crit"]:
			p.next_crit = guaranteed == "next_crit"
			q.vuln_time = 1.0 if guaranteed == "marked_crit" else 0.0
			q.vuln_mult = 1.0
			var effect := {guaranteed: 1}
			var error := await _hit(g, offense, defense, p, q, effect, 7,
				100.0 * p.crit_dmg * Balance.PVP_DMG_MULT)
			if error != "": return guaranteed + ": " + error
			if not bool(offense.numbers[0][1]) or p.next_crit: return "guaranteed crit lost or not consumed"
		q.vuln_time = 0.0
		# An old owner's 3-arg vitals packet leaves the shell at the default 0.
		owner._rpc_vitals.rpc(victim.hp, victim.max_hp, victim.mp)
		var legacy_deadline := Time.get_ticks_msec() + 3000
		while q.critres != 0.0 and Time.get_ticks_msec() < legacy_deadline:
			await g.get_tree().create_timer(0.01).timeout
		if q.critres != 0.0: return "legacy vitals default failed, side %d" % side
		# Every data-driven true_frac ability uses this shared funnel (currently
		# Meteor, including its second mage strike path); no named-ability gate.
		for cls in Classes.CLASSES:
			for slot in Classes.CLASSES[cls]["abilities"]:
				var fraction: float = Classes.CLASSES[cls]["abilities"][slot].get("dmg", {}).get("true_frac", 0.0)
				if fraction <= 0.0: continue
				for mode in ["resist", "dodge", "graze", "floor", "shield", "forced", "ward", "amp"]:
					victim.magres = 1000000.0
					victim.eva = 100.0 if mode in ["dodge", "graze", "floor", "shield"] else 0.0
					victim.dr_time = 1.0 if mode == "ward" else 0.0
					victim.dr_amt = 0.5
					# Damage-taken amps (Depths debuff, laced sting) scale both parts.
					victim.debuff_dmg_in = 1.5 if mode == "amp" else 1.0
					victim.laced_dmg_in_time = 1.0 if mode == "amp" else 0.0
					victim.laced_dmg_in_amt = 0.2 if mode == "amp" else 0.0
					var amp: float = victim.debuff_dmg_in * (1.0 + victim.laced_dmg_in_amt)
					p.dex = 0.0
					var through := 1.0
					if victim.eva > 0.0:
						# Pin a successful evade, regardless of engine seed mapping.
						for candidate in range(100):
							seed(candidate)
							if randf() < Stats.eva_curve(victim.eva):
								victim.receive_seed = candidate
								break
						through = 0.0
						if mode in ["graze", "floor"]:
							var ratio: float = Balance.DEX_GRAZE_RATIO if mode == "floor" else (1.0 + Balance.DEX_GRAZE_RATIO) / 2.0
							p.dex = Stats.eva_curve(victim.eva) * ratio / Balance.DEX_PER_EVA
							through = Stats.graze_through(p.dex, victim.eva)
							if through < Balance.GRAZE_MIN_THROUGH: through = 0.0
					var true_damage := 100.0 * fraction * Balance.PVP_DMG_MULT
					victim.shield = true_damage / 2.0 if mode == "shield" else 0.0
					var expected := amp * (true_damage + 100.0 * (1.0 - fraction) * Balance.PVP_DMG_MULT \
						* (p.crit_dmg if mode == "forced" else 1.0) \
						* (1.0 - Stats.res_frac(victim.magres)) * through \
						* (1.0 - victim.dr_amt if mode == "ward" else 1.0)) - victim.shield
					var error := await _hit(g, offense, defense, p, q,
						{"type": "magic", "true_frac": fraction, "force_crit": int(mode == "forced")}, 7, expected)
					if error != "": return "%s/%s %s: %s" % [cls, slot, mode, error]
					# A blow that lands true damage is a hit, never a DODGE! callout.
					if defense.texts.has("DODGE!"):
						return "%s/%s %s: a hit that landed true damage read DODGE!" % [cls, slot, mode]
		victim.eva = 0.0
		victim.shield = 0.0
		victim.dr_time = 0.0
		victim.debuff_dmg_in = 1.0
		victim.laced_dmg_in_time = 0.0
		victim.laced_dmg_in_amt = 0.0
		# A forged true subset larger than its hit is capped to the hit's total.
		# Max magres makes any uncapped (negative typed) remainder show as damage.
		victim.hurt_cd = 0.0
		victim.hp = victim.max_hp
		var capped := victim.received
		sender.pvp_strike(victim.peer_id, 10.0, "magic", 0.0, 0.0, 50.0)
		var cap_error := await _wait_hit(g, victim, capped)
		if cap_error != "" or not is_equal_approx(victim.max_hp - victim.hp, 10.0):
			return "oversized true subset was not capped, side %d" % side
		victim.magres = 0.0
		# Old call shapes retain their defaults on both receiving RPCs.
		victim.hurt_cd = 0.0
		var before := victim.hp
		var received := victim.received
		if side == 0:
			sender._rpc_player_hit.rpc_id(victim.peer_id, 10.0, "magic", 0, false)
		else:
			sender._rpc_pvp_strike.rpc_id(1, 1, 10.0, "magic")
		var error := await _wait_hit(g, victim, received)
		if error != "" or not is_equal_approx(before - victim.hp, 10.0): return "legacy strike defaults failed"
		# Only the host's round clock decides whether a strike is accepted.
		games[0].pvp.state = "countdown"
		received = victim.received
		sender.pvp_strike(victim.peer_id, 100.0, "magic", 0.0, 0.0, 25.0)
		if side == 1:
			# The guest's strike crosses the wire first. Reliable RPCs share one
			# ordered channel, so once this later vitals packet lands on the host,
			# the host has already judged the strike ahead of it.
			var shell: Player = defense.players[side]
			var mark := maxf(shell.critres, p.critres) + 1.0
			p.critres = mark
			sender._tick_vitals(1.0, p)
			var barrier := Time.get_ticks_msec() + 3000
			while shell.critres != mark and Time.get_ticks_msec() < barrier:
				await g.get_tree().create_timer(0.01).timeout
			if shell.critres != mark:
				games[0].pvp.state = "fight"
				return "host gate ordering barrier timed out"
		games[0].pvp.state = "fight"
		if victim.received != received: return "host accepted a strike outside the fight"
		# Positive sentinel on the same ordered road: exactly this 10-damage
		# strike lands. A gated strike that slipped through would arrive first.
		victim.hurt_cd = 0.0
		before = victim.hp
		sender.pvp_strike(victim.peer_id, 10.0, "magic")
		error = await _wait_hit(g, victim, received)
		if error != "" or victim.received != received + 1 or not is_equal_approx(before - victim.hp, 10.0):
			return "host gate: gated strike landed or the reopened fight dropped the sentinel, side %d" % side
	return ""


static func _hit(g: Game, offense: ProbeGame, defense: ProbeGame, p: ProbePlayer,
		q: ProbePlayer, effects: Dictionary, roll_seed: int, expected: float) -> String:
	var victim: ProbePlayer = defense.local_player
	victim.hp = victim.max_hp
	victim.hurt_cd = 0.0
	victim.damage_memory.clear_recent()
	defense.texts.clear()
	offense.numbers.clear()
	var received := victim.received
	seed(roll_seed)
	p.hit_enemy(q, 1.0, effects)
	var error := await _wait_hit(g, victim, received)
	if error != "": return error
	if not is_equal_approx(victim.max_hp - victim.hp, expected):
		return "damage %.6f, expected %.6f" % [victim.max_hp - victim.hp, expected]
	var floats := 0
	for text in defense.texts:
		if text.begins_with("-"): floats += 1
	if victim.received != received + 1 or victim.damage_memory.hits.size() != 1 \
			or offense.numbers.size() != 1 or floats != 1 or victim.hurt_cd <= 0.0:
		return "strike did not produce exactly one hit event/number and hurt window"
	return ""


static func _wait_hit(g: Game, victim: ProbePlayer, before: int) -> String:
	var deadline := Time.get_ticks_msec() + 3000
	while victim.received == before and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.01).timeout
	return "strike delivery timed out" if victim.received == before else ""
