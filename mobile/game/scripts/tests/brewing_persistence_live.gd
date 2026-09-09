extends "res://shot_party_appearance.gd"
## Existing paired readers/ENet plus the unchanged brewing acceptance logic.
## Appearance checks never run; the public outer ShotRig owns the verdict.
var owner_rig: ShotRig

const Alchemy = preload("res://scripts/alchemy.gd")
const HOST_SLOT := 98
const OTHER_SLOT := 99
const PERSONAL := ["gold", "materials", "consumables", "profession", "mastery", "blueprints", "npc_favor"]
var home_world := {}
var home_chapter := ""
var unaffected_host := {}
var unaffected_files := {}
var accepted: Array[String] = []
var home_initial_file := {}
var home_boundary_sealed := false
var home_save_audit := {"rows": [], "overflow": false}


func run() -> int:
	# A crash/watchdog may skip restoration, so isolated APPDATA is mandatory.
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not user_root.contains("/brewing-persistence-candidate/"):
		push_error("Run with APPDATA inside brewing-persistence-candidate; refusing real profile writes")
		return 1
	var backup := _save_bytes([SLOT, HOST_SLOT, OTHER_SLOT])
	await _reader("warrior", "Host")
	await _reader("mage", "Guest")
	var error: String
	if flag("ui-only"):
		shot_dir += "/ui"
		error = await preload("res://scripts/tests/alchemy_enet_ui.gd").run_enet(self)
	else:
		error = await _checks()
	if error != "":
		_show(1)
		shot("diagnostic_before_cleanup")
	get_tree().paused = false
	for i in readers.size():
		readers[i].no_saves = true
		readers[i].save_slot = -1
		readers[i].guest_world = false
		readers[i].qa_online = false
		wires[i].set_physics_process(false)
		roots[i].online = false
	for transport in transports: transport.close()
	for i in apis.size():
		apis[i].multiplayer_peer = null
		get_tree().set_multiplayer(null, roots[i].get_path())
	var restored := _restore_bytes(backup)
	if not restored: error += " fixture save bytes did not restore"
	report.merge({"checks": accepted, "error": error, "fixture_save_bytes_restored": restored,
		"ordinary_input_gameplay": false, "real_file_roundtrip": not flag("ui-only"), "real_enet_transport": true,
		"qualification": "Controlled paired capital fixture; real ENet award/travel transport and actual Alchemy input. UI-only branch skips domain persistence checks; see UI rows and qualified child-scene disconnect diagnostic." if flag("ui-only") else "Fixture resources and direct domain commits; production save/load, world snapshots, travel and reliable award fanout. Boss reward trigger/duplicate recipe packets are posed, not actual boss combat. Native UI acceptance is a separate candidate."}, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))
	var file := FileAccess.open(shot_dir + "/acceptance.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	_print_report_summary(error, restored)
	if error != "":
		push_error(error)
		return 1
	return 0


func _save_bytes(slots: Array) -> Dictionary:
	var out := {}
	for slot in slots:
		for suffix in ["", ".bak", ".tmp"]:
			var path := SaveGame.path(int(slot)) + String(suffix)
			out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


func _restore_bytes(files: Dictionary) -> bool:
	var ok := true
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and ok
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				ok = false
			else:
				file.store_buffer(files[path])
				file.close()
	for path in files:
		var current: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		ok = current == files[path] and ok
	return ok


func _normal(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _personal(g: Game) -> Dictionary:
	var out := {}
	for key in PERSONAL: out[key] = _normal(g.player.get(key))
	out.mailbox = _normal(g.mailbox)
	return out


func _saved_personal(slot: int) -> Dictionary:
	var character := SaveGame.character_of(SaveGame.read(slot))
	var out := {}
	for key in PERSONAL: out[key] = character.get(key)
	out.mailbox = character.get("mailbox", [])
	return out


func _observe_others() -> void:
	unaffected_host = _personal(readers[0])
	unaffected_files = _save_bytes([HOST_SLOT, OTHER_SLOT])


func _ownership_error(g: Game) -> String:
	if _personal(readers[0]) != unaffected_host or _save_bytes([HOST_SLOT, OTHER_SLOT]) != unaffected_files:
		return "guest action changed host inventory or another character's save bytes"
	var saved := SaveGame.read(SLOT)
	if SaveGame.world_of(saved) != home_world or String(saved.get("chapter", "")) != home_chapter:
		var observed_world := SaveGame.world_of(saved)
		var world_differences := {}
		for key in home_world:
			if observed_world.get(key) != home_world[key]:
				world_differences[key] = {"before": home_world[key], "after": observed_world.get(key)}
		for key in observed_world:
			if not home_world.has(key):
				world_differences[key] = {"added": observed_world[key]}
		report.home_mismatch = {"expected_chapter": home_chapter, "actual_chapter": saved.get("chapter"),
			"world_differences": world_differences, "world_equal": observed_world == home_world,
			"guest_world": g.guest_world, "restoring": g.restoring_save}
		return "guest character write replaced its exact saved home world/chapter"
	if _saved_personal(SLOT) != _personal(g):
		return "guest autosave did not persist exact materials/gold/bottles/mastery/knowledge/favor/mail"
	return ""


func _until(predicate: Callable, seconds := 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds*1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return true
		await get_tree().create_timer(0.03, true).timeout
	return bool(predicate.call())


func _quiet(index: int) -> void:
	_show(index)
	await skip_dialogue()
	var g: Game = readers[index]
	g.menus.close()
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.request_pause(false)
	g.player.dead = false
	g.player.downed = false
	g.player.ghost = false
	g.player.hp = g.player.max_hp
	g.player.mp = g.player.max_mp
	g.player.set_physics_process(false)
	g.terrain_event_t = 10000.0
	await frames(3)


func _loan(g: Game) -> void:
	# Explicit test resources, never represented as normal acquisition/pacing.
	var p: Player = g.local_player
	p.profession = "alchemist"
	p.mastery = {"alchemist": 500}
	p.blueprints = [Items.blueprint_key("gloves", "B")]
	p.gold = 1000000
	p.resonance = 0.0
	p.npc_favor = {}
	p.greed = 0.0
	p.goldrush_time = 0.0
	p.backpack = []
	p.gem_bag = []
	p.consumables = []
	p.loose_bags = []
	p.bags = [Items.make_bag("A")]
	p.materials = []
	for grade in ["F", "B", "A"]:
		p.materials.append(Items.make_material("herb", grade, 20))
		p.materials.append(Items.make_material("reagent", grade, 20))
	g.mailbox = []
	g.retire_dropped_loot()


func _brew_exact(g: Game, fs: String, grade: String) -> String:
	var p: Player = g.local_player
	var order := Alchemy.prepare(g, fs, grade)
	var quote := order.view()
	if not bool(quote.allowed): return "fixture recipe blocked: " + String(quote.reason)
	var gold := p.gold
	var herbs := p.material_count("herb", grade)
	var reagents := p.material_count("reagent", grade)
	var mastery := Professions.points(p, "alchemist")
	var bottle_count := p.consumables.size()
	var mail_count := g.mailbox.size()
	var result := Alchemy.commit(order)
	if not bool(result.ok) or p.gold != gold-int(quote.fee) \
			or p.material_count("herb", grade) != herbs-int(quote.herbs) \
			or p.material_count("reagent", grade) != reagents-int(quote.reagents) \
			or Professions.points(p, "alchemist") != mastery+int(quote.mastery_gain):
		return "brew failed exact resources or mastery settlement"
	if bool(result.mailed):
		if p.consumables.size() != bottle_count or g.mailbox.size() != mail_count+1 \
				or g.mailbox[-1].items != [{"kind": "potion", "potion": result.item}]:
			return "full-pack brew did not create precisely one canonical mailed bottle"
	else:
		if p.consumables.size() != bottle_count+1 or p.consumables[-1] != result.item or g.mailbox.size() != mail_count:
			return "brew did not create precisely one canonical carried bottle"
	var after := _personal(g)
	var bytes := _save_bytes([SLOT])
	if bool(Alchemy.commit(order).ok) or _personal(g) != after or _save_bytes([SLOT]) != bytes:
		return "repeated order changed live or durable inventory"
	return ""


func _buy_exact(g: Game, fs: String, grade: String) -> String:
	var p: Player = g.local_player
	var order := Alchemy.prepare(g, fs, grade, "blueprint")
	var quote := order.view()
	if not bool(quote.allowed): return "fixture blueprint blocked: " + String(quote.reason)
	var gold_before := p.gold
	var gold_expected := gold_before-int(quote.fee)
	var before := _personal(g)
	var result := Alchemy.commit(order)
	var expected := before.duplicate(true)
	# _personal is JSON-normalized, so its numbers are floats. Keep this
	# comparison in the same representation AND assert the live integer debit.
	expected.gold = _normal(gold_expected)
	expected.blueprints.append(Items.blueprint_key(Items.potion_blueprint_slot(fs), grade))
	var actual := _personal(g)
	var legacy_expected := expected.duplicate(true)
	legacy_expected.gold = gold_expected
	var differences := {}
	for key in expected:
		if not actual.has(key) or actual[key] != expected[key]:
			differences[key] = {"expected": expected[key], "actual": actual.get(key),
				"expected_type": type_string(typeof(expected[key])),
				"actual_type": type_string(typeof(actual.get(key)))}
	if not report.has("purchase_diagnostics"): report.purchase_diagnostics = []
	report.purchase_diagnostics.append({"shape": fs, "grade": grade,
		"result_ok": bool(result.ok), "result_reason": String(result.get("reason", "")),
		"gold_before": gold_before, "fee": int(quote.fee), "gold_expected": gold_expected,
		"gold_actual": p.gold, "live_gold_type": type_string(typeof(p.gold)),
		"snapshot_gold_type": type_string(typeof(actual.gold)),
		"legacy_expected_gold_type": type_string(typeof(legacy_expected.gold)),
		"legacy_snapshot_equal": actual == legacy_expected,
		"normalized_snapshot_equal": actual == expected, "differences": differences})
	if not bool(result.ok) or not result.has("blueprint") or typeof(p.gold) != TYPE_INT \
			or p.gold != gold_expected or actual != expected:
		return "blueprint purchase changed more than exact gold and one recipe key"
	var bytes := _save_bytes([SLOT])
	if bool(Alchemy.commit(order).ok) or p.gold != gold_expected \
			or _personal(g) != expected or _save_bytes([SLOT]) != bytes:
		return "repeated blueprint order settled twice"
	return ""


func _checks() -> String:
	var host: Game = readers[0]
	var guest: Game = readers[1]
	step("solo brew and purchase use real per-character autosave")
	for i in 2:
		readers[i].switch_chapter("capital", true)
		await _quiet(i)
		_loan(readers[i])
	host.player.char_name = "Brew QA Host"
	guest.player.char_name = "Brew QA Guest"
	SaveGame.write(host, HOST_SLOT)
	var other := SaveGame.read(HOST_SLOT).duplicate(true)
	other.character.name = "Brew QA Unrelated Character"
	other.character.gold = 24680
	if not SaveGame.atomic_store(SaveGame.path(OTHER_SLOT), JSON.stringify(other)):
		return "could not create isolated unrelated-character control"
	_observe_others()
	guest.save_slot = SLOT
	guest.no_saves = false
	guest.guest_world = false
	guest.autosave()
	var error := _brew_exact(guest, "health_instant", "F")
	if error == "": error = _buy_exact(guest, "health_instant", "B")
	if error != "": return error
	if _saved_personal(SLOT) != _personal(guest): return "solo brew/purchase did not reach the real character save"
	var exact := _personal(guest)
	guest.no_saves = true
	guest.player.gold = 1
	guest.player.materials = []
	guest.player.consumables = []
	guest.player.mastery = {}
	guest.player.blueprints = []
	guest.mailbox = []
	guest.load_save(SLOT)
	await _quiet(1)
	if _personal(guest) != exact:
		return "actual load_save roundtrip lost materials/gold/bottles/mastery/recipe knowledge"
	if _personal(host) != unaffected_host or _save_bytes([HOST_SLOT, OTHER_SLOT]) != unaffected_files:
		return "solo brewing roundtrip changed another character's inventory or save"
	accepted.append("solo exact brew + B purchase -> real autosave -> destructive in-memory wipe -> actual load_save restores all brewing fields")
	await _capture_milestone("01_solo_roundtrip")
	# Establish a distinct home chapter/seed BEFORE joining the host's capital.
	guest.switch_chapter("ch2", true)
	await _quiet(1)
	guest.flags["alchemy_qa_home_marker"] = true
	guest.no_saves = false
	guest.autosave()
	var saved := SaveGame.read(SLOT)
	home_world = SaveGame.world_of(saved).duplicate(true)
	home_chapter = String(saved.chapter)
	if home_chapter == host.chapter_id: return "home-world control is not distinct from the host capital"
	# The await in the transport handshake still runs the home world. Capture
	# its initial file and trace legitimate own-world autosaves until dispatch.
	home_initial_file = guest.call("qa_save_file", SLOT)
	home_boundary_sealed = false
	home_save_audit = {"rows": [], "overflow": false}
	for reader in readers:
		reader.qa_save_audit = home_save_audit
	report["home_pre_dispatch_autosaves"] = home_save_audit
	_observe_others()
	step("real ENet join uses production host snapshot and own saved character")
	if transports[0].create_server(0, 2) != OK: return "ENet server bind failed"
	apis[0].multiplayer_peer = transports[0]
	if not await _connect_guest(): return "ENet guest join/snapshot timed out"
	await _quiet(1)
	if not guest.net_guest() or guest.chapter_id != "capital" or not guest.guest_world \
			or guest.save_slot != SLOT or guest.local_player == _shell(1, 1):
		return "production snapshot did not establish the local guest's home-owned capital visit"
	error = _ownership_error(guest)
	if error != "": return error
	accepted.append("real ENet snapshot loads own character into host capital; exact home chapter/world retained")
	step("guest-owned brew, A recipe purchase and A brew")
	error = _brew_exact(guest, "health_instant", "B")
	if error == "": error = _buy_exact(guest, "mana_instant", "A")
	if error == "": error = _brew_exact(guest, "mana_instant", "A")
	if error == "": error = _ownership_error(guest)
	if error != "": return error
	accepted.append("guest B brew + A purchase + A brew settle once and persist only the owning character")
	await _capture_milestone("02_guest_owned_brewing")
	step("guest overflow mail persists then real mailbox claim consumes it once")
	# Partial ingredient stacks survive this brew so no consumed stack frees a slot.
	while guest.player.bag_used() < guest.player.bag_capacity():
		guest.player.consumables.append(Items.make_recall_scroll())
	guest.autosave()
	var mails := guest.mailbox.size()
	error = _brew_exact(guest, "health_instant", "F")
	if error != "": return error
	if guest.mailbox.size() != mails+1: return "overflow fixture failed to produce mail"
	error = _ownership_error(guest)
	if error != "": return error
	var mailed_state := _personal(guest)
	# Real save parser + apply_character, keeping the borrowed world in place.
	guest.restoring_save = true
	SaveGame.apply_character(guest, SaveGame.character_of(SaveGame.read(SLOT)), false)
	guest.restoring_save = false
	await _quiet(1)
	if _personal(guest) != mailed_state: return "mailed bottle or ingredients failed the guest save reload"
	var letter: Dictionary = guest.mailbox[-1]
	var before_claim := _personal(guest)
	UIMailbox._claim(guest.menus, letter)
	if _personal(guest).consumables != before_claim.consumables or letter.items.size() != 1:
		return "full-pack mailbox claim lost or paid an overflow attachment"
	guest.player.consumables.pop_back() # fixture frees exactly its own filler slot
	var carried := guest.player.consumables.size()
	UIMailbox._claim(guest.menus, letter)
	if not letter.items.is_empty() or guest.player.consumables.size() != carried+1:
		return "real mailbox claim did not recover exactly one brewed bottle"
	UIMailbox._claim(guest.menus, letter)
	if guest.player.consumables.size() != carried+1: return "empty letter paid a bottle twice"
	guest.menus.close()
	error = _ownership_error(guest)
	if error != "": return error
	accepted.append("guest full-pack brew mails once; file reload retains mail; full claim refuses then one freed slot claims once")
	await _capture_milestone("03_overflow_recovered")
	# Free the remaining fixture filler, leaving actual brewed bottles intact.
	guest.player.consumables = guest.player.consumables.filter(func(c: Dictionary) -> bool: return String(c.get("id", "")) != "recall_scroll")
	guest.autosave()
	step("production party travel invalidates retained bench orders")
	var old_order := Alchemy.prepare(guest, "health_instant", "F")
	if not bool(old_order.view().allowed): return "travel order was never eligible"
	var old_world := guest.world.get_instance_id()
	host.switch_chapter("ch2", true)
	# The host's own chapter change can reconcile its teaching bottle. Baseline
	# that explicit host action before testing anything the guest does next.
	unaffected_host = _personal(host)
	wires[0].host_advance_party()
	if not await _until(func() -> bool: return guest.chapter_id == "ch2" and guest.world.get_instance_id() != old_world):
		return "party travel did not rebuild guest world"
	await _quiet(0)
	await _quiet(1)
	var after_travel := _personal(guest)
	var travel_bytes := _save_bytes([SLOT])
	if bool(Alchemy.commit(old_order).ok) or _personal(guest) != after_travel or _save_bytes([SLOT]) != travel_bytes:
		return "an old capital quote spent after production travel"
	error = _ownership_error(guest)
	if error != "": return error
	accepted.append("real reliable party travel replaces guest world and rejects old order without live/save changes")
	step("posed campaign boss fanout carries both potion and existing gear blueprints")
	error = await _boss_fanout(host, guest)
	if error != "": return error
	accepted.append("real host_boss_kill fanout delivers a seeded full campaign reward pack; potion/gear knowledge each learns once, gear chest retained")
	# Return to capital with real travel so the order is eligible before teardown.
	host.switch_chapter("capital", true)
	unaffected_host = _personal(host)
	wires[0].host_advance_party()
	if not await _until(func() -> bool: return guest.chapter_id == "capital"): return "return-to-capital travel timed out"
	await _quiet(0)
	await _quiet(1)
	var reconnect_order := Alchemy.prepare(guest, "health_instant", "F")
	if not bool(reconnect_order.view().allowed): return "reconnect order was never eligible"
	step("real transport disconnect and snapshot reconnect preserve home and invalidate old order")
	var old_pid := apis[1].get_unique_id()
	transports[1].close()
	apis[1].multiplayer_peer = null
	roots[1].online = false
	guest.qa_online = false
	wires[1].set_physics_process(false)
	wires[1]._on_session_ended("brewing persistence fixture disconnect")
	if not await _until(func() -> bool: return not wires[0].peer_chars.has(old_pid)): return "host retained disconnected guest roster"
	if SaveGame.world_of(SaveGame.read(SLOT)) != home_world: return "disconnect overwrote guest home"
	if not await _connect_guest(): return "real transport reconnect/snapshot timed out"
	await _quiet(1)
	var returned := _personal(guest)
	var returned_bytes := _save_bytes([SLOT])
	if bool(Alchemy.commit(reconnect_order).ok) or _personal(guest) != returned or _save_bytes([SLOT]) != returned_bytes:
		return "a pre-reconnect order spent against the replacement world"
	error = _ownership_error(guest)
	if error != "": return error
	# A fresh quote still works: old quote invalidation must not brick the bench.
	error = _brew_exact(guest, "health_instant", "F")
	if error == "": error = _ownership_error(guest)
	if error != "": return error
	accepted.append("actual close/reconnect/new snapshot restores own progress, rejects old order, accepts a fresh brew")
	await _capture_milestone("04_reconnected_owner")
	return ""


func _connect_guest() -> bool:
	var guest: Game = readers[1]
	if transports[1].create_client("127.0.0.1", transports[0].host.get_local_port()) != OK: return false
	apis[1].multiplayer_peer = transports[1]
	if not await _until(func() -> bool: return not apis[0].get_peers().is_empty() and apis[1].get_unique_id() > 1): return false
	var pid := apis[1].get_unique_id()
	roots[0].peers[pid] = {}
	roots[1].peers[1] = {}
	roots[1].online = true
	for i in 2:
		readers[i].qa_online = true
		wires[i].set_physics_process(true)
	wires[1].local_char = {"slot": SLOT, "name": "Brew QA Guest", "cls": "mage"}
	wires[1].world_ready = false
	readers[0].player.peer_id = 1
	guest.player.peer_id = pid
	guest.no_saves = false
	if not home_initial_file.is_empty() and not _seal_home_before_dispatch():
		return false
	# No await between the exact file boundary above and this dispatch.
	if not home_initial_file.is_empty():
		home_save_audit["phase"] = "snapshot_dispatched"
	wires[0]._send_snapshot(pid)
	var ready: bool = await _until(func() -> bool: return bool(wires[1].world_ready) and wires[0].peer_chars.has(pid) and _shell(0, pid) != null)
	for reader in readers:
		reader.qa_save_audit = {}
	return ready


func _boss_fanout(host: Game, guest: Game) -> String:
	var chosen_seed := -1
	var selected: Array = []
	var bp_events: Array = []
	var at := host.room_center(0) + Vector2(320, 100)
	# Search live roller output; no hand-picked fake recipe bypasses the source.
	for seed_value in range(9100, 14100):
		host.loot_rng.seed = seed_value
		var pack: Array = host.roll_boss_pack("stormwarden", at, 8, false, guest.player.cls)
		var has_potion := false
		var has_gear := false
		for event in pack:
			if String(event.get("k", "")) != "blueprint": continue
			if guest.player.blueprints.has(String(event.bp.key)): continue
			if String(event.bp.slot).begins_with("potion/"): has_potion = true
			else: has_gear = true
		if has_potion and has_gear:
			chosen_seed = seed_value
			selected = pack
			break
	if chosen_seed < 0: return "bounded boss seed search could not find unknown potion + gear recipes"
	var keys := guest.player.blueprints.duplicate()
	var before_chests := _gear_chests(guest)
	var expected_grade := ""
	for event in selected:
		if String(event.get("k", "")) == "blueprint":
			bp_events.append(event)
			if not keys.has(String(event.bp.key)): keys.append(String(event.bp.key))
		if String(event.get("k", "")) == "chest" and String(event.get("chest_kind", "gear")) == "gear":
			expected_grade = String(event.grade)
	if expected_grade == "": return "selected live boss pack omitted guaranteed gear chest"
	host.loot_rng.seed = chosen_seed
	wires[1].last_award = []
	wires[0].host_boss_kill("stormwarden", at, 8, false)
	if not await _until(func() -> bool: return guest.player.blueprints == keys): return "real boss fanout did not teach both expected personal recipes"
	await frames(6)
	if wires[1].last_award != selected: return "boss fanout delivered a different full reward package"
	var after_chests := _gear_chests(guest)
	if after_chests.size() != before_chests.size()+1: return "potion recipe extension changed guaranteed gear chest count"
	var new_grade := ""
	for id in after_chests:
		if not before_chests.has(id): new_grade = String(after_chests[id])
	if new_grade != expected_grade: return "potion recipe extension changed guaranteed gear chest grade"
	# Duplicate ONLY the recipe events, not the full loot package. The existing
	# award transport is not a durable all-packet deduplication protocol.
	wires[0].host_award_all(bp_events)
	wires[0].host_award_all(bp_events)
	await _settle(0.5)
	if guest.player.blueprints != keys or _gear_chests(guest) != after_chests:
		return "duplicate recipe events changed knowledge or gear loot"
	# Ground gold/chests are legitimate posed rewards. Bank/retire their live
	# bodies before travel and save comparisons, using the normal recovery path.
	preload("res://scripts/loot_recovery.gd").recover_live(guest)
	guest.flush_dropped_loot()
	guest.autosave()
	var error := _ownership_error(guest)
	if error != "": return error
	report.boss_seed = chosen_seed
	report.boss_reward_method = "Posed host_boss_kill call at a seeded campaign reward; real ENet delivery and owner apply, no boss combat. Duplicate test repeats blueprint events only."
	return ""


func _gear_chests(g: Game) -> Dictionary:
	var out := {}
	for node in g.get_children():
		if node is Chest and node.kind == "gear" and not node.is_queued_for_deletion():
			out[node.get_instance_id()] = node.grade
	return out


func _boundary_failure(reason: String) -> bool:
	report["home_boundary_error"] = reason
	return false


func _seal_home_before_dispatch() -> bool:
	var guest: Game = readers[1]
	# The host must dispatch synchronously; otherwise its internal wait would
	# leave another unobserved pre-receipt interval after this boundary.
	if not readers[0].play_started:
		return _boundary_failure("host was not ready for synchronous snapshot dispatch")
	if _personal(readers[0]) != unaffected_host or _save_bytes([HOST_SLOT, OTHER_SLOT]) != unaffected_files:
		return _boundary_failure("host/other-character control changed before snapshot dispatch")
	var current: Dictionary = guest.call("qa_save_file", SLOT)
	if home_boundary_sealed:
		# Reconnect checks the ORIGINAL sealed world. Never establish a newer
		# expectation after a guest receipt, action, travel or disconnect.
		var same: bool = current.world == home_world and String(current.chapter) == home_chapter
		report["reconnect_pre_dispatch_home_equal"] = same
		return same or _boundary_failure("reconnect reached dispatch with a changed sealed home world")
	if guest.guest_world or guest.chapter_id != String(home_initial_file.chapter) \
			or wires[1].world_ready or bool(home_save_audit.overflow):
		return _boundary_failure("first boundary was not a complete pre-snapshot own-world trace")
	# Every changed primary file must be accounted for by this local guest's
	# production full-save call. Hash chaining also detects untraced/direct
	# writes; another reader cannot secretly overwrite SLOT and be rebaselined.
	var expected_hash := String(home_initial_file.sha256)
	var writes := 0
	for raw in home_save_audit.rows:
		var entry: Dictionary = raw
		if entry.before.sha256 == entry.after.sha256:
			continue
		if int(entry.owner_id) != guest.get_instance_id() or int(entry.slot) != SLOT \
				or bool(entry.guest_world) or bool(entry.restoring) or bool(entry.no_saves) \
				or String(entry.chapter) != String(home_initial_file.chapter):
			return _boundary_failure("a pre-dispatch write was not the guest saving its own live home")
		if String(entry.before.sha256) != expected_hash:
			return _boundary_failure("pre-dispatch save hash chain contains an untraced write")
		expected_hash = String(entry.after.sha256)
		writes += 1
	if String(current.sha256) != expected_hash:
		return _boundary_failure("last pre-dispatch file changed outside the traced autosave chain")
	if String(current.chapter) != String(home_initial_file.chapter):
		return _boundary_failure("pre-dispatch save changed the home chapter")
	report["home_dispatch_boundary"] = {"initial": home_initial_file, "last_solo": current,
		"initial_world_equal": current.world == home_initial_file.world, "explained_full_writes": writes,
		"dispatch_frame": Engine.get_process_frames(), "guest_world": guest.guest_world,
		"qualification": "Exact existing file immediately before first host snapshot dispatch. Every intervening changed write must have an own-home autosave stack and an unbroken SHA256 chain. No time tolerance or world field omission."}
	home_world = Dictionary(current.world).duplicate(true)
	home_chapter = String(current.chapter)
	home_boundary_sealed = true
	return true


func _init() -> void:
	super()
	# Same adapter pattern as party_quest_pair: keep the outer timer only.
	if _watchdog != null:
		remove_child(_watchdog)
		_watchdog.free()
		_watchdog = null


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	# Keep the outer watchdog's context current during inherited reader boot.
	# Do not use PROCESS_MODE_ALWAYS: the readers must retain normal pause rules.
	if owner_rig != null:
		owner_rig.game = game
		owner_rig.shot_dir = shot_dir


func step(label: String) -> void:
	super(label)
	if owner_rig != null:
		owner_rig.game = game
		owner_rig.shot_dir = shot_dir
		owner_rig.last_step = label


func _show(index: int) -> void:
	super(index)
	if owner_rig != null:
		owner_rig.game = game


func shot(name: String, extra: String = "") -> String:
	owner_rig.game = game
	owner_rig.shot_dir = shot_dir
	owner_rig.sim_t = sim_t
	var path := owner_rig.shot(name, extra)
	shots_taken = owner_rig.shots_taken
	last_step = owner_rig.last_step
	return path


func _capture_milestone(name: String) -> void:
	# Transactions can finish in one frame; wait for the real HUD to update
	# and the renderer to draw it before saving the milestone's full frame.
	await frames(2)
	await RenderingServer.frame_post_draw
	shot(name)


func _print_report_summary(error: String, restored: bool) -> void:
	var ui: Dictionary = report.get("ui", {})
	var boundary: Dictionary = report.get("home_dispatch_boundary", {})
	print("BREWING PERSISTENCE: ", JSON.stringify({"milestones": accepted.size(), "error": error,
		"fixture_save_bytes_restored": restored, "real_file_roundtrip": not flag("ui-only"),
		"real_enet_transport": true, "ui_checks": int(ui.get("checks", 0)),
		"ui_failures": int(ui.get("failures", 0)),
		"pre_dispatch_full_writes": int(boundary.get("explained_full_writes", 0)),
		"report": ProjectSettings.globalize_path(shot_dir + "/acceptance.json")}))
