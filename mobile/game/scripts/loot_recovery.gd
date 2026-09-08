extends RefCounted
## Personal earned spoils survive saves and world teardown. Snapshotting is
## read-only to the world: chests still wait for their painted opening moment.
## Authored caches rebuild through their own discovery/opened flags instead.


static func earned_chest(g: Game, node: Node) -> bool:
	return node is Chest and node.game == g and not node.opened and not node.buried \
		and not node.is_queued_for_deletion() and not node.on_open.is_valid()


static func earned_coin(g: Game, node: Node) -> bool:
	return node is Pickup and node.game == g and node.loot.is_empty() \
		and not node.goldrush and not node.claimed and not node.is_queued_for_deletion()


static func snapshot(g: Game) -> Dictionary:
	var out := {"items": [], "gold": 0, "chests": 0}
	if not g.has_local_player():
		return out
	for node in g.get_children():
		if earned_chest(g, node):
			var contents: Dictionary = node.sealed_contents()
			out.items.append_array(contents.items.duplicate(true))
			out.gold += g.player.gold_yield(int(contents.gold))
			out.chests += 1
		elif earned_coin(g, node):
			# Respect the same per-coin rounding and owner's current bonus as touch.
			out.gold += g.player.gold_yield(int(node.value))
	return out


static func recover_live(g: Game) -> Dictionary:
	var saved := snapshot(g)
	if not g.has_local_player():
		return saved
	retire_live(g)
	return recover_saved(g, saved)


## Applying a saved character replaces its live reward sources too, even when
## a caller restores in place. Otherwise both the chest and its letter survive.
static func retire_live(g: Game) -> void:
	# Consume before paying: repeated teardown/claim callbacks cannot double-pay.
	for node in g.get_children():
		if earned_chest(g, node):
			node.opened = true
			node.queue_free()
		elif earned_coin(g, node):
			node.claimed = true
			node.queue_free()


static func recover_saved(g: Game, raw: Variant) -> Dictionary:
	var saved := clean(raw)
	if not g.has_local_player() or (saved.items.is_empty() and saved.gold <= 0):
		return saved
	# Already scaled when saved. gain_gold here would apply Greed a second time.
	g.player.gold += int(saved.gold)
	var body := "Your uncollected spoils were recovered. Claim the contents when you have room."
	if saved.gold > 0:
		body += "\n%d gold has already been added to your purse." % int(saved.gold)
	g.send_mail("Recovered Spoils", body, saved.items)
	return saved


## This optional character field is JSON-only and accepts only existing loot
## payloads. Malformed records are ignored without wedging the rest of a save.
static func clean(raw: Variant) -> Dictionary:
	var out := {"items": [], "gold": 0, "chests": 0}
	if not raw is Dictionary:
		return out
	out.gold = _integer(raw.get("gold", 0))
	out.chests = _integer(raw.get("chests", 0))
	var items = raw.get("items", [])
	if items is Array:
		for entry in items:
			var payload := _payload(entry)
			if not payload.is_empty():
				out.items.append(payload)
	return out


static func _integer(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return 0
	# Bound the JSON conversion to a signed 32-bit reward, not a tuning cap.
	if value < 0 or value > 2147483647:
		return 0
	return int(value)


static func _payload(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("kind", "") is String:
		return {}
	match String(raw.kind):
		"item":
			var it = raw.get("item", {})
			if not it is Dictionary or not it.get("slot", "") in Items.SLOTS \
				or not it.get("grade", "") in Items.GRADES:
				return {}
			for key in ["name", "noun"]:
				if not it.get(key, "") is String:
					return {}
			for key in ["main", "subs"]:
				var stats = it.get(key, {})
				if not stats is Dictionary:
					return {}
				for value in stats.values():
					if not (value is int or value is float) or not is_finite(float(value)):
						return {}
			var item: Dictionary = it.duplicate(true)
			item.plus = _integer(item.get("plus", 0))
			item.gem_slots = _integer(item.get("gem_slots", 0))
			item.gems = []
			var gems = it.get("gems", [])
			if gems is Array:
				for gem in gems:
					var restored := _gem(gem)
					if not restored.is_empty():
						item.gems.append(restored)
			return {"kind": "item", "item": item}
		"gem":
			var gem := _gem(raw.get("gem", {}))
			return {"kind": "gem", "gem": gem} if not gem.is_empty() else {}
		"material":
			var family = raw.get("family", "")
			var grade = raw.get("grade", "")
			var count := _integer(raw.get("count", 0))
			if family is String and grade is String and count > 0 \
				and Items.MATERIALS.get(family, {}).has(grade):
				return {"kind": "material", "family": family, "grade": grade, "count": count}
		"bag":
			var grade = raw.get("grade", "")
			if grade is String and Items.BAG_NAMES.has(grade):
				return {"kind": "bag", "grade": grade}
		"potion":
			var pot = raw.get("potion", {})
			if not pot is Dictionary:
				return {}
			for key in ["family", "shape", "grade", "lane"]:
				if not pot.get(key, "") is String:
					return {}
			var made := Items.make_potion(String(pot.get("family", "")), String(pot.get("shape", "")),
				String(pot.get("grade", "")), String(pot.get("lane", "")))
			if not made.is_empty():
				return {"kind": "potion", "potion": made}
	return {}


static func _gem(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var stat = raw.get("stat", "")
	var level := _integer(raw.get("lvl", 0))
	if not stat is String or not Items.GEM_STATS.has(stat) or level < 1 or level > Items.GEM_MAX_LEVEL:
		return {}
	return Items.make_gem(stat, level)
