extends Node
## One local presentation clock per light source. The authored strip, halo and
## floor light share its phase; only illumination alpha/energy is modulated.
## No gameplay RNG, network state, transforms or whole-prop tint are changed.

var phase := 0.0
var period := Balance.PROP_LIGHT_PERIOD
var value := 1.0
var _source: Node2D
var _frames := 1
var _outputs: Array = []
var _frozen := false


static func attach(source: Node2D, at: Vector2, fps := 0.0) -> Node:
	if source.has_node("Illumination"):
		return source.get_node("Illumination")
	var clock := preload("res://scripts/prop_illumination.gd").new()
	clock.name = "Illumination"
	clock.phase = phase_at(at)
	clock._source = source
	if source is AnimatedSprite2D:
		var spr := source as AnimatedSprite2D
		clock._frames = spr.sprite_frames.get_frame_count(spr.animation)
		fps = spr.sprite_frames.get_animation_speed(spr.animation)
		spr.pause()
	elif source is Sprite2D and fps > 0.0:
		clock._frames = (source as Sprite2D).hframes
	# A single-frame source has no strip to follow; keep the slow static period
	# rather than pulsing its lights at the strip's frame rate.
	if fps > 0.0 and clock._frames > 1:
		clock.period = float(clock._frames) / fps
	source.add_child(clock)
	clock.advance(0.0)
	return clock


static func phase_at(at: Vector2) -> float:
	# Position identity survives rebuilds and does not consume gameplay RNG.
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s" % at).hash()
	return rng.randf()


func bind(light: Node2D) -> void:
	var property := "energy" if light is PointLight2D else "modulate:a"
	var path := NodePath(property)
	_outputs.append({"node": weakref(light), "property": property, "path": path,
		"peak": float(light.get_indexed(path))})
	_apply()


## A sealed prop holds still: the strip stays on whatever frame the sealer
## parks it on, and its lights stop breathing.
func freeze() -> void:
	_frozen = true
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _frozen:
		return
	phase = fposmod(phase + delta / period, 1.0)
	if _frames > 1:
		var frame_at := phase * _frames
		var frame := int(frame_at)
		if _source is AnimatedSprite2D:
			(_source as AnimatedSprite2D).set_frame_and_progress(frame, fposmod(frame_at, 1.0))
		elif (_source as Sprite2D).frame != frame:
			# Sprite2D.set_frame emits frame_changed on every call, and the cast
			# shadow resyncs on that signal, so only write a real frame change.
			(_source as Sprite2D).frame = frame
	value = lerpf(Balance.PROP_LIGHT_LOW, 1.0, (sin(phase * TAU) + 1.0) * 0.5)
	_apply()


func _apply() -> void:
	for output: Dictionary in _outputs:
		var light: Node2D = output["node"].get_ref()
		if light != null:
			light.set_indexed(output["path"], float(output["peak"]) * value)
