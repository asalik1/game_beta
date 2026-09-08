extends RefCounted


static func run(t: Node) -> String:
	var error := _data_contracts()
	if error != "":
		return error
	var g: Game = t.game
	error = _gear_contracts(g)
	if error != "":
		return error
	error = _loot_contracts(g)
	if error != "":
		return error
	var cue_probe := Enemy.new()
	var session := preload("res://scripts/net/net_session.gd").new()
	session.game = g
	error = _cue_checks(cue_probe, session)
	session.free()
	cue_probe.free()
	if error != "":
		return error
	var p: Player = g.local_player
	var keep_settings := g.settings.duplicate(true)
	var keep_buffer: RefCounted = p.action_buffer
	var keep_cds := p.cds.duplicate()
	var keep_mp := p.mp
	var keep_frozen := p.frozen_time
	var keep_combo := p.combo
	p.action_buffer = preload("res://scripts/action_buffer.gd").new()
	error = await _live_contracts(t)
	g.menus.close()
	p.action_buffer = keep_buffer
	p.cds = keep_cds
	p.mp = keep_mp
	p.frozen_time = keep_frozen
	p.combo = keep_combo
	g.settings = keep_settings
	if error == "":
		print("ok: buffered taps, overlay cancellation, damage history, gear protection and comfort controls")
	return error


static func _data_contracts() -> String:
	var buffer: RefCounted = preload("res://scripts/action_buffer.gd").new()
	buffer.press("a2", 1.0)
	if not buffer.has_press("a2", 1.05):
		return "a short input expired before a physics tick could consume it"
	buffer.consume("a2")
	if buffer.has_press("a2", 1.05):
		return "one buffered tap fired more than once"
	buffer.press("ult", 2.0)
	if buffer.has_press("ult", 2.0 + Balance.ABILITY_BUFFER_SECONDS):
		return "an expired press remained queued"
	buffer.press("a1", 3.0)
	buffer.clear()
	if buffer.has_press("a1", 3.01):
		return "overlay cancellation retained a press"
	var memory: RefCounted = preload("res://scripts/combat_memory.gd").new()
	memory.record(1.0, 0, 100, 100, "Shielded blow", "phys", false)
	memory.record(2.0, 30, 100, 100, "Wolf", "phys", false)
	memory.record(3.0, 1000, 70, 100, "Guardian", "magic", true)
	var hits: Array = memory.recent(3.0)
	if hits.size() != 2 or hits[1]["amount"] != 70.0 or hits[1]["hp"] != 0.0:
		return "damage history counted shield absorption or overkill as lost health"
	memory.fall(3.0, "The test room")
	memory.clear_recent()
	if memory.last_defeat["hits"].size() != 2:
		return "recovery erased the last fall's snapshot"
	memory.record(4.0, 10, 100, 100, "Wolf", "phys", false)
	if not memory.recent(4.0 + Balance.COMBAT_MEMORY_SECONDS + 0.1).is_empty():
		return "recent-damage window never expired"
	for i in Balance.COMBAT_MEMORY_MAX_HITS + 10:
		memory.record(30.0, 1, 100, 100, "Wolf", "phys", false)
	if memory.hits.size() != Balance.COMBAT_MEMORY_MAX_HITS:
		return "damage history grew past its memory bound"
	return ""


static func _cue_checks(e: Enemy, session: Node) -> String:
	var cues := preload("res://scripts/combat_cues.gd")
	e.vuln_time = 2.0
	e.reflect_t = 1.0
	if cues.code_for(e) != cues.Cue.REFLECT:
		return "an exposure hint encouraged attacking a reflecting enemy"
	session.net_enemies = {42: e}
	e.hp = 50.0
	e.max_hp = 100.0
	var packet: PackedByteArray = session._enemy_state_packet()
	if packet.size() != 14:
		return "tactical cues changed the enemy packet size"
	e.net_mirror = true
	e.reflect_t = 0.0
	session._apply_enemy_state_packet(packet)
	if cues.code_for(e) != cues.Cue.REFLECT or absf(e.hp - 50.0) > 0.5:
		return "the enemy wire packet lost a combat cue or corrupted HP"
	e.net_mirror = false
	e.reflect_t = 0.0
	if cues.code_for(e) != cues.Cue.EXPOSED:
		return "a damage opportunity did not become visible after reflect ended"
	e.net_mirror = true
	e.net_apply_state(Vector2(4, 8), true, false, 1.0, false, false, false, cues.Cue.HEAL)
	if cues.code_for(e) != cues.Cue.HEAL:
		return "a guest's tactical instruction read unsimulated local timers"
	e.net_apply_state(Vector2.ZERO, false, false, 1.0)
	if cues.code_for(e) != cues.Cue.NONE:
		return "an expired host cue remained on its guest mirror"
	e.dying = true
	e.net_combat_cue = cues.Cue.EXPOSED
	if cues.code_for(e) != cues.Cue.NONE:
		return "a dead enemy retained a tactical instruction"
	return ""


static func _loot_contracts(g: Game) -> String:
	var p: Player = g.local_player
	var before := g.get_children()
	var keep := {"backpack": p.backpack, "bags": p.bags, "gold": p.gold, "dropped": g.dropped_loot, "stash": g.stash}
	p.backpack = []
	p.bags = [{"grade": "S", "slots": 100000}]
	g.dropped_loot = []
	g.stash = []
	var error := _loot_checks(g, before)
	p.backpack = keep["backpack"]
	p.bags = keep["bags"]
	p.gold = keep["gold"]
	g.dropped_loot = keep["dropped"]
	g.stash = keep["stash"]
	for node in g.get_children():
		if node is Pickup and not before.has(node):
			node.queue_free()
	return error


static func _loot_checks(g: Game, before: Array) -> String:
	var p: Player = g.local_player
	Pickup.drop_gold(g, 7, p.global_position + Vector2(200, 0))
	Pickup.drop_gold(g, 14, p.global_position + Vector2(230, 0))
	Pickup.drop_gold(g, 0, p.global_position + Vector2(260, 0))
	var total := 0
	var first: Pickup
	for node in g.get_children():
		if node is Pickup and not before.has(node):
			total += node.value
			first = node
	if first == null or total != g.gold_scaled(7) + g.gold_scaled(14):
		return "splitting gold into coins changed the rolled reward"
	var old_gold := p.gold
	var expected := p.gold_yield(first.value)
	first._on_body_entered(p)
	first._on_body_entered(p)
	if p.gold != old_gold + expected:
		return "a deferred coin paid twice before being freed"
	var rng := RandomNumberGenerator.new()
	rng.seed = 2472
	var payload := {"kind": "item", "item": Items.roll_item_of("weapon", "F", rng, p.cls)}
	var twin := payload.duplicate(true)
	var a := Pickup.drop_loot(g, payload, p.global_position)
	var b := Pickup.drop_loot(g, twin, p.global_position)
	# Equal drop payloads still belong to two distinct world pickups.
	twin["pos"] = payload["pos"].duplicate()
	g.dropped_loot = [payload, twin]
	b._try_claim(p)
	b._try_claim(p)
	if p.backpack.size() != 1 or g.dropped_loot.size() != 1 or not is_same(g.dropped_loot[0], payload):
		return "claiming identical overflow loot removed or duplicated the wrong drop"
	a._try_claim(p)
	if p.backpack.size() != 2 or not g.dropped_loot.is_empty():
		return "a second identical overflow drop was lost"
	p.set_gear_kept(payload["item"], true)
	if not g.stash_deposit_from_bag(payload) or g.stash_deposit_from_bag(payload):
		return "a repeated deposit duplicated an item into the account stash"
	if g.stash.size() != 1 or p.backpack.size() != 1:
		return "stash deposit did not transfer exactly one owned item"
	if not g.stash_withdraw(payload) or g.stash_withdraw(payload):
		return "a repeated withdrawal duplicated a stored item"
	if p.backpack.size() != 2 or not preload("res://scripts/gear_care.gd").kept(p.backpack[1]):
		return "stash round trip lost a kept item or its protection"
	return ""


static func _gear_contracts(g: Game) -> String:
	var p: Player = g.local_player
	var bag := p.backpack
	var worn := p.equipment
	var gems := p.gem_bag
	var gold := p.gold
	var hp := p.hp
	var mp := p.mp
	var err := _gear_checks(p)
	p.backpack = bag
	p.equipment = worn
	p.gem_bag = gems
	p.gold = gold
	p.recalc()
	p.hp = hp
	p.mp = mp
	p._update_weapon_visual()
	return err


static func _gear_checks(p: Player) -> String:
	var care := preload("res://scripts/gear_care.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 80412
	var first: Dictionary = Items.roll_item_of("weapon", "F", rng, p.cls)
	var twin := first.duplicate(true)
	p.backpack = [first, twin]
	p.equipment = {}
	p.gem_bag = []
	if not p.set_gear_kept(first, true):
		return "owned gear could not be kept"
	if care.index_of(p.backpack, twin) != 1 or care.sellable(p.backpack).size() != 1:
		return "gear protection confused two otherwise identical items"
	if p.discard_gear(first):
		return "kept gear could be discarded"
	var before := p.gold
	var expected := p.gold_yield(care.sale_value(twin))
	var result := p.sell_gear([first, twin, twin])
	if result["count"] != 1 or p.gold != before + expected or result["gold"] != expected or p.backpack.size() != 1:
		return "bulk sale ignored protection or paid twice for the same item"
	if p.sell_gear([twin])["count"] != 0:
		return "stale sale callback paid for an item no longer owned"
	var loaded: Dictionary = SaveGame._fix_item(JSON.parse_string(JSON.stringify(first)))
	if not care.kept(loaded):
		return "save normalization forgot kept gear"
	p.equip(first)
	var size_before := p.backpack.size()
	p.equip(first)
	if p.backpack.size() != size_before:
		return "equipping an already worn item duplicated it into the bag"
	var better := first.duplicate(true)
	better["kept"] = false
	better["main"] = {"atk_flat": 1000.0}
	p.backpack = [better]
	if p.auto_equip() != 0 or not is_same(p.equipment["weapon"], first):
		return "auto-equip displaced kept equipment"
	var rows: Array = care.comparison(better, first)
	if rows.is_empty():
		return "gear comparison produced no stat rows"
	var sorted: Array = care.sorted([better, first], "kept")
	if not is_same(sorted[0], first):
		return "kept-first sorting lost item identity"
	return ""


static func _live_contracts(t: Node) -> String:
	var g: Game = t.game
	var p: Player = g.local_player
	g.menus.close()
	await t._frames(2)
	p.cds["a1"] = 0.0
	p.mp = p.max_mp
	p.frozen_time = 0.0
	p.combo = 0.0
	# Both edges arrive before the next physics tick. Held-state polling alone
	# loses this input, which is exactly the quick-tap regression being guarded.
	t._press_key(int(g.binds["a1"]), true)
	t._press_key(int(g.binds["a1"]), false)
	Input.flush_buffered_events()
	if not p.action_buffer.has_press("a1", Time.get_ticks_msec() * 0.001):
		return "a real keyboard tap failed to queue (state %d, overlay %s, dead %s, down %s, ghost %s, input %s, paused %s)" % [g.state, g.input_overlay_up(), p.dead, p.downed, p.ghost, p.is_processing_input(), t.get_tree().paused]
	await t.get_tree().physics_frame
	await t._frames(1)
	if p.action_buffer.has_press("a1", Time.get_ticks_msec() * 0.001):
		return "physics did not consume the released key's buffered ability"
	p.cds["a1"] = 0.05
	p.mp = p.max_mp
	g.hud.combat_feedback.ability_notice("a1", "Not enough mana")
	p.queue_ability("a1")
	p._physics_process(0.02)
	if p.action_buffer.pending.is_empty():
		return "a buffered press bypassed the remaining cooldown"
	p._physics_process(0.04)
	if not p.action_buffer.pending.is_empty() or p.cds["a1"] <= 0.0:
		return "a buffered press was lost as its cooldown finished"
	if g.hud.combat_feedback._notice_t > 0.0:
		return "a successful cast retained its obsolete refusal notice"
	p.queue_ability("a2")
	p._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if not p.action_buffer.pending.is_empty():
		return "window focus loss retained a buffered cast"
	p.queue_ability("a2")
	g.menus.open_pause()
	p.clear_local_intents()
	if not p.action_buffer.pending.is_empty():
		return "opening a menu retained a combat input"
	p.queue_ability("ult")
	if not p.action_buffer.pending.is_empty():
		return "a menu accepted an ability tap"
	g.hud.combat_feedback._process(0.0)
	if g.hud.combat_feedback.visible:
		return "combat feedback remained visible under a menu"
	preload("res://scripts/ui/comfort.gd").open(g.menus)
	await t._frames(3)
	var slider := g.menus.root.find_child("impact_flashes", true, false) as HSlider
	if slider == null:
		return "comfort screen did not expose impact-flash control"
	slider.value = 0.0
	g.hud.flash_screen(Color.RED, 0.8)
	if g.hud.flash_rect.color.a != 0.0:
		return "zero impact flashes still produced a screen wash"
	preload("res://scripts/ui/combat_report.gd").open(g.menus)
	await t._frames(2)
	if g.menus.current != "combat_report":
		return "combat report failed to open"
	return ""
