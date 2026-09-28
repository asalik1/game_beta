extends RefCounted
## Real physics contacts in an isolated reward world, covered by --quick.

class RewardWorld extends Game:
	func _ready() -> void: pass


const SETTLE := 0.15                  # s of wall clock: several physics ticks
const HOME := Vector2.ZERO            # where every fixture is dropped
const AWAY := Vector2(300, 0)         # off the loot and past the coin magnet
const SAFE_ROOM := Vector2(0, 900)    # a respawn teleport's destination


static func run(t: Node) -> String:
	var g := RewardWorld.new()
	g.no_saves = true
	g.chapter_id = "ch1"
	g.player = Player.new()
	g.player.game = g
	g.add_child(g.player)
	g.hud = Hud.new()
	g.hud.game = g
	g.add_child(g.hud)
	# Separate physics space: no campaign loot/enemies or shared hero state.
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	t.add_child(viewport)
	viewport.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	g.player.set_physics_process(false)
	g.hud.set_process(false)
	var error := await _checks(g)
	viewport.free()  # includes every fixture, on failure paths too
	if error == "":
		print("ok: stand-up/revive loot pays once in place; moved-off, respawn-teleport, charged, claimed, buried, foreign and remote-shell guards")
	return error


# Timers, not render frames: headless rendering outruns physics.
static func _settle(g: Game) -> void:
	await g.get_tree().create_timer(SETTLE).timeout


static func _hero(p: Player, at: Vector2, dead: bool, downed: bool) -> void:
	p.dead = dead
	p.downed = downed
	p.ghost = false
	p._refresh_down_visual()
	p.global_position = at


static func _coin(g: Game, at: Vector2, charged := false) -> Pickup:
	var c := Pickup.new()
	c.game = g
	c.value = 7
	c.goldrush = charged
	c.global_position = at
	c._body_setup()
	g.add_child(c)
	return c


static func _chest(g: Game, at: Vector2) -> Chest:
	return Chest.drop(g, "wood", at, {"grade": "F", "gem_ok": false})


static func _free_all(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()


static func _checks(g: Game) -> String:
	var p := g.player
	p.bags = [Items.make_bag("S")]
	p.greed = 0.0
	p.goldrush_time = 0.0
	p.gold = 100
	var error: String = await _in_place(g)
	if error == "":
		error = await _moved_off(g)
	if error == "":
		error = await _respawn_teleport(g)
	if error == "":
		error = await _charged_and_claimed(g)
	if error == "":
		error = await _buried(g)
	if error == "":
		error = await _ownership(g)
	return error


## A downed hero lying on a coin and a chest gets up without moving. Layer 2
## is kept, so no new body_entered fires: each overlap must pay exactly once.
static func _in_place(g: Game) -> String:
	var p := g.player
	for recovery in ["stand_up", "revive"]:
		_hero(p, HOME, false, true)
		var gold_before := p.gold
		var bag_before := p.backpack.size()
		var coin := _coin(g, HOME)
		var chest := _chest(g, HOME)
		var hooks := [0]
		chest.on_open = func() -> void: hooks[0] += 1
		var expected := p.gold_yield(coin.value) + p.gold_yield(int(chest.sealed_contents().gold))
		await _settle(g)
		if not coin.overlaps_body(p) or not chest.overlaps_body(p):
			return recovery + ": fixture did not establish physical overlaps"
		if coin.claimed or chest.opened or p.gold != gold_before or hooks[0] != 0:
			return recovery + ": downed contact paid loot"
		if recovery == "stand_up":
			p.net_stand_up(0.3)
		else:
			p.revive()
		await _settle(g)
		if p.global_position != HOME or p.collision_layer != 2:
			return recovery + ": hero moved or changed contact layer"
		if is_instance_valid(coin) or not chest.opened or hooks[0] != 1 \
				or p.gold != gold_before + expected or p.backpack.size() != bag_before + 1:
			return recovery + ": overlapping coin/chest did not pay exactly once"
		if chest.is_physics_processing():
			return recovery + ": opened chest kept polling"
		chest._on_body_entered(p)
		await _settle(g)
		if hooks[0] != 1 or p.gold != gold_before + expected or p.backpack.size() != bag_before + 1:
			return recovery + ": repeated contact paid the chest twice"
		chest.free()
	return ""


## The fallen hero is moved off the loot before getting up. The chest stops
## polling once nobody overlaps it, and nothing pays from a distance: the
## recheck needs a live overlap, not a remembered rejected contact.
static func _moved_off(g: Game) -> String:
	var p := g.player
	_hero(p, HOME, false, true)
	var gold_before := p.gold
	var coin := _coin(g, HOME)
	var chest := _chest(g, HOME)
	var hooks := [0]
	chest.on_open = func() -> void: hooks[0] += 1
	await _settle(g)
	var armed: bool = coin.overlaps_body(p) and coin._retry_contact and chest.is_physics_processing()
	p.global_position = HOME + AWAY
	await _settle(g)
	var left: bool = not coin.overlaps_body(p) and not chest.overlaps_body(p)
	var slept: bool = not chest.is_physics_processing()
	p.net_stand_up(0.3)
	await _settle(g)
	var ok: bool = is_instance_valid(coin) and not coin.claimed and not coin._retry_contact \
		and not chest.opened and hooks[0] == 0 and p.gold == gold_before \
		and not chest.is_physics_processing()
	_free_all([coin, chest])
	if not armed:
		return "moved off: the downed contact did not arm the recheck"
	if not left:
		return "moved off: fixture still overlaps the moved hero"
	if not slept:
		return "moved off: chest kept polling with nobody on it"
	return "" if ok else "moved off: loot paid a hero who had left it"


## Loot lands on a dead hero, then _death_respawn's order runs in one idle
## frame: teleport to the safe room, then revive. Area2D overlap lists lag a
## teleport by a physics step, and that stale entry must not pay the hero
## from rooms away. The loot stays put for the walk back.
static func _respawn_teleport(g: Game) -> String:
	var p := g.player
	_hero(p, HOME, true, false)
	var gold_before := p.gold
	var coin := _coin(g, HOME)
	var chest := _chest(g, HOME)
	var hooks := [0]
	chest.on_open = func() -> void: hooks[0] += 1
	await _settle(g)
	var armed: bool = coin.overlaps_body(p) and coin._retry_contact and chest.is_physics_processing()
	p.global_position = HOME + SAFE_ROOM
	p.revive()
	await _settle(g)
	var ok: bool = is_instance_valid(coin) and not coin.claimed and not coin._retry_contact \
		and not chest.opened and hooks[0] == 0 and p.gold == gold_before \
		and not chest.is_physics_processing()
	_free_all([coin, chest])
	if not armed:
		return "respawn: the fallen hero's contact did not arm the recheck"
	return "" if ok else "respawn: a stale overlap paid loot left in the death room"


## A charged coin surges once on standing up. A coin claimed by another path
## (recovery, travel) after its downed contact was rejected never pays.
static func _charged_and_claimed(g: Game) -> String:
	var p := g.player
	_hero(p, HOME, false, true)
	p.goldrush_time = 0.0
	var gold_before := p.gold
	var charged := _coin(g, HOME, true)
	var claimed := _coin(g, HOME)
	await _settle(g)
	var armed: bool = charged._retry_contact and claimed._retry_contact
	var idle: bool = not charged.claimed and p.goldrush_time == 0.0
	claimed.claimed = true
	p.net_stand_up(0.3)
	await _settle(g)
	var ok: bool = not is_instance_valid(charged) and p.goldrush_time == Balance.GOLDRUSH_DUR \
		and is_instance_valid(claimed) and p.gold == gold_before
	_free_all([charged, claimed])
	p.goldrush_time = 0.0
	if not armed:
		return "charged/claimed: the downed contact did not arm the recheck"
	if not idle:
		return "charged coin activated while downed"
	return "" if ok else "charged/claimed coin paid gold again or failed to activate"


## Buried caches in the local world. A downed hero still discovers one (the
## reveal only skips the dead) but opens it on standing up, exactly once. A
## dead hero neither reveals nor opens one; after reviving in place, direct
## contact still cannot open it until the reveal, then it opens once.
static func _buried(g: Game) -> String:
	var p := g.player
	_hero(p, HOME, false, true)
	var cache := _chest(g, HOME)
	cache.bury()
	var hooks := [0]
	cache.on_open = func() -> void: hooks[0] += 1
	await _settle(g)
	var revealed: bool = not cache.buried and cache.visible and not cache.opened \
		and hooks[0] == 0 and cache.is_physics_processing()
	p.net_stand_up(0.3)
	await _settle(g)
	var opened_once: bool = cache.opened and hooks[0] == 1
	_free_all([cache])
	if not revealed:
		return "buried: a downed hero's reveal opened the cache or stopped its recheck"
	if not opened_once:
		return "buried: a revealed cache under a hero who got up did not open once"

	_hero(p, HOME, true, false)
	var hidden := _chest(g, HOME)
	hidden.bury()
	var opens := [0, false]  # [count, opened while still buried]
	hidden.on_open = func() -> void:
		opens[0] += 1
		opens[1] = opens[1] or hidden.buried
	await _settle(g)
	var held: bool = hidden.overlaps_body(p) and hidden.buried and not hidden.visible \
		and not hidden.opened
	p.revive()
	hidden._on_body_entered(p)  # a live contact before any reveal tick
	var guarded: bool = hidden.buried and not hidden.opened
	await _settle(g)
	var ok: bool = not hidden.buried and hidden.opened and opens[0] == 1 and not opens[1]
	_free_all([hidden])
	if not held:
		return "buried: a dead hero revealed or opened a buried cache"
	if not guarded:
		return "buried: direct contact opened a cache that was still buried"
	return "" if ok else "buried: a revealed cache did not open exactly once after the reveal"


## Loot is personal. Another machine's copies (a foreign world whose owner is
## elsewhere) never pay our overlapping hero, and a remote shell downed on our
## loot in our own world leaves nothing polling and collects nothing when it
## stands up or touches the loot again.
static func _ownership(g: Game) -> String:
	var p := g.player
	_hero(p, HOME, false, true)
	var gold_before := p.gold
	var foreign := RewardWorld.new()
	foreign.no_saves = true
	foreign.player = Player.new()
	foreign.player.global_position = HOME + SAFE_ROOM
	g.add_child(foreign)
	foreign.set_process(false)
	foreign.set_physics_process(false)
	var other_coin := _coin(g, HOME)
	other_coin.game = foreign
	var other_chest := _chest(g, HOME)
	other_chest.game = foreign
	await _settle(g)
	var overlapped: bool = other_coin.overlaps_body(p) and other_chest.overlaps_body(p)
	p.net_stand_up(0.3)
	await _settle(g)
	# A fresh contact from the hero, now standing, still isn't the owner's.
	other_coin._on_body_entered(p)
	other_chest._on_body_entered(p)
	var rejected: bool = not other_coin.claimed and not other_coin._retry_contact \
		and not other_chest.opened and not other_chest.is_physics_processing() \
		and p.gold == gold_before
	_free_all([other_coin, other_chest, foreign.player])
	foreign.player = null
	foreign.free()
	if not overlapped:
		return "ownership: foreign fixtures did not overlap the hero"
	if not rejected:
		return "ownership: recovery took another player's loot"

	# Our hero stands in another room while a remote shell lies on our loot.
	_hero(p, HOME + SAFE_ROOM, false, false)
	var shell := Player.new()
	shell.game = g
	shell.peer_id = 2
	g.register_remote_player(shell)
	shell.set_physics_process(false)
	shell.global_position = HOME
	shell.net_set_down(1)
	# A kinematic teleport lands on the next physics step: let our hero
	# really leave HOME before the loot appears there.
	await _settle(g)
	var shell_gold := shell.gold
	var coin := _coin(g, HOME)
	var chest := _chest(g, HOME)
	var hooks := [0]
	chest.on_open = func() -> void: hooks[0] += 1
	await _settle(g)
	var touched: bool = coin.overlaps_body(shell) and chest.overlaps_body(shell)
	var armed: bool = coin._retry_contact or chest.is_physics_processing()
	shell.net_set_down(0)  # the owner's stand-up, mirrored onto the shell
	await _settle(g)
	coin._on_body_entered(shell)  # the standing shell touching it afresh
	chest._on_body_entered(shell)
	var ok: bool = is_instance_valid(coin) and not coin.claimed and not chest.opened \
		and hooks[0] == 0 and not chest.is_physics_processing() \
		and shell.gold == shell_gold and p.gold == gold_before
	g.players.erase(shell)
	_free_all([coin, chest, shell])
	_hero(p, HOME, false, false)
	if not touched:
		return "ownership: loot did not overlap the remote shell"
	if armed:
		return "ownership: a remote shell's contact left loot polling"
	return "" if ok else "ownership: a remote shell's stand-up collected our loot"
