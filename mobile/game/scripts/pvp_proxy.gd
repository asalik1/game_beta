extends Enemy
## PVP PROXY — the invisible Enemy standing exactly where the RIVAL's shell
## stands (PvP v1, pvp.gd). Player-vs-player damage is structurally impossible
## in the combat layer (every offensive path is typed to Enemy / scans the
## "enemies" group / masks players out of friendly projectiles) — so instead
## of rewiring all of it, each machine raises ONE of these: targeting acquires
## it, melee arcs sweep it, projectiles strike its layer-4 body, and every
## resolved hit lands in take_damage below, which forwards the amount over
## net_session.pvp_strike to the rival's OWN take_damage (owner-applied — their
## armor, evasion and crit-guards mitigate, the enemy->guest damage doctrine).
##
## Known v1 limits (deliberate): control riders (stuns/slows/roots) applied to
## the proxy do NOT reach the real rival — only damage crosses the wire; DoTs
## tick here at a flat 0.5 s cadence and forward like any other hit.
##
## NOT a session enemy: _ready is overridden so the host never announces it
## (no mirror on the far side), zone_idx stays -1 so it can never seal a door
## or count in a room census, and it pays no xp/gold because it never dies.

var foe: Player = null   # the rival's shell this proxy shadows

const DOT_TICK := 0.5    # forward cadence for burn/bleed riders parked on us


## Build on top of the ordinary Enemy plumbing (a throwaway "wolf" skeleton),
## then strip it to a pure hitbox: no stats of its own, no loot, no AI.
func setup_proxy(game_node: Node2D, foe_p: Player) -> void:
	_setup(game_node, "wolf", foe_p.global_position, 1, 1.0)
	foe = foe_p
	display_name = String(foe_p.get_meta("net_name", ""))
	if display_name == "":
		display_name = "Rival"
	level = foe_p.level
	max_hp = maxf(1.0, foe_p.max_hp)
	hp = clampf(foe_p.hp, 0.0, max_hp)
	xp_value = 0
	gold_value = 0
	speed = 0.0
	# Neutral defenses: the ATTACKER's pipeline resolves against these, and the
	# real mitigation belongs to the defender's own take_damage on their machine.
	physres = 0.0
	magres = 0.0
	eva = 0.0
	critres = 0.0
	crit = 0.0
	dex = 0.0
	physpen = 0.0
	magpen = 0.0
	traits = {}
	mend_rate = 0.0
	zone_idx = -1        # never hot-seals a room, never in a clear census
	collision_mask = 0   # pinned every frame, not simulated — collides with nothing
	visible = false      # the rival's SHELL is the visual; this is pure hitbox


## NEVER announce to the session — the base _ready registers host enemies with
## net_session, which would raise a phantom mirror on the rival's machine.
func _ready() -> void:
	pass


## No AI, no movement, no death: shadow the shell, mirror its vitals (execute
## thresholds and kill-window reads see true numbers), tick parked DoTs.
func _physics_process(delta: float) -> void:
	if foe == null or not is_instance_valid(foe) or game == null:
		return
	global_position = foe.global_position
	max_hp = maxf(1.0, foe.max_hp)
	hp = clampf(foe.hp, 0.0, max_hp)
	vuln_time = maxf(0.0, vuln_time - delta)
	stun_time = maxf(0.0, stun_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = DOT_TICK
			_forward_hit(burn_dps * DOT_TICK, burn_src, false, true)
	if bleed_time > 0.0:
		bleed_time -= delta
		bleed_tick -= delta
		if bleed_tick <= 0.0:
			bleed_tick = DOT_TICK
			_forward_hit(bleed_dps * DOT_TICK, bleed_src, false, true)


## Every resolved player hit funnels here (hit_enemy's terminal call, the
## projectile body hit, aegis reflects...). SILENT hits stay local-only: a
## hazard/dev sweep runs on BOTH machines and the rival's own copy already
## bills them directly — forwarding would double it.
func take_damage(amount: float, _from_dir := Vector2.ZERO, is_crit := false, silent := false) -> void:
	var striker: Player = hit_src if hit_src != null and is_instance_valid(hit_src) else null
	hit_src = null
	stat_src = null
	if silent:
		return
	if vuln_time > 0.0:
		amount *= vuln_mult
	_forward_hit(amount, striker, is_crit, false)


## A proxy never dies — falls belong to the real player's lethal branch.
func die() -> void:
	pass


## Ship one resolved amount to the rival's owner. The defender's take_damage
## runs attacker-less (their evasion + typed resist mitigate); the damage TYPE
## is class-derived — the one breadcrumb the Enemy funnel doesn't carry.
func _forward_hit(amount: float, striker: Player, is_crit: bool, quiet: bool) -> void:
	if game == null or game.pvp == null or not bool(game.pvp.combat_live()):
		return
	if foe == null or not is_instance_valid(foe) or foe.dead:
		return
	amount = maxf(0.0, amount) * Balance.PVP_DMG_MULT
	if amount <= 0.0:
		return
	var dtype := "phys"
	if striker != null and is_instance_valid(striker) and striker.cls in ["mage", "warlock"]:
		dtype = "magic"
	if not quiet:
		# Attacker-side juice (the mirror-hit pattern): the number and the sting
		# here, the victim's own hurt flash on their machine, vitals re-truth all.
		# No shell modulate flash — skins own their sprite tint (base_mod trap).
		game.sfx("ehit", 1.0, 0.0, 4.0)
		if is_crit:
			game.spawn_text(global_position + Vector2(0, -34), "%d!" % int(amount), Color(1.0, 0.55, 0.1))
		else:
			game.spawn_text(global_position + Vector2(0, -30), str(int(amount)), Color(1, 1, 1))
	hp = maxf(0.0, hp - amount)  # predicted; the vitals stream re-asserts
	game.net_session().pvp_strike(foe.peer_id, amount, dtype)
