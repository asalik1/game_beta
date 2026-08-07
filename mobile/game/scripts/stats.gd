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


## Evasion: knee at 50%, then a GENTLE overflow (EVA_OVERCAP_RATE, owner 2026-08-07)
## so a full dedicated eva stack tops out ~65% dodge — strong and rewarding for a
## heavy commitment, but not an unhittable wall (and answerable by ~matching dex).
static func eva_curve(e: float) -> float:
	return Balance.soft_cap(maxf(0.0, e), Balance.CAP_EVA, Balance.EVA_OVERCAP_RATE)


## How well `dex` answers `e_eva` — the DEX-vs-evasion gradient (Balance
## §DEX vs evasion). Returns the TIER, not a chance:
##   0 = outmatched: an evade is a full MISS
##   1 = closing:    an evade only GRAZES (Balance.GRAZE_DAMAGE)
##   2 = parity+:    evasion is CANCELLED outright, no roll at all
## Deterministic on purpose: the player can SEE which tier they're in and
## build out of it, where the old flat subtraction just bled a hidden
## dodge chance. Zero evasion is tier 2 — there is nothing to answer.
static func dex_tier(dex: float, e_eva: float) -> int:
	# DEX answers the CAPPED dodge chance (eva_curve), NOT the runaway raw stat
	# (owner 2026-08-07): stacking eva past the 50% chance cap no longer buys
	# uncounterability — the dodge keeps its full value, but a fixed, reachable DEX
	# (parity ~= 4 dex gems at the cap) answers it, so eva stays a viable build.
	var eff := eva_curve(e_eva)
	if eff <= 0.0:
		return 2
	var ratio: float = maxf(0.0, dex) * Balance.DEX_PER_EVA / eff
	if ratio >= 1.0:
		return 2
	return 1 if ratio >= Balance.DEX_GRAZE_RATIO else 0


## Fraction of damage a GRAZED hit pays through (the graze CURVE). 0 at the graze
## threshold (dodge still fully works), ramping convexly to 1.0 at parity (dodge
## cancelled). Only meaningful for a tier-1 (grazed) hit; matches dex_tier's bands.
static func graze_through(dex: float, e_eva: float) -> float:
	var eff := eva_curve(e_eva)
	if eff <= 0.0:
		return 1.0
	var ratio: float = maxf(0.0, dex) * Balance.DEX_PER_EVA / eff
	if ratio >= 1.0:
		return 1.0
	if ratio < Balance.DEX_GRAZE_RATIO:
		return 0.0
	var t: float = (ratio - Balance.DEX_GRAZE_RATIO) / (1.0 - Balance.DEX_GRAZE_RATIO)
	return pow(t, Balance.GRAZE_CURVE_EXP)


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
## Returns {"dmg": float, "crit": bool, "miss": bool, "graze": bool}.
## crit_exempt: cap-exempt crit (theme bonuses) added above the knee.
static func resolve(atk_dmg: float, dmg_type: String, crit_chance: float, crit_dmg: float,
		pen: float, dex: float, e_res: float, e_eva: float, e_critres: float,
		crit_exempt := 0.0) -> Dictionary:
	# DEX answers evasion as a TIER (dex_tier), not a subtraction: the target
	# rolls at its own evasion, and the tier decides whether that evade is a
	# full miss, a graze, or nothing at all. True damage always hits.
	var grazed := false
	if dmg_type != "true":
		var tier := dex_tier(dex, e_eva)
		if tier < 2:
			var eva := eva_curve(e_eva)
			if eva > 0.0 and randf() < eva:
				if tier == 0:
					return {"dmg": 0.0, "crit": false, "miss": true, "graze": false}
				grazed = true  # tier 1: it connects, but only just

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
	# The graze is the LAST cut, after crit/res/pen: it clips whatever the blow
	# would otherwise have paid. The graze CURVE (graze_through) scales the clip by
	# how far the attacker's DEX has climbed the counter band — near 0% just inside
	# it, ramping to full at parity — so the dodge degrades smoothly, not a flat 50%.
	if grazed:
		dmg *= graze_through(dex, e_eva)
	return {"dmg": dmg, "crit": is_crit, "miss": false, "graze": grazed}
