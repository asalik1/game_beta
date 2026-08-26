class_name FangmootHostStandalone
extends FangmootHost
## The STANDALONE shell for Fangmoot (PROPOSALS/FANGMOOT.md §18). Same game, no
## Crownless campaign: launched with `--fangmoot` (play_fangmoot.bat), it boots
## straight into the Carver's Circle. No game instance is touched — Art is
## static (inherited portrait/clip), and state lives in its own save file.
##
## The whole bestiary is fieldable from the start: there is no world to catalogue
## pieces from, so the standalone hands you the full roster (the "Hunts" unlock
## ladder of §18 is a later refinement). Renown is its own wallet.

const SAVE_PATH := "user://fangmoot_standalone.json"

var _file: Dictionary = {}

func _init() -> void:
	_read()

# --- collection: everything available (no campaign to gate on) ---
func fieldable(_kind: String) -> bool:
	return true

func mastered(_kind: String) -> bool:
	return false

# --- rewards: a self-contained Renown wallet, persisted to the save file ---
func reward(event: String, amount: int) -> void:
	if event == "renown" and amount > 0:
		_file["renown"] = int(_file.get("renown", 0)) + amount
		_write()

func renown() -> int:
	return int(_file.get("renown", 0))

# --- persistence: the fangmoot state dict, in its own file ---
func save_state(dict: Dictionary) -> void:
	_file["fangmoot"] = dict
	_write()

func load_state() -> Dictionary:
	var d = _file.get("fangmoot", {})
	return d if d is Dictionary else {}

func _read() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(txt)
	if data is Dictionary:
		_file = data

func _write() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_file))
		f.close()
