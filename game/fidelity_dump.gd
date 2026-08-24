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
	for kind in Story.ALL_ENEMIES:
		var st: Dictionary = Story.ALL_ENEMIES[kind]
		if st.get("placeholder", false):
			continue
		out["enemies"][String(kind)] = {
			"sprite": String(st.get("sprite", kind)),
			"scale": float(st.get("scale", 1.0)),
			"boss": bool(kind in boss_kinds),
		}
	# NPCs: unique sprites across every chapter's zones (codex._npcs walk).
	for chid in Story.CHAPTER_LIST:
		for zone in Story.CHAPTER_LIST[chid].get("zones", []):
			for npc in zone.get("npcs", []):
				if npc.get("placeholder", false):
					continue
				var spr := String(npc.get("sprite", ""))
				if spr != "" and not out["npcs"].has(spr):
					out["npcs"][spr] = {"body_target": 46.0}
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://fidelity_entities.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("fidelity_dump: %d enemies, %d npcs -> %s" % [
		out["enemies"].size(), out["npcs"].size(), ProjectSettings.globalize_path(path)])
	quit(0)
