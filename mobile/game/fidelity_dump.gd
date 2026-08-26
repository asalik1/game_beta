extends SceneTree
## Runtime entity dump for tools/art/fidelity_audit.py (2026-08-21). Writes the
## live scale/sprite/boss data the auditor can't parse statically (enemy stats
## merge balance.gd + every content module at load). Headless:
##   godot --headless --path game --script res://fidelity_dump.gd -- <out.json>
## (run when the box is free of Codex image-gen — quick, but still a Godot boot.)

func _init() -> void:
	Story.load_content()   # populate ALL_ENEMIES / CHAPTER_LIST (not auto in a --script boot)
	var out := {"enemies": {}, "npcs": {}}
	var boss_kinds: Array = Menus.BOSS_KINDS
	# PLACED set (mirrors dump_codex_data / codex used-filter): only enemies a
	# player actually meets — a zone-spawn kind, a zone boss, or a chapter final
	# boss. Enemies merely DEFINED in ALL_ENEMIES but never placed (bat/direbat)
	# must not pollute the fidelity audit as phantom fails.
	var placed := {}
	for chid in Story.CHAPTER_LIST:
		var ch: Dictionary = Story.CHAPTER_LIST[chid]
		var fb := String(ch.get("final_boss", ""))
		if fb != "":
			placed[fb] = true
		for zone in ch.get("zones", []):
			var zb := String(zone.get("boss", ""))
			if zb != "":
				placed[zb] = true
			for e in zone.get("enemies", []):
				if e is Array and e.size() > 0:
					placed[String(e[0])] = true
	# Mechanic-SUMMONED adds (censers/rods/clones) never appear in a zone's
	# enemies array, so the walk above misses them — the choir_censer blind
	# spot (FIDELITY_AUDIT.md). Boss defs now declare them via a "summons"
	# key; a summon of a placed boss is seen in game, so it counts as placed.
	for kind in Story.ALL_ENEMIES:
		if placed.has(String(kind)):
			for s in Story.ALL_ENEMIES[kind].get("summons", []):
				placed[String(s)] = true
	for kind in Story.ALL_ENEMIES:
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		if st.get("placeholder", false):
			continue
		out["enemies"][String(kind)] = {
			"sprite": String(st.get("sprite", kind)),
			"scale": float(st.get("scale", 1.0)),
			"boss": bool(kind in boss_kinds),
			"placed": bool(placed.has(String(kind))),
		}
	# NPCs: unique sprites across every chapter's zones (codex._npcs walk).
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid].get("zones", []):
			for npc in zone.get("npcs", []):
				if npc.get("placeholder", false):
					continue
				var spr := String(npc.get("sprite", ""))
				if spr != "" and not out["npcs"].has(spr):
					# Real per-sprite body target (the old dump hardcoded 46.0
					# for everyone, mis-auditing every non-46 NPC). 0.0 = no
					# entry -> the LEGACY path: game_world scales the sprite so
					# its frame WIDTH renders at NPC_RENDER_SCALE*CHAR*nsize*16
					# world px (width-normalized, so bigger art = more detail).
					out["npcs"][spr] = {"body_target":
						float(Balance.NPC_BODY_TARGETS.get(spr, 0.0))}
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://fidelity_entities.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("fidelity_dump: %d enemies, %d npcs -> %s" % [
		out["enemies"].size(), out["npcs"].size(), ProjectSettings.globalize_path(path)])
	quit(0)
