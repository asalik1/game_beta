## Easter eggs (DYNAMIC_WORLD.md §8): the world remembers. Pure flag-gated
## flavor — never gates progression or power, never pays currency. Each rides
## a mark an earlier quest already left, and reads it once, later, somewhere.
## New eggs land here; ZONE_PROPS drops a gated NPC/prop into an existing room.

# --- Egg #1: "The boy grows up." The heron-feather hat, returned in ch1
# (sq_kept_hat), walks back into the story in ch7 — the miller's boy is a Guard
# recruit now, and he stands his first watch in his father's hat. The whole
# "the world reads flat" complaint answered in one NPC.
const ZONE_PROPS := {
	"ch7": {
		"The Wayhouse": [
			{"sprite": "millers_boy", "x": 700, "y": 400, "prompt": "E — A young guard",
				"convo": "ch7_heron_recruit", "req_flag": "sq_kept_hat"},
		],
	},
}

const CONVOS := {
	"ch7_heron_recruit": {"start": "e1", "nodes": {
		"e1": {"who": "A Young Guard",
			"text": "A recruit no older than the war stands his watch at the Wayhouse door with the stiff pride of someone who CHOSE this. His helm is regulation. His HAT is not — a wide brown brim pinned up with a wolf tooth, a heron feather blue at the tip, worn over the steel like he'd fight anyone who told him to take it off.",
			"variants": [
				{"flag": "heron_recruit_met", "text": "The young guard nods to you like an old debt paid. \"Still standing, bearer. So am I.\"", "next": ""},
			],
			"next": "e2"},
		"e2": {"who": "A Young Guard", "text": "\"...You. You're the one who brought it back. To the mill.\" He touches the brim, once, the way you touch a thing to be sure it's real. \"I was a boy watching a road for a hat that wasn't coming. Then somebody walked a dead man's hat up it anyway — and I stopped watching the road, and started walking it. Signed with the Guard at the capital muster. They let me keep the hat. I did NOT ask twice.\"",
			"choices": [
				{"text": "\"Your father would know you in it.\"",
					"resonance": 3.0, "flags": {"heron_recruit_met": true}, "next": "e_kind"},
				{"text": "\"It's just a hat, recruit.\"",
					"flags": {"heron_recruit_met": true}, "next": "e_gruff"},
			]},
		"e_kind": {"who": "A Young Guard", "text": "His jaw works once. \"...That's the idea, bearer. That's the whole idea.\" He straightens, and stands his watch a little taller — a heron feather blue against the storm, on a road his father never finished and he means to.", "next": ""},
		"e_gruff": {"who": "A Young Guard", "text": "\"It's my father's hat, and I'm the one still wearing it toward the howling. That's not nothing, bearer.\" He's right, and you both know it. He turns back to his watch, the feather bright against the grey.", "next": ""},
	}},
}


# ---- CONTENT-MODULE TEST HOOK: called from autotest via _test_eggs() ----
static func selftest_present() -> bool:
	return Story.ALL_CONVOS.has("ch7_heron_recruit")
