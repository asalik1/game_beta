extends RefCounted
## Road bargains are choices, not destructive-action confirmation prompts.
const GOOD := Color(0.72, 0.91, 0.70)

class Lifetime extends Node:
	var menus: Menus
	var actor: Variant
	var room := -1
	var shell: Control
	func _process(_delta: float) -> void:
		if menus.root != shell:
			set_process(false)
		elif not menus.game._road_can_choose(room, actor):
			menus.close()


static func guard(m: Menus, actor: Node2D, room: int) -> void:
	m.root.set_meta("road_offer", actor.get_instance_id())
	var lifetime := Lifetime.new()
	lifetime.name = "RoadChoiceLifetime"
	lifetime.menus = m
	lifetime.actor = actor
	lifetime.room = room
	lifetime.shell = m.root
	lifetime.process_mode = Node.PROCESS_MODE_ALWAYS
	m.root.add_child(lifetime)


static func reading(m: Menus, actor: Node2D) -> bool:
	return is_instance_valid(m.root) and m.current in ["road_choice", "wager"] \
		and m.root.get_meta("road_offer", 0) == actor.get_instance_id()


static func open(m: Menus, actor: Node2D, room: int, id: String, body: String, options: Array) -> void:
	var card := RoadDeck.card(id)
	var box := m._open(String(card.title), 860, 530, true)
	m.current = "road_choice"
	guard(m, actor, room)
	var shell := m.root
	var intro := HBoxContainer.new()
	intro.add_theme_constant_override("separation", 24)
	box.add_child(intro)
	var portrait := TextureRect.new()
	portrait.texture = Art.tex(String(card.sprite))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(112, 136)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 12)
	intro.add_child(words)
	_copy(m, words, body, 17)
	m._lbl(words, "Purse: %d gold" % m.game.player.gold, 15, UITheme.GOLD_BRIGHT)
	UITheme.rule(box)
	for option in options:
		var action: Callable = option.action
		var button := m._btn(box, String(option.title), func() -> void:
			if m.root != shell:
				return
			m.close()
			action.call(), option.get("color", GOOD), bool(option.get("enabled", true)))
		button.custom_minimum_size.y = 46
		_copy(m, box, String(option.detail), 15)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var leave := m._btn(box, "Leave — keep walking", func() -> void:
		if m.root == shell:
			m.close(), Color(0.79, 0.83, 0.88))
	leave.custom_minimum_size.y = 44
	m._hint(box, "Leaving or pressing Escape costs nothing.")


static func _copy(m: Menus, parent: Control, text: String, pixels: int) -> void:
	var label := m._lbl(parent, text, pixels, Color(0.83, 0.84, 0.80))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
