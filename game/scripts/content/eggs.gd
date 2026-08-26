## Easter eggs (DYNAMIC_WORLD.md §8): the world remembers. Pure flag-gated
## flavor — never gates progression or power, never pays currency. Each rides
## a mark an earlier quest already left, and reads it once, later, somewhere.
## New eggs land here; ZONE_PROPS drops a gated NPC/prop into an existing room.

# --- Egg #1: "The boy grows up." The heron-feather hat, returned in ch1
# (sq_kept_hat), walks back into the story in ch7 — the miller's boy is a Guard
# recruit now, and he stands his first watch in his father's hat. The whole
# "the world reads flat" complaint answered in one NPC.
# --- Egg #2: "The Hatless Man." (owner ruling 2026-08-24 #8 — build it cruel,
# no warmth.) The dark mirror of the hat quest. The miller's boy's father went
# "toward the howling" and died at the ravine — his hat was found in the thorns
# there (lore_millers_hat) and you carried it home to the boy. His REVENANT
# still stands at the ravine's lip, hollowed by the blight, bareheaded, and
# still walking into the howling — the warm ending ("a good place to stop
# walking") inverted: he never stopped. Gives NOTHING back (no fight, no reward,
# no resonance, no closure) — the cruelty is the futility. Gated on having met
# the boy (boy_answered), so only players inside the hat storyline meet him;
# diverges INSIDE on hat_given (owner ruling #1). Reads once (heron_father_met).
const ZONE_PROPS := {
	"ch1": {
		"Ravine Edge": [
			{"sprite": "zombie", "x": 1580, "y": 1040, "prompt": "E — A man stands at the ravine's edge",
				"convo": "ch1_hatless_man", "req_flag": "boy_answered"},
		],
	},
	"ch7": {
		"The Wayhouse": [
			{"sprite": "millers_boy", "x": 700, "y": 400, "prompt": "E — A young guard",
				"convo": "ch7_heron_recruit", "req_flag": "sq_kept_hat"},
		],
	},
}

const CONVOS := {
	"ch1_hatless_man": {"start": "h1", "nodes": {
		"h1": {"who": "Narrator",
			"text": "A man stands at the lip of the ravine, facing into the wind, not moving. Something about the posture is wrong. Too still, too long, the way nothing living holds itself. When your step turns him, his face is a ruin the blight has been at, and his eyes have the flat shine of deep water. He's bareheaded. The wind moves what's left of his hair the same way it moves the dead grass.",
			"variants": [
				{"flag": "heron_father_met", "text": "The hatless man still stands at the ravine's lip, facing into the howling, going nowhere and never stopping. He doesn't turn for you a second time. There was never a second thing to see.", "next": ""},
				{"flag": "hat_given", "text": "A man stands at the lip of the ravine, bareheaded, and one hand drifts up to his scalp and feels along it, slow and patient, hunting for a brim that's a day's walk south now, pinned up with a wolf tooth on a boy who swallowed it to the eyebrows. He doesn't find it. Something in the ruin of his face almost remembers what it's looking for, and can't, and keeps looking.", "next": "h2"},
			],
			"next": "h2"},
		"h2": {"who": "Narrator",
			"text": "He was going toward the howling. He's still going toward the howling. Whatever the wood took from him, it left the walking, and pointed it in the one direction.",
			"choices": [
				{"text": "\"It's gone. Your boy has the hat. He's safe. You can stop now.\"",
					"flags": {"heron_father_met": true}, "next": "h_speak"},
				{"text": "Say nothing. Leave him to the wind.",
					"flags": {"heron_father_met": true}, "next": "h_leave"},
			]},
		"h_speak": {"who": "Narrator",
			"text": "The word 'boy' moves nothing behind his eyes. 'Safe' moves nothing. 'Stop' moves nothing either. Those are words for the living, and he set them down at the ravine's edge with everything else that had weight. He turns back into the wind. After a moment the walking starts again, one foot, then the other, toward a howling that has all the time there is. You brought his hat home. That was the only part of this that could be finished.", "next": ""},
		"h_leave": {"who": "Narrator",
			"text": "You leave him to it. Behind you the walking starts again, one foot, then the other, in the direction the wood pointed him and the only one it left. Somewhere south a boy stands straighter under a hat two sizes too big. Both of those things are true at once. The wood won't reconcile them for you.", "next": ""},
	}},
	"ch7_heron_recruit": {"start": "e1", "nodes": {
		"e1": {"who": "A Young Guard",
			"text": "A recruit no older than the war stands his watch at the Wayhouse door with the stiff pride of someone who chose this. His helm is regulation. His hat is not: a wide brown brim pinned up with a wolf tooth, a heron feather blue at the tip, worn over the steel like he'd fight anyone who told him to take it off.",
			"variants": [
				{"flag": "heron_recruit_met", "text": "The young guard nods to you like an old debt paid. \"Still standing, bearer. So am I.\"", "next": ""},
			],
			"next": "e2"},
		"e2": {"who": "A Young Guard", "text": "\"...You. You're the one who brought it back. To the mill.\" He touches the brim, once, the way you touch a thing to be sure it's real. \"I was a boy watching a road for a hat that wasn't coming. Then somebody walked a dead man's hat up it anyway, and I stopped watching the road and started walking it. Signed with the Guard at the capital muster. They let me keep the hat. I didn't ask twice.\"",
			"choices": [
				{"text": "\"Your father would know you in it.\"",
					"resonance": 3.0, "flags": {"heron_recruit_met": true}, "next": "e_kind"},
				{"text": "\"It's just a hat, recruit.\"",
					"flags": {"heron_recruit_met": true}, "next": "e_gruff"},
			]},
		"e_kind": {"who": "A Young Guard", "text": "His jaw works once. \"...That's the idea, bearer. That's the whole idea.\" He straightens, and stands his watch a little taller, a heron feather blue against the storm, on a road his father never finished and he means to.", "next": ""},
		"e_gruff": {"who": "A Young Guard", "text": "\"It's my father's hat, and I'm the one still wearing it toward the howling. That's not nothing, bearer.\" He's right, and you both know it. He turns back to his watch, the feather bright against the grey.", "next": ""},
	}},
}


# ---- CONTENT-MODULE TEST HOOK: called from autotest via _test_eggs() ----
static func selftest_present() -> bool:
	return Story.ALL_CONVOS.has("ch7_heron_recruit") and Story.ALL_CONVOS.has("ch1_hatless_man")
