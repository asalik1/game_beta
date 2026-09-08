class_name ShotRig
extends Node
## Base for the in-engine SHOT RIGS (dev-only, `game/shot_*.gd`): boot the
## real game, drive it, screenshot to disk, quit. Subclass it:
##
##   extends ShotRig
##   func _ready() -> void:
##       await boot("mage", "ch1")          # main.tscn, no_saves, class, skip dialogue, god-mode
##       hide_hud(); zoom(2.0)
##       await sim_wait(0.5)
##       shot("meteor_peak")                # user://shots/<rig>/meteor_peak.png
##       finish()
##
## Run it through the runner — `shot.bat <rig> [--timeout=N] [rig args]` — which
## injects the mute flag, gates the compile (INCLUDING the rig script, which
## check_compile's `res://scripts` walk misses) and kills the process if the
## in-engine watchdog can't. Worked example: `shot_fx_series.gd`.
##
## What every rig gets for free (each was a trap the old copy-paste rigs had
## to remember by hand):
##   MUTED    — Master bus muted in `_init` (belt) on top of the runner's
##              `--audio-driver Dummy` (braces). Owner ruling 2026-08-15: rigs
##              boot the real game with music+SFX on a shared machine.
##   WATCHDOG — `--timeout=N` (default TIMEOUT_DEFAULT s; 0 disables): a
##              pause-immune, time_scale-immune Timer that prints RIG TIMEOUT
##              with the last step label, saves `_timeout.png`, and quit(2).
##              Without it a rig whose `await` never resolves sits open forever
##              — and a rig can never be `--headless`, the viewport readback
##              needs a real renderer. N counts from process launch (the first
##              frame's delta includes startup), but a Timer only fires ON a
##              frame: this game's first frame lands ~15-30 s in (Vulkan +
##              main.tscn's synchronous boot), so a wedged FRAME needs the
##              runner's outer kill (`shot.bat`, N+60 s) — the two are a pair.
##   SHOTS    — `shot(name)` → `user://shots/<rig>/<name>.png`, prints the
##              absolute path + paused/state/frame diagnostics on one line.
##   BOOT     — `boot(cls, chapter)` = the 25 lines every rig used to copy
##              (instantiate main.tscn, no_saves, pick chapter/class, skip the
##              opening dialogue, god-mode). `boot_game()` alone for menu rigs.
##   TIME     — `sim_wait(sec)` / `sim_wait_until(t)` accumulate PROCESS delta,
##              never wall clock: the viewport readback in `shot()` costs
##              ~0.1 s, so wall-clock offsets came due together and were shot in
##              ONE frame (shot_fx_series learned this the hard way).
##   ARGS     — `arg("class", "warrior")` / `flag("pin")` over the user args
##              (everything after `--`).
##
## If a subclass overrides `_init()`, call `super()` — the mute and the
## watchdog live there so they run before the game is even instantiated.

const TIMEOUT_DEFAULT := 120.0

var game: Game
var rig_name := ""            # "fx_series" for res://shot_fx_series.gd
var shot_dir := ""            # user://shots/<rig_name>
var last_step := "init"       # what the watchdog reports
var shots_taken := 0
var timeout_s := TIMEOUT_DEFAULT
var sim_t := 0.0              # the sim clock (see sim_wait_until)
var _watchdog: Timer = null


func _init() -> void:
	var sp: String = get_script().resource_path
	rig_name = sp.get_file().get_basename().trim_prefix("shot_")
	shot_dir = "user://shots/%s" % rig_name
	timeout_s = float(arg("timeout", str(TIMEOUT_DEFAULT)))
	# Belt: mute Master no matter how we were launched. Braces: the runner's
	# --audio-driver Dummy (no device is even opened). Both, always.
	AudioServer.set_bus_mute(0, true)
	# The engine strips --audio-driver from OS.get_cmdline_args(), so detect
	# the Dummy driver by its footprint: no real output device enumerated and
	# zero output latency (measured 2026-08-15: real = ["Default", "Speakers
	# (Realtek…)"] + 10.7 ms; Dummy = ["Default"] + 0.0). A machine with no
	# audio device reads the same — and then there is nothing to blare.
	var dummy_driver := AudioServer.get_output_latency() == 0.0 \
		and AudioServer.get_output_device_list().size() <= 1
	if timeout_s > 0.0:
		_watchdog = Timer.new()
		_watchdog.name = "RigWatchdog"
		_watchdog.one_shot = true
		_watchdog.autostart = true
		_watchdog.wait_time = timeout_s
		_watchdog.ignore_time_scale = true
		_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS   # ticks under a paused menu
		_watchdog.timeout.connect(_on_watchdog)
		add_child(_watchdog)
	print("RIG START: %s  timeout=%.0fs  master_muted=%s  dummy_audio_driver=%s" % [
		rig_name, timeout_s, AudioServer.is_bus_mute(0), dummy_driver])
	print("RIG SHOTS DIR: %s" % ProjectSettings.globalize_path(shot_dir))
	if not dummy_driver:
		print("RIG WARN: a REAL audio device is open (no --audio-driver Dummy) — Master is muted as a fallback, but run rigs via shot.bat (or add the flag) per CLAUDE.md.")


func _on_watchdog() -> void:
	print("RIG TIMEOUT: %s exceeded %.0fs at step '%s' (%d shots taken). A rig this slow needs --timeout=N; a rig stuck here has an await that never resolves — see the last STEP/SHOT line." % [
		rig_name, timeout_s, last_step, shots_taken])
	shot("_timeout")
	get_tree().quit(2)


# ---------------------------------------------------------------- args ----

## `--name=value` from the user args (after `--`), else `default`.
func arg(name: String, default: String = "") -> String:
	var key := "--%s=" % name
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key):
			return a.trim_prefix(key)
	return default


## `--name` present in the user args.
func flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + name)


# ---------------------------------------------------------------- time ----

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Advance the sim clock to `t` seconds (process delta), ALWAYS yielding at
## least one frame — two offsets closer together than one frame (a shot's
## viewport readback alone stretches a frame to ~0.14 s) still produce two
## DIFFERENT images; the SHOT line's `sim=` is the true time, the name is
## nominal. Use for a SERIES of offsets measured from one origin:
## `sim_reset()` then `sim_wait_until(0.3)`, `sim_wait_until(0.64)`, … —
## overshoot carries, so the offsets stay absolute instead of drifting.
func sim_wait_until(t: float) -> void:
	await get_tree().process_frame
	sim_t += get_process_delta_time()
	while sim_t < t:
		await get_tree().process_frame
		sim_t += get_process_delta_time()


## Wait `sec` seconds of SIM time from now.
func sim_wait(sec: float) -> void:
	await sim_wait_until(sim_t + sec)


func sim_reset() -> void:
	sim_t = 0.0


func step(label: String) -> void:
	last_step = label
	print("STEP: " + label)


# ---------------------------------------------------------------- boot ----

## Instantiate the real game (no_saves) under this node and let it settle.
## Menu rigs stop here; everything else calls `boot()`.
func boot_game() -> Game:
	step("boot_game")
	var main: PackedScene = load("res://scenes/main.tscn")
	game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await frames(10)
	# Rigs shoot a screen the frame it opens: no shell fade/settle (P2 motion),
	# or the first frame of every menu shot would be a translucent ghost.
	if game.menus != null:
		game.menus.shell_motion = false
	return game


## The standard rig boot: game → chapter → class → skip the opening dialogue
## → god-mode (hp/mp so nothing dies mid-shot). Returns `game`.
func boot(cls: String = "warrior", chapter: String = "ch1", god: bool = true) -> Game:
	await boot_game()
	step("pick_chapter " + chapter)
	game.menus.pick_chapter(chapter)
	await frames(3)
	step("pick_class " + cls)
	game.menus.pick_class(cls)
	await frames(5)
	await skip_dialogue()
	if god:
		god_mode()
	return game


## Click through dialogue/choice prompts (first choice) until the HUD is clear.
func skip_dialogue(max_steps: int = 80) -> void:
	step("skip_dialogue")
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < max_steps:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await frames(2)
		guard += 1


func god_mode() -> void:
	var p := game.player
	p.max_hp = 999999.0
	p.hp = 999999.0
	p.mp = 9999.0


func hide_hud() -> void:
	game.hud.visible = false


func zoom(f: float) -> void:
	game.camera.zoom = Vector2(f, f)


## Repaint a zone through a terrain AND apply its ambient tint (the two always
## go together in rigs; forgetting the tint shot every biome under village light).
func apply_terrain(terrain_id: String, zone: int = 0) -> void:
	game.apply_terrain(zone, terrain_id)
	game.ambient.color = Terrains.get_terrain(terrain_id)["tint"]


## Spawn a mob through the real factory; immortal by default (a durable target).
func spawn_enemy(kind: String, pos: Vector2, immortal: bool = true) -> Enemy:
	var e: Enemy = Enemy.make(game, kind, pos)
	game.add_enemy(e)
	if immortal:
		e.max_hp = 999999.0
		e.hp = 999999.0
	return e


# ---------------------------------------------------------------- shots ----

## HDR2D readback is linear, unlike the image the window displays. Convert
## only HDR renderer captures; Compatibility's LDR image is already sRGB.
## Godot 4.4 ViewportTexture documentation explicitly requires this step.
func capture_image() -> Image:
	var img := get_viewport().get_texture().get_image()
	if get_viewport().use_hdr_2d and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		# Keep float precision through the transfer function. Converting to
		# RGBA8 first crushes near-black panels into coarse colored bands.
		img.convert(Image.FORMAT_RGBAF)
		var samples := img.get_data().to_float32_array()
		var encoded := PackedByteArray()
		encoded.resize(samples.size())
		for i in range(0, samples.size(), 4):
			var srgb := Color(samples[i], samples[i + 1], samples[i + 2], samples[i + 3]).linear_to_srgb()
			encoded[i] = clampi(roundi(srgb.r * 255.0), 0, 255)
			encoded[i + 1] = clampi(roundi(srgb.g * 255.0), 0, 255)
			encoded[i + 2] = clampi(roundi(srgb.b * 255.0), 0, 255)
			encoded[i + 3] = clampi(roundi(srgb.a * 255.0), 0, 255)
		img = Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, encoded)
	return img

## Save the viewport to `user://shots/<rig>/<name>.png`; returns the absolute
## path. `extra` is appended to the diagnostic line (rig-specific state).
func shot(name: String, extra: String = "") -> String:
	var dir := ProjectSettings.globalize_path(shot_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := capture_image()
	var path := "%s/%s.png" % [dir, name]
	img.save_png(path)
	shots_taken += 1
	last_step = "shot " + name
	var st := ""
	if game != null and game.hud != null:
		st = " state=%s dialogue=%s" % [game.state, game.hud.dialogue_active]
	var tail := "" if extra == "" else " " + extra
	print("SHOT: %s  paused=%s%s ts=%.2f pf=%d sim=%.2f%s" % [
		path, get_tree().paused, st, Engine.time_scale, Engine.get_process_frames(), sim_t, tail])
	return path


## Print the summary line the runner parses and quit. 0 = ok, 1 = the rig
## found a defect (mob missing, strip blank…), 2 is reserved for the watchdog.
func finish(code: int = 0) -> void:
	if _watchdog != null:
		_watchdog.stop()
	print("RIG DONE: %s  shots=%d  exit=%d  dir=%s" % [
		rig_name, shots_taken, code, ProjectSettings.globalize_path(shot_dir)])
	get_tree().quit(code)
