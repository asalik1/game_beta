class_name Art
## Procedural pixel-art factory.
## Every sprite in the game is defined here as a grid of characters
## (one character = one pixel, "." = transparent). At boot we convert
## these grids into textures, so the project needs zero image files.

static var _cache: Dictionary = {}

# Shared palette: character -> color.
const PAL := {
	# High-contrast arcade palette (Soul-Knight-ish): saturated mids,
	# bright highlights, near-black outlines so silhouettes always read.
	"k": Color(0.05, 0.04, 0.08),   # outline / near-black
	"w": Color(0.98, 0.98, 1.00),   # white / bone
	"s": Color(0.80, 0.84, 0.92),   # steel
	"S": Color(0.48, 0.54, 0.66),   # dark steel
	"e": Color(0.62, 0.62, 0.72),   # grey (rock, wolf fur)
	"E": Color(0.32, 0.32, 0.42),   # dark grey
	"b": Color(0.35, 0.58, 1.00),   # blue
	"B": Color(0.18, 0.28, 0.60),   # dark blue
	"r": Color(1.00, 0.25, 0.22),   # red
	"R": Color(0.58, 0.10, 0.14),   # dark red
	"g": Color(0.55, 0.88, 0.38),   # light green
	"G": Color(0.22, 0.52, 0.26),   # green
	"y": Color(1.00, 0.90, 0.32),   # gold
	"o": Color(1.00, 0.60, 0.12),   # orange
	"n": Color(0.62, 0.42, 0.24),   # brown
	"N": Color(0.36, 0.24, 0.13),   # dark brown
	"p": Color(0.85, 0.52, 1.00),   # light purple
	"P": Color(0.45, 0.22, 0.62),   # purple
	"f": Color(0.97, 0.80, 0.64),   # skin
	"m": Color(1.00, 0.35, 0.85),   # magenta (enemy bolts)
	"c": Color(0.35, 0.95, 0.95),   # cyan
}

# Sprite definitions. "over" optionally re-colors palette characters
# for that one sprite (used to make the witch a purple cultist, etc).
const SPRITES := {
	# Ambient critters (scenery that reacts — see ambience.gd).
	"bird": {"rows": [
		"...kkk..",
		"..knnnk.",
		".knnnnok",
		".knNNnk.",
		"..knnk..",
		"...k.k..",
	]},
	"crow": {"rows": [
		"....kk...",
		"...kEEk..",
		"..kEEEEk.",
		".kEEEEEsk",
		"..kEEEk..",
		"...k.k...",
	]},
	"butterfly": {"rows": [
		"p.k.p",
		"ppkpp",
		"PpkpP",
		"P...P",
	]},
	# Village buildings (visual pass): homes make the village a village.
	# Thatched cottage — golden straw roof, plastered walls, blue window.
	"cottage_a": {"rows": [
		"..........kk............",
		".........knnk...........",
		"........knyynk..........",
		".......knyyyynk.........",
		"......knyyyyyynk........",
		".....knyyyyyyyynk.......",
		"....knyyyyyyyyyynk......",
		"...knyyyyyyyyyyyynk.....",
		"..knnnnnnnnnnnnnnnnk....",
		"..kssssssssssssssssk....",
		"..kskbbkssssskNNkssk....",
		"..kskbbkssssskNNkssk....",
		"..ksssssssssskNNkssk....",
		"..ksssssssssskNykssk....",
		"..kkkkkkkkkkkkkkkkkk....",
	]},
	# Stone cottage — slate roof, mortared stone, arched door.
	"cottage_b": {"rows": [
		"....kkkkkkkkkkkkkkkk....",
		"...kSSSSSSSSSSSSSSSSk...",
		"..kSSSSSSSSSSSSSSSSSSk..",
		"..kkkkkkkkkkkkkkkkkkkk..",
		"..keeeekbbkeeeeeeeeeek..",
		"..keeeekbbkeeeekNNkeek..",
		"..keekeeeeeekeekNNkeek..",
		"..keeeeekeeeeeekNNkeek..",
		"..kkkkkkkkkkkkkkkkkkkk..",
	]},
	# Market stall — cloth awning on timber posts over a goods counter.
	# (Was red/white stripes: read as a modern road barrier, QA 2026-07-07.)
	"stall": {"rows": [
		"...kkkkkkkkkkkkkkkkkk...",
		"..kyyyyyyyyyyyyyyyyyyk..",
		".kyyyyyyyyyyyyyyyyyyyyk.",
		".kyoyyoyyoyyoyyoyyoyyok.",
		"..kyk..kyk....kyk..kyk..",
		"..kn................nk..",
		"..kn................nk..",
		"..knnrrnnbbnnyynnssnnk..",
		"..knnnnnnnnnnnnnnnnnnk..",
		"..kNNNNNNNNNNNNNNNNNNk..",
		"...N................N...",
		"...N................N...",
	]},
	# Wooden bridge planks (stretched across the river band).
	"bridge": {"rows": [
		"kkkkkkkkkkkkkkkk",
		"knnnnnnnknnnnnnk",
		"kNNNNNNNkNNNNNNk",
		"knnnnnnnknnnnnnk",
		"kkkkkkkkkkkkkkkk",
		"knnnknnnnnnknnnk",
		"kNNNkNNNNNNkNNNk",
		"knnnknnnnnnknnnk",
		"kkkkkkkkkkkkkkkk",
		"knnnnnnnknnnnnnk",
		"kNNNNNNNkNNNNNNk",
		"kkkkkkkkkkkkkkkk",
	]},
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
		".kk......keerek.",
		"..kkkkkkkeeeeek.",
		"..keeeeeeeeewkk.",
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
		".......kk.......",
		"......kPPk......",
		".....kPPPPk.....",
		"....kPPPPPPk....",
		".kkkkkkkkkkkkk..",
		"..kPkkkkkkkkPk..",
		"....kEgkkgEk....",
		"....kEEEEEEk..y.",
		"....kPPPPPPk.kyk",
		"...kPPpPPpPPkkNk",
		"...kPPPPPPPPk.Nk",
		"..kPPPPPPPPPPkNk",
		"..kPPpPPPPpPPkNk",
		"..kkkkkkkkkkkkNk",
		"..............Nk",
		"..............k.",
	], "over": {"g": Color(0.45, 1.0, 0.55)}},
	"direwolf": {"rows": [
		"........................",
		"..................kk....",
		".kk..............krek...",
		".kRk........kkkkkeeeek..",
		".kRRk..kkkkkRRRRkeeeeek.",
		"..kRRkkRRRRRRRRRkewwek..",
		"..kRRRRRRRRRRRRReeeeek..",
		"...kReeeeeeeeeeReeeek...",
		"...kReeeeeeeeeeeeeek....",
		"....keeeeeeeeeeeeek.....",
		"....keeeeeeeeeeeek......",
		".....keek....keek.......",
		".....kek......kek.......",
		".....kk........kk.......",
		"........................",
		"........................",
	]},
	"greatsword": {"rows": [
		"......kyyk......",
		".....kyyyyk.....",
		"....kkkwwkkk....",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwwk......",
		"......kwsk......",
		"......kwsk......",
		".......kwk......",
		".......kk.......",
		"................",
	]},
	# ------------------------------------------- held weapon variants ---
	"w_blade": {"rows": [
		".......kk.......",
		"......kwwk......",
		"......kwsk......",
		"......kwsk......",
		"......kwsk......",
		"......kwsk......",
		"......kwsk......",
		"......kwsk......",
		"....kkkwwkkk....",
		"....kkkwwkkk....",
		"......knnk......",
		"......knnk......",
		"......kyyk......",
		".......kk.......",
		"................",
		"................",
	]},
	"w_edge": {"rows": [
		"................",
		"....kkk.........",
		"..kkwwwk........",
		".kwwwwwwk.......",
		".kwsswwwwk......",
		".kwsk.kwwwk.....",
		".ksk...kwwwk....",
		"..k.....kwwwk...",
		".........kwwwk..",
		"..........kwsk..",
		"..........knnk..",
		"...........knnk.",
		"...........kyyk.",
		"............kk..",
		"................",
		"................",
	]},
	"w_fang": {"rows": [
		"................",
		"..........kk....",
		".........kwwk...",
		"........kwwsk...",
		".......kwwsk....",
		"......kwwsk.....",
		".....kwwsk......",
		"....kwwsk.......",
		"....kwsk........",
		"..kkkwskkk......",
		"....knnk........",
		"....knnk........",
		"....kyyk........",
		".....kk.........",
		"................",
		"................",
	]},
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
	# A comet, not a ball: white-hot head (right — projectiles rotate to
	# their velocity), orange body, ragged red tail with detached embers.
	"fireball": {"rows": [
		"................",
		"..r....kkkkk....",
		"....kkkyyyyyk...",
		".rkoyyyywwwwwyk.",
		"rkooyyywwwwwwwk.",
		".rkoyyyywwwwwyk.",
		"....kkkyyyyyk...",
		"..r....kkkkk....",
	]},
	# A jagged ice shard, point right — the Ice-theme bolt.
	"icelance": {"rows": [
		"................",
		"...kkkkkk.......",
		".kkccccccck.....",
		"kbccwwwwwwwwwck.",
		".kkccccccck.....",
		"...kkkkkk.......",
		"................",
		"................",
	]},
	# Hungry darkness with a pale core, ragged void wisps trailing left
	# (projectiles rotate to their velocity — head points right).
	"shadowbolt": {"rows": [
		"................",
		"..P....kkkkk....",
		"....kkkpppppk...",
		".PkPppppwwwwppk.",
		"PkPPpppwwwwwwwk.",
		".PkPppppwwwwppk.",
		"....kkkpppppk...",
		"..P....kkkkk....",
	]},
	# The Ember Crown — cutscene prop.
	"crown": {"rows": [
		"y..yy..y",
		"yy.yy.yy",
		"yyyyyyyy",
		"yyryyryy",
		".yyyyyy.",
		"........",
		"........",
		"........",
	]},
	"bolt": {"rows": [
		"...kk...",
		"..kmmk..",
		".kmwwmk.",
		".kmwwmk.",
		".kmwwmk.",
		"..kmmk..",
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
		"......rrr.......",
		"..kkkkrrkkkk....",
		".kssssssssssk...",
		".ksswssssswsk...",
		".kSSkkkkkkSSk...",
		".kssEssssEssk...",
		".kssssssssssk...",
		"..kssssssssk....",
		"..kBBsrrsBBk....",
		"..kBBsrrsBBk....",
		"...kssrrssk.....",
		"...kssssssk.....",
		"....kSSkSSk.....",
		"....kkk.kkk.....",
		"................",
		"................",
	]},
	"archer": {"rows": [
		".....kkkkkk.....",
		"...kkGgggGGkk...",
		"..kGGGGGGGGGGk..",
		"..kGGkkkkkkGGk..",
		"..kGkffffffkGk..",
		"..kGkfEffEfkGk..",
		"..kGkffffffkGk..",
		"...kGkkkkkkGk...",
		"...kGGnnnnGGk...",
		"...kGGnnnnGGk...",
		"....knNNNNnk....",
		"....knnnnnnk....",
		"....knn..nnk....",
		"....kkk..kkk....",
		"................",
		"................",
	]},
	"mage": {"rows": [
		".......kk.......",
		"......kbbk......",
		".....kbwbbk.....",
		"....kbbbbbbk....",
		".kkkkbbbbbbkkkk.",
		".kbbbbbbbbbbbbk.",
		"..kkkkkkkkkkkk..",
		"...kffffffffk...",
		"...kfEffffEfk...",
		"...kffffffffk...",
		"...kbbbwwbbbk...",
		"....kbbbbbbk....",
		"....kbbbbbbk....",
		"....kbb..bbk....",
		"....kkk.kkk.....",
		"................",
	]},
	"assassin": {"rows": [
		".....kkkkkk.....",
		"...kkEEEEEEkk...",
		"..kEEEEEEEEEEk..",
		"..kEEkkkkkkEEk..",
		"..kEkkwkkwkkEk..",
		"..kEEkkkkkkEEk..",
		"...kEEEEEEEEk...",
		"...krrrrrrrrk...",
		"...kEEEEEEEEk...",
		"....kEEEEEEk....",
		"....kEErrEEk....",
		"....kEEEEEEk....",
		"....kEE..EEk....",
		"....kkk.kkk.....",
		"................",
		"................",
	]},
	# Gold-trimmed holy knight: white tabard, gilded plate, golden plume.
	"paladin": {"rows": [
		"......yyy.......",
		"..kkkkyykkkk....",
		".kssssssssssk...",
		".ksswssssswsk...",
		".kSSkkkkkkSSk...",
		".kssEssssEssk...",
		".kssssssssssk...",
		"..kssssssssk....",
		"..kyyswwsyyk....",
		"..kyyswwsyyk....",
		"...ksswwssk.....",
		"...kssyyssk.....",
		"....kSSkSSk.....",
		"....kkk.kkk.....",
		"................",
		"................",
	]},
	# Hooded pact-mage: deep purple robes, glowing cyan eyes in the dark.
	"warlock": {"rows": [
		".....kkkkkk.....",
		"...kkPPPPPPkk...",
		"..kPPPPPPPPPPk..",
		"..kPPkkkkkkPPk..",
		"..kPkkckkckkPk..",
		"..kPPkkkkkkPPk..",
		"...kPPPPPPPPk...",
		"...kPpPPPPpPk...",
		"...kPPPPPPPPk...",
		"....kPPppPPk....",
		"....kPPPPPPk....",
		"....kPPPPPPk....",
		"....kPP..PPk....",
		"....kkk.kkk.....",
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
	# The assassin's thrown KUNAI (round 50): ring pommel + wrapped handle +
	# a steel leaf-blade tapering to a point. Reads as a THROWN BLADE, not a
	# needle — and the kit rides a variant-tinted glow halo behind it
	# (poison green / blood red / shadow purple) via _knife_glow.
	"dart": {"rows": [
		"................",
		".kk....kSk......",
		"k..k..kSsssk....",
		"k..kNNSssssssskk",
		"k..k..kSsssk....",
		".kk....kSk......",
		"................",
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
		"..kkk......kkk..",
		".kwwsk....kssSk.",
		".kwsskkkkkkssSk.",
		"..kwsssswssssk..",
		"..kwsssswssssk..",
		"..kssssswsssSk..",
		"..kssssswsssSk..",
		"...ksssswssSk...",
		"...kyysssyySk...",
		"....kkkkkkkk....",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_boots": {"rows": [
		"................",
		".kkkkk...kkkkk..",
		".kwwsk...kwwsk..",
		".kssSk...kssSk..",
		".kssSk...kssSk..",
		".kssSk...kssSk..",
		".kssSk...kssSk..",
		".ksssSk..ksssSk.",
		".kssssSk.kssssSk",
		".kSSSSSk.kSSSSSk",
		".kkkkkkk.kkkkkkk",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_charm": {"rows": [
		"................",
		"....kk....kk....",
		"...k........k...",
		"...k........k...",
		"....k......k....",
		".....k....k.....",
		"......kyyk......",
		".....kwwsk......",
		"....kwwsssk.....",
		"....kwsssSk.....",
		".....kssSk......",
		"......ksk.......",
		".......k........",
		"................",
		"................",
		"................",
	]},
	"icon_mail": {"rows": [
		"................",
		"..kkk......kkk..",
		".ksesk....ksesk.",
		".kseskkkkkksesk.",
		"..kesesesesesk..",
		"..ksesesesesek..",
		"..kesesesesesk..",
		"..ksesesesesek..",
		"...kesesesesk...",
		"...ksesesesek...",
		"....kkkkkkkk....",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_shield": {"rows": [
		"................",
		"................",
		"...kkkkkkkk.....",
		"..kssssssssk....",
		"..kswwsswwsk....",
		"..kssssssssk....",
		"..kssbbbbssk....",
		"...kssbbssk.....",
		"...kssssssk.....",
		"....kssssk......",
		".....kssk.......",
		"......kk........",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_striders": {"rows": [
		"................",
		"................",
		"......kkkkk.....",
		"......kwwsk.....",
		"...ww.kssSk.....",
		"..wwwwkssSk.....",
		"...ww.kssSk.....",
		"......kssSk.....",
		"......ksssSk....",
		"......kssssSk...",
		"......kSSSSSk...",
		"......kkkkkkk...",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_treads": {"rows": [
		"................",
		"................",
		"................",
		"...kkkkkkk......",
		"...kwwsssk......",
		"...kssssSk......",
		"...kSkkkSk......",
		"...kssssSkk.....",
		"...kssssssSk....",
		"...kssssssssk...",
		"...kSSSSSSSSk...",
		"...kkkkkkkkkk...",
		"....k..k..k.....",
		"................",
		"................",
		"................",
	]},
	"icon_talisman": {"rows": [
		"................",
		".......kk.......",
		"......kyyk......",
		".....kkkkkk.....",
		"....kwwssssk....",
		"...kwwskkssSk...",
		"...kwskwwksSk...",
		"...kwwskkssSk...",
		"....kwssssSk....",
		".....kkkkkk.....",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"icon_sigil": {"rows": [
		"................",
		".....kkkkkk.....",
		"....kssssssk....",
		"...kswwkkwssk...",
		"...ksk....ksk...",
		"...ksk.kk.ksk...",
		"...ksk.kk.ksk...",
		"...ksk....ksk...",
		"...kswkkkwssk...",
		"....kssssssk....",
		".....kkkkkk.....",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"w_bow": {"rows": [
		"................",
		"....kkk....k....",
		"...knnwk...k....",
		"..knwk.....k....",
		".knwk......k....",
		".knwk......k....",
		".knwk......k....",
		".knwnnnnnnnkwwk.",
		".knwk......k....",
		".knwk......k....",
		".knwk......k....",
		"..knwk.....k....",
		"...knnwk...k....",
		"....kkk....k....",
		"................",
		"................",
	]},
	# Widow Sera's mill on the Greyrun: grey walls gone to blight,
	# the water wheel furred over — and the door still defiantly blue.
	"mill": {"rows": [
		"................",
		".......kkkk.....",
		".....kkeeeekk...",
		"....keeeeeeeek..",
		"...keeeeeeeeeek.",
		"...kEEEEEEEEEEk.",
		"kk.keeeeeeeeeek.",
		"kNkkeeekkkkeeek.",
		"kNNkeeekbbkeeek.",
		"kNkkeeekbbkeeek.",
		"kk.keeekbbkeeek.",
		"...keeekbbkeeek.",
		"...kkkkkkkkkkkk.",
		"................",
		"................",
		"................",
	]},
	"tombstone": {"rows": [
		"................",
		"....kkkkkk......",
		"...keeeeeek.....",
		"...keeeeeek.....",
		"...keekkeek.....",
		"...keeeeeek.....",
		"...keekeeek.....",
		"...keeeeeek.....",
		"...keeeeeek.....",
		"...keeeeeek.....",
		"..kEeeeeeeEk....",
		"..kkkkkkkkkk....",
		"................",
		"................",
		"................",
		"................",
	]},
	"crystal": {"rows": [
		"......kk........",
		".....kcck.......",
		".....kcck..kk...",
		"....kccwck.kck..",
		"....kcccckkcck..",
		"...kccwccckcck..",
		"...kcccccckck...",
		"...kccccccck....",
		"....kccccck.....",
		"....kkkkkkk.....",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	]},
	"w_kunai": {"rows": [
		"................",
		"......kkk.......",
		".....kk.kk......",
		".....kk.kk......",
		"......kkk.......",
		"......knnk......",
		"......knnk......",
		".....kwwsk......",
		"....kwwwssk.....",
		"....kwwwssk.....",
		".....kwwsk......",
		"......kwsk......",
		".......kwk......",
		"........k.......",
		"................",
		"................",
	]},
	"w_claymore": {"rows": [
		"......kkk.......",
		".....kwwwk......",
		".....kwswk......",
		".....kwswk......",
		".....kwswk......",
		".....kwswk......",
		".....kwswk......",
		".....kwswk......",
		"...kkkwwwkkk....",
		"..kyykkkkkyyk...",
		"......knnk......",
		"......knnk......",
		".....kyyyyk.....",
		"......kk........",
		"................",
		"................",
	]},
	"w_crossbow": {"rows": [
		"................",
		".kk..........kk.",
		".knk........knk.",
		"..knk......knk..",
		"...knkk..kknk...",
		"....kknwwnkk....",
		".ksssskwwkssssk.",
		"......kwwk......",
		"......knnk......",
		"......knnk......",
		"......knnk......",
		".....kynnyk.....",
		"......kkkk......",
		"................",
		"................",
		"................",
	]},
	"w_wand": {"rows": [
		"................",
		"........w..w....",
		".......kkk......",
		"......kwppk.....",
		"......kpppk.....",
		".......kkk......",
		".......knk......",
		"......knk.......",
		".....knk........",
		"....knk.........",
		"....kyk.........",
		".....k..........",
		"................",
		"................",
		"................",
		"................",
	]},
	"gem": {"rows": [
		"........",
		"..kkkk..",
		".kwwwwk.",
		".kwwwsk.",
		"..kwsk..",
		"...kk...",
		"........",
		"........",
	]},
	"w_staff": {"rows": [
		"................",
		".....kcck.......",
		"....kcccck......",
		"....kcccck......",
		".....kcck.......",
		"......knk.......",
		"......knk.......",
		"......knk.......",
		"......knk.......",
		"......knk.......",
		"......knk.......",
		"......knk.......",
		".....kNNk.......",
		"................",
		"................",
		"................",
	]},
	"w_hammer": {"rows": [
		"................",
		"...kkkkkkkkk....",
		"..ksssssssssk...",
		"..ksswwwssssk...",
		"..ksssssssssk...",
		"..kkkkkkkkkkk...",
		"......knnk......",
		"......knnk......",
		"......knnk......",
		"......knnk......",
		"......knnk......",
		"......kyyk......",
		".......kk.......",
		"................",
		"................",
		"................",
	]},
	"w_tome": {"rows": [
		"................",
		"................",
		"..kkkkkkkkkkk...",
		"..kPPPPkPPPPk...",
		"..kPpPPkPPpPk...",
		"..kPPPPkPPPPk...",
		"..kPPcPkPcPPk...",
		"..kPPPPkPPPPk...",
		"..kPpPPkPPpPk...",
		"..kPPPPkPPPPk...",
		"..kkkkkkkkkkk...",
		"...kNNNNNNNk....",
		"................",
		"................",
		"................",
		"................",
	]},
}

# Ground tile colors: base, darker speckle, lighter speckle.
# Value notes (art audit 2026-07-09): the Forward+ tonemap sinks midtones,
# so a ground base below ~0.3 renders near-black in-game and the biome's
# own props stop separating from the floor. gravedirt was raised to pale
# ashen earth (dark tombstones now read as silhouettes ON it), stormgrass
# went grey-blue (it was a darkwood clone in green), forest got a small
# lift out of murk. voidstone stays near-black ON PURPOSE — absence is
# its identity; its readability comes from the tint value floor
# (terrains.gd) instead.
const GROUND := {
	"grass":  [Color(0.32, 0.55, 0.30), Color(0.27, 0.49, 0.26), Color(0.38, 0.62, 0.33)],
	"forest": [Color(0.22, 0.39, 0.23), Color(0.17, 0.32, 0.19), Color(0.28, 0.47, 0.27)],
	"marsh":  [Color(0.33, 0.38, 0.23), Color(0.27, 0.32, 0.19), Color(0.40, 0.44, 0.27)],
	"stone":  [Color(0.40, 0.40, 0.46), Color(0.34, 0.34, 0.40), Color(0.46, 0.46, 0.52)],
	"dirt":   [Color(0.52, 0.40, 0.26), Color(0.45, 0.34, 0.22), Color(0.58, 0.46, 0.30)],
	# --------------------------------------------- terrain expansion ---
	"basalt":       [Color(0.20, 0.12, 0.11), Color(0.15, 0.09, 0.08), Color(0.30, 0.15, 0.10)],
	"snow":         [Color(0.82, 0.86, 0.93), Color(0.74, 0.79, 0.88), Color(0.92, 0.95, 1.00)],
	"gravedirt":    [Color(0.40, 0.38, 0.34), Color(0.33, 0.31, 0.28), Color(0.48, 0.46, 0.41)],
	"sand":         [Color(0.78, 0.67, 0.44), Color(0.70, 0.59, 0.38), Color(0.86, 0.76, 0.52)],
	"bogsoil":      [Color(0.21, 0.28, 0.17), Color(0.16, 0.22, 0.13), Color(0.28, 0.35, 0.21)],
	"crystalfloor": [Color(0.30, 0.31, 0.46), Color(0.24, 0.25, 0.38), Color(0.40, 0.42, 0.60)],
	"stormgrass":   [Color(0.36, 0.40, 0.46), Color(0.29, 0.33, 0.38), Color(0.44, 0.49, 0.55)],
	"voidstone":    [Color(0.11, 0.08, 0.16), Color(0.07, 0.05, 0.11), Color(0.18, 0.13, 0.26)],
	"holystone":    [Color(0.66, 0.61, 0.49), Color(0.58, 0.53, 0.42), Color(0.76, 0.71, 0.58)],
	"sporesoil":    [Color(0.31, 0.23, 0.31), Color(0.25, 0.18, 0.25), Color(0.40, 0.30, 0.40)],
}

# Per-ground generation profile: [organic patch count, fine speckle count].
# Grounds not listed use the default [90, 600]. voidstone runs nearly FLAT
# on purpose — with the full speckle it read as a crystal-cavern clone
# (art audit 2026-07-09: void identity is ABSENCE). Stone floors calm
# their speckle so the flagstone seams read as the dominant texture.
const GROUND_NOISE := {
	"voidstone":    [14, 70],
	"crystalfloor": [60, 240],
	"stone":        [70, 340],
	"holystone":    [70, 340],
}


## Load an asset-override image through the resource system, so it works
## in EXPORTED builds too. Image.load_from_file + globalize_path only
## reach loose files on disk; inside a packed .pck there are none, so the
## whole sprite/icon override system silently reverted to procedural art
## in exports (and PNG-only pieces like cottage_a2 crashed on a null).
## load() reads the imported texture, which is always in the pack.
static func _override_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	return t.get_image() if t else null


## Hand-authored UI icon override (assets/icons/<name>.png), or null.
## A separate seam from assets/sprites/: icons are UI art (bag slots,
## HUD), never world sprites, and are used AS-IS — no grade tinting;
## rarity stays readable via slot borders and item-name colors.
static func _icon_override(name: String) -> Image:
	return _override_image("res://assets/icons/%s.png" % name)


## A HUD-button icon loaded from assets/icons/<name>.png (pack art, e.g. Raven
## Fantasy Icons), cached and used at its native size. Returns null when the
## file is absent so the caller can fall back to procedural art.
static func ui_icon(name: String) -> ImageTexture:
	var key := "uiicon_" + name
	if _cache.has(key):
		return _cache[key]
	var im := _icon_override(name)
	if im == null:
		return null
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t


## Get (and cache) the texture for a named sprite.
## If assets/sprites/<name>.png exists it OVERRIDES the procedural art —
## drop in hand-drawn or CC0 sprites (any size) without touching code.
static func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var override_path := "res://assets/sprites/%s.png" % name
	var file_img := _override_image(override_path)
	if file_img:
		var ft := ImageTexture.create_from_image(file_img)
		_cache[name] = ft
		return ft
	if name == "potion":  # HUD potion icon: allow an assets/icons/ override
		var icon_img := _icon_override(name)
		if icon_img != null:
			var it := ImageTexture.create_from_image(icon_img)
			_cache[name] = it
			return it
	var t: ImageTexture
	match name:
		"slash":
			t = ImageTexture.create_from_image(_make_slash())
		"shadow":
			t = ImageTexture.create_from_image(_make_shadow())
		"glow":
			t = ImageTexture.create_from_image(_make_glow())
		"slashline":
			t = ImageTexture.create_from_image(_make_slashline())
		"lootbeam":
			t = ImageTexture.create_from_image(_make_lootbeam())
		"dangerrim":
			t = ImageTexture.create_from_image(_make_dangerrim())
		"ring":
			t = ImageTexture.create_from_image(_make_ring())
		"vignette":
			t = ImageTexture.create_from_image(_make_vignette())
		"light":
			t = ImageTexture.create_from_image(_make_light())
		"white":
			var wimg := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
			wimg.fill(Color(1, 1, 1))
			t = ImageTexture.create_from_image(wimg)
		"reticle":
			t = ImageTexture.create_from_image(_make_reticle())
		"telegraph":
			t = ImageTexture.create_from_image(_make_telegraph())
		"tree_green", "tree_autumn", "tree_teal", "tree_snow", "tree_spore":
			t = ImageTexture.create_from_image(_make_tree(name))
		"bubble":
			t = ImageTexture.create_from_image(_make_bubble())
		"bag":  # HUD inventory button
			t = ImageTexture.create_from_image(_make_bag())
		"book":  # HUD codex button
			t = ImageTexture.create_from_image(_make_book())
		"mail":  # HUD mailbox button (the ✉ glyph has no mobile font — draw an envelope)
			t = ImageTexture.create_from_image(_make_mail())
		"skills":  # HUD skill-tree button
			t = ImageTexture.create_from_image(_make_skills())
		"settings":  # HUD menu/settings (gear) button
			t = ImageTexture.create_from_image(_make_gear())
		"stash":  # HUD stash (treasure chest) button
			t = ImageTexture.create_from_image(_make_stash())
		"crosshair":  # touch target-lock button (red scope crosshair)
			t = ImageTexture.create_from_image(_make_crosshair())
		_:
			t = ImageTexture.create_from_image(img(name))
	_cache[name] = t
	return t


# ------------------------------------------------------------- glyphs ---
# Small symbol drawings for ability buttons and skill-tree nodes.
# "w" pixels take the tint color, "k" stays dark, "y" stays gold.
const GLYPHS := {
	"ab_slash": [  # warrior Cleave / generic damage
		"..........k.",
		".........kwk",
		"........kwk.",
		".......kwk..",
		"......kwk...",
		".....kwk....",
		"....kwk.....",
		"...kwk......",
		"..kwk.......",
		".kwk........",
		".kk.........",
	],
	"ab_shield": [  # Shield Bash / resistances
		".kkkkkkkkk..",
		".kwwwwwwwk..",
		".kwwyywwwk..",
		".kwwyywwwk..",
		"..kwwwwwk...",
		"..kwwwwwk...",
		"...kwwwk....",
		"....kwk.....",
		".....k......",
	],
	"ab_whirl": [  # Whirlwind
		"...kkkkkk...",
		"..kwwwwwwk..",
		".kwk....kwk.",
		".kw......wk.",
		".kw......wk.",
		".kwk...kykk.",
		"..kwwwwwyk..",
		"...kkkkkk...",
	],
	"ab_fist": [  # Berserk
		"....kkkk....",
		"...kwwwwk...",
		"..kwwwwwwk..",
		"..kwwwwwwk..",
		"..kwwywwwk..",
		"..kkwwwwkk..",
		"...kwwwwk...",
		"...kkkkkk...",
	],
	"ab_arrow": [  # Quick Shot
		"......kkkkk.",
		".......kwwk.",
		"......kwwyk.",
		".....kwkkk..",
		"....kwk.....",
		"...kwk......",
		"..kwk.......",
		".kwk........",
		".kk.........",
	],
	"ab_multi": [  # Multishot
		".k...k...k..",
		".kw..kw..kw.",
		".kw..kw..kw.",
		".kw..kw..kw.",
		".ky..ky..ky.",
		"..k...k...k.",
	],
	"ab_roll": [  # Tumble / speed
		"..kww.......",
		"....kww.....",
		"......kww...",
		"........kww.",
		"......kww...",
		"....kww.....",
		"..kww.......",
	],
	"ab_rain": [  # Arrow Storm
		".kkkkkkkkk..",
		"kwwwwwwwwwk.",
		".kkkkkkkkk..",
		"..w...w...w.",
		"..w...w...w.",
		".kwk.kwk.kwk",
		"..k...k...k.",
	],
	"ab_flame": [  # Firebolt
		".....kk.....",
		"....kwwk....",
		"...kwwwwk...",
		"...kwywwk...",
		"..kwyyywwk..",
		"..kwyyyywk..",
		"...kwyywk...",
		"....kkkk....",
	],
	"ab_snow": [  # Frost Nova
		"..w...w...w.",
		"...w..w..w..",
		"....w.w.w...",
		".....www....",
		"..wwwwwwww..",
		".....www....",
		"....w.w.w...",
		"...w..w..w..",
		"..w...w...w.",
	],
	"ab_blink": [  # Blink / evasion
		".kw...kw....",
		"..kw...kw...",
		"...kw...kw..",
		"....kw...kw.",
		"...kw...kw..",
		"..kw...kw...",
		".kw...kw....",
	],
	"ab_meteor": [  # Meteor
		"........kw..",
		".......kw...",
		"......kw....",
		"..kkkkw.....",
		".kwwwwk.....",
		".kwyywk.....",
		".kwwwwk.....",
		"..kkkk......",
	],
	"ab_dagger": [  # Stab
		".....kk.....",
		".....kwk....",
		".....kwk....",
		".....kwk....",
		".....kwk....",
		"....kkkk....",
		".....kyk....",
		".....kk.....",
	],
	"ab_knives": [  # Fan of Knives
		".k....k....k",
		".kw...kw..wk",
		"..kw..kw.wk.",
		"...kw.kwwk..",
		"....kwkwk...",
		".....kkk....",
	],
	"ab_skull": [  # Death Mark
		"...kkkkk....",
		"..kwwwwwk...",
		"..kwkwkwk...",
		"..kwwwwwk...",
		"...kwkwk....",
		"...kkkkk....",
	],
	"ab_hammer": [  # Judgment
		".kkkkkkkk...",
		".kwwwwwwk...",
		".kwwwwwwk...",
		".kkkkkkkk...",
		"....kyk.....",
		"....kyk.....",
		"....kyk.....",
		"....kyk.....",
		"....kkk.....",
	],
	"ab_sun": [  # Consecration (radiant ground)
		".....w......",
		"..w..w..w...",
		"...kkkkk....",
		"..kwwwwwk...",
		"w.kwwywwk.w.",
		"..kwwwwwk...",
		"...kkkkk....",
		"..w..w..w...",
		".....w......",
	],
	"ab_chain": [  # Chains of Wrath
		".kkk........",
		"kw.wk.......",
		".kkk........",
		"...kkk......",
		"..kw.wk.....",
		"...kkk......",
		".....kkk....",
		"....kw.wk...",
		".....kkk....",
	],
	"ab_orb": [  # Shadowbolt
		"....kkkk....",
		"...kwwwwk...",
		"..kwwkkwwk..",
		"..kwkwwkwk..",
		"..kwwkkwwk..",
		"...kwwwwk...",
		"....kkkk....",
	],
	"ab_hex": [  # Hex (the watching curse)
		"...kkkkk....",
		"..kwwwwwk...",
		".kwwkkkwwk..",
		".kwkwywkwk..",
		".kwwkkkwwk..",
		"..kwwwwwk...",
		"...kkkkk....",
		"....kwk.....",
		".....kw.....",
	],
	"ab_pact": [  # Dark Pact (the paid drop)
		".....k......",
		"....kwk.....",
		"...kwwwk....",
		"..kwwwwwk...",
		"..kwwywwk...",
		"..kwwwwwk...",
		"...kwwwk....",
		"....kkk.....",
	],
	"ab_rift": [  # Void Rift
		"...kkkkk....",
		"..kw...wk...",
		".kw..k..wk..",
		".kw.kwk.wk..",
		".kw..w..wk..",
		"..kw...wk...",
		"...kkkkk....",
	],
	"ic_cd": [  # cooldown (hourglass)
		".kkkkkkk....",
		"..kwwwk.....",
		"...kwk......",
		"....k.......",
		"...kwk......",
		"..kwwwk.....",
		".kkkkkkk....",
	],
	"ic_hp": [  # health (heart)
		"..kk...kk...",
		".kwwk.kwwk..",
		".kwwwkwwwk..",
		"..kwwwwwk...",
		"...kwwwk....",
		"....kwk.....",
		".....k......",
	],
	"ic_mp": [  # mana / lifesteal (drop)
		".....k......",
		"....kwk.....",
		"...kwwwk....",
		"...kwwwk....",
		"...kwwwk....",
		"....kkk.....",
	],
	"ic_crit": [  # crit (star)
		".....w......",
		"....www.....",
		".wwwwwwwww..",
		"....www.....",
		"...ww.ww....",
		"..w.....w...",
	],
	"ic_pen": [  # penetration (arrowhead)
		".....k......",
		"....kwk.....",
		"...kwwwk....",
		"..kwwwwwk...",
		".kwwkkkwwk..",
		"....kwk.....",
		"....kwk.....",
	],
	"ic_combo": [  # combo (linked rings)
		"..kkk..kkk..",
		".kw.wkkw.wk.",
		".kw..ww..wk.",
		".kw.wkkw.wk.",
		"..kkk..kkk..",
	],
	"ic_eye": [  # dex (eye)
		"...kkkkk....",
		"..kwwwwwk...",
		".kwwkkkwwk..",
		"..kwwwwwk...",
		"...kkkkk....",
	],
	"ic_coin": [  # greed (coin)
		"...kkkk.....",
		"..kwwwwk....",
		".kwwyywwk...",
		".kwwyywwk...",
		"..kwwwwk....",
		"...kkkk.....",
	],
}

# Which glyph each ability uses.
const ABILITY_GLYPH := {
	"warrior":  {"a1": "ab_slash",  "a2": "ab_shield", "a3": "ab_whirl",  "ult": "ab_fist"},
	"archer":   {"a1": "ab_arrow",  "a2": "ab_multi",  "a3": "ab_roll",   "ult": "ab_rain"},
	"mage":     {"a1": "ab_flame",  "a2": "ab_snow",   "a3": "ab_blink",  "ult": "ab_meteor"},
	"assassin": {"a1": "ab_dagger", "a2": "ab_blink",  "a3": "ab_knives", "ult": "ab_skull"},
	"paladin":  {"a1": "ab_hammer", "a2": "ab_sun",    "a3": "ab_shield", "ult": "ab_chain"},
	"warlock":  {"a1": "ab_orb",    "a2": "ab_hex",    "a3": "ab_pact",   "ult": "ab_rift"},
}


## Build (and cache) a tinted glyph texture, upscaled for UI use.
static func glyph_tex(name: String, tint := Color(0.92, 0.92, 0.98)) -> ImageTexture:
	var key := "glyph_%s_%s" % [name, tint.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var rows: Array = GLYPHS[name]
	var w := 12
	for row in rows:
		w = maxi(w, row.length())
	var image := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			match row[x]:
				"k": image.set_pixel(x, y, Color(0.05, 0.04, 0.08))
				"w": image.set_pixel(x, y, tint)
				"y": image.set_pixel(x, y, Color(1.0, 0.9, 0.32))
	image.resize(w * 2, rows.size() * 2, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t


# Every gear family (noun) has its own sprite; grade adds the tint.
const GEAR_SHAPES := {
	"weapon": {"Blade": "w_blade", "Edge": "w_edge", "Fang": "w_fang", "Shuriken": "w_kunai", "Kunai": "w_kunai", "Claymore": "w_claymore", "Bow": "w_bow", "Crossbow": "w_crossbow", "Staff": "w_staff", "Wand": "w_wand", "Hammer": "w_hammer", "Tome": "w_tome"},
	"armor":  {"Plate": "icon_armor", "Mail": "icon_mail", "Guard": "icon_shield"},
	"boots":  {"Boots": "icon_boots", "Striders": "icon_striders", "Treads": "icon_treads"},
	"charm":  {"Charm": "icon_charm", "Talisman": "icon_talisman", "Sigil": "icon_sigil"},
}


static func _shape_for(slot: String, noun: String) -> String:
	var shapes: Dictionary = GEAR_SHAPES[slot]
	if shapes.has(noun):
		return shapes[noun]
	return shapes.values()[0]


## Convenience: the icon for a rolled item Dictionary.
static func icon_for(item: Dictionary) -> ImageTexture:
	return item_icon(item["slot"], item["grade"], item.get("noun", ""))


## Held weapon sprite tinted by grade (drawn in the hero's hand).
static func weapon_tex(noun: String, grade: String) -> ImageTexture:
	var shape := _shape_for("weapon", noun)
	var key := "wpn_%s_%s" % [shape, grade]
	if _cache.has(key):
		return _cache[key]
	var image := img(shape)
	var tint: Color = Items.GRADE_COLOR[grade]
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				# Blend toward the grade color so blades stay metallic.
				image.set_pixel(x, y, c.lerp(Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a), 0.65))
	_embellish(image, grade)
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t


## Grade-specific visual treatment, so a Rusty Shuriken and a legendary
## dagger look nothing alike beyond mere color:
##   F: chipped and dull · C/D: gem accents · B+: glowing rim
##   A: gold trim · S: bright aura + sparkles
static func _embellish(image: Image, grade: String) -> void:
	var gi: int = Items.GRADES.find(grade)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + gi
	var w := image.get_width()
	var h := image.get_height()

	if grade == "F":  # dull the colors and chip a few pixels off
		for y in h:
			for x in w:
				var c := image.get_pixel(x, y)
				if c.a > 0.0:
					if rng.randf() < 0.10:
						image.set_pixel(x, y, Color(0, 0, 0, 0))
					else:
						image.set_pixel(x, y, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, c.a))
		return

	if gi >= 3:  # C+: a couple of bright gem/etching pixels
		var opaque: Array = []
		for y in h:
			for x in w:
				var c := image.get_pixel(x, y)
				if c.a > 0.0 and c.v > 0.25:  # skip outlines
					opaque.append(Vector2i(x, y))
		if not opaque.is_empty():
			var gem := Color(0.35, 0.95, 0.95) if gi < 5 else Color(1.0, 0.9, 0.3)
			for i in mini(2 + (gi - 3), opaque.size()):
				var p: Vector2i = opaque[rng.randi_range(0, opaque.size() - 1)]
				image.set_pixel(p.x, p.y, gem)

	if gi >= 5:  # A/S: gold-trim some of the dark outline
		for y in h:
			for x in w:
				var c := image.get_pixel(x, y)
				if c.a > 0.0 and c.v < 0.25 and rng.randf() < 0.30:
					image.set_pixel(x, y, Color(1.0, 0.85, 0.3, c.a))

	if gi >= 4:  # B+: glowing rim around the silhouette
		var rim: Color = Items.GRADE_COLOR[grade]
		var rim_a := 0.75 if grade == "S" else 0.45
		var to_rim: Array = []
		for y in h:
			for x in w:
				if image.get_pixel(x, y).a > 0.0:
					continue
				for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and image.get_pixel(nx, ny).a > 0.5:
						to_rim.append(Vector2i(x, y))
						break
		for p in to_rim:
			image.set_pixel(p.x, p.y, Color(rim.r, rim.g, rim.b, rim_a))
		if grade == "S":  # sparkles in the aura
			for i in 4:
				if to_rim.is_empty():
					break
				var p: Vector2i = to_rim[rng.randi_range(0, to_rim.size() - 1)]
				image.set_pixel(p.x, p.y, Color(1, 1, 1, 0.95))


## A lush tree: overlapping canopy blobs with 4-tone shading (light from
## the top-right), a highlight sprinkle, dark outline, and a trunk.
## Palettes per zone: green (village), autumn (Darkwood), teal (marsh).
static func _make_tree(kind: String) -> Image:
	var pal: Array = {
		"tree_green":  [Color(0.09, 0.28, 0.13), Color(0.15, 0.44, 0.19), Color(0.27, 0.62, 0.25), Color(0.52, 0.84, 0.34)],
		"tree_autumn": [Color(0.45, 0.13, 0.05), Color(0.76, 0.28, 0.07), Color(0.96, 0.51, 0.10), Color(1.00, 0.80, 0.24)],
		"tree_teal":   [Color(0.04, 0.20, 0.19), Color(0.09, 0.33, 0.29), Color(0.17, 0.48, 0.39), Color(0.33, 0.68, 0.51)],
		"tree_snow":   [Color(0.45, 0.52, 0.62), Color(0.62, 0.68, 0.78), Color(0.80, 0.85, 0.92), Color(0.96, 0.98, 1.00)],
		"tree_spore":  [Color(0.28, 0.12, 0.32), Color(0.45, 0.22, 0.50), Color(0.62, 0.35, 0.68), Color(0.85, 0.55, 0.90)],
	}[kind]
	var w := 26
	var h := 28
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()

	# Trunk first; the canopy will overlap its top.
	var bark := Color(0.34, 0.22, 0.12)
	var bark_d := Color(0.22, 0.14, 0.08)
	for y in range(16, 27):
		for x in range(11, 15):
			image.set_pixel(x, y, bark_d if x == 11 else bark)
	for x in range(10, 16):
		image.set_pixel(x, 26, bark_d)

	# Canopy: four overlapping blobs.
	var canopy := {}
	for blob in [[13, 9, 7.2], [8, 12, 5.8], [18, 12, 5.8], [13, 14, 6.6]]:
		for y in h:
			for x in w:
				if Vector2(x - blob[0], y - blob[1]).length() <= blob[2]:
					canopy[Vector2i(x, y)] = true
	for p: Vector2i in canopy:
		# Light from the top-right, with a little noise for texture.
		var f := (p.x - 13) * 0.55 - (p.y - 11) * 0.85 + rng.randf_range(-1.6, 1.6)
		var tone := clampi(2 + int(round(f / 4.0)), 0, 3)
		image.set_pixel(p.x, p.y, pal[tone])
	# Highlight sprinkles.
	var keys: Array = canopy.keys()
	for i in 7:
		var p: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		image.set_pixel(p.x, p.y, pal[3])
	# Dark outline around the canopy.
	var outline := Color(0.04, 0.06, 0.05)
	for p: Vector2i in canopy:
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + off
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or not canopy.has(Vector2i(q.x, q.y)):
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and not canopy.has(q):
					image.set_pixel(q.x, q.y, outline)
	return image


## Little white speech bubble for emotes ("!", "♪", "…").
static func _make_bubble() -> Image:
	var image := Image.create_empty(14, 13, false, Image.FORMAT_RGBA8)
	var k := Color(0.05, 0.04, 0.08)
	var wcol := Color(0.98, 0.98, 1.0)
	for y in range(1, 9):
		for x in range(1, 13):
			image.set_pixel(x, y, wcol)
	for x in range(1, 13):
		image.set_pixel(x, 0, k)
		image.set_pixel(x, 9, k)
	for y in range(1, 9):
		image.set_pixel(0, y, k)
		image.set_pixel(13, y, k)
	# Tail.
	image.set_pixel(4, 10, k)
	image.set_pixel(5, 10, wcol)
	image.set_pixel(6, 10, k)
	image.set_pixel(5, 11, k)
	return image


## Danger-zone circle for telegraphed attacks (tinted via modulate).
static func _make_telegraph() -> Image:
	var s := 64
	var image := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var c := s / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			if d < 1.0:
				var a := 0.30 if d < 0.92 else 0.95  # soft fill + hard rim
				image.set_pixel(x, y, Color(1, 1, 1, a))
	return image


## A gear icon tinted with its grade color (32x32, ready for UI buttons).
## noun picks the shape variant (Blade vs Bow, Plate vs Guard...).
## If assets/icons/<shape>.png exists (hand-colored icon packs, e.g.
## Raven Fantasy Icons) it wins: used untinted and un-embellished —
## grade stays legible via bag-slot borders and item-name colors.
static func item_icon(slot: String, grade: String, noun := "") -> ImageTexture:
	var shape := _shape_for(slot, noun)
	var key := "itemicon_%s_%s" % [shape, grade]
	if _cache.has(key):
		return _cache[key]
	# Base 32x32: the hand-colored override if present, else procedural. Both
	# take a grade tint — the override gently (it keeps its own palette), the
	# procedural fully — so a Trainee's Blade and an S Blade never look alike.
	var base := _icon_override(shape)
	if base != null:
		if base.get_width() != 32 or base.get_height() != 32:
			base.resize(32, 32, Image.INTERPOLATE_NEAREST)
		_grade_tint(base, Items.GRADE_COLOR[grade], Balance.ICON_OVERRIDE_TINT)
	else:
		base = img(shape)
		_grade_tint(base, Items.GRADE_COLOR[grade], Balance.ICON_PROC_TINT)
		base.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(_tier_frame(base, grade))
	_cache[key] = t
	return t


## Blend a sprite's opaque pixels toward its grade color (multiplied so
## metal stays metal). strength 0 = untouched, 1 = fully the grade color.
static func _grade_tint(image: Image, tint: Color, strength: float) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				var g := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
				image.set_pixel(x, y, c.lerp(g, strength))


## Pad a 32px icon into a fixed margin canvas (so every tier renders the
## SAME size in a row), paint the A/S misty aura into that margin, then run
## the grade embellishment. The pad also gives B+'s rim glow room to bloom.
static func _tier_frame(icon32: Image, grade: String) -> Image:
	var pad: int = Balance.TIER_AURA_PAD
	var w := icon32.get_width()
	var h := icon32.get_height()
	var canvas := Image.create_empty(w + pad * 2, h + pad * 2, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(icon32, Rect2i(0, 0, w, h), Vector2i(pad, pad))
	# A/S read via a SUBTLE colored mist (orange / red), not the loud gold
	# trim + sparkle treatment that suits a weapon held in-world — so the top
	# tiers skip _embellish and wear the aura alone. F..B keep the quiet
	# per-material detailing (chip / gem accents / purple rim).
	if grade == "A" or grade == "S":
		_paint_aura(canvas, Items.GRADE_COLOR[grade])
	else:
		_embellish(canvas, grade)
	return canvas


## The tier AURA: a very light misty halo hugging the silhouette. Pixel
## rings dilate outward from the opaque core into the transparent margin,
## each fainter than the last (peak stays deliberately low). S wears light
## red, A light orange — both straight from GRADE_COLOR.
static func _paint_aura(canvas: Image, col: Color) -> void:
	var cw := canvas.get_width()
	var ch := canvas.get_height()
	var rings: int = Balance.TIER_AURA_RINGS
	var peak: float = Balance.TIER_AURA_ALPHA
	var filled := {}
	var frontier: Array = []
	for y in ch:
		for x in cw:
			if canvas.get_pixel(x, y).a > 0.3:
				var p := Vector2i(x, y)
				filled[p] = true
				frontier.append(p)
	var offs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for r in range(1, rings + 1):
		var a: float = peak * pow(1.0 - float(r) / float(rings + 1), 1.6)
		var nxt: Array = []
		for p: Vector2i in frontier:
			for off: Vector2i in offs:
				var q: Vector2i = p + off
				if q.x < 0 or q.y < 0 or q.x >= cw or q.y >= ch:
					continue
				if filled.has(q):
					continue
				filled[q] = true
				canvas.set_pixel(q.x, q.y, Color(col.r, col.g, col.b, a))
				nxt.append(q)
		frontier = nxt


## assets/icons/ file per consumable id ({"kind": "stone"} bag items).
## Missing file or unknown id -> null; callers keep their text glyph.
const CONSUMABLE_ICONS := {
	"mana_potion": "mana_draught", "elixir_might": "might_elixir",
	"recall_scroll": "recall_scroll", "reset_stone": "reset_stone",
	"tree_tome": "tree_tome",
}


## Hand-authored icon for a non-gear consumable Dictionary, or null.
## Same seam as item_icon overrides: used untinted — grade rarity stays
## on bag-slot borders and name colors.
static func consumable_icon(c: Dictionary) -> ImageTexture:
	var icon_name: String = CONSUMABLE_ICONS.get(String(c.get("id", "")), "")
	if icon_name == "":
		return null
	var key := "consicon_" + icon_name
	if _cache.has(key):
		return _cache[key]
	var over := _icon_override(icon_name)
	if over == null:
		return null
	if over.get_width() != 32 or over.get_height() != 32:
		over.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(over)
	_cache[key] = t
	return t


# A cut gem: bright crown top-left falling to a dark pavilion — drawn
# in whites/steels so the stat color tints it multiplicatively (same
# trick as item_icon). Rows are 12x12.
const GEM_ROWS := [
	"...kkkkkk...",
	"..kwwwsssk..",
	".kwwwwsssSk.",
	"kwwwwssssSSk",
	"kwwsssssSSSk",
	".kwsssSSSSk.",
	".ksssSSSSSk.",
	"..kssSSSSk..",
	"...ksSSSk...",
	"....kSSk....",
	".....kk.....",
	"............",
]


## Gem icon tinted by the stat color. The CUT encodes the level (owner
## rule, 2026-07-09: more cuts = higher tier — teardrop at Lv1 climbing
## to octagon at Lv9/10): assets/icons/gem_lv<1..10>.png, neutral-grey
## bases so the stat tint colors them; Lv10 gains a gold crown pip.
## 32x32, cached — bags hold a lot of gems.
static func gem_icon(col: Color, lvl := 1) -> ImageTexture:
	var key := "gemicon_%s_%d" % [col.to_html(false), lvl]
	if _cache.has(key):
		return _cache[key]
	# Per-level cut first, then the shared gem.png (same seam as the ground
	# drop, which modulates the neutral jewel by stat colour).
	var override := _icon_override("gem_lv%d" % clampi(lvl, 1, 10))
	if override == null:
		override = _icon_override("gem")
	if override != null:
		var tinted := override.duplicate() as Image
		tinted.convert(Image.FORMAT_RGBA8)
		for y in tinted.get_height():
			for x in tinted.get_width():
				var p: Color = tinted.get_pixel(x, y)
				if p.a > 0.0:
					tinted.set_pixel(x, y, Color(p.r * col.r, p.g * col.g, p.b * col.b, p.a))
		if lvl >= 10 and tinted.get_width() >= 32:
			# Max-level capstone: a gold crown pip above the octagon,
			# untinted so it reads gold on every stat color.
			for gy in range(1, 3):
				for gx in range(15, 18):
					tinted.set_pixel(gx, gy, Color(1.0, 0.9, 0.4))
		var ot := ImageTexture.create_from_image(tinted)
		_cache[key] = ot
		return ot
	var image := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	for y in GEM_ROWS.size():
		var row: String = GEM_ROWS[y]
		for x in row.length():
			if row[x] != ".":
				var base: Color = PAL[row[x]]
				image.set_pixel(x, y, Color(base.r * col.r, base.g * col.g, base.b * col.b, 1.0))
	if lvl >= 4:
		image.set_pixel(3, 2, Color(1, 1, 1))
	if lvl >= 7:
		image.set_pixel(6, 4, Color(1, 1, 1))
	if lvl >= 10:
		image.set_pixel(5, 0, Color(1.0, 0.9, 0.4))
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


## A 1px dark outline where an opaque pixel borders empty space — the shared
## finishing pass for the little procedural UI icons below.
static func _ink_outline(img: Image, ink: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edges: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.0:
					edges.append(Vector2i(x, y))
					break
	for p: Vector2i in edges:
		img.set_pixel(p.x, p.y, ink)


## HUD inventory icon: a cinched leather coin-pouch (reads as "bag").
static func _make_bag() -> Image:
	var w := 20
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var body := Color(0.60, 0.40, 0.20)
	var body_d := Color(0.40, 0.25, 0.11)
	var body_l := Color(0.74, 0.53, 0.29)
	var tie := Color(0.86, 0.72, 0.45)
	var ink := Color(0.14, 0.08, 0.04)
	var cx := 9.5
	# Sack body: an egg shape, fatter toward the bottom.
	for y in range(6, 21):
		for x in range(1, 19):
			var ry := (y - 13.0) / 8.0
			var wx: float = 8.2 - maxf(0.0, -ry) * 1.6  # narrower up near the neck
			var rx := (x - cx) / wx
			if rx * rx + ry * ry <= 1.0:
				var c := body
				if (x - cx) < -1.5 and (y - 13.0) < 2.0:
					c = body_l
				elif (x - cx) > 2.5 or (y - 13.0) > 4.0:
					c = body_d
				img.set_pixel(x, y, c)
	# Cinched neck + collar.
	for x in range(6, 14):
		img.set_pixel(x, 5, body_d)
		img.set_pixel(x, 6, tie)
	# Drawstring ends flaring up from the knot.
	for p: Vector2i in [Vector2i(7, 4), Vector2i(12, 4), Vector2i(6, 3), Vector2i(13, 3)]:
		img.set_pixel(p.x, p.y, tie)
	# A knot/coin glint low on the belly.
	img.set_pixel(9, 14, tie)
	img.set_pixel(10, 14, tie)
	_ink_outline(img, ink)
	return img


## HUD codex icon: a closed red book with a gold title band + page edges.
static func _make_book() -> Image:
	var w := 20
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cover := Color(0.62, 0.16, 0.17)
	var cover_d := Color(0.42, 0.10, 0.11)
	var cover_l := Color(0.74, 0.24, 0.24)
	var spine := Color(0.32, 0.07, 0.08)
	var page := Color(0.93, 0.89, 0.76)
	var page_d := Color(0.70, 0.64, 0.50)
	var gold := Color(0.90, 0.74, 0.32)
	var ink := Color(0.12, 0.05, 0.06)
	# Cover block.
	for y in range(2, 20):
		for x in range(4, 17):
			img.set_pixel(x, y, cover)
	# Spine down the left, page block peeking on the right + bottom.
	for y in range(2, 20):
		img.set_pixel(4, y, spine)
		img.set_pixel(5, y, cover_d)
		img.set_pixel(16, y, page if y % 2 == 0 else page_d)
	for x in range(6, 17):
		img.set_pixel(x, 19, page if x % 2 == 0 else page_d)
	# Cover top highlight.
	for x in range(6, 16):
		img.set_pixel(x, 3, cover_l)
	# Gold title bands + clasp glint.
	for x in range(7, 14):
		img.set_pixel(x, 8, gold)
		img.set_pixel(x, 11, gold)
	img.set_pixel(15, 10, gold)
	_ink_outline(img, ink)
	return img


## HUD mailbox icon: a closed envelope with a folded flap (the ✉ glyph has no
## coverage in the mobile pixel font, so the HUD draws this instead).
static func _make_mail() -> Image:
	var w := 20
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var paper := Color(0.93, 0.90, 0.80)
	var paper_d := Color(0.74, 0.70, 0.58)
	var crease := Color(0.56, 0.50, 0.40)
	var ink := Color(0.16, 0.12, 0.07)
	# Envelope body (wider than tall), y 6..17, x 2..17.
	for y in range(6, 18):
		for x in range(2, 18):
			img.set_pixel(x, y, paper)
	for x in range(2, 18):
		img.set_pixel(x, 6, paper_d)   # top edge shade
		img.set_pixel(x, 17, paper_d)  # bottom edge shade
	# Flap: two diagonals from the top corners meeting at a low centre point.
	var apex_x := 10
	var apex_y := 13
	for i in range(0, 9):
		var t: float = float(i) / 8.0
		var lx: int = int(round(2.0 + (float(apex_x) - 2.0) * t))
		var ly: int = int(round(6.0 + (float(apex_y) - 6.0) * t))
		img.set_pixel(clampi(lx, 0, w - 1), clampi(ly, 0, h - 1), crease)
		var rx: int = int(round(17.0 + (float(apex_x) - 17.0) * t))
		var ry: int = int(round(6.0 + (float(apex_y) - 6.0) * t))
		img.set_pixel(clampi(rx, 0, w - 1), clampi(ry, 0, h - 1), crease)
	_ink_outline(img, ink)
	return img


## HUD skill-tree icon: three talent nodes joined by branches (top node forking
## to two below), reading as "skills / progression".
static func _make_skills() -> Image:
	var w := 20
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var node := Color(0.55, 0.80, 1.0)
	var node_l := Color(0.82, 0.94, 1.0)
	var line := Color(0.45, 0.62, 0.86)
	var ink := Color(0.10, 0.14, 0.22)
	var top := Vector2(10, 4)
	var bl := Vector2(5, 16)
	var br := Vector2(15, 16)
	# Branches: top node down to each lower node (2px thick).
	for pair in [[top, bl], [top, br]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		for i in range(0, 15):
			var t: float = float(i) / 14.0
			var px: int = int(round(a.x + (b.x - a.x) * t))
			var py: int = int(round(a.y + (b.y - a.y) * t))
			img.set_pixel(clampi(px, 0, w - 1), clampi(py, 0, h - 1), line)
			img.set_pixel(clampi(px + 1, 0, w - 1), clampi(py, 0, h - 1), line)
	# Nodes as small filled discs.
	for n: Vector2 in [top, bl, br]:
		for y in range(0, h):
			for x in range(0, w):
				var d: float = Vector2(x - n.x, y - n.y).length()
				if d <= 3.0:
					img.set_pixel(x, y, node_l if d < 1.4 else node)
	_ink_outline(img, ink)
	return img


## HUD menu/settings icon: a cogwheel (eight teeth, dark axle bore).
static func _make_gear() -> Image:
	var w := 20
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var metal := Color(0.62, 0.66, 0.74)
	var metal_d := Color(0.42, 0.46, 0.54)
	var metal_l := Color(0.80, 0.84, 0.92)
	var bore := Color(0.20, 0.22, 0.27)
	var ink := Color(0.12, 0.13, 0.16)
	var cx := 10.0
	var cy := 11.0
	# Teeth: eight blocks around the rim (drawn first; the disc overlaps their base).
	for k in range(0, 8):
		var ang: float = float(k) * PI / 4.0
		var tx: int = int(round(cx + cos(ang) * 8.0))
		var ty: int = int(round(cy + sin(ang) * 8.0))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px: int = tx + dx
				var py: int = ty + dy
				if px >= 0 and py >= 0 and px < w and py < h:
					img.set_pixel(px, py, metal_d)
	# Body disc with a diagonal light-to-dark shade.
	for y in range(0, h):
		for x in range(0, w):
			var d: float = Vector2(x - cx, y - cy).length()
			if d <= 6.5:
				var c := metal
				if (x - cx) + (y - cy) < -3.0:
					c = metal_l
				elif (x - cx) + (y - cy) > 3.0:
					c = metal_d
				img.set_pixel(x, y, c)
	# Axle bore (dark, so it reads as a hole without punching transparency).
	for y in range(0, h):
		for x in range(0, w):
			if Vector2(x - cx, y - cy).length() <= 2.4:
				img.set_pixel(x, y, bore)
	_ink_outline(img, ink)
	return img


## HUD stash icon: a banded treasure chest (distinct from the coin-pouch bag).
static func _make_stash() -> Image:
	var w := 20
	var h := 22
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var wood := Color(0.54, 0.35, 0.18)
	var wood_d := Color(0.37, 0.22, 0.10)
	var wood_l := Color(0.66, 0.45, 0.24)
	var band := Color(0.82, 0.68, 0.34)
	var band_d := Color(0.56, 0.45, 0.20)
	var lock := Color(0.88, 0.76, 0.42)
	var ink := Color(0.13, 0.07, 0.03)
	# Lower box (the chest body), y 11..19, x 3..17.
	for y in range(11, 19):
		for x in range(3, 17):
			img.set_pixel(x, y, wood if x < 13 else wood_d)
	# Domed lid, y 5..11 — pull the top row in a pixel each side to round it.
	for y in range(5, 11):
		var inset: int = 1 if y == 5 else 0
		for x in range(3 + inset, 17 - inset):
			img.set_pixel(x, y, wood_l if y < 8 else wood)
	# Lid seam.
	for x in range(3, 17):
		img.set_pixel(x, 11, band_d)
	# Two vertical brass bands.
	for y in range(5, 19):
		img.set_pixel(6, y, band if y % 2 == 0 else band_d)
		img.set_pixel(13, y, band if y % 2 == 0 else band_d)
	# Centre lock plate + keyhole.
	for y in range(10, 14):
		for x in range(9, 12):
			img.set_pixel(x, y, lock)
	img.set_pixel(10, 12, ink)
	_ink_outline(img, ink)
	return img


## Touch target-lock button: a red scope crosshair (arms with a centre gap,
## graduation ticks, a bright core dot) — reads as "aim / lock on". (Distinct
## from _make_reticle, the yellow auto-aim corner brackets.)
static func _make_crosshair() -> Image:
	var w := 24
	var h := 24
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var red := Color(0.92, 0.18, 0.16)
	var red_l := Color(1.0, 0.48, 0.42)
	var cx := 12
	var cy := 12
	# Crosshair arms (2px) with a centre gap around the dot.
	for i in range(1, 23):
		if i >= 9 and i <= 15:
			continue
		img.set_pixel(cx - 1, i, red)
		img.set_pixel(cx, i, red)
		img.set_pixel(i, cy - 1, red)
		img.set_pixel(i, cy, red)
	# Graduation ticks near each arm's end (scope feel).
	for tk in [3, 20]:
		img.set_pixel(cx - 2, tk, red)
		img.set_pixel(cx + 1, tk, red)
		img.set_pixel(tk, cy - 2, red)
		img.set_pixel(tk, cy + 1, red)
	# Bright core dot.
	for y in range(cy - 1, cy + 1):
		for x in range(cx - 1, cx + 1):
			img.set_pixel(x, y, red_l)
	return img


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


## Radial falloff for PointLight2D — like the glow but full-strength at
## the core (lights read through their texture's alpha).
static func _make_light() -> Image:
	var s := 64
	var image := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s / 2.0, y + 0.5 - s / 2.0).length() / (s / 2.0)
			if d < 1.0:
				image.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.2)))
	return image


# One shared wind material sways all foliage: phase comes from each
# sprite's world position, so a single material desynchronizes the
# whole forest for free (no per-instance uniforms).
static var _wind_mat: ShaderMaterial = null

static func wind_material() -> ShaderMaterial:
	if _wind_mat != null:
		return _wind_mat
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
// Foliage wind sway: the sprite's TOP leans, the base stays planted.
// amp is in local texture pixels (sprites are scaled ~3x on screen).
uniform float amp = 1.4;
uniform float speed = 1.1;
void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.031 + MODEL_MATRIX[3].y * 0.017;
	float sway = sin(TIME * speed + phase) + 0.4 * sin(TIME * speed * 2.7 + phase * 1.3);
	VERTEX.x += sway * amp * (1.0 - UV.y);
}
"""
	_wind_mat = ShaderMaterial.new()
	_wind_mat.shader = sh
	return _wind_mat


## Animated river water: pixel-quantized ripple glints scrolling
## downstream, soft banks, faint foam lines at the edges. One material
## per river (the water color is a uniform — the Greyrun runs BLACK in
## blighted lands, murky teal elsewhere).
static func water_material(col: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 water_col : source_color = vec4(0.1, 0.2, 0.2, 0.8);
void fragment() {
	// Chunky water pixels so the shader sits with the 16px art.
	vec2 uv = floor(UV * vec2(20.0, 220.0)) / vec2(20.0, 220.0);
	float x = uv.x;
	float edge = smoothstep(0.0, 0.12, x) * smoothstep(1.0, 0.88, x);
	float y = uv.y * 46.0;
	float r1 = sin((y - TIME * 1.7) * 3.14159 + x * 4.0) * 0.5 + 0.5;
	float r2 = sin((y * 0.53 + TIME * 0.8) * 3.14159 + x * 9.0) * 0.5 + 0.5;
	float glint = smoothstep(0.82, 0.96, r1 * 0.55 + r2 * 0.55);
	float foam = smoothstep(0.10, 0.02, x) + smoothstep(0.90, 0.98, x);
	vec3 rgb = water_col.rgb + glint * 0.16 + foam * 0.08;
	COLOR = vec4(rgb, clamp(water_col.a * edge + foam * 0.20, 0.0, 0.9));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("water_col", col)
	return mat


## A ready-to-add soft point light. radius_px = world-space reach.
## Additive: brightens what's under it, disappears politely in daylight,
## carves through dark terrain tints (voidstone, gravedirt, night).
static func light(color: Color, radius_px: float, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex("light")
	l.texture_scale = radius_px / 32.0
	l.color = color
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l


## A WHITE edge vignette for danger rims (the ambient vignette is black,
## which modulate can't tint — black x red = black). White base, deeper
## edge reach than the ambient one: modulate paints it any danger color.
static func _make_dangerrim() -> Image:
	var w := 320
	var h := 180
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := absf(x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := absf(y + 0.5 - h / 2.0) / (h / 2.0)
			var d := maxf(dx, dy)
			var a := clampf((d - 0.45) / 0.55, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a * 0.85))
	return image


## A vertical loot beam (Diablo-style drop pillar): a hot narrow core
## with a soft horizontal skirt, solid at the base and fading toward
## the sky. Drawn white — the drop's GRADE tints it with modulate.
static func _make_lootbeam() -> Image:
	var w := 32
	var h := 180
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var up := 1.0 - float(y) / h          # 1 at the top of the beam
		var vfade := pow(1.0 - up, 0.6)       # bright base, soft head
		for x in w:
			var dx: float = absf(x + 0.5 - w / 2.0) / (w / 2.0)
			var core: float = maxf(0.0, 1.0 - dx * dx * 3.4)   # hot center column
			var halo: float = (1.0 - dx) * (1.0 - dx) * 0.35   # soft wide skirt
			var a := clampf((core + halo) * vfade, 0.0, 1.0)
			if a > 0.01:
				# The center overexposes toward white for the hot look.
				var white := clampf(core - 0.55, 0.0, 1.0)
				var c := Color(1.0, 1.0, 1.0, a).lerp(Color(1.6, 1.6, 1.5, a), white)
				image.set_pixel(x, y, c)
	return image


## A solid blade sliver: needle points at BOTH ends, belly at ~65%
## along the length (player-provided reference, round 33). SOLID white
## core with a 1px anti-aliased edge — striking, not glowy. White base;
## theme variants tint it with modulate. Drawn pointing right.
static func _make_slashline() -> Image:
	var w := 96
	var h := 14
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cy := (h - 1) / 2.0
	for x in w:
		var t := (x + 0.5) / float(w)
		# Long shallow taper to the belly, then a fast sharp point.
		var half: float = cy * (pow(t / 0.65, 1.6) if t < 0.65 else pow((1.0 - t) / 0.35, 0.8))
		for y in h:
			var a := clampf(half - absf(y - cy) + 0.5, 0.0, 1.0)
			if a > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, a))
	return image


## A soft shockwave ring (white — tint with modulate). Powers nova
## blasts and projectile impact flashes.
# A thin, sleek shockwave ring. Kept at 64px with the ring at texel-radius 24 so
# EVERY consumer's scale (both _ring_fx's radius/24 and the direct fixed-scale
# users: nova, enemy, projectile, paladin link, cutscene, game_base) stays
# correct — only the BAND width dropped (from ~6 to ~1.7) so it reads as a fine
# crisp line instead of a fat blocky smoke band.
static func _make_ring() -> Image:
	var s := 64
	var image := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var band := absf(Vector2(x - c, y - c).length() - 24.0)
			if band < 1.7:
				image.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - band / 1.7, 1.1)))
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


## Override PNGs that BREAK the Crawl faces-left convention by being drawn
## facing RIGHT (so they'd render facing AWAY from the player). Add a sprite's
## base key here when it looks the wrong way; the _anim/_walk strips inherit it
## since facing is resolved on the base name.
const FACES_RIGHT := {
	"zombie": true, "zombie_brute": true, "zombie_overweight": true,
}

## Does this sprite's art natively face LEFT? The Crawl-tileset override
## PNGs face left by convention; our procedural grids (and the FACES_RIGHT
## overrides) face right. Flip logic must invert for left-facing art.
static var _faceleft_cache := {}
static func faces_left(name: String) -> bool:
	if not _faceleft_cache.has(name):
		_faceleft_cache[name] = (not FACES_RIGHT.has(name)) \
			and FileAccess.file_exists("res://assets/sprites/%s.png" % name)
	return _faceleft_cache[name]


## HDR lift for emissive FX (rides viewport/hdr_2d + the glow pass in
## game.gd): pushes a tint past 1.0 so the bloom threshold catches it,
## alpha untouched. Ordinary sprites stay LDR — only deliberate
## emissives (projectile glows, impact rings, loot beams) call this.
const HDR_FX_BOOST := 2.2

static func hdr(c: Color, boost: float = HDR_FX_BOOST) -> Color:
	return Color(c.r * boost, c.g * boost, c.b * boost, c.a)


# ---------------------------------------------------- animation seam ---
# Track C machinery (DESIGN.md Graphics & Ambience): drop
# assets/sprites/<name>_anim.png — a HORIZONTAL strip of square frames —
# and that creature animates. Rendering stays Sprite2D (hframes + frame
# advance), so every existing flip/tint/scale/juice call still works.
# Frame count is auto-detected (width / height). Strips follow the same
# native-facing rule as static overrides (Art.faces_left).
static var _anim_cache := {}

## Idle strip: assets/sprites/<name>_anim.png.
static func anim_info(name: String) -> Dictionary:
	return _strip_info("%s_anim" % name)


## Walk strip: assets/sprites/<name>_walk.png — swapped in by enemies
## and the player while moving (walk/idle split, Track C round 2).
static func walk_info(name: String) -> Dictionary:
	return _strip_info("%s_walk" % name)


## Ability strip: assets/sprites/<name>_<action>.png — a one-shot cast/motion
## strip a boss plays when it fires the matching ability (Track C round 3).
## Empty when absent, so callers stay art-optional.
static func action_info(name: String, action: String) -> Dictionary:
	return _strip_info("%s_%s" % [name, action])


static func _strip_info(base: String) -> Dictionary:
	if _anim_cache.has(base):
		return _anim_cache[base]
	var info := {}
	var path := "res://assets/sprites/%s.png" % base
	var img := _override_image(path)
	if img != null and img.get_height() > 0:
		info = {
			"tex": ImageTexture.create_from_image(img),
			"frames": maxi(1, int(img.get_width() / img.get_height())),
			"fps": 6.0,
		}
	_anim_cache[base] = info
	return info


# ------------------------------------------------ 8-direction render ---
# Optional per-facing art. A directional clip is eight strips
# assets/sprites/<base>_<dir>.png, dir in DIR8. When the SOUTH anchor
# exists the entity renders the strip matching its facing (art encodes
# the direction, so no flip); otherwise dir_set returns {} and callers
# keep the single-facing + horizontal-flip path untouched — every
# existing single-facing mob is unaffected. Missing side directions fall
# back to south so a partial set still renders. PixelLab exports one
# rotation set per clip; the install step assembles them into these files.
static var _dir_cache := {}
const DIR8 := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

## Screen-space vector (+y is DOWN) -> one of the eight DIR8 suffixes.
## Zero rests facing the camera ("s").
static func dir8_suffix(d: Vector2) -> String:
	if d == Vector2.ZERO:
		return "s"
	match int(round(atan2(d.y, d.x) / (PI / 4.0))):  # -4..4
		0: return "e"
		1: return "se"
		2: return "s"
		3: return "sw"
		4, -4: return "w"
		-3: return "nw"
		-2: return "n"
		-1: return "ne"
	return "s"

## The eight per-direction strips for a clip base, or {} when no
## directional art exists on disk. Keyed by DIR8 suffix; absent sides
## fall back to south. Cached per base.
static func dir_set(base: String) -> Dictionary:
	if _dir_cache.has(base):
		return _dir_cache[base]
	var out := {}
	var south := _strip_info("%s_s" % base)
	if not south.is_empty():
		for d in DIR8:
			var info := _strip_info("%s_%s" % [base, d])
			out[d] = info if not info.is_empty() else south
	_dir_cache[base] = out
	return out


# ------------------------------------------------ hero action clips ---
# Full per-class animation set (round: Custom character sheets). Each class
# ships a family of horizontal strips assets/sprites/<class>_<suffix>.png;
# the player clip state machine (player_core/_advance_clip) loops locomotion
# (idle/walk/run) and fires one-shot action clips (attack/cast/dash/ult/death)
# that return to locomotion. idle keeps the legacy "_anim" suffix so the
# enemy/anim_info seam is untouched. Absent files are simply skipped.
const HERO_CLIP_FILES := {
	"idle": "anim", "walk": "walk", "run": "run", "attack": "attack",
	"attack2": "attack2", "cast": "cast", "dash": "dash", "ult": "ult",
	"ultidle": "ultidle", "death": "death",
}
const HERO_CLIP_FPS := {
	# Action clips run FAST so a ~7-frame swing/throw/dash lands in ~0.3s and
	# doesn't trail an arm-swing after the hit. (Directional clips only pick
	# these up via the _dir_loco fps stamp in player_core — dir_set defaults 6.)
	"idle": 6.0, "walk": 9.0, "run": 11.0, "attack": 22.0, "attack2": 22.0,
	"cast": 10.0, "dash": 26.0, "ult": 11.0, "ultidle": 6.0, "death": 9.0,
}

## Every installed animation clip for a hero class, keyed by clip name.
## Returns {} entries only for strips that exist on disk.
static func hero_clips(name: String) -> Dictionary:
	var out := {}
	for clip in HERO_CLIP_FILES:
		var info := _strip_info("%s_%s" % [name, HERO_CLIP_FILES[clip]])
		if not info.is_empty():
			info = info.duplicate()
			info["fps"] = HERO_CLIP_FPS[clip]
			out[clip] = info
	return out


# Directional POSE strips: 8 frames = 8 compass aims (E,NE,N,NW,W,SW,S,SE,
# in that order). Unlike animation clips these aren't played over time — the
# player picks the frame matching the ability's aim so the arm points exactly
# where the strike goes (fixes the flat-swing-vs-aimed-attack mismatch).
const HERO_DIR_FILES := {"stab": "stab_dir", "throw": "throw_dir"}

## Installed directional-pose strips for a hero class, keyed by pose name.
static func hero_dir_clips(name: String) -> Dictionary:
	var out := {}
	for pose in HERO_DIR_FILES:
		var info := _strip_info("%s_%s" % [name, HERO_DIR_FILES[pose]])
		if not info.is_empty():
			out[pose] = info
	return out


## Sprite scale that keeps on-screen size constant regardless of the
## texture's pixel size (grids are 16px, file overrides are often 32px).
## `frames` divides the width for hframes strips (animation seam).
static func scale_for(texture: Texture2D, scale_16px: float, frames := 1) -> Vector2:
	var s := scale_16px * 16.0 / maxf(1.0, float(texture.get_width()) / maxi(1, frames))
	return Vector2(s, s)


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
## Organic look: patch blobs instead of a tile checkerboard, litter (fallen
## leaves / puddles), an edge-highlighted road, and depth shading under
## the top wall. path_kind is painted across the middle rows.
static func ground(base_kind: String, path_kind: String, tiles_w: int, tiles_h: int, seed_val: int, exits: Array = ["W", "E"]) -> ImageTexture:
	var dirs: Array = exits.duplicate()
	dirs.sort()
	var dstr := ""
	for d in dirs:
		dstr += String(d)
	var key := "ground_%s_%s_%d_%s" % [base_kind, path_kind, seed_val, dstr]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pw := tiles_w * 16
	var ph := tiles_h * 16
	# The road is painted as ARMS from the room's center to each REAL
	# doorway — it never promises a door that isn't there (playtest
	# round 3: an always-E/W road walked players into blank walls).
	# Horizontal arms sit on the middle rows (E/W doors), vertical arms
	# on the middle columns (N/S doors); all 3 tiles (48px) wide.
	var path_top := (tiles_h / 2 - 1) * 16 - 8
	var path_bottom := path_top + 3 * 16
	var vleft := pw / 2 - 24
	var vright := vleft + 48
	var arms: Array = [Rect2i(vleft, path_top, 48, 48)]  # central plaza
	if "W" in dirs:
		arms.append(Rect2i(0, path_top, vleft, 48))
	if "E" in dirs:
		arms.append(Rect2i(vright, path_top, pw - vright, 48))
	if "N" in dirs:
		arms.append(Rect2i(vleft, 0, 48, path_top))
	if "S" in dirs:
		arms.append(Rect2i(vleft, path_bottom, 48, ph - path_bottom))
	var image := Image.create_empty(pw, ph, false, Image.FORMAT_RGBA8)

	var g_cols: Array = GROUND[base_kind]
	var p_cols: Array = GROUND[path_kind]
	image.fill_rect(Rect2i(0, 0, pw, ph), g_cols[0])
	var mask := PackedByteArray()
	mask.resize(pw * ph)
	for arm in arms:
		var ar: Rect2i = arm
		image.fill_rect(ar, p_cols[0])
		for y in range(ar.position.y, ar.end.y):
			var row := y * pw
			for x in range(ar.position.x, ar.end.x):
				mask[row + x] = 1

	# Soft organic patches of lighter/darker ground (no checkerboard!).
	var noise_prof: Array = GROUND_NOISE.get(base_kind, [90, 600])
	for i in int(noise_prof[0]):
		var cx := rng.randi_range(0, pw - 1)
		var cy := rng.randi_range(0, ph - 1)
		var r := rng.randi_range(3, 9)
		var on_path := mask[cy * pw + cx] == 1
		var cols: Array = p_cols if on_path else g_cols
		var col: Color = cols[1] if rng.randf() < 0.5 else cols[2]
		for y in range(maxi(0, cy - r), mini(ph, cy + r)):
			for x in range(maxi(0, cx - r), mini(pw, cx + r)):
				var same_band := (mask[y * pw + x] == 1) == on_path
				if same_band and Vector2(x - cx, y - cy).length() <= r and rng.randf() < 0.7:
					image.set_pixel(x, y, col)

	# Fine speckle everywhere.
	for i in int(noise_prof[1]):
		var x := rng.randi_range(0, pw - 1)
		var y := rng.randi_range(0, ph - 1)
		var cols: Array = p_cols if mask[y * pw + x] == 1 else g_cols
		image.set_pixel(x, y, cols[1] if rng.randf() < 0.5 else cols[2])

	# Road edges catch the light (top/left) and fall to shadow
	# (bottom/right); a few stones scattered along the arms.
	var edge: Color = p_cols[2].lightened(0.12)
	var dark: Color = p_cols[1].darkened(0.15)
	for y in ph:
		var row := y * pw
		for x in pw:
			if mask[row + x] == 0:
				continue
			var lit: bool = (y == 0 or mask[row - pw + x] == 0) or (x == 0 or mask[row + x - 1] == 0)
			var shad: bool = (y == ph - 1 or mask[row + pw + x] == 0) or (x == pw - 1 or mask[row + x + 1] == 0)
			if lit and rng.randf() < 0.85:
				image.set_pixel(x, y, edge)
			elif shad and rng.randf() < 0.85:
				image.set_pixel(x, y, dark)
	for i in 26:
		for attempt in 14:
			var sx := rng.randi_range(2, pw - 3)
			var sy := rng.randi_range(2, ph - 3)
			if mask[sy * pw + sx] == 1:
				var stone := Color(0.55, 0.55, 0.6).lightened(rng.randf_range(-0.1, 0.1))
				image.set_pixel(sx, sy, stone)
				image.set_pixel(sx + 1, sy, stone)
				break

	# MACRO floor pass (art audit 2026-07-09). The old flavor litter was
	# 1px confetti — ten biomes collapsed into "murk with accent dots".
	# Each ground kind now draws sparse LANDMARK features (flagstone seams,
	# puddles, dune ripples, drift ridges, buried slabs...) with chunkier
	# strokes, so the floor reads at the same pixel density as the props
	# standing on it. Everything respects the road mask.
	_ground_macro(image, mask, base_kind, pw, ph, rng)

	# Depth: the ground darkens in the wall's shadow at the top.
	for y in range(16, 24):
		var f := 0.72 + (y - 16) / 8.0 * 0.28
		for x in pw:
			var c := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(c.r * f, c.g * f, c.b * f, 1.0))

	# Stone border wall along the top and bottom edge — EXCEPT across a
	# real doorway: painting the whole row walled the N/S doors shut
	# visually even though the collider gap was open (playtest round 3).
	var wall := img("wallblock")
	for tx in tiles_w:
		var in_gap: bool = tx * 16 + 16 > vleft and tx * 16 < vright
		if not (in_gap and "N" in dirs):
			image.blit_rect(wall, Rect2i(0, 0, 16, 16), Vector2i(tx * 16, 0))
		if not (in_gap and "S" in dirs):
			image.blit_rect(wall, Rect2i(0, 0, 16, 16), Vector2i(tx * 16, (tiles_h - 1) * 16))
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t


## ---------------------------------------------------------------------
## Ground MACRO features (art audit 2026-07-09): per-biome landmark
## detail baked into the floor image at generation time. Design rules:
##  * SPARSE — a landmark every few tiles; the generic speckle still
##    carries the in-between (except voidstone, which stays flat).
##  * CHUNKY — 1-2px strokes in ground space (3x on screen), so the
##    floor stops reading one art-voice finer than the props on it.
##  * OFF-ROAD — every feature respects the path mask; roads stay a
##    clean walkable read.
## Cost: generation-time only (the image is cached per room seed).
static func _ground_macro(image: Image, mask: PackedByteArray, base_kind: String, pw: int, ph: int, rng: RandomNumberGenerator) -> void:
	var tiles := (pw / 16) * (ph / 16)
	match base_kind:
		"grass":
			_gm_grass(image, mask, pw, ph, rng, tiles)
		"forest":
			_gm_forest(image, mask, pw, ph, rng, tiles)
		"marsh":
			_gm_wetland(image, mask, pw, ph, rng, tiles, true)
		"bogsoil":
			_gm_wetland(image, mask, pw, ph, rng, tiles, false)
		"stone":
			_gm_flagstones(image, mask, pw, ph, rng, tiles, false)
		"holystone":
			_gm_flagstones(image, mask, pw, ph, rng, tiles, true)
		"basalt":
			_gm_basalt(image, mask, pw, ph, rng, tiles)
		"snow":
			_gm_snow(image, mask, pw, ph, rng, tiles)
		"gravedirt":
			_gm_gravedirt(image, mask, pw, ph, rng, tiles)
		"sand":
			_gm_sand(image, mask, pw, ph, rng)
		"crystalfloor":
			_gm_crystal(image, mask, pw, ph, rng, tiles)
		"voidstone":
			_gm_void(image, mask, pw, ph, rng, tiles)
		"stormgrass":
			_gm_storm(image, mask, pw, ph, rng, tiles)
		"sporesoil":
			_gm_spore(image, mask, pw, ph, rng, tiles)


## Chunky 2x2 block — the macro pass's "fat pixel".
static func _gm_px(image: Image, x: int, y: int, col: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()
	for dy in 2:
		for dx in 2:
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < w and py >= 0 and py < h:
				image.set_pixel(px, py, col)


## Random OFF-ROAD anchor point, clear of the wall rows and their shadow
## band. Returns (-1,-1) when the roll keeps landing on the road.
static func _gm_spot(mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, margin: int) -> Vector2i:
	var y_lo := 22 + margin
	var y_hi := ph - 18 - margin
	if y_hi <= y_lo:
		return Vector2i(-1, -1)
	for attempt in 20:
		var x := rng.randi_range(margin, pw - 1 - margin)
		var y := rng.randi_range(y_lo, y_hi)
		if mask[y * pw + x] == 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## Wobbly line, off-road only. thick=2 draws chunky 2x2 blocks. Points
## actually drawn are appended to out_pts (for shadow/ember follow-ups).
static func _gm_line(image: Image, mask: PackedByteArray, a: Vector2, b: Vector2, col: Color, rng: RandomNumberGenerator, wobble := 0.0, thick := 1, out_pts: Array = []) -> void:
	var pw := image.get_width()
	var ph := image.get_height()
	var n := (b - a).orthogonal().normalized()
	var phase := rng.randf_range(0.0, TAU)
	var freq := rng.randf_range(1.5, 3.5)
	var steps := int(a.distance_to(b)) + 1
	for i in steps:
		var t := float(i) / maxf(1.0, float(steps - 1))
		var p := a.lerp(b, t) + n * (sin(phase + t * freq * TAU) * wobble)
		var x := int(p.x)
		var y := int(p.y)
		if x < 0 or x >= pw or y < 16 or y >= ph - 16:
			continue
		if mask[y * pw + x] == 1:
			continue
		if thick >= 2:
			_gm_px(image, x, y, col)
		else:
			image.set_pixel(x, y, col)
		out_pts.append(Vector2i(x, y))


## Filled ellipse, off-road only; density < 1 stipples the fill; pass a
## rim with alpha > 0 to edge the outer ~quarter in a second color.
static func _gm_blob(image: Image, mask: PackedByteArray, cx: int, cy: int, rx: int, ry: int, fill: Color, rim: Color, rng: RandomNumberGenerator, density := 1.0) -> void:
	var pw := image.get_width()
	var ph := image.get_height()
	for y in range(maxi(16, cy - ry), mini(ph - 16, cy + ry + 1)):
		for x in range(maxi(0, cx - rx), mini(pw, cx + rx + 1)):
			if mask[y * pw + x] == 1:
				continue
			var d := Vector2(float(x - cx) / rx, float(y - cy) / ry).length()
			if d > 1.0:
				continue
			if d > 0.76 and rim.a > 0.0:
				image.set_pixel(x, y, rim)
			elif rng.randf() < density:
				image.set_pixel(x, y, fill)


## grass/village: tufts, worn-dirt patches, a whisper of mowing bands.
static func _gm_grass(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	# Alternating 4-tile bands nudged darker: reads as a meadow's grain.
	# Keep it a WHISPER — at 0.955 the stripes read as scanlines.
	var band := 64
	var by := 24
	var bi := 0
	while by < ph - 16:
		if bi % 2 == 1:
			for y in range(by, mini(by + band, ph - 16)):
				var row := y * pw
				for x in pw:
					if mask[row + x] == 1:
						continue
					var c := image.get_pixel(x, y)
					image.set_pixel(x, y, Color(c.r * 0.975, c.g * 0.975, c.b * 0.975, 1.0))
		by += band
		bi += 1
	# Grass tufts: little 2-4 blade sprigs, tip catching the light.
	var tuft_hi := Color(0.47, 0.71, 0.38)
	var tuft_lo := Color(0.22, 0.42, 0.22)
	for i in maxi(6, tiles / 12):
		var s := _gm_spot(mask, pw, ph, rng, 4)
		if s.x < 0:
			continue
		for b in rng.randi_range(2, 4):
			var bx := s.x + rng.randi_range(-3, 3)
			var bl := rng.randi_range(2, 3)
			if bx < 0 or bx >= pw:
				continue
			for k in bl:
				var py := s.y - k
				if py >= 16 and mask[py * pw + bx] == 0:
					image.set_pixel(bx, py, tuft_hi if k == bl - 1 else tuft_lo)
	# Worn dirt patches: the grass gives up where feet cut the corner.
	var dirt: Array = GROUND["dirt"]
	for i in maxi(3, tiles / 140):
		var s := _gm_spot(mask, pw, ph, rng, 12)
		if s.x < 0:
			continue
		var d_fill: Color = dirt[1]
		var d_rim: Color = dirt[0].darkened(0.18)
		_gm_blob(image, mask, s.x, s.y, rng.randi_range(7, 13), rng.randi_range(4, 8), d_fill, d_rim, rng, 0.88)


## forest/darkwood: root lines + clustered leaf-litter piles.
static func _gm_forest(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var root := Color(0.10, 0.075, 0.05)
	for i in maxi(4, tiles / 70):
		var s := _gm_spot(mask, pw, ph, rng, 10)
		if s.x < 0:
			continue
		var a := Vector2(s.x, s.y)
		var dirv := Vector2.from_angle(rng.randf_range(0.0, TAU))
		_gm_line(image, mask, a, a + dirv * rng.randf_range(30.0, 70.0), root, rng, 2.5, 2)
	# Leaf litter falls in PILES under the canopy, not as even confetti.
	var leaf_cols := [Color(0.95, 0.5, 0.1), Color(0.85, 0.3, 0.1), Color(1.0, 0.75, 0.2), Color(0.55, 0.30, 0.10)]
	for i in maxi(6, tiles / 55):
		var s := _gm_spot(mask, pw, ph, rng, 6)
		if s.x < 0:
			continue
		for j in rng.randi_range(10, 22):
			var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if off.length() > 1.0:
				continue
			var lx := s.x + int(off.x * 9.0)
			var ly := s.y + int(off.y * 6.0)
			if lx < 0 or lx >= pw or ly < 16 or ly >= ph - 16 or mask[ly * pw + lx] == 1:
				continue
			var lc: Color = leaf_cols[rng.randi_range(0, leaf_cols.size() - 1)]
			image.set_pixel(lx, ly, lc)
			if rng.randf() < 0.5 and lx + 1 < pw and mask[ly * pw + lx + 1] == 0:
				image.set_pixel(lx + 1, ly, lc)


## marsh + bogsoil: standing water with a dark rim, sheen dashes, reeds.
## marsh water is teal; the bog's is BLACK with a sickly green rim.
static func _gm_wetland(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int, marsh: bool) -> void:
	var water := Color(0.13, 0.25, 0.26) if marsh else Color(0.07, 0.09, 0.08)
	var rim := Color(0.09, 0.17, 0.18) if marsh else Color(0.27, 0.36, 0.14)
	var sheen := Color(0.34, 0.49, 0.48) if marsh else Color(0.22, 0.30, 0.22)
	var reed := Color(0.18, 0.30, 0.13) if marsh else Color(0.31, 0.39, 0.17)
	for i in maxi(4, tiles / 80):
		var s := _gm_spot(mask, pw, ph, rng, 14)
		if s.x < 0:
			continue
		var rx := rng.randi_range(7, 15)
		var ry := rng.randi_range(4, 8)
		_gm_blob(image, mask, s.x, s.y, rx, ry, water, rim, rng, 1.0)
		# Light catches the water in short horizontal dashes.
		for d in rng.randi_range(2, 4):
			var dx := rng.randi_range(-rx / 2, rx / 4)
			var dy := -ry / 3 - rng.randi_range(0, maxi(1, ry / 3))
			for k in rng.randi_range(3, 6):
				var px := s.x + dx + k
				var py := s.y + dy
				if px >= pw or py < 16 or py >= ph - 16 or mask[py * pw + px] == 1:
					continue
				if Vector2(float(px - s.x) / rx, float(py - s.y) / ry).length() < 0.72:
					image.set_pixel(px, py, sheen)
		# Reeds cluster on the bank.
		for r in rng.randi_range(3, 6):
			var ang := rng.randf_range(0.0, TAU)
			var bx := s.x + int(cos(ang) * (rx + 2))
			var by := s.y + int(sin(ang) * (ry + 2))
			var bl := rng.randi_range(3, 5)
			for k in bl:
				var py := by - k
				if bx < 0 or bx >= pw or py < 16 or py >= ph - 16 or mask[py * pw + bx] == 1:
					continue
				image.set_pixel(bx, py, reed.lightened(0.3) if k == bl - 1 else reed)


## stone/keep + holystone: running-bond flagstone slabs. Holy slabs are
## larger and a few carry an inlaid gold diamond motif.
static func _gm_flagstones(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int, holy: bool) -> void:
	var cols: Array = GROUND["holystone" if holy else "stone"]
	var seam: Color = cols[1].darkened(0.24)
	var sw := 64 if holy else 48
	var sh := 48 if holy else 32
	# Slab tone variation FIRST so seams draw crisp on top.
	for i in maxi(4, tiles / 70):
		var gx := rng.randi_range(0, maxi(0, pw / sw - 1)) * sw
		var gy := 16 + rng.randi_range(0, maxi(0, (ph - 32) / sh - 1)) * sh
		var tone: Color = cols[2] if rng.randf() < 0.5 else cols[1]
		for y in range(gy, mini(gy + sh, ph - 16)):
			var row := y * pw
			for x in range(gx, mini(gx + sw, pw)):
				if mask[row + x] == 0 and rng.randf() < 0.45:
					image.set_pixel(x, y, tone)
	# Running-bond seam grid.
	var y0 := 16
	var row_i := 0
	while y0 < ph - 16:
		for x in pw:
			if mask[y0 * pw + x] == 0 and rng.randf() < 0.9:
				image.set_pixel(x, y0, seam)
		var vx := (sw / 2) if (row_i % 2 == 1) else 0
		while vx < pw:
			for vy in range(y0, mini(y0 + sh, ph - 16)):
				if mask[vy * pw + vx] == 0 and rng.randf() < 0.9:
					image.set_pixel(vx, vy, seam)
			vx += sw
		y0 += sh
		row_i += 1
	# Cracked corners: short diagonal fractures off random seams.
	for i in maxi(4, tiles / 90):
		var s := _gm_spot(mask, pw, ph, rng, 6)
		if s.x < 0:
			continue
		var dirv := Vector2(1, 1) if rng.randf() < 0.5 else Vector2(-1, 1)
		_gm_line(image, mask, Vector2(s.x, s.y), Vector2(s.x, s.y) + dirv * rng.randf_range(4.0, 9.0), seam, rng, 0.8, 1)
	if holy:
		# Inlaid line motifs: concentric diamonds in muted gold, centered
		# on a few slabs — sanctified masonry, not gilded wallpaper.
		var inlay := Color(0.78, 0.68, 0.40)
		var inlay_hi := Color(0.88, 0.80, 0.52)
		for i in maxi(2, tiles / 160):
			var gx := rng.randi_range(0, maxi(0, pw / sw - 1)) * sw + sw / 2
			var gy := 16 + rng.randi_range(0, maxi(0, (ph - 32) / sh - 1)) * sh + sh / 2
			for rad in [10, 5]:
				var mc := inlay if rad == 10 else inlay_hi
				for d in range(-rad, rad + 1):
					var rr: int = rad - absi(d)
					for sy in [gy + rr, gy - rr]:
						var px := gx + d
						if px >= 0 and px < pw and sy >= 16 and sy < ph - 16 and mask[sy * pw + px] == 0:
							image.set_pixel(px, sy, mc)


## basalt/magma: cracked plates with thin ember seams glowing between
## some of them. LDR oranges only — bloom decides what glows.
static func _gm_basalt(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var crack := Color(0.05, 0.03, 0.03)
	var plate_hi := Color(0.27, 0.17, 0.14)
	# A few plates catch more heat-light than others.
	for i in maxi(3, tiles / 110):
		var s := _gm_spot(mask, pw, ph, rng, 14)
		if s.x < 0:
			continue
		_gm_blob(image, mask, s.x, s.y, rng.randi_range(9, 16), rng.randi_range(6, 10), plate_hi, Color(0, 0, 0, 0), rng, 0.4)
	# Jittered lattice of wobbly cracks = plate boundaries.
	var pts: Array = []
	var y := 22 + rng.randi_range(0, 10)
	while y < ph - 18:
		_gm_line(image, mask, Vector2(0, y + rng.randf_range(-4.0, 4.0)), Vector2(pw, y + rng.randf_range(-4.0, 4.0)), crack, rng, 3.0, 1, pts)
		y += rng.randi_range(26, 40)
	var x := rng.randi_range(8, 40)
	while x < pw - 4:
		_gm_line(image, mask, Vector2(x + rng.randf_range(-4.0, 4.0), 16), Vector2(x + rng.randf_range(-4.0, 4.0), ph - 16), crack, rng, 3.0, 1, pts)
		x += rng.randi_range(34, 52)
	# Ember seams: short glowing runs along SOME cracks.
	var ember := Color(1.0, 0.45, 0.12)
	var ember_hot := Color(1.0, 0.72, 0.25)
	if pts.size() > 20:
		for i in maxi(6, pts.size() / 80):  # SOME plates leak fire, not all
			var r0 := rng.randi_range(0, pts.size() - 10)
			var run := rng.randi_range(4, 9)
			for k in run:
				var p: Vector2i = pts[r0 + k]
				image.set_pixel(p.x, p.y, ember_hot if k == run / 2 else ember)
	# A little drifting ash keeps the air dirty (was 260-dot confetti).
	var ash := Color(0.42, 0.36, 0.34)
	for i in 70:
		var ax := rng.randi_range(0, pw - 1)
		var ay := rng.randi_range(16, ph - 17)
		if mask[ay * pw + ax] == 0:
			image.set_pixel(ax, ay, ash)


## snow/ice: drift ridges with a shadowed south face + glassy sheen
## patches. The benchmark biome — augment, don't repaint.
static func _gm_snow(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var crest := Color(0.97, 0.98, 1.0)
	var shade := Color(0.66, 0.72, 0.84)
	for i in maxi(3, tiles / 130):
		var s := _gm_spot(mask, pw, ph, rng, 16)
		if s.x < 0:
			continue
		var pts: Array = []
		var b := Vector2(s.x + rng.randf_range(50.0, 130.0), s.y + rng.randf_range(-8.0, 8.0))
		_gm_line(image, mask, Vector2(s.x, s.y), b, crest, rng, 4.0, 1, pts)
		for p in pts:
			var pv: Vector2i = p
			var sy := pv.y + 1
			if sy < ph - 16 and mask[sy * pw + pv.x] == 0:
				image.set_pixel(pv.x, sy, shade)
	var sheen := Color(0.78, 0.87, 0.97)
	for i in maxi(2, tiles / 190):
		var s := _gm_spot(mask, pw, ph, rng, 12)
		if s.x < 0:
			continue
		var rx := rng.randi_range(6, 11)
		var ry := rng.randi_range(3, 6)
		_gm_blob(image, mask, s.x, s.y, rx, ry, sheen, Color(0, 0, 0, 0), rng, 0.9)
		for g in 2:  # diagonal glints on the ice
			var gx := s.x + rng.randi_range(-rx / 2, rx / 2)
			var gy := s.y + rng.randi_range(-ry / 2, ry / 2)
			for k in 3:
				var px := gx + k
				var py := gy - k
				if px < pw and py >= 16 and mask[py * pw + px] == 0:
					image.set_pixel(px, py, Color(1, 1, 1))
	for i in 140:  # sparse glitter (was 200)
		image.set_pixel(rng.randi_range(0, pw - 1), rng.randi_range(16, ph - 17), Color(1, 1, 1))


## gravedirt: half-buried slab fragments + disturbed-earth mounds.
static func _gm_gravedirt(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var slab := Color(0.55, 0.55, 0.58)
	var slab_dk := Color(0.34, 0.34, 0.38)
	var slab_hi := Color(0.67, 0.67, 0.71)
	for i in maxi(3, tiles / 110):
		var s := _gm_spot(mask, pw, ph, rng, 10)
		if s.x < 0:
			continue
		var w := rng.randi_range(5, 11)
		var h := rng.randi_range(3, 6)
		var chip_x := rng.randi_range(0, 1) * (w - 2)  # one corner sheared off
		var chip_y := rng.randi_range(0, 1) * (h - 2)
		for yy in h:
			for xx in w:
				if xx >= chip_x and xx < chip_x + 2 and yy >= chip_y and yy < chip_y + 2:
					continue
				var px := s.x + xx
				var py := s.y + yy
				if px >= pw or py >= ph - 16 or mask[py * pw + px] == 1:
					continue
				var c := slab
				if yy == 0 or xx == 0:
					c = slab_hi
				elif yy == h - 1 or xx == w - 1 or rng.randf() < 0.14:
					c = slab_dk
				image.set_pixel(px, py, c)
	# Freshly turned earth. Recently. By something.
	var soil_dk := Color(0.24, 0.22, 0.19)
	var soil_hi := Color(0.47, 0.44, 0.39)
	for i in maxi(3, tiles / 120):
		var s := _gm_spot(mask, pw, ph, rng, 8)
		if s.x < 0:
			continue
		var rx := rng.randi_range(4, 8)
		var ry := rng.randi_range(2, 4)
		_gm_blob(image, mask, s.x, s.y, rx, ry, soil_dk, Color(0, 0, 0, 0), rng, 0.9)
		for x in range(s.x - rx / 2, s.x + rx / 2 + 1):
			var py := s.y - ry
			if x >= 0 and x < pw and py >= 16 and mask[py * pw + x] == 0:
				image.set_pixel(x, py, soil_hi)


## sand/desert: directional dune ripple bands — long wavy crests all
## running with the same wind, trough shadow two rows below.
static func _gm_sand(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator) -> void:
	var crest := Color(0.88, 0.78, 0.54)
	var trough := Color(0.61, 0.51, 0.33)
	var slope := 0.14
	var phase0 := rng.randf_range(0.0, TAU)
	var y0 := 20
	var band_i := 0
	while y0 < ph + int(pw * slope):
		var amp := rng.randf_range(2.0, 4.0)
		var freq := rng.randf_range(0.020, 0.035)
		var bphase := phase0 + band_i * 1.7
		for x in pw:
			var yf := float(y0) - x * slope + sin(bphase + x * freq * TAU) * amp
			var y := int(yf)
			if y < 18 or y >= ph - 17 or mask[y * pw + x] == 1:
				continue
			if rng.randf() < 0.85:
				image.set_pixel(x, y, crest)
			var ty := y + 2
			if ty < ph - 16 and mask[ty * pw + x] == 0 and rng.randf() < 0.55:
				image.set_pixel(x, ty, trough)
		y0 += rng.randi_range(20, 30)
		band_i += 1


## crystalfloor: faceted plate lattice + rare glint crosses. The white
## starfield speckle is gone — that's what made it a void/keep clone.
static func _gm_crystal(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var seam := Color(0.45, 0.48, 0.68)
	var seam_hi := Color(0.60, 0.65, 0.88)
	var facet := Color(0.36, 0.38, 0.55)
	for i in maxi(3, tiles / 130):  # a few facets catch the light
		var s := _gm_spot(mask, pw, ph, rng, 14)
		if s.x < 0:
			continue
		_gm_blob(image, mask, s.x, s.y, rng.randi_range(8, 14), rng.randi_range(5, 9), facet, Color(0, 0, 0, 0), rng, 0.5)
	var span := ph - 32
	var d0 := -span
	while d0 < pw:  # +45 degree seams
		var pts: Array = []
		_gm_line(image, mask, Vector2(d0, 16), Vector2(d0 + span, ph - 16), seam, rng, 1.5, 1, pts)
		if pts.size() > 14:  # one bright edge per seam
			var r0 := rng.randi_range(0, pts.size() - 9)
			for k in 8:
				var p: Vector2i = pts[r0 + k]
				image.set_pixel(p.x, p.y, seam_hi)
		d0 += 52 + rng.randi_range(-8, 8)
	var d1 := 0
	while d1 < pw + span:  # -45 degree seams
		_gm_line(image, mask, Vector2(d1, 16), Vector2(d1 - span, ph - 16), seam, rng, 1.5, 1)
		d1 += 52 + rng.randi_range(-8, 8)
	for i in maxi(3, tiles / 120):  # rare glint crosses
		var s := _gm_spot(mask, pw, ph, rng, 6)
		if s.x < 0:
			continue
		for k in range(-2, 3):
			if s.x + k >= 0 and s.x + k < pw and mask[s.y * pw + s.x + k] == 0:
				image.set_pixel(s.x + k, s.y, Color(0.85, 0.95, 1.0))
			if s.y + k >= 16 and s.y + k < ph - 16 and mask[(s.y + k) * pw + s.x] == 0:
				image.set_pixel(s.x, s.y + k, Color(0.85, 0.95, 1.0))


## voidstone: ABSENCE is the identity. Near-featureless matte, a handful
## of hairline rifts, one dim node each. Nothing else. (It read as a
## crystal-cavern clone when it speckled.)
static func _gm_void(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var rift := Color(0.28, 0.20, 0.44)
	var node := Color(0.55, 0.38, 0.85)
	for i in clampi(tiles / 300, 2, 4):
		var s := _gm_spot(mask, pw, ph, rng, 16)
		if s.x < 0:
			continue
		var a := Vector2(s.x, s.y)
		var dirv := Vector2.from_angle(rng.randf_range(0.0, TAU))
		_gm_line(image, mask, a, a + dirv * rng.randf_range(28.0, 70.0), rift, rng, 5.0, 1)
		image.set_pixel(s.x, s.y, node)


## stormgrass: wind-flattened grass — directional streak lanes, every
## streak blown the same way. Grey-blue base lives in GROUND.
static func _gm_storm(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var hi := Color(0.51, 0.58, 0.67)
	var lo := Color(0.20, 0.24, 0.29)
	for i in maxi(5, tiles / 55):
		var s := _gm_spot(mask, pw, ph, rng, 10)
		if s.x < 0:
			continue
		for j in rng.randi_range(8, 14):
			var ox := s.x + rng.randi_range(-40, 40)
			var oy := s.y + rng.randi_range(-9, 9)
			var slen := rng.randi_range(6, 15)
			var col := hi if rng.randf() < 0.65 else lo
			var thick2 := rng.randf() < 0.3
			for k in slen:
				var px := ox + k
				var py := oy + k / 8  # the same shallow downwind slope everywhere
				if px < 0 or px >= pw or py < 16 or py >= ph - 16 or mask[py * pw + px] == 1:
					continue
				image.set_pixel(px, py, col)
				if thick2 and py + 1 < ph - 16 and mask[(py + 1) * pw + px] == 0:
					image.set_pixel(px, py + 1, col)


## sporesoil: mycelium web threads between nodes + spore-dust rings.
static func _gm_spore(image: Image, mask: PackedByteArray, pw: int, ph: int, rng: RandomNumberGenerator, tiles: int) -> void:
	var thread := Color(0.56, 0.43, 0.60)
	var nodes: Array = []
	for i in maxi(3, tiles / 130):
		var s := _gm_spot(mask, pw, ph, rng, 12)
		if s.x >= 0:
			nodes.append(Vector2(s.x, s.y))
	for i in nodes.size():
		var a: Vector2 = nodes[i]
		var b: Vector2 = nodes[(i + 1) % nodes.size()]
		if nodes.size() > 1 and a.distance_to(b) < 170.0:
			_gm_line(image, mask, a, b, thread, rng, 6.0, 1)
		for j in rng.randi_range(2, 3):  # short radial rootlets
			var dirv := Vector2.from_angle(rng.randf_range(0.0, TAU))
			_gm_line(image, mask, a, a + dirv * rng.randf_range(10.0, 24.0), thread, rng, 2.0, 1)
	var dust := Color(0.75, 0.52, 0.78)
	var dust_dk := Color(0.20, 0.14, 0.20)
	for i in maxi(2, tiles / 160):
		var s := _gm_spot(mask, pw, ph, rng, 12)
		if s.x < 0:
			continue
		var rad := rng.randi_range(5, 10)
		_gm_blob(image, mask, s.x, s.y, maxi(2, rad - 2), maxi(2, (rad - 2) * 2 / 3), dust_dk, Color(0, 0, 0, 0), rng, 0.35)
		for k in 20:  # dotted ring of settled spores
			var ang := (TAU / 20.0) * k + rng.randf_range(-0.1, 0.1)
			var px := s.x + int(cos(ang) * rad)
			var py := s.y + int(sin(ang) * rad * 0.66)
			if px >= 0 and px < pw and py >= 16 and py < ph - 16 and mask[py * pw + px] == 0 and rng.randf() < 0.8:
				image.set_pixel(px, py, dust)
