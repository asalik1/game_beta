extends RefCounted
const Pad := preload("res://scripts/gamepad.gd")


class ReadyHUD extends Hud:
	func _ready() -> void:
		pass # Exercise the production card without constructing the combat HUD.


class ReadySession extends Node:
	var hud: Hud
	var answers: Array[bool] = []
	func answer_ready(ok: bool) -> void:
		answers.append(ok)
		if ok:
			hud._show_ready_card(self, {"chapter": "ch1", "answered": true})
		else:
			hud._hide_ready_card()


static func run(t: Node) -> String:
	for dz in [0.08, 0.18, 0.4]:
		for degrees in range(0, 360, 5):
			var dir := Vector2.RIGHT.rotated(deg_to_rad(degrees))
			if Pad.radial(dir * dz * 0.99, dz) != Vector2.ZERO:
				return "stick drift crossed the radial deadzone"
			var half := Pad.radial(dir * lerpf(dz, 1.0, 0.5), dz)
			if not is_equal_approx(half.length(), 0.5) or half.normalized().dot(dir) < 0.999:
				return "gentle walking lost its magnitude or direction"
			if not is_equal_approx(Pad.radial(dir * 2, dz).length(), 1.0):
				return "diagonal input exceeded or failed to reach full speed"
	if Pad.radial(Vector2(NAN, 1), 0.18) != Vector2.ZERO or Pad.radial(Vector2.INF, 0.18) != Vector2.ZERO:
		return "invalid device axes reached movement"
	var p := Pad.new()
	p.buttons = {JOY_BUTTON_A: true}
	if p.held("interact") or p.movement() != Vector2.ZERO:
		p.free()
		return "an inactive controller contributed held input"
	# Text-only reader: never added to the tree, no device, network or save.
	var reader := Game.new()
	reader.gamepad = p
	p.game = reader
	var copy_error := _prompt_copy(reader, p)
	reader.gamepad = null
	p.game = null
	reader.free()
	p.free()
	if copy_error != "":
		return copy_error
	var ready_error := _ready_fixture(t)
	if ready_error != "":
		return ready_error
	print("ok: controller Ready/Decline, waiting/hidden/menu/keyboard gates, victory/downed/chat/choice/dialogue priority, card and hint labels, held-Y isolation")
	print("ok: whole-key touch/controller copy plus gamepad radial deadzone, 216 directions, analog speed caps, invalid axes and inactive-device isolation")
	return ""


static func _ready_fixture(t: Node) -> String:
	# All input, HUD and player state belongs to this disposable reader. Cleanup
	# lives outside the assertion helper, including its early failure returns.
	var g := Game.new()
	g.hud = ReadyHUD.new()
	g.hud.game = g
	g.menus = Menus.new()
	g.menus.game = g
	g.local_player = Player.new()
	g.play_started = true
	g.state = Game.ST_PLAYING
	var pad := Pad.new()
	g.gamepad = pad
	pad.game = g
	t.add_child(g.hud)
	t.add_child(pad)
	pad.set_process(false)
	pad.set_process_input(false)
	pad.active = true
	g.settings["pad_labels"] = "xbox"
	var sess := ReadySession.new()
	sess.hud = g.hud
	var error := _ready_checks(g, pad, sess)
	if g.menus.root != null:
		g.menus.root.free()
		g.menus.root = null
	# The loose keyboard stand-in is never parented, so pad.free() cannot reach
	# it when the keyboard-priority check fails before B closes it.
	if is_instance_valid(pad.ui.key_root) and pad.ui.key_root.get_parent() == null:
		pad.ui.key_root.free()
		pad.ui.key_root = null
	pad.free()
	g.hud.free()
	g.menus.free()
	g.local_player.free()
	sess.free()
	g.free()
	return error


static func _ready_checks(g: Game, pad: Node, sess: ReadySession) -> String:
	var h: Hud = g.hud
	h._show_ready_card(sess, {"chapter": "ch1"})
	pad.ui.refresh_hints()
	if pad.ui.hints.text != "Y: Ready · B: Decline":
		return "unanswered ready card lacks controller hints"
	if h.ready_yes.text != "  Y  Ready  " or h.ready_no.text != "  B  Decline  ":
		return "ready card buttons lack controller labels: %s / %s" % [h.ready_yes.text, h.ready_no.text]
	g.settings["pad_labels"] = "playstation"
	pad.ui.refresh_hints()
	if pad.ui.hints.text != "△: Ready · ○: Decline":
		return "ready card ignores PlayStation button labels"
	if h.ready_yes.text != "  △  Ready  " or h.ready_no.text != "  ○  Decline  ":
		return "ready card buttons ignore PlayStation labels: %s / %s" % [h.ready_yes.text, h.ready_no.text]
	g.settings["pad_labels"] = "xbox"
	pad.active = false
	pad.ui.refresh_hints()
	var idle_copy := [h.ready_yes.text, h.ready_no.text]
	pad.active = true
	pad.ui.refresh_hints()
	if idle_copy != ["  ✓  Ready  ", "  ✕  Decline  "] or h.ready_yes.text != "  Y  Ready  ":
		return "ready card buttons did not follow the active device: %s" % [idle_copy]
	pad.buttons = {JOY_BUTTON_A: true, JOY_BUTTON_Y: true}
	if not pad.held("interact") or pad.held("potion_next"):
		return "ready card stole interact/revive or let Y cycle potions"
	pad._button(JOY_BUTTON_Y, false)
	if not sess.answers.is_empty():
		return "ready card answered on a button release"
	pad._button(JOY_BUTTON_Y, true)
	if sess.answers != [true]:
		return "Y did not answer the ready check once"
	if pad.held("potion_next"):
		return "held Y leaked into potion cycling after the answer rebuilt the card"
	pad._button(JOY_BUTTON_Y, true)
	if sess.answers != [true]:
		return "waiting card retained stale answer buttons"
	pad._button(JOY_BUTTON_Y, false)
	if not pad.held("potion_next"):
		return "releasing the answer did not restore ordinary potion cycling"
	h._show_ready_card(sess, {"chapter": "ch1"})
	g.local_player.intent_lock_release = false
	pad._button(JOY_BUTTON_B, true)
	if sess.answers != [true, false] or g.local_player.intent_lock_release:
		return "B did not decline exclusively"
	pad._button(JOY_BUTTON_B, true)
	if not g.local_player.intent_lock_release or sess.answers != [true, false]:
		return "B did not resume releasing target lock after card dismissal"
	for data in [{"chapter": "ch1", "mine": true}, {"chapter": "ch1", "answered": true}]:
		h._show_ready_card(sess, data)
		pad._button(JOY_BUTTON_Y, true)
		pad._button(JOY_BUTTON_B, true)
		if sess.answers != [true, false]:
			return "host/answered card accepted an answer"
	h._show_ready_card(sess, {"chapter": "ch1"})
	h.visible = false
	pad._button(JOY_BUTTON_Y, true)
	h.visible = true
	g.menus.root = Control.new()
	pad._button(JOY_BUTTON_Y, true)
	g.menus.root.free()
	g.menus.root = null
	pad.ui.key_root = Control.new()
	pad._button(JOY_BUTTON_B, true)
	if sess.answers != [true, false] or pad.ui.keyboard_open():
		return "hidden card/menu/keyboard priority lost to ready check"
	pad._button(JOY_BUTTON_Y, true)
	if sess.answers != [true, false, true]:
		return "ready card could not be answered after the overlays closed"
	pad._button(JOY_BUTTON_Y, false)
	var state_error := _ready_play_states(g, pad, sess)
	if state_error != "":
		return state_error
	h._hide_ready_card()
	pad.ui.refresh_hints()
	if "Ready" in pad.ui.hints.text:
		return "dismissed card retained ready hints"
	return ""


## The ready branch sits above chat, choices, dialogue, the victory card and
## the _can_play gate. Pin that order: Y answers from every one of them, B
## declines on the victory card but never while chat, a choice or dialogue
## is up (open chat keeps B for closing itself). Each loaned field is put back
## before its assertion so later cases start from ordinary play.
static func _ready_play_states(g: Game, pad: Node, sess: ReadySession) -> String:
	var h: Hud = g.hud
	var want: Array = sess.answers.duplicate()
	# A guest still reading their victory results is the brief's trigger.
	g.state = Game.ST_VICTORY
	h._show_ready_card(sess, {"chapter": "ch1"})
	pad._button(JOY_BUTTON_Y, true)
	pad._button(JOY_BUTTON_Y, false)
	h._show_ready_card(sess, {"chapter": "ch1"})
	pad._button(JOY_BUTTON_B, true)
	g.state = Game.ST_PLAYING
	want.append_array([true, false])
	if sess.answers != want:
		return "victory results screen could not answer the ready check: %s" % [sess.answers]
	for field in ["downed", "ghost"]:
		g.local_player.set(field, true)
		h._show_ready_card(sess, {"chapter": "ch1"})
		pad._button(JOY_BUTTON_Y, true)
		pad._button(JOY_BUTTON_Y, false)
		g.local_player.set(field, false)
		want.append(true)
		if sess.answers != want:
			return "a %s player could not answer Ready" % field
	# Open chat: B closes chat and leaves the check alone; the next B declines.
	h._show_ready_card(sess, {"chapter": "ch1"})
	h.chat_active = true
	pad.ui.refresh_hints()
	var chat_hint: String = pad.ui.hints.text
	pad._button(JOY_BUTTON_B, true)
	var chat_closed := not h.chat_active
	var card_kept := h.ready_card_active()
	h.chat_active = false
	if chat_hint != "Y: Ready · B: close chat" or not chat_closed or not card_kept or sess.answers != want:
		return "B in open party chat touched the ready check (hint '%s', chat closed %s, answers %s)" % [chat_hint, chat_closed, sess.answers]
	pad._button(JOY_BUTTON_B, true)
	want.append(false)
	if sess.answers != want:
		return "B did not decline once party chat was closed"
	# Chat, choices and dialogue: B never declines and Y still answers Ready.
	var tails := {"chat_active": "Y: Ready · B: close chat",
		"choices_active": "D-pad ↑ ↓: choose   •   A: confirm   •   Y: Ready",
		"dialogue_active": "A: reveal / continue   •   Y: Ready"}
	for field in tails:
		h._show_ready_card(sess, {"chapter": "ch1"})
		h.set(field, true)
		if field != "chat_active":
			pad._button(JOY_BUTTON_B, true)
		var kept := h.ready_card_active() and sess.answers == want
		pad.ui.refresh_hints()
		var hint: String = pad.ui.hints.text
		# The card stops promising B while B has another job.
		var card_copy := [h.ready_yes.text, h.ready_no.text]
		pad._button(JOY_BUTTON_Y, true)
		pad._button(JOY_BUTTON_Y, false)
		h.set(field, false)
		want.append(true)
		if not kept or hint != tails[field] or sess.answers != want:
			return "%s: B declined or Y did not answer (hint '%s', answers %s)" % [field, hint, sess.answers]
		if card_copy != ["  Y  Ready  ", "  ✕  Decline  "]:
			return "%s: ready card still labels B as Decline: %s" % [field, card_copy]
	return ""


static func _prompt_copy(g: Game, pad: Node) -> String:
	g.settings["pad_labels"] = "xbox"
	var untouched := [
		"Close this panel or press ESC — your party session stays active",
		"Close this panel or press ESC — you stay with the party",
		"and press ESC; Press ESC; hold ESC; Hold ESC",
		"press ECHO; press E1; press Quarter; Press Tactics; press Spacebar",
		"depress E; depress Q; withhold T",
	]
	var prompts := [
		["walk up to her and press E", "walk up to her and tap Act", "walk up to her and press A"],
		["walk up to him and press E.", "walk up to him and tap Act.", "walk up to him and press A."],
		["and press E", "and tap Act", "and press A"],
		["Hold E — Pull the cart", "Hold Act — Pull the cart", "Hold A — Pull the cart"],
		["press E or press ESC", "tap or press ESC", "press A or press ESC"],
		["press E, press Q; press Space; press T.", "tap, tap the potion button; tap; tap Skills.", "press A, press X; press A; press D-pad →."],
		["Press Q / Press Space", "Tap the potion button / Tap", "Press X / Press A"],
		["E — Talk", "Talk", "A — Talk"],
	]
	for mode in ["keyboard", "touch", "pad"]:
		g.touch_mode = mode == "touch"
		pad.active = mode == "pad"
		for text in untouched:
			if g.touchify(text) != text or g.ui_copy(text) != text:
				return "%s copy rewrote part of a longer word/key: %s" % [mode, text]
		for row in prompts:
			var column := 1 if mode == "touch" else (2 if mode == "pad" else 0)
			if g.touchify(row[0]) != row[column]:
				return "%s copy lost a complete key prompt: %s" % [mode, row[0]]
	return ""
