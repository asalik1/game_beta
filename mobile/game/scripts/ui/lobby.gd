## PLAY TOGETHER — the co-op lobby (MP-08, MULTIPLAYER.md §5.1), a static
## module in the menus idiom: `m` (the Menus instance) owns the panel
## scaffolding (_open/_btn/_lbl/_hint) and the open/close state; flow
## state lives in m.lobby. Loaded by PATH from menus.gd — deliberately NO
## class_name (a new global class would demand a --import pass).
##
## The flow, as a player walks it:
##   HOST: Play Together → Host → pick a hero (their roster) → pick a
##     chapter (their unlocks; the save's own chapter continues as saved)
##     → the lobby shows the CODE big + the party as it gathers → Start.
##   JOIN: Play Together → Join → type the code → pick a hero from their
##     OWN roster → wait in the lobby → the host starts and everyone
##     transitions together (the MP-07 snapshot flow does the moving).
##
## Talks to the transport ONLY through the NetworkManager autoload — by
## node path, never the bare global (check_compile trap, MP-05) — and to
## the session bridge (lobby roster, session_started) through its child.

const NetMgr := preload("res://scripts/net/net_manager.gd")

const GOLD := Color(0.95, 0.85, 0.5)
const DIM := Color(0.65, 0.68, 0.78)
const GOOD := Color(0.6, 1.0, 0.6)
const BAD := Color(1.0, 0.6, 0.55)
const BLUE := Color(0.6, 0.9, 1.0)


static func open(m: Menus, stage := "menu") -> void:
	if m.lobby.is_empty():
		m.lobby = {"stage": "menu", "path": "host", "msg": "", "quiet": false}
	match stage:
		"char":
			_stage_char(m)
		"chapter":
			_stage_chapter(m)
		"join":
			_stage_join(m)
		"wait":
			_stage_wait(m)
		"host_lobby":
			_stage_host_lobby(m)
		"guest_lobby":
			_stage_guest_lobby(m)
		_:
			_stage_menu(m)


## ESC routing (menus._input): one stage back, never into a paused void.
static func esc(m: Menus) -> void:
	match String(m.lobby.get("stage", "menu")):
		"char":
			open(m, "join" if String(m.lobby.get("path", "host")) == "join" else "menu")
		"chapter":
			open(m, "char")
		"join":
			open(m, "menu")
		"host_lobby":
			_leave(m, "You closed the lobby.")
		"guest_lobby":
			_leave(m, "You left the lobby.")
		"wait":
			pass  # a connection attempt is in flight — let it resolve
		_:
			_exit(m)


# ---------------------------------------------------------------- stages ---

## Stage 1 — Host / Join / Back, plus the build mark (§3.4).
static func _stage_menu(m: Menus) -> void:
	var vbox := m._open("Play Together", 760, 460)
	m.current = "lobby"
	m.lobby["stage"] = "menu"
	m.lobby["quiet"] = false
	var msg := String(m.lobby.get("msg", ""))
	if msg != "":
		m.lobby["msg"] = ""
		var ml := m._lbl(vbox, "◆ " + msg, 14, BAD)
		ml.custom_minimum_size = Vector2(680, 0)
	m._lbl(vbox, "Up to four heroes share one road — the host's world, everyone's own hero. Host a session and read your code to friends, or join theirs. Monsters grow tougher for every extra head; the loot each of you sees is your own.", 14, Color(0.75, 0.75, 0.75))
	_gap(vbox, 6)
	m._btn(vbox, "  ⚑  Host a session  ", func() -> void:
		m.lobby["path"] = "host"
		open(m, "char"), GOLD)
	m._btn(vbox, "  ➤  Join with a code  ", func() -> void:
		m.lobby["path"] = "join"
		open(m, "join"), BLUE)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	var vl := m._lbl(vbox, "build %s — friends must run the SAME build to join (everyone's is printed on their title screen)." % NetMgr.NET_VERSION, 13, Color(0.55, 0.58, 0.66))
	vl.custom_minimum_size = Vector2(680, 0)
	m._btn(vbox, "  Back  ", func() -> void: _exit(m), Color(0.8, 0.85, 0.9))
	m._hint(vbox, "ESC to go back")


## Shared hero pick — the player's OWN roster (§5.1: any class, any
## level; the lobby shows levels so friends can self-select).
static func _stage_char(m: Menus) -> void:
	var saves: Array = SaveGame.list()
	var vbox := m._open("Play Together — choose your hero", 760, 520)
	m.current = "lobby"
	m.lobby["stage"] = "char"
	var hosting: bool = String(m.lobby.get("path", "host")) == "host"
	if saves.is_empty():
		var nl := m._lbl(vbox, "No heroes yet — forge one first (New Character on the title screen). Any hero you make can host or guest.", 14, DIM)
		nl.custom_minimum_size = Vector2(680, 0)
		m._btn(vbox, "  Back  ", func() -> void: esc(m), Color(0.8, 0.85, 0.9))
		m._hint(vbox, "ESC to go back")
		return
	m._lbl(vbox, "Your hero hosts — friends walk YOUR world, saved exactly where you left it." if hosting
		else "Bring any hero from your roster into the host's world. Their build, gear and progress travel with them — and come home again.", 14, Color(0.75, 0.75, 0.75))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for s in saves:
		var slot: int = int(s["slot"])
		var cls: String = String(s["cls"])
		var level: int = int(s["level"])
		var cname := String(Classes.CLASSES.get(cls, {}).get("name", cls))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var pick := func() -> void:
			m.lobby["slot"] = slot
			m.lobby["cls"] = cls
			m.lobby["level"] = level
			if hosting:
				m.lobby["saved_chapter"] = String(SaveGame.read(slot).get("chapter", "ch1"))
				open(m, "chapter")
			else:
				_join_go(m)
		var b := m._btn(row, "  %s — Lv %d" % [cname, level], pick, GOOD)
		b.custom_minimum_size = Vector2(420, 0)
		var when := Time.get_datetime_string_from_unix_time(int(s["saved_at"])).replace("T", "  ")
		var wl := m._lbl(row, when, 12, Color(0.55, 0.58, 0.66))
		wl.custom_minimum_size = Vector2(170, 0)
	m._btn(vbox, "  Back  ", func() -> void: esc(m), Color(0.8, 0.85, 0.9))
	m._hint(vbox, "ESC to go back")


## HOST step 2 — the chapter, from THEIR unlocks (§5.1). The save's own
## chapter continues exactly as saved (§5.7: the save IS the session
## world); any unlocked chapter can be started from its beginning
## instead (the solo replay semantics — fresh seed, story state resets).
static func _stage_chapter(m: Menus) -> void:
	var vbox := m._open("Play Together — choose the chapter", 900, 540)
	m.current = "lobby"
	m.lobby["stage"] = "chapter"
	var saved_ch := String(m.lobby.get("saved_chapter", "ch1"))
	var saved_name := String(Story.chapter(saved_ch)["name"])
	var cont_btn := m._btn(vbox, "  ▶  Continue — %s (as your save left it)  " % saved_name,
		func() -> void: _host_go(m, saved_ch, true), GOOD)
	cont_btn.add_theme_font_size_override("font_size", 17)
	UITheme.header(m._lbl(vbox, "— OR START A CHAPTER FROM ITS BEGINNING —", 14, GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var idx := 1
	for chid in Story.CHAPTER_LIST:
		var pick_id: String = chid
		var unlocked: bool = m.game.chapter_available(pick_id)
		var chname := String(Story.CHAPTER_LIST[chid]["name"])
		m._btn(list, "  %d.  %s%s  " % [idx, "" if unlocked else "🔒 ", chname],
			func() -> void: _host_go(m, pick_id, false),
			GOLD if unlocked else Color(0.5, 0.5, 0.55), unlocked)
		idx += 1
	m._lbl(vbox, "Replays reset that chapter's story for your save; your hero's build, gear and Resonance ride along untouched.", 13, Color(0.55, 0.58, 0.66))
	m._btn(vbox, "  Back  ", func() -> void: open(m, "char"), Color(0.8, 0.85, 0.9))
	m._hint(vbox, "ESC to go back")


## JOIN step 1 — the code (§5.1: enter code, THEN pick your hero).
static func _stage_join(m: Menus) -> void:
	var vbox := m._open("Play Together — join with a code", 760, 400)
	m.current = "lobby"
	m.lobby["stage"] = "join"
	var msg := String(m.lobby.get("msg", ""))
	if msg != "":
		m.lobby["msg"] = ""
		var ml := m._lbl(vbox, "◆ " + msg, 14, BAD)
		ml.custom_minimum_size = Vector2(680, 0)
	m._lbl(vbox, "Ask the host for their lobby code — it's written large on their lobby screen.", 14, Color(0.75, 0.75, 0.75))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	var name_l := m._lbl(row, "Code", 15)
	name_l.custom_minimum_size = Vector2(70, 0)  # HBox label-collapse trap
	var box := LineEdit.new()
	box.text = String(m.lobby.get("code", ""))
	box.placeholder_text = "the host's code (or ip:port on a LAN)"
	box.custom_minimum_size = Vector2(420, 0)
	row.add_child(box)
	var go := func() -> void:
		var code := box.text.strip_edges()
		if code == "":
			return
		m.lobby["code"] = code
		open(m, "char")
	m._btn(row, "  Next — pick your hero  ", go, GOOD)
	box.text_submitted.connect(func(_t: String) -> void: go.call())
	box.grab_focus.call_deferred()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	m._lbl(vbox, "build %s — a different build is refused with both versions named, so you'll know who updates." % NetMgr.NET_VERSION, 13, Color(0.55, 0.58, 0.66))
	m._btn(vbox, "  Back  ", func() -> void: open(m, "menu"), Color(0.8, 0.85, 0.9))
	m._hint(vbox, "ESC to go back")


## A captive beat while transport work is in flight (host/join awaits).
static func _stage_wait(m: Menus, title := "One moment...", note := "") -> void:
	var vbox := m._open(title, 640, 280)
	m.current = "lobby"
	m.lobby["stage"] = "wait"
	if note != "":
		var nl := m._lbl(vbox, note, 14, DIM)
		nl.custom_minimum_size = Vector2(560, 0)


## HOST lobby — the code big, the party assembling, Start (§5.1: enabled
## from a party of 1 — solo numbers — up to host + 3 guests).
static func _stage_host_lobby(m: Menus) -> void:
	var net: Node = m.get_node("/root/NetworkManager")
	var sess: Node = m.get_node("/root/NetworkManager/Session")
	if not net.is_online():
		open(m, "menu")
		return
	var vbox := m._open("Lobby — your party gathers", 900, 560)
	m.current = "lobby"
	m.lobby["stage"] = "host_lobby"
	m._lbl(vbox, "Read this code to your friends (Play Together → Join with a code):", 14, DIM)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 14)
	vbox.add_child(crow)
	var code := String(net.session_code)
	var cl := m._lbl(crow, code, 15, Color(1.0, 0.92, 0.62))
	UITheme.title(cl, 30)
	cl.custom_minimum_size = Vector2(560, 0)
	cl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY  # codes have no spaces
	m._btn(crow, "  ⧉ Copy  ", func() -> void:
		DisplayServer.clipboard_set(code), Color(0.8, 0.9, 1.0))
	m._lbl(vbox, "An internet code — it works from anywhere." if int(net.mode) == NetMgr.Mode.NORAY
		else "A direct address — same network (or a forwarded port) only.", 13, Color(0.55, 0.58, 0.66))
	var msg := String(m.lobby.get("msg", ""))
	if msg != "":
		m.lobby["msg"] = ""
		var ml := m._lbl(vbox, "◆ " + msg, 14, BAD)
		ml.custom_minimum_size = Vector2(800, 0)
	_party(m, vbox)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 16)
	vbox.add_child(brow)
	var start := m._btn(brow, "  ▶  Start the chapter  ", func() -> void: _start_session(m), GOOD)
	start.add_theme_font_size_override("font_size", 17)
	m._btn(brow, "  ✕  Close the lobby  ", func() -> void: _leave(m, "You closed the lobby."), BAD)
	m._hint(vbox, "Start any time — a party of 1 plays the solo game; joins lock once the chapter begins")
	_wire(m, sess.lobby_changed, func() -> void: _refresh(m, "host_lobby"))
	_wire(m, net.peer_rejected, func(_id: int, reason: String) -> void:
		m.lobby["msg"] = "A knock was turned away — %s" % reason
		_refresh(m, "host_lobby"))
	_wire(m, net.session_ended, func(reason: String) -> void: _ended(m, reason))


## GUEST lobby — the same party list, waiting on the host's Start.
static func _stage_guest_lobby(m: Menus) -> void:
	var net: Node = m.get_node("/root/NetworkManager")
	var sess: Node = m.get_node("/root/NetworkManager/Session")
	if not net.is_online():
		open(m, "menu")
		return
	if m.game.play_started:
		m.close()  # the snapshot already landed — we're in the world
		return
	var vbox := m._open("Lobby — the party gathers", 800, 520)
	m.current = "lobby"
	m.lobby["stage"] = "guest_lobby"
	m._lbl(vbox, "You're in. The host starts the chapter once everyone has gathered — you'll all set out together.", 14, Color(0.75, 0.75, 0.75))
	_party(m, vbox)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	m._btn(vbox, "  ✕  Leave the lobby  ", func() -> void: _leave(m, "You left the lobby."), BAD)
	m._hint(vbox, "ESC to leave the lobby")
	_wire(m, sess.lobby_changed, func() -> void: _refresh(m, "guest_lobby"))
	_wire(m, sess.session_started, func() -> void:
		if m.current == "lobby":
			m.close())
	_wire(m, net.session_ended, func(reason: String) -> void: _ended(m, reason))


# ---------------------------------------------------------------- actions ---

## HOST: raise the session. Internet lobby (noray) first; if the lobby
## service can't be reached, fall back to a direct LAN listen so friends
## on the same network still play tonight.
static func _host_go(m: Menus, chid: String, cont: bool) -> void:
	m.lobby["chapter"] = chid
	m.lobby["continue"] = cont
	_stage_wait(m, "Opening the road...", "Raising a lobby — a few seconds.")
	var net: Node = m.get_node("/root/NetworkManager")
	var sess: Node = m.get_node("/root/NetworkManager/Session")
	sess.local_char = {"slot": int(m.lobby.get("slot", 0)),
		"cls": String(m.lobby.get("cls", "warrior")),
		"level": int(m.lobby.get("level", 1)),
		"name": String(sess.os_name())}
	var err: Error = await net.host(NetMgr.Mode.NORAY)
	if err != OK:
		err = await net.host(NetMgr.Mode.ENET_DIRECT)
	if err != OK:
		m.lobby["msg"] = "Could not open a session (%s)." % error_string(err)
		open(m, "menu")
		return
	net.lobby_open = true
	open(m, "host_lobby")


## JOIN: announce who we're bringing (slot = OUR save; its character
## loads when the host's snapshot arrives — §5.7), then knock.
static func _join_go(m: Menus) -> void:
	var net: Node = m.get_node("/root/NetworkManager")
	var sess: Node = m.get_node("/root/NetworkManager/Session")
	sess.local_char = {"slot": int(m.lobby.get("slot", 0)),
		"cls": String(m.lobby.get("cls", "warrior")),
		"level": int(m.lobby.get("level", 1)),
		"name": String(sess.os_name())}
	_stage_wait(m, "Knocking...", "Reaching the host — a moment.")
	m.lobby["quiet"] = false
	_wire(m, net.peer_joined, func(id: int, _ci: Dictionary) -> void:
		if id == 1 and m.current == "lobby":
			open(m, "guest_lobby"))
	_wire(m, sess.session_started, func() -> void:
		if m.current == "lobby":
			m.close())
	_wire(m, net.session_ended, func(reason: String) -> void: _ended(m, reason))
	var err: Error = await net.join(String(m.lobby.get("code", "")))
	if err != OK:
		m.lobby["msg"] = "Could not join (%s)." % error_string(err)
		open(m, "join")


## HOST: Start. Lock the lobby (§5.1 — late knocks get a readable
## refusal), then run the exact solo entry: load the picked save (its
## world IS the session world, §5.7) and, for a from-the-beginning pick,
## the exact solo replay. play_started flips and the MP-07 snapshot flow
## carries every admitted guest into the chapter.
static func _start_session(m: Menus) -> void:
	var net: Node = m.get_node("/root/NetworkManager")
	net.lobby_open = false
	var slot: int = int(m.lobby.get("slot", 0))
	var chid := String(m.lobby.get("chapter", "ch1"))
	var cont: bool = bool(m.lobby.get("continue", true))
	if m.root:
		m.root.queue_free()
		m.root = null
	m.current = ""
	m.game.load_save(slot)
	if not cont and m.game.play_started:
		m.game.replay_chapter(chid)


## Deliberate exit (host closing the lobby / guest leaving): quiet the
## session_ended echo our own leave() fires, then land on the menu.
static func _leave(m: Menus, note: String) -> void:
	var net: Node = m.get_node("/root/NetworkManager")
	m.lobby["quiet"] = true
	net.leave()
	m.lobby["quiet"] = false
	m.lobby["msg"] = note
	open(m, "menu")


## The session died under the lobby (host left, refusal, timeout): show
## the transport's player-readable reason plainly (§3.4 — a version
## mismatch names both builds; a locked lobby says the run already began).
static func _ended(m: Menus, reason: String) -> void:
	if bool(m.lobby.get("quiet", false)):
		return  # our own deliberate leave — _leave already narrates it
	if m.current != "lobby":
		return  # mid-run drop UX is phase 2's; the lobby owns lobby-time only
	m.lobby["msg"] = reason
	open(m, "menu")


# ---------------------------------------------------------------- helpers ---

## The party list both lobbies share: host star, name, class, level,
## ready state. Admitted-but-still-announcing peers show as "joining...".
static func _party(m: Menus, vbox: VBoxContainer) -> void:
	var net: Node = m.get_node("/root/NetworkManager")
	var sess: Node = m.get_node("/root/NetworkManager/Session")
	UITheme.header(m._lbl(vbox, "— THE PARTY —", 15, GOLD))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	vbox.add_child(list)
	var roster: Dictionary = sess.lobby_roster()
	var ids: Array = []
	for k in roster:
		ids.append(int(k))
	if bool(net.is_host()):
		for pid in net.peers:  # admitted, hello still in flight
			if not ids.has(int(pid)):
				ids.append(int(pid))
	if not ids.has(1):
		ids.append(1)  # the host seat always shows, even pre-broadcast
	ids.sort()
	var my_id: int = m.multiplayer.get_unique_id()
	for pid_v in ids:
		var pid: int = int(pid_v)
		var block: Dictionary = roster.get(pid, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		var star := m._lbl(row, "★" if pid == 1 else " ", 15, GOLD)
		star.custom_minimum_size = Vector2(24, 0)
		var nm := String(block.get("name", "…"))
		if pid == my_id:
			nm += "  (you)"
		var nl := m._lbl(row, nm, 15, Color(0.9, 0.92, 0.98))
		nl.custom_minimum_size = Vector2(230, 0)
		if block.is_empty():
			var jl := m._lbl(row, "joining...", 14, Color(0.6, 0.62, 0.7))
			jl.custom_minimum_size = Vector2(280, 0)
			continue
		var cls := String(block.get("cls", "warrior"))
		var cn := m._lbl(row, String(Classes.CLASSES.get(cls, {}).get("name", cls)), 14, GOLD)
		cn.custom_minimum_size = Vector2(150, 0)
		var lv := m._lbl(row, "Lv %d" % int(block.get("level", 1)), 14, Color(0.8, 0.85, 0.9))
		lv.custom_minimum_size = Vector2(80, 0)
		var rd := m._lbl(row, "host" if pid == 1 else "ready", 14, GOOD)
		rd.custom_minimum_size = Vector2(100, 0)
	var free: int = (NetMgr.MAX_GUESTS + 1) - ids.size()
	if free > 0:
		m._lbl(vbox, "%d seat%s open." % [free, "" if free == 1 else "s"], 13, Color(0.55, 0.58, 0.66))


## Rebuild the current stage IF the player is still on it (signal-driven
## refresh — the party list has no per-row bindings to update).
static func _refresh(m: Menus, stage: String) -> void:
	if m.current == "lobby" and String(m.lobby.get("stage", "")) == stage:
		open(m, stage)


## Connect a signal for THIS screen only: the panel's root disconnects
## it on teardown, so rebuilt screens never stack handlers.
static func _wire(m: Menus, sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	m.root.tree_exiting.connect(func() -> void:
		if sig.is_connected(cb):
			sig.disconnect(cb))


## Leave Play Together entirely: the roster at boot, plain close in-game
## (the render smoke opens the lobby mid-world; a real player never does).
static func _exit(m: Menus) -> void:
	if m.game.play_started:
		m.close()
	else:
		m.open_slots()


static func _gap(vbox: VBoxContainer, px: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	vbox.add_child(c)
