extends RefCounted
## Durable personal flags. The host still owns ordinary run/story state.

const PREFIXES := [
	"opened_", "chose_", "completed_", "cap_", "first_clear_paid_",
	"saw_chapter_opening_", "sq_kept_", "tut_",
]
const FLAGS := ["owned_the_harm", "excused_the_harm", "walked_away",
	"gave_back", "kept_taking", "fled_theft", "told_truth", "hid_truth",
	"left_silent", "said_farewell", "cut_clean", "walked_silent",
	"delivered_verdict", "spared_guilty", "recused", "closed_tome",
	"borrowed_more", "burned_pages"]


static func is_kept(key: String) -> bool:
	if key in FLAGS or key in Story.chapter_opener_flags():
		return true
	for prefix in PREFIXES:
		if key.begins_with(prefix):
			return true
	return false


static func is_local(key: String) -> bool:
	if is_kept(key):
		return true
	for prefix in ["cache_", "hidden_", "shrined_"]:
		if key.begins_with(prefix):
			return true
	return false


static func is_saved(key: String) -> bool:
	# These six records have their own validated character field. Never let
	# a duplicate flag record override the canonical rescued_pets array.
	if key.begins_with("sq_kept_rescue_"):
		return false
	if is_kept(key):
		return true
	# Keep an unscoped quest's payment marker with its durable step flags.
	# Otherwise restored steps can pay again against the old home acceptance.
	# This matches chapter-wipe persistence; live party routing is unchanged.
	for prefix in ["sq_on_", "sq_paid_", "sq_pledge_"]:
		if key.begins_with(prefix):
			Story.load_content()
			var id := key.trim_prefix(prefix)
			return Story.ALL_SIDE_QUESTS.has(id) and not Story.quest_scoped(Story.ALL_SIDE_QUESTS[id])
	return false


static func world_only(raw) -> Dictionary:
	var result: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	for key in result.keys():
		if key is String and is_local(key):
			result.erase(key)
	return result


static func clean(raw) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for key in raw:
		if not key is String or not is_saved(key):
			continue
		var value = raw[key]
		if value is bool or value is String or value is int or (value is float and is_finite(value)):
			result[key] = value
	return result


static func legacy(world_flags, achievements) -> Dictionary:
	var result := clean(world_flags)
	# Older guest saves can retain their OWN clear achievement even when the
	# old world-only completed flag was lost. Account unlocks are not evidence.
	if achievements is Array:
		Story.load_content()
		for id in Story.CHAPTER_LIST:
			if ("clear_" + String(id)) in achievements:
				result["completed_" + String(id)] = true
		for id in Story.STANDALONE_WORLDS:
			if ("clear_" + String(id)) in achievements:
				result["completed_" + String(id)] = true
	return result


static func merge(world_flags, personal) -> Dictionary:
	var result: Dictionary = world_flags.duplicate(true) if world_flags is Dictionary else {}
	for key in result.keys():
		if key is String and is_saved(key):
			result.erase(key)
	result.merge(clean(personal), true)
	return result
