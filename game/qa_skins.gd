extends Node
## SKIN-COMPLETION QA (dev, temporary): boots the real game once per class,
## equips each of the class's skins (base then awakened where defined), and
## fires every ability slot — executing the skin-gated FX branches the
## suites never reach and forcing the awakened strip sets through the real
## render resolver. Pure exercise: pass = no SCRIPT ERROR in the log and
## every skin state resolves a live sprite texture.
## Run headless:  godot --headless --path game res://qa_skins.tscn

const CLASSES := ["warrior", "archer", "mage", "paladin", "warlock", "assassin"]
var fails := 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for cls in CLASSES:
		await _run_class(cls)
	if fails == 0:
		print("QA SKINS PASS")
	else:
		print("QA SKINS FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _run_class(cls: String) -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	var game = main.instantiate()
	game.no_saves = true
	add_child(game)
	await _frames(10)
	game.menus.pick_chapter("ch1")
	await _frames(3)
	game.menus.pick_class(cls)
	await _frames(5)
	var guard := 0
	while (game.hud.dialogue_active or game.hud.choices_active) and guard < 80:
		if game.hud.choices_active:
			game.hud._choose(0)
		else:
			game.hud._advance_dialogue()
		await _frames(2)
		guard += 1
	var p = game.player
	p.max_hp = 999999.0
	p.hp = 999999.0
	p.mp = 9999.0
	await get_tree().create_timer(0.4).timeout
	# a target so aimed abilities (marks, judgments, rifts) have a victim
	var dummy = Enemy.make(game, "wolf", p.global_position + Vector2(0, -150))
	game.add_enemy(dummy)
	dummy.max_hp = 999999.0
	dummy.hp = 999999.0
	await _frames(4)
	for entry in Skins.skins_for(cls):
		var states := [false]
		if entry.has("awakened_sprite"):
			states.append(true)
		for awakened in states:
			game.set_flag("s_awakened_" + cls, awakened)
			p.skin = entry["id"]
			p.refresh_skin_sprite()
			await _frames(3)
			var tag := "%s/%s%s" % [cls, entry["id"], "+awakened" if awakened else ""]
			if p.sprite == null or p.sprite.texture == null:
				print("QA FAIL: no sprite texture for ", tag)
				fails += 1
			for slot in ["a1", "a2", "a3", "ult"]:
				p.cds[slot] = 0.0
				p.use_ability(slot)
				# swing/cast delays are wall-clock; let each branch fully land
				await get_tree().create_timer(0.55).timeout
				if not is_instance_valid(dummy) or dummy.dying:
					dummy = Enemy.make(game, "wolf", p.global_position + Vector2(0, -150))
					game.add_enemy(dummy)
					dummy.max_hp = 999999.0
					dummy.hp = 999999.0
			print("qa ok: ", tag)
	game.set_flag("s_awakened_" + cls, false)
	game.queue_free()
	await _frames(6)
