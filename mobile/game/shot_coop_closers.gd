extends ShotRig
## Two real games and two ENet API scopes in one engine: independent readers.
const SLOT := 96
var host: ReaderGame
var guest: ReaderGame
var host_wire: WireSession
var guest_wire: WireSession
var host_api: MultiplayerAPI
var guest_api: MultiplayerAPI
var server := ENetMultiplayerPeer.new()
var client := ENetMultiplayerPeer.new()
var roots: Array[Node] = []
var screens: Array[SubViewportContainer] = []
var report := {}

class ReaderGame extends Game:
	var qa_online := false
	var qa_bridge: Node
	func net_online() -> bool: return qa_online
	func net_session() -> Node: return qa_bridge

class WireRoot extends Node:
	var peers := {}
	var online := true
	func is_online() -> bool: return online

class WireSession extends "res://scripts/net/net_session.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class NetworkStageProbe extends "res://scripts/tests/net_test_session.gd":
	func _ready() -> void: pass


func _ready() -> void:
	var files := {}
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(SLOT) + suffix
		files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	host = await _reader("warrior", "Host")
	guest = await _reader("mage", "Guest")
	host_api = MultiplayerAPI.create_default_interface()
	guest_api = MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(host_api, roots[0].get_path())
	get_tree().set_multiplayer(guest_api, roots[1].get_path())
	host_wire = WireSession.new()
	guest_wire = WireSession.new()
	for pair in [[host_wire, host, roots[0]], [guest_wire, guest, roots[1]]]:
		pair[0].name = "Session"
		pair[0].game = pair[1]
		pair[1].qa_bridge = pair[0]
		pair[2].add_child(pair[0])
	var error := await _connect_and_check()
	if error != "":
		shot("diagnostic_before_cleanup")
	get_tree().paused = false
	for reader in [host, guest]:
		reader.qa_online = false
		reader.no_saves = true
		reader.save_slot = -1
		reader.guest_world = false
		reader.chapter_finale.cancel(reader)
	client.close()
	server.close()
	host_api.multiplayer_peer = null
	guest_api.multiplayer_peer = null
	for root in roots:
		get_tree().set_multiplayer(null, root.get_path())
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var output := FileAccess.open(path, FileAccess.WRITE)
			if output == null:
				error = "could not restore closer save fixture"
			else:
				output.store_buffer(files[path])
				output.close()
	print("COOP CLOSERS LIVE: ", JSON.stringify(report))
	if error != "":
		push_error(error)
		shot("diagnostic_failure")
		return finish(1)
	print("ok: co-op closers live: two real readers, real ENet victory/claim/advance, own artwork, unequal reading, queued choice/menu/chat, duplicate suppression and interrupted home save")
	finish()


func _reader(cls: String, label: String) -> ReaderGame:
	step("boot " + label)
	var screen := SubViewportContainer.new()
	screen.size = Vector2(1280, 720)
	add_child(screen)
	screens.append(screen)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	viewport.use_hdr_2d = get_viewport().use_hdr_2d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.add_child(viewport)
	var root := WireRoot.new()
	root.name = label
	viewport.add_child(root)
	roots.append(root)
	var reader := ReaderGame.new()
	reader.name = "Game"
	reader.y_sort_enabled = true
	reader.no_saves = true
	root.add_child(reader)
	game = reader
	await frames(10)
	step(label + " class selection")
	reader.menus.shell_motion = false
	reader.menus.pick_chapter("ch1")
	await frames(3)
	reader.menus.pick_class(cls)
	await frames(5)
	await skip_dialogue()
	await sim_wait(0.6)
	reader.dev_god = true
	reader.settings["camera_shake"] = 0.0
	reader.player.pending_theme_note = ""
	reader.camera.position_smoothing_enabled = false
	reader.terrain_event_t = 10000.0
	_freeze_physics(reader)
	return reader


func _freeze_physics(node: Node) -> void:
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze_physics(child)


func _show(reader: ReaderGame) -> void:
	game = reader
	screens[0].visible = reader == host
	screens[1].visible = reader == guest


func _connect_and_check() -> String:
	if server.create_server(0, 2) != OK:
		return "ENet closer host bind failed"
	host_api.multiplayer_peer = server
	if client.create_client("127.0.0.1", server.host.get_local_port()) != OK:
		return "ENet closer guest connect failed"
	guest_api.multiplayer_peer = client
	var deadline := Time.get_ticks_msec() + 4000
	while host_api.get_peers().is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02, true).timeout
	if host_api.get_peers().is_empty():
		return "ENet closer handshake timed out"
	var pid := guest_api.get_unique_id()
	roots[0].peers[pid] = {}
	roots[1].peers[1] = {}
	host_wire.peer_chars[pid] = {"cls": "mage", "level": guest.player.level}
	guest_wire.peer_chars[1] = {"cls": "warrior", "level": host.player.level}
	host_wire.world_ready = true
	guest_wire.world_ready = true
	host.player.peer_id = 1
	guest.player.peer_id = pid
	host.player._net_mgr = roots[0]
	guest.player._net_mgr = roots[1]
	for pair in [[host, pid, "mage"], [guest, 1, "warrior"]]:
		var remote := Player.new()
		remote.game = pair[0]
		remote.peer_id = pair[1]
		remote.cls = pair[2]
		remote.set_multiplayer_authority(pair[1])
		pair[0].register_remote_player(remote)
		remote._net_mgr = roots[0] if pair[0] == host else roots[1]
		remote.global_position = pair[0].room_center(pair[0].zone_count - 1)
		remote.set_physics_process(false)
		if remote.is_locally_controlled():
			return "network fixture treated a remote shell as a local player"
	if not host.player.is_locally_controlled() or not guest.player.is_locally_controlled():
		return "network fixture lost a reader's local ownership"
	host.qa_online = true
	guest.qa_online = true
	guest.guest_world = true
	SaveGame.write(guest, SLOT)
	var home := SaveGame.world_of(SaveGame.read(SLOT))
	guest.save_slot = SLOT
	guest.no_saves = false
	for reader in [host, guest]:
		reader.flags.erase("completed_ch1")
		reader.flags.erase("first_clear_paid_ch1")
		reader.run_time = 120.0
		reader.mailbox = []
	var error := await _real_boss_and_readers()
	if error != "":
		return error
	error = await _queued_interactions()
	if error != "":
		return error
	error = await _world_cancels()
	if error != "":
		return error
	# Exercise the production lost-session callback after an actual ENet run;
	# this is a controlled callback, not a simulated transport outage.
	_reset_reader(guest)
	guest.chapter_id = "ch1"
	guest.net_victory("Saved before the last page.", true)
	await sim_wait(0.2)
	var stale: Callable = guest.hud.dialogue_done
	guest.qa_online = false
	roots[1].online = false
	guest_wire._on_session_ended("QA host connection lost")
	stale.call()
	await sim_wait(0.6)
	var saved := SaveGame.read(SLOT)
	if guest.chapter_finale.active or is_instance_valid(guest.cutscene) or guest.hud.dialogue_active:
		return "host-loss cleanup retained an ending or its dialogue"
	if SaveGame.world_of(saved) != home or not SaveGame.character_of(saved).get("history_flags", {}).get("completed_ch1", false):
		return "ending interruption lost personal credit or changed the home world"
	_show(guest)
	await frames(3)
	shot("10_host_loss_keeps_home_progress")
	report["home_world_preserved"] = true
	return ""


func _real_boss_and_readers() -> String:
	step("actual final boss death on connected host")
	_show(host)
	var kind := String(Story.chapter(host.chapter_id).final_boss)
	var boss := Boss.make_boss(host, kind, host.player.global_position + Vector2(240, 0), 12)
	boss.story_boss = true
	boss.zone_idx = host.cur_room
	host.current_boss = boss
	host.bosses.append(boss)
	host.world.add_child(boss)
	boss.set_physics_process(false)
	await frames(2)
	boss.take_damage(9999999.0)
	await sim_wait(0.7)
	for reader in [host, guest]:
		report[String(reader.player.cls) + "_kill"] = {"completed": reader.get_flag("completed_ch1"),
			"paid": reader.get_flag("first_clear_paid_ch1"), "mail": reader.mailbox.size()}
		if not reader.chapter_finale.active or not is_instance_valid(reader.cutscene):
			return "real host kill did not start both personal endings"
		if not reader.get_flag("completed_ch1") or not reader.get_flag("first_clear_paid_ch1"):
			return "real host kill did not bank each reader's reward and credit"
		if reader.cutscene._frame_cache.is_empty():
			return "personal ending has no loaded artwork"
		if is_instance_valid(reader.hud._boss_splash_layer) or (reader.hud.party_root != null and reader.hud.party_root.visible):
			return "boss introduction or party frames covered the personal ending"
		for arrow in reader.hud.party_arrows:
			if arrow.visible:
				return "party direction arrow covered the personal ending"
		var own := false
		for key in reader.cutscene._frame_cache:
			if String(key).contains(String(reader.player.cls)):
				own = true
		if not own:
			return "personal ending loaded another class's artwork"
		reader.hud._finish_reveal()
	if not host_wire._convo_claims.is_empty() or not guest_wire._pending_convo.is_empty():
		return "personal endings acquired party/NPC claims"
	await frames(2)
	shot("01_host_warrior_ending")
	_show(guest)
	await frames(3)
	shot("02_guest_mage_ending")
	var before_time := guest.run_time
	var before_mail := guest.mailbox.size()
	var before_record := guest.chapter_pb("ch1", "mage").duplicate(true)
	# No god mode may mask a helpless reader being hit. The host sends the
	# same owner-side damage RPC as a real enemy; local hazards use take_damage.
	var before_hp := guest.player.hp
	guest.dev_god = false
	guest.player.hurt_cd = 0.0
	guest.player.take_damage(999999.0, "true", null, true)
	host_wire.host_player_hit(guest_api.get_unique_id(), 999999.0, "true", 0, true)
	await sim_wait(0.2)
	if guest.player.hp != before_hp or guest.player.downed or guest.player.dead:
		return "a late hit injured the guest while its ending held all input"
	guest.player.downed = true
	guest.player.down_t = 0.25
	guest.player.cds["a1"] = 5.0
	guest.player._physics_process(1.0)
	if guest.player.down_t != 0.25 or guest.player.ghost or guest.player.cds["a1"] != 5.0:
		return "reading consumed a survival/cooldown clock or bled out a downed hero"
	guest.player.downed = false
	guest.player.down_t = 0.0
	guest.dev_god = true
	report["reader_survival_held"] = true
	var down_before := []
	for member in host.players:
		down_before.append(member.downed)
		member.downed = true
	host_wire._check_wipe()
	var wiped: bool = host_wire._wipe_fired or host.state != Game.ST_PLAYING
	for i in host.players.size():
		host.players[i].downed = down_before[i]
	if wiped:
		return "the party wipe census replaced a won chapter's ending"
	report["won_chapter_not_wiped"] = true
	host_wire.host_victory("Duplicate must be ignored.", true)
	_show(host)
	await skip_dialogue()
	if not host.chapter_finale.active or not host.input_overlay_up():
		return "last-line dissolve released world inputs too soon"
	host.hud._on_escape()
	if host.menus.is_open():
		return "escape opened a menu through the final dissolve"
	await sim_wait(0.7)
	if host.state != Game.ST_VICTORY or not guest.chapter_finale.active or guest.state != Game.ST_PLAYING:
		return "fast host forced the slow guest's ending to finish"
	shot("03_fast_host_results")
	_show(guest)
	await frames(3)
	shot("04_guest_still_reading")
	if guest.run_time != before_time or guest.mailbox.size() != before_mail:
		return "reading or duplicate victory changed time or rewards"
	if guest.chapter_pb("ch1", "mage") != before_record:
		return "duplicate victory counted another completed run"
	# Reuse the legacy network suite's actual guest reader setup, while
	# keeping both ENet peers in this one engine.
	var legacy_probe := NetworkStageProbe.new()
	legacy_probe.game = guest
	add_child(legacy_probe)
	await legacy_probe._watch_setup(guest_wire, "victory", {})
	legacy_probe.free()
	await sim_wait(0.7)
	if guest.state != Game.ST_VICTORY:
		return "guest could not finish while host results paused the shared test tree"
	shot("05_guest_own_results")
	guest.victory_dismiss()
	host_wire.host_victory("Late duplicate must also be ignored.", true)
	await sim_wait(0.2)
	if guest.chapter_finale.active or guest.state != Game.ST_PLAYING or guest.mailbox.size() != before_mail:
		return "duplicate victory replayed after the guest dismissed its card"
	if guest.chapter_pb("ch1", "mage") != before_record:
		return "late duplicate victory counted another run after card dismissal"
	guest.player.cds["a1"] = 5.0
	guest.player._physics_process(0.1)
	if guest.player.cds["a1"] >= 5.0:
		return "ending protection stranded the player's survival clock after dismissal"
	report["different_class_art"] = true
	report["independent_readers"] = true
	report["legacy_network_reader"] = true
	report["reading_time_unchanged"] = true
	report["duplicate_rewards_unchanged"] = true
	return ""


func _reset_reader(reader: ReaderGame) -> void:
	reader.chapter_finale.cancel(reader)
	reader.hud.cancel_conversation()
	reader.hud.hide_results()
	reader.hud.overlay.color = Color.TRANSPARENT
	reader.state = Game.ST_PLAYING
	reader.menus.close()
	get_tree().paused = false


func _queued_interactions() -> String:
	step("ending waits behind real local interactions")
	_reset_reader(host)
	_reset_reader(guest)
	_show(guest)
	var chosen := [0]
	var convo := {"start": "a", "nodes": {"a": {"who": "Mara", "text": "The road can wait for one last promise.",
		"choices": [{"text": "Keep the promise.", "next": ""}]}}}
	guest_wire.begin_convo("qa_finale_choice", convo, func() -> void: chosen[0] += 1)
	# Victory arrives before the reliable claim grant: the pending request is
	# itself busy, even before the choice panel has appeared.
	guest.net_victory("The ending waits for your choice.", true)
	await sim_wait(0.3)
	if not guest.hud.choices_active or is_instance_valid(guest.cutscene) or not guest.chapter_finale.active:
		return "ending overwrote an in-flight NPC claim or choice"
	guest.settings["touch_controls"] = true
	guest.refresh_touch_mode()
	guest._apply_touch_mode()
	await frames(3)
	if guest._touch_hud._enabled or guest._touch_hud.visible:
		return "touch controls stayed enabled under the pending ending/choice"
	shot("06_touch_choice_before_ending")
	guest.hud._choose(0)
	await sim_wait(0.4)
	if chosen[0] != 1 or host_wire._convo_claims.has("qa_finale_choice") or not is_instance_valid(guest.cutscene):
		return "choice consequence/claim release was lost before the queued ending"
	if guest._touch_hud._enabled or guest._touch_hud.visible:
		return "touch controls reappeared under the illustrated ending"
	guest.hud._finish_reveal()
	await frames(2)
	shot("07_touch_personal_ending")
	_reset_reader(guest)
	guest.menus.open_codex("coop")
	guest.net_victory("The ending waits for your menu.", true)
	await sim_wait(0.2)
	if is_instance_valid(guest.cutscene) or not guest.menus.is_open():
		return "ending covered an existing menu"
	shot("08_codex_before_ending")
	guest.menus.close()
	await sim_wait(0.3)
	if not is_instance_valid(guest.cutscene):
		return "ending did not resume after menu close"
	_reset_reader(guest)
	guest.hud.open_chat()
	guest.net_victory("The ending waits for your message.", true)
	await sim_wait(0.2)
	if is_instance_valid(guest.cutscene) or not guest.hud.chat_active:
		return "ending overwrote open chat"
	guest.hud._close_chat()
	await sim_wait(0.3)
	if not is_instance_valid(guest.cutscene):
		return "ending did not resume after chat closed"
	report["queued_choice_menu_chat"] = true
	return ""


func _world_cancels() -> String:
	step("real advance RPC cancels old reader")
	var stale: Callable = guest.hud.dialogue_done
	host_wire._rpc_advance_world.rpc_id(guest_api.get_unique_id(), {"chapter": "ch2", "wander_seed": 555})
	await sim_wait(0.5)
	if guest.chapter_id != "ch2" or guest.chapter_finale.active or guest.state == Game.ST_VICTORY:
		return "world advance left the old finale active"
	var opener: Control = guest.cutscene
	stale.call()
	await sim_wait(0.6)
	if guest.state == Game.ST_VICTORY or guest.cutscene != opener:
		return "old ending callback overlaid the next chapter"
	_show(guest)
	shot("09_advance_keeps_new_chapter_opener")
	await skip_dialogue()
	await sim_wait(0.6)
	_freeze_physics(guest)
	_reset_reader(guest)
	guest.net_victory("Travel during the final dissolve.", true)
	await frames(3)
	await skip_dialogue()
	if not guest.chapter_finale.active or guest.hud.dialogue_active:
		return "fade interruption fixture did not reach the final dissolve"
	host_wire._rpc_advance_world.rpc_id(guest_api.get_unique_id(), {"chapter": "ch2", "wander_seed": 556})
	await sim_wait(0.7)
	if guest.chapter_finale.active or guest.state == Game.ST_VICTORY or is_instance_valid(guest.cutscene):
		return "same-chapter world rebuild retained a fading ending or stale results"
	_freeze_physics(guest)
	_reset_reader(guest)
	var cancelled := [0]
	var convo := {"start": "a", "nodes": {"a": {"who": "Mara", "text": "This unfinished conversation must not survive travel.", "next": ""}}}
	guest_wire.begin_convo("qa_finale_active_cancel", convo, func() -> void: cancelled[0] += 1)
	await sim_wait(0.2)
	if not guest.hud.dialogue_active or not host_wire._convo_claims.has("qa_finale_active_cancel"):
		return "active cancellation fixture did not receive its real NPC claim"
	guest.net_victory("Waiting behind a claimed conversation.", true)
	guest.chapter_finale.cancel(guest)
	await sim_wait(0.2)
	if cancelled[0] != 0 or guest.hud.dialogue_active or host_wire._convo_claims.has("qa_finale_active_cancel"):
		return "cancelled active interaction leaked its claim or executed its callback"
	guest_wire.begin_convo("qa_finale_cancel", convo, func() -> void: cancelled[0] += 1)
	guest.net_victory("Waiting behind an unfinished conversation.", true)
	# Cancel before the grant returns; ordered request/release must retire the
	# host's claim, and the late grant must never execute the conversation.
	guest.chapter_finale.cancel(guest)
	await sim_wait(0.3)
	if cancelled[0] != 0 or guest.hud.dialogue_active or not guest_wire._pending_convo.is_empty() \
		or host_wire._convo_claims.has("qa_finale_cancel"):
		return "cancelled pending interaction leaked its claim or callback"
	report["advance_and_pending_claim_cancel"] = true
	return ""
