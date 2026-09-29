extends RefCounted
## shot.bat polish --illumination --fixed-fps=30 --no-import --timeout=300
## Isolated native factories on a matte floor, through the real HDR renderer.
## 8 seconds at 1x, sampled at 15 fps; all originals and ROI measurements saved.
## The luminance gate reads a second, lights-only pass (art hidden) so it
## measures the illumination envelope, not the authored strips' own motion.
const Illumination := preload("res://scripts/prop_illumination.gd")
const CAPTURE_SECONDS := 8.0
const FPS := 30
# CLAUDE.md "World props" contract: glows swing at most 10-12%, open fire 25%.
const GLOW_SWING_MAX := 0.12
const FIRE_SWING_MAX := 0.25
const LIGHT_PASS_MIN_SECONDS := 2.0


static func run(rig: Node) -> String:
	var regression := preload("res://scripts/tests/test_prop_illumination.gd").run(rig)
	if regression != "":
		return regression
	var g: Game = rig.game
	regression = preload("res://scripts/tests/test_prop_illumination.gd").run_world(g)
	if regression != "":
		return regression
	var original_world := g.world
	var old_visible := original_world.visible
	var old_process := g.process_mode
	var old_ambient := g.ambient.color
	var old_camera := g.camera.global_position
	var old_zoom := g.camera.zoom
	var old_camera_process := g.camera.process_mode
	var old_camera_offset := g.camera.offset
	var old_limits := [g.camera.limit_left, g.camera.limit_top, g.camera.limit_right, g.camera.limit_bottom]
	var fixture := Node2D.new()
	rig.add_child(fixture)
	original_world.hide()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	g.camera.offset = Vector2.ZERO
	g.world = fixture
	g.ambient.color = Terrains.get_terrain("keep")["tint"]
	var result := await _capture(rig, fixture)
	g.world = original_world
	original_world.visible = old_visible
	g.process_mode = old_process
	g.ambient.color = old_ambient
	g.camera.global_position = old_camera
	g.camera.zoom = old_zoom
	g.camera.process_mode = old_camera_process
	g.camera.offset = old_camera_offset
	g.camera.limit_left = old_limits[0]
	g.camera.limit_top = old_limits[1]
	g.camera.limit_right = old_limits[2]
	g.camera.limit_bottom = old_limits[3]
	g.camera.force_update_scroll()
	fixture.free()
	return result


static func _capture(rig: Node, fixture: Node2D) -> String:
	var g: Game = rig.game
	var zi := 17
	var pr := g.play_rect(zi)
	preload("res://scripts/door_torch_mount.gd").build(g, zi,
		Vector2(pr.get_center().x, pr.position.y), false)
	var mounts: Array[Node2D] = []
	for child in fixture.get_children():
		if child.has_meta("door_torch"):
			mounts.append(child)
	if mounts.size() != 2:
		return "native door mount did not create its pair"
	var center := (mounts[0].global_position + mounts[1].global_position) * 0.5 + Vector2(0, 120)
	g._add_structure("watch_brazier", center + Vector2(-300, 180))
	g._add_structure("spore_cathedral", center + Vector2(300, 180))
	g._add_structure("signal_fire", center + Vector2(0, 180))
	var floor_base := Polygon2D.new()
	floor_base.polygon = PackedVector2Array([center + Vector2(-900, -600), center + Vector2(900, -600),
		center + Vector2(900, 600), center + Vector2(-900, 600)])
	floor_base.color = Color(0.16, 0.17, 0.18)
	floor_base.z_index = -100
	fixture.add_child(floor_base)
	# Boot leaves the camera clamped to room 0. This fixture is in room 17,
	# so explicitly set its bounds before requesting the native 1x framing.
	g.camera.limit_left = int(center.x - 900)
	g.camera.limit_right = int(center.x + 900)
	g.camera.limit_top = int(center.y - 600)
	g.camera.limit_bottom = int(center.y + 600)
	g.camera.zoom = Vector2.ONE
	g.camera.global_position = center
	# The game camera smooths; jump straight to the fixture so the sampled
	# screen patches stay on the same floor pixels for the whole capture.
	g.camera.reset_smoothing()
	g.camera.force_update_scroll()
	await rig.frames(3)
	var clocks: Array[Node] = []
	var geometry: Array[Dictionary] = []
	_collect(fixture, clocks, geometry)
	if clocks.size() != 5:
		return "expected five native light clocks, got %d" % clocks.size()
	var regions: Array[Dictionary] = []
	for clock in clocks:
		if clock._outputs.size() < 2:
			return "native source is missing its shared floor/halo output"
		for output: Dictionary in clock._outputs:
			var node: Node2D = output["node"].get_ref()
			if node is Sprite2D and node.material is CanvasItemMaterial:
				# A fixed scene patch beside each source (reported), and the gated
				# patch on the pool's centre for the lights-only pass.
				var at := node.get_global_transform_with_canvas() * Vector2(6, 0)
				var mount: Node = clock.get_parent().get_parent()
				var fire: bool = mount.has_meta("door_torch") or bool(Terrains.STRUCTURES.get(
					String(mount.get_meta("structure", "")), {}).get("fire", false))
				var pool_at := node.get_global_transform_with_canvas().origin
				regions.append({"name": str(clock.get_parent().get_path()),
					"rect": Rect2i(Vector2i(at) - Vector2i(6, 6), Vector2i(12, 12)),
					"light_rect": Rect2i(Vector2i(pool_at) - Vector2i(6, 6), Vector2i(12, 12)),
					"limit": FIRE_SWING_MAX if fire else GLOW_SWING_MAX,
					"min": INF, "max": 0.0, "samples": [],
					"light_min": INF, "light_max": 0.0, "light_samples": []})
	if regions.size() != 5:
		return "missing native floor-light regions"
	var out_dir := ProjectSettings.globalize_path(rig.shot_dir + "/illumination")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var rows: Array = []
	for frame in int(CAPTURE_SECONDS * FPS):
		await rig.get_tree().process_frame
		await RenderingServer.frame_post_draw
		for item in geometry:
			if item["node"].global_transform != item["transform"]:
				return "base, silhouette transform or halo extent moved: " + str(item["node"].get_path())
		for clock in clocks:
			for output: Dictionary in clock._outputs:
				var node: Node2D = output["node"].get_ref()
				var actual := float(node.get_indexed(NodePath(output["property"])))
				if absf(actual - float(output["peak"]) * clock.value) > 0.00001:
					return "native halo/point light/floor envelope diverged"
		if frame % 2 != 0:
			continue
		var img: Image = rig.capture_image()
		img.save_png(out_dir + "/f_%04d.png" % (frame / 2))
		rig.shots_taken += 1
		for region in regions:
			var rect: Rect2i = region["rect"]
			if not Rect2i(Vector2i.ZERO, img.get_size()).encloses(rect):
				return "light sample escaped the native viewport"
			var luma := _luminance(img, rect)
			region["min"] = minf(region["min"], luma)
			region["max"] = maxf(region["max"], luma)
			region["samples"].append(luma)
		var phases: Array = []
		for clock in clocks:
			phases.append({"phase": clock.phase, "envelope": clock.value})
		rows.append({"seconds": float(frame + 1) / FPS, "sources": phases})
	# Pass 2, the gate: the same live sources with every art sprite hidden, so
	# each patch at a floor pool's centre reads only floor + pool + halo + point
	# light, bloom included. The scene patches above also carry the authored
	# strips (audited separately by tools/art/audit_prop_anims.py), so they are
	# reported here but not gated.
	var keep := {}
	for clock in clocks:
		for output: Dictionary in clock._outputs:
			keep[output["node"].get_ref()] = true
	var hidden: Array[CanvasItem] = []
	_hide_art(fixture, keep, hidden)
	for light in keep:
		if not (light as CanvasItem).is_visible_in_tree():
			return "a light layer sits under prop art and cannot be measured alone"
	var longest := 0.0
	for clock in clocks:
		longest = maxf(longest, float(clock.period))
	var light_frames := ceili(maxf(LIGHT_PASS_MIN_SECONDS, 2.0 * longest) * FPS)
	for frame in light_frames:
		await rig.get_tree().process_frame
		await RenderingServer.frame_post_draw
		if frame % 2 != 0:
			continue
		var img: Image = rig.capture_image()
		for region in regions:
			var rect: Rect2i = region["light_rect"]
			if not Rect2i(Vector2i.ZERO, img.get_size()).encloses(rect):
				return "light sample escaped the native viewport"
			var luma := _luminance(img, rect)
			region["light_min"] = minf(region["light_min"], luma)
			region["light_max"] = maxf(region["light_max"], luma)
			region["light_samples"].append(luma)
	for item in hidden:
		item.visible = true
	var failure := ""
	for region in regions:
		var swing: float = (region["max"] - region["min"]) / maxf(region["max"], 0.00001)
		region["swing"] = swing
		var light_swing: float = (region["light_max"] - region["light_min"]) / maxf(region["light_max"], 0.00001)
		region["light_swing"] = light_swing
		print("ILLUMINATION LUMA: %s light min=%.6f max=%.6f swing=%.2f%% limit=%.0f%% | scene incl. authored strip swing=%.2f%%" %
			[region["name"], region["light_min"], region["light_max"], light_swing * 100.0,
			float(region["limit"]) * 100.0, swing * 100.0])
		if light_swing > float(region["limit"]) or region["light_max"] <= 0.0:
			failure = "rendered light region exceeds its %.0f%% contract: %s" % [float(region["limit"]) * 100.0, region["name"]]
	var report := {"seconds": CAPTURE_SECONDS, "zoom": 1.0, "sample_fps": FPS / 2,
		"light_pass_frames": light_frames,
		"regions": regions, "frames": rows, "stationary_transforms": geometry.size(), "failure": failure}
	var file := FileAccess.open(out_dir + "/measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	if failure == "":
		print("ILLUMINATION PASS: five native sources, 120 rendered frames, 8 seconds at 1x; fixed bases/halo extents; lights-only swing within the glow 12% / fire 25% contract")
	return failure


static func _collect(node: Node, clocks: Array[Node], geometry: Array[Dictionary]) -> void:
	if node.get_script() == Illumination:
		clocks.append(node)
	# Cast shadows follow authored flame silhouettes and are outside the rigid
	# prop/light geometry contract; source transforms and light extents are fixed.
	if node is Node2D and not node.has_meta("cast_shadow"):
		geometry.append({"node": node, "transform": node.global_transform})
	for child in node.get_children():
		_collect(child, clocks, geometry)


static func _hide_art(node: Node, keep: Dictionary, hidden: Array[CanvasItem]) -> void:
	if (node is Sprite2D or node is AnimatedSprite2D) and not keep.has(node) and (node as CanvasItem).visible:
		(node as CanvasItem).visible = false
		hidden.append(node)
	for child in node.get_children():
		_hide_art(child, keep, hidden)


static func _luminance(img: Image, rect: Rect2i) -> float:
	var total := 0.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y).srgb_to_linear()
			total += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	return total / float(rect.get_area())
