class_name Achievements
## The achievement registry — id -> {name, desc, pts}. Unlocks are stored
## on the Game (game.achievements: id -> true), persisted with the save,
## and announced by a HUD toast. Triggers are sprinkled at their natural
## sites (boss death, level-up, chapter clear, daily streak, S-gear).
## Displayed in the codex Records tab alongside boss personal bests.
##
## POINTS feed the title system below: every unlock is worth pts
## (DEFAULT_PTS unless the entry says otherwise — the hard ones pay more).
##
## Single-player today; this same unlock set seeds account-wide progress
## when multiplayer lands.

const DEFAULT_PTS := 10

const DATA := {
	"first_boss":     {"name": "First Blood", "desc": "Defeat your first boss."},
	"flawless":       {"name": "Untouchable", "desc": "Defeat a boss without taking a single hit.", "pts": 20},
	"no_potion_boss": {"name": "Iron Discipline", "desc": "Defeat a boss without drinking a potion."},
	"boss_hunter":    {"name": "Vale Reaper", "desc": "Defeat 9 different bosses.", "pts": 20},
	"s_gear":         {"name": "Legendary Arms", "desc": "Acquire an S-grade item.", "pts": 15},
	"gem_max":        {"name": "Master Jeweler", "desc": "Obtain a max-level gem.", "pts": 20},
	"wealthy":        {"name": "Coin Hoarder", "desc": "Amass 5,000 gold."},
	"level_20":       {"name": "Seasoned", "desc": "Reach level 20."},
	"level_40":       {"name": "Ascendant", "desc": "Reach the level 40 cap.", "pts": 20},
	"streak_7":       {"name": "Devoted", "desc": "Reach a 7-day login streak."},
	"clear_ch1":      {"name": "The Hollow King Falls", "desc": "Complete Chapter 1."},
	"clear_ch2":      {"name": "Warden of the Waking", "desc": "Complete Chapter 2."},
	"clear_ch3":      {"name": "Into the Unburied Vale", "desc": "Complete Chapter 3."},
}

## Display order (registry dicts don't guarantee it).
const ORDER := ["first_boss", "flawless", "no_potion_boss", "boss_hunter",
	"s_gear", "gem_max", "wealthy", "level_20", "level_40", "streak_7",
	"clear_ch1", "clear_ch2", "clear_ch3"]

# ------------------------------------------------------------------ titles ---
# Displayed titles (retention roadmap #5): worn next to the class name on
# the HUD, equipped from the codex Records tab. Requirements combine
# achievement POINTS with specific feats, lore entries unearthed
# (kill-count thresholds, see lore.gd) and lifetime kills — the collection
# game pays out in identity. game.title_available(id) checks them.

const TITLES := {
	"wanderer":    {"name": "the Wanderer",       "req_pts": 0,
		"how": "Free for every bearer — the road makes no demands."},
	"slayer":      {"name": "the Slayer",         "req_pts": 30,
		"how": "Earn 30 achievement points."},
	"untouchable": {"name": "the Untouchable",    "req_ach": "flawless",
		"how": "Defeat a boss without taking a single hit."},
	"devoted":     {"name": "the Devoted",        "req_ach": "streak_7",
		"how": "Reach a 7-day login streak."},
	"lorekeeper":  {"name": "the Lorekeeper",     "req_lore": 8,
		"how": "Unearth 8 codex lore entries (slay enough of a kind)."},
	"reaper":      {"name": "Reaper of the Vale", "req_kills": 500,
		"how": "Slay 500 monsters with one character."},
	"legend":      {"name": "the Legend",         "req_pts": 100,
		"how": "Earn 100 achievement points."},
}

const TITLE_ORDER := ["wanderer", "slayer", "untouchable", "devoted",
	"lorekeeper", "reaper", "legend"]
