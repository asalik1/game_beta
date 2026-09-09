extends Control
## One shared cast readout in the target HUD, plus brackets on the casting
## body. Damage fills the broad amber bar; the thin white fuse counts down.

var game: Game
var boss: Boss
var title: Label
var instruction: Label
var clock: Label
const Cast := preload("res://scripts/boss_cast.gd")
const AMBER := Color(1.0, 0.76, 0.36)
const MINT := Color(0.59, 1.0, 0.81)
const PANEL := Rect2(390, 128, 500, 67)


func _ready() -> void:
	name = "BossCastReadout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = _label(Vector2(406, 134), Vector2(376, 20), 15)
	clock = _label(Vector2(790, 134), Vector2(84, 20), 14)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	instruction = _label(Vector2(406, 171), Vector2(468, 20), 13)
	hide()


func _label(at: Vector2, bounds: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = bounds
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.world(label, font_size, 2)
	if UITheme.body_bold_font() != null:
		label.add_theme_font_override("font", UITheme.body_bold_font())
	add_child(label)
	return label


func _process(_delta: float) -> void:
	visible = false
	boss = null
	if game == null or not is_instance_valid(game.local_player) or not game.play_started \
			or game.state != Game.ST_PLAYING or game.local_player.dead or game.local_player.downed \
			or game.input_overlay_up():
		return
	var tracked: CharacterBody2D = game.hud.target_bar_unit
	if is_instance_valid(tracked) and tracked is Boss and not tracked.dying and tracked.cast_window.phase != "":
		boss = tracked
	else:
		# Auto-aim can drift onto an add during a cast. Keep the commitment
		# readable without changing the player's aim or revealing another room.
		for other in game.bosses:
			if is_instance_valid(other) and not other.dying and other.cast_window.phase != "" \
					and (other.zone_idx < 0 or other.zone_idx == game.cur_room) \
					and game.local_player.global_position.distance_to(other.global_position) < Balance.BOSS_BREAK_NOTICE_RANGE:
				boss = other
				break
	if boss == null:
		return
	visible = true
	var cast = boss.cast_window
	var broken: bool = cast.phase == "broken"
	var tint: Color = MINT if broken else AMBER
	title.text = ("BROKEN · " if broken else "INTERRUPT · ") + String(Cast.MOVES[cast.kind].name)
	clock.text = "%.1fs" % (cast.exposed if broken else cast.remaining)
	instruction.text = "Attack now · +%d%% damage" % int(round((Balance.BOSS_BREAK_DAMAGE_MULT - 1.0) * 100.0)) if broken \
		else "Deal damage to fill the bar · Close hits build more pressure"
	for label in [title, clock]:
		label.add_theme_color_override("font_color", tint)
	instruction.add_theme_color_override("font_color", Color(0.88, 0.89, 0.91))
	queue_redraw()


func _draw() -> void:
	if not visible or not is_instance_valid(boss):
		return
	var cast = boss.cast_window
	var broken: bool = cast.phase == "broken"
	var tint: Color = MINT if broken else AMBER
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025, 0.035, 0.045, 0.94)
	frame.border_color = Color(tint, 0.7)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(5)
	draw_style_box(frame, PANEL)
	var bar := Rect2(406, 158, 468, 8)
	draw_rect(bar, Color(0.15, 0.17, 0.20))
	var fraction: float = cast.exposed / Balance.BOSS_BREAK_EXPOSED if broken else cast.pressure / maxf(1.0, cast.goal)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)), tint)
	for i in range(1, 5):
		var x: float = bar.position.x + bar.size.x * float(i) / 5.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0.035, 0.045, 0.06), 2)
	if not broken:
		var fuse: float = clampf(cast.remaining / maxf(0.001, cast.duration), 0.0, 1.0)
		draw_line(Vector2(406, 169), Vector2(406 + 468 * fuse, 169), Color(0.93, 0.95, 1.0), 2)
	# Screen-space brackets stay readable at every camera zoom and never
	# masquerade as a ground damage radius. Four corners surround the body.
	var center: Vector2 = game.get_viewport().get_canvas_transform() * (boss.global_position + Vector2(0, -50))
	# Header reflow moves this Control; world brackets remain at the actor.
	center = get_global_transform().affine_inverse() * center
	var radius := 36.0
	for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner: Vector2 = center + direction * radius
		draw_polyline(PackedVector2Array([corner - Vector2(direction.x * 13, 0), corner,
			corner - Vector2(0, direction.y * 13)]), Color(0.01, 0.02, 0.025, 0.9), 6, true)
		draw_polyline(PackedVector2Array([corner - Vector2(direction.x * 13, 0), corner,
			corner - Vector2(0, direction.y * 13)]), tint, 2, true)
