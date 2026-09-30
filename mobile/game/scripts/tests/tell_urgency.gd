extends RefCounted
## Ground danger tells, renderer-free half (DESIGN.md "Ground danger tells"):
## time reads as a smooth pale-to-bold ramp of the ability's own theme color,
## never a sweep, a pop at a fixed fraction of the fuse, or a numeric fuse.
## Production telegraph()/telegraph_safe()/reactive props with posed progress;
## the pixel half (opposite rim pixels, captures) is `shot.bat tells --urgency`.
## Every attack is visual-only (net_visual) and all are cancelled on exit.
const Clock := preload("res://scripts/ground_tell.gd")
const Terrain := preload("res://scripts/reactive_terrain.gd")
const RADIUS := 90.0
const FUSE := 2.4
const SWELL_FUSE := 1.2


static func suite(t: Node) -> String:
	var g: Game = t.game
	var error := _ramp_rows()
	if error == "":
		error = _boss_themes(g)
	if error == "":
		error = _shapes(g)
	if error == "":
		error = await _smooth_envelope(t)
	if error == "":
		error = _shelters(g)
	if error == "":
		error = _reactive_prop(g)
	# Also restores the shelter exam's screen wash and world saturation.
	g.cancel_ground_attacks()
	if error == "":
		print("ok: ground tell urgency (theme ramps hue-true and step-free, Fangmaw yellow to red, Morwen green, color_locked opts out, every shape and shelter/decoy bound, smooth fill/accent swell, Rimeheart frost ramp, breathing idle marker, no countdown caption)")
	return error


static func _near(a: Color, b: Color, tolerance := 0.002) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


static func _ramp_rows() -> String:
	var hot_start := Clock.ramp(Color.TRANSPARENT, 0.0)
	var hot_mid := Clock.ramp(Color.TRANSPARENT, 0.5)
	var hot_end := Clock.ramp(Color.TRANSPARENT, 1.0)
	if not (hot_start.r > 0.9 and hot_start.g > 0.8 and hot_start.b < 0.5):
		return "a neutral tell does not start yellow: %s" % hot_start
	if not (hot_mid.r > 0.9 and hot_mid.g > 0.3 and hot_mid.g < 0.75):
		return "a neutral tell is not orange mid-fuse: %s" % hot_mid
	if not (hot_end.r > 0.9 and hot_end.g < 0.2 and hot_end.b < 0.1):
		return "a neutral tell does not end red: %s" % hot_end
	for kind: String in Balance.BOSS_TELL:
		var theme: Color = Balance.BOSS_TELL[kind].color
		var previous := Clock.ramp(theme, 0.0)
		for i in range(1, 101):
			var color := Clock.ramp(theme, float(i) / 100.0)
			var drift := absf(color.h - theme.h)
			if theme.s > 0.01 and minf(drift, 1.0 - drift) > 0.002:
				return "%s tell left its theme hue at %d%% of the fuse (%.3f vs %.3f)" % [kind, i, color.h, theme.h]
			if not _near(color, previous, 0.03):
				return "%s tell color steps at %d%% of the fuse" % [kind, i]
			if color.s < previous.s - 0.0001 or color.v < previous.v - 0.0001:
				return "%s tell grows paler at %d%% of the fuse" % [kind, i]
			previous = color
		var pale := Clock.ramp(theme, 0.0)
		var bold := Clock.ramp(theme, 1.0)
		if theme.s > 0.01 and bold.s - pale.s < 0.3:
			return "%s tell barely bolds (saturation %.2f to %.2f)" % [kind, pale.s, bold.s]
	return ""


## One production telegraph; null when it did not form (a live shelter).
static func _fire(g: Game, at: Vector2, opts: Dictionary) -> Node2D:
	var count: int = g._ground_attacks.size()
	g.telegraph(at, RADIUS, FUSE, 0.0, opts)
	if g._ground_attacks.size() == count:
		return null
	return g._ground_attacks.back().get_node_or_null("GroundTellClock")


## Rim tint and every bound surface equal the theme ramp at posed phases.
static func _tracks(tell: Node2D, theme: Color, label: String) -> String:
	var rim: Polygon2D = tell.get_node_or_null("CometRim")
	if rim == null:
		return label + " tell has no analytic rim"
	for phase: float in [0.0, 0.5, 1.0]:
		tell.progress = phase
		var want := Clock.ramp(theme, phase)
		var got: Color = rim.material.get_shader_parameter("tint")
		if not _near(got, want):
			return "%s rim is not its theme ramp at %d%% (%s, want %s)" % [label, roundi(phase * 100), got, want]
		for surface: Variant in tell.surfaces:
			if not _near((surface as CanvasItem).modulate, want):
				return "%s fill or accent is not its theme ramp at %d%%" % [label, roundi(phase * 100)]
	return ""


## The real style merger: Fangmaw picks the hot family, Morwen keeps green,
## "color_locked" keeps the call site's own color as the theme, and an
## unthemed mob tell falls back to the hot family.
static func _boss_themes(g: Game) -> String:
	var at: Vector2 = g.local_player.global_position + Vector2(0, -600)
	for kind: String in ["fangmaw", "morwen"]:
		for locked: bool in [false, true]:
			var opts := {"net_visual": true, "dir": Vector2.RIGHT}
			if locked:
				opts["color"] = Color(0.3, 0.6, 1.0, 0.5)
				opts["color_locked"] = true
			var boss := Boss.new()
			boss.kind = kind
			boss._apply_tell_style(opts, at)
			boss.free()
			var label := "%s%s" % [kind, " (color_locked)" if locked else ""]
			var tell := _fire(g, at, opts)
			if tell == null:
				return label + " tell never formed"
			var hot := kind == "fangmaw" and not locked
			if bool(tell.hot_ramp) != hot:
				return label + " tell picked the wrong ramp family"
			var theme := Color.TRANSPARENT
			if not hot:
				theme = opts["color"]
			var error := _tracks(tell, theme, label)
			tell.get_parent().queue_free()
			if error != "":
				return error
	var plain := _fire(g, at, {"net_visual": true})
	if plain == null or not plain.hot_ramp:
		return "an unthemed tell did not fall back to the yellow to red family"
	var plain_error := _tracks(plain, Color.TRANSPARENT, "unthemed")
	plain.get_parent().queue_free()
	return plain_error


static func _shapes(g: Game) -> String:
	var at: Vector2 = g.local_player.global_position + Vector2(0, -600)
	var theme: Color = Balance.BOSS_TELL.morwen.color
	for shape: String in ["disc", "ring", "cone", "line", "cross", "square"]:
		var tell := _fire(g, at, {"net_visual": true, "shape": shape, "color": theme, "dir": Vector2.RIGHT})
		if tell == null:
			return shape + " tell never formed"
		if tell.surfaces.size() != (1 if shape == "disc" else 2):
			return "%s tell binds %d surfaces to its ramp" % [shape, tell.surfaces.size()]
		var error := _tracks(tell, theme, shape)
		tell.get_parent().queue_free()
		if error != "":
			return error
	return ""


## Disc fill and shape accent share two smooth alpha segments that peak at
## impact; the old accent popped to 1.8x in 0.14s at 72% of every fuse.
static func _smooth_envelope(t: Node) -> String:
	var g: Game = t.game
	var tint := Color(0.55, 1.0, 0.25, 0.55)
	var count: int = g._ground_attacks.size()
	g.telegraph(g.local_player.global_position + Vector2(0, -600), RADIUS, SWELL_FUSE, 0.0,
		{"net_visual": true, "shape": "cone", "color": tint, "dir": Vector2.RIGHT})
	if g._ground_attacks.size() == count:
		return "envelope tell never formed"
	var tell: Node2D = g._ground_attacks.back().get_node("GroundTellClock")
	var zone: CanvasItem = tell.surfaces[0]
	var accent: CanvasItem = tell.surfaces[1]
	var deadline := Time.get_ticks_msec() + 8000
	for target: float in [0.8, 0.95]:
		while is_instance_valid(tell) and float(tell.progress) < target:
			if Time.get_ticks_msec() > deadline:
				return "envelope fuse did not advance"
			await t.get_tree().process_frame
		if not is_instance_valid(tell) or float(tell.progress) >= 1.0:
			return "envelope fuse resolved before its %d%% sample" % roundi(target * 100)
		var p: float = tell.progress
		var want_zone := _envelope(p, tint.a, Balance.GROUND_TELL_FILL_START, Balance.GROUND_TELL_FILL_PEAK)
		var want_accent := _envelope(p, tint.a, Balance.GROUND_TELL_ACCENT_START, Balance.GROUND_TELL_ACCENT_PEAK)
		if absf(zone.modulate.a - want_zone) > 0.02 or absf(accent.modulate.a - want_accent) > 0.02:
			return "fill/accent alpha left the smooth swell at %.2f of the fuse (fill %.3f want %.3f, accent %.3f want %.3f)" \
				% [p, zone.modulate.a, want_zone, accent.modulate.a, want_accent]
	if zone.modulate.a <= tint.a or accent.modulate.a <= tint.a:
		return "the final swell toward impact is missing"
	return ""


static func _envelope(p: float, a: float, start: float, peak: float) -> float:
	var f := Balance.GROUND_TELL_FLASH_START
	if p <= f:
		return lerpf(a * start, a, p / f)
	return lerpf(a, minf(1.0, a * peak), (p - f) / (1.0 - f))


## Shelters and decoys ramp their own fill in the shelter color, and keep
## their identity (inward chevrons; the decoy's flicker).
static func _shelters(g: Game) -> String:
	var at: Vector2 = g.local_player.global_position + Vector2(900, -600)
	var color := Color(0.5, 1.0, 0.7, 0.5)
	var count: int = g._ground_attacks.size()
	g.telegraph_safe([at], RADIUS, FUSE, 0.0, {"net_visual": true, "color": color,
		"decoys": [at + Vector2(400, 0)]})
	if g._ground_attacks.size() == count:
		return "shelter exam never formed"
	var clocks: Array = []
	for child: Node in g._ground_attacks.back().get_children():
		if child.get_script() == Clock:
			clocks.append(child)
	if clocks.size() != 2 or not clocks[0].safe or clocks[0].decoy or not clocks[1].decoy:
		return "shelter exam did not draw one shelter and one decoy"
	for tell: Node2D in clocks:
		var label := "decoy" if tell.decoy else "shelter"
		if tell.surfaces.size() != 1:
			return label + " fill is not bound to its ramp"
		var error := _tracks(tell, color, label)
		if error != "":
			return error
	return ""


## An intact prop's marker breathes evenly in its theme color; a primed one
## ramps its frost/ember color and its caption shows no countdown. The fixture
## controls its own preconditions (room, playing state) and restores them.
static func _reactive_prop(g: Game) -> String:
	var p: Player = g.local_player
	var zi: int = g.cur_room
	var flags: Dictionary = g.flags.duplicate(true)
	var scenery: Array = g.zone_scenery.get(zi, []).duplicate()
	var saved_position := p.global_position
	var saved_state: int = g.state
	p.global_position = g.room_center(zi)
	g.state = Game.ST_PLAYING
	var prop := Terrain.install(g, zi, 998, "rime", p.global_position + Vector2(40, 0))
	prop.set_physics_process(false)
	var error := _prop_contracts(g, prop)
	prop.free()
	g.zone_scenery[zi] = scenery
	g.flags = flags
	g.state = saved_state
	p.global_position = saved_position
	return error


static func _prop_contracts(g: Game, prop: StaticBody2D) -> String:
	if prop.phase != 0:
		return "fixture Rimeheart was not intact"
	var theme: Color = Terrain.TYPES.rime.color
	var marker: Node2D = prop.ready_marker
	var marker_rim: Polygon2D = marker.get_node("CometRim")
	marker.progress = 0.0
	var low := float(marker_rim.material.get_shader_parameter("signal_alpha"))
	marker.progress = 0.5
	var high := float(marker_rim.material.get_shader_parameter("signal_alpha"))
	if high - low < 0.3:
		return "intact terrain marker does not breathe (alpha %.2f to %.2f)" % [low, high]
	if not _near(marker_rim.material.get_shader_parameter("tint"), theme):
		return "intact terrain marker lost its theme tint"
	if not prop.prime() or not is_instance_valid(prop.clock):
		return "fixture Rimeheart did not prime"
	prop._physics_process(0.3)
	if prop.phase != 1 or not is_instance_valid(prop.clock):
		return "primed Rimeheart left its fuse early (phase %d)" % prop.phase
	var clock: Node2D = prop.clock
	if clock.hot_ramp or float(clock.progress) <= 0.0:
		return "primed Rimeheart fuse did not advance its own frost ramp"
	if not _near(clock.get_node("CometRim").material.get_shader_parameter("tint"), Clock.ramp(theme, clock.progress)):
		return "primed Rimeheart rim is not its frost ramp"
	var caption: String = prop.caption.text
	for ch: String in "0123456789—":
		if caption.contains(ch):
			return "primed terrain caption shows a countdown or an em dash: " + caption
	if caption == caption.to_upper():
		return "primed terrain caption shouts in caps: " + caption
	return ""
