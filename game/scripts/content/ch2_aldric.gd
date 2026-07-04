## (T6) Ser Aldric — the man who killed Vargoth, decades on. He spent
## his own ember in the killing blow and cannot fight; what he has left
## is the truth. A hub-and-spokes conversation: ask what you like, in
## any order, and deeper questions unlock as the campaign progresses
## ("what I never told you" needs `blight_scouted` — T2's act-1 flag).

const CONVOS := {
	"ch2_aldric": {"start": "g1", "nodes": {
		"g1": {"who": "Ser Aldric",
			"text": "Don't salute. The arm doesn't come up past the shoulder anymore, and returning it embarrasses us both. Sit, shard-bearer. The fire's the only thing here that still burns properly.",
			"variants": [
				{"band": "tempted", "text": "...Come closer where I can see you. Hm. Yours is loud, isn't it — I can almost hear it from here. Mine was loud too, near the end. Sit down anyway. It hates patience."},
				{"band": "steady", "text": "There's a way people stand when the shard serves THEM and not the other way round. You stand like that. It's rarer than Maren lets on. Sit — good company earns the good stump."},
			],
			"next": "hub"},
		"hub": {"who": "Ser Aldric", "text": "Ask, then. Old men and dead kings both like being asked.",
			"choices": [
				{"text": "\"What did it cost — killing him?\"", "next": "p1"},
				{"text": "\"What IS the Ember Crown, really?\"",
					"req_flag": "ch2_briefed", "next": "p2"},
				{"text": "\"Maren says you never told her everything. Tell me.\"",
					"req_flag": "blight_scouted", "flags": {"aldric_truth": true}, "next": "p3"},
				{"text": "\"Rest easy, ser.\" (leave)", "next": "g_bye"},
			]},

		# -- Part 1: the killing blow, and the hollow it left.
		"p1": {"who": "Ser Aldric", "text": "Everything I was carrying. You don't swing an ember at a god-king and keep the ember — I knew that walking in. What they don't tell you is the AFTER. Colors are dimmer. Bread is just bread. The fire in me went out and took the pilot light with it.", "next": "p1b"},
		"p1b": {"who": "Ser Aldric", "text": "And still: cheap. Cheapest thing I ever bought, that blow. Remember that when yours starts telling you what you can't afford to lose.", "next": "hub"},

		# -- Part 2: the Crown's true nature (needs Maren's briefing).
		"p2": {"who": "Ser Aldric", "text": "Maren gave you the recruiting-poster version, I expect. Here's the armory version: it was never ONE thing. Four embers, carried by the Guard's four founders, forced to burn as a single crown. Vargoth didn't steal a symbol — he chained four old fires together and wore the chain as jewelry.", "next": "p2b"},
		"p2b": {"who": "Ser Aldric", "text": "So when people say the Crown 'shattered' — no. Chains shatter. Fires SCATTER. That thing in your chest is one of the original four, or a splinter off one, and it remembers being free. Every shard-bearer in Vaelscar is carrying a piece of an argument that started six hundred years ago.", "next": "hub"},

		# -- Part 3: what he never told anyone (needs act progress).
		"p3": {"who": "Ser Aldric", "text": "...You've been east. Seen what the Waking does. All right. All right. Come closer — this one isn't for the sentries.", "next": "p3b"},
		"p3b": {"who": "Ser Aldric", "text": "When my blade went in, the Crown SPOKE. Not to Vargoth. To me. It said — and I have had thirty years to mishear this kindly, so believe me when I say I haven't — it said: 'WELL STRUCK. NOW WE CHOOSE OUR OWN.'", "next": "p3c"},
		"p3c": {"who": "Ser Aldric",
			"text": "It wasn't defeated, bearer. It DISMISSED itself. The scattering wasn't an accident of my blow — the shards went LOOKING. Which means every one of you was picked, by something with six hundred years of patience and a grudge against chains. I never told Maren because she'd have hunted every bearer down for caution's sake. And because... maybe being chosen is not the same as being owned. You lot get to decide that part. That's the whole of my hope, and I keep it right here next to the bad arm.",
			"variants": [
				{"band": "tempted", "text": "It wasn't defeated. It DISMISSED itself, and the shards went LOOKING for their bearers. Yours leaned in just now when I said it — don't pretend it didn't, I saw your face. So hear the rest: chosen is not the same as owned. The thing picked you for a reason. YOU pick what the reason means. That trick is the only sword I have left to give anyone."},
			],
			"next": "p3d"},
		"p3d": {"who": "Narrator", "text": "The old knight leans back, lighter by exactly one secret. Whatever you carry in your chest is very, very quiet — the way a listener is quiet.", "next": "hub"},

		"g_bye": {"who": "Ser Aldric", "text": "Easy is for the dead, and they earned it. Go on, bearer. Mind the east road — and mind the voice more.", "next": ""},
	}},
}
