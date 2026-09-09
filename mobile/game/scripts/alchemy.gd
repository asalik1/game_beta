extends RefCounted
## Personal Alchemist brewing. Quotes are read-only; a prepared order binds
## the owning hero/world and can settle once. UI shell lifetime stays in UI.
## Ordinary brewing never creates laced, S, Grand or training bottles.

class Order extends RefCounted:
	var _game: WeakRef
	var _player: WeakRef
	var _world: WeakRef
	var _seed := 0
	var _quote: Dictionary = {}
	var _used := false
	func view() -> Dictionary:
		return _quote.duplicate(true)


static func shapes() -> Array:
	return Items.POTION_SHAPES.keys()


static func recipe(fs: String, grade: String) -> Dictionary:
	if not Items.POTION_SHAPES.has(fs) or not Balance.BREW_HERBS_BY_GRADE.has(grade):
		return {}
	var meta: Dictionary = Items.POTION_SHAPES[fs]
	var bottle := Items.make_potion(String(meta.family), String(meta.shape), grade, "accord")
	var herbs := int(Balance.BREW_HERBS_BY_GRADE[grade])
	var reagents := int(Balance.BREW_REAGENTS)
	if bottle.is_empty() or herbs <= 0 or reagents <= 0 \
			or herbs > Items.MATERIAL_STACK_MAX or reagents > Items.MATERIAL_STACK_MAX:
		return {}
	return {"shape": fs, "grade": grade, "item": bottle,
		"herbs": herbs, "reagents": reagents,
		"mastery_gain": int(Balance.CRAFT_MASTERY_BY_GRADE.get(grade, 0)),
		"blueprint_slot": Items.potion_blueprint_slot(fs)}


static func grades(fs: String) -> Array[String]:
	var out: Array[String] = []
	for grade in Balance.BREW_HERBS_BY_GRADE:
		if not recipe(fs, String(grade)).is_empty():
			out.append(String(grade))
	return out


static func _owner_error(g: Game) -> String:
	if not is_instance_valid(g) or g.is_queued_for_deletion() or not g.has_local_player() \
			or g.local_player.is_queued_for_deletion() or g.local_player.game != g or g.dedicated:
		return "Brewing needs your own character."
	if g.chapter_id != "capital" or g.pvp_active:
		return "The Alchemist's bench is in Crownfall."
	var p: Player = g.local_player
	if not g.play_started or g.state != Game.ST_PLAYING or p.dead or p.downed or p.ghost or p.hp <= 0.0:
		return "Return to the bench when you can stand."
	if not is_instance_valid(g.world) or g.world.is_queued_for_deletion():
		return "The bench is no longer available."
	return ""


## Validate both exact stacks and plan their next values without mutating any
## carried Dictionary. An empty consumed stack can free a slot for the bottle.
static func _ingredients(p: Player, spec: Dictionary) -> Dictionary:
	var out := p.materials.duplicate()
	var needs := {"herb": int(spec.herbs), "reagent": int(spec.reagents)}
	var counts := {"herb": 0, "reagent": 0}
	var matches := {"herb": 0, "reagent": 0}
	var removals: Array[int] = []
	for i in p.materials.size():
		var material: Dictionary = p.materials[i]
		var family := String(material.get("family", ""))
		if not needs.has(family) or String(material.get("grade", "")) != String(spec.grade):
			continue
		matches[family] = int(matches[family]) + 1
		var raw: Variant = material.get("count", 0)
		if not (raw is int or raw is float) or not is_finite(float(raw)) \
				or float(raw) != floorf(float(raw)) or float(raw) <= 0.0 \
				or float(raw) > Items.MATERIAL_STACK_MAX or int(matches[family]) > 1:
			return {"ok": false, "reason": "An ingredient stack is invalid.", "counts": counts}
		var have := int(raw)
		counts[family] = have
		if have >= int(needs[family]):
			if have == int(needs[family]):
				removals.append(i)
			else:
				var remainder := material.duplicate(true)
				remainder.count = have - int(needs[family])
				out[i] = remainder
	for family in needs:
		if int(counts[family]) < int(needs[family]):
			var title := String(Items.MATERIALS[family][String(spec.grade)])
			return {"ok": false, "reason": "Needs %d %s; have %d." % [int(needs[family]), title, int(counts[family])],
				"counts": counts}
	removals.reverse()
	for idx in removals:
		out.remove_at(idx)
	return {"ok": true, "reason": "", "counts": counts, "materials": out}


## action is "brew" or "blueprint". Recipe purchase may precede mastery, but
## only the active Alchemist can buy it at the capital bench.
static func quote(g: Game, fs: String, grade: String, action := "brew") -> Dictionary:
	var spec := recipe(fs, grade)
	var out := {"allowed": false, "reason": "No clean recipe for this bottle.",
		"action": action, "shape": fs, "grade": grade, "fee": 0, "terms": {}}
	if spec.is_empty() or action not in ["brew", "blueprint"] \
			or (action == "blueprint" and grade not in Items.BLUEPRINT_GRADES):
		return out
	out.merge(spec, true)
	if not is_instance_valid(g) or not g.has_local_player():
		out.reason = "Brewing needs your own character."
		return out
	var p: Player = g.local_player
	var known := p.has_blueprint(String(spec.blueprint_slot), grade)
	var favor := g.favor_price_mult("kesh")
	var price := int(spec.item.price)
	var fee := Balance.brew_gold_fee(price, grade, favor) if action == "brew" \
		else Items.potion_blueprint_price(fs, grade)
	var stock := _ingredients(p, spec)
	out.fee = fee
	out.herbs_have = int(stock.counts.herb)
	out.reagents_have = int(stock.counts.reagent)
	out.blueprint_known = known
	out.favor_multiplier = favor
	out.mastery = Professions.points(p, "alchemist")
	out.mastery_gain = int(spec.mastery_gain) if action == "brew" else 0
	out.terms = {"action": action, "shape": fs, "grade": grade,
		"fee": fee, "herbs": int(spec.herbs), "reagents": int(spec.reagents),
		"mastery_gain": int(out.mastery_gain), "mastery": int(out.mastery),
		"trade": p.profession, "known": known,
		"favor": favor if action == "brew" else 1.0,
		"item_id": String(spec.item.id)}
	out.reason = _owner_error(g)
	if out.reason == "" and p.profession != "alchemist":
		out.reason = "Lock Alchemist as your active trade first."
	if out.reason == "" and fee <= 0:
		out.reason = "This recipe's price is unavailable."
	if action == "blueprint":
		if out.reason == "" and known:
			out.reason = "This potion blueprint is already known."
	else:
		if out.reason == "" and Items.GRADES.find(grade) > Items.GRADES.find(Professions.max_grade(p)):
			out.reason = "%s mastery cannot brew grade %s yet." % [Professions.band(p), grade]
		if out.reason == "" and grade in Items.BLUEPRINT_GRADES and not known:
			out.reason = "Learn the generic %s %s blueprint first." % [grade, String(Items.POTION_ACCORD_NOUN[fs])]
		if out.reason == "" and not bool(stock.ok):
			out.reason = String(stock.reason)
	if out.reason == "" and p.gold < fee:
		out.reason = "Needs %d gold; have %d." % [fee, p.gold]
	out.allowed = out.reason == ""
	return out


static func prepare(g: Game, fs: String, grade: String, action := "brew") -> Order:
	var order := Order.new()
	order._quote = quote(g, fs, grade, action)
	if is_instance_valid(g) and g.has_local_player() and is_instance_valid(g.world):
		order._game = weakref(g)
		order._player = weakref(g.local_player)
		order._world = weakref(g.world)
		order._seed = g.wander_seed
	return order


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "item": {}, "fee": 0,
		"mastery_gain": 0, "mailed": false}


## No awaits or signal-driven UI callbacks occur between revalidation and
## inventory mutation. The order owns banking and saving, not its UI caller.
static func commit(order: Order) -> Dictionary:
	if order == null or order._used:
		return _failure("This order has already been used.")
	if not bool(order._quote.get("allowed", false)):
		return _failure(String(order._quote.get("reason", "Refresh this recipe.")))
	if order._game == null or order._player == null or order._world == null:
		return _failure("Return to the current bench.")
	var g: Game = order._game.get_ref() as Game
	var p: Player = order._player.get_ref() as Player
	var world: Node2D = order._world.get_ref() as Node2D
	if not is_instance_valid(g) or not is_instance_valid(p) or not is_instance_valid(world) \
			or g.local_player != p or p.game != g or g.world != world or g.wander_seed != order._seed:
		return _failure("This order belongs to a previous character or world.")
	var reason := _owner_error(g)
	if reason != "":
		return _failure(reason)
	var fs := String(order._quote.shape)
	var grade := String(order._quote.grade)
	var action := String(order._quote.action)
	var fresh := quote(g, fs, grade, action)
	if not bool(fresh.allowed):
		return _failure(String(fresh.reason))
	if fresh.terms != order._quote.terms:
		return _failure("The recipe quote changed. Review its current cost.")
	var fee := int(fresh.fee)
	if action == "blueprint":
		order._used = true
		if not p.learn_blueprint(String(fresh.blueprint_slot), grade):
			return _failure("This potion blueprint is already known.")
		p.gold -= fee
		g.autosave()
		return {"ok": true, "reason": "", "item": {}, "fee": fee,
			"mastery_gain": 0, "mailed": false, "blueprint": Items.make_potion_blueprint(fs, grade)}
	var stock := _ingredients(p, fresh)
	if not bool(stock.ok):
		return _failure(String(stock.reason))
	var bottle: Dictionary = fresh.item
	var gain := int(fresh.mastery_gain)
	if bottle.is_empty() or gain <= 0:
		return _failure("This recipe is unavailable.")
	order._used = true
	p.materials = stock.materials
	p.gold -= fee
	p.mastery["alchemist"] = Professions.points(p, "alchemist") + gain
	var mailed := not p.add_consumable(bottle)
	if mailed:
		g.send_mail("Your brewed potion", "The bottle is ready. Your full pack left it here.",
			[{"kind": "potion", "potion": bottle}])
	g.favor_spend("kesh", fee)
	g.autosave()
	return {"ok": true, "reason": "", "item": bottle, "fee": fee,
		"mastery_gain": gain, "mailed": mailed}


## Independent of the existing gear recipe roll. Only roll_boss_pack calls
## this faucet; its existing owner-only award channel teaches the result.
static func roll_blueprint(rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= Balance.BOSS_BREW_BLUEPRINT_CHANCE:
		return {}
	var choices := shapes()
	var fs := String(choices[rng.randi_range(0, choices.size() - 1)])
	var grade := "A" if rng.randf() < Balance.BOSS_BLUEPRINT_A_FRACTION else "B"
	return Items.make_potion_blueprint(fs, grade)
