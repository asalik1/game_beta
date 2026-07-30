extends "res://scripts/game_base.gd"
## GAME, layer 2 of 4 — the world: chapter/room graph generation, room
## building (walls, gates, scenery, NPCs), monster/merchant/elite
## spawning and terrain application. See game_base.gd for the layout.


## Open any built gate whose lock condition is now satisfied.
func _recheck_gates() -> void:
	for key in gates.keys():
		var parts: PackedStringArray = String(key).split("_")
		var a := int(parts[0])
		var b := int(parts[1])
		if _edge_unlocked(a, b):
			open_edge(a, b)


## MP (Wave-1 co-op fix): apply a host-fanned boss_done mark on a guest — record
## it, then reopen any built gate whose "boss" lock it just satisfied. A guest
## already standing in the arena has a built, locked gate (this opens it); a
## guest that builds the arena LATER never builds the gate at all (the gate-
## construction guard in _build_room_walls reads boss_done). Reached from
## net_session._rpc_boss_done — solo never sets a boss_done over the wire.
func net_apply_boss_done(kind: String) -> void:
	boss_done[kind] = true
	_recheck_gates()

## Tear the world down and rebuild it from another chapter's data.
## Only ever called before play starts (chapter select) or on load —
## dynamic entities (chests, pickups, projectiles) don't exist then.
func switch_chapter(id: String, force := false) -> void:
	# World teardown: forgotten ground loot mails itself first (round 8).
	flush_dropped_loot()
	if not (Story.CHAPTER_LIST.has(id) or Story.is_endgame(id) or Story.is_standalone(id)) or (id == chapter_id and not force):
		return
	chapter_id = id
	# NG+ tier snapshot: the RUN owns its tier from launch to clear. The
	# picker edits the character's STANDING choice; it arms HERE, where
	# every campaign (re)launch passes (replay/advance/new game). Endgame
	# arenas keep the campaign's snapshot parked (run_tier() forces 0
	# there anyway). A net GUEST never arms its own — the host's brief
	# owns the value, applied AFTER this rebuild (join snapshot /
	# net_advance, the weekly-flags pattern).
	if not Story.is_endgame(id) and not net_guest():
		world_run_tier = player.run_tier if has_local_player() else 0
	# Wave 9, the party-town contract: the lobby is OPEN while the session
	# world is a SAFE HUB (the capital — friends join the plaza and the
	# party gathers in person) and LOCKS the moment real content starts
	# (the §5.1 rule, now a LIFECYCLE instead of a one-way latch). Scope:
	# PLAYER-HOSTED listen sessions only — a DEDICATED server world has no
	# local player and admits joiners at any time (the MMO-step contract;
	# this line closing it was stage 12's admission timeout), and the dev
	# CLI/harness seam stays join-anytime (MP-08 --mp-host; the flag lives
	# in the derived layer — the MP-12 get("downed") idiom). Stage 15
	# clears mp_host to opt INTO production semantics; it IS this test.
	if net_host() and has_local_player() and not bool(get("mp_host")):
		get_node("/root/NetworkManager").lobby_open = Story.is_standalone(id)
	# Waking Incursion snapshot (world state, wander_seed contract): a LOAD
	# hands the saved week through _waking_restore so the rebuilt graph
	# matches the save; a fresh launch arms only for a SOLO visit to the
	# week's rotating chapter once THIS character has cleared it, and only
	# on spine chapters (the legacy ch2 strip has no attach pass — its
	# graph-retrofit inherits the event). Co-op sync = flagged follow-up.
	# A GUEST always clears the value — the host's world has no breaches,
	# and a stale solo week must never inject rooms into a briefed world.
	if not Story.is_endgame(id):
		if net_guest():
			waking_week = -1
		elif _waking_restore != -2:
			waking_week = _waking_restore
			_waking_restore = -2
		else:
			waking_week = -1
			if not net_online() and Story.CHAPTER_LIST.has(id) and id == weekly_chapter() \
					and get_flag("completed_" + id, false) \
					and not Story.chapter(id).get("spine", []).is_empty():
				waking_week = _week_index()
	_quest_avail_cache = -1  # a new chapter offers a whole new set (⚑ shine memo)
	quest_marks.clear()      # the old world's ❢ nodes die with it
	# Potion investment (2026-07-09): stock is BOUGHT and carries across
	# chapters — no grants. The one exception: entering a teaching chapter
	# (ch1-3) hands ONE free health potion that EXPIRES on leaving it. The
	# absolute set below is grant + expiry in one move (revisits can never
	# stack freebies); loads overwrite it from the save right after this.
	if has_local_player():
		player.potions_free = 1 if chapter_id in Balance.FREE_POTION_CHAPTERS else 0
	var chapter: Dictionary = Story.chapter(id)
	zones = chapter["zones"]
	zone_count = zones.size()
	# Campaign-only: an endgame arena PARKS the campaign's waking_week (the
	# run_tier pattern) and must never grow breach rooms of its own.
	if waking_week >= 0 and Story.CHAPTER_LIST.has(id):
		# Breach rooms append to a DUPLICATE of the authored array — the
		# chapter dict is shared Story data and must never grow permanently.
		zones = _waking_inject(zones, id, waking_week)
		zone_count = zones.size()

	if is_instance_valid(world):
		world.free()  # immediate: everything world-owned dies with it
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	# Draw under the hero again (a DEDICATED server renders nothing — any
	# slot works, and there is no hero to sit under).
	move_child(world, player.get_index() if has_local_player() else 0)

	gates.clear()
	interactables.clear()
	zone_alive.clear()
	boss_spawned.clear()
	boss_done.clear()
	merchant_zones.clear()
	hazards.clear()
	zone_grounds.clear()
	zone_road_marks.clear()
	zone_scenery.clear()
	shop_stock.clear()
	built.clear()
	visited.clear()
	cleared.clear()
	door_seen.clear()
	bosses.clear()
	victory_gates_up = false   # the way-gates died with the old world's nodes
	current_boss = null
	elder = null
	barrier_active = false
	talked_to_elder = false
	last_room = -1
	gust_vec = Vector2.ZERO
	terrain_by_zone.clear()
	for zone in zones:
		terrain_by_zone.append(zone.get("terrain", "village"))
	_prepare_rooms()
	_build_door_seals()
	quest_key = String(chapter.get("start_quest", "talk"))

	if has_local_player():
		player.global_position = _start_pos()
	last_safe_room = maxi(0, room_at_pos(_start_pos()))
	_enter_room(last_safe_room)
	ambient.color = Terrains.get_terrain(terrain_by_zone[cur_room])["tint"]
	refresh_quest()


## Enter Crownfall, the standalone capital hub (dev panel "Go To Capital").
## Remembers the chapter we left so the hub's Story gate can return there.
func enter_capital() -> void:
	if chapter_id != "capital":
		_pre_capital_chapter = chapter_id
	switch_chapter("capital", true)
	# First arrival (capital rework §5): one short welcome, once per character.
	# The plaza artisans' ❢ marks carry the onboarding from here.
	if not get_flag("cap_seen", false) and has_local_player():
		set_flag("cap_seen")
		hud.dialogue([
			["Narrator", "CROWNFALL — the capital. Whatever the road takes, the city holds: forge and lapidary, vault and bazaar, and every gate worth walking through."],
			["Narrator", "The marked folk on the plaza have work for a newcomer. Speak to them."],
		])


## An interaction dispatched by a Crownfall hub prop (a portal or a civic desk).
## The three portals leave for a mode; the desks open an existing menu. Keyed
## off the "action" field on the zone's npc def (see _build_room). enter_endgame
## lives in the derived game_flow layer, so it is reached via a dynamic call.
func _hub_action(act: String) -> void:
	match act:
		"portal_story":
			# Wave 9: in a PARTY the portal is the content queue — the HOST
			# picks the road (chapter + NG+ tier, the reprise picker) and the
			# MP-20 ready check reaches every head in the plaza; guests are
			# told who leads. Solo (or a party of 1) keeps the simple door:
			# back to the campaign we came from (dev may have jumped in cold).
			if net_online() and net_guest():
				spawn_text(player.global_position + Vector2(0, -90),
					"The party leader chooses the road — gather at the portal.",
					Color(0.8, 0.85, 1.0), 3.0)
			elif net_host() and not get_node("/root/NetworkManager").peers.is_empty():
				menus.lobby["reprise"] = true
				menus.open_lobby("chapter")
			else:
				switch_chapter(_pre_capital_chapter if _pre_capital_chapter != "" else "ch1", true)
		"portal_crucible":
			call("enter_endgame", "crucible")
		"portal_depths":
			call("enter_endgame", "depths")
		"vault":
			menus.open_stash()
		"wardrobe":
			# Not yet placed in the generated capital (gen_capital.py owns
			# that file); the case is ready for the wardrobe desk it will add.
			menus.open_wardrobe()
		"codex":
			menus.open_codex("monsters")
		"records":
			menus.open_codex("records")
		"daily":
			menus.open_daily()
		"journal":
			menus.open_journal("log")
		"mail":
			menus.open_mailbox()
		"guild":
			# The Chartered Hall is Crownfall's player-to-player gathering
			# point. Reuse the real party/lobby surface instead of leaving the
			# largest civic building as flavour-only scenery.
			menus.open_lobby("menu")
		"skills":
			menus.open_skills("talents")
		"gear":
			menus.open_inventory("gear")
		"map":
			menus.open_map()
		"shop":
			# Landmark-owned bazaar stalls use the room they stand in, so the
			# inventory and sell state match the room's actual merchant stock.
			menus.open_shop(cur_room)
		"potions":
			menus.open_potion_loadout()
		"forge":
			_cap_artisan("petra")
		"lapidary":
			_cap_artisan("lapidary")
		"drill":
			_cap_drill()
		_:
			push_warning("hub action unhandled: %s" % act)


func _inspect_landmark(title: String, text: String) -> void:
	hud.dialogue([[title, text]])


# ------------------------------------- capital rework: services + quests ---
# (2026-07-25, PROPOSALS/CAPITAL_REWORK.md §4-5) The plaza artisans OWN their
# services — one access point per function. Each carries a small intro quest
# accepted and turned in AT the NPC (reward + favor), and a ❢ that self-polls
# so the mark always means "this person has something for you".
# All cap_* flags are character-scoped (KEPT_FLAG_PREFIXES) — they survive
# chapter wipes and stay per-head in co-op.

const CAP_ARTISANS := {
	"petra": {
		"who": "Smith Petra", "greet": "cap_petra", "quest": "forge",
		"qname": "Tempered Once",
		"hub": "The forge is lit. What do you need?",
		"offer": "Bench rules: your coin, my fire. Here's a bargain for a new patron — temper any piece once, quench, reforge or transmute, and I'll stand you the fee back with interest. Deal's open till it's done.",
		"turnin": "So the fire took. That's the bench paid back, as promised — and I'll remember the name over the coin. Regulars get my better rates.",
	},
	"lapidary": {
		"who": "Master Lapidary", "greet": "cap_lapidary", "quest": "gem",
		"qname": "A Stone Well Set",
		"hub": "Benches are clear. Stones and sockets — or something else?",
		"offer": "You've never set a stone? Then your first lesson is on the house. Here — a cut gem, and a keepsake with an empty socket to seat it in. Bring me back the fit.",
		"turnin": "A clean seat. You have the hands for it. Bring me your patronage and your rough stones — patient patrons get my patient prices.",
	},
}

## A plaza artisan is a GOSSIP HUB (owner 2026-07-25): one press opens the
## splash dialogue with options — the bench, the intro-quest line whenever it
## has something to say, and a way out. First meeting still plays the greet.
func _cap_artisan(npc: String) -> void:
	var d: Dictionary = CAP_ARTISANS[npc]
	var qid := String(d["quest"])
	var who := String(d["who"])
	if not get_flag("cap_met_" + npc, false):
		set_flag("cap_met_" + npc)
		run_convo_id(String(d["greet"]), func() -> void: _cap_artisan(npc))
		return
	var options: Array = ["Use the bench"]
	var acts: Array = ["bench"]
	if not get_flag("cap_q_%s_on" % qid, false):
		options.append("\"Any work for a newcomer?\"")
		acts.append("offer")
	elif get_flag("cap_q_%s_done" % qid, false) and not get_flag("cap_q_%s_paid" % qid, false):
		options.append("Turn in — %s" % String(d["qname"]))
		acts.append("turnin")
	options.append("(Leave)")
	acts.append("leave")
	hud.dialogue_choice(who, String(d["hub"]), options, func(idx: int) -> void:
		_cap_artisan_choice(npc, acts, idx))


## One picked option from an artisan's gossip hub (named method — a match
## statement can't close a multiline lambda, GDScript trap §38).
func _cap_artisan_choice(npc: String, acts: Array, idx: int) -> void:
	var d: Dictionary = CAP_ARTISANS[npc]
	var qid := String(d["quest"])
	var who := String(d["who"])
	match String(acts[clampi(idx, 0, acts.size() - 1)]):
		"bench":
			_cap_open_service(npc)
		"offer":
			set_flag("cap_q_%s_on" % qid)
			if qid == "gem" and has_local_player():
				# The training KIT (2026-07-25): gems need a socketed vessel
				# and the socket floor is C-grade — a fresh ch1 hero owns
				# nothing socketable, so the lesson supplies both halves: a
				# socketed keepsake charm + a REGULAR cut stone (specials
				# would be refused by the very vessel she hands over).
				var charm: Dictionary = Items.roll_item_of("charm", "C", loot_rng, player.cls)
				if int(charm.get("gem_slots", 0)) < 1:
					Items.add_socket(charm)
				var gem: Dictionary = Items.make_gem("atk_flat", 1)
				if not player.add_item(charm):
					send_mail("The Lapidary's keepsake",
						"Your bag was full at the bench — the training keepsake waits here.",
						[{"kind": "item", "item": charm}])
				if not player.gain_gem(gem):
					send_mail("The Lapidary's training stone",
						"Your bag was full at the bench — the training gem waits here.",
						[{"kind": "gem", "gem": gem}])
			hud.dialogue([[who, String(d["offer"])]], func() -> void: _cap_open_service(npc))
			refresh_quest_marks()
		"turnin":
			set_flag("cap_q_%s_paid" % qid)
			if has_local_player():
				player.gold += Balance.CAPITAL_INTRO_GOLD
				spawn_text(player.global_position + Vector2(0, -56),
					"+%d gold" % Balance.CAPITAL_INTRO_GOLD, Color(1.0, 0.85, 0.35))
			favor_add(npc, Balance.FAVOR_QUEST_POINTS)
			sfx("chest")
			hud.dialogue([[who, String(d["turnin"])]])
			refresh_quest_marks()
			autosave()


func _cap_open_service(npc: String) -> void:
	menus.open_inventory("gear")


## Marshal Corin, the plaza drillmaster: the same gossip-hub shape — quest
## line when it has something to say, drill-yard flavor always.
func _cap_drill() -> void:
	var who := "Marshal Corin"
	var options: Array = []
	var acts: Array = []
	if not get_flag("cap_q_talent_on", false):
		options.append("\"Any work for a newcomer?\"")
		acts.append("offer")
	elif get_flag("cap_q_talent_done", false) and not get_flag("cap_q_talent_paid", false):
		options.append("Turn in — The Marshal's Approval")
		acts.append("turnin")
	options.append("Ask about the drill yard")
	acts.append("talk")
	options.append("(Leave)")
	acts.append("leave")
	hud.dialogue_choice(who, "Fresh boots on my yard. Speak.", options, func(idx: int) -> void:
		_cap_drill_choice(acts, idx))


func _cap_drill_choice(acts: Array, idx: int) -> void:
	var who := "Marshal Corin"
	match String(acts[clampi(idx, 0, acts.size() - 1)]):
		"offer":
			set_flag("cap_q_talent_on")
			hud.dialogue([[who, "Green as the Warren, then. Open your talents, commit one point — the tree remembers what the arm forgets. Show me you've chosen, and the drill yard pays for the lesson."]])
			refresh_quest_marks()
		"turnin":
			set_flag("cap_q_talent_paid")
			if has_local_player():
				player.gold += Balance.CAPITAL_INTRO_GOLD
				spawn_text(player.global_position + Vector2(0, -56),
					"+%d gold" % Balance.CAPITAL_INTRO_GOLD, Color(1.0, 0.85, 0.35))
			sfx("chest")
			hud.dialogue([[who, "Committed, and to something with a spine. The yard pays its debts — now go spend the rest of yourself the same way."]])
			refresh_quest_marks()
			autosave()
		"talk":
			hud.dialogue([[who, "Companies drill here before they take the northern gates. The Crucible arch in the Sanctum is the live trial — the rail is for bragging."]])


## Does this capital service NPC have something NEW for the player? Drives
## the self-polling ❢ (unmet greet, unasked quest, or a turn-in owed).
func _cap_mark_active(act: String) -> bool:
	match act:
		"forge":
			return not get_flag("cap_met_petra", false) \
				or not get_flag("cap_q_forge_on", false) \
				or (get_flag("cap_q_forge_done", false) and not get_flag("cap_q_forge_paid", false))
		"lapidary":
			return not get_flag("cap_met_lapidary", false) \
				or not get_flag("cap_q_gem_on", false) \
				or (get_flag("cap_q_gem_done", false) and not get_flag("cap_q_gem_paid", false))
		"drill":
			return not get_flag("cap_q_talent_on", false) \
				or (get_flag("cap_q_talent_done", false) and not get_flag("cap_q_talent_paid", false))
	return false


## Hang the bobbing ❢ over a capital service NPC (same look as the side-quest
## giver mark). Registered in quest_marks with a "cap" key; refresh_quest_marks
## polls _cap_mark_active on the same set_flag beats.
func _mark_capital_npc(npc: Node2D, act: String) -> void:
	if act not in ["forge", "lapidary", "drill"]:
		return
	var mark := Label.new()
	mark.text = "❢"
	mark.position = Vector2(-40, -84)
	mark.size = Vector2(80, 22)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	mark.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	mark.add_theme_constant_override("outline_size", 5)
	npc.add_child(mark)
	var tw := mark.create_tween().set_loops()
	tw.tween_property(mark, "position:y", -90.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mark, "position:y", -84.0, 0.9).set_trans(Tween.TRANS_SINE)
	quest_marks.append({"node": mark, "cap": act})
	refresh_quest_marks()


# --------------------------------- capital rework §6: victory way-gates ---
# The chapter-end choice lives in the WORLD now: three gates rise beside the
# fallen final boss — Crownfall, a fresh pass, the road on. Solo they act
# directly; a HOST with a party rides the Wave-9 machinery (the reprise
# picker / the MP-20 "advance" proposal), so nobody can be stranded; a guest
# is told the leader picks the road. Rebuilt with the arena on load, so a
# save made after the kill still finds its way out.

func spawn_victory_gates(zi: int = -1) -> void:
	if victory_gates_up:
		return
	victory_gates_up = true
	var room := zi if zi >= 0 else cur_room
	var c := room_center(room)
	var next_ch := Story.next_chapter(chapter_id)
	# Each gate wears its own TINT (owner 2026-07-25: three identical blue
	# arches read as one choice) — Crownfall warm gold, Return cool violet,
	# the Road onward verdant. A photo-filter wash over the shared arch art.
	var defs: Array = [
		["capital", "E — Gate of Crownfall  (the capital)", Vector2(-300, -20), Color(1.0, 0.86, 0.6)],
		["replay", "E — Gate of Return  (a fresh pass at %s)" % String(Story.chapter(chapter_id)["name"]), Vector2(0, -90), Color(0.85, 0.75, 1.0)],
	]
	if next_ch != "":
		defs.append(["next", "E — Gate of the Road  (onward to %s)" % String(Story.chapter(next_ch)["name"]), Vector2(300, -20), Color(0.7, 1.0, 0.72)])
	for d in defs:
		var kind: String = d[0]
		# The arch is a STRUCTURE (width-normalized, base collider) — the NPC
		# render path would blow the 512px source up ~5x. The interaction is a
		# separate hidden hotspot in front, prompt lifted onto the arch, prop
		# reach (same idiom as the capital's own Wayfinder portals).
		var gate_world: Vector2 = c + (d[2] as Vector2)
		var gate_node := _add_structure("capital_portal_story", gate_world)
		gate_node.modulate = d[3]
		var gate_h: float = float(gate_node.get_child(0).get_meta("hpx", 200.0))
		var hotspot := _make_npc("book", gate_world + Vector2(0, 34),
			String(d[1]), func() -> void:
				_gate_use(kind), "", Balance.PROP_HOTSPOT_REACH)
		for child in hotspot.get_children():
			if child is Sprite2D:
				child.visible = false
			elif child is Label:
				child.position.y = -(34.0 + gate_h * Balance.PROP_PROMPT_HEIGHT)


func _gate_use(kind: String) -> void:
	if net_online() and net_guest():
		spawn_text(player.global_position + Vector2(0, -90),
			"The party leader chooses the road — gather at the gates.",
			Color(0.8, 0.85, 1.0), 3.0)
		return
	var partied: bool = net_host() and not get_node("/root/NetworkManager").peers.is_empty()
	match kind:
		"capital":
			if partied:
				# The party heads home TOGETHER — the reprise picker's capital
				# row runs the ready check and the advance snap (Wave 9).
				menus.lobby["reprise"] = true
				menus.open_lobby("chapter")
			else:
				enter_capital()
		"replay":
			if partied:
				menus.lobby["reprise"] = true
				menus.open_lobby("chapter")
			else:
				call("reprise_chapter", chapter_id,
					player.run_tier if has_local_player() else 0)
		"next":
			var nxt := Story.next_chapter(chapter_id)
			if nxt == "":
				return
			if partied:
				# MP-20: the road on is a PROPOSAL — _finish_check launches the
				# advance itself when every head confirms.
				var sess: Node = get_node_or_null("/root/NetworkManager/Session")
				if sess == null or bool(sess.propose_content("advance", nxt, world_run_tier, false)):
					call("advance_chapter")
			else:
				call("advance_chapter")


# ------------------------------------------------- waking incursions ---

## The week's breach roster for a chapter: WAKING_ROOMS distinct story
## bosses authored in OTHER chapters (the wrong god-king's domain — the
## terrain mismatch IS the story), deterministic from the week, so every
## player faces the same echoes. Each entry: {kind, terrain (the boss's
## own home room), level (this chapter's finale + WAKING_LEVEL_BONUS)}.
## Pure function of (chid, week) — the autotest exercises it directly.
func _waking_roster(chid: String, week: int) -> Array:
	var pool: Array = []          # [kind, home terrain] from other chapters
	for cid in Story.CHAPTER_LIST:
		if String(cid) == chid:
			continue
		for z in Story.chapter(String(cid))["zones"]:
			var bk := String(z.get("boss", ""))
			if bk != "" and Story.ALL_ENEMIES.has(bk):
				pool.append([bk, String(z.get("terrain", "village"))])
	var rng := RandomNumberGenerator.new()
	rng.seed = week * 8117 + chid.hash() % 100003
	for i in range(pool.size() - 1, 0, -1):  # seeded Fisher-Yates
		var j := rng.randi_range(0, i)
		var tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
	var fb := String(Story.chapter(chid).get("final_boss", ""))
	var target := int(Story.ALL_ENEMIES.get(fb, {}).get("level", 10)) + Balance.WAKING_LEVEL_BONUS
	# Eligibility: prefer echoes at or UNDER the chapter's target — the
	# no-downscaling rule means an over-level echo fights at its NATIVE
	# level (make_boss treats authored level as a minimum), and a late-act
	# legend would wall an early chapter's sweep. Fill from the lowest
	# natives above only when the eligible pool runs short.
	var eligible: Array = []
	var high: Array = []
	var seen := {}
	for entry in pool:
		if seen.has(entry[0]):
			continue
		seen[entry[0]] = true
		var native := int(Story.ALL_ENEMIES[entry[0]].get("level", 1))
		(eligible if native <= target else high).append(entry)
	high.sort_custom(func(a, b) -> bool:
		var la := int(Story.ALL_ENEMIES[a[0]].get("level", 1))
		var lb := int(Story.ALL_ENEMIES[b[0]].get("level", 1))
		return la < lb if la != lb else String(a[0]) < String(b[0]))
	var out: Array = []
	for entry in eligible + high:
		if out.size() >= Balance.WAKING_ROOMS:
			break
		var native := int(Story.ALL_ENEMIES[entry[0]].get("level", 1))
		out.append({"kind": entry[0], "terrain": entry[1], "level": maxi(target, native)})
	return out


## Extend a chapter's authored zone list with the week's breach rooms —
## returns a NEW array (the input is shared Story data). The breaches are
## exploration-only boss rooms; the spine layout's side-attach pass places
## them (foreign terrain falls through to the any-host pass by design).
func _waking_inject(zones_in: Array, chid: String, week: int) -> Array:
	var out: Array = zones_in.duplicate()
	for e in _waking_roster(chid, week):
		out.append({"name": "Waking Breach", "type": "combat",
			"terrain": String(e["terrain"]), "enemies": [],
			"boss": String(e["kind"]), "boss_level": int(e["level"]),
			"waking": String(e["kind"]),
			"obstacle_count": 0, "decor_count": 0})
	return out


# ------------------------------------------------------- the room graph ---

## Build the runtime graph meta (grid coords, exits, locks, scales)
## from the chapter's room dicts. Chapters authored WITHOUT coords are
## legacy west→east strips: they become a one-row chain, and all their
## authored positions rescale from the old 34x15 zone into the room.
func _prepare_rooms() -> void:
	rooms.clear()
	coord_to_room.clear()
	edge_locks.clear()
	# Chapters with a SPINE get a seeded procedural layout instead of
	# their authored coords — every run is a different map.
	var spine: Array = Story.chapter(chapter_id).get("spine", [])
	if not spine.is_empty():
		_generate_layout(spine)
		return
	var graph := false
	for zone in zones:
		if zone.has("coord"):
			graph = true
			break
	for i in zone_count:
		var zone: Dictionary = zones[i]
		var meta := {}
		var exits := {}
		if graph:
			var c: Array = zone.get("coord", [i, 0])
			meta["coord"] = Vector2i(int(c[0]), int(c[1]))
			meta["scale"] = Vector2.ONE
			var locks: Dictionary = zone.get("locks", {})
			for dir in zone.get("exits", []):
				exits[String(dir)] = String(locks.get(dir, ""))
		else:
			meta["coord"] = Vector2i(i, 0)
			meta["scale"] = Vector2(float(ROOM_W) / LEGACY_W, float(ROOM_H) / LEGACY_H)
			if i > 0:
				exits["W"] = ""
			if i < zone_count - 1:
				# Old strip gate rule: the way east opens when this zone's
				# boss dies or its gate_flag is set.
				var lock := ""
				if String(zone.get("boss", "")) != "":
					lock = "boss"
				elif String(zone.get("gate_flag", "")) != "":
					lock = "flag:" + String(zone["gate_flag"])
				exits["E"] = lock
		meta["exits"] = exits
		meta["origin"] = Vector2(meta["coord"].x * ROOM_W, meta["coord"].y * ROOM_H)
		rooms.append(meta)
		coord_to_room[meta["coord"]] = i
	# Exits are declared one-sided; imply the reciprocal, and register
	# each locked edge with the room that owns the lock condition.
	for i in zone_count:
		var exits: Dictionary = rooms[i]["exits"]
		for dir in exits.keys():
			var nb := neighbor(i, dir)
			if nb < 0:
				push_warning("room %d: exit %s leads nowhere" % [i, dir])
				exits.erase(dir)
				continue
			var nexits: Dictionary = rooms[nb]["exits"]
			if not nexits.has(OPP[dir]):
				nexits[OPP[dir]] = ""
			var lock: String = exits[dir]
			if lock != "" and not edge_locks.has(_edge_key(i, nb)):
				edge_locks[_edge_key(i, nb)] = {"lock": lock, "own": i}

## Seeded procedural layout (playtest round 3: "why is every run the
## same map?"). The spine (story-ordered boss path) walks the grid
## east with seeded N/S jogs — at most one vertical step per column,
## which makes the walk provably self-avoiding. Side rooms then attach
## to a seeded host of the SAME TERRAIN with a free edge (falling back
## to any placed room), so wings and dead ends land somewhere new each
## run. Pure function of wander_seed: saves reload the same world;
## replays and new characters roll a fresh one.
func _generate_layout(spine: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 31 + chapter_id.hash() % 100003
	var coord := {}                     # room idx -> Vector2i
	var room_exits: Array = []          # room idx -> {dir: lock}
	for i in zone_count:
		room_exits.append({})

	# --- the spine walk ---
	var at := Vector2i(0, 0)
	coord[int(spine[0])] = at
	var vertical_last := false
	for k in range(1, spine.size()):
		var dir := "E"
		if not vertical_last and rng.randf() < 0.45:
			dir = "N" if rng.randf() < 0.5 else "S"
		vertical_last = dir != "E"
		var prev := int(spine[k - 1])
		var cur := int(spine[k])
		at += Vector2i(DIRS[dir])
		coord[cur] = at
		room_exits[prev][dir] = String(zones[prev].get("lock_next", ""))
		room_exits[cur][OPP[dir]] = ""

	# --- side rooms attach to same-terrain hosts (then anyone) ---
	var placed: Array = spine.duplicate()
	var taken := {}
	for i in coord:
		taken[coord[i]] = true
	for i in zone_count:
		if coord.has(i):
			continue
		var cands: Array = []
		for pass_same in [true, false]:
			for p in placed:
				if pass_same and terrain_by_zone[int(p)] != terrain_by_zone[i]:
					continue
				for d in ["N", "S", "E", "W"]:
					if room_exits[int(p)].has(d):
						continue
					if not taken.has(coord[int(p)] + Vector2i(DIRS[d])):
						cands.append([int(p), d])
			if not cands.is_empty():
				break
		if cands.is_empty():
			push_warning("layout: no host found for room %d" % i)
			continue
		var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
		var host := int(pick[0])
		var host_dir := String(pick[1])
		coord[i] = coord[host] + Vector2i(DIRS[host_dir])
		taken[coord[i]] = true
		room_exits[host][host_dir] = ""
		room_exits[i][OPP[host_dir]] = ""
		placed.append(i)

	# --- write the runtime meta (same shape as the authored path) ---
	for i in zone_count:
		var meta := {"coord": coord[i], "scale": Vector2.ONE, "exits": room_exits[i],
			"origin": Vector2(coord[i].x * ROOM_W, coord[i].y * ROOM_H)}
		rooms.append(meta)
		coord_to_room[coord[i]] = i
	for i in zone_count:
		var exits: Dictionary = rooms[i]["exits"]
		for dir in exits.keys():
			var lock := String(exits[dir])
			var nb := neighbor(i, String(dir))
			if lock != "" and nb >= 0 and not edge_locks.has(_edge_key(i, nb)):
				edge_locks[_edge_key(i, nb)] = {"lock": lock, "own": i}

## Make room i the live room: build it on first entry, clamp the camera
## to it, wake the mood, autosave. Only the live room simulates.
func _enter_room(i: int) -> void:
	if i < 0 or i >= zone_count:
		return
	var prev := cur_room
	_build_room(i)
	var first_visit: bool = not visited.get(i, false)
	visited[i] = true
	cur_room = i
	_refresh_active_rooms()  # the sim gate follows atomically (MP §4.3)
	_calm_left_room(prev, i)
	if is_instance_valid(player):
		player.reset_room_potions()  # the loadout's per-room budget refills
	# Standing in a room, you can SEE its doors: neighbors go on the map
	# as stubs, and a seen boss door gets its marker.
	for dir in rooms[i]["exits"].keys():
		var nb := neighbor(i, dir)
		if nb >= 0:
			door_seen[nb] = true
	# Camera clamps to the PLAYABLE rect — small rooms read small, and
	# the empty margin outside their walls never shows.
	var r := play_rect(i)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
	if room_safe(i):
		last_safe_room = i
	var terrain := Terrains.get_terrain(terrain_by_zone[i])
	var tween := create_tween()
	tween.tween_property(ambient, "color", terrain["tint"], 1.0)
	_setup_ambient_fx(terrain_by_zone[i])
	terrain_event_t = randf_range(2.5, 5.0)
	var room_boss: Boss = null
	var rogue_boss := false
	for b in _live_bosses():
		var live_b: Boss = b
		if live_b.zone_idx == i:
			room_boss = live_b
		elif live_b.zone_idx < 0:
			rogue_boss = true
	if room_boss != null:
		# Walking back into a live arena: the fight's bar + music resume.
		current_boss = room_boss
		set_music(_boss_music())
		hud.show_boss_bar(room_boss.display_name)
	elif not rogue_boss:
		set_music(terrain.get("music", "village"))
	if play_started and first_visit:
		hud.flash_title(zones[i]["name"])
		# The cursed chest's bargain is offered at the door, once,
		# while the pack still stands (playtest 2026-07-07).
		_offer_cursed_chest(i)
	refresh_quest()
	_try_spawn_boss(i)
	# Wave-1 co-op fix: a guest entering an already-cleared boss arena must find
	# its gate OPEN. The gate-construction guard skips building a gate for a
	# satisfied edge; this reopens one that a boss_done arrival satisfied AFTER
	# the gate was built. Guest-only — the host opens gates through its own
	# kill/clear/flag triggers, so solo/host paths run no extra recheck here
	# (offline is bit-identical).
	if net_guest():
		_recheck_gates()
	last_room = i
	autosave()  # autosave on every room transition (DESIGN.md)

## HOST (empty-room fix 2026-07-10): a room only builds + spawns on its LOCAL
## player's entry, so a room a GUEST walked into FIRST would sit empty — the
## host never populated it, so MP-09 had nothing to mirror and the guest saw
## a rendered but lifeless room. The host already tracks every guest's room in
## active_rooms; here it builds + arms any it hasn't yet, so the enemies (and
## a boss) spawn host-side and stream out. Runs off the host's per-frame after
## _refresh_active_rooms. No-op solo and on guests (net_host gate).
func _host_ensure_active_rooms() -> void:
	if not net_host():
		return
	for r in active_rooms:
		var i := int(r)
		if i < 0 or i >= zone_count or built.get(i, false):
			continue
		_build_room(i)            # walls/scenery + _spawn_room_enemies (host spawns)
		_try_spawn_boss(i, true)  # arm a boss room a guest reached ahead of the
		                          # host (force: ignore the host's cur_room guard)
	# Wave-1 co-op fix: a room freshly built here for an already-cleared boss
	# leaves its gate open via the construction guard; this reopens any that a
	# late boss_done arrival satisfied after the gate was built. Host-only path.
	_recheck_gates()

## Leaving a room calms whatever you didn't kill: its pack forgets you and
## returns to post, so re-entry reads clean instead of a cluster still
## camping the doorway. You only ever leave a LIVE room by dying or a
## scripted yank (recall is barred while sealed, the door-lock bars a walk-
## out) — death already de-aggros, this covers the rest. Re-entry wakes the
## pack fresh; killed-but-uncleared mobs respawn via _reset_room_enemies.
## Bosses and homeless spawns (zone_idx < 0) are left to death/reset.
func _calm_left_room(prev: int, now: int) -> void:
	if prev < 0 or prev == now:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying:
			continue
		if e.zone_idx == prev and (e.force_aggro or e.alerted):
			e.force_aggro = false
			e.alerted = false
			e.global_position = e.home

## Build a room's world nodes on first entry (rooms build lazily).
func _build_room(i: int) -> void:
	if built.get(i, false):
		return
	built[i] = true
	var zone: Dictionary = zones[i]
	var meta: Dictionary = rooms[i]
	var origin: Vector2 = meta["origin"]

	var terrain := Terrains.get_terrain(terrain_by_zone[i])
	var ground := Sprite2D.new()
	ground.texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H,
		i * 1000 + 7, meta["exits"].keys())
	ground.centered = false
	ground.position = origin
	ground.scale = Vector2(3, 3)
	ground.z_index = -10
	world.add_child(ground)
	zone_grounds[i] = ground
	_mark_roads(i)
	_spawn_patches(i)
	zone_scenery[i] = []
	_spawn_scenery(i)
	_build_room_walls(i)

	# Data-driven NPCs (content modules + Chapter 1 props/shrines):
	# {"sprite": "villager", "x": 500, "y": 330, "prompt": "E — Talk",
	#  "convo": "some_convo_id"}
	for npc_def in zone.get("npcs", []):
		# Conditional props: "req_wanderer" ties a prop to this run's
		# seeded wanderer rolls — e.g. the miller's hat only exists in
		# worlds that also rolled the boy who's missing it.
		if npc_def.has("req_wanderer") \
				and not _wanderer_rolled(String(npc_def["req_wanderer"])):
			continue
		# Placeholder NPCs (extracted art wired for review) only exist in the
		# dev launcher — a normal playthrough never sees them in the world.
		if npc_def.get("placeholder", false) and not dev_mode:
			continue
		# Action interactables (Crownfall hub): a portal or a civic desk whose
		# prompt fires a game action (enter a mode, open a menu) instead of a
		# conversation. Handled by _hub_action; no convo, no quest marker.
		if npc_def.has("action"):
			var act: String = npc_def["action"]
			var action_node := _make_npc(npc_def["sprite"],
				room_pos(i, npc_def["x"], npc_def["y"]),
				npc_def.get("prompt", "E — Use"), func() -> void:
					_hub_action(act), "")
			# A landmark can carry the whole visual while this node supplies only
			# its interaction hotspot and prompt (the three Crownfall portals).
			if npc_def.get("hidden", false):
				for child in action_node.get_children():
					if child is Sprite2D:
						child.visible = false
			# Capital service NPCs advertise their intro quests (rework §5).
			_mark_capital_npc(action_node, act)
			continue
		var convo_id: String = npc_def["convo"]
		var npc_node := _make_npc(npc_def["sprite"],
			room_pos(i, npc_def["x"], npc_def["y"]),
			npc_def.get("prompt", "E — Talk"), func() -> void:
				run_convo_id(convo_id), convo_id)
		_mark_quest_giver(npc_node, convo_id)

	# Elder Maren, the Chapter 1 quest giver in the village.
	if chapter_id == "ch1" and i == 0:
		elder = _make_npc("elder", origin + Vector2(660, 500), "E — Talk", func() -> void:
			if not talked_to_elder:
				talked_to_elder = true
				var after := func() -> void:
					set_flag("met_elder")  # unbars the village's east gate
					quest_key = "fangmaw"
					refresh_quest()
					autosave()
				if get_flag("opened_" + player.cls, false) and Story.ALL_CONVOS.has("maren_" + player.cls):
					run_convo_id("maren_" + player.cls, after)  # she read your opening choice
				else:
					hud.dialogue(Story.ALL_BEATS["elder"], after)
			else:
				hud.dialogue(Story.ALL_BEATS["elder_repeat"])
		)

	# Merchants: SAFE rooms with a merchant spot keep one from the start
	# (or one who already wandered in, restored from the save). Combat
	# rooms only get theirs through the post-clear arrival roll.
	# Capital rework (2026-07-25 §3): campaign chapters no longer OPEN with a
	# shop — the start room's static merchant is gone (provision in Crownfall
	# first). Mid-chapter safe camps and wander-in arrivals stay, at road
	# prices (game_base.shop_markup). Standalones (capital/arenas) unaffected.
	if merchant_zones.has(i):
		_merchant_node(i)
	elif zone.has("merchant") and String(zone.get("boss", "")) == "" \
			and zone.get("enemies", []).is_empty() \
			and not (i == 0 and Story.CHAPTER_LIST.has(chapter_id)):
		_spawn_merchant(i)

	# Victory way-gates rebuild with the arena (rework §6): a save made after
	# the final boss fell still finds its road out on reload.
	var arena_boss := String(zone.get("boss", ""))
	if arena_boss != "" and arena_boss == String(Story.chapter(chapter_id).get("final_boss", "")) \
			and boss_done.get(arena_boss, false):
		spawn_victory_gates(i)

	# Room-type extras.
	var cache_tier := String(zone.get("cache", ""))
	if cache_tier != "" and not get_flag(_cache_flag(i), false):
		var cache_room := i
		var chest := Chest.drop(self, cache_tier, room_center(i) + Vector2(0, -140))
		chest.on_open = func() -> void:
			set_flag(_cache_flag(cache_room))  # once per character
			run_secrets += 1                   # results card: secrets found

	# Packs — skipped when the save already calls this room cleared.
	if not cleared.get(i, false):
		_spawn_room_enemies(i)
	else:
		zone_alive[i] = 0

	# Social rooms (after the pack pass, so zone_alive counts stick):
	# seeded per character, some hold a lone ELITE instead of a wanderer
	# — a miniboss beat between combat rooms (playtest round 6; later
	# chapters may spawn more than one). Once beaten, the room stays
	# quiet — a wanderer moves in on the next visit.
	if room_type(i) == "social":
		var erng := _social_rng(i)
		var elite_room := erng.randf() < Balance.ELITE_SOCIAL_ROOM_CHANCE * weekly_fx("elite")
		if elite_room and not cleared.get(i, false):
			_spawn_elite_room(i, erng)
		elif not elite_room or cleared.get(i, false):
			_spawn_wanderer(i)

	# Elective risk events (retention roadmap #4): seeded per character
	# like elites — a replay meets different temptations. Both are
	# walk-past-able; neither ever ambushes.
	_spawn_risk_events(i)

	# Hidden caches (exploration premium): some dead ends bury a chest
	# that only glints awake when the player wanders near.
	_spawn_hidden_cache(i)

func _spawn_room_enemies(i: int) -> void:
	zone_alive[i] = 0
	if net_guest():
		return  # MP-09: guests never spawn enemies — the host owns the sim
		        # and its net_session spawn events + ~20 Hz state stream
		        # build the mirrors this room shows.
	var spawned: Array = []
	# +15% density (presence pass 2026-07-07): seeded per room so a save
	# reloads the same pack. Each authored spawn has a MOB_DENSITY_EXTRA
	# chance to bring a jittered twin — never on boss arenas.
	var drng := RandomNumberGenerator.new()
	drng.seed = wander_seed * 41 + i * 613 + chapter_id.hash() % 7919
	var densify: bool = String(zones[i].get("boss", "")) == ""
	for spawn in zones[i].get("enemies", []):
		var lvl := int(spawn[4]) if spawn.size() > 4 else -1
		var pack := int(spawn[3]) if spawn.size() > 3 else 0
		# Optional 6th param: AUTHORED XP for this spawn. Cross-chapter ranged
		# IMPORTS (2026-07-09 distribution pass) ride reward_m off a LOW base
		# level, overpaying 3-4x vs the chapter natives they stand beside —
		# this pins them back onto the chapter's authored XP budget.
		var xp_override := int(spawn[5]) if spawn.size() > 5 else -1
		var count := 1
		if densify and drng.randf() < Balance.MOB_DENSITY_EXTRA:
			count = 2
		for c in count:
			var jit := Vector2.ZERO if c == 0 else Vector2(drng.randf_range(-70, 70), drng.randf_range(-60, 60))
			# NG+ tier lifts every AUTHORED spawn level (game_base.tiered_level).
			var e := Enemy.make(self, spawn[0], room_pos(i, spawn[1], spawn[2]) + jit, tiered_level(spawn[0], lvl))
			e.zone_idx = i
			e.pack_id = pack
			if xp_override >= 0:
				e.xp_value = xp_override
			zone_alive[i] = zone_alive.get(i, 0) + 1
			add_enemy(e)
			spawned.append(e)
	# Tether pairing (mob mechanic): link tether mobs two-by-two so their
	# bond burns the player and one dying full-heals the twin (kill both
	# together). Odd one out simply loses the trait (no partner).
	var teth: Array = []
	for s in spawned:
		if (s as Enemy).traits.has("tether"):
			teth.append(s)
	for pi in range(0, teth.size() - 1, 2):
		var a := teth[pi] as Enemy
		var b := teth[pi + 1] as Enemy
		a.tether_partner = b
		b.tether_partner = a
	if teth.size() % 2 == 1:
		(teth[-1] as Enemy).traits.erase("tether")
	# Elite ambush (playtest round 6): seeded per character+room, some
	# combat rooms promote one pack member to a miniboss. Boss rooms
	# are exempt — those arenas stay as authored.
	if not spawned.is_empty() and String(zones[i].get("boss", "")) == "":
		var rng := RandomNumberGenerator.new()
		rng.seed = wander_seed * 17 + i * 337 + chapter_id.hash() % 8837
		if rng.randf() < Balance.ELITE_COMBAT_AMBUSH_CHANCE * weekly_fx("elite"):
			spawned[rng.randi_range(0, spawned.size() - 1)].promote_elite()
	# An accepted curse outlives saves and death-resets: the flag re-arms
	# the pack's buff (and the payout) every time the room respawns.
	if get_flag(_curse_flag(i), false) and zone_alive.get(i, 0) > 0:
		curse_pending[i] = true
		_apply_room_curse(i)

## A lone elite holds a small side room. Kind and level ride the
## nearest earlier combat room, one level above its toughest spawn —
## a miniboss that always fits the local power band.
func _spawn_elite_room(i: int, rng: RandomNumberGenerator) -> void:
	if net_guest():
		return  # MP-09: enemies are host-side (mirrored via net_session)
	var kind := ""
	var lvl := 1
	for j in range(i - 1, -1, -1):
		var packs: Array = zones[j].get("enemies", [])
		if packs.is_empty():
			continue
		var pick: Array = packs[rng.randi_range(0, packs.size() - 1)]
		kind = String(pick[0])
		for s in packs:
			var sl := int(s[4]) if s.size() > 4 else int(Story.ALL_ENEMIES[s[0]]["level"])
			lvl = maxi(lvl, sl)
		break
	if kind == "":
		return
	var e := Enemy.make(self, kind, room_center(i) + Vector2(0, -60),
		tiered_level(kind, lvl + Balance.ELITE_ROOM_LEVEL_BONUS))
	e.zone_idx = i
	e.pack_id = 0
	e.promote_elite()
	# The lone room guardian watches its whole (small) arena; pack-
	# promoted elites keep pack aggro so doorways never wake a room.
	e.aggro_range *= Balance.ELITE_AGGRO_MULT
	zone_alive[i] = zone_alive.get(i, 0) + 1
	add_enemy(e)

## The room you died in resets: its surviving packs despawn and respawn
## fresh (and calm) for the retry.
func _reset_room_enemies(i: int) -> void:
	if not built.get(i, false):
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e.zone_idx == i and not (e is Boss):
			e.remove_from_group("enemies")
			e.queue_free()
	_spawn_room_enemies(i)

## One pack member noticed you: the whole pack answers (per-pack aggro —
## rooms are too big for all-at-once).
func wake_pack(room: int, pack: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and e.zone_idx == room and e.pack_id == pack \
				and not e.force_aggro:
			e.force_aggro = true
			if not e.alerted:
				e.alerted = true
				emote(e, "!", 0.9)


## Any living member of this pack still standing? (The just-dead enemy is
## already out of the "enemies" group when on_enemy_died runs, so an emptied
## pack reads false — the pack-cascade trigger.)
func _pack_alive(room: int, pack: int) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.dying and e.zone_idx == room and e.pack_id == pack:
			return true
	return false


## Wake the sleeping pack whose nearest member is closest to the player — the
## cascade after a wipe (game_flow.on_enemy_died). Same room only; packs
## already engaged are skipped. No-op if nothing's left to wake.
func _wake_nearest_pack(room: int) -> void:
	if not is_instance_valid(player):
		return
	var best_pack := -1
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dying or e.zone_idx != room or e.force_aggro or e.alerted:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best_pack = e.pack_id
	if best_pack >= 0:
		wake_pack(room, best_pack)

# ------------------------------------------------------- risk events ---

## Seeded elective risk (retention roadmap #4): a CURSED CHEST in some
## combat rooms — open it and the living pack grows crueler until the
## purge, THEN it pays (golden chest + gem) — and a GAMBLE SHRINE in
## some quiet rooms — feed it gold and it blesses or drinks deeper.
## Once per character per room; replays reroll with the seed.
## (The cursed chest moved to _offer_cursed_chest — playtest 2026-07-07:
## a chest that waits in the room forever gets claimed AFTER the pack
## dies, making the bargain free and the payout unreachable.)
func _spawn_risk_events(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 53 + i * 947 + chapter_id.hash() % 6659
	if room_type(i) in ["social", "dead_end"]:
		if rng.randf() < Balance.SHRINE_ROOM_CHANCE and not get_flag(_shrine_flag(i), false):
			_gamble_shrine_node(i, room_center(i)
				+ Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(-70.0, 70.0)))


## The cursed chest offers itself AT THE DOOR (playtest 2026-07-07): it
## materializes ahead of the player on their FIRST step into a blighted
## room and gives Balance.CURSE_OFFER_WINDOW seconds to decide, then
## withdraws. Accepting therefore always happens with the whole pack
## alive — no more clear-most-then-claim, and no more claiming after
## the purge already fired (which paid nothing). Same seeded roll as
## before, so the same rooms carry the bargain.
func _offer_cursed_chest(i: int) -> void:
	if room_type(i) != "combat" or String(zones[i].get("boss", "")) != "":
		return
	if get_flag(_curse_flag(i), false) or cleared.get(i, false) \
			or zone_alive.get(i, 0) <= 0 or not is_instance_valid(player):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 53 + i * 947 + chapter_id.hash() % 6659
	if rng.randf() >= Balance.CURSED_ROOM_CHANCE:
		return
	var toward: Vector2 = room_center(i) - player.global_position
	var dir := toward.normalized() if toward.length() > 1.0 else Vector2.RIGHT
	_cursed_chest_node(i, player.global_position + dir * 150.0)


## A buried chest in some dead ends (exploration premium): invisible
## until the player wanders within reach, then it glints awake. Only in
## dead ends WITHOUT an authored cache; once per character per room
## (flag wiped by replays, like caches). Counts as a secret.
func _spawn_hidden_cache(i: int) -> void:
	if room_type(i) != "dead_end" or String(zones[i].get("cache", "")) != "" \
			or get_flag(_hidden_flag(i), false):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed * 71 + i * 383 + chapter_id.hash() % 5581
	if rng.randf() >= Balance.HIDDEN_CACHE_CHANCE:
		return
	var room := i
	var tier := "gold" if rng.randf() < Balance.HIDDEN_CACHE_GOLD_TIER else "silver"
	var chest := Chest.drop(self, tier,
		room_center(i) + Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-130.0, 130.0)))
	chest.bury()
	chest.on_open = func() -> void:
		set_flag(_hidden_flag(room))
		run_secrets += 1  # results card: the wanderer's premium


## Drop an interactable from the prompt registry and the world.
func _remove_interactable(npc: Node2D) -> void:
	for it in interactables.duplicate():
		if it["node"] == npc:
			interactables.erase(it)
	npc.queue_free()


func _cursed_chest_node(i: int, pos: Vector2) -> void:
	var room := i
	var npc := _make_npc(String(Items.CHEST_TIERS["gold"]["sprite"]), pos,
		"E — The chest whispers", Callable())
	npc.modulate = Color(0.72, 0.5, 0.95)  # wrong-colored gold: clearly a bargain
	burst(pos, Color(0.7, 0.4, 1.0), 12)   # it ARRIVES — the window is open
	# Ten breaths to decide, then the bargain withdraws. The timer is a
	# CHILD of the chest: it pauses with the tree (menus don't eat the
	# window) and dies with the room (no lambda firing into a freed
	# world on chapter switches).
	var ticker := Timer.new()
	ticker.wait_time = Balance.CURSE_OFFER_WINDOW
	ticker.one_shot = true
	ticker.autostart = true
	npc.add_child(ticker)
	ticker.timeout.connect(func() -> void:
		if is_instance_valid(npc) and not get_flag(_curse_flag(room), false):
			burst(npc.global_position, Color(0.5, 0.3, 0.7), 10)
			sfx("gate", 0.7, 0.0, -6.0)
			_remove_interactable(npc))
	# The action needs the npc handle, so it's bound after creation.
	interactables[-1]["action"] = func() -> void:
		menus.open_confirm(
			"The chest whispers promises. Open it, and every monster in this room grows CRUELER (+%d%% damage, faster) until the room is purged — but the purge unlocks its hoard: a golden chest and a gem, guaranteed. Open it?"
				% int((Balance.CURSE_DMG_MULT - 1.0) * 100),
			func() -> void:
				set_flag(_curse_flag(room))
				curse_pending[room] = true
				_apply_room_curse(room)
				# Wave-1 co-op fix: the buff/tint lands only on the HOST's enemies,
				# but guests fight the SAME host-buffed pack — fan the visual so
				# their mirrors go violet and the party reads WHY it got crueler.
				if net_host():
					net_session().host_curse_applied(room)
				sfx("gate", 1.2)
				burst(npc.global_position, Color(0.7, 0.4, 1.0), 18)
				if is_instance_valid(player):
					spawn_text(player.global_position + Vector2(0, -78),
						"THE PACK STIRS, CRUELER — purge the room to claim the hoard",
						Color(0.85, 0.6, 1.0), 3.5)
				_remove_interactable(npc), func() -> void: pass)


## The accepted curse: every living pack member in the room hits harder
## and moves faster, wearing a violet cast so the bargain stays visible.
func _apply_room_curse(i: int) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e is Boss or e.dying or e.zone_idx != i:
			continue
		if e.has_meta("cursed"):
			continue  # rebuilds re-arm the curse; never double-buff
		e.set_meta("cursed", true)
		e.dmg *= Balance.CURSE_DMG_MULT
		e.speed *= Balance.CURSE_SPEED_MULT
		e.modulate = e.modulate * Color(0.85, 0.65, 1.1)


func _gamble_shrine_node(i: int, pos: Vector2) -> void:
	var room := i
	var npc := _make_npc("pillar", pos, "E — Feed the shrine", Callable())
	npc.modulate = Color(0.85, 0.75, 1.05)
	interactables[-1]["action"] = func() -> void:
		var cost := shrine_cost()
		if player.gold < cost:
			spawn_text(player.global_position + Vector2(0, -56),
				"The shrine wants %d gold." % cost, Color(0.8, 0.75, 0.9))
			return
		menus.open_confirm(
			"The shrine hums with a borrowed hunger. Feed it %d gold? It may bless the offering... or drink deeper." % cost,
			func() -> void:
				set_flag(_shrine_flag(room))
				player.gold -= cost
				_shrine_outcome(cost)
				_remove_interactable(npc), func() -> void: pass)


## The gamble resolves — a true roll (loot_rng), not seeded: blessings
## outnumber banes, but the banes bite. Never lethal by design.
func _shrine_outcome(cost: int) -> void:
	var pos: Vector2 = player.global_position
	if loot_rng.randf() < Balance.SHRINE_BLESS_CHANCE:
		sfx("nova", 1.1)
		burst(pos, Color(1.0, 0.9, 0.5), 16)
		var roll := loot_rng.randf()
		if roll < 0.4 and Balance.regular_gems_drop(loot_chapter()):
			var gem := drop_gem(
				2 if loot_rng.randf() < Balance.gem_lv2_chance(player.level) else 1)
			if give_loot({"kind": "gem", "gem": gem}, pos + Vector2(0, 44)):
				spawn_text(pos + Vector2(0, -70), "+ " + Items.gem_title(gem), Items.gem_color(gem))
		elif roll < 0.7:
			var back := cost * 3
			player.gain_gold(back)
			spawn_text(pos + Vector2(0, -70), "The shrine returns THREEFOLD (+%d gold)" % back,
				Color(1.0, 0.85, 0.4))
		elif roll < 0.9:
			Chest.drop(self, "silver", clamp_to_zone(pos + Vector2(70, 0), pos))
			spawn_text(pos + Vector2(0, -70), "A gift surfaces...", Color(0.85, 0.88, 0.95))
		else:
			give_loot({"kind": "stone", "stone": Items.make_elixir_might()}, pos + Vector2(0, 44))
			spawn_text(pos + Vector2(0, -70), "+ Elixir of Might", Color(1.0, 0.7, 0.4))
	else:
		sfx("hurt", 0.8)
		hud.flash_screen(Color(0.6, 0.2, 0.5), 0.25, 0.3)
		if loot_rng.randf() < 0.6:
			player.hp = maxf(1.0, player.hp - player.max_hp * 0.3)
			spawn_text(pos + Vector2(0, -70), "The shrine drinks your BLOOD", Color(0.9, 0.4, 0.5))
		else:
			var more := mini(cost, player.gold)
			player.gold -= more
			spawn_text(pos + Vector2(0, -70), "The shrine drinks DEEPER (−%d gold)" % more,
				Color(0.9, 0.5, 0.6))


## Social rooms roll ONE wanderer from the pool, seeded per character —
## a replay meets different people (DESIGN.md room palette).
func _spawn_wanderer(i: int) -> void:
	var pool: Array = Story.wanderers_for(chapter_id)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wander_seed + i * 131 + chapter_id.hash() % 9973
	var w: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var convo_id: String = w["convo"]
	var pos := room_center(i) + Vector2(rng.randf_range(-220.0, 220.0), rng.randf_range(-140.0, 140.0))
	var npc_node := _make_npc(w["sprite"], pos, w.get("prompt", "E — Talk"), func() -> void:
		run_convo_id(convo_id), convo_id)
	_mark_quest_giver(npc_node, convo_id)

## Hang a ❢ over an NPC who can still offer a side quest you haven't taken —
## the genre's "!" and the actual fix for walking past a giver and never
## learning the quest existed (the journal only ever tracked quests you'd
## already accepted). Silent if this convo offers nothing, or if the offer is
## already taken//paid, so the mark means exactly one thing: an unasked job.
## The node self-polls rather than snapshotting at spawn — the mark must clear
## the instant you say yes, and the NPC outlives the conversation.
func _mark_quest_giver(npc: Node2D, convo_id: String) -> void:
	var offered: Array = Story.quests_offered_by(convo_id)
	if offered.is_empty():
		return
	var mark := Label.new()
	mark.text = "❢"
	mark.position = Vector2(-40, -84)
	mark.size = Vector2(80, 22)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	mark.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	mark.add_theme_constant_override("outline_size", 5)
	npc.add_child(mark)
	# A slow bob so it reads as a marker, not scenery.
	var tw := mark.create_tween().set_loops()
	tw.tween_property(mark, "position:y", -90.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mark, "position:y", -84.0, 0.9).set_trans(Tween.TRANS_SINE)
	quest_marks.append({"node": mark, "quests": offered})
	refresh_quest_marks()  # a reloaded save may already hold this quest


## Re-read every ❢ against the flags. Cheap (a handful of marks, two flag
## lookups each), so it rides the same set_flag beat that accepts a quest.
func refresh_quest_marks() -> void:
	for mk in quest_marks.duplicate():
		var node: Label = mk["node"]
		if not is_instance_valid(node):
			quest_marks.erase(mk)
			continue
		# Capital service marks poll their own state machine (capital rework).
		if mk.has("cap"):
			node.visible = _cap_mark_active(String(mk["cap"]))
			continue
		var any := false
		for sqid in mk["quests"]:
			if side_quest_available(String(sqid)):
				any = true
				break
		node.visible = any


## Whether this run's seeded wanderer rolls put `convo_id` in SOME social
## room — mirrors _spawn_wanderer's roll exactly (same seed, same single
## randi call). Quest props declaring "req_wanderer" ride the same
## worlds their wanderer does.
func _wanderer_rolled(convo_id: String) -> bool:
	var pool: Array = Story.wanderers_for(chapter_id)
	if pool.is_empty():
		return false
	for i in zone_count:
		if room_type(i) != "social":
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = wander_seed + i * 131 + chapter_id.hash() % 9973
		var w: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		if String(w.get("convo", "")) == convo_id:
			return true
	return false

func _spawn_merchant(zi: int) -> void:
	if not zones[zi].has("merchant") or merchant_zones.has(zi):
		return
	merchant_zones.append(zi)
	if built.get(zi, false):
		_merchant_node(zi)

func _merchant_node(zi: int) -> void:
	var zone: Dictionary = zones[zi]
	if not zone.has("merchant"):
		return
	var pos := room_pos(zi, zone["merchant"][0], zone["merchant"][1])
	var zone_idx := zi
	_make_npc("merchant", pos, "E — Shop", func() -> void:
		menus.open_shop(zone_idx)
	)

## The post-boss arrival: a puff of travel dust and a sales pitch.
func _merchant_arrives(zi: int) -> void:
	if merchant_zones.has(zi) or not zones[zi].has("merchant"):
		return
	_spawn_merchant(zi)
	var pos := room_pos(zi, zones[zi]["merchant"][0], zones[zi]["merchant"][1])
	burst(pos, Color(0.9, 0.8, 0.5), 12)
	sfx("coin")
	spawn_text(pos + Vector2(0, -50), "A WANDERING MERCHANT ARRIVES!", Color(0.95, 0.85, 0.5))
	# Wave-1 co-op fix: the arrival roll is host-only (guests run no kill/clear
	# triggers), so fan it — guests spawn the same node + fanfare owner-side.
	# The guest's re-entry here no-ops the re-fan (net_host false) and can't
	# double the static safe-room merchant (merchant_zones/_spawn_merchant guard).
	if net_host():
		net_session().host_merchant_arrives(zi)

## Teleport to a visited safe room from the map screen. Walking through
## a LIVE room is content; re-walking a cleared one is not (DESIGN.md).
func fast_travel(i: int) -> void:
	# `downed` blocks too: bleed-out is a state you get carried out of, not one
	# you teleport out of (matches the §5.3 exclusions in game_flow's boss-heal
	# paths). GHOSTS stay free to travel — a bled-out spectator catching up with
	# the party is convenience, not combat power. Solo never sets either flag.
	if not travel_target(i) or state != ST_PLAYING or barrier_active \
			or hud.dialogue_active or player.dead or player.downed:
		return
	sfx("blink")
	burst(player.global_position, Color(0.7, 0.8, 1.0), 12)
	player.global_position = room_center(i)
	_enter_room(i)
	burst(player.global_position, Color(0.7, 0.8, 1.0), 12)

func _make_npc(sprite_name: String, pos: Vector2, prompt_text: String, action: Callable,
		profile_key := "", reach := 0.0) -> Node2D:
	# reach 0.0 = the standard person-to-person INTERACT_RANGE; prop hotspots
	# pass Balance.PROP_HOTSPOT_REACH so their prompts demand adjacency.
	var npc := Node2D.new()
	npc.position = pos
	# Live people use the lore-authored height profile in Balance. Everything
	# outside that roster (props and dev-only NPC gallery entries) retains this
	# stable hash fallback, so co-op never rolls a different footprint.
	var nsize: float = float(Balance.NPC_HEIGHT_BY_SPRITE.get(sprite_name, 0.0))
	if not profile_key.is_empty():
		nsize = float(Balance.NPC_HEIGHT_BY_CONVO.get(profile_key, nsize))
	if nsize <= 0.0:
		var nhash := absi((sprite_name + str(int(pos.x)) + str(int(pos.y))).hash())
		nsize = 1.0 + (float(nhash % 1000) / 1000.0 - 0.5) * 2.0 * Balance.NPC_SIZE_VAR
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(2, 2) * nsize
	shadow.position = Vector2(0, 20)
	npc.add_child(shadow)
	var spr := Sprite2D.new()
	var anim := Art.anim_info(sprite_name)
	# Directional idle art is optional. On interaction an eight-way NPC selects
	# the visitor-facing strip; a single-facing body mirrors horizontally.
	var dir_anims := Art.dir_set("%s_anim" % sprite_name)
	# Legacy interaction targets ride the global character scale; the humanoid
	# roster below instead uses alpha-body normalization and its authored height
	# profile, so a padded source export cannot make a citizen look child-sized.
	var render_scale: float = Balance.NPC_RENDER_SCALE * Balance.CHAR_RENDER_SCALE
	var body_target: float = float(Balance.NPC_BODY_TARGETS.get(sprite_name, 0.0))
	if anim.is_empty():
		spr.texture = Art.tex(sprite_name)
		if body_target > 0.0:
			var legacy_scale := Art.scale_for(spr.texture, render_scale * nsize)
			spr.scale = Art.scale_for_alpha_height(spr.texture,
				body_target * Balance.CHAR_RENDER_SCALE * nsize)
			spr.position.y = Art.alpha_feet_offset(spr.texture, legacy_scale.y) \
				- Art.alpha_feet_offset(spr.texture, spr.scale.y)
		else:
			spr.scale = Art.scale_for(spr.texture, render_scale * nsize)
	else:
		# NPCs breathe too (animation seam): slow frame flip on a tween,
		# random phase so a crowd never inhales in unison.
		spr.texture = anim["tex"]
		var frames := int(anim["frames"])
		spr.hframes = frames
		if body_target > 0.0:
			var legacy_scale := Art.scale_for(spr.texture, render_scale * nsize, frames)
			spr.scale = Art.scale_for_alpha_height(spr.texture,
				body_target * Balance.CHAR_RENDER_SCALE * nsize, frames)
			spr.position.y = Art.alpha_feet_offset(spr.texture, legacy_scale.y, frames) \
				- Art.alpha_feet_offset(spr.texture, spr.scale.y, frames)
		else:
			spr.scale = Art.scale_for(spr.texture, render_scale * nsize, frames)
		var tw := spr.create_tween().set_loops()
		tw.tween_interval(randf_range(0.1, 0.8))
		# Directional NPC idle strips can have a different number of frames than
		# the initial south-facing strip. Read hframes at playback time so changing
		# direction during an interaction keeps the new idle looping correctly.
		tw.tween_callback(func() -> void: spr.frame = (spr.frame + 1) % maxi(1, spr.hframes))
		tw.tween_interval(0.45)
	npc.add_child(spr)
	if sprite_name == "mill":
		# The mill's chimney breathes a thin smoke plume (visual pass) —
		# somebody still lives behind that blue door.
		var smoke := CPUParticles2D.new()
		smoke.amount = 10
		smoke.lifetime = 3.5
		smoke.preprocess = 3.5
		smoke.position = Vector2(8, -float(spr.texture.get_height()) * spr.scale.y * 0.5 - 4.0)
		smoke.direction = Vector2(0.25, -1)
		smoke.spread = 14.0
		smoke.gravity = Vector2(6, -16)
		smoke.initial_velocity_min = 8.0
		smoke.initial_velocity_max = 18.0
		smoke.scale_amount_min = 1.6
		smoke.scale_amount_max = 3.2
		smoke.color = Color(0.75, 0.74, 0.7, 0.35)
		npc.add_child(smoke)
	var prompt := Label.new()
	prompt.text = touchify(prompt_text)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	# The rect clamps UP to the text's width — a long prompt ("E — Feed the
	# shrine") anchored at a fixed left edge drifted right of the NPC. Size
	# first, then center the real rect on the authored +8 anchor.
	prompt.size = Vector2(96, 20)
	prompt.position = Vector2(8.0 - prompt.size.x * 0.5, -58)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.visible = false
	npc.add_child(prompt)
	world.add_child(npc)
	interactables.append({"node": npc, "prompt": prompt, "action": action,
		"reach": reach if reach > 0.0 else Balance.INTERACT_RANGE,
		"sprite": spr, "sprite_name": sprite_name, "dir_anims": dir_anims,
		"render_scale": render_scale,
		"size_var": nsize, "body_target": body_target,
		"faces_left": Art.faces_left(sprite_name),
		# Interaction-facing is presentation-only. Preserve the exact authored
		# rest pose so leaving a conversation or shop never leaves a citizen
		# rotated, rescaled, or vertically shifted.
		"rest_tex": spr.texture, "rest_frames": spr.hframes, "rest_frame": spr.frame,
		"rest_scale": spr.scale, "rest_pos": spr.position, "rest_flip_h": spr.flip_h})
	return npc

## Props that grow in natural CLUMPS (a stand of trees, a patch of mushrooms,
## a clutch of grass) rather than always standing alone. Rocks, pillars,
## sandstone, statues and every landmark stay solitary (they read as litter
## when clustered). Prefix-matched so tree_green2 / bush_autumn clump too.
func _groupable(name: String) -> bool:
	if name.begins_with("tree") or name.begins_with("bush") or name.begins_with("grass"):
		return true
	return name in ["mushroom", "mushroom_purple", "toadstool", "flower",
		"pebble", "cattail", "frost_reeds"]


## Living scenery shares one restrained wind language. The earlier pass only
## moved large trees plus two flower types, leaving reed beds and undergrowth
## frozen like cardboard beneath a moving canopy.
func _wind_scenery(name: String) -> bool:
	return name.contains("tree") or name.begins_with("bush") \
		or name.begins_with("grass") or name in [
			"mushroom", "mushroom_purple", "toadstool", "flower",
			"cattail", "frost_reeds"]


## Clump size with a DECAYING tail: starts at 2, each extra member only GROW
## as likely as the last (capped at MAX). Pairs/triples common, a dense stand
## of 4 rare, 5+ impossible — a natural distribution, not a flat 2..4 roll.
func _clump_size(rng: RandomNumberGenerator) -> int:
	var n := 2
	var grow := Balance.SCENERY_CLUSTER_GROW
	while n < Balance.SCENERY_CLUSTER_MAX and rng.randf() < grow:
		n += 1
		grow *= Balance.SCENERY_CLUSTER_GROW_DECAY
	return n


## (Re)build a room's decor + obstacles from its TERRAIN — tombstones in
## the graveyard, snowy pines on the ice, crystals in the caverns...
func _spawn_scenery(zi: int) -> void:
	for node in zone_scenery.get(zi, []):
		if is_instance_valid(node):
			node.queue_free()
	zone_scenery[zi] = []
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	# Gallery/unassigned terrains must preview as complete environments. If one
	# is painted onto Emberfall (or any authored story room), do not retain that
	# zone's cottages, civic landmark, furniture or scatter overrides over the
	# new biome. `preview_isolated` survives promotion out of placeholder status;
	# legacy placeholders remain isolated by their existing flag.
	var terrain_preview := bool(terrain.get("preview_isolated", false)) \
		or bool(terrain.get("placeholder", false))
	# Scenery is TERRAIN-keyed by default, but a ZONE may author its own
	# props — buildings / obstacles / decor / accents / obstacle_count on the
	# zone dict override the terrain. Without this, the one "village" terrain
	# paints Emberfall, the Outskirts and Maren's Camp identically (same five
	# cottages everywhere). Absent fields fall back to the terrain, so combat
	# zones just inherit their biome.
	var zone: Dictionary = zones[zi]
	var pr := play_rect(zi)
	var origin: Vector2 = pr.position
	var pw := pr.size.x
	var ph := pr.size.y
	var area_frac := (pw * ph) / float(ROOM_W * ROOM_H)
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 77 + terrain_by_zone[zi].hash() % 1000
	var placed: Array = []
	var reserved: Array = []
	var unique_props_seen := {}

	# Connected city-edge architecture gives the capital a skyline without
	# pretending that every background window is another shop. Backdrops sit
	# behind the existing perimeter walls, carry no collider, and leave their
	# authored central arch aligned with the room's real north road.
	var room_scale: float = float(zone.get("room_scale", 1.0))
	for backdrop in ([] if terrain_preview else zone.get("backdrops", [])):
		var backdrop_spec: Dictionary = backdrop
		var backdrop_name: String = String(backdrop_spec.get("name", ""))
		if backdrop_name.is_empty():
			continue
		var backdrop_world: Vector2 = room_pos(
			zi, float(backdrop_spec.get("x", ROOM_CENTER.x)),
			float(backdrop_spec.get("y", ROOM_CENTER.y)))
		var authored_width: float = float(backdrop_spec.get(
			"w", Balance.CAPITAL_BACKDROP_WIDTH_FALLBACK))
		zone_scenery[zi].append(
			_add_backdrop(backdrop_name, backdrop_world, authored_width * room_scale))

	# Authored LANDMARKS are the visual anchors of civic spaces. Unlike the
	# terrain's shuffled structures, these use exact room-local coordinates and
	# reserve enough breathing room that random clutter cannot pile against a
	# facade, fountain, gate, or ward monument.
	for landmark in ([] if terrain_preview else zone.get("landmarks", [])):
		var spec: Dictionary = landmark
		var landmark_name: String = String(spec.get("name", ""))
		if landmark_name.is_empty():
			continue
		# Landmark coordinates use the same full-cell authoring space as NPCs
		# and merchants.  Remap them through room_pos so an intentionally small
		# capital service room preserves its composition instead of pushing the
		# landmark beyond the inset walls.
		var landmark_world := room_pos(zi, float(spec.get("x", ROOM_CENTER.x)),
			float(spec.get("y", ROOM_CENTER.y)))
		var landmark_pos := landmark_world - origin
		placed.append(landmark_pos)
		reserved.append({"pos": landmark_pos,
			"radius": float(spec.get("clearance", 190.0))})
		var landmark_node := _add_structure(landmark_name, landmark_world)
		zone_scenery[zi].append(landmark_node)
		for unique_name in Terrains.structure_unique_props(landmark_name):
			unique_props_seen[String(unique_name)] = true
		# The structure's rendered height (base sprite meta) — the prompt
		# anchors ON the art, not at the invisible stand-point below it.
		var landmark_h: float = float(landmark_node.get_child(0).get_meta("hpx", 120.0))
		# Every foreground landmark owns typed interaction stations. Most are
		# real service actions; only true monuments/lookouts use inspect text.
		# Multiple stations may be spaced across one facade (the Archive).
		# STAND-POINTS DERIVE from the collider's south edge (owner 2026-07-25
		# round 3): the authored y offsets were tuned against the old oversized
		# colliders — once colliders hugged the art, a hero standing against it
		# fell OUTSIDE the trigger band. Derived = collider edge + a step back,
		# so adjacency always triggers; the authored x still spaces stations.
		var sdef: Dictionary = Terrains.STRUCTURES.get(landmark_name, {})
		var south_edge := 9.0   # the unlisted-def default base strip (-8 + 17)
		for scol in sdef.get("colliders", []):
			var sc2: Dictionary = scol
			var s_reach: float = float(sc2.get("radius", 0.0)) \
				if String(sc2.get("shape", "rect")) == "circle" \
				else (sc2.get("size", Vector2.ZERO) as Vector2).y * 0.5
			south_edge = maxf(south_edge, (sc2.get("off", Vector2.ZERO) as Vector2).y + s_reach)
		for landmark_use in spec.get("uses", []):
			var use_spec: Dictionary = landmark_use
			var use_dy: float = south_edge + Balance.PROP_HOTSPOT_STAND
			var use_pos := landmark_world + Vector2(
				float(use_spec.get("x", 0.0)), use_dy)
			var use_action := Callable()
			if String(use_spec.get("type", "")) == "action":
				use_action = Callable(self, "_hub_action").bind(
					String(use_spec.get("ref", "")))
			elif String(use_spec.get("type", "")) == "inspect":
				use_action = Callable(self, "_inspect_landmark").bind(
					String(use_spec.get("title", landmark_name)),
					String(use_spec.get("text", "")))
			else:
				push_warning("landmark %s has invalid interaction type" % landmark_name)
				continue
			# Prop hotspots demand adjacency (owner report 2026-07-25: the
			# fountain's prompt fired tiles away and floated below the art).
			var hotspot := _make_npc("book", use_pos,
				String(use_spec.get("prompt", "E — Use")), use_action, "",
				Balance.PROP_HOTSPOT_REACH)
			for child in hotspot.get_children():
				if child is Sprite2D:
					child.visible = false
				elif child is Label:
					# Lift the prompt from the stand-point up onto the landmark
					# itself — mid-height over THIS station's x, so the Archive's
					# three desks still label their own doors.
					child.position.y = -(use_dy + landmark_h * Balance.PROP_PROMPT_HEIGHT)
			zone_scenery[zi].append(hotspot)

	# Capital furniture is placed deliberately, not scattered. This prevents
	# generic benches from clipping the inset walls or reading as fence scraps.
	for furnishing in ([] if terrain_preview else zone.get("furnishings", [])):
		var furnish_spec: Dictionary = furnishing
		var furnish_world := room_pos(zi, float(furnish_spec.get("x", ROOM_CENTER.x)),
			float(furnish_spec.get("y", ROOM_CENTER.y)))
		var furnish_pos := furnish_world - origin
		placed.append(furnish_pos)
		reserved.append({"pos": furnish_pos,
			"radius": float(furnish_spec.get("clearance", 0.0))})
		zone_scenery[zi].append(
			_add_structure(String(furnish_spec.get("name", "")), furnish_world))

	# Per-room density jitter: not every room is equally dense (see Balance).
	var dens := rng.randf_range(Balance.SCENERY_DENSITY_JITTER.x, Balance.SCENERY_DENSITY_JITTER.y)

	# Non-colliding ground decor (density scaled to the room's area —
	# small rooms get proportionally less).
	var decor_list: Array = terrain.get("decor", ["pebble"]) if terrain_preview \
		else zone.get("decor", terrain.get("decor", ["pebble"]))
	var decor_target := int(ceil(Balance.SCENERY_DECOR_BASE * area_frac * dens)) \
		if terrain_preview else int(zone.get("decor_count",
			ceil(Balance.SCENERY_DECOR_BASE * area_frac * dens)))
	if decor_list.is_empty():
		decor_target = 0
	var decor_n := 0
	var decor_guard := 0
	while decor_n < decor_target and decor_guard < maxi(8, decor_target * 5):
		decor_guard += 1
		var decor_name: String = decor_list[rng.randi_range(0, decor_list.size() - 1)]
		# Groupable decor (mushrooms, grass, flowers) sometimes grows in a patch.
		var dclump := 1
		if _groupable(decor_name) and rng.randf() < Balance.SCENERY_CLUSTER_CHANCE:
			dclump = _clump_size(rng)
		var dcenter := origin + Vector2(rng.randf_range(70.0, pw - 70.0), rng.randf_range(80.0, ph - 80.0))
		var decor_blocked := false
		for reservation in reserved:
			var reserve: Dictionary = reservation
			if (dcenter - origin).distance_to(reserve["pos"]) < float(reserve["radius"]):
				decor_blocked = true
				break
		if decor_blocked:
			continue
		for k in dclump:
			var dpos := dcenter
			if k > 0:
				dpos = dcenter + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Balance.SCENERY_CLUSTER_RADIUS
				dpos.x = clampf(dpos.x, origin.x + 70.0, origin.x + pw - 70.0)
				dpos.y = clampf(dpos.y, origin.y + 80.0, origin.y + ph - 80.0)
			var decor_base := Terrains.prop_base(decor_name)
			var decor_visual := Terrains.prop_variant(
				decor_name, int(dpos.x * 31.0 + dpos.y * 17.0))
			var spr := _prop_visual(decor_visual)  # animates if a _anim strip ships
			var decor_scale: float = _scenery_render_scale(
				spr, decor_base,
				rng.randf_range(Balance.SCENERY_SCALE_JITTER.x, Balance.SCENERY_SCALE_JITTER.y))
			spr.scale = Vector2(decor_scale, decor_scale)
			spr.position = dpos
			if Balance.SCENERY_RENDER_WIDTH.has(decor_base):
				# Generated ground details are tight-cropped. Plant their
				# painted roots at the scatter point instead of centering them.
				spr.position.y -= _visual_size(spr).y * decor_scale * 0.5 - 5.0
			spr.z_index = -8
			_apply_scenery_variation(spr, decor_base, dpos)
			if _wind_scenery(decor_base):
				spr.material = Art.wind_material()
			world.add_child(spr)
			zone_scenery[zi].append(spr)
		decor_n += dclump

	# Colliding obstacles, kept off the road band and the door lanes.
	var obstacles: Array = terrain.get("obstacles", ["rock"]) if terrain_preview \
		else zone.get("obstacles", terrain.get("obstacles", ["rock"]))
	var max_x := pw - 760.0 if zones[zi].get("boss", "") != "" else pw - 90.0

	# Buildings first (visual pass): AUTHORED landmarks a zone opts into —
	# Emberfall's cottages + stall, Maren's camp kit — not terrain scatter.
	# Seeded like everything else; obstacles keep clear of them.
	var preview_buildings: Array = terrain.get("buildings", []) if terrain_preview \
		else zone.get("buildings", terrain.get("buildings", []))
	for bname in preview_buildings:
		for attempt in 60:
			var bpos := Vector2(rng.randf_range(200.0, max_x - 160.0), rng.randf_range(170.0, ph - 180.0))
			if absf(bpos.y - ph / 2.0) < 160.0 or absf(bpos.x - pw / 2.0) < 190.0:
				continue  # the road and door lanes stay open
			var bok := true
			for other in placed:
				if bpos.distance_to(other) < 260.0:
					bok = false
					break
			if bok:
				placed.append(bpos)
				zone_scenery[zi].append(_add_building(String(bname), origin + bpos))
				break

	# LANDMARK: select exactly ONE candidate from the terrain roster. Ecology,
	# terrain structures and zone additions are candidates, not an additive
	# checklist; the family pool fills every procedural terrain to >=5 kinds.
	# The selected composition is seeded, clear of road/door lanes, and claims
	# its signature sprites so accents/props cannot echo it elsewhere.
	var zone_structures: Array = [] if terrain_preview else zone.get("structures", [])
	var landmark_roster := Terrains.landmark_candidates(
		terrain_by_zone[zi], zone_structures)
	if Terrains.uses_procedural_taxonomy(terrain_by_zone[zi]) and not landmark_roster.is_empty():
		var landmark_occurrence := 0
		for previous_zi in zi:
			if terrain_by_zone[previous_zi] == terrain_by_zone[zi]:
				landmark_occurrence += 1
		var sname := Terrains.landmark_for_occurrence(
			terrain_by_zone[zi], landmark_roster, landmark_occurrence)
		for attempt in 60:
			var spos := Vector2(rng.randf_range(200.0, max_x - 160.0), rng.randf_range(170.0, ph - 180.0))
			if absf(spos.y - ph / 2.0) < 160.0 or absf(spos.x - pw / 2.0) < 190.0:
				continue  # keep the road and door lanes open
			var sok := true
			for other in placed:
				if spos.distance_to(other) < 240.0:
					sok = false
					break
			if sok:
				placed.append(spos)
				var landmark_node := _add_structure(String(sname), origin + spos)
				landmark_node.set_meta("terrain_landmark", String(sname))
				zone_scenery[zi].append(landmark_node)
				for unique_name in Terrains.structure_unique_props(String(sname)):
					unique_props_seen[String(unique_name)] = true
				break

	var obstacle_count: int = int(terrain.get("count", 10)) if terrain_preview \
		else int(zone.get("obstacle_count", terrain.get("count", 10)))
	var count := int(ceil(float(obstacle_count) * Balance.SCENERY_OBSTACLE_MULT * area_frac * dens))
	var placed_n := 0
	var guard := 0
	while placed_n < count and guard < count * 3:
		guard += 1
		var prop: String = obstacles[rng.randi_range(0, obstacles.size() - 1)]
		var prop_base := Terrains.prop_base(prop)
		if Terrains.is_unique_prop(prop_base) and unique_props_seen.has(prop_base):
			continue
		# Groupable props (trees, bushes) sometimes form a STAND; rocks/pillars
		# stay solo. A clump's members count toward `count`, so density holds.
		var clump := 1
		if _groupable(prop) and rng.randf() < Balance.SCENERY_CLUSTER_CHANCE:
			clump = _clump_size(rng)
		# Find a clump CENTRE that clears existing props and the road/door lanes.
		var center := Vector2.ZERO
		var got := false
		for attempt in Balance.SCENERY_PLACE_TRIES:
			var pos := Vector2(rng.randf_range(90.0, max_x), rng.randf_range(100.0, ph - 100.0))
			if pos.y > ph / 2.0 - 90.0 and pos.y < ph / 2.0 + 90.0:
				continue  # the road / east-west door lane stays open
			if absf(pos.x - pw / 2.0) < 130.0:
				continue  # the north-south door lane stays open
			var ok := true
			for reservation in reserved:
				var reserve: Dictionary = reservation
				if pos.distance_to(reserve["pos"]) < float(reserve["radius"]):
					ok = false
					break
			for other in placed:
				if pos.distance_to(other) < Balance.SCENERY_MIN_SPACING:
					ok = false
					break
			if ok:
				center = pos
				got = true
				break
		if not got:
			placed_n += 1  # couldn't fit this one; don't spin forever
			continue
		# Place the clump: centre first, then members on a tighter intra-clump
		# spacing so a stand reads dense without canopies overlapping.
		var intra := Balance.SCENERY_MIN_SPACING * 0.55
		for k in clump:
			var mpos := center
			if k > 0:
				mpos = center + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Balance.SCENERY_CLUSTER_RADIUS
				mpos.x = clampf(mpos.x, 90.0, max_x)
				mpos.y = clampf(mpos.y, 100.0, ph - 100.0)
				if mpos.y > ph / 2.0 - 90.0 and mpos.y < ph / 2.0 + 90.0:
					continue
				if absf(mpos.x - pw / 2.0) < 130.0:
					continue
				var okc := true
				for other in placed:
					if mpos.distance_to(other) < intra:
						okc = false
						break
				if not okc:
					continue
			placed.append(mpos)
			zone_scenery[zi].append(_add_obstacle(
				prop, origin + mpos,
				rng.randf_range(Balance.SCENERY_SCALE_JITTER.x, Balance.SCENERY_SCALE_JITTER.y)))
			if Terrains.is_unique_prop(prop_base):
				unique_props_seen[prop_base] = true
			placed_n += 1

	# ACCENTS: distinct, non-landmark features placed as ONE local group per
	# kind. Each kind owns a normalized bell curve: peak 3 makes three crystals
	# or giant fungi common and both smaller/larger groups progressively rarer;
	# peak 1 makes a second coffin/sign uncommon. Multiple accent kinds may
	# coexist. Props above remain the freely repeatable scatter tier.
	var raw_accents: Array = terrain.get("accents", []) if terrain_preview \
		else zone.get("accents", terrain.get("accents", []))
	for accent_spec in Terrains.accent_specs(terrain_by_zone[zi], raw_accents):
		var spec: Dictionary = accent_spec
		var aname := String(spec["name"])
		var ap := minf(Balance.SCENERY_ACCENT_CHANCE_CAP,
			float(spec.get("chance", Balance.SCENERY_ACCENT_CHANCE)) * area_frac * dens)
		if rng.randf() >= ap:
			continue
		var group_count := Terrains.sample_accent_count(spec, rng)
		var group_radius := float(spec.get("radius", Balance.SCENERY_ACCENT_GROUP_RADIUS))
		for attempt in Balance.SCENERY_PLACE_TRIES:
			var acenter := Vector2(rng.randf_range(90.0, max_x), rng.randf_range(100.0, ph - 100.0))
			if acenter.y > ph / 2.0 - 90.0 and acenter.y < ph / 2.0 + 90.0:
				continue
			if absf(acenter.x - pw / 2.0) < 130.0:
				continue
			var aok := true
			for other in placed:
				if acenter.distance_to(other) < Balance.SCENERY_MIN_SPACING:
					aok = false
					break
			if not aok:
				continue
			var group_positions: Array = []
			for member_idx in group_count:
				var apos := acenter
				if member_idx > 0:
					var member_found := false
					for member_try in Balance.SCENERY_ACCENT_MEMBER_TRIES:
						var angle := rng.randf_range(0.0, TAU)
						var distance := group_radius * sqrt(rng.randf_range(0.18, 1.0))
						apos = acenter + Vector2.from_angle(angle) * distance
						apos.x = clampf(apos.x, 90.0, max_x)
						apos.y = clampf(apos.y, 100.0, ph - 100.0)
						if apos.y > ph / 2.0 - 90.0 and apos.y < ph / 2.0 + 90.0:
							continue
						if absf(apos.x - pw / 2.0) < 130.0:
							continue
						var member_ok := true
						for other in placed:
							if apos.distance_to(other) < Balance.SCENERY_ACCENT_INTRA_SPACING:
								member_ok = false
								break
						for sibling in group_positions:
							if apos.distance_to(sibling) < Balance.SCENERY_ACCENT_INTRA_SPACING:
								member_ok = false
								break
						if member_ok:
							member_found = true
							break
					if not member_found:
						continue
				group_positions.append(apos)
				placed.append(apos)
				zone_scenery[zi].append(_add_obstacle(
					aname, origin + apos,
					rng.randf_range(Balance.SCENERY_SCALE_JITTER.x, Balance.SCENERY_SCALE_JITTER.y)))
			break

	# Ambient critters (birds/crows/butterflies) live with the scenery:
	# room rebuilds and terrain repaints sweep them up too.
	for critter in Ambience.populate(self, zi):
		zone_scenery[zi].append(critter)

	# ---- the river (the Greyrun and its cousins) ------------------
	# Terrain-configured, seeded per room; skips boss arenas. Wading
	# slows everyone; the bridge carries the road across dry.
	rivers.erase(zi)
	var river_cfg: Dictionary = terrain.get("river", {})
	if not river_cfg.is_empty() and String(zones[zi].get("boss", "")) == "":
		var rrng := RandomNumberGenerator.new()
		rrng.seed = zi * 131 + terrain_by_zone[zi].hash() % 100000
		if rrng.randf() < float(river_cfg.get("chance", 0.5)):
			# Keep the channel clear of the N/S door lane at room center.
			var fx_pos := rrng.randf_range(0.18, 0.40) if rrng.randf() < 0.5 \
				else rrng.randf_range(0.60, 0.82)
			var wpx := rrng.randf_range(120.0, 170.0)
			var rect := Rect2(origin.x + pw * fx_pos - wpx / 2.0, origin.y, wpx, ph)
			var bridge := Rect2(rect.position.x - 14.0, origin.y + ph / 2.0 - 84.0,
				wpx + 28.0, 168.0)
			var water := Sprite2D.new()
			water.texture = Art.tex("white")
			water.centered = false
			water.position = rect.position
			water.scale = rect.size / 8.0  # white tex is 8x8
			water.z_index = -9             # over the ground, under decor
			water.material = Art.water_material(river_cfg.get("color", Color(0.1, 0.2, 0.2, 0.8)))
			world.add_child(water)
			zone_scenery[zi].append(water)
			var plank := Sprite2D.new()
			plank.texture = Art.tex("bridge")
			plank.centered = false
			plank.position = bridge.position
			plank.scale = bridge.size / plank.texture.get_size()  # fit any-res bridge art to the span
			plank.z_index = -8
			world.add_child(plank)
			zone_scenery[zi].append(plank)
			rivers[zi] = {"rect": rect, "bridge": bridge}

## A building: base-anchored (y-sort lets the player walk behind the
## roof), footprint collider, chimney smoke on the cottages.
func _add_building(sprite_name: String, pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos  # the base line is the sort anchor
	body.collision_layer = 1
	body.collision_mask = 0
	var spr := _prop_visual(sprite_name)
	# Houses DWARF a person (2026-07-17): a cottage renders ~250px wide ->
	# ~180px tall, ~2x the 88px hero body — only bosses top a structure.
	# The stall is mid; the camp kit (bonfire/tripod/meat rack) is person-
	# scale. Normalized by texture width so an override PNG lands the same.
	var target_w := 150.0
	if sprite_name.begins_with("cottage"):
		target_w = 250.0
	elif sprite_name.begins_with("camp_"):
		target_w = 90.0
	var native_size := _visual_size(spr)
	var bscale := target_w / maxf(1.0, native_size.x)
	spr.scale = Vector2(bscale, bscale)
	# Seeded mirroring: half the houses face the other way (free variety).
	var mirrored := (int(pos.x) + int(pos.y)) % 2 == 1
	if spr is Sprite2D:
		(spr as Sprite2D).flip_h = mirrored
	elif spr is AnimatedSprite2D:
		(spr as AnimatedSprite2D).flip_h = mirrored
	var hpx := native_size.y * bscale
	var wpx := native_size.x * bscale
	spr.position = Vector2(0, -hpx * 0.5 + 12.0)
	spr.set_meta("occlusion_sort_y", pos.y)
	spr.set_meta("occlusion_radius", Vector2(wpx, hpx).length() * 0.5)
	spr.add_to_group("structure_occluders")
	body.add_child(spr)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(wpx * 0.62, 34.0)
	cs.position = Vector2(0, -8.0)
	cs.shape = shape
	body.add_child(cs)
	if sprite_name.begins_with("cottage") or sprite_name == "camp_bonfire":
		_attach_fire_audio(body)  # hearth / camp fire crackles as you pass
	if sprite_name.begins_with("cottage"):
		var smoke := CPUParticles2D.new()
		smoke.amount = 8
		smoke.lifetime = 3.5
		smoke.preprocess = 3.5
		# The chimney sits ~66% across the art; mirrored houses mirror it.
		smoke.position = Vector2(wpx * 0.16 * (-1.0 if mirrored else 1.0), -hpx + 8.0)
		smoke.direction = Vector2(0.25, -1)
		smoke.spread = 14.0
		smoke.gravity = Vector2(6, -16)
		smoke.initial_velocity_min = 8.0
		smoke.initial_velocity_max = 18.0
		smoke.scale_amount_min = 1.6
		smoke.scale_amount_max = 3.2
		smoke.color = Color(0.75, 0.74, 0.7, 0.35)
		body.add_child(smoke)
	world.add_child(body)
	return body


## Positional hearth / campfire crackle (first positional audio) — cottages
## and open camp fires both get it, so a flame you walk past sounds alive.
func _attach_fire_audio(body: Node2D) -> void:
	var fstream: AudioStream = game_stream("campfire")
	if not fstream:
		return
	var fire := AudioStreamPlayer2D.new()
	fire.stream = fstream
	fire.max_distance = 340.0
	fire.attenuation = 1.6
	fire.volume_db = -6.0
	fire.autoplay = true
	body.add_child(fire)


func _add_obstacle(sprite_name: String, pos: Vector2, visual_variation := 1.0) -> StaticBody2D:
	var family_base := Terrains.prop_base(sprite_name)
	var visual_name := Terrains.prop_variant(
		sprite_name, int(pos.x * 31.0 + pos.y * 17.0))
	var is_tree := family_base.contains("tree")
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = float(Balance.SCENERY_COLLIDER_RADIUS.get(
		family_base, 13.0 if is_tree else 11.0))
	cs.shape = shape
	cs.position = Vector2(0, 10)
	body.add_child(cs)
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(4, 2.4) if is_tree else Vector2(3, 2)
	shadow.position = Vector2(0, 38 if is_tree else 22)
	body.add_child(shadow)
	# Static Sprite2D, or a self-animating AnimatedSprite2D when the prop ships
	# a <name>_anim.png strip (Lane 3) — same 3x footprint either way.
	var spr := _prop_visual(visual_name)
	var visual_scale: float = _scenery_render_scale(spr, family_base, visual_variation)
	spr.scale = Vector2(visual_scale, visual_scale)
	if Balance.SCENERY_RENDER_WIDTH.has(family_base):
		var base_y := 38.0 if is_tree else 22.0
		spr.position = Vector2(
			0, base_y - _visual_size(spr).y * visual_scale * 0.5)
	elif is_tree:
		spr.position = Vector2(0, -18)  # trunk base sits at the body origin
	_apply_scenery_variation(spr, family_base, pos)
	if _wind_scenery(family_base):
		spr.material = Art.wind_material()
	# Scatter props y-sort over a hero north of their base exactly like
	# buildings do, so they join the same occlusion-outline group (2026-07-28:
	# the hero vanished outline-less behind trees/statues — only architecture
	# was tagged). The scaled half-diagonal lets the player's per-frame probe
	# skip far props before doing any transform math.
	spr.set_meta("occlusion_sort_y", pos.y)
	spr.set_meta("occlusion_radius", _visual_size(spr).length() * visual_scale * 0.5)
	spr.add_to_group("structure_occluders")
	body.add_child(spr)
	if sprite_name == "camp_bonfire":
		_attach_fire_audio(body)  # an open camp fire crackles like a hearth
	world.add_child(body)
	return body


## Seeded micro-variation supplements real silhouette families: mirror, a
## restrained natural lean and slight value drift. The same room rebuilds
## identically, while repeated plants and rocks stop reading as cloned stamps.
func _apply_scenery_variation(vis: Node2D, family_base: String, pos: Vector2) -> void:
	var h := absi(("%s_%d_%d" % [family_base, int(pos.x), int(pos.y)]).hash())
	if h % 2 == 1:
		vis.scale.x *= -1.0
	var lean_step := int(h / 2) % 7 - 3
	vis.rotation = float(lean_step) * 0.007
	var value := 0.94 + float(int(h / 14) % 9) * 0.015
	vis.modulate = Color(value, value, value, 1.0)


## The visual node for a scenery prop: a looping AnimatedSprite2D when the
## prop ships a <name>_anim.png strip (Lane 3), else a static Sprite2D. The
## caller owns scale / position / z / material — both node types are Node2D +
## CanvasItem, so every existing call still type-checks. This is the ONE seam
## every prop path (obstacles, decor, accents, structure parts) routes through.
func _prop_visual(name: String) -> Node2D:
	var vis: Node2D = Art.anim_prop(name)
	if vis == null:
		var spr := Sprite2D.new()
		spr.texture = Art.tex(name)
		vis = spr
	return vis


## The native (unscaled) pixel size of a prop visual, whether it's a static
## Sprite2D or an animated prop's first frame — so structures can width-
## normalize either kind.
func _visual_size(vis: Node2D) -> Vector2:
	if vis is Sprite2D and (vis as Sprite2D).texture != null:
		return (vis as Sprite2D).texture.get_size()
	if vis is AnimatedSprite2D:
		var sf: SpriteFrames = (vis as AnimatedSprite2D).sprite_frames
		if sf != null and sf.get_frame_count("default") > 0:
			var t := sf.get_frame_texture("default", 0)
			if t != null:
				return t.get_size()
	return Vector2(16, 16)


## World-space scale for scenery. Generated overrides use an authored rendered
## width; all other assets preserve the legacy 3x native-pixel contract.
func _scenery_render_scale(vis: Node2D, name: String, variation := 1.0) -> float:
	var native := _visual_size(vis)
	var authored_w: float = float(Balance.SCENERY_RENDER_WIDTH.get(
		name, native.x * 3.0))
	return authored_w * variation / maxf(1.0, native.x)


## One width-normalized part of a composite structure (Lane 2). Returns the
## visual (static or animated) scaled so it renders `target_w` px wide, with
## its scaled w/h stashed as meta so the caller can anchor + place decals.
func _structure_sprite(name: String, target_w: float, wind: bool) -> Node2D:
	var vis := _prop_visual(name)
	var native := _visual_size(vis)
	var s := target_w / maxf(1.0, native.x)
	vis.scale = Vector2(s, s)
	if wind:
		vis.material = Art.wind_material()
	vis.set_meta("wpx", native.x * s)
	vis.set_meta("hpx", native.y * s)
	return vis


## A non-colliding city-edge layer. Unlike _add_structure this intentionally
## renders only one coherent architectural silhouette: no default footprint,
## no fire audio, and no service affordance. Room walls remain the authoritative
## physical boundary, so the central painted arch can frame a real door lane
## without introducing an invisible blocker.
## Cached bottom padding (SOURCE px) of structure art. Padded exports used
## to render their visual base above the y-sort anchor — every consumer
## shifts its art down by this so pixels, collision, and sort agree.
static var _pad_cache := {}

func _art_pad_bottom(tex: Texture2D, key: String) -> int:
	if _pad_cache.has(key):
		return int(_pad_cache[key])
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var iw := img.get_width()
	var ih := img.get_height()
	var pad := 0
	for y in range(ih - 1, -1, -1):
		var found := false
		for x in range(0, iw, 2):
			if img.get_pixel(x, y).a > 0.08:
				found = true
				break
		if found:
			pad = ih - 1 - y
			break
	_pad_cache[key] = pad
	return pad


func _add_backdrop(name: String, pos: Vector2, target_w: float) -> Node2D:
	var def: Dictionary = Terrains.STRUCTURES.get(name, {})
	var layer := Node2D.new()
	layer.position = pos
	layer.z_index = Balance.CAPITAL_BACKDROP_Z
	var visual: Node2D = _structure_sprite(
		String(def.get("sprite", name)), target_w, false)
	var height: float = float(visual.get_meta("hpx"))
	visual.position = Vector2(
		float(def.get("visual_x", 0.0)), -height * 0.5 + 12.0)
	var bprobe: Texture2D = Art.tex(String(def.get("sprite", name)))
	if bprobe != null:
		visual.position.y += float(_art_pad_bottom(bprobe, String(def.get("sprite", name)))) \
			* (height / maxf(1.0, float(bprobe.get_height())))
	visual.set_meta("occlusion_sort_y", pos.y)
	visual.add_to_group("structure_occluders")
	layer.add_child(visual)
	# The silhouette's authored base strip (owner report 2026-07-25): the
	# room walls were supposed to own this edge but don't reach it — without
	# a body the hero strolls INTO the city-edge art. Scaled to the render
	# width like the sprite itself.
	var bscale: float = float(visual.get_meta("wpx")) / maxf(1.0, float(def.get("w", target_w)))
	var bdef: Array = def.get("colliders", [])
	if not bdef.is_empty():
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		for c in bdef:
			var cshape := CollisionShape2D.new()
			cshape.position = (c.get("off", Vector2.ZERO) as Vector2) * bscale
			if String(c.get("shape", "rect")) == "circle":
				var circ := CircleShape2D.new()
				circ.radius = float(c.get("radius", 12.0)) * bscale
				cshape.shape = circ
			else:
				var rect := RectangleShape2D.new()
				rect.size = (c.get("size", Vector2(60, 26)) as Vector2) * bscale
				cshape.shape = rect
			body.add_child(cshape)
		layer.add_child(body)
	world.add_child(layer)
	return layer


## A composite STRUCTURE (Lane 2 unlock): several sprites y-sorted as ONE
## base-anchored body, a MULTI-shape footprint collider (an L-ruin or a gate
## needs more than one circle), and non-colliding WALL DECALS (banners,
## torches, moss) that can themselves animate and carry a point light. Driven
## by Terrains.STRUCTURES; an unlisted name degrades to a single base-anchored
## sprite with a footprint rect (like _add_building), so a zone can reference
## pack art before a full def is authored. Contrast _add_obstacle: one sprite,
## one circle.
func _add_structure(name: String, pos: Vector2) -> StaticBody2D:
	var def: Dictionary = Terrains.STRUCTURES.get(name, {})
	var body := StaticBody2D.new()
	body.position = pos  # the base line is the y-sort anchor
	body.collision_layer = 1
	body.collision_mask = 0

	# Base sprite (the structure's main art), width-normalized like a building
	# so any-res override art lands the same on-screen size. SELF-ALIGNED
	# (owner 2026-07-25 round 4): padded exports drew their visual base above
	# the anchor, so a hero standing in the gap y-sorted BEHIND the art (head
	# under the masonry). The measured bottom padding shifts the art down so
	# its lowest opaque row always sits at the +12 grounding line tight-
	# cropped art already had — y-sort, collider, and pixels finally agree.
	var base_spr := _structure_sprite(String(def.get("sprite", name)),
		float(def.get("w", 180.0)), def.get("wind", false))
	var bw: float = base_spr.get_meta("wpx")
	var bh: float = base_spr.get_meta("hpx")
	base_spr.flip_h = def.get("mirror", false) and (int(pos.x) + int(pos.y)) % 2 == 1
	# A one-time horizontal crop offset preserves the exact old art centre for
	# sources whose removed left/right margins were asymmetric.
	base_spr.position = Vector2(
		float(def.get("visual_x", 0.0)), -bh * 0.5 + 12.0)
	var probe_tex: Texture2D = Art.tex(String(def.get("sprite", name)))
	if probe_tex != null:
		base_spr.position.y += float(_art_pad_bottom(probe_tex, String(def.get("sprite", name)))) \
			* (bh / maxf(1.0, float(probe_tex.get_height())))
	base_spr.set_meta("occlusion_sort_y", pos.y)
	base_spr.set_meta("occlusion_radius", Vector2(bw, bh).length() * 0.5)
	base_spr.add_to_group("structure_occluders")
	body.add_child(base_spr)
	var target_w: float = float(def.get("w", 180.0))

	# Extra composited parts (a tower beside a gate, a roof over a wall). Each
	# is a fraction of the base width, offset in world px from the anchor.
	for part in def.get("parts", []):
		var ps := _structure_sprite(String(part["sprite"]),
			target_w * float(part.get("scale", 1.0)), part.get("wind", false))
		ps.position = part.get("off", Vector2.ZERO)
		ps.z_index = int(part.get("z", 0))
		# Sunken parts (z<0) render beneath the hero and can never hide them;
		# every other part covers like the base sprite, so it probes too.
		if ps.z_index >= 0:
			ps.set_meta("occlusion_sort_y", pos.y)
			ps.set_meta("occlusion_radius", Vector2(float(ps.get_meta("wpx")),
				float(ps.get_meta("hpx"))).length() * 0.5)
			ps.add_to_group("structure_occluders")
		body.add_child(ps)

	# Footprint collider(s): a composite of rects/circles. Default = one rect
	# spanning ~62% of the base width, matching _add_building.
	var colliders: Array = def.get("colliders",
		[{"shape": "rect", "size": Vector2(bw * 0.62, 34.0), "off": Vector2(0, -8.0)}])
	for c in colliders:
		var cshape := CollisionShape2D.new()
		cshape.position = c.get("off", Vector2.ZERO)
		if String(c.get("shape", "rect")) == "circle":
			var circ := CircleShape2D.new()
			circ.radius = float(c.get("radius", 12.0))
			cshape.shape = circ
		else:
			var rect := RectangleShape2D.new()
			rect.size = c.get("size", Vector2(bw * 0.62, 34.0))
			cshape.shape = rect
		body.add_child(cshape)

	# Wall decals: non-colliding overlays (banners, torches, moss). A decal can
	# animate (Lane 3) and can carry a point light — a torch's glow.
	for d in def.get("decals", []):
		var ds := _structure_sprite(String(d["sprite"]),
			target_w * float(d.get("scale", 0.2)), d.get("wind", false))
		ds.position = d.get("off", Vector2.ZERO)
		ds.z_index = int(d.get("z", 1))
		body.add_child(ds)
		var lcol: Variant = d.get("light")
		if lcol is Color:
			var lt := PointLight2D.new()
			lt.texture = Art.tex("light")
			lt.color = lcol
			# Scale by the terrain's light budget (Track A doctrine): an unscaled
			# additive torch glow blooms a daylight scene to white. Scenery
			# rebuilds on terrain change, so this re-reads a fresh light_mult.
			lt.energy = float(d.get("light_energy", 0.8)) * light_mult
			lt.texture_scale = float(d.get("light_scale", 0.7))
			lt.position = d.get("off", Vector2.ZERO)
			body.add_child(lt)

	# Pure light sockets preserve a structure's authored illumination without
	# requiring a second animated sprite to be pasted over its full-object
	# animation strip.
	for light in def.get("lights", []):
		var lt := PointLight2D.new()
		lt.texture = Art.tex("light")
		lt.color = light.get("color", Color.WHITE)
		lt.energy = float(light.get("energy", 0.8)) * light_mult
		lt.texture_scale = float(light.get("scale", 0.7))
		lt.position = light.get("off", Vector2.ZERO)
		body.add_child(lt)

	if def.get("fire", false):
		_attach_fire_audio(body)  # a lit structure crackles as you pass
	world.add_child(body)
	return body

## A wall segment: collider + tiled wall visual. `wall_tex` is the terrain's
## seamless 16px wall tile (Terrains.wall_for); defaults to the stone block.
func _wall(rect: Rect2, wall_tex := "wallblock") -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	body.add_child(cs)
	# Walls block LIGHT too (visual pass): the player's halo throws real
	# shadows in dark terrains. Additive lights make this free-subtle in
	# daylight (light_mult ~0 there anyway).
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var hx := rect.size.x / 2.0
	var hy := rect.size.y / 2.0
	poly.polygon = PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy),
		Vector2(hx, hy), Vector2(-hx, hy)])
	occ.occluder = poly
	body.add_child(occ)
	world.add_child(body)
	var spr := Sprite2D.new()
	spr.texture = Art.tex(wall_tex)
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.region_enabled = true
	spr.region_rect = Rect2(Vector2.ZERO, rect.size / 3.0)
	spr.centered = false
	spr.position = rect.position
	spr.scale = Vector2(3, 3)
	spr.z_index = -5
	world.add_child(spr)
	_wall_sink.append(spr)  # tracked so a terrain repaint can retexture it live

## Perimeter walls for one room, with door gaps on its open edges, and
## a gate body on any locked edge that isn't already satisfied.
## Small rooms build their walls at the inset playable rect and add
## short corridor walls from each doorway out to the cell edge.
func _build_room_walls(i: int) -> void:
	var r := play_rect(i)
	var full := room_rect(i)
	var ins := room_inset(i)
	var exits: Dictionary = rooms[i]["exits"]
	var gap := DOOR_TILES * TILE
	# Terrain-aware wall tile (2026-07-08): stone keep, wood village, mossy
	# forest/marsh, volcanic magma, ice, graveyard, sandstone — else stone.
	# Track the wall sprites so apply_terrain can retexture them live.
	var wt: String = Terrains.wall_for(terrain_by_zone[i])
	zone_wall_sprites[i] = []
	_wall_sink = zone_wall_sprites[i]
	# North/south walls (gap centered on x).
	for spec in [["N", r.position.y], ["S", r.end.y - TILE]]:
		var dir: String = spec[0]
		var y: float = spec[1]
		if exits.has(dir):
			var half := r.size.x / 2.0 - gap / 2.0
			_wall(Rect2(r.position.x, y, half, TILE), wt)
			_wall(Rect2(r.position.x + r.size.x / 2.0 + gap / 2.0, y, half, TILE), wt)
			_door_torches(door_pos(i, dir), false)
			if ins.y > 0.0:
				var cx := full.position.x + ROOM_W / 2.0
				var cy := full.position.y if dir == "N" else r.end.y
				_wall(Rect2(cx - gap / 2.0 - TILE, cy, TILE, ins.y), wt)
				_wall(Rect2(cx + gap / 2.0, cy, TILE, ins.y), wt)
		else:
			_wall(Rect2(r.position.x, y, r.size.x, TILE), wt)
	# West/east walls (gap centered on y).
	for spec in [["W", r.position.x], ["E", r.end.x - TILE]]:
		var dir: String = spec[0]
		var x: float = spec[1]
		if exits.has(dir):
			var half := r.size.y / 2.0 - gap / 2.0
			_wall(Rect2(x, r.position.y, TILE, half), wt)
			_wall(Rect2(x, r.position.y + r.size.y / 2.0 + gap / 2.0, TILE, half), wt)
			_door_torches(door_pos(i, dir), true)
			if ins.x > 0.0:
				var cy2 := full.position.y + ROOM_H / 2.0
				var cx2 := full.position.x if dir == "W" else r.end.x
				_wall(Rect2(cx2, cy2 - gap / 2.0 - TILE, ins.x, TILE), wt)
				_wall(Rect2(cx2, cy2 + gap / 2.0, ins.x, TILE), wt)
		else:
			_wall(Rect2(x, r.position.y, TILE, r.size.y), wt)
	var wall_tint := Terrains.wall_tint_for(terrain_by_zone[i])
	for wall_sprite in zone_wall_sprites[i]:
		if is_instance_valid(wall_sprite):
			wall_sprite.modulate = wall_tint
	# Locked edges get a gate — built once per edge, by whichever room
	# builds first, and only while the lock is still unmet.
	for dir in exits.keys():
		var nb := neighbor(i, dir)
		if nb < 0:
			continue
		var key := _edge_key(i, nb)
		if edge_locks.has(key) and not gates.has(key) and not _edge_unlocked(i, nb):
			gates[key] = _build_gate(i, String(dir))

## Flickering torches flank each doorway.
func _door_torches(pos: Vector2, vertical: bool) -> void:
	var span := DOOR_TILES * TILE / 2.0 + 26.0
	for side in [-1, 1]:
		var off := Vector2(0, side * span) if vertical else Vector2(side * span, 0)
		var torch := Sprite2D.new()
		torch.texture = Art.tex("torch")
		torch.scale = Vector2(3, 3)
		torch.position = pos + off
		torch.z_index = 2
		world.add_child(torch)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.6, 0.2, 0.5)
		glow.position = torch.position + Vector2(0, -12)
		glow.scale = Vector2(2.5, 2.5)
		glow.z_index = 1
		world.add_child(glow)
		var tween := glow.create_tween()
		tween.set_loops()
		tween.tween_property(glow, "scale", Vector2(3.1, 3.1), 0.5 + randf() * 0.3)
		tween.tween_property(glow, "scale", Vector2(2.4, 2.4), 0.5 + randf() * 0.3)

## A gate barring the doorway on room i's `dir` edge.
func _build_gate(i: int, dir: String) -> Node2D:
	var vertical := dir in ["E", "W"]  # the barred passage runs east-west
	var gate := StaticBody2D.new()
	gate.position = door_pos(i, dir)
	gate.collision_layer = 1
	gate.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE * 2.2, DOOR_TILES * TILE) if vertical \
		else Vector2(DOOR_TILES * TILE, TILE * 2.2)
	cs.shape = shape
	gate.add_child(cs)
	for row in DOOR_TILES:
		var spr := Sprite2D.new()
		spr.texture = Art.tex("gate")
		spr.scale = Vector2(3, 3)
		var off := (row - 1) * TILE
		spr.position = Vector2(0, off) if vertical else Vector2(off, 0)
		gate.add_child(spr)
	world.add_child(gate)
	return gate

## Open a (possibly gated) edge between two rooms.
func open_edge(a: int, b: int) -> void:
	var key := _edge_key(a, b)
	if not gates.has(key):
		return
	var gate: Node2D = gates[key]
	gates.erase(key)
	if gate == null or not is_instance_valid(gate):
		return
	sfx("gate")
	gate.collision_layer = 0
	var tween := create_tween()
	tween.tween_property(gate, "modulate:a", 0.0, 0.8)
	tween.tween_callback(gate.queue_free)

## Legacy helper: open the gate on room zi's EAST edge (old strip rule).
func open_gate(zi: int) -> void:
	var nb := neighbor(zi, "E")
	if nb >= 0:
		open_edge(zi, nb)

## Battle seals: the 4 pooled door-blockers that close the current
## room's exits while a fight is live (rebuilt with the world).
func _build_door_seals() -> void:
	door_seals.clear()
	for i in 4:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(TILE * 1.4, DOOR_TILES * TILE + 24.0)
		cs.shape = shape
		body.add_child(cs)
		var glow := Sprite2D.new()
		glow.texture = Art.tex("glow")
		glow.modulate = Color(1.0, 0.25, 0.2, 0.55)
		glow.scale = Vector2(1.4, 3.6)
		glow.z_index = 4
		body.add_child(glow)
		# Visible GATE BARS at the door line (owner 2026-07-25): the seal body
		# parks a step OUTSIDE the room — beyond the camera clamp — so its red
		# glow alone was invisible from inside; the exit read as an unexplained
		# invisible block. The bars reuse the ch1 quest-gate look (rows of the
		# gate sprite), red-tinted so a battle seal reads different from a
		# story gate, offset back onto the door line where the camera can see.
		var bars := Node2D.new()
		var bar_sprites: Array = []
		for r in DOOR_TILES:
			var bspr := Sprite2D.new()
			bspr.texture = Art.tex("gate")
			bspr.scale = Vector2(3, 3)
			bspr.modulate = Color(1.0, 0.62, 0.58)
			bspr.z_index = 3
			bars.add_child(bspr)
			bar_sprites.append(bspr)
		body.add_child(bars)
		body.position = Vector2(-4000, -4000)  # parked (inactive)
		world.add_child(body)
		door_seals.append({"body": body, "shape": shape, "glow": glow,
			"bars": bars, "bar_sprites": bar_sprites})


# ==================================================================== bosses

func _on_boss_trigger(zi: int) -> void:
	if boss_spawned.get(zi, false):
		return
	var kind: String = zones[zi]["boss"]
	if boss_done.get(kind, false):
		return
	boss_spawned[zi] = true
	if String(zones[zi].get("waking", "")) != "":
		_spawn_boss(zi, kind)  # a breach echo: no story beat out of its chapter
		return
	var beat: Array = Story.beat_for("pre_" + kind,
		Story.res_band(player.resonance), flags)
	if beat.is_empty():
		_spawn_boss(zi, kind)
	else:
		hud.dialogue(beat, func() -> void:
			_spawn_boss(zi, kind)
		)

func _spawn_boss(zi: int, kind: String) -> void:
	shake(6.0)
	# Rooms may spawn a boss off its "story" level (Act pacing); NG+ tiers
	# lift the authored level like every campaign spawn (tiered_level).
	current_boss = Boss.make_boss(self, kind,
		rooms[zi]["origin"] + Vector2(ROOM_W - 420.0, ROOM_H / 2.0),
		tiered_level(kind, int(zones[zi].get("boss_level", -1))))
	var waking: bool = String(zones[zi].get("waking", "")) != ""
	# A breach echo dies down the ROGUE path (rewards only, no story) plus
	# the weekly bank; a zone boss drives quests/gates as always.
	current_boss.story_boss = not waking
	if waking:
		current_boss.waking_boss = true
		# One week-seeded elite affix — the same exam for everyone this week.
		var wrng := RandomNumberGenerator.new()
		wrng.seed = waking_week * 6659 + kind.hash() % 100003
		for i in Balance.WAKING_AFFIXES:
			var akey := String(Balance.AFFIX_KEYS[wrng.randi_range(0, Balance.AFFIX_KEYS.size() - 1)])
			Endgame.apply_affix(current_boss, akey)
			current_boss.affix = String(Balance.AFFIXES[akey]["name"])
		if current_boss.affix != "":
			current_boss.display_name = current_boss.affix + " " + current_boss.display_name
	current_boss.zone_idx = zi
	bosses.append(current_boss)
	world.add_child(current_boss)
	current_boss.roar()
	hud.show_boss_bar(current_boss.display_name if waking else Story.ALL_ENEMIES[kind]["name"])
	hud.boss_banner(current_boss.display_name if waking else Story.ALL_ENEMIES[kind]["name"])
	set_music(_boss_music())

func _try_spawn_boss(zi: int, force := false) -> void:
	if net_guest():
		return  # MP-09: bosses are host-side too (mirrored via net_session,
		        # boss bar included)
	# MP (Wave-1 co-op fix): `force` arms a boss room a GUEST reached ahead of
	# the host — _host_ensure_active_rooms populates such rooms, but the normal
	# `zi != cur_room` guard (the host stands elsewhere) would leave the arena
	# unarmed until the host walked in. Force skips ONLY that guard; every other
	# precondition (built, room purged, not already done/spawned) still holds.
	# Local entry passes force=false, so solo/normal behavior is unchanged.
	if not built.get(zi, false) or zone_alive.get(zi, 0) > 0 or (zi != cur_room and not force):
		return
	var kind: String = zones[zi].get("boss", "")
	if kind == "" or boss_done.get(kind, false) or boss_spawned.get(zi, false):
		return
	if String(zones[zi].get("waking", "")) != "" and waking_banked(kind):
		return  # a banked echo does not rise again this week
	_on_boss_trigger(zi)

func add_enemy(e: Enemy) -> void:
	var party: int = players.size()
	if party > 1:
		# Co-op party scaling (MULTIPLAYER.md §5.2) rides every spawn exactly
		# like weekly_fx below; solo (party of 1) skips this block entirely.
		e.max_hp *= Balance.party_hp(party)
		e.hp = e.max_hp
		e.dmg *= Balance.party_dmg(party)
	if weekly_active:
		# The week's modifier rides every spawn (weekly challenge run).
		e.max_hp *= weekly_fx("hp")
		e.hp = e.max_hp
		e.dmg *= weekly_fx("dmg")
		e.speed *= weekly_fx("speed")
	world.add_child(e)


# ============================================================ death / respawn

## Is the current room HOT — ANY living pack, or a live boss that is in
## this room (or a homeless dev spawn)? Hot rooms seal their doors: the
## room must be PURGED before you move on (playtest round 2 — aggro
## stays per-pack, but no running past content).
func _room_hot(i: int) -> bool:
	for b in _live_bosses():
		if b.zone_idx == i or b.zone_idx < 0:
			return true
	if net_guest():
		# Guests never run _spawn_room_enemies, so zone_alive stays 0 — count
		# the HOST's live mirror enemies in the room instead, so a guest is
		# sealed into a combat room exactly as the host is (MP door-seal parity
		# 2026-07-10). Brief gap on first entry until the mirrors stream in.
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e != null and not (e is Boss) and not e.dying and e.zone_idx == i:
				return true
		return false
	return zone_alive.get(i, 0) > 0

## Seal or lift the current room's door seals based on its fight state.
func _update_barrier() -> void:
	var want := _room_hot(cur_room)
	if want and not barrier_active:
		sfx("gate")
	barrier_active = want
	var idx := 0
	if want:
		var pulse := 0.45 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
		for dir in rooms[cur_room]["exits"].keys():
			if idx >= door_seals.size():
				break
			var entry: Dictionary = door_seals[idx]
			idx += 1
			var vertical: bool = dir in ["E", "W"]
			entry["shape"].size = Vector2(TILE * 1.4, DOOR_TILES * TILE + 24.0) if vertical \
				else Vector2(DOOR_TILES * TILE + 24.0, TILE * 1.4)
			entry["glow"].scale = Vector2(1.4, 3.6) if vertical else Vector2(3.6, 1.4)
			entry["glow"].modulate.a = pulse
			# The bars sit back ON the door line (the body itself parks a
			# step outside — see below — where the camera clamp can't see).
			(entry["bars"] as Node2D).position = -Vector2(DIRS[dir]) * (TILE * 0.9)
			for r in DOOR_TILES:
				var bspr: Sprite2D = entry["bar_sprites"][r]
				var bar_off := float(r - 1) * TILE
				bspr.position = Vector2(0, bar_off) if vertical else Vector2(bar_off, 0)
				bspr.modulate.a = 0.7 + 0.3 * pulse
			# Seals sit a step OUTSIDE the room (into the doorway
			# corridor) so one never spawns on top of a player who just
			# walked in — they pass it, then it bars the way back.
			var spos: Vector2 = door_pos(cur_room, String(dir)) \
				+ Vector2(DIRS[dir]) * (TILE * 0.9)
			# ...and never arms INTO the player (playtest 2026-07-07:
			# crossing the line slowly caught the body inside the
			# freshly-armed seal — seconds of grinding to depenetrate).
			# The seal waits, parked, until the player steps clear.
			if is_instance_valid(player) \
					and player.global_position.distance_to(spos) < TILE * 2.4:
				entry["body"].position = Vector2(-4000, -4000)
				continue
			entry["body"].position = spos
	for j in range(idx, door_seals.size()):
		door_seals[j]["body"].position = Vector2(-4000, -4000)

## Weather particles driven by the terrain's ambient preset.
func _setup_ambient_fx(terrain_id: String) -> void:
	if is_instance_valid(ambient_fx):
		ambient_fx.queue_free()
	var spec: Dictionary = Terrains.AMBIENTS.get(
		Terrains.get_terrain(terrain_id).get("ambient", "leaves_green"), {})
	if spec.is_empty():
		ambient_fx = null
		return
	ambient_fx = CPUParticles2D.new()
	ambient_fx.amount = spec["amount"]
	ambient_fx.lifetime = 9.0
	ambient_fx.preprocess = 6.0
	ambient_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ambient_above = spec["above"]
	ambient_fx.emission_rect_extents = Vector2(760, 60) if ambient_above else Vector2(760, 340)
	ambient_fx.spread = 30.0
	ambient_fx.z_index = 12
	ambient_fx.color = spec["color"]
	ambient_fx.direction = spec["dir"]
	ambient_fx.gravity = spec["gravity"]
	ambient_fx.initial_velocity_min = spec["vel"][0]
	ambient_fx.initial_velocity_max = spec["vel"][1]
	ambient_fx.scale_amount_min = spec["scale"][0]
	ambient_fx.scale_amount_max = spec["scale"][1]
	add_child(ambient_fx)


# ================================================================= terrain

## Repaint a room with a different terrain (look + mechanics). Live —
## this is how dev mode lets you audition every terrain instantly.
func apply_terrain(zi: int, terrain_id: String) -> void:
	terrain_by_zone[zi] = terrain_id
	if not built.get(zi, false):
		return  # unbuilt rooms pick the new terrain up at build time
	var terrain := Terrains.get_terrain(terrain_id)
	if is_instance_valid(zone_grounds.get(zi)):
		zone_grounds[zi].texture = Art.ground(terrain["ground"], terrain["path"], TILES_W, TILES_H,
			zi * 1000 + 7, rooms[zi]["exits"].keys())
	_mark_roads(zi)
	_spawn_scenery(zi)  # tombstones, snowy pines, crystals...
	_spawn_patches(zi)
	# Retexture the room's walls to this terrain's tile (colliders unchanged,
	# so no rebuild — just swap the visual). Lets the dev terrain-paint preview
	# walls too, not just ground/props.
	var wt: String = Terrains.wall_for(terrain_id)
	var wall_tint := Terrains.wall_tint_for(terrain_id)
	for s in zone_wall_sprites.get(zi, []):
		if is_instance_valid(s):
			s.texture = Art.tex(wt)
			s.modulate = wall_tint
	# If the player is standing in this room, refresh mood immediately.
	if cur_room == zi:
		var tween := create_tween()
		tween.tween_property(ambient, "color", terrain["tint"], 0.6)
		_setup_ambient_fx(terrain_id)
		terrain_event_t = randf_range(2.0, 4.0)
		if not is_instance_valid(current_boss):
			set_music(terrain.get("music", "village"))

## The road arms Art.ground paints (center plaza -> each REAL doorway)
## are invisible on terrains whose path kind IS their ground kind (keep,
## holy, void, ice...): only the 1px light-catch rim survives, and on
## stone it reads as dashed debug rectangles (art audit 2026-07-10).
## The road is a real navigation marker — door-honest since playtest
## round 3 — so it stays; this lays a faint worn-traffic band over the
## same geometry so the rim reads as the edge of an intentional walkway.
## Geometry mirrors Art.ground's arm rects (16px ground space at 3x).
func _mark_roads(zi: int) -> void:
	for s in zone_road_marks.get(zi, []):
		if is_instance_valid(s):
			s.queue_free()
	zone_road_marks[zi] = []
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var gk := String(terrain["ground"])
	if String(terrain["path"]) != gk or not Art.GROUND.has(gk):
		return  # contrasting path kinds already read as a road
	# Worn tone: dark floors polish LIGHTER underfoot, light floors tread
	# DARKER — both at a whisper (presentation constants, not tuning).
	var base_c: Color = Art.GROUND[gk][0]
	var lum: float = 0.2126 * base_c.r + 0.7152 * base_c.g + 0.0722 * base_c.b
	var worn := Color(1, 1, 1, 0.075) if lum < 0.45 else Color(0, 0, 0, 0.10)
	# Art.ground's arm rects, scaled to world px (16px ground tile * 3 = TILE).
	var path_top := float((TILES_H / 2 - 1) * TILE - 24)
	var band := 3.0 * TILE
	var vleft := float(ROOM_W / 2 - 72)
	var arms: Array = [Rect2(vleft, path_top, band, band)]  # central plaza
	var exits: Array = rooms[zi]["exits"].keys()
	if "W" in exits:
		arms.append(Rect2(0, path_top, vleft, band))
	if "E" in exits:
		arms.append(Rect2(vleft + band, path_top, ROOM_W - vleft - band, band))
	if "N" in exits:  # vertical arms stop at the painted top/bottom wall row
		arms.append(Rect2(vleft, TILE, band, path_top - TILE))
	if "S" in exits:
		arms.append(Rect2(vleft, path_top + band, band, ROOM_H - path_top - band - TILE))
	var origin: Vector2 = rooms[zi]["origin"]
	for arm in arms:
		var r: Rect2 = arm
		var s := Sprite2D.new()
		s.texture = Art.tex("white")
		s.centered = false
		s.position = origin + r.position
		s.scale = r.size / 8.0  # white tex is 8x8
		s.modulate = worn
		s.z_index = -10  # same layer as the ground, added after -> on top
		world.add_child(s)
		zone_road_marks[zi].append(s)


## (Re)roll a room's static hazard patches from its terrain spec.
func _spawn_patches(zi: int) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		if hazards[i]["zone"] == zi:
			if is_instance_valid(hazards[i]["sprite"]):
				hazards[i]["sprite"].queue_free()
			hazards.remove_at(i)
	var terrain := Terrains.get_terrain(terrain_by_zone[zi])
	var origin: Vector2 = rooms[zi]["origin"]
	var rng := RandomNumberGenerator.new()
	rng.seed = zi * 991 + terrain_by_zone[zi].hash()
	for spec in terrain.get("patches", []):
		# Patch counts were tuned for the old strip; rooms are ~2.2x the area.
		for i in int(ceil(float(spec["count"]) * 2.0)):
			var pos := origin + Vector2(rng.randf_range(120.0, ROOM_W - 120.0), rng.randf_range(120.0, ROOM_H - 120.0))
			var radius := rng.randf_range(spec["radius"][0], spec["radius"][1])
			var drift := Vector2.ZERO
			if spec.get("drift", false):
				drift = Vector2(rng.randf_range(-20, 20), rng.randf_range(-14, 14))
			_add_hazard(zi, spec["type"], pos, radius, -1.0, drift)

## Add a floor hazard (until < 0 = permanent, else expires at that time).
func _add_hazard(zi: int, type: String, pos: Vector2, radius: float, duration := -1.0, drift := Vector2.ZERO) -> void:
	var spr := Sprite2D.new()
	spr.texture = Art.tex("glow")
	spr.modulate = Terrains.PATCH_COLOR.get(type, Color(1, 1, 1, 0.4))
	spr.global_position = pos
	spr.scale = Vector2(radius / 22.0, radius / 26.0)
	spr.z_index = -7
	world.add_child(spr)
	hazards.append({"zone": zi, "type": type, "pos": pos, "radius": radius,
		"until": (Time.get_ticks_msec() / 1000.0 + duration) if duration > 0.0 else -1.0,
		"drift": drift, "sprite": spr})
