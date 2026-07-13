# Pixel Crawler asset-extraction pass (2026-07-08) — EXTRA MOB ROSTER.
#
# TODO(review): these 8 mobs were extracted from the owned Pixel Crawler
# packs to widen the bestiary. They are ROSTER + CODEX ONLY — not placed in
# any room yet. A later session should decide where each fits (spawn tables /
# chapters) or discard it, and retune stats (numbers here are first-pass,
# cloned from the nearest existing relative). Sprites installed as overrides
# in assets/sprites/ (pillarboxed, same pipeline as the mob re-cut). Kinds
# are semantically named (sprite != kind), matching the existing convention
# (e.g. "bogspider" uses the rat sprite).
#
# Skipped as redundant per the "difference must count" rule: Pixel Crawler
# Rat-Base (dupe of our rat) and Elf-Hunter (too close to elf_druid/ranger).
#
# No class_name (import-hang trap). Registered via ONE line in
# Story.CONTENT_MODULES.

const ENEMIES := {
	# --- undead (Cemetery / Desert packs) ---
	"bloated_dead": {"name": "Bloated Dead", "sprite": "zombie_overweight", "hp": 95.0, "dmg": 16.0, "speed": 90.0, "xp": 10, "gold": 7, "ranged": false, "scale": 3.3,
		"physres": 14.0, "magres": 0.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 5, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["mend"],
		"lore": "It ate well in life and, in death, refuses to give any of it back. Slow, but it soaks a beating the lean dead never could."},
	"grave_cutter": {"name": "Grave Cutter", "sprite": "mummy_rogue", "hp": 110.0, "dmg": 24.0, "speed": 155.0, "xp": 14, "gold": 10, "ranged": false, "scale": 3.2,
		"physres": 10.0, "magres": 8.0, "eva": 0.10, "critres": 0.0, "dmg_type": "phys",
		"level": 10, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["swift"],
		"lore": "Wrapped tight and cut loose — a tomb-thief embalmed with its own knives still in hand."},
	"tomb_warden": {"name": "Tomb Warden", "sprite": "mummy_warrior", "hp": 210.0, "dmg": 30.0, "speed": 100.0, "xp": 16, "gold": 14, "ranged": false, "scale": 3.5,
		"physres": 22.0, "magres": 12.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 11, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["warded"],
		"lore": "Set to guard a door for one king's rest. The king is dust; the order stands."},
	# --- cave / forest ---
	"sporeling": {"name": "Sporeling", "sprite": "fungus_immature", "hp": 55.0, "dmg": 10.0, "speed": 120.0, "xp": 8, "gold": 4, "ranged": false, "scale": 2.7,
		"physres": 6.0, "magres": 10.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 5, "hp_g": 0.10, "dmg_g": 0.08, "traits": ["swift"],
		"lore": "Barely a cap on legs. Alone it is nothing; the caves are never so kind as to send one alone."},
	"wildkin_elf": {"name": "Wildkin Skirmisher", "sprite": "elf_wild", "hp": 95.0, "dmg": 18.0, "speed": 145.0, "xp": 12, "gold": 9, "ranged": false, "scale": 3.1,
		"physres": 6.0, "magres": 6.0, "eva": 0.08, "critres": 0.0, "dmg_type": "phys",
		"level": 7, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["swift"],
		"lore": "Blue-marked and barefoot, it fights for a grove that has no name a human tongue can hold."},
	# --- sewer rat crew ---
	"plague_chanter": {"name": "Plague Chanter", "sprite": "rat_mage", "hp": 70.0, "dmg": 22.0, "speed": 120.0, "xp": 12, "gold": 10, "ranged": true, "scale": 3.0,
		"physres": 4.0, "magres": 20.0, "eva": 0.0, "critres": 0.0, "dmg_type": "magic",
		"level": 8, "hp_g": 0.10, "dmg_g": 0.10, "traits": ["warded"],
		"lore": "It learned three words of a dead sorcerer's cant. Two of them make sickness; the third, it will not say."},
	"gutter_cutter": {"name": "Gutter Cutter", "sprite": "rat_rogue", "hp": 60.0, "dmg": 16.0, "speed": 210.0, "xp": 10, "gold": 8, "ranged": false, "scale": 3.0,
		"physres": 0.0, "magres": 6.0, "eva": 0.14, "critres": 0.0, "dmg_type": "phys",
		"level": 6, "hp_g": 0.09, "dmg_g": 0.08, "traits": ["swift"],
		"lore": "Fast, low, and gone before the pain lands. It has robbed corpses that were still choosing to be one."},
	"warren_breaker": {"name": "Warren Breaker", "sprite": "rat_warrior", "hp": 130.0, "dmg": 24.0, "speed": 130.0, "xp": 13, "gold": 11, "ranged": false, "scale": 3.2,
		"physres": 14.0, "magres": 6.0, "eva": 0.0, "critres": 0.0, "dmg_type": "phys",
		"level": 8, "hp_g": 0.10, "dmg_g": 0.09, "traits": ["frenzy"],
		"lore": "The biggest thing the warren could grow, strapped into the biggest thing it could steal."},
}
