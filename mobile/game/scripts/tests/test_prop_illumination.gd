extends RefCounted
## Disposable fixtures; the native-factory audit restores the world's owner
## and the hazard list on success and failure and never changes campaign
## flags, terrain or saves.
const Illumination := preload("res://scripts/prop_illumination.gd")


static func run(_r: Node) -> String:
	var holder := Node2D.new()
	var result := _contract(holder)
	holder.free()  # cleanup also covers every failure path
	if result == "":
		print("ok: prop illumination fixed geometry, shared strip/halo/pool phase, 4% envelope and lifetime")
	return result


static func run_world(g: Game) -> String:
	# Exercise the real consumer factories, in a disposable world. In particular,
	# the old _floor_glow tween has no Illumination node and fails this contract.
	var original_world := g.world
	var hazard_count := g.hazards.size()
	var holder := Node2D.new()
	g.add_child(holder)
	g.world = holder
	var result := _consumers(g, holder)
	if result == "":
		result = _door_torches(g, holder)
	if result == "":
		result = _sealed_gate(g)
	if result == "":
		result = _hazard_caller(g, holder)
	g.world = original_world
	g.hazards.resize(hazard_count)  # the lava fixture appends one entry
	holder.free()
	if result == "":
		print("ok: door torches, all native structure light consumers per clock, sealed gate, standalone pools, hazard opt-out and inert props")
	return result


static func _consumers(g: Game, holder: Node2D) -> String:
	var zi := g.cur_room
	var at := g.room_center(zi)
	var pool := g._floor_glow(holder, at, Color.WHITE, 80.0, 0.8, zi)
	if not pool.has_node("Illumination"):
		return "floor glow still runs the old independent pulse"
	pool.free()
	var inert := g._floor_glow(holder, at, Color.WHITE, 80.0, 0.8, zi, false)
	if inert.has_node("Illumination"):
		return "pulse=false lost its static illumination rule"
	inert.free()
	var hazard := g._floor_glow(holder, at, Color.WHITE, 80.0, 0.8, zi, true, null, true)
	if hazard.has_node("Illumination"):
		return "hazard pool acquired the ordinary prop envelope"
	hazard.free()
	for key: String in Terrains.STRUCTURES:
		var spec: Dictionary = Terrains.STRUCTURES[key]
		var expected: int = spec.get("lights", []).size()
		for decal in spec.get("decals", []):
			if decal.get("light") is Color:
				expected += 1
		# old_well is inert by design (NO_MOTION_OK) and must stay unlit.
		if expected == 0 and key != "old_well":
			continue
		var body := g._add_structure(key, at)
		var clocks := body.find_children("Illumination", "", true, false)
		var linked_lights := 0
		var linked_pools := 0
		for clock in clocks:
			# Pairing is per clock: a light and its floor pool share ONE envelope.
			var lights := 0
			var pools := 0
			for output: Dictionary in clock._outputs:
				var node: Node2D = output["node"].get_ref()
				if node is PointLight2D:
					lights += 1
				elif node.material is CanvasItemMaterial:
					pools += 1
			if lights != pools:
				return "%s floor pool and point light run on different clocks (%d/%d)" % [key, lights, pools]
			var source: Node2D = clock._source
			if source is AnimatedSprite2D and (source as AnimatedSprite2D).is_playing():
				return "%s light source still plays on its own animation clock" % key
			# A light parked on static art while an animated strip in the same
			# structure keeps its own playback = two rhythms on one source.
			if int(clock._frames) <= 1 and _plays_own_strip(body):
				return "%s light follows static art beside a strip with its own rhythm" % key
			linked_lights += lights
			linked_pools += pools
		if linked_lights != expected or linked_pools != expected:
			return "%s has unpaired native light/floor consumers (%d/%d expected %d)" % [key, linked_lights, linked_pools, expected]
		for child in body.get_children():
			if child is Sprite2D and child.material is CanvasItemMaterial and child.has_node("Illumination"):
				return "%s floor pool runs its own pulse instead of its light's" % key
		if key == "keep_courtyard" and clocks.size() != 2:
			return "two courtyard braziers must have distinct source clocks"
		if key == "old_well" and not clocks.is_empty():
			return "NO_MOTION_OK prop gained a light envelope: " + key
		body.free()
	return ""


static func _plays_own_strip(body: Node) -> bool:
	for child in body.get_children():
		if child is AnimatedSprite2D and not child.has_meta("cast_shadow") \
				and (child as AnimatedSprite2D).is_playing():
			return true
	return false


## The task's headline source: the doorway torch pair. Its flame strip, fixed
## halo and floor pool must share one clock with a per-torch phase.
static func _door_torches(g: Game, holder: Node2D) -> String:
	var info: Dictionary = Art.anim_info("torch_pillar")
	if info.is_empty():
		return "door torch flame strip is missing"
	var zi := g.cur_room
	var pr: Rect2 = g.play_rect(zi)
	preload("res://scripts/door_torch_mount.gd").build(g, zi,
		Vector2(pr.get_center().x, pr.position.y), false)
	var phases: Array[float] = []
	for root in holder.get_children():
		if not root.has_meta("door_torch"):
			continue
		var pillar := root.get_node_or_null("Pillar") as Sprite2D
		if pillar == null or not pillar.has_node("Illumination"):
			return "door torch flame still runs on its own animation clock"
		var clock = pillar.get_node("Illumination")
		if pillar.hframes <= 1 or not is_equal_approx(clock.period, float(pillar.hframes) / float(info["fps"])):
			return "door torch light envelope is not the flame strip's own loop"
		var halo: Sprite2D = null
		var pool: Sprite2D = null
		for output: Dictionary in clock._outputs:
			var node = output["node"].get_ref()
			if node is Sprite2D:
				if node.material is CanvasItemMaterial:
					pool = node
				else:
					halo = node
		if halo == null or pool == null:
			return "door torch halo and floor pool are not on the flame's clock"
		if pool.has_node("Illumination"):
			return "door torch floor pool runs its own pulse"
		var halo_scale := Vector2.ONE * Balance.DOOR_TORCH_HALO_SCALE
		if halo.scale != halo_scale:
			return "door torch halo is not at its fixed scale"
		phases.append(float(clock.phase))
		var transforms := [pillar.transform, halo.transform, pool.transform]
		for tick in 48:
			clock.advance(clock.period / 16.0)
			if pillar.frame != int(clock.phase * pillar.hframes):
				return "door torch flame left the shared clock"
			if halo.scale != halo_scale or [pillar.transform, halo.transform, pool.transform] != transforms:
				return "door torch halo pumps its scale or a light layer moved"
	if phases.size() != 2:
		return "door mount did not build its torch pair (%d)" % phases.size()
	if is_equal_approx(phases[0], phases[1]):
		return "paired door torches share one phase and blink in unison"
	return ""


## A sealed endgame gate holds its strip on frame 0 (owner ruling: only an
## unlocked gate animates). Its light clock must not restart the strip.
static func _sealed_gate(g: Game) -> String:
	var gate := g._add_structure("capital_portal_crucible", g.room_center(g.cur_room))
	g._seal_portal(gate)
	var clocks := gate.find_children("Illumination", "", true, false)
	if clocks.is_empty():
		return "sealed gate fixture has no light clock to hold"
	for clock in clocks:
		for tick in 12:
			clock.advance(0.1)
	for child in gate.get_children():
		if child is AnimatedSprite2D and not child.has_meta("cast_shadow"):
			var strip := child as AnimatedSprite2D
			if strip.frame != 0 or strip.is_playing():
				return "sealed Crucible gate animates again"
	gate.free()
	return ""


## The real hazard caller keeps its own telegraph pulse, off the prop envelope.
static func _hazard_caller(g: Game, holder: Node2D) -> String:
	var before := holder.get_child_count()
	g._add_hazard(g.cur_room, "lava", g.room_center(g.cur_room), 40.0, 5.0)
	if holder.get_child_count() != before + 1:
		return "lava hazard fixture did not land in the disposable world"
	var found := false
	for glow in holder.get_child(before).get_children():
		if glow is Sprite2D and glow.material is CanvasItemMaterial:
			found = true
			if glow.has_node("Illumination"):
				return "lava hazard glow joined the prop light envelope"
	if not found:
		return "lava hazard lost its floor glow"
	return ""


static func _contract(holder: Node2D) -> String:
	if Balance.PROP_LIGHT_LOW < 0.96 or Balance.PROP_LIGHT_LOW >= 1.0:
		return "prop illumination must reserve bloom headroom with a nonzero dip of at most 4%"
	if Balance.HAZARD_GLOW_PULSE_LOW != 0.72 or Balance.HAZARD_GLOW_PULSE_PERIOD != Vector2(1.1, 1.6):
		return "hazard pool telegraph envelope changed"
	var source := Sprite2D.new()
	source.hframes = 4
	source.position = Vector2(70, 80)
	source.scale = Vector2(0.4, 0.4)
	holder.add_child(source)
	var halo := Sprite2D.new()
	halo.modulate.a = 0.5
	halo.scale = Vector2.ONE * Balance.DOOR_TORCH_HALO_SCALE
	holder.add_child(halo)
	var floor_pool := Sprite2D.new()
	floor_pool.modulate.a = 0.85
	floor_pool.scale = Vector2(3.5, 3.5)
	holder.add_child(floor_pool)
	var light := PointLight2D.new()
	light.energy = 1.1
	holder.add_child(light)
	var clock := Illumination.attach(source, source.position, 6.0)
	clock.bind(halo)
	clock.bind(floor_pool)
	clock.bind(light)
	if Illumination.attach(source, source.position) != clock:
		return "multiple light sockets created competing clocks on one source"
	if not is_equal_approx(clock.period, 4.0 / 6.0):
		return "illumination changed the authored animation speed"
	var phase: float = clock.phase
	if not is_equal_approx(phase, Illumination.phase_at(source.position)):
		return "source phase is not stable across rebuilds"
	if absf(phase - Illumination.phase_at(source.position + Vector2(100, 0))) < 0.01:
		return "neighbouring sources blink together"
	var transforms := [source.transform, halo.transform, floor_pool.transform]
	var low := 1.0
	var high := 0.0
	var seen := {}
	for tick in 240:
		clock.advance(clock.period / 80.0)
		var envelope: float = halo.modulate.a / 0.5
		low = minf(low, envelope)
		high = maxf(high, envelope)
		seen[source.frame] = true
		if absf(envelope - floor_pool.modulate.a / 0.85) > 0.00001 \
			or absf(envelope - light.energy / 1.1) > 0.00001:
			return "halo, floor pool and point light lost their shared envelope"
		if source.frame != int(clock.phase * source.hframes):
			return "flame has an independent animation clock"
		if [source.transform, halo.transform, floor_pool.transform] != transforms:
			return "illumination moved the base or pumped halo/floor geometry"
	if seen.size() != 4 or high - low < 0.039 or (high - low) / high > 0.04001:
		return "illumination is frozen or exceeds its restrained luminance budget"
	# A sibling light may be retired before its source; weak outputs must tolerate it.
	floor_pool.free()
	clock.advance(0.1)
	var animated := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	for frame in 4:
		sf.add_frame("default", null)
	sf.set_animation_speed("default", 6.0)
	animated.sprite_frames = sf
	holder.add_child(animated)
	animated.play()
	var animated_clock := Illumination.attach(animated, Vector2(400, 80))
	if animated.is_playing():
		return "animated prop still owns a competing playback clock"
	animated_clock.advance(animated_clock.period * 0.25)
	if animated.frame != int(animated_clock.phase * 4):
		return "animated prop and socket light lost their shared phase"
	return ""
