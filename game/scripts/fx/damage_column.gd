extends Node2D
## Presentation only. All tweens are label-bound and explicitly killed on retirement.
var game: Node
var target_ref: WeakRef
var target_id: int
var room: int
var clock := 0.0
var rise := 0.0
var anchor := Vector2.ZERO # the target's last live position
var detached := false # target died or was freed: the column stays where it fell
var entries: Array[Dictionary] = [] # newest row first


func _process(delta: float) -> void:
	# A room change is the only hard stop; the numbers belong to the room left behind.
	if game.cur_room != room:
		retire()
		return
	clock += delta
	rise = minf(Balance.DAMAGE_NUM_RISE_MAX, rise + delta * Balance.DAMAGE_NUM_RISE_SPEED)
	if not detached:
		var target: Node2D = target_ref.get_ref()
		if not is_instance_valid(target) or target.is_queued_for_deletion() \
				or (target is Enemy and target.dying):
			# The killing blow and any running total play out their full life where it fell.
			detached = true
		else:
			anchor = target.global_position
	global_position = anchor + Vector2(0, -Balance.DAMAGE_NUM_HEIGHT - rise)


func hit(amount: int, crit: bool, dot: bool, ally: bool) -> void:
	var kind := "dot" if dot else ("crit" if crit else "normal")
	# Your direct crits stand alone so they read. Ticks build one running total per
	# owner (the window spans the DoT cadence). An ally's blows, crits included,
	# share one quiet row so a friend never reshapes your own stack.
	var group := "dot" if dot else ("ally" if ally else kind)
	var window := Balance.DAMAGE_NUM_DOT_MERGE if dot else Balance.DAMAGE_NUM_MERGE
	if group != "crit":
		for entry in entries:
			if entry.group == group and entry.ally == ally and clock - entry.last <= window:
				entry.total += amount
				entry.last = clock
				if crit and not dot and not entry.crit:
					entry.crit = true
					_style(entry)
				# The density cap evicts the longest-idle number, never a live total.
				game._float_nums.erase(entry.label)
				game._float_nums.append(entry.label)
				_pop(entry)
				return
	_add_entry({"kind": kind, "group": group, "ally": ally, "crit": crit and not dot,
		"total": amount, "shown": float(amount), "last": clock, "row": 0.0})


## Repeated words refresh one row; signed hits/heals retain their color and sum.
func text(message: String, color: Color) -> void:
	var numeric: int = game._float_kind(message)
	var prefix := "+" if message.begins_with("+") else ""
	var suffix := " CRIT!" if message.ends_with(" CRIT!") else ("!" if numeric == 2 else "")
	var amount := message.to_int() if numeric > 0 else 0
	var group := "text:" + (prefix + suffix + str(signi(amount)) if numeric > 0 else message)
	for entry in entries:
		if entry.group == group and entry.get("color") == color and clock - entry.last <= Balance.DAMAGE_NUM_MERGE:
			entry.total += amount
			entry.last = clock
			if _capped(entry):
				game._float_nums.erase(entry.label)
				game._float_nums.append(entry.label)
			_pop(entry)
			return
	_add_entry({"kind": "text", "group": group, "ally": false, "crit": numeric == 2,
		"total": amount, "shown": float(amount), "last": clock, "row": 0.0,
		"message": message, "color": color, "numeric": numeric, "prefix": prefix,
		"suffix": suffix})


## Only numbers join the global density cap. Words (mechanic tells, boss
## instructions, status) were never capped, so a burst of AoE numbers can't
## evict a dodge warning before it is read.
func _capped(entry: Dictionary) -> bool:
	return entry.kind != "text" or int(entry.numeric) > 0


func _add_entry(entry: Dictionary) -> void:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_as_relative = false
	l.z_index = Balance.COMBAT_TEXT_Z
	l.set_meta("damage_column", self)
	entry.label = l
	_style(entry)
	add_child(l)
	entries.push_front(entry)
	_update_value(float(entry.total), entry)
	# Enter from the row below: even during the shift, digits never share a row.
	l.position.y = entries[1].label.position.y + Balance.DAMAGE_NUM_ROW if entries.size() > 1 else 0.0
	_restack()
	_pop(entry)
	if _capped(entry):
		game._float_nums.append(l)
		while game._float_nums.size() > Balance.FLOAT_NUM_MAX:
			game._retire_float_num(game._float_nums.front())
	_process(0.0)


func _style(entry: Dictionary) -> void:
	var l: Label = entry.label
	var size := Balance.DAMAGE_NUM_SIZE
	var color := Balance.DAMAGE_NUM_NORMAL
	var outline := Balance.DAMAGE_NUM_OUTLINE
	if entry.kind == "text":
		color = game._floor_text_color(entry.color)
		if entry.numeric == 0:
			size = Balance.COMBAT_TEXT_LONG_SIZE if entry.message.length() > Balance.COMBAT_TEXT_LONG_LENGTH else Balance.COMBAT_TEXT_SIZE
			outline = Balance.COMBAT_TEXT_OUTLINE
		elif entry.crit:
			size = Balance.DAMAGE_NUM_CRIT_SIZE
	elif entry.kind == "dot":
		size = Balance.DAMAGE_NUM_DOT_SIZE
		color = Balance.DAMAGE_NUM_DOT
	elif entry.crit:
		size = Balance.DAMAGE_NUM_CRIT_SIZE
		color = Balance.DAMAGE_NUM_CRIT
	if entry.ally:
		size = Balance.DAMAGE_NUM_ALLY_SIZE
		color.a = Balance.DAMAGE_NUM_ALLY_ALPHA
	UITheme.world(l, size, outline)
	# Fully opaque ring (the shared world treatment is 0.92) so pale fills keep
	# a hard dark edge on snow and ice.
	l.add_theme_color_override("font_outline_color", Balance.COMBAT_TEXT_OUTLINE_COLOR)
	l.add_theme_color_override("font_color", color)


## Rows follow list order: the column is only as tall as its live labels, and
## older rows settle back down when a newer one expires. Every row restarts its
## shift together, so adjacent rows never close below one row while moving.
func _restack() -> void:
	for i in entries.size():
		entries[i].row = -i * Balance.DAMAGE_NUM_ROW
		_shift(entries[i])


func _shift(entry: Dictionary) -> void:
	_kill(entry, "shift")
	var l: Label = entry.label
	var tw := l.create_tween()
	entry.shift = tw
	tw.tween_property(l, "position:y", entry.row, Balance.DAMAGE_NUM_SHIFT)


func _update_value(value: float, entry: Dictionary) -> void:
	var l: Label = entry.label
	entry.shown = value
	l.text = "%d!" % roundi(value) if entry.crit else str(roundi(value))
	if entry.kind == "text":
		l.text = entry.prefix + str(roundi(value)) + entry.suffix if entry.numeric > 0 else entry.message
	var f: Font = l.get_theme_font("font")
	var size: int = l.get_theme_font_size("font_size")
	var measured := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	l.size = measured + Vector2.ONE * (l.get_theme_constant("outline_size") * 2 + Balance.DAMAGE_NUM_PADDING)
	l.position.x = -l.size.x * 0.5
	# Scale around the label's top edge: a pop grows toward the newer row below,
	# which the row pitch clears (test_quality checks it against the font).
	l.pivot_offset = Vector2(l.size.x * 0.5, 0.0)


func _pop(entry: Dictionary) -> void:
	_kill(entry, "pop")
	_kill(entry, "life")
	var l: Label = entry.label
	l.scale = Vector2.ONE * Balance.DAMAGE_NUM_POP
	l.modulate.a = 1.0
	var pop := l.create_tween().set_parallel(true)
	entry.pop = pop
	pop.tween_method(_update_value.bind(entry), float(entry.shown), float(entry.total), Balance.DAMAGE_NUM_COUNT_TIME)
	pop.tween_property(l, "scale", Vector2.ONE, Balance.DAMAGE_NUM_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var life := l.create_tween()
	entry.life = life
	life.tween_interval(Balance.DAMAGE_NUM_LIFE - Balance.DAMAGE_NUM_FADE)
	life.tween_property(l, "modulate:a", 0.0, Balance.DAMAGE_NUM_FADE)
	life.tween_callback(game._retire_float_num.bind(l))


func _kill(entry: Dictionary, key: String) -> void:
	if entry.has(key):
		(entry[key] as Tween).kill()
		entry.erase(key)


func remove_label(l: Label) -> void:
	for entry in entries:
		if entry.label == l:
			for key in ["pop", "life", "shift"]:
				_kill(entry, key)
			entries.erase(entry)
			break
	l.hide()
	l.queue_free()
	if entries.is_empty():
		game._damage_columns.erase(target_id)
		set_process(false)
		queue_free()
	else:
		_restack()


## Hard stop (room change): every label goes now instead of fading out.
func retire() -> void:
	for entry in entries.duplicate():
		game._retire_float_num(entry.label)
