extends RefCounted
## Isolated real-domain checks; no real save writes and no live hero changes.
## UI-shell expiration and actual ENet transport belong to the native rig.
const Alchemy := preload("res://scripts/alchemy.gd")
const Types := preload("res://scripts/tests/test_road_hunt.gd")

class BrewGame extends Types.Fixture:
	var saves := 0
	func autosave() -> void: saves += 1


static func run(t: Node) -> String:
	var g := BrewGame.new()
	g.no_saves = true
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.chapter_id = "capital"
	g.wander_seed = 7301
	t.add_child(g)
	g.world = Node2D.new()
	g.add_child(g.world)
	var p := Player.new()
	p.game = g
	p.hp = 100.0
	p.max_hp = 100.0
	g.player = p
	g.players = [p]
	var error := _checks(g)
	g.player = null
	g.players = []
	p.free()
	g.free()
	if error == "":
		print("ok: Alchemist recipe ceilings, exact quotes/ingredients, one-use orders, live world/owner/terms guards, overflow, distinct B/A knowledge and boss recipe payloads")
	return error


static func _stock(g: BrewGame, grade := "F", herbs := 20, reagents := 20, mastery := 0) -> void:
	var p: Player = g.local_player
	p.profession = "alchemist"
	p.gold = 1000000
	p.mastery = {"alchemist": mastery}
	p.blueprints = []
	p.npc_favor = {}
	p.resonance = 0.0
	p.greed = 0.0
	p.goldrush_time = 0.0
	p.materials = [Items.make_material("herb", grade, herbs), Items.make_material("reagent", grade, reagents)]
	p.backpack = []
	p.consumables = []
	p.gem_bag = []
	p.loose_bags = []
	p.bags = [{"slots": 30}]
	g.mailbox = []
	g.saves = 0


static func _state(g: BrewGame) -> Dictionary:
	var p: Player = g.local_player
	return {"gold": p.gold, "mastery": p.mastery.duplicate(true),
		"materials": p.materials.duplicate(true), "bottles": p.consumables.duplicate(true),
		"blueprints": p.blueprints.duplicate(), "favor": p.npc_favor.duplicate(true),
		"mail": g.mailbox.duplicate(true), "saves": g.saves}


static func _unchanged_failure(g: BrewGame, order: Alchemy.Order) -> bool:
	var before := _state(g)
	return not bool(Alchemy.commit(order).ok) and _state(g) == before


static func _checks(g: BrewGame) -> String:
	var p: Player = g.local_player
	_stock(g)
	var recipes := 0
	for fs in Alchemy.shapes():
		for grade in Alchemy.grades(String(fs)):
			var spec := Alchemy.recipe(String(fs), grade)
			var bottle: Dictionary = spec.item
			if bottle.lane != "accord" or not bottle.sting.is_empty() or grade in ["S", "Grand"] \
					or bool(bottle.get("training", false)) or int(spec.herbs) <= 0 or int(spec.reagents) != 1:
				return "a brewing recipe escaped the clean ordinary bottle/input contract"
			_stock(g, grade, 20, 20, 500)
			if grade in Items.BLUEPRINT_GRADES:
				p.learn_blueprint(String(spec.blueprint_slot), grade)
			p.npc_favor.kesh = 150
			p.goldrush_time = 1.0
			var priced := Alchemy.quote(g, String(fs), grade)
			var sale := p.gold_yield(maxi(1, int(float(bottle.price) * Balance.MERCHANT_SELL_FRACTION)))
			if not bool(priced.allowed) or sale >= int(priced.fee):
				return "current maximum favor/Gold Rush allowed brew-for-resale gold profit"
			var made := Alchemy.commit(Alchemy.prepare(g, String(fs), grade))
			if not bool(made.ok) or p.consumables.size() != 1 or p.consumables[0] != bottle \
					or p.material_count("herb", grade) != 20 - int(spec.herbs) \
					or p.material_count("reagent", grade) != 19 \
					or Professions.points(p) != 500 + int(spec.mastery_gain):
				return "a supported recipe failed to make exactly its canonical bottle: " + String(fs) + ":" + grade
			recipes += 1
		for grade in ["S", "Grand", "", "unknown"]:
			if not Alchemy.recipe(String(fs), grade).is_empty():
				return "brewing accepted a forbidden grade"
	if recipes != 39 or Alchemy.grades("renewal") != ["C", "B", "A"] \
			or not Alchemy.recipe("black", "A").is_empty():
		return "brewing roster is not the 39 supported existing products"
	for row in [["E", 0], ["D", 30], ["C", 90], ["B", 220], ["A", 500]]:
		var grade := String(row[0])
		var points := int(row[1])
		_stock(g, grade, 20, 20, points)
		if grade in Items.BLUEPRINT_GRADES:
			p.learn_blueprint("potion/health_instant", grade)
		if not bool(Alchemy.quote(g, "health_instant", grade).allowed):
			return "the exact mastery threshold did not unlock grade " + grade
		if points > 0:
			p.mastery.alchemist = points - 1
			if bool(Alchemy.quote(g, "health_instant", grade).allowed):
				return "grade " + grade + " unlocked one mastery point early"
	_stock(g)
	# Golden fixtures use owner-facing prices, not a repeated formula.
	for row in [["F", 166], ["E", 470], ["D", 1510], ["C", 4852], ["B", 17423], ["A", 66388]]:
		var q := Alchemy.quote(g, "health_instant", String(row[0]))
		if int(q.fee) != int(row[1]):
			return "Health Potion's exact ingredient-inclusive fee changed at " + String(row[0])
	if int(Alchemy.quote(g, "health_tonic", "F").fee) != 96:
		return "the slow F tonic did not retain its cheaper distinct price"
	# Exact input exhaustion frees a full pack slot; quote copies cannot alter
	# the bound order or smuggle another product into its output.
	_stock(g, "F", 2, 1)
	p.bags = [{"slots": 2}]
	var order := Alchemy.prepare(g, "health_instant", "F")
	var copy := order.view()
	copy.fee = 1
	copy.item.id = "forged"
	var result := Alchemy.commit(order)
	if not bool(result.ok) or bool(result.mailed) or int(result.fee) != 166 \
			or p.gold != 999834 or not p.materials.is_empty() or p.consumables.size() != 1 \
			or String(p.consumables[0].id) != "pot_health_instant_f_accord" \
			or Professions.points(p) != 5 or g.saves != 1:
		return "a legitimate brew failed exact charge, input exhaustion, output, mastery or single save"
	if not _unchanged_failure(g, order):
		return "replaying a settled order produced another transaction"
	# Removing the reagent after the quote must not consume any herb or gold.
	_stock(g)
	order = Alchemy.prepare(g, "health_instant", "F")
	p.materials.remove_at(1)
	if not _unchanged_failure(g, order):
		return "a vanished reagent allowed a partial transaction"
	for count in [0, -1, 1.5, INF, "5"]:
		_stock(g)
		p.materials[1].count = count
		if bool(Alchemy.quote(g, "health_instant", "F").allowed):
			return "a malformed or nonpositive input stack enabled brewing"
	_stock(g)
	p.materials.append(p.materials[1].duplicate(true))
	if bool(Alchemy.quote(g, "health_instant", "F").allowed):
		return "ambiguous duplicate reagent stacks enabled brewing"
	# Context and quote terms are checked in the transaction, with no UI.
	for change in ["chapter", "trade", "mastery", "favor", "gold", "seed", "downed"]:
		_stock(g)
		order = Alchemy.prepare(g, "health_instant", "F")
		match change:
			"chapter": g.chapter_id = "ch1"
			"trade": p.profession = "tailor"
			"mastery": p.mastery.alchemist = 1
			"favor": p.npc_favor.kesh = 150
			"gold": p.gold = 165
			"seed": g.wander_seed += 1
			"downed": p.downed = true
		var rejected := _unchanged_failure(g, order)
		g.chapter_id = "capital"
		g.wander_seed = 7301
		p.downed = false
		if not rejected:
			return "stale order mutated the hero after " + change + " changed"
	_stock(g)
	order = Alchemy.prepare(g, "health_instant", "F")
	var old_world := g.world
	g.world = Node2D.new()
	g.add_child(g.world)
	var rejected := _unchanged_failure(g, order)
	g.world.free()
	g.world = old_world
	if not rejected:
		return "an order survived a same-seed world replacement"
	order = Alchemy.prepare(g, "health_instant", "F")
	var other := Player.new()
	other.game = g
	other.hp = 100.0
	g.player = other
	rejected = _unchanged_failure(g, order)
	g.player = p
	other.free()
	if not rejected:
		return "an order followed a replaced local character"
	# Remaining partial stacks occupy both slots, so overflow must deliver one
	# correctly typed mail payload and save after that payload is banked.
	_stock(g)
	p.bags = [{"slots": 2}]
	result = Alchemy.commit(Alchemy.prepare(g, "health_instant", "F"))
	if not bool(result.ok) or not bool(result.mailed) or not p.consumables.is_empty() \
			or g.mailbox.size() != 1 or g.mailbox[0].items.size() != 1 \
			or g.mailbox[0].items[0].kind != "potion" or g.saves != 1 \
			or p.material_count("herb", "F") != 18 or p.material_count("reagent", "F") != 19:
		return "full-pack brewing lost or duplicated the bottle or consumed incorrect inputs"
	_stock(g, "B", 20, 20, 500)
	if bool(Alchemy.quote(g, "health_instant", "B").allowed):
		return "Master mastery bypassed the B potion blueprint"
	p.learn_blueprint("charm", "B")
	p.learn_blueprint(Items.potion_blueprint_slot("health_tonic"), "B")
	p.learn_blueprint(Items.potion_blueprint_slot("health_instant"), "A")
	if bool(Alchemy.quote(g, "health_instant", "B").allowed):
		return "wrong slot, shape or grade knowledge unlocked a brew"
	# Knowledge can be learned before mastery, but only the Alchemist path may
	# price potion namespaces; the generic gear fallback must reject them.
	_stock(g)
	if Professions.buy_blueprint(p, Items.potion_blueprint_slot("health_instant"), "B").ok:
		return "a potion recipe bypassed its own transaction through gear blueprint pricing"
	result = Alchemy.commit(Alchemy.prepare(g, "health_instant", "B", "blueprint"))
	if not bool(result.ok) or int(result.fee) != 30000 or p.gold != 970000 \
			or not p.has_blueprint("potion/health_instant", "B") or Professions.points(p) != 0:
		return "learning a B recipe before mastery failed its exact knowledge/fee contract"
	if not _unchanged_failure(g, Alchemy.prepare(g, "health_instant", "B", "blueprint")):
		return "an already-known potion blueprint charged again"
	var error := _award_checks(g)
	if error != "":
		return error
	# Local owner authority also works in a visiting world; a remote player is
	# never consulted for stock or changed by this personal transaction.
	_stock(g)
	g.guest = true
	g.guest_world = true
	result = Alchemy.commit(Alchemy.prepare(g, "health_instant", "F"))
	g.guest = false
	g.guest_world = false
	if not bool(result.ok) or p.consumables.size() != 1:
		return "a guest could not brew using their own capital-world character"
	return ""


static func _award_checks(g: BrewGame) -> String:
	var p: Player = g.local_player
	var learned_before := p.blueprints.duplicate()
	for bad in [{"slot": "potion/unknown", "grade": "B"},
			{"slot": "potion/health_instant", "grade": "S"}, {"slot": "unknown", "grade": "A"}]:
		g.apply_award_events([{"k": "blueprint", "bp": bad}])
	if p.blueprints != learned_before:
		return "an invalid award taught an unknown or forbidden blueprint"
	var bp := Items.make_potion_blueprint("renewal", "A")
	g.apply_award_events([{"k": "blueprint", "bp": bp}])
	g.apply_award_events([{"k": "blueprint", "bp": bp}])
	if p.blueprints.count("potion/renewal:A") != 1 or Items.potion_blueprint_price("renewal", "A") != 150000:
		return "a canonical A award duplicated knowledge or missed its deterministic price"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	var grades_seen := {}
	for _i in 1024:
		var rolled := Alchemy.roll_blueprint(rng)
		if rolled.is_empty():
			continue
		if not Items.valid_blueprint(String(rolled.slot), String(rolled.grade)) \
				or not String(rolled.slot).begins_with("potion/"):
			return "the boss potion-recipe roller emitted an invalid payload"
		grades_seen[String(rolled.grade)] = true
	if not grades_seen.has("B") or not grades_seen.has("A"):
		return "the deterministic boss recipe sample did not exercise both legal grades"
	return ""
