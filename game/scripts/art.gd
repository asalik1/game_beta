class_name Art
## Procedural pixel-art factory.
## Every sprite in the game is defined here as a grid of characters
## (one character = one pixel, "." = transparent). At boot we convert
## these grids into textures, so the project needs zero image files.

static var _cache: Dictionary = {}

# Shared palette: character -> color.
const PAL := {
	"k": Color(0.07, 0.06, 0.09),   # outline / near-black
	"w": Color(0.94, 0.94, 0.96),   # white / bone
	"s": Color(0.72, 0.76, 0.84),   # steel
	"S": Color(0.45, 0.50, 0.60),   # dark steel
	"e": Color(0.55, 0.55, 0.62),   # grey (rock, wolf fur)
	"E": Color(0.30, 0.30, 0.38),   # dark grey
	"b": Color(0.30, 0.50, 0.92),   # blue
	"B": Color(0.16, 0.24, 0.50),   # dark blue
	"r": Color(0.88, 0.22, 0.20),   # red
	"R": Color(0.50, 0.10, 0.12),   # dark red
	"g": Color(0.45, 0.75, 0.35),   # light green
	"G": Color(0.20, 0.45, 0.24),   # green
	"y": Color(0.96, 0.84, 0.30),   # gold
	"o": Color(0.95, 0.55, 0.15),   # orange
	"n": Color(0.55, 0.38, 0.22),   # brown
	"N": Color(0.33, 0.22, 0.12),   # dark brown
	"p": Color(0.75, 0.45, 0.95),   # light purple
	"P": Color(0.40, 0.20, 0.55),   # purple
	"f": Color(0.94, 0.78, 0.62),   # skin
}

# Sprite definitions. "over" optionally re-colors palette characters
# for that one sprite (used to make the witch a purple cultist, etc).
const SPRITES := {
	"knight": {"rows": [
		"................",
		".....kkkkkk.....",
		"....kssssssk....",
		"....kssssssk....",
		"....kEsEEsEk....",
		"....kssssssk....",
		".....kssssk.....",
		"...kBssssssBk...",
		"..kBBssbbssBBk..",
		"..kBBssbbssBBk..",
		"..kB.kssssk.Bk..",
		".....kssssk.....",
		"....kss..ssk....",
		"....kSs..sSk....",
		"....kkk..kkk....",
		"................",
	]},
	"wolf": {"rows": [
		"................",
		"................",
		"..........kk....",
		".k........keek..",
		".kk......keeeek.",
		"..kkkkkkkeeeeek.",
		"..keeeeeeeeeekk.",
		"...keeeeeeeeek..",
		"...keeeeeeeek...",
		"....keeeeeek....",
		"....kek..kek....",
		"....kk....kk....",
		"................",
		"................",
		"................",
		"................",
	]},
	"spider": {"rows": [
		"................",
		"................",
		"................",
		"....k......k....",
		".k..k......k..k.",
		".k...kkkkkk...k.",
		"..k.kPPPPPPk.k..",
		"..kkkPrPPrPkkk..",
		".k..kPPPPPPk..k.",
		".k...kkkkkk...k.",
		"....k......k....",
		"...k........k...",
		"................",
		"................",
		"................",
		"................",
	]},
	"cultist": {"rows": [
		"................",
		".....kkkkkk.....",
		"....kGGGGGGk....",
		"...kGGGGGGGGk...",
		"...kGkkkkkkGk...",
		"...kGkkrkkrkkGk.",
		"....kGGGGGGk....",
		"....kGGGGGGk....",
		"...kGGGGGGGGk...",
		"...kGGNNNNGGk...",
		"...kGGGGGGGGk...",
		"..kGGGGGGGGGGk..",
		"..kGGGGGGGGGGk..",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
	]},
	"witch": {"rows": [
		"................",
		".....kkkkkk.....",
		"....kGGGGGGk....",
		"...kGGGGGGGGk...",
		"...kGkkkkkkGk...",
		"...kGkkrkkrkkGk.",
		"....kGGGGGGk....",
		"....kGGGGGGk....",
		"...kGGGGGGGGk...",
		"...kGGNNNNGGk...",
		"...kGGGGGGGGk...",
		"..kGGGGGGGGGGk..",
		"..kGGGGGGGGGGk..",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
	], "over": {"G": Color(0.40, 0.20, 0.55), "r": Color(0.45, 1.0, 0.55), "N": Color(0.75, 0.45, 0.95)}},
	"skeleton": {"rows": [
		"................",
		".....kkkkk......",
		"....kwwwwwk.....",
		"....kwEwEwk.....",
		"....kwwkwwk.....",
		".....kkkkk......",
		"......kwk.......",
		"...kkkwwwkkk....",
		"....kwkwkwk.....",
		"....kwwwwwk.....",
		"......kwk.......",
		"....kkwwwkk.....",
		"....kw...wk.....",
		"....kw...wk.....",
		"...kkw...wkk....",
		"................",
	]},
	"king": {"rows": [
		"....y.y.y.y.....",
		"....yyyyyyy.....",
		"....kwwwwwk.....",
		"....kwrwrwk.....",
		"....kwwkwwk.....",
		".....kkkkk......",
		"..kPPkkwkkPPk...",
		".kPPkwwwwwkPPk..",
		".kPPkwkwkwkPPk..",
		".kPPkwwwwwkPPk..",
		".kPP.kwwwk.PPk..",
		".kP..kkwkk..Pk..",
		".kk.kw...wk.kk..",
		"....kw...wk.....",
		"...kkw...wkk....",
		"................",
	]},
	"elder": {"rows": [
		"................",
		".....kkkkkk.....",
		"....knnnnnnk....",
		"....kffffffk....",
		"....kfEffEfk....",
		"....kwwwwwwk....",
		".....kwwwwk.....",
		"....knnnnnnk....",
		"...knnnnnnnnk...",
		"...knnNNNNnnk...",
		"...knnnnnnnnk...",
		"..knnnnnnnnnnk..",
		"..knnnnnnnnnnk..",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
	]},
	"tree": {"rows": [
		".....kkkkk......",
		"...kkGGGGGkk....",
		"..kGGGgGGGGGk...",
		".kGGgggGGGGGGk..",
		".kGGgggGGGGGGk..",
		".kGGGgGGGGGGGk..",
		"..kGGGGGGGGGk...",
		"...kkGGGGGkk....",
		".....kkkkk......",
		"......kNNk......",
		"......kNNk......",
		"......kNNk......",
		".....kNNNNk.....",
		"................",
		"................",
		"................",
	]},
	"deadtree": {"rows": [
		"................",
		"..k.....k.......",
		"..kk...kk..k....",
		"...kNkkNk.kk....",
		"....kNNNNkkk....",
		".....kNNk.......",
		".....kNNk.......",
		".....kNNk.......",
		"....kNNNNk......",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"rock": {"rows": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"....kkkkk.......",
		"...keeeeekk.....",
		"..keeeweeeeek...",
		"..keeeeeeEEek...",
		"..kEEeeeEEEEk...",
		"...kkkkkkkkk....",
		"................",
		"................",
	]},
	"pillar": {"rows": [
		"................",
		"................",
		"....kkkkkkk.....",
		"....keeeeek.....",
		"....kEEEEEk.....",
		".....keeek......",
		".....keeek......",
		".....keeek......",
		".....keeek......",
		".....keeek......",
		".....keeek......",
		".....keeek......",
		"....keeeeek.....",
		"....kkkkkkk.....",
		"................",
		"................",
	]},
	"wallblock": {"rows": [
		"kkkkkkkkkkkkkkkk",
		"keeeeeeekeeeeeek",
		"keeeeeeekeeeeeek",
		"kEEEEEEEkEEEEEEk",
		"kkkkkkkkkkkkkkkk",
		"keeekeeeeeeekeek",
		"keeekeeeeeeekeek",
		"kEEEkEEEEEEEkEEk",
		"kkkkkkkkkkkkkkkk",
		"keeeeeeekeeeeeek",
		"keeeeeeekeeeeeek",
		"kEEEEEEEkEEEEEEk",
		"kkkkkkkkkkkkkkkk",
		"keeekeeeeeeekeek",
		"keeekeeeeeeekeek",
		"kEEEkEEEEEEEkEEk",
	]},
	"gate": {"rows": [
		"kkkkkkkkkkkkkkkk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNNNNNNNNNNNNNNk",
		"kNNNNNNNNNNNNNNk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kNnnkNnnkNnnkNnk",
		"kkkkkkkkkkkkkkkk",
	]},
	"fireball": {"rows": [
		"...kk...",
		"..kyyk..",
		".kyooyk.",
		".kyoryk.",
		".kyooyk.",
		"..kyyk..",
		"...kk...",
		"........",
	]},
	"bolt": {"rows": [
		"...kk...",
		"..kppk..",
		".kpPPpk.",
		".kpPPpk.",
		".kpPPpk.",
		"..kppk..",
		"...kk...",
		"........",
	]},
	"potion": {"rows": [
		"................",
		"................",
		"......kkkk......",
		".......kk.......",
		".......kk.......",
		"......krrk......",
		".....krrrrk.....",
		"....krrrrrrk....",
		"....krrwrrrk....",
		"....krrrrrrk....",
		".....krrrrk.....",
		"......kkkk......",
		"................",
		"................",
		"................",
		"................",
	]},
	# ------------------------------------------------- hero classes ---
	"warrior": {"rows": [
		"......rr........",
		".....krrk.......",
		".....kssssk.....",
		"....kssssssk....",
		"....ksEssEsk....",
		"....kssssssk....",
		".....kSSSSk.....",
		"...kssssssssk...",
		"...ksSrrrrSsk...",
		"..kEksrrrrskEk..",
		"..kEksSrrSskEk..",
		"...k.kssssk.k...",
		"....kss..ssk....",
		"....kSs..sSk....",
		"....kkk..kkk....",
		"................",
	]},
	"archer": {"rows": [
		"................",
		".....kkkkkk.....",
		"....kGGGGGGk....",
		"...kGGGGGGGGk...",
		"...kGkffffkGk...",
		"...kGkfEfEfkGk..",
		"....kGffffGk....",
		"....kGGGGGGk....",
		"...knGGGGGGnk...",
		"...knGNNNNGnk...",
		"...knGGGGGGnk...",
		"....kGGGGGGk....",
		"....knn..nnk....",
		"....kNn..nNk....",
		"....kkk..kkk....",
		"................",
	]},
	"mage": {"rows": [
		".......kk.......",
		"......kbbk......",
		".....kbbbbk.....",
		"....kbbbbbbk....",
		"..kkkkkkkkkkkk..",
		"....kffffffk....",
		"....kfEffEfk....",
		"....kffffffk....",
		"....kbbbbbbk....",
		"...kbbBwwBbbk...",
		"...kbbbbbbbbk...",
		"..kbbbbbbbbbbk..",
		"..kbbbbbbbbbbk..",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
	]},
	"assassin": {"rows": [
		"................",
		".....kkkkkk.....",
		"....kEEEEEEk....",
		"...kEEEEEEEEk...",
		"...kEkkkkkkEk...",
		"...kEkkrkkrkkEk.",
		"....kEEkkEEk....",
		"....kEEEEEEk....",
		"...kEEEEEEEEk...",
		"...kEERRRREEk...",
		"...kEEEEEEEEk...",
		"....kEEEEEEk....",
		"....kEE..EEk....",
		"....kkk..kkk....",
		"................",
		"................",
	]},
	# --------------------------------------------------- loot & NPCs ---
	"merchant": {"rows": [
		"................",
		".....kkkkkk.....",
		"....knnnnnnk....",
		"...knnnnnnnnk...",
		"...knkffffknk...",
		"...knkfEfEfknk..",
		"....knffffnk....",
		"....kyyyyyyk....",
		"...kPPPPPPPPk...",
		"...kPPyPPyPPk...",
		"..kPPPPPPPPPPk..",
		"..kPPPPPPPPPPk..",
		"..kkkkkkkkkkkk..",
		"................",
		"................",
		"................",
	]},
	"chest_wood": {"rows": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		".knnnnnnnnnnnnk.",
		".knnnnnnnnnnnnk.",
		".kkkkkkkkkkkkkk.",
		".knnnnkyyknnnnk.",
		".knnnnkyyknnnnk.",
		".knnnnnnnnnnnnk.",
		".kkkkkkkkkkkkkk.",
		"................",
		"................",
		"................",
	]},
	"chest_silver": {"rows": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		".knnnnnnnnnnnnk.",
		".knnnnnnnnnnnnk.",
		".kkkkkkkkkkkkkk.",
		".knnnnkyyknnnnk.",
		".knnnnkyyknnnnk.",
		".knnnnnnnnnnnnk.",
		".kkkkkkkkkkkkkk.",
		"................",
		"................",
		"................",
	], "over": {"n": Color(0.72, 0.76, 0.84)}},
	"chest_gold": {"rows": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"..kkkkkkkkkkkk..",
		".knnnnnnnnnnnnk.",
		".knnnnnnnnnnnnk.",
		".kkkkkkkkkkkkkk.",
		".knnnnkrrknnnnk.",
		".knnnnkrrknnnnk.",
		".knnnnnnnnnnnnk.",
		".kkkkkkkkkkkkkk.",
		"................",
		"................",
		"................",
	], "over": {"n": Color(0.96, 0.84, 0.30)}},
	"coin": {"rows": [
		"........",
		"..kkkk..",
		".kyyyyk.",
		".kywyyk.",
		".kyyyyk.",
		".kyyyyk.",
		"..kkkk..",
		"........",
	]},
	"arrow": {"rows": [
		"........",
		"........",
		"......k.",
		"nnnnnnkw",
		"......k.",
		"........",
		"........",
		"........",
	]},
	"knife": {"rows": [
		"........",
		"........",
		"..kkkkk.",
		"nkssssw.",
		"..kkkkk.",
		"........",
		"........",
		"........",
	]},
	"torch": {"rows": [
		"................",
		"................",
		"......oo........",
		".....koook......",
		".....kyoyk......",
		"......kyk.......",
		"......kNk.......",
		"......kNk.......",
		"......kNk.......",
		"......kNk.......",
		"......kNk.......",
		"......kNk.......",
		"......kNk.......",
		".....kNNNk......",
		"................",
		"................",
	]},
	# --------------------------------------------------- ground decor ---
	"flower": {"rows": [
		"........",
		"........",
		".r.r....",
		"..y.....",
		".r.r....",
		"..g.....",
		"..g.....",
		"........",
	]},
	"mushroom": {"rows": [
		"........",
		"........",
		".rrrr...",
		"rrwrrr..",
		"..ww....",
		"..ww....",
		"........",
		"........",
	]},
	"bones": {"rows": [
		"........",
		"........",
		"w.....w.",
		".w.ww.w.",
		"..www...",
		"........",
		"........",
		"........",
	]},
	"crack": {"rows": [
		"........",
		"..E.....",
		"..EE....",
		"...E....",
		"...EE...",
		"....E...",
		"........",
		"........",
	]},
	"pebble": {"rows": [
		"........",
		"........",
		"........",
		"........",
		".ee.....",
		"eeee....",
		".ee.....",
		"........",
	]},
	# ------------------------------------- gear icons (tinted by grade) ---
	"icon_weapon": {"rows": [
		"................",
		".......kk.......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"....kkkwwkkk....",
		"....kkkwwkkk....",
		"......knnk......",
		"......knnk......",
		"......kyyk......",
		".......kk.......",
		"................",
		"................",
	]},
	"icon_armor": {"rows": [
		"................",
		"................",
		"................",
		".kkkk....kkkk...",
		".kwwwkkkkwwwk...",
		".kwwwwwwwwwwk...",
		"..kwwwwwwwwk....",
		"..kwwwwwwwwk....",
		"..kwwwwwwwwk....",
		"...kwwwwwwk.....",
		"...kkkkkkkk.....",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_boots": {"rows": [
		"................",
		"................",
		"................",
		"................",
		"....kwwk........",
		"....kwwk........",
		"....kwwk........",
		"....kwwkk.......",
		"....kwwwwk......",
		"....kkkkkk......",
		"........kwwk....",
		"........kwwk....",
		"........kwwkk...",
		"........kwwwwk..",
		"........kkkkkk..",
		"................",
	]},
	"icon_charm": {"rows": [
		"................",
		"................",
		"................",
		".....k..k.......",
		"....k....k......",
		"....k....k......",
		".....kkkk.......",
		".....kwwwwk.....",
		".....kwwwwk.....",
		"......kwwk......",
		".......kk.......",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
}

# Ground tile colors: base, darker speckle, lighter speckle.
const GROUND := {
	"grass":  [Color(0.32, 0.55, 0.30), Color(0.27, 0.49, 0.26), Color(0.38, 0.62, 0.33)],
	"forest": [Color(0.19, 0.36, 0.21), Color(0.15, 0.30, 0.18), Color(0.24, 0.43, 0.25)],
	"marsh":  [Color(0.33, 0.38, 0.23), Color(0.27, 0.32, 0.19), Color(0.40, 0.44, 0.27)],
	"stone":  [Color(0.40, 0.40, 0.46), Color(0.34, 0.34, 0.40), Color(0.46, 0.46, 0.52)],
	"dirt":   [Color(0.52, 0.40, 0.26), Color(0.45, 0.34, 0.22), Color(0.58, 0.46, 0.30)],
}


## Get (and cache) the texture for a named sprite.
static func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var t: ImageTexture
	match name:
		"slash":
			t = ImageTexture.create_from_image(_make_slash())
		"shadow":
			t = ImageTexture.create_from_image(_make_shadow())
		"glow":
			t = ImageTexture.create_from_image(_make_glow())
		"vignette":
			t = ImageTexture.create_from_image(_make_vignette())
		"reticle":
			t = ImageTexture.create_from_image(_make_reticle())
		_:
			t = ImageTexture.create_from_image(img(name))
	_cache[name] = t
	return t


## A gear icon tinted with its grade color (32x32, ready for UI buttons).
static func item_icon(slot: String, grade: String) -> ImageTexture:
	var key := "itemicon_%s_%s" % [slot, grade]
	if _cache.has(key):
		return _cache[key]
	var image := img("icon_" + slot)
	var tint: Color = Items.GRADE_COLOR[grade]
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				image.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t


## Soft dark ellipse drawn under every character (fake ground shadow).
static func _make_shadow() -> Image:
	var w := 20
	var h := 9
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := dx * dx + dy * dy
			if d < 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0.30 * (1.0 - d)))
	return image


## Soft radial light, tinted with modulate (torch glow, frost nova...).
static func _make_glow() -> Image:
	var s := 48
	var image := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s / 2.0, y + 0.5 - s / 2.0).length() / (s / 2.0)
			if d < 1.0:
				image.set_pixel(x, y, Color(1, 1, 1, (1.0 - d) * (1.0 - d) * 0.55))
	return image


## Darkened screen corners, drawn over the world (under the UI).
static func _make_vignette() -> Image:
	var w := 320
	var h := 180
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := absf(x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := absf(y + 0.5 - h / 2.0) / (h / 2.0)
			var d := maxf(dx, dy)
			var a := clampf((d - 0.62) / 0.38, 0.0, 1.0)
			image.set_pixel(x, y, Color(0, 0, 0, a * a * 0.42))
	return image


## Four yellow corner brackets that hover over the auto-aim target.
static func _make_reticle() -> Image:
	var s := 22
	var image := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var c := Color(1.0, 0.85, 0.25, 0.9)
	for i in 6:
		for edge in [[i, 0], [0, i], [s - 1 - i, 0], [s - 1, i], [i, s - 1], [0, s - 1 - i], [s - 1 - i, s - 1], [s - 1, s - 1 - i]]:
			image.set_pixel(edge[0], edge[1], c)
	return image


## Build an Image from a sprite's character grid.
static func img(name: String) -> Image:
	var def: Dictionary = SPRITES[name]
	var rows: Array = def["rows"]
	var over: Dictionary = def.get("over", {})
	var w := 0
	for row in rows:
		w = max(w, row.length())
	var image := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color = over.get(ch, PAL.get(ch, Color.MAGENTA))
			image.set_pixel(x, y, col)
	return image


## A white crescent for the sword swing, generated with math instead of a grid.
static func _make_slash() -> Image:
	var size := 24
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length()
			if d >= 6.0 and d <= 10.5 and absf(p.angle()) < 1.15:
				var a := 1.0 - absf(p.angle()) / 1.3
				image.set_pixel(x, y, Color(1, 1, 1, clampf(0.35 + a * 0.65, 0, 1)))
	return image


## Compose one big ground texture for a zone (34 x 15 tiles of 16px art).
## path_kind is painted across the middle rows so there is always a road.
static func ground(base_kind: String, path_kind: String, tiles_w: int, tiles_h: int, seed_val: int) -> ImageTexture:
	var key := "ground_%s_%s_%d" % [base_kind, path_kind, seed_val]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var image := Image.create_empty(tiles_w * 16, tiles_h * 16, false, Image.FORMAT_RGBA8)
	for ty in tiles_h:
		for tx in tiles_w:
			var kind := base_kind
			if ty >= 6 and ty <= 8:
				kind = path_kind
			var cols: Array = GROUND[kind]
			var base: Color = cols[0]
			# Tiny per-tile brightness variation so the ground isn't flat.
			base = base.lightened(rng.randf_range(-0.03, 0.03))
			image.fill_rect(Rect2i(tx * 16, ty * 16, 16, 16), base)
			for i in 7:
				var px := tx * 16 + rng.randi_range(0, 15)
				var py := ty * 16 + rng.randi_range(0, 15)
				image.set_pixel(px, py, cols[1] if rng.randf() < 0.5 else cols[2])
	# Stone border wall along the top and bottom edge of the world.
	var wall := img("wallblock")
	for tx in tiles_w:
		image.blit_rect(wall, Rect2i(0, 0, 16, 16), Vector2i(tx * 16, 0))
		image.blit_rect(wall, Rect2i(0, 0, 16, 16), Vector2i(tx * 16, (tiles_h - 1) * 16))
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t
