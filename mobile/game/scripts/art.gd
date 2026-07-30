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
	# Elemental boss projectiles: each silhouette communicates its source at a
	# glance instead of every archetype throwing the same magenta orb.
	"stormbolt": {"rows": [
		"................",
		"....c...........",
		"...cwcc.........",
		".ccwwwcc........",
		"......ccwwwwcc..",
		"..........ccwc..",
		"............c...",
		"................",
	]},
	"windslash": {"rows": [
		".........cc.....",
		"......ccwwc.....",
		"...ccwwwwc......",
		".ccwwwwcc.......",
		"...ccwwwwc......",
		"......ccwwc.....",
		".........cc.....",
		"................",
	]},
	"rotbolt": {"rows": [
		"................",
		"...G.....G......",
		"....kGGGk.......",
		".GkkggwggkkG....",
		"..kggwwwggk.....",
		".GkkggwggkkG....",
		"....kGGGk.......",
		"...G.....G......",
	]},
	"earthshard": {"rows": [
		"................",
		"..N.............",
		".kNNNk..........",
		"kNnnNNkkkk......",
		"kNNnnnnnnNNNkk..",
		".kNNNkkkk.......",
		"..N.............",
		"................",
	]},
	"metalshard": {"rows": [
		"................",
		"..S.............",
		".kSSSk..........",
		"kSsswwkkkk......",
		"kSSssssssSSSkk..",
		".kSSSkkkk.......",
		"..S.............",
		"................",
	]},
	"holybolt": {"rows": [
		"................",
		".....y..........",
		"..y..kyyk.......",
		".kyywwwwwyyyk...",
		"kyywwwwwwwwwyyk.",
		".kyywwwwwyyyk...",
		"..y..kyyk.......",
		".....y..........",
	]},
	"griefwave": {"rows": [
		".........pp.....",
		"......ppwwp.....",
		"...ppwwwwp......",
		".ppwwwwpp.......",
		"...ppwwwwp......",
		"......ppwwp.....",
		".........pp.....",
		"................",
	]},
	"sigilbolt": {"rows": [
		"................",
		"......P.........",
		"..P...w.........",
		".PwwwwwwPPPP....",
		"..P...w.........",
		"......P.........",
		"................",
		"................",
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
	"forest": [Color(0.28, 0.45, 0.28), Color(0.22, 0.37, 0.22), Color(0.36, 0.54, 0.34)],
	"marsh":  [Color(0.37, 0.43, 0.27), Color(0.30, 0.36, 0.22), Color(0.46, 0.51, 0.33)],
	"stone":  [Color(0.40, 0.40, 0.46), Color(0.34, 0.34, 0.40), Color(0.46, 0.46, 0.52)],
	"dirt":   [Color(0.52, 0.40, 0.26), Color(0.45, 0.34, 0.22), Color(0.58, 0.46, 0.30)],
	# --------------------------------------------- terrain expansion ---
	"basalt":       [Color(0.32, 0.20, 0.18), Color(0.24, 0.14, 0.13), Color(0.42, 0.25, 0.18)],
	"snow":         [Color(0.82, 0.86, 0.93), Color(0.74, 0.79, 0.88), Color(0.92, 0.95, 1.00)],
	"gravedirt":    [Color(0.40, 0.38, 0.34), Color(0.33, 0.31, 0.28), Color(0.48, 0.46, 0.41)],
	"sand":         [Color(0.78, 0.67, 0.44), Color(0.70, 0.59, 0.38), Color(0.86, 0.76, 0.52)],
	"bogsoil":      [Color(0.28, 0.35, 0.22), Color(0.21, 0.28, 0.17), Color(0.36, 0.43, 0.27)],
	"crystalfloor": [Color(0.30, 0.31, 0.46), Color(0.24, 0.25, 0.38), Color(0.40, 0.42, 0.60)],
	"stormgrass":   [Color(0.36, 0.40, 0.46), Color(0.29, 0.33, 0.38), Color(0.44, 0.49, 0.55)],
	"voidstone":    [Color(0.18, 0.12, 0.24), Color(0.12, 0.08, 0.17), Color(0.28, 0.19, 0.36)],
	"holystone":    [Color(0.66, 0.61, 0.49), Color(0.58, 0.53, 0.42), Color(0.76, 0.71, 0.58)],
	"sporesoil":    [Color(0.38, 0.29, 0.38), Color(0.31, 0.23, 0.31), Color(0.48, 0.37, 0.48)],
	# Dev-preview terrain expansion (2026-07-27): twenty future-biome floor
	# identities. These colors now serve only as road/fallback values: each
	# kind ships a full non-repeating ground_room_<kind>.png surface.
	"mossmeadow":   [Color(0.34, 0.50, 0.32), Color(0.27, 0.42, 0.26), Color(0.43, 0.59, 0.39)],
	"amberleaf":    [Color(0.43, 0.32, 0.21), Color(0.34, 0.24, 0.16), Color(0.54, 0.40, 0.25)],
	"hollowsoil":   [Color(0.25, 0.31, 0.24), Color(0.18, 0.24, 0.18), Color(0.33, 0.39, 0.29)],
	"moonmire":     [Color(0.25, 0.34, 0.34), Color(0.18, 0.27, 0.28), Color(0.34, 0.43, 0.42)],
	"mournearth":   [Color(0.45, 0.43, 0.40), Color(0.36, 0.34, 0.32), Color(0.54, 0.52, 0.48)],
	"barrowgrass":  [Color(0.36, 0.43, 0.33), Color(0.28, 0.35, 0.26), Color(0.45, 0.51, 0.40)],
	"bonefloor":    [Color(0.49, 0.47, 0.41), Color(0.39, 0.37, 0.32), Color(0.59, 0.56, 0.49)],
	"ashsoil":      [Color(0.37, 0.33, 0.31), Color(0.29, 0.25, 0.24), Color(0.46, 0.40, 0.37)],
	"slagstone":    [Color(0.30, 0.22, 0.20), Color(0.23, 0.16, 0.15), Color(0.40, 0.28, 0.23)],
	"obsidian":     [Color(0.22, 0.21, 0.25), Color(0.16, 0.15, 0.19), Color(0.31, 0.29, 0.34)],
	"cinderstone":  [Color(0.36, 0.23, 0.16), Color(0.27, 0.16, 0.11), Color(0.47, 0.31, 0.20)],
	"rimegrass":    [Color(0.57, 0.64, 0.67), Color(0.47, 0.55, 0.59), Color(0.68, 0.73, 0.76)],
	"blueice":      [Color(0.56, 0.68, 0.77), Color(0.45, 0.58, 0.68), Color(0.69, 0.79, 0.86)],
	"hoarfrost":    [Color(0.54, 0.58, 0.62), Color(0.44, 0.48, 0.53), Color(0.65, 0.68, 0.72)],
	"deepcrystal":  [Color(0.25, 0.28, 0.39), Color(0.18, 0.21, 0.31), Color(0.35, 0.39, 0.53)],
	"drownedsoil":  [Color(0.24, 0.33, 0.27), Color(0.17, 0.26, 0.21), Color(0.32, 0.41, 0.34)],
	"rootsoil":     [Color(0.29, 0.25, 0.20), Color(0.22, 0.18, 0.14), Color(0.38, 0.33, 0.25)],
	"fungalhumus":  [Color(0.31, 0.23, 0.29), Color(0.23, 0.16, 0.22), Color(0.42, 0.31, 0.39)],
	"stormstone":   [Color(0.31, 0.35, 0.40), Color(0.24, 0.28, 0.33), Color(0.41, 0.46, 0.51)],
	"voidscar":     [Color(0.20, 0.14, 0.28), Color(0.14, 0.09, 0.20), Color(0.31, 0.21, 0.42)],
	# ----- authored-floor demo kinds (2026-07-18, Lane 1): each has a
	# ground_<kind>.png tileset drop-in, so these palettes only tint the road
	# blend/fallback; the PNG carries the real look. Placeholder-terrain only.
	"forgefloor":   [Color(0.16, 0.09, 0.09), Color(0.22, 0.12, 0.11), Color(0.11, 0.06, 0.06)],
	"lavafield":    [Color(0.90, 0.42, 0.12), Color(1.00, 0.62, 0.20), Color(0.65, 0.25, 0.08)],
	"dungeonfloor": [Color(0.20, 0.24, 0.30), Color(0.28, 0.33, 0.40), Color(0.14, 0.17, 0.22)],
	"hallwood":     [Color(0.34, 0.24, 0.15), Color(0.44, 0.32, 0.20), Color(0.24, 0.17, 0.10)],
	"castletile":   [Color(0.34, 0.32, 0.34), Color(0.42, 0.40, 0.42), Color(0.26, 0.24, 0.26)],
}

# Per-ground generation profile: [organic patch count, fine speckle count].
# Grounds not listed use the default [90, 600]. voidstone runs nearly FLAT
# on purpose — with the full speckle it read as a crystal-cavern clone
# (art audit 2026-07-09: void identity is ABSENCE). Stone floors calm
# their speckle so the flagstone seams read as the dominant texture.
const GROUND_NOISE := {
	"voidstone":    [14, 70],
	"voidscar":     [12, 60],
	"obsidian":     [28, 110],
	"crystalfloor": [60, 240],
	"stone":        [70, 340],
	"holystone":    [70, 340],
}

# Authored future-biome surfaces keep their own macro composition.  Their
# route arms are therefore blended INTO that surface instead of overwriting
# it with one of the legacy dirt/stone/snow strips.  Pattern + palette make
# the navigation language terrain-specific while keeping every real doorway
# connected.
const GROUND_ROOM_PATH := {
	"mossmeadow":  {"pattern": "stepping", "tint": Color("#748b43"), "accent": Color("#b7b66c"), "alpha": 0.12, "period": 22},
	"amberleaf":   {"pattern": "leafwind", "tint": Color("#6d4227"), "accent": Color("#b06d2d"), "alpha": 0.14, "period": 17},
	"hollowsoil":  {"pattern": "root", "tint": Color("#343229"), "accent": Color("#666047"), "alpha": 0.16, "period": 25},
	"moonmire":    {"pattern": "boardwalk", "tint": Color("#46504b"), "accent": Color("#8b8c76"), "alpha": 0.18, "period": 8},
	"mournearth":  {"pattern": "procession", "tint": Color("#b0a999"), "accent": Color("#77736b"), "alpha": 0.11, "period": 20},
	"barrowgrass": {"pattern": "moortrack", "tint": Color("#4c4431"), "accent": Color("#777057"), "alpha": 0.15, "period": 21},
	"bonefloor":   {"pattern": "inlay", "tint": Color("#77736c"), "accent": Color("#c0b798"), "alpha": 0.12, "period": 18},
	"ashsoil":     {"pattern": "ashwind", "tint": Color("#625d58"), "accent": Color("#8a8075"), "alpha": 0.13, "period": 24},
	"slagstone":   {"pattern": "rail", "tint": Color("#29272a"), "accent": Color("#8c4d32"), "alpha": 0.16, "period": 10},
	"obsidian":    {"pattern": "glass", "tint": Color("#242033"), "accent": Color("#665482"), "alpha": 0.10, "period": 29},
	"cinderstone": {"pattern": "quarry", "tint": Color("#56372d"), "accent": Color("#8d4d32"), "alpha": 0.14, "period": 16},
	"rimegrass":   {"pattern": "snowtrack", "tint": Color("#899caf"), "accent": Color("#c0c9cd"), "alpha": 0.12, "period": 23},
	"blueice":     {"pattern": "iceridge", "tint": Color("#7092aa"), "accent": Color("#c1d4df"), "alpha": 0.09, "period": 31},
	"hoarfrost":   {"pattern": "runes", "tint": Color("#77818d"), "accent": Color("#b8c4ca"), "alpha": 0.11, "period": 20},
	"deepcrystal": {"pattern": "mineral", "tint": Color("#343b67"), "accent": Color("#7c89ae"), "alpha": 0.12, "period": 27},
	"drownedsoil": {"pattern": "sunkenplank", "tint": Color("#30372e"), "accent": Color("#6f6a54"), "alpha": 0.18, "period": 9},
	"rootsoil":    {"pattern": "root", "tint": Color("#53412c"), "accent": Color("#8a6a42"), "alpha": 0.13, "period": 22},
	"fungalhumus": {"pattern": "mycelium", "tint": Color("#5b3d50"), "accent": Color("#b69a83"), "alpha": 0.11, "period": 19},
	"stormstone":  {"pattern": "storm", "tint": Color("#46586b"), "accent": Color("#9eb2c4"), "alpha": 0.10, "period": 26},
	"voidscar":    {"pattern": "voidflow", "tint": Color("#33223f"), "accent": Color("#73567d"), "alpha": 0.10, "period": 33},
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


## True when assets/sprites/<name>.png ships (imported into the pack). Lets a
## caller light up an optional override — e.g. the dialogue splash frame shows a
## speaker's art only when splash_<sprite>.png exists, else falls back — without
## paying tex()'s procedural-fallback path just to test presence.
static func has_sprite(name: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/%s.png" % name)


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


## Hand-authored ability icon, or null when no file is installed. An equipped
## theme first looks for assets/icons/ability_<class>_<slot>_<theme>.png and
## falls back to the base ability_<class>_<slot>.png. This lets every gameplay
## variant carry distinct art without making a partial art set unsafe.
##
## The MISS is cached too (as null), not just the hit — unlike the bag/menu
## seams this is polled EVERY FRAME by the ability bar (hud.gd, touch_hud.gd),
## and an uncached miss would re-hit ResourceLoader.exists() 4x per frame
## forever on the (current) all-procedural path.
static func ability_art(cls: String, slot: String, theme_id := "") -> ImageTexture:
	var key := "abicon_%s_%s_%s" % [cls, slot, theme_id]
	if _cache.has(key):
		return _cache[key]
	var base_name := "ability_%s_%s" % [cls, slot]
	var im: Image = null
	if theme_id != "":
		im = _icon_override("%s_%s" % [base_name, theme_id])
	if im == null:
		im = _icon_override(base_name)
	var t: ImageTexture = null
	if im != null:
		if im.get_width() != 64 or im.get_height() != 64:
			im.resize(64, 64, Image.INTERPOLATE_LANCZOS)
		t = ImageTexture.create_from_image(im)
	_cache[key] = t
	return t


## True when a slot has hand-authored art (so it renders untinted, and the
## caller must carry the theme color some other way — see ability_icon).
static func has_ability_art(cls: String, slot: String, theme_id := "") -> bool:
	return ability_art(cls, slot, theme_id) != null


## The icon for one ability slot: hand-authored art if installed, else the
## procedural ASCII glyph tinted with the ability theme's color.
##
## Hand art is used AS-IS, UNTINTED — the same rule (and reason) as the
## item_icon/consumable_icon overrides. The glyph is a 2-color stencil, so
## multiplying a theme color through it IS the art; a painted icon already
## carries its own palette and modulating it just washes the whole thing to
## one hue, which is exactly the "rudimentary" look we're replacing.
##
## The theme signal is NOT dropped, it MOVES to text — which is where the
## menus already put it (menus.gd passes the same tcolor as the button's
## font_color, so those screens lose nothing). On the ability bars, callers
## paint the ability NAME in the theme color instead; see has_ability_art().
static func ability_icon(cls: String, slot: String, tint := Color(0.92, 0.92, 0.98),
		theme_id := "") -> ImageTexture:
	var art := ability_art(cls, slot, theme_id)
	if art != null:
		return art
	return glyph_tex(ABILITY_GLYPH[cls][slot], tint)


## A soft WHITE radial gradient (bright centre, transparent rim), cached once
## and reused for every ability slot. The caller modulates it by the equipped
## variant's theme color, so the icon reads as lit by its element and the slot
## carries the variant colour at a glance. Peak alpha ~0.5 at centre; modulate
## alpha scales it (dim neutral for a slot with no variant chosen yet). Drawn
## at 64px and filtered LINEAR — it is a smooth gradient, not pixel art.
static func ability_glow() -> ImageTexture:
	if _cache.has("ability_glow"):
		return _cache["ability_glow"]
	var n := 64
	var im := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var r: float = sqrt((x - c) * (x - c) + (y - c) * (y - c)) / (n * 0.5)
			var a: float = clampf(0.5 * (1.0 - r), 0.0, 0.5)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(im)
	_cache["ability_glow"] = t
	return t


## Soft-edged white disc used by TextureProgressBar for the clockwise cooldown
## sweep. Every class gets the same recharge language without baking UI state
## into its painted medallion.
##
## `n` must be the EXACT pixel size the bar renders at: TextureProgressBar
## clamps its control size UP to the texture's native size and draws it
## un-scaled from the top-left, so an oversized mask lands off-centre in the
## slot (the sweep read ~6px down-right of the medallion when this was a
## fixed 64 inside a 52px rect).
static func ability_cooldown_mask(n := 64) -> ImageTexture:
	var key := "ability_cooldown_mask_%d" % n
	if _cache.has(key):
		return _cache[key]
	var im := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var r: float = sqrt((x - c) * (x - c) + (y - c) * (y - c))
			# The production medallion occupies 60px of its 64px canvas. Inset
			# the sweep another pixel so its dark edge stays inside the painted
			# gold rim.
			var a: float = clampf((n * 0.455 - r) * 1.5, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t


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


# Every gear family (noun) has its own sprite. B/A/S may provide authored,
# untinted condition-and-ornament variants alongside the neutral family art.
const GEAR_SHAPES := {
	"weapon": {
		"Shuriken": "w_shuriken",
		"Pike": "w_pike", "Warblade": "w_warblade", "Saber": "w_saber",
		"Bulwark Blade": "w_bulwark_blade", "Claymore": "w_claymore",
		"Warbow": "w_warbow", "Longbow": "w_longbow",
		"Hunting Bow": "w_hunting_bow", "Thornbow": "w_thornbow",
		"Recurve": "w_recurve",
		"Stiletto": "w_stiletto", "Glasswing": "w_glasswing",
		"Warded Fang": "w_warded_fang", "Cleaver": "w_cleaver",
		"Scepter": "w_scepter", "Starfocus": "w_starfocus",
		"Zephyr Rod": "w_zephyr_rod", "Bloomstaff": "w_bloomstaff",
		"Greatstaff": "w_greatstaff",
		"Lance": "w_lance", "Oathflail": "w_oathflail",
		"Duelist's Blade": "w_duelists_blade", "Aegis Mace": "w_aegis_mace",
		"Warmaul": "w_warmaul",
		"Grimoire": "w_grimoire", "Hexblade": "w_hexblade",
		"Whisper Rod": "w_whisper_rod", "Pactshield Codex": "w_pactshield_codex",
		"Grimheart Staff": "w_grimheart_staff",
	},
	"armor": {
		"Wardsteel Plate": "a_wardsteel_plate", "Ironwall Plate": "a_ironwall_plate", "Skirmisher's Halfplate": "a_skirmishers_halfplate", "Bloodforged Harness": "a_bloodforged_harness", "Titanplate": "a_titanplate",
		"Stormweave Jerkin": "a_stormweave_jerkin", "Studded Brigandine": "a_studded_brigandine", "Ranger's Leathers": "a_rangers_leathers", "Hunter's Harness": "a_hunters_harness", "Beastpelt": "a_beastpelt",
		"Shadowveil Cloak": "a_shadowveil_cloak", "Warded Mantle": "a_warded_mantle", "Gossamer Cloak": "a_gossamer_cloak", "Nightsilk Wrap": "a_nightsilk_wrap", "Verdant Shroud": "a_verdant_shroud",
		"Silk Vestments": "a_silk_vestments", "Runeplate Robe": "a_runeplate_robe", "Featherweave Robe": "a_featherweave_robe", "Starweave Robe": "a_starweave_robe", "Earthen Robe": "a_earthen_robe",
		"Templar Plate": "a_templar_plate", "Blessed Plate": "a_blessed_plate", "Vigil Halfplate": "a_vigil_halfplate", "Zealot Harness": "a_zealot_harness", "Sanctified Bulwark": "a_sanctified_bulwark",
		"Voidsilk Robe": "a_voidsilk_robe", "Bonemail": "a_bonemail", "Shadeweave Robe": "a_shadeweave_robe", "Ruinweave": "a_ruinweave", "Bloodpact Vestment": "a_bloodpact_vestment",
		"Plate": "icon_armor", "Mail": "icon_mail", "Guard": "icon_shield",
	},
	"boots": {
		"Wardstep Greaves": "b_wardstep_greaves", "Sabatons": "b_sabatons", "Skirmisher's Boots": "b_skirmishers_boots", "Reaver Treads": "b_reaver_treads", "Anchorplate": "b_anchorplate",
		"Piercer's Cleats": "b_piercers_cleats", "Windstriders": "b_windstriders", "Marksman's Stance": "b_marksmans_stance", "Wardedsole": "b_wardedsole", "Trailboots": "b_trailboots",
		"Slipsteps": "b_slipsteps", "Prowlers": "b_prowlers", "Venomtread": "b_venomtread", "Ironsole Wraps": "b_ironsole_wraps", "Grave Treads": "b_grave_treads",
		"Starstep": "b_starstep", "Levitation Slippers": "b_levitation_slippers", "Sigil Sandals": "b_sigil_sandals", "Wardstone Shoes": "b_wardstone_shoes", "Rootbound Sandals": "b_rootbound_sandals",
		"Zealot's Cleats": "b_zealots_cleats", "Sabatons of the Oath": "b_sabatons_of_the_oath", "Vigil Steps": "b_vigil_steps", "Radiant Greaves": "b_radiant_greaves", "Pilgrim's Resolve": "b_pilgrims_resolve",
		"Ruinstep": "b_ruinstep", "Shadowstep Wraps": "b_shadowstep_wraps", "Hexcarved Treads": "b_hexcarved_treads", "Bonewalkers": "b_bonewalkers", "Gravebound Boots": "b_gravebound_boots",
		"Boots": "icon_boots", "Striders": "icon_striders", "Treads": "icon_treads",
	},
	"charm": {
		"Warbanner": "c_warbanner", "Oath Sigil": "c_oath_sigil", "Butcher's Token": "c_butchers_token", "Duelist's Knot": "c_duelists_knot", "Heart of the Wall": "c_heart_of_the_wall",
		"Fletcher's Token": "c_fletchers_token", "Windfeather": "c_windfeather", "Hunter's Totem": "c_hunters_totem", "Stonebark Ward": "c_stonebark_ward", "Greenheart Idol": "c_greenheart_idol",
		"Killer's Mark": "c_killers_mark", "Poisoner's Vial": "c_poisoners_vial", "Ghostlight Charm": "c_ghostlight_charm", "Bloodoath Cord": "c_bloodoath_cord", "Wraithbone Fetish": "c_wraithbone_fetish",
		"Arcane Orb": "c_arcane_orb", "Starshard": "c_starshard", "Aegis Crystal": "c_aegis_crystal", "Zephyr Sigil": "c_zephyr_sigil", "Lifebloom Pendant": "c_lifebloom_pendant",
		"Reliquary": "c_reliquary", "Sunburst Icon": "c_sunburst_icon", "Judgment Sigil": "c_judgment_sigil", "Swiftvow Cord": "c_swiftvow_cord", "Oathkeeper's Seal": "c_oathkeepers_seal",
		"Soul Fetish": "c_soul_fetish", "Cursed Idol": "c_cursed_idol", "Ward of Ash": "c_ward_of_ash", "Umbral Cord": "c_umbral_cord", "Heartcage": "c_heartcage",
		"Charm": "icon_charm", "Talisman": "icon_talisman", "Sigil": "icon_sigil",
	},
	"helmet": {
		"Wardsteel Helm": "h_wardsteel_helm", "Ironwall Helm": "h_ironwall_helm", "Skirmisher's Helm": "h_skirmishers_helm", "Reaver Helm": "h_reaver_helm", "Titan Helm": "h_titan_helm",
		"Stormweave Hood": "h_stormweave_hood", "Studded Hood": "h_studded_hood", "Ranger's Hood": "h_rangers_hood", "Hunter's Hood": "h_hunters_hood", "Beastpelt Hood": "h_beastpelt_hood",
		"Shadowveil Cowl": "h_shadowveil_cowl", "Warded Cowl": "h_warded_cowl", "Gossamer Cowl": "h_gossamer_cowl", "Nightsilk Cowl": "h_nightsilk_cowl", "Grave Cowl": "h_grave_cowl",
		"Silkward Circlet": "h_silkward_circlet", "Runeplate Circlet": "h_runeplate_circlet", "Featherweave Circlet": "h_featherweave_circlet", "Starweave Circlet": "h_starweave_circlet", "Earthen Circlet": "h_earthen_circlet",
		"Blessed Greathelm": "h_blessed_greathelm", "Templar Greathelm": "h_templar_greathelm", "Vigil Greathelm": "h_vigil_greathelm", "Zealot Greathelm": "h_zealot_greathelm", "Sanctified Greathelm": "h_sanctified_greathelm",
		"Voidsilk Hood": "h_voidsilk_hood", "Bonemail Hood": "h_bonemail_hood", "Shadeweave Hood": "h_shadeweave_hood", "Ruinweave Hood": "h_ruinweave_hood", "Bloodpact Hood": "h_bloodpact_hood",
	},
	"gloves": {
		"Wardsteel Gauntlets": "g_wardsteel_gauntlets", "Ironwall Gauntlets": "g_ironwall_gauntlets", "Skirmisher's Gauntlets": "g_skirmishers_gauntlets", "Reaver Gauntlets": "g_reaver_gauntlets", "Titan Gauntlets": "g_titan_gauntlets",
		"Stormweave Bracers": "g_stormweave_bracers", "Studded Bracers": "g_studded_bracers", "Ranger's Bracers": "g_rangers_bracers", "Hunter's Bracers": "g_hunters_bracers", "Beastpelt Bracers": "g_beastpelt_bracers",
		"Shadowveil Grips": "g_shadowveil_grips", "Warded Grips": "g_warded_grips", "Gossamer Grips": "g_gossamer_grips", "Nightsilk Grips": "g_nightsilk_grips", "Grave Grips": "g_grave_grips",
		"Silkward Handwraps": "g_silkward_handwraps", "Runeplate Handwraps": "g_runeplate_handwraps", "Featherweave Handwraps": "g_featherweave_handwraps", "Starweave Handwraps": "g_starweave_handwraps", "Earthen Handwraps": "g_earthen_handwraps",
		"Blessed Gauntlets": "g_blessed_gauntlets", "Templar Gauntlets": "g_templar_gauntlets", "Vigil Gauntlets": "g_vigil_gauntlets", "Zealot Gauntlets": "g_zealot_gauntlets", "Sanctified Gauntlets": "g_sanctified_gauntlets",
		"Voidsilk Claws": "g_voidsilk_claws", "Bonemail Claws": "g_bonemail_claws", "Shadeweave Claws": "g_shadeweave_claws", "Ruinweave Claws": "g_ruinweave_claws", "Bloodpact Claws": "g_bloodpact_claws",
	},
	"pants": {
		"Wardsteel Legplates": "p_wardsteel_legplates", "Ironwall Legplates": "p_ironwall_legplates", "Skirmisher's Legplates": "p_skirmishers_legplates", "Reaver Legplates": "p_reaver_legplates", "Titan Legplates": "p_titan_legplates",
		"Stormweave Leggings": "p_stormweave_leggings", "Studded Leggings": "p_studded_leggings", "Ranger's Leggings": "p_rangers_leggings", "Hunter's Leggings": "p_hunters_leggings", "Beastpelt Leggings": "p_beastpelt_leggings",
		"Shadowveil Wraps": "p_shadowveil_wraps", "Warded Wraps": "p_warded_wraps", "Gossamer Wraps": "p_gossamer_wraps", "Nightsilk Wraps": "p_nightsilk_wraps", "Grave Wraps": "p_grave_wraps",
		"Silkward Underleggings": "p_silkward_underleggings", "Runeplate Underleggings": "p_runeplate_underleggings", "Featherweave Underleggings": "p_featherweave_underleggings", "Starweave Underleggings": "p_starweave_underleggings", "Earthen Underleggings": "p_earthen_underleggings",
		"Blessed Legguards": "p_blessed_legguards", "Templar Legguards": "p_templar_legguards", "Vigil Legguards": "p_vigil_legguards", "Zealot Legguards": "p_zealot_legguards", "Sanctified Legguards": "p_sanctified_legguards",
		"Voidsilk Chausses": "p_voidsilk_chausses", "Bonemail Chausses": "p_bonemail_chausses", "Shadeweave Chausses": "p_shadeweave_chausses", "Ruinweave Chausses": "p_ruinweave_chausses", "Bloodpact Chausses": "p_bloodpact_chausses",
	},
}

# All currently rollable per-class slots have explicit noun-to-art mappings.
const ART_PENDING_SLOTS := []


static func _shape_for(slot: String, noun: String) -> String:
	var shapes: Dictionary = GEAR_SHAPES[slot]
	if shapes.has(noun):
		return shapes[noun]
	return shapes.values()[0]


## Convenience: the icon for a rolled item Dictionary. An item may carry its OWN
## art key (`item["art"]`) — that is the named-unique seam: "End of Night" is not
## an S Shuriken in a different color, it is its own object with its own sprite,
## so it outranks both the per-grade and the family art. Every gear UI in the game
## routes through here, so the key lights up bag, shop, mail, popovers and drops
## at once (the hero's HAND reads it too — see Player weapon_spr / weapon_tex).
static func icon_for(item: Dictionary) -> ImageTexture:
	return item_icon(item["slot"], item["grade"], item.get("noun", ""), item.get("art", ""))


## Held weapon sprite (drawn in the hero's hand). Same override cascade as
## item_icon, so authored gear art reaches the HAND and not just the bag slot —
## before 2026-07-26 this read img() only, meaning a hand-drawn assets/icons/
## weapon changed the inventory icon while the hero still swung the procedural
## one. Tier-1 art (<shape>_<grade>.png) is used as authored: no tint, no
## embellish, because the artist already made it read as its grade.
static func weapon_tex(noun: String, grade: String, art := "") -> ImageTexture:
	var shape := _shape_for("weapon", noun)
	var key := "wpn_%s_%s_%s" % [shape, grade, art]
	if _cache.has(key):
		return _cache[key]
	if art != "":   # tier 0: the named unique's own blade, in the hero's hand
		var uniq := _icon_override(art)
		if uniq != null:
			var ut := ImageTexture.create_from_image(uniq)
			_cache[key] = ut
			return ut
	var authored := _icon_override("%s_%s" % [shape, grade])
	if authored != null:
		var at := ImageTexture.create_from_image(authored)
		_cache[key] = at
		return at
	var image := _icon_override(shape)
	if image == null:
		image = img(shape)
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
static func item_icon(slot: String, grade: String, noun := "", art := "") -> ImageTexture:
	var shape := _shape_for(slot, noun)
	var key := "itemicon_%s_%s_%s" % [shape, grade, art]
	if _cache.has(key):
		return _cache[key]
	# Tier 0 — a NAMED UNIQUE's own sprite, outranking everything. Used exactly as
	# authored. Falls through if the file is missing, so a unique declared before
	# its art exists still renders as its shape instead of vanishing.
	if art != "":
		var uniq := _icon_override(art)
		if uniq != null:
			if uniq.get_width() != 32 or uniq.get_height() != 32:
				uniq.resize(32, 32, Image.INTERPOLATE_NEAREST)
			var ut := ImageTexture.create_from_image(_tier_frame(uniq, grade, false))
			_cache[key] = ut
			return ut
	# Base 32x32: the hand-colored override if present, else procedural. Both
	# take a grade tint — the override gently (it keeps its own palette), the
	# procedural fully — so a Trainee's Blade and an S Blade never look alike.
	# Override cascade, most specific first (PROPOSALS/GEAR_SHAPE_MATRIX.md §5):
	#   1. <shape>_<grade>.png — art authored FOR this tier. Used AS-IS: no tint,
	#      because the art already IS the grade. An S Guard and a D Guard are meant
	#      to be different objects, not one object in two colors.
	#   2. <shape>.png         — one hand-drawn sprite for the whole family, tinted
	#      gently (it keeps its own palette).
	#   3. procedural          — the built-in shape, tinted hard.
	# Grades with no bespoke file fall through to 2/3, so a family can be authored
	# tier by tier without a code change or a half-finished look.
	var authored := false
	var base := _icon_override("%s_%s" % [shape, grade])
	if base != null:
		authored = true   # drawn FOR this grade: no tint, no aura, no embellish
		if base.get_width() != 32 or base.get_height() != 32:
			base.resize(32, 32, Image.INTERPOLATE_NEAREST)
	else:
		base = _icon_override(shape)
		if base != null:
			if base.get_width() != 32 or base.get_height() != 32:
				base.resize(32, 32, Image.INTERPOLATE_NEAREST)
			_grade_tint(base, Items.GRADE_COLOR[grade], Balance.ICON_OVERRIDE_TINT)
		else:
			base = img(shape)
			_grade_tint(base, Items.GRADE_COLOR[grade], Balance.ICON_PROC_TINT)
			base.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(_tier_frame(base, grade, not authored))
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
## `decorate` = false pads only, leaving the art untouched. That is the contract
## for AUTHORED art (a named unique's own sprite, or <shape>_<grade>.png drawn for
## one tier): the artist already expressed the grade in condition, ornament and
## palette, so painting an aura or an embellish rim over it fights the drawing and
## flattens every shape back onto the same rarity ramp. 2026-07-26: the tier-0/1
## cascade skipped _grade_tint but still landed here with decoration ON, which is
## exactly how a hand-authored gold S and blue B both came out reading as the
## stock orange/purple in the codex.
static func _tier_frame(icon32: Image, grade: String, decorate := true) -> Image:
	var pad: int = Balance.TIER_AURA_PAD
	var w := icon32.get_width()
	var h := icon32.get_height()
	if not decorate:
		# Authored art wears no aura, so it needs no transparent margin to bleed
		# into. Returning it UNPADDED means the drawing fills its whole frame
		# wherever it is shown (bag, shop, gallery) instead of sitting in a 42px box
		# at 32/42 = 76% size — a free legibility win for the art the owner invests
		# in, at no cost to the tinted/aura'd icons that still pad below.
		return icon32
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
	# 2026-07-16: the two merchant elixirs were live (stocked, priced, working)
	# but unmapped here, so they fell back to the ⟲ glyph in bag/shop/ground —
	# the "missing icon" the owner reported. File names follow the existing
	# <descriptor>_<vessel> convention (cf. mana_draught / might_elixir).
	# The PNGs are still to be drawn; until they land _icon_override returns
	# null and every caller keeps its glyph, exactly as before.
	"elixir_ward": "ward_elixir", "renewal_draught": "renewal_draught",
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


## Resolve the stat identity from the exact Items.GEM_STATS color supplied by
## every call site. Keeping the public color+level signature avoids making all
## inventory/socket/mailbox callers depend on icon filenames.
static func _gem_stat_for_color(col: Color) -> String:
	var best_stat := ""
	var best_distance := INF
	for stat_key in Items.GEM_STATS:
		var stat := String(stat_key)
		var authored: Color = Items.GEM_STATS[stat]["color"]
		var distance := absf(authored.r - col.r) + absf(authored.g - col.g) \
			+ absf(authored.b - col.b)
		if distance < best_distance:
			best_distance = distance
			best_stat = stat
	return best_stat if best_distance <= 0.02 else ""


## Lore-authored gem family + exact level:
## assets/icons/gem_<stat>_lv<1..10>.png. Every level changes silhouette or
## internal motif, with a shared rough 1-3 / cut 4-6 / fine 7-9 / perfected 10
## quality rhythm. The old tintable cut ladder remains the missing-art fallback.
## 32x32, cached — bags hold a lot of gems.
static func gem_icon(col: Color, lvl := 1) -> ImageTexture:
	var safe_lvl := clampi(lvl, 1, 10)
	var key := "gemicon_%s_%d" % [col.to_html(false), safe_lvl]
	if _cache.has(key):
		return _cache[key]
	var stat := _gem_stat_for_color(col)
	if stat != "":
		var family := _icon_override("gem_%s_lv%d" % [stat, safe_lvl])
		if family != null:
			if family.get_width() != 32 or family.get_height() != 32:
				family.resize(32, 32, Image.INTERPOLATE_NEAREST)
			var family_tex := ImageTexture.create_from_image(family)
			_cache[key] = family_tex
			return family_tex
	# Per-level cut first, then the shared gem.png (same seam as the ground
	# drop, which modulates the neutral jewel by stat colour).
	var override := _icon_override("gem_lv%d" % safe_lvl)
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
		# Square cells remain the universal fallback. A matching static sprite
		# may define a rectangular idle frame when its dimensions evenly tile
		# the strip; structures can then ship tight-cropped instead of carrying
		# transparent padding solely for the old square-frame convention.
		var frame_size := Vector2i(img.get_height(), img.get_height())
		var frames := maxi(1, int(img.get_width() / img.get_height()))
		if base.ends_with("_anim"):
			var static_base := base.trim_suffix("_anim")
			var static_img := _override_image(
				"res://assets/sprites/%s.png" % static_base)
			if static_img != null \
					and static_img.get_height() == img.get_height() \
					and img.get_width() % static_img.get_width() == 0:
				frame_size = static_img.get_size()
				frames = maxi(1, int(img.get_width() / static_img.get_width()))
		info = {
			"tex": ImageTexture.create_from_image(img),
			"frames": frames,
			"frame_size": frame_size,
			"fps": 6.0,
		}
	_anim_cache[base] = info
	return info


# --------------------------------------------------- animated props ---
# Lane 3 asset unlock: SCENERY props (torches, banners, water wheels, forge
# fires, waving grass) self-animate off the SAME <name>_anim.png strip seam
# the creatures use — but a prop has no per-frame script, so it drives itself
# with a looping AnimatedSprite2D built from the strip's frames. Callers set
# scale / z / material / flip exactly as they did on the static Sprite2D, so a
# prop with an _anim strip drops in with no call-site change; without one,
# anim_prop returns null and the static Sprite2D path is untouched.
static var _prop_frames_cache := {}
static func _prop_frames(name: String, info: Dictionary) -> SpriteFrames:
	if _prop_frames_cache.has(name):
		return _prop_frames_cache[name]
	var frames := SpriteFrames.new()  # ships with a "default" animation
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", float(info["fps"]))
	var tex: Texture2D = info["tex"]
	var frame_size: Vector2i = info.get(
		"frame_size", Vector2i(tex.get_height(), tex.get_height()))
	for i in int(info["frames"]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(
			i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame("default", at)
	_prop_frames_cache[name] = frames
	return frames


## A self-driving animated scenery node, or null when the prop ships no
## <name>_anim.png strip (caller then keeps its static Sprite2D). The node
## auto-plays a looping clip; one shared SpriteFrames per prop name is reused
## across every copy in the world.
static func anim_prop(name: String) -> AnimatedSprite2D:
	var info := anim_info(name)
	if info.is_empty():
		return null
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = _prop_frames(name, info)
	spr.animation = "default"
	# Random per-instance start frame so a row of identical props (a wall of
	# torches) doesn't flicker in lockstep — ambient phase, never gameplay.
	spr.frame = randi() % maxi(1, int(info["frames"]))
	spr.play()
	return spr


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

## A few generated rotation sets arrived with mislabeled source views. Keep the
## correction beside the direction seam instead of teaching individual NPC
## interactions about asset filenames. Only the proven-bad views are remapped;
## Fenna's north-east/north-west rotations are already authored correctly.
const DIR8_SOURCE_REMAP := {
	"old_fenna": {"se": "sw", "e": "w", "w": "e", "sw": "se"},
}

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


## Direction suffix for a particular sprite, including narrow corrections for
## generated source sets whose east/west filenames do not match their artwork.
static func dir8_suffix_for(name: String, d: Vector2) -> String:
	var suffix := dir8_suffix(d)
	var remap: Dictionary = DIR8_SOURCE_REMAP.get(name, {})
	return String(remap.get(suffix, suffix))

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


## Scale a strip from the actual painted body height rather than its square
## export canvas. High-resolution character exports often carry wide transparent
## padding; using their full width makes the body visibly smaller than legacy
## 16/32px sprites. This mirrors Player._measure_hero_frame's alpha rule.
static func scale_for_alpha_height(texture: Texture2D, target_height: float, frames := 1) -> Vector2:
	var img: Image = texture.get_image()
	var frame_w := int(img.get_width() / maxi(1, frames))
	var top := img.get_height()
	var bot := -1
	for y in img.get_height():
		for x in frame_w:
			if img.get_pixel(x, y).a > 0.15:
				top = mini(top, y)
				bot = maxi(bot, y)
				break
	if bot <= top:
		return scale_for(texture, target_height / 16.0, frames)
	var s := target_height / float(bot - top)
	return Vector2(s, s)


## Vertical offset from a Sprite2D's centered frame origin to its painted feet.
## Lets a newly normalized high-res body grow upward from its existing ground
## line instead of sinking into it as its scale increases.
static func alpha_feet_offset(texture: Texture2D, scale: float, frames := 1) -> float:
	var img: Image = texture.get_image()
	var frame_w := int(img.get_width() / maxi(1, frames))
	var bot := -1
	for y in img.get_height():
		for x in frame_w:
			if img.get_pixel(x, y).a > 0.15:
				bot = maxi(bot, y)
				break
	if bot < 0:
		return 0.0
	return (float(bot) - float(img.get_height()) * 0.5) * scale


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


# -------------------------------------------------- ground tile seam ---
# Lane 1 asset unlock: a ground KIND can ship a PNG tileset that replaces
# its procedural palette fill. Drop assets/sprites/ground_<kind>.png — a
# single seamless square tile OR a GRID of square variation tiles (a 4x1
# strip, a 1xN column, or an NxM sheet of grass/stone variants). Cell size
# is inferred from the SHORTER axis so any of those shapes parse; the floor
# tiles it, picking a seeded variation cell per 16px tile so a multi-cell
# sheet reads non-repeating. No override -> {} and the procedural floor is
# byte-for-byte untouched, so every shipping biome is unaffected until art
# lands. Pack tiles resize to the 16px ground grid, matching the props'
# pixel density. Both the parse and the resized cells cache per kind.
static var _ground_ts_cache := {}
static func _ground_tileset(kind: String) -> Dictionary:
	if _ground_ts_cache.has(kind):
		return _ground_ts_cache[kind]
	var info := {}
	var im := _override_image("res://assets/sprites/ground_%s.png" % kind)
	if im != null and im.get_width() > 0 and im.get_height() > 0:
		if im.get_format() != Image.FORMAT_RGBA8:
			im.convert(Image.FORMAT_RGBA8)
		var w := im.get_width()
		var h := im.get_height()
		var cell := maxi(1, mini(w, h))
		info = {"img": im, "cell": cell, "cols": maxi(1, w / cell), "rows": maxi(1, h / cell)}
	_ground_ts_cache[kind] = info
	return info


## A complete authored room surface. Unlike ground_<kind>.png tile sheets,
## this image is stretched once across the whole 44x26 room and never repeats.
## Roads, door-aware arms, wall shadow and boundary walls are still composited
## afterward, so authored terrain material does not break navigation language.
static var _ground_room_cache := {}
static func _ground_room_surface(kind: String, pw: int, ph: int) -> Image:
	var key := "%s_%dx%d" % [kind, pw, ph]
	if _ground_room_cache.has(key):
		return _ground_room_cache[key]
	var im := _override_image("res://assets/sprites/ground_room_%s.png" % kind)
	if im != null:
		if im.get_format() != Image.FORMAT_RGBA8:
			im.convert(Image.FORMAT_RGBA8)
		if im.get_width() != pw or im.get_height() != ph:
			# Preserve the deliberately chunky pixel clusters at non-default
			# room sizes; smoothing would pull these surfaces back toward the
			# overly realistic look this authored pass replaces.
			im.resize(pw, ph, Image.INTERPOLATE_NEAREST)
	_ground_room_cache[key] = im
	return im


## Fill `rect` by tiling a ground tileset — one 16px floor tile per step,
## a seeded variation cell each — so a multi-cell sheet covers without an
## obvious repeat. Source cells resize to 16px once and cache on the shared
## tileset dict (cheap across every room that paints the same kind).
static func _tile_fill(image: Image, rect: Rect2i, ts: Dictionary, rng: RandomNumberGenerator) -> void:
	var cache: Array = ts.get("_cells16", [])
	if cache.is_empty():
		var cell: int = ts["cell"]
		var src: Image = ts["img"]
		for r in int(ts["rows"]):
			for c in int(ts["cols"]):
				var piece := Image.create_empty(cell, cell, false, Image.FORMAT_RGBA8)
				piece.blit_rect(src, Rect2i(c * cell, r * cell, cell, cell), Vector2i.ZERO)
				if cell != 16:
					piece.resize(16, 16, Image.INTERPOLATE_NEAREST)
				cache.append(piece)
		ts["_cells16"] = cache
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var piece: Image = cache[rng.randi() % cache.size()]
			var dst := Rect2i(x, y, 16, 16).intersection(rect)
			if dst.size.x > 0 and dst.size.y > 0:
				image.blit_rect(piece, Rect2i(0, 0, dst.size.x, dst.size.y), dst.position)
			x += 16
		y += 16


static func _route_mark(image: Image, mask: PackedByteArray, pw: int, ph: int,
		x: int, y: int, radius: int, color: Color, strength: float = 0.46) -> void:
	for py in range(maxi(0, y - radius), mini(ph, y + radius + 1)):
		var row := py * pw
		for px in range(maxi(0, x - radius), mini(pw, x + radius + 1)):
			if mask[row + px] == 1:
				var current := image.get_pixel(px, py)
				image.set_pixel(px, py, current.lerp(color, strength))


## Preserve the authored room composition while still making every real exit
## readable. The legacy compositor replaced every path arm with dirt/stone;
## these future biomes instead receive a restrained material glaze plus their
## own route grammar (fen planks, slag rails, root ribs, ice seams, etc.).
static func _paint_authored_route(image: Image, mask: PackedByteArray, arms: Array,
		pw: int, ph: int, spec: Dictionary, rng: RandomNumberGenerator) -> void:
	var tint: Color = spec.get("tint", Color.WHITE)
	var accent: Color = spec.get("accent", tint.lightened(0.18))
	var alpha: float = float(spec.get("alpha", 0.12))
	var pattern: String = String(spec.get("pattern", "track"))
	var period: int = int(spec.get("period", 20))
	for y in ph:
		var row := y * pw
		for x in pw:
			if mask[row + x] == 1:
				image.set_pixel(x, y, image.get_pixel(x, y).lerp(tint, alpha))

	for arm_var in arms:
		var arm: Rect2i = arm_var
		var vertical := arm.size.y > arm.size.x
		var start := arm.position.y if vertical else arm.position.x
		var finish := arm.end.y if vertical else arm.end.x
		var center := arm.position.x + arm.size.x / 2 if vertical else arm.position.y + arm.size.y / 2
		var along := start + period / 2
		while along < finish:
			var jitter := rng.randi_range(-2, 2)
			var x := center + jitter if vertical else along
			var y := along if vertical else center + jitter
			match pattern:
				"boardwalk", "sunkenplank":
					# Cross-planks, deliberately broken in the drowned variant.
					var half := 18 if pattern == "boardwalk" else 15
					for cross in range(-half, half + 1, 3):
						if pattern == "sunkenplank" and rng.randf() < 0.12:
							continue
						_route_mark(image, mask, pw, ph,
							x + (cross if vertical else 0),
							y + (0 if vertical else cross), 1, accent, 0.42)
				"rail":
					# Paired rails and regularly spaced clinker ties.
					for offset in [-11, 11]:
						_route_mark(image, mask, pw, ph,
							x + (offset if vertical else 0),
							y + (0 if vertical else offset), 1, accent, 0.58)
					for cross in range(-16, 17, 4):
						_route_mark(image, mask, pw, ph,
							x + (cross if vertical else 0),
							y + (0 if vertical else cross), 0, tint.lightened(0.16), 0.38)
				"stepping":
					for offset in [-8, 7]:
						_route_mark(image, mask, pw, ph,
							x + (offset if vertical else 0),
							y + (0 if vertical else offset), 3, accent, 0.28)
				"procession", "moortrack", "snowtrack":
					for offset in [-9, 9]:
						_route_mark(image, mask, pw, ph,
							x + (offset if vertical else 0),
							y + (0 if vertical else offset),
							1 if pattern != "snowtrack" else 2, accent, 0.30)
				"root", "mycelium":
					for offset in [-10, 0, 10]:
						var wave := int(sin(float(along + offset * 3) * 0.08) * 4.0)
						_route_mark(image, mask, pw, ph,
							x + (offset + wave if vertical else 0),
							y + (0 if vertical else offset + wave),
							1 if pattern == "root" else 0, accent, 0.33)
				"leafwind", "ashwind":
					for offset in [-12, 0, 12]:
						_route_mark(image, mask, pw, ph,
							x + (offset if vertical else jitter),
							y + (jitter if vertical else offset), 1, accent, 0.28)
				"inlay", "runes", "quarry":
					for offset in [-6, 6]:
						_route_mark(image, mask, pw, ph,
							x + (offset if vertical else 0),
							y + (0 if vertical else offset), 1, accent, 0.38)
					_route_mark(image, mask, pw, ph, x, y, 2, accent, 0.24)
				"glass", "iceridge", "mineral", "storm", "voidflow":
					var branch := rng.randi_range(-9, 9)
					_route_mark(image, mask, pw, ph, x, y, 1, accent, 0.31)
					_route_mark(image, mask, pw, ph,
						x + (branch if vertical else 4),
						y + (4 if vertical else branch), 0, accent, 0.27)
				_:
					_route_mark(image, mask, pw, ph, x, y, 1, accent, 0.30)
			along += period


## Compose one big ground texture for a zone (34 x 15 tiles of 16px art).
## Organic look: patch blobs instead of a tile checkerboard, litter (fallen
## leaves / puddles), an edge-highlighted road, and depth shading under
## the top wall. path_kind is painted across the middle rows. A ground kind
## with a PNG tileset (_ground_tileset) tiles that instead of the palette.
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

	# Full authored room surfaces take precedence over optional tile sheets.
	# Both replace procedural base detail; paths remain independently
	# composited so exits and roads stay readable.
	var room_surface := _ground_room_surface(base_kind, pw, ph)
	var authored_room := room_surface != null
	var base_ts := _ground_tileset(base_kind)
	var path_ts := _ground_tileset(path_kind)
	var tiled_base := not base_ts.is_empty()
	var tiled_path := not path_ts.is_empty()
	var authored_base := authored_room or tiled_base
	var authored_path := authored_room and GROUND_ROOM_PATH.has(base_kind)

	var g_cols: Array = GROUND[base_kind]
	var p_cols: Array = GROUND[path_kind]
	if authored_room:
		image.blit_rect(room_surface, Rect2i(0, 0, pw, ph), Vector2i.ZERO)
	elif tiled_base:
		_tile_fill(image, Rect2i(0, 0, pw, ph), base_ts, rng)
	else:
		image.fill_rect(Rect2i(0, 0, pw, ph), g_cols[0])
	var mask := PackedByteArray()
	mask.resize(pw * ph)
	for arm in arms:
		var ar: Rect2i = arm
		if authored_path:
			pass  # keep the room-scale composition under its bespoke route
		elif tiled_path:
			_tile_fill(image, ar, path_ts, rng)
		else:
			image.fill_rect(ar, p_cols[0])
		for y in range(ar.position.y, ar.end.y):
			var row := y * pw
			for x in range(ar.position.x, ar.end.x):
				mask[row + x] = 1
	if authored_path:
		_paint_authored_route(image, mask, arms, pw, ph, GROUND_ROOM_PATH[base_kind], rng)

	# Soft organic patches of lighter/darker ground (no checkerboard!).
	var noise_prof: Array = GROUND_NOISE.get(base_kind, [90, 600])
	for i in int(noise_prof[0]):
		var cx := rng.randi_range(0, pw - 1)
		var cy := rng.randi_range(0, ph - 1)
		var r := rng.randi_range(3, 9)
		var on_path := mask[cy * pw + cx] == 1
		if (on_path and (tiled_path or authored_path)) or (not on_path and authored_base):
			continue  # a PNG-tiled band carries its own detail
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
		var on_path_px := mask[y * pw + x] == 1
		if (on_path_px and (tiled_path or authored_path)) or (not on_path_px and authored_base):
			continue  # skip speckle over a PNG-tiled band
		var cols: Array = p_cols if on_path_px else g_cols
		image.set_pixel(x, y, cols[1] if rng.randf() < 0.5 else cols[2])

	# Road edges catch the light (top/left) and fall to shadow
	# (bottom/right); a few stones scattered along the arms. A PNG-tiled
	# path ships its own edges, so this painted rim + stones skip it.
	var edge: Color = p_cols[2].lightened(0.12)
	var dark: Color = p_cols[1].darkened(0.15)
	for y in (0 if tiled_path or authored_path else ph):
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
	for i in (0 if tiled_path or authored_path else 26):
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
	# standing on it. Everything respects the road mask. A PNG-tiled base
	# ships its own landmark detail, so the macro pass skips it.
	if not authored_base:
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
		"grass", "mossmeadow":
			_gm_grass(image, mask, pw, ph, rng, tiles)
		"forest", "amberleaf", "hollowsoil":
			_gm_forest(image, mask, pw, ph, rng, tiles)
		"marsh", "moonmire", "drownedsoil":
			_gm_wetland(image, mask, pw, ph, rng, tiles, true)
		"bogsoil", "rootsoil":
			_gm_wetland(image, mask, pw, ph, rng, tiles, false)
		"stone", "bonefloor", "hoarfrost":
			_gm_flagstones(image, mask, pw, ph, rng, tiles, false)
		"holystone":
			_gm_flagstones(image, mask, pw, ph, rng, tiles, true)
		"basalt", "ashsoil", "slagstone", "cinderstone", "obsidian":
			_gm_basalt(image, mask, pw, ph, rng, tiles)
		"snow", "rimegrass", "blueice":
			_gm_snow(image, mask, pw, ph, rng, tiles)
		"gravedirt", "mournearth", "barrowgrass":
			_gm_gravedirt(image, mask, pw, ph, rng, tiles)
		"sand":
			_gm_sand(image, mask, pw, ph, rng)
		"crystalfloor", "deepcrystal":
			_gm_crystal(image, mask, pw, ph, rng, tiles)
		"voidstone", "voidscar":
			_gm_void(image, mask, pw, ph, rng, tiles)
		"stormgrass", "stormstone":
			_gm_storm(image, mask, pw, ph, rng, tiles)
		"sporesoil", "fungalhumus":
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
