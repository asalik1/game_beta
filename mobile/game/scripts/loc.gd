class_name Loc
## Localization string table (foundation pass). Route user-facing strings
## through Loc.t("key") so translating the game becomes a TABLE SWAP, not a
## code-wide string sweep later. Lookup order: current language → English
## → the key itself (so a missing key is visible, never a crash).
##
## Format with positional placeholders: Loc.t("gold_amount", [42]) where the
## string is "{0} gold". Add new user-facing text as a KEY here from now on.
##
## Migration is incremental: the pause menu and the meta-system screens go
## through Loc; older screens will be converted as they're touched.

static var lang := "en"

const STRINGS := {
	"en": {
		# pause / system menu
		"resume": "Resume",
		"settings": "Settings (sound)",
		"keybinds": "Keybinds",
		"quest_log": "Quest Log",
		"stash": "Stash  (shared across characters)",
		"mailbox": "Mailbox",
		"daily_reward": "Daily reward  (ready to claim!)",
		"restart_chapter": "Restart chapter  (keeps your character)",
		"chapter_select": "Chapter select  (replay any chapter)",
		"exit_title": "Exit to title  (switch character)",
		"save_quit": "Save and quit game",
		# meta-system screen titles / labels
		"bounties": "Bounties",
		"weekly_vault": "Weekly Vault",
		"records": "Records",
		"achievements": "Achievements",
		"reforge_bench": "Reforge Bench",
		# common formats
		"gold_amount": "{0} gold",
		"esc_close": "ESC to close",
	},
	# Partial sample locale (proves the swap + English fallback). Real
	# translations drop in here per key; anything missing falls back to en.
	"es": {
		"resume": "Reanudar",
		"quest_log": "Diario de misiones",
		"mailbox": "Buzón",
		"gold_amount": "{0} de oro",
		"esc_close": "ESC para cerrar",
	},
}


## Localized string for `key`, with positional {0}, {1}… replaced by args.
static func t(key: String, args: Array = []) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS["en"])
	var s := String(table.get(key, STRINGS["en"].get(key, key)))
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s


## Language codes with a table present (for a settings selector).
static func languages() -> Array:
	return STRINGS.keys()
