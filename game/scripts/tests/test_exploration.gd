extends RefCounted
const Guide := preload("res://scripts/quest_guide.gd")
const Wildlife := preload("res://scripts/wildlife.gd")
const Pet := preload("res://scripts/pet_visual.gd")


class CurseMenus extends Menus:
	var accept := Callable()
	var closed := 0
	# Each confirm gets a fresh shell, like the real Menus._open.
	func open_confirm(_msg: String, on_yes: Callable, _cancel := Callable(), _options: Dictionary = {}) -> void:
		accept = on_yes
		_stub_shell(Control.new())
	func close() -> void:
		closed += 1
		_stub_shell(null)
	func _stub_shell(next: Control) -> void:
		if root != null:
			root.free()
		root = next
		if next != null:
			add_child(next)

class CurseWorld extends Game:
	var notice := ""
	func _ready() -> void: pass
	func burst(_pos: Vector2, _color: Color, _count := 10) -> void: pass
	func sfx(_name: String, _pitch := 1.0, _cutoff := 0.0, _vol_db := 0.0) -> void: pass
	func spawn_text(_pos: Vector2, text: String, _color: Color, _hold := 0.0) -> void:
		notice = text
	func _make_npc(_sprite: String, pos: Vector2, _prompt: String, action: Callable,
			_profile := "", _reach := 0.0) -> Node2D:
		var npc := Node2D.new()
		npc.position = pos
		add_child(npc)
		interactables.append({"node": npc, "action": action})
		return npc

class CurseEnemy extends Enemy:
	func _ready() -> void: pass


static func run(t: Node) -> String:
	var curse := CurseWorld.new()
	curse.process_mode = Node.PROCESS_MODE_DISABLED
	curse.player = t.game.player  # read-only position for the notice
	curse.menus = CurseMenus.new()
	curse.add_child(curse.menus)
	t.add_child(curse)
	var curse_error := _curse_checks(curse)
	curse.player = null
	curse.free()
	if curse_error != "":
		return curse_error
	var g: Game = t.game
	var saved := {}
	for key in ["flags", "visited", "door_seen", "_meta", "quest_kills"]:
		saved[key] = g.get(key).duplicate(true)
	var meta_loaded: bool = g._meta_loaded
	var tracked: String = g.player.tracked_quest
	var pet: String = g.player.equipped_pet
	var rescues := g.player.rescued_pets.duplicate()
	var guide_index := Guide._setters.duplicate(true)
	var indexed := Guide._indexed
	var pin: int = g.hud.wayfinder.pinned_room
	var path: Array[int] = g.hud.wayfinder.pinned_path.duplicate()
	var error := _checks(g)
	for key in saved:
		g.set(key, saved[key])
	g._meta_loaded = meta_loaded
	g.player.tracked_quest = tracked
	g.player.rescued_pets = rescues
	g.player.set_pet(pet)
	g.hud.wayfinder.pinned_room = pin
	g.hud.wayfinder.pinned_path = path
	Guide._setters = guide_index
	Guide._indexed = indexed
	g.hud.wayfinder._sample_quest()
	g.hud.wayfinder.pinned_room = pin
	g.hud.wayfinder.pinned_path = path
	Story.ALL_SIDE_QUESTS.erase("_qa_guide")
	if error == "":
		print("ok: quest fog, objective advancement, manual route handoff, personal save selection, six rescue sites, claim-once ownership and companion frame scale")
	return error


static func _checks(g: Game) -> String:
	for site in Wildlife.SITES:
		var found := false
		for zone in Story.chapter(String(site.chapter)).zones:
			if String(zone.name) == String(site.room):
				found = true
		if not found or Skins.find_pet(String(site.id)).is_empty():
			return "unreachable rescue site: " + String(site.id)
	if not g._flag_is_local("sq_kept_rescue_hearth_hopper"):
		return "a personal rescue escaped onto the shared flag channel"
	g.flags.erase("sq_kept_rescue_hearth_hopper")
	g.player.rescued_pets.erase("hearth_hopper")
	if not Wildlife.claim(g, "hearth_hopper") or Wildlife.claim(g, "hearth_hopper"):
		return "rescue claim was not exactly once"
	if not g.owns_cosmetic("pet", "all", "hearth_hopper"):
		return "rescue failed to unlock the account companion"
	if Wildlife.claim(g, "invalid"):
		return "unknown creature could be rescued"
	for site in Wildlife.SITES:
		var v := Pet.new()
		v.setup(String(site.id))
		var good: bool = v.texture != null and v.hframes >= 1 and is_finite(v.scale.y)
		var expected: Vector2 = Art.scale_for_alpha_height(v.texture, Balance.PET_BODY_HEIGHT, v.hframes) if v.texture != null else Vector2.ZERO
		good = good and v.scale.is_equal_approx(expected)
		v.animate(1.0)
		good = good and v.frame >= 0 and v.frame < v.hframes
		v.free()
		if not good:
			return "companion atlas/scale failed: " + String(site.id)
	Story.ALL_SIDE_QUESTS["_qa_guide"] = {"name": "A guide fixture", "scope": "world", "steps": [
		{"flag": "qa_guide_one", "text": "Find the guide"}, {"flag": "qa_guide_two", "text": "Return"}]}
	g.flags["sq_on__qa_guide"] = true
	g.flags.erase("qa_guide_one")
	g.flags.erase("qa_guide_two")
	g.flags.erase("sq_paid__qa_guide")
	Guide._setters = {"qa_guide_one": ["qa_convo"]}
	Guide._indexed = true
	var npc := Node2D.new()
	npc.position = g.room_center(g.cur_room)
	npc.set_meta("quest_convo", "qa_convo")
	g.world.add_child(npc)
	var entry := {"node": npc}
	g.interactables.append(entry)
	var error := _guide_checks(g)
	g.interactables.erase(entry)
	npc.free()
	return error


static func _guide_checks(g: Game) -> String:
	var step := Guide.step(g, "_qa_guide")
	if String(step.get("flag", "")) != "qa_guide_one":
		return "guide did not choose the next incomplete objective"
	# Standalone worlds deliberately reveal their full maps; campaign worlds
	# must still keep even a live but unvisited target behind fog.
	if not Story.is_standalone(g.chapter_id):
		g.visited = {}
		g.door_seen = {}
		if not Guide.destination(g, step).is_empty():
			return "quest guidance leaked an uncharted objective"
	g.visited[g.cur_room] = true
	var target := Guide.destination(g, step)
	if target.is_empty() or int(target.room) != g.cur_room:
		return "a charted local quest NPC was not located"
	g.hud.wayfinder.track("_qa_guide")
	g.hud.wayfinder._sample_quest()
	if not g.hud.wayfinder.quest_root.visible:
		return "tracking did not display the objective card"
	var section := SaveGame._character_section(g)
	if String(section.get("tracked_quest", "")) != "_qa_guide":
		return "quest selection was not saved with the character"
	g.flags["qa_guide_one"] = true
	if String(Guide.step(g, "_qa_guide").get("flag", "")) != "qa_guide_two":
		return "guide did not advance after a completed objective"
	g.hud.wayfinder.track("")
	g.hud.wayfinder.pinned_room = g.cur_room
	g.hud.wayfinder._sample_quest()
	if g.hud.wayfinder.pinned_room != g.cur_room:
		return "retired quest tracking erased a later manual route"
	return ""


static func _curse_checks(g: CurseWorld) -> String:
	# A private room index prevents touching the running campaign's enemies.
	var room := -901
	var enemy := CurseEnemy.new()
	enemy.zone_idx = room
	enemy.dmg = 10.0
	enemy.speed = 100.0
	g.add_child(enemy)
	enemy.add_to_group("enemies")
	var menus := g.menus as CurseMenus
	var withdrawn := "The bargain has withdrawn"
	for freed in [false, true]:
		g.notice = ""
		var closed := menus.closed
		g._cursed_chest_node(room, Vector2.ZERO)
		var npc: Node2D = g.interactables[-1].node
		g.interactables[-1].action.call()
		var accept: Callable = menus.accept
		# Fire the real timeout while confirm is pending, as online play does.
		(npc.get_child(0) as Timer).timeout.emit()
		if menus.closed != closed + 1 or menus.is_open() or g.notice != withdrawn:
			return "a lapsed cursed bargain left its confirm open or did not say it withdrew"
		# A click already in flight still reaches the retired offer.
		g.notice = ""
		if freed:
			npc.free()
		accept.call()
		if g.get_flag(g._curse_flag(room), false) or g.curse_pending.has(room) \
			or enemy.has_meta("cursed") or enemy.dmg != 10.0 or enemy.speed != 100.0:
			return "an expired cursed bargain still changed flags, rewards or the pack"
		if g.notice != withdrawn:
			return "expired curse acceptance did not explain the withdrawn offer"
	# A lapse whose offer never opened a confirm leaves another open menu alone.
	g._cursed_chest_node(room, Vector2.ZERO)
	var idle: Node2D = g.interactables[-1].node
	menus.open_confirm("another prompt", Callable())
	var other: Control = menus.root
	var closed_before := menus.closed
	g.notice = ""
	(idle.get_child(0) as Timer).timeout.emit()
	if menus.root != other or menus.closed != closed_before or g.notice != "" \
		or not idle.is_queued_for_deletion():
		return "a lapsed cursed bargain closed a menu it did not open"
	menus.close()
	g._cursed_chest_node(room, Vector2.ZERO)
	var live: Node2D = g.interactables[-1].node
	g.interactables[-1].action.call()
	menus.accept.call()
	if not g.get_flag(g._curse_flag(room), false) or not g.curse_pending.has(room) \
		or not enemy.has_meta("cursed") or not is_equal_approx(enemy.dmg, 10.0 * Balance.CURSE_DMG_MULT) \
		or not is_equal_approx(enemy.speed, 100.0 * Balance.CURSE_SPEED_MULT) or not live.is_queued_for_deletion() \
		or g.notice == withdrawn:
		return "a live cursed bargain no longer applies its reward flag and pack buff"
	print("ok: cursed bargains close their own confirm on lapse and reject queued/freed offers before writes; a live offer still buffs the pack")
	return ""
