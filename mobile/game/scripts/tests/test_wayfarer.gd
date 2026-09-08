extends RefCounted
const Escort := preload("res://scripts/wayfarer.gd")


static func run(t: Node) -> String:
	var g: Game = t.game
	var old_flags := g.flags.duplicate(true)
	var old_interactables := g.interactables.duplicate()
	var old_cache := g._quest_avail_cache
	var old_marks := g.quest_marks.duplicate()
	var actor := Node2D.new()
	actor.set_meta("quest_convo", "wayfarer_tovin")
	g.world.add_child(actor)
	g.interactables.append({"node": actor})
	var v := Escort.new()
	v.game = g
	v.zone = g.cur_room
	v.start = g.room_center(g.cur_room) - Vector2(100, 0)
	v.goal = v.start + Vector2(200, 0)
	v.position = v.start
	var error := _checks(g, v)
	v.free()
	actor.free()
	g.flags = old_flags
	g.interactables = old_interactables
	g._quest_avail_cache = old_cache
	g.quest_marks = old_marks
	if error == "":
		print("ok: escort content, physical quest-giver discovery, completed-story retirement, finite/path snapshot guards and completion prerequisites")
	return error


static func _checks(g: Game, v: Node2D) -> String:
	# The traveling giver dies with room scenery, before every flag refresh.
	var stale := Label.new()
	var live := Label.new()
	g.quest_marks = [{"node": stale, "quests": []}, {"node": live, "quests": []}]
	stale.free()
	g.refresh_quest_marks()
	var cleaned: bool = g.quest_marks.size() == 1 and g.quest_marks[0]["node"] == live
	live.free()
	g.refresh_quest_marks()
	if not cleaned or not g.quest_marks.is_empty():
		return "freed quest-giver marks were not safely retired"
	# Exercise the actual world renderer against the installed painted crops.
	# A missing width profile previously made a garden leaf taller than a house.
	for name in ["crop_carrot", "crop_cabbage", "crop_turnip", "crop_mid", "crop_sprout", "sprout", "node_herb", "fence"]:
		var visual := g._prop_visual(name)
		var native := g._visual_size(visual)
		var factor := g._scenery_render_scale(visual, Terrains.prop_base(name), Balance.SCENERY_SCALE_JITTER.y)
		visual.free()
		if native.y * factor > Balance.ESCORT_BODY_HEIGHT or factor <= 0.0:
			return name + " exceeds a person's height in the scenery renderer"
	if not Story.ALL_SIDE_QUESTS.has("one_more_mile") or not Achievements.TITLES.has("road_companion"):
		return "escort quest/title missing"
	if not g._convo_reachable("wayfarer_tovin"):
		return "physical encounter giver was not discoverable"
	g.flags = {}
	if g.chapter_id == "ch1":
		if not g.side_quest_available("one_more_mile"):
			return "visible Tovin did not offer his quest"
		g.flags[Escort.KEPT] = true
		if g.side_quest_available("one_more_mile"):
			return "Tovin's permanently finished quest was advertised on replay"
	g.flags = {}
	for invalid in [NAN, INF, -1.0, Balance.ESCORT_RESOLVE + 1.0]:
		v.apply_state(1, 0, invalid, 0.0, false, true, 0, v.start, true, [])
		if v.phase != 0:
			return "invalid escort resolve accepted"
	for at in [Vector2(NAN, 0), Vector2(INF, 0), v.start + Vector2(0, 30), v.start - Vector2(20, 0), v.goal + Vector2(20, 0)]:
		v.apply_state(1, 0, 100.0, 0.0, false, true, 0, at, true, [])
		if v.phase != 0:
			return "escort snapshot left its safe route"
	v.apply_state(2, 1, 100.0, 2.0, false, true, 0, v.start, false, [Vector2(INF, 0)])
	if v.phase != 0:
		return "invalid escort arrival accepted"
	if v.request(null, "start") or v.request(g.player, "invented"):
		return "invalid escort caller/action accepted"
	v.apply_state(1, 0, 80.0, 0.0, true, true, 0, v.start.lerp(v.goal, 0.5), false, [])
	if v.phase != 1 or not v.waiting or not is_equal_approx(v.progress(), 0.5):
		return "valid escort state lost"
	v.complete()
	if v.phase == 4 or g.get_flag(Escort.DONE, false):
		return "escort completed without its encounters"
	v.stage = Escort.WAVES.size()
	v.complete()
	if v.phase == 4 or g.get_flag(Escort.DONE, false):
		return "escort completed before reaching home"
	return ""
