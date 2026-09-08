## The traveler exists before the promise. The escort owns its completion.
const SIDE_QUESTS := {
	"one_more_mile": {
		"name": "One More Mile", "chapter": "ch1", "completed_flag": "sq_kept_wayfarer",
		"desc": "Tovin can see the village lamps, but the wolves have followed him for miles. Walk him across the outskirts, keep close when they catch up, and let him reach the fire on his own feet.",
		"steps": [
			{"kind": "escort", "flag": "escort_tovin_home", "text": "Walk Tovin to the campfire in Village Outskirts"},
			{"flag": "tovin_thanked", "text": "Speak with Tovin beside the campfire"},
		],
		"reward": {"kept": "sq_kept_wayfarer"},
	},
}

const CONVOS := {
	"wayfarer_tovin": {"start": "hello", "nodes": {
		"hello": {"who": "Tovin", "text": "You can see the lamps from here. That's the part that gets me. I've walked a hundred miles, and this last one has teeth.",
			"variants": [
				{"flag": "sq_kept_wayfarer", "text": "I've put a kettle by the fire. Seems a poor repayment for a road, but the next traveler won't know that. They'll only know there's hot water.", "next": ""},
				{"flag": "escort_tovin_home", "text": "He eases the pack to the ground, then keeps one hand on it as if it might walk away. The fire is real. It takes him a moment to believe it.", "next": "thanks"},
			],
			"choices": [
				{"text": "I'll walk the last stretch with you.", "side_quest": "one_more_mile", "next": "how"},
				{"text": "Stay by the road. I'll come back.", "next": ""},
			]},
		"how": {"who": "Tovin", "text": "Thank you. Speak to me again when you're ready to move. I'll keep to the road. If you need me to wait, just say. When the wolves come, don't let them close around me. If my nerve goes, we'll fall back and try again.", "next": ""},
		"thanks": {"who": "Tovin", "text": "A hundred miles alone, he says. I don't remember most of them. I'll remember this one.",
			"choices": [{"text": "Set down the pack. You're home.", "side_quest": "one_more_mile", "flags": {"tovin_thanked": true}, "next": "kettle"}]},
		"kettle": {"who": "Narrator", "text": "Before he sits, he takes a dented kettle from the pack and fills it. Someone else may be walking this way. He leaves room for them beside the fire.", "next": ""},
	}},
}
