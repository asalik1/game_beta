extends RefCounted
## Reuses the hunt rig's two real games/ENet APIs and save-fixture cleanup.
const Hunt := preload("res://scripts/road_hunt.gd")
const Escort := preload("res://scripts/wayfarer.gd")
const Vigil := preload("res://scripts/ward_vigil.gd")


static func _notes(hud: Hud, text: String) -> int:
	var count := 0
	for row in hud._log_lines:
		if is_instance_valid(row) and String(row.get_meta("label").text) == text:
			count += 1
	return count


static func _fit(g: Game, panel: Control) -> String:
	if not panel.visible or not Rect2(Vector2.ZERO, g.get_viewport_rect().size).encloses(panel.get_global_rect()):
		return "encounter objective is hidden or outside the viewport"
	for slot in g.hud.party_slots:
		# The grouping Control has zero size; measure its actual health backdrop.
		if slot.root.visible and panel.get_global_rect().intersects(slot.hp_bg.get_global_rect()):
			return "encounter objective covers a teammate's health"
	if g._touch_hud != null and g._touch_hud.visible:
		for button in g._touch_hud._btns.values():
			if panel.get_global_rect().intersects(button.panel.get_global_rect()):
				return "encounter objective covers a touch action"
	for node in panel.get_children():
		if node is Control and not panel.get_global_rect().encloses(node.get_global_rect()):
			return "encounter objective clipped its text or meter"
	return ""


static func run(r: Node, room: int) -> String:
	var host: Game = r.readers[0]
	var guest: Game = r.readers[1]
	var trail := Hunt.find(host, room)
	var mirror := Hunt.find(guest, room)
	for reader in [host, guest]:
		reader.hud.wayfinder._sample()
		if reader.hud.wayfinder._hot or not reader.hud.wayfinder.status_label.text.contains("Encounter"):
			return "an open-door hunt sealed a passage or still advertised sanctuary"
	if _notes(guest.hud, Hunt.CLUES[0]) != 0:
		return "late joining replayed the first discovery"
	guest.player.global_position = mirror.points[1]
	if not await r._until(func() -> bool: return r._shell(0, guest.player.peer_id).global_position.distance_to(mirror.points[1]) < 30.0):
		return "guest tracking position did not reach the authority"
	mirror.entries[1].action.call()
	if not await r._until(func() -> bool: return mirror.sign_index == 2):
		return "guest's shared sign did not advance"
	if _notes(guest.hud, Hunt.CLUES[1]) != 1:
		return "guest did not receive the new discovery message"
	r.wires[0].host_road_hunt_state(trail)
	await r.frames(3)
	if _notes(guest.hud, Hunt.CLUES[1]) != 1:
		return "repeated network state repeated the discovery"
	r._show(1)
	if not await r._until(func() -> bool: return is_instance_valid(guest.hud._ann_active) and String(guest.hud._ann_active.get_meta("message", "")) == Hunt.CLUES[1] and guest.hud._ann_active.modulate.a > 0.95, 12.0):
		return "guest discovery did not reach its readable announcement state"
	await r._capture("company_01_guest_reads_the_discovery")
	var traveler := Escort.find(host)
	var companion := Escort.find(guest)
	if traveler == null or companion == null:
		return "company fixture has no shared traveler"
	host.player.global_position = traveler.global_position + Vector2(0, 60)
	guest.player.global_position = companion.global_position + Vector2(0, 60)
	preload("res://scripts/ui/wayfarer.gd").open(host.menus, traveler)
	var start := host.menus.root.find_child("Escort_start", true, false) as Button
	if start == null or not start.disabled:
		return "the escort invitation allows a second fight during a hunt"
	r._show(0)
	await r._capture("company_02_finish_the_hunt_first")
	for node in host.menus.root.find_children("*", "Button", true, false):
		if not host.menus._shell_rect.grow(1).encloses(node.get_global_rect()):
			return "busy explanation pushed an escort action outside the panel"
	start.pressed.emit()  # a stale/forced click must still fail at the authority
	if traveler.active():
		return "a forced click started the escort during a hunt"
	host.menus.close()  # disabled buttons intentionally have no connected callback
	if traveler.request(host.player, "start"):
		return "direct start bypassed the encounter reservation"
	if not await r._until(func() -> bool: return r._shell(0, guest.player.peer_id).global_position.distance_to(traveler.global_position) < Balance.INTERACT_RANGE):
		return "guest escort position did not reach the host"
	r.wires[1].request_escort("start")
	await r.frames(4)
	if traveler.active() or companion.active():
		return "a guest request stacked the escort over a hunt"
	trail.cancel()
	if not await r._until(func() -> bool: return Hunt.find(guest, room) == null):
		return "company fixture retained the earlier hunt"
	if not traveler.request(host.player, "start"):
		return "the escort did not become available after the hunt ended"
	if Hunt.begin(host, room, host.room_center(room)) != null:
		return "the reverse order stacked a hunt over the escort"
	if not await r._until(func() -> bool: return companion.active()):
		return "guest never received the escort's active state"
	r._show(0)
	await r._capture("company_03_escort_party_health")
	var error := _fit(host, traveler.status)
	if error != "":
		return error
	var good_position: Vector2 = traveler.status.position
	traveler.status.position = Vector2(16, 240)
	var baseline_detected := _fit(host, traveler.status) != ""
	traveler.status.position = good_position
	if not baseline_detected:
		return "layout check failed to detect the old overlapping position"
	# Exercise the real panel clock with an actual camera-transformed hero.
	# At a room edge the normal objective slot can cover the fight; it yields.
	var feet: Vector2 = host.player.get_global_transform_with_canvas().origin
	traveler.status.position = feet - Vector2(152, 75)
	if not await r._until(func() -> bool: return traveler.status.modulate.a <= Balance.ENCOUNTER_COVER_ALPHA + 0.01):
		traveler.status.position = good_position
		return "the encounter panel did not yield when it covered the hero"
	await r._capture("company_03a_objective_yields_to_the_hero")
	traveler.status.position = good_position
	if not await r._until(func() -> bool: return traveler.status.modulate.a > 0.99):
		return "the encounter panel did not become readable after the hero moved clear"
	guest.settings["touch_controls"] = true
	guest.refresh_touch_mode()
	guest._apply_touch_mode()
	r._show(1)
	await r._capture("company_04_touch_escort_party_health")
	error = _fit(guest, companion.status)
	if error != "":
		return error
	traveler.cancel("")
	if not await r._until(func() -> bool: return not companion.active()):
		return "the stopped escort kept its guest objective"
	var tower := -1
	for i in host.zones.size():
		if Vigil.eligible(host, i):
			tower = i
	if tower < 0:
		return "company fixture has no authored tower"
	for i in 2:
		var g: Game = r.readers[i]
		g.player.global_position = g.room_center(tower)
		g._enter_room(tower)
		r._show(i)
		await r.skip_dialogue()
	await r.frames(3)
	for enemy in r.get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and enemy.game == host and enemy.zone_idx == tower and not enemy.dying:
			enemy.take_damage(999999.0, Vector2.LEFT)
	if not await r._until(func() -> bool: return not host._room_hot(tower)):
		return "tower's ordinary combat did not clear for its optional watch"
	var ward := Vigil.find(host)
	var reflected := Vigil.find(guest)
	if ward == null or reflected == null:
		return "company fixture has no shared tower ward"
	host.player.global_position = ward.global_position + Vector2(0, 65)
	guest.player.global_position = reflected.global_position + Vector2(0, 65)
	if not ward.request(host.player, "start"):
		return "ward did not start in the cleared tower"
	if not await r._until(func() -> bool: return reflected.active()):
		return "guest never received the ward's active state"
	r._show(0)
	await r._capture("company_05_ward_party_health")
	error = _fit(host, ward.status)
	if error != "":
		return error
	r._show(1)
	await r._capture("company_06_touch_ward_party_health")
	error = _fit(guest, reflected.status)
	if error != "":
		return error
	ward.cancel("")
	if not await r._until(func() -> bool: return not reflected.active()):
		return "the stopped ward kept its guest objective"
	print("ok: live encounter company: guest discovery once, no historical bark, both fight orders, forced click/guest-request guard, released invitations, escort/ward party and touch health visibility, negative layout control, camera-aware combat clearance and recovery")
	return ""
