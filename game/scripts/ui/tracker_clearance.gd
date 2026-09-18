extends Node
## Keep complete quest and target text clear of bodies when a lane fits.
## Connect during Hud._ready, before Game connects its landmark pre-draw hook.
const Bodies := preload("res://scripts/ui/hud_clearance.gd")
const Cast := preload("res://scripts/ui/boss_cast.gd")
var hud: Hud
var parts: Array[Control] = []
var base_positions: Array[Vector2] = []
var offset_y := 0.0
var no_fit := false
var release_in := 0.0
var context := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	parts.assign([hud.quest_panel, hud.zone_label, hud.quest_label,
		hud.boss_box, hud.mob_box, hud.rival_box, hud.boss_cast_readout])
	capture_base()
	RenderingServer.frame_pre_draw.connect(_place)


## Called only after Hud has recomputed the ordinary unshifted layout.
func capture_base() -> void:
	base_positions.clear()
	for part in parts:
		base_positions.append(part.position)


func _process(delta: float) -> void:
	release_in = maxf(0.0, release_in - delta)


func _apply(dy: float) -> void:
	for i in parts.size():
		if is_instance_valid(parts[i]):
			parts[i].position = base_positions[i] + Vector2(0, dy)
	offset_y = dy
	# CombatFeedback retains ownership of cue layout; use its one formula.
	if is_instance_valid(hud.combat_feedback) and is_instance_valid(hud.combat_feedback.target_cue):
		hud.combat_feedback.layout_target_cue(hud.target_bar_unit)


func _body(actor: Variant) -> Rect2:
	if not is_instance_valid(actor) or not (actor is Player or actor is Enemy):
		return Rect2()
	var g := hud.game
	if actor.game != g or not is_instance_valid(g.world):
		return Rect2()
	if actor is Enemy and not g.world.is_ancestor_of(actor):
		return Rect2()
	return Bodies.body_rect(actor)


func _append_body(out: Array[Rect2], actor: Variant) -> void:
	var rect := _body(actor)
	if rect.has_area(): out.append(rect)


## Grouping Controls have no drawn area; their actual child panels/text do.
func _drawn(out: Array[Rect2], node: Node) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Control and node.size.x > 0.0 and node.size.y > 0.0:
		var rect: Rect2 = node.get_global_rect()
		if node is Label:
			if node.text.is_empty(): return
			rect = rect.grow(float(node.get_theme_constant("outline_size")))
		out.append(rect)
	for child in node.get_children(): _drawn(out, child)


func _family() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for part in parts:
		if not part.is_visible_in_tree(): continue
		if part == hud.boss_cast_readout:
			out.append(part.get_global_transform() * Cast.PANEL)
		else:
			_drawn(out, part)
	_drawn(out, hud.combat_feedback.target_cue)
	return out


func _fixed_reservations() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in [hud.vitals_panel, hud.info_panel, hud.minimap_root,
		hud.wayfinder.quest_root]:
		if is_instance_valid(node): _drawn(out, node)
	for slot in hud.party_slots:
		if is_instance_valid(slot.root): _drawn(out, slot.root)
	return out


func _reservations() -> Array[Rect2]:
	var out := _fixed_reservations()
	_interaction_reservations(out)
	return out


## The later NPC prompt hook must avoid the HUD as actually placed this frame.
## Exclude interaction reservations: the prompt itself is not a HUD obstacle.
func prompt_blockers() -> Array[Rect2]:
	var out := _fixed_reservations()
	out.append_array(_family())
	return out


## Only the current visible interaction is reserved; never scan world art.
## The later landmark/NPC hook restores its anchor before moving a prompt, so
## measure that anchor here rather than feeding back last frame's displacement.
func _interaction_reservations(out: Array[Rect2]) -> void:
	var g := hud.game
	for entry in g.interactables:
		var node: Variant = entry.get("node")
		var prompt: Variant = entry.get("prompt")
		if not is_instance_valid(node) or not node is Node2D \
				or node.is_queued_for_deletion() or not g.world.is_ancestor_of(node):
			continue
		if not is_instance_valid(prompt) or not prompt is Label \
				or prompt.is_queued_for_deletion() or not prompt.is_visible_in_tree() \
				or prompt.text.is_empty():
			continue
		var bounds: Rect2 = g.interaction_prompt_bounds(prompt)
		var transform: Transform2D = prompt.get_global_transform_with_canvas()
		var anchor_key := "landmark_prompt_anchor" if prompt.has_meta("landmark_prompt_anchor") else "npc_prompt_anchor"
		if prompt.has_meta(anchor_key):
			var parent_canvas := prompt.get_parent() as CanvasItem
			if parent_canvas != null:
				var anchor: Vector2 = prompt.get_meta(anchor_key)
				transform.origin += parent_canvas.get_global_transform_with_canvas().basis_xform(anchor - prompt.position)
		out.append(transform * bounds)
		# Factory NPCs expose their one painted body in the registry. Tovin
		# exposes the same explicit body through his existing wayfarers group.
		# A conservative sprite cell includes transparent padding, but needs no
		# image readback, texture scan, or body geometry cache every draw.
		var sprite: Variant = entry.get("sprite")
		if not is_instance_valid(sprite) and node.is_in_group("wayfarers"):
			sprite = node.get("body")
		if is_instance_valid(sprite) and sprite is Sprite2D \
				and not sprite.is_queued_for_deletion() and sprite.is_visible_in_tree():
			out.append(sprite.get_global_transform_with_canvas() * sprite.get_rect())


func _blocked(family: Array[Rect2], obstacles: Array[Rect2], dy: float) -> bool:
	for rect in family:
		var moved := Rect2(rect.position + Vector2(0, dy), rect.size)
		for obstacle in obstacles:
			if moved.intersects(obstacle.grow(Balance.HUD_TRACKER_BODY_GAP)):
				return true
	return false


func _fits(family: Array[Rect2], obstacles: Array[Rect2], dy: float) -> bool:
	var screen := hud.get_viewport().get_visible_rect().grow(-Balance.HUD_TRACKER_BODY_GAP)
	var ceiling := minf(screen.end.y, Balance.HUD_TRACKER_CLEARANCE_BOTTOM)
	for rect in family:
		var moved := Rect2(rect.position + Vector2(0, dy), rect.size)
		if not screen.encloses(moved) or moved.end.y > ceiling:
			return false
	return not _blocked(family, obstacles, dy)


func _place() -> void:
	if not is_instance_valid(hud) or base_positions.size() != parts.size(): return
	var retained := offset_y
	_apply(0.0)
	no_fit = false
	if not is_instance_valid(hud.clearance) or not hud.clearance.enabled():
		release_in = 0.0
		return
	var g := hud.game
	if not is_instance_valid(g.world) or not g.world.is_inside_tree():
		release_in = 0.0
		return
	var current := "%d:%d:%d" % [g.local_player.get_instance_id(), g.world.get_instance_id(), g.cur_room]
	if current != context:
		context = current
		retained = 0.0
		release_in = 0.0
	var bodies: Array[Rect2] = []
	_append_body(bodies, g.local_player)
	_append_body(bodies, hud.target_bar_unit)
	if hud.boss_cast_readout.is_visible_in_tree() and hud.boss_cast_readout.boss != hud.target_bar_unit:
		_append_body(bodies, hud.boss_cast_readout.boss)
	var family := _family()
	var base_blocked := _blocked(family, bodies, 0.0)
	if base_blocked: release_in = Balance.HUD_TRACKER_CLEARANCE_RELEASE
	if not base_blocked and release_in <= 0.0: return
	var obstacles := _reservations()
	obstacles.append_array(bodies)
	# Keep a valid lane instead of chasing the body every rendered frame.
	if retained > 0.0 and _fits(family, obstacles, retained):
		_apply(retained)
		return
	if not base_blocked: return
	# Every forbidden vertical interval ends at one obstacle's lower edge.
	# Trying those finite boundaries in order finds the smallest downward fit.
	var candidates: Array[float] = []
	for rect in family:
		for obstacle in obstacles:
			var padded := obstacle.grow(Balance.HUD_TRACKER_BODY_GAP)
			if rect.end.x <= padded.position.x or rect.position.x >= padded.end.x: continue
			var dy := padded.end.y - rect.position.y
			if dy > 0.0 and not candidates.has(dy): candidates.append(dy)
	candidates.sort()
	for dy in candidates:
		if _fits(family, obstacles, dy):
			_apply(dy)
			return
	# No legal lane: keep complete readable UI, never alter camera or opacity.
	no_fit = true


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_place):
		RenderingServer.frame_pre_draw.disconnect(_place)
	if base_positions.size() == parts.size(): _apply(0.0)
