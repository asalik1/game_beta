extends ShotRig
## Ordinary-input sample: --fresh-ch1 earns progression; default preserves the posed ch2 baseline.
## NO injected damage, loot, wallet, equipment or consumable mutations.
const Alchemy := preload("res://scripts/alchemy.gd")
const NativeInput := preload("res://scripts/tests/menu_navigation_live.gd")
const FullKitGroundTell := preload("res://scripts/ground_tell.gd")
const WalkPath := preload("res://scripts/tests/journey_path.gd")
const Progression := preload("res://scripts/tests/journey_progression.gd")
var fresh_ch1 := false
var full_kit_reason := ""
var native: NativeInput
var p: Player
var held := {}
var report := {"complete": false, "outcome": "setup", "reason": "", "setup": {},
	"milestones": [], "samples": [], "rooms": [], "loot_visits": [], "checks": []}
var start_gold := 0
var begun := 0
var sample_at := 0
# Optional QA observation only; cap the retained boss window, not the run.
const BOSS_TRACE_PERIOD_MSEC := 100
const BOSS_TRACE_MAX_ROWS := 600
var boss_trace_at := 0
var total_walked := 0.0
var previous_position := Vector2.ZERO
var previous_world := 0
var shape: CollisionShape2D
var chosen_grade := ""
var bottle: Dictionary = {}


func _ready() -> void:
	fresh_ch1 = flag("fresh-ch1")
	if flag("full-kit"):
		report.setup["combat_driver"] = "Optional full-kit automated input policy: current visible ground warnings and red/committed Fangmaw charge; normal readiness/mana-gated Blink requests. No human-play claim."
	if fresh_ch1:
		await boot_game()
		game.menus.pick_chapter("ch1")
		await frames(3)
		game.menus.pick_class("mage")
		await frames(5)
	else:
		await boot("mage", "ch2", false)
	p = game.local_player
	native = NativeInput.new()
	native.r = self
	native.g = game
	native.m = game.menus
	var opener_error := ""
	if fresh_ch1:
		report.setup["fresh_birth"] = _hero()
		if p.level != 1 or p.xp != 0 or p.skill_points != 1 or p.unspent_attr != 0 \
				or not p.equipment.is_empty() or not p.tree_points.is_empty():
			opener_error = "New ch1 hero is not the unmodified L1 birth state; no values were reset."
		else:
			await _dialogue()
			if not _choice_contains(0, "My spell did this"):
				opener_error = "Fresh mage opening did not show the declared truth choice."
			else:
				await native._key(KEY_1)
				await _dialogue()
				report.setup["opening_input"] = "Real dialogue advance + key 1: My spell did this (truth)"
	var ready_by := Time.get_ticks_msec() + 8000
	while not game.play_started and Time.get_ticks_msec() < ready_by:
		await get_tree().create_timer(0.05, true).timeout
	var result := opener_error
	if result == "": result = await _journey()
	_release()
	report.reason = result
	report.complete = result == ""
	report.outcome = "complete" if result == "" else String(report.outcome)
	report["end"] = _hero()
	if flag("boss-trace") and is_instance_valid(p):
		# Existing production record: no damage injection or new death handler.
		report["defeat_memory"] = p.damage_memory.last_defeat.duplicate(true)
	report["seconds"] = (Time.get_ticks_msec() - begun) / 1000.0 if begun > 0 else 0.0
	report["input"] = {"mouse_clicks": native.mouse_clicks, "key_taps": native.key_taps,
		"held_key_edges": report.get("held_key_edges", 0), "distance_walked": total_walked}
	await _capture("outcome")
	if not _write_report():
		push_error("BREWING JOURNEY could not write journey.json")
		return finish(1)
	print("BREWING JOURNEY: ", JSON.stringify({"complete": report.complete,
		"outcome": report.outcome, "reason": result, "seconds": report.seconds}))
	# A genuine shortage is INCOMPLETE, never an accepted brew or a balance verdict.
	finish(0 if result == "" else 1)


func _journey() -> String:
	if not game.play_started or not game.no_saves or game.net_online():
		return "Requires ready, isolated no-save solo gameplay."
	report.setup["boot_hero"] = _hero()
	if not p.materials.is_empty() or p.gold < 15 or p.profession != "":
		return "Fresh production hero does not match the empty-material/no-trade start and production starting wallet."
	if game.run_tier() != 0 or p.run_tier != 0:
		return "Fresh production hero/world is not the declared normal-tier scenario."
	report.setup["overrides"] = ["ShotRig no_saves and immediate menu-shell presentation",
		("New mage/ch1 through the existing chapter/class selection seam; opening completed with real input" if fresh_ch1 else "New mage/ch2 selected through the existing ShotRig seam; initial class dialogue skipped by ShotRig")]
	# The boot dialogue can award gold (first observed wallet: 47, from a
	# 15-gold new hero). Preserve it and exclude the ENTIRE pre-combat wallet
	# below; none of those shortcut dialogue rewards prove earned brew funding.
	report.setup["boot_wallet_qualification"] = "Unmodified production boot/dialogue wallet; all pre-combat gold excluded from earned-fee proof."
	if fresh_ch1:
		if game.dev_god or game.dev_mode:
			return "Fresh ch1 must use ordinary combat; no debug state is changed."
		report.setup["mode"] = "fresh-ch1"
		report.setup.overrides.append("No level, XP, point, theme, equipment, HP/MP, wallet, material or replay-access mutation")
	else:
		# Root-approved scenario only. No completed_ch1 flag, equipment roll or XP grant.
		game.dev_god = false
		game.dev_mode = false
		p.level = 6
		p.recalc()
		p.hp = p.max_hp
		p.mp = p.max_mp
		report.setup.overrides.append("dev_god=false, dev_mode=false; level6, recalc normal class/starting-equipment stats; HP/MP filled ONCE at scenario start")
		game._load_meta()
		game._meta["unlocked_ch2"] = true
		report.setup.overrides.append("RAM-only unlocked_ch2=true for subsequent normal replay UI; no completed_ch1 flag")
	Loc.lang = "en"
	game.settings["touch_controls"] = false
	game.refresh_touch_mode()
	game._apply_touch_mode()
	report.setup.overrides.append("English labels and desktop keyboard/mouse controls")
	for child in p.get_children():
		if child is CollisionShape2D and child.shape != null and not child.disabled:
			shape = child
			break
	if shape == null:
		return "The actual hero collision shape is unavailable."
	if fresh_ch1:
		if not _sweep_clear(p.global_position, p.global_position, 0.0):
			return "Production ch1 spawn overlaps scenery; no position or geometry is changed."
	else:
		var mills := _room("The Greyrun Mills")
		if mills < 0:
			return "Authored Greyrun Mills scenario is absent."
		# The single position pose starts beyond the earlier chapter's story gate.
		# Every subsequent position change is player physics or a real UI travel action.
		game._enter_room(mills)
		var start := game.free_spawn_pos(game.room_pos(mills, 360, 620), game.room_center(mills))
		p.global_position = start
		report.setup.overrides.append("One initial room entry/position pose in authored Greyrun Mills: " + str(start))
		if not _motion_clear(Vector2.ZERO):
			return "The initial pose overlaps solid scenery; no geometry is moved."
	await _dialogue()
	if game.menus.is_open():
		return "Initial scenario contains an unresolved menu; no offer is auto-accepted."
	start_gold = p.gold
	begun = Time.get_ticks_msec()
	previous_position = p.global_position
	previous_world = game.world.get_instance_id()
	report.setup["hero"] = _hero()
	report.setup["flags"] = game.flags.duplicate(true)
	report.setup["initial_wallet_excluded_from_earned_fee"] = start_gold
	report.setup["wander_seed"] = game.wander_seed
	report.setup["loot_rng_state"] = str(game.loot_rng.state)
	report.setup["terrain_event_timer_unchanged"] = game.terrain_event_t
	await _capture("00_declared_start")
	_write_report()
	if fresh_ch1:
		var upkeep: String = await Progression.run(self, "initial free point")
		if upkeep != "": return _stop("upkeep_incomplete", upkeep)
		if not await _camp_road(): return _stop("navigation_incomplete", "Could not leave ch1 village through its ordinary elder/road route.")
	var route_names := ["The Darkwood Road", "Wolfpaths", "The Deep Darkwood", "Fangmaw's Hollow"] if fresh_ch1 else ["The Greyrun Mills", "The Howling Fields", "The Sporewood"]
	report.setup["collection_route"] = route_names.duplicate()
	for name in route_names:
		var room := _room(name)
		if room < 0 or (game.cur_room != room and not await _route(room)):
			return _stop("navigation_incomplete", "Could not walk the real unlocked route to " + name)
		var error := await _clear_room(room, 150.0)
		if error != "":
			return error
		if fresh_ch1:
			var teaching: String = await Progression.dismiss_teaching(self)
			if teaching != "": return _stop("upkeep_incomplete", teaching)
		if not await _collect_room(room):
			return _stop("collection_incomplete", "Actual dropped loot could not be reached in " + name)
		_mark("collected " + name)
		if fresh_ch1:
			var upkeep: String = await Progression.run(self, "after " + name)
			if upkeep != "": return _stop("upkeep_incomplete", upkeep)
		await _capture("collected_" + str(room))
	# Prices are read, not committed. Both low grades are novice recipes.
	for grade in ["F", "E"]:
		var spec: Dictionary = Alchemy.recipe("health_tonic", grade)
		var quote: Dictionary = Alchemy.quote(game, "health_tonic", grade)
		if p.material_count("herb", grade) >= int(spec.herbs) \
				and p.material_count("reagent", grade) >= int(spec.reagents) \
				and p.gold - start_gold >= int(quote.fee) and p.consumable_count(String(spec.item.id)) == 0:
			chosen_grade = grade
			bottle = spec.item
			break
	report["collection_end"] = _hero()
	if chosen_grade == "":
		return _stop("natural_shortage", "The single authored route ended without an unowned F/E Health Tonic recipe's exact ingredients and entirely earned fee. No reroll, grant or stock substitution was performed.")
	await native._key(KEY_ESCAPE)
	if game.menus.current != "pause" or not await native._button("Travel to Crownfall"):
		return _stop("ui_incomplete", "Real pause-menu travel to Crownfall was unavailable.")
	await frames(5)
	await _dialogue()
	if game.chapter_id != "capital" or not await _route(_room("Accord Commons")):
		return _stop("navigation_incomplete", "Could not walk from Crownfall arrival to Accord Commons.")
	var kesh: Node2D
	for entry in game.interactables:
		if is_instance_valid(entry.get("node")) and String(entry.get("sprite_name", "")) == "herbalist_kesh":
			kesh = entry.node
	if kesh == null:
		return _stop("ui_incomplete", "The authored Kesh interactable is absent.")
	if not await _walk(kesh.global_position, 35.0, 45.0):
		return _stop("navigation_incomplete", "Could not reach Kesh through solid-safe normal movement.")
	await _tap_interact()
	var choice_by := Time.get_ticks_msec() + 8000
	while not game.hud.choices_active and Time.get_ticks_msec() < choice_by:
		if game.hud.dialogue_active:
			await native._key(KEY_SPACE)
		await frames(2)
	if not _choice_contains(0, "Professions"):
		return _stop("ui_incomplete", "Real Interact did not reach Kesh's choices.")
	await _capture("04_kesh_choices")
	# First authored choice is Professions; root's copy patch preserves its action/order.
	await native._key(KEY_1)
	await _dialogue()
	if game.menus.current != "professions" or not await native._button("Lock Alchemist"):
		return _stop("ui_incomplete", "Kesh's completed reply did not offer the actual first trade lock.")
	if p.profession != "alchemist" or not await _named("ProfessionsAlchemy"):
		return _stop("ui_incomplete", "The real Alchemist/Alchemy entry did not settle.")
	if not await _named("AlchemyShape_health_tonic") or not await _named("AlchemyGrade_" + chosen_grade):
		return _stop("ui_incomplete", "The exact naturally funded Health Tonic recipe could not be selected.")
	var before := _hero()
	var quote: Dictionary = Alchemy.quote(game, "health_tonic", chosen_grade)
	report["brew_quote"] = quote
	if not bool(quote.allowed) or p.gold - start_gold < int(quote.fee):
		return _stop("natural_shortage", "Current bench quote is not fully funded by earned resources.")
	await _capture("05_earned_quote")
	if not await _named("AlchemyBrew"):
		return _stop("ui_incomplete", "The actual Brew control could not be clicked.")
	var exact := p.gold == int(before.gold) - int(quote.fee) \
		and p.material_count("herb", chosen_grade) == int(before.material_counts[chosen_grade].herb) - int(quote.herbs) \
		and p.material_count("reagent", chosen_grade) == int(before.material_counts[chosen_grade].reagent) - int(quote.reagents) \
		and Professions.points(p, "alchemist") == int(before.mastery.get("alchemist", 0)) + int(quote.mastery_gain) \
		and p.consumable_count(String(bottle.id)) == 1
	report.checks.append({"check": "one exact paid brew", "ok": exact, "before": before, "after": _hero()})
	if not exact:
		return _stop("transaction_failed", "Real Brew did not produce the exact ingredient/gold/mastery/one-pack-bottle delta. Inspect mail rather than treating it as a pass.")
	_mark("brewed one naturally funded tonic")
	await _capture("06_brewed")
	# Back out through real input, then assign the exact visible SKU in inventory.
	for i in 3:
		if game.menus.is_open():
			await native._key(KEY_ESCAPE)
	if game.menus.is_open():
		return _stop("ui_incomplete", "Could not close Alchemy/Professions through Escape.")
	if fresh_ch1:
		if not await Progression.open_menu(self, "inventory"):
			return _stop("ui_incomplete", "Real Inventory held key did not open after leaving the bench.")
	else:
		await native._key(int(game.binds.inventory))
	if not await native._button("Potions"):
		return _stop("ui_incomplete", "Inventory Potions tab was unavailable.")
	var slot_button: Button
	for control in game.menus.root.find_children("*", "Button", true, false):
		if control.tooltip_text.begins_with(String(bottle.name) + "\n") \
				and control.tooltip_text.contains("Select: assign to the next free slot"):
			slot_button = control
	if not await _click(slot_button) or not p.potion_loadout().has(String(bottle.id)):
		return _stop("ui_incomplete", "The brewed bottle could not be assigned through its real inventory tile.")
	await _capture("07_exact_loadout")
	await native._key(KEY_ESCAPE)
	await native._key(KEY_ESCAPE)
	if game.menus.current != "pause" or not await native._button("Chapter select"):
		return _stop("ui_incomplete", "Capital's real replay selector was unavailable.")
	var return_chapter := "ch1" if fresh_ch1 else "ch2"
	if not await native._button(("1.  " if fresh_ch1 else "2.  ") + String(Story.chapter(return_chapter).name)):
		return _stop("ui_incomplete", "The current chapter eligibility did not enable its real replay button: " + return_chapter)
	await frames(5)
	await _dialogue()
	if game.hud.choices_active:
		if fresh_ch1:
			return _stop("ui_incomplete", "Ch1 replay showed an unexpected choice; no branch was auto-accepted.")
		# The first actual ch2 replay can show its chapter opener. Choose the
		# authored neutral response through real input; never skip by setting a flag.
		if not _choice_contains(2, "File it away"):
			return _stop("ui_incomplete", "The replay showed an unexpected chapter-opening choice.")
		await native._key(KEY_3)
		await _dialogue()
		_mark("normal replay opener: File it away, neutral choice")
	if game.chapter_id != return_chapter:
		return _stop("ui_incomplete", "Real replay did not enter " + return_chapter)
	report["replay_start"] = _hero()
	# The normal replay makes fresh enemies. It also restores the camp's story gate.
	# Speak through the real camp elder before attempting the first road; no flags set here.
	if not await _camp_road():
		return _stop("navigation_incomplete", "The normal camp story/road could not be traversed. Brew proof remains valid; combat-use proof is incomplete.")
	return await _use_tonic_in_combat(60.0)


func _clear_room(room: int, seconds: float) -> String:
	step("ordinary combat " + String(game.zones[room].name))
	var started := Time.get_ticks_msec()
	var initial := _hero()
	var roster := _roster(room)
	while Time.get_ticks_msec() - started < int(seconds * 1000):
		if p.dead or p.downed or p.ghost:
			return _stop("ordinary_defeat", "Normal mage fell in " + String(game.zones[room].name))
		if game.hud.choices_active:
			return _stop("ui_incomplete", "An unplanned choice interrupted combat; no bargain was auto-accepted.")
		if game.hud.dialogue_active:
			_release()
			await _dialogue()
			continue
		if game.menus.is_open():
			_release()
			if fresh_ch1 and game.room_pacified(room) and _nearest_enemy(room) == null:
				var teaching: String = await Progression.dismiss_teaching(self)
				if teaching != "": return _stop("upkeep_incomplete", teaching)
				continue
			return _stop("ui_incomplete", "An unplanned menu interrupted ordinary combat: " + game.menus.current)
		var enemy := _nearest_enemy(room)
		if game.room_pacified(room) and enemy == null:
			_release()
			report.rooms.append({"name": game.zones[room].name, "roster_at_entry": roster,
				"before": initial, "after": _hero(), "seconds": (Time.get_ticks_msec() - started) / 1000.0})
			return ""
		_drive_combat(enemy, (Time.get_ticks_msec() - started) / 1000.0, true)
		await _tick()
	_release()
	return _stop("combat_incomplete", "The input-only driver did not clear its bounded room attempt; no damage or death was injected.")


func _drive_combat(enemy: Enemy, seconds: float, survival: bool) -> void:
	if flag("full-kit"):
		_drive_full_kit(enemy, seconds, survival)
		return
	var walk := Vector2.ZERO
	var near := INF
	if is_instance_valid(enemy):
		var toward := (enemy.global_position - p.global_position).normalized()
		near = p.global_position.distance_to(enemy.global_position)
		walk = toward if near > 245.0 else -toward if near < 210.0 else Vector2.ZERO
		if enemy.pounce_windup > 0.0 or enemy.pounce_time > 0.0:
			walk = Vector2(-toward.y, toward.x)
		if not game.play_rect(game.cur_room).grow(-55.0).has_point(p.global_position + walk * 70.0):
			walk = (game.room_center(game.cur_room) - p.global_position).normalized()
	var movement := _steer(walk)
	_move(movement)
	_press(int(game.binds.a1), enemy != null and near < 480.0)
	var nova_needed := enemy != null and near < 190.0
	if fresh_ch1 and enemy != null:
		nova_needed = nova_needed or p.hp < p.max_hp * 0.8 or p.mp < p.max_mp * 0.6
	_press(int(game.binds.a2), nova_needed)
	# Keep this collection sample independent of the separately audited Blink
	# landing question. A1/A2/ultimate are the ordinary mage damage inputs here.
	_press(int(game.binds.a3), false)
	_press(int(game.binds.ult), enemy != null and seconds > 10.0 and near < (500.0 if fresh_ch1 else 220.0))
	_press(int(game.binds.potion), survival and p.hp < p.max_hp * 0.4)


## Optional deterministic input policy, not a human-play or victory claim.
func _drive_full_kit(enemy: Enemy, seconds: float, survival: bool) -> void:
	if game.input_overlay_up() or get_tree().paused or p.dead or p.downed or p.ghost:
		_release()
		return
	# Preserve the existing Firebolt/Nova/Meteor/Q policy except while requesting
	# an evasive Blink: releasing damage keys gives its ordinary mana gate priority.
	var walk := Vector2.ZERO
	var near := INF
	if is_instance_valid(enemy):
		var toward := (enemy.global_position - p.global_position).normalized()
		near = p.global_position.distance_to(enemy.global_position)
		walk = toward if near > 245.0 else -toward if near < 210.0 else Vector2.ZERO
		if enemy.pounce_windup > 0.0 or enemy.pounce_time > 0.0:
			walk = Vector2(-toward.y, toward.x)
		if not game.play_rect(game.cur_room).grow(-55.0).has_point(p.global_position + walk * 70.0):
			walk = (game.room_center(game.cur_room) - p.global_position).normalized()
	var response := _full_kit_response(walk)
	var movement: Vector2 = response.movement
	var blink: bool = response.danger and response.escape_alignment and movement.length_squared() > 0.01 \
		and not bool(held.get(int(game.binds.a3), false)) and p.frozen_time <= 0.0 \
		and float(p.cds.get("a3", 1.0)) <= 0.0 and p.mp >= p.ability_cost("a3")
	_move(movement)
	_press(int(game.binds.a1), not blink and enemy != null and near < 480.0)
	var nova_needed := enemy != null and near < 190.0
	if fresh_ch1 and enemy != null:
		nova_needed = nova_needed or p.hp < p.max_hp * 0.8 or p.mp < p.max_mp * 0.6
	_press(int(game.binds.a2), not blink and nova_needed)
	# One normal poll interval down, then an unconditional up on the next visit.
	# This is a key request; the real Player owns cast eligibility and spending.
	_press(int(game.binds.a3), blink)
	_press(int(game.binds.ult), not blink and enemy != null and seconds > 10.0 and near < (500.0 if fresh_ch1 else 220.0))
	_press(int(game.binds.potion), survival and p.hp < p.max_hp * 0.4)
	if not report.has("full_kit"):
		report["full_kit"] = {"rows": [], "total_rows": 0, "dropped_rows": 0, "blink_key_presses": 0}
	var history: Dictionary = report.full_kit
	if blink:
		history.blink_key_presses = int(history.blink_key_presses) + 1
	# Keep a bounded decision receipt at existing driver visits. No extra wait,
	# report write, state setter, cast call or damage hook is introduced here.
	if response.reason != full_kit_reason or blink:
		full_kit_reason = response.reason
		history.rows.append({"monotonic_seconds": Time.get_ticks_msec() / 1000.0,
			"reason": response.reason, "observed": response.observed, "danger": response.danger, "escape_alignment": response.escape_alignment,
			"position": _vec(p.global_position), "movement": _vec(movement), "blink_key_down": blink,
			"mp_at_request": p.mp, "blink_cost": p.ability_cost("a3"), "blink_cd": p.cds.a3,
			"ground_clocks": response.clocks})
		history.total_rows = int(history.total_rows) + 1
		while history.rows.size() > 256:
			history.rows.pop_front()
			history.dropped_rows = int(history.dropped_rows) + 1


func _full_kit_response(ordinary_walk: Vector2) -> Dictionary:
	var result := {"movement": _steer(ordinary_walk), "danger": false, "escape_alignment": false,
		"reason": "ordinary policy", "observed": {}, "clocks": []}
	if not is_instance_valid(game.current_boss):
		return result
	var boss := game.current_boss as Boss
	if boss == null or boss.kind != "fangmaw" or boss.game != game \
		or boss.zone_idx != game.cur_room or boss.dying or boss.is_queued_for_deletion():
		return result
	var toward := (boss.global_position - p.global_position).normalized()
	var avoidance := Vector2.ZERO
	var reasons: Array[String] = []
	# Leap and rake both create these CURRENT rendered warning clocks. Never
	# inspect ring_cd/special_cd or reconstruct an attack that has not appeared.
	for attack in game._ground_attacks:
		if not is_instance_valid(attack) or attack.is_queued_for_deletion():
			continue
		for child in attack.get_children():
			var clock := child as FullKitGroundTell
			if clock == null or clock.is_queued_for_deletion() or clock.safe or clock.decoy or clock.orbit_only \
				or not _full_kit_on_screen(clock, clock.radius):
				continue
			var away := p.global_position - clock.global_position
			# 24px is conservative driver spacing beyond the visible rim. It
			# changes no hit radius and does not predict the hidden damage timer.
			if away.length() > clock.radius + 24.0:
				continue
			result.clocks.append({"instance_id": clock.get_instance_id(),
				"position": _vec(clock.global_position), "radius": clock.radius,
				"visible_progress": clock.progress, "safe": clock.safe})
			avoidance += away.normalized() if away.length_squared() > 1.0 else toward.orthogonal()
			result.danger = true
	if not result.clocks.is_empty():
		reasons.append("visible ground warning")
	var boss_visible := is_instance_valid(boss.sprite) and _full_kit_on_screen(boss.sprite, 0.0)
	if boss_visible:
		result.observed = {"leaping": boss.leaping, "telegraphing": boss.telegraphing,
			"charging": boss.charging, "sprite_modulate": str(boss.sprite.modulate)}
		if boss.charging and boss.velocity.length_squared() > 1.0:
			# Read the moving body's current direction only after charge commits.
			# Never use stale charge_dir during windup or call future AI selection.
			var direction := boss.velocity.normalized()
			var relative := p.global_position - boss.global_position
			var side := direction.orthogonal()
			if relative.dot(direction) > -32.0 and relative.length() < 360.0 \
				and absf(relative.dot(side)) < 110.0:
				avoidance += side if relative.dot(side) >= 0.0 else -side
				result.danger = true
				reasons.append("visible committed charge")
				result.observed["committed_direction"] = _vec(direction)
		elif boss.telegraphing and boss.sprite.modulate.r > 1.5 \
			and boss.sprite.modulate.r > boss.sprite.modulate.g * 2.0 \
			and p.global_position.distance_to(boss.global_position) < 360.0:
			# Red charge warning: sidestep now; this alone never requests Blink.
			# Fangmaw still re-aims at windup end, so no committed lane is assumed.
			avoidance += toward.orthogonal()
			reasons.append("visible charge windup")
	if not reasons.is_empty():
		if avoidance.length_squared() < 0.01:
			avoidance = toward.orthogonal()
		var steered: Vector2 = _steer(avoidance.normalized())
		result.movement = steered
		result.escape_alignment = steered.dot(avoidance.normalized()) > 0.25
		result.reason = "; ".join(reasons)
	return result


func _full_kit_on_screen(item: Node2D, radius: float) -> bool:
	if not item.is_visible_in_tree() or item.modulate.a <= 0.0 or item.self_modulate.a <= 0.0:
		return false
	var ancestor: Node = item.get_parent()
	while ancestor != null:
		if ancestor is CanvasItem and ancestor.modulate.a <= 0.0:
			return false
		ancestor = ancestor.get_parent()
	var transform := item.get_global_transform_with_canvas()
	var point := transform.origin
	var extent := Vector2(transform.x.length(), transform.y.length()) * maxf(radius, 1.0)
	return get_viewport().get_visible_rect().intersects(Rect2(point - extent, extent * 2.0))

func _collect_room(room: int) -> bool:
	step("collect actual room drops")
	var until := Time.get_ticks_msec() + 55000
	while Time.get_ticks_msec() < until:
		var closest: Node2D
		var near := INF
		for node in game.find_children("*", "Node2D", true, false):
			if not (node is Pickup or node is Chest) or node.is_queued_for_deletion():
				continue
			if node is Chest and node.opened:
				continue
			if game.room_at_pos(node.global_position) != room:
				continue
			var distance: float = p.global_position.distance_to(node.global_position)
			if distance < near:
				near = distance
				closest = node
		if closest == null:
			return true
		var receipt := {"node": str(closest.get_path()), "position": _vec(closest.global_position),
			"before": _hero(), "kind": closest.kind if closest is Chest else String(closest.loot.get("kind", "gold")),
			"status": "walking", "opened_or_collected": false}
		# Preserve the attempted target even if its first walk fails or times out.
		report.loot_visits.append(receipt)
		_write_report()
		if not await _walk(closest.global_position, 12.0, 9.0, -1, weakref(closest)):
			receipt.status = "walk_failed"
			receipt["after"] = _hero()
			_write_report()
			return false
		await sim_wait(0.45)
		receipt["opened_or_collected"] = not is_instance_valid(closest) or closest.is_queued_for_deletion() \
			or (closest is Chest and closest.opened)
		receipt["after"] = _hero()
		receipt.status = "collected" if bool(receipt.opened_or_collected) else "arrived_without_collection"
		_write_report()
		if not bool(receipt.opened_or_collected):
			return false
	return false


func _use_tonic_in_combat(seconds: float) -> String:
	step("use the brewed bottle under ordinary incoming attacks")
	var started := Time.get_ticks_msec()
	var names: Array = []
	for entry in _roster(game.cur_room):
		names.append(entry.name)
	var drank := false
	var drink_hp := 0.0
	while Time.get_ticks_msec() - started < int(seconds * 1000):
		if p.dead or p.downed or p.ghost:
			return _stop("ordinary_defeat", "The mage fell during the normal combat-use leg.")
		var enemy := _nearest_enemy(game.cur_room)
		if game.hud.dialogue_active or game.hud.choices_active or game.menus.is_open():
			_release()
			return _stop("ui_incomplete", "An overlay interrupted the combat-use leg.")
		_drive_combat(enemy, (Time.get_ticks_msec() - started) / 1000.0, false)
		var landed: Dictionary = {}
		for hit in p.damage_memory.hits:
			if float(hit.time) >= started / 1000.0 and names.has(String(hit.source)):
				landed = hit
		if not drank and not landed.is_empty() and p.hp < p.max_hp - 2.0 and enemy != null:
			if p.active_potion != String(bottle.id) or int(p.room_potions.get(String(bottle.id), 0)) != 1:
				return _stop("ui_incomplete", "A real room transition did not make the assigned tonic active with one use.")
			_release()
			drink_hp = p.hp
			report["drink_before"] = {"hero": _hero(), "incoming_hit": landed, "live_enemy": enemy.display_name}
			await native._key(int(game.binds.potion))
			drank = p.consumable_count(String(bottle.id)) == 0 \
				and int(p.room_potions.get(String(bottle.id), 0)) == 0 \
				and p.heal_tonic_time > 0.0 and p.heal_tonic_rate > 0.0
			report["drink_after"] = {"hero": _hero(), "tonic_time": p.heal_tonic_time, "tonic_rate": p.heal_tonic_rate}
			if not drank:
				return _stop("potion_use_failed", "Real Q did not consume the sole brewed SKU, spend its room budget and start a nonzero tonic.")
			await _capture("08_brewed_tonic_in_combat")
		if drank and p.hp > drink_hp + 0.1 and p.heal_tonic_time > 0.0:
			_release()
			_mark("tonic consumed in combat; active effect and HP recovery observed")
			return ""
		await _tick()
	_release()
	return _stop("combat_use_incomplete", "No qualifying ordinary enemy hit/use/recovery completed in the bounded window; no hit or missing health was manufactured.")


func _camp_road() -> bool:
	var mills := _room("The Darkwood Road" if fresh_ch1 else "The Greyrun Mills")
	if mills < 0:
		return false
	if game._edge_unlocked(game.cur_room, mills):
		return await _route(mills)
	# Only the actual elder's conversation may advance the camp gate.
	var elder: Node2D
	if fresh_ch1:
		elder = game.elder
	else:
		for entry in game.interactables:
			if is_instance_valid(entry.get("node")) and String(entry.get("sprite_name", "")) == "elder":
				elder = entry.node
	if elder == null or not await _walk(elder.global_position, 30.0, 45.0):
		return false
	await _tap_interact()
	await _dialogue()
	if game.hud.choices_active:
		if fresh_ch1: return false # do not accept unrelated ch1 choices
		# Authored ch2_maren_hub.m3 choice 1: Point me east. This actual
		# input sets ch2_briefed/quest through the normal conversation path.
		if not _choice_contains(0, "Point me east"):
			return false
		await native._key(KEY_1)
		await _dialogue()
	if not game._edge_unlocked(game.cur_room, mills):
		return false
	return await _route(mills)


func _route(target: int) -> bool:
	if target < 0:
		return false
	var queue: Array[int] = [game.cur_room]
	var previous := {game.cur_room: -1}
	while not queue.is_empty() and not previous.has(target):
		var current: int = queue.pop_front()
		for raw in game.rooms[current].exits:
			var next := game.neighbor(current, String(raw))
			if next >= 0 and not previous.has(next) and game._edge_unlocked(current, next):
				previous[next] = current
				queue.append(next)
	if not previous.has(target):
		return false
	var path: Array[int] = []
	var cursor := target
	while cursor != game.cur_room:
		path.push_front(cursor)
		cursor = int(previous[cursor])
	for next in path:
		var direction := ""
		for raw in game.rooms[game.cur_room].exits:
			if game.neighbor(game.cur_room, String(raw)) == next:
				direction = String(raw)
		if direction == "":
			return false
		var outward: Vector2 = {"N": Vector2.UP, "S": Vector2.DOWN, "E": Vector2.RIGHT, "W": Vector2.LEFT}[direction]
		var door := game.door_pos(game.cur_room, direction)
		if not await _walk(door + outward * 45.0, 28.0, 14.0, next):
			return false
		await _dialogue()
	return game.cur_room == target


func _walk(goal: Vector2, seconds: float, reach: float, arrival_room := -1, watched: WeakRef = null) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	var starting_room := game.cur_room
	var record := {"goal": _vec(goal), "start": _vec(p.global_position), "room": starting_room,
		"arrival_room": arrival_room, "reach": reach, "status": "walking", "plans": [], "stalls": [],
		"actual_shape_blockers": _walk_blockers(0.0), "old_margin_blockers": _walk_blockers(2.0)}
	if not report.has("walks"): report["walks"] = []
	report.walks.append(record)
	_write_report()
	var route: Array = []
	var waypoint := 0
	var checkpoint := p.global_position
	var checkpoint_waypoint := 0
	var checkpoint_at := Time.get_ticks_msec()
	var replans := 0
	while Time.get_ticks_msec() < until:
		if p.dead or p.downed or p.ghost:
			return _walk_result(record, "hero_unavailable", false)
		if watched != null:
			var loot_node: Node = watched.get_ref() as Node
			if loot_node == null or loot_node.is_queued_for_deletion() or (loot_node is Chest and loot_node.opened):
				return _walk_result(record, "target_collected", true)
		if (arrival_room >= 0 and game.cur_room == arrival_room) \
				or (arrival_room < 0 and p.global_position.distance_to(goal) <= reach):
			return _walk_result(record, "arrived", true)
		if game.cur_room != starting_room:
			return _walk_result(record, "unexpected_room_transition", false)
		if game.menus.is_open() or game.hud.dialogue_active or game.hud.choices_active:
			return _walk_result(record, "overlay_interrupted_walk", false)
		if route.is_empty():
			_release()
			if replans >= 3:
				return _walk_result(record, "bounded_replans_exhausted", false)
			var planned: Dictionary = await WalkPath.plan(self, goal, reach, until)
			replans += 1
			var detail := planned.duplicate()
			detail.points = []
			for point in planned.points: detail.points.append(_vec(point))
			record.plans.append(detail)
			_write_report()
			if String(planned.status) != "planned":
				return _walk_result(record, String(planned.status), false)
			route = planned.points
			waypoint = 0
			checkpoint = p.global_position
			checkpoint_waypoint = 0
			checkpoint_at = Time.get_ticks_msec()
			continue # recheck actual pickup/overlay/world state after the yielded search
		while waypoint < route.size() - 1 and p.global_position.distance_to(route[waypoint]) <= 5.0:
			waypoint += 1
		var delta: Vector2 = route[waypoint] - p.global_position
		# Cardinal keys match planned grid edges. The final few pixels approach
		# the actual target; every emitted step is swept again from the real body.
		var direction := Vector2(signf(delta.x), 0.0) if absf(delta.x) >= absf(delta.y) else Vector2(0.0, signf(delta.y))
		var lookahead := maxf(2.0, minf(12.0, delta.length()))
		if not _sweep_clear(p.global_position, p.global_position + direction * lookahead, 0.0):
			_move(Vector2.ZERO)
			record.stalls.append({"reason": "next_actual_step_blocked", "position": _vec(p.global_position),
				"waypoint": waypoint, "blockers": _walk_blockers(0.0)})
			route = []
			continue
		_move(direction)
		await _tick(0.01)
		if Time.get_ticks_msec() - checkpoint_at >= 1500:
			if waypoint == checkpoint_waypoint and p.global_position.distance_to(checkpoint) < 12.0:
				record.stalls.append({"reason": "no_net_progress", "position": _vec(p.global_position), "waypoint": waypoint})
				route = []
			checkpoint = p.global_position
			checkpoint_waypoint = waypoint
			checkpoint_at = Time.get_ticks_msec()
	return _walk_result(record, "walk_deadline", false)


func _walk_result(record: Dictionary, status: String, ok: bool) -> bool:
	_release()
	record.status = status
	record["end"] = _vec(p.global_position)
	record["actual_shape_blockers_end"] = _walk_blockers(0.0)
	record["old_margin_blockers_end"] = _walk_blockers(2.0)
	_write_report()
	return ok


func _walk_query(at: Vector2, margin: float) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.transform.origin += at - p.global_position
	query.collision_mask = 1
	query.margin = margin
	query.exclude = [p.get_rid()]
	return query


func _sweep_clear(start_at: Vector2, end_at: Vector2, margin: float) -> bool:
	var space := p.get_world_2d().direct_space_state
	var query := _walk_query(start_at, margin)
	if not space.intersect_shape(query, 1).is_empty(): return false
	var end_query := _walk_query(end_at, margin)
	if not space.intersect_shape(end_query, 1).is_empty(): return false
	query.motion = end_at - start_at
	var fractions := space.cast_motion(query)
	return fractions.size() >= 1 and fractions[0] >= 0.999


func _walk_blockers(margin: float) -> Array:
	var out := []
	for hit in p.get_world_2d().direct_space_state.intersect_shape(_walk_query(p.global_position, margin), 4):
		var collider: Node = hit.get("collider") as Node
		out.append({"node": str(collider.get_path()) if is_instance_valid(collider) else "unavailable",
			"shape_index": int(hit.get("shape", -1)), "margin": margin})
	return out


func _motion_clear(motion: Vector2, offset := Vector2.ZERO) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.transform.origin += offset
	query.collision_mask = 1
	query.margin = 2.0
	query.exclude = [p.get_rid()]
	var space := p.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = motion
	var fractions := space.cast_motion(query)
	return fractions.size() >= 1 and fractions[0] >= 0.99


func _steer(wanted: Vector2) -> Vector2:
	if wanted.length_squared() < 0.01:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var score := -INF
	# Local eight-direction avoidance only; no teleport, collider change or nav repair.
	for turn in [0, 1, -1, 2, -2, 3, -3, 4]:
		var direction := wanted.rotated(float(turn) * PI / 4.0).normalized()
		# Match the keyboard quantization BEFORE probing the actual swept body.
		direction = Vector2(-1 if direction.x < -0.3 else 1 if direction.x > 0.3 else 0,
			-1 if direction.y < -0.3 else 1 if direction.y > 0.3 else 0).normalized()
		var candidate := direction.dot(wanted)
		if candidate > score and _motion_clear(direction * 48.0):
			best = direction
			score = candidate
	return best


func _move(direction: Vector2) -> void:
	_press(KEY_A, direction.x < -0.3)
	_press(KEY_D, direction.x > 0.3)
	_press(KEY_W, direction.y < -0.3)
	_press(KEY_S, direction.y > 0.3)


func _press(key: int, down: bool) -> void:
	if bool(held.get(key, false)) == down:
		return
	held[key] = down
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	report["held_key_edges"] = int(report.get("held_key_edges", 0)) + 1


func _release() -> void:
	for key in held.keys():
		_press(int(key), false)
	if is_instance_valid(p):
		p.clear_local_intents()


func _tap_interact() -> void:
	_press(int(game.binds.interact), true)
	await frames(3)
	_press(int(game.binds.interact), false)
	await frames(2)


func _dialogue() -> void:
	for i in 100:
		if game.hud.choices_active:
			# Choices remain with the explicitly labeled Kesh/opener/Maren callers.
			return
		if not game.hud.dialogue_active:
			return
		await native._key(KEY_SPACE)
		await frames(2)


func _choice_contains(index: int, text: String) -> bool:
	return game.hud.choices_active and game.hud.choice_option_labels.size() > index \
		and is_instance_valid(game.hud.choice_option_labels[index]) \
		and String(game.hud.choice_option_labels[index].text).contains(text)


func _named(name: String) -> bool:
	if not is_instance_valid(game.menus.root):
		return false
	var button := game.menus.root.find_child(name, true, false) as Button
	return await _click(button)


func _click(button: Button) -> bool:
	if button == null or button.disabled or not button.is_visible_in_tree():
		return false
	var parent := button.get_parent()
	while parent != null and parent != game.menus.root:
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			await frames(2)
		parent = parent.get_parent()
	await native._mouse(button.get_global_rect().get_center())
	await frames(3)
	return true


func _nearest_enemy(room: int) -> Enemy:
	var result: Enemy
	var near := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy.dying or enemy.is_queued_for_deletion() or enemy.zone_idx != room:
			continue
		var distance := p.global_position.distance_to(enemy.global_position)
		if distance < near:
			near = distance
			result = enemy
	return result


func _roster(room: int) -> Array:
	var out := []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.game == game and enemy.zone_idx == room and not enemy.dying:
			out.append({"name": enemy.display_name, "kind": enemy.kind, "level": enemy.level,
				"elite": enemy.elite, "hp": enemy.hp, "max_hp": enemy.max_hp, "position": _vec(enemy.global_position)})
	return out


func _room(name: String) -> int:
	for i in game.zones.size():
		if String(game.zones[i].name) == name:
			return i
	return -1


func _tick(wait_seconds := 0.05) -> void:
	await get_tree().create_timer(wait_seconds, true).timeout
	if game.world.get_instance_id() == previous_world:
		total_walked += p.global_position.distance_to(previous_position)
	previous_position = p.global_position
	previous_world = game.world.get_instance_id()
	_record_boss_trace()
	if Time.get_ticks_msec() >= sample_at:
		sample_at = Time.get_ticks_msec() + 1000
		report.samples.append({"seconds": (Time.get_ticks_msec() - begun) / 1000.0,
			"hero": _hero(), "nearby_roster": _roster(game.cur_room)})


func _boss_trace_target(actor: Enemy) -> Dictionary:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return {}
	return {"instance_id": actor.get_instance_id(), "kind": actor.kind,
		"position": _vec(actor.global_position), "distance": p.global_position.distance_to(actor.global_position),
		"hp": actor.hp, "dying": actor.dying, "untargetable": actor.untargetable}


func _record_boss_trace(force := false, marker := "sample") -> void:
	if not flag("boss-trace") or not is_instance_valid(game) or not is_instance_valid(p):
		return
	var now: int = Time.get_ticks_msec()
	if not force and now < boss_trace_at:
		return
	boss_trace_at = now + BOSS_TRACE_PERIOD_MSEC
	var bosses: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var boss := node as Boss
		if (boss == null or boss.game != game or boss.zone_idx != game.cur_room
				or boss.dying or boss.is_queued_for_deletion()):
			continue
		var body: Dictionary = _boss_trace_target(boss)
		body["max_hp"] = boss.max_hp
		body["velocity"] = _vec(boss.velocity)
		body["leaping"] = boss.leaping
		body["telegraphing"] = boss.telegraphing
		body["charging"] = boss.charging
		body["charge_dir"] = _vec(boss.charge_dir)
		body["charge_time"] = boss.charge_time
		body["ability_cd"] = boss.ability_cd
		body["special_cd"] = boss.special_cd
		body["ring_cd"] = boss.ring_cd
		body["attack_cd"] = boss.attack_cd
		body["cast_window_phase"] = boss.cast_window.phase
		# These are the different Enemy fields the current driver reacts to.
		body["pounce_windup"] = boss.pounce_windup
		body["pounce_time"] = boss.pounce_time
		bosses.append(body)
	if bosses.is_empty():
		return
	if not report.has("boss_trace"):
		report["boss_trace"] = {"period_msec": BOSS_TRACE_PERIOD_MSEC, "max_rows": BOSS_TRACE_MAX_ROWS,
			"phase": "after ordinary tick timer; forced stop sample precedes existing key release",
			"total_rows": 0, "dropped_rows": 0, "rows": []}
	var trace: Dictionary = report.boss_trace
	var requested: Dictionary = {}
	var pressed: Dictionary = {}
	for action in ["a1", "a2", "a3", "ult", "potion"]:
		var code: int = game.binds[action]
		requested[action] = bool(held.get(code, false))
		pressed[action] = Input.is_key_pressed(code)
	var move_keys: Dictionary = {}
	for pair in [["W", KEY_W], ["A", KEY_A], ["S", KEY_S], ["D", KEY_D]]:
		move_keys[pair[0]] = Input.is_key_pressed(int(pair[1]))
	# aim_focus is a read-only query of the current soft/hard/facing selection.
	# This is NOT the historical release target of an asynchronous Firebolt.
	var aim := p.aim_focus() as Enemy
	var row := {"seconds": (now - begun) / 1000.0, "marker": marker,
		"monotonic_seconds": now / 1000.0, "process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(), "in_physics": Engine.is_in_physics_frame(),
		"chapter": game.chapter_id, "room": game.cur_room, "state": game.state,
		"paused": get_tree().paused, "overlay": game.input_overlay_up(),
		"position": _vec(p.global_position), "velocity": _vec(p.velocity), "facing": _vec(p.facing),
		"hp": p.hp, "max_hp": p.max_hp, "mp": p.mp, "max_mp": p.max_mp,
		"cooldowns": p.cds.duplicate(true), "requested_keys": requested, "pressed_keys": pressed,
		"move_keys": move_keys, "intent_move": _vec(p.intent_move),
		"intents": {"a1": p.intent_a1, "a2": p.intent_a2, "a3": p.intent_a3,
			"ult": p.intent_ult, "potion": p.intent_potion},
		"driver_nearest": _boss_trace_target(_nearest_enemy(game.cur_room)),
		"aim_now": _boss_trace_target(aim), "soft_target": _boss_trace_target(p.soft_target as Enemy),
		"locked_target": _boss_trace_target(p.locked_target as Enemy), "bosses": bosses}
	trace.rows.append(row)
	trace.total_rows = int(trace.total_rows) + 1
	while trace.rows.size() > BOSS_TRACE_MAX_ROWS:
		trace.rows.pop_front()
		trace.dropped_rows = int(trace.dropped_rows) + 1


func _hero() -> Dictionary:
	if not is_instance_valid(p):
		return {}
	var materials := {}
	for grade in ["F", "E", "D", "C", "B", "A", "S"]:
		materials[grade] = {"herb": p.material_count("herb", grade), "reagent": p.material_count("reagent", grade)}
	return {"class": p.cls, "level": p.level, "xp": p.xp, "hp": p.hp, "max_hp": p.max_hp,
		"mp": p.mp, "max_mp": p.max_mp, "attack": p.atk, "speed": p.speed, "gold": p.gold,
		"materials": p.materials.duplicate(true), "material_counts": materials,
		"equipment": p.equipment.duplicate(true), "backpack": p.backpack.duplicate(true), "consumables": p.consumables.duplicate(true),
		"themes_known": p.themes_known, "talent_budget": p.talent_point_budget(), "resonance": p.resonance,
		"ability_theme": p.ability_theme.duplicate(true), "tree_points": p.tree_points.duplicate(true),
		"attr_points": p.attr_points.duplicate(true), "unspent_attr": p.unspent_attr, "skill_points": p.skill_points,
		"mastery": p.mastery.duplicate(true), "profession": p.profession, "blueprints": p.blueprints.duplicate(),
		"room_potions": p.room_potions.duplicate(true), "active_potion": p.active_potion,
		"potion_rotation": p.potion_rotation.duplicate(), "bags": p.bags.duplicate(true),
		"bag_used": p.bag_used(), "bag_capacity": p.bag_capacity(), "position": _vec(p.global_position),
		"chapter": game.chapter_id, "room": game.cur_room, "run_tier": game.run_tier(),
		"character_tier": p.run_tier, "god": game.dev_god,
		"physics": p.is_physics_processing(), "dead": p.dead, "motion_faults": p.motion_faults}


func _mark(label: String) -> void:
	report.milestones.append({"label": label, "seconds": (Time.get_ticks_msec() - begun) / 1000.0, "hero": _hero()})
	_write_report()


func _stop(outcome: String, reason: String) -> String:
	_record_boss_trace(true, "stop:" + outcome) # observe before the existing key release
	_release()
	report.outcome = outcome
	return reason


func _capture(label: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	var scenario := "fresh level1/ch1; actual earned progression and native upkeep" if fresh_ch1 else "posed level6/ch2 start"
	shot(label, scenario + "; ordinary-input collection/brewing/combat sample; no full campaign claim")


func _write_report() -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir)) != OK:
		return false
	var file := FileAccess.open(shot_dir.path_join("journey.json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return true


func _vec(value: Vector2) -> Array:
	return [value.x, value.y]
