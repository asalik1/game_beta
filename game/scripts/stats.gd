class_name Stats
## The combat math engine: diminishing-return curves and damage resolution.
##
## Damage types: "phys" (warrior/assassin/archer), "magic" (mage),
## "true" (ignores all defenses, cannot crit).

# Every cap below is a SOFT KNEE (Balance.soft_cap, player rule
# 2026-07-06): full value up to the cap, ~1/10 conversion beyond —
# greatly diminishing, never a dead stop.

## Resistance -> damage reduction fraction. Saturating curve (60 res =
## 33%, 120 = 50%, 360 = 75%), with the REDUCTION itself knee'd at 80%.
static func res_frac(res: float) -> float:
	var f := maxf(0.0, res) / (maxf(0.0, res) + 120.0)
	return Balance.soft_cap(f, Balance.CAP_RES_FRAC)


## Crit chance: knee at 35%, diminishing at a gentler 1/5 (crit is a
## payoff stat — the harsh 1/10 knees guard the SYSTEM-breakers).
static func crit_curve(c: float) -> float:
	return Balance.soft_cap(maxf(0.0, c), Balance.CAP_CRIT, Balance.CRIT_SOFT_RATE)


## Evasion: knee at 50% — nothing approaches unhittable.
static func eva_curve(e: float) -> float:
	return Balance.soft_cap(maxf(0.0, e), Balance.CAP_EVA)


## Combo: chance an ability doesn't go on cooldown. Its knee lives in
## recalc (combo is gem-built with no temp sources); this only floors.
static func combo_curve(c: float) -> float:
	return maxf(0.0, c)


## Greed -> bonus gold fraction. Knee at 40%.
static func greed_gold(g: float) -> float:
	return Balance.soft_cap(maxf(0.0, g), Balance.CAP_GREED)


## Greed -> bonus chest-drop chance: applies from the FIRST point
## (player rule 2026-07-06 — the 30% threshold is gone), bounded so
## drop tables stay sane.
static func greed_loot(g: float) -> float:
	return minf(0.10, maxf(0.0, g) * 0.2)


## (Level gaps carry NO special combat rule: monster stats compound
## per level — Story.enemy_stats_at — so a +10 monster's raw numbers
## are the wall, and the codex never lies about it.)

## Effective crit chance against a target: the BUILT stat rides the 35%
## knee; `exempt` (theme crit_bonus + theme-line talents) is added ABOVE
## the knee at full value (player rule 2026-07-06 — themes may exceed
## caps). Enemy crit-res still shaves the total: it's their stat, not a cap.
static func effective_crit(c: float, exempt: float, e_critres: float) -> float:
	return (crit_curve(c) + maxf(0.0, exempt)) * (1.0 - res_frac(e_critres * 6.0))


## Resolve one hit from the player against an enemy.
## Returns {"dmg": float, "crit": bool, "miss": bool}.
## crit_exempt: cap-exempt crit (theme bonuses) added above the knee.
static func resolve(atk_dmg: float, dmg_type: String, crit_chance: float, crit_dmg: float,
		pen: float, dex: float, e_res: float, e_eva: float, e_critres: float,
		crit_exempt := 0.0) -> Dictionary:
	# DEX reduces enemy evasion before the dodge roll. True damage always hits.
	if dmg_type != "true":
		var eva := eva_curve(e_eva - dex * 0.004)
		if eva > 0.0 and randf() < eva:
			return {"dmg": 0.0, "crit": false, "miss": true}

	var dmg := atk_dmg
	var is_crit := false
	if dmg_type != "true":
		# Enemy crit resistance shaves the attacker's effective crit chance.
		var eff_crit := effective_crit(crit_chance, crit_exempt, e_critres)
		is_crit = randf() < eff_crit
		if is_crit:
			dmg *= crit_dmg
		# Penetration eats resistance; any EXCESS becomes bonus damage.
		var eff_res := maxf(0.0, e_res - pen)
		dmg *= (1.0 - res_frac(eff_res))
		if pen > e_res:
			dmg += (pen - e_res) * 0.5
	return {"dmg": dmg, "crit": is_crit, "miss": false}
