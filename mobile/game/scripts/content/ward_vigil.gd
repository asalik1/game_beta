## The tower lamp exists before the ask. A real, retryable defense answers it.
const SIDE_QUESTS := {
	"tower_light": {
		"name": "A Light on the Road", "chapter": "ch1",
		"completed_flag": "sq_kept_tower_light",
		"desc": "Lamplighter Mara still leaves oil for a watchtower that no longer answers. Light its old ward, stand inside its circle, and survive the three waves drawn to the flame.",
		"steps": [
			{"kind": "defend", "flag": "ward_tower_lit", "text": "Defend the ward at the Collapsed Tower through three waves"},
			{"flag": "tower_light_told", "text": "Tell Mara in Emberfall that the road has a light again"},
		],
		"reward": {"kept": "sq_kept_tower_light"},
	},
}

const ZONE_PROPS := {"ch1": {"Emberfall Village": [
	{"sprite": "villager", "x": 620, "y": 860, "prompt": "E — A woman with an oil can", "convo": "lamplighter_mara"},
]}}

const CONVOS := {
	"lamplighter_mara": {"start": "m1", "nodes": {
		"m1": {"who": "Lamplighter Mara", "text": "Every seventh evening I leave a can of oil by the north road. Habit, they tell me. The Collapsed Tower hasn't answered in sixty years. But someone might be walking home tonight who doesn't know that.",
			"variants": [
				{"flag": "sq_kept_tower_light", "text": "I saw it from the mill bridge. Just a pinprick. Enough to walk toward. I've filled another can; a light is a thing you keep doing.", "next": ""},
				{"flag": "ward_tower_lit", "text": "There's soot on your sleeve. New soot. Tell me that isn't what I think it is.", "next": "m_found"},
				{"flag": "sq_on_tower_light", "text": "The ward drinks courage before it drinks oil. Stay within the ring and keep the creatures away from its heart. Three waves, then the flame remembers. If it gutters, you can try again.", "next": ""},
			],
			"choices": [
				{"text": "I'll see whether the old ward remembers its work.", "side_quest": "tower_light", "next": "m_how"},
				{"text": "Keep the oil dry. I may yet take that road.", "next": ""},
			]},
		"m_how": {"who": "Lamplighter Mara", "text": "Clear the tower first. The brazier stands in the open court. Lighting it draws three waves out of the ruins. Stand within the ring; keep them out of the small circle. If you need to stop, snuff the brazier. No shame in coming back alive.", "next": ""},
		"m_found": {"who": "Lamplighter Mara", "text": "Her hands close around the oil can. For once she doesn't seem to know what to do with it.", "choices": [
			{"text": "The tower is lit. I stood its watch.", "side_quest": "tower_light", "next": "m_answer"},
			{"text": "I'll come back when I can tell it properly.", "next": ""},
		]},
		"m_answer": {"who": "Lamplighter Mara", "text": "My father said his father kept that lamp. I thought what I'd inherited was the waiting. She looks past you toward the north road. It seems I inherited a job.", "next": "m_can"},
		"m_can": {"who": "Narrator", "text": "She sets a full can by the door, then brings a second. A small, practical kind of faith: somebody will need oil tomorrow.", "choices": [
			{"text": "Leave her with tomorrow's work.", "flags": {"tower_light_told": true}, "next": ""},
		]},
	}},
}
