extends Control
## Menus owns this sibling of the disposable shell. It never owns input.

var painting: Control
var embers: CPUParticles2D
var dim: ColorRect
var elapsed := 0.0
var _dim_tween: Tween
var _stage: Control = null  # procedural fallback, authored in canvas coordinates


func _ready() -> void:
	name = "BootBackdrop"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	var night := ColorRect.new()
	night.color = Balance.BOOT_NIGHT
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	painting = Control.new()
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painting)
	var covers := UICover._covers()
	if covers.is_empty():
		# Seated back on the canvas origin, so only the drift moves the crown
		# relative to the independently drawn wordmark.
		_stage = Control.new()
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painting.add_child(_stage)
		UICover._procedural(_stage)
	else:
		var back := TextureRect.new()
		back.texture = covers[0]
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		painting.add_child(back)
		if covers.size() > 1:
			UICover._cycle(painting, back, covers)
	for child in painting.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embers = CPUParticles2D.new()
	embers.texture = Art.tex("spark")
	embers.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	embers.amount = Balance.BOOT_EMBER_COUNT
	embers.lifetime = Balance.BOOT_EMBER_LIFE
	embers.preprocess = Balance.BOOT_EMBER_LIFE
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.direction = Vector2.UP
	embers.spread = Balance.BOOT_EMBER_SPREAD
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = Balance.BOOT_EMBER_SPEED.x
	embers.initial_velocity_max = Balance.BOOT_EMBER_SPEED.y
	embers.scale_amount_min = Balance.BOOT_EMBER_SCALE.x
	embers.scale_amount_max = Balance.BOOT_EMBER_SCALE.y
	embers.color = Balance.BOOT_EMBER_COLOR
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(Balance.BOOT_EMBER_FADE_IN, Color.WHITE)
	fade.add_point(Balance.BOOT_EMBER_FADE_OUT, Color.WHITE)
	embers.color_ramp = fade
	add_child(embers)
	dim = ColorRect.new()
	dim.color = Color(Balance.BOOT_NIGHT, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	elapsed += delta
	_drift()


func _layout() -> void:
	if painting == null:
		return
	painting.size = size * (1.0 + Balance.BOOT_OVERSCAN * 2.0)
	if _stage != null:
		_stage.position = size * Balance.BOOT_OVERSCAN
	embers.position = size * Balance.BOOT_EMBER_ORIGIN
	embers.emission_rect_extents = size * Balance.BOOT_EMBER_EXTENTS
	_drift()


func _drift() -> void:
	var phase := elapsed * TAU / Balance.BOOT_DRIFT_PERIOD
	painting.position = -size * Balance.BOOT_OVERSCAN \
		+ size * Balance.BOOT_DRIFT_RANGE * Vector2(sin(phase), cos(phase))


func set_panel_dim(panel: bool, animate: bool) -> void:
	var alpha := Balance.BOOT_PANEL_DIM if panel else 0.0
	if _dim_tween != null:
		_dim_tween.kill()
	if animate:
		_dim_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_dim_tween.tween_property(dim, "color:a", alpha, Balance.BOOT_NAV_TIME)
	else:
		dim.color.a = alpha
