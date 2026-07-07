## (Q2) Chapter 2 side quests — three flag-chain quests on the side-quest
## engine (QUESTS_TASKS.md), hooked onto existing NPCs by convo override:
##   still_blue          — Sera's mill arc (existing flags) as a visible quest
##   bread_for_the_road  — Sera's loaf, carried to Scholar Ivo in the Deeps
##   ash_for_aldric      — Ivo's sealed jar of Bastion ash, back to Aldric
## No zones, no new spawns: every hook lands on a fixed NPC that already
## stands in the world (ch2_hub.gd / ch2_zones_act2.gd / ch2_aldric.gd).

const SIDE_QUESTS := {
	"still_blue": {
		"name": "Still Blue",
		"chapter": "ch2",
		"desc": "Widow Sera's mill stood on the Greyrun — grey walls, and a door she repainted blue every spring for twenty years. She wants to know if the door held.",
		"steps": [
			{"flag": "mill_seen", "text": "Find the mill on the Greyrun — see whether the blue door stands"},
			{"flag": "mill_told", "text": "Bring Sera the truth"},
		],
		"reward": {"gold": 150},
	},
	"bread_for_the_road": {
		"name": "Bread for the Road",
		"chapter": "ch2",
		"desc": "Sera bakes for whoever mans the far crossings. This week that means a chronicler alone among the crystals, two wastes east of anywhere.",
		"steps": [
			{"flag": "loaf_taken", "text": "Take Sera's loaf from Maren's camp"},
			{"flag": "loaf_given", "text": "Deliver it to Scholar Ivo in the Crystal Deeps"},
		],
		"reward": {"gold": 150, "standing": {"accord": 2}},
	},
	"ash_for_aldric": {
		"name": "Ash for the Old Knight",
		"chapter": "ch2",
		"desc": "Ser Aldric wrote one letter in thirty years: a commission for a pinch of ash off the Null Bastion's road. 'I want to know what it burns like now.'",
		"steps": [
			{"flag": "ash_taken", "text": "Take the sealed jar from Scholar Ivo in the Crystal Deeps"},
			{"flag": "ash_given", "text": "Set it by Ser Aldric's fire at Maren's camp"},
		],
		"reward": {"gold": 200},
	},
}

const QUEST_ITEMS := {
	"sera_loaf": {"name": "Sera's Road Loaf",
		"desc": "Dark bread in waxed cloth, oven-warm when she tied it. Baked for whoever mans the far crossings.", "grade": "C"},
	"bastion_ash": {"name": "Jar of Bastion Ash",
		"desc": "Grey ash off the Null Bastion's road, sealed and labeled in Ivo's exact hand: 'ALDRIC — AS COMMISSIONED.'", "grade": "C"},
}

const CONVOS := {
	# OVERRIDES ch2_hub.gd's "ch2_refugee" — verbatim copy, extended:
	# r1 gains choices (Still Blue accept / bread courier / leave), and the
	# mill_told variant now flows to r_after so the bread ask stays
	# reachable once the mill arc closes. The mill payoff flow itself
	# (mill_seen -> r_told -> r_told2) is untouched.
	"ch2_refugee": {"start": "r1", "nodes": {
		"r1": {"who": "Widow Sera",
			"text": "We had a mill on the Greyrun. Then the water came up black one morning, and that was that. Maren says the land can be cleaned. I say she believes it because someone has to.",
			"variants": [
				# Payoff first (playtest fix): she asked about the blue door —
				# if you went and looked, she must KNOW you did.
				{"flag": "mill_told", "text": "Sera nods as you pass, the way people nod at good weather. \"Still blue,\" she says, to herself as much as you. She has stopped saying 'we HAD a mill.'", "next": "r_after"},
				{"flag": "mill_seen", "text": "\"You went.\" She reads it off your face before you speak. \"...And it stands? The door held?\" She sits down slowly on the cook-bench. \"Twenty years of spring paint. You tell Maren she's right — the land can be cleaned. Some of it is clean ALREADY.\"", "next": "r_told"},
				{"band": "tempted", "text": "My gran used to say the blight gets in through what you want most. ...Why are you looking at me like that, shard-bearer?"},
				{"band": "steady", "text": "You have kind eyes for someone carrying a dead king's splinter. If you get as far as the Greyrun... the mill had a blue door. I'd like to know if it's standing."},
			],
			"next": "",
			"choices": [
				{"text": "\"The Greyrun is on my road east. I'll look for your mill — and the door.\"",
					"req_not_flag": "sq_on_still_blue", "resonance": 2.0,
					"side_quest": "still_blue", "next": "r_accept"},
				{"text": "\"I'm bound for the far crossings next. Anything I can carry?\"",
					"req_flag": "act1_complete", "req_not_flag": "loaf_taken",
					"gain_item": "sera_loaf", "flags": {"loaf_taken": true},
					"side_quest": "bread_for_the_road", "next": "r_loaf"},
				{"text": "\"Keep the fire, Sera.\" (leave)", "next": ""},
			]},
		"r_told": {"who": "Widow Sera", "text": "\"Twenty years I painted that door. Tell me true, once more — it stands?\"",
			"next": "",
			"choices": [
				{"text": "\"It stands, Sera. The paint is winning.\"",
					"flags": {"mill_told": true}, "resonance": 2.0, "next": "r_told2"},
			]},
		"r_told2": {"who": "Narrator", "text": "Small honest cargo, delivered. It weighed nothing, and it was worth the trip.", "next": ""},
		"r_accept": {"who": "Widow Sera", "text": "\"Blue. There won't be two of them out there. I sanded and repainted it every spring for twenty years — the rot hates being argued with.\" She looks at her hands. \"Don't dress it up for me, whatever you find. I've had enough weather turned kind by liars.\"", "next": ""},
		"r_loaf": {"who": "Widow Sera", "text": "She wraps a dark loaf in waxed cloth, knots it like it's going somewhere important, and weighs it once in her hand before letting it go. \"For whoever mans the far crossings — the chronicler in the crystal deep, if the crystals haven't talked him deaf. Tell him it's from Sera. Not 'the camp'. Sera.\"", "next": ""},
		"r_after": {"who": "Widow Sera", "text": "\"The ovens don't stop just because the door held. Camp still eats — and the far crossings stand their watch hungry.\"",
			"next": "",
			"choices": [
				{"text": "\"I'm bound for the far crossings next. Anything I can carry?\"",
					"req_flag": "act1_complete", "req_not_flag": "loaf_taken",
					"gain_item": "sera_loaf", "flags": {"loaf_taken": true},
					"side_quest": "bread_for_the_road", "next": "r_loaf"},
				{"text": "\"Keep the fire, Sera.\" (leave)", "next": ""},
			]},
	}},

	# OVERRIDES ch2_zones_act2.gd's "ch2_scholar" — verbatim copy, extended:
	# the scholar_met revisit variant now lands on s_desk (it used to end
	# the scene, which would strand both courier hooks), s2 gains the two
	# gated quest choices at the END (autotest still picks choice 0), and
	# the new nodes carry Sera's loaf payoff and Aldric's ash commission.
	"ch2_scholar": {"start": "s1", "nodes": {
		"s1": {"who": "Scholar Ivo",
			"text": "Mind the resonance, shard-bearer — the crystals repeat what they hear, and some of what they heard down here predates manners. Ivo. Chronicler. Unaffiliated, whatever the envoy tells you.",
			"variants": [
				{"flag": "scholar_met", "text": "\"Still standing? Statistically remarkable. The Bastion is ahead — my notes, regrettably, end where they get interesting.\"", "next": "s_desk"},
				{"band": "tempted", "text": "The scholar looks up — then looks HARDER, the way one reads a difficult footnote. \"Fascinating. Yours is further along than most. Do sit AWAY from the crystals, if you please — they repeat things.\""},
				{"band": "steady", "text": "\"Ah — a quiet one. The crystals barely hum around you. That is the rarest reading I've taken all year, shard-bearer; I intend to write it down twice.\""},
			],
			"next": "s2"},
		"s2": {"who": "Scholar Ivo", "text": "Free knowledge, since you're heading east anyway: the Bastion ahead predates Vargoth — an ARMORY, from the war the Concord ended. What woke inside it is not blighted and not beastkin. It is MAINTENANCE, resumed after six hundred years, and it has decided the whole region is out of specification.",
			"choices": [
				{"text": "\"What do your notes say about killing it?\"",
					"flags": {"scholar_met": true}, "next": "s3"},
				{"text": "Hand over the waxed-cloth bundle. \"From Sera, at Maren's camp. She says the far crossings stand their watch hungry.\"",
					"req_flag": "loaf_taken", "req_not_flag": "loaf_given",
					"lose_item": "sera_loaf", "flags": {"loaf_given": true},
					"resonance": 2.0, "next": "s_loaf"},
				{"text": "Nod at the sealed jar on his sample desk — the one labeled ALDRIC.",
					"req_not_flag": "ash_taken", "next": "s_jar"},
			]},
		"s3": {"who": "Scholar Ivo", "text": "\"Shed its armor before it sheds yours — it protects the frame, not the function. And when the grid stamps, DON'T be where you were standing. That sentence has cost four lives to write, so do me the courtesy of surviving it.\"", "next": ""},
		"s_desk": {"who": "Scholar Ivo", "text": "\"Back again. Good — the crystals repeat dull company.\" He waves at the sample desk without looking up.",
			"next": "",
			"choices": [
				{"text": "Hand over the waxed-cloth bundle. \"From Sera, at Maren's camp. She says the far crossings stand their watch hungry.\"",
					"req_flag": "loaf_taken", "req_not_flag": "loaf_given",
					"lose_item": "sera_loaf", "flags": {"loaf_given": true},
					"resonance": 2.0, "next": "s_loaf"},
				{"text": "Nod at the sealed jar on his sample desk — the one labeled ALDRIC.",
					"req_not_flag": "ash_taken", "next": "s_jar"},
				{"text": "\"Mind the crystals, Ivo.\" (leave)", "next": ""},
			]},
		"s_loaf": {"who": "Scholar Ivo", "text": "\"...Bread. OVEN bread.\" He takes the bundle in both hands, the way one handles a first edition. \"I have catalogued four hundred resonance events this year, bearer, and this is the finest data among them. Tell Sera the crossing is manned — and that the crossing says thank you. From Ivo. Not 'the deeps'. Ivo.\"", "next": ""},
		"s_jar": {"who": "Scholar Ivo", "text": "\"Ah. A commission, technically — Ser Aldric wrote me exactly one letter in thirty years. 'A pinch of ash off the Bastion road. I want to know what it burns like now.' His words. I collected it in the spring; the couriers, you'll have noticed, stopped running.\" He taps the wax seal. \"The jar weighs nothing, and the debt isn't yours. But you ARE walking west.\"",
			"choices": [
				{"text": "Take the jar. \"An old knight's one letter shouldn't go unanswered.\"",
					"req_not_flag": "ash_taken", "resonance": 2.0,
					"gain_item": "bastion_ash", "flags": {"ash_taken": true},
					"side_quest": "ash_for_aldric", "next": "s_ash"},
				{"text": "\"Not my road today.\" Leave it on the desk.", "next": ""},
			]},
		"s_ash": {"who": "Scholar Ivo", "text": "\"Careful hands. It took the wind six centuries to grind the Bastion road that fine — a fact I will thank you not to test by dropping it.\" He returns to his instruments, then, without looking up: \"Tell the old man the chronicler keeps his ledgers. All of them.\"", "next": ""},
	}},

	# OVERRIDES ch2_aldric.gd's "ch2_aldric" — verbatim copy, extended with
	# one hub choice appended at the END, gated on actually carrying Ivo's
	# jar (req_flag ash_taken): invisible in every suite convo-walk state,
	# so the hub's asserted choice counts (3 pre-act, 4 post) still hold.
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
				# One-time reveal: once told, the question retires (playtest
				# fix — "I never told anyone" rang false on the second ask).
				{"text": "\"Maren says you never told her everything. Tell me.\"",
					"req_flag": "blight_scouted", "req_not_flag": "aldric_truth",
					"flags": {"aldric_truth": true}, "next": "p3"},
				{"text": "\"Rest easy, ser.\" (leave)", "next": "g_bye"},
				{"text": "Set a sealed jar by the fire. \"Bastion ash, ser. Ivo kept your commission.\"",
					"req_flag": "ash_taken", "req_not_flag": "ash_given",
					"lose_item": "bastion_ash", "flags": {"ash_given": true},
					"resonance": 2.0, "next": "p_ash"},
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

		# -- The ash commission, answered (Q2: ash_for_aldric payoff).
		"p_ash": {"who": "Narrator", "text": "He works the wax off one-handed, unhurried, like a man opening a letter he already knows the contents of. Then he takes a pinch and feeds it to his own small fire. It burns orange. Just orange. He watches it the way other men watch a grave filled in.", "next": "p_ash2"},
		"p_ash2": {"who": "Ser Aldric", "text": "It burned GREEN, the night we took that road. Sixty years the ash held the color of the wound — I know, I kept asking. And now it's just ash again. The land forgets faster than the men do, bearer. That is the kindest thing anyone has carried me in years, and it came in a JAR.", "next": "hub"},

		"g_bye": {"who": "Ser Aldric", "text": "Easy is for the dead, and they earned it. Go on, bearer. Mind the east road — and mind the voice more.", "next": ""},
	}},
}
