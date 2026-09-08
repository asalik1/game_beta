extends RefCounted
## Each co-op reader owns an ending. Never acquire an NPC or party beat claim.
var active := false
var seen := false
var _epoch := 0
var _chapter := ""
var _art: Control = null


func play(g: Node2D, on_done: Callable, fallback: Array = []) -> bool:
	if seen:
		return false
	seen = true
	active = true
	_epoch += 1
	_chapter = String(g.chapter_id)
	_start_when_ready(g, _epoch, on_done, fallback)
	return true


func _start_when_ready(g: Node2D, epoch: int, on_done: Callable, fallback: Array) -> void:
	var resolved := _resolved.bind(g, epoch, on_done)
	if g.dedicated or not g.has_local_player():
		resolved.call()
		return
	g.player.clear_local_intents()
	# Let an existing menu, choice or NPC conversation finish normally, so its
	# consequences and online claim-release callback are never overwritten.
	while _current(g, epoch) and _reader_busy(g):
		await g.get_tree().create_timer(Balance.FINALE_READY_POLL, true).timeout
	if not _current(g, epoch):
		return
	var id := _chapter + "_closing_" + String(g.player.cls)
	if Story.ALL_CONVOS.has(id):
		_art = Cutscene.new(g)
		g.cutscene = _art
		g.hud.add_child(_art)
		g.hud.move_child(_art, g.hud.dialogue_box.get_index())
		# run_convo_id routes online NPC claims and party gathering. The
		# authored closer is passive and personal, so run its nodes locally.
		g.run_convo(Story.ALL_CONVOS[id], resolved, _current.bind(g, epoch))
	elif not fallback.is_empty():
		g.hud.dialogue(fallback, resolved)
	else:
		resolved.call()


func _reader_busy(g: Node2D) -> bool:
	var menus: Node = g.get("menus")
	if (menus != null and menus.is_open()) or g.hud.dialogue_active or g.hud.choices_active or g.hud.chat_active:
		return true
	if g.net_online():
		var session: Node = g.net_session()
		if session != null and not session._pending_convo.is_empty():
			return true
	# The ordinary cinematic path clears game.cutscene before its dissolve
	# finishes. Wait for that old node to leave too, before mounting new art.
	for child in g.hud.get_children():
		if child is Cutscene:
			return true
	return false


func _current(g: Node2D, epoch: int) -> bool:
	return is_instance_valid(g) and g.is_inside_tree() and active \
		and epoch == _epoch and String(g.chapter_id) == _chapter


func _resolved(g: Node2D, epoch: int, on_done: Callable) -> void:
	if not _current(g, epoch):
		return
	if is_instance_valid(_art):
		_art.finish(_finished.bind(g, epoch, on_done))
	else:
		_finished(g, epoch, on_done)


func _finished(g: Node2D, epoch: int, on_done: Callable) -> void:
	if not _current(g, epoch):
		return
	if g.cutscene == _art:
		g.cutscene = null
	_art = null
	active = false
	if on_done.is_valid():
		on_done.call()


func cancel(g: Node2D) -> void:
	var was_active := active
	_epoch += 1
	active = false
	seen = false
	_chapter = ""
	if was_active and g.net_online():
		var session: Node = g.net_session()
		if session != null:
			session.cancel_local_convo()
	if is_instance_valid(_art):
		if g.cutscene == _art:
			g.cutscene = null
		# Free before a new opener mounts. A queued old Cutscene's exit hook
		# would otherwise restore the HUD over the new chapter's artwork.
		_art.free()
	_art = null
	if was_active and g.hud != null:
		# A chapter change may arrive while we still wait behind an older
		# illustrated interaction. Retire that art before the next opener too.
		for child in g.hud.get_children():
			if child is Cutscene:
				if g.cutscene == child:
					g.cutscene = null
				child.free()
		g.hud.cancel_conversation()
