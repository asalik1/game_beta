extends Node2D
## Visible consequences on the props whose conversations already own the flags.
const MARKS := {
	"lore_ravine": "hunter_mark_ravine", "lore_ravine_edge": "hunter_mark_ravine",
	"lore_drowned_chapel": "hunter_mark_chapel", "lore_collapsed_tower": "hunter_mark_tower",
}
var game: Game
var profile := ""
var age := 0.0
var sign: Sprite2D


func _ready() -> void:
	if MARKS.has(profile):
		sign = Sprite2D.new()
		sign.texture = Art.tex("signpost")
		sign.scale = Vector2.ONE * 64.0 / sign.texture.get_height()
		sign.position = Vector2(-22, -25)
		sign.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sign)


static func attach(g: Game, npc: Node2D, key: String) -> void:
	if not MARKS.has(key) and key != "lore_hollow_oak":
		return
	var mark := new()
	mark.game = g
	mark.profile = key
	mark.position = Vector2(76, 0)
	npc.add_child(mark)


func _process(delta: float) -> void:
	if game.room_at_pos(global_position) != game.cur_room:
		return
	age += delta
	if sign != null:
		sign.visible = game.get_flag(String(MARKS.get(profile, "")), false) or game.get_flag("sq_kept_hunter_warden", false)
	queue_redraw()


func _draw() -> void:
	var signed: bool = game.get_flag(String(MARKS.get(profile, "")), false) or game.get_flag("sq_kept_hunter_warden", false)
	if MARKS.has(profile) and signed:
		# A small crossed trail blaze on a planted, weathered sign.
		draw_line(Vector2(-26, -41), Vector2(-15, -35), Color(0.96, 0.83, 0.58), 2, true)
		draw_line(Vector2(-15, -41), Vector2(-26, -35), Color(0.96, 0.83, 0.58), 2, true)
	if profile == "lore_drowned_chapel" and (game.get_flag("pine_lit", false) or game.get_flag("sq_kept_flame_lit", false)):
		var flame := Vector2(20, -35)
		for i in range(4, 0, -1):
			draw_circle(flame, i * 12.0, Color(1.0, 0.66, 0.20, 0.035), true, -1, true)
		draw_line(Vector2(20, 3), flame, Color(0.59, 0.33, 0.13), 5, true)
		var lean := sin(age * 4.0) * 2.5
		draw_colored_polygon(PackedVector2Array([flame + Vector2(-6, 1), flame + Vector2(lean, -22), flame + Vector2(7, -4), flame + Vector2(3, 5)]), Color(1.0, 0.64, 0.18))
		draw_circle(flame + Vector2(0, -4), 3, Color(1.0, 0.94, 0.64), true, -1, true)
	if profile == "lore_hollow_oak" and game.get_flag("sq_kept_oak_debt", false):
		# Osla leaves a tied blue ribbon after her father's debt is settled.
		draw_line(Vector2(0, -42), Vector2(0, 0), Color(0.28, 0.22, 0.15), 4, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -37), Vector2(24, -34 + sin(age) * 2), Vector2(16, -25), Vector2(27, -18), Vector2(0, -23)]), Color(0.38, 0.74, 0.84))
