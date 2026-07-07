## (Q6) Chapter 6 side quests — The Blooming Deep. Content module (see
## README.md): three flag-chain side quests on the side-quest engine,
## registered via one line in Story.CONTENT_MODULES.
##
##   ch6_far_shore  — Fisher Dov's ask: find what the Root keeps of the
##                    far shore (the Pale Gallery), come back, tell TRUE.
##   ch6_gate_bread — Vela's loaf carried from the gate flock to the
##                    schism camps' table (courier, choir standing).
##   ch6_kesh_tally — Kesh's survey: mark two overgrown props for the
##                    camps' maps, report the tally (wildfang standing).
##
## All hooks are convo OVERRIDES of ch6_zones.gd surfaces — no zones,
## no NPCs added. Quest choices are appended at the END of choice lists
## and gated on sq_on_*/step flags; revisit variants that used to end
## with next "" are extended into new nodes so the hooks stay reachable
## after first contact (the walker only talks to gate NPCs pre-brief).

const SIDE_QUESTS := {
	"ch6_far_shore": {
		"name": "The Far Shore's Door",
		"chapter": "ch6",
		"desc": "Fisher Dov hasn't rowed past the leaning reeds since midsummer, and nobody has seen the far shore. Find what the Root keeps of it — and come back and tell him true.",
		"steps": [
			{"flag": "sq6_shore_seen", "text": "Find the far shore's remainders in the deep root gallery"},
			{"flag": "sq6_shore_told", "text": "Return to Fisher Dov at the Pilgrim Gate — and tell it true"},
		],
		"reward": {"gold": 150},
	},
	"ch6_gate_bread": {
		"name": "Bread Between Camps",
		"chapter": "ch6",
		"desc": "Deacon Vela's flock bakes at the gate while the schism camps let a stale loaf sit between them. Carry a fresh one down. It won't mend the doctrine. It might mend supper.",
		"steps": [
			{"flag": "sq6_bread_taken", "text": "Take the gate camp's loaf from Deacon Vela"},
			{"flag": "sq6_bread_left", "text": "Set it on the table between the schism camps"},
		],
		"reward": {"gold": 120, "standing": {"choir": 2}},
	},
	"ch6_kesh_tally": {
		"name": "Kesh's Tally",
		"chapter": "ch6",
		"desc": "The Bloom takes ground faster than the cure-camp's runners can map it. Mark what the green has claimed — the sunken shrine, the cure pool's fence — and bring Kesh the tally.",
		"steps": [
			{"flag": "sq6_tally_shrine", "text": "Cut the survey-mark at the Sunken Shrine"},
			{"flag": "sq6_tally_pool", "text": "Cut the survey-mark on the Cure Pool's fence line"},
			{"flag": "sq6_tally_told", "text": "Report the tally to Herbalist Kesh at the Pilgrim Gate"},
		],
		"reward": {"gold": 180, "standing": {"wildfang": 3}},
	},
}

const QUEST_ITEMS := {
	"ch6_gate_loaf": {"name": "The Gate Camp's Loaf", "grade": "C",
		"desc": "Fresh from the gate flock's baking stone, wrapped in linen. Bound for the table between the schism camps — refusing Vela's bread is a heresy neither side has the doctrine for."},
}

const CONVOS := {
	# OVERRIDES ch6_zones.gd's ch6_fisher — first-meeting flow unchanged;
	# the ch6_dov_heard revisit now leads to Dov's ask (accept), and new
	# quest-state variants handle the reminder / report / closing beats.
	"ch6_fisher": {"start": "f1", "nodes": {
		"f1": {"who": "Fisher Dov",
			"text": "Thirty years I've fished this bog — it takes, that's its NATURE, a net a season and a cousin a decade. I made my peace with a taking bog. Then last spring it started giving BACK. Fish I never stocked. Fruit on the drowned trees. My old dog, bearer — dead four winters — scratching at the door one morning, looking exactly right. That's when I moved to the gate. Exactly right is how you know.",
			"variants": [
				{"flag": "sq6_shore_told", "text": "The far shore keeps what it keeps, and now I know the shape of it. That's more than the bog ever gave me for free. The dog still comes by, nights — and since you told me, bearer, I feel no pull at all to call him in. Knowing does that.", "next": ""},
				{"flag": "sq6_shore_seen", "text": "You've been past the canal — it's on your boots and in your eyes. The far shore, bearer. Brekk's door. Tell me.", "next": "f_report"},
				{"flag": "sq_on_ch6_far_shore", "text": "The far shore's past the leaning reeds — but the reeds are only the fence, bearer. What the bog TOOK, it keeps deeper in, where the white roots run. Look where everything green in this Deep is headed: down and inward. You'll know his door. Blue.", "next": ""},
				{"flag": "ch6_dov_heard", "text": "The dog still comes by, nights. Sits past the firelight, looking exactly right. I don't call him in. Hardest thing I do, most nights, not calling him in.", "next": "f_quest"},
			],
			"choices": [
				{"text": "\"You did right, Dov. The bog that takes is honest — the one that gives back wants something.\"",
					"resonance": 4.0, "flags": {"ch6_dov_heard": true}, "next": "f_right"},
				{"text": "\"...What happens if you call the dog in?\"",
					"resonance": -3.0, "flags": {"ch6_dov_heard": true}, "next": "f_ask"},
			]},
		"f_right": {"who": "Fisher Dov", "text": "Wants something. Aye. My gran said it plainer: 'free is the most expensive price.' Thirty years fishing and the spring the bog turned generous is the spring I lost my nerve. Tells you everything about what kind of generous it is.", "next": ""},
		"f_ask": {"who": "Fisher Dov", "text": "...Brekk from the far shore called his wife in. She'd been dead two years and she came back exactly right, and for a month the far shore was the happiest place in the bog. Nobody's seen the far shore since midsummer, bearer. The reeds there grow forty feet and they LEAN toward you when you row past. Don't ask me that again, and don't ask ME why I still leave the door unlatched.", "next": ""},
		# Dov's ask — the quest hook, reachable on any revisit after his story.
		"f_quest": {"who": "Fisher Dov",
			"text": "Since you're bound for the Deep anyway, bearer — a fisher's ask. Brekk's croft sat on the far shore. Blue door; he painted it for his wife the spring before she died the first time. Nobody's rowed past the leaning reeds since midsummer, and I can't. Find what's left of the shore. Then come back and tell me TRUE — I've had a bellyful of the bog's kind of giving.",
			"choices": [
				{"text": "\"I'll find the far shore, Dov. And you'll get it true — whatever it turns out to be.\"",
					"resonance": 2.0, "side_quest": "ch6_far_shore", "next": "f_sworn"},
				{"text": "\"Some doors are better left unchecked. Ask me another season.\"", "next": ""},
			]},
		"f_sworn": {"who": "Fisher Dov", "text": "True. You'd be surprised how few will promise the word without dressing it first. The bog took the far shore going on a year now — whatever the Deep did with it, it did it where the white roots run. Follow the roots down, bearer. Everything in this Deep that gets KEPT ends up along that bearing.", "next": ""},
		"f_report": {"who": "Fisher Dov",
			"text": "I've mended the same net three times since you walked in there, just for something honest to hold. Say it plain, bearer. I'll stand it.",
			"choices": [
				{"text": "\"The Root has the shore. Brekk's door stands in the deep gallery — grown into the wall, blue as the day he painted it, nobody behind it. It keeps what it likes best.\"",
					"resonance": 2.0, "flags": {"sq6_shore_told": true}, "next": "f_true"},
				{"text": "\"Gone, Dov. The shore, the croft, all of it — under the bog and past rowing to. That's true enough to carry.\"",
					"resonance": -2.0, "flags": {"sq6_shore_told": true}, "next": "f_soft"},
			]},
		"f_true": {"who": "Fisher Dov", "text": "...In the WALL. Flame keep him. ...Good. That's a truth with edges — a man can get a grip on a thing like that without it slipping. Take the far-shore share, bearer; Brekk's catch was half mine by the old net-rights, and rights want SETTLING, not keeping. Last night the dog sat past the firelight, exactly right, and for the first time since spring I felt no pull to call him in. That's what true buys. Cheap at any price.", "next": ""},
		"f_soft": {"who": "Fisher Dov", "text": "...Under. Aye. He looks at you a long moment — a man who has fished lies out of this bog for thirty years and knows the exact weight of a kind one. \"Then 'under' is what I'll tell his kin at the gate,\" he says, even as still water. \"Some accounts a man closes the way his neighbors can live with.\" He presses the far-shore share on you anyway. He does not thank you, and he does not ask again, and both of those are answers.", "next": ""},
	}},

	# OVERRIDES ch6_zones.gd's ch6_briefing — the briefing path (b1..b3,
	# choice order) is untouched; the ch6_briefed revisit variant now
	# leads to Vela's loaf ask, with quest-state variants ahead of it.
	"ch6_briefing": {"start": "b1", "nodes": {
		"b1": {"who": "Deacon Vela",
			"text": "A shard-bearer, at OUR gate. The flame has a sense of humor after all. Vela — deacon of the pilgrimage, or of what the Deep has left of it. Before you size up my grey habit and decide I'm your enemy: out here, deacon mostly means the one who keeps the count when people don't come back.",
			"variants": [
				{"flag": "sq6_bread_left", "text": "Word came up from the Rest with the evening pilgrims: the loaf crossed the table. BOTH camps ate, bearer. Sixty years of schism and supper held — the flame keeps its jokes small and its mercies smaller, and I have learned to bank on either.", "next": ""},
				{"flag": "sq6_bread_taken", "text": "The loaf travels better than doctrine, bearer, but not forever. The schism table sits with the split camps, off the pilgrim paths past the fringe — set it down between them and let the bake argue for us.", "next": ""},
				{"flag": "ch6_briefed", "text": "The fringe first, bearer — nothing moves in the Deep while the Auroch holds the wallow.", "next": "b_gate"},
				{"flag": "chose_wagon_south", "text": "You're the bearer from the ice — the one who hauled a wagon of sleepers back to the fires. My faithful argued about you for three nights. Half called it desecration of a vow. The other half quietly wished someone had hauled THEIR kin south. I was in the second half. Vela. Deacon. Welcome to a worse question."},
				{"flag": "chose_wagon_north", "text": "You're the bearer from the ice — the one who finished a dead porter's haul and delivered eleven sleepers to their vow. My faithful approved; vows are our trade. I keep wondering about YOUR nights since. Vela. Deacon. Welcome to a worse question."},
			],
			"next": "b2"},
		"b2": {"who": "Deacon Vela", "text": "We came on pilgrimage. The blight is the land telling the truth — rot comes for everything; the Choir simply stopped calling that bad news. Sixty years of that creed, bearer, and it HELD, through plague and Vale and worse. Then we walked into the Deep and found the opposite of rot: growth without death. Things that only add. And half my flock knelt to it on sight.", "next": "b3"},
		"b3": {"who": "Deacon Vela", "text": "The Auroch holds the wallow — the bog-bull that drowned a century back and never stopped growing. Past it, Rotmaw: MY deacon once, now gardener to the lie. And in the heart of the Bloom, the Wildfang shaman Kaethra, who drank the green looking for a cure. Both her camps agree she cannot leave the Deep. When Wildfang camps agree, bearer, the thing they agree on is always terrible.",
			"choices": [
				{"text": "\"I'll clear the way and hear Kaethra out before anything ends. She's owed that much.\"",
					"resonance": 6.0, "flags": {"ch6_briefed": true}, "quest": "auroch", "next": "b_owed"},
				{"text": "\"Growth without death sounds like a weapon somebody should bottle before it's destroyed.\"",
					"resonance": -8.0, "flags": {"ch6_briefed": true, "chose_covets_bloom": true}, "quest": "auroch", "next": "b_bottle"},
				{"text": "\"Auroch, gardener, shaman. I'll work inward. Keep your flock at the gate.\"",
					"resonance": 0.0, "flags": {"ch6_briefed": true}, "quest": "auroch", "next": "b_work"},
			]},
		"b_owed": {"who": "Deacon Vela", "text": "Owed. Yes. ...You know what the Deep has taught me, bearer? Every creed I own fits a funeral. NONE of them fit a woman who cured herself into something worse and stayed kind through it. Hear her out. And come tell an old deacon what you heard — my theology needs the bruise.", "next": ""},
		"b_bottle": {"who": "Deacon Vela", "text": "Bottle it. Flame preserve us — that's exactly what Kaethra thought, and she was wiser than you and twice as careful, and the bottle is currently WEARING her. Go look at what bottling costs before you price it. The Deep does theology by demonstration.", "next": ""},
		"b_work": {"who": "Deacon Vela", "text": "Inward it is. The flock stays gated — those that still listen to me. The ones that don't are past the canal, in Rotmaw's congregation now, and bearer... they were mine. Whatever you must do out there, know that someone at this gate is still praying for them by NAME.", "next": ""},
		# Vela's loaf — the courier hook, offered once the briefing is done.
		"b_gate": {"who": "Deacon Vela",
			"text": "One small thing, bearer — small the way load-bearing things are. My flock bakes at this gate every morning; it's the one liturgy the Deep hasn't found an argument against. Meanwhile the split camps at the schism table have let a loaf go STALE between them because neither side will eat first. Carry a fresh one down? It won't mend the doctrine. It might mend supper.",
			"choices": [
				{"text": "\"Bread I can carry. Doctrine's your trade, deacon.\"",
					"resonance": 2.0, "side_quest": "ch6_gate_bread", "flags": {"sq6_bread_taken": true},
					"gain_item": "ch6_gate_loaf", "next": "b_loaf"},
				{"text": "\"The Deep first. The bread will keep better than I will.\"", "next": ""},
			]},
		"b_loaf": {"who": "Deacon Vela", "text": "Still warm off the stone. She wraps it in gate-linen with the exact care she'd give a relic, which — watch her hands — is what she considers it. \"Set it BETWEEN them, bearer, not nearer either camp. In a schism the table's midpoint is surveyed to the finger-width, and both sides will check.\"", "next": ""},
	}},

	# OVERRIDES ch6_zones.gd's ch6_wildfang — first-meeting flow unchanged;
	# the ch6_kesh_heard revisit now continues into Kesh's survey ask, and
	# the tally is debriefed mark by mark (req_flag-gated chain).
	"ch6_wildfang": {"start": "k1", "nodes": {
		"k1": {"who": "Herbalist Kesh",
			"text": "You came. Good — I sent the runner, so whatever happens in the Deep, the weight of it starts with me. Kesh, cure-camp. Kaethra was my teacher, my chief, and the best of us by a margin I won't insult with modesty. I need you to understand what she is before you meet what she's become.",
			"variants": [
				{"flag": "sq6_tally_told", "text": "Both your marks are on the camps' maps, bearer, and the hunt-camp's runners re-walked the bearings and found them TRUE — which did more for the peace than the payment did. Kaethra's rule holds: an honest count, honestly paid.", "next": ""},
				{"flag": "sq_on_ch6_kesh_tally", "text": "The tally, bearer — let's have it while the light holds. The Deep moves at night and my maps age like bread.", "next": "k_tally"},
				{"flag": "ch6_kesh_heard", "text": "The Deep is that way, bearer. Whatever the Root left of her — she'd want it met with clear eyes. Both camps are behind you. Flame, that sentence still sounds wrong.", "next": "k_offer"},
			],
			"next": "k2"},
		"k2": {"who": "Herbalist Kesh", "text": "Our whole people is one argument: cure the beast-blood, or accept it. Kaethra led the cure camp — and she was HONEST, bearer, that's the wound of it. She wouldn't test the Root's green on a child or a volunteer or an enemy. Herself only. It worked. The beast in her blood is gone... and the Root moved into the empty room. Now the hunt-camp says 'we told you so' and weeps while saying it.",
			"choices": [
				{"text": "\"When it's done, I'll carry her answer back to both camps — whatever it turns out to be.\"",
					"resonance": 5.0, "faction": {"wildfang": 3}, "flags": {"ch6_kesh_heard": true}, "next": "k_carry"},
				{"text": "\"So the cure question is settled, then. That's worth knowing, whatever it cost.\"",
					"resonance": -3.0, "flags": {"ch6_kesh_heard": true}, "next": "k_cold"},
			]},
		"k_carry": {"who": "Herbalist Kesh", "text": "Her ANSWER. Yes — that's the first framing of this that hasn't made me want to break something. She always said the argument would end with evidence, not victory. She just never meant to BE it. Go, bearer. And if any part of her is still choosing words in there... let her finish them.", "next": ""},
		"k_cold": {"who": "Herbalist Kesh", "text": "...Settled. Aye, the way a fire settles a granary dispute. You're not wrong, bearer, and I'll thank you to never say it that way inside the camp. WORTH and COST are hunt-camp words this week. We're all hunt-camp this week.", "next": ""},
		# Kesh's survey — the pilgrimage hook, offered after her story.
		"k_offer": {"who": "Herbalist Kesh",
			"text": "One more thing, since both camps trust your eyes now: the Bloom takes ground faster than my runners can map it, and three of my survey stakes went into the Deep and never reported back. Mark what the green has claimed — the Choir's sunken wayshrine, and the fence line at HER pool — and bring me the tally. Kaethra kept the survey honest for ten years. Somebody still has to.",
			"choices": [
				{"text": "\"I'll carry the tally. Her stakes stopped at the gallery's edge — someone should push the line.\"",
					"resonance": 2.0, "side_quest": "ch6_kesh_tally", "next": "k_go"},
				{"text": "\"Maps later, Kesh. The Deep first.\"", "next": ""},
			]},
		"k_go": {"who": "Herbalist Kesh", "text": "Cut the marks plain and deep, and date nothing — the Root reads patience off a date the way we read tracks. What the maps need is WHERE the green stood the day somebody sober looked at it. That's the whole science we have left down here, bearer, and she built it. Keep it standing.", "next": ""},
		"k_tally": {"who": "Herbalist Kesh",
			"text": "The wayshrine first — the Choir stone that sank. Did the green truly collar it?",
			"choices": [
				{"text": "\"Marked. The flowers open at dawn facing the lintel — a congregation. Your map won't like it.\"",
					"req_flag": "sq6_tally_shrine", "next": "k_tally2"},
				{"text": "\"Not yet — the shrine's still uncounted.\"", "next": ""},
			]},
		"k_tally2": {"who": "Herbalist Kesh",
			"text": "And the pool. Her pool. The fence?",
			"choices": [
				{"text": "\"Marked. The stakes lean inward a hand's width past last season's line. The pull is real, and it is patient.\"",
					"req_flag": "sq6_tally_pool", "flags": {"sq6_tally_told": true}, "next": "k_done"},
				{"text": "\"The fence line's not marked yet.\"", "next": ""},
			]},
		"k_done": {"who": "Herbalist Kesh", "text": "A congregation and a leaning fence. She'd have traded a finger for a tally this clean. Both marks go on the camps' maps tonight, and the young scouts learn your bearings by heart before they learn anything else. Here — surveyor's share, from the cure-camp chest. Kaethra's rule, and now yours: the count gets PAID, so the count stays honest.", "next": ""},
	}},

	# OVERRIDES ch6_zones.gd's ch6_lore_gallery — base text untouched; a
	# quest-gated search choice (filtered out otherwise, node stays linear)
	# and a found-state variant carry the far-shore payoff.
	"ch6_lore_gallery": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A gallery of white roots, thick as bridge-cables, running through the peat in one direction: down. Every root in the Deep, whatever it feeds above, bends eventually to this bearing. The cure-camp's survey stakes stop at the gallery's edge; the last stake carries Kaethra's own tag, in a steady hand: 'ALL ONE PLANT. STOP CALLING THEM ROOTS. THESE ARE FINGERS.'",
			"variants": [
				{"flag": "sq6_shore_seen", "text": "The gallery keeps its one bearing: down. And in the west face, where you found it, Brekk's blue door stands in its collar of white cable — exactly right, and exactly wrong. You do not try the latch this time either. Dov is owed the truth. Nobody is owed what's behind it.", "next": ""},
			],
			"choices": [
				{"text": "Walk the west face and search for the far shore's remainders — Dov's neighbor Brekk had a blue door.",
					"req_flag": "sq_on_ch6_far_shore", "flags": {"sq6_shore_seen": true}, "next": "g_door"},
			],
			"next": ""},
		"g_door": {"who": "Narrator", "text": "The west face is where the thickest cables come up from under the bog — the bearing of the far shore. It takes an hour of peat and white root, and then it stops taking any looking at all: set INTO the gallery wall, framed in cable thick as your leg, a door. Blue paint. Brass latch. A boot-scrape at the sill, worn by one man's habit. Exactly right. The Root never subtracts — somewhere under the bog it has the croft, and the reeds, and whatever answered when Brekk called his wife in. You take Dov's truth from the wall with your eyes only, and you leave the latch its silence.", "next": ""},
	}},

	# OVERRIDES ch6_zones.gd's ch6_lore_shrine — base text untouched; a
	# tally-gated mark choice and a marked-state variant.
	"ch6_lore_shrine": {"start": "l1", "nodes": {
		"l1": {"who": "Narrator", "text": "A Choir wayshrine, sunk to its lintel — the pilgrims built it the week they arrived, to consecrate the Deep to holy rot. The bog swallowed it in a season, which the faithful took as acceptance. Then the Blooming found it: the shrine now stands in a collar of flowers that open every dawn, facing it, like a congregation. The Choir won't go near it. Nothing they own has a rite for being WORSHIPPED BACK.",
			"variants": [
				{"flag": "sq6_tally_shrine", "text": "The wayshrine stands in its congregation of flowers, your survey-mark plain on the lintel stone. The blooms have not grown over it — around it, yes; over it, no. Counted, then. And noticed.", "next": ""},
			],
			"choices": [
				{"text": "Cut Kesh's survey-mark into the lintel stone, above the waterline — the shrine claimed, counted.",
					"req_flag": "sq_on_ch6_kesh_tally", "req_not_flag": "sq6_tally_shrine",
					"flags": {"sq6_tally_shrine": true}, "next": "sh_mark"},
			],
			"next": ""},
		"sh_mark": {"who": "Narrator", "text": "The chisel-work takes minutes, and the flowers watch — there is no other word for what a hundred blooms turning off their dawn-bearing to face your hands is doing. When you step back, the mark reads clean: the Choir's sunken stone, claimed by the green, counted by the camps, on the maps by nightfall. The collar will turn with the dawn tomorrow, and every dawn after. But now somebody is looking BACK, and the tally says so in stone.", "next": ""},
	}},

	# OVERRIDES ch6_zones.gd's ch6_shrine_pool — the three resonance
	# choices and their payoffs are verbatim; a tally-gated mark choice is
	# appended, and the faced-pool revisit continues to a short node that
	# keeps the mark reachable after the resonance choice is spent.
	"ch6_shrine_pool": {"start": "p1", "nodes": {
		"p1": {"who": "Narrator",
			"text": "The Cure Pool — the spring Kaethra drank from. Green water, utterly clear, and under it white roots in slow motion. The camp fenced it with bone stakes and warnings in three scripts, and the fence is leaning inward now, pulled gently, month by month. The water knows what you carry. It is already offering: the Ember's whisper gone QUIET, the debt lifted, the temptation cured. Growth without death. All it has ever asked is room.",
			"variants": [{"flag": "cure_pool_faced", "text": "The pool lies clear and patient behind its leaning fence. Between you and it, whatever passed is finished — though the water, you notice, has not stopped being certain you'll be back.", "next": "p_after"}],
			"choices": [
				{"text": "Kneel and speak your temptation ALOUD to the water — name the thing it's offering to cure, and keep it, owned, yours.",
					"resonance": 8.0, "flags": {"cure_pool_faced": true, "chose_owned_temptation": true}, "next": "p_own"},
				{"text": "Drink. One mouthful. Kaethra was reckless; you'll be careful. The difference feels enormous from this side of the fence.",
					"resonance": -10.0, "flags": {"cure_pool_faced": true, "chose_drank_cure": true}, "next": "p_drink"},
				{"text": "Drive the leaning fence-stakes back upright, and go. Some pools you fix the FENCE for, not the thirst.",
					"resonance": 3.0, "flags": {"cure_pool_faced": true}, "next": "p_fence"},
				{"text": "Cut Kesh's survey-mark into a fence-stake — the lean measured, the line held, the count kept.",
					"req_flag": "sq_on_ch6_kesh_tally", "req_not_flag": "sq6_tally_pool",
					"flags": {"sq6_tally_pool": true}, "next": "p_mark"},
			]},
		"p_own": {"who": "Narrator", "text": "You say it plainly — the exact thing the Ember wants of you, the thing you have carried since your shard woke. Spoken to open water, it sounds smaller. Ownable. The pool's stillness flickers, once: an offer has never been declined by NAMING before, and somewhere down among the white roots something files you under DIFFICULT. The Ember's whisper is still there as you walk away. But it's yours. That was always the only cure on the table.", "next": ""},
		"p_drink": {"who": "Narrator", "text": "One mouthful. Cold, sweet, and the whisper STOPS — for the first time since your shard woke, perfect silence where the temptation lived. You could weep. Halfway back to the trail you notice your cut knuckle from the fringe has healed without a scar. By nightfall, the scar you got at TEN is gone too. The Root never subtracts, bearer. It is very much hoping you won't do the arithmetic on what it's adding.", "next": ""},
		"p_fence": {"who": "Narrator", "text": "You reset the stakes one by one, driving them deep, angling them out. Honest work; the kind hands remember. The water watches with what you'd swear is amusement — fences have never once held it, and you both know it. But that was never what the fence was for. The fence is a SENTENCE, written in bone, that says: somebody decided no. It reads a little clearer now. Travelers will see it. That's the whole victory, and you'll take it.", "next": ""},
		"p_after": {"who": "Narrator",
			"text": "The stakes hold their slow inward lean. The water holds its offer. Neither is in any hurry — patience is the one currency the Deep has never once run short of.",
			"choices": [
				{"text": "Cut Kesh's survey-mark into a fence-stake — the lean measured, the line held, the count kept.",
					"req_flag": "sq_on_ch6_kesh_tally", "req_not_flag": "sq6_tally_pool",
					"flags": {"sq6_tally_pool": true}, "next": "p_mark"},
			],
			"next": ""},
		"p_mark": {"who": "Narrator", "text": "You choose the stake with the worst lean and cut the mark: the fence line as it stands TODAY, witnessed, counted. The water's stillness does not flicker this time — measurement, it has learned, is the thing humans do instead of deciding. Let it think so. Kaethra measured too, and her stakes are the only reason anyone knows how fast it moves. The tally goes on, and the tally is a fence of its own.", "next": ""},
	}},

	# OVERRIDES ch6_zones.gd's ch6_shrine_schism — the three answer
	# choices and their payoffs are verbatim; the bread delivery is an
	# appended, gated choice, and the answered-schism revisit continues
	# to a short node that keeps the delivery reachable.
	"ch6_shrine_schism": {"start": "s1", "nodes": {
		"s1": {"who": "Narrator",
			"text": "Two knots of Choir pilgrims, one shouting-match past mending, and between them a table with bread going stale — nobody will eat first. An old pilgrim grips a rot-blackened staff: \"Decay is the truth! This Blooming is the LIE that tests us!\" A younger one holds up a flowering reed: \"Or sixty years of funerals were the test, and THIS is the answer!\" They see you — shard-lit, blooded, fresh from the Deep itself — and both sides go quiet with the same terrible hope: an oracle has arrived. \"You've SEEN it,\" the young one breathes. \"Which is the land's truth, bearer? The rot or the bloom?\"",
			"variants": [{"flag": "schism_answered", "text": "The two camps share the gate again — not the table yet, but the gate. Your answer is still being turned over by both sides, which may be the most any answer ever achieves in a schism.", "next": "s_after"}],
			"choices": [
				{"text": "\"Neither. Rot and bloom are both just APPETITES wearing the land. The truth is whoever keeps feeding the other pilgrims — pass the bread.\"",
					"resonance": 6.0, "faction": {"choir": 2}, "flags": {"schism_answered": true, "chose_schism_bread": true}, "next": "s_bread"},
				{"text": "\"The rot. I've seen the bloom up close — it's the same hunger with better manners. Your old creed holds.\"",
					"resonance": 0.0, "faction": {"choir": 4}, "flags": {"schism_answered": true}, "next": "s_rot"},
				{"text": "Say nothing. Take the stale bread from between them, break it, eat, and walk on — let them argue about THAT for a decade.",
					"resonance": -2.0, "flags": {"schism_answered": true}, "next": "s_eat"},
				{"text": "Set the gate camp's loaf on the table between them — fresh this morning, from the flock that stayed.",
					"req_flag": "sq6_bread_taken", "req_not_flag": "sq6_bread_left",
					"resonance": 2.0, "flags": {"sq6_bread_left": true},
					"lose_item": "ch6_gate_loaf", "next": "s_loaf"},
			]},
		"s_bread": {"who": "Narrator", "text": "Both camps stare — at you, at the bread, at each other. The old pilgrim laughs first: one harsh bark, sixty years of doctrine cracking to let it out. \"...Appetites wearing the land,\" he repeats. \"Flame help me, that's better theology than I've managed since the Vale.\" The bread moves. Somebody fetches the good knife. The schism isn't healed — schisms don't heal — but tonight it is FED, and fed arguments stay arguments instead of becoming wars.", "next": ""},
		"s_rot": {"who": "Narrator", "text": "The old guard erupts in grim vindication; the young reed-bearer looks at her flower like it lied to her, and lets it fall. You've handed one side victory and it fits them like a warm coat — and as they crowd around you for details, you catch the young one at the edge of the lamplight, slipping away toward the Deep. Toward the bloom. People don't stop believing when you rule against them, bearer. They just stop believing NEAR you.", "next": ""},
		"s_eat": {"who": "Narrator", "text": "You eat their argument. The silence is total and profoundly theological. As you walk on, the debate reignites behind you at double volume — WHAT DID IT MEAN — and you find you're smiling. The shard is smiling too, which sours it a little. It likes oracles. It especially likes oracles who answer in riddles and keep walking; that's how ITS old bearers ended up with kingdoms.", "next": ""},
		"s_after": {"who": "Narrator",
			"text": "The stale loaf is gone from the table — eaten, buried, or argued into crumbs; nobody will say. The table itself keeps its surveyed midpoint, and both camps keep their sides of it.",
			"choices": [
				{"text": "Set the gate camp's loaf on the table between them — fresh this morning, from the flock that stayed.",
					"req_flag": "sq6_bread_taken", "req_not_flag": "sq6_bread_left",
					"resonance": 2.0, "flags": {"sq6_bread_left": true},
					"lose_item": "ch6_gate_loaf", "next": "s_loaf"},
			],
			"next": ""},
		"s_loaf": {"who": "Narrator", "text": "You set it down at the table's exact midpoint — still warm, wrapped in gate-linen, smelling of a morning nobody here has had in weeks. Silence. Then the old pilgrim reaches out and turns it once, checking the bake the way deacons and millers do, and finds no fault to hide behind. \"The gate flock sent it,\" you say, and Vela's name does what no argument could: both camps eat, because refusing HER bread is a heresy neither side has the doctrine for. It isn't peace. It's supper. In a schism, supper is the load-bearing miracle.", "next": ""},
	}},
}
