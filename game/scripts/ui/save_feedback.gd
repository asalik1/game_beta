extends CanvasLayer
## Character-save outcomes, independent of menus and the hidden gameplay HUD.
## Presentation only: never writes, retries, rolls back or changes pause/input.

const NODE_NAME := "CharacterSaveFeedback"
const FAILURE_TEXT := "Saving failed. Recent progress is only in this session; check free space or access to your save folder."
const RECOVERY_TEXT := "Progress saved."
const RECOVERY_SECONDS := 4.0
const GAMEPLAY_FAILURE_TEXT := "Saving failed.\nRecent progress is not saved.\nCheck free space or save access."
const GAMEPLAY_SIZE := Vector2(280, 68)
const MENU_SIZE := Vector2(920, 24)
const EDGE_INSET := 16.0
const GAMEPLAY_TOP := 8.0
const MENU_TOP := 1.0

var _game: WeakRef
var _owner: WeakRef
var _slot := -1
var _failed := false
var _recovery_until_ms := 0
var _bar: PanelContainer
var _label: Label


## Called only after the real atomic write returns. Other-slot exports cannot
## clear a failure on the active hero's file. Successful saves allocate no UI.
static func record(game: Game, slot: int, saved: bool) -> void:
	if not is_instance_valid(game) or game.is_queued_for_deletion() \
			or not game.has_local_player() or game.dedicated \
			or slot <= 0 or game.save_slot != slot or not game.is_inside_tree():
		return
	var feedback: Node = game.get_node_or_null(NodePath(NODE_NAME))
	if feedback == null:
		if saved:
			return
		feedback = new()
		feedback.name = NODE_NAME
		game.add_child(feedback)
	feedback.call("_record", game, slot, saved)


func _ready() -> void:
	layer = 80  # above menus (20), below the gamepad pointer (90)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bar = PanelContainer.new()
	_bar.name = "SaveFeedbackBar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	UITheme.apply(_bar)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.045, 0.025, 0.99)
	style.border_color = Color(1.0, 0.70, 0.30)
	style.border_width_bottom = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_bar.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.name = "SaveFeedbackText"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 16)
	_bar.add_child(_label)
	visible = false
	set_process(false)


func _record(game: Game, slot: int, saved: bool) -> void:
	var same_owner: bool = _game != null and _game.get_ref() == game \
		and _owner != null and _owner.get_ref() == game.local_player and _slot == slot
	if saved:
		if same_owner and _failed:
			_failed = false
			_label.text = RECOVERY_TEXT
			_label.add_theme_color_override("font_color", Color(0.73, 1.0, 0.77))
			_recovery_until_ms = Time.get_ticks_msec() + roundi(RECOVERY_SECONDS * 1000.0)
		elif not same_owner:
			_clear()
		return
	_game = weakref(game)
	_owner = weakref(game.local_player)
	_slot = slot
	_failed = true
	_recovery_until_ms = 0
	_label.text = FAILURE_TEXT
	_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55))
	visible = true
	set_process(true)
	_layout()


func _clear() -> void:
	visible = false
	_failed = false
	_game = null
	_owner = null
	_slot = -1
	_recovery_until_ms = 0
	set_process(false)


func _process(_delta: float) -> void:
	var game: Game = _game.get_ref() as Game if _game != null else null
	var owner: Player = _owner.get_ref() as Player if _owner != null else null
	if not is_instance_valid(game) or not is_instance_valid(owner) \
			or owner.is_queued_for_deletion() or game.local_player != owner or game.save_slot != _slot:
		_clear()
		return
	if not _failed and Time.get_ticks_msec() >= _recovery_until_ms:
		_clear()
		return
	_layout()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var game: Game = _game.get_ref() as Game if _game != null else null
	var menus: Menus = game.menus if is_instance_valid(game) else null
	var in_menu := is_instance_valid(menus) and menus.is_open()
	var wanted: Vector2 = MENU_SIZE if in_menu else GAMEPLAY_SIZE
	wanted.x = minf(wanted.x, maxf(1.0, viewport_size.x - EDGE_INSET * 2.0))
	var copy := RECOVERY_TEXT
	if _failed:
		copy = FAILURE_TEXT if in_menu else GAMEPLAY_FAILURE_TEXT
	if _label.text != copy:
		_label.text = copy
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF if in_menu else TextServer.AUTOWRAP_WORD_SMART
	var at := Vector2(maxf(0.0, viewport_size.x - EDGE_INSET - wanted.x), GAMEPLAY_TOP)
	if in_menu:
		at = Vector2((viewport_size.x - wanted.x) * 0.5, _menu_top(menus))
	_bar.position = at
	_bar.size = wanted


func _menu_top(menus: Menus) -> float:
	# Ordinary shells keep action controls below the top status row or outside
	# its 920px span. This may cover a little title/frame chrome in a full-height
	# shell; native clearance checks still protect dismissal and action targets.
	if menus.current == "fangmoot":
		# The active board/fight has a 62px topbar with crests/scars and Concede.
		# Its arena starts directly beneath it. Use the arena's actual origin,
		# including the FINAL fight (fm_moot.done is already true during playback).
		# The hub's backdrop starts at zero; the result uses an ordinary shell.
		for child in menus.root.get_children():
			if child is SubViewportContainer and child.position.y > 0.0:
				return child.get_global_rect().position.y + 1.0
	return MENU_TOP
