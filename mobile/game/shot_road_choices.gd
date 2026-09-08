extends ShotRig
const Net := preload("res://scripts/net/net_manager.gd")
var offer_timeouts := 0


func _ready() -> void:
	await boot("warrior", "ch1", false)
	var error := await _checks()
	game.menus.close()
	var net := get_node("/root/NetworkManager")
	if net.is_online():
		net.leave()
	if error != "":
		push_error(error)
		shot("diagnostic")
		return finish(1)
	print("ok: road choices live: explicit costs/verbs, safe leave/back, treatment affordability, once-only payment, touch bounds, real hosted ENet offer timeout held while reading and retired in unrelated menus")
	finish()


func _offer(id: String) -> Node2D:
	game.menus.close()
	for entry in game.interactables.duplicate():
		var old: Variant = entry.get("node")
		if is_instance_valid(old) and old.has_meta("road_context") and not old.is_queued_for_deletion():
			game._remove_interactable(old)
	game.flags.erase(game._road_flag(game.cur_room))
	game._road_card_node(game.cur_room, id)
	var entry: Dictionary = game.interactables[-1]
	entry.action.call()
	return entry.node


func _button(text: String) -> Button:
	for node in game.menus.root.find_children("*", "Button", true, false):
		if text in node.text:
			return node
	return null


func _fit() -> String:
	var bounds := game.menus._shell_rect.grow(1)
	for node in game.menus.root.find_children("*", "Control", true, false):
		if node is Button and node.is_visible_in_tree() and not bounds.encloses(node.get_global_rect()):
			return "road button escaped the panel: " + node.text
	return ""


func _checks() -> String:
	game.player.set_physics_process(false)
	game.terrain_event_t = 10000.0
	game.settings["camera_shake"] = 0.0
	game.camera.position_smoothing_enabled = false
	game.player.global_position = game.room_center(game.cur_room)
	game.player.gold = 500
	game.player.hp = game.player.max_hp * 0.5
	# The opener's final fade invokes begin() after dialogue_active clears.
	# Wait for actual play before a solo menu can pause that final callback.
	var arrival_deadline := Time.get_ticks_msec() + 5000
	while (not game.play_started or game.hud.overlay.color.a > 0.01) and Time.get_ticks_msec() < arrival_deadline:
		await get_tree().create_timer(0.05, true).timeout
	if not game.play_started:
		return "the chapter opener did not hand control to gameplay"
	await RenderingServer.frame_post_draw
	var actor: Variant = _offer("toll")
	await frames(4)
	if _fit() != "":
		return _fit()
	shot("01_toll_explicit_choices")
	var before := [game.player.gold, game.player.hp, game.player.faction_standing.duplicate(), game.run_road_cards]
	_button("Leave").pressed.emit()
	await frames(2)
	if game.menus.is_open() or before != [game.player.gold, game.player.hp, game.player.faction_standing, game.run_road_cards]:
		return "leaving a real road offer changed the hero"
	game.player.gold = 15
	game._road_toll(game.cur_room, actor)
	await frames(4)
	if _button("Offer your last 15 gold") == null:
		return "a short purse still advertises the full toll"
	shot("02_toll_last_coins")
	var paid_count := game.run_road_cards
	var pay := _button("Offer your last")
	pay.pressed.emit()
	pay.pressed.emit()
	if game.player.gold != 0 or game.run_road_cards != paid_count + 1:
		return "real toll click did not charge once"
	await frames(3)
	game.player.gold = 10
	actor = _offer("courier")
	await frames(4)
	if not _button("Buy treatment").disabled or _fit() != "":
		return "poor courier panel has a clickable unaffordable action or broken layout"
	shot("03_courier_short_purse")
	game.menus.controller_back()
	game.player.gold = 500
	game._road_courier(game.cur_room, actor)
	await frames(4)
	shot("04_courier_treatment_or_robbery")
	var heal := int(ceil(Balance.ROAD_COURIER_HEAL_COST * Balance.daily_gold_mult(game.player.level)))
	var gift := int(ceil(Balance.ROAD_COURIER_GIFT_GOLD * Balance.daily_gold_mult(game.player.level)))
	var expected := game.player.gold - heal + game.player.gold_yield(gift)
	_button("Buy treatment").pressed.emit()
	if game.player.gold != expected:
		return "courier treatment charged or rewarded differently from its offer"
	await frames(3)
	actor = _offer("wager")
	await frames(4)
	if _fit() != "":
		return _fit()
	shot("05_wager_clear_stakes_and_leave")
	var purse := game.player.gold
	_button("Leave").pressed.emit()
	if game.player.gold != purse:
		return "leaving a real wager forfeited its stake"
	game.settings["touch_controls"] = true
	game.refresh_touch_mode()
	game._apply_touch_mode()
	actor = _offer("courier")
	await frames(4)
	if _fit() != "":
		return _fit()
	shot("06_touch_road_choices")
	actor.queue_free()
	await frames(3)
	if game.menus.is_open():
		return "losing the offer's actor left a dead decision panel open"
	# A real hosted session uses the production non-pausing menu path. No guest
	# is needed to test this host-local Road Deck timer; it adds no network RPCs.
	var net := get_node("/root/NetworkManager")
	if await net.host(Net.Mode.ENET_DIRECT, "127.0.0.1:0") != OK:
		return "could not host the ENet timeout check"
	actor = _offer("toll")
	var stale_action: Callable = game._road_toll_pay.bind(game.cur_room, actor, 100)
	var timer: Timer = actor.get_node("RoadWindow")
	timer.timeout.connect(func() -> void: offer_timeouts += 1)
	var deadline := Time.get_ticks_msec() + 25000
	while offer_timeouts == 0 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1, true).timeout
	if get_tree().paused or offer_timeouts == 0 or not is_instance_valid(actor) \
			or actor.is_queued_for_deletion() or game.menus.current != "road_choice":
		return "the real online decision expired while being read, or the shared world paused"
	shot("07_online_offer_survives_full_window")
	game.menus.open_inventory()
	deadline = Time.get_ticks_msec() + 25000
	while is_instance_valid(actor) and not actor.is_queued_for_deletion() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1, true).timeout
	await frames(3)
	if is_instance_valid(actor):
		return "an unrelated online menu kept the road stranger alive"
	purse = game.player.gold
	stale_action.call()
	if game.player.gold != purse or game.menus.current != "inventory":
		return "an expired callback charged the hero or dismissed an unrelated menu"
	shot("08_expired_offer_keeps_inventory_safe")
	return ""
