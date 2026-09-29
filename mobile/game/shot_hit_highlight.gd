extends ShotRig
## T50 hit highlight on the REAL renderer. The quick tier's hit-visual checks run
## headless on the dummy renderer, which never compiles or draws
## enemy_hit.gdshader; this rig does, and the runner rejects SHADER ERROR.
##   shot.bat hit_highlight [--renderer=gl_compatibility] [--timeout=240]
## 1. Measure (SubViewport, body only: rim, shadow and bars hidden), per body:
##    wolf and void_shade (near-black art). At hit_strength 0 the shader must
##    render exactly like the default material (the premultiplied-COLOR trap
##    darkens it; a lost vertex COLOR drops the tell tint). At the peak the body
##    must brighten while the bite tell keeps its hue (a white stomp fails R:B),
##    the painted colours keep theirs, and the silhouette alpha stays put.
## 2. Stills for eyes: wolf / void_shade / cinderhide on keep and void floors,
##    plain and under the bite tell, rest vs peak, world paused so each pair
##    differs only by the hit. user://shots/hit_highlight/.

const TELL := Color(2.0, 1.7, 0.5)  # the bite windup tint (Enemy._think)
const MEASURE_KINDS := ["wolf", "void_shade"]
const STILL_KINDS := ["wolf", "void_shade", "cinderhide"]


func _ready() -> void:
	await boot("warrior", "ch1")
	hide_hud()
	await sim_wait(1.5)  # title card clears
	var error := ""
	for kind: String in MEASURE_KINDS:
		error = await _measure(kind)
		if error != "":
			break
	if error == "":
		await _stills()
	if error != "":
		print("HIT HIGHLIGHT FAIL: " + error)
		finish(1)
		return
	print("HIT HIGHLIGHT PASS: renderer %s" % RenderingServer.get_current_rendering_method())
	finish()


func _measure(kind: String) -> String:
	step("measure " + kind)
	var hdr := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 320)
	vp.transparent_bg = true
	vp.use_hdr_2d = hdr  # linear floats: a 2x tell tint must not clip the ratios
	# Own World3D = no WorldEnvironment: the game's glow and saturation grade
	# would otherwise mix channels and bleed light across the measured pixels.
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var e := Enemy.make(null, kind, Vector2(160, 250), -1, 1.0)
	e.remove_from_group("enemies")  # unseen by room-clear, targeting and AI
	e.process_mode = Node.PROCESS_MODE_DISABLED  # nothing moves between renders
	vp.add_child(e)
	# Body only: the rim, shadows, rings and bars are separate canvas items.
	for c in e.get_children():
		if c is CanvasItem and c != e.sprite:
			(c as CanvasItem).hide()
	for c in e.sprite.get_children():
		if c is CanvasItem:
			(c as CanvasItem).hide()
	var body := e.sprite
	var hit_mat := body.material as ShaderMaterial
	if hit_mat == null:
		vp.queue_free()
		return kind + " has no hit-highlight body material"
	var peak := Balance.MOB_HIT_HIGHLIGHT_STRENGTH
	# pass -> [material on?, hit_strength, modulate]
	var passes := {
		"default": [false, 0.0, TELL],
		"rest": [true, 0.0, TELL],
		"peak": [true, peak, TELL],
		"plain_rest": [true, 0.0, e.base_mod],
		"plain_peak": [true, peak, e.base_mod],
	}
	var caps := {}
	for name: String in passes:
		var p: Array = passes[name]
		body.material = hit_mat if p[0] else null
		hit_mat.set_shader_parameter("hit_strength", p[1])
		body.modulate = p[2]
		await frames(2)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img == null or img.is_empty():
			vp.queue_free()
			return "could not read the %s capture back" % name
		caps[name] = img
	vp.queue_free()
	return _judge(kind, caps, hdr)


## Stats over the body (opaque in the default render), in the space the
## renderer shades in: linear floats on Forward+ (HDR 2D), 8-bit sRGB on
## Compatibility, which does its 2D maths in sRGB (decoding those values would
## make the tint factor drift with brightness through the sRGB curve's toe).
## LDR also skips pixels a tint clipped at 1.0 or left so dark (a 0.5 blue tell
## on dim art) that rounding to 1/255 steps swamps any ratio.
func _judge(kind: String, caps: Dictionary, hdr: bool) -> String:
	var ref: Image = caps["default"]
	var w := ref.get_width()
	var h := ref.get_height()
	var sums := {}
	for name: String in caps:
		sums[name] = Vector4.ZERO  # r, g, b, luminance
	var body_px := 0
	var used := 0
	var pass_diff := 0.0
	var alpha_diff := 0.0
	var srgb_lift := 0.0
	for y in h:
		for x in w:
			var d: Color = ref.get_pixel(x, y)
			if d.a < 0.5:
				continue
			body_px += 1
			var r: Color = (caps["rest"] as Image).get_pixel(x, y)
			var pk: Color = (caps["peak"] as Image).get_pixel(x, y)
			pass_diff = maxf(pass_diff, maxf(maxf(absf(d.r - r.r), absf(d.g - r.g)), absf(d.b - r.b)))
			alpha_diff = maxf(alpha_diff, maxf(absf(d.a - r.a), absf(d.a - pk.a)))
			var clipped := false
			var px := {}
			for name: String in caps:
				var c: Color = (caps[name] as Image).get_pixel(x, y)
				if not hdr and (maxf(c.r, maxf(c.g, c.b)) >= 0.99 or minf(c.r, minf(c.g, c.b)) < 0.04):
					clipped = true
				px[name] = c
			if clipped:
				continue
			used += 1
			for name: String in caps:
				var c: Color = px[name]
				var acc: Vector4 = sums[name]
				sums[name] = acc + Vector4(c.r, c.g, c.b, c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
			var plain_rest: Color = px["plain_rest"]
			var plain_peak: Color = px["plain_peak"]
			if hdr:
				plain_rest = plain_rest.linear_to_srgb()
				plain_peak = plain_peak.linear_to_srgb()
			srgb_lift += plain_peak.get_luminance() - plain_rest.get_luminance()
	if body_px < 200 or used < 100:
		return "%s: too few body pixels to judge (%d body, %d readable)" % [kind, body_px, used]
	var rest: Vector4 = sums["rest"]
	var pk4: Vector4 = sums["peak"]
	var plain_r: Vector4 = sums["plain_rest"]
	var plain_p: Vector4 = sums["plain_peak"]
	var lift := pk4.w / maxf(rest.w, 1e-6)
	var plain_lift := plain_p.w / maxf(plain_r.w, 1e-6)
	# The tell's own R:B factor, read as tell / plain per channel: exactly
	# TELL / base_mod while the tint multiplies AFTER the highlight, whatever
	# the highlight does to the painted colours; a white stomp drives it to 1.
	var tint_rest := (rest.x / maxf(plain_r.x, 1e-6)) / maxf(rest.z / maxf(plain_r.z, 1e-6), 1e-6)
	var tint_peak := (pk4.x / maxf(plain_p.x, 1e-6)) / maxf(pk4.z / maxf(plain_p.z, 1e-6), 1e-6)
	# The painted colours' own balance: a hue-keeping gain lifts R and B alike.
	var painted_shift := (plain_p.x / maxf(plain_r.x, 1e-6)) / maxf(plain_p.z / maxf(plain_r.z, 1e-6), 1e-6)
	var numbers := "%s: %d body px (%d readable), rest-vs-default diff %.4f, alpha diff %.4f, tell lift x%.2f, plain lift x%.2f, tell R:B factor %.2f -> %.2f, painted R:B shift x%.3f, mean plain sRGB lift %.3f" % [
		kind, body_px, used, pass_diff, alpha_diff, lift, plain_lift, tint_rest, tint_peak, painted_shift, srgb_lift / float(used)]
	print("HIT HIGHLIGHT NUMBERS: " + numbers)
	# Half-float HDR readback vs 8-bit LDR quantization.
	var tol := 0.01 if hdr else 3.0 / 255.0
	if pass_diff > tol:
		return "strength 0 does not render like the default material (COLOR trap or lost tint): " + numbers
	if alpha_diff > tol:
		return "the highlight changed the silhouette alpha: " + numbers
	if lift < 1.15 or plain_lift < 1.15:
		return "the peak highlight does not brighten the body: " + numbers
	if absf(tint_peak / maxf(tint_rest, 1e-6) - 1.0) > 0.1:
		return "the peak changed the bite tell's own tint (a white stomp): " + numbers
	if absf(painted_shift - 1.0) > 0.05:
		return "the peak shifted the painted hue (e.g. orange lava going pink): " + numbers
	return ""


func _stills() -> void:
	step("stills")
	var room: int = game.cur_room
	var terrain_before: String = game.terrain_by_zone[room]
	var ambient_before := game.ambient.color
	game.player.set_physics_process(false)
	game.camera.position_smoothing_enabled = false
	zoom(1.2)
	await frames(3)
	# Frame on wherever the camera settled (it follows the hero).
	var center := game.camera.get_screen_center_position() + Vector2(0, -60)
	var mobs: Array[Enemy] = []
	for i in STILL_KINDS.size():
		var kind: String = STILL_KINDS[i]
		var pos := center + Vector2(-320 + i * 280, -60)  # a row above the hero
		var e: Enemy
		if kind == "cinderhide":
			e = Boss.make_boss(game, kind, pos)
			game.add_enemy(e)
		else:
			e = spawn_enemy(kind, pos)
		e.set_physics_process(false)
		e.set_process(false)
		e.hp_bar_bg.hide()
		e.hp_bar_fg.hide()
		mobs.append(e)
	await frames(3)
	for terrain: String in ["keep", "void"]:
		apply_terrain(terrain, room)
		await frames(3)
		for tell in [false, true]:
			var tag := "%s_%s" % [terrain, "tell" if tell else "plain"]
			get_tree().paused = true
			for strength: float in [0.0, Balance.MOB_HIT_HIGHLIGHT_STRENGTH]:
				for e in mobs:
					e.sprite.modulate = TELL if tell else e.base_mod
					(e.sprite.material as ShaderMaterial).set_shader_parameter("hit_strength", strength)
				await frames(2)
				await RenderingServer.frame_post_draw
				shot("%s_%s" % [tag, "peak" if strength > 0.0 else "rest"],
					"wolf / void_shade / cinderhide, hit_strength %.2f" % strength)
			get_tree().paused = false
	for e in mobs:
		e.queue_free()
	apply_terrain(terrain_before, room)
	game.ambient.color = ambient_before
	game.player.set_physics_process(true)
