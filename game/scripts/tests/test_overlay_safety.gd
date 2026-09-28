extends RefCounted
## Synchronous systems fixture: real HUD signals and menus, private UI and body.
## No timers/frames or shared combat state advance while the pointers are loaned.


static func run(t: Node) -> String:
	var g: Game = t.game
	var saved := {"hud": g.hud, "menus": g.menus, "state": g.state,
		"paused": g.get_tree().paused, "started": g.play_started,
		"no_saves": g.no_saves, "talk_cd": g.talk_cd,
		"finale": g.chapter_finale.active, "chapter": g.chapter_id,
		"gates": g.victory_gates_up, "player": g.local_player, "touch": g._touch_hud,
		"death_epoch": g.death_epoch}
	var prompts := {}
	for entry: Dictionary in g.interactables:
		var prompt: Variant = entry.get("prompt")
		if is_instance_valid(prompt) and prompt is CanvasItem:
			prompts[prompt] = prompt.visible
	# The menu releases held touch gestures; keep the real client's inputs intact.
	g._touch_hud = null
	g.hud = Hud.new()
	g.hud.game = g
	g.add_child(g.hud)
	g.menus = Menus.new()
	g.menus.game = g
	g.menus.shell_motion = false
	g.add_child(g.menus)
	g.no_saves = true
	var error := _checks(g)
	# Restore on failure as well as success, including the original UI instances.
	g.menus.free()
	g.hud.free()
	g.hud = saved.hud
	g.menus = saved.menus
	g.state = saved.state
	g.play_started = saved.started
	g.no_saves = saved.no_saves
	g.talk_cd = saved.talk_cd
	g.chapter_finale.active = saved.finale
	g.chapter_id = saved.chapter
	g.victory_gates_up = saved.gates
	g.death_epoch = saved.death_epoch
	g.local_player = saved.player
	g._touch_hud = saved.touch
	for prompt: CanvasItem in prompts:
		if is_instance_valid(prompt):
			prompt.visible = prompts[prompt]
	g.get_tree().paused = saved.paused
	if error == "":
		print("ok: utility overlays, dialogue AUTO/pause ownership, and victory during death recovery")
	return error


static func _checks(g: Game) -> String:
	var h: Hud = g.hud
	g.play_started = true
	g.state = Game.ST_PLAYING
	g.chapter_finale.active = false
	h.dialogue([["Narrator", "Overlay safety fixture."]])
	for context in ["dialogue", "choices", "chat", "finale", "dead", "victory", "boot"]:
		h.dialogue_active = context == "dialogue"
		h.choices_active = context == "choices"
		h.chat_active = context == "chat"
		g.chapter_finale.active = context == "finale"
		g.play_started = context != "boot"
		g.state = Game.ST_DEAD if context == "dead" else (Game.ST_VICTORY if context == "victory" else Game.ST_PLAYING)
		# The shared gate itself: shut everywhere here, except that the Menu
		# icon's victory allowance opens on the settled victory card.
		if h._utility_menu_ok() or h._utility_menu_ok(true) != (context == "victory"):
			return "utility gate misread %s" % context
		for button: Button in [h.inv_btn, h.codex_btn, h.skills_btn, h.settings_btn,
				h.mail_btn, h.quest_btn, h.daily_btn, h.party_btn]:
			if context == "victory" and button == h.settings_btn:
				continue  # the card's documented route to the game menu, checked below
			button.pressed.emit()
			if g.menus.is_open():
				return "%s opened %s during %s" % [button.tooltip_text, g.menus.current, context]
		if context == "victory":
			h.settings_btn.pressed.emit()
			if g.menus.current != "pause":
				return "the Menu icon stopped opening the game menu on the victory card"
			g.menus.close()
	# Force an overlapping menu to exercise both independent backstops.
	g.play_started = true
	g.state = Game.ST_PLAYING
	h.dialogue_active = true
	g.menus.open_inventory()
	h._auto_on = true
	h._auto_t = 0.0
	var index := h.dialogue_index
	h._process(h._auto_dwell + 1.0)
	if h.dialogue_index != index or not h.dialogue_active or not g.get_tree().paused:
		return "AUTO advanced the hidden dialogue or released its pause"
	g.menus.close()
	if not g.get_tree().paused:
		return "closing a menu released the dialogue pause"
	h.dialogue_active = false
	h.choices_active = true
	g.menus.open_inventory()
	g.menus.close()
	if not g.get_tree().paused:
		return "closing a menu released the choice pause"
	h.cancel_conversation()
	g.request_pause(false)
	h.inv_btn.pressed.emit()
	if g.menus.current != "inventory":
		return "ordinary inventory shortcut stopped opening"
	var shell: Control = g.menus.root
	h.settings_btn.pressed.emit()
	if g.menus.root != shell:
		return "utility shortcut replaced an existing menu"
	g.menus.close()
	# A private body avoids borrowing the shared hero's animation/combat memory.
	# It is freed here on every path; run() restores local_player.
	var p := Player.new()
	var error := _victory_during_death(g, h, p)
	p.free()
	return error


## A win that lands inside the death beat ends it: the hero rises at once and
## the beat's pending respawn stands down, whether the card is still up or was
## already dismissed. The dedicated server's wipe beat obeys the same token.
static func _victory_during_death(g: Game, h: Hud, p: Player) -> String:
	p.dead = true
	p.hp = 0.0
	g.local_player = p
	g.state = Game.ST_DEAD
	g.request_pause(true)
	h.dim(Balance.DEATH_DIM)
	var beat := g.death_epoch
	g._enter_victory()  # what end_it and _network_victory_card run
	if g.state != Game.ST_VICTORY or p.dead or p.hp != p.max_hp or g.death_epoch == beat:
		return "a victory during the death beat left the hero dead or the beat pending"
	h.results_box = Control.new()
	h.add_child(h.results_box)
	var card: Control = h.results_box
	var room := g.cur_room
	var spot := p.position
	# The beat's timer fires while the card is still up.
	g._finish_death_beat(p, room, beat)
	if g.state != Game.ST_VICTORY or not g.get_tree().paused or h.results_box != card \
			or not is_equal_approx(h.overlay.color.a, Balance.DEATH_DIM) or g.cur_room != room or p.position != spot:
		return "pending death recovery clobbered victory, its card, pause or world"
	# A direct respawn during the card keeps it as well, and still revives.
	p.dead = true
	p.hp = 0.0
	g._death_respawn(p, room)
	if g.state != Game.ST_VICTORY or p.dead or h.results_box != card or g.cur_room != room:
		return "a direct respawn during victory clobbered the card or left the hero dead"
	# DEDICATED: the server's wipe beat must not overwrite that victory either,
	# or _server_after_victory finds ST_PLAYING and never moves the world on.
	g.local_player = null
	g.state = Game.ST_DEAD
	var server_beat := g.death_epoch
	g._enter_victory()
	g._finish_server_wipe(room, server_beat)
	if g.state != Game.ST_VICTORY or g.cur_room != room:
		return "the server's wipe beat overwrote a victory that landed during it"
	# Dismiss before the beat ends (gates already exist; not the first ch1
	# clear), then let the stale timer fire: nothing may respawn afterwards.
	g.chapter_id = "ch2"
	g.victory_gates_up = true
	g.victory_dismiss()
	if g.state != Game.ST_PLAYING or g.get_tree().paused or h.results_box != null:
		return "victory could not be dismissed after death recovery"
	g._finish_death_beat(p, room, beat)
	if g.state != Game.ST_PLAYING or p.dead or g.cur_room != room or p.position != spot:
		return "a stale death respawn ran after the victory card was dismissed"
	return ""
