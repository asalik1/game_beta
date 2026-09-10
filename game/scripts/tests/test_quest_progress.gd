extends RefCounted
const Progress := preload("res://scripts/quest_progress.gd")
const Guide := preload("res://scripts/quest_guide.gd")

class GuestGuide extends Game:
	func _ready() -> void: pass
	func net_guest() -> bool: return true


static func run(r: Node) -> String:
	var g: Game = r.game
	var saved := {"flags": g.flags.duplicate(true), "counts": g.quest_kills.duplicate(true),
		"key": g.quest_key, "tracked": g.player.tracked_quest}
	var error := _checks(g)
	g.flags = saved.flags
	g.quest_kills = saved.counts
	g.quest_key = saved.key
	g.player.tracked_quest = saved.tracked
	if error == "":
		print("ok: bounded quest mirrors, JSON save projection, guest guide counts and journal quest invalidation")
	return error


static func _checks(g: Game) -> String:
	var bounds := Progress.limits()
	if int(bounds.get("hunter_pack_thinned", 0)) != 3:
		return "authored hunter counter was absent or had the wrong bound"
	var original := {"hunter_pack_thinned": 2}
	var cleaned: Variant = Progress.clean(original)
	if not cleaned is Dictionary or cleaned != original:
		return "valid counter table was rejected"
	cleaned["hunter_pack_thinned"] = 1
	if original.hunter_pack_thinned != 2:
		return "validated table retained an input alias"
	if Progress.clean({}) != {} or Progress.clean(null) != null or Progress.clean([]) != null:
		return "empty authoritative state and malformed state were conflated"
	for value in [-1, 4, true, "2", 2.0, NAN, INF, [], {}]:
		if Progress.clean({"hunter_pack_thinned": value}) != null:
			return "malformed wire count was accepted: " + str(value)
	for key in ["unknown", "sq_kept_hunter_warden", "", 7, "x".repeat(Balance.NET_MAX_FLAG_LEN + 1)]:
		if Progress.clean({key: 1}) != null:
			return "invalid wire counter key was accepted"
	var excessive := {}
	for i in bounds.size() + 1:
		excessive["extra_%d" % i] = 0
	if Progress.clean(excessive) != null:
		return "oversized counter table was accepted"
	var disk := {"hunter_pack_thinned": 2.0, "unknown": 99}
	if Progress.project(disk) != original or disk.hunter_pack_thinned != 2.0 or disk.size() != 2:
		return "JSON-restored counter projection lost work or mutated the save table"
	for pair in [[999999999999.0, 3], [-12.0, 0], [2.5, 0], [NAN, 0], [true, 0]]:
		if Progress.project({"hunter_pack_thinned": pair[0]}) != {"hunter_pack_thinned": pair[1]}:
			return "legacy counter projection did not bound before integer conversion"
	if not Progress.key_ok("") or not Progress.key_ok("fangmaw") \
			or Progress.key_ok("not_authored") or Progress.key_ok(3) \
			or Progress.key_ok("x".repeat(Balance.NET_MAX_QUEST_LEN + 1)):
		return "main quest key validation lost empty worlds or accepted malformed input"
	var packet := {"chapter": g.chapter_id, "wander_seed": g.wander_seed,
		"quest_key": "fangmaw", "quest_kills": original}
	if not Progress.context_ok(g, packet) or Progress.read(packet) == null:
		return "current world packet was rejected"
	var wrong := packet.duplicate(true)
	wrong.wander_seed = g.wander_seed + 1
	if Progress.context_ok(g, wrong):
		return "previous world seed was accepted"
	wrong = packet.duplicate(true)
	wrong.wander_seed = float(g.wander_seed)
	if Progress.context_ok(g, wrong):
		return "wire context coerced a float seed"
	wrong = packet.duplicate(true)
	wrong.chapter = "different"
	if Progress.context_ok(g, wrong):
		return "previous chapter was accepted"
	wrong = packet.duplicate(true)
	wrong.quest_key = "not_authored"
	if Progress.read(wrong) != null:
		return "invalid main text permitted a partial packet application"
	var guide_guest := GuestGuide.new()
	guide_guest.quest_kills = original.duplicate(true)
	var described := Guide.describe(guide_guest, {"kind": "kill", "flag": "hunter_pack_thinned",
		"count": 3, "text": "Thin the pack"})
	guide_guest.free()
	if described != "Thin the pack (2/3)":
		return "guest objective description still hid shared progress"
	var signature := UIActivityRewards._signature(g, "quests")
	g.quest_key = "fangmaw" if g.quest_key != "fangmaw" else "morwen"
	if UIActivityRewards._signature(g, "quests") == signature:
		return "open quest signature ignored the main objective"
	signature = UIActivityRewards._signature(g, "quests")
	g.quest_kills["hunter_pack_thinned"] = int(g.quest_kills.get("hunter_pack_thinned", 0)) + 1
	if UIActivityRewards._signature(g, "quests") == signature:
		return "open quest signature ignored a partial kill"
	signature = UIActivityRewards._signature(g, "quests")
	g.flags["hunter_mark_tower"] = not bool(g.flags.get("hunter_mark_tower", false))
	if UIActivityRewards._signature(g, "quests") == signature:
		return "open quest signature ignored a non-kill step"
	signature = UIActivityRewards._signature(g, "quests")
	g.player.tracked_quest = "hunters_rounds" if g.player.tracked_quest != "hunters_rounds" else ""
	if UIActivityRewards._signature(g, "quests") == signature:
		return "open quest signature ignored local tracking"
	return ""
