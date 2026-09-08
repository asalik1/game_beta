extends RefCounted
## Inventory views preserve object identity. Matching stats do not make two
## separate dropped items interchangeable when one is kept or sold.


static func index_of(items: Array, item: Dictionary) -> int:
	for i in items.size():
		if is_same(items[i], item):
			return i
	return -1


static func kept(item: Dictionary) -> bool:
	return bool(item.get("kept", false))


static func sale_value(item: Dictionary) -> int:
	return maxi(1, int(Items.price(item) * Balance.MERCHANT_SELL_FRACTION))


static func sellable(items: Array, max_grade := "S") -> Array:
	var out: Array = []
	var limit := Items.GRADES.find(max_grade)
	for item in items:
		if not kept(item) and Items.GRADES.find(String(item["grade"])) <= limit:
			out.append(item)
	return out


static func sorted(items: Array, mode: String) -> Array:
	var out := items.duplicate()
	if mode == "found":
		return out
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if mode == "kept" and kept(a) != kept(b):
			return kept(a)
		if mode == "slot" and a["slot"] != b["slot"]:
			return Items.SLOTS.find(a["slot"]) < Items.SLOTS.find(b["slot"])
		if a["grade"] != b["grade"]:
			return Items.GRADES.find(a["grade"]) > Items.GRADES.find(b["grade"])
		if a["plus"] != b["plus"]:
			return int(a["plus"]) > int(b["plus"])
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out


static func comparison(item: Dictionary, worn: Dictionary) -> Array[Dictionary]:
	var candidate := Items.stats_of(item)
	var equipped := Items.stats_of(worn) if not worn.is_empty() else {}
	var keys := candidate.keys()
	for key in equipped:
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var out: Array[Dictionary] = []
	for stat in keys:
		var after: float = candidate.get(stat, 0.0)
		var before: float = equipped.get(stat, 0.0)
		out.append({"stat": stat, "before": before, "after": after, "delta": after - before})
	return out


static func stat_text(stat: String, value: float, signed := false) -> String:
	if stat in Items.FLAT_STATS:
		var number := ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
		return ("+" if signed and value > 0.0 else "") + number
	return ("%+.1f%%" if signed else "%.1f%%") % (value * 100.0)
