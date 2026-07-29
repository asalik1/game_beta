extends Node2D
## ACT 2 ART RIG (dev-only)
## Loads every canonical visual through Art's live sprite seams, plays its walk
## row, checks the four installed clip families, and captures paged contact shots.
## Run:
##   godot --path game res://shot_act2_art.tscn

const CATALOG := "res://assets/act2_visual_catalog.json"
const COLS := 4
const ROWS := 3
const PAGE_SIZE := COLS * ROWS
const CELL := Vector2(300.0, 205.0)
const ORIGIN := Vector2(190.0, 120.0)

var _visuals: Array[Sprite2D] = []
var _labels: Array[Label] = []
var _entries: Array = []
var _page := 0
var _elapsed := 0.0
var _fails: Array[String] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#10131a"))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not parsed is Dictionary:
		push_error("ACT2 ART: catalog parse failed")
		get_tree().quit(1)
		return
	for chapter in parsed.get("chapters", []):
		for entry in chapter.get("entries", []):
			var item: Dictionary = entry.duplicate()
			item["chapter"] = chapter.get("chapter", 0)
			_entries.append(item)
	_show_page()
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_pages()


func _process(delta: float) -> void:
	_elapsed += delta
	var frame := int(_elapsed * 6.0) % 4
	for sprite in _visuals:
		sprite.frame = frame


func _clear_page() -> void:
	for sprite in _visuals:
		sprite.queue_free()
	for label in _labels:
		label.queue_free()
	_visuals.clear()
	_labels.clear()


func _show_page() -> void:
	_clear_page()
	var start := _page * PAGE_SIZE
	var stop := mini(start + PAGE_SIZE, _entries.size())
	for index in range(start, stop):
		var entry: Dictionary = _entries[index]
		var slot := index - start
		var position := ORIGIN + Vector2(slot % COLS, slot / COLS) * CELL
		var key: String = entry.key
		var walk := Art.walk_info(key)
		var idle := Art.anim_info(key)
		var attack := Art.action_info(key, "attack")
		var death := Art.action_info(key, "death")
		if walk.is_empty() or idle.is_empty() or attack.is_empty() or death.is_empty():
			_fails.append("%s missing a clip family" % key)
			continue
		if walk.frames != 4 or idle.frames != 4 or attack.frames != 4 or death.frames != 4:
			_fails.append("%s does not have four frames per clip" % key)

		var sprite := Sprite2D.new()
		sprite.texture = walk.tex
		sprite.hframes = walk.frames
		sprite.position = position
		sprite.scale = Vector2.ONE * 0.55
		add_child(sprite)
		_visuals.append(sprite)

		var label := Label.new()
		label.text = "Ch. %d · %s\n%s" % [entry.chapter, entry.name, key]
		label.position = position + Vector2(-135, 82)
		label.size = Vector2(270, 45)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override(
			"font_color",
			Color("#f0b85a") if entry.kind == "boss" else Color("#dce3ef")
		)
		add_child(label)
		_labels.append(label)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT SKIPPED (headless renderer): ", name)
		return
	var folder := ProjectSettings.globalize_path("user://shots/act2_art")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join(name + ".png")
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("SHOT SKIPPED (headless renderer): ", name)
		return
	image.save_png(path)
	print("SHOT: ", path)


func _capture_pages() -> void:
	var pages := ceili(float(_entries.size()) / PAGE_SIZE)
	for page in pages:
		_page = page
		_show_page()
		await get_tree().process_frame
		await get_tree().process_frame
		_shot("page_%02d" % (page + 1))
	print("ACT2 ART: %d visuals, %d page(s), %d failure(s)" % [
		_entries.size(), pages, _fails.size()
	])
	for failure in _fails:
		print("FAIL ", failure)
	get_tree().quit(1 if not _fails.is_empty() else 0)
