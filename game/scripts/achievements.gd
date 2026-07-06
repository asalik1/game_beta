class_name Achievements
## The achievement registry — id -> {name, desc}. Unlocks are stored on
## the Game (game.achievements: id -> true), persisted with the save, and
## announced by a HUD toast. Triggers are sprinkled at their natural
## sites (boss death, level-up, chapter clear, daily streak, S-gear).
## Displayed in the codex Records tab alongside boss personal bests.
##
## Single-player today; this same unlock set seeds account-wide progress
## when multiplayer lands.

const DATA := {
	"first_boss":     {"name": "First Blood", "desc": "Defeat your first boss."},
	"flawless":       {"name": "Untouchable", "desc": "Defeat a boss without taking a single hit."},
	"no_potion_boss": {"name": "Iron Discipline", "desc": "Defeat a boss without drinking a potion."},
	"boss_hunter":    {"name": "Vale Reaper", "desc": "Defeat 9 different bosses."},
	"s_gear":         {"name": "Legendary Arms", "desc": "Acquire an S-grade item."},
	"gem_max":        {"name": "Master Jeweler", "desc": "Obtain a max-level gem."},
	"wealthy":        {"name": "Coin Hoarder", "desc": "Amass 5,000 gold."},
	"level_20":       {"name": "Seasoned", "desc": "Reach level 20."},
	"level_40":       {"name": "Ascendant", "desc": "Reach the level 40 cap."},
	"streak_7":       {"name": "Devoted", "desc": "Reach a 7-day login streak."},
	"clear_ch1":      {"name": "The Hollow King Falls", "desc": "Complete Chapter 1."},
	"clear_ch2":      {"name": "Warden of the Waking", "desc": "Complete Chapter 2."},
	"clear_ch3":      {"name": "Into the Unburied Vale", "desc": "Complete Chapter 3."},
}

## Display order (registry dicts don't guarantee it).
const ORDER := ["first_boss", "flawless", "no_potion_boss", "boss_hunter",
	"s_gear", "gem_max", "wealthy", "level_20", "level_40", "streak_7",
	"clear_ch1", "clear_ch2", "clear_ch3"]
