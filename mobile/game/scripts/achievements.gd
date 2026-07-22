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

	# Record-track tiers (see TRACKS below) — ids are "<track>_<tier>", one
	# entry per crossed tier so unlock/persist/toast/points ride the same
	# machinery as every achievement above. Kept OUT of ORDER: the codex
	# Records tab draws tracks as progress bars, not 20 extra list rows.
	"kills_1":  {"name": "Reaper's Tally I",   "desc": "Slay 100 monsters (lifetime, this character)."},
	"kills_2":  {"name": "Reaper's Tally II",  "desc": "Slay 500 monsters (lifetime, this character)."},
	"kills_3":  {"name": "Reaper's Tally III", "desc": "Slay 1,500 monsters (lifetime, this character).", "pts": 15},
	"kills_4":  {"name": "Reaper's Tally IV",  "desc": "Slay 4,000 monsters (lifetime, this character).", "pts": 20},
	"bosses_1": {"name": "Bossbreaker I",   "desc": "Fell 5 bosses (lifetime, this character)."},
	"bosses_2": {"name": "Bossbreaker II",  "desc": "Fell 20 bosses (lifetime, this character)."},
	"bosses_3": {"name": "Bossbreaker III", "desc": "Fell 60 bosses (lifetime, this character).", "pts": 15},
	"bosses_4": {"name": "Bossbreaker IV",  "desc": "Fell 150 bosses (lifetime, this character).", "pts": 20},
	"lore_1":   {"name": "Chronicler I",   "desc": "Unearth 3 codex lore entries."},
	"lore_2":   {"name": "Chronicler II",  "desc": "Unearth 8 codex lore entries."},
	"lore_3":   {"name": "Chronicler III", "desc": "Unearth 15 codex lore entries.", "pts": 15},
	"lore_4":   {"name": "Chronicler IV",  "desc": "Unearth 25 codex lore entries.", "pts": 20},
	"clears_1": {"name": "Pathfinder I",   "desc": "Clear a chapter (account-wide, any class)."},
	"clears_2": {"name": "Pathfinder II",  "desc": "Clear 5 chapters (account-wide, any class)."},
	"clears_3": {"name": "Pathfinder III", "desc": "Clear 15 chapters (account-wide, any class).", "pts": 15},
	"clears_4": {"name": "Pathfinder IV",  "desc": "Clear 30 chapters (account-wide, any class).", "pts": 20},
	"depth_1":  {"name": "Depthcrawler I",   "desc": "Reach depth 12 in the Waking Depths (any class)."},
	"depth_2":  {"name": "Depthcrawler II",  "desc": "Reach depth 24 in the Waking Depths (any class)."},
	"depth_3":  {"name": "Depthcrawler III", "desc": "Reach depth 36 in the Waking Depths (any class).", "pts": 15},
	"depth_4":  {"name": "Depthcrawler IV",  "desc": "Reach depth 48 in the Waking Depths (any class).", "pts": 20},
}

## Display order (registry dicts don't guarantee it).
const ORDER := ["first_boss", "flawless", "no_potion_boss", "boss_hunter",
	"s_gear", "gem_max", "wealthy", "level_20", "level_40", "streak_7",
	"clear_ch1", "clear_ch2", "clear_ch3"]

# ------------------------------------------------------------ record tracks ---
# Tiered, repeatable achievements (the "record score" pattern): one TRACK =
# one lifetime counter graded by rising tier thresholds, rendered in the
# codex Records tab as a progress bar with a medal per tier crossed. Each
# crossed tier is a REGULAR achievement (id "<track>_<tier>", entries in
# DATA above) so unlock/persist/toast/points all ride the existing
# machinery. Counters are read live in game_flow.track_value();
# game_flow.check_track_achievements() crosses tiers idempotently.

const TRACKS := {
	"kills":  {"name": "Reaper's Tally", "how": "Monsters slain — lifetime, this character.",
		"tiers": [100, 500, 1500, 4000]},
	"bosses": {"name": "Bossbreaker", "how": "Boss kills — lifetime, this character.",
		"tiers": [5, 20, 60, 150]},
	"lore":   {"name": "Chronicler", "how": "Codex lore entries unearthed (slay enough of a kind).",
		"tiers": [3, 8, 15, 25]},
	"clears": {"name": "Pathfinder", "how": "Chapter clears — account-wide, any class.",
		"tiers": [1, 5, 15, 30]},
	"depth":  {"name": "Depthcrawler", "how": "Deepest Waking Depths descent — account-wide, any class.",
		"tiers": [12, 24, 36, 48]},
}

const TRACK_ORDER := ["kills", "bosses", "lore", "clears", "depth"]

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
