extends RefCounted
const Cast := preload("res://scripts/boss_cast.gd")


static func run(t: Node) -> String:
	var error := _clock_contracts()
	if error == "":
		error = _damage_contracts(t.game)
	if error == "":
		print("ok: signature cast deadline, pressure, party scaling, damage attribution, expose and mirror authority")
	return error


static func _clock_contracts() -> String:
	for kind: String in Cast.MOVES:
		for party in range(1, 5):
			var c := Cast.new()
			var hp: float = 10000.0 * Balance.party_hp(party)
			if not c.start(kind, hp) or c.start(kind, hp):
				return "cast start accepted an overlapping commitment"
			if not is_equal_approx(c.goal, hp * Balance.BOSS_BREAK_HP_FRACTION):
				return "party-scaled HP did not scale shared pressure"
			var before: float = c.remaining
			for invalid in [NAN, INF, -1.0, 0.0]:
				c.step(invalid)
				c.hit(invalid, true, false)
			if c.remaining != before or c.pressure != 0.0:
				return "invalid clock/damage changed a cast"
			c.hit(c.goal * 0.5, false, false)
			var mirror := Cast.new()
			if not mirror.apply_snapshot(c.snapshot()) or mirror.pressure != c.pressure:
				return "late-join snapshot lost cast progress"
			if mirror.step(100.0, false) != "" or mirror.phase != "windup":
				return "a mirror resolved an attack without authority"
			if c.step(before) != "release" or c.step(1.0) != "":
				return "cast failed to release exactly once at its deadline"
			c.start(kind, hp)
			c.hit(c.goal * 0.4, true, false)
			if not is_equal_approx(c.pressure / c.goal, 0.6):
				return "close pressure does not reward the approach"
			if not c.hit(c.goal * 0.4, false, false) or c.phase != "broken":
				return "damage at the threshold did not break the cast"
			if c.hit(100.0, true, false) or c.step(Balance.BOSS_BREAK_RECOVERY) == "release":
				return "a broken cast released or paid twice"
			if c.recovery != 0.0 or c.damage_multiplier() != Balance.BOSS_BREAK_DAMAGE_MULT:
				return "recovery and damage window were conflated"
			c.step(Balance.BOSS_BREAK_EXPOSED)
			if c.phase != "" or c.damage_multiplier() != 1.0:
				return "exposure did not expire"
			c.start(kind, hp)
			c.hit(c.goal, true, true)
			if not is_equal_approx(c.pressure / c.goal, Balance.BOSS_BREAK_DOT_WEIGHT):
				return "periodic damage gained the close-range bonus"
			var bad: Dictionary = c.snapshot()
			bad["remaining"] = NAN
			if mirror.apply_snapshot(bad):
				return "mirror accepted a non-finite cast clock"
			c.cancel()
			c.start(kind, 14691.7321 * Balance.party_hp(party))
			# HP subtraction / network floats may differ by a few ulps.
			if not c.hit(c.goal * (1.0 - 1e-9), false, false):
				return "floating-point roundoff lost a threshold-sized hit"
			c.cancel()
			if c.step(100.0) != "" or c.hit(1e8, false, false):
				return "canceled cast resurrected"
	return ""


static func _damage_contracts(g: Game) -> String:
	var p: Player = g.local_player
	var stats: Dictionary = g.party_stats.duplicate(true)
	var fight: Dictionary = g.fight_stats.duplicate(true)
	var b := Boss.make_boss(g, "morwen", p.global_position + Vector2(300, 0))
	g.world.add_child(b)
	b.set_physics_process(false)
	b.max_hp = 100000.0
	b.hp = b.max_hp
	var error := _damage_checks(g, p, b)
	b._cancel_signature()
	b.queue_free()
	g.party_stats = stats
	g.fight_stats = fight
	return error


static func _damage_checks(g: Game, p: Player, b: Boss) -> String:
	if not b._begin_signature():
		return "a live boss with live prey could not begin a cast"
	b.take_damage(100.0, Vector2.ZERO, false, true)
	if b.cast_window.pressure != 0.0:
		return "unsourced environmental damage built player pressure"
	b.plate_dr = 0.8
	b.hit_src = p
	b.take_damage(100.0, Vector2.ZERO, false, true)
	if not is_equal_approx(b.cast_window.pressure, 8.0):
		return "pressure counted raw damage instead of actual health loss"
	b.plate_dr = 0.0
	b.cast_window.pressure = 0.0
	b.hit_src = p
	b.take_damage(b.cast_window.goal, Vector2.ZERO, false, false)
	if b.cast_window.phase != "broken":
		return "an authoritative player hit failed to interrupt"
	var health := b.hp
	b.take_damage(100.0, Vector2.ZERO, false, true)
	if not is_equal_approx(health - b.hp, 100.0 * Balance.BOSS_BREAK_DAMAGE_MULT):
		return "broken boss did not take the advertised extra damage"
	# The new exposure is independent: it must not erase Death Mark.
	b.apply_vuln(5.0, 1.5)
	b.cast_window.step(Balance.BOSS_BREAK_EXPOSED)
	if b.vuln_time != 5.0 or b.vuln_mult != 1.5:
		return "cast exposure overwrote an existing class debuff"
	b.reset_fight()
	if b.cast_window.phase != "" or b._fight_serial != 1:
		return "fight reset kept an old cast or sequence alive"
	if not b._begin_signature():
		return "cast did not rearm after a fight reset"
	var data: Dictionary = b.cast_window.snapshot()
	b.net_mirror = true
	b.cast_window.cancel()
	b.net_apply_cast(data)
	if b._begin_signature() or b.cast_window.phase != "windup":
		return "mirror authored a cast or failed to accept host state"
	b.hit_src = p
	b.take_damage(1000.0, Vector2.ZERO, false, true)
	if b.cast_window.pressure != 0.0:
		return "optimistic guest damage interrupted the host's cast locally"
	var session := preload("res://scripts/net/net_session.gd").new()
	session.game = g
	var block: Dictionary = session._spawn_block(b)
	session.free()
	if block.get("cast", {}) != data:
		return "enemy join snapshot omitted an active cast"
	b.net_mirror = false
	return ""
