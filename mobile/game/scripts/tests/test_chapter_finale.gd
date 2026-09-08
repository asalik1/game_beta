extends RefCounted
const Finale := preload("res://scripts/chapter_finale.gd")

class ReaderPlayer extends RefCounted:
	var cls := "mage"
	var cleared := false
	func clear_local_intents() -> void: cleared = true

class ReaderHUD extends Node:
	var dialogue_active := false
	var choices_active := false
	var chat_active := false
	var dialogue_lines: Array = []
	var dialogue_done := Callable()
	var dialogue_box := Control.new()
	func _init() -> void: add_child(dialogue_box)
	func dialogue(lines: Array, callback: Callable) -> void:
		dialogue_active = true
		dialogue_lines = lines
		dialogue_done = callback
	func finish() -> void:
		var callback := dialogue_done
		dialogue_active = false
		dialogue_done = Callable()
		callback.call()
	func _reset_dialogue_chrome() -> void: pass
	func cancel_conversation() -> void:
		dialogue_active = false
		dialogue_done = Callable()
		dialogue_lines = []
		dialogue_box.hide()

class Reader extends Node2D:
	var chapter_id := "qa_unillustrated_chapter"
	var dedicated := false
	var player := ReaderPlayer.new()
	var hud := ReaderHUD.new()
	var cutscene: Control = null
	var menus: Node = null
	func _init() -> void: add_child(hud)
	func has_local_player() -> bool: return not dedicated
	func net_online() -> bool: return false


static func run(t: Node) -> String:
	var reader := Reader.new()
	t.add_child(reader)
	var finale := Finale.new()
	var error := _checks(finale, reader)
	finale.cancel(reader)
	reader.free()
	if error == "":
		print("ok: chapter finales isolate each reader, clear held input, reject duplicate/past callbacks, cancel pending dialogue, reset for a new world and resolve absent-art/dedicated endings")
	return error


static func _checks(finale: RefCounted, reader: Node2D) -> String:
	var calls := {"count": 0}
	var done := func() -> void: calls.count += 1
	var fallback := [["Narrator", "The road falls quiet."]]
	if not finale.play(reader, done, fallback) or not finale.active or not reader.player.cleared:
		return "local ending did not own the pending dialogue/input"
	var old_callback: Callable = reader.hud.dialogue_done
	if finale.play(reader, done, fallback):
		return "repeated victory replaced an active ending"
	finale.cancel(reader)
	old_callback.call()
	if calls.count != 0 or finale.active or reader.hud.dialogue_active or reader.hud.dialogue_done.is_valid():
		return "cancelled ending retained dialogue or delivered stale results"
	if not finale.play(reader, done, fallback):
		return "new world could not start another ending"
	old_callback.call()
	if calls.count != 0:
		return "previous world callback completed the new ending"
	var completed_callback: Callable = reader.hud.dialogue_done
	reader.hud.finish()
	if calls.count != 1 or finale.active or not finale.seen:
		return "local ending did not finish exactly once"
	completed_callback.call()
	if finale.play(reader, done, fallback) or calls.count != 1:
		return "victory repeated after its local results were dismissed"
	finale.cancel(reader)
	finale.play(reader, done, fallback)
	reader.chapter_id = "qa_next_chapter"
	reader.hud.dialogue_done.call()
	if calls.count != 1:
		return "old ending painted its results onto a different chapter"
	finale.cancel(reader)
	reader.dedicated = true
	if not finale.play(reader, done, fallback) or finale.active or calls.count != 2:
		return "dedicated authority waited for a reader"
	finale.cancel(reader)
	reader.dedicated = false
	if not finale.play(reader, done) or finale.active or calls.count != 3:
		return "chapter without a closer or fallback stranded the result"
	return ""
