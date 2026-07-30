# Chapter Openers — class-refracted entry cutscenes + choice map, ch2–ch14 (2026-07-29, v2)

Proposal: every chapter entry opens the way the game itself opens — a short
illustrated storybook beat (the `Cutscene` layer from the class openers) that
ends on one three-way choice, whose flag an NPC reads back to you minutes
later. Chapter 1 already has this (the six `open_<class>` convos); this maps
the same grammar onto ch2–ch7 (Act 1, buildable now) and ch8–ch14 (Act 2,
lands with each chapter build). **Nothing here is installed — this is a
decision document.**

**⚠ Plate descriptions revised 2026-07-29 (two owner review passes) — if
you generated assets from an earlier read of this doc, see
`CHAPTER_OPENERS_PLATE_CHANGELOG.md` for the exact 32-plate regenerate
list (ch2 and ch14 are fully safe; ch8 is a full redo except its warlock
plate).**

**v2 (owner call):** v1's class-agnostic openers rejected. Every chapter
opener is now CLASS-REFRACTED like ch1: a shared world spine (two plates,
two narration beats — the chapter is the same chapter for everyone), then a
per-class turn (one plate, one beat: the chapter seen through THAT class's
wound) and a fully class-voiced three-way choice. Same chapter, six
different temptations. The plot never branches; the person does.

---

## 1. The grammar (distilled from the ch1 class openers)

The class openers (`story.gd:48-236` + `cutscene.gd`) all follow one shape:

1. **Establish → Incident → Consequence.** A shared world plate ("crown"),
   then plates where the power acts *through* you, then a plate where
   someone looks at you differently.
2. **The choice is never "what happens" — it is "who you are about it".**
   All three branches lead to the same map, the same quest, the same plot.
   What branches is the stance, the resonance, and the flag.
3. **Three-way stance:** virtue (+res), temptation (−res), deflection (0).
   Sets persistent flags.
4. **The echo.** An NPC reads the flag back in their next greeting (Maren's
   `variants` block). The choice is *felt* within minutes.
5. **End on `fade` + a travel hook** naming where you're going next.

### The refraction table (the doc's engine)

Each class's ch1 opener established a wound and a standing temptation.
Every chapter below is refracted through these six lenses — the shared
spine says what the chapter IS; the class turn says what it means TO YOU:

| Class | The wound (from ch1) | The standing temptation |
|---|---|---|
| Warrior | violence exceeding intent — the blackout; "you kept swinging" | let it off the leash |
| Assassin | the Ember TAKES to keep you alive — the flask, the grey lips | taking that feels earned |
| Mage | help that harms — the green light, the grey mark, the promise to undo | perfect work, whatever it costs (Mórwyn's road) |
| Archer | the severed thread — ties made visible, then cut; the unlatched gate | lightness; cut more |
| Paladin | the chain that argues verdicts — "HE IS YOURS. SHIELD HIM." | let it judge for you |
| Warlock | the debt you don't remember signing — the tome, the interest | one more borrow; it's only sensible |

### Structure per chapter

- **Shared spine:** plates `opening_chN_0` and `opening_chN_1` (one cue),
  narration beats n1–n2. Identical across classes (the ch1 openers
  duplicate the `crown` node verbatim per class — same precedent).
- **Class turn:** plate `opening_chN_<class>` (per-class cue), beat n3 —
  the chapter through the wound.
- **Choice:** n4, three options fully class-voiced, all mapping to the SAME
  three chapter stance flags (+6 / −6 / 0; ch14 ±8). Flags stay
  chapter-level so briefing echoes and long-fuse callbacks stay sane.
- **Convergence is by design; repetition is a defect.** Within a chapter
  the six voicings land on the same three flags — six REASONS, one
  stance; no two classes may share a rationale or a tagline. Across
  chapters the discipline is the reverse: a returning domain (ch8
  revisits ch4's foundries, ch10 revisits ch5's ice, ch12 revisits ch6,
  ch13 revisits ch7) must key its spine and class turns to what CHANGED —
  never re-render the domain's imagery or re-run a class's old angle at
  larger scale.
- **Plates are scenes, not emblems.** The class plate stages the HERO in
  the chapter's world in a chapter-specific composition — the wound lives
  in the narration, so the picture never re-performs it. Each class's
  icon-closeup (the tome page, the bare chain, thread-vision, the
  laying-on of hands, the stared-at hands) is budgeted: at most twice per
  campaign, where it lands hardest — and a ch1 signature pose is never
  restaged unless flagged as a deliberate rhyme (ch14's crown plate is
  the model). Vary camera and scale per class across chapters — closeup,
  wide, over-shoulder, reflection — or thirteen openers become one
  painting with palette swaps.
- **The question comes from the WORLD, never from the power.** In every
  ch1 opener a person in the scene asks (Bren, the Carter, the Mother,
  Ren, Osric, the Tome-as-presence) and the options are REPLIES. Chapter
  openers do the same: each chapter names an ASKER — a figure standing in
  the spine's scene, never the chapter's briefing NPC — whose n4 prompt
  the class-voiced options answer. The Ember/chain/tome may lean in n3;
  it never polls you. (v2 defect, owner-caught: thirteen chapters of the
  narrator asking "what do you think" is one scene with palette swaps.)
- **Two prompt modes (owner call, 2026-07-29).** PUBLIC chapters — ch3,
  ch4, ch6, ch7, ch8, ch11, ch12, ch14 — keep the external asker: the
  options are spoken replies. PRIVATE chapters — ch2, ch5, ch9, ch10,
  ch13 — go INTERNAL: the world still supplies a concrete trigger (the
  offered pen, the barred shaft), but the deliberation is the
  character's own, and the TEMPTATION option is written in the vice's
  own voice — the shard/chain/tome speaking in CAPS (the ch1 paladin's
  "HE IS YOURS" convention). Choosing it means agreeing with its
  account. Where the vice is the character's own wish rather than the
  power's (ch5's warrior), it stays quiet lowercase — hidden FROM the
  shard. Budget: the power speaks inside temptation options ONLY in
  these five chapters — five times a campaign, class-voiced, rare enough
  to chill.
- **No false promises.** Every option either resolves inside the cutscene
  (ch1's kneel, ch1's walk) or is a stance on HOW the chapter's mandatory
  events get done — never on WHETHER. A deflection that vows to leave the
  saint alone is a lie the boss wall exposes an hour later (v2 defect,
  owner-caught: ch3's assassin, all six ch12 deflections).
- **Replies + fade:** each option gets a short reply node (drafted at
  build, ch1-style) and the shared `fade` travel hook.
- **The echo:** the chapter's existing briefing NPC gains one read-back
  tier above their current variants (opener flag first, falling through to
  what's there today). Existing briefings are otherwise untouched — opener
  = narrator + picture; briefing = a person + a quest. Two beats, two jobs.

---

## 2. Act 1 — chapters 2–7 (buildable now)

---

### ch2 — The Waking (hub: Maren's Camp)

**Logline:** the crown broke; the years passed; the shards started choosing.

**Shared spine** *(cue `shatter`)*
- `opening_ch2_0` — the Ember Crown mid-shatter, fragments streaking out
  over a darkened map of Vaelscar. Deliberate rhyme with the `crown` plate:
  same composition, breaking. (A FLASHBACK plate — the first fall, thirty
  years past; visual unchanged.)
- `opening_ch2_1` — the quiet years: a road, refugee wagons, blight-green
  creeping along a fence line no one repaints.
- n1 — "Thirty years ago, Ser Aldric's blade found the Hollow King, and
  the Ember Crown shattered — not into metal, but into PEOPLE. You know
  this the way you know your own scar: one of those pieces has been in
  your chest since before you had a name for it. Vargoth told you so
  himself, at the end."
- n2 — "Then came the second fall — yours. The years since have not
  healed the kingdom; they have WOKEN it. All across Vaelscar the old
  scatter is stirring: shards that slept thirty years in farmhands and
  deserters are opening their eyes, the factions count the newly-woken
  like a harvest, and an old woman keeps a fire at the crossroads to
  reach them first."
- *(Canon: `story.gd:1272-1341` — the Crown shattered at the FIRST fall,
  thirty years back; the player's shard predates ch1, and Vargoth names
  it: "A piece of me, walking about in someone else's chest." The v2
  draft wrongly put the scatter at the second fall — owner caught it.)*

**The trigger + n4 (INTERNAL)** — the stranger across Maren's fire, a
fellow newly-woken with the shard-glow still fresh under their wrist:
"I got mine in the spring. You've had yours a while, haven't you. …How
did you carry it?" You look into the fire instead of answering. The
shard was there for all of it — and it offers its account FIRST. Each
class's temptation below is the shard's version of the years, in its own
voice; choosing it means agreeing with its memory.

**Class turns** — each class answers from inside its ch1 ending.

**Warrior — the counted gaps.** Plate: a woodpile split far past need, axe
still in hand, dawn light.
- n3: "Years of careful. You took work that tired the body honest —
  fences, wells, timber — and never once finished a job with the same
  memory you started it. The neighbors called you tireless. You kept count
  of the gaps."
- "Point it at work. Every gap ended with something BUILT — you made the
  blackout a carpenter." → **+6** `ch2_kept_faith`
- "YOU PICKED THE NIGHTS. YOU WALKED PAST THE TREE LINE AND LET ME SWING
  UNTIL I WAS TIRED — AND YOU SLEPT SOUND, AFTER. SAY IT WAS US." →
  **−6** `ch2_fed_ember`
- "Chain it. No sword in the house, sleep tied to the bedpost, and never
  once ask it what it wanted." → **0** `ch2_buried_it`

**Assassin — the leaning warmth.** Plate: a market crowd parting around a
hooded figure; every stall-candle leaning toward them.
- n3: "Years of arithmetic. The Ember takes to keep you alive — so the
  years were a ledger question: what it took, from whom, and what you did
  about the bill. In every market you crossed, the candle-flames leaned
  at you like debt collectors who already knew the address."
- "Pay forward. Every winter you found the freezing and sat with them —
  let it take from YOU for a change." → **+6** `ch2_kept_faith`
- "A LITTLE FROM MANY, NONE THE WISER, BOTH OF US FED. WE MADE THE THEFT
  A TAX — AND THE TAX WAS FAIR." → **−6** `ch2_fed_ember`
- "Starve it. Sleep cold, eat thin, touch no one. It waited. It is very
  good at waiting." → **0** `ch2_buried_it`

**Mage — the aging promise.** Plate: a workbench of failed unguents; the
boy's grey mark sketched a hundred times over pinned pages.
- n3: "Years of the promise. The ferrier's boy grew up; the mark grew with
  him, slow as a shadow at noon. You filled three journals learning what
  your green light was NOT."
- "Keep it burning. Every remedy, every archive, every road that rumored a
  cure — the promise aged better than you did." → **+6** `ch2_kept_faith`
- "WE CAST IT AGAIN. SMALLER. CONTROLLED. ON THINGS THAT COULD NOT SAY
  NO — HOW ELSE DOES ANYONE LEARN?" → **−6** `ch2_fed_ember`
- "File it away. The boy stopped writing back; the journals went in a
  chest. Some spells you outlive." → **0** `ch2_buried_it`
- *(Continuity: the "promise" is her PRIVATE vow on every ch1 branch —
  only `told_truth` spoke it aloud; every later promise-reference must
  read either way.)*

**Archer — the ridge road.** Plate: a fence line seen from a distant
ridge; one gate open; a small light in the farmhouse.
- n3 *(base, for `said_farewell`)*: "Years in sight of the fence. You
  never crossed it — but twice a year you took the ridge road, counted
  the chimney smoke, and left before the dogs knew you. The gate stayed
  unlatched. You checked."
- n3 variants *(the ch1 branches remember differently)*: `cut_clean` —
  "You stopped taking the ridge road the day you cut it. You still know,
  to the week, how many springs it has been."; `walked_silent` — "Twice a
  year, the ridge, the smoke-count — and every visit ends on the same
  small remembered sound. The latch."
- "Answer it. Walk down, sit at Ren's table, and let the stranger-distance
  be a thing you both work at." → **+6** `ch2_kept_faith`
- "THE RIDGE ROAD WAS A THREAD AND WE CUT IT. YOU FELT THE LIGHTNESS.
  YOU LIKED IT. SAY YOU LIKED IT." → **−6** `ch2_fed_ember`
- "Keep the ritual. The ridge, the smoke-count. Near enough to know; far
  enough to owe nothing." → **0** `ch2_buried_it`
- *(Build note: gate option wording with `req_flag` where a ch1 branch
  contradicts it — a `cut_clean` archer has no ritual to keep; her
  deflection reads "Leave it cut. It has stayed cut this long.")*

**Paladin — verdicts without a bench.** Plate: two farmers and a broken
cart before a seated figure; the hammer leaned deliberately AGAINST the
wall, out of reach.
- n3: "Years without a bench. Villages learn what you were; they bring you
  their disputes anyway. And every time you open your mouth to rule, the
  chain clears its throat FIRST."
- "Rule anyway — slowly. You heard every case twice: once as yourself,
  once listening for which verdict the chain leaned on. You ruled against
  the lean." → **+6** `ch2_kept_faith`
- "MY VERDICTS WERE FAST, CLEAN, AND LOVED. YOU READ THEM ALOUD
  UNEDITED — AND NOT ONE VILLAGE APPEALED." → **−6** `ch2_fed_ember`
- "Decline the bench. 'Find a magistrate.' Let the chain argue with an
  empty room." → **0** `ch2_buried_it`

**Warlock — the silent interest.** Plate: the tome on a rented table; a
candle burned to its ring — and a second ring, older, beside it.
- n3: "Years of the ledger. Whatever you did about the debt — the tome
  kept perfect books on it, in a hand that got a little more like yours
  each year. And in all that time it never once mentioned the interest.
  That is what frightened you."
- "Audit it. You learned its grammar, listed every asset 'what you traded'
  could mean, and crossed off what you could prove still yours." → **+6**
  `ch2_kept_faith`
- "A CANDLE HERE, A CANDLE THERE — FOR GOOD CAUSES, MOSTLY. THE DEBT IS
  DEEPER AND YOUR REASONS WERE EXCELLENT. *(The tome's account. In your
  handwriting.)*" → **−6** `ch2_fed_ember`
- "Freeze the account. The tome stayed wrapped in the pack's bottom.
  Unopened. Warm." → **0** `ch2_buried_it`

**Echo:** `ch2_maren_hub` `m1` gains three variants above the existing
`chose_virtue/temptation/away` tier — e.g. `ch2_fed_ember`: "Sit. …So the
quiet years weren't quiet. The woken who spent them leaning INTO the
thing carry the lean ever after — I could see yours from across the
fire. We'll work on it, or it will work on you." *(Echo lines live in the
SHARED briefing convo, so they must read true for all six classes'
versions of the deed — write to the stance, never the specifics.)*

---

### ch3 — The Unburied Vale (hub: The Vigil Gate)

**Logline:** the funeral that never ends, and the saint who cannot.

**Shared spine** *(cue `vale`)*
- `opening_ch3_0` — the Vale from the gate: one continuous open grave
  winding to a cathedral hill, procession lanterns strung along it like a
  rosary.
- `opening_ch3_1` — the dead walking their own funeral: grey figures in
  grave-clothes shuffling in file, Choir cantors alongside keeping count
  in ledgers.
- n1 — "East of the camps lies the Choir's heartland, and the Choir does
  not bury its dead. Rot is the land's honest truth, they teach — so the
  dead walk their own funerals. They have been walking for sixty years."
- n2 — "The procession never arrives. That is the point. And at the top
  of it all kneels Saint Varo — the one man the rot refuses, worshipped
  for the refusing, asking the one mercy the Vale no longer stocks."

**The asker (n4)** — the gate's counting-cantor, looking up from her
ledger as the procession shuffles past: "State your business with the
unburied, pilgrim."

**Warrior — harm that stays standing.** Plate: the warrior stilled
mid-stride as the procession parts around him, sword-hand hanging open.
- n3: "Every dead thing here is an aftermath still on its feet. You know
  aftermaths — you wake up in them. The Vale is a blackout that never
  ends, walking in grave-clothes, and nobody here will even flinch if you
  swing."
- "Endings are owed. You finish what you start — time somebody finished
  THESE." → **+6** `ch3_vowed_rest`
- "Swing free. Nothing here stays down and nothing here counts — the one
  place your gaps can feast without a bill." → **−6** `ch3_covets_rot`
- "Eyes forward. You didn't break these; you don't owe these. Save the arm
  for the saint's hill." → **0** `ch3_eyes_forward`

**Assassin — the refused man.** Plate: Varo kneeling on the hill, and the
assassin's shadow stretched toward him up the grave-rows, leaning.
- n3: "Sixty years and the rot has not taken ONE thing from Varo. You, who
  cannot keep a fire lit near a stranger, are walking toward the single
  most refused man alive. The Ember is curious. You can feel it leaning."
- "Give him rest. The one gift nobody here has offered the man everything
  else refuses." → **+6** `ch3_vowed_rest`
- "Learn the refusal. Whatever keeps the rot's hands off him could keep
  YOUR Ember's hands off everyone else — take the technique." → **−6**
  `ch3_covets_rot`
- "No gifts, no studies. If the saint must fall, let it be clean
  stranger's work — in, through, gone." → **0** `ch3_eyes_forward`

**Mage — the mark writ large.** Plate: a walking corpse passing the mage
close on the grave-road — on its jaw, a bloom of grey; the mage arrested
mid-stride, recognizing it.
- n3: "The grey on the ferrier's boy — cold, spreading, unwashable. You
  have carried its likeness for years. The Vale is ACRES of it. Somewhere
  between the gate and the saint, this place knows what your green light
  did."
- "The promise walks in with you. If the Vale can teach you what the mark
  IS, the boy finally gets his answer." → **+6** `ch3_vowed_rest`
- "Varo first. The rot refuses him — refusal is a mechanism, and
  mechanisms can be extracted. The boy would understand the methods." →
  **−6** `ch3_covets_rot`
- "Research later. Chart it, sample nothing, promise nothing new. You have
  enough unkept already." → **0** `ch3_eyes_forward`

**Archer — ties refusing release.** Plate: an old mourner's fists
knotted in a walking corpse's grave-shroud, holding it back from the
road; the archer stopped on the path beside them, bow lowered.
- n3: "You can see the threads here. That is the horror of it — every
  walking corpse trails a hundred, held from the OTHER end. The Vale is
  not full of dead who won't leave. It is full of mourners who won't let
  go."
- "Release is a mercy you know the price of. Untie them — gently, one
  funeral at a time, all the way up the hill." → **+6** `ch3_vowed_rest`
- "Cut the lot. One arrow through a held thread hurts less than sixty
  years of holding — and you'd barely feel it anymore." → **−6**
  `ch3_covets_rot`
- "Touch no threads. You cut one once and it echoes yet. Walk the spine,
  mind the bow." → **0** `ch3_eyes_forward`

**Paladin — the unserved sentence.** Plate: the paladin halfway up the
cathedral hill, stopped, helm under his arm, looking up at the kneeling
saint — the first bench he has ever approached uphill.
- n3: "Sixty years, one petitioner, no verdict. Varo begs for death and
  the Choir calls the begging liturgy. The chain has read the case
  already and — for the first time since the granary — it is NOT SURE. You
  felt it hesitate. That frightened you more than its certainty ever has."
- "Hear the case. Climb, listen to the man himself, and deliver the
  verdict sixty years of clergy refused to." → **+6** `ch3_vowed_rest`
- "Preserve the miracle. The chain steadies: a man the rot refuses is
  EVIDENCE, and evidence is not released — it is kept." → **−6**
  `ch3_covets_rot`
- "Not your court. The Choir made this docket; let the Choir choke on
  it." → **0** `ch3_eyes_forward`

**Warlock — interest without end.** Plate: the gate's counting-table —
sixty years of grave-ledgers stacked into six pillars, one per decade,
the newest pillar tallest; the warlock beside them, measuring himself
against it.
- n3: "You know these books. Death deferred, grief compounding, the
  principal never touched — the Vale is a loan sixty years past due and
  still accruing. The tome, in your pack, is purring. It thinks it is
  HOME."
- "Close the accounts. Every walker is a debt someone refuses to settle —
  settle them, paid in full, starting at the gate." → **+6** `ch3_vowed_rest`
- "Study the instrument. Whatever contract keeps the Vale's books open has
  terms the tome has never dared offer YOU. Read it." → **−6**
  `ch3_covets_rot`
- "Sign nothing. Speak to no cantor, bless no ledger, and keep the tome
  wrapped until the sky changes." → **0** `ch3_eyes_forward`

**Echo:** `ch3_briefing` `b1` — e.g. `ch3_covets_rot`: "I left the Choir
because they looked at a dying man and saw furniture. You're looking at
him and seeing a RECIPE. Watch that, bearer — that's how cantors start."

---

### ch4 — The Slagfields (hub: The Cinder Gate)

**Logline:** the foundries reopened, and something under them started
signing the work.

**Shared spine** *(cue `foundry`)*
- `opening_ch4_0` — the foundry skyline at night: chimney rows like organ
  pipes, ash falling as slow grey snow over freight lines.
- `opening_ch4_1` — a furnace door open like a doorway; a work crew
  walking IN, unhurried; the one walking OUT stands straighter than any of
  them.
- n1 — "South, the Compact reopened the old foundries. Best ore vein in
  Vaelscar, and heats the coal cannot explain. The blades stopped breaking
  two years ago. Nobody asked why loudly enough."
- n2 — "Workers walk into the furnaces now. Most come out — straighter,
  longer-working, unblinking at the fire. Improved, the overseers say.
  And in the sermon-hall, the smiths have begun to notice that when the
  chaplain says GUILTY, the fire leans in."

**The asker (n4)** — the crew-boss at the furnace corridor's mouth, her
roped crew filing past behind her: "You're not signed. So what's a
foundry to you, stranger?"

**Paladin — the chain meets the Judge.** Plate: Ordo mid-verdict, arm
extended, the forge-fire behind him leaning the same direction as his
arm — and the paladin in the aisle, walking OUT against a current of
late arrivals.
- n3: "Three rooms past the gate and the chain went QUIET — the quiet of a
  junior arbiter when the high judge enters. Something under this rock
  hands down verdicts, and the thing around your heart wants to clerk for
  it."
- "People first, then the bench. Get the crews out; a court that burns its
  witnesses is no court." → **+6** `ch4_people_first`
- "Sit in. Hear how a fire argues, learn what your chain's superior sounds
  like — then rule on it." → **−6** `ch4_heard_verdict`
- "Recuse. Two verdicts in one chest is one too many; kill what's on the
  docket and go." → **0** `ch4_not_my_court`

**Warrior — the certain hands.** Plate: an improved smith working a
two-man hammer alone, strikes landing in perfect rhythm; the warrior in
the doorway, unnoticed, half-lit by the pour.
- n3: "The improved stand straighter, hit harder, and stop blinking at the
  fire. Nobody says what got smelted out. You have wondered your whole
  life what you'd give to be certain of your own hands. The furnace is
  CERTAIN."
- "Hands like yours don't go in fires. Get the crews out before the
  certainty spreads." → **+6** `ch4_people_first`
- "Ask the fire. One door, one walk-through — maybe the gaps come out
  annealed shut." → **−6** `ch4_heard_verdict`
- "Steel, not souls. Break the machines, spare the philosophy." → **0**
  `ch4_not_my_court`

**Mage — perfect work, poured daily.** Plate: a cooling blade held to the
light, flawless; reflected in it, a small green flame that isn't in the
room.
- n3: "The blades stopped breaking. Say it plainly: somewhere below, a
  technique exists that does not FAIL. You cast one heal, once, and it is
  still failing years later. Mórwyn would have loved this place. That
  sentence should be the whole warning."
- "Perfect isn't the promise — UNDONE is. Take nothing from this place the
  boy wouldn't thank you for." → **+6** `ch4_people_first`
- "Watch one pour. Just to see what unfailing looks like from the gallery.
  Everyone in this story said 'just once'." → **−6** `ch4_heard_verdict`
- "Melt it all down. A technique needs practitioners; leave neither." →
  **0** `ch4_not_my_court`

**Archer — threads downhill.** Plate: a roped work-crew filing into a
furnace corridor; the archer on a gantry above, arrow nocked but not
drawn, choosing a rope.
- n3: "You see the freight lines the way you see threads — and every
  thread in this city runs DOWNHILL. Crews roped together walking in; ore,
  verdicts, prayers, all one direction. Nothing in the Slagfields leads
  out."
- "Cut them loose. Every rope walking furnace-ward gets an arrow before
  the door does." → **+6** `ch4_people_first`
- "Follow the pull. Threads that strong lead to whatever's holding them —
  and you'd like to see the hand." → **−6** `ch4_heard_verdict`
- "Sever the freight, not the faithful. Kill the machine's supply and let
  the people keep their choices." → **0** `ch4_not_my_court`

**Assassin — taking with a receipt.** Plate: an improved worker showing
his new steadiness to his family — itemized, smiling; behind him the
furnace door still open.
- n3: "Your Ember takes and leaves nothing but grey lips. The furnace
  takes and hands back improvements, itemized. It is the same theft with
  better paperwork — and half this city is GRATEFUL. That is the part that
  itches."
- "Gratitude isn't consent. Get them out before the bill comes due — you
  know how these ledgers end." → **+6** `ch4_people_first`
- "Compare terms. If a fire can take cleanly and pay back, yours can learn
  the trick — negotiate." → **−6** `ch4_heard_verdict`
- "Rob the robber. Whatever the Judge hoards under the rock, relieve it of
  the inventory and go." → **0** `ch4_not_my_court`

**Warlock — professional courtesy.** Plate: the tome in the warlock's
hands, clamped SHUT, its strap-buckles drawn like a held breath; forge
light all around.
- n3: "The tome has not said one word since you crossed the Cinder Gate.
  You know that silence — a small creditor in a large bank's lobby. The
  thing beneath the foundries writes contracts in fire and signs them with
  verdicts, and your book is AFRAID of it."
- "A creditor that scares yours has clients that need out. Void what
  contracts you can, crews first." → **+6** `ch4_people_first`
- "Read the fine print. A bigger lender means better terms — or a way to
  refinance what you owe the tome." → **−6** `ch4_heard_verdict`
- "No new paper. In and out, vessel dead, signature withheld." → **0**
  `ch4_not_my_court`

**Echo:** `ch4_briefing` `b1` — e.g. `ch4_people_first`: "First thing you
say is about my crews and not my ore? Then we'll get along. Most of what
comes through that gate has it the other way round."

---

### ch5 — The Long Sleep (hub: The Last Fire)

**Logline:** freely-given sleepers, famine grain, and nobody out there is
evil.

**Shared spine** *(cue `sledge`)*
- `opening_ch5_0` — a sledge caravan on sea-ice at dusk: bundled sleepers
  lashed in rows, lanterns swinging, cultists walking alongside
  bare-headed.
- `opening_ch5_1` — the toll: grain sacks passing from cult hands to clan
  hands; behind the clan line, children too thin for their coats, watching
  the sacks and not the sleepers.
- n1 — "North, the Long Sleep hauls its faithful onto the ice. Freely
  given, every one — they sign their names, lie down smiling, and wait for
  the Queen's morning. The cult keeps the ledgers beautifully."
- n2 — "The winter clans let the sledges pass because the cult pays in
  grain, and this is a famine winter. That grain is marrow in children's
  bones. Every bundle on those sledges is somebody's supper. Under the
  shelf, the vault grows a row at a time — and there is always an empty
  bed."

**The trigger + n4 (INTERNAL)** — a Long Sleep sister at the sledge line
offers the open ledger and the pen, and says nothing at all. The pen
hangs there. The deliberation is yours — and the shard gets a word in.

**Assassin — the hush with no bill.** Plate: the vault in blue light, rows
of the kept; one turned-down empty bed, and the assassin's lantern the
only warm color in frame.
- n3: "The vault under the ice is the one room in the world where your
  Ember has nothing to take. Nobody warm, nobody spending, everyone
  perfectly KEPT. Three days poisoned on a winter road, you'd have crawled
  to a bed like that. There is an empty one."
- "Wake them. You know what 'kept' costs from the taking side — nobody
  down there agreed to the real price." → **+6** `ch5_vowed_morning`
- "LIE DOWN. ONE TENCOUNT IN THE EMPTY BED. WHAT THE ICE HOLDS STILL I
  CANNOT SPEND — AND YOU ARE SO TIRED OF MY SPENDING." → **−6**
  `ch5_felt_pull`
- "Their beds, their business. Clear the road, tithe the cult nothing,
  touch no ledgers." → **0** `ch5_kept_ledger`

**Archer — final lightness.** Plate: a family watching the sledge line
leave — one child running three steps after it and stopping; the archer
at the roadside, exactly between the child and the ice.
- n3: "Every sleeper cut all their threads at once and called it peace.
  You did it one thread at a time and called it the road. The difference
  is smaller than you'd like, and the ice knows it — the vault glows like
  a farmhouse window from the ridge."
- "Threads are for holding. Wake them into their own winters and stand
  there while they re-tie." → **+6** `ch5_vowed_morning`
- "ALL THE LIGHTNESS, NONE OF THE WALKING. EVERY THREAD AT ONCE, AND NO
  ROAD AFTER. ASK WHAT THE LEDGER REQUIRES." → **−6** `ch5_felt_pull`
- "Neither wake nor join. Count the beds like chimney smoke — near enough
  to know — and move on." → **0** `ch5_kept_ledger`

**Warrior — the certain leash.** Plate: the warrior's silhouette on the
shelf above the vault; below, hundreds of hands folded and still, forever.
- n3: "You have tied yourself to bedposts, walked off swords, chained the
  thing nightly for years — and every leash held until it didn't. The ice
  does not slip. Under the shelf, nobody's hands do anything at ALL,
  forever. It is the only guarantee you have ever been offered."
- "Mornings over guarantees. Wake them, and keep waking — a held sword
  beats a buried one." → **+6** `ch5_vowed_morning`
- "Price the bed — not for the peace, for the containment. Think it
  quietly, so the shard doesn't hear: one sleeper down there never hurts
  a miller again." → **−6** `ch5_felt_pull`
- "Fight what's awake. The Queen's problem is the Queen; leave the
  sleeping to their bargain." → **0** `ch5_kept_ledger`

**Mage — kept is not cured.** Plate: a sleeper held mid-fever in the ice,
the sick-flush frozen on their face like paint that will never dry.
- n3: "The ice keeps perfectly and heals NOTHING. Fevers paused mid-burn,
  wounds held mid-bleed — a hospital of unfinished sentences. You have a
  mark that spreads a shadow's width a year. Cold enough, still enough…
  it would stop. Stopping is not undoing. You know that. You KNOW that."
- "The promise says undone, not paused. Wake them into cures, however long
  cures take." → **+6** `ch5_vowed_morning`
- "ONE BLOOM OF GREY UNDER HER COLD. IF THE MARK HALTS, THE BOY SLEEPS A
  WINTER AND WAKES CLEAN. YOU HAVE CAST ON WORSE ODDS — WE BOTH
  REMEMBER." → **−6** `ch5_felt_pull`
- "Study nothing here. Preservation is her domain and her invoice; you
  have one open account already." → **0** `ch5_kept_ledger`

**Paladin — consent under famine.** Plate: the cult's intake table — a
signature being written by a hand thin as the pen; grain sacks stacked
where the witness should stand.
- n3: "Signed ledgers, freely given — the cult's paperwork is immaculate
  and the chain finds NO fault in it. Grain for passage, sleep for grief:
  contracts all round. But you have judged mills in famine years. You know
  what a signature is worth when the alternative is watching your children
  thin."
- "Coercion doesn't need a knife. Void the winter's terms: grain stays,
  sleepers wake, and the cult renegotiates with ME." → **+6**
  `ch5_vowed_morning`
- "CONSENT GIVEN IS CONSENT KEPT. THE LEDGERS ARE LAWFUL. ENFORCE THEM
  AS WRITTEN — OR ADMIT YOUR MERCY OUTRANKS THE LAW." → **−6**
  `ch5_felt_pull`
- "Rule narrow. The road must open; everything else is out of
  jurisdiction." → **0** `ch5_kept_ledger`

**Warlock — the balloon payment.** Plate: the intake tent at night — the
cult's beautiful ledger open under a lamp, a queue of the grieving
waiting to sign; the warlock in the queue's shadow, reading the column
headings from three places back.
- n3: "Sleep now, morning later — the Queen's whole faith is a deferral
  scheme, and the tome respects the CRAFT of it. No interest visible,
  principal frozen, payout scheduled for a date the lender controls. You
  have read this instrument before. You are STANDING in one."
- "Call the loan early. Wake them before the Queen's 'morning' names its
  real price." → **+6** `ch5_vowed_morning`
- "A CREDITOR PATIENT ENOUGH TO FREEZE CENTURIES. TERMS WORTH HEARING,
  PROFESSIONAL TO PROFESSIONAL. INTRODUCE US." → **−6** `ch5_felt_pull`
- "Neither borrow nor foreclose. Clear the ridge and leave the ice its
  portfolio." → **0** `ch5_kept_ledger`

**Echo:** `ch5_briefing` `b1` — e.g. `ch5_felt_pull`: "You've heard it
already, then. The hush. Suli calls it the Queen's mercy; I call it bait
that doesn't need a hook. Either way, bearer — walk next to me, not
ahead."

---

### ch6 — The Blooming Deep (hub: The Pilgrim Gate)

**Logline:** the Choir found the opposite of everything it believes, and
half the flock knelt on sight.

**Shared spine** *(cue `bloom`)*
- `opening_ch6_0` — the bog gate: a pilgrim column on a plank road, green
  light standing on the waterline like dawn from below.
- `opening_ch6_1` — the Deep itself: growth without death — flowers the
  size of doors, fruit nothing ever bit, no carrion, no rot, not one dead
  thing in frame.
- n1 — "The Choir walked east preaching what it has always preached:
  everything dies, and the dying is honest. Then the bog opened, and the
  Deep showed them something that has never died once."
- n2 — "Growth without death. Bloom without wilt. A garden that only ADDS —
  the most beautiful thing in Vaelscar, and wrong the way a sentence with
  no ending is wrong. The column that found it walked in preaching and
  came out half its size — the rest stayed, knee-down in the moss.
  Somewhere at the heart of the green, a shaman went looking for a cure
  and found a congregation."

**The asker (n4)** — a glad-eyed kneeler, catching your sleeve at the
gate: "It gives, stranger. It only ever gives. Will you not take?"

**Mage — THE green.** Plate: the green light rising off the waterline in
the exact SHAPE of her old healing light — and the mage a step back from
the plank road's edge, recoiling from her own spell.
- n3: "The light standing on the waterline is the color your heal came
  out. Not similar. THE color. The green said yes to Kaethra too — and
  you would give both journals to know whether it finished the sentence."
- "Find Kaethra. Two people the green answered; between you, maybe one
  truth — and the boy's cure at the end of it." → **+6** `ch6_seeks_truth`
- "Take a cutting. Growth-without-death, pressed in a journal, carried to
  the boy's mark. You'd be careful. You're always careful. You were
  careful the FIRST time." → **−6** `ch6_answered_green`
- "Burn your samples and everyone else's. The last green thing that said
  yes to you is still spreading." → **0** `ch6_would_burn`

**Archer — the regrown thread.** Plate: a snapped stem finding itself,
mid-mend, in close focus; behind it, out of focus, a boundary fence that
isn't there.
- n3: "Nothing here stays cut. Vines close behind the column; a cleared
  path heals by morning. You watched a pilgrim snap a stem and it FOUND
  ITSELF again by dusk. You have exactly one severed thing you never
  stopped carrying, and the Deep is very quietly offering."
- "Some cuts should hold — the Ember's included. Find what the green wants
  before deciding what it gives." → **+6** `ch6_seeks_truth`
- "Ask it. One thread, regrown — a farm, a brother, a gate that stays
  unlatched, restored like the stem. Whatever it costs." → **−6**
  `ch6_answered_green`
- "Trust the scar. What regrows here isn't what was cut — it's what the
  Deep remembers of it. Keep walking." → **0** `ch6_would_burn`

**Warrior — nothing stays broken.** Plate: a sapling snapped at the
gate, mid-mend; the warrior crouched before it at eye level, watching it
heal the way other men watch a fire.
- n3: "You broke a sapling at the gate — habit, checking your hands. By
  the time the column passed, it had straightened. A place where NOTHING
  you break stays broken. You have wanted absolution your whole bearing
  life. This is the counterfeit, and it is very good."
- "Absolution is owned, not grown over. Find the shaman, find the truth,
  and keep your own count honest." → **+6** `ch6_seeks_truth`
- "Test it properly. If the Deep unmakes damage, then in the green the
  blackout is FREE — let it off the leash where nothing can die." → **−6**
  `ch6_answered_green`
- "Refuse the absolution. Break what the road demands, count every
  breaking, and let none of it grow over you." → **0** `ch6_would_burn`

**Assassin — the giving thing.** Plate: the green offering fruit into the
column's open hands; the assassin's hands the only ones behind their back.
- n3: "It gives. No fee, no flask, no grey lips after — fruit for the
  walking, shade for the tired, never once reaching into the pilgrims'
  pockets. Your Ember has been leaning at it since the gate like a cat at
  a fishmonger's. Nothing gives like this. Nothing gives like this WITHOUT
  A REASON."
- "Find the reason. Kaethra knows what the green charges and when — get
  the truth before the bill lands." → **+6** `ch6_seeks_truth`
- "Take the cutting. If it truly gives free, you hold the one thing your
  Ember can spend forever without hurting anyone. Call the bluff." →
  **−6** `ch6_answered_green`
- "Refuse the gift. You know a baited hand when your whole arm is one.
  Torch the offer." → **0** `ch6_would_burn`

**Paladin — mercy without judgment.** Plate: the kneeling field — half
the pilgrim column down in the moss before the green, and the paladin
the only figure left standing in it, hammer grounded like a staff.
- n3: "The Deep acquits EVERYONE. No case heard, no sentence weighed — the
  sick walk in guilty of nothing and come out green and glad. The flock
  knelt in HALVES, and the chain, for the second time in your life, has
  gone quiet. Not respectful-quiet. OUTNUMBERED-quiet."
- "Mercy without truth is just anesthesia. Find Kaethra, hear the actual
  case, and rule on what the green really does." → **+6** `ch6_seeks_truth`
- "Bottle the amnesty. A mercy that skips the bench entirely — the chain
  whispers that some verdicts could use one. Take a cutting for the
  court." → **−6** `ch6_answered_green`
- "Neither kneel nor rule. Burn a firebreak, hold the line, and let wiser
  benches argue the theology." → **0** `ch6_would_burn`

**Warlock — the competitor.** Plate: the tome open and BRISTLING, pages
fanned like a threatened bird; beyond it the green, growing, indifferent.
- n3: "The tome went RIGID at the gate. Growth that only adds, credit that
  never calls, compounding without repayment — the Deep runs the tome's
  own scheme at landscape scale and undercuts it on rates. You have never
  felt your creditor jealous before. It is almost worth the trip."
- "Two predatory lenders, one honest question: find the shaman and learn
  what the green's fine print actually says." → **+6** `ch6_seeks_truth`
- "Open an account. A cutting is a signing bonus — and leverage: let the
  tome and the Deep bid against each other for you." → **−6**
  `ch6_answered_green`
- "Burn the branch office. One creditor is survivable; two is a bidding
  war over your remains." → **0** `ch6_would_burn`

**Echo:** `ch6_briefing` `b1` — e.g. `ch6_answered_green` (stance-neutral,
per the rule above): "The Deep answered eleven pilgrims this spring —
whatever each one asked of it. I have buried what nine of them turned
into, and the other two I still hear at night. Whatever YOU asked at the
gate, bearer — unask it."

**Later payoff:** `ch6_answered_green` is deliberately long-fused — the
Act 2 Drowned Reaches and Roothold openers read it (§3). Two continuity
rules, both free because openers are per-class convos: (1) the DEED
differs by class — warrior ("let it off the leash") and archer ("ask it")
never pocket a physical cutting, so their ch9/ch12 read-back lines speak
to what they LOOSED or ASKED, never to "the cutting in your pack"
(cutting-takers: mage, assassin, paladin, warlock). (2) the SHARED
briefing echo must stay stance-neutral — Vela reads the leaning, not the
pocket. Owner-approved 2026-07-29: the flag is `ch6_answered_green`
(renamed from the draft's `ch6_answered_green` — the name covers all six
deeds).

---

### ch7 — The Breaking Sky (hub: The Summit Camp)

**Logline:** the seal was never stone — it was a sentence, and the last
speaker has stopped speaking.

**Shared spine** *(cue `relay`)*
- `opening_ch7_0` — the Thunder Plains under a bruised sky tearing at the
  edges, lightning frozen mid-fork like cracks in enamel.
- `opening_ch7_1` — the relay: six hundred years of speakers painted as a
  receding chain of firelit figures, each mouth passing the sentence to
  the next — and the newest link standing silent.
- n1 — "The Storm Tongue's seal was never stone. It was a SENTENCE — begun
  six hundred years ago and never allowed to finish, passed mouth to mouth
  by Korrag's order like a torch that must not gutter. For six hundred
  years, it WORKED."
- n2 — "The last speaker has stopped speaking. He stands on the ridge with
  his mouth closed, and he is not resting — he is LISTENING. And the sky
  has begun, very quietly, to finish his sentences for him."

**The asker (n4)** — Apprentice Sorrel, falling in step on the summit
road: "Everyone up there asks about the drake. Nobody asks about the
SENTENCE. What are words, to you?" *(Maren's echo already names her —
the wiring pays twice.)*

**Warlock — contracts of speech.** Plate: the relay-chain redrawn as a
single unbroken line of script winding ridge to ridge; the tome beneath
it, taking dictation.
- n3: "Six hundred years of enforceable SPEECH. No parchment, no seal —
  just breath handed mouth to mouth, and a god bound by the unbroken
  saying of it. The greatest contract ever executed, and the counterparty
  has found the flaw: outlive the signatories. The tome takes notes. So do
  you."
- "Contracts this good deserve performance. Learn the words; be the next
  mouth if no better one stands." → **+6** `ch7_would_speak`
- "Let it lapse. When the sentence fails, the storm owes NOBODY — and an
  unowed god is a god that might deal fresh." → **−6** `ch7_let_it_end`
- "Neither speak nor sign. There's a drake on the ridge with no clauses at
  all; start there." → **0** `ch7_hears_wind`

**Paladin — law older than courts.** Plate: the relay painted as a line
of magistrates across six centuries, each passing a burning writ to the
next — and the newest hand outstretched, empty.
- n3: "The relay is older than the chain, older than benches — a sentence
  served not ON the guilty but BY the innocent, six hundred years of
  speakers doing time for a god's crime. The chain reads it and, for once,
  asks YOU what it means."
- "It means somebody has to serve. Learn the words — a sentence this old
  ends properly or not at all." → **+6** `ch7_would_speak`
- "It means the court failed. Six centuries of gag-order isn't a verdict,
  it's a filibuster — strike it down and hear the case at last." → **−6**
  `ch7_let_it_end`
- "It means the docket's full. Drake first, jurisprudence after." → **0**
  `ch7_hears_wind`

**Mage — sustained perfect work.** Plate: the relay seen as a spell
diagram — one working, three hundred hands, zero errors — annotated in a
margin-hand the mage recognizes as her own.
- n3: "Look at it as a working: one spell, held without error, for six
  hundred years, across three hundred casters, none of whom were
  archmages. Your one heal failed inside a breath. You came up the summit
  road planning tactics and found yourself just… standing there. Admiring
  the craftsmanship. Grieving it."
- "Work that good is finished by hand, not dropped. Learn the words —
  errorless, this time, if it kills you." → **+6** `ch7_would_speak`
- "Every long spell teaches more falling than standing. Let it fall, and
  read the failure closely — Mórwyn's mistakes built your whole art." →
  **−6** `ch7_let_it_end`
- "You don't touch another caster's live working. Especially not one
  holding a GOD. The drake, then." → **0** `ch7_hears_wind`

**Warrior — the listening stillness.** Plate: Cyrraeth on the ridge, head
tilted; below the ridge, small, the warrior in the exact same posture,
recognizing it.
- n3: "You know Cyrraeth's stillness. It is the stillness before your own
  gaps — the body quiet, the tenant leaning forward. He is not resting up
  there. He is doing what you do at night: listening to something on the
  far side of himself, deciding whether to open the door. Nobody ever
  warned HIM about bedposts."
- "Nobody stood with you in the quiet either. Learn the words — stand the
  next watch so his door stays shut." → **+6** `ch7_would_speak`
- "You've always wanted to know what walks in when the door opens. His
  door. Safer than yours. Let it." → **−6** `ch7_let_it_end`
- "Two open doors on one ridge is one too many. Kill the drake, keep your
  own latch, let the sky mind its manners." → **0** `ch7_hears_wind`

**Archer — the thread of breath.** Plate: the relay as one taut line
ridge to ridge, fraying at the near end in a silent mouth; the archer's
eye drawn down it like a sightline.
- n3: "The relay is a thread — the longest you have ever seen. Six hundred
  years of voices tied breath to breath, taut as a bowstring, one end
  fraying in a silent man's mouth. You know exactly what it sounds like
  when a thread like that lets go: a small sound, and it carries further
  than the howl after it."
- "Hold the line. Learn the words and splice yourself in — some threads
  are worth being tied by." → **+6** `ch7_would_speak`
- "A thread that old isn't holding the god — it's holding EVERYONE ELSE.
  Cut it clean and see who was leaning on whom." → **−6** `ch7_let_it_end`
- "Never touch a taut line mid-song. Drake first; the thread was holding
  fine before you got here." → **0** `ch7_hears_wind`

**Assassin — held by giving.** Plate: the speakers each placing something
small and bright into the relay-line — years, breath, a life apiece — and
the line glowing with the paid-in warmth.
- n3: "Every seal you have met was a lock. This one is held shut by what
  the speakers GIVE it: breath, years, a life apiece, freely, forever.
  Nothing taken anywhere. Your Ember circles the idea like it circles a
  warm room, finding no way in. A power sustained by paying. You didn't
  know that was allowed."
- "Learn the words. Just once, be the one who gives the warmth instead of
  the one who wakes holding the flask." → **+6** `ch7_would_speak`
- "Giving that total is the richest vein there is. When the sentence
  breaks, EVERYTHING they paid in comes loose — be standing where it
  lands." → **−6** `ch7_let_it_end`
- "You'd owe the relay your breath forever, and you already carry one open
  debt. The drake dies free of charge." → **0** `ch7_hears_wind`

**Echo:** `ch7_briefing` `m1` (Maren, bookending Act 1) — e.g.
`ch7_would_speak`: "'Learn the words.' Sorrel said the same thing at nine
years old, and the Wardens laughed at her. Nobody on this summit is
laughing now. Hold that thought through everything I'm about to tell you."

**Later payoff:** `ch7_would_speak` / `ch7_let_it_end` are read by the
Act 2 Storm Scar opener and gate one extra line in the True Name
recitation quest (ch13).

---

## 3. Act 2 — chapters 8–14 (lands with each chapter build)

Same grammar, same refraction table. Two Act-2-specific notes:

- **The opener is the bible's delivery vehicle.** `ACT2_DESIGN.md` §V gives
  each chapter dense fiction (vessels, seals, the Waking War) with no
  specified on-ramp. The shared spine carries the bible; the class turn
  makes it personal.
- **Briefing NPCs for ch8–ch14 don't exist yet.** Each echo below names
  the *role* the chapter build should cast, not a final name.

---

### ch8 — The Ashfall Foundries

**Logline:** Act 1 showed the Cinderborn pitch; the foundry city is the
invoice.

**Shared spine** *(cue `ashfall`)*
- `opening_ch8_0` — the crack: a hairline of white-gold light running
  through a foundry floor — and the work continuing around it, ore-carts
  routed wide, a walkway built OVER the glow. The seal, straining; the
  city, used to it.
- `opening_ch8_1` — outside the walls: the defectors' camp — master
  smiths at a cold fire, tools across their knees, looking back at their
  own lit chimneys.
- n1 — "The Cinderborn built their heart on the Molten Judge's seal and
  called the whispering a technique. Act One let them make that pitch.
  This is the invoice: the forges have not banked in three years, the
  verdicts no longer wait for sermons, and under the central works the
  seal has developed a crack the foremen ROUTE THE CARTS AROUND."
- n2 — "And outside the walls sit the first defectors — master smiths who
  signed the pitch, worked the heats, and one shift put their tools down
  and walked. Ask them what changed. They will tell you: the fire started
  signing the work. And the signature was not theirs anymore."
- *(faction variants on n2, one line each — `joined_cinderborn`: "These
  are YOUR people's fires. That is either a reason to look away or the
  only reason to look closely." / `joined_accord`: "Your writ says
  infiltrate. The ash does not care whose seal is on your papers.")*

**The asker (n4)** — a journeyman who walked out mid-indenture, feeding
the defectors' cold fire one splinter at a time: "Going in, then. To
cool it, to copy it, or just to kill it — which?"

**Paladin — the maker's-mark.** Plate: the paladin's hammer held up
against the city's oldest foundry gate — and on both, the same
maker's-mark. *(Canon-safe: the ch1 opener puts the Ember IN the hammer —
a physical forging origin, not a metaphysical one.)*
- n3: "The chain does not go quiet here. It RECITES — case law you never
  learned, precedents in a dead tongue, rising through the links like
  heat through a floor. And on the city's oldest gate: a maker's-mark
  you have run your thumb over a thousand times without reading — the
  one on the cheek of YOUR hammer. The hammer that carries your Ember
  was poured in these foundries. Start asking what else of yours was."
- "Whatever poured it doesn't own it. Cool this city, crews first, and
  let the chain watch you overrule the foundry that cast your hammer." →
  **+6** `ch8_cool_the_forge`
- "Read the precedents. The binding texts hold the Judge's whole
  jurisprudence — and your hammer's provenance. Study before you
  smash." → **−6** `ch8_studied_binding`
- "One defendant: the vessel. Everything else is scenery with a docket
  number." → **0** `ch8_here_for_vessel`

**Warrior — the cured man.** Plate: the defectors' fire at night; the
camp's one improved man sits apart, back to the flames, facing the lit
city — his silhouette the straightest thing in the frame.
- n3: "There is one improved man in the defectors' camp. He had a thing
  like yours once — gaps, a tenant, wreckage he didn't remember making.
  The furnace took it. He is certain now, and steady, and he sits outside
  the walls because he cannot stop MISSING it. You walked in ready to
  envy this city. Nobody warned you about the cured man grieving his
  disease."
- "Believe him. The cure is a taking with better manners — cool the
  forges before it collects everyone still deciding." → **+6**
  `ch8_cool_the_forge`
- "His grief is his. The technique is REAL — learn how the binding holds
  the fire before ruling that nobody gets to be certain." → **−6**
  `ch8_studied_binding`
- "Certainty, grief, philosophy — it all keeps. The vessel doesn't. Down,
  done, out." → **0** `ch8_here_for_vessel`

**Mage — the mismanaged working.** Plate: the crack from above, ringed by
hurried chalk containment-lattices — patches on patches, three different
hands, none of them right.
- n3: "You grieved one great working on the summit — six hundred years,
  ended clean. This one is ending UGLY: the Concord's seal, patched by
  forge-lords who mistake the prisoner's patience for their own skill.
  Every 'improvement' in this city is the working failing a little
  further, and production calling it yield. You are watching the
  second-oldest spell in Vaelscar die of mismanagement."
- "Workings deserve better deaths. Cool the forges and give the seal an
  honest keeper — or an honest end." → **+6** `ch8_cool_the_forge`
- "The binding texts are the seal's own grammar. Copy them — a caster who
  can read THIS containment could contain anything. Anything at all." →
  **−6** `ch8_studied_binding`
- "Not your spell, not your patient. The vessel dies; the seal does what
  seals do." → **0** `ch8_here_for_vessel`

**Archer — the leaving, done well.** Plate: a master smith at the camp's
cold fire, teaching an apprentice a hammer-grip with empty hands — no
forge, no iron; the archer watching from the edge of the light.
- n3: "Two acts of reading threads people would not drop, and here is
  something new: threads CUT WELL. Masters who loved the work, watched
  the signature change, and walked out with the ends cauterized. You know
  what that walk costs down to the copper. You are the only person at
  their fire who has made it on purpose."
- "Every smith still inside is mid-decision. Cool the forges before the
  furnace closes the question for them." → **+6** `ch8_cool_the_forge`
- "The defectors carried out the masters' knowledge. Sit at their fire
  and learn the binding from the hands that held it — knowledge travels
  lighter than loyalty." → **−6** `ch8_studied_binding`
- "One vessel, one arrow's worth of business. The camp's grief isn't
  yours to carry." → **0** `ch8_here_for_vessel`

**Assassin — the open vault.** Plate: the foundry quarter at night, every
door standing open, lit warm from inside — an invitation shaped like a
city.
- n3: "Every door in this city stands open to you, and that is what has
  your neck prickling: the Judge's city does not guard against takers —
  it RECRUITS them. Walk in, take anything; the fire adds it to your
  account and starts improving you toward repayment. The first vault
  you've met that WANTS the thief inside. The Ember thinks it is home."
- "Take nothing but people. Crews out, account empty, forges cooling
  behind you." → **+6** `ch8_cool_the_forge`
- "Open the one door they DO watch: the binding texts. A vault this
  confident keeps its real valuables legible — read how the grip works." →
  **−6** `ch8_studied_binding`
- "In, vessel, out — hands in pockets the whole way down." → **0**
  `ch8_here_for_vessel`

**Warlock — the compelling grammar.** Plate: the binding texts in their
reliquary — mortal paper a god once countersigned — and the tome pressed
flat against the warlock's back, hiding.
- n3: "The binding texts are the only known instrument that made a
  god-king countersign — mortal paper, divine signatory, terms ENFORCED
  for six centuries. Your book has spent two acts refusing to name what
  you traded. Somewhere below is the grammar that could COMPEL it — and
  the tome knows, and has pressed itself flat against your back like a
  debtor at a summons."
- "Compel it for everyone. Cool the forges, free the collateral — this
  city's people first, your clause after." → **+6** `ch8_cool_the_forge`
- "The texts. Before anything burns, the texts — one binding grammar,
  applied at home, and the tome finally answers questions." → **−6**
  `ch8_studied_binding`
- "Banks fall; debtors walk out in the confusion. The vessel, then the
  door, and no withdrawals." → **0** `ch8_here_for_vessel`

**Echo:** the chapter's briefing NPC (Accord route: a defecting Cinderborn
smith; Cinderborn route: a foundry quartermaster). **Later payoff:**
`ch8_studied_binding` gates one extra dialogue line at the ch14 finale's
Seal-her option — the player who took notes has standing to ask for the
binding text.

---

### ch9 — The Drowned Reaches

**Logline:** the Root flooded an imperial undercity, and it is using
people as wire.

**Shared spine** *(cue `drowned`; the second spine beat is
Kaethra-conditional, keyed on the ch6 finale flags
`chose_kaethra_sheathed` / `chose_kaethra_struck` — see §5 engine note)*
- `opening_ch9_0` — the drowned undercity: imperial arches under
  green-glass water, streets visible below the surface like a pressed
  flower.
- `opening_ch9_1` — roots threading THROUGH the streets like veins
  through a hand; Wildfang cure-seekers in coracles, taking samples with
  long tongs.
- n1 — "Below the old empire's southern gate, an undercity drowned in
  green. The Pale Root found the empire's plumbing and liked it — a god
  of growth does not dig when it can inherit."
- n2 *(conditional)* — spared: "At the heart of the flood: Kaethra.
  Alive. Lucid. GROWING. The Root speaks through her the way a voice
  speaks through a horn — and she hears every word it makes her say." /
  killed: "At the heart of the flood, the Root grew a new gardener from
  what it remembered of the last one. It remembered the shape. It did not
  bother with the face."
- *(flag variant on n1, `ch6_answered_green` — one line appended: "The
  cutting in your pack turned over in the night. It is pointing at the
  city like a compass needle.")*

**The trigger + n4 (INTERNAL)** — the cure-seekers' map-runner shows you
a chart the city corrected overnight, then wades off to re-survey. You
stand at the waterline holding the wrong map. Below is a god that talks.
The shard has opinions about gods that talk.

**Mage — the sister wound.** Plate: Kaethra grown into the junction wall
(or her faceless echo), and beside the image, small, a page of the mage's
own journal — the handwriting nearly the same.
- n3: "Kaethra asked the green for a cure and it said yes — you have
  carried the twin of that yes for years. Every cure-seeker map in this
  camp is a version of your journals. This chapter is your promise with
  the ending still wet."
- "She is what the boy could become. Cut tethers, never wire — and take
  the truth home whole this time." → **+6** `ch9_spares_the_wire`
- "IT ANSWERED HER. IT WILL ANSWER YOU. GET CLOSE TO THE RELAY AND ASK
  ABOUT GREY MARKS — ASKING IS NOT TAKING." → **−6** `ch9_would_bargain`
- "Let the water keep the answers. Some questions cost more asked than
  unasked — pass through, and open nothing." → **0** `ch9_seals_behind`

**Archer — threads through people.** Plate: a cure-seeker wading,
oblivious, through root-threads strung in one wrist and out the
collarbone — visible only to the archer in the foreground.
- n3: "You have seen threads all your bearing life — but the Root's are
  the first strung THROUGH people, in one wrist and out the collarbone,
  taut to a green horizon. The cure-seekers can't see what they're wading
  through. You can't stop."
- "Wire is people. Cut only tethers, and walk the seekers out along the
  lines they can't see." → **+6** `ch9_spares_the_wire`
- "FOLLOW ONE THREAD ALL THE WAY IN. A WEAVER WHO WORKS IN PEOPLE COULD
  RESTRING WHAT I CUT. THE GREEN OFFERED ONCE. I AM OFFERING NOW." →
  **−6** `ch9_would_bargain`
- "Close every door you pass. What the water holds it can keep — it just
  catches no one NEW." → **0** `ch9_seals_behind`

**Warrior — borrowed hands.** Plate: wire-people at work in the flooded
dark — tying, hauling, holding — every posture competent, every face
absent.
- n3: "The wire-people move when the Root moves them — hands tying,
  hauling, holding, and behind every motion NOBODY DECIDING. It is your
  blackout, distributed: a whole undercity of borrowed hands. You have
  woken in wreckage enough times to know exactly what they'll feel when
  the wire goes slack."
- "Nobody else wakes up in wreckage they didn't choose. Slack every wire
  gently; catch them as they come back." → **+6** `ch9_spares_the_wire`
- "IT BORROWS HANDS. IT COULD BORROW ME. OFFER IT THE TRADE — AND WAKE
  UP INNOCENT FOREVER." → **−6** `ch9_would_bargain`
- "Break the junctions as you pass, and let the water hold what falls. A
  wire underwater moves nothing." → **0** `ch9_seals_behind`

**Assassin — the god that negotiates.** Plate: a root-tendril curled on a
stone table in the shape of an open hand — palm up, patient, waiting.
- n3: "Everything down here was TAKEN without being stolen — the Root
  just grew where the ownership was thin. And unlike your Ember, it will
  TALK. The first power you've met with a negotiating table. The
  flask-cold carter never got to negotiate. That's the memory that
  surfaces, wading in."
- "You never got to bargain either — the Ember just took. Spare the wire
  the courtesy nobody spared you: get them out un-negotiated." → **+6**
  `ch9_spares_the_wire`
- "IT DEALS. I NEVER LEARNED HOW. SIT US AT THE TABLE AND OPEN WITH MY
  APPETITE — SEE WHAT A GOD BIDS FOR A HUNGER LIKE MINE." → **−6**
  `ch9_would_bargain`
- "Never bargain wet. Pass through with your pockets shut and leave the
  water sitting between you and its table." → **0** `ch9_seals_behind`

**Paladin — the defendant that inherits.** Plate: an imperial courtroom
under water, root-mass on the bench, in the dock, and in the gallery —
all one organism.
- n3: "The chain wants someone to CHARGE, and the Root won't hold still
  for an indictment — it is the crime, the accomplice, the witness, and
  the estate, all growing through each other. Every wire-person is
  evidence being actively tampered with. You cannot try a flood. You can
  only decide who drowns in it."
- "Protect the witnesses. The wire comes out alive; the Root can answer
  in a later court." → **+6** `ch9_spares_the_wire`
- "THE RELAY TALKS. TAKE TESTIMONY FROM THE GOD ITSELF, WHATEVER THE
  HEARING COSTS THE WIRE. TRUTH OUTRANKS WITNESSES." → **−6**
  `ch9_would_bargain`
- "No hearings below the waterline. Do what the descent demands and let
  the water keep custody of the rest. Appeals in the spring." → **0**
  `ch9_seals_behind`

**Warlock — the inheritor.** Plate: a drowned guildhall strongroom, root
grown clean through the vault door; coins fused into the root-wood like
knots — ownership dissolving in real time.
- n3: "The Root does not lend. It INHERITS — plumbing, cities, bodies,
  whole estates absorbed the moment the will is weak. The tome is
  offended to its spine: inheritance skips the signature entirely. No
  consent, no clause, no debt. Even your creditor thinks it's cheating."
- "No one consents to being plumbing. Cut the wire free, estate by
  estate." → **+6** `ch9_spares_the_wire`
- "Ask the Root, through the relay, what it takes to eat a contract.
  *(The tome pressed itself shut ON YOUR HAND as you thought it. You are
  still thinking it.)*" → **−6** `ch9_would_bargain`
- "Contest nothing, sign nothing, save nothing it can bill you for. Take
  the one path through and leave the water holding the paperwork." →
  **0** `ch9_seals_behind`

**Echo:** briefing NPC (a Wildfang cure-seeker foreman — the bible puts
their camp at the gate). `ch9_would_bargain` earns a recoil variant if the
Kaethra-spared finale's mid-fight choice arrives.

---

### ch10 — The Singing Ice

**Logline:** the vessel is fifteen, and she walked into the ice because
everything warm had been taken from her.

**Shared spine** *(cue `singing_ice`)*
- `opening_ch10_0` — the crystal caverns singing: the ice shelf lit from
  below, resonance crystals ringing visible ripples through the blue.
- `opening_ch10_1` — Elara walking into the ice: a small figure, barefoot
  in the snow, not looking back at the burning forge-town behind her.
- n1 — "The Frozen Expanse has learned to sing. Below the shelf, the
  crystal caverns ring like struck glass, and the Long Sleep cult calls
  it the Queen's morning hymn. They are not entirely wrong. That is the
  problem."
- n2 — "Her name is Elara. The blacksmith's daughter — the one Mórwyn's
  awakening orphaned. She walked into the ice because the ice was the
  only thing left that promised to KEEP something. She sleeps, and the
  ice grows, and nobody in either camp says the word 'vessel' where the
  cult can hear."
- *(flag variants on n2, one line — `ch5_vowed_morning`: "You promised
  the north a real morning once. She is what the promise looks like now."
  / `ch5_felt_pull`: "The hush you leaned toward under the ice — it has a
  name now, and the name is a child's.")*

**The trigger + n4 (INTERNAL)** — the singer barring the shaft mouth
breaks off mid-hymn: "If you go down to her — go down carrying WHAT?"
You push past without answering. The answer happens on the long climb
down, in the blue dark, where the shard's voice carries best.

**Mage — the founding debt.** Plate: the cocoon, and reflected faintly in
its crystal face, not the mage's own reflection but a forge-town burning.
- n3: "Elara's father died of the blight — Mórwyn's domain, the same
  waking world that woke YOUR green light. Do the arithmetic you've been
  avoiding since the shelf came into view: her orphaning and your art
  are two receipts from the same age. The girl in the ice is what your
  power's era costs the people it doesn't choose."
- "Then owe her. Carry the warm thing down, hold the door open, and pay
  the founding debt in person." → **+6** `ch10_carries_warmth`
- "A GOD FILTERED THROUGH A CHILD IS THE WEAKEST IT WILL EVER BE. YOU
  NEED TO HAVE STUDIED ONE BEFORE THE HOLLOW FLAME. STRIKE THROUGH — I
  WILL HOLD YOUR HAND STEADY." → **−6** `ch10_strikes_through`
- "The cult built the shrine; the cult answers. Keep your arithmetic out
  of it." → **0** `ch10_blames_cult`

**Warrior — the exam.** Plate: the descent shaft into blue dark; the
warrior at its lip, sword half-drawn, his own breath the only movement.
- n3: "Somewhere under the shelf there is a fight where the sword-line
  runs THROUGH a sleeping fifteen-year-old. You have spent a lifetime
  learning to aim the thing that doesn't aim. This is the exam: the
  blackout does not distinguish cocoon from Queen. You would have to stay
  yourself the whole way down."
- "Stay yourself. Carry warmth, swing late, and be the first blade she
  sees that waited." → **+6** `ch10_carries_warmth`
- "LET THE ARM DECIDE AT THE COCOON. I HAVE ALWAYS KNOWN WHAT YOU WON'T
  ADMIT WANTING. I NEVER HESITATE ON THE DOWNSWING." → **−6**
  `ch10_strikes_through`
- "Bind the cult, starve the shrine, and make the singers undo what the
  singing built." → **0** `ch10_blames_cult`

**Archer — the thread-blank girl.** Plate: the cocoon at the center of a
dreamed web — the Queen's threads spun AROUND a girl who has none of her
own; a web with no anchor points.
- n3: "You read people by their threads, and the girl in the cocoon has
  NONE. Not cut ends, not scars — nothing. She unpicked herself so
  completely walking into the ice that the Queen has to dream threads
  around her, a borrowed web where a person's ties should be. You have
  met one other blank like that. In mirrors. On the bad mornings."
- "Bring her a real one. One thread that doesn't pull, offered beside the
  Queen's fakes — held out until she takes it, or doesn't." → **+6**
  `ch10_carries_warmth`
- "NOTHING ANCHORS HER. THE QUEEN GRIPS A GIRL WITH NO HANDLES — ONE
  SHOT AND THE GRIP CLOSES ON NOTHING. IT WOULD EVEN BE CLEAN. I CUT
  CLEANER." → **−6** `ch10_strikes_through`
- "The cult spun the web; the cult unspins it. Warrant first." → **0**
  `ch10_blames_cult`

**Assassin — the kept warmth.** Plate: the assassin's bare palm flat
against the cocoon's crystal, a coin of thaw blooming under the hand —
the first warmth the ice has accepted in years (deliberate rhyme with
ch1's "take my warmth back" beat — flagged, not accidental).
- n3: "Everything warm was TAKEN from her — you have been on the other
  end of that sentence, holding the flask. So she gave the last of it to
  the one vault that promised keeping. Now the Queen holds a child's
  warmth in trust and calls the interest 'winter'. You know this
  contract. You've BEEN this contract."
- "Break it the way nobody broke yours: warmth returned, no charge, and
  stay till dawn." → **+6** `ch10_carries_warmth`
- "TRUST FUNDS CAN BE RAIDED. STRIKE THE TRUSTEE WHILE THE ASSETS RUN
  LIQUID — AND WHAT THE VAULT SPILLS, I WILL CATCH." → **−6**
  `ch10_strikes_through`
- "The cult brokered the deposit. Collect the brokers; leave the vault." →
  **0** `ch10_blames_cult`

**Paladin — the crime with no criminal.** Plate: cult candlelight
throwing the paladin's shadow across the cocoon — and the shadow's arm
raised in accusation while his own arms stay at his sides.
- n3: "The chain has met every kind of guilt. This is its first crime
  with no criminal: the cult believed, the god is a god, and the girl
  consented as much as a gutted fifteen-year-old can. Harm everywhere; a
  hand nowhere. The chain circles the cocoon like a bailiff with a
  warrant nobody will sign — and it has begun, very quietly, to suggest
  the VESSEL will do."
- "When there is no one to punish, there is still someone to protect.
  Warm the plaintiff; let the charge stay empty." → **+6**
  `ch10_carries_warmth`
- "A VESSEL IS THE CRIME MADE FLESH. STRIKE THROUGH THE GIRL AND ENTER
  THE CASE CLOSED. I WILL SIGN THE WARRANT MYSELF." → **−6**
  `ch10_strikes_through`
- "There IS a hand: the ones who sang her down. Charge the cult, and let
  precedent sort the god." → **0** `ch10_blames_cult`

**Warlock — the blank appraisal.** Plate: the tome open before the
cocoon, quill hovering — its appraisal page empty. The first blank page
you have ever seen it keep.
- n3: "The tome appraises everything — it priced your soul mid-sentence
  once, unasked. It has been open at the cocoon for an hour, and the page
  is still BLANK. A girl who gave everything away before the god arrived:
  no equity, no lien, nothing to secure a debt against. The Queen is
  squatting in an empty deed. The tome finds this horrifying. You find it
  almost hopeful."
- "An empty deed can't be foreclosed — but it can be lived in again.
  Carry the warm thing down and help her repossess herself." → **+6**
  `ch10_carries_warmth`
- "A TRUSTEE WITH NO SECURITY HAS NO CLAIM. STRIKE WHILE THE QUEEN HOLDS
  NOTHING — THE CHEAPEST GOD-KILL THERE WILL EVER BE. I HAVE RUN THE
  NUMBERS TWICE." → **−6** `ch10_strikes_through`
- "The brokers wrote a deal on an empty deed. Unwind the cult and let the
  escrow starve." → **0** `ch10_blames_cult`

**Echo:** briefing NPC (a Warden iceline officer, or a Long Sleep
apostate — the bible's camps offer both). `ch10_strikes_through` deserves
the coldest read-back in the game; write it so the player feels SEEN.

---

### ch11 — The Ember Crusade

**Logline:** both armies are right, and that is why it will be a
slaughter.

**Shared spine** *(cue `two_fires`)*
- `opening_ch11_0` — two camps of fires facing each other across the
  Sanctified Ruins at night — the same firelight in two colors, Accord
  grey-gold and Cinderborn flame-red.
- `opening_ch11_1` — between the lines: refugees walking OUT down the
  contested road, carrying doors and cradles, under both armies' silent
  watch.
- n1 — "It has come to banners. The Accord will rebind the seals — which
  costs bearers their Embers, burned willingly into new locks. The
  Cinderborn will bind the god-kings to harness — which costs only
  everything, eventually. Both of them are right about the other."
- n2 — "The old Ember Guard fortress sits between them, sanctified,
  ruined, suddenly the most valuable ground in the world. The people who
  lived in its shadow are leaving with their doors on their backs. They
  have seen righteous fires before. And on the wall above the whole board
  stands Aldric — the grey knight who shared Maren's fire in the refugee
  years, the Guard's last, no fire left in him at all — not choosing a
  side. GRADING them."
- *(faction variants on n1, one line each, matching allegiance.)*

**The asker (n4)** — the refugee with the door on his back, passing
without stopping: "Two armies, both right. Where will you be standing
when they stop being polite about it?"

**Paladin — right v right.** Plate: the chain split down its length into
grey-gold and flame-red strands, pulling evenly, the paladin's fist
closed around the fork point.
- n3: "The chain has read both briefs and finds for BOTH — which it has
  never done, and it is not enjoying the experience. The Accord's math is
  sacrifice; the Cinderborn's is hubris; and Aldric on the wall has
  stopped grading the armies and started watching YOU."
- "When both sides are right, the verdict protects whoever's between
  them. Stand there." → **+6** `ch11_stands_between`
- "A hung court pays whoever holds the evidence. Collect from both —
  receipts are neutral." → **−6** `ch11_holds_receipts`
- "Your banner filed first. March, and appeal after the war." → **0**
  `ch11_marches_in_step`

**Warrior — pre-forgiven violence.** Plate: two recruiting tables, two
banners, two quartermasters — both beckoning the same scarred pair of
hands.
- n3: "A war is the one place the blackout comes PRE-FORGIVEN — every gap
  in memory covered in advance by somebody's righteous cause. Two of
  them, even, bidding. You have never been offered absolution wholesale
  before, and it smells exactly like the furnace city did."
- "No cause gets the arm unsupervised. Stand between, swing last,
  remember everything you can." → **+6** `ch11_stands_between`
- "Take the coverage. Enlist the gaps under a flag and let the paperwork
  call it valor." → **−6** `ch11_holds_receipts`
- "In step, eyes open. Your banner's orders, your own count, doubt filed
  for after." → **0** `ch11_marches_in_step`

**Mage — the symposium with casualties.** Plate: both armies' siege
artifacts rolling to the line — seal-lattices, bound-fire engines — the
finest applied work of the age, aimed at each other.
- n3: "Both armies brought ARTIFACTS — Accord seal-lattices, Cinderborn
  bound-fire engines, the best applied work of the age rolling toward
  mutual disassembly. It is a symposium with casualties. And every device
  on both manifests descends from someone's 'just once'."
- "Stand between the engines and the people they'll miss by. Somebody has
  to review this war's methods." → **+6** `ch11_stands_between`
- "Battlefield salvage is peer review. Collect the receipts — and the
  prototypes — from both sides while they spend." → **−6**
  `ch11_holds_receipts`
- "March with your banner and study only what your orders point at." →
  **0** `ch11_marches_in_step`

**Archer — banners as chosen ties.** Plate: the refugee road at dawn
between the armies: a family's dog straining back toward the abandoned
house, the child hauling its rope onward; the archer walking the same
road, same direction.
- n3: "A banner is a thread you tie ON PURPOSE — the first ones you've
  seen chosen freely since the Ember cut yours. Whole camps belonging,
  loudly, in matching colors. And between the camps, the refugees: every
  one trailing threads to houses both armies plan to be RIGHT on top of."
- "Stand where the threads cross. The refugees' lines out are the only
  ones on this field worth guarding." → **+6** `ch11_stands_between`
- "Belonging is a market this week. Hold both armies' receipts and let
  them bid for the drifter with the eyes." → **−6** `ch11_holds_receipts`
- "You tied your banner on; honor the knot. March, and mind your own
  thread." → **0** `ch11_marches_in_step`

**Assassin — the taking in uniform.** Plate: a requisition detail
emptying a farmhouse larder, every item signed for in triplicate; the
farm family holding the receipt.
- n3: "War is the taking with a UNIFORM — requisition, forage, spoils,
  all signed for in advance. Your Ember has never been so relaxed;
  everything it wants to do here is POLICY somewhere. That, precisely, is
  what has your hackles up: you have spent years learning to refuse
  yourself. Nobody else on this field is even trying."
- "Somebody has to keep refusing. Stand between the armies and the
  larders they'll 'requisition' through." → **+6** `ch11_stands_between`
- "Go professional. Two armies, one discreet contractor, receipts from
  both — the taking finally salaried." → **−6** `ch11_holds_receipts`
- "March quiet, take nothing off-books, and let the war feed itself
  without you." → **0** `ch11_marches_in_step`

**Warlock — the closed ledger.** Plate: Aldric on the wall, seen from
the warlock's place in the muster line — and around the old knight,
faint, the AFTER-IMAGE of a fire that is no longer there, like a brand
lifted from a page.
- n3: "The tome cannot stop looking at the man on the wall. Aldric BURNED
  his Ember — principal, interest, the whole instrument, discharged in
  one payment, thirty years ago, on the first fall's field. The only
  closed ledger in Vaelscar, walking around, breathing. The tome finds
  him obscene. You find him… instructive."
- "A man who paid everything guards what's left honestly. Stand between
  the armies the way he stands above them." → **+6** `ch11_stands_between`
- "Study the discharge. If an Ember can be burned to settle, YOUR debt
  has an exit clause — collect both sides' receipts while you work out
  the terms." → **−6** `ch11_holds_receipts`
- "March in step and don't make eye contact with the wall. Some ledgers
  close; yours has miles left." → **0** `ch11_marches_in_step`

**Echo:** briefing NPC = the player's own faction quartermaster at the
muster (faction-divergent hub rooms are this chapter's signature). The
parley choice at Drayce/Maeven 30% keeps sole ownership of faction
STANDING shifts — the opener stays resonance-only (one faucet, one job).

---

### ch12 — The Roothold

**Logline:** the Pale Root never needed a vessel — you are standing
inside it.

**Shared spine** *(cue `roothold`)*
- `opening_ch12_0` — the Blooming Deep grown into a biome: a horizon of
  moving green, weather patterns visible in the canopy like currents.
- `opening_ch12_1` — deep center, from above: five slow glows through the
  canopy, arranged like organs seen through skin.
- n1 — "The Deep did not spread. Spreading is what fires do. The Deep
  GREW — and what it grew into is a country. The maps of this region are
  redrawn weekly, and lately the maps lose the argument."
- n2 — "Every other god-king needed a mortal door. The Pale Root looked
  at the Concord's rule — THROUGH people, only through people — and grew
  around it the way a root grows around a law. The land is the vessel.
  You are not walking to the boss. You are walking ON it. It has five
  hearts, and every living thing in the green leans toward them slightly
  on the beat."
- *(flag variant on n2, `ch6_answered_green`: "The cutting you took in the
  Deep is heavier every day now. It is not growing. It is REPORTING.")*

**The asker (n4)** — a Wildfang scout hammering in a warning-post at the
treeline, the third replacement this month: "Signs don't hold it. What
is YOUR answer to a land that will not die?"

**Archer — a country of thread.** Plate: the horizon as pure weave —
thread AS landscape — five great knots glowing at the center.
- n3: "The whole horizon is weave. Not threads THROUGH things — thread AS
  things: hills of it, weather of it, five slow knots at the center
  glowing like hearts because they ARE hearts. You have read rooms by
  their threads all your life. You have never had to read a nation."
- "Read it to the end. Every weave has a selvage — find the Root's, and
  give the country a hem." → **+6** `ch12_brings_ending`
- "A weaver this size could re-string ANYTHING — walk to the hearts and
  show it the cut end you carry." → **−6** `ch12_would_garden`
- "Unpick exactly what the road demands — five knots, no flourishes —
  then hem the border behind you and post the warnings." → **0**
  `ch12_draws_borders`

**Warrior — the meaningless swing.** Plate: a sword-cut through a root
wall, already sealing; the warrior watching it close with an unreadable
face.
- n3: "You hit it, it heals. You burn it, it blooms. A COUNTRY where the
  arm means nothing — every swing absorbed like rain into loam. The
  blackout took one look at the regrowing green and, for the first time
  in your life, went back to sleep. You cannot decide if that is peace or
  insult."
- "If the arm means nothing here, bring what does: an ending, delivered
  deliberately, heart by heart." → **+6** `ch12_brings_ending`
- "Ask the Root to KEEP the arm asleep. It quiets what it grows through —
  a gardener's hands never black out." → **−6** `ch12_would_garden`
- "Cut the five hearts because they must fall — not because it means
  anything. Then draw the border, and hold it." → **0**
  `ch12_draws_borders`

**Mage — the casterless working.** Plate: the five hearts drawn as a
spell diagram with the caster's position empty — and a chair, grown from
root, waiting at that exact point.
- n3: "Five hearts, one working, no caster. It maintains ITSELF — the
  dream every archmage chased and the nightmare every apprentice is
  warned with, running at country scale on nobody's mana. Your green
  light needed you for one breath and failed. This needed no one, ever,
  and cannot stop succeeding."
- "A working that can't stop isn't finished — it's abandoned mid-cast.
  End it properly, heart by heart, the way its author should have." →
  **+6** `ch12_brings_ending`
- "Take the maintainer's chair. A working needs no caster, but it will
  accept a GARDENER — and a gardener could grow one small grey-marked
  cure on the side." → **−6** `ch12_would_garden`
- "Edit nothing you don't have to. The hearts fall — that is surgery,
  not authorship — then ward the perimeter and go." → **0**
  `ch12_draws_borders`

**Assassin — the thing without appetite.** Plate: a candle set at the
green's edge as a test — burning dead straight, unleaned-at; the
assassin crouched behind it, watching the flame not move.
- n3: "It has stopped inheriting and started COMPOSING — a whole country
  now, self-owned, self-feeding, needing nothing from anyone. Even the
  relay lived on what its speakers paid in; this doesn't even RECEIVE.
  The first power you've ever met with no appetite at all. Your Ember stands at the
  treeline like a pickpocket at a monastery: professionally offended,
  personally unnerved."
- "No appetite means no mercy either. Give it the ending it can't want
  for itself." → **+6** `ch12_brings_ending`
- "Feed it the one thing it lacks: intent. Offer your hands as gardener
  and your hunger as seed." → **−6** `ch12_would_garden`
- "Nothing to steal, nothing to save — just five hearts between you and
  out. Do the job, fence the border, walk away." → **0**
  `ch12_draws_borders`

**Paladin — the country-sized defendant.** Plate: a Wildfang map-table:
the region redrawn five times, older maps pushed off the table's edge;
the paladin's gauntlet holding the newest flat while its inked border
crawls.
- n3: "The trial you postponed in the Drowned Reaches convenes here, and
  the defendant has grown into its own jurisdiction — courts need
  borders, and the Root IS one. Five hearts, five counts. The chain has
  stopped reciting and started PREPARING. It has never sentenced a
  landscape before. Neither have you."
- "Five counts, five verdicts, executed in person. A land that can't die
  gets due process and an ENDING." → **+6** `ch12_brings_ending`
- "Plea-bargain: the Root wants a warden it can grow around. Take the
  gardener's bench and call it a supervised sentence." → **−6**
  `ch12_would_garden`
- "Execute the warrant, not a verdict: five hearts, due force, no ruling
  entered. Border and signage for whatever grows back." → **0**
  `ch12_draws_borders`

**Warlock — the solvent estate.** Plate: the warlock at the Roothold's
treeline, holding the tome out toward the green like a talisman — and
nothing in the whole breathing country so much as leaning toward it.
- n3: "The tome ran the numbers three times: the Root owes NOTHING. No
  pacts, no interest, no counterparty — a god that simply grew until
  owning and being were the same act. Your whole life is denominated in
  what you owe. You are standing inside the only solvent thing you have
  ever met, and it is beautiful, and the tome wants it BURNED."
- "Solvency isn't innocence. Close the estate cleanly — five hearts,
  five settlements, no heirs." → **+6** `ch12_brings_ending`
- "Apply for residency. A gardener inside a debtless estate is beyond
  every creditor's reach — including the one in your pack." → **−6**
  `ch12_would_garden`
- "Settle only what blocks the road — five hearts, itemized, no interest
  taken — then draw the border at the treeline and keep your liabilities
  OUT of its assets." → **0** `ch12_draws_borders`

**Echo:** briefing NPC (a Wildfang elder who remembers the Deep as a
bog — this is their homeland's last argument). **Later payoff:**
`ch6_answered_green` + `ch12_would_garden` together earn one unsettling
extra line in the Heart of the Root arena — the Root recognizes an
APPLICANT.

---

### ch13 — The Storm Scar

**Logline:** the crack is wide enough to speak through now, and it knows
your language.

**Shared spine** *(cue `storm_scar`)*
- `opening_ch13_0` — the scar: void showing through weather like
  underpainting through worn canvas; sand streaming UP into the tear.
- `opening_ch13_1` — lightning striking in a LINE of glyphs across the
  plain — a sentence being written on the world in the world's own
  handwriting.
- n1 — "The seal you heard crack at the end of Act One has torn. The
  Thunder Plains are a wound now — a place where the weather is a
  membrane and the void leans on it from the far side, testing the give."
- n2 — "The Storm Tongue never needed a vessel. It is a VOICE — it speaks
  in weather, and lately it has been practicing sentences: short ones,
  grammatical, aimed. Korrag's last survivors hold the tear's corners
  with the old recitation, three mouths doing the work of six hundred
  years. The storm knows their words rather better than they do."
- *(flag variants on n2 — `ch7_would_speak`: "You said once that some
  sentences deserve finishing. The plain ahead is where you find out if
  you meant it." / `ch7_let_it_end`: "You wanted to hear the world
  unmuzzled. Listen, then. It is saying something.")*

**The trigger + n4 (INTERNAL)** — the youngest of the three speakers,
hoarse between recitations *(the senior speaker stays the briefing
NPC)*: "What is a name, in your hands?" You open your mouth to answer —
and realize you have been mouthing storm-words all morning without
choosing to. Some of the voice below is yours. Some is not.

**Warlock — the first language.** Plate: the tome open beneath the glyph
lightning, copying — and its own script visibly a child's hand beside the
storm's.
- n3: "The tome writes in words. THIS is what words are descended from —
  speech that binds weather, sentences with casualties, grammar older
  than debt. The Storm Tongue is not a god that uses language. It is
  language, that got worshipped. The tome, for the first time in your
  acquaintance, is taking dictation."
- "Finish the vow. A recitation held six hundred years deserves speakers,
  not creditors — learn it whole and hand it on." → **+6**
  `ch13_finishes_the_vow`
- "HOLD THE NAME. UNSHARED, IT IS THE ONLY COLLATERAL A TALKING GOD
  RESPECTS — AND I WOULD RESPECT IT TOO. I WOULD HAVE NO CHOICE." →
  **−6** `ch13_holds_the_leash`
- "Words are ordnance here. Learn what the fight needs, spend it on the
  fight, archive nothing." → **0** `ch13_spends_the_word`

**Paladin — sentence as sentence.** Plate: a storm-word blazing across
the plain in letters taller than a man — and the paladin planted inside
the telegraph line, reading it to the end instead of dodging.
- n3: "The chain has waited two acts for this pun to stop being one: the
  seal is a SENTENCE, imposed and served, and the prisoner has learned
  the law. Every storm-word on the plain is case citation. The god is
  filing motions in weather. And the awful thing — the thing you'd never
  say at a bench — is that some of its arguments are GOOD."
- "Good arguments deserve a real hearing: finish the vow, learn the name,
  and retry the case with the sentence INTACT." → **+6**
  `ch13_finishes_the_vow`
- "HOLD THE NAME. LEVERAGE OVER PRISONER AND COURT ALIKE — A JUDGE WHO
  OWNS THE SENTENCE ANSWERS TO NEITHER. NOT EVEN TO ME." → **−6**
  `ch13_holds_the_leash`
- "Motion denied, recitation cited, next case. Spend the words where the
  fight needs them." → **0** `ch13_spends_the_word`

**Mage — the dangerous curriculum.** Plate: a storm-word telegraphed
across the ground, and the mage mid-dodge — reading it on the way past.
- n3: "Every incantation you have ever fumbled descends from THIS:
  language that does not describe the world but INSTRUCTS it. The
  storm-words are syntax you can dodge and read in the same breath — the
  most dangerous curriculum ever offered, tuition payable in silence. You
  have been sounding them out since the scar came into view. Of course
  you have."
- "Learn the whole sentence and speak it as MEANT — the first perfect
  work of your life, borrowed from six hundred years of imperfect
  mouths." → **+6** `ch13_finishes_the_vow`
- "KEEP THE GRAMMAR. A NAME THAT INSTRUCTS THE WORLD, HELD PRIVATELY.
  THE BOY'S MARK IS ALSO, TECHNICALLY, AN INSTRUCTION — AND INSTRUCTIONS
  CAN BE REVOKED." → **−6** `ch13_holds_the_leash`
- "Read only what dodging requires. Some curricula are priced to ruin the
  scholar." → **0** `ch13_spends_the_word`

**Warrior — the blackout with a diploma.** Plate: a spoken shockwave
reshaping the plain — force with a vocabulary — and the warrior braced in
it, listening despite himself.
- n3: "The storm speaks and things BREAK — force with a vocabulary,
  damage that MEANS. It is your blackout with a diploma, and it is
  winning arguments against three old men and an anchor line. You have
  spent your life wishing the arm could explain itself. Here is what the
  explanation costs."
- "Finish the vow. If force can learn to speak, it can learn to stop
  mid-sentence — hold the line and learn the words that hold." → **+6**
  `ch13_finishes_the_vow`
- "TAKE DICTATION. LET THE STORM TEACH ME GRAMMAR — IF I COULD SPEAK,
  YOU COULD FINALLY NEGOTIATE. WOULDN'T YOU LIKE TERMS?" → **−6**
  `ch13_holds_the_leash`
- "The arm doesn't need a thesaurus. Spend the words on the fight and
  keep your own silence." → **0** `ch13_spends_the_word`

**Archer — the loose strands.** Plate: a glowing word-strand drifting
past the archer's face at the anchor camp, close as a mosquito — her
lips pressed shut against it.
- n3: "Three speakers left of a six-hundred-year thread, holding a tear
  the size of the sky. You watched this line from the Summit Camp once
  and called it the longest thread you'd ever seen. It is shorter
  now. Every word you dodge on the plain is a strand of it, blown loose,
  looking for a mouth to land in."
- "Catch the strands. Learn the words as they were tied and splice the
  line back to strength — a thread of breath deserves one archer who
  holds." → **+6** `ch13_finishes_the_vow`
- "GATHER THE STRANDS PRIVATELY. WHO WINDS THE LOOSE LINE HOLDS EVERY
  MOUTH THAT EVER LEANED ON IT. YOU HAVE ALWAYS WANTED A THREAD THAT
  CANNOT BE CUT." → **−6** `ch13_holds_the_leash`
- "Field-strip the language: the words that win the fight, nothing more.
  Lines this old make poor slings." → **0** `ch13_spends_the_word`

**Assassin — stealing a name.** Plate: a single storm-word caught
mid-air in the assassin's hand like a lifted purse — glowing between the
fingers, half-swallowed already.
- n3: "The heist of the age is lying scattered on a battlefield: a god's
  TRUE NAME, blown loose one word at a time, guarded only by weather.
  Take it and you own the leash on the loudest thing alive. Your Ember
  has already started collecting — you caught yourself mouthing a word
  you never chose to learn. It went down warm. Like the flask did."
- "Steal it FOR them. Assemble the name and hand it to the speakers
  whole — the one theft in your life with a return address." → **+6**
  `ch13_finishes_the_vow`
- "FINDERS KEEPERS. A LEASH ON A GOD, HELD QUIETLY — THE FIRST THING I
  EVER TOOK THAT COULD TAKE BACK. LET ME HAVE IT. LET US HAVE IT." →
  **−6** `ch13_holds_the_leash`
- "Spend the words in the fight, then burn your notes. Some loot marks
  its taker." → **0** `ch13_spends_the_word`

**Echo:** briefing NPC = the senior surviving Stormwarden speaker.
`ch13_holds_the_leash` maps onto the bible's hoard-as-leverage true-name
outcome; `ch13_finishes_the_vow` onto share-freely — the opener seeds the
True Name choice without pre-empting it.

---

### ch14 — The Hollow Crown (Act 2 finale)

**Logline:** the Hollow Flame walks, every banner converges, and the
game's first image comes back wrong.

**Shared spine** *(cues `convergence`, then `crown_hollow` on n2)*
- `opening_ch14_0` — the old capital under a sky of ALL weathers at
  once — snow into ashfall into green rain, the Waking smearing reality
  by district.
- `opening_ch14_1` — Mórwyn on the causeway: walking, unhurried, blight
  blooming in her footprints like a bridal train; both armies' lines
  parting BEFORE she reaches them — and at the causeway's foot, small in
  the foreground, a girl of fifteen standing her ground to watch her
  mother's gait go by. Elara: the chapter's asker, in the frame (owner
  call 2026-07-30).
- `opening_ch14_2` *(shared third plate — the rhyme)* — the Hollow
  Throne, composed as an exact match of the game-opening `crown` plate:
  same angle, same framing, the crown's silhouette now hollow and burning
  green. The first image of the game, returned wrong.
- n1 — "Every seal you have touched, every vessel you have freed or
  felled, has led here: the old capital, under a sky that cannot decide
  what season it is breaking. The Waking has stopped creeping. It is
  CONVERGING. Mórwyn walks the causeway at the pace of someone who has
  already won, and the armies part for her. Nobody orders them to."
- n2 *(crown_hollow)* — "You have seen this throne before — in the first
  breath of your story, when the crown was stolen and the world went
  quiet. Here it is again. The crown it wants is hollow now. And
  somewhere inside the god walking toward it, a blacksmith who loved
  perfect work is still holding a hammer she cannot put down. You know
  her forge. It is the one that burned behind a barefoot girl on her way
  into the ice — the Queen took the daughter; the Flame took the mother.
  Two god-kings, one family's grief. You are the only one on this field
  who has met both halves."

**The asker (n4)** — Elara, at the causeway's foot, awake and steady and
fifteen: "That is my mother's walk it is wearing. When you reach the
throne — what did you come for?" *(Realizes the approved Elara–Mórwyn
wiring; if the owner prefers Maren keeps the bookend, Maren asks and
Elara stands beside her.)*

**Mage — the marquee mirror.** Plate: Mórwyn and the mage facing across
the causeway; between them, small, two identical green lights — hers old,
yours young.
- n3: "'You know exactly what I mean, spellwright.' She hasn't said it
  yet — she will — and the terrible thing is she's right. Battle-healer.
  Perfect work. A green yes that didn't finish its sentence. Mórwyn is
  your art's founding error walking to collect its throne, and every step
  of her causeway is paved with your own reasons."
- "Come for the blacksmith inside her — the one who loved the work before
  the work loved back. Someone should reach the forge-memory FIRST." →
  **+8** `ch14_remembers_forge`
- "The crown answers your open promise: undoing at LAST, at scale, WORN.
  The Ember has held your candidacy under your tongue since the
  sickbed." → **−8** `ch14_eyes_the_crown`
- "No more perfect work — hers or anyone's. Break her, break the throne.
  CROWNLESS." → **0** `ch14_no_crowns`

**Warrior — the fitted crown.** Plate: the warrior's reflection in a
blade — and the reflection wearing something the warrior isn't.
- n3: "Something has been trying you on for years — that is what the
  blackout is, on its worst nights: a fitting. You never let yourself
  finish the thought of what FOR. Now you watch the armies part for
  Mórwyn without an order given, and you finally recognize the gait.
  That is a body being WORN WELL. That is the finished version of your
  bad nights."
- "Come for the wearer, not the worn. Somewhere in there is a smith who
  never asked — swing for HER captor, and remember every second of it." →
  **+8** `ch14_remembers_forge`
- "Stop resisting the fit. The crown wants a body that can carry it, and
  the blackout has been TAILORING you for years." → **−8**
  `ch14_eyes_the_crown`
- "Nothing gets worn again. Her, the throne, the fitting-room.
  CROWNLESS." → **0** `ch14_no_crowns`

**Archer — the last thread.** Plate: Mórwyn on the causeway trailing one
thread — thin as smoke, running backward through six hundred years to a
forge that isn't there.
- n3: "Even from the causeway you can see it: one thread left on her,
  running back through six centuries to a forge that no longer exists.
  Everything else the god burned through. It is the last thread in
  Vaelscar you have any business cutting — and the only one that, cut,
  sets a dead woman free."
- "Follow it in. Reach the forge-end of her before the god does, and hold
  it taut so she can find her way back down it — once, at the end." →
  **+8** `ch14_remembers_forge`
- "A thread that old, into a power that vast — take the smoke-thin end
  and you hold HER. The crown always needs a falconer." → **−8**
  `ch14_eyes_the_crown`
- "Cut it, and every thread like it. No crowns, no tethers, nothing left
  for gods to climb down. CROWNLESS." → **0** `ch14_no_crowns`

**Assassin — the career criminal.** Plate: Mórwyn's silhouette rendered
as six hundred years of takings compounded — and visible at the core of
it, small, the first victim.
- n3: "Six hundred years ago something did to Mórwyn what your Ember does
  retail: took a person and kept the receipts. What walks the causeway is
  the takings, compounded past humanity, coming to collect the crown —
  the final acquisition. You have been small-time your whole cursed life.
  Here is the career criminal. And under all of it, the first victim."
- "Come for the victim. Whatever the god kept of the blacksmith, steal it
  BACK — the one heist your Ember was born for." → **+8**
  `ch14_remembers_forge`
- "Inherit the estate. Kill the holder at the moment of transfer, and the
  crown's portfolio looks for a hand already shaped by taking." → **−8**
  `ch14_eyes_the_crown`
- "Burn the vault. Her, the throne, the ledgers of every crown.
  CROWNLESS." → **0** `ch14_no_crowns`

**Paladin — counsel rests.** Plate: the paladin on the causeway, and for
the first time in any plate, the chain drawn SLACK — coiled, silent,
watching.
- n3: "The chain has argued every verdict of your life — and on the
  causeway it falls SILENT, the silence of counsel resting. This is the
  case it was forged for. Mórwyn is defendant, victim, and precedent in
  one body; the crown behind her is the court that corrupted the law
  itself. Whatever you rule at the throne, you rule alone. It is, at
  last, watching its arbiter."
- "Find for the victim. The blacksmith gets remembered into the record
  before any sentence touches the god." → **+8** `ch14_remembers_forge`
- "Claim the bench ENTIRE. A crown is only a gavel that stopped
  pretending — and no one alive is better qualified to hold it." → **−8**
  `ch14_eyes_the_crown`
- "Dissolve the court. Break her, break the throne — no gavels, no
  crowns. CROWNLESS." → **0** `ch14_no_crowns`

**Warlock — the final settlement.** Plate: the tome open to its FIRST
page — the one that rewrote itself in the warlock's hand — and the ink,
on the causeway, beginning to move again.
- n3: "The tome has gone reverent, which is worse than afraid. Mórwyn is
  the oldest open position in the world — six hundred years compounding,
  walking to the throne to close itself out. And your own unnamed debt,
  the thing you traded and never lost YET? On the causeway, for the first
  time, the tome offers to TELL you. Free. Which means the price is
  ahead."
- "Refuse the reveal one last time and come for the blacksmith — some
  debts end by remembering the debtor, not the amount." → **+8**
  `ch14_remembers_forge`
- "Hear it at the throne, where all instruments settle. The crown clears
  EVERY ledger — hers, yours — for the one who wears it." → **−8**
  `ch14_eyes_the_crown`
- "Default the whole system. Her, the throne, the tome's entire market.
  CROWNLESS." → **0** `ch14_no_crowns`

**Echo:** Maren, if she stands at the muster — she opened Act 1 and
Act 2; she should open the finale. **Payoffs:** `ch14_remembers_forge`
earns the Phase 4 "I remember the forge" line as a CALLBACK instead of a
surprise; `ch14_eyes_the_crown` is exactly the loud, diegetic signposting
the Hollow ending demands (DESIGN.md — never a surprise at hour 40);
`ch14_no_crowns` is the title thesis said out loud, once, by the player.
With the Elara wiring in n2 (owner-approved 2026-07-29), the build may
also seat ELARA at the ch14 muster — awake since the ch10 finale — as
the strongest possible read-back for `ch14_remembers_forge`: the
daughter watching you decide what her mother's face is worth.

---

## 4. Resonance budget (the honest math)

One-time sources, cap ±100. Current mainline maximum (all-virtue play):
class opener +12, briefings ch2..ch7 = 4+8+6+6+6+8 → **+50** before side
content. Openers add +6 × 6 (Act 1) = +36 → ~86 by the ch7 finale; Act 2
openers add +44 (6×6 + 8) on top of whatever ch8–ch14 briefings bring —
committed play saturates the band well before the ch14 finale.

That is a *feature* under current design ("staying undecided is the only
way to get nothing" — the leans scale with |res| and full conviction =
full lean), but it does move saturation earlier. If the owner wants slower
saturation, the knob is the opener size (±6 → ±4), not fewer choices.
Class-refraction does NOT change this math — six voicings, one flag, one
shift per chapter.

---

## 5. Implementation notes (for whichever agent builds it)

- **Convos:** six per chapter — `chN_opening_<class>`, ch1-style — in the
  chapter's content module (`chN_zones.gd` / `ch2_hub.gd`), one CONVOS
  merge, no shared-file edits beyond the trigger. Shared spine nodes are
  duplicated verbatim per class convo (the ch1 openers duplicate the
  `crown` node the same way). Autotest gains the pairing invariant: every
  chapter with openers has all six (mirrors `autotest.gd:1770`).
- **Trigger:** in `advance_chapter()` (`game_flow.gd:132-165`), after
  `switch_chapter()`: if `Story.ALL_CONVOS.has(cid + "_opening_" +
  player.cls)` and persistent flag `saw_<cid>_opening` is unset → set it,
  build the `Cutscene` layer, run the convo, and move
  `hud.flash_title(...)` into the finish callback. Extract the four
  Cutscene-creation lines from `game.gd:385-388` into a shared helper
  (e.g. `game_base.run_cinematic_convo`). Chapter select / NG+: the
  `saw_` flag is per character — openers never replay; new characters see
  everything.
- **Cues:** per chapter, one shared cue (spine plates) + six class-turn
  cues (`vale_warrior`, `vale_mage`, …) in `Cutscene.FRAME_SEQUENCES` +
  `KNOWN_CUES`; ch14 adds the shared `crown_hollow`. Cues and frames must
  land together (autotest validates convo cues against `KNOWN_CUES`).
- **Conditional spine beat (ch9):** node `variants` currently select TEXT
  only. Extend variant resolution to also carry a `"cue"` override (one
  line where `game_base.gd:1657` resolves the cue) — ch9's Kaethra fates
  want different framing, and any future fate-dependent opener will too.
- **Flag persistence:** opener stance flags must survive
  `_wipe_chapter_flags()` (`game_flow.gd:151`) — cross-chapter callbacks
  like `chose_varo_mercy` already do, so follow whatever convention
  protects those; verify at build time. This is the one landmine the
  exploration pass flagged.
- **Co-op:** the tree pause NO-OPS online (§5.4) and dialogue already
  runs un-paused per player. Proposed default: the opener plays
  per-client for players entering the chapter for the first time; the
  world keeps running; input gating rides the existing overlay-state
  guards (`hud.dialogue_active`). Alternative: co-op sessions skip
  cinematics entirely — owner call (§6).
- **Art:** 2 shared + 6 class plates = 8 per chapter, ×13 chapters =
  **104 plates + ch14's shared third = 105** (Act 1: 48 now; Act 2: 57
  pre-wired for the chapter builds). The ch1 opening set already establishes
  hero-identity painted plates, so the class plates have precedent and a
  style anchor. Default generation lane (ChatGPT per `ART_PROMPTS.md`) —
  **PixelLab only with explicit owner authorization, per standing rule.**
  Author display-referred sRGB like the existing opening set; the
  cutscene's shader does the linear-space lift, no pre-brightening. The
  ch14 `crown_hollow` plate must be generated FROM the original
  `opening_crown_0` composition (same angle/framing) or the rhyme dies.
- **Replies:** each choice gets a short reply node (ch1-style) drafted at
  build — the choices above fix the stance; the replies are performance.
- **Codex:** no codex surface — openers are story delivery, not reference
  content (checked against the codex-staleness rule).
- **Briefing trim:** owner-approved 2026-07-29 — spec in §7. Lands in the
  SAME change as the Act 1 openers, never before: until openers exist,
  the briefings are the only exposition delivery.
- **Mobile:** rides the standard sync ritual.

## 6. Open questions for the owner

1. **Co-op behavior** — play per-client on first entry (proposed) or skip
   cinematics in sessions entirely?
2. **Opener resonance size** — ±6 as proposed, or ±4 if earlier band
   saturation (§4) feels too fast?
3. **Install order** — the art bill is 48 plates for Act 1. Pilot
   ONE chapter across all six classes first (ch3 is the strongest
   standalone), then batch the rest? Or all six chapters in one pass?
4. **ch14's third option** — "CROWNLESS" says the title out loud, in all
   six voices. Keep, or too on-the-nose?

---

## 7. Briefing trim spec (owner-approved 2026-07-29)

The openers now own the neutral world-exposition each briefing was
written to deliver first. When the Act 1 openers land, the briefings get
a LIGHT trim in the same change — final copy is the build's, but this
spec fixes what each NPC loses and keeps so the trim never guts a
character.

**The rule:** the NPC keeps everything PERSONAL (their stake and story),
TACTICAL (targets, obstacles, the quest hand-off), and OPINIONATED
(their read on what you both just saw). They lose only the neutral
world-recap — compressed into a one-line acknowledgment that the player
has SEEN it, which turns exposition into rapport. `b1` flag-variant
greetings and `b3` choices are untouched everywhere; only the `b2`
world-recap sentences compress.

- **ch2 `ch2_maren_hub` m2** — trim: the years-since-the-fall /
  world-is-waking recap. Keep: her mission (finding the woken before the
  factions do), the factions-want-leashes warning (the opener does not
  cover factions), the ask east. Shape: "You've seen the road in — the
  Waking isn't a rumor, it's a season. What you haven't seen is what
  circles the newly-woken…"
- **ch3 `ch3_briefing` b2 (Cantor Ilse)** — trim: the
  no-burials/sixty-years/walking-funeral premise. Keep: her defection
  story (the furniture vote), the three obstacles (Sexton, Vess, Varo),
  and her "begging to die longer than you've been alive" line. Shape:
  "You walked the grave-road in; I'll spare you the liturgy of it."
- **ch4 `ch4_briefing` b2 (Overseer Brann)** — trim: the
  reopening/ore-vein/unexplained-heats recap. Keep: his personal stake
  (he signed Ordo's requisitions), Cinderhide's four crews, the three
  targets by depth, and his "sermons with verdicts" line. Shape: straight
  from "my problems are now arriving FASTER" to the target list.
- **ch5 `ch5_briefing` b2 (Tracker Yri)** — trim: the
  sledges/grain-toll mechanics recap. Keep: the thesis ("nobody out
  there is evil"), the marrow-in-children's-bones line, the Whitepelt
  brief. Shape: "You've seen the sledges. Now hear the part that makes
  it hard…"
- **ch6 `ch6_briefing` b2 (Deacon Vela)** — trim: the
  creed-meets-its-opposite recap. Keep: her count-keeper identity, the
  three obstacles (Auroch, Rotmaw, Kaethra), the "when Wildfang camps
  agree" line. Shape: "You've seen it. I won't preach what it does to
  the preaching."
- **ch7 `ch7_briefing` m2 (Maren)** — trim: the
  sentence-not-stone/relay mechanics recap. Keep: the four-seals-strained
  ledger (Serane's warning), the summit-is-theater line, and the whole
  no-win framing ("no road out of this chapter where the sky holds").
  Shape: "You've seen what holds the sky now. Here is what I couldn't
  put in a letter…"
