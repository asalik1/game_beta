extends RefCounted
const Appearance := preload("res://scripts/net/net_appearance.gd")
const Pet := preload("res://scripts/pet_visual.gd")

class Roster extends Node:
	var local_player: Player
	var players: Array[Player] = []

class WorldFixture extends Game:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func net_online() -> bool: return true
	func _refresh_active_rooms() -> void: pass


static func run(_t: Node) -> String:
	var g := Roster.new()
	var own := Player.new()
	var remote := Player.new()
	own.peer_id = 1
	remote.peer_id = 8
	remote.cls = "mage"
	own.skin = "emberbound_heir"
	own.equipped_pet = "spore_pup"
	g.local_player = own
	g.players = [own, remote]
	var error := _checks(g, own, remote)
	own.free()
	remote.free()
	g.free()
	if error == "":
		var fixture := WorldFixture.new()
		error = _world_lifecycle(fixture)
		fixture.free()
	if error == "":
		print("ok: party appearance validates wire types/class/legacy IDs, preserves local identity/stats, shares warp/rest clocks, survives freed-world rebuilds and clears remote pets on ghost/death/unequip/unregister")
	return error


static func _checks(g: Node, own: Player, remote: Player) -> String:
	var empty := {"skin": "", "pet": ""}
	for raw in [null, [], 42, "spore_pup", {"skin": [], "pet": {}}, {"skin": 1, "pet": false}]:
		if Appearance.normalize("mage", raw) != empty:
			return "malformed cosmetic identity survived normalization"
	if Appearance.normalize("mage", {"skin": "emberbound_heir", "pet": "unknown"}) != empty:
		return "wrong-class skin or unknown pet survived normalization"
	if Appearance.normalize("warlock", {"skin": "eldritch_herald"}).skin != "arcane_warlock":
		return "legacy warlock identity was not resolved"
	var raw := {"skin": "blighted_healer", "pet": "ash_crow", "gold": 9999, "owned": ["all"]}
	var normalized := Appearance.normalize("mage", raw)
	if normalized != {"skin": "blighted_healer", "pet": "ash_crow"} or raw.size() != 4:
		return "cosmetic normalization retained unrelated data or mutated its source"
	var block := Appearance.character({"cls": {}, "appearance": {"skin": "emberbound_heir"}})
	if block.cls != "warrior" or block.appearance.skin != "emberbound_heir" \
			or Appearance.character({"cls": "mage"}).appearance != empty:
		return "legacy or malformed character block has no safe appearance default"
	var before := [remote.hp, remote.max_hp, remote.mp, remote.atk, remote.gold, remote.level]
	if Appearance.apply_remote(g, 1, raw) or Appearance.apply_remote(g, 999, raw):
		return "cosmetic relay accepted local or unregistered owner"
	if not Appearance.apply_remote(g, 8, raw) or remote.skin != "blighted_healer" or remote.equipped_pet != "ash_crow":
		return "remote owner did not receive validated appearance"
	if before != [remote.hp, remote.max_hp, remote.mp, remote.atk, remote.gold, remote.level] \
			or own.skin != "emberbound_heir" or own.equipped_pet != "spore_pup":
		return "remote cosmetics changed stats or local identity"
	Appearance.apply_remote(g, 8, {"skin": "unknown", "pet": []})
	if remote.skin != "" or remote.equipped_pet != "":
		return "invalid replacement left stale remote appearance"
	var pet := Pet.new()
	g.add_child(pet)
	pet.setup("spore_pup")
	pet.follow(Vector2(2000, 2000), 0.1)
	if pet.global_position != Vector2(2000, 2000) + Balance.PET_FOLLOW_OFFSET or pet.frame != 0:
		return "pet warp failed to snap without a false walking stride"
	var at_rest := pet.global_position
	pet.follow(Vector2(2000, 2000), 0.8)
	if pet.global_position != at_rest or pet.frame != 0:
		return "resting grounded follower walked in place"
	pet.follow(Vector2(1920, 2000), 0.1)
	if not pet.flip_h or pet.global_position.x >= at_rest.x:
		return "shared follower did not turn and move toward its owner"
	return ""


static func _world_lifecycle(g: Game) -> String:
	g.world = Node2D.new()
	g.add_child(g.world)
	var own := Player.new()
	g.add_child(own)
	g.player = own
	own.game = g
	own.equipped_pet = "spore_pup"
	var remote := Player.new()
	g.add_child(remote)
	remote.game = g
	remote.peer_id = 8
	remote.equipped_pet = "hearth_hopper"
	g.players.append(remote)
	g._update_pet_follower(0.1)
	g._update_remote_pet_followers(0.1)
	var own_pet := g.pet_follower
	remote.set_pet("ash_crow")
	if g.pet_follower != own_pet:
		return "remote set_pet rebuilt the local follower"
	g._update_remote_pet_followers(0.1)
	var key := remote.get_instance_id()
	var first: Variant = g.remote_pet_followers[key].visual
	# The regression: Dictionary lookup of a freed Node into a typed variable.
	g.world.free()
	g.world = Node2D.new()
	g.add_child(g.world)
	g._update_remote_pet_followers(0.1)
	var replacement: Variant = g.remote_pet_followers[key].visual
	if is_instance_valid(first) or not is_instance_valid(replacement) or replacement.get_parent() != g.world:
		return "world rebuild left a freed or orphaned remote companion"
	remote.ghost = true
	g._update_remote_pet_followers(0.1)
	if replacement.visible:
		return "ghost companion remained visible"
	remote.ghost = false
	remote.dead = true
	g._update_remote_pet_followers(0.1)
	if replacement.visible:
		return "dead companion remained visible"
	remote.dead = false
	remote.downed = true
	g._update_remote_pet_followers(0.1)
	if not replacement.visible:
		return "living downed companion remained hidden"
	remote.equipped_pet = ""
	g._update_remote_pet_followers(0.1)
	if g.remote_pet_followers.has(key) or not replacement.is_queued_for_deletion():
		return "unequip retained a remote companion"
	remote.equipped_pet = "spore_pup"
	g._update_remote_pet_followers(0.1)
	g.unregister_player(8)
	if not g.remote_pet_followers.is_empty():
		return "unregister retained the follower registry entry"
	return ""
