class_name FangmootHost
extends RefCounted
## The one seam between Fangmoot and its host (Crownless, or a future
## standalone). PROPOSALS/FANGMOOT.md §18. Nothing under game/scripts/fangmoot/
## except fangmoot_host_crownless.gd may reach into the game instance, the save
## system, Art or Renown directly; everything routes through here so graduation
## is a re-shell rather than a rewrite.
##
## The pure layer (sim, moot, bot, codes) only calls fieldable/mastered/reward/
## save/load. Portrait and clip lookups (Art) are used by the renderer, which
## already runs inside Crownless, so they live on the concrete host.
##
## This base is a fully-usable stub: everything fieldable, no rewards, no
## persistence. The bench and headless tests use it directly.

func fieldable(_kind: String) -> bool:
	return true

func mastered(_kind: String) -> bool:
	return false

func reward(_event: String, _amount: int) -> void:
	pass

func save_state(_dict: Dictionary) -> void:
	pass

func load_state() -> Dictionary:
	return {}

# --- art (renderer only) — engine-static, no game instance needed, so both the
# Crownless and standalone shells inherit these unchanged. ---
func portrait(kind: String) -> Texture2D:
	return Art.tex(_sprite_key(kind))

func clip(kind: String, action: String) -> Dictionary:
	var sprite := _sprite_key(kind)
	if action == "idle":
		return Art.anim_info(sprite)
	return Art.action_info(sprite, action)

func _sprite_key(kind: String) -> String:
	# a token id is a real enemy/boss kind; its art key is the row's "sprite".
	if Story.ALL_ENEMIES.has(kind):
		return String(Story.ALL_ENEMIES[kind].get("sprite", kind))
	return kind
