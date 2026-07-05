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
	"first_boss": {"name": "First Blood", "desc": "Defeat your first boss."},
	"flawless":   {"name": "Untouchable", "desc": "Defeat a boss without taking a single hit."},
	"s_gear":     {"name": "Legendary Arms", "desc": "Acquire an S-grade item."},
	"level_20":   {"name": "Seasoned", "desc": "Reach level 20."},
	"level_40":   {"name": "Ascendant", "desc": "Reach the level 40 cap."},
	"streak_7":   {"name": "Devoted", "desc": "Reach a 7-day login streak."},
	"clear_ch1":  {"name": "The Hollow King Falls", "desc": "Complete Chapter 1."},
	"clear_ch2":  {"name": "Warden of the Waking", "desc": "Complete Chapter 2."},
	"clear_ch3":  {"name": "Into the Unburied Vale", "desc": "Complete Chapter 3."},
}

## Display order (registry dicts don't guarantee it).
const ORDER := ["first_boss", "flawless", "s_gear", "level_20", "level_40",
	"streak_7", "clear_ch1", "clear_ch2", "clear_ch3"]
