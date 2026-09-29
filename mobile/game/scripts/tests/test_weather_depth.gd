extends RefCounted
## Configuration regression used by systems and the native ambient-life rig.
## Preserve the live emitters themselves, including their particle ages.

static func run(g: Game) -> String:
	var keep := {"near": g.ambient_fx, "far": g.ambient_fx_distant, "fog": g.ground_fog,
		"above": g.ambient_above, "settings": g.settings.duplicate(true)}
	for key in ["near", "far", "fog"]:
		var node: Node = keep[key]
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
	g.ambient_fx = null
	g.ambient_fx_distant = null
	g.ground_fog = null
	var error := _contracts(g)
	for node in [g.ambient_fx, g.ambient_fx_distant, g.ground_fog]:
		if is_instance_valid(node): node.free()
	g.settings = keep.settings
	g.ambient_above = keep.above
	g.ambient_fx = keep.near
	g.ambient_fx_distant = keep.far
	g.ground_fog = keep.fog
	for node in [g.ambient_fx, g.ambient_fx_distant]:
		if is_instance_valid(node): g.add_child(node)
	if is_instance_valid(g.ground_fog): g.world.add_child(g.ground_fog)
	if error == "": print("WEATHER CONFIG PASS: every preset / quality, two depths, world space, camera coverage, budget and clean replacement; mist preserved")
	return error


static func _contracts(g: Game) -> String:
	var covered := {}
	for terrain in Terrains.DATA:
		var preset: String = Terrains.DATA[terrain].get("ambient", "leaves_green")
		if covered.has(preset): continue
		covered[preset] = true
		var spec: Dictionary = Terrains.AMBIENTS[preset]
		for quality in ["low", "medium", "high"]:
			g.settings["weather_quality"] = quality
			var previous := [g.ambient_fx, g.ambient_fx_distant]
			g._setup_ambient_fx(terrain)
			for old in previous:
				if is_instance_valid(old) and (old.is_inside_tree() or not old.is_queued_for_deletion() or old.emitting):
					return "old weather remains live during replacement: " + preset
			var near: CPUParticles2D = g.ambient_fx
			var far: CPUParticles2D = g.ambient_fx_distant
			if not is_instance_valid(near): return "missing weather: " + preset
			if preset == "mist":
				if is_instance_valid(far) or near.amount != 8 or near.z_index != 12 \
						or near.color != spec.color or near.gravity != spec.gravity \
						or near.emission_rect_extents != Vector2(760, 340):
					return "mist wisps changed"
				if not is_instance_valid(g.ground_fog) or g.ground_fog.z_index != -6:
					return "mist lost its ground fog"
				continue
			if not is_instance_valid(far): return "missing distant weather layer: " + preset
			if far.z_index != Balance.WEATHER_DISTANT_Z or far.z_index <= -8 or far.z_index >= 0 \
					or near.z_index != Balance.WEATHER_NEAR_Z or near.z_index <= 0:
				return "weather does not straddle actors above the floor: " + preset
			if far.amount <= near.amount or near.amount < 1:
				return "near weather is not sparse: " + preset
			var fraction: float = Balance.WEATHER_QUALITY_BUDGET[quality]
			if far.amount + near.amount != int(floor(spec.amount * fraction)) \
					or far.amount + near.amount > int(spec.amount):
				return "weather exceeded/ignored quality budget: " + preset + "/" + quality
			if far.local_coords or near.local_coords:
				return "weather drags living particles with its source: " + preset
			if far.scale_amount_max >= near.scale_amount_min \
					or far.initial_velocity_min >= near.initial_velocity_min \
					or far.initial_velocity_max >= near.initial_velocity_max:
				return "weather depths lack distinct size/speed: " + preset
			if near.color.a > float(spec.color.a) * Balance.WEATHER_NEAR_ALPHA + 0.0001 \
					or near.color.a >= far.color.a:
				return "near weather obscures combat: " + preset
			if is_instance_valid(g.ground_fog): return "non-mist weather gained ground fog"
			g._update_ambient_fx()
			if far.color_ramp == null or near.color_ramp == null:
				return "weather pops in without a fade: " + preset
			var half_view := g.get_viewport_rect().size / g.camera.zoom * 0.5
			var view_center := g.camera.get_screen_center_position()
			for emitter in [near, far]:
				var gap: Vector2 = (emitter.global_position - view_center).abs()
				if gap.x + half_view.x > emitter.emission_rect_extents.x \
						or gap.y + half_view.y > emitter.emission_rect_extents.y:
					return "weather leaves viewport uncovered: " + preset
	return ""
