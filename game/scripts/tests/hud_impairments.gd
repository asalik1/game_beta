extends RefCounted
## Quick systems tier: real applications and physics clocks, then the actual
## pooled HUD controls. All borrowed state is restored on failure as well.
const EFFECTS := {"frozen": "frozen_time", "rooted": "rooted_time", "chilled": "chill_time"}
const REASONS := {"asleep": "frozen_time", "staggered": "rooted_time", "stunned": "frozen_time"}
const BUFFS := ["berserk_time", "aegis_time", "dr_time", "pact_time",
	"theme_guard_time", "theme_speed_time", "elixir_time", "goldrush_time", "dodge_time"]
## Chips that hold their slot at the head of the row (Hud._active_buffs).
const PERSISTENT := ["ng_tier", "holy", "retri", "grit", "second_wind"]


class WireRoot extends Node:
	var peers: Array[int] = []
	func is_online() -> bool: return true

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class HostGame extends Game:
	var bridge: Node
	func net_host() -> bool: return true
	func net_session() -> Node: return bridge

class HostShell extends Player:
	func is_locally_controlled() -> bool: return false


static func suite(g: Game) -> String:
	var p: Player = g.local_player
	var saved := {}
	var fields: Array = EFFECTS.values() + BUFFS + ["chill_mult", "uniq_cc_mult", "uniq_armor", "dead",
		"grit_stacks", "grit_time", "freeze_reason", "root_reason"]
	for field in fields:
		saved[field] = p.get(field)
	var paused: bool = g.get_tree().paused
	var peaks: Dictionary = g.hud._buff_peak.duplicate(true)
	p.dead = false
	p.uniq_armor = []
	p.uniq_cc_mult = 0.5
	for field in EFFECTS.values():
		p.set(field, 0.0)
	p.chill_mult = 1.0
	# Nine ordinary buffs alone exceed the eight-slot row. No inherited buff
	# state or previous section's equipment can satisfy the overflow control.
	for field in BUFFS:
		p.set(field, 10.0)
	# One persistent chip on any class: impairments must queue behind it.
	p.grit_stacks = 1
	p.grit_time = 10.0
	g.get_tree().paused = false
	var error: String = await _checks(g, p)
	if error == "":
		error = await _reason_checks(g, p)
	if error == "":
		error = await _stun_checks(g, p)
	if error == "":
		error = await _forwarded_reasons(g, p)
	for field in fields:
		p.set(field, saved[field])
	g.get_tree().paused = paused
	g.hud._update_buffs()
	g.hud._buff_peak = peaks
	if error == "":
		print("ok: HUD impairments (real freeze/root/chill, reduced durations, countdown, refresh, expiry, full-row priority behind persistent chips, own art, casting detail)")
	return error


static func _checks(g: Game, p: Player) -> String:
	var h: Hud = g.hud
	for id in EFFECTS:
		if not _entry(h, id).is_empty():
			return "inactive impairment already has a chip: " + id
		# The chip has no name label, so its art alone must set it apart.
		for other in Hud.BUFF_ICONS:
			if other != id and Hud.BUFF_ICONS[other] == Hud.BUFF_ICONS[id]:
				return "impairment chip %s shares its icon with %s" % [id, other]
	p.apply_freeze(1.6)
	p.apply_root(2.0)
	p.apply_chill(0.6, 2.4)
	var expected := {"frozen": 0.8, "rooted": 1.0, "chilled": 1.2}
	if h._active_buffs().size() <= h.buff_slots.size():
		return "impairment overflow fixture did not fill the row"
	for id in EFFECTS:
		var error := _chip_error(h, p, id)
		if error != "":
			return error
		if not is_equal_approx(float(_entry(h, id).t), float(expected[id])):
			return "impairment chip ignored the actual reduced duration: " + id
	if "can still cast" not in String(_entry(h, "rooted").tip):
		return "Rooted chip does not explain casting is allowed"
	if "40%" not in String(_entry(h, "chilled").tip):
		return "Chilled chip does not show the actual slow amount"
	await g.get_tree().create_timer(0.25).timeout
	for id in EFFECTS:
		var error := _chip_error(h, p, id)
		if error != "":
			return error
		if float(_entry(h, id).t) >= float(expected[id]):
			return "impairment countdown did not advance: " + id
	# Refresh through the same gameplay entry points, including a stronger aura.
	p.apply_freeze(2.0)
	p.apply_root(2.4)
	p.apply_chill(0.4, 2.8)
	expected = {"frozen": 1.0, "rooted": 1.2, "chilled": 1.4}
	for id in EFFECTS:
		if not is_equal_approx(float(_entry(h, id).t), float(expected[id])):
			return "impairment chip did not refresh: " + id
	if "60%" not in String(_entry(h, "chilled").tip):
		return "Chilled detail retained the old slow amount"
	var expired := {}
	var deadline := Time.get_ticks_msec() + 4000
	while expired.size() < EFFECTS.size() and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.05).timeout
		h._update_buffs()
		for id in EFFECTS:
			if float(p.get(EFFECTS[id])) > 0.0:
				var error := _chip_error(h, p, id)
				if error != "":
					return error
				continue
			expired[id] = true
			if not _entry(h, id).is_empty() or h._buff_peak.has(id):
				return "expired impairment retained its chip or drain state: " + id
			for slot in h.buff_slots:
				if slot.border.visible and String(slot.border.get_meta("tip_raw", "")).begins_with(String(id).capitalize() + ":"):
					return "expired impairment is still painted: " + id
	if expired.size() != EFFECTS.size():
		return "impairment physics timers did not expire"
	return ""


static func _entry(h: Hud, id: String) -> Dictionary:
	for entry in h._active_buffs():
		if entry.id == id:
			return entry
	return {}


static func _chip_error(h: Hud, p: Player, id: String) -> String:
	h._update_buffs()
	var active: Array = h._active_buffs()
	var entry := _entry(h, id)
	if entry.is_empty():
		return "active impairment missing from HUD: " + id
	var index: int = active.find(entry)
	if index < 0 or index >= h.buff_slots.size():
		return "ordinary buffs crowded impairment out of the row: " + id
	if _entry(h, "grit").is_empty():
		return "persistent-chip fixture is missing from the row"
	for i in active.size():
		var other: String = String(active[i].id)
		if i < index and other not in PERSISTENT and not EFFECTS.has(other) and not REASONS.has(other):
			return "ordinary buff %s sits ahead of impairment %s" % [other, id]
		if i > index and other in PERSISTENT:
			return "impairment %s pushed persistent chip %s down the row" % [id, other]
	if not is_equal_approx(float(entry.t), float(p.get(EFFECTS.get(id, REASONS.get(id))))) or float(entry.t) <= 0.0:
		return "impairment chip has the wrong remaining time: " + id
	var slot: Dictionary = h.buff_slots[index]
	if not slot.border.visible or not slot.icon.visible or slot.icon.texture == null \
			or String(slot.border.get_meta("tip_raw", "")) != String(entry.tip):
		return "impairment chip is not painted with its icon and detail: " + id
	# The chip draws at BUFF_ICON px: smaller art is upscaled soft, and an
	# ability button's art would read as that ability right above its button.
	if String(Hud.BUFF_ICONS.get(id, "")).begins_with("ability_") \
			or slot.icon.texture.get_width() < int(Hud.BUFF_ICON):
		return "impairment chip art is an ability button or smaller than the chip: " + id
	var time_text: String = "%.0f" % ceil(float(entry.t)) if float(entry.t) >= 1.0 else "%.1f" % float(entry.t)
	if not slot.time.visible or slot.time.text != time_text or slot.fill.size.x <= 0.0:
		return "impairment chip countdown or drain is missing: " + id
	return ""


static func _reason_checks(g: Game, p: Player) -> String:
	var h: Hud = g.hud
	p.frozen_time = 0.0
	p.rooted_time = 0.0
	p.apply_freeze(1.6, "asleep")
	p.apply_root(2.0, "staggered")
	for id in ["asleep", "staggered"]:
		var error := _chip_error(h, p, id)
		if error != "": return error
		for other in Hud.BUFF_ICONS:
			if other != id and Hud.BUFF_ICONS[other] == Hud.BUFF_ICONS[id]:
				return "named impairment shares its icon: " + id
	if not _entry(h, "frozen").is_empty() or not _entry(h, "rooted").is_empty():
		return "sleep or stagger still shows the generic chip"
	if not String(_entry(h, "asleep").tip).begins_with("Asleep:") or "can't move or cast" not in String(_entry(h, "asleep").tip):
		return "sleep detail has the wrong name or restrictions"
	if not String(_entry(h, "staggered").tip).begins_with("Staggered:") or "can still cast" not in String(_entry(h, "staggered").tip):
		return "stagger detail has the wrong name or restrictions"
	if not is_equal_approx(float(_entry(h, "asleep").t), 0.8) or not is_equal_approx(float(_entry(h, "staggered").t), 1.0):
		return "named impairments ignored CC duration reduction"
	# A shorter incoming effect must not rename the longer live one.
	p.apply_freeze(0.2)
	p.apply_root(0.2)
	if _entry(h, "asleep").is_empty() or _entry(h, "staggered").is_empty():
		return "shorter generic effects renamed sleep or stagger"
	p.apply_freeze(2.0)
	p.apply_root(2.4)
	if _entry(h, "frozen").is_empty() or _entry(h, "rooted").is_empty():
		return "default freeze/root did not restore their labels on refresh"
	p.apply_freeze(0.2, "asleep")
	p.apply_root(0.2, "staggered")
	if not _entry(h, "asleep").is_empty() or not _entry(h, "staggered").is_empty():
		return "shorter named effects renamed freeze or root"
	# Control expiry independently of the preceding refresh section.
	p.frozen_time = 0.0
	p.rooted_time = 0.0
	p.apply_freeze(0.4, "asleep")
	p.apply_root(0.4, "staggered")
	h._update_buffs()
	var deadline := Time.get_ticks_msec() + 4000
	while (p.frozen_time > 0.0 or p.rooted_time > 0.0) and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.05).timeout
	h._update_buffs()
	for id in REASONS:
		if not _entry(h, id).is_empty() or h._buff_peak.has(id):
			return "expired named impairment retained its chip or drain: " + id
	p.apply_freeze(0.4)
	p.apply_root(0.4)
	if _entry(h, "frozen").is_empty() or _entry(h, "rooted").is_empty():
		return "a fresh generic effect retained an expired reason"
	print("ok: HUD sleep/stagger (names, restrictions, art, reduced time, overlap, refresh, expiry, defaults)")
	return ""


static func _stun_checks(g: Game, p: Player) -> String:
	var h: Hud = g.hud
	p.frozen_time = 0.0
	p.rooted_time = 0.0
	# Exercise the real PvP delivery branch, without borrowing a live duel.
	var session := WireSession.new()
	session.game = g
	var children_before := g.get_child_count()
	session._pvp_apply_status(1, "freeze", 1.6, 0.0)
	session.free()
	var error := _chip_error(h, p, "stunned")
	if error != "": return error
	if not _entry(h, "frozen").is_empty() or not String(_entry(h, "stunned").tip).begins_with("Stunned:") \
			or "can't move or cast" not in String(_entry(h, "stunned").tip):
		return "PvP stun still has a Frozen chip or incorrect restrictions"
	if not is_equal_approx(p.frozen_time, 0.8):
		return "stun label changed the reduced hard-CC duration"
	var callout := false
	for i in range(children_before, g.get_child_count()):
		var child := g.get_child(i)
		if child is Label and child.text == "STUNNED!":
			callout = true
	if not callout:
		return "stun is missing the STUNNED! callout"
	for other in Hud.BUFF_ICONS:
		if other != "stunned" and Hud.BUFF_ICONS[other] == Hud.BUFF_ICONS.stunned:
			return "stun shares another chip's icon"
	await g.get_tree().create_timer(0.25).timeout
	error = _chip_error(h, p, "stunned")
	if error != "": return error
	if p.frozen_time >= 0.8:
		return "stun countdown did not advance"
	p.apply_freeze(0.2)
	if _entry(h, "stunned").is_empty():
		return "shorter freeze renamed a longer stun"
	p.apply_freeze(2.0)
	p.apply_freeze(0.2, "stunned")
	if _entry(h, "frozen").is_empty() or not _entry(h, "stunned").is_empty():
		return "stun label overwrote a longer genuine freeze"
	p.apply_freeze(2.4, "stunned")
	if not is_equal_approx(float(_entry(h, "stunned").get("t", 0.0)), 1.2):
		return "longer stun failed to refresh its label and timer"
	# Expiry has its own precondition, independent of refresh above.
	p.frozen_time = 0.0
	p.apply_freeze(0.4, "stunned")
	h._update_buffs()
	var deadline := Time.get_ticks_msec() + 4000
	while p.frozen_time > 0.0 and Time.get_ticks_msec() < deadline:
		await g.get_tree().create_timer(0.05).timeout
	h._update_buffs()
	if not _entry(h, "stunned").is_empty() or h._buff_peak.has("stunned"):
		return "expired stun retained its chip or drain"
	p.apply_freeze(0.4)
	if _entry(h, "frozen").is_empty():
		return "fresh genuine freeze retained the expired stun label"
	# The rider names its hard CC: an Ice freeze stays Frozen in a duel, and a
	# peer-supplied label outside that pair falls back to Stunned.
	for row in [["frozen", "frozen", "FROZEN!"], ["asleep", "stunned", "STUNNED!"], ["", "stunned", "STUNNED!"]]:
		p.frozen_time = 0.0
		session = WireSession.new()
		session.game = g
		children_before = g.get_child_count()
		session._pvp_apply_status(1, "freeze", 1.6, 0.0, row[0])
		session.free()
		error = _chip_error(h, p, row[1])
		if error != "": return "PvP label '%s': %s" % [row[0], error]
		var wrong: String = "stunned" if row[1] == "frozen" else "frozen"
		if not _entry(h, wrong).is_empty() or not _entry(h, "asleep").is_empty() \
				or not is_equal_approx(p.frozen_time, 0.8):
			return "PvP label '%s' showed the wrong chip or changed the duration" % row[0]
		callout = false
		for i in range(children_before, g.get_child_count()):
			var child := g.get_child(i)
			if child is Label and child.text == row[2]:
				callout = true
		if not callout:
			return "PvP label '%s' is missing the %s callout" % [row[0], row[2]]
	print("ok: HUD stun (Stunned chip, STUNNED! callout, reduced countdown, overlap, refresh, expiry, genuine freeze control, duel Frozen label, label whitelist)")
	return ""


## Two private ENet branches exercise shell -> host status RPC -> guest owner.
## Only the owner's effect clocks are borrowed; suite() restores them even on failure.
static func _forwarded_reasons(g: Game, p: Player) -> String:
	var hr := WireRoot.new()
	var gr := WireRoot.new()
	hr.name = "ImpairmentHost"
	gr.name = "ImpairmentGuest"
	g.add_child(hr)
	g.add_child(gr)
	var ha := MultiplayerAPI.create_default_interface()
	var ga := MultiplayerAPI.create_default_interface()
	g.get_tree().set_multiplayer(ha, hr.get_path())
	g.get_tree().set_multiplayer(ga, gr.get_path())
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	var error := ""
	if server.create_server(0, 2) != OK:
		error = "impairment ENet bind failed"
	else:
		ha.multiplayer_peer = server
		if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
			error = "impairment ENet connect failed"
		else:
			ga.multiplayer_peer = client
	var host := WireSession.new()
	var guest := WireSession.new()
	host.name = "Session"
	guest.name = "Session"
	hr.add_child(host)
	gr.add_child(guest)
	guest.game = g
	var shell := HostShell.new()
	var bridge := HostGame.new()
	bridge.bridge = host
	bridge.local_player = p
	bridge.pvp_active = true
	bridge.pvp = PvpDuel.new()
	bridge.pvp.state = "fight"
	host.game = bridge
	shell.game = bridge
	if error == "":
		var deadline := Time.get_ticks_msec() + 3000
		while ha.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
			await g.get_tree().create_timer(0.02).timeout
		if ha.get_peers().is_empty():
			error = "impairment ENet handshake timed out"
		else:
			shell.peer_id = ga.get_unique_id()
			hr.peers.append(shell.peer_id)
			for named in [true, false]:
				p.frozen_time = 0.0
				p.rooted_time = 0.0
				if named:
					shell.apply_freeze(2.0, "asleep")
					shell.apply_root(2.0, "staggered")
				else:
					shell.apply_freeze(2.0)
					shell.apply_root(2.0)
				deadline = Time.get_ticks_msec() + 3000
				while (p.frozen_time <= 0.0 or p.rooted_time <= 0.0) and Time.get_ticks_msec() < deadline:
					await g.get_tree().create_timer(0.02).timeout
				for id in (["asleep", "staggered"] if named else ["frozen", "rooted"]):
					var chip_error := _chip_error(g.hud, p, id)
					if chip_error != "":
						error = "forwarded status: " + chip_error
				if error != "": break
			if error == "":
				# Both duel directions: host attacker -> guest owner, then
				# guest attacker -> host validation -> host owner. apply_stun
				# is the production rider entry, retaining the same wire kind;
				# an Ice freeze rides it with its own label and stays Frozen.
				guest.game = bridge
				for target_pid in [ga.get_unique_id(), 1]:
					for frozen in [false, true]:
						p.frozen_time = 0.0
						shell.peer_id = target_pid
						bridge.bridge = host if target_pid != 1 else guest
						if frozen:
							shell.apply_stun(2.0, "frozen")
						else:
							shell.apply_stun(2.0)   # the default every real stun sends
						deadline = Time.get_ticks_msec() + 3000
						while p.frozen_time <= 0.0 and Time.get_ticks_msec() < deadline:
							await g.get_tree().create_timer(0.02).timeout
						var label: String = "frozen" if frozen else "stunned"
						error = _chip_error(g.hud, p, label)
						if error != "": break
						var other: String = "stunned" if frozen else "frozen"
						if not _entry(g.hud, other).is_empty() or p.frozen_time > 1.0:
							error = "forwarded PvP %s shows %s or has an unreduced duration" % [label, other]
							break
					if error != "": break
	shell.free()
	bridge.pvp.free()
	bridge.free()
	ha.multiplayer_peer = null
	ga.multiplayer_peer = null
	client.close()
	server.close()
	g.get_tree().set_multiplayer(null, hr.get_path())
	g.get_tree().set_multiplayer(null, gr.get_path())
	hr.free()
	gr.free()
	if error == "":
		print("ok: HUD impairment ENet forwarding (sleep/stagger/defaults, PvP stun and Ice freeze labels to guest and host owners)")
	return error
