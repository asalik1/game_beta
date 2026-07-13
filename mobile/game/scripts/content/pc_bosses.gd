# Ninja Adventure (CC0) boss-candidate sweep (2026-07-08) — PLACEHOLDERS.
#
# TODO(review): 6 boss-scale sprites extracted from the CC0 Ninja Adventure
# pack, wired as PLACEHOLDER bosses so they can be spawned from the dev panel
# and judged. They are dev-launcher only (the codex used-filter hides unplaced
# bosses outside dev, and "placeholder": true tags them). NONE are placed in a
# zone. They carry NO mechanics — Boss._think's `match kind` has no case for
# them, so they spawn as plain chasing bruisers (safe). A later session gives
# the keepers real stats + mechanics + a story slot, or discards them.
#
# NOTE: Ninja Adventure is a different art style from the Pixel Crawler roster
# — deliberately kept out of the normal game until reviewed. music_fallback
# points each at an existing boss track so the boss-music invariant holds.
#
# No class_name (import-hang trap). Registered via ONE line in
# Story.CONTENT_MODULES; kinds also added to Menus.BOSS_KINDS.

const ENEMIES := {
	"cyclops": {"name": "Cyclopean Horror", "sprite": "cyclops", "hp": 3200.0, "dmg": 60.0, "speed": 135.0, "xp": 130, "gold": 95, "ranged": false, "scale": 6.0,
		"physres": 20.0, "magres": 8.0, "eva": 0.0, "critres": 3.0, "crit": 0.05, "dmg_type": "phys",
		"level": 18, "hp_g": 0.13, "dmg_g": 0.12, "boss": true, "placeholder": true,
		"attrs": {"STR": 2.2}, "mechanics": [], "music_fallback": "boss_vargoth",
		"lore": "One eye, no mercy, and a reach that closes the room. [placeholder — Ninja Adventure art, awaiting a real fight.]"},
	"tengu": {"name": "Crimson Tengu", "sprite": "tengu", "hp": 2600.0, "dmg": 66.0, "speed": 165.0, "xp": 130, "gold": 95, "ranged": false, "scale": 5.5,
		"physres": 10.0, "magres": 16.0, "eva": 0.10, "critres": 2.0, "crit": 0.08, "dmg_type": "phys",
		"level": 20, "hp_g": 0.13, "dmg_g": 0.12, "boss": true, "placeholder": true,
		"attrs": {"AGI": 2.2}, "mechanics": [], "music_fallback": "boss_stormwarden",
		"lore": "A winged judge in a white mask. [placeholder — Ninja Adventure art, awaiting a real fight.]"},
	"flame_giant": {"name": "Cinder Colossus", "sprite": "flame_giant", "hp": 3600.0, "dmg": 62.0, "speed": 115.0, "xp": 140, "gold": 100, "ranged": false, "scale": 6.0,
		"physres": 12.0, "magres": 28.0, "eva": 0.0, "critres": 2.0, "crit": 0.05, "dmg_type": "magic",
		"level": 24, "hp_g": 0.13, "dmg_g": 0.12, "boss": true, "placeholder": true,
		"attrs": {"INT": 2.2}, "mechanics": [], "music_fallback": "boss_cinderhide",
		"lore": "A living pyre that walks. [placeholder — Ninja Adventure art, awaiting a real fight.]"},
	"great_spirit": {"name": "Hollow Revenant", "sprite": "great_spirit", "hp": 2400.0, "dmg": 58.0, "speed": 150.0, "xp": 130, "gold": 95, "ranged": false, "scale": 5.5,
		"physres": 8.0, "magres": 30.0, "eva": 0.12, "critres": 2.0, "crit": 0.05, "dmg_type": "magic",
		"level": 22, "hp_g": 0.13, "dmg_g": 0.12, "boss": true, "placeholder": true,
		"attrs": {"INT": 2.2}, "mechanics": [], "music_fallback": "boss_morwen",
		"lore": "The shape grief leaves when it will not rest. [placeholder — Ninja Adventure art, awaiting a real fight.]"},
	"ooze": {"name": "Devouring Ooze", "sprite": "ooze", "hp": 4200.0, "dmg": 52.0, "speed": 95.0, "xp": 130, "gold": 95, "ranged": false, "scale": 5.5,
		"physres": 24.0, "magres": 24.0, "eva": 0.0, "critres": 4.0, "crit": 0.0, "dmg_type": "phys",
		"level": 16, "hp_g": 0.14, "dmg_g": 0.11, "boss": true, "placeholder": true,
		"attrs": {"STR": 2.0}, "mechanics": [], "music_fallback": "boss_sexton",
		"lore": "Everything it touches becomes more of it. [placeholder — Ninja Adventure art, awaiting a real fight.]"},
	"kraken": {"name": "Deepmaw Kraken", "sprite": "kraken", "hp": 3400.0, "dmg": 64.0, "speed": 130.0, "xp": 140, "gold": 100, "ranged": false, "scale": 6.5,
		"physres": 14.0, "magres": 18.0, "eva": 0.05, "critres": 2.0, "crit": 0.06, "dmg_type": "phys",
		"level": 26, "hp_g": 0.13, "dmg_g": 0.12, "boss": true, "placeholder": true,
		"attrs": {"STR": 1.6, "AGI": 1.6}, "mechanics": [], "music_fallback": "boss_auroch",
		"lore": "It reached up out of a well that had no bottom. [placeholder — Ninja Adventure art, awaiting a real fight.]"},
}
