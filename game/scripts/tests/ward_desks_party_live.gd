extends RefCounted
## Filtered ward desks through the existing two-game road_hunt ENet fixture.
## The caller owns the transports; this module restores its state and save bytes.

const GAME_FIELDS := ["contracts", "contract_day", "contract_claims_day", "bounties",
	"bounty_day", "bounty_week", "clock_anchor", "vault_week", "vault_progress",
	"vault_claimed_week", "settings", "no_saves"]
const PLAYER_FIELDS := ["gold", "level", "resonance", "faction_standing", "npc_favor", "hp", "mp"]
const JOURNAL_META := ["journal_tab", "journal_ward", "journal_notice"]


static func run(r: Node) -> String:
	var keep: Array[Dictionary] = []
	var files := {}
	var shown: Game = r.game
	for g in r.readers:
		var state := {"game": {}, "player": {}, "meta": {}}
		for key in GAME_FIELDS:
			state.game[key] = g.get(key)
		for key in PLAYER_FIELDS:
			state.player[key] = g.player.get(key)
		for key in JOURNAL_META:
			if g.menus.has_meta(key):
				state.meta[key] = g.menus.get_meta(key)
		keep.append(state)
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SaveGame.path(r.SLOT) + suffix
		files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var result := await _checks(r)
	if result != "":
		await r._capture("ward_desks_party_failure")
	# Every assertion returns through here, including failures after a real save.
	for g in r.readers:
		g.menus.close()
		g.no_saves = true
	await r.frames(3)
	for i in r.readers.size():
		var g: Game = r.readers[i]
		for key in GAME_FIELDS:
			if key != "no_saves":
				g.set(key, keep[i].game[key])
		for key in PLAYER_FIELDS:
			g.player.set(key, keep[i].player[key])
		g.player.recalc()
		g.player.hp = keep[i].player.hp
		g.player.mp = keep[i].player.mp
		for key in JOURNAL_META:
			if keep[i].meta.has(key):
				g.menus.set_meta(key, keep[i].meta[key])
			elif g.menus.has_meta(key):
				g.menus.remove_meta(key)
		g.refresh_touch_mode()
		g._apply_touch_mode()
		if g == shown:
			r._show(i)
	for path in files:
		if files[path] == null:
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				result += " ward desk fixture could not remove its temporary save"
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				result += " ward desk fixture could not restore its save"
			else:
				file.store_buffer(files[path])
				file.close()
	for i in r.readers.size():
		r.readers[i].no_saves = keep[i].game.no_saves
	if result == "":
		print("ok: selected ward ENet credit, exact own claims/home save, shared cap, live quote/focus/scroll, touch selectors, stale callback rollover and watcher cleanup")
	return result


static func _seed(g: Game) -> Dictionary:
	# Use the real data factory and retain its actual Dictionary entries. Search
	# a bounded seed range for the room deed rather than inventing a fake deed.
	var tracking: Dictionary = {}
	for seed_value in 32:
		g.contracts = []
		for ward in Balance.WARD_CONTRACT_WARDS:
			g._roll_contracts(String(ward), Balance.WARD_CONTRACT_PER_WARD, seed_value)
		for c in g.contracts:
			if String(c.ward) == "accord" and String(c.type) == "rooms_cleared":
				tracking = c
		if not tracking.is_empty():
			break
	for c in g.contracts:
		c.done = true
		c.progress = c.target
	g.contract_day = g.daily_day_index()
	g.contract_claims_day = Balance.WARD_CONTRACT_DAILY_CAP - 2
	g.bounties = []
	g._roll_bounties("daily", Balance.BOUNTY_DAILY_COUNT, 84)
	g._roll_bounties("weekly", Balance.BOUNTY_WEEKLY_COUNT, 84)
	for bounty in g.bounties:
		bounty.done = true # Authority room credit must not pay an unrelated bounty.
		bounty.progress = bounty.target
	g.bounty_day = g.contract_day
	g.bounty_week = int(g.contract_day / 7)
	g.vault_claimed_week = g._week_index()
	g.settings = g.settings.duplicate(true)
	g.player.faction_standing = g.player.faction_standing.duplicate(true)
	g.player.npc_favor = g.player.npc_favor.duplicate(true)
	return tracking


static func _button(g: Game, name: String) -> Button:
	return g.menus.root.find_child(name, true, false) as Button


static func _card(g: Game, c: Dictionary) -> Control:
	return g.menus.root.find_child("ContractCard_" + String(c.ward) + "_" + String(c.type), true, false) as Control


static func _text(node: Node) -> String:
	var lines: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		lines.append(String(label.text))
	return "\n".join(lines)


static func _selected(g: Game, ward: String) -> String:
	if g.menus.current != "journal" or String(g.menus.get_meta("journal_tab", "")) != "activities" \
		or String(g.menus.get_meta("journal_ward", "")) != ward:
		return "journal lost the selected " + ward + " ward"
	var cards := g.menus.root.find_children("ContractCard_*", "Control", true, false)
	var expected := 0
	for c in g.contracts:
		if ward == "" or String(c.ward) == ward:
			expected += 1
			if _card(g, c) == null:
				return "selected ward omitted a current contract"
	if cards.size() != expected:
		return "selected ward leaked other wards or duplicated contract cards"
	var heading := g.menus.root.find_child("JournalWardHeading", true, false) as Label
	var allowance := g.menus.root.find_child("JournalWardAllowance", true, false) as Label
	if heading == null or allowance == null:
		return "ward desk lacks its heading or shared allowance"
	if ward != "" and not ward in heading.text.to_lower() \
		and not String(Balance.WARD_CONTRACT_WARD_NAME[ward]).to_lower() in heading.text.to_lower():
		return "ward heading does not identify its selected ward"
	var remaining := maxi(0, Balance.WARD_CONTRACT_DAILY_CAP - g.contract_claims_day)
	if not ("%d of %d" % [remaining, Balance.WARD_CONTRACT_DAILY_CAP]) in allowance.text \
		or not "all wards" in allowance.text.to_lower():
		return "selected ward does not quote the hero-wide remaining allowance"
	return ""


static func _fit(g: Game) -> String:
	var tabs := g.menus.root.find_child("JournalTabs", true, false) as Control
	var scroll := g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	if tabs == null or scroll == null or not g.menus._shell_rect.grow(1).encloses(tabs.get_global_rect()) \
		or not g.menus._shell_rect.grow(1).encloses(scroll.get_global_rect()):
		return "ward desk tabs or scroll escaped the journal shell"
	for name in ["JournalWard_all", "JournalWard_wildfang", "JournalWard_choir", "JournalWard_accord", "JournalWard_cinderborn"]:
		var button := _button(g, name)
		if button == null or button.size.y < 44.0 or button.custom_minimum_size.y < 44.0:
			return "ward selector is missing or too small for touch: " + name
		if not g.menus._shell_rect.grow(1).encloses(button.get_global_rect()):
			return "ward selector escaped the journal shell: " + name
	for button in g.menus.root.find_children("ContractClaim_*", "Button", true, false):
		if button.custom_minimum_size.y < 44.0 or button.size.y < 44.0:
			return "filtered ward claim is too small for touch"
	return ""


static func _focus_and_scroll(g: Game, name: String, offset: int) -> String:
	var focus := g.menus.get_viewport().gui_get_focus_owner()
	var scroll := g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	if focus == null or String(focus.name) != name or not g.menus.root.is_ancestor_of(focus):
		return "live selected-ward refresh lost stable keyboard/controller focus"
	var maximum := maxi(0, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))
	if absi(scroll.scroll_vertical - mini(offset, maximum)) > 1:
		return "live selected-ward refresh lost or failed to clamp scroll position"
	return _selected(g, "accord")


static func _checks(r: Node) -> String:
	var host: Game = r.readers[0]
	var g: Game = r.readers[1]
	var home := SaveGame.world_of(SaveGame.read(r.SLOT)).duplicate(true)
	host.menus.close()
	g.menus.close()
	_seed(host)
	var tracking := _seed(g)
	if tracking.is_empty():
		return "ward desk fixture could not roll an Accord room deed"
	tracking.progress = int(tracking.target) - 2
	tracking.done = false
	g.player.level = 20
	g.player.resonance = 0.0
	g.player.recalc()
	var chosen: Dictionary = {}
	for c in g.contracts:
		if String(c.ward) == "accord" and bool(c.done):
			chosen = c
	if chosen.is_empty():
		return "ward desk fixture lacks a ready Accord choice"
	r._show(1)
	g.menus.open_journal("activities", "accord")
	await r.frames(4)
	var error := _selected(g, "accord")
	if error == "":
		error = _fit(g)
	if error != "":
		return error
	if r.get_tree().paused:
		return "selected ward paused the live party"
	var claim_name := "ContractClaim_accord_" + String(chosen.type)
	var claim := _button(g, claim_name)
	if claim == null or claim.disabled:
		return "selected ward has no usable ready claim"
	claim.grab_focus()
	var scroll := g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 160
	await r.frames(2)
	var offset := scroll.scroll_vertical
	var old_shell := g.menus.root.get_instance_id()
	g.player.level += 1
	g.player.recalc()
	await r.get_tree().create_timer(0.7, true).timeout
	if g.menus.root.get_instance_id() == old_shell:
		return "selected ward kept a stale live gold quote"
	error = _focus_and_scroll(g, claim_name, offset)
	if error != "":
		return error
	if not ("Reward  ·  %d gold" % g.activity_gold(int(chosen.gold))) in _text(_card(g, chosen)):
		return "filtered card gold quote disagrees with its actual payout"
	# Favor quotes must follow the same resonance rounding as the real reward.
	for resonance in [Story.RES_BAND_AT, -Story.RES_BAND_AT, 0.0]:
		g.player.resonance = resonance
		await r.get_tree().create_timer(0.7, true).timeout
		var multiplier := Balance.FAVOR_RES_STEADY_MULT if resonance > 0.0 else Balance.FAVOR_RES_TEMPTED_MULT if resonance < 0.0 else 1.0
		var quoted_favor := maxi(1, int(round(Balance.WARD_CONTRACT_FAVOR * multiplier)))
		if not ("+ %d Kesh favor" % quoted_favor) in _text(_card(g, chosen)):
			return "selected Accord card kept a stale or inexact resonance-scaled favor quote"
	g.player.faction_standing["accord"] = int(g.player.faction_standing.get("accord", 0)) + 2
	g.player.npc_favor["kesh"] = int(g.player.npc_favor.get("kesh", 0)) + 1
	await r.get_tree().create_timer(0.7, true).timeout
	var status := g.menus.root.find_child("JournalWardStanding", true, false) as Label
	if status == null or not ("Accord standing: %d" % int(g.player.faction_standing.accord)) in status.text \
		or not ("Kesh favor: %d" % int(g.player.npc_favor.kesh)) in status.text:
		return "selected ward kept stale live standing or favor totals"
	error = _focus_and_scroll(g, claim_name, offset)
	if error != "":
		return error
	await r._capture("ward_desks_party_01_live_quote_focus")
	var host_rewards := [host.player.gold, host.player.faction_standing.duplicate(true),
		host.player.npc_favor.duplicate(true), host.contracts.duplicate(true), host.contract_claims_day]
	var gold := g.player.gold
	var standing := g.player.faction_standing.duplicate(true)
	var favor := g.player.npc_favor.duplicate(true)
	var expected_gold := g.activity_gold(int(chosen.gold))
	_button(g, claim_name).pressed.emit()
	await r.frames(4)
	standing["accord"] = int(standing.get("accord", 0)) + Balance.WARD_CONTRACT_STANDING
	favor["kesh"] = int(favor.get("kesh", 0)) + Balance.WARD_CONTRACT_FAVOR
	var count := 0
	for c in g.contracts:
		count += int(c.claimed)
	if not chosen.claimed or count != 1 or g.contract_claims_day != Balance.WARD_CONTRACT_DAILY_CAP - 1 \
		or g.player.gold != gold + expected_gold or g.player.faction_standing != standing or g.player.npc_favor != favor:
		return "filtered claim lost original entry identity or paid anything besides the chosen exact reward"
	if [host.player.gold, host.player.faction_standing, host.player.npc_favor,
		host.contracts, host.contract_claims_day] != host_rewards:
		return "the guest's filtered claim changed the host's rewards or board"
	var saved := SaveGame.read(r.SLOT)
	var character := SaveGame.character_of(saved)
	var saved_board: Variant = JSON.parse_string(JSON.stringify(g.contracts))
	var saved_standing: Variant = JSON.parse_string(JSON.stringify(g.player.faction_standing))
	var saved_favor: Variant = JSON.parse_string(JSON.stringify(g.player.npc_favor))
	if SaveGame.world_of(saved) != home or character.get("contracts", []) != saved_board \
		or int(character.get("gold", -1)) != g.player.gold \
		or int(character.get("contract_day", -1)) != g.contract_day \
		or int(character.get("contract_claims_day", -1)) != g.contract_claims_day \
		or character.get("faction_standing", {}) != saved_standing \
		or character.get("npc_favor", {}) != saved_favor:
		return "filtered claim failed exact guest character save or changed its home world"
	error = _selected(g, "accord")
	if error != "":
		return error
	var focus := g.menus.get_viewport().gui_get_focus_owner()
	if focus == null or not g.menus.root.is_ancestor_of(focus):
		return "claiming a selected deed left focus on its freed claim control"
	await r._capture("ward_desks_party_02_own_claim_saved")
	_button(g, "JournalWard_accord").grab_focus()
	scroll = g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 160
	await r.frames(2)
	offset = scroll.scroll_vertical
	var progress := int(tracking.progress)
	g.contract_progress("rooms_cleared")
	if int(tracking.progress) != progress:
		return "guest local code invented filtered contract progress"
	for credit in 2:
		r.wires[0].host_party_credit("room")
		await r.get_tree().create_timer(0.7, true).timeout
		if int(tracking.progress) != progress + credit + 1 or bool(tracking.done) != (credit == 1):
			return "real ENet room credit did not advance the selected guest deed exactly once"
		error = _focus_and_scroll(g, "JournalWard_accord", offset)
		if error != "":
			return error
		var meter := _card(g, tracking).find_child("JournalMeter", true, false) as ProgressBar
		if meter == null or int(meter.value) != int(tracking.progress):
			return "selected ward did not repaint authoritative room progress"
	await r._capture("ward_desks_party_03_credit_while_reading")
	# Keep the real enabled callbacks while the old node can still be read.
	# Calling them after rollover exercises the reference identity guard even
	# though the watcher has already freed yesterday's displayed button.
	var stale_callbacks: Array[Callable] = []
	claim = _button(g, "ContractClaim_accord_" + String(tracking.type))
	if claim == null or claim.disabled:
		return "completed selected deed did not gain a claim control"
	for connection in claim.pressed.get_connections():
		stale_callbacks.append(connection.callable)
	if stale_callbacks.is_empty():
		return "completed selected deed has no claim callback to retain"
	g.settings["touch_controls"] = true
	g.refresh_touch_mode()
	g._apply_touch_mode()
	_button(g, "JournalWard_choir").pressed.emit()
	await r.frames(4)
	error = _selected(g, "choir")
	if error == "":
		error = _fit(g)
	if error != "":
		return error
	if g._touch_hud == null or g._touch_hud.visible or g._touch_hud._enabled or r.get_tree().paused:
		return "selected ward failed the unpaused co-op touch overlay gate"
	scroll = g.menus.root.find_child("JournalScroll", true, false) as ScrollContainer
	if scroll.scroll_vertical != 0:
		return "explicit ward selection retained the previous ward's scroll offset"
	await r._capture("ward_desks_party_04_touch_choir")
	var choir_claims := g.menus.root.find_children("ContractClaim_choir_*", "Button", true, false)
	if choir_claims.is_empty() or choir_claims[0].disabled:
		return "switching wards hid the final shared claim choice"
	choir_claims[0].pressed.emit()
	await r.frames(4)
	if g.contract_claims_day != Balance.WARD_CONTRACT_DAILY_CAP or g.contracts_claimable() != 0:
		return "a different ward did not consume the hero's final shared choice"
	for ward in Balance.WARD_CONTRACT_WARDS:
		_button(g, "JournalWard_" + String(ward)).pressed.emit()
		await r.frames(3)
		error = _selected(g, String(ward))
		if error != "":
			return error
		for button in g.menus.root.find_children("ContractClaim_*", "Button", true, false):
			if not button.disabled:
				return "another ward offered a claim after the shared daily cap"
	_button(g, "JournalWard_all").pressed.emit()
	await r.frames(3)
	error = _selected(g, "")
	if error != "":
		return error
	await r._capture("ward_desks_party_05_all_choices_used")
	g.menus.open_journal("activities", "accord")
	await r.frames(3)
	_button(g, "JournalWard_accord").grab_focus()
	var next_day := g.daily_day_index() + 1
	g.clock_anchor = next_day * 86400
	await r.get_tree().create_timer(0.7, true).timeout
	if g.contract_day != next_day or g.contract_claims_day != 0 or g.contracts_claimable() != 0:
		return "selected ward rollover retained yesterday's board or allowance"
	error = _selected(g, "accord")
	if error != "":
		return error
	gold = g.player.gold
	standing = g.player.faction_standing.duplicate(true)
	favor = g.player.npc_favor.duplicate(true)
	var fresh_board := g.contracts.duplicate(true)
	for callback in stale_callbacks:
		callback.call()
	await r.frames(4)
	if tracking.claimed or g.player.gold != gold or g.player.faction_standing != standing \
		or g.player.npc_favor != favor or g.contract_claims_day != 0 or g.contracts != fresh_board:
		return "retained filtered claim callback paid yesterday's deed or consumed today's allowance"
	error = _selected(g, "accord")
	if error != "":
		return error
	if not "contract expired" in _text(g.menus.root):
		return "expired filtered callback did not explain its rejection in the selected ward"
	await r._capture("ward_desks_party_06_retained_callback_rollover")
	var retired_shell: WeakRef = weakref(g.menus.root)
	g.menus.close()
	g.player.level += 1
	await r.get_tree().create_timer(0.7, true).timeout
	if retired_shell.get_ref() != null or g.menus.root != null or g.menus.current != "":
		return "a closed selected ward retained or reopened its live watcher"
	g.menus.open_journal("activities")
	await r.frames(4)
	error = _selected(g, "")
	if error != "":
		return "ordinary Activities reopen kept a stale ward filter: " + error
	await r._capture("ward_desks_party_07_generic_reopen")
	return ""
