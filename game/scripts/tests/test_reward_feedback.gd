extends RefCounted


static func run(t: Node) -> String:
	var g: Game = t.game
	var h := g.hud
	var queue := h._ann_queue.duplicate(true)
	var active := h._ann_active
	var motion := h._ann_tween
	var lines := h._log_lines.duplicate()
	var started := g.play_started
	var dialogue := h.dialogue_active
	var old_xp := g.player.xp
	var run_xp := g.run_xp
	var capped := g.xp_capped_noted
	var chat_owned := h.chat_root == null
	var chat_y: float = 0.0 if chat_owned else h.chat_root.position.y
	var stack := h._ann_stack
	h._ann_queue = []
	h._ann_active = null
	h._ann_tween = null
	h._log_lines = []
	g.play_started = false
	h.dialogue_active = true
	var error := _lifecycle(g)
	if error == "":
		error = _checks(g)
	if error == "":
		error = _readability(g)
	h._retire_announcement()
	_clear_feed(h)
	if chat_owned and h.chat_root != null:
		h.chat_root.free()
		h.chat_root = null
		h.chat_lines_box = null
		h.chat_input = null
	elif h.chat_root != null:
		h.chat_root.position.y = chat_y
	h._log_lines = lines
	h._ann_queue = queue
	h._ann_active = active
	h._ann_tween = motion
	h._ann_stack = stack
	g.play_started = started
	h.dialogue_active = dialogue
	g.player.xp = old_xp
	g.run_xp = run_xp
	g.xp_capped_noted = capped
	if error == "":
		print("ok: achievement/quest queue sharing, earned-notice overflow, overlay log clocks, complete fixed-width feed rows, party chat clear of a full feed and silent zero/negative XP")
	return error


static func _clear_feed(h: Hud) -> void:
	for row in h._log_lines:
		if is_instance_valid(row):
			var tw: Tween = row.get_meta("tween", null)
			if tw != null and tw.is_valid():
				tw.kill()
			row.free()
	h._log_lines.clear()


static func _checks(g: Game) -> String:
	var h := g.hud
	h.achievement_toast("First Light", "A long description that must remain in the same reading position as the quest it completes.")
	h.achievement_toast("First Light", "A long description that must remain in the same reading position as the quest it completes.")
	if h._ann_queue.size() != 1 or h._ann_queue[0].kind != "achievement":
		return "achievement bypassed the queue or duplicated its pending notice"
	for i in 8:
		h.announce("A roadside discovery with deliberately long explanatory words that must fit its fixed feed column %d" % i, Color.WHITE)
	if h._ann_queue.size() != h.ANN_QUEUE_MAX:
		return "reward notice queue became unbounded"
	var kept := false
	for notice in h._ann_queue:
		kept = kept or String(notice.kind) == "achievement"
	if not kept:
		return "incidental notices discarded the earned achievement"
	var camp := "Stock up, then descend \u2014 this is the last safe ground. Rewards pay when you fall or cash out."
	var departure := "W".repeat(64) + " left the party"
	h.log_event(camp, Color.WHITE)
	h.log_event(departure, Color.WHITE, "party")
	h.log_event("+5 gold", Color.WHITE)
	h._tick_event_log()
	var height := 0.0
	var wrapped := 0
	for row in h._log_lines:
		var tw: Tween = row.get_meta("tween")
		var label: Label = row.get_meta("label")
		if row.visible or tw.is_running():
			return "event feed stayed live under dialogue"
		if label.size.x > Balance.HUD_LOG_TEXT_WIDTH or label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			return "event feed must wrap inside its fixed column without clipping or ellipsis"
		if label.text == "+5 gold" and not is_equal_approx(row.size.y, h.LOG_LINE_H):
			return "a one-line feed row grew past the classic line pitch"
		if label.text in [camp, departure]:
			if label.get_line_count() < 2 or label.get_line_count() != label.get_visible_line_count():
				return "camp guidance or party departure lost its consequence"
			wrapped += 1
		height += row.size.y
	if wrapped != 2 or height > Balance.HUD_LOG_HEIGHT_BUDGET or h._log_lines.size() > h.LOG_MAX:
		return "wrapped feed exceeded its budget or discarded the newest guidance"
	var amount_before := g.player.xp
	var feed_before := h._log_lines.size()
	g.player.gain_xp(0)
	g.player.gain_xp(-5)
	if g.player.xp != amount_before or h._log_lines.size() != feed_before:
		return "nonpositive XP changed progress or produced a reward popup"
	# Rows are never cut short: a row past three lines keeps every line.
	var long_text := "Rewards pay when you fall or cash out. ".repeat(7).strip_edges()
	h.log_event(long_text, Color.WHITE)
	var longest: Label = (h._log_lines[-1] as Control).get_meta("label")
	if longest.text != long_text or longest.get_line_count() <= 3 or longest.get_line_count() != longest.get_visible_line_count():
		return "a long event-feed row was cut short"
	# Party chat sits above the feed's reserved footprint, its input line
	# included even while closed, so it never costs the classic rows or covers
	# them. fullscreen_covers resizes the real canvas (16:10, 4:3, tall phones).
	h._ensure_chat()
	_clear_feed(h)
	for i in h.LOG_MAX:
		h.log_event("Found a Rusted Dagger (%d)" % (i + 1), Color.WHITE, "note")
	if h._log_lines.size() != h.LOG_MAX:
		return "party chat cost the event feed its classic rows"
	var feed_top: float = (h._log_lines[0] as Control).get_global_rect().position.y
	for surface: Control in [h.chat_lines_box, h.chat_input]:
		if surface.get_global_rect().end.y + Balance.HUD_CHAT_FEED_GAP > feed_top:
			return "party chat history or input overlaps the event feed"
	return ""


## Remote shells for the real leave/rejoin path: two originals, then each
## name rejoining under a fresh peer id (as a real reconnect does).
const REJOIN_PEERS := [9101, 9102, 9103, 9104]
const REJOIN_NAMES := ["QA rejoiner", "QA wanderer"]


## Loan only presentation/controller state, restoring even on assertion failure.
## No world rebuild or rewards: the live trial rig covers actual start/travel.
static func _lifecycle(g: Game) -> String:
	var h := g.hud
	var saved := {"endgame": g.endgame, "endgame_active": g.endgame_active,
		"state": g.state, "started": g.play_started, "dialogue": h.dialogue_active,
		"choices": h.choices_active, "chat": h.chat_active, "menu": g.menus.root,
		"finale": g.chapter_finale.active,
		"title": h.title_label.modulate, "subtitle": h.subtitle_label.modulate,
		"boss": h.boss_box.visible, "cast": h.boss_cast_readout.visible}
	var session: Node = g.net_session()
	var saved_session := {}
	if session != null:
		saved_session = {"peers": session.peer_chars.duplicate(true),
			"lobby": session.lobby_chars.duplicate(true), "wipe": session._wipe_fired}
	var trial := preload("res://scripts/endgame.gd").new()
	trial.game = g
	g.add_child(trial)
	g.endgame = trial
	g.endgame_active = true
	trial.active = true
	trial.mode = "crucible"
	trial._run_world_id = g.world.get_instance_id()
	# A second, never-parented controller for the replaced-owner case.
	var other := preload("res://scripts/endgame.gd").new()
	other.game = g
	h.choices_active = false
	h.chat_active = false
	g.menus.root = null
	g.chapter_finale.active = false
	var error := _lifecycle_checks(g, trial, other)
	if error == "":
		error = _rejoin_checks(g, session)
	h._retire_announcement()
	h._ann_queue = []
	for pid in REJOIN_PEERS:
		g.unregister_player(pid)
	if session != null:
		session.peer_chars = saved_session.peers
		session.lobby_chars = saved_session.lobby
		session._wipe_fired = saved_session.wipe
	g.endgame = saved.endgame
	g.endgame_active = saved.endgame_active
	g.state = saved.state
	g.play_started = saved.started
	h.dialogue_active = saved.dialogue
	h.choices_active = saved.choices
	h.chat_active = saved.chat
	g.menus.root = saved.menu
	g.chapter_finale.active = saved.finale
	h.title_label.modulate = saved.title
	h.subtitle_label.modulate = saved.subtitle
	h.boss_box.visible = saved.boss
	h.boss_cast_readout.visible = saved.cast
	trial.free()
	other.free()
	if error == "":
		print("ok: trial notice run/world/controller expiry with feed retained, campaign/achievement retention, and real session leave/rejoin departure retraction")
	return error


static func _lifecycle_checks(g: Game, trial: Node, other: Node) -> String:
	var h := g.hud
	# Same copy in a new run must replace stale copy BEFORE duplicate suppression.
	h.announce("Trial queued", Color.WHITE)
	trial._run_generation += 1
	h.announce("Trial queued", Color.WHITE)
	if h._ann_queue.size() != 1 or String(h._ann_queue[0].get("run_token", "")) != trial.run_token():
		return "same-mode restart retained or suppressed the wrong run's notice"
	trial.active = false
	var feed := h._log_lines.duplicate()
	h._tick_announcements()
	if not h._ann_queue.is_empty(): return "settled trial retained queued notice behind overlay"
	if h._log_lines != feed or not _feed_has(h, "Trial queued"):
		return "settled trial expiry changed the event feed"
	trial.active = true
	h.announce("World queued", Color.WHITE)
	trial._run_world_id = 0
	feed = h._log_lines.duplicate()
	h._tick_announcements()
	if not h._ann_queue.is_empty(): return "replaced arena retained queued notice"
	if h._log_lines != feed or not _feed_has(h, "World queued"):
		return "replaced arena expiry changed the event feed"
	trial._run_world_id = g.world.get_instance_id()
	h.announce("Owner queued", Color.WHITE)
	# Same mode, run and arena under a different controller: only the owner
	# identity differs, so this pins the controller part of the token.
	other.mode = trial.mode
	other._run_generation = trial._run_generation
	other._run_world_id = trial._run_world_id
	other.active = true
	g.endgame = other
	if h._ann_queue.size() != 1 or other.run_token() == "":
		return "replacement controller precondition: live token or queued owner notice missing"
	feed = h._log_lines.duplicate()
	h._tick_announcements()
	if not h._ann_queue.is_empty(): return "replaced controller retained queued notice"
	if h._log_lines != feed or not _feed_has(h, "Owner queued"):
		return "replaced controller expiry changed the event feed"
	other.active = false
	g.endgame = trial
	# A real active tween hidden by results must be killed, not later resumed.
	g.play_started = true
	g.state = Game.ST_PLAYING
	h.dialogue_active = false
	h.title_label.modulate.a = 0.0
	h.subtitle_label.modulate.a = 0.0
	h.boss_box.hide()
	h.boss_cast_readout.hide()
	h.announce("THE CRUCIBLE CONQUERED", Color.WHITE)
	if not is_instance_valid(h._ann_active): return "controlled trial plaque did not activate"
	var old_motion := h._ann_tween
	var old_plaque := h._ann_active
	g.state = Game.ST_VICTORY
	h._tick_announcements()
	trial.active = false
	feed = h._log_lines.duplicate()
	h._tick_announcements()
	# kill() stops immediately; is_valid() stays true until the tree's next tick.
	if is_instance_valid(h._ann_active) or old_motion.is_running() or h._ann_tween != null \
			or h._ann_stack != 0 or old_plaque.visible or not old_plaque.is_queued_for_deletion():
		return "settled trial left paused active plaque or tween alive"
	if h._log_lines != feed or not _feed_has(h, "THE CRUCIBLE CONQUERED"):
		return "retiring the settled trial plaque changed the event feed"
	g.endgame_active = false
	h.announce("Campaign tier unlocked", Color.WHITE)
	g.endgame_active = true
	trial.active = true
	h.announce("Earned trial feat", Color.WHITE, 0.0, "achievement")
	h.announce("Expired trial copy", Color.WHITE)
	trial._run_generation += 1
	h._tick_announcements()
	if h._ann_queue.size() != 2: return "run change lost campaign/achievement notice or retained trial copy"
	g.state = Game.ST_PLAYING
	h._tick_announcements()
	if not is_instance_valid(h._ann_active) or h._ann_active.get_meta("message") != "Campaign tier unlocked":
		return "campaign notice did not survive victory and trial switch"
	h.discard_announcement("Campaign tier unlocked")
	h._tick_announcements()
	if not is_instance_valid(h._ann_active) or h._ann_active.get_meta("message") != "Earned trial feat":
		return "achievement notice did not survive trial switch"
	h.discard_announcement("Earned trial feat")
	g.endgame_active = false
	h.boss_box.show()
	h.announce("Ally left the party", Color.WHITE)
	h.announce("Other ally left the party", Color.WHITE)
	feed = h._log_lines.duplicate()
	h.discard_announcement("Ally left the party")
	if h._ann_queue.size() != 1 or h._ann_queue[0].text != "Other ally left the party" or h._log_lines != feed:
		return "queued departure retraction changed another notice or its event history"
	h.boss_box.hide()
	h._tick_announcements()
	if not is_instance_valid(h._ann_active) or h._ann_active.get_meta("message") != "Other ally left the party":
		return "departure without rejoin failed to appear after boss gate"
	old_motion = h._ann_tween
	old_plaque = h._ann_active
	h.discard_announcement("Other ally left the party")
	if is_instance_valid(h._ann_active) or old_motion.is_running() or h._ann_tween != null \
			or old_plaque.visible or not old_plaque.is_queued_for_deletion() or h._log_lines != feed:
		return "active departure retraction retained its tween or removed history"
	return ""


## The shipped call sites on the real (offline) session: _on_peer_left posts
## the departure and _spawn_remote retracts it when the same name rejoins,
## queued or on screen, while the feed keeps the line. Another ally's
## departure is the negative control. Shells and roster restore in the caller.
static func _rejoin_checks(g: Game, session: Node) -> String:
	var h := g.hud
	if session == null or session.game != g:
		return "no production session bound to this game"
	g.state = Game.ST_VICTORY  # unreadable; also keeps the offline wipe census idle
	for i in REJOIN_NAMES.size():
		var block := {"name": REJOIN_NAMES[i], "cls": "warrior", "level": 1}
		session._spawn_remote(REJOIN_PEERS[i], block)
		session.peer_chars[REJOIN_PEERS[i]] = block
	for i in REJOIN_NAMES.size():
		session._on_peer_left(REJOIN_PEERS[i])
	var left := "QA rejoiner left the party"
	var stays := "QA wanderer left the party"
	if not _has_notice(h, left) or not _has_notice(h, stays) \
			or not _feed_has(h, left) or not _feed_has(h, stays):
		return "real peer departures did not queue and log their party notices"
	var feed := h._log_lines.duplicate()
	session._spawn_remote(REJOIN_PEERS[2], {"name": REJOIN_NAMES[0], "cls": "warrior", "level": 1})
	if _has_notice(h, left):
		return "real rejoin left its departure notice queued"
	if not _has_notice(h, stays) or h._log_lines != feed:
		return "rejoin retracted another ally's departure or changed the event feed"
	g.state = Game.ST_PLAYING
	h._tick_announcements()
	if not is_instance_valid(h._ann_active) or h._ann_active.get_meta("message") != stays:
		return "departure without a rejoin did not appear once readable"
	var motion := h._ann_tween
	var plaque := h._ann_active
	session._spawn_remote(REJOIN_PEERS[3], {"name": REJOIN_NAMES[1], "cls": "warrior", "level": 1})
	if is_instance_valid(h._ann_active) or motion.is_running() or plaque.visible \
			or not plaque.is_queued_for_deletion() or h._log_lines != feed:
		return "real rejoin left the showing departure plaque up or changed the event feed"
	return ""


static func _has_notice(h: Node, text: String) -> bool:
	if is_instance_valid(h._ann_active) and h._ann_active.get_meta("message", "") == text:
		return true
	for notice in h._ann_queue:
		if notice.text == text: return true
	return false


## A line repeated back to back collapses in place ("Trial queued x2") and
## keeps its event text, so the history still holds it.
static func _feed_has(h: Node, text: String) -> bool:
	for row in h._log_lines:
		if is_instance_valid(row) and ((row.get_meta("label") as Label).text == text \
				or String(row.get_meta("event_text", "")) == text):
			return true
	return false


## One synchronous loan; all early check failures return through this restore.
static func _readability(g: Game) -> String:
	var p: Player = g.local_player
	var saved := {}
	for field in ["level", "xp", "skill_points", "unspent_attr", "hp", "max_hp", "mp", "themes_known",
			"pending_theme_note", "equipment", "backpack", "bags", "consumables", "active_potion",
			"room_potions", "potion_cd", "dead", "downed", "ghost"]:
		saved[field] = p.get(field)
	saved["ability_theme"] = p.ability_theme.duplicate(true)
	var game_saved := {"dev_mode": g.dev_mode, "run_levels": g.run_levels,
		"pvp_active": g.pvp_active, "pocket_id": g.pocket_id, "settings": g.settings.duplicate(true),
		"binds": g.binds.duplicate(true), "touch_mode": g.touch_mode}
	var pad_active: bool = g.gamepad != null and g.gamepad.active
	var banner_y := g.hud.banner_y
	var hud_saved := {}
	for field in ["_chip_frac", "_chip_hold", "_xp_shown", "_last_level", "_avatar_level_shown",
			"_hint_play_t", "_hint_faded"]:
		hud_saved[field] = g.hud.get(field)
	# Independent of campaign tier, prior point spending, potion plans, gear luck
	# and whichever device last spoke (the copy checks pin keyboard bindings).
	g.dev_mode = true
	g.pvp_active = false
	g.pocket_id = ""
	g.touch_mode = false
	if g.gamepad != null:
		g.gamepad.active = false
	g.binds["skills"] = KEY_F8
	g.binds["inventory"] = KEY_F9
	g.settings["impact_flashes"] = 0.0
	p.level = 1
	p.xp = 0
	p.skill_points = 0
	p.unspent_attr = 0
	p.equipment = {}
	p.backpack = []
	p.bags = [Items.make_bag("S")]
	p.dead = false
	p.downed = false
	p.ghost = false
	p.recalc()
	var error := _level_checks(g)
	if error == "":
		error = _potion_checks(g)
	if error == "":
		error = _gear_checks(g)
	for field in saved:
		p.set(field, saved[field])
	p.recalc()
	p.hp = saved.hp
	p.mp = saved.mp
	for field in game_saved:
		g.set(field, game_saved[field])
	if g.gamepad != null:
		g.gamepad.active = pad_active
	g.hud.banner_y = banner_y
	g.hud._last_level = p.level
	g.hud._avatar_level_shown = 0
	g.hud.update_stats(p)
	for field in hud_saved:
		g.hud.set(field, hud_saved[field])
	if error == "":
		print("ok: level plaques/log/bindings/touch copy/world pop, multi-level awards, low-HP potion cue on bar and touch button, protected gear upgrade banners/stacking and bag badges")
	return error


static func _level_checks(g: Game) -> String:
	var p: Player = g.local_player
	var h := g.hud
	h._ann_queue = []
	# The previous queue-overflow section deliberately filled the bounded feed.
	for row in h._log_lines:
		var tw: Tween = row.get_meta("tween", null)
		if tw != null and tw.is_valid(): tw.kill()
		row.free()
	h._log_lines = []
	var before := g.get_children()
	p.gain_xp(p.xp_needed())
	# The in-world moment: one short 16px pop (18 characters or fewer) and one spark ring.
	var pops := 0
	var sparks := 0
	for node in g.get_children():
		if node in before:
			continue
		if node is Label and String(node.text).contains("LEVEL"):
			pops += 1 if node.text == "LEVEL UP!" else 100
		elif node is CPUParticles2D:
			sparks += 1
		if node is Label or node is CPUParticles2D:
			node.free()
	if pops != 1 or sparks != 1:
		return "level-up lost its short world pop or spark ring"
	if h._ann_queue.size() != 1:
		return "level-up did not queue exactly one plaque"
	var notice: Dictionary = h._ann_queue[0]
	if not String(notice.text).begins_with("LEVEL 2\n") or not String(notice.text).ends_with(" · spend them in Skills [F8]"):
		return "level plaque omitted the level or live skills binding"
	if notice.kind != "victory" or not is_equal_approx(notice.hold, Balance.LEVEL_UP_HOLD):
		return "level plaque lost its reward style or reading time"
	if not String(notice.text).contains("+%d talent point · +%d attribute point" % [Balance.SKILL_POINTS_PER_LEVEL, Balance.ATTR_POINTS_PER_LEVEL]):
		return "level plaque does not use the live point rewards"
	if h._log_lines.size() < 2 or not String(h._log_lines[-1].get_meta("label").text).begins_with("LEVEL 2"):
		return "level-up is missing from the event log"
	if p.skill_points != Balance.SKILL_POINTS_PER_LEVEL or p.unspent_attr != Balance.ATTR_POINTS_PER_LEVEL:
		return "level-up point awards changed"
	h._ann_queue = []
	p.gain_xp(p.xp_needed() + Balance.XP_BASE + (p.level + 1) * Balance.XP_PER_LEVEL)
	if h._ann_queue.size() != 2 or not String(h._ann_queue[0].text).begins_with("LEVEL 3\n") or not String(h._ann_queue[1].text).begins_with("LEVEL 4\n"):
		return "multi-level XP collapsed distinct level plaques"
	if p.skill_points != 3 * Balance.SKILL_POINTS_PER_LEVEL or p.unspent_attr != 3 * Balance.ATTR_POINTS_PER_LEVEL:
		return "multi-level point awards changed"
	# Touch names the HUD icon the player taps; the noun must never double up.
	h._ann_queue = []
	g.touch_mode = true
	p.gain_xp(p.xp_needed())
	g.touch_mode = false
	if h._ann_queue.size() != 1 or not String(h._ann_queue[0].text).ends_with(" · spend them in Skills") \
			or String(h._ann_queue[0].text).contains("["):
		return "touch level plaque garbled its Skills hint"
	return ""


static func _gear_checks(g: Game) -> String:
	var p: Player = g.local_player
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var weak := Items.roll_item_of("weapon", "B", rng, p.cls)
	weak["plus"] = 0
	var strong := weak.duplicate(true)
	strong["plus"] = 3
	p.equipment = {}
	if not p.would_auto_equip(weak): return "empty gear slot was not flagged"
	if _banner_upgrade(g, weak, false) != "": return "upgrade hint pointed at the bag for a piece left on the ground"
	if _banner_upgrade(g, weak) != "▲ Empty slot! Put it on from your bag [F9]": return "empty-slot loot banner omitted its upgrade hint"
	p.equipment = {"weapon": weak}
	if not p.would_auto_equip(strong): return "strict upgrade was not flagged"
	if _banner_upgrade(g, strong) != "▲ Upgrade! Hit Auto-equip in your bag [F9]": return "upgrade banner omitted the bag binding"
	g.touch_mode = true
	var touch_copy := _banner_upgrade(g, strong)
	g.touch_mode = false
	if touch_copy != "▲ Upgrade! Hit Auto-equip in your bag": return "touch upgrade banner garbled its bag hint"
	p.equipment = {"weapon": strong}
	if p.would_auto_equip(weak) or _banner_upgrade(g, weak) != "": return "worse gear was flagged as an upgrade"
	for protection in ["kept", "gems", "passive"]:
		var protected := weak.duplicate(true)
		protected[protection] = true if protection == "kept" else ([Items.make_gem("atk", 1)] if protection == "gems" else "reprisal")
		p.equipment = {"weapon": protected}
		if p.would_auto_equip(strong): return "upgrade flag displaced " + protection
	p.equipment = {}
	var kept := weak.duplicate(true)
	kept["kept"] = true
	var locked := weak.duplicate(true)
	locked["cls"] = "mage" if p.cls != "mage" else "warrior"
	if p.would_auto_equip(kept) or p.would_auto_equip(locked) or p.would_auto_equip(Items.make_gift_health_potion()):
		return "kept, wrong-class or non-gear item was flagged"
	p.backpack = [weak, kept, locked]
	return _bag_checks(g)


## The banner's upgrade line ("" when it has none), or "stacking" when it sits
## over the body or the next banner would start over it. `in_bag` false = a
## full bag left the piece on the ground.
static func _banner_upgrade(g: Game, item: Dictionary, in_bag := true) -> String:
	var p: Player = g.local_player
	p.backpack = [item] if in_bag else []
	g.hud.banner_y = g.hud.LOOT_BANNER_Y
	g.hud.loot_banner(item, 0)
	var advance: float = g.hud.banner_y - g.hud.LOOT_BANNER_Y
	var banner: Node = g.hud.get_child(g.hud.get_child_count() - 1)
	var copy := ""
	var body: Label = null
	for child in banner.get_children():
		if child is Label and child.text.begins_with("▲"):
			copy = String(child.text).replace("\n", " ")
			if body == null or child.position.y < body.position.y + body.get_minimum_size().y \
					or advance < child.position.y + child.get_minimum_size().y:
				copy = "stacking"
		elif child is Label:
			body = child
	banner.free()
	p.backpack = []
	if copy == "" and advance < 52.0:
		return "stacking"
	return copy


static func _bag_checks(g: Game) -> String:
	# A separate real Menus instance preserves an earlier test's open panel.
	var menu := Menus.new()
	menu.game = g
	menu.shell_motion = false
	var paused := g.get_tree().paused
	var visible := g.hud.visible
	var prompts := {}
	for entry in g.interactables:
		var prompt: Variant = entry.get("prompt")
		if is_instance_valid(prompt) and prompt is CanvasItem:
			prompts[prompt] = prompt.visible
	g.add_child(menu)
	menu.open_inventory("gear")
	var arrows := 0
	var stars := 0
	var tipped := true
	var readable := true
	var badge_metrics := ""
	for node in menu.root.find_children("*", "Label", true, false):
		if node.get_parent() is Button:
			if node.text == "▲":
				arrows += 1
				tipped = tipped and String(node.get_parent().tooltip_text).contains(" · Upgrade")
				# Pin a full-size glyph independent of the inherited menu face;
				# the native reward_feedback capture checks its painted footprint.
				readable = readable and node.get_theme_font("font") == ThemeDB.fallback_font \
					and node.get_theme_font_size("font_size") >= Balance.GEAR_UPGRADE_BADGE_FONT_SIZE \
					and -node.offset_top >= node.get_minimum_size().y
				badge_metrics = "font=%s size=%d top=%s minimum=%s" % [node.get_theme_font("font") == ThemeDB.fallback_font,
					node.get_theme_font_size("font_size"), node.offset_top, node.get_minimum_size()]
			if node.text == "★": stars += 1
	menu.free()
	g.get_tree().paused = paused
	g.hud.visible = visible
	for prompt in prompts:
		if is_instance_valid(prompt): prompt.visible = prompts[prompt]
	if not tipped:
		return "bag upgrade badge has no tooltip explanation"
	if not readable:
		return "bag upgrade badge inherited a tiny glyph or clipped its font height: " + badge_metrics
	return "" if arrows == 1 and stars == 1 else "bag upgrade badge missing or kept-star precedence changed"


## Every precondition of a usable low-health drink, set fresh (no inherited state).
static func _arm_potion(g: Game) -> void:
	var p: Player = g.local_player
	p.hp = p.max_hp * 0.2
	p.consumables = [Items.make_gift_health_potion()]
	p.room_potions = {"health": 1}
	p.potion_cd = 0.0
	p.dead = false
	p.downed = false
	p.ghost = false
	p.active_potion = "health"
	g.pvp_active = false


static func _potion_checks(g: Game) -> String:
	var p: Player = g.local_player
	var h := g.hud
	var box: Dictionary = h.slot_boxes[h.SLOTS.find("potion")]
	var rest := Color(0.75, 0.35, 0.35)
	var hot := Balance.POTION_URGENT_COLOR
	# This fixture tests potion feedback, not the independent XP-bar flourish.
	h._last_level = p.level
	h._avatar_level_shown = 0
	p.max_hp = 100.0 # exact threshold fixture, independent of inherited stat fractions
	_arm_potion(g)
	h.update_stats(p)
	if not box.border.get_meta("urgent", false) or box.ring_style.border_color == rest:
		return "available gift potion has no low-health cue"
	# Flashes off: ring, key label and vignette all hold the steady midpoint.
	if not box.ring_style.border_color.is_equal_approx(rest.lerp(hot, 0.5)) \
			or not box.key.modulate.is_equal_approx(Color.WHITE.lerp(hot, 0.5)) \
			or not h.vignette.modulate.is_equal_approx(Color(1.3, 0.75, 0.75, 1.3)):
		return "low-health cue ignores the flashes comfort setting"
	# Flashes on: the ring and key label ride the vignette's own pulse this frame.
	g.settings["impact_flashes"] = 1.0
	h.update_stats(p)
	var pulse: float = (h.vignette.modulate.r - 1.0) / 0.6
	g.settings["impact_flashes"] = 0.0
	if not box.ring_style.border_color.is_equal_approx(rest.lerp(hot, pulse)) \
			or not box.key.modulate.is_equal_approx(Color.WHITE.lerp(hot, pulse)):
		return "potion cue does not pulse with the low-health vignette"
	for blocked in ["healthy", "threshold", "empty", "spent", "other_budget", "cooldown", "dead", "downed", "ghost", "duel", "other_active"]:
		# Each gate must clear a cue that was live a moment ago.
		_arm_potion(g)
		h.update_stats(p)
		if not box.border.get_meta("urgent", false):
			return "potion cue did not re-arm before " + blocked
		match blocked:
			"healthy": p.hp = p.max_hp * 0.8
			"threshold": p.hp = p.max_hp * Balance.LOW_HP_WARN_FRAC
			"empty": p.consumables = []
			"spent": p.room_potions = {}
			"other_budget": p.room_potions = {"mana": 1}
			"cooldown": p.potion_cd = 1.0
			"dead": p.dead = true
			"downed": p.downed = true
			"ghost": p.ghost = true
			"duel": g.pvp_active = true
			"other_active": p.active_potion = "mana"
		h.update_stats(p)
		if box.border.get_meta("urgent", false) or box.key.modulate != Color.WHITE:
			return "potion cue did not reset for " + blocked
		if blocked == "threshold" and h.vignette.modulate != Color(1, 1, 1):
			return "low-health vignette still shows at the threshold"
	return _touch_potion_checks(g)


## The touch potion button carries the same cue (touch hides the ability bar).
## A detached TouchHud: its buttons are built, but _ready never runs, so the
## keyboard ability bar keeps its desktop visibility.
static func _touch_potion_checks(g: Game) -> String:
	var p: Player = g.local_player
	var th := TouchHud.new()
	th.game = g
	for id in th.BTN_LAYOUT:
		th._make_button(String(id))
	var panel: Panel = th._btns["potion"].panel
	var label: Label = th._btns["potion"].label
	var rim := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var hot := Balance.POTION_URGENT_COLOR
	var error := ""
	_arm_potion(g)
	th._refresh_ability_icons()
	if not panel.get_meta("urgent", false) or not rim.border_color.is_equal_approx(th.BTN_BORDER.lerp(hot, 0.5)) \
			or not label.modulate.is_equal_approx(Color.WHITE.lerp(hot, 0.5)):
		error = "touch potion button has no low-health cue"
	for blocked in ["healthy", "cooldown"]:
		_arm_potion(g)
		if blocked == "healthy": p.hp = p.max_hp * 0.8
		if blocked == "cooldown": p.potion_cd = 1.0
		th._refresh_ability_icons()
		if error == "" and (panel.get_meta("urgent", false) or rim.border_color != th.BTN_BORDER or label.modulate != Color.WHITE):
			error = "touch potion cue did not reset for " + blocked
	th.free()
	return error
