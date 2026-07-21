extends SceneTree
## PREFLIGHT DATA CHECK -- run via tools/preflight.py (preflight.bat).
## Audits the hand-maintained codex gates against the real content data:
## every boss-flagged enemy in Story.ALL_ENEMIES must sit in
## Menus.BOSS_KINDS (the list the codex bestiary buckets by), and
## BOSS_KINDS must hold no dead entries. Dependency-light like
## check_compile.gd: loads story/menus with load() and bails with a
## printed verdict instead of hanging when either fails to compile.

func _init() -> void:
	var story = load("res://scripts/story.gd")
	var menus = load("res://scripts/menus.gd")
	if story == null or not (story as GDScript).can_instantiate() \
			or menus == null or not (menus as GDScript).can_instantiate():
		print("DATA FAIL: story.gd or menus.gd does not compile -- run test_quick.bat (gate first)")
		quit(1)
		return
	story.load_content()
	var enemies: Dictionary = story.ALL_ENEMIES
	var boss_kinds: Array = (menus as GDScript).get_script_constant_map()["BOSS_KINDS"]
	var bad := 0
	for kind in enemies:
		var st: Dictionary = enemies[kind]
		if bool(st.get("boss", false)) and not (kind in boss_kinds):
			print("BOSS_NOT_BUCKETED: %s -- boss-flagged in its ENEMIES table but missing from Menus.BOSS_KINDS; the codex files it under monsters" % kind)
			bad += 1
	for kind in boss_kinds:
		if not enemies.has(kind):
			print("BOSS_KINDS_DEAD: %s -- listed in Menus.BOSS_KINDS but no such enemy in Story.ALL_ENEMIES" % kind)
			bad += 1
	if bad == 0:
		print("DATA OK (%d enemies, %d boss kinds)" % [enemies.size(), boss_kinds.size()])
	else:
		print("DATA: %d issue(s)" % bad)
	quit(1 if bad > 0 else 0)
