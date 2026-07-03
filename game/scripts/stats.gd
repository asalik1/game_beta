class_name Stats
## The combat math engine: diminishing-return curves and damage resolution.
##
## Damage types: "phys" (warrior/assassin/archer), "magic" (mage),
## "true" (ignores all defenses, cannot crit).

## Resistance -> damage reduction fraction. Logarithmic-style curve:
## 60 res = 33% reduction, 120 = 50%, 360 = 75%. Never reaches 100%.
static func res_frac(res: float) -> float:
	return maxf(0.0, res) / (maxf(0.0, res) + 120.0)


## Crit chance with strongly diminishing returns above 70%.
static func crit_curve(c: float) -> float:
	if c <= 0.7:
		return maxf(0.0, c)
	return 0.7 + 0.25 * (1.0 - exp(-(c - 0.7) * 2.0))  # asymptote ~95%


## Evasion is a chance, capped so nothing is unhittable.
static func eva_curve(e: float) -> float:
	return clampf(e, 0.0, 0.6)


## Combo: chance an ability doesn't go on cooldown. Capped.
static func combo_curve(c: float) -> float:
	return clampf(c, 0.0, 0.6)


## Greed -> bonus gold fraction. Diminishing above +50%.
static func greed_gold(g: float) -> float:
	if g <= 0.5:
		return maxf(0.0, g)
	return 0.5 + 0.3 * (1.0 - exp(-(g - 0.5) * 1.5))


## Greed -> bonus chest-drop chance (only above the 30% threshold).
static func greed_loot(g: float) -> float:
	if g <= 0.3:
		return 0.0
	return minf(0.10, (g - 0.3) * 0.2)


## Resolve one hit from the player against an enemy.
## Returns {"dmg": float, "crit": bool, "miss": bool}.
static func resolve(atk_dmg: float, dmg_type: String, crit_chance: float, crit_dmg: float,
		pen: float, dex: float, e_res: float, e_eva: float, e_critres: float) -> Dictionary:
	# DEX reduces enemy evasion before the dodge roll. True damage always hits.
	if dmg_type != "true":
		var eva := eva_curve(e_eva - dex * 0.004)
		if eva > 0.0 and randf() < eva:
			return {"dmg": 0.0, "crit": false, "miss": true}

	var dmg := atk_dmg
	var is_crit := false
	if dmg_type != "true":
		# Enemy crit resistance shaves the attacker's effective crit chance.
		var eff_crit := crit_curve(crit_chance) * (1.0 - res_frac(e_critres * 6.0))
		is_crit = randf() < eff_crit
		if is_crit:
			dmg *= crit_dmg
		# Penetration eats resistance; any EXCESS becomes bonus damage.
		var eff_res := maxf(0.0, e_res - pen)
		dmg *= (1.0 - res_frac(eff_res))
		if pen > e_res:
			dmg += (pen - e_res) * 0.5
	return {"dmg": dmg, "crit": is_crit, "miss": false}
