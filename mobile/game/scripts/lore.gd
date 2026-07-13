class_name Lore
## Codex completion lore (retention roadmap #5): slay enough of a monster
## kind and its codex card unearths a lore entry — the codex becomes a
## collection game, not just a reference. Thresholds live in Balance
## (LORE_KILLS_MOB / LORE_KILLS_BOSS); kill counts live on the Game
## (game.kill_counts, persisted per character).
##
## Unauthored kinds fall back to a generic hunter's note, so new content
## modules never ship a broken codex — but authored lines are better:
## add the kind here when adding a monster.

const LORE := {
	# --- Chapter 1: Ashvale ---
	"wolf": "Ashvale's wolves ran with Fangmaw's warbands once. The packs survived their master by years — leaner now, and less afraid of firelight than wolves should be.",
	"spider": "The web-choked hollows south of the village predate the blight. Whatever the spiders feed on down there, they have grown past any natural size for it.",
	"cultist": "Choir faithful, mostly farmers who lost everything to the blight and found someone who said the rot LOVED them. Pity them after they stop swinging.",
	"skeleton": "The Concord's wars left more dead than the ground could hold. When the seals cracked, the ground gave some of them back.",
	"zombie": "Blight-dead. They walk because Mórwyn's rot refuses to concede an ending — the Choir calls this a blessing and buries nothing.",
	"fangmaw": "Fangmaw was the Ember Guard's beastmaster before the corruption took him — commander of the Stormwarden line. Killing him cut the head off the warbands; the packs still wear his teeth-marks.",
	"morwen": "Morwen the Blightcaller heard Mórwyn first and took her goddess's name, as Choir tradition demands. Killing her woke the god-king in an unprepared vessel — the Vale is still paying for that mercy.",
	"vargoth": "The tyrant of the Ember Crown. Aldric's blow scattered the Crown into shards — one of them into you. Every bearer's power is a fragment of this man's will.",
	# --- Chapter 2 ---
	"stormwarden": "A commander of the old Guard line that bred Fangmaw, storm-touched and long past reason. The Waking is pulling the old bloodlines apart first.",
	"choirmother": "She fed the blight her own congregation and sang while it took them. The Choir reveres her; the survivors she made do not.",
	"nullwarden": "The Warden of the Waking — a seal-keeper hollowed out by the very thing he was set to guard. What patrols the deep rooms now is the uniform, not the man.",
	# --- Chapter 3: the Unburied Vale ---
	"sexton": "The Vale's gravekeeper kept burying the dead as they climbed back out. Somewhere in that arithmetic he decided the fault lay with the living.",
	"vess": "Vess sings the silence between the Choir's hymns. Stand where the song is NOT — survivors agree on that much and little else.",
	"saint_varo": "Censer-bearer of the Hollow Choir, swinging incense that heals the rot it billows over. The censers are the fight; Varo is the schedule.",
}

# The generic note when no authored line exists (content modules add
# monsters faster than lore gets written; the codex never shows a hole).
const FALLBACK := "A hunter's tally this thorough earns its own kind of knowledge: habits, weaknesses, the hour it prowls. The Vale has one fewer mystery."


## Kills needed to unearth `kind`'s lore (bosses die once a run, so their
## bar is short; trash earns it in bulk). Boss-ness reads the same
## hand-maintained list the codex buckets by (Menus.BOSS_KINDS).
static func threshold(kind: String) -> int:
	return Balance.LORE_KILLS_BOSS if kind in Menus.BOSS_KINDS else Balance.LORE_KILLS_MOB


static func entry(kind: String) -> String:
	return String(LORE.get(kind, FALLBACK))
