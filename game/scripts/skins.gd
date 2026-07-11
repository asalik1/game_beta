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
			"primary": Color(0.10, 0.10, 0.10),
			"trim":    Color(0.25, 0.25, 0.25),
			"accent":  Color(0.69, 0.69, 0.69)},
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.55, 0.10, 0.10),
			"trim":    Color(0.80, 0.13, 0.13),
			"accent":  Color(0.96, 0.78, 0.78)},
		{"id": "gilded", "name": "Gilded",
			"primary": Color(0.16, 0.12, 0.04),
			"trim":    Color(0.83, 0.63, 0.09),
			"accent":  Color(1.00, 0.95, 0.78)},
		{"id": "jade", "name": "Jade",
			"primary": Color(0.04, 0.16, 0.10),
			"trim":    Color(0.13, 0.77, 0.37),
			"accent":  Color(0.73, 0.97, 0.82)},
	],
	"archer": [
		{"id": "frost", "name": "Frost",
			"primary": Color(0.12, 0.23, 0.37),
			"trim":    Color(0.38, 0.65, 0.98),
			"accent":  Color(0.88, 0.95, 1.00)},
		{"id": "rose", "name": "Rose",
			"primary": Color(0.29, 0.10, 0.26),
			"trim":    Color(0.93, 0.28, 0.60),
			"accent":  Color(0.99, 0.91, 0.95)},
		{"id": "obsidian", "name": "Obsidian",
			"primary": Color(0.09, 0.09, 0.11),
			"trim":    Color(0.32, 0.32, 0.36),
			"accent":  Color(0.63, 0.63, 0.67)},
		{"id": "violet", "name": "Violet",
			"primary": Color(0.18, 0.06, 0.40),
			"trim":    Color(0.55, 0.36, 0.96),
			"accent":  Color(0.93, 0.91, 1.00)},
	],
	"mage": [
		{"id": "void", "name": "Void",
			"primary": Color(0.12, 0.06, 0.25),
			"trim":    Color(0.49, 0.23, 0.93),
			"accent":  Color(0.77, 0.71, 0.99)},
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.27, 0.04, 0.04),
			"trim":    Color(0.86, 0.15, 0.15),
			"accent":  Color(1.00, 0.79, 0.79)},
		{"id": "gilded", "name": "Gilded",
			"primary": Color(0.11, 0.07, 0.03),
			"trim":    Color(0.92, 0.70, 0.03),
			"accent":  Color(1.00, 0.98, 0.76)},
	],
	"assassin": [
		{"id": "arctic", "name": "Arctic",
			"primary": Color(0.05, 0.29, 0.43),
			"trim":    Color(0.22, 0.74, 0.97),
			"accent":  Color(0.88, 0.95, 1.00)},
		{"id": "gilded", "name": "Gilded",
			"primary": Color(0.11, 0.10, 0.09),
			"trim":    Color(0.96, 0.62, 0.04),
			"accent":  Color(1.00, 0.95, 0.78)},
		{"id": "white", "name": "White",
			"primary": Color(0.96, 0.96, 0.96),
			"trim":    Color(0.84, 0.83, 0.82),
			"accent":  Color(0.47, 0.44, 0.42)},
		{"id": "rose", "name": "Rose",
			"primary": Color(0.31, 0.03, 0.14),
			"trim":    Color(0.96, 0.25, 0.37),
			"accent":  Color(1.00, 0.89, 0.90)},
	],
	"paladin": [
		{"id": "onyx", "name": "Onyx",
			"primary": Color(0.09, 0.09, 0.11),
			"trim":    Color(0.25, 0.25, 0.27),
			"accent":  Color(0.63, 0.63, 0.67)},
		{"id": "emerald", "name": "Emerald",
			"primary": Color(0.02, 0.18, 0.09),
			"trim":    Color(0.09, 0.64, 0.29),
			"accent":  Color(0.73, 0.97, 0.82)},
		{"id": "crimson", "name": "Crimson",
			"primary": Color(0.27, 0.04, 0.04),
			"trim":    Color(0.86, 0.15, 0.15),
			"accent":  Color(1.00, 0.79, 0.79)},
	],
	"warlock": [
		{"id": "hellfire", "name": "Hellfire",
			"primary": Color(0.10, 0.04, 0.00),
			"trim":    Color(0.92, 0.35, 0.05),
			"accent":  Color(1.00, 0.84, 0.67)},
		{"id": "blight", "name": "Blight",
			"primary": Color(0.02, 0.18, 0.09),
			"trim":    Color(0.13, 0.77, 0.37),
			"accent":  Color(0.73, 0.97, 0.82)},
		{"id": "bone", "name": "Bone",
			"primary": Color(0.96, 0.96, 0.96),
			"trim":    Color(0.66, 0.64, 0.62),
			"accent":  Color(0.34, 0.33, 0.31)},
	],
}


## Elite + Mythic skin definitions. Each entry:
## {id, name, tier, sprite} where sprite is the Art name (looked up via
## Art.tex / hero_clips / dir_set under assets/sprites/).
const SKINS := {
	"warrior": [
		{"id": "dreadknight", "name": "Dreadknight", "tier": "elite",
			"sprite": "skins/elite/warrior_dreadknight"},
		{"id": "stormforged", "name": "Stormforged", "tier": "mythic",
			"sprite": "skins/mythic/warrior_stormforged"},
	],
	"archer": [
		{"id": "astral_marksman", "name": "Astral Marksman", "tier": "elite",
			"sprite": "skins/elite/archer_astral_marksman"},
		{"id": "plague_doctor", "name": "Plague Doctor", "tier": "mythic",
			"sprite": "skins/mythic/archer_plague_doctor"},
	],
	"mage": [
		{"id": "void_weaver", "name": "Void Weaver", "tier": "elite",
			"sprite": "skins/elite/mage_void_weaver"},
		{"id": "crystal_archmage", "name": "Crystal Archmage", "tier": "mythic",
			"sprite": "skins/mythic/mage_crystal_archmage"},
	],
	"assassin": [
		{"id": "blade_dancer", "name": "Blade Dancer", "tier": "elite",
			"sprite": "skins/elite/assassin_blade_dancer"},
		{"id": "phantom", "name": "Phantom", "tier": "mythic",
			"sprite": "skins/mythic/assassin_phantom"},
	],
	"paladin": [
		{"id": "eclipse_knight", "name": "Eclipse Knight", "tier": "elite",
			"sprite": "skins/elite/paladin_eclipse_knight"},
		{"id": "fallen_arbiter", "name": "Fallen Arbiter", "tier": "mythic",
			"sprite": "skins/mythic/paladin_fallen_arbiter"},
	],
	"warlock": [
		{"id": "hellfire_inquisitor", "name": "Hellfire Inquisitor", "tier": "elite",
			"sprite": "skins/elite/warlock_hellfire_inquisitor"},
		{"id": "eldritch_herald", "name": "Eldritch Herald", "tier": "mythic",
			"sprite": "skins/mythic/warlock_eldritch_herald"},
	],
}


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
static func skin_sprite(cls: String, skin_id: String) -> String:
	var data: Dictionary = find_skin(cls, skin_id)
	if data.is_empty():
		return ""
	return data["sprite"]


## Build (or update) a ShaderMaterial for the chroma effect. When
## chroma_id is "" the material is deactivated (chroma_active = 0).
## Reuses the existing material on the sprite when one is already set
## to avoid thrashing the render state.
static func apply_to_sprite(spr: Sprite2D, cls: String, chroma_id: String) -> void:
	if chroma_id == "":
		# Deactivate: if a chroma material is already on, flip the flag
		# off instead of removing it (avoids alloc next time).
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
