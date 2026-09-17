extends RefCounted
## Isolated inventory-domain regression; native input lives in the gems rig.
const Types := preload("res://scripts/tests/test_road_hunt.gd")


static func run(_t: Node) -> String:
	var g := Types.Fixture.new()
	g.no_saves = true
	g.chapter_id = "capital"
	var p := Player.new()
	p.game = g
	g.player = p
	g.players = [p]
	var error := _checks(p)
	g.player = null
	g.players = []
	p.free()
	g.free()
	if error == "":
		print("ok: equipped synthesis respects gear caps before consuming gems, preserves old sockets, continues other vessels and bag merges, and keeps road work bag-only")
	return error


static func _checks(p: Player) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17092026
	# Both regular and special gems obey their vessel. Existing over-cap and
	# unknown-grade save data must survive unchanged, with no further upgrade.
	for spec in [["C", 2, "atk_flat"], ["B", 3, "atk_flat"], ["A", 6, "cdr"],
		["S", 10, "cdr"], ["C", 3, "atk_flat"], ["unknown", 2, "atk_flat"]]:
		var grade := String(spec[0])
		var level := int(spec[1])
		var stat := String(spec[2])
		var item := _seed(p, rng, grade, level, stat, 2)
		var before := _state(p)
		if p.auto_synthesize() != 0 or _state(p) != before:
			return "equipped synthesis changed capped/legacy %s Lv%d %s or its ingredients" % [grade, level, stat]
		if not is_same(p.equipment.weapon, item):
			return "capped synthesis replaced the owned vessel"
	# Legal levels still progress, with exact ingredient consumption.
	for spec in [["C", 1, "atk_flat"], ["B", 2, "atk_flat"], ["A", 5, "cdr"], ["S", 9, "cdr"]]:
		var level := int(spec[1])
		var item := _seed(p, rng, String(spec[0]), level, String(spec[2]), 2)
		if p.auto_synthesize() != 1 or int(item.gems[0].lvl) != level + 1 or not p.gem_bag.is_empty():
			return "legal equipped synthesis failed or consumed the wrong ingredients"
		var after := _state(p)
		if p.auto_synthesize() != 0 or _state(p) != after:
			return "repeated synthesis changed an exhausted inventory"
	if not p.game.achievements.has("gem_max"):
		return "legal S10 synthesis lost its maximum-gem achievement"
	var capped := _seed(p, rng, "C", 2, "atk_flat", 2)
	var other := Items.roll_item_of("armor", "B", rng, p.cls)
	other.gems = [Items.make_gem("hp_flat", 2)]
	p.equipment.armor = other
	p.gem_bag.append_array([Items.make_gem("hp_flat", 2), Items.make_gem("hp_flat", 2)])
	p.recalc()
	if p.auto_synthesize() != 1 or int(capped.gems[0].lvl) != 2 or int(other.gems[0].lvl) != 3 \
		or p.gem_bag != [Items.make_gem("atk_flat", 2), Items.make_gem("atk_flat", 2)]:
		return "capped vessel blocked another eligible item or lost ingredients"
	# Bag merges must feed eligible sockets again even when a capped item
	# earlier in equipment order holds the same kind of gem.
	capped = _seed(p, rng, "C", 2, "atk_flat", 0)
	other = Items.roll_item_of("armor", "B", rng, p.cls)
	other.gems = [Items.make_gem("atk_flat", 2)]
	p.equipment.armor = other
	for i in 6: p.gem_bag.append(Items.make_gem("atk_flat", 1))
	p.recalc()
	if p.auto_synthesize() != 3 or int(capped.gems[0].lvl) != 2 or int(other.gems[0].lvl) != 3 \
		or not p.gem_bag.is_empty():
		return "same-kind bag cascade failed to skip the capped vessel and feed the eligible one"
	var reaching_cap := _seed(p, rng, "C", 1, "atk_flat", 11)
	if p.auto_synthesize() != 5 or int(reaching_cap.gems[0].lvl) != 2 \
		or p.gem_bag != [Items.make_gem("atk_flat", 3)]:
		return "synthesis did not stop a socket at its newly reached cap while continuing bag merges"
	for chapter in ["capital", "ch1"]:
		var item := _seed(p, rng, "C", 2, "atk_flat", 3)
		p.game.chapter_id = chapter
		if p.auto_synthesize() != 1 or int(item.gems[0].lvl) != 2 \
			or p.gem_bag != [Items.make_gem("atk_flat", 3)]:
			return "bag triple did not merge independently of the capped socket"
	# Road policy also matters below the vessel cap.
	var road := _seed(p, rng, "B", 2, "atk_flat", 3)
	p.game.chapter_id = "ch1"
	if p.auto_synthesize() != 1 or int(road.gems[0].lvl) != 2 \
		or p.gem_bag != [Items.make_gem("atk_flat", 3)]:
		return "road synthesis upgraded an equipped gem"
	return ""


static func _seed(p: Player, rng: RandomNumberGenerator, grade: String, level: int, stat: String, matches: int) -> Dictionary:
	p.game.chapter_id = "capital"
	var item := Items.roll_item_of("weapon", "C" if grade == "unknown" else grade, rng, p.cls)
	item.grade = grade
	item.gems = [Items.make_gem(stat, level)]
	p.equipment = {"weapon": item}
	p.gem_bag = []
	for i in matches: p.gem_bag.append(Items.make_gem(stat, level))
	p.recalc()
	return item


static func _state(p: Player) -> Dictionary:
	return {"equipment": p.equipment.duplicate(true), "bag": p.gem_bag.duplicate(true),
		"atk": p.atk, "hp": p.max_hp, "cdr": p.cdr}
