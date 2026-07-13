class_name Dummy extends Enemy
## A training dummy: an immortal, planted target for measuring a class's
## sustained DPS. Its HP never drops and it never attacks or moves. Every
## hit (direct or DoT tick) feeds a live readout floating above it —
## realized DPS, total damage, hit count, peak hit, crit rate. The window
## starts on first blood and RESETS after RESET_SECS with no incoming
## damage, so each fresh burst reads clean. Spawned from the F1 dev panel.

const RESET_SECS := 5.0  # idle gap that clears the readout for a fresh run

# --- live metrics (the window from first hit to the idle reset) ---
var m_active := false
var m_total := 0.0    # summed damage this window
var m_time := 0.0     # seconds since first blood (includes sub-reset gaps)
var m_hits := 0
var m_crits := 0
var m_peak := 0.0     # biggest single hit
var m_idle := 0.0     # seconds since the last hit (RESET_SECS -> wipe)

var readout: Label
var readout_bg: ColorRect


static func spawn_dummy(game_node: Node2D, pos: Vector2) -> Dummy:
	var d := Dummy.new()
	# Borrow the skeleton's body/sprite for a recognizable standing target;
	# everything that matters (immortality, stillness) is overridden below.
	d._setup(game_node, "skeleton", pos)
	d._make_dummy()
	return d


func _make_dummy() -> void:
	display_name = "Training Dummy"
	# zone_idx stays -1 (Enemy default) so it always simulates and never
	# seals a room's doors. A straw tint reads "practice target", not "mob".
	sprite.modulate = Color(1.15, 1.0, 0.6)
	# Immortal: park HP absurdly high so nothing (a stray 9999999 dev-kill
	# aside) ever bottoms it out, and the overhead HP bar never appears.
	max_hp = 1.0e12
	hp = max_hp

	# Floating stat readout, pinned above the head. A dim panel keeps the
	# text legible over any terrain; z_index rides above sprites like the
	# damage numbers (game.spawn_text) do.
	readout_bg = ColorRect.new()
	readout_bg.color = Color(0, 0, 0, 0.6)
	readout_bg.position = Vector2(-118, -96)
	readout_bg.size = Vector2(236, 62)
	readout_bg.z_index = 19
	readout_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(readout_bg)

	readout = Label.new()
	readout.position = Vector2(-118, -94)
	readout.size = Vector2(236, 58)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.z_index = 20
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_font_size_override("font_size", 13)
	readout.add_theme_color_override("font_color", Color(0.95, 0.95, 0.8))
	readout.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	readout.add_theme_constant_override("outline_size", 4)
	add_child(readout)
	_refresh_readout()


func _physics_process(delta: float) -> void:
	# Reuse the base tick — crucially its burn/DoT handling, which routes
	# ticks back through our take_damage so damage-over-time counts too —
	# then pin the body in place (gusts/knock can't nudge a dummy) and
	# advance the readout.
	super(delta)
	global_position = home
	_tick_metrics(delta)
	_refresh_readout()


## Planted and pacifist: never chase, never bite.
func _think(_delta: float) -> Vector2:
	return Vector2.ZERO


## Record the hit, flash + float the number like a normal enemy, but keep
## HP pinned — the dummy never dies and never gets knocked off its mark.
func take_damage(amount: float, from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
	if untargetable:
		return
	if vuln_time > 0.0:
		amount *= 1.5
	_note_hit(amount, is_crit)
	knock = Vector2.ZERO
	if not silent:
		game.sfx("ehit")
		if is_crit:
			game.spawn_text(global_position + Vector2(0, -34), "%d!" % int(amount), Color(1.0, 0.55, 0.1))
		else:
			game.spawn_text(global_position + Vector2(0, -30), str(int(amount)), Color(1, 1, 1))
		sprite.modulate = Color(3, 3, 3)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.15, 1.0, 0.6), 0.15)


func _note_hit(amount: float, is_crit: bool) -> void:
	if not m_active:
		m_active = true
		m_total = 0.0
		m_time = 0.0
		m_hits = 0
		m_crits = 0
		m_peak = 0.0
	m_total += amount
	m_hits += 1
	if is_crit:
		m_crits += 1
	m_peak = maxf(m_peak, amount)
	m_idle = 0.0


func _tick_metrics(delta: float) -> void:
	if not m_active:
		return
	m_time += delta
	m_idle += delta
	if m_idle >= RESET_SECS:
		m_active = false  # stop the clock; next hit starts a fresh window


func _refresh_readout() -> void:
	if not m_active:
		readout.text = "TRAINING DUMMY\nhit me — I'll measure your DPS"
		return
	var dps: float = m_total / maxf(m_time, 0.1)
	var crit_pct: float = 100.0 * float(m_crits) / float(maxi(m_hits, 1))
	readout.text = "TRAINING DUMMY\n%.0f DPS   (%.0f over %.1fs)\n%d hits · peak %.0f · crit %.0f%%" % [
		dps, m_total, m_time, m_hits, m_peak, crit_pct]
