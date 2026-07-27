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

const SLOTS := ["weapon", "armor", "boots", "charm"]
const SLOT_ICON := {"weapon": "⚔", "armor": "🛡", "boots": "👢", "charm": "❖"}

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
const SLOT_MAIN_BUDGET := {"weapon": 5.0, "armor": 3.0, "boots": 2.0, "charm": 2.5}
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

# SLOT_NAMES["weapon"] = the union of every class's rollable weapon shapes (the
# classless fallback pool). Armor/boots/charm are the shared shapes still awaiting
# their own matrix pass.
const SLOT_NAMES := {
	"weapon": ["Pike", "Warblade", "Saber", "Bulwark Blade", "Claymore",
		"Warbow", "Longbow", "Hunting Bow", "Thornbow", "Recurve",
		"Stiletto", "Shuriken", "Glasswing", "Warded Fang", "Cleaver",
		"Scepter", "Starfocus", "Zephyr Rod", "Bloomstaff", "Greatstaff",
		"Lance", "Oathflail", "Duelist's Blade", "Aegis Mace", "Warmaul",
		"Grimoire", "Hexblade", "Whisper Rod", "Pactshield Codex", "Grimheart Staff"],
	"armor":  ["Plate", "Mail", "Guard"],
	"boots":  ["Boots", "Striders", "Treads"],
	"charm":  ["Charm", "Talisman", "Sigil"],
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
	{"name": "Crownfall, the Kingdom's End", "cls": "warrior", "slot": "weapon", "noun": "Claymore", "grade": "S", "art": "u_crownfall_the_kingdoms_end", "passive": "aftershock"},
	# --- Archer weapons ---
	{"name": "Siegebough", "cls": "archer", "slot": "weapon", "noun": "Warbow", "grade": "A", "art": "u_siegebough", "passive": "siegebolt"},
	{"name": "Tempest Yew, Bow of the Last Gale", "cls": "archer", "slot": "weapon", "noun": "Warbow", "grade": "S", "art": "u_tempest_yew_bow_of_the_last_gale", "passive": "gale"},
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
	{"name": "Pale Flight, Blade Between Heartbeats", "cls": "assassin", "slot": "weapon", "noun": "Glasswing", "grade": "S", "art": "u_pale_flight_blade_between_heartbeats", "passive": "heartbeat"},
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
	{"name": "Firmament, the Heaven-Bearing Staff", "cls": "mage", "slot": "weapon", "noun": "Greatstaff", "grade": "S", "art": "u_firmament_the_heaven_bearing_staff", "passive": "skyfall"},
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
	{"name": "Dawnfall, Hammer of the Final Oath", "cls": "paladin", "slot": "weapon", "noun": "Warmaul", "grade": "S", "art": "u_dawnfall_hammer_of_the_final_oath", "passive": "dawnfall"},
	# --- Warlock weapons ---
	{"name": "Ink of Teeth", "cls": "warlock", "slot": "weapon", "noun": "Grimoire", "grade": "A", "art": "u_ink_of_teeth", "passive": "inkteeth"},
	{"name": "The Book That Remembers You", "cls": "warlock", "slot": "weapon", "noun": "Grimoire", "grade": "S", "art": "u_the_book_that_remembers_you", "passive": "remembrance"},
	{"name": "Debtcollector", "cls": "warlock", "slot": "weapon", "noun": "Hexblade", "grade": "A", "art": "u_debtcollector", "passive": "collection"},
	{"name": "Black Clause, Edge of the Final Bargain", "cls": "warlock", "slot": "weapon", "noun": "Hexblade", "grade": "S", "art": "u_black_clause_edge_of_the_final_bargain", "passive": "clause"},
	{"name": "Hushbone", "cls": "warlock", "slot": "weapon", "noun": "Whisper Rod", "grade": "A", "art": "u_hushbone", "passive": "hush"},
	{"name": "The Name Beneath All Names", "cls": "warlock", "slot": "weapon", "noun": "Whisper Rod", "grade": "S", "art": "u_the_name_beneath_all_names", "passive": "truename"},
	{"name": "Bound Witness", "cls": "warlock", "slot": "weapon", "noun": "Pactshield Codex", "grade": "A", "art": "u_bound_witness", "passive": "witness"},
	{"name": "The Cover Between Worlds", "cls": "warlock", "slot": "weapon", "noun": "Pactshield Codex", "grade": "S", "art": "u_the_cover_between_worlds", "passive": "thecover"},
	{"name": "Veinroot", "cls": "warlock", "slot": "weapon", "noun": "Grimheart Staff", "grade": "A", "art": "u_veinroot", "passive": "veinroot"},
	{"name": "Red Reliquary, Staff of the Last Pulse", "cls": "warlock", "slot": "weapon", "noun": "Grimheart Staff", "grade": "S", "art": "u_red_reliquary_staff_of_the_last_pulse", "passive": "lastpulse"},
]


## Named uniques for one class, in manifest order (shape, then A before S).
static func uniques_for(cls: String) -> Array:
	var out: Array = []
	for u in UNIQUES:
		if String(u["cls"]) == cls:
			out.append(u)
	return out


# S_GEAR — the class-signature legendaries. The weapon `noun` was DROPPED
# 2026-07-26: it used to force each S weapon onto a legacy shape (Blade/Bow/…),
# the last thing keeping those shapes alive. The passives are ability-based, not
# shape-based, so a legendary now rides whatever matrix shape rolled and keeps its
# name + signature passive. (2026-07-27) The interim "every S is a legendary"
# behaviour is GONE: the legendary is now the class's 6th named-S — a rare
# Act-2+ roll through roll_item_of's legendary channel (Balance.LEGEND_S_CHANCE),
# same power tier as the named-S uniques, sole keeper of the awakening quest.
# Generic S drops passive-less (PROPOSALS/GEAR_UNIQUE_PASSIVES.md §9).
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
	"thegate":    "Shield Bash raises the Gate: 2.5s of massive guard, and every blow taken is answered with a stagger and a counter-cut",
	"dirge":      "Cleave and Whirlwind hit 20% harder — BUT Cleave tolls 15% slower",
	"aftershock": "Everything falls twice: Whirlwind leaves a collapsing ring that detonates a beat later",
	# --- archer ---
	"siegebolt":  "Multishot looses siege bolts that punch straight through their victims",
	"gale":       "Every 5th Quick Shot looses the gale — a free 3-arrow fan rides the shot",
	"farsight":   "Arrows loosed at distant prey halve its armor",
	"herald":     "Your first hit on an unwounded enemy is a guaranteed crit and EXPOSES the prey",
	"foxfire":    "Slipping an attack draws the fox's shot: your next Quick Shot fires twin arrows",
	"hartsbreath": "A PERFECT dodge grants the Hart's Breath: your next 3 shots are guaranteed crits and Multishot returns at once",
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
	# ===================== ARMOR / BOOTS / CHARM (matrix rework pending) ========
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
		if slot == "weapon" and grade in ["A", "S"]:
			var gate_act: int = Balance.UNIQUE_A_ACT if grade == "A" else Balance.UNIQUE_S_ACT
			var chance: float = Balance.UNIQUE_A_CHANCE if grade == "A" else Balance.UNIQUE_S_CHANCE
			if act >= gate_act and rng.randf() < chance:
				var pool := uniques_of(cls, grade)
				if not pool.is_empty():
					return make_unique(pool[rng.randi_range(0, pool.size() - 1)], rng)
		if grade == "S" and act >= Balance.UNIQUE_A_ACT and S_GEAR.has(cls) \
				and rng.randf() < Balance.LEGEND_S_CHANCE:
			return make_legendary(cls, slot, rng)

	var mult: float = GRADE_MULT[grade]
	var noun_list: Array = SLOT_NAMES[slot]
	if slot == "weapon" and cls != "" and CLASS_WEAPONS.has(cls):
		noun_list = CLASS_WEAPONS[cls]
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


## The named uniques of one class at one grade (drop pool for the named channel).
static func uniques_of(cls: String, grade: String) -> Array:
	var out: Array = []
	for u in UNIQUES:
		if String(u["cls"]) == cls and String(u["grade"]) == grade:
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


## Build the class's S_GEAR legendary for a slot: a generic S roll wearing the
## legendary name; the weapon's signature passive SLEEPS until the class's
## awakening quest sets s_awakened_<cls> (round 51b, unchanged).
static func make_legendary(cls: String, slot: String, rng: RandomNumberGenerator) -> Dictionary:
	var item := roll_item_of(slot, "S", rng, cls)
	var special: Dictionary = S_GEAR[cls][slot]
	item["name"] = special["name"]
	item["cls"] = cls
	if special.has("passive"):
		item["passive"] = special["passive"]
		item["passive_dormant"] = true
	return item


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


## "★ <Passive>" — or "★ <Passive> — LOCKED (awakening)" for a dormant
## legendary whose class hasn't awakened (s_awakened_<cls>) yet.
static func passive_label(item: Dictionary, awakened := false) -> String:
	var txt: String = "★ " + PASSIVES[item["passive"]]
	if item.get("passive_dormant", false) and not awakened:
		txt += " — LOCKED (awakening)"
	return txt


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
