extends Control
## Compact cast feedback and directional evidence of a blow that actually hit.
## Bearings never predict attacks or expose enemies before they attack.

var game: Game
var notice: Label
var notice_panel: PanelContainer
var _notice_t := 0.0
var _notice_slot := ""
var _bearings: Array[Dictionary] = []
var _hero_id := 0
var target_cue: Label
const Cues := preload("res://scripts/combat_cues.gd")


func _ready() -> void:
	name = "CombatFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice_panel = PanelContainer.new()
	notice_panel.position = Vector2(440, 534)
	notice_panel.size = Vector2(400, 34)
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.045, 0.06, 0.94)
	frame.border_color = Color(UITheme.GOLD, 0.5)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(8)
	frame.set_content_margin_all(8)
	notice_panel.add_theme_stylebox_override("panel", frame)
	add_child(notice_panel)
	notice = Label.new()
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 14)
	notice.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	if UITheme.body_font() != null:
		notice.add_theme_font_override("font", UITheme.body_font())
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.add_child(notice)
	notice_panel.hide()
	target_cue = Label.new()
	target_cue.name = "TargetCombatCue"
	target_cue.position = Vector2(400, 124)
	target_cue.size = Vector2(480, 24)
	target_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.world(target_cue, 14, 2)
	if UITheme.body_bold_font() != null:
		target_cue.add_theme_font_override("font", UITheme.body_bold_font())
	add_child(target_cue)
	target_cue.hide()


func ability_notice(slot: String, why: String) -> void:
	if not is_instance_valid(game.local_player):
		return
	var ability: Dictionary = Classes.CLASSES[game.local_player.cls]["abilities"].get(slot, {})
	notice.text = "%s · %s" % [String(ability.get("name", slot)), why]
	_notice_slot = slot
	_notice_t = Balance.ABILITY_NOTICE_SECONDS


func ability_fired(slot: String) -> void:
	if _notice_slot == slot:
		_notice_t = 0.0
		notice_panel.hide()


func hit(from: Vector2, heavy: bool) -> void:
	if from.is_zero_approx():
		return
	_bearings.append({"direction": from.normalized(), "time": Balance.DAMAGE_BEARING_SECONDS, "heavy": heavy})
	while _bearings.size() > 4:
		_bearings.pop_front()


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game.local_player):
		hide()
		return
	var p: Player = game.local_player
	if _hero_id != p.get_instance_id():
		_hero_id = p.get_instance_id()
		_bearings.clear()
		_notice_t = 0.0
	_notice_t = maxf(0.0, _notice_t - delta)
	for i in range(_bearings.size() - 1, -1, -1):
		_bearings[i]["time"] -= delta
		if float(_bearings[i]["time"]) <= 0.0:
			_bearings.remove_at(i)
	visible = game.play_started and game.state == Game.ST_PLAYING and not p.dead \
		and not p.downed and not game.input_overlay_up()
	notice_panel.visible = _notice_t > 0.0
	notice_panel.modulate.a = minf(1.0, _notice_t * 4.0)
	var target: CharacterBody2D = game.hud.target_bar_unit
	# This HUD processes while solo menus pause Game's target refresh. A
	# just-freed opponent must be checked before any typed cast or class test.
	if not is_instance_valid(target):
		target = null
	var cue := Cues.code_for(target as Enemy)
	target_cue.position = Vector2(390, 104) if target is Boss else Vector2(400, 102)
	target_cue.size = Vector2(350, 20) if target is Boss else Vector2(480, 20)
	target_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if target is Boss else HORIZONTAL_ALIGNMENT_CENTER
	target_cue.visible = cue != Cues.Cue.NONE
	target_cue.text = String(Cues.TEXT.get(cue, ""))
	target_cue.add_theme_color_override("font_color", Cues.tint(cue))
	queue_redraw()


func _draw() -> void:
	if not visible or not bool(game.settings.get("damage_bearings", true)):
		return
	var center := game.get_viewport().get_canvas_transform() * game.local_player.global_position
	for entry in _bearings:
		var dir: Vector2 = entry["direction"]
		var alpha := clampf(float(entry["time"]) / Balance.DAMAGE_BEARING_SECONDS, 0, 1)
		var angle := dir.angle()
		var tint := Color(1.0, 0.67, 0.27, alpha) if entry["heavy"] else Color(1.0, 0.32, 0.26, alpha)
		draw_arc(center, 72, angle - 0.27, angle + 0.27, 18, Color(0.02, 0.02, 0.03, alpha * 0.8), 7, true)
		draw_arc(center, 72, angle - 0.25, angle + 0.25, 18, tint, 3, true)
		if entry["heavy"]:
			draw_arc(center, 78, angle - 0.15, angle + 0.15, 12, tint, 2, true)
