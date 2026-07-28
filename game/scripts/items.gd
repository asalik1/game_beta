class_name Items
## Gear, grades, chests and shop stock.
## An item is a plain Dictionary:
##   {"slot": "weapon", "grade": "B", "name": "...", "main": {"atk_flat": 14.0},
##    "subs": {"crit": 0.04}, "plus": 0}   (plus = upgrade level from the smith)

const GRADES := ["F", "E", "D", "C", "B", "A", "S"]
const GRADE_MULT := {"F": 0.5, "E": 0.75, "D": 1.0, "C": 1.35, "B": 1.8, "A": 2.4, "S": 3.2}
const GRADE_COLOR := {
	"F": Color(0.62, 0.62, 0.62), "E": Color(0.92, 0.92, 0.92),
	"D": Color(0.45, 0.85, 0.45), "C": Color(0.40, 0.65, 1.00),
	"B": Color(0.75, 0.45, 0.95), "A": Color(1.00, 0.60, 0.20),
	"S": Color(1.00, 0.30, 0.30),
}

# Per-grade pickup chime (loot fanfare — the rarity is audible before
# it's readable). Keys are Sfx bank entries.
const LOOT_SOUND := {
	"F": "loot_low", "E": "loot_low", "D": "loot_mid", "C": "loot_mid",
	"B": "loot_b", "A": "loot_a", "S": "loot_s",
}

static func loot_sound(grade: String) -> String:
	return String(LOOT_SOUND.get(grade, "loot_low"))

const SLOTS := ["weapon", "helmet", "armor", "gloves", "pants", "boots", "charm"]
const SLOT_ICON := {"weapon": "⚔", "helmet": "🪖", "armor": "🛡", "gloves": "🧤", "pants": "👖", "boots": "👢", "charm": "❖"}

# Every piece's MAIN is the wearer-class's PRIMARY attribute (player
# rule, 2026-07-06, WoW-style): guaranteed, class-matched, slot-budgeted
# points that convert through Classes.ATTR_SCALE exactly like allocated
# talent points — a dagger literally cannot carry INT. (Old slot mains —
# weapon ATK / armor HP / boots Speed / charm Haste — are retired; legacy
# ATK/HP mains on old saves still count, banned ones are stripped on load.)
# Budgets sized (2026-07-06) so the L42 full-B benchmark loadout lands
# within ~1-2% of the pre-attribute-mains power envelope: attributes
# convert SUB-1 to ATK (0.9 — player rule: 100 STR = 90 ATK + 120 HP),
# and the total slot budget stays small enough that gear attributes
# never outrun the ~5.5%/level player curve every boss is pinned to.
# 7-slot lineup (2026-07-26, GEAR_SHAPE_MATRIX.md §5b): helmet/gloves/pants added.
# The existing four keep their values; the three new slot into the hierarchy
# (helmet/pants solid armor, gloves minor). Total 12.5 -> 19.5 (+56%) — the L42
# benchmark envelope shifts up, so mobs/bosses recalibrate for it (owner step 4).
# STEP 4 DONE (2026-07-27, dps-bench round): at-level re-measured ON budget
# (L42/A finale 41.9s vs ~40s), so the recalibration landed as the endgame
# GEAR ramp (Balance.GEAR_RAMP_*) instead of an in-band retune.
const SLOT_MAIN_BUDGET := {"weapon": 5.0, "helmet": 2.5, "armor": 3.0, "gloves": 2.0, "pants": 2.5, "boots": 2.0, "charm": 2.5}
# Mirror of Classes.CLASSES[cls]["primary"] — items.gd must not preload
# classes.gd (same rule as CLASSES_DMG_TYPE below).
const CLASS_PRIMARY := {
	"warrior": "STR", "paladin": "STR",
	"archer": "AGI", "assassin": "AGI",
	"mage": "INT", "warlock": "INT",
}

# Weapon shapes a class can actually be DEALT (round 15: an archer was
# looting Tomes). Since 2026-07-06 gear is also class-LOCKED at equip
# (item["cls"]) — a mage cannot wear an assassin's boots.
# Each class's five matrix weapon shapes (2026-07-26). The pre-matrix nouns
# (Blade/Bow/Staff/Fang/Hammer/Tome/…) are RETIRED from rolling — kept only in
# SHAPE_STYLE for old saves and S_GEAR legendary nouns.
const CLASS_WEAPONS := {
	"warrior":  ["Pike", "Warblade", "Saber", "Bulwark Blade", "Claymore"],
	"archer":   ["Warbow", "Longbow", "Hunting Bow", "Thornbow", "Recurve"],
	"assassin": ["Stiletto", "Shuriken", "Glasswing", "Warded Fang", "Cleaver"],
	"mage":     ["Scepter", "Starfocus", "Zephyr Rod", "Bloomstaff", "Greatstaff"],
	"paladin":  ["Lance", "Oathflail", "Duelist's Blade", "Aegis Mace", "Warmaul"],
	"warlock":  ["Grimoire", "Hexblade", "Whisper Rod", "Pactshield Codex", "Grimheart Staff"],
}

# Per-class shapes for the NEW matrix slots (helmet/gloves/pants, §5b). roll_item_of
# picks from here when a class is set — the armor-family analogue of CLASS_WEAPONS.
# (armor/boots/charm are not here yet; they still roll the shared SLOT_NAMES shapes
# until their own matrix pass.)
const CLASS_GEAR := {
	"warrior": {"helmet": ["Wardsteel Helm", "Ironwall Helm", "Skirmisher's Helm", "Reaver Helm", "Titan Helm"], "gloves": ["Wardsteel Gauntlets", "Ironwall Gauntlets", "Skirmisher's Gauntlets", "Reaver Gauntlets", "Titan Gauntlets"], "pants": ["Wardsteel Legplates", "Ironwall Legplates", "Skirmisher's Legplates", "Reaver Legplates", "Titan Legplates"], "armor": ["Wardsteel Plate", "Ironwall Plate", "Skirmisher's Halfplate", "Bloodforged Harness", "Titanplate"], "boots": ["Wardstep Greaves", "Sabatons", "Skirmisher's Boots", "Reaver Treads", "Anchorplate"], "charm": ["Warbanner", "Oath Sigil", "Butcher's Token", "Duelist's Knot", "Heart of the Wall"]},
	"archer": {"helmet": ["Stormweave Hood", "Studded Hood", "Ranger's Hood", "Hunter's Hood", "Beastpelt Hood"], "gloves": ["Stormweave Bracers", "Studded Bracers", "Ranger's Bracers", "Hunter's Bracers", "Beastpelt Bracers"], "pants": ["Stormweave Leggings", "Studded Leggings", "Ranger's Leggings", "Hunter's Leggings", "Beastpelt Leggings"], "armor": ["Stormweave Jerkin", "Studded Brigandine", "Ranger's Leathers", "Hunter's Harness", "Beastpelt"], "boots": ["Piercer's Cleats", "Windstriders", "Marksman's Stance", "Wardedsole", "Trailboots"], "charm": ["Fletcher's Token", "Windfeather", "Hunter's Totem", "Stonebark Ward", "Greenheart Idol"]},
	"assassin": {"helmet": ["Shadowveil Cowl", "Warded Cowl", "Gossamer Cowl", "Nightsilk Cowl", "Grave Cowl"], "gloves": ["Shadowveil Grips", "Warded Grips", "Gossamer Grips", "Nightsilk Grips", "Grave Grips"], "pants": ["Shadowveil Wraps", "Warded Wraps", "Gossamer Wraps", "Nightsilk Wraps", "Grave Wraps"], "armor": ["Shadowveil Cloak", "Warded Mantle", "Gossamer Cloak", "Nightsilk Wrap", "Verdant Shroud"], "boots": ["Slipsteps", "Prowlers", "Venomtread", "Ironsole Wraps", "Grave Treads"], "charm": ["Killer's Mark", "Poisoner's Vial", "Ghostlight Charm", "Bloodoath Cord", "Wraithbone Fetish"]},
	"mage": {"helmet": ["Silkward Circlet", "Runeplate Circlet", "Featherweave Circlet", "Starweave Circlet", "Earthen Circlet"], "gloves": ["Silkward Handwraps", "Runeplate Handwraps", "Featherweave Handwraps", "Starweave Handwraps", "Earthen Handwraps"], "pants": ["Silkward Underleggings", "Runeplate Underleggings", "Featherweave Underleggings", "Starweave Underleggings", "Earthen Underleggings"], "armor": ["Silk Vestments", "Runeplate Robe", "Featherweave Robe", "Starweave Robe", "Earthen Robe"], "boots": ["Starstep", "Levitation Slippers", "Sigil Sandals", "Wardstone Shoes", "Rootbound Sandals"], "charm": ["Arcane Orb", "Starshard", "Aegis Crystal", "Zephyr Sigil", "Lifebloom Pendant"]},
	"paladin": {"helmet": ["Blessed Greathelm", "Templar Greathelm", "Vigil Greathelm", "Zealot Greathelm", "Sanctified Greathelm"], "gloves": ["Blessed Gauntlets", "Templar Gauntlets", "Vigil Gauntlets", "Zealot Gauntlets", "Sanctified Gauntlets"], "pants": ["Blessed Legguards", "Templar Legguards", "Vigil Legguards", "Zealot Legguards", "Sanctified Legguards"], "armor": ["Templar Plate", "Blessed Plate", "Vigil Halfplate", "Zealot Harness", "Sanctified Bulwark"], "boots": ["Zealot's Cleats", "Sabatons of the Oath", "Vigil Steps", "Radiant Greaves", "Pilgrim's Resolve"], "charm": ["Reliquary", "Sunburst Icon", "Judgment Sigil", "Swiftvow Cord", "Oathkeeper's Seal"]},
	"warlock": {"helmet": ["Voidsilk Hood", "Bonemail Hood", "Shadeweave Hood", "Ruinweave Hood", "Bloodpact Hood"], "gloves": ["Voidsilk Claws", "Bonemail Claws", "Shadeweave Claws", "Ruinweave Claws", "Bloodpact Claws"], "pants": ["Voidsilk Chausses", "Bonemail Chausses", "Shadeweave Chausses", "Ruinweave Chausses", "Bloodpact Chausses"], "armor": ["Voidsilk Robe", "Bonemail", "Shadeweave Robe", "Ruinweave", "Bloodpact Vestment"], "boots": ["Ruinstep", "Shadowstep Wraps", "Hexcarved Treads", "Bonewalkers", "Gravebound Boots"], "charm": ["Soul Fetish", "Cursed Idol", "Ward of Ash", "Umbral Cord", "Heartcage"]},
}

# SLOT_NAMES[slot] = the union of every class's rollable shapes (the classless
# fallback pool). Weapon + the three new slots are per-class (CLASS_WEAPONS /
# CLASS_GEAR); armor/boots/charm are the shared shapes still awaiting their matrix.
const SLOT_NAMES := {
	"weapon": ["Pike", "Warblade", "Saber", "Bulwark Blade", "Claymore",
		"Warbow", "Longbow", "Hunting Bow", "Thornbow", "Recurve",
		"Stiletto", "Shuriken", "Glasswing", "Warded Fang", "Cleaver",
		"Scepter", "Starfocus", "Zephyr Rod", "Bloomstaff", "Greatstaff",
		"Lance", "Oathflail", "Duelist's Blade", "Aegis Mace", "Warmaul",
		"Grimoire", "Hexblade", "Whisper Rod", "Pactshield Codex", "Grimheart Staff"],
	"helmet": ["Wardsteel Helm", "Ironwall Helm", "Skirmisher's Helm", "Reaver Helm", "Titan Helm", "Stormweave Hood", "Studded Hood", "Ranger's Hood", "Hunter's Hood", "Beastpelt Hood", "Shadowveil Cowl", "Warded Cowl", "Gossamer Cowl", "Nightsilk Cowl", "Grave Cowl", "Silkward Circlet", "Runeplate Circlet", "Featherweave Circlet", "Starweave Circlet", "Earthen Circlet", "Blessed Greathelm", "Templar Greathelm", "Vigil Greathelm", "Zealot Greathelm", "Sanctified Greathelm", "Voidsilk Hood", "Bonemail Hood", "Shadeweave Hood", "Ruinweave Hood", "Bloodpact Hood"],
	"armor":  ["Wardsteel Plate", "Ironwall Plate", "Skirmisher's Halfplate", "Bloodforged Harness", "Titanplate", "Stormweave Jerkin", "Studded Brigandine", "Ranger's Leathers", "Hunter's Harness", "Beastpelt", "Shadowveil Cloak", "Warded Mantle", "Gossamer Cloak", "Nightsilk Wrap", "Verdant Shroud", "Silk Vestments", "Runeplate Robe", "Featherweave Robe", "Starweave Robe", "Earthen Robe", "Templar Plate", "Blessed Plate", "Vigil Halfplate", "Zealot Harness", "Sanctified Bulwark", "Voidsilk Robe", "Bonemail", "Shadeweave Robe", "Ruinweave", "Bloodpact Vestment"],
	"gloves": ["Wardsteel Gauntlets", "Ironwall Gauntlets", "Skirmisher's Gauntlets", "Reaver Gauntlets", "Titan Gauntlets", "Stormweave Bracers", "Studded Bracers", "Ranger's Bracers", "Hunter's Bracers", "Beastpelt Bracers", "Shadowveil Grips", "Warded Grips", "Gossamer Grips", "Nightsilk Grips", "Grave Grips", "Silkward Handwraps", "Runeplate Handwraps", "Featherweave Handwraps", "Starweave Handwraps", "Earthen Handwraps", "Blessed Gauntlets", "Templar Gauntlets", "Vigil Gauntlets", "Zealot Gauntlets", "Sanctified Gauntlets", "Voidsilk Claws", "Bonemail Claws", "Shadeweave Claws", "Ruinweave Claws", "Bloodpact Claws"],
	"pants":  ["Wardsteel Legplates", "Ironwall Legplates", "Skirmisher's Legplates", "Reaver Legplates", "Titan Legplates", "Stormweave Leggings", "Studded Leggings", "Ranger's Leggings", "Hunter's Leggings", "Beastpelt Leggings", "Shadowveil Wraps", "Warded Wraps", "Gossamer Wraps", "Nightsilk Wraps", "Grave Wraps", "Silkward Underleggings", "Runeplate Underleggings", "Featherweave Underleggings", "Starweave Underleggings", "Earthen Underleggings", "Blessed Legguards", "Templar Legguards", "Vigil Legguards", "Zealot Legguards", "Sanctified Legguards", "Voidsilk Chausses", "Bonemail Chausses", "Shadeweave Chausses", "Ruinweave Chausses", "Bloodpact Chausses"],
	"boots":  ["Wardstep Greaves", "Sabatons", "Skirmisher's Boots", "Reaver Treads", "Anchorplate", "Piercer's Cleats", "Windstriders", "Marksman's Stance", "Wardedsole", "Trailboots", "Slipsteps", "Prowlers", "Venomtread", "Ironsole Wraps", "Grave Treads", "Starstep", "Levitation Slippers", "Sigil Sandals", "Wardstone Shoes", "Rootbound Sandals", "Zealot's Cleats", "Sabatons of the Oath", "Vigil Steps", "Radiant Greaves", "Pilgrim's Resolve", "Ruinstep", "Shadowstep Wraps", "Hexcarved Treads", "Bonewalkers", "Gravebound Boots"],
	"charm":  ["Warbanner", "Oath Sigil", "Butcher's Token", "Duelist's Knot", "Heart of the Wall", "Fletcher's Token", "Windfeather", "Hunter's Totem", "Stonebark Ward", "Greenheart Idol", "Killer's Mark", "Poisoner's Vial", "Ghostlight Charm", "Bloodoath Cord", "Wraithbone Fetish", "Arcane Orb", "Starshard", "Aegis Crystal", "Zephyr Sigil", "Lifebloom Pendant", "Reliquary", "Sunburst Icon", "Judgment Sigil", "Swiftvow Cord", "Oathkeeper's Seal", "Soul Fetish", "Cursed Idol", "Ward of Ash", "Umbral Cord", "Heartcage"],
}

# One representative prefix per grade (used in the codex).
const GRADE_PREFIX := {
	"F": "Rusty", "E": "Worn", "D": "Tempered", "C": "Fine",
	"B": "Runed", "A": "Dragonforged", "S": "Emberforged",
}

# Rolled items pick a random prefix from their grade's pool,
# so drops read like "Fine Shuriken" or "Masterwork Claymore". Prefixes are
# CLASS-NEUTRAL quality adjectives (2026-07-08): the old martial words
# (Knight's/Soldier's/Militia/Veteran's/Warlord's) read wrong on an
# assassin's dagger or a mage's wand ("Knight's Fang"). Keep any new prefix
# fitting for every class's gear.
const PREFIXES := {
	"F": ["Rusty", "Cracked", "Chipped", "Bent"],
	"E": ["Worn", "Plain", "Sturdy", "Simple"],
	"D": ["Tempered", "Honed", "Polished", "Keen"],
	"C": ["Fine", "Gilded", "Wrought", "Refined"],
	"B": ["Runed", "Masterwork", "Enchanted", "Pristine"],
	"A": ["Dragonforged"],
	"S": ["Emberforged"],
}

# A-grade items get a unique epic name instead of "prefix + noun".
# A_NAMES retired 2026-07-26 (owner: only NAMED gear carries a passive/identity;
# a generic A is just "Dragonforged <shape>"). The old table auto-renamed EVERY A
# drop to a hollow epic — a pseudo-unique with no passive and no art — which is
# exactly what named uniques (below) now are for real. Generic A rolls its grade
# prefix + shape like every other grade.

# S-grade gear is CLASS-EXCLUSIVE: a unique name, and S weapons carry a signature
# passive ability (implemented in player.gd). Substats roll RANDOMLY like every
# other grade — NO pinned synergy subs (2026-07-13): a legendary is chased for its
# passive + top rolls, not handed a guaranteed stat line.
# NAMED UNIQUES (2026-07-26) — generic-grade power PLUS a signature passive, and
# rarer than generic (owner rule; PROPOSALS/GEAR_SHAPE_MATRIX.md §7). The PASSIVE
# is the whole difference: a named S and a generic S share a stat ceiling, but the
# unique carries a passive and drops less often. A unique is its own object — a
# fixed shape, an authored name, and its own 32px sprite that outranks the
# per-grade and family art (`art` -> assets/icons/<art>.png, via Art.icon_for /
# Art.weapon_tex). Two per shape: one A, one S.
#
# THE 60 NAMED WEAPON UNIQUES — rows from PROPOSALS/GEAR_UNIQUE_ART_MANIFEST.md,
# passives assigned 2026-07-27 per PROPOSALS/GEAR_UNIQUE_PASSIVES.md (design
# approved by owner; magnitudes in Balance.UNIQ are FIRST-PASS placeholders for
# the dps-bench phase). Still deliberately absent:
#   * `bias` — a unique may exceed the shape budget (cap Sum(bias-1) <= 1.20);
#     for now every unique rides its shape's stock bias (the passive is the chase).
# Drop source: make_unique / roll_item_of's named channels (named A Act 2+,
# named S Act 3+ — Balance.UNIQUE_*). Armor/boots/charm uniques await their
# shape matrix.
const UNIQUES := [
	# --- Warrior weapons ---
	{"name": "The Red Pennon", "cls": "warrior", "slot": "weapon", "noun": "Pike", "grade": "A", "art": "u_the_red_pennon", "passive": "pennon"},
	{"name": "Crownspike, the Last Decree", "cls": "warrior", "slot": "weapon", "noun": "Pike", "grade": "S", "art": "u_crownspike_the_last_decree", "passive": "decree"},
	{"name": "Marchbreaker", "cls": "warrior", "slot": "weapon", "noun": "Warblade", "grade": "A", "art": "u_marchbreaker", "passive": "warpath"},
	{"name": "Throneless, Edge of the Last Host", "cls": "warrior", "slot": "weapon", "noun": "Warblade", "grade": "S", "art": "u_throneless_edge_of_the_last_host", "passive": "lasthost"},
	{"name": "Ashrider", "cls": "warrior", "slot": "weapon", "noun": "Saber", "grade": "A", "art": "u_ashrider", "passive": "outrider"},
	{"name": "Red Horizon", "cls": "warrior", "slot": "weapon", "noun": "Saber", "grade": "S", "art": "u_red_horizon", "passive": "horizon"},
	{"name": "Bastion's Tooth", "cls": "warrior", "slot": "weapon", "noun": "Bulwark Blade", "grade": "A", "art": "u_bastions_tooth", "passive": "reprisal"},
	{"name": "The Gate That Walks", "cls": "warrior", "slot": "weapon", "noun": "Bulwark Blade", "grade": "S", "art": "u_the_gate_that_walks", "passive": "thegate"},
	{"name": "Gravesong", "cls": "warrior", "slot": "weapon", "noun": "Claymore", "grade": "A", "art": "u_gravesong", "passive": "dirge"},
	{"name": "Crownfall, the Kingdom's End", "cls": "warrior", "slot": "weapon", "noun": "Claymore", "grade": "S", "art": "u_crownfall_the_kingdoms_end", "passive": "kingsblade"},
	# --- Archer weapons ---
	{"name": "Siegebough", "cls": "archer", "slot": "weapon", "noun": "Warbow", "grade": "A", "art": "u_siegebough", "passive": "siegebolt"},
	{"name": "Tempest Yew, Bow of the Last Gale", "cls": "archer", "slot": "weapon", "noun": "Warbow", "grade": "S", "art": "u_tempest_yew_bow_of_the_last_gale", "passive": "windward"},
	{"name": "Far-Witness", "cls": "archer", "slot": "weapon", "noun": "Longbow", "grade": "A", "art": "u_far_witness", "passive": "farsight"},
	{"name": "Skyline, the Arrow Before Dawn", "cls": "archer", "slot": "weapon", "noun": "Longbow", "grade": "S", "art": "u_skyline_the_arrow_before_dawn", "passive": "herald"},
	{"name": "Foxfire String", "cls": "archer", "slot": "weapon", "noun": "Hunting Bow", "grade": "A", "art": "u_foxfire_string", "passive": "foxfire"},
	{"name": "The White Hart's Last Breath", "cls": "archer", "slot": "weapon", "noun": "Hunting Bow", "grade": "S", "art": "u_the_white_harts_last_breath", "passive": "hartsbreath"},
	{"name": "Briar Covenant", "cls": "archer", "slot": "weapon", "noun": "Thornbow", "grade": "A", "art": "u_briar_covenant", "passive": "briar"},
	{"name": "Green Ruin, Root of the First Wild", "cls": "archer", "slot": "weapon", "noun": "Thornbow", "grade": "S", "art": "u_green_ruin_root_of_the_first_wild", "passive": "bramble"},
	{"name": "Hornsong", "cls": "archer", "slot": "weapon", "noun": "Recurve", "grade": "A", "art": "u_hornsong", "passive": "warhorn"},
	{"name": "Moonturn, Bow of Returning Night", "cls": "archer", "slot": "weapon", "noun": "Recurve", "grade": "S", "art": "u_moonturn_bow_of_returning_night", "passive": "moonturn"},
	# --- Assassin weapons ---
	{"name": "Silkneedle", "cls": "assassin", "slot": "weapon", "noun": "Stiletto", "grade": "A", "art": "u_silkneedle", "passive": "gapfinder"},
	{"name": "Quietus, the King's Final Thought", "cls": "assassin", "slot": "weapon", "noun": "Stiletto", "grade": "S", "art": "u_quietus_the_kings_final_thought", "passive": "quietus"},
	{"name": "Widow's Compass", "cls": "assassin", "slot": "weapon", "noun": "Shuriken", "grade": "A", "art": "u_widows_compass", "passive": "compass"},
	{"name": "End of Night", "cls": "assassin", "slot": "weapon", "noun": "Shuriken", "grade": "S", "art": "u_end_of_night", "passive": "midnight"},
	{"name": "Mothknife", "cls": "assassin", "slot": "weapon", "noun": "Glasswing", "grade": "A", "art": "u_mothknife", "passive": "mothdust"},
	{"name": "Pale Flight, Blade Between Heartbeats", "cls": "assassin", "slot": "weapon", "noun": "Glasswing", "grade": "S", "art": "u_pale_flight_blade_between_heartbeats", "passive": "mirrorstep"},
	{"name": "Parryshade", "cls": "assassin", "slot": "weapon", "noun": "Warded Fang", "grade": "A", "art": "u_parryshade", "passive": "parry"},
	{"name": "The Hand That Refused Death", "cls": "assassin", "slot": "weapon", "noun": "Warded Fang", "grade": "S", "art": "u_the_hand_that_refused_death", "passive": "refusal"},
	{"name": "Red Arithmetic", "cls": "assassin", "slot": "weapon", "noun": "Cleaver", "grade": "A", "art": "u_red_arithmetic", "passive": "arithmetic"},
	{"name": "Headsman's Mercy", "cls": "assassin", "slot": "weapon", "noun": "Cleaver", "grade": "S", "art": "u_headsmans_mercy", "passive": "headsman"},
	# --- Mage weapons ---
	{"name": "Wardpiercer", "cls": "mage", "slot": "weapon", "noun": "Scepter", "grade": "A", "art": "u_wardpiercer", "passive": "wardcrack"},
	{"name": "Axiom, Scepter of the Broken Law", "cls": "mage", "slot": "weapon", "noun": "Scepter", "grade": "S", "art": "u_axiom_scepter_of_the_broken_law", "passive": "axiom"},
	{"name": "Comet's Eye", "cls": "mage", "slot": "weapon", "noun": "Starfocus", "grade": "A", "art": "u_comets_eye", "passive": "cometfall"},
	{"name": "The Ninth Star, Unblinking", "cls": "mage", "slot": "weapon", "noun": "Starfocus", "grade": "S", "art": "u_the_ninth_star_unblinking", "passive": "ninthstar"},
	{"name": "Quickweather", "cls": "mage", "slot": "weapon", "noun": "Zephyr Rod", "grade": "A", "art": "u_quickweather", "passive": "squall"},
	{"name": "Breathless, Rod of the Empty Sky", "cls": "mage", "slot": "weapon", "noun": "Zephyr Rod", "grade": "S", "art": "u_breathless_rod_of_the_empty_sky", "passive": "breathless"},
	{"name": "Springwake", "cls": "mage", "slot": "weapon", "noun": "Bloomstaff", "grade": "A", "art": "u_springwake", "passive": "springwake"},
	{"name": "Verdancy, Staff of the Worldroot", "cls": "mage", "slot": "weapon", "noun": "Bloomstaff", "grade": "S", "art": "u_verdancy_staff_of_the_worldroot", "passive": "worldroot"},
	{"name": "Atlas Branch", "cls": "mage", "slot": "weapon", "noun": "Greatstaff", "grade": "A", "art": "u_atlas_branch", "passive": "atlas"},
	{"name": "Firmament, the Heaven-Bearing Staff", "cls": "mage", "slot": "weapon", "noun": "Greatstaff", "grade": "S", "art": "u_firmament_the_heaven_bearing_staff", "passive": "wellspring"},
	# --- Paladin weapons ---
	{"name": "Vowspike", "cls": "paladin", "slot": "weapon", "noun": "Lance", "grade": "A", "art": "u_vowspike", "passive": "vow"},
	{"name": "Noonday, Lance of the Unshadowed", "cls": "paladin", "slot": "weapon", "noun": "Lance", "grade": "S", "art": "u_noonday_lance_of_the_unshadowed", "passive": "noonday"},
	{"name": "Bell of Censure", "cls": "paladin", "slot": "weapon", "noun": "Oathflail", "grade": "A", "art": "u_bell_of_censure", "passive": "censure"},
	{"name": "Absolution, the Last Toll", "cls": "paladin", "slot": "weapon", "noun": "Oathflail", "grade": "S", "art": "u_absolution_the_last_toll", "passive": "absolution"},
	{"name": "Mercy in Measure", "cls": "paladin", "slot": "weapon", "noun": "Duelist's Blade", "grade": "A", "art": "u_mercy_in_measure", "passive": "measure"},
	{"name": "First Light, Edge of the Vigil", "cls": "paladin", "slot": "weapon", "noun": "Duelist's Blade", "grade": "S", "art": "u_first_light_edge_of_the_vigil", "passive": "vigil"},
	{"name": "Chapel Knell", "cls": "paladin", "slot": "weapon", "noun": "Aegis Mace", "grade": "A", "art": "u_chapel_knell", "passive": "knell"},
	{"name": "The Bastion's Answer", "cls": "paladin", "slot": "weapon", "noun": "Aegis Mace", "grade": "S", "art": "u_the_bastions_answer", "passive": "answer"},
	{"name": "Pilgrim's Burden", "cls": "paladin", "slot": "weapon", "noun": "Warmaul", "grade": "A", "art": "u_pilgrims_burden", "passive": "burden"},
	{"name": "Dawnfall, Hammer of the Final Oath", "cls": "paladin", "slot": "weapon", "noun": "Warmaul", "grade": "S", "art": "u_dawnfall_hammer_of_the_final_oath", "passive": "dawnbreaker"},
	# --- Warlock weapons ---
	{"name": "Ink of Teeth", "cls": "warlock", "slot": "weapon", "noun": "Grimoire", "grade": "A", "art": "u_ink_of_teeth", "passive": "inkteeth"},
	{"name": "The Book That Remembers You", "cls": "warlock", "slot": "weapon", "noun": "Grimoire", "grade": "S", "art": "u_the_book_that_remembers_you", "passive": "voidmaw"},
	{"name": "Debtcollector", "cls": "warlock", "slot": "weapon", "noun": "Hexblade", "grade": "A", "art": "u_debtcollector", "passive": "collection"},
	{"name": "Black Clause, Edge of the Final Bargain", "cls": "warlock", "slot": "weapon", "noun": "Hexblade", "grade": "S", "art": "u_black_clause_edge_of_the_final_bargain", "passive": "clause"},
	{"name": "Hushbone", "cls": "warlock", "slot": "weapon", "noun": "Whisper Rod", "grade": "A", "art": "u_hushbone", "passive": "hush"},
	{"name": "The Name Beneath All Names", "cls": "warlock", "slot": "weapon", "noun": "Whisper Rod", "grade": "S", "art": "u_the_name_beneath_all_names", "passive": "truename"},
	{"name": "Bound Witness", "cls": "warlock", "slot": "weapon", "noun": "Pactshield Codex", "grade": "A", "art": "u_bound_witness", "passive": "witness"},
	{"name": "The Cover Between Worlds", "cls": "warlock", "slot": "weapon", "noun": "Pactshield Codex", "grade": "S", "art": "u_the_cover_between_worlds", "passive": "thecover"},
	{"name": "Veinroot", "cls": "warlock", "slot": "weapon", "noun": "Grimheart Staff", "grade": "A", "art": "u_veinroot", "passive": "veinroot"},
	{"name": "Red Reliquary, Staff of the Last Pulse", "cls": "warlock", "slot": "weapon", "noun": "Grimheart Staff", "grade": "S", "art": "u_red_reliquary_staff_of_the_last_pulse", "passive": "lastpulse"},
	# ===== ARMOR-FAMILY + ARMOR/BOOTS/CHARM UNIQUES (2026-07-27) =====
	# 360 rows from GEAR_UNIQUE_ART_MANIFEST.md; passives are the bespoke
	# catalog of GEAR_ARMOR_UNIQUE_PASSIVES.md §4 (verb + class beat), ids
	# structural <cls>_<slot>_<profile><lane>, knobs in Balance.UNIQ.
	{"name": "Spellscar Helm", "cls": "warrior", "slot": "helmet", "noun": "Wardsteel Helm", "grade": "A", "art": "u_spellscar_helm", "passive": "warrior_helmet_Aa"},
	{"name": "Nullward, Helm of the Crownless Host", "cls": "warrior", "slot": "helmet", "noun": "Wardsteel Helm", "grade": "S", "art": "u_nullward_helm_of_the_crownless_host", "passive": "warrior_helmet_As"},
	{"name": "Gatebrow Helm", "cls": "warrior", "slot": "helmet", "noun": "Ironwall Helm", "grade": "A", "art": "u_gatebrow_helm", "passive": "warrior_helmet_Ba"},
	{"name": "Unbroken, Helm of the Crownless Host", "cls": "warrior", "slot": "helmet", "noun": "Ironwall Helm", "grade": "S", "art": "u_unbroken_helm_of_the_crownless_host", "passive": "warrior_helmet_Bs"},
	{"name": "Windcut Helm", "cls": "warrior", "slot": "helmet", "noun": "Skirmisher's Helm", "grade": "A", "art": "u_windcut_helm", "passive": "warrior_helmet_Ca"},
	{"name": "No Horizon, Helm of the Crownless Host", "cls": "warrior", "slot": "helmet", "noun": "Skirmisher's Helm", "grade": "S", "art": "u_no_horizon_helm_of_the_crownless_host", "passive": "warrior_helmet_Cs"},
	{"name": "Red Antler Helm", "cls": "warrior", "slot": "helmet", "noun": "Reaver Helm", "grade": "A", "art": "u_red_antler_helm", "passive": "warrior_helmet_Da"},
	{"name": "Warhowl, Helm of the Crownless Host", "cls": "warrior", "slot": "helmet", "noun": "Reaver Helm", "grade": "S", "art": "u_warhowl_helm_of_the_crownless_host", "passive": "warrior_helmet_Ds"},
	{"name": "Mountainheart Helm", "cls": "warrior", "slot": "helmet", "noun": "Titan Helm", "grade": "A", "art": "u_mountainheart_helm", "passive": "warrior_helmet_Ea"},
	{"name": "Stonefather, Helm of the Crownless Host", "cls": "warrior", "slot": "helmet", "noun": "Titan Helm", "grade": "S", "art": "u_stonefather_helm_of_the_crownless_host", "passive": "warrior_helmet_Es"},
	{"name": "Spellscar Gauntlets", "cls": "warrior", "slot": "gloves", "noun": "Wardsteel Gauntlets", "grade": "A", "art": "u_spellscar_gauntlets", "passive": "warrior_gloves_Aa"},
	{"name": "Nullward, Hands of the Crownless Host", "cls": "warrior", "slot": "gloves", "noun": "Wardsteel Gauntlets", "grade": "S", "art": "u_nullward_hands_of_the_crownless_host", "passive": "warrior_gloves_As"},
	{"name": "Gatebrow Gauntlets", "cls": "warrior", "slot": "gloves", "noun": "Ironwall Gauntlets", "grade": "A", "art": "u_gatebrow_gauntlets", "passive": "warrior_gloves_Ba"},
	{"name": "Unbroken, Hands of the Crownless Host", "cls": "warrior", "slot": "gloves", "noun": "Ironwall Gauntlets", "grade": "S", "art": "u_unbroken_hands_of_the_crownless_host", "passive": "warrior_gloves_Bs"},
	{"name": "Windcut Gauntlets", "cls": "warrior", "slot": "gloves", "noun": "Skirmisher's Gauntlets", "grade": "A", "art": "u_windcut_gauntlets", "passive": "warrior_gloves_Ca"},
	{"name": "No Horizon, Hands of the Crownless Host", "cls": "warrior", "slot": "gloves", "noun": "Skirmisher's Gauntlets", "grade": "S", "art": "u_no_horizon_hands_of_the_crownless_host", "passive": "warrior_gloves_Cs"},
	{"name": "Red Antler Gauntlets", "cls": "warrior", "slot": "gloves", "noun": "Reaver Gauntlets", "grade": "A", "art": "u_red_antler_gauntlets", "passive": "warrior_gloves_Da"},
	{"name": "Warhowl, Hands of the Crownless Host", "cls": "warrior", "slot": "gloves", "noun": "Reaver Gauntlets", "grade": "S", "art": "u_warhowl_hands_of_the_crownless_host", "passive": "warrior_gloves_Ds"},
	{"name": "Mountainheart Gauntlets", "cls": "warrior", "slot": "gloves", "noun": "Titan Gauntlets", "grade": "A", "art": "u_mountainheart_gauntlets", "passive": "warrior_gloves_Ea"},
	{"name": "Stonefather, Hands of the Crownless Host", "cls": "warrior", "slot": "gloves", "noun": "Titan Gauntlets", "grade": "S", "art": "u_stonefather_hands_of_the_crownless_host", "passive": "warrior_gloves_Es"},
	{"name": "Spellscar Legplates", "cls": "warrior", "slot": "pants", "noun": "Wardsteel Legplates", "grade": "A", "art": "u_spellscar_legplates", "passive": "warrior_pants_Aa"},
	{"name": "Nullward, Legplates of the Crownless Host", "cls": "warrior", "slot": "pants", "noun": "Wardsteel Legplates", "grade": "S", "art": "u_nullward_legplates_of_the_crownless_host", "passive": "warrior_pants_As"},
	{"name": "Gatebrow Legplates", "cls": "warrior", "slot": "pants", "noun": "Ironwall Legplates", "grade": "A", "art": "u_gatebrow_legplates", "passive": "warrior_pants_Ba"},
	{"name": "Unbroken, Legplates of the Crownless Host", "cls": "warrior", "slot": "pants", "noun": "Ironwall Legplates", "grade": "S", "art": "u_unbroken_legplates_of_the_crownless_host", "passive": "warrior_pants_Bs"},
	{"name": "Windcut Legplates", "cls": "warrior", "slot": "pants", "noun": "Skirmisher's Legplates", "grade": "A", "art": "u_windcut_legplates", "passive": "warrior_pants_Ca"},
	{"name": "No Horizon, Legplates of the Crownless Host", "cls": "warrior", "slot": "pants", "noun": "Skirmisher's Legplates", "grade": "S", "art": "u_no_horizon_legplates_of_the_crownless_host", "passive": "warrior_pants_Cs"},
	{"name": "Red Antler Legplates", "cls": "warrior", "slot": "pants", "noun": "Reaver Legplates", "grade": "A", "art": "u_red_antler_legplates", "passive": "warrior_pants_Da"},
	{"name": "Warhowl, Legplates of the Crownless Host", "cls": "warrior", "slot": "pants", "noun": "Reaver Legplates", "grade": "S", "art": "u_warhowl_legplates_of_the_crownless_host", "passive": "warrior_pants_Ds"},
	{"name": "Mountainheart Legplates", "cls": "warrior", "slot": "pants", "noun": "Titan Legplates", "grade": "A", "art": "u_mountainheart_legplates", "passive": "warrior_pants_Ea"},
	{"name": "Stonefather, Legplates of the Crownless Host", "cls": "warrior", "slot": "pants", "noun": "Titan Legplates", "grade": "S", "art": "u_stonefather_legplates_of_the_crownless_host", "passive": "warrior_pants_Es"},
	{"name": "Stormneedle Hood", "cls": "archer", "slot": "helmet", "noun": "Stormweave Hood", "grade": "A", "art": "u_stormneedle_hood", "passive": "archer_helmet_Aa"},
	{"name": "Tempest Crown, Hood of the Last Gale", "cls": "archer", "slot": "helmet", "noun": "Stormweave Hood", "grade": "S", "art": "u_tempest_crown_hood_of_the_last_gale", "passive": "archer_helmet_As"},
	{"name": "Rivetleaf Hood", "cls": "archer", "slot": "helmet", "noun": "Studded Hood", "grade": "A", "art": "u_rivetleaf_hood", "passive": "archer_helmet_Ba"},
	{"name": "Ironwood Witness, Hood of the Last Gale", "cls": "archer", "slot": "helmet", "noun": "Studded Hood", "grade": "S", "art": "u_ironwood_witness_hood_of_the_last_gale", "passive": "archer_helmet_Bs"},
	{"name": "Windfeather Hood", "cls": "archer", "slot": "helmet", "noun": "Ranger's Hood", "grade": "A", "art": "u_windfeather_hood", "passive": "archer_helmet_Ca"},
	{"name": "White Wind, Hood of the Last Gale", "cls": "archer", "slot": "helmet", "noun": "Ranger's Hood", "grade": "S", "art": "u_white_wind_hood_of_the_last_gale", "passive": "archer_helmet_Cs"},
	{"name": "Red Quarry Hood", "cls": "archer", "slot": "helmet", "noun": "Hunter's Hood", "grade": "A", "art": "u_red_quarry_hood", "passive": "archer_helmet_Da"},
	{"name": "Last Hunt, Hood of the Last Gale", "cls": "archer", "slot": "helmet", "noun": "Hunter's Hood", "grade": "S", "art": "u_last_hunt_hood_of_the_last_gale", "passive": "archer_helmet_Ds"},
	{"name": "Oldhide Hood", "cls": "archer", "slot": "helmet", "noun": "Beastpelt Hood", "grade": "A", "art": "u_oldhide_hood", "passive": "archer_helmet_Ea"},
	{"name": "First Beast, Hood of the Last Gale", "cls": "archer", "slot": "helmet", "noun": "Beastpelt Hood", "grade": "S", "art": "u_first_beast_hood_of_the_last_gale", "passive": "archer_helmet_Es"},
	{"name": "Stormneedle Bracers", "cls": "archer", "slot": "gloves", "noun": "Stormweave Bracers", "grade": "A", "art": "u_stormneedle_bracers", "passive": "archer_gloves_Aa"},
	{"name": "Tempest Crown, Bracers of the Last Gale", "cls": "archer", "slot": "gloves", "noun": "Stormweave Bracers", "grade": "S", "art": "u_tempest_crown_bracers_of_the_last_gale", "passive": "archer_gloves_As"},
	{"name": "Rivetleaf Bracers", "cls": "archer", "slot": "gloves", "noun": "Studded Bracers", "grade": "A", "art": "u_rivetleaf_bracers", "passive": "archer_gloves_Ba"},
	{"name": "Ironwood Witness, Bracers of the Last Gale", "cls": "archer", "slot": "gloves", "noun": "Studded Bracers", "grade": "S", "art": "u_ironwood_witness_bracers_of_the_last_gale", "passive": "archer_gloves_Bs"},
	{"name": "Windfeather Bracers", "cls": "archer", "slot": "gloves", "noun": "Ranger's Bracers", "grade": "A", "art": "u_windfeather_bracers", "passive": "archer_gloves_Ca"},
	{"name": "White Wind, Bracers of the Last Gale", "cls": "archer", "slot": "gloves", "noun": "Ranger's Bracers", "grade": "S", "art": "u_white_wind_bracers_of_the_last_gale", "passive": "archer_gloves_Cs"},
	{"name": "Red Quarry Bracers", "cls": "archer", "slot": "gloves", "noun": "Hunter's Bracers", "grade": "A", "art": "u_red_quarry_bracers", "passive": "archer_gloves_Da"},
	{"name": "Last Hunt, Bracers of the Last Gale", "cls": "archer", "slot": "gloves", "noun": "Hunter's Bracers", "grade": "S", "art": "u_last_hunt_bracers_of_the_last_gale", "passive": "archer_gloves_Ds"},
	{"name": "Oldhide Bracers", "cls": "archer", "slot": "gloves", "noun": "Beastpelt Bracers", "grade": "A", "art": "u_oldhide_bracers", "passive": "archer_gloves_Ea"},
	{"name": "First Beast, Bracers of the Last Gale", "cls": "archer", "slot": "gloves", "noun": "Beastpelt Bracers", "grade": "S", "art": "u_first_beast_bracers_of_the_last_gale", "passive": "archer_gloves_Es"},
	{"name": "Stormneedle Leggings", "cls": "archer", "slot": "pants", "noun": "Stormweave Leggings", "grade": "A", "art": "u_stormneedle_leggings", "passive": "archer_pants_Aa"},
	{"name": "Tempest Crown, Leggings of the Last Gale", "cls": "archer", "slot": "pants", "noun": "Stormweave Leggings", "grade": "S", "art": "u_tempest_crown_leggings_of_the_last_gale", "passive": "archer_pants_As"},
	{"name": "Rivetleaf Leggings", "cls": "archer", "slot": "pants", "noun": "Studded Leggings", "grade": "A", "art": "u_rivetleaf_leggings", "passive": "archer_pants_Ba"},
	{"name": "Ironwood Witness, Leggings of the Last Gale", "cls": "archer", "slot": "pants", "noun": "Studded Leggings", "grade": "S", "art": "u_ironwood_witness_leggings_of_the_last_gale", "passive": "archer_pants_Bs"},
	{"name": "Windfeather Leggings", "cls": "archer", "slot": "pants", "noun": "Ranger's Leggings", "grade": "A", "art": "u_windfeather_leggings", "passive": "archer_pants_Ca"},
	{"name": "White Wind, Leggings of the Last Gale", "cls": "archer", "slot": "pants", "noun": "Ranger's Leggings", "grade": "S", "art": "u_white_wind_leggings_of_the_last_gale", "passive": "archer_pants_Cs"},
	{"name": "Red Quarry Leggings", "cls": "archer", "slot": "pants", "noun": "Hunter's Leggings", "grade": "A", "art": "u_red_quarry_leggings", "passive": "archer_pants_Da"},
	{"name": "Last Hunt, Leggings of the Last Gale", "cls": "archer", "slot": "pants", "noun": "Hunter's Leggings", "grade": "S", "art": "u_last_hunt_leggings_of_the_last_gale", "passive": "archer_pants_Ds"},
	{"name": "Oldhide Leggings", "cls": "archer", "slot": "pants", "noun": "Beastpelt Leggings", "grade": "A", "art": "u_oldhide_leggings", "passive": "archer_pants_Ea"},
	{"name": "First Beast, Leggings of the Last Gale", "cls": "archer", "slot": "pants", "noun": "Beastpelt Leggings", "grade": "S", "art": "u_first_beast_leggings_of_the_last_gale", "passive": "archer_pants_Es"},
	{"name": "Hushveil Cowl", "cls": "assassin", "slot": "helmet", "noun": "Shadowveil Cowl", "grade": "A", "art": "u_hushveil_cowl", "passive": "assassin_helmet_Aa"},
	{"name": "Empty Witness, Cowl Between Heartbeats", "cls": "assassin", "slot": "helmet", "noun": "Shadowveil Cowl", "grade": "S", "art": "u_empty_witness_cowl_between_heartbeats", "passive": "assassin_helmet_As"},
	{"name": "Sealhand Cowl", "cls": "assassin", "slot": "helmet", "noun": "Warded Cowl", "grade": "A", "art": "u_sealhand_cowl", "passive": "assassin_helmet_Ba"},
	{"name": "Closed Door, Cowl Between Heartbeats", "cls": "assassin", "slot": "helmet", "noun": "Warded Cowl", "grade": "S", "art": "u_closed_door_cowl_between_heartbeats", "passive": "assassin_helmet_Bs"},
	{"name": "Mothsilk Cowl", "cls": "assassin", "slot": "helmet", "noun": "Gossamer Cowl", "grade": "A", "art": "u_mothsilk_cowl", "passive": "assassin_helmet_Ca"},
	{"name": "Pale Web, Cowl Between Heartbeats", "cls": "assassin", "slot": "helmet", "noun": "Gossamer Cowl", "grade": "S", "art": "u_pale_web_cowl_between_heartbeats", "passive": "assassin_helmet_Cs"},
	{"name": "Red Fold Cowl", "cls": "assassin", "slot": "helmet", "noun": "Nightsilk Cowl", "grade": "A", "art": "u_red_fold_cowl", "passive": "assassin_helmet_Da"},
	{"name": "Last Shadow, Cowl Between Heartbeats", "cls": "assassin", "slot": "helmet", "noun": "Nightsilk Cowl", "grade": "S", "art": "u_last_shadow_cowl_between_heartbeats", "passive": "assassin_helmet_Ds"},
	{"name": "Pale Bone Cowl", "cls": "assassin", "slot": "helmet", "noun": "Grave Cowl", "grade": "A", "art": "u_pale_bone_cowl", "passive": "assassin_helmet_Ea"},
	{"name": "Returning Dead, Cowl Between Heartbeats", "cls": "assassin", "slot": "helmet", "noun": "Grave Cowl", "grade": "S", "art": "u_returning_dead_cowl_between_heartbeats", "passive": "assassin_helmet_Es"},
	{"name": "Hushveil Grips", "cls": "assassin", "slot": "gloves", "noun": "Shadowveil Grips", "grade": "A", "art": "u_hushveil_grips", "passive": "assassin_gloves_Aa"},
	{"name": "Empty Witness, Grips Between Heartbeats", "cls": "assassin", "slot": "gloves", "noun": "Shadowveil Grips", "grade": "S", "art": "u_empty_witness_grips_between_heartbeats", "passive": "assassin_gloves_As"},
	{"name": "Sealhand Grips", "cls": "assassin", "slot": "gloves", "noun": "Warded Grips", "grade": "A", "art": "u_sealhand_grips", "passive": "assassin_gloves_Ba"},
	{"name": "Closed Door, Grips Between Heartbeats", "cls": "assassin", "slot": "gloves", "noun": "Warded Grips", "grade": "S", "art": "u_closed_door_grips_between_heartbeats", "passive": "assassin_gloves_Bs"},
	{"name": "Mothsilk Grips", "cls": "assassin", "slot": "gloves", "noun": "Gossamer Grips", "grade": "A", "art": "u_mothsilk_grips", "passive": "assassin_gloves_Ca"},
	{"name": "Pale Web, Grips Between Heartbeats", "cls": "assassin", "slot": "gloves", "noun": "Gossamer Grips", "grade": "S", "art": "u_pale_web_grips_between_heartbeats", "passive": "assassin_gloves_Cs"},
	{"name": "Red Fold Grips", "cls": "assassin", "slot": "gloves", "noun": "Nightsilk Grips", "grade": "A", "art": "u_red_fold_grips", "passive": "assassin_gloves_Da"},
	{"name": "Last Shadow, Grips Between Heartbeats", "cls": "assassin", "slot": "gloves", "noun": "Nightsilk Grips", "grade": "S", "art": "u_last_shadow_grips_between_heartbeats", "passive": "assassin_gloves_Ds"},
	{"name": "Pale Bone Grips", "cls": "assassin", "slot": "gloves", "noun": "Grave Grips", "grade": "A", "art": "u_pale_bone_grips", "passive": "assassin_gloves_Ea"},
	{"name": "Returning Dead, Grips Between Heartbeats", "cls": "assassin", "slot": "gloves", "noun": "Grave Grips", "grade": "S", "art": "u_returning_dead_grips_between_heartbeats", "passive": "assassin_gloves_Es"},
	{"name": "Hushveil Wraps", "cls": "assassin", "slot": "pants", "noun": "Shadowveil Wraps", "grade": "A", "art": "u_hushveil_wraps", "passive": "assassin_pants_Aa"},
	{"name": "Empty Witness, Wraps Between Heartbeats", "cls": "assassin", "slot": "pants", "noun": "Shadowveil Wraps", "grade": "S", "art": "u_empty_witness_wraps_between_heartbeats", "passive": "assassin_pants_As"},
	{"name": "Sealhand Wraps", "cls": "assassin", "slot": "pants", "noun": "Warded Wraps", "grade": "A", "art": "u_sealhand_wraps", "passive": "assassin_pants_Ba"},
	{"name": "Closed Door, Wraps Between Heartbeats", "cls": "assassin", "slot": "pants", "noun": "Warded Wraps", "grade": "S", "art": "u_closed_door_wraps_between_heartbeats", "passive": "assassin_pants_Bs"},
	{"name": "Mothsilk Wraps", "cls": "assassin", "slot": "pants", "noun": "Gossamer Wraps", "grade": "A", "art": "u_mothsilk_wraps", "passive": "assassin_pants_Ca"},
	{"name": "Pale Web, Wraps Between Heartbeats", "cls": "assassin", "slot": "pants", "noun": "Gossamer Wraps", "grade": "S", "art": "u_pale_web_wraps_between_heartbeats", "passive": "assassin_pants_Cs"},
	{"name": "Red Fold Wraps", "cls": "assassin", "slot": "pants", "noun": "Nightsilk Wraps", "grade": "A", "art": "u_red_fold_wraps", "passive": "assassin_pants_Da"},
	{"name": "Last Shadow, Wraps Between Heartbeats", "cls": "assassin", "slot": "pants", "noun": "Nightsilk Wraps", "grade": "S", "art": "u_last_shadow_wraps_between_heartbeats", "passive": "assassin_pants_Ds"},
	{"name": "Pale Bone Wraps", "cls": "assassin", "slot": "pants", "noun": "Grave Wraps", "grade": "A", "art": "u_pale_bone_wraps", "passive": "assassin_pants_Ea"},
	{"name": "Returning Dead, Wraps Between Heartbeats", "cls": "assassin", "slot": "pants", "noun": "Grave Wraps", "grade": "S", "art": "u_returning_dead_wraps_between_heartbeats", "passive": "assassin_pants_Es"},
	{"name": "Wardthread Circlet", "cls": "mage", "slot": "helmet", "noun": "Silkward Circlet", "grade": "A", "art": "u_wardthread_circlet", "passive": "mage_helmet_Aa"},
	{"name": "White Theorem, Circlet Beyond the Firmament", "cls": "mage", "slot": "helmet", "noun": "Silkward Circlet", "grade": "S", "art": "u_white_theorem_circlet_beyond_the_firmament", "passive": "mage_helmet_As"},
	{"name": "Hexplate Circlet", "cls": "mage", "slot": "helmet", "noun": "Runeplate Circlet", "grade": "A", "art": "u_hexplate_circlet", "passive": "mage_helmet_Ba"},
	{"name": "Axiom Guard, Circlet Beyond the Firmament", "cls": "mage", "slot": "helmet", "noun": "Runeplate Circlet", "grade": "S", "art": "u_axiom_guard_circlet_beyond_the_firmament", "passive": "mage_helmet_Bs"},
	{"name": "Skyquill Circlet", "cls": "mage", "slot": "helmet", "noun": "Featherweave Circlet", "grade": "A", "art": "u_skyquill_circlet", "passive": "mage_helmet_Ca"},
	{"name": "Zero Weight, Circlet Beyond the Firmament", "cls": "mage", "slot": "helmet", "noun": "Featherweave Circlet", "grade": "S", "art": "u_zero_weight_circlet_beyond_the_firmament", "passive": "mage_helmet_Cs"},
	{"name": "Cometweave Circlet", "cls": "mage", "slot": "helmet", "noun": "Starweave Circlet", "grade": "A", "art": "u_cometweave_circlet", "passive": "mage_helmet_Da"},
	{"name": "Ninth Star, Circlet Beyond the Firmament", "cls": "mage", "slot": "helmet", "noun": "Starweave Circlet", "grade": "S", "art": "u_ninth_star_circlet_beyond_the_firmament", "passive": "mage_helmet_Ds"},
	{"name": "Faultstone Circlet", "cls": "mage", "slot": "helmet", "noun": "Earthen Circlet", "grade": "A", "art": "u_faultstone_circlet", "passive": "mage_helmet_Ea"},
	{"name": "Worldmantle, Circlet Beyond the Firmament", "cls": "mage", "slot": "helmet", "noun": "Earthen Circlet", "grade": "S", "art": "u_worldmantle_circlet_beyond_the_firmament", "passive": "mage_helmet_Es"},
	{"name": "Wardthread Handwraps", "cls": "mage", "slot": "gloves", "noun": "Silkward Handwraps", "grade": "A", "art": "u_wardthread_handwraps", "passive": "mage_gloves_Aa"},
	{"name": "White Theorem, Handwraps Beyond the Firmament", "cls": "mage", "slot": "gloves", "noun": "Silkward Handwraps", "grade": "S", "art": "u_white_theorem_handwraps_beyond_the_firmament", "passive": "mage_gloves_As"},
	{"name": "Hexplate Handwraps", "cls": "mage", "slot": "gloves", "noun": "Runeplate Handwraps", "grade": "A", "art": "u_hexplate_handwraps", "passive": "mage_gloves_Ba"},
	{"name": "Axiom Guard, Handwraps Beyond the Firmament", "cls": "mage", "slot": "gloves", "noun": "Runeplate Handwraps", "grade": "S", "art": "u_axiom_guard_handwraps_beyond_the_firmament", "passive": "mage_gloves_Bs"},
	{"name": "Skyquill Handwraps", "cls": "mage", "slot": "gloves", "noun": "Featherweave Handwraps", "grade": "A", "art": "u_skyquill_handwraps", "passive": "mage_gloves_Ca"},
	{"name": "Zero Weight, Handwraps Beyond the Firmament", "cls": "mage", "slot": "gloves", "noun": "Featherweave Handwraps", "grade": "S", "art": "u_zero_weight_handwraps_beyond_the_firmament", "passive": "mage_gloves_Cs"},
	{"name": "Cometweave Handwraps", "cls": "mage", "slot": "gloves", "noun": "Starweave Handwraps", "grade": "A", "art": "u_cometweave_handwraps", "passive": "mage_gloves_Da"},
	{"name": "Ninth Star, Handwraps Beyond the Firmament", "cls": "mage", "slot": "gloves", "noun": "Starweave Handwraps", "grade": "S", "art": "u_ninth_star_handwraps_beyond_the_firmament", "passive": "mage_gloves_Ds"},
	{"name": "Faultstone Handwraps", "cls": "mage", "slot": "gloves", "noun": "Earthen Handwraps", "grade": "A", "art": "u_faultstone_handwraps", "passive": "mage_gloves_Ea"},
	{"name": "Worldmantle, Handwraps Beyond the Firmament", "cls": "mage", "slot": "gloves", "noun": "Earthen Handwraps", "grade": "S", "art": "u_worldmantle_handwraps_beyond_the_firmament", "passive": "mage_gloves_Es"},
	{"name": "Wardthread Underleggings", "cls": "mage", "slot": "pants", "noun": "Silkward Underleggings", "grade": "A", "art": "u_wardthread_underleggings", "passive": "mage_pants_Aa"},
	{"name": "White Theorem, Underleggings Beyond the Firmament", "cls": "mage", "slot": "pants", "noun": "Silkward Underleggings", "grade": "S", "art": "u_white_theorem_underleggings_beyond_the_firmament", "passive": "mage_pants_As"},
	{"name": "Hexplate Underleggings", "cls": "mage", "slot": "pants", "noun": "Runeplate Underleggings", "grade": "A", "art": "u_hexplate_underleggings", "passive": "mage_pants_Ba"},
	{"name": "Axiom Guard, Underleggings Beyond the Firmament", "cls": "mage", "slot": "pants", "noun": "Runeplate Underleggings", "grade": "S", "art": "u_axiom_guard_underleggings_beyond_the_firmament", "passive": "mage_pants_Bs"},
	{"name": "Skyquill Underleggings", "cls": "mage", "slot": "pants", "noun": "Featherweave Underleggings", "grade": "A", "art": "u_skyquill_underleggings", "passive": "mage_pants_Ca"},
	{"name": "Zero Weight, Underleggings Beyond the Firmament", "cls": "mage", "slot": "pants", "noun": "Featherweave Underleggings", "grade": "S", "art": "u_zero_weight_underleggings_beyond_the_firmament", "passive": "mage_pants_Cs"},
	{"name": "Cometweave Underleggings", "cls": "mage", "slot": "pants", "noun": "Starweave Underleggings", "grade": "A", "art": "u_cometweave_underleggings", "passive": "mage_pants_Da"},
	{"name": "Ninth Star, Underleggings Beyond the Firmament", "cls": "mage", "slot": "pants", "noun": "Starweave Underleggings", "grade": "S", "art": "u_ninth_star_underleggings_beyond_the_firmament", "passive": "mage_pants_Ds"},
	{"name": "Faultstone Underleggings", "cls": "mage", "slot": "pants", "noun": "Earthen Underleggings", "grade": "A", "art": "u_faultstone_underleggings", "passive": "mage_pants_Ea"},
	{"name": "Worldmantle, Underleggings Beyond the Firmament", "cls": "mage", "slot": "pants", "noun": "Earthen Underleggings", "grade": "S", "art": "u_worldmantle_underleggings_beyond_the_firmament", "passive": "mage_pants_Es"},
	{"name": "Saintglass Greathelm", "cls": "paladin", "slot": "helmet", "noun": "Blessed Greathelm", "grade": "A", "art": "u_saintglass_greathelm", "passive": "paladin_helmet_Aa"},
	{"name": "Unshadowed, Greathelm of the Final Oath", "cls": "paladin", "slot": "helmet", "noun": "Blessed Greathelm", "grade": "S", "art": "u_unshadowed_greathelm_of_the_final_oath", "passive": "paladin_helmet_As"},
	{"name": "Oathiron Greathelm", "cls": "paladin", "slot": "helmet", "noun": "Templar Greathelm", "grade": "A", "art": "u_oathiron_greathelm", "passive": "paladin_helmet_Ba"},
	{"name": "Last Templar, Greathelm of the Final Oath", "cls": "paladin", "slot": "helmet", "noun": "Templar Greathelm", "grade": "S", "art": "u_last_templar_greathelm_of_the_final_oath", "passive": "paladin_helmet_Bs"},
	{"name": "Swiftvow Greathelm", "cls": "paladin", "slot": "helmet", "noun": "Vigil Greathelm", "grade": "A", "art": "u_swiftvow_greathelm", "passive": "paladin_helmet_Ca"},
	{"name": "Vigil Without End, Greathelm of the Final Oath", "cls": "paladin", "slot": "helmet", "noun": "Vigil Greathelm", "grade": "S", "art": "u_vigil_without_end_greathelm_of_the_final_oath", "passive": "paladin_helmet_Cs"},
	{"name": "Censure Greathelm", "cls": "paladin", "slot": "helmet", "noun": "Zealot Greathelm", "grade": "A", "art": "u_censure_greathelm", "passive": "paladin_helmet_Da"},
	{"name": "Final Censure, Greathelm of the Final Oath", "cls": "paladin", "slot": "helmet", "noun": "Zealot Greathelm", "grade": "S", "art": "u_final_censure_greathelm_of_the_final_oath", "passive": "paladin_helmet_Ds"},
	{"name": "Dawnstone Greathelm", "cls": "paladin", "slot": "helmet", "noun": "Sanctified Greathelm", "grade": "A", "art": "u_dawnstone_greathelm", "passive": "paladin_helmet_Ea"},
	{"name": "First Dawn, Greathelm of the Final Oath", "cls": "paladin", "slot": "helmet", "noun": "Sanctified Greathelm", "grade": "S", "art": "u_first_dawn_greathelm_of_the_final_oath", "passive": "paladin_helmet_Es"},
	{"name": "Saintglass Gauntlets", "cls": "paladin", "slot": "gloves", "noun": "Blessed Gauntlets", "grade": "A", "art": "u_saintglass_gauntlets", "passive": "paladin_gloves_Aa"},
	{"name": "Unshadowed, Gauntlets of the Final Oath", "cls": "paladin", "slot": "gloves", "noun": "Blessed Gauntlets", "grade": "S", "art": "u_unshadowed_gauntlets_of_the_final_oath", "passive": "paladin_gloves_As"},
	{"name": "Oathiron Gauntlets", "cls": "paladin", "slot": "gloves", "noun": "Templar Gauntlets", "grade": "A", "art": "u_oathiron_gauntlets", "passive": "paladin_gloves_Ba"},
	{"name": "Last Templar, Gauntlets of the Final Oath", "cls": "paladin", "slot": "gloves", "noun": "Templar Gauntlets", "grade": "S", "art": "u_last_templar_gauntlets_of_the_final_oath", "passive": "paladin_gloves_Bs"},
	{"name": "Swiftvow Gauntlets", "cls": "paladin", "slot": "gloves", "noun": "Vigil Gauntlets", "grade": "A", "art": "u_swiftvow_gauntlets", "passive": "paladin_gloves_Ca"},
	{"name": "Vigil Without End, Gauntlets of the Final Oath", "cls": "paladin", "slot": "gloves", "noun": "Vigil Gauntlets", "grade": "S", "art": "u_vigil_without_end_gauntlets_of_the_final_oath", "passive": "paladin_gloves_Cs"},
	{"name": "Censure Gauntlets", "cls": "paladin", "slot": "gloves", "noun": "Zealot Gauntlets", "grade": "A", "art": "u_censure_gauntlets", "passive": "paladin_gloves_Da"},
	{"name": "Final Censure, Gauntlets of the Final Oath", "cls": "paladin", "slot": "gloves", "noun": "Zealot Gauntlets", "grade": "S", "art": "u_final_censure_gauntlets_of_the_final_oath", "passive": "paladin_gloves_Ds"},
	{"name": "Dawnstone Gauntlets", "cls": "paladin", "slot": "gloves", "noun": "Sanctified Gauntlets", "grade": "A", "art": "u_dawnstone_gauntlets", "passive": "paladin_gloves_Ea"},
	{"name": "First Dawn, Gauntlets of the Final Oath", "cls": "paladin", "slot": "gloves", "noun": "Sanctified Gauntlets", "grade": "S", "art": "u_first_dawn_gauntlets_of_the_final_oath", "passive": "paladin_gloves_Es"},
	{"name": "Saintglass Legguards", "cls": "paladin", "slot": "pants", "noun": "Blessed Legguards", "grade": "A", "art": "u_saintglass_legguards", "passive": "paladin_pants_Aa"},
	{"name": "Unshadowed, Legguards of the Final Oath", "cls": "paladin", "slot": "pants", "noun": "Blessed Legguards", "grade": "S", "art": "u_unshadowed_legguards_of_the_final_oath", "passive": "paladin_pants_As"},
	{"name": "Oathiron Legguards", "cls": "paladin", "slot": "pants", "noun": "Templar Legguards", "grade": "A", "art": "u_oathiron_legguards", "passive": "paladin_pants_Ba"},
	{"name": "Last Templar, Legguards of the Final Oath", "cls": "paladin", "slot": "pants", "noun": "Templar Legguards", "grade": "S", "art": "u_last_templar_legguards_of_the_final_oath", "passive": "paladin_pants_Bs"},
	{"name": "Swiftvow Legguards", "cls": "paladin", "slot": "pants", "noun": "Vigil Legguards", "grade": "A", "art": "u_swiftvow_legguards", "passive": "paladin_pants_Ca"},
	{"name": "Vigil Without End, Legguards of the Final Oath", "cls": "paladin", "slot": "pants", "noun": "Vigil Legguards", "grade": "S", "art": "u_vigil_without_end_legguards_of_the_final_oath", "passive": "paladin_pants_Cs"},
	{"name": "Censure Legguards", "cls": "paladin", "slot": "pants", "noun": "Zealot Legguards", "grade": "A", "art": "u_censure_legguards", "passive": "paladin_pants_Da"},
	{"name": "Final Censure, Legguards of the Final Oath", "cls": "paladin", "slot": "pants", "noun": "Zealot Legguards", "grade": "S", "art": "u_final_censure_legguards_of_the_final_oath", "passive": "paladin_pants_Ds"},
	{"name": "Dawnstone Legguards", "cls": "paladin", "slot": "pants", "noun": "Sanctified Legguards", "grade": "A", "art": "u_dawnstone_legguards", "passive": "paladin_pants_Ea"},
	{"name": "First Dawn, Legguards of the Final Oath", "cls": "paladin", "slot": "pants", "noun": "Sanctified Legguards", "grade": "S", "art": "u_first_dawn_legguards_of_the_final_oath", "passive": "paladin_pants_Es"},
	{"name": "Nullsilk Hood", "cls": "warlock", "slot": "helmet", "noun": "Voidsilk Hood", "grade": "A", "art": "u_nullsilk_hood", "passive": "warlock_helmet_Aa"},
	{"name": "Oblivion Veil, Hood Beneath All Names", "cls": "warlock", "slot": "helmet", "noun": "Voidsilk Hood", "grade": "S", "art": "u_oblivion_veil_hood_beneath_all_names", "passive": "warlock_helmet_As"},
	{"name": "Gravebone Hood", "cls": "warlock", "slot": "helmet", "noun": "Bonemail Hood", "grade": "A", "art": "u_gravebone_hood", "passive": "warlock_helmet_Ba"},
	{"name": "Ossuary King, Hood Beneath All Names", "cls": "warlock", "slot": "helmet", "noun": "Bonemail Hood", "grade": "S", "art": "u_ossuary_king_hood_beneath_all_names", "passive": "warlock_helmet_Bs"},
	{"name": "Hushshade Hood", "cls": "warlock", "slot": "helmet", "noun": "Shadeweave Hood", "grade": "A", "art": "u_hushshade_hood", "passive": "warlock_helmet_Ca"},
	{"name": "Shadow Without Owner, Hood Beneath All Names", "cls": "warlock", "slot": "helmet", "noun": "Shadeweave Hood", "grade": "S", "art": "u_shadow_without_owner_hood_beneath_all_names", "passive": "warlock_helmet_Cs"},
	{"name": "Black Clause Hood", "cls": "warlock", "slot": "helmet", "noun": "Ruinweave Hood", "grade": "A", "art": "u_black_clause_hood", "passive": "warlock_helmet_Da"},
	{"name": "Ruin's Testament, Hood Beneath All Names", "cls": "warlock", "slot": "helmet", "noun": "Ruinweave Hood", "grade": "S", "art": "u_ruins_testament_hood_beneath_all_names", "passive": "warlock_helmet_Ds"},
	{"name": "Veinbound Hood", "cls": "warlock", "slot": "helmet", "noun": "Bloodpact Hood", "grade": "A", "art": "u_veinbound_hood", "passive": "warlock_helmet_Ea"},
	{"name": "Last Pulse, Hood Beneath All Names", "cls": "warlock", "slot": "helmet", "noun": "Bloodpact Hood", "grade": "S", "art": "u_last_pulse_hood_beneath_all_names", "passive": "warlock_helmet_Es"},
	{"name": "Nullsilk Claws", "cls": "warlock", "slot": "gloves", "noun": "Voidsilk Claws", "grade": "A", "art": "u_nullsilk_claws", "passive": "warlock_gloves_Aa"},
	{"name": "Oblivion Veil, Claws Beneath All Names", "cls": "warlock", "slot": "gloves", "noun": "Voidsilk Claws", "grade": "S", "art": "u_oblivion_veil_claws_beneath_all_names", "passive": "warlock_gloves_As"},
	{"name": "Gravebone Claws", "cls": "warlock", "slot": "gloves", "noun": "Bonemail Claws", "grade": "A", "art": "u_gravebone_claws", "passive": "warlock_gloves_Ba"},
	{"name": "Ossuary King, Claws Beneath All Names", "cls": "warlock", "slot": "gloves", "noun": "Bonemail Claws", "grade": "S", "art": "u_ossuary_king_claws_beneath_all_names", "passive": "warlock_gloves_Bs"},
	{"name": "Hushshade Claws", "cls": "warlock", "slot": "gloves", "noun": "Shadeweave Claws", "grade": "A", "art": "u_hushshade_claws", "passive": "warlock_gloves_Ca"},
	{"name": "Shadow Without Owner, Claws Beneath All Names", "cls": "warlock", "slot": "gloves", "noun": "Shadeweave Claws", "grade": "S", "art": "u_shadow_without_owner_claws_beneath_all_names", "passive": "warlock_gloves_Cs"},
	{"name": "Black Clause Claws", "cls": "warlock", "slot": "gloves", "noun": "Ruinweave Claws", "grade": "A", "art": "u_black_clause_claws", "passive": "warlock_gloves_Da"},
	{"name": "Ruin's Testament, Claws Beneath All Names", "cls": "warlock", "slot": "gloves", "noun": "Ruinweave Claws", "grade": "S", "art": "u_ruins_testament_claws_beneath_all_names", "passive": "warlock_gloves_Ds"},
	{"name": "Veinbound Claws", "cls": "warlock", "slot": "gloves", "noun": "Bloodpact Claws", "grade": "A", "art": "u_veinbound_claws", "passive": "warlock_gloves_Ea"},
	{"name": "Last Pulse, Claws Beneath All Names", "cls": "warlock", "slot": "gloves", "noun": "Bloodpact Claws", "grade": "S", "art": "u_last_pulse_claws_beneath_all_names", "passive": "warlock_gloves_Es"},
	{"name": "Nullsilk Chausses", "cls": "warlock", "slot": "pants", "noun": "Voidsilk Chausses", "grade": "A", "art": "u_nullsilk_chausses", "passive": "warlock_pants_Aa"},
	{"name": "Oblivion Veil, Chausses Beneath All Names", "cls": "warlock", "slot": "pants", "noun": "Voidsilk Chausses", "grade": "S", "art": "u_oblivion_veil_chausses_beneath_all_names", "passive": "warlock_pants_As"},
	{"name": "Gravebone Chausses", "cls": "warlock", "slot": "pants", "noun": "Bonemail Chausses", "grade": "A", "art": "u_gravebone_chausses", "passive": "warlock_pants_Ba"},
	{"name": "Ossuary King, Chausses Beneath All Names", "cls": "warlock", "slot": "pants", "noun": "Bonemail Chausses", "grade": "S", "art": "u_ossuary_king_chausses_beneath_all_names", "passive": "warlock_pants_Bs"},
	{"name": "Hushshade Chausses", "cls": "warlock", "slot": "pants", "noun": "Shadeweave Chausses", "grade": "A", "art": "u_hushshade_chausses", "passive": "warlock_pants_Ca"},
	{"name": "Shadow Without Owner, Chausses Beneath All Names", "cls": "warlock", "slot": "pants", "noun": "Shadeweave Chausses", "grade": "S", "art": "u_shadow_without_owner_chausses_beneath_all_names", "passive": "warlock_pants_Cs"},
	{"name": "Black Clause Chausses", "cls": "warlock", "slot": "pants", "noun": "Ruinweave Chausses", "grade": "A", "art": "u_black_clause_chausses", "passive": "warlock_pants_Da"},
	{"name": "Ruin's Testament, Chausses Beneath All Names", "cls": "warlock", "slot": "pants", "noun": "Ruinweave Chausses", "grade": "S", "art": "u_ruins_testament_chausses_beneath_all_names", "passive": "warlock_pants_Ds"},
	{"name": "Veinbound Chausses", "cls": "warlock", "slot": "pants", "noun": "Bloodpact Chausses", "grade": "A", "art": "u_veinbound_chausses", "passive": "warlock_pants_Ea"},
	{"name": "Last Pulse, Chausses Beneath All Names", "cls": "warlock", "slot": "pants", "noun": "Bloodpact Chausses", "grade": "S", "art": "u_last_pulse_chausses_beneath_all_names", "passive": "warlock_pants_Es"},
	{"name": "Spellscar Cuirass", "cls": "warrior", "slot": "armor", "noun": "Wardsteel Plate", "grade": "A", "art": "u_spellscar_cuirass", "passive": "warrior_armor_Aa"},
	{"name": "Null Crown, Plate of the Silent Siege", "cls": "warrior", "slot": "armor", "noun": "Wardsteel Plate", "grade": "S", "art": "u_null_crown_plate_of_the_silent_siege", "passive": "warrior_armor_As"},
	{"name": "Stone's Refusal", "cls": "warrior", "slot": "armor", "noun": "Ironwall Plate", "grade": "A", "art": "u_stones_refusal", "passive": "warrior_armor_Ba"},
	{"name": "Last Rampart, Armor That Would Not Fall", "cls": "warrior", "slot": "armor", "noun": "Ironwall Plate", "grade": "S", "art": "u_last_rampart_armor_that_would_not_fall", "passive": "warrior_armor_Bs"},
	{"name": "Fleet Iron", "cls": "warrior", "slot": "armor", "noun": "Skirmisher's Halfplate", "grade": "A", "art": "u_fleet_iron", "passive": "warrior_armor_Ca"},
	{"name": "Windcut, Halfplate of the Uncaught", "cls": "warrior", "slot": "armor", "noun": "Skirmisher's Halfplate", "grade": "S", "art": "u_windcut_halfplate_of_the_uncaught", "passive": "warrior_armor_Cs"},
	{"name": "Red Maw Harness", "cls": "warrior", "slot": "armor", "noun": "Bloodforged Harness", "grade": "A", "art": "u_red_maw_harness", "passive": "warrior_armor_Da"},
	{"name": "The Armor That Bites Back", "cls": "warrior", "slot": "armor", "noun": "Bloodforged Harness", "grade": "S", "art": "u_the_armor_that_bites_back", "passive": "warrior_armor_Ds"},
	{"name": "Mountain's Burden", "cls": "warrior", "slot": "armor", "noun": "Titanplate", "grade": "A", "art": "u_mountains_burden", "passive": "warrior_armor_Ea"},
	{"name": "Worldweight, Plate of the First Giant", "cls": "warrior", "slot": "armor", "noun": "Titanplate", "grade": "S", "art": "u_worldweight_plate_of_the_first_giant", "passive": "warrior_armor_Es"},
	{"name": "Spellbreak March", "cls": "warrior", "slot": "boots", "noun": "Wardstep Greaves", "grade": "A", "art": "u_spellbreak_march", "passive": "warrior_boots_Aa"},
	{"name": "Quiet Ground, Greaves of the Unhexed", "cls": "warrior", "slot": "boots", "noun": "Wardstep Greaves", "grade": "S", "art": "u_quiet_ground_greaves_of_the_unhexed", "passive": "warrior_boots_As"},
	{"name": "Ironroot Sabatons", "cls": "warrior", "slot": "boots", "noun": "Sabatons", "grade": "A", "art": "u_ironroot_sabatons", "passive": "warrior_boots_Ba"},
	{"name": "No Retreat, Steps of the Last Line", "cls": "warrior", "slot": "boots", "noun": "Sabatons", "grade": "S", "art": "u_no_retreat_steps_of_the_last_line", "passive": "warrior_boots_Bs"},
	{"name": "Quickmarch", "cls": "warrior", "slot": "boots", "noun": "Skirmisher's Boots", "grade": "A", "art": "u_quickmarch", "passive": "warrior_boots_Ca"},
	{"name": "Dustbefore, Boots of the First Charge", "cls": "warrior", "slot": "boots", "noun": "Skirmisher's Boots", "grade": "S", "art": "u_dustbefore_boots_of_the_first_charge", "passive": "warrior_boots_Cs"},
	{"name": "Red Spurs", "cls": "warrior", "slot": "boots", "noun": "Reaver Treads", "grade": "A", "art": "u_red_spurs", "passive": "warrior_boots_Da"},
	{"name": "Warpath, Treads That Crossed the Dead", "cls": "warrior", "slot": "boots", "noun": "Reaver Treads", "grade": "S", "art": "u_warpath_treads_that_crossed_the_dead", "passive": "warrior_boots_Ds"},
	{"name": "Groundlock", "cls": "warrior", "slot": "boots", "noun": "Anchorplate", "grade": "A", "art": "u_groundlock", "passive": "warrior_boots_Ea"},
	{"name": "Stillpoint, Boots Beneath the World", "cls": "warrior", "slot": "boots", "noun": "Anchorplate", "grade": "S", "art": "u_stillpoint_boots_beneath_the_world", "passive": "warrior_boots_Es"},
	{"name": "Ash Pennant", "cls": "warrior", "slot": "charm", "noun": "Warbanner", "grade": "A", "art": "u_ash_pennant", "passive": "warrior_charm_Aa"},
	{"name": "Standard of the Crownless Host", "cls": "warrior", "slot": "charm", "noun": "Warbanner", "grade": "S", "art": "u_standard_of_the_crownless_host", "passive": "warrior_charm_As"},
	{"name": "Iron Promise", "cls": "warrior", "slot": "charm", "noun": "Oath Sigil", "grade": "A", "art": "u_iron_promise", "passive": "warrior_charm_Ba"},
	{"name": "The Word That Outlived Kings", "cls": "warrior", "slot": "charm", "noun": "Oath Sigil", "grade": "S", "art": "u_the_word_that_outlived_kings", "passive": "warrior_charm_Bs"},
	{"name": "Gapfinder's Mark", "cls": "warrior", "slot": "charm", "noun": "Butcher's Token", "grade": "A", "art": "u_gapfinders_mark", "passive": "warrior_charm_Ca"},
	{"name": "Last Measure, Token of the Perfect Cut", "cls": "warrior", "slot": "charm", "noun": "Butcher's Token", "grade": "S", "art": "u_last_measure_token_of_the_perfect_cut", "passive": "warrior_charm_Cs"},
	{"name": "First Feint", "cls": "warrior", "slot": "charm", "noun": "Duelist's Knot", "grade": "A", "art": "u_first_feint", "passive": "warrior_charm_Da"},
	{"name": "Untouchable, Knot of the Empty Step", "cls": "warrior", "slot": "charm", "noun": "Duelist's Knot", "grade": "S", "art": "u_untouchable_knot_of_the_empty_step", "passive": "warrior_charm_Ds"},
	{"name": "Gateheart", "cls": "warrior", "slot": "charm", "noun": "Heart of the Wall", "grade": "A", "art": "u_gateheart", "passive": "warrior_charm_Ea"},
	{"name": "Citadel Seed, Heart of the Unbroken", "cls": "warrior", "slot": "charm", "noun": "Heart of the Wall", "grade": "S", "art": "u_citadel_seed_heart_of_the_unbroken", "passive": "warrior_charm_Es"},
	{"name": "Gale-Sewn Jack", "cls": "archer", "slot": "armor", "noun": "Stormweave Jerkin", "grade": "A", "art": "u_gale_sewn_jack", "passive": "archer_armor_Aa"},
	{"name": "Eye of the Tempest, Jerkin of Still Air", "cls": "archer", "slot": "armor", "noun": "Stormweave Jerkin", "grade": "S", "art": "u_eye_of_the_tempest_jerkin_of_still_air", "passive": "archer_armor_As"},
	{"name": "Thousand-Nail Vest", "cls": "archer", "slot": "armor", "noun": "Studded Brigandine", "grade": "A", "art": "u_thousand_nail_vest", "passive": "archer_armor_Ba"},
	{"name": "Rainwall, Brigandine of the Last Volley", "cls": "archer", "slot": "armor", "noun": "Studded Brigandine", "grade": "S", "art": "u_rainwall_brigandine_of_the_last_volley", "passive": "archer_armor_Bs"},
	{"name": "Hartshadow Leathers", "cls": "archer", "slot": "armor", "noun": "Ranger's Leathers", "grade": "A", "art": "u_hartshadow_leathers", "passive": "archer_armor_Ca"},
	{"name": "Greenwood Ghost, Hide of the Unseen Trail", "cls": "archer", "slot": "armor", "noun": "Ranger's Leathers", "grade": "S", "art": "u_greenwood_ghost_hide_of_the_unseen_trail", "passive": "archer_armor_Cs"},
	{"name": "Whitefang Rig", "cls": "archer", "slot": "armor", "noun": "Hunter's Harness", "grade": "A", "art": "u_whitefang_rig", "passive": "archer_armor_Da"},
	{"name": "Apex Covenant, Harness of the First Hunt", "cls": "archer", "slot": "armor", "noun": "Hunter's Harness", "grade": "S", "art": "u_apex_covenant_harness_of_the_first_hunt", "passive": "archer_armor_Ds"},
	{"name": "Moonclaw Pelt", "cls": "archer", "slot": "armor", "noun": "Beastpelt", "grade": "A", "art": "u_moonclaw_pelt", "passive": "archer_armor_Ea"},
	{"name": "Winterking's Mantle", "cls": "archer", "slot": "armor", "noun": "Beastpelt", "grade": "S", "art": "u_winterking_mantle", "passive": "archer_armor_Es"},
	{"name": "Needleheel", "cls": "archer", "slot": "boots", "noun": "Piercer's Cleats", "grade": "A", "art": "u_needleheel", "passive": "archer_boots_Aa"},
	{"name": "Groundsplit, Cleats of the Falling Star", "cls": "archer", "slot": "boots", "noun": "Piercer's Cleats", "grade": "S", "art": "u_groundsplit_cleats_of_the_falling_star", "passive": "archer_boots_As"},
	{"name": "Kestrel Steps", "cls": "archer", "slot": "boots", "noun": "Windstriders", "grade": "A", "art": "u_kestrel_steps", "passive": "archer_boots_Ba"},
	{"name": "Horizonless, Boots That Outran the Gale", "cls": "archer", "slot": "boots", "noun": "Windstriders", "grade": "S", "art": "u_horizonless_boots_that_outran_the_gale", "passive": "archer_boots_Bs"},
	{"name": "Deadstill Boots", "cls": "archer", "slot": "boots", "noun": "Marksman's Stance", "grade": "A", "art": "u_deadstill_boots", "passive": "archer_boots_Ca"},
	{"name": "Truefoot, Stance of the Final Arrow", "cls": "archer", "slot": "boots", "noun": "Marksman's Stance", "grade": "S", "art": "u_truefoot_stance_of_the_final_arrow", "passive": "archer_boots_Cs"},
	{"name": "Hexwalker Soles", "cls": "archer", "slot": "boots", "noun": "Wardedsole", "grade": "A", "art": "u_hexwalker_soles", "passive": "archer_boots_Da"},
	{"name": "Safe Passage, Boots Beyond the Curse", "cls": "archer", "slot": "boots", "noun": "Wardedsole", "grade": "S", "art": "u_safe_passage_boots_beyond_the_curse", "passive": "archer_boots_Ds"},
	{"name": "Wayfinder Treads", "cls": "archer", "slot": "boots", "noun": "Trailboots", "grade": "A", "art": "u_wayfinder_treads", "passive": "archer_boots_Ea"},
	{"name": "Last Trail, Boots at the World's Edge", "cls": "archer", "slot": "boots", "noun": "Trailboots", "grade": "S", "art": "u_last_trail_boots_at_the_worlds_edge", "passive": "archer_boots_Es"},
	{"name": "Blackshaft Token", "cls": "archer", "slot": "charm", "noun": "Fletcher's Token", "grade": "A", "art": "u_blackshaft_token", "passive": "archer_charm_Aa"},
	{"name": "First Arrow, Mark of the Empty Sky", "cls": "archer", "slot": "charm", "noun": "Fletcher's Token", "grade": "S", "art": "u_first_arrow_mark_of_the_empty_sky", "passive": "archer_charm_As"},
	{"name": "Stormpinion", "cls": "archer", "slot": "charm", "noun": "Windfeather", "grade": "A", "art": "u_stormpinion", "passive": "archer_charm_Ba"},
	{"name": "Breath of the High Wind", "cls": "archer", "slot": "charm", "noun": "Windfeather", "grade": "S", "art": "u_breath_of_the_high_wind", "passive": "archer_charm_Bs"},
	{"name": "Stag-Eye Totem", "cls": "archer", "slot": "charm", "noun": "Hunter's Totem", "grade": "A", "art": "u_stag_eye_totem", "passive": "archer_charm_Ca"},
	{"name": "Horned Moon, Totem of the Old Hunt", "cls": "archer", "slot": "charm", "noun": "Hunter's Totem", "grade": "S", "art": "u_horned_moon_totem_of_the_old_hunt", "passive": "archer_charm_Cs"},
	{"name": "Cairnseed Ward", "cls": "archer", "slot": "charm", "noun": "Stonebark Ward", "grade": "A", "art": "u_cairnseed_ward", "passive": "archer_charm_Da"},
	{"name": "Elderwall, Ward of the Walking Wood", "cls": "archer", "slot": "charm", "noun": "Stonebark Ward", "grade": "S", "art": "u_elderwall_ward_of_the_walking_wood", "passive": "archer_charm_Ds"},
	{"name": "Springcore Idol", "cls": "archer", "slot": "charm", "noun": "Greenheart Idol", "grade": "A", "art": "u_springcore_idol", "passive": "archer_charm_Ea"},
	{"name": "Everwild, Heart of the First Grove", "cls": "archer", "slot": "charm", "noun": "Greenheart Idol", "grade": "S", "art": "u_everwild_heart_of_the_first_grove", "passive": "archer_charm_Es"},
	{"name": "Knife-Shadow Cloak", "cls": "assassin", "slot": "armor", "noun": "Shadowveil Cloak", "grade": "A", "art": "u_knife_shadow_cloak", "passive": "assassin_armor_Aa"},
	{"name": "Eclipse's Hem, Cloak of No Witness", "cls": "assassin", "slot": "armor", "noun": "Shadowveil Cloak", "grade": "S", "art": "u_eclipses_hem_cloak_of_no_witness", "passive": "assassin_armor_As"},
	{"name": "Nine-Seal Mantle", "cls": "assassin", "slot": "armor", "noun": "Warded Mantle", "grade": "A", "art": "u_nine_seal_mantle", "passive": "assassin_armor_Ba"},
	{"name": "Unanswerable, Mantle of the Closed Door", "cls": "assassin", "slot": "armor", "noun": "Warded Mantle", "grade": "S", "art": "u_unanswerable_mantle_of_the_closed_door", "passive": "assassin_armor_Bs"},
	{"name": "Widowglass Veil", "cls": "assassin", "slot": "armor", "noun": "Gossamer Cloak", "grade": "A", "art": "u_widowglass_veil", "passive": "assassin_armor_Ca"},
	{"name": "Pale Web, Cloak Between Heartbeats", "cls": "assassin", "slot": "armor", "noun": "Gossamer Cloak", "grade": "S", "art": "u_pale_web_cloak_between_heartbeats", "passive": "assassin_armor_Cs"},
	{"name": "Red Fold", "cls": "assassin", "slot": "armor", "noun": "Nightsilk Wrap", "grade": "A", "art": "u_red_fold", "passive": "assassin_armor_Da"},
	{"name": "Last Shadow, Wrap of the Absent Hand", "cls": "assassin", "slot": "armor", "noun": "Nightsilk Wrap", "grade": "S", "art": "u_last_shadow_wrap_of_the_absent_hand", "passive": "assassin_armor_Ds"},
	{"name": "Thornshade Shroud", "cls": "assassin", "slot": "armor", "noun": "Verdant Shroud", "grade": "A", "art": "u_thornshade_shroud", "passive": "assassin_armor_Ea"},
	{"name": "Green Silence, Shroud of the Hollow Grove", "cls": "assassin", "slot": "armor", "noun": "Verdant Shroud", "grade": "S", "art": "u_green_silence_shroud_of_the_hollow_grove", "passive": "assassin_armor_Es"},
	{"name": "Mothstep", "cls": "assassin", "slot": "boots", "noun": "Slipsteps", "grade": "A", "art": "u_mothstep", "passive": "assassin_boots_Aa"},
	{"name": "No Footfall, Shoes of the Empty Room", "cls": "assassin", "slot": "boots", "noun": "Slipsteps", "grade": "S", "art": "u_no_footfall_shoes_of_the_empty_room", "passive": "assassin_boots_As"},
	{"name": "Wallcat Boots", "cls": "assassin", "slot": "boots", "noun": "Prowlers", "grade": "A", "art": "u_wallcat_boots", "passive": "assassin_boots_Ba"},
	{"name": "High Hunt, Prowlers Above the Moon", "cls": "assassin", "slot": "boots", "noun": "Prowlers", "grade": "S", "art": "u_high_hunt_prowlers_above_the_moon", "passive": "assassin_boots_Bs"},
	{"name": "Glassfang Treads", "cls": "assassin", "slot": "boots", "noun": "Venomtread", "grade": "A", "art": "u_glassfang_treads", "passive": "assassin_boots_Ca"},
	{"name": "Last Dose, Boots of the Perfect Poison", "cls": "assassin", "slot": "boots", "noun": "Venomtread", "grade": "S", "art": "u_last_dose_boots_of_the_perfect_poison", "passive": "assassin_boots_Cs"},
	{"name": "Quiet Anvil Wraps", "cls": "assassin", "slot": "boots", "noun": "Ironsole Wraps", "grade": "A", "art": "u_quiet_anvil_wraps", "passive": "assassin_boots_Da"},
	{"name": "Weightless Iron, Soles That Made No Sound", "cls": "assassin", "slot": "boots", "noun": "Ironsole Wraps", "grade": "S", "art": "u_weightless_iron_soles_that_made_no_sound", "passive": "assassin_boots_Ds"},
	{"name": "Pale Heel", "cls": "assassin", "slot": "boots", "noun": "Grave Treads", "grade": "A", "art": "u_pale_heel", "passive": "assassin_boots_Ea"},
	{"name": "Afterstep, Treads of the Returning Dead", "cls": "assassin", "slot": "boots", "noun": "Grave Treads", "grade": "S", "art": "u_afterstep_treads_of_the_returning_dead", "passive": "assassin_boots_Es"},
	{"name": "Red Witness", "cls": "assassin", "slot": "charm", "noun": "Killer's Mark", "grade": "A", "art": "u_red_witness", "passive": "assassin_charm_Aa"},
	{"name": "Final Name, Mark of the Inevitable", "cls": "assassin", "slot": "charm", "noun": "Killer's Mark", "grade": "S", "art": "u_final_name_mark_of_the_inevitable", "passive": "assassin_charm_As"},
	{"name": "Green Secret", "cls": "assassin", "slot": "charm", "noun": "Poisoner's Vial", "grade": "A", "art": "u_green_secret", "passive": "assassin_charm_Ba"},
	{"name": "Queen's Kiss, Vial of the Last Breath", "cls": "assassin", "slot": "charm", "noun": "Poisoner's Vial", "grade": "S", "art": "u_queens_kiss_vial_of_the_last_breath", "passive": "assassin_charm_Bs"},
	{"name": "Lantern for None", "cls": "assassin", "slot": "charm", "noun": "Ghostlight Charm", "grade": "A", "art": "u_lantern_for_none", "passive": "assassin_charm_Ca"},
	{"name": "Pale Guest, Light That Knows the Dead", "cls": "assassin", "slot": "charm", "noun": "Ghostlight Charm", "grade": "S", "art": "u_pale_guest_light_that_knows_the_dead", "passive": "assassin_charm_Cs"},
	{"name": "Knotted Debt", "cls": "assassin", "slot": "charm", "noun": "Bloodoath Cord", "grade": "A", "art": "u_knotted_debt", "passive": "assassin_charm_Da"},
	{"name": "Never Broken, Cord of the First Betrayal", "cls": "assassin", "slot": "charm", "noun": "Bloodoath Cord", "grade": "S", "art": "u_never_broken_cord_of_the_first_betrayal", "passive": "assassin_charm_Ds"},
	{"name": "Hollow Finger", "cls": "assassin", "slot": "charm", "noun": "Wraithbone Fetish", "grade": "A", "art": "u_hollow_finger", "passive": "assassin_charm_Ea"},
	{"name": "Bone Whisper, Fetish of the Unremembered", "cls": "assassin", "slot": "charm", "noun": "Wraithbone Fetish", "grade": "S", "art": "u_bone_whisper_fetish_of_the_unremembered", "passive": "assassin_charm_Es"},
	{"name": "Equation Robe", "cls": "mage", "slot": "armor", "noun": "Silk Vestments", "grade": "A", "art": "u_equation_robe", "passive": "mage_armor_Aa"},
	{"name": "White Theorem, Vestments of Proof", "cls": "mage", "slot": "armor", "noun": "Silk Vestments", "grade": "S", "art": "u_white_theorem_vestments_of_proof", "passive": "mage_armor_As"},
	{"name": "Hexwall Cassock", "cls": "mage", "slot": "armor", "noun": "Runeplate Robe", "grade": "A", "art": "u_hexwall_cassock", "passive": "mage_armor_Ba"},
	{"name": "Axiom Guard, Robe of Nine Locks", "cls": "mage", "slot": "armor", "noun": "Runeplate Robe", "grade": "S", "art": "u_axiom_guard_robe_of_nine_locks", "passive": "mage_armor_Bs"},
	{"name": "Skyquill Robe", "cls": "mage", "slot": "armor", "noun": "Featherweave Robe", "grade": "A", "art": "u_skyquill_robe", "passive": "mage_armor_Ca"},
	{"name": "Zero Weight, Raiment Above Gravity", "cls": "mage", "slot": "armor", "noun": "Featherweave Robe", "grade": "S", "art": "u_zero_weight_raiment_above_gravity", "passive": "mage_armor_Cs"},
	{"name": "Comet Sash", "cls": "mage", "slot": "armor", "noun": "Starweave Robe", "grade": "A", "art": "u_comet_sash", "passive": "mage_armor_Da"},
	{"name": "Eventide, Robe of the Last Constellation", "cls": "mage", "slot": "armor", "noun": "Starweave Robe", "grade": "S", "art": "u_eventide_robe_of_the_last_constellation", "passive": "mage_armor_Ds"},
	{"name": "Faultscribe Robe", "cls": "mage", "slot": "armor", "noun": "Earthen Robe", "grade": "A", "art": "u_faultscribe_robe", "passive": "mage_armor_Ea"},
	{"name": "Worldmantle, Vestment of the First Stone", "cls": "mage", "slot": "armor", "noun": "Earthen Robe", "grade": "S", "art": "u_worldmantle_vestment_of_the_first_stone", "passive": "mage_armor_Es"},
	{"name": "Comet Heel", "cls": "mage", "slot": "boots", "noun": "Starstep", "grade": "A", "art": "u_comet_heel", "passive": "mage_boots_Aa"},
	{"name": "Orbitless, Steps Between Stars", "cls": "mage", "slot": "boots", "noun": "Starstep", "grade": "S", "art": "u_orbitless_steps_between_stars", "passive": "mage_boots_As"},
	{"name": "Cloudkiss Slippers", "cls": "mage", "slot": "boots", "noun": "Levitation Slippers", "grade": "A", "art": "u_cloudkiss_slippers", "passive": "mage_boots_Ba"},
	{"name": "Ascendant, Slippers That Never Landed", "cls": "mage", "slot": "boots", "noun": "Levitation Slippers", "grade": "S", "art": "u_ascendant_slippers_that_never_landed", "passive": "mage_boots_Bs"},
	{"name": "Circlewalker Sandals", "cls": "mage", "slot": "boots", "noun": "Sigil Sandals", "grade": "A", "art": "u_circlewalker_sandals", "passive": "mage_boots_Ca"},
	{"name": "Closed Form, Sandals of the Perfect Rune", "cls": "mage", "slot": "boots", "noun": "Sigil Sandals", "grade": "S", "art": "u_closed_form_sandals_of_the_perfect_rune", "passive": "mage_boots_Cs"},
	{"name": "Bastion Shoes", "cls": "mage", "slot": "boots", "noun": "Wardstone Shoes", "grade": "A", "art": "u_bastion_shoes", "passive": "mage_boots_Da"},
	{"name": "No Entry, Shoes of the Uncrossed Line", "cls": "mage", "slot": "boots", "noun": "Wardstone Shoes", "grade": "S", "art": "u_no_entry_shoes_of_the_uncrossed_line", "passive": "mage_boots_Ds"},
	{"name": "Greenstride", "cls": "mage", "slot": "boots", "noun": "Rootbound Sandals", "grade": "A", "art": "u_greenstride", "passive": "mage_boots_Ea"},
	{"name": "Worldroot Steps", "cls": "mage", "slot": "boots", "noun": "Rootbound Sandals", "grade": "S", "art": "u_worldroot_steps", "passive": "mage_boots_Es"},
	{"name": "Thesis Orb", "cls": "mage", "slot": "charm", "noun": "Arcane Orb", "grade": "A", "art": "u_thesis_orb", "passive": "mage_charm_Aa"},
	{"name": "Singularity, Orb of the Unsolved", "cls": "mage", "slot": "charm", "noun": "Arcane Orb", "grade": "S", "art": "u_singularity_orb_of_the_unsolved", "passive": "mage_charm_As"},
	{"name": "Comet Splinter", "cls": "mage", "slot": "charm", "noun": "Starshard", "grade": "A", "art": "u_comet_splinter", "passive": "mage_charm_Ba"},
	{"name": "First Star's Tooth", "cls": "mage", "slot": "charm", "noun": "Starshard", "grade": "S", "art": "u_first_stars_tooth", "passive": "mage_charm_Bs"},
	{"name": "Mirror Ward", "cls": "mage", "slot": "charm", "noun": "Aegis Crystal", "grade": "A", "art": "u_mirror_ward", "passive": "mage_charm_Ca"},
	{"name": "Absolute, Crystal of the Final Barrier", "cls": "mage", "slot": "charm", "noun": "Aegis Crystal", "grade": "S", "art": "u_absolute_crystal_of_the_final_barrier", "passive": "mage_charm_Cs"},
	{"name": "Gale Script", "cls": "mage", "slot": "charm", "noun": "Zephyr Sigil", "grade": "A", "art": "u_gale_script", "passive": "mage_charm_Da"},
	{"name": "Breathless Seal", "cls": "mage", "slot": "charm", "noun": "Zephyr Sigil", "grade": "S", "art": "u_breathless_seal", "passive": "mage_charm_Ds"},
	{"name": "Spring Axiom", "cls": "mage", "slot": "charm", "noun": "Lifebloom Pendant", "grade": "A", "art": "u_spring_axiom", "passive": "mage_charm_Ea"},
	{"name": "First Bloom, Pendant Before Winter", "cls": "mage", "slot": "charm", "noun": "Lifebloom Pendant", "grade": "S", "art": "u_first_bloom_pendant_before_winter", "passive": "mage_charm_Es"},
	{"name": "Blue Oath Cuirass", "cls": "paladin", "slot": "armor", "noun": "Templar Plate", "grade": "A", "art": "u_blue_oath_cuirass", "passive": "paladin_armor_Aa"},
	{"name": "Covenant Crownplate", "cls": "paladin", "slot": "armor", "noun": "Templar Plate", "grade": "S", "art": "u_covenant_crownplate", "passive": "paladin_armor_As"},
	{"name": "Rose Chapel Plate", "cls": "paladin", "slot": "armor", "noun": "Blessed Plate", "grade": "A", "art": "u_rose_chapel_plate", "passive": "paladin_armor_Ba"},
	{"name": "Noonheart, Armor of First Light", "cls": "paladin", "slot": "armor", "noun": "Blessed Plate", "grade": "S", "art": "u_noonheart_armor_of_first_light", "passive": "paladin_armor_Bs"},
	{"name": "Watcher's Halfplate", "cls": "paladin", "slot": "armor", "noun": "Vigil Halfplate", "grade": "A", "art": "u_watchers_halfplate", "passive": "paladin_armor_Ca"},
	{"name": "Unblinking, Plate of the Last Vigil", "cls": "paladin", "slot": "armor", "noun": "Vigil Halfplate", "grade": "S", "art": "u_unblinking_plate_of_the_last_vigil", "passive": "paladin_armor_Cs"},
	{"name": "Red Doctrine", "cls": "paladin", "slot": "armor", "noun": "Zealot Harness", "grade": "A", "art": "u_red_doctrine", "passive": "paladin_armor_Da"},
	{"name": "Martyrfire Harness", "cls": "paladin", "slot": "armor", "noun": "Zealot Harness", "grade": "S", "art": "u_martyrfire_harness", "passive": "paladin_armor_Ds"},
	{"name": "Gate-Shrine Armor", "cls": "paladin", "slot": "armor", "noun": "Sanctified Bulwark", "grade": "A", "art": "u_gate_shrine_armor", "passive": "paladin_armor_Ea"},
	{"name": "Holy City, Bulwark of the Walking Cathedral", "cls": "paladin", "slot": "armor", "noun": "Sanctified Bulwark", "grade": "S", "art": "u_holy_city_bulwark_of_the_walking_cathedral", "passive": "paladin_armor_Es"},
	{"name": "Redspur Cleats", "cls": "paladin", "slot": "boots", "noun": "Zealot's Cleats", "grade": "A", "art": "u_redspur_cleats", "passive": "paladin_boots_Aa"},
	{"name": "Fervor, Steps of Unending Charge", "cls": "paladin", "slot": "boots", "noun": "Zealot's Cleats", "grade": "S", "art": "u_fervor_steps_of_unending_charge", "passive": "paladin_boots_As"},
	{"name": "Vowbound Sabatons", "cls": "paladin", "slot": "boots", "noun": "Sabatons of the Oath", "grade": "A", "art": "u_vowbound_sabatons", "passive": "paladin_boots_Ba"},
	{"name": "Ever Oath, Feet of the Faithful", "cls": "paladin", "slot": "boots", "noun": "Sabatons of the Oath", "grade": "S", "art": "u_ever_oath_feet_of_the_faithful", "passive": "paladin_boots_Bs"},
	{"name": "Nightwatch Steps", "cls": "paladin", "slot": "boots", "noun": "Vigil Steps", "grade": "A", "art": "u_nightwatch_steps", "passive": "paladin_boots_Ca"},
	{"name": "Dawnless Watch, Boots That Never Slept", "cls": "paladin", "slot": "boots", "noun": "Vigil Steps", "grade": "S", "art": "u_dawnless_watch_boots_that_never_slept", "passive": "paladin_boots_Cs"},
	{"name": "Solarch Greaves", "cls": "paladin", "slot": "boots", "noun": "Radiant Greaves", "grade": "A", "art": "u_solarch_greaves", "passive": "paladin_boots_Da"},
	{"name": "Noonwalker Greaves", "cls": "paladin", "slot": "boots", "noun": "Radiant Greaves", "grade": "S", "art": "u_noonwalker_greaves", "passive": "paladin_boots_Ds"},
	{"name": "Roadworn Promise", "cls": "paladin", "slot": "boots", "noun": "Pilgrim's Resolve", "grade": "A", "art": "u_roadworn_promise", "passive": "paladin_boots_Ea"},
	{"name": "Final Mile, Boots Beyond the Shrine", "cls": "paladin", "slot": "boots", "noun": "Pilgrim's Resolve", "grade": "S", "art": "u_final_mile_boots_beyond_the_shrine", "passive": "paladin_boots_Es"},
	{"name": "Saint's Window", "cls": "paladin", "slot": "charm", "noun": "Reliquary", "grade": "A", "art": "u_saints_window", "passive": "paladin_charm_Aa"},
	{"name": "House of Light, Reliquary Without Doors", "cls": "paladin", "slot": "charm", "noun": "Reliquary", "grade": "S", "art": "u_house_of_light_reliquary_without_doors", "passive": "paladin_charm_As"},
	{"name": "Dawn Coin", "cls": "paladin", "slot": "charm", "noun": "Sunburst Icon", "grade": "A", "art": "u_dawn_coin", "passive": "paladin_charm_Ba"},
	{"name": "Unsetting, Icon of the First Sun", "cls": "paladin", "slot": "charm", "noun": "Sunburst Icon", "grade": "S", "art": "u_unsetting_icon_of_the_first_sun", "passive": "paladin_charm_Bs"},
	{"name": "White Verdict", "cls": "paladin", "slot": "charm", "noun": "Judgment Sigil", "grade": "A", "art": "u_white_verdict", "passive": "paladin_charm_Ca"},
	{"name": "Last Measure, Seal of Perfect Justice", "cls": "paladin", "slot": "charm", "noun": "Judgment Sigil", "grade": "S", "art": "u_last_measure_seal_of_perfect_justice", "passive": "paladin_charm_Cs"},
	{"name": "Red Haste Knot", "cls": "paladin", "slot": "charm", "noun": "Swiftvow Cord", "grade": "A", "art": "u_red_haste_knot", "passive": "paladin_charm_Da"},
	{"name": "First to Answer, Cord of Immediate Oath", "cls": "paladin", "slot": "charm", "noun": "Swiftvow Cord", "grade": "S", "art": "u_first_to_answer_cord_of_immediate_oath", "passive": "paladin_charm_Ds"},
	{"name": "Broken King's Seal", "cls": "paladin", "slot": "charm", "noun": "Oathkeeper's Seal", "grade": "A", "art": "u_broken_kings_seal", "passive": "paladin_charm_Ea"},
	{"name": "Never Forsworn, Seal That Binds the Dawn", "cls": "paladin", "slot": "charm", "noun": "Oathkeeper's Seal", "grade": "S", "art": "u_never_forsworn_seal_that_binds_the_dawn", "passive": "paladin_charm_Es"},
	{"name": "Black Equation Robe", "cls": "warlock", "slot": "armor", "noun": "Voidsilk Robe", "grade": "A", "art": "u_black_equation_robe", "passive": "warlock_armor_Aa"},
	{"name": "Event Horizon, Vestment of No Return", "cls": "warlock", "slot": "armor", "noun": "Voidsilk Robe", "grade": "S", "art": "u_event_horizon_vestment_of_no_return", "passive": "warlock_armor_As"},
	{"name": "Pale Covenant", "cls": "warlock", "slot": "armor", "noun": "Bonemail", "grade": "A", "art": "u_pale_covenant", "passive": "warlock_armor_Ba"},
	{"name": "Ossuary King, Mail of the First Grave", "cls": "warlock", "slot": "armor", "noun": "Bonemail", "grade": "S", "art": "u_ossuary_king_mail_of_the_first_grave", "passive": "warlock_armor_Bs"},
	{"name": "Mothshade Robe", "cls": "warlock", "slot": "armor", "noun": "Shadeweave Robe", "grade": "A", "art": "u_mothshade_robe", "passive": "warlock_armor_Ca"},
	{"name": "The Shadow That Remained", "cls": "warlock", "slot": "armor", "noun": "Shadeweave Robe", "grade": "S", "art": "u_the_shadow_that_remained", "passive": "warlock_armor_Cs"},
	{"name": "Broken Law Vestment", "cls": "warlock", "slot": "armor", "noun": "Ruinweave", "grade": "A", "art": "u_broken_law_vestment", "passive": "warlock_armor_Da"},
	{"name": "Catastrophe Script", "cls": "warlock", "slot": "armor", "noun": "Ruinweave", "grade": "S", "art": "u_catastrophe_script", "passive": "warlock_armor_Ds"},
	{"name": "Red Contract", "cls": "warlock", "slot": "armor", "noun": "Bloodpact Vestment", "grade": "A", "art": "u_red_contract", "passive": "warlock_armor_Ea"},
	{"name": "Last Pulse, Vestment of the Final Debt", "cls": "warlock", "slot": "armor", "noun": "Bloodpact Vestment", "grade": "S", "art": "u_last_pulse_vestment_of_the_final_debt", "passive": "warlock_armor_Es"},
	{"name": "Faultwalker", "cls": "warlock", "slot": "boots", "noun": "Ruinstep", "grade": "A", "art": "u_faultwalker", "passive": "warlock_boots_Aa"},
	{"name": "Worldbreak Treads", "cls": "warlock", "slot": "boots", "noun": "Ruinstep", "grade": "S", "art": "u_worldbreak_treads", "passive": "warlock_boots_As"},
	{"name": "Hollow Step", "cls": "warlock", "slot": "boots", "noun": "Shadowstep Wraps", "grade": "A", "art": "u_hollow_step", "passive": "warlock_boots_Ba"},
	{"name": "Unseen Road", "cls": "warlock", "slot": "boots", "noun": "Shadowstep Wraps", "grade": "S", "art": "u_unseen_road", "passive": "warlock_boots_Bs"},
	{"name": "Nine-Hex Boots", "cls": "warlock", "slot": "boots", "noun": "Hexcarved Treads", "grade": "A", "art": "u_nine_hex_boots", "passive": "warlock_boots_Ca"},
	{"name": "Final Curse Treads", "cls": "warlock", "slot": "boots", "noun": "Hexcarved Treads", "grade": "S", "art": "u_final_curse_treads", "passive": "warlock_boots_Cs"},
	{"name": "Pale March", "cls": "warlock", "slot": "boots", "noun": "Bonewalkers", "grade": "A", "art": "u_pale_march", "passive": "warlock_boots_Da"},
	{"name": "Dead Road, Boots of Returning Kings", "cls": "warlock", "slot": "boots", "noun": "Bonewalkers", "grade": "S", "art": "u_dead_road_boots_of_returning_kings", "passive": "warlock_boots_Ds"},
	{"name": "Chainwake", "cls": "warlock", "slot": "boots", "noun": "Gravebound Boots", "grade": "A", "art": "u_chainwake", "passive": "warlock_boots_Ea"},
	{"name": "No Release, Boots of the Bound Dead", "cls": "warlock", "slot": "boots", "noun": "Gravebound Boots", "grade": "S", "art": "u_no_release_boots_of_the_bound_dead", "passive": "warlock_boots_Es"},
	{"name": "Quiet Passenger", "cls": "warlock", "slot": "charm", "noun": "Soul Fetish", "grade": "A", "art": "u_quiet_passenger", "passive": "warlock_charm_Aa"},
	{"name": "Soulstar, Fetish of the Last Breath", "cls": "warlock", "slot": "charm", "noun": "Soul Fetish", "grade": "S", "art": "u_soulstar_fetish_of_the_last_breath", "passive": "warlock_charm_As"},
	{"name": "Black Oracle", "cls": "warlock", "slot": "charm", "noun": "Cursed Idol", "grade": "A", "art": "u_black_oracle", "passive": "warlock_charm_Ba"},
	{"name": "Nameless God, Idol Beneath the Throne", "cls": "warlock", "slot": "charm", "noun": "Cursed Idol", "grade": "S", "art": "u_nameless_god_idol_beneath_the_throne", "passive": "warlock_charm_Bs"},
	{"name": "Cinder Seal", "cls": "warlock", "slot": "charm", "noun": "Ward of Ash", "grade": "A", "art": "u_cinder_seal", "passive": "warlock_charm_Ca"},
	{"name": "Ashen Law, Ward After All Fires", "cls": "warlock", "slot": "charm", "noun": "Ward of Ash", "grade": "S", "art": "u_ashen_law_ward_after_all_fires", "passive": "warlock_charm_Cs"},
	{"name": "Night Knot", "cls": "warlock", "slot": "charm", "noun": "Umbral Cord", "grade": "A", "art": "u_night_knot", "passive": "warlock_charm_Da"},
	{"name": "Endless Shade, Cord Around the Moon", "cls": "warlock", "slot": "charm", "noun": "Umbral Cord", "grade": "S", "art": "u_endless_shade_cord_around_the_moon", "passive": "warlock_charm_Ds"},
	{"name": "Vein Prison", "cls": "warlock", "slot": "charm", "noun": "Heartcage", "grade": "A", "art": "u_vein_prison", "passive": "warlock_charm_Ea"},
	{"name": "Last Heart, Cage That Beats in Darkness", "cls": "warlock", "slot": "charm", "noun": "Heartcage", "grade": "S", "art": "u_last_heart_cage_that_beats_in_darkness", "passive": "warlock_charm_Es"},
]


## Named uniques for one class, in manifest order (shape, then A before S).
static func uniques_for(cls: String) -> Array:
	var out: Array = []
	for u in UNIQUES:
		if String(u["cls"]) == cls:
			out.append(u)
	return out


# S_GEAR — RETIRED (owner call, 2026-07-27): no legendary tier, no awakening
# questline. The six flagship weapon passives were TRANSPLANTED onto fitting
# named-S uniques (kingsblade->Crownfall, windward->Tempest Yew, wellspring->
# Firmament, mirrorstep->Pale Flight, dawnbreaker->Dawnfall, voidmaw->The Book
# That Remembers You) and are live on pickup like every unique. This table is
# now a HISTORICAL RECORD only — old saves carry these names on their items
# directly and their passives grandfather in live (the dormant gate is gone).
# Nothing rolls from here; the codex legendary shelf was removed with the tier.
const S_GEAR := {
	"warrior": {
		"weapon": {"name": "Kingsbane, Edge of the Fallen Crown", "passive": "kingsblade"},
		"armor":  {"name": "Aegis of the Mountain"},
		"boots":  {"name": "Earthshaker Sabatons"},
		"charm":  {"name": "Warlord's Iron Oath"},
	},
	"archer": {
		"weapon": {"name": "Stormcaller, Bow of the Tempest", "passive": "windward"},
		"armor":  {"name": "Cloak of a Thousand Leaves"},
		"boots":  {"name": "Zephyr's Grace"},
		"charm":  {"name": "The Hawk God's Eye"},
	},
	"mage": {
		"weapon": {"name": "Heart of the Phoenix", "passive": "wellspring"},
		"armor":  {"name": "Robes of the Infinite"},
		"boots":  {"name": "Steps of the Void"},
		"charm":  {"name": "The Archmage's Folly"},
	},
	"assassin": {
		"weapon": {"name": "Nightfang, Kiss of the Abyss", "passive": "mirrorstep"},
		"armor":  {"name": "Shroud of Silence"},
		"boots":  {"name": "Whisperwind"},
		"charm":  {"name": "The Bloodpact"},
	},
	"paladin": {
		"weapon": {"name": "Dawnbreaker, Hammer of the Highfather", "passive": "dawnbreaker"},
		"armor":  {"name": "Bulwark of the Dawn"},
		"boots":  {"name": "Greaves of the Vigil"},
		"charm":  {"name": "The Highfather's Oath"},
	},
	"warlock": {
		"weapon": {"name": "Grimoire of the Hollow Choir", "passive": "voidmaw"},
		"armor":  {"name": "Vestments of the Long Bargain"},
		"boots":  {"name": "Voidwalkers"},
		"charm":  {"name": "The First Debt"},
	},
}

const PASSIVES := {
	# ---- the six S_GEAR class legendaries (awakening-quest gated) ----
	"kingsblade":  "Cleave hurls a sword wave",
	"windward":    "Second Wind kicks in after just 1.5s untouched (from 3s)",
	"wellspring":  "+50% mana regen; Firebolt and (Frost Nova, Blink) cool down 8% faster",
	"mirrorstep":  "Dashing reflects nearby projectiles and softens AoE damage; during Death Mark, Stab and Fan of Knives WEAVE — both fire at once for a burst",
	"dawnbreaker": "Judgment calls down a pillar of light (splash + holy burn)",
	"voidmaw":     "Shadowbolt cools down 8% faster; Void Rift ends with a curse-wave that shoves enemies off you and curses the room",
	# ---- named-unique signature passives (2026-07-27, live on pickup) ----
	# Text is the player-facing line on the item card; A-tier BARGAIN drawbacks
	# are printed in full (no silent effects). Magnitudes live in Balance.UNIQ.
	# --- warrior ---
	"pennon":     "Shield Bash SUNDERS everything it rams — their armor is torn open for 4s",
	"decree":     "Every 3rd Cleave is the DECREE: a heavier thrust that ignores armor outright and staggers",
	"warpath":    "While Berserk runs, your crits echo a ghost-blade strike",
	"lasthost":   "Your crits raise the Last Host — a spectral blade strikes again",
	"outrider":   "When an attack misses you, your next Cleave (2s) strikes twice — BUT Grit never stacks",
	"horizon":    "Every dodge sharpens the line: your next Cleave is a guaranteed crit, and Shield Bash returns 1.5s sooner",
	"reprisal":   "Blows that land on you risk the tooth: 30% chance the melee attacker is counter-cut",
	"thegate":    "Shield Bash raises the Gate: 2.5s of massive guard, and blows taken while it holds are answered with a stagger and a counter-cut",
	"dirge":      "Cleave and Whirlwind hit 20% harder — BUT both toll 15% slower",
	"aftershock": "Everything falls twice: Whirlwind leaves a collapsing ring that detonates a beat later",
	# --- archer ---
	"siegebolt":  "Multishot looses siege bolts that punch straight through their victims",
	"gale":       "Every 5th Quick Shot looses the gale — a free 3-arrow fan rides the shot",
	"farsight":   "Arrows loosed at distant prey halve its armor",
	"herald":     "Your first hit on an unwounded enemy is a guaranteed crit and EXPOSES the prey — and a kill re-arms the dawn for 3s",
	"foxfire":    "Slipping an attack draws the fox's shot: your next Quick Shot fires twin arrows",
	"hartsbreath": "Tumble draws the Hart's Breath: your next 2 shots are guaranteed crits — a PERFECT dodge draws 3, and Multishot returns at once",
	"briar":      "Enemies that strike you are briar-lashed (torn + slowed) — BUT Second Wind mends at half strength",
	"bramble":    "While the wild has your blood (hit within 3s), your arrows grow thorns — and a landed blow vents a rooting burst (6s cd)",
	"warhorn":    "Multishot fans 7 arrows instead of 5 — BUT takes 1.5s longer to return",
	"moonturn":   "Night returns: after Arrow Storm ends, a half-strength storm falls again unbidden",
	# --- assassin ---
	"gapfinder":  "Stab ignores half the armor of staggered, stunned or slowed prey",
	"quietus":    "Below 20% health the needle is a verdict: Stab strikes TRUE, and a Stab kill hastens Death Mark 2s",
	"compass":    "Every knife points the same way: Fan of Knives converges on your prey — BUT loses its spread",
	"midnight":   "A critical knife doesn't stop: Fan of Knives crits ricochet to a second enemy",
	"mothdust":   "Slipping a blow shakes dust from the wing: nearby enemies are slowed",
	"heartbeat":  "Each dodge falls between heartbeats: half of Shadow Dash's remaining cooldown vanishes and the next dash cuts 30% deeper",
	"parry":      "30% chance to PARRY a melee blow outright and riposte — BUT your Elusive evasion is halved",
	"refusal":    "Death is refused (90s): a killing blow leaves you at 1 HP, untouchable a breath, blood surge full, Death Mark ready",
	"arithmetic": "The sum comes due: every 4th Stab lands with cleaver weight — 60% harder, staggering",
	"headsman":   "Mercy is quick: Stab and Shadow Dash BEHEAD wounded prey outright, and each beheading feeds the blood surge",
	# --- mage ---
	"wardcrack":  "Each Firebolt cracks the ward a little wider — stacking armor shred",
	"axiom":      "The law is broken: 15% of ALL your ability damage resolves as TRUE damage",
	"cometfall":  "A critical Firebolt bursts like a cometfall — splash damage around the victim",
	"ninthstar":  "The ninth bolt is the Star: every 9th Firebolt is a guaranteed crit that bursts and cracks the ward",
	"squall":     "Blink stirs a squall: your next Firebolt after a Blink strikes twice",
	"breathless": "The sky empties where you stood: evading a hit resets Blink, and the next Blink's shock strikes doubled",
	"springwake": "The bloom drinks deeper: Frost Nova's restore swells half again, and each enemy caught mends you",
	"worldroot":  "Your life IS your power: bonus max health feeds your ATK, and Frost Nova ROOTS what it catches",
	"atlas":      "Meteor burns 40% TRUE (from 25%) — BUT the sky takes 6s longer to answer",
	"skyfall":    "Heaven answers twice: Meteor calls a second, half-weight meteor onto the next-nearest enemy",
	# --- paladin ---
	"vow":        "The vow re-orders the soul: INT converts to ATK at the primary rate — BUT STR falls to the lesser one",
	"noonday":    "At noon nothing shades you: INT converts at the primary rate alongside STR, and every 4th Judgment lances THROUGH the target",
	"censure":    "A critical blow tolls the bell: the chime staggers and splashes around the victim",
	"absolution": "Every 3rd kill rings the Last Toll: a free Consecration wave breaks from you",
	"measure":    "A measured step earns a measured answer: evading arms your next Judgment with +40% weight and a sliver of mending",
	"vigil":      "The vigil rewards the watchful: a dodge instantly rearms Judgment's leap, and the next Judgment lands as a guaranteed crit",
	"knell":      "Each answered blow is a knell that mends: Aegis's smite-backs heal you",
	"answer":     "The wall keeps accounts: 30% of damage you take is banked as holy charge for your next Judgment's SMITE",
	"burden":     "The burden makes the blow: Judgment strikes 15% heavier — BUT swings 15% slower",
	"dawnfall":   "The last oath falls like dawn: Conviction's slam hits 30% harder and leaves everything burning and slowed",
	# --- warlock ---
	"inkteeth":   "The ink bites: Shadowbolt leaves gnawing teeth-marks",
	"remembrance": "Whoever wounds you is written down — your attacker is automatically HEXED",
	"collection": "Debts accrue interest: crits against hexed enemies collect 30% extra and a little mana back",
	"clause":     "The clause can be invoked early: a crit against a hexed enemy detonates its hex at half strength — without consuming it",
	"hush":       "What misses you feeds the silence: after an evade, your next Shadowbolt strikes twice",
	"truename":   "Dodge a blow and you have heard the attacker's true name: they are hexed on the spot and lashed by shadow",
	"witness":    "The book sees who struck you: attackers are BOUND — withered and slowed",
	"thecover":   "When a blow would break you (below 30%), the Cover opens: 2s of heavy damage reduction and a repulsing void-wave (25s cd)",
	"veinroot":   "The root drinks from your reserve: Dark Pact's blast draws extra force from your max health, and its surge lingers 2s",
	"lastpulse":  "Every pulse of stored blood is power: bonus max health feeds your ATK — doubled for 5s after Dark Pact",
	# ---- armor-family TEMPLATES (helmet/gloves/pants uniques, 2026-07-27) ----
	# 30 shared systems (GEAR_ARMOR_UNIQUE_PASSIVES.md): bare id = S lane,
	# `_a` = A lane. The 180 items carrying these arrive with the slot go-live
	# (art pass names them); the engine behind every line is live already.
	"helm_ward":      "Taking magic damage arms the ward-crown: 30% magic damage reduction for 2s (8s cd)",
	"helm_ward_a":    "Taking magic damage arms a lesser ward: 15% magic damage reduction for 2s (8s cd)",
	"glove_ward":     "Your hits unweave the target's wards — their armor is torn open for 3s",
	"glove_ward_a":   "Your hits fray the target's wards — a little armor torn open for 3s",
	"pants_ward":     "Grounded: slows, roots and freezes on you run 30% shorter",
	"pants_ward_a":   "Deep-grounded: slows, roots and freezes on you run 50% shorter — BUT you receive 10% less healing",
	"helm_guard":     "The crest BLUNTS: the first enemy crit every 10s lands as a normal hit",
	"helm_guard_a":   "The crest turns: the first enemy crit every 10s loses half its bite",
	"glove_guard":    "Iron answer: 25% chance a melee attacker is counter-struck",
	"glove_guard_a":  "Iron answer: 15% chance a melee attacker is counter-struck",
	"pants_guard":    "Anchor stance: every blow you take hardens you — flat damage reduction, up to 3 stacks",
	"pants_guard_a":  "Anchor stance: blows you take harden you a little — up to 2 stacks",
	"helm_finesse":   "Keen eye: evading a blow EXPOSES the attacker for 3s",
	"helm_finesse_a": "Keen eye: evading a blow briefly EXPOSES the attacker",
	"glove_finesse":  "Deft hands: every 5th basic attack cannot miss or be grazed",
	"glove_finesse_a": "Deft hands: every 8th basic attack cannot miss or be grazed",
	"pants_finesse":  "Slip stance: being hit leaves you slippery — +10% evasion for 2s",
	"pants_finesse_a": "Slip stance: being hit leaves you very slippery — +15% evasion for 2s — BUT Second Wind waits 0.5s longer",
	"helm_aggr":      "War-crown: your first hit on an unwounded enemy strikes 25% harder",
	"helm_aggr_a":    "War-crown: your first hit on an unwounded enemy strikes 15% harder",
	"glove_aggr":     "Blood knuckle: your crits tear — a wound that keeps burning for 3s",
	"glove_aggr_a":   "Blood knuckle: your crits nick — a lesser wound that burns for 3s",
	"pants_aggr":     "Advance stance: after your commit ability, your next damaging ability within 3s strikes 20% harder",
	"pants_aggr_a":   "Advance stance: after your commit ability, your next damaging ability within 3s strikes 12% harder",
	"helm_bulwark":   "Life-crest: overhealing pools into a shield (up to 8% max health)",
	"helm_bulwark_a": "Life-crest: overhealing pools into a small shield (up to 4% max health)",
	"glove_bulwark":  "Might grip: your bulk lands with every hit — bonus damage from your max health",
	"glove_bulwark_a": "Might grip: a little of your bulk lands with every hit",
	"pants_bulwark":  "Last bastion: below 30% health you stand in the doorway — 15% damage reduction",
	"pants_bulwark_a": "Last bastion: below 30% health, 25% damage reduction — BUT Second Wind never triggers while worn",
	# ---- the 360 named gear uniques (armor family + armor/boots/charm) ----
	"warrior_helmet_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warrior_helmet_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the warded blow still builds a GRIT stack",
	"warrior_helmet_Ba": "The first enemy crit every 10s loses half its bite",
	"warrior_helmet_Bs": "The first enemy crit every 10s lands BLUNTED to a normal hit, and the blunted blow grants a free Grit stack",
	"warrior_helmet_Ca": "Evading a blow briefly EXPOSES the attacker",
	"warrior_helmet_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge refunds 1.5s of Whirlwind",
	"warrior_helmet_Da": "Your first hit on an unwounded enemy strikes 15% harder",
	"warrior_helmet_Ds": "Your first hit on an unwounded enemy strikes 25% harder, and the opening blow staggers",
	"warrior_helmet_Ea": "Overhealing pools into a small shield (up to 4% max health)",
	"warrior_helmet_Es": "Overhealing pools into a shield (up to 8% max health), and it pools at double rate while Berserk runs",
	"warrior_gloves_Aa": "Your hits fray the target's wards a little for 3s",
	"warrior_gloves_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"warrior_gloves_Ba": "Iron answer: 15% chance a melee attacker is counter-struck",
	"warrior_gloves_Bs": "Iron answer: 25% chance a melee attacker is counter-struck, and the counter-cut staggers",
	"warrior_gloves_Ca": "Every 8th basic attack cannot miss or be grazed",
	"warrior_gloves_Cs": "Every 5th basic attack cannot miss or be grazed, and the sure cut knocks harder",
	"warrior_gloves_Da": "Your crits nick — a lesser wound that burns for 3s",
	"warrior_gloves_Ds": "Your crits TEAR — a wound that keeps burning for 3s, and it tears deeper while Berserk runs",
	"warrior_gloves_Ea": "A little of your bulk lands with every hit",
	"warrior_gloves_Es": "Your bulk lands with every hit — bonus damage from your max health, doubled while Berserk runs",
	"warrior_pants_Aa": "Grounded: slows, roots and freezes on you run 20% shorter — BUT you receive 10% less healing",
	"warrior_pants_As": "Grounded: slows, roots and freezes on you run 30% shorter, and shaking off a CC grants a Grit stack",
	"warrior_pants_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"warrior_pants_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and a full-stack blow staggers the attacker",
	"warrior_pants_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"warrior_pants_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and abilities cast while slippery strike 20% harder",
	"warrior_pants_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"warrior_pants_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the commit returns 0.5s sooner",
	"warrior_pants_Ea": "Below 30% health, 10% damage reduction — BUT Grit's regen is halved",
	"warrior_pants_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold every blow feeds Grit",
	"archer_helmet_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"archer_helmet_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and a warded hit does not reset Second Wind's clock",
	"archer_helmet_Ba": "The first enemy crit every 10s loses half its bite",
	"archer_helmet_Bs": "The first enemy crit every 10s lands BLUNTED to a normal hit, and the blunted attacker is EXPOSED",
	"archer_helmet_Ca": "Evading a blow briefly EXPOSES the attacker",
	"archer_helmet_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge ticks the hunt rhythm by one",
	"archer_helmet_Da": "Your first hit on an unwounded enemy strikes 15% harder",
	"archer_helmet_Ds": "Your first hit on an unwounded enemy strikes 25% harder, and an opening shot feeds the hunt rhythm",
	"archer_helmet_Ea": "Overhealing pools into a small shield (up to 4% max health)",
	"archer_helmet_Es": "Overhealing pools into a shield (up to 8% max health), — Second Wind's overshoot pools too",
	"archer_gloves_Aa": "Your hits fray the target's wards a little for 3s",
	"archer_gloves_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"archer_gloves_Ba": "Iron answer: 15% chance a melee attacker is counter-struck",
	"archer_gloves_Bs": "Iron answer: 25% chance a melee attacker is counter-struck, as a point-blank arrow that shoves the attacker back",
	"archer_gloves_Ca": "Every 8th basic attack cannot miss or be grazed",
	"archer_gloves_Cs": "Every 5th basic attack cannot miss or be grazed, — the sure arrow flies true",
	"archer_gloves_Da": "Your crits nick — a lesser wound that burns for 3s",
	"archer_gloves_Ds": "Your crits TEAR — a wound that keeps burning for 3s, deeper on EXPOSED prey",
	"archer_gloves_Ea": "A little of your bulk lands with every hit",
	"archer_gloves_Es": "Your bulk lands with every hit — bonus damage from your max health, — Arrow Storm arrows each carry half of it",
	"archer_pants_Aa": "Grounded: slows, roots and freezes on you run 20% shorter — BUT you receive 10% less healing",
	"archer_pants_As": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC refunds 1s of Tumble",
	"archer_pants_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"archer_pants_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and at full stacks the hide toughens",
	"archer_pants_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"archer_pants_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and Tumble rolled while slippery re-arms its perfect window",
	"archer_pants_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"archer_pants_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and Tumble returns 0.5s sooner",
	"archer_pants_Ea": "Below 30% health, 10% damage reduction — BUT Second Wind never triggers while worn",
	"archer_pants_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold Tumble returns sooner",
	"assassin_helmet_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"assassin_helmet_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and a warded hit keeps the blood surge alive",
	"assassin_helmet_Ba": "The first enemy crit every 10s loses half its bite",
	"assassin_helmet_Bs": "The first enemy crit every 10s lands BLUNTED to a normal hit, and the blunted attacker is left bleeding",
	"assassin_helmet_Ca": "Evading a blow briefly EXPOSES the attacker",
	"assassin_helmet_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge extends a live Death Mark's window",
	"assassin_helmet_Da": "Your first hit on an unwounded enemy strikes 15% harder",
	"assassin_helmet_Ds": "Your first hit on an unwounded enemy strikes 25% harder, and an opening strike arms the blood surge",
	"assassin_helmet_Ea": "Overhealing pools into a small shield (up to 4% max health)",
	"assassin_helmet_Es": "Overhealing pools into a shield (up to 8% max health), and it pools at double rate while the surge runs",
	"assassin_gloves_Aa": "Your hits fray the target's wards a little for 3s",
	"assassin_gloves_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"assassin_gloves_Ba": "Iron answer: 15% chance a melee attacker is counter-struck",
	"assassin_gloves_Bs": "Iron answer: 25% chance a melee attacker is counter-struck, and a landed counter feeds the blood surge",
	"assassin_gloves_Ca": "Every 8th basic attack cannot miss or be grazed",
	"assassin_gloves_Cs": "Every 5th basic attack cannot miss or be grazed, and the sure Stab's surge runs longer",
	"assassin_gloves_Da": "Your crits nick — a lesser wound that burns for 3s",
	"assassin_gloves_Ds": "Your crits TEAR — a wound that keeps burning for 3s, ticking deeper on MARKED prey",
	"assassin_gloves_Ea": "A little of your bulk lands with every hit",
	"assassin_gloves_Es": "Your bulk lands with every hit — bonus damage from your max health, doubled while the blood surge runs",
	"assassin_pants_Aa": "Grounded: slows, roots and freezes on you run 20% shorter — BUT you receive 10% less healing",
	"assassin_pants_As": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC refunds 1s of Shadow Dash",
	"assassin_pants_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"assassin_pants_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and full stacks harden Elusive",
	"assassin_pants_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"assassin_pants_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and abilities cast while slippery strike 20% harder",
	"assassin_pants_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"assassin_pants_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the dash returns 0.5s sooner",
	"assassin_pants_Ea": "Below 30% health, 10% damage reduction — BUT Elusive's regen is halved",
	"assassin_pants_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the surge holds",
	"mage_helmet_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"mage_helmet_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the warded hit refunds 5 mana",
	"mage_helmet_Ba": "The first enemy crit every 10s loses half its bite",
	"mage_helmet_Bs": "The first enemy crit every 10s lands BLUNTED to a normal hit, and the blow refunds 1s of Blink",
	"mage_helmet_Ca": "Evading a blow briefly EXPOSES the attacker",
	"mage_helmet_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge grants 10 mana",
	"mage_helmet_Da": "Your first hit on an unwounded enemy strikes 15% harder",
	"mage_helmet_Ds": "Your first hit on an unwounded enemy strikes 25% harder, and an opening bolt cracks the ward",
	"mage_helmet_Ea": "Overhealing pools into a small shield (up to 4% max health)",
	"mage_helmet_Es": "Overhealing pools into a shield (up to 8% max health), — Frost Nova's restore overflow pools too",
	"mage_gloves_Aa": "Your hits fray the target's wards a little for 3s",
	"mage_gloves_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"mage_gloves_Ba": "Iron answer: 15% chance a melee attacker is counter-struck",
	"mage_gloves_Bs": "Iron answer: 25% chance a melee attacker is counter-struck, as an arcane snap that CHILLS the attacker",
	"mage_gloves_Ca": "Every 8th basic attack cannot miss or be grazed",
	"mage_gloves_Cs": "Every 5th basic attack cannot miss or be grazed, — the sure bolt cannot be slipped",
	"mage_gloves_Da": "Your crits nick — a lesser wound that burns for 3s",
	"mage_gloves_Ds": "Your crits TEAR — a wound that keeps burning for 3s, deeper on ward-cracked prey",
	"mage_gloves_Ea": "A little of your bulk lands with every hit",
	"mage_gloves_Es": "Your bulk lands with every hit — bonus damage from your max health, — it rides Meteor at full weight",
	"mage_pants_Aa": "Grounded: slows, roots and freezes on you run 20% shorter — BUT you receive 10% less healing",
	"mage_pants_As": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC restores mana",
	"mage_pants_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"mage_pants_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and full stacks deepen Blink's Arcane Ward",
	"mage_pants_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"mage_pants_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and abilities cast while slippery strike 20% harder",
	"mage_pants_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"mage_pants_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and Blink returns 0.5s sooner",
	"mage_pants_Ea": "Below 30% health, 10% damage reduction — BUT Frost Nova's restore is halved",
	"mage_pants_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold blows restore mana",
	"paladin_helmet_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"paladin_helmet_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the warded blow banks holy charge",
	"paladin_helmet_Ba": "The first enemy crit every 10s loses half its bite",
	"paladin_helmet_Bs": "The first enemy crit every 10s lands BLUNTED to a normal hit, and the blunted blow banks holy charge",
	"paladin_helmet_Ca": "Evading a blow briefly EXPOSES the attacker",
	"paladin_helmet_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge mends you",
	"paladin_helmet_Da": "Your first hit on an unwounded enemy strikes 15% harder",
	"paladin_helmet_Ds": "Your first hit on an unwounded enemy strikes 25% harder, and it opens harder in Retribution",
	"paladin_helmet_Ea": "Overhealing pools into a small shield (up to 4% max health)",
	"paladin_helmet_Es": "Overhealing pools into a shield (up to 8% max health), and it pools at double rate in Holy stance",
	"paladin_gloves_Aa": "Your hits fray the target's wards a little for 3s",
	"paladin_gloves_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"paladin_gloves_Ba": "Iron answer: 15% chance a melee attacker is counter-struck",
	"paladin_gloves_Bs": "Iron answer: 25% chance a melee attacker is counter-struck, as a smite that mends you 1%",
	"paladin_gloves_Ca": "Every 8th basic attack cannot miss or be grazed",
	"paladin_gloves_Cs": "Every 5th basic attack cannot miss or be grazed, and the sure Judgment mends 1%",
	"paladin_gloves_Da": "Your crits nick — a lesser wound that burns for 3s",
	"paladin_gloves_Ds": "Your crits TEAR — a wound that keeps burning for 3s, of holy fire, deeper in Retribution",
	"paladin_gloves_Ea": "A little of your bulk lands with every hit",
	"paladin_gloves_Es": "Your bulk lands with every hit — bonus damage from your max health, doubled while Aegis holds",
	"paladin_pants_Aa": "Grounded: slows, roots and freezes on you run 20% shorter — BUT you receive 10% less healing",
	"paladin_pants_As": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC banks holy charge",
	"paladin_pants_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"paladin_pants_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and full stacks brace the shield",
	"paladin_pants_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"paladin_pants_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and abilities cast while slippery strike 20% harder",
	"paladin_pants_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"paladin_pants_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the leap rearms sooner",
	"paladin_pants_Ea": "Below 30% health, 10% damage reduction — BUT your class regen is halved",
	"paladin_pants_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the Holy mend doubles",
	"warlock_helmet_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warlock_helmet_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and 3% of what the ward eats returns as life",
	"warlock_helmet_Ba": "The first enemy crit every 10s loses half its bite",
	"warlock_helmet_Bs": "The first enemy crit every 10s lands BLUNTED to a normal hit, and the blunted attacker is WITHERED",
	"warlock_helmet_Ca": "Evading a blow briefly EXPOSES the attacker",
	"warlock_helmet_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge extends every live hex",
	"warlock_helmet_Da": "Your first hit on an unwounded enemy strikes 15% harder",
	"warlock_helmet_Ds": "Your first hit on an unwounded enemy strikes 25% harder, and an opening bolt withers",
	"warlock_helmet_Ea": "Overhealing pools into a small shield (up to 4% max health)",
	"warlock_helmet_Es": "Overhealing pools into a shield (up to 8% max health), and it pools at double rate after Dark Pact",
	"warlock_gloves_Aa": "Your hits fray the target's wards a little for 3s",
	"warlock_gloves_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"warlock_gloves_Ba": "Iron answer: 15% chance a melee attacker is counter-struck",
	"warlock_gloves_Bs": "Iron answer: 25% chance a melee attacker is counter-struck, and the counter BINDS the attacker",
	"warlock_gloves_Ca": "Every 8th basic attack cannot miss or be grazed",
	"warlock_gloves_Cs": "Every 5th basic attack cannot miss or be grazed, and the sure bolt drains life",
	"warlock_gloves_Da": "Your crits nick — a lesser wound that burns for 3s",
	"warlock_gloves_Ds": "Your crits TEAR — a wound that keeps burning for 3s, ticking deeper on HEXED prey",
	"warlock_gloves_Ea": "A little of your bulk lands with every hit",
	"warlock_gloves_Es": "Your bulk lands with every hit — bonus damage from your max health, doubled for a spell after Dark Pact",
	"warlock_pants_Aa": "Grounded: slows, roots and freezes on you run 20% shorter — BUT you receive 10% less healing",
	"warlock_pants_As": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC refunds 3% max health",
	"warlock_pants_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"warlock_pants_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and full stacks steady the pact",
	"warlock_pants_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"warlock_pants_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and abilities cast while slippery strike 20% harder",
	"warlock_pants_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"warlock_pants_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the advance deepens every hex",
	"warlock_pants_Ea": "Below 30% health, 10% damage reduction — BUT Soulthirst is halved",
	"warlock_pants_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold blows repay in blood",
	"warrior_armor_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warrior_armor_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the warded blow builds Grit",
	"warrior_armor_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"warrior_armor_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and a full-stack blow staggers",
	"warrior_armor_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"warrior_armor_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow hastens Shield Bash",
	"warrior_armor_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"warrior_armor_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, and the harness's spikes stagger",
	"warrior_armor_Ea": "Below 30% health, 10% damage reduction — BUT Grit's regen is halved",
	"warrior_armor_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold blows mend you",
	"warrior_boots_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warrior_boots_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and warded ground feeds Grit",
	"warrior_boots_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"warrior_boots_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and the planted stance staggers attackers",
	"warrior_boots_Ca": "Evading a blow briefly EXPOSES the attacker",
	"warrior_boots_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge hastens Shield Bash",
	"warrior_boots_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"warrior_boots_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the charge returns sooner",
	"warrior_boots_Ea": "Below 30% health, 10% damage reduction — BUT Grit's regen is halved",
	"warrior_boots_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the ground holds you",
	"warrior_charm_Aa": "Your first hit on an unwounded enemy strikes 15% harder",
	"warrior_charm_As": "Your first hit on an unwounded enemy strikes 25% harder, and the banner's first blow staggers",
	"warrior_charm_Ba": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warrior_charm_Bs": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the sworn ward feeds Grit",
	"warrior_charm_Ca": "Your crits nick — a lesser wound that burns for 3s",
	"warrior_charm_Cs": "Your crits TEAR — a wound that keeps burning for 3s, deeper while Berserk runs",
	"warrior_charm_Da": "Evading a blow briefly EXPOSES the attacker",
	"warrior_charm_Ds": "Evading a blow EXPOSES the attacker for 3s, and the feint hastens Whirlwind",
	"warrior_charm_Ea": "Overhealing pools into a small shield (up to 4% max health) — BUT Grit's regen is halved",
	"warrior_charm_Es": "Overhealing pools into a shield (up to 8% max health), pooling double while Berserk runs",
	"archer_armor_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"archer_armor_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and a warded hit keeps Second Wind's clock",
	"archer_armor_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"archer_armor_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and the riveted plates hold",
	"archer_armor_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"archer_armor_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow ticks the hunt rhythm",
	"archer_armor_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"archer_armor_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, as barbs that throw the attacker back",
	"archer_armor_Ea": "Below 30% health, 10% damage reduction — BUT Second Wind never triggers while worn",
	"archer_armor_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the pelt mends you",
	"archer_boots_Aa": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"archer_boots_As": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and Tumble returns sooner",
	"archer_boots_Ba": "Evading a blow briefly EXPOSES the attacker",
	"archer_boots_Bs": "Evading a blow EXPOSES the attacker for 3s, and the dodge ticks the hunt rhythm",
	"archer_boots_Ca": "Your first hit on an unwounded enemy strikes 15% harder",
	"archer_boots_Cs": "Your first hit on an unwounded enemy strikes 25% harder, and the held shot feeds the rhythm",
	"archer_boots_Da": "Grounded: slows, roots and freezes on you run 20% shorter",
	"archer_boots_Ds": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC refunds Tumble",
	"archer_boots_Ea": "Below 30% health, 10% damage reduction — BUT Second Wind never triggers while worn",
	"archer_boots_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold Tumble hastens",
	"archer_charm_Aa": "Every 8th basic attack cannot miss or be grazed",
	"archer_charm_As": "Every 5th basic attack cannot miss or be grazed, and the perfect nock feeds the rhythm",
	"archer_charm_Ba": "Evading a blow briefly EXPOSES the attacker",
	"archer_charm_Bs": "Evading a blow EXPOSES the attacker for 3s, and the feather marks the attacker longer",
	"archer_charm_Ca": "Your first hit on an unwounded enemy strikes 15% harder",
	"archer_charm_Cs": "Your first hit on an unwounded enemy strikes 25% harder, harder on EXPOSED prey",
	"archer_charm_Da": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"archer_charm_Ds": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the bark keeps Second Wind's clock",
	"archer_charm_Ea": "Overhealing pools into a small shield (up to 4% max health) — BUT Second Wind never triggers while worn",
	"archer_charm_Es": "Overhealing pools into a shield (up to 8% max health), — the grove's endurance pools",
	"assassin_armor_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"assassin_armor_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and a warded hit feeds the surge",
	"assassin_armor_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"assassin_armor_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and a full-stack blow EXPOSES the attacker",
	"assassin_armor_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"assassin_armor_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow feeds the surge",
	"assassin_armor_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"assassin_armor_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, and the wrap's blades feed the surge",
	"assassin_armor_Ea": "Below 30% health, 10% damage reduction — BUT Elusive's regen is halved",
	"assassin_armor_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the shroud mends you",
	"assassin_boots_Aa": "Being hit leaves you slippery — +7% evasion for 2s",
	"assassin_boots_As": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow feeds the surge",
	"assassin_boots_Ba": "Your first hit on an unwounded enemy strikes 15% harder",
	"assassin_boots_Bs": "Your first hit on an unwounded enemy strikes 25% harder, and the pounce arms the surge",
	"assassin_boots_Ca": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"assassin_boots_Cs": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the dash returns sooner",
	"assassin_boots_Da": "Grounded: slows, roots and freezes on you run 20% shorter",
	"assassin_boots_Ds": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC refunds the dash",
	"assassin_boots_Ea": "Below 30% health, 10% damage reduction — BUT Elusive's regen is halved",
	"assassin_boots_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the surge holds",
	"assassin_charm_Aa": "Every 8th basic attack cannot miss or be grazed",
	"assassin_charm_As": "Every 5th basic attack cannot miss or be grazed, and the perfect cut feeds the surge",
	"assassin_charm_Ba": "Your hits fray the target's wards a little for 3s",
	"assassin_charm_Bs": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"assassin_charm_Ca": "Evading a blow briefly EXPOSES the attacker",
	"assassin_charm_Cs": "Evading a blow EXPOSES the attacker for 3s, and the dodge extends a live Death Mark",
	"assassin_charm_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"assassin_charm_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, and the sworn debt feeds the surge",
	"assassin_charm_Ea": "Overhealing pools into a small shield (up to 4% max health) — BUT Elusive's regen is halved",
	"assassin_charm_Es": "Overhealing pools into a shield (up to 8% max health), pooling double while the surge runs",
	"mage_armor_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"mage_armor_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the warded hit refunds mana",
	"mage_armor_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"mage_armor_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and full plates hasten Blink",
	"mage_armor_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"mage_armor_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow grants mana",
	"mage_armor_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"mage_armor_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, as star-fire that CHILLS the attacker",
	"mage_armor_Ea": "Below 30% health, 10% damage reduction — BUT Frost Nova's restore is halved",
	"mage_armor_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the clay mends you",
	"mage_boots_Aa": "Your first hit on an unwounded enemy strikes 15% harder",
	"mage_boots_As": "Your first hit on an unwounded enemy strikes 25% harder, and the opening cast cracks the ward",
	"mage_boots_Ba": "Evading a blow briefly EXPOSES the attacker",
	"mage_boots_Bs": "Evading a blow EXPOSES the attacker for 3s, and the dodge grants mana",
	"mage_boots_Ca": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"mage_boots_Cs": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and Blink returns sooner",
	"mage_boots_Da": "Grounded: slows, roots and freezes on you run 20% shorter",
	"mage_boots_Ds": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC restores mana",
	"mage_boots_Ea": "Below 30% health, 10% damage reduction — BUT Frost Nova's restore is halved",
	"mage_boots_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold blows restore mana",
	"mage_charm_Aa": "Your hits fray the target's wards a little for 3s",
	"mage_charm_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"mage_charm_Ba": "Your crits nick — a lesser wound that burns for 3s",
	"mage_charm_Bs": "Your crits TEAR — a wound that keeps burning for 3s, deeper on ward-cracked prey",
	"mage_charm_Ca": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"mage_charm_Cs": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the carried ward refunds mana",
	"mage_charm_Da": "Evading a blow briefly EXPOSES the attacker",
	"mage_charm_Ds": "Evading a blow EXPOSES the attacker for 3s, and the sigil pays the dodge in mana",
	"mage_charm_Ea": "Overhealing pools into a small shield (up to 4% max health) — BUT Frost Nova's restore is halved",
	"mage_charm_Es": "Overhealing pools into a shield (up to 8% max health), — the bloom's overflow pools",
	"paladin_armor_Aa": "Anchor: blows you take harden you a little — up to 2 stacks",
	"paladin_armor_As": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and full stacks bank holy charge",
	"paladin_armor_Ba": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"paladin_armor_Bs": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the warded blow banks holy charge",
	"paladin_armor_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"paladin_armor_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow mends the watcher",
	"paladin_armor_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"paladin_armor_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, burning harder in Retribution",
	"paladin_armor_Ea": "Below 30% health, 10% damage reduction — BUT your class regen is halved",
	"paladin_armor_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the Holy mend doubles",
	"paladin_boots_Aa": "Your first hit on an unwounded enemy strikes 15% harder",
	"paladin_boots_As": "Your first hit on an unwounded enemy strikes 25% harder, and the charge's first blow staggers",
	"paladin_boots_Ba": "Grounded: slows, roots and freezes on you run 20% shorter",
	"paladin_boots_Bs": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC banks holy charge",
	"paladin_boots_Ca": "Evading a blow briefly EXPOSES the attacker",
	"paladin_boots_Cs": "Evading a blow EXPOSES the attacker for 3s, and the watch mends the dodger",
	"paladin_boots_Da": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"paladin_boots_Ds": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the leap rearms sooner",
	"paladin_boots_Ea": "Below 30% health, 10% damage reduction — BUT your class regen is halved",
	"paladin_boots_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold the road mends you",
	"paladin_charm_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"paladin_charm_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the relic banks holy charge",
	"paladin_charm_Ba": "Your crits nick — a lesser wound that burns for 3s",
	"paladin_charm_Bs": "Your crits TEAR — a wound that keeps burning for 3s, of dawn-fire, deeper in Retribution",
	"paladin_charm_Ca": "Your hits fray the target's wards a little for 3s",
	"paladin_charm_Cs": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"paladin_charm_Da": "Evading a blow briefly EXPOSES the attacker",
	"paladin_charm_Ds": "Evading a blow EXPOSES the attacker for 3s, and the vow hastens Aegis",
	"paladin_charm_Ea": "Overhealing pools into a small shield (up to 4% max health) — BUT your class regen is halved",
	"paladin_charm_Es": "Overhealing pools into a shield (up to 8% max health), pooling double in Holy stance",
	"warlock_armor_Aa": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warlock_armor_As": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the ward pays you back in life",
	"warlock_armor_Ba": "Anchor: blows you take harden you a little — up to 2 stacks",
	"warlock_armor_Bs": "Anchor: every blow you take hardens you — flat damage reduction, up to 3 stacks, and a full-stack blow WITHERS",
	"warlock_armor_Ca": "Being hit leaves you slippery — +7% evasion for 2s",
	"warlock_armor_Cs": "Being hit leaves you slippery — +10% evasion for 2s, and slipping a blow deepens every hex",
	"warlock_armor_Da": "Iron answer: 15% chance a melee attacker is counter-struck",
	"warlock_armor_Ds": "Iron answer: 25% chance a melee attacker is counter-struck, and the script curses the attacker",
	"warlock_armor_Ea": "Below 30% health, 10% damage reduction — BUT Soulthirst is halved",
	"warlock_armor_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold blows repay in blood",
	"warlock_boots_Aa": "Your first hit on an unwounded enemy strikes 15% harder",
	"warlock_boots_As": "Your first hit on an unwounded enemy strikes 25% harder, and the opening curse withers",
	"warlock_boots_Ba": "Evading a blow briefly EXPOSES the attacker",
	"warlock_boots_Bs": "Evading a blow EXPOSES the attacker for 3s, and the dodge deepens every hex",
	"warlock_boots_Ca": "After your commit ability, your next damaging ability within 3s strikes 12% harder",
	"warlock_boots_Cs": "After your commit ability, your next damaging ability within 3s strikes 20% harder, and the advance deepens every hex",
	"warlock_boots_Da": "Grounded: slows, roots and freezes on you run 20% shorter",
	"warlock_boots_Ds": "Grounded: slows, roots and freezes on you run 30% shorter, and a shrugged CC refunds max health",
	"warlock_boots_Ea": "Below 30% health, 10% damage reduction — BUT Soulthirst is halved",
	"warlock_boots_Es": "Below 30% health you stand in the doorway — 15% damage reduction, and below the threshold blows repay in blood",
	"warlock_charm_Aa": "Your hits fray the target's wards a little for 3s",
	"warlock_charm_As": "Your hits unweave the target's wards, tearing armor open for 3s — and the tear stacks twice as deep",
	"warlock_charm_Ba": "Your crits nick — a lesser wound that burns for 3s",
	"warlock_charm_Bs": "Your crits TEAR — a wound that keeps burning for 3s, ticking deeper on HEXED prey",
	"warlock_charm_Ca": "Taking magic damage arms a lesser ward — 15% magic damage reduction for 2s (8s cd)",
	"warlock_charm_Cs": "Taking magic damage arms a ward — 30% magic damage reduction for 2s (8s cd), and the ash pays you back in life",
	"warlock_charm_Da": "Evading a blow briefly EXPOSES the attacker",
	"warlock_charm_Ds": "Evading a blow EXPOSES the attacker for 3s, and the cord deepens every hex",
	"warlock_charm_Ea": "Overhealing pools into a small shield (up to 4% max health) — BUT Soulthirst is halved",
	"warlock_charm_Es": "Overhealing pools into a shield (up to 8% max health), pooling double after Dark Pact",
}

# ------------------------------------------------------------------- gems ---
# A gem grants exactly ONE stat. Equipment C+ has sockets (C:1, B:1, A:2,
# S:3) — C gained its socket 2026-07-09 so ch4's first gem drops land on
# ch4's C-band gear the moment they appear, instead of idling until B.
# Synthesis: 3 gems of the same stat & level -> 1 gem of the next level.

const GEM_SLOTS := {"F": 0, "E": 0, "D": 0, "C": 1, "B": 1, "A": 2, "S": 3}
# A+ gear unlocks ONE dedicated SPECIAL slot that ONLY takes special gems
# (Balance.SPECIAL_GEM_STATS); every other socket is REGULAR and takes only
# regular gems (2026-07-08). So C/B = 1 regular; A = 1 regular + 1 special;
# S = 2 regular + 1 special. You can't stack specials (one slot, and one gem
# per stat across gear), and you can't skip them (a regular gem can't go in
# the special slot). Reforge-added sockets are always regular (this stays 1).
const GEM_SPECIAL_SLOTS := {"F": 0, "E": 0, "D": 0, "C": 0, "B": 0, "A": 1, "S": 1}


## How many SPECIAL-only slots this grade's gear carries (A+ = 1, else 0).
static func special_slots(grade: String) -> int:
	return int(GEM_SPECIAL_SLOTS.get(grade, 0))


## How many REGULAR-only slots (total sockets minus the special one).
static func regular_slots(grade: String) -> int:
	return int(GEM_SLOTS.get(grade, 0)) - int(GEM_SPECIAL_SLOTS.get(grade, 0))
const GEM_MAX_LEVEL := 10
# A vessel holds what it can bear (player rule, 2026-07-06): each grade
# caps the gem LEVEL it can socket — deep gems need endgame gear. C holds
# Lv2 (2026-07-09, with its new socket): exactly what ch4-5 actually drop
# (act-1 gem floor Lv1, elite Lv2 rolls, first-clear bonus Lv2).
const GEM_LEVEL_LIMIT := {"F": 0, "E": 0, "D": 0, "C": 2, "B": 3, "A": 6, "S": 10}

# stat -> [display name, base value per level-ish, color]
const GEM_STATS := {
	"atk_flat": {"name": "Ruby",      "base": 1.0,   "color": Color(1.0, 0.3, 0.3)},  # FLAT atk (+1/lvl-ish), NOT a % — a regular gem that doesn't scale, so stacking it can't runaway
	"hp_pct":   {"name": "Garnet",    "base": 0.025, "color": Color(0.9, 0.45, 0.45)},
	"crit":     {"name": "Topaz",     "base": 0.012, "color": Color(1.0, 0.8, 0.3)},
	"dmg_pct":  {"name": "Sunstone",  "base": 0.02,  "color": Color(1.0, 0.6, 0.2)},  # universal DAMAGE increase (special slot); replaced the crit-only crit_dmg gem
	"cdr":      {"name": "Sapphire",  "base": 0.01,  "color": Color(0.35, 0.55, 1.0)},
	"combo":    {"name": "Opal",      "base": 0.01,  "color": Color(0.85, 0.9, 1.0)},
	"physres":  {"name": "Onyx",      "base": 4.0,   "color": Color(0.5, 0.5, 0.6)},
	"magres":   {"name": "Lapis",     "base": 4.0,   "color": Color(0.4, 0.5, 0.9)},
	"physpen":  {"name": "Bloodstone", "base": 2.5,  "color": Color(0.7, 0.2, 0.3)},
	"magpen":   {"name": "Amethyst",  "base": 2.5,   "color": Color(0.7, 0.4, 0.95)},
	"eva":      {"name": "Jade",      "base": 0.008, "color": Color(0.4, 0.85, 0.5)},
	"dex":      {"name": "Amber",     "base": 2.0,   "color": Color(0.95, 0.7, 0.3)},
	"flat_dr":  {"name": "Tenacity",  "base": 0.005, "color": Color(0.55, 0.62, 0.72)},  # damage reduction (special) — replaced the DPS-dead greed gem; greed the STAT still exists, just no longer from gems
	"lifesteal": {"name": "Vampire Eye", "base": 0.006, "color": Color(0.8, 0.2, 0.5)},
}


static func make_gem(stat: String, lvl := 1) -> Dictionary:
	return {"gem": true, "stat": stat, "lvl": lvl}


static func random_gem(rng: RandomNumberGenerator, lvl := 1, allow_special := true) -> Dictionary:
	var keys := GEM_STATS.keys()
	if not allow_special:
		# Early chapters roll REGULAR stats only (Balance.special_gems_drop).
		keys = keys.filter(func(k: String) -> bool: return not (k in Balance.SPECIAL_GEM_STATS))
	return make_gem(keys[rng.randi_range(0, keys.size() - 1)], lvl)


# ------------------------------------------------------------------ bags ---
# The bag is carried capacity for everything NOT equipped: gear, GEM
# STACKS (one slot per stat+level, round 7) and consumables share its
# slots. Round 52: the hero equips UP TO Balance.MAX_BAGS bags and their
# slots SUM. Bags drop from bosses/elites (act-tiered) and stock cheap at
# merchants. Round 52b: capacity counts UNITS not kinds — every gem and
# consumable UNIT takes a slot (stacking is DISPLAY-only), so the curve is
# bumped one step to compensate. 2026-07-09 v2: HEALTH POTIONS occupy
# slots too (they stay a counter internally but count as units and render
# in the bag), so every tier grew +5 again (F 15 .. S 45, +5/tier).
# Capacity spans 1 bag (15) to 5xS (225). Stacking bags is the growth
# axis, not one bag.
const BAG_SLOTS := {"F": 15, "E": 20, "D": 25, "C": 30, "B": 35, "A": 40, "S": 45}
const BAG_NAMES := {
	"F": "Frayed Pouch", "E": "Patched Satchel", "D": "Soldier's Knapsack",
	"C": "Knight's Rucksack", "B": "Runed Haversack", "A": "Dragonhide Duffel",
	"S": "Emberforged Hold",
}


static func make_bag(grade: String) -> Dictionary:
	return {"kind": "bag", "grade": grade, "name": BAG_NAMES[grade],
		"slots": int(BAG_SLOTS[grade])}


static func bag_price(grade: String) -> int:
	return int(40.0 * GRADE_MULT[grade])


## The two Frayed Pouches every new hero starts with (Balance.STARTER_BAGS).
static func starter_bags() -> Array:
	var out: Array = []
	for g in Balance.STARTER_BAGS:
		out.append(make_bag(String(g)))
	return out


## Merchant buy price for a bag — QoL-cheap, flat per tier (Balance table).
static func bag_buy_price(grade: String) -> int:
	return int(Balance.BAG_BUY_PRICE.get(grade, 30))


# ----------------------------------------------------------- consumables ---
# Non-gear bag items ({"kind": "stone", ...}). The talent reset stone is
# the first; elites are the primary source (playtest round 6).

# Potions eligible for the room LOADOUT (2026-07-07 v2): slotted from
# the inventory, cycled with the potion_next bind, budgeted per room
# (Balance.potion_slots, chapter-banded; unassigned slots drink as health).
# Scrolls and stones stay inventory-clicked utilities.
# renewal_draught joined 2026-07-21: it shipped round 50 as a bag-only click
# and BYPASSED the room budget entirely (unlimited 30%-max heals, gold the
# only gate). Rule now: if it can slot in the rotation, it ALWAYS spends the
# room budget — bag click or Q alike (player_core._drink_gate).
const ROTATION_POTIONS := ["mana_potion", "elixir_might", "renewal_draught"]
static func make_reset_stone() -> Dictionary:
	return {"kind": "stone", "id": "reset_stone", "grade": "B",
		"name": "Stone of Unlearning",
		"desc": "Crush it to refund EVERY allocated talent point (attributes and substats) for reallocation."}


## The skill-tree twin of the reset stone: a manuscript scraped clean
## and rewritten — the tree forgets, you choose again. Elite drop,
## rarer than the stone (Balance.ELITE_TOME_CHANCE).
static func make_respec_tome() -> Dictionary:
	return {"kind": "stone", "id": "tree_tome", "grade": "B",
		"name": "Palimpsest of the Path",
		"desc": "Crush it to refund EVERY spent skill point — the tree forgets, you choose a new path."}


## Utility consumables (round 47) — bought from merchants, used from the
## bag. Distinct from the health-potion counter (that lives on the player).
static func make_mana_potion() -> Dictionary:
	return {"kind": "stone", "id": "mana_potion", "grade": "D",
		"name": "Mana Draught",
		"desc": "Restore %d%% of your MISSING mana." % int(Balance.MANA_POTION_FRAC * 100)}


static func make_elixir_might() -> Dictionary:
	return {"kind": "stone", "id": "elixir_might", "grade": "C",
		"name": "Elixir of Might",
		"desc": "+%d%% damage for %ds." % [int(Balance.ELIXIR_MIGHT_AMT * 100), int(Balance.ELIXIR_MIGHT_DUR)]}


static func make_recall_scroll() -> Dictionary:
	return {"kind": "stone", "id": "recall_scroll", "grade": "D",
		"name": "Scroll of Recall",
		"desc": "Whisk yourself back to the last safe room you rested in."}


static func make_elixir_ward() -> Dictionary:
	return {"kind": "stone", "id": "elixir_ward", "grade": "C",
		"name": "Elixir of Warding",
		"desc": "Cut incoming damage by %d%% for %ds. Quaff it before a heavy blow lands." % [int(Balance.ELIXIR_WARD_AMT * 100), int(Balance.ELIXIR_WARD_DUR)]}


static func make_renewal_draught() -> Dictionary:
	return {"kind": "stone", "id": "renewal_draught", "grade": "C",
		"name": "Draught of Renewal",
		"desc": "Instantly restore %d%% of your maximum health." % int(Balance.RENEWAL_HEAL_FRAC * 100)}


# ------------------------------------------------------------ quest items ---
# Bag riders with no use-click: they exist to be GIVEN (convo choices
# grant/collect them via "gain_item"/"lose_item"). Run-scoped — the
# purge in game_flow._wipe_chapter_flags deletes kind "quest" from the
# bag when the run ends, alongside the flags that earned them.
# Content modules author theirs in a QUEST_ITEMS const ({id: {name,
# desc, grade?}} — merged into Story.ALL_QUEST_ITEMS); base-game ones
# live in the match below.
static func make_quest_item(id: String) -> Dictionary:
	match id:
		"millers_hat":
			return {"kind": "quest", "id": "millers_hat", "grade": "C",
				"name": "The Miller's Hat",
				"desc": "Wide-brim, brown, heron feather — blue at the tip. A boy at the village edge is waiting on it."}
	var q: Dictionary = Story.ALL_QUEST_ITEMS.get(id, {})
	if q.is_empty():
		return {}
	var out := q.duplicate(true)
	out["kind"] = "quest"
	out["id"] = id
	if not out.has("grade"):
		out["grade"] = "C"
	return out


## The stat value a gem grants at its level (superlinear growth).
static func gem_value(gem: Dictionary) -> float:
	var base: float = GEM_STATS[gem["stat"]]["base"]
	var lvl: int = gem["lvl"]
	return base * lvl * (1.0 + 0.18 * (lvl - 1))


static func gem_title(gem: Dictionary) -> String:
	var info: Dictionary = GEM_STATS[gem["stat"]]
	var v := gem_value(gem)
	var val_txt := "+%d" % int(v) if gem["stat"] in FLAT_STATS else "+%d%%" % int(round(v * 100))
	return "%s Lv%d  (%s %s)" % [info["name"], gem["lvl"], STAT_LABEL[gem["stat"]], val_txt]


static func gem_color(gem: Dictionary) -> Color:
	return GEM_STATS[gem["stat"]]["color"]

# Every shape has a stat personality: a main-stat multiplier plus a substat BIAS.
#
# 2026-07-26 (player rule) — a shape NEVER GRANTS A STAT. The old `subs` table
# tacked flat bonus stats onto every rolled item, which meant a Shuriken's crit
# arrived free and OUTSIDE the grade's affix count: an S Shuriken showed six stat
# lines on a "3-substat" item, and the shape's stats couldn't be chased, quenched
# or traded away. A shape is now a WEIGHTING on the roll, in both axes:
#   * POOL WEIGHT   — a biased stat is `bias`x as LIKELY to be drawn
#   * MAGNITUDE     — when it does land it rolls `bias`x bigger, which also widens
#                     its quench band (stat_band), so a bad Shuriken can be
#                     quenched up toward a crit ceiling a Hammer can never reach
# 1.0 = neutral. Shapes with an empty bias carry their whole identity in `main`
# (a Claymore hits like a truck; Plate is bulk) — that was always true of them.
#
# Biased stats MUST exist in SUBSTATS or the bias is dead data (it can neither be
# drawn nor scaled). That retired the old `hp_flat` tack-on on Hammer/Treads —
# hp_flat is not in the pool; the pool's bulk stat is hp_pct.
# BREADTH COSTS DEPTH (2026-07-26, PROPOSALS/GEAR_SHAPE_MATRIX.md §3). Every
# shape spends the SAME budget — Sum(bias - 1.0) == SHAPE_BIAS_BUDGET — so the
# only thing that varies is how thinly it is spread. One stat leans hardest and
# quenches to the highest ceiling in the game; three stats each lean weakly. That
# is the whole trade: specialists reach further, generalists cover more. Stat
# COUNT is the only input — crit+pen pays exactly what crit+physres pays.
const SHAPE_BIAS_BUDGET := 0.60
const SHAPE_BIAS_ONE := 1.60      # sole stat — the highest cap available
const SHAPE_BIAS_TWO := 1.30      # each of two
const SHAPE_BIAS_THREE := 1.20    # each of three
const DEFAULT_STYLE := {"main": 1.0, "bias": {}}
const SHAPE_STYLE := {
	# ===================== WEAPONS — per class (matrix §5) =====================
	# Each class's five weapon shapes span all six stat groups. 2026-07-26: the
	# full weapon matrix landed with its art, so all six classes are wired here and
	# the pre-matrix weapon shapes drop to the LEGACY block below.
	# --- Warrior ---
	"Pike":          {"main": 1.0,  "bias": {"physpen": 1.60}, "tag": "penetration"},
	"Warblade":      {"main": 1.05, "bias": {"atk_pct": 1.30, "crit": 1.30}, "tag": "killing steel"},
	"Saber":         {"main": 0.9,  "bias": {"dex": 1.30, "eva": 1.30}, "tag": "fast and light"},
	"Bulwark Blade": {"main": 1.1,  "bias": {"physres": 1.20, "magres": 1.20, "hp_pct": 1.20}, "tag": "guarded"},
	"Claymore":      {"main": 1.4,  "bias": {}, "tag": "massive damage"},
	# --- Archer ---
	"Warbow":        {"main": 1.05, "bias": {"atk_pct": 1.60}, "tag": "raw draw"},
	"Longbow":       {"main": 0.95, "bias": {"crit": 1.30, "physpen": 1.30}, "tag": "punch-through"},
	"Hunting Bow":   {"main": 0.9,  "bias": {"dex": 1.30, "eva": 1.30}, "tag": "fast and light"},
	"Thornbow":      {"main": 1.05, "bias": {"physres": 1.20, "magres": 1.20, "hp_pct": 1.20}, "tag": "warded wood"},
	"Recurve":       {"main": 1.35, "bias": {}, "tag": "raw capacity"},
	# --- Assassin --- (Shuriken moved crit+dex -> crit+atk: Glasswing now owns finesse)
	"Stiletto":      {"main": 0.85, "bias": {"physpen": 1.60}, "tag": "find the gap"},
	"Shuriken":      {"main": 0.8,  "bias": {"crit": 1.30, "atk_pct": 1.30}, "tag": "thrown steel"},
	"Glasswing":     {"main": 0.8,  "bias": {"dex": 1.30, "eva": 1.30}, "tag": "fast and light"},
	"Warded Fang":   {"main": 1.0,  "bias": {"physres": 1.20, "magres": 1.20, "hp_pct": 1.20}, "tag": "parrying"},
	"Cleaver":       {"main": 1.35, "bias": {}, "tag": "brutal weight"},
	# --- Mage ---
	"Scepter":       {"main": 0.9,  "bias": {"magpen": 1.60}, "tag": "ward-borer"},
	"Starfocus":     {"main": 0.95, "bias": {"crit": 1.30, "atk_pct": 1.30}, "tag": "concentrated"},
	"Zephyr Rod":    {"main": 0.85, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "weightless"},
	"Bloomstaff":    {"main": 1.0,  "bias": {"hp_pct": 1.20, "VIT": 1.20, "magres": 1.20}, "tag": "living wood"},
	"Greatstaff":    {"main": 1.4,  "bias": {}, "tag": "raw capacity"},
	# --- Paladin ---
	"Lance":         {"main": 1.0,  "bias": {"magpen": 1.60}, "tag": "holy point"},
	"Oathflail":     {"main": 1.05, "bias": {"atk_pct": 1.30, "crit": 1.30}, "tag": "finds openings"},
	"Duelist's Blade": {"main": 0.9, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "fast and light"},
	"Aegis Mace":    {"main": 1.1,  "bias": {"physres": 1.20, "magres": 1.20, "hp_pct": 1.20}, "tag": "mace-and-shield"},
	"Warmaul":       {"main": 1.35, "bias": {}, "tag": "consecrated weight"},
	# --- Warlock ---
	"Grimoire":      {"main": 0.9,  "bias": {"magpen": 1.60}, "tag": "the written word"},
	"Hexblade":      {"main": 1.0,  "bias": {"atk_pct": 1.30, "crit": 1.30}, "tag": "cursed edge"},
	"Whisper Rod":   {"main": 0.85, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "drifting"},
	"Pactshield Codex": {"main": 1.1, "bias": {"physres": 1.20, "magres": 1.20, "hp_pct": 1.20}, "tag": "bound to protect"},
	"Grimheart Staff": {"main": 1.1, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "fuel reserve"},
	# (Legacy weapon shapes Blade/Edge/Fang/Kunai/Bow/Crossbow/Staff/Wand/Hammer/
	# Tome deleted 2026-07-26 — nothing references them now that S_GEAR dropped its
	# pinned nouns; the matrix set fully replaces them. Owner: not needed as saves.)
	# === HELMET / GLOVES / PANTS (matrix §5b, 2026-07-26) — the armor family on one
	# shared 5-profile coverage skeleton (A magic ward · B physical ward · C finesse
	# · D aggressor w/ on-type pen · E bulwark); only material + slot noun vary. ===
	# --- Warrior (pen=physpen) ---
	"Wardsteel Helm": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Ironwall Helm": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Skirmisher's Helm": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Reaver Helm": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Titan Helm": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Wardsteel Gauntlets": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Ironwall Gauntlets": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Skirmisher's Gauntlets": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Reaver Gauntlets": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Titan Gauntlets": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Wardsteel Legplates": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Ironwall Legplates": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Skirmisher's Legplates": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Reaver Legplates": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Titan Legplates": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	# --- Archer (pen=physpen) ---
	"Stormweave Hood": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Studded Hood": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Ranger's Hood": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Hunter's Hood": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Beastpelt Hood": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Stormweave Bracers": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Studded Bracers": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Ranger's Bracers": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Hunter's Bracers": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Beastpelt Bracers": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Stormweave Leggings": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Studded Leggings": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Ranger's Leggings": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Hunter's Leggings": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Beastpelt Leggings": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	# --- Assassin (pen=physpen) ---
	"Shadowveil Cowl": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Warded Cowl": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Gossamer Cowl": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Nightsilk Cowl": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Grave Cowl": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Shadowveil Grips": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Warded Grips": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Gossamer Grips": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Nightsilk Grips": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Grave Grips": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Shadowveil Wraps": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Warded Wraps": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Gossamer Wraps": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Nightsilk Wraps": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "physpen": 1.20}, "tag": "aggressor"},
	"Grave Wraps": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	# --- Mage (pen=magpen) ---
	"Silkward Circlet": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Runeplate Circlet": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Featherweave Circlet": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Starweave Circlet": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Earthen Circlet": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Silkward Handwraps": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Runeplate Handwraps": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Featherweave Handwraps": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Starweave Handwraps": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Earthen Handwraps": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Silkward Underleggings": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Runeplate Underleggings": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Featherweave Underleggings": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Starweave Underleggings": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Earthen Underleggings": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	# --- Paladin (pen=magpen) ---
	"Blessed Greathelm": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Templar Greathelm": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Vigil Greathelm": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Zealot Greathelm": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Sanctified Greathelm": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Blessed Gauntlets": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Templar Gauntlets": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Vigil Gauntlets": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Zealot Gauntlets": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Sanctified Gauntlets": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Blessed Legguards": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Templar Legguards": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Vigil Legguards": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Zealot Legguards": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Sanctified Legguards": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	# --- Warlock (pen=magpen) ---
	"Voidsilk Hood": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Bonemail Hood": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Shadeweave Hood": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Ruinweave Hood": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Bloodpact Hood": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Voidsilk Claws": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Bonemail Claws": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Shadeweave Claws": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Ruinweave Claws": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Bloodpact Claws": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	"Voidsilk Chausses": {"main": 1.00, "bias": {"magres": 1.60}, "tag": "spell ward"},
	"Bonemail Chausses": {"main": 1.05, "bias": {"physres": 1.30, "critres": 1.30}, "tag": "guarded"},
	"Shadeweave Chausses": {"main": 0.90, "bias": {"dex": 1.30, "eva": 1.30}, "tag": "nimble"},
	"Ruinweave Chausses": {"main": 0.95, "bias": {"atk_pct": 1.20, "crit": 1.20, "magpen": 1.20}, "tag": "aggressor"},
	"Bloodpact Chausses": {"main": 1.10, "bias": {"hp_pct": 1.30, "VIT": 1.30}, "tag": "bulwark"},
	# ===== ARMOR / BOOTS / CHARM matrix shapes (§5, migrated 2026-07-27) =====
	# The legacy shared shapes (Plate/Mail/.../Sigil) stay below for saved
	# items; they are no longer in SLOT_NAMES' union or CLASS_GEAR.
	# --- Warrior ---
	"Wardsteel Plate": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Ironwall Plate": {"main": 1.05, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Skirmisher's Halfplate": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Bloodforged Harness": {"main": 0.95, "bias": {"atk_pct": 1.2, "crit": 1.2, "physpen": 1.2}, "tag": "aggressor"},
	"Titanplate": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Wardstep Greaves": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Sabatons": {"main": 1.05, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Skirmisher's Boots": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Reaver Treads": {"main": 0.95, "bias": {"atk_pct": 1.2, "crit": 1.2, "physpen": 1.2}, "tag": "aggressor"},
	"Anchorplate": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Warbanner": {"main": 0.9, "bias": {"atk_pct": 1.6}, "tag": "aggressor"},
	"Oath Sigil": {"main": 1.0, "bias": {"physres": 1.3, "magres": 1.3}, "tag": "guarded"},
	"Butcher's Token": {"main": 0.9, "bias": {"crit": 1.3, "physpen": 1.3}, "tag": "aggressor"},
	"Duelist's Knot": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Heart of the Wall": {"main": 1.1, "bias": {"hp_pct": 1.2, "VIT": 1.2, "critres": 1.2}, "tag": "bulk"},
	# --- Archer ---
	"Stormweave Jerkin": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Studded Brigandine": {"main": 1.05, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Ranger's Leathers": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Hunter's Harness": {"main": 0.95, "bias": {"atk_pct": 1.2, "crit": 1.2, "physpen": 1.2}, "tag": "aggressor"},
	"Beastpelt": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Piercer's Cleats": {"main": 0.9, "bias": {"physpen": 1.6}, "tag": "aggressor"},
	"Windstriders": {"main": 0.9, "bias": {"eva": 1.3, "dex": 1.3}, "tag": "fast and light"},
	"Marksman's Stance": {"main": 0.95, "bias": {"crit": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Wardedsole": {"main": 1.05, "bias": {"physres": 1.2, "magres": 1.2, "critres": 1.2}, "tag": "guarded"},
	"Trailboots": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Fletcher's Token": {"main": 0.85, "bias": {"crit": 1.6}, "tag": "aggressor"},
	"Windfeather": {"main": 0.9, "bias": {"eva": 1.3, "dex": 1.3}, "tag": "fast and light"},
	"Hunter's Totem": {"main": 0.9, "bias": {"atk_pct": 1.3, "physpen": 1.3}, "tag": "aggressor"},
	"Stonebark Ward": {"main": 1.0, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Greenheart Idol": {"main": 1.1, "bias": {"hp_pct": 1.2, "VIT": 1.2, "magres": 1.2}, "tag": "bulk"},
	# --- Assassin ---
	"Shadowveil Cloak": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Warded Mantle": {"main": 1.05, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Gossamer Cloak": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Nightsilk Wrap": {"main": 0.95, "bias": {"physpen": 1.2, "atk_pct": 1.2, "crit": 1.2}, "tag": "aggressor"},
	"Verdant Shroud": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Slipsteps": {"main": 0.9, "bias": {"eva": 1.6}, "tag": "fast and light"},
	"Prowlers": {"main": 0.9, "bias": {"crit": 1.3, "dex": 1.3}, "tag": "fast and light"},
	"Venomtread": {"main": 0.95, "bias": {"physpen": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Ironsole Wraps": {"main": 1.05, "bias": {"physres": 1.2, "magres": 1.2, "critres": 1.2}, "tag": "guarded"},
	"Grave Treads": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Killer's Mark": {"main": 0.85, "bias": {"crit": 1.6}, "tag": "aggressor"},
	"Poisoner's Vial": {"main": 0.85, "bias": {"physpen": 1.6}, "tag": "aggressor"},
	"Ghostlight Charm": {"main": 0.9, "bias": {"eva": 1.3, "dex": 1.3}, "tag": "fast and light"},
	"Bloodoath Cord": {"main": 0.95, "bias": {"atk_pct": 1.3, "physres": 1.3}, "tag": "guarded"},
	"Wraithbone Fetish": {"main": 1.1, "bias": {"hp_pct": 1.2, "VIT": 1.2, "magres": 1.2}, "tag": "bulk"},
	# --- Mage ---
	"Silk Vestments": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Runeplate Robe": {"main": 1.05, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Featherweave Robe": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Starweave Robe": {"main": 0.95, "bias": {"atk_pct": 1.2, "crit": 1.2, "magpen": 1.2}, "tag": "aggressor"},
	"Earthen Robe": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Starstep": {"main": 0.85, "bias": {"crit": 1.6}, "tag": "aggressor"},
	"Levitation Slippers": {"main": 0.9, "bias": {"eva": 1.3, "dex": 1.3}, "tag": "fast and light"},
	"Sigil Sandals": {"main": 0.95, "bias": {"magpen": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Wardstone Shoes": {"main": 1.05, "bias": {"physres": 1.2, "magres": 1.2, "critres": 1.2}, "tag": "guarded"},
	"Rootbound Sandals": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Arcane Orb": {"main": 0.85, "bias": {"magpen": 1.6}, "tag": "aggressor"},
	"Starshard": {"main": 0.9, "bias": {"crit": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Aegis Crystal": {"main": 1.0, "bias": {"physres": 1.3, "magres": 1.3}, "tag": "guarded"},
	"Zephyr Sigil": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Lifebloom Pendant": {"main": 1.1, "bias": {"hp_pct": 1.2, "VIT": 1.2, "critres": 1.2}, "tag": "bulk"},
	# --- Paladin ---
	"Templar Plate": {"main": 1.05, "bias": {"physres": 1.6}, "tag": "guarded"},
	"Blessed Plate": {"main": 1.0, "bias": {"magres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Vigil Halfplate": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Zealot Harness": {"main": 0.95, "bias": {"atk_pct": 1.2, "crit": 1.2, "magpen": 1.2}, "tag": "aggressor"},
	"Sanctified Bulwark": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Zealot's Cleats": {"main": 0.85, "bias": {"crit": 1.6}, "tag": "aggressor"},
	"Sabatons of the Oath": {"main": 1.05, "bias": {"physres": 1.3, "magres": 1.3}, "tag": "guarded"},
	"Vigil Steps": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Radiant Greaves": {"main": 0.95, "bias": {"magpen": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Pilgrim's Resolve": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Reliquary": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Sunburst Icon": {"main": 0.9, "bias": {"atk_pct": 1.3, "crit": 1.3}, "tag": "aggressor"},
	"Judgment Sigil": {"main": 0.85, "bias": {"magpen": 1.6}, "tag": "aggressor"},
	"Swiftvow Cord": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Oathkeeper's Seal": {"main": 1.1, "bias": {"hp_pct": 1.2, "VIT": 1.2, "physres": 1.2}, "tag": "bulk"},
	# --- Warlock ---
	"Voidsilk Robe": {"main": 1.0, "bias": {"magres": 1.6}, "tag": "warded"},
	"Bonemail": {"main": 1.05, "bias": {"physres": 1.3, "critres": 1.3}, "tag": "guarded"},
	"Shadeweave Robe": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Ruinweave": {"main": 0.95, "bias": {"atk_pct": 1.2, "crit": 1.2, "magpen": 1.2}, "tag": "aggressor"},
	"Bloodpact Vestment": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Ruinstep": {"main": 0.85, "bias": {"crit": 1.6}, "tag": "aggressor"},
	"Shadowstep Wraps": {"main": 0.9, "bias": {"eva": 1.3, "dex": 1.3}, "tag": "fast and light"},
	"Hexcarved Treads": {"main": 0.95, "bias": {"magpen": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Bonewalkers": {"main": 1.05, "bias": {"physres": 1.2, "magres": 1.2, "critres": 1.2}, "tag": "guarded"},
	"Gravebound Boots": {"main": 1.1, "bias": {"hp_pct": 1.3, "VIT": 1.3}, "tag": "bulk"},
	"Soul Fetish": {"main": 0.85, "bias": {"magpen": 1.6}, "tag": "aggressor"},
	"Cursed Idol": {"main": 0.9, "bias": {"crit": 1.3, "atk_pct": 1.3}, "tag": "aggressor"},
	"Ward of Ash": {"main": 1.0, "bias": {"physres": 1.3, "magres": 1.3}, "tag": "guarded"},
	"Umbral Cord": {"main": 0.9, "bias": {"dex": 1.3, "eva": 1.3}, "tag": "fast and light"},
	"Heartcage": {"main": 1.1, "bias": {"hp_pct": 1.2, "VIT": 1.2, "critres": 1.2}, "tag": "bulk"},
	# ===================== ARMOR / BOOTS / CHARM (LEGACY back-compat) ========
	"Plate":    {"main": 1.15, "bias": {}, "tag": "bulk"},
	"Mail":     {"main": 0.9,  "bias": {"eva": 1.60}, "tag": "elusive"},
	"Guard":    {"main": 0.95, "bias": {"physres": 1.60}, "tag": "physical resistance"},
	"Boots":    {"main": 1.0,  "bias": {}, "tag": "balanced"},
	"Striders": {"main": 0.9,  "bias": {"eva": 1.60}, "tag": "elusive"},
	"Treads":   {"main": 0.85, "bias": {"hp_pct": 1.60}, "tag": "sturdy"},
	"Charm":    {"main": 1.0,  "bias": {}, "tag": "balanced"},
	"Talisman": {"main": 0.85, "bias": {"atk_pct": 1.60}, "tag": "power"},
	"Sigil":    {"main": 0.85, "bias": {"crit": 1.60}, "tag": "crit"},
}


## The bias every stat on an N-stat shape carries, per the flat budget above.
static func bias_for_count(n: int) -> float:
	match n:
		1: return SHAPE_BIAS_ONE
		2: return SHAPE_BIAS_TWO
		3: return SHAPE_BIAS_THREE
	return 1.0 + SHAPE_BIAS_BUDGET / float(maxi(1, n))


## Draw ONE stat from `pool` with shape weighting and REMOVE it (draw without
## replacement). A stat with bias b is b times as likely as a neutral one.
static func _weighted_take(pool: Array, bias: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for s in pool:
		total += float(bias.get(s, 1.0))
	var r: float = rng.randf() * total
	var chosen: String = String(pool[pool.size() - 1])   # float-drift fallback
	for s in pool:
		r -= float(bias.get(s, 1.0))
		if r <= 0.0:
			chosen = String(s)
			break
	pool.erase(chosen)
	return chosen


## This shape's bias multiplier for `stat` (1.0 = neutral). Single reader so the
## roll, the reforge and the quench BAND can never disagree about a stat's ceiling.
static func shape_bias(noun: String, stat: String) -> float:
	var style: Dictionary = SHAPE_STYLE.get(noun, DEFAULT_STYLE)
	var bias: Dictionary = style.get("bias", {})
	return float(bias.get(stat, 1.0))

# Substat pool: stat -> base roll (scaled a little by grade).
# Mirror of Classes.CLASSES[cls]["dmg_type"] — items.gd must not preload
# classes.gd (content modules preload items early).
const CLASSES_DMG_TYPE := {
	"warrior": "phys", "archer": "phys", "assassin": "phys",
	"paladin": "magic", "mage": "magic", "warlock": "magic",
}

# The SPECIAL stats (Haste/Lifesteal/Combo/Tenacity/Dmg%) are deliberately
# ABSENT: they are gem-only (Balance.SPECIAL_GEM_STATS) — gems are the
# gateway to off-build stats, and each item sockets at most one special
# gem. MOVEMENT SPEED is absent for a harder reason: it is sovereign —
# only terrain and abilities may touch it (dodging is life or death;
# player rule 2026-07-06). Supersedes round 43's B-gate.
# MP_FLAT IS NOT A GEAR STAT (2026-07-26, player rule). Mana is a CLASS resource:
# it comes from the class's base pool and its per-level growth, nothing else. No
# attribute ever converted to it either (Classes.ATTR_SCALE has no mp_flat entry —
# the branch in Classes' attribute blurb is dead), so as a substat it was a flat
# handout that no build could scale, chase or care about: dead on the assassin
# (a kit that costs 0 MP end to end) and near-dead on warrior/archer. Its label
# and FLAT_STATS entry stay so pre-2026-07-26 gear still DISPLAYS its MP; that
# stat is now unquenchable (stat_band returns a degenerate band for anything
# outside this pool) and reforging the slot rolls it into a live stat.
const SUBSTATS := {
	"atk_pct": 0.05, "hp_pct": 0.06, "crit": 0.03,
	"VIT": 3.0,
	"physres": 9.0, "magres": 9.0, "critres": 6.0, "eva": 0.02, "dex": 4.0,
	"physpen": 5.0, "magpen": 5.0,
}

const STAT_LABEL := {
	"atk_flat": "ATK", "hp_flat": "HP", "atk_pct": "ATK%", "hp_pct": "HP%",
	"STR": "STR", "AGI": "AGI", "INT": "INT", "VIT": "VIT",
	"crit": "Crit", "crit_dmg": "CritDmg", "dmg_pct": "Damage", "cdr": "Haste", "speed_pct": "Speed",
	"lifesteal": "Lifesteal", "greed": "Greed", "flat_dr": "Tenacity", "mp_flat": "MP",
	"physres": "PhysRes", "magres": "MagRes", "critres": "CritRes",
	"eva": "EVA", "dex": "DEX", "physpen": "PhysPen", "magpen": "MagPen",
	"combo": "Combo",
}

# Stats measured in flat points rather than percent (for display).
const FLAT_STATS := ["atk_flat", "hp_flat", "mp_flat", "physres", "magres", "critres", "dex", "physpen", "magpen", "STR", "AGI", "INT", "VIT"]

# Chest tiers -> grade weights.
const CHEST_TIERS := {
	"wood":   {"sprite": "chest_wood",   "weights": {"F": 40, "E": 30, "D": 20, "C": 10}},
	"silver": {"sprite": "chest_silver", "weights": {"D": 30, "C": 35, "B": 25, "A": 10}},
	"gold":   {"sprite": "chest_gold",   "weights": {"B": 35, "A": 40, "S": 25}},
}


static func roll_grade(tier: String, rng: RandomNumberGenerator, cap := "S") -> String:
	var weights: Dictionary = CHEST_TIERS[tier]["weights"]
	var total := 0
	for w in weights.values():
		total += w
	var pick := rng.randi_range(1, total)
	for grade in weights:
		pick -= weights[grade]
		if pick <= 0:
			# Act loot ceiling (game.loot_cap): anything rolled above the
			# chapter's cap collapses TO the cap — a gold chest in Act 1
			# pays the act's best, never endgame gear.
			if GRADES.find(String(grade)) > GRADES.find(cap):
				return cap
			return grade
	return "F"


static func roll_item(tier: String, rng: RandomNumberGenerator, cls := "", cap := "S") -> Dictionary:
	var grade := roll_grade(tier, rng, cap)
	var slot := _roll_slot(grade, rng)
	return roll_item_of(slot, grade, rng, cls)


## Pick a gear slot. S-tier down-weights WEAPON (Balance.S_WEAPON_DROP_WEIGHT):
## the class legendary weapon carries the endgame passive, so it is the single
## rarest slot. Sub-S rolls stay uniform. All gear channels funnel through here.
static func _roll_slot(grade: String, rng: RandomNumberGenerator) -> String:
	if grade != "S":
		return SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
	var total := 0.0
	var cum: Array = []
	for s in SLOTS:
		total += Balance.S_WEAPON_DROP_WEIGHT if s == "weapon" else 1.0
		cum.append(total)
	var pick := rng.randf() * total
	for i in SLOTS.size():
		if pick <= float(cum[i]):
			return SLOTS[i]
	return SLOTS[SLOTS.size() - 1]


## One gear item of an exact grade (slot picked via _roll_slot). Used by the
## boss gear channel and the act-appearance shop roll. `act` feeds the named
## drop channels (0 = generic only — see roll_item_of).
static func roll_gear_of_grade(grade: String, rng: RandomNumberGenerator, cls := "", act := 0) -> Dictionary:
	return roll_item_of(_roll_slot(grade, rng), grade, rng, cls, "", act)


## The chapter's act, for the named-unique drop gates. CHAPTER_ECON is the
## source (Balance-only — items.gd must not pull Story/content in); an unknown
## chid (endgame rooms pass their own act explicitly) is act 1 = generic only.
static func chapter_act(chid: String) -> int:
	return int(Balance.CHAPTER_ECON.get(chid, {}).get("act", 1))


## One GENERAL gear item for a chapter (chest / shop-filler / spoils / gamble):
## grade from the chapter's general band, slot via _roll_slot. (2026-07-09)
## Derives the chapter's act so named uniques can surface where the split allows.
static func roll_chapter_gear(chid: String, rng: RandomNumberGenerator, cls := "") -> Dictionary:
	return roll_gear_of_grade(Balance.roll_weighted_grade(Balance.gear_weights(chid), rng), rng, cls, chapter_act(chid))


## Grade a SHOP stock slot rolls — the chapter's GENERAL band table (2026-07-09).
## `cap` is accepted for call-site compatibility but the band already bounds it.
static func roll_shop_grade(chid: String, rng: RandomNumberGenerator, _cap := "") -> String:
	return Balance.roll_weighted_grade(Balance.gear_weights(chid), rng)


## The BOSS gear drop channel (2026-07-09): one BOSS_GEAR_CHANCE roll for whether
## gear drops at all, then a weighted grade from the chapter's boss band. "" = none.
static func roll_boss_gear_grade(chid: String, rng: RandomNumberGenerator) -> String:
	if rng.randf() >= Balance.BOSS_GEAR_CHANCE:
		return ""
	return Balance.roll_weighted_grade(Balance.boss_weights(chid), rng)


## The class's signature weapon shape — its first matrix weapon. Used by the dev
## gear sets and class swaps so a mage never holds a warrior's shape. (S_GEAR no
## longer pins a noun, so this reads the arsenal directly.)
static func class_weapon_noun(cls: String) -> String:
	var arsenal: Array = CLASS_WEAPONS.get(cls, [])
	return String(arsenal[0]) if not arsenal.is_empty() else "Warblade"


## `act` gates the NAMED drop channels (2026-07-27 drop split, PROPOSALS/
## GEAR_UNIQUE_PASSIVES.md §9). 0 (the default — tests, dev paths, nested
## constructor rolls) rolls pure generics: an S is now a prefixed generic with
## NO passive, exactly like every other grade. Player-facing loot channels pass
## the real act (Story.act_of / CHAPTER_ECON) so named gear can surface.
static func roll_item_of(slot: String, grade: String, rng: RandomNumberGenerator, cls := "", force_noun := "", act := 0) -> Dictionary:
	# --- named channels first: the roll lands as a NAMED piece instead of a
	# generic. Named A unique: Act 2+ weapons. Named S unique: Act 3+ weapons
	# (rarest). Class LEGENDARY (S_GEAR): Act 2+ S of any slot — its weapon
	# passive still sleeps behind the awakening quest; unique passives are
	# live on pickup (owner call, §10.1).
	if cls != "" and force_noun == "" and act > 0:
		if grade in ["A", "S"]:
			# Slot-generic (2026-07-27): the pool filters by SLOT, so the channel
			# lights up per slot exactly when that slot's uniques enter the table
			# (weapons today; helmet/gloves/pants when the art pass names theirs).
			var gate_act: int = Balance.UNIQUE_A_ACT if grade == "A" else Balance.UNIQUE_S_ACT
			var chance: float = Balance.UNIQUE_A_CHANCE if grade == "A" else Balance.UNIQUE_S_CHANCE
			if act >= gate_act and rng.randf() < chance:
				var pool := uniques_of(cls, grade, slot)
				if not pool.is_empty():
					return make_unique(pool[rng.randi_range(0, pool.size() - 1)], rng)
		# (2026-07-27, owner call) The LEGENDARY channel is RETIRED: no separate
		# legendary tier, no awakening questline — the six flagship passives
		# live on their fitting named-S uniques instead (kingsblade on
		# Crownfall, windward on Tempest Yew, wellspring on Firmament,
		# mirrorstep on Pale Flight, dawnbreaker on Dawnfall, voidmaw on The
		# Book That Remembers You). Old-save legendaries keep working: their
		# stored passive id is live and the dormant gate is gone.

	var mult: float = GRADE_MULT[grade]
	var noun_list: Array = SLOT_NAMES[slot]
	if cls != "":
		if slot == "weapon" and CLASS_WEAPONS.has(cls):
			noun_list = CLASS_WEAPONS[cls]
		elif CLASS_GEAR.has(cls) and CLASS_GEAR[cls].has(slot):
			noun_list = CLASS_GEAR[cls][slot]  # per-class helmet/gloves/pants (§5b)
	var noun: String = force_noun if force_noun != "" else noun_list[rng.randi_range(0, noun_list.size() - 1)]
	var style: Dictionary = SHAPE_STYLE.get(noun, DEFAULT_STYLE)

	# The main is the class's primary attribute, guaranteed (2026-07-06).
	var primary := String(CLASS_PRIMARY.get(cls, "STR"))
	var main := {primary: snappedf(SLOT_MAIN_BUDGET[slot] * mult * style["main"]
		* rng.randf_range(0.9, 1.15), 0.01)}
	var subs := roll_subs(grade, noun, cls, rng)

	var item := {
		"slot": slot, "grade": grade, "noun": noun,
		"main": main, "subs": subs, "plus": 0,
		"gem_slots": GEM_SLOTS[grade], "gems": [],
	}
	if cls != "":
		item["cls"] = cls  # class-locked: only this class may EQUIP it
	var prefix_pool: Array = PREFIXES[grade]
	item["name"] = "%s %s" % [prefix_pool[rng.randi_range(0, prefix_pool.size() - 1)], item["noun"]]
	# (2026-07-27) Generic S no longer auto-names itself S_GEAR: the legendary
	# is a rare named roll through the channel above, and "generic S" finally
	# exists — top rolls, plain prefixed name, NO passive (the §7 target model).
	return item


## The named uniques of one class at one grade (drop pool for the named
## channel). `slot` narrows the pool ("" = all slots — codex/dev listings).
static func uniques_of(cls: String, grade: String, slot := "") -> Array:
	var out: Array = []
	for u in UNIQUES:
		if String(u["cls"]) == cls and String(u["grade"]) == grade \
				and (slot == "" or String(u["slot"]) == slot):
			out.append(u)
	return out


## Build a named unique from its UNIQUES row: generic-grade power on the row's
## fixed noun PLUS the identity — name, own art, signature passive. The passive
## is LIVE on pickup: the awakening quest stays legendary-exclusive (owner call).
static func make_unique(u: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var item := roll_item_of(String(u["slot"]), String(u["grade"]), rng,
		String(u["cls"]), String(u["noun"]))
	item["name"] = String(u["name"])
	item["art"] = String(u["art"])
	item["passive"] = String(u["passive"])
	return item


# (make_legendary deleted 2026-07-27 with the legendary tier — see the
# retired-channel note in roll_item_of. S_GEAR below stays as the historical
# name record; nothing rolls or reads it at drop time anymore.)


## How many RANDOM substats a grade rolls. Formula gives F/E/D:0, C/B:1, A:2; S is
## overridden to Balance.S_SUB_COUNT (its legendary stat weight, all random now that
## pinned synergy subs are gone). Single source for roll_subs AND the dps bench.
static func sub_count_for(grade: String) -> int:
	if grade == "S":
		return Balance.S_SUB_COUNT
	return maxi(0, (GRADES.find(grade) - 1) / 2)


## Roll an item's substat set: `sub_count` random affixes for the grade
## (class-appropriate, endgame stats gated below B) plus the shape's
## guaranteed personality stats. Shared by drops (roll_item_of) and the
## reforge bench (reforge_affixes).
static func roll_subs(grade: String, noun: String, cls: String, rng: RandomNumberGenerator) -> Dictionary:
	var mult: float = GRADE_MULT[grade]
	var style: Dictionary = SHAPE_STYLE.get(noun, DEFAULT_STYLE)
	var bias: Dictionary = style.get("bias", {})
	var sub_count := sub_count_for(grade)
	var subs := {}
	var pool := SUBSTATS.keys()
	# Every grade below S rolls the FULL pool (2026-07-17, supersedes round 15's
	# "no dead stats"). Round 15 assumed a class's damage type never changes —
	# once a rune can reroute it, the off-type pen is DORMANT, not dead, and the
	# bench is the player's to fix. S is the exception the rule now names: a
	# legendary's FIRST roll is guaranteed class-usable (what the player reforges
	# it into afterward is their own risk).
	# (Special stats — Haste/Lifesteal/Combo/Tenacity/Dmg% — aren't in the pool at
	# all since 2026-07-06: gem-only, superseding round 43's B-gate.)
	if grade == "S" and cls != "" and CLASSES_DMG_TYPE.has(cls):
		pool.erase("physpen" if CLASSES_DMG_TYPE[cls] == "magic" else "magpen")
	# Shape-WEIGHTED draw without replacement (2026-07-26): a Shuriken pulls crit
	# more often than a Hammer does, and rolls it bigger when it lands. No stat is
	# ever GRANTED — a Shuriken that draws three defensive subs is just a bad
	# Shuriken, and the bench is the player's way out.
	var count := mini(sub_count, pool.size())
	for _i in count:
		var stat := _weighted_take(pool, bias, rng)
		var b: float = float(bias.get(stat, 1.0))
		subs[stat] = snappedf(SUBSTATS[stat] * b * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	return subs


# ------------------------------------------------------------ reforge bench ---
# Deterministic-ish crafting on OWNED gear (gold sink). FOUR crafts: reroll one
# substat's magnitude, reroll the whole affix set, add a gem socket (C+ only —
# C joined 2026-07-09, see can_add_socket — capped), or quench (reroll a stat's
# band position, keeping the higher). Costs scale with grade.
const REFORGE_COST := {"F": 120, "E": 200, "D": 350, "C": 600, "B": 1200, "A": 2200, "S": 3500}  # 2026-07-13: affix reroll = base x2 (S = 7k/pull). A RANDOM full-set reroll, so not priced to the moon — the RNG is already a wall.
const MAX_SOCKETS := 4   # every grade may reforge exactly ONE extra socket; S (natural 3) can reach 4

## Gold cost of a reforge on this item. kind: "sub" | "affix" | "socket".
## (Quench has its own escalating price — see quench_cost.)
static func reforge_cost(item: Dictionary, kind: String) -> int:
	var base: int = REFORGE_COST.get(String(item["grade"]), 100)
	match kind:
		"affix": return base * 2
		"socket": return int(Balance.ADD_SOCKET_COST.get(String(item["grade"]), base * 3))
		_: return base


## Reroll the MAGNITUDE of one existing substat (keeps which stat it is).
static func reforge_sub(item: Dictionary, stat: String, rng: RandomNumberGenerator) -> void:
	if not item.get("subs", {}).has(stat):
		return
	var mult: float = GRADE_MULT[item["grade"]]
	if SUBSTATS.has(stat):
		# Shape bias applies here too. Before 2026-07-26 this reroll silently DROPPED
		# the shape's contribution (it re-rolled the bare pool value while stat_band
		# still counted a shape part) — a bench-side downgrade trap. A multiplier has
		# no additive part to lose, so roll/reforge/band now agree by construction.
		var b: float = shape_bias(String(item.get("noun", "")), stat)
		item["subs"][stat] = snappedf(SUBSTATS[stat] * b * rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	else:
		item["subs"][stat] = snappedf(float(item["subs"][stat]) * rng.randf_range(0.8, 1.2), 0.01)


## Reroll WHICH substats the item carries (and their values) — the whole affix
## set at once. Every grade (S included) rolls freely; there are no pinned synergy
## subs. (No longer in the UI, which rerolls one slot at a time via reforge_affix
## — kept as an API/for tests.)
static func reforge_affixes(item: Dictionary, cls: String, rng: RandomNumberGenerator) -> void:
	item["subs"] = roll_subs(String(item["grade"]), String(item.get("noun", "Blade")), cls, rng)


## Can this ONE substat slot be reforged (rerolled into a different stat)? Any
## rolled affix can (S legendaries included — no fixed synergy subs anymore). The
## MAIN stat is never reforged (quench it — it's the class primary attribute you'd
## never trade away).
static func can_reforge_affix(item: Dictionary, stat: String) -> bool:
	return item.get("subs", {}).has(stat)


## Reforge ONE substat slot: drop `target_stat` and roll a DIFFERENT random affix
## in its place (the FULL pool, no duplicates), at a fresh band roll — the
## magnitude is then the player's to quench. Returns the new stat ("" if it
## couldn't reroll). A targeted gamble on a single slot, not the whole set.
## Un-gated for every grade including S (2026-07-17): the player chose to gamble
## this slot, and an off-type pen goes live the moment a rune reroutes their
## damage type. roll_subs' S first-roll guarantee is the only class-gating left.
## `_cls` is kept for call-site compatibility; the pool no longer consults it.
static func reforge_affix(item: Dictionary, target_stat: String, _cls: String, rng: RandomNumberGenerator) -> String:
	if not can_reforge_affix(item, target_stat):
		return ""
	var subs: Dictionary = item["subs"]
	var mult: float = GRADE_MULT[String(item["grade"])]
	var pool: Array = SUBSTATS.keys()
	for s in subs:
		pool.erase(String(s))   # no duplicate affixes (also drops target_stat)
	if pool.is_empty():
		return ""
	var noun := String(item.get("noun", ""))
	var style: Dictionary = SHAPE_STYLE.get(noun, DEFAULT_STYLE)
	var bias: Dictionary = style.get("bias", {})
	# Weighted like a fresh roll: gambling a slot on a Shuriken leans toward crit.
	var new_stat := _weighted_take(pool, bias, rng)
	subs.erase(target_stat)
	subs[new_stat] = snappedf(float(SUBSTATS[new_stat]) * shape_bias(noun, new_stat)
		* rng.randf_range(0.7, 1.3) * (1.0 + mult * 0.25), 0.01)
	return new_stat


## The [min, max] BASE (pre-plus) range a rolled stat can occupy on this item —
## the band quenching rerolls within. Main: budget x grade x shape x [0.9, 1.15].
## Sub: the shape's fixed part + the rollable pool part x [0.7, 1.3]. A degenerate
## band (min == max) marks a fixed shape/legendary sub that quenching can't move.
static func stat_band(item: Dictionary, stat: String) -> Array:
	var grade := String(item["grade"])
	var mult: float = GRADE_MULT.get(grade, 1.0)
	var noun := String(item.get("noun", "Blade"))
	var style: Dictionary = SHAPE_STYLE.get(noun, DEFAULT_STYLE)
	if item.get("main", {}).has(stat):
		var base: float = float(SLOT_MAIN_BUDGET.get(String(item["slot"]), 3.0)) * mult * float(style["main"])
		return [snappedf(base * 0.9, 0.01), snappedf(base * 1.15, 0.01)]
	if item.get("subs", {}).has(stat):
		if SUBSTATS.has(stat):
			# The shape's bias scales the whole band, so quenching a Shuriken's crit
			# climbs toward a ceiling a Hammer's crit can never reach. Same reader as
			# the roll (shape_bias) — band and roll cannot drift apart.
			var roll_base: float = float(SUBSTATS[stat]) * shape_bias(noun, stat) * (1.0 + mult * 0.25)
			return [snappedf(roll_base * 0.7, 0.01), snappedf(roll_base * 1.3, 0.01)]
		var cur: float = float(item["subs"][stat])   # legendary/off-pool sub — no band
		return [cur, cur]
	return [0.0, 0.0]


## True if quenching could ever improve this stat (its band is non-degenerate).
static func can_quench(item: Dictionary, stat: String) -> bool:
	var band := stat_band(item, stat)
	return float(band[1]) > float(band[0])


## Quench a stat: reroll its band position and KEEP THE HIGHER of old/new — never
## regresses. Returns {"old","rolled","kept","max","improved"} for the UI.
static func quench_stat(item: Dictionary, stat: String, rng: RandomNumberGenerator) -> Dictionary:
	var band := stat_band(item, stat)
	var lo: float = float(band[0])
	var hi: float = float(band[1])
	var in_main: bool = item.get("main", {}).has(stat)
	var store: Dictionary = item["main"] if in_main else item["subs"]
	var old_val: float = float(store.get(stat, lo))
	var rolled: float = snappedf(rng.randf_range(lo, hi), 0.01)
	var kept: float = maxf(old_val, rolled)
	store[stat] = kept
	return {"old": old_val, "rolled": rolled, "kept": kept, "max": hi, "improved": kept > old_val}


## Escalating gold cost to quench `stat`: cheap near the band floor, steeply
## pricier near the max (base x (1 + ESCALATION x current-band-fraction)) so
## perfecting a roll — the last few % — is where the real gold goes.
static func quench_cost(item: Dictionary, stat: String) -> int:
	var base: int = int(Balance.QUENCH_COST_BASE.get(String(item["grade"]), 60))
	var band := stat_band(item, stat)
	var lo: float = float(band[0])
	var hi: float = float(band[1])
	var in_main: bool = item.get("main", {}).has(stat)
	var store: Dictionary = item["main"] if in_main else item.get("subs", {})
	var cur: float = float(store.get(stat, lo))
	var frac: float = 0.0 if hi <= lo else clampf((cur - lo) / (hi - lo), 0.0, 1.0)
	return int(round(base * (1.0 + Balance.QUENCH_COST_ESCALATION * frac)))


# ------------------------------------------------------- main transmute ---
# The bench's answer to an off-meta build (2026-07-17). Gear mains still ROLL as
# the wearer class's primary (CLASS_PRIMARY) — that keeps the drop's power
# envelope honest (the SLOT_MAIN_BUDGET sizing every boss is pinned to) and means
# a drop is never a brick. What changes is that the player may PAY to point that
# budget somewhere else: a STR archer trading AGI's crit rider for STR's hp_flat,
# a VIT tank, an INT hybrid. Transmute moves WHICH attribute the budget feeds,
# never HOW MANY points it is — so it is a build commitment, not a reroll, and
# it can't inflate an item. stat_band is slot/grade/shape-keyed and never reads
# the attribute, so a transmuted main quenches exactly like a rolled one.

## Mirror of Classes.ATTR_NAMES — items.gd must not preload classes.gd
## (same rule as CLASS_PRIMARY / CLASSES_DMG_TYPE above).
const ATTR_NAMES := ["STR", "AGI", "INT", "VIT"]


## The attributes this item's main could be transmuted INTO — every attribute but
## the one it carries. Empty unless the item has exactly one main. (A legacy
## ATK/HP main from an old save lists all four: transmuting is its way forward.)
static func transmute_targets(item: Dictionary) -> Array:
	var main: Dictionary = item.get("main", {})
	if main.size() != 1:
		return []
	var cur := String(main.keys()[0])
	return ATTR_NAMES.filter(func(a: String) -> bool: return a != cur)


## Can the bench transmute this item's main at all?
static func can_transmute_main(item: Dictionary) -> bool:
	return not transmute_targets(item).is_empty()


## Gold cost to transmute this item's main. FLAT per grade — a one-off commitment
## per piece, so unlike quench it doesn't escalate.
static func transmute_cost(item: Dictionary) -> int:
	return int(Balance.TRANSMUTE_MAIN_COST.get(String(item.get("grade", "D")), 600))


## Convert the item's main to `attr`, KEEPING the rolled magnitude — you buy the
## attribute, not a reroll. Returns the attribute it WAS ("" if it couldn't convert).
static func transmute_main(item: Dictionary, attr: String) -> String:
	if not attr in transmute_targets(item):
		return ""
	var main: Dictionary = item["main"]
	var old := String(main.keys()[0])
	var val: float = float(main[old])
	main.erase(old)
	main[attr] = val
	return old


## Can this item take another gem socket? C+ only (C joined 2026-07-09 with
## its rolled socket), capped at grade's roll + 1, never past MAX_SOCKETS.
static func can_add_socket(item: Dictionary) -> bool:
	return String(item["grade"]) in ["C", "B", "A", "S"] \
		and int(item.get("gem_slots", 0)) < mini(GEM_SLOTS[item["grade"]] + 1, MAX_SOCKETS)


static func add_socket(item: Dictionary) -> void:
	item["gem_slots"] = int(item.get("gem_slots", 0)) + 1


# --------------------------------------------------------------- set bonuses ---
# Each class's four S legendaries form a SET. Wearing 2 / 4 pieces of your
# own class's S set grants escalating bonuses (applied in Player.recalc).
# S items carry item["cls"], so only your class's legendaries count.
# ROLE-WEAKNESS doctrine (2026-07-07, refined): a set shores up the class's
# WEAKNESS, not its strength. The plate tanks (warrior/paladin) already
# excel at survival, so their set is pure OFFENSE — their weak axis — to
# keep their dps from falling behind the squishies' damage scaling. The
# squishies (archer/assassin/mage/warlock) get DEFENSE from real mitigation
# — VITALITY (pool + a broad tiny-res sprinkle) plus direct resistances and
# critres — NO evasion (a soft-capping avoid-RNG cop-out). Modest numbers
# ride the STEEP low end of the res curve (res_frac saturates, so a little
# from a near-zero base buys a lot), closing the survival gap for endgame
# bullet hell WITHOUT making them tanks. All four squishy 4pc are broad
# phys + mag res + a little critres (bullet hell throws both damage types);
# the VIT 2pc adds the pool. No specials (gear rule holds).
const SET_BONUSES := {
	# S-set bonuses are the ENDGAME DPS dial (S-gear only, inert below): glass
	# cannons (archer/mage) get OFFENSE to top the charts, plate a SMALL offense
	# lift (they lead on survivability, not damage), assassin/warlock keep the
	# defensive set (assassin tops on raw kit; warlock is the survivable caster).
	"warrior":  {"name": "Emberforged Warplate",    "2": {"atk_pct": 0.02}, "4": {"atk_pct": 0.04, "physpen": 4.0}},
	"paladin":  {"name": "The Highfather's Aegis",  "2": {"atk_pct": 0.06}, "4": {"atk_pct": 0.12, "magpen": 6.0}},
	"archer":   {"name": "The Hawk God's Regalia",  "2": {"atk_pct": 0.08}, "4": {"atk_pct": 0.17, "crit": 0.04, "physpen": 6.0}},
	"assassin": {"name": "The Shadow God's Vestige", "2": {"VIT": 8.0},     "4": {"physres": 14.0, "magres": 14.0, "critres": 6.0}},
	"mage":     {"name": "The Archmage's Array",    "2": {"atk_pct": 0.10}, "4": {"atk_pct": 0.22, "magpen": 8.0}},
	"warlock":  {"name": "The Long Bargain Raiment", "2": {"VIT": 8.0},     "4": {"physres": 14.0, "magres": 14.0, "critres": 6.0}},
}


## How many pieces of `cls`'s S set are equipped (S grade + matching class).
static func count_set_pieces(equipment: Dictionary, cls: String) -> int:
	var n := 0
	for slot in equipment:
		var it: Dictionary = equipment[slot]
		if String(it.get("grade", "")) == "S" and String(it.get("cls", "")) == cls:
			n += 1
	return n


## All stats an item grants. The smith upgrade (plus) scales EVERY rolled stat
## — main AND subs — by +5%/plus (Balance.UPGRADE_PCT_PER_PLUS). Socketed gems
## are the player's own investment, not part of the gear's roll, so plus never
## touches them.
static func stats_of(item: Dictionary) -> Dictionary:
	var out := {}
	var plus_mult: float = 1.0 + Balance.UPGRADE_PCT_PER_PLUS * item["plus"]
	for stat in item["main"]:
		out[stat] = item["main"][stat] * plus_mult
	for stat in item["subs"]:
		out[stat] = out.get(stat, 0.0) + item["subs"][stat] * plus_mult
	for gem in item.get("gems", []):
		out[gem["stat"]] = out.get(gem["stat"], 0.0) + gem_value(gem)
	return out


static func price(item: Dictionary) -> int:
	return int(22.0 * GRADE_MULT[item["grade"]] * (1.0 + 0.5 * item["plus"]))


static func upgrade_cost(item: Dictionary) -> int:
	# Steep per-tier curve (base * grade factor * (1+plus)^EXP) — an S step costs
	# 8x a C step, and the exponent makes each plus bite harder. Knobs in balance.gd.
	var f: float = float(Balance.UPGRADE_GRADE_FACTOR.get(String(item["grade"]), 1.0))
	return int(Balance.UPGRADE_BASE * f * pow(float(1 + int(item["plus"])), Balance.UPGRADE_COST_EXP))


## True while the item's plus sits below its grade cap (the smith can still work it).
static func can_upgrade(item: Dictionary) -> bool:
	return int(item.get("plus", 0)) < Balance.max_plus(String(item.get("grade", "D")))


## FARM-COST buy price of a gear item in a `chid` merchant (round 51): the gold
## you'd earn farming one yourself + FARM_TAX. Rare grades (in the act's boss
## table) use the farm-cost formula; commodity grades below them get a cheap
## flat intrinsic price so shop filler stays junk-cheap. S weapons pay ~2x
## (halved drop rate). SELL is separate — always MERCHANT_SELL_FRACTION x the
## small intrinsic price(), never this inflated number.
static func shop_buy_price(item: Dictionary, chid: String) -> int:
	var grade := String(item["grade"])
	var econ: Dictionary = Balance.CHAPTER_ECON.get(chid, {})
	var odds: Dictionary = Balance.boss_gear_odds(chid)
	var plus_mult: float = 1.0 + 0.5 * float(item.get("plus", 0))
	if odds.has(grade) and not econ.is_empty():
		var chance: float = float(odds[grade])
		if grade == "S" and String(item.get("slot", "")) == "weapon":
			chance *= Balance.S_WEAPON_DROP_WEIGHT
		var n: int = Balance.farm_runs(chance)
		var g: float = float(econ["first"]) + float(n - 1) * float(econ["replay"])
		return int(round(g * Balance.FARM_TAX * plus_mult))
	return int(ceil(price(item) * Balance.SHOP_BUY_MARKUP))


## FARM-COST buy price of a shop GEM at `lvl` (round 51). Gems drop many per
## run, so per-unit cost = (one run's gold / gems per run) scaled up the
## combine curve from the act's floor level, + FARM_TAX. A fraction of gear.
static func gem_buy_price(lvl: int, chid: String) -> int:
	var econ: Dictionary = Balance.CHAPTER_ECON.get(chid, {})
	if econ.is_empty():
		return int(ceil(Balance.gem_gold_value(lvl) * Balance.FARM_TAX))
	var act: int = int(econ.get("act", 1))
	var floor_lvl: int = int(Balance.GEM_ACT_LEVEL.get(act, 1))
	var gems_per_run: float = maxf(1.0, float(econ.get("gems", 15.0)))
	var per_gem: float = float(econ["replay"]) / gems_per_run
	var weight: float = pow(Balance.GEM_GOLD_PER_LEVEL, float(maxi(lvl - floor_lvl, 0)))
	return int(round(per_gem * weight * Balance.FARM_TAX))


## "★ <Passive>". The dormant/LOCKED path is GONE (2026-07-27): the legendary
## tier retired and every passive is live on pickup — old-save legendaries
## included (their passive_dormant field is simply ignored now). `awakened`
## is kept for call-site compatibility and no longer changes the text.
static func passive_label(item: Dictionary, _awakened := false) -> String:
	return "★ " + PASSIVES[item["passive"]]


## `awakened` (the item's class flag s_awakened_<cls>) governs how a dormant
## legendary's passive reads: pass game.get_flag(...) from player-facing UI.
## `show_sockets` off drops the ◆◇ glyph tail — for screens that render the
## REAL socket squares right below the text (inventory equipped column).
static func describe(item: Dictionary, awakened := false, show_sockets := true) -> String:
	var bits: Array = []
	var stats := stats_of(item)
	for stat in stats:
		var v: float = stats[stat]
		if stat in FLAT_STATS:
			bits.append("%s +%d" % [STAT_LABEL.get(stat, stat), int(v)])
		else:
			bits.append("%s +%d%%" % [STAT_LABEL.get(stat, stat), int(round(v * 100))])
	var out := ", ".join(bits)
	if item.has("passive"):
		out += "  " + passive_label(item, awakened)
	var slots: int = item.get("gem_slots", 0)
	if slots > 0 and show_sockets:
		var used: int = item.get("gems", []).size()
		out += "  " + "◆".repeat(used) + "◇".repeat(slots - used)
	return out


## Stat-by-stat difference between a candidate item and what's equipped
## in that slot ("▲ ATK +5" / "▼ Crit -2%"). For hover tooltips.
static func diff_text(new_item: Dictionary, old_item, awakened := false) -> String:
	if old_item == null:
		return "Slot is empty — pure upgrade:\n" + describe(new_item, awakened)
	var a := stats_of(new_item)
	var b := stats_of(old_item)
	var keys := {}
	for stat in a:
		keys[stat] = true
	for stat in b:
		keys[stat] = true
	var lines: Array = ["vs %s:" % title(old_item)]
	for stat in keys:
		var d: float = a.get(stat, 0.0) - b.get(stat, 0.0)
		if absf(d) < 0.001:
			continue
		var arrow := "▲" if d > 0.0 else "▼"
		var label: String = STAT_LABEL.get(stat, stat)
		if stat in FLAT_STATS:
			lines.append("%s %s %+d" % [arrow, label, int(round(d))])
		else:
			lines.append("%s %s %+d%%" % [arrow, label, int(round(d * 100))])
	if lines.size() == 1:
		lines.append("(identical stats)")
	if new_item.has("passive"):
		lines.append(passive_label(new_item, awakened))
	return "\n".join(lines)


static func title(item: Dictionary) -> String:
	var plus: String = "" if item["plus"] == 0 else " +%d" % item["plus"]
	return "[%s] %s%s" % [item["grade"], item["name"], plus]
