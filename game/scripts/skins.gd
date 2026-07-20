class_name Skins
## Chroma (palette-swap) skin system: per-class cosmetic recolors.
## Chromas are the cheapest cosmetic tier -- a simple recolor of the
## character's existing sprite via a luminance-mapped shader. No new
## sprite sheets, no FX changes. Think League of Legends chromas.
##
## Data lives here; rendering integration is in player_core.gd
## (apply_chroma / _chroma_material). Persistence is in save.gd
## (character section, "chroma" key).

## The preloaded chroma shader (see shaders/chroma.gdshader).
## Recolors non-skin, non-outline pixels by mapping luminance to a
## three-stop gradient (primary=dark, trim=mid, accent=light).
static var _shader: Shader = null

static func _get_shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/chroma.gdshader")
	return _shader


## Per-class chroma definitions. Each entry: {id, name, primary, trim, accent}.
## primary = dark armor tones, trim = mid tones, accent = highlights.
const CHROMAS := {
	"warrior": [
		{"id": "obsidian", "name": "Obsidian",
			"primary": Color(0.05, 0.02, 0.12),
			"trim":    Color(0.18, 0.08, 0.42),
			"accent":  Color(0.52, 0.35, 0.82)},
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.14, 0.01, 0.01),
			"trim":    Color(0.58, 0.06, 0.06),
			"accent":  Color(1.00, 0.25, 0.18)},
		{"id": "gilded", "name": "Gilded",
			"primary": Color(0.14, 0.11, 0.00),
			"trim":    Color(0.72, 0.55, 0.02),
			"accent":  Color(1.00, 0.92, 0.15)},
		{"id": "jade", "name": "Jade",
			"primary": Color(0.01, 0.08, 0.03),
			"trim":    Color(0.06, 0.45, 0.18),
			"accent":  Color(0.40, 0.92, 0.50)},
	],
	"archer": [
		{"id": "ember", "name": "Ember",
			"primary": Color(0.14, 0.05, 0.00),
			"trim":    Color(0.68, 0.28, 0.02),
			"accent":  Color(1.00, 0.52, 0.05)},
		{"id": "rose", "name": "Rose",
			"primary": Color(0.12, 0.00, 0.10),
			"trim":    Color(0.62, 0.03, 0.55),
			"accent":  Color(1.00, 0.28, 0.90)},
		{"id": "jade", "name": "Jade",
			"primary": Color(0.01, 0.08, 0.03),
			"trim":    Color(0.05, 0.42, 0.16),
			"accent":  Color(0.35, 0.90, 0.48)},
		{"id": "violet", "name": "Violet",
			"primary": Color(0.08, 0.01, 0.14),
			"trim":    Color(0.38, 0.08, 0.62),
			"accent":  Color(0.75, 0.42, 1.00)},
	],
	"mage": [
		{"id": "void", "name": "Void",
			"primary": Color(0.06, 0.01, 0.14),
			"trim":    Color(0.32, 0.10, 0.65),
			"accent":  Color(0.68, 0.48, 1.00)},
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.14, 0.01, 0.01),
			"trim":    Color(0.60, 0.06, 0.06),
			"accent":  Color(1.00, 0.30, 0.22)},
		{"id": "gilded", "name": "Gilded",
			"primary": Color(0.12, 0.10, 0.00),
			"trim":    Color(0.68, 0.52, 0.02),
			"accent":  Color(1.00, 0.92, 0.20)},
	],
	"assassin": [
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.14, 0.01, 0.01),
			"trim":    Color(0.62, 0.04, 0.04),
			"accent":  Color(1.00, 0.18, 0.12)},
		{"id": "gilded", "name": "Gilded",
			"primary": Color(0.14, 0.12, 0.00),
			"trim":    Color(0.75, 0.58, 0.02),
			"accent":  Color(1.00, 0.95, 0.12)},
		{"id": "white", "name": "White",
			"primary": Color(0.04, 0.05, 0.12),
			"trim":    Color(0.40, 0.46, 0.65),
			"accent":  Color(0.82, 0.88, 1.00)},
		{"id": "rose", "name": "Rose",
			"primary": Color(0.12, 0.00, 0.12),
			"trim":    Color(0.62, 0.02, 0.58),
			"accent":  Color(1.00, 0.22, 0.95)},
	],
	"paladin": [
		{"id": "onyx", "name": "Onyx",
			"primary": Color(0.05, 0.02, 0.10),
			"trim":    Color(0.18, 0.12, 0.35),
			"accent":  Color(0.48, 0.38, 0.72)},
		{"id": "emerald", "name": "Emerald",
			"primary": Color(0.01, 0.08, 0.03),
			"trim":    Color(0.05, 0.45, 0.16),
			"accent":  Color(0.38, 0.92, 0.48)},
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.14, 0.01, 0.01),
			"trim":    Color(0.58, 0.06, 0.06),
			"accent":  Color(1.00, 0.28, 0.20)},
	],
	"warlock": [
		{"id": "hellfire", "name": "Hellfire",
			"primary": Color(0.12, 0.03, 0.00),
			"trim":    Color(0.62, 0.18, 0.02),
			"accent":  Color(1.00, 0.50, 0.10)},
		{"id": "blight", "name": "Blight",
			"primary": Color(0.01, 0.08, 0.02),
			"trim":    Color(0.06, 0.48, 0.16),
			"accent":  Color(0.42, 0.95, 0.45)},
		{"id": "bone", "name": "Bone",
			"primary": Color(0.08, 0.07, 0.06),
			"trim":    Color(0.50, 0.48, 0.42),
			"accent":  Color(0.95, 0.92, 0.82)},
	],
}


## Elite + Mythic skin definitions. Each entry:
## {id, name, tier, sprite} where sprite is the Art name (looked up via
## Art.tex / hero_clips / dir_set under assets/sprites/).
const SKINS := {
	# Completed MYTHIC awakening art follows the Phantom->Nightfang pattern:
	# completing the class's S-weapon awakening evolves the skin's palette
	# family. Eldritch Warlock intentionally ships without that sprite upgrade;
	# the awakening-art pass is later and must not block nailing its abilities.
	"warrior": [
		{"id": "dreadknight", "name": "Dreadknight", "tier": "elite",
			"sprite": "skins/elite/warrior_dreadknight"},
		# Awakened: the storm wakes — the plate deepens toward violet, the
		# charged accents flare, and the face itself ignites storm-light.
		{"id": "stormforged", "name": "Stormforged", "tier": "mythic",
			"sprite": "skins/mythic/warrior_stormforged",
			"awakened_sprite": "skins/mythic/warrior_stormforged_awakened"},
	],
	"archer": [
		{"id": "frostfall_ranger", "name": "Frostfall Ranger", "tier": "elite",
			"sprite": "skins/elite/archer_frostfall_ranger"},
		# Awakened: the void deepens — the grey cloak drinks dusk-violet and
		# every purple accent surges toward glowing magenta.
		{"id": "voidwraith", "name": "Voidwraith", "tier": "mythic",
			"sprite": "skins/mythic/archer_voidwraith",
			"awakened_sprite": "skins/mythic/archer_voidwraith_awakened"},
	],
	"mage": [
		# Awakened: prismatic — bright facets bleach to white light while the
		# robe's shadows refract indigo-violet.
		{"id": "crystal_archmage", "name": "Crystal Archmage", "tier": "mythic",
			"sprite": "skins/mythic/mage_crystal_archmage",
			"awakened_sprite": "skins/mythic/mage_crystal_archmage_awakened"},
	],
	"assassin": [
		# Golden Ronin (id kept as "blade_dancer" for save/sprite-path compat).
		# Signature FX: its knife-throw (Fan of Knives) hurls spinning shuriken
		# with a fading after-image instead of the kunai — see player_kit_assassin.
		{"id": "blade_dancer", "name": "Golden Ronin", "tier": "elite",
			"sprite": "skins/elite/assassin_blade_dancer"},
		{"id": "phantom", "name": "Phantom", "tier": "mythic",
			"sprite": "skins/mythic/assassin_phantom",
			# Awakened form: completing the assassin's S-weapon awakening
			# (flag s_awakened_assassin) evolves the blue Phantom into the teal
			# spectral "Nightfang" form — same skin, a progression payoff. The
			# render resolver (player_core._apply_class_sprite) swaps to this
			# base when the flag is set; falls back to `sprite` otherwise.
			"awakened_sprite": "skins/mythic/assassin_phantom_awakened"},
	],
	"paladin": [
		{"id": "eclipse_knight", "name": "Eclipse Knight", "tier": "elite",
			"sprite": "skins/elite/paladin_eclipse_knight"},
		# Awakened: the light goes cold — halo, crown and every gold trim
		# bleach to silver-white over the black wings; the verdict has no
		# warmth left in it.
		{"id": "fallen_arbiter", "name": "Fallen Arbiter", "tier": "mythic",
			"sprite": "skins/mythic/paladin_fallen_arbiter",
			"awakened_sprite": "skins/mythic/paladin_fallen_arbiter_awakened"},
	],
	"warlock": [
		{"id": "hellfire_inquisitor", "name": "Hellfire Inquisitor", "tier": "elite",
			"sprite": "skins/elite/warlock_hellfire_inquisitor"},
		# The former Eldritch Herald is retained as an elite under its new identity.
		# Its existing green kit remains untouched and receives no awakening pass.
		{"id": "arcane_warlock", "name": "Arcane Warlock", "tier": "elite",
			"sprite": "skins/mythic/warlock_eldritch_herald"},
		# Eldritch Warlock inherits the exact Void Weaver character art. The Mage
		# no longer exposes an elite skin; there is one shared source asset, not a
		# duplicate copy under a second class path.
		{"id": "eldritch_warlock", "name": "Eldritch Warlock", "tier": "mythic",
			"sprite": "skins/elite/mage_void_weaver"},
	],
}


## Skin swing-sync (2026-07-13): a skin's AI-generated strike clips land their
## contact on a DIFFERENT frame than the base-class clips the Balance delay
## consts are tuned to — so the base delay fires the FX ahead of the skin's
## swing. Maps class -> skin_id -> clip -> contact time (s), MEASURED from the
## installed strike strips (motion-peak). Abilities that swing these clips
## delay their FX to this time via player.swing_delay() instead of the shared
## base const. Only skins that DIVERGE need an entry; missing = base const.
## (Archers omitted — their loose already lands ~at ARCHER_LOOSE_DELAY.)
const SWING := {
	"warrior": {
		"dreadknight": {"attack": 0.227},
		"stormforged": {"attack": 0.227},
	},
	"mage": {
		"crystal_archmage": {"attack": 0.227},
	},
	"assassin": {
		"blade_dancer": {"attack": 0.182, "attack2": 0.227},
		"phantom": {"attack": 0.227, "attack2": 0.182},
	},
	# Judgment (a1) lands the golden shock on the overhead-hammer contact (~frame
	# 4). Consecration (attack2) is a near-static channel with no crisp contact —
	# left on the base const.
	"paladin": {
		"eclipse_knight": {"attack": 0.182},
		"fallen_arbiter": {"attack": 0.182},
	},
	# Shadowbolt (a1, "attack" clip) looses as the bolt leaves the staff (~frame
	# 5). Hex (a2) swings the "ult" clip, whose energy doesn't erupt until ~0.5s —
	# syncing there would over-slow the curse per-skin, so Hex stays on the base
	# WARLOCK_CAST_DELAY.
	"warlock": {
		"hellfire_inquisitor": {"attack": 0.227},
		"arcane_warlock": {"attack": 0.227},
		"eldritch_warlock": {"attack": 0.182},
	},
}


## Contact time (s) for a skin's strike clip, or -1.0 if none (use base delay).
static func swing_time(cls: String, skin_id: String, clip: String) -> float:
	var byskin: Dictionary = SWING.get(cls, {})
	var byclip: Dictionary = byskin.get(skin_id, {})
	return float(byclip.get(clip, -1.0))


## Per-skin vertical anchor nudge (source-cell px). The hero render grounds every
## character on its LOWEST opaque pixel; for a skin whose weapon points BELOW the
## boots (Stormforged's E/W sword) that lands the blade tip on the ground line and
## reads as "cut off." A positive nudge shifts the skin DOWN so the FEET ground and
## the blade hangs below. Default 0 — every other skin keeps the shared anchor,
## so the approved robe/cape skins (incl. Phantom) are untouched. Owner-tuned by
## eye. See [[hero-anchor-blade-cutoff-diagnosis]].
const ANCHOR_NUDGE := {
	# (Stormforged tried here, but a nudge moves the whole sprite — it can't lift
	# the blade OUT of the terrain without floating the feet, since the blade is
	# drawn below the boots in the art itself. Left empty; fix is an art re-pose.)
}

static func anchor_nudge(skin_id: String) -> float:
	return float(ANCHOR_NUDGE.get(skin_id, 0.0))


## All chromas available for a class, or [] if none.
static func chromas_for(cls: String) -> Array:
	return CHROMAS.get(cls, [])


## Look up a chroma by class + id. Returns {} when not found.
static func find(cls: String, chroma_id: String) -> Dictionary:
	for entry in chromas_for(cls):
		if entry["id"] == chroma_id:
			return entry
	return {}


## All skins (elite + mythic) for a class, or [] if none.
static func skins_for(cls: String) -> Array:
	return SKINS.get(cls, [])


## Look up a skin by class + id. Returns {} when not found.
static func find_skin(cls: String, skin_id: String) -> Dictionary:
	for entry in skins_for(cls):
		if entry["id"] == skin_id:
			return entry
	return {}


## Return the Art sprite name for a skin, or "" if invalid/no skin.
## When `awakened` (the skin's class has completed its S-weapon awakening) and
## the skin defines an `awakened_sprite`, returns that evolved base instead —
## e.g. Phantom's teal Nightfang form. Skins without one ignore the flag.
static func skin_sprite(cls: String, skin_id: String, awakened := false) -> String:
	var data: Dictionary = find_skin(cls, skin_id)
	if data.is_empty():
		return ""
	if awakened and data.has("awakened_sprite"):
		return String(data["awakened_sprite"])
	return String(data["sprite"])


## Build (or update) a ShaderMaterial for the chroma effect. When
## chroma_id is "" the material is deactivated (chroma_active = 0).
## Reuses the existing material on the sprite when one is already set
## to avoid thrashing the render state.
static func apply_to_sprite(spr: Sprite2D, cls: String, chroma_id: String) -> void:
	if chroma_id == "":
		var mat: ShaderMaterial = spr.material as ShaderMaterial
		if mat != null and mat.shader == _get_shader():
			mat.set_shader_parameter("chroma_active", 0.0)
		return
	var data: Dictionary = find(cls, chroma_id)
	if data.is_empty():
		return
	var mat: ShaderMaterial = spr.material as ShaderMaterial
	if mat == null or mat.shader != _get_shader():
		mat = ShaderMaterial.new()
		mat.shader = _get_shader()
		spr.material = mat
	mat.set_shader_parameter("chroma_active", 1.0)
	mat.set_shader_parameter("chroma_primary", Vector3(data["primary"].r, data["primary"].g, data["primary"].b))
	mat.set_shader_parameter("chroma_trim", Vector3(data["trim"].r, data["trim"].g, data["trim"].b))
	mat.set_shader_parameter("chroma_accent", Vector3(data["accent"].r, data["accent"].g, data["accent"].b))
