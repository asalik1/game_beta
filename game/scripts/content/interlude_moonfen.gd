extends Node
## Q13 Interlude I2 — THE MOONFEN. A standalone side-chapter reached from the
## capital (game_flow.enter_interlude), unlocked by clearing Act 1 and standing
## with the Wildfang. Its finale, THE FIRST HOWL, reads your resonance BAND on
## spawn (owner ruling 2026-08-24 #2): both bands are winnable, but TEMPTED is a
## faster, harder fight that pays +10% gold (Balance.FIRST_HOWL_*, wired in
## game_world._spawn_boss via the boss def's "band_read": true).
##
## Registered in Story.CONTENT_MODULES; its STANDALONE const merges into
## Story.STANDALONE_WORLDS (chapter()/is_standalone/is_interlude read it), kept
## OUT of CHAPTER_LIST so chapter select / advance_chapter never see it.
##
## v1 reuses the `marsh` terrain and the `fangmaw` beast sprite for the First
## Howl; a bespoke ph_moonfen terrain + First Howl body/splash are an art pass.

const STANDALONE := {
	"interlude_moonfen": {
		"name": "The Moonfen",
		"sub": "The fen where the first wolf still runs — and still remembers.",
		"interlude": true,
		"zones": [
			{"name": "The Fen's Edge", "terrain": "marsh", "type": "combat", "lock_next": "clear",
				"enemies": [["wolf", 500, 400, 0, 41, 0], ["wolf", 640, 320, 0, 41, 0],
					["spider", 1300, 900, 1, 41, 0], ["spider", 1180, 980, 1, 41, 0]],
				"boss": ""},
			{"name": "The Sunken Path", "terrain": "marsh", "type": "combat", "lock_next": "clear",
				"enemies": [["wolf", 480, 360, 0, 41, 0], ["wolf", 600, 460, 0, 41, 0],
					["wolf", 720, 300, 0, 41, 0], ["spider", 1350, 880, 1, 41, 0], ["spider", 1240, 960, 1, 41, 0]],
				"boss": ""},
			{"name": "The First Howl's Wake", "terrain": "marsh", "type": "combat",
				"enemies": [], "boss": "first_howl"},
		],
		"spine": [0, 1, 2],
		"loot_cap": "A",   # an Act-1-tier reward, like ch7's band
		"start_quest": "",
		"final_boss": "first_howl",
		"victory_text": "The First Howl lies still, and for the first time in an age the fen is only water and moonlight. Something very old has stopped listening for you.",
		"start_pos": [500, 500],
	},
}

const ENEMIES := {
	# The First Howl — the first thing that ever hunted, waiting in the fen to see
	# what the shard-bearer became. band_read makes it fight to your resonance.
	# v1 sprite: fangmaw (a giant beast); a bespoke body/splash is the art pass.
	"first_howl": {
		"name": "The First Howl", "sprite": "fangmaw",
		"music": "boss_whitepelt",  # v1: the wolf-chief theme; a bespoke track can follow
		"hp": 205000.0, "dmg": 235.0, "speed": 150.0, "xp": 0, "gold": 1300,
		"ranged": false, "scale": 9.0,
		"physres": 20.0, "magres": 10.0, "eva": 0.05, "critres": 5.0, "crit": 0.05, "dmg_type": "phys",
		"level": 41, "hp_g": 0.15, "dmg_g": 0.14, "boss": true, "band_read": true,
		"attrs": {"STR": 2.0, "AGI": 1.5},
		"mechanics": [
			{"name": "The Long Lunge",
			 "tell": "It coils low, ears flat, and the ground under you dims — then it takes the whole fen in a single leap.",
			 "counter": "The dim patch marks where it LANDS, not where you stand. Break sideways the instant it crouches."}],
	},
}

const BEATS := {
	"pre_first_howl": [
		["Narrator", "The water goes flat. Across the fen, something the size of a barn rises out of the reeds without a sound and looks at you the way weather looks at a field."]],
	"pre_first_howl@steady": [
		["Narrator", "The water goes flat. Something the size of a barn rises out of the reeds without a sound. It was the first thing that ever hunted, and it has been waiting a long age to see what you would become. It seems, almost, to approve."]],
	"pre_first_howl@tempted": [
		["Narrator", "The water goes flat. The thing rising from the reeds has been watching the shard in you the whole way in — and it likes what the greed left behind. It comes faster for the hungry. GOOD, the flat old eyes seem to say. GOOD."]],
	"epilogue_interlude_moonfen": [
		["Narrator", "You leave the fen the way you found it, quiet. The oldest hunt is over, and you were the one still standing."]],
	"epilogue_interlude_moonfen@steady": [
		["Narrator", "You leave the fen the way you found it — quiet, and only water now. The oldest hunt is over and you were the one still standing. Crownfall will not believe you, and you find you do not need it to."]],
	"epilogue_interlude_moonfen@tempted": [
		["Narrator", "You leave the fen heavier than you came, the shard warm and pleased. The oldest hunter is dead, and something in you enjoyed the size of it. Crownfall waits — and so, now, does whatever comes after."]],
}


# ---- CONTENT-MODULE TEST HOOK: called from autotest via _test_interludes() ----
static func selftest_present() -> bool:
	return Story.STANDALONE_WORLDS.has("interlude_moonfen") \
		and Story.ALL_ENEMIES.has("first_howl") \
		and bool(Story.ALL_ENEMIES["first_howl"].get("band_read", false))
