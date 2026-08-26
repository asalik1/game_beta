class_name FangmootHostCrownless
extends FangmootHost
## The Crownless implementation of the Fangmoot seam. PROPOSALS/FANGMOOT.md §18.
## This is the ONLY file under scripts/fangmoot/ permitted to touch the game
## instance, Renown, kill_counts, boss_done, Art or Lore (the seam lint in
## autotest enforces it). Swapping this file re-shells Fangmoot as a standalone.

var game: Node   # the running Game (game_base <- ... <- game.gd)

func _init(g: Node = null) -> void:
	game = g

# --- collection: "field what you have faced" (§10) ---
func fieldable(kind: String) -> bool:
	# Tiers 1-2 are the Carver's stock, always available.
	if FangmootData.TOKENS.has(kind) and int(FangmootData.TOKENS[kind]["tier"]) <= 2:
		return true
	if game == null:
		return true
	if FangmootData.is_named(kind):
		return bool(game.boss_done.get(kind, false))
	return int(game.kill_counts.get(kind, 0)) > 0

func mastered(kind: String) -> bool:
	if game == null:
		return false
	return int(game.kill_counts.get(kind, 0)) >= Lore.threshold(kind)

# --- rewards: Renown only, never power (§9) ---
func reward(event: String, amount: int) -> void:
	if game == null:
		return
	match event:
		"renown":
			game.add_renown(amount)
		"achievement":
			pass  # title ids handled by title_available; wired in Phase 3

# --- persistence: one key in the character save (§14) ---
func save_state(dict: Dictionary) -> void:
	if game == null:
		return
	game.set("fangmoot", dict)
	if game.has_method("autosave"):
		game.autosave()

func load_state() -> Dictionary:
	if game == null:
		return {}
	var d = game.get("fangmoot")
	return d if d is Dictionary else {}

# portrait() / clip() are inherited from FangmootHost (engine-static Art lookups).
