extends ShotRig
## One-session T57 before/after, production obstacle scale/filter on village grass.
## --before-dir=<absolute folder of original PNGs> --timeout=240
## Original PNGs get Godot's import-equivalent alpha-border treatment. Animation
## frame zero and wind are frozen so only source RGB changes between each pair.

func _ready() -> void:
	if arg("before-dir", "") == "":
		push_error("T57 requires --before-dir containing the original PNGs")
		finish(1)
		return
	seed(570029)
	await boot("warrior", "ch1")
	await sim_wait(1.0)
	apply_terrain("village", game.cur_room)
	await frames(3)
	hide_hud()
	game.set_process(false)
	game.player.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.visible = false
	for node in game.zone_scenery.get(game.cur_room, []):
		if is_instance_valid(node) and node is CanvasItem:
			node.visible = false
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2.ONE
	var origin: Vector2 = game.room_center(game.cur_room) + Vector2(180, 160)
	for name in ["tree_teal3", "tree_teal", "tree_teal2", "grave_deadtree"]:
		var point := origin
		var found := false
		for dx in range(48):
			for dy in range(16):
				var candidate := origin + Vector2(dx, dy)
				if Terrains.prop_variant(name, int(candidate.x * 31.0 + candidate.y * 17.0)) == name:
					point = candidate
					found = true
					break
			if found: break
		if not found:
			push_error("T57 could not select variant " + name)
			finish(1)
			return
		var body: StaticBody2D = game._add_obstacle(name, point, 1.0)
		var source: Node2D = null
		for child in body.get_children():
			if child is AnimatedSprite2D:
				child.stop()
				child.frame = 0
			if child is CanvasItem:
				child.material = null
			if child.has_meta("cast_shadow") or child.has_meta("prop_contact_shadow"): continue
			if child is Sprite2D or child is AnimatedSprite2D: source = child
		if source == null or source.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR:
			push_error("T57 source missing or production sampling is not LINEAR")
			finish(1)
			return
		# Freeze TIME-dependent sway for identical comparison geometry.
		source.material = null
		var current: Texture2D
		var filename: String = name + ".png"
		if source is AnimatedSprite2D:
			source.stop()
			source.frame = 0
			source.sprite_frames = source.sprite_frames.duplicate()
			current = source.sprite_frames.get_frame_texture(source.animation, 0)
			filename = name + "_anim.png"
		else:
			current = source.texture
		var original := Image.load_from_file(arg("before-dir").path_join(filename))
		if original == null or original.is_empty():
			push_error("T57 missing original " + filename)
			finish(1)
			return
		original.fix_alpha_edges()
		var before: Texture2D = ImageTexture.create_from_image(original)
		if current is AtlasTexture:
			var atlas := AtlasTexture.new()
			atlas.atlas = before
			atlas.region = current.region
			atlas.filter_clip = current.filter_clip
			before = atlas
		game.camera.global_position = source.global_position
		game.camera.reset_smoothing()
		game.camera.force_update_scroll()
		for phase in ["before", "after"]:
			var texture: Texture2D = before if phase == "before" else current
			if source is AnimatedSprite2D:
				source.sprite_frames.set_frame(source.animation, 0, texture)
			else:
				source.texture = texture
			await frames(3)
			await RenderingServer.frame_post_draw
			shot(name + "_" + phase, "LINEAR; native scale; village grass; wind/frame frozen")
		body.queue_free()
		await frames(2)
	print("WHITE DEFRINGE PASS: 4 production trees, 8 paired captures")
	finish()
