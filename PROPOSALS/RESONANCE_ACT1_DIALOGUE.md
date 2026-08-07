# Resonance Game — Act 1 "The Waking of Dunmere": skeleton + dialogue (v2 — class-voice pass landed, §11)

**Status: proposal. Nothing installed.** This is the §11.4 deliverable from
`PORTFOLIO_AND_SHOT1_RESONANCE.md` — the string-of-pearls skeleton for the
resonance game's Act 1, with the dialogue authored, not described. Strategy,
cost model, and streamability rules live in the portfolio doc and are not
repeated here; this doc cites them by section where a line exists because of
one.

Working title used throughout: **HEARTH** (placeholder — owner's call).
Same Emberfall universe as Crownless, ~same present (the Waking spreading,
Maren's Accord gathering the woken), different corner of the map, standalone
story. A stranger who never heard of Crownless loses nothing.

Pipeline intent: this doc is written to be generator-consumable the way
`CHAPTER_OPENERS.md` fed `gen_chapter_openers.py` — every scene is tagged
with its node id, flags, and deltas. A new generator gets written at build
time; the conventions here are its spec.

---

## 1. Premise & the legible hook

**You are not a wandering hero. You are the town's own.** Dunmere is a
lakeside valley town of maybe two hundred people, and every one of them has
known you since before you could swim. Then the Waking reaches the valley,
a shard roots in you, and the people watching you become something are not
strangers — they are your brother, your aunt, your best friend, the woman
who taught you to gut fish. The drama engine is that **reactivity reads as
personal history**, not faction math.

**The 5-second hook (portfolio §3a.1, sound off):** the shard marks you
visibly. The mark — an ember-line up the neck, into the eye — runs **golden**
in the steady bands and **ink** in the tempted bands, and the sprite tint
shifts with it. A muted clip shows a marked figure walking a town street
while doors close, or while dogs trail them like a procession. The state of
the run is legible from the thumbnail. This is the iconic visual.

**Both poles cost (canon: resonance is not good/evil).** Deep ink: doors
bar, prices climb, dogs growl, Fenn's sermons find an audience. High gold:
the town makes you a saint — they bring you their sick, their disputes,
their drowned nets, and they do not ask so much as expect. The dial is
"how do you relate to the power," and Dunmere punishes both answers.

**Streamability mapping (portfolio §3a, point by point):**
1. *5s legibility* — the mark + the dogs + the doors.
2. *Clippable moments* — the Jorin scene (§5.4), the vote (§7).
3. *Chat backseats* — every stance choice has three options with teeth
   (no throwaway "good" pick; see the no-false-promises rule below).
4. *Tune-in-anytime* — pearls are session-sized, self-contained arcs.
5. *Variance* — band + flags make two streamers' Dunmeres visibly differ
   at the ecosystem level (portfolio §6 cross-stream aggregation).
6. *Thumbnail identity* — the marked hero, golden or ink.

**Grammar carried over from the chapter-openers doc (proven, reuse):**
choices are stances, never plot forks ("the plot never branches; the
person does" — until a PIVOT, where it does, once, then reconverges);
the question comes from a person in the scene, never from the power
polling you; every option resolves or is a stance on HOW, never a lying
WHETHER; every flag gets an echo within minutes.

**The protagonist is ONE fixed person; class is a combat/temperament
skin, not a gender (ruling, 2026-08-04).** HEARTH's PC is Col's older
sibling and Tilda's kin — a specific person from a specific town, which
is what makes the family drama load-bear. Class does NOT carry gender
here (unlike Crownless's per-class canon), and the shared NPC lines are
written **gender-neutral** (Tilda "both my own," "my own blood"; Ede
"that neck"; Hale "the face across from me") so every player projects
onto the role while the aunt/brother/best-friend structure stays intact.
No PC-gendered pronoun appears anywhere in the spine or the class-voice
pass.

**Class refraction ships in v1 (owner call, 2026-08-04).** The six
classes exist (combat core is Crownless's), but this game's PC has ONE
canonical wound — the ferry — so the Crownless ch1 wound table does not
apply. The refraction axis here is **temperament, refracting the shared
wound** (warrior blunt, assassin guarded, mage precise, archer distant,
paladin dutiful, warlock transactional). Scope of the six-voice
treatment:
- **P1 gets a class turn** (one beat between n3 and n4 — the freezing of
  the lake felt through that temperament) and **class-voiced stance
  options**.
- **All four stance choices** (P1 Hale, P2 Jorin, P2 Fenn, P3 bell) get
  class-voiced options — same flags, same deltas, six REASONS per
  stance; the openers-doc discipline applies verbatim (no two classes
  share a rationale or a tagline).
- Spine narration, NPC lines, and the whole tint layer stay
  class-agnostic — the world doesn't change; the person does.
- The 6×-voiced option sets + P1 class turns are **authored — §11**;
  the class-agnostic options in §§4–6 stand as the *shared-meaning
  spec* each voicing maps to.

---

## 2. Cast (small, load-bearing; every NPC is also a band instrument)

| NPC | Who they are to you | What they measure |
|---|---|---|
| **Col** | Your younger brother. Forge apprentice. Was on the ferry. | Unconditional love — the control group. The last door that never bars. |
| **Jorin** | Your best friend and lifelong rival. Pulled from the water when the lake froze; the ice took his right hand. | The cost of your power, wearing a face. The Act 1 pivot hinges on him. |
| **Tilda** | Your aunt. Runs the inn and the ferry concession. Raised you both after the fever year. | The town's pragmatic middle — her greetings are the band barometer (§8.1). |
| **Reeve Hale** | The town's elected law. Owes Tilda money, owes nobody else anything. | Institutional trust; source of steady-gated content. |
| **Bell-keeper Fenn** | Keeps the lake shrine and the town bell. Lost his wife to the water years ago. | Fear looking for a liturgy. The Hollow Choir seed — his arc curdles across acts. |
| **Gammer Ede** | Ancient neighbor. Outlived three reeves and intends to outlive Hale. | The humor lever (portfolio §6): treats your terror-power as a chore tool. Her arc IS the acquisition-humor budget, and it pays off at the vote. |
| **Corb** | Runs freight nobody taxes. Friendly like a knife is friendly. | Source of tempted-gated content. |
| **Pillo** | Itinerant peddler, quarter-yearly regular. Sells remedies that don't work. | Ambient humor + a walking price-tint gauge (§8.3). |
| **The rider** (end of act) | An Ember Accord watcher with Maren's letter. | The universe hook, kept light (portfolio §1: stand-alone first). |

Name-collision check done against the Crownless roster (Maren, Aldric,
Bren, Ren, Osric, Morwen, Vess): clear.

---

## 3. Act 1 topology (the string of pearls)

Four pearls. Small ± deltas throughout (the tint economy), ONE pivot at
the act's end (portfolio §4: pivots are rare, hand-authored, tied to a
specific remembered choice; band amplifies, never substitutes).

```
P1 The Ferry ──► P2 The Quiet Days ──► P3 The Thing in the Lake ──► P4 The Reeve's Question
   (awakening)      (town negotiates      (combat spine +               (PIVOT 1: the vote —
    stance ±6        you; JORIN ±8;        bell choice ±6)               3 verdicts, keyed to
    choice)          gated offers ±4)                                    the Jorin flag,
                                                                        band-amplified)
                                                        └──► all three verdicts reconverge:
                                                             Act 2 opens on the road out of
                                                             Dunmere; the verdict rides as flags
```

**Delta ledger (Act 1 reachable swing ≈ ±41):**

| Beat | Delta | Flags |
|---|---|---|
| P1 stance (Hale's question) | +6 / −6 / 0 | `a1_stance_steady` / `a1_stance_pride` / `a1_stance_rope` |
| P2 Jorin (the flagship) | +8 / −8 / 0 | `a1_jorin_asked` / `a1_jorin_forced` / `a1_jorin_silent` |
| P2 Fenn's blessing | +4 / −4 / 0 | `a1_fenn_stood` / `a1_fenn_scorned` / `a1_fenn_slipped` |
| P2 gated: Hale's deputizing (band ≥ +10) | +4 | `a1_deputy` |
| P2 gated: Corb's night ferry (band ≤ −10) | −4 | `a1_night_ferry` |
| P2–P4 Ede's chores (recurring ×3) | +1 each | `a1_ede_chores` (counter 0–3) |
| P3 the Sunken Bell | +6 / −6 / 0 | `a1_bell_broken` / `a1_bell_taken` / `a1_bell_bound` |
| P4 verdict (outcome, not a choice) | +5 / −5 / 0 | `a1_verdict_ward` / `a1_verdict_walk` / `a1_verdict_watched` |

**Pivot thresholds are authored per pivot, not the ±50 band walls** — the
±50 bands govern tint and the endings (portfolio §4); P4 reads terciles of
the Act-1-reachable range: steady ≥ +18, tempted ≤ −18, balanced between.

**Reconvergence (the load-bearing rule, portfolio §5):** all three P4
verdicts end with you on the east road at dawn with the rider's letter.
What differs is *what Dunmere now is* — a home that will take you back, a
probation, or a barred gate — carried entirely as flags + tint, costing
zero extra scenes in Act 2 except authored echo lines. Permanent
divergence is saved for the endings.

**Endings plant (game-level, for later docs):** the three endings read
final band lane + the pivot flags (`a1_jorin_*` is ending-relevant; the
vote verdict is not — it is Dunmere's opinion, and Dunmere's opinion gets
one more scene in Act 3, not an ending).

---

## 4. Pearl 1 — "The Ferry" (the awakening)

Cutscene grammar per the openers doc: plates + narration beats + one
choice + echo. Class-agnostic (the class turn is spent at pivots in this
game). Plates: `hearth_a1p1_0..3`.

**n1 (establish — warm; the humor budget starts here):**
> Dunmere has one bell, one ferry, and one story worth telling, and you
> have heard it told wrong in both inns. The story is about the bell that
> sank in your great-grandmother's day. They say it rings under the mere
> before a drowning. They say a lot of things in Dunmere; the lake says
> nothing, and everyone crosses it anyway.

**n2 (incident):**
> The autumn crossing. Wind off the fells like a slammed door. Mid-lake,
> the ferry rope parts — you hear it go, a sound like a knuckle cracking,
> and the water stands up. Col is aboard. Your brother is aboard, and the
> boat goes sideways, and the whole town is on the shore doing what towns
> do: shouting the water into behaving. It doesn't.
>
> Under the mere — and you will swear to this later, to anyone, to no one —
> something rings.

**n3 (the waking — the power acts through you):**
> The shard does not ask. Heat climbs your neck like a swallowed coal and
> the world goes quiet and specific: the rope, the boat, the eleven people
> on it, your brother's coat. You reach — not with your hands.
>
> The lake obeys. That is the only way to say it. From the shore to the
> ferry the water stops being water, and eleven people are standing on ice
> in a silence like the inside of the bell.

**n4 (consequence — someone looks at you differently):**
> Jorin was in the water. He'd gone in off the jetty with a line before
> anyone thought to stop him — of course he had — and the ice took the
> lake and everything in it, and it took his right hand to the wrist.
> They chop him free with hatchets. He does not scream until the fire
> thaws him, and then you learn what your name sounds like screamed.
>
> Twelve saved, they will say. Count again.

**The choice (asker: Reeve Hale, on the shore, per the ask-from-the-world
rule).** Plate: Hale between you and the fires, not touching his stave.

> **HALE:** Look at me. Not at them — at me. Whatever that was, it wore
> you like a glove. So you'll answer me one, here, while the ice is still
> on the lake: what did I just watch?

- **[+6, `a1_stance_steady`]** "Something woke in me and I don't know its
  name yet. I will. Before it learns mine."
  — **HALE (reply):** "That's the first honest thing said on this shore
  tonight. Learn fast." *(He turns his back on you to organize the
  stretchers — deliberate, visible: turning his back is the trust.)*
- **[−6, `a1_stance_pride`]** "You watched a rope break and nobody drown.
  Twelve people, Hale. Whatever it costs, I'd pay it again."
  — **HALE (reply):** "Eleven were on the boat." *(Beat.)* "Mind which
  half of that sentence you fall in love with." *(He does not turn his
  back.)*
- **[0, `a1_stance_rope`]** "The rope broke. That's all I know for
  certain, and I mean to keep to what's certain."
  — **HALE (reply):** "The rope broke." *(He looks at the frozen lake,
  all the way across, and lets it sit.)* "Get inside, then. Certainty's
  cold work."

**The echo (Tilda, at the inn, same night — flag read-back within
minutes, per the grammar):**
- `a1_stance_steady`: "Hale says you spoke like a carpenter measuring a
  beam. Good. Your bed's where it's always been. Both my own came home
  tonight — the rest is carpentry."
- `a1_stance_pride`: "Hale says you'd pay it again. I've heard men say
  that about drink, about debt, and once about a woman, and it always
  meant the price already had its hooks in. Bed. Now."
- `a1_stance_rope`: "'The rope broke.' Aye. And my kettle boiled itself.
  You'll talk when you talk — but eat, or the town'll say the shard did
  that too."

**The mark:** it appears in n3 and is on you at the fires — Pearl 1 ends
with Col reaching to touch your neck and stopping an inch short.
No dialogue; the plate carries it.

---

## 5. Pearl 2 — "The Quiet Days" (the town negotiates what you are)

Hub pearl. Errand-and-visit structure; every scene below is a discrete
convo node keyed on flags/band. This pearl carries the tint showcase
(§8) and the flagship choice.

### 5.1 The Ede bit (recurring humor; +1 each; `a1_ede_chores` 0–3)

The rule that makes it land (portfolio §6: humor as shareability): **Ede
is never afraid, never impressed, and escalates.** The terror-power as a
chore tool.

**Chore 1 (day one, over her fence):**
> **EDE:** You froze half a lake, I hear. Half a LAKE. Well — my pond's
> full of weed and my back's a hundred and six. Do the pond. Not frozen,
> mind. Just tidy.
- *(do it: +1. The pond is comically small. The shard, primed for
  catastrophe, tidies weed. If declined she just says:)* "Suit yourself.
  The weed's patient and so am I."

**Chore 2 (mid-pearl, after whichever Jorin outcome):**
> **EDE:** Whatever it is you did or didn't do to the Aldwin boy's hand,
> the whole street's chewing it. My cellar's the other business — frost
> got in and my roots'll turn. You're frost's own cousin now, I'm told.
> Have a word with it.
- *(do it: +1. She pays you in pickled beets, ceremonially, coin-style.)*

**Chore 3 (during P4, morning of the vote — timing is the joke and the
knife):**
> **EDE:** Big day. Whole town deciding what you are. I already know what
> you are — you're the one who does my pond. Wolves have been at the goat
> fence. See to it before the hall fills. A body votes better on a safe
> goat.
- *(do it: +1. It matters at the vote — §7.3.)*

### 5.2 Fenn's blessing (±4)

At the lake shrine. Fenn has rung the bell for the dead for thirty years
and the lake gave him back a frozen miracle and a maimed young man, and
he does not know which offends him more.

> **FENN:** The shrine takes all comers — that's the rule and I keep it.
> So come, if you're coming. There's a blessing said over the woken, or
> so the pamphlets from downvalley claim. I'll say the words if you'll
> kneel for them. *(quieter)* Kneel, and let the town see the fire bend
> its head. That's what I'm asking, and I'm not pretending it's less.

- **[+4, `a1_fenn_stood`]** Kneel. — **FENN:** "…Well. It kneels." *(His
  hands shake through the blessing; he means every word and is furious
  that he's grateful.)*
- **[−4, `a1_fenn_scorned`]** "Your bell rang before the rope broke,
  Fenn. I heard it under the mere. Bless THAT." — **FENN:** *(long
  silence)* "Get out of my shrine." *(First brick of the Choir road —
  you handed him a theology.)*
- **[0, `a1_fenn_slipped`]** "Another day, keeper." — **FENN:** "Aye.
  There's always another day. Right up until." *(He rings the noon bell
  early, watching you walk off.)*

### 5.3 Gated content (portfolio §6: the highest-ROI reactivity tier —
you SEE the door you can't open)

- **Band ≥ +10 — Hale's deputizing (+4, `a1_deputy`):** a patrol quest
  (the fell road, missing charcoal burners). **HALE:** "I don't hand the
  town's stave to a weather-vane. You've been steady. Walk the fell road
  with me and be seen being useful — half of law is being seen."
  *If under-band, the door stays visible:* **HALE:** "Not yet. Ask me
  when the dogs stop pretending they don't know you."
- **Band ≤ −10 — Corb's night ferry (−4, `a1_night_ferry`):** untaxed
  freight across the frozen margin. **CORB:** "Ice makes roads where
  there weren't any. Roads make money. You made the ice — seems to me
  you're owed a toll, and Hale never has to know the arithmetic."
  *If over-band:* **CORB:** "Nothing for you tonight, saint. Come back
  when your neck's the other color." *(He means the mark. Attribution
  rule: the tint always names its cause — portfolio §6.)*
- **Middle band:** both doors visible, neither open; Tilda mentions each
  offer secondhand at the inn ("Hale asked after you. So did Corb.
  Congratulations — you're a coin now, and both sides want the toss").

### 5.4 THE JORIN SCENE (the flagship; ±8; the pivot's fuel)

This is the scene the game is for — the proof of the whole
choice-drama thesis, and the one to cut a trailer from. Jorin's cottage,
a week after the ferry. The stump is wrapped. He's teaching himself to
tie knots one-handed with a horse-hitch loop on the bedpost, badly, and
he doesn't stop when you come in.

> **JORIN:** They keep coming by with soup. Whole town's got exactly one
> idea of what a missing hand eats, and it's soup. *(beat; he gets the
> knot, loses it)* Say what you're circling.

The shard hums it before you say it — the mend is *in reach*, and the
player has known since the mark first warmed near him. (No system voice,
no CAPS; the power leans, it doesn't poll — openers rule. The HUM is a
UI shimmer on Jorin's wrapped arm, attribution-clean.)

> **YOU:** The thing that froze the lake can finish what it started.
> The hand, Jorin. I can reach it — the shape of it's still… there.
> I'm asking first. It's yours to say.

> **JORIN:** *(he finally stops with the knot)* You're asking. *(laughs,
> once, not kindly)* You know what I did the first morning? Reached for
> the pisspot with a hand that isn't there. Funny thing, reaching. The
> arm still believes in it. *(beat)* No. Not with that. I'd rather learn
> the hook than owe my hand to the thing that took it. …Ask me again in
> ten years. Don't ask me again this year.

**The choice (three, all with teeth — no cost-free option):**

- **[+8, `a1_jorin_asked`] Respect it.**
  > **YOU:** Then that's the whole conversation. Ten years. I'll bring
  > better soup.
  > **JORIN:** You'll bring ale is what you'll bring. *(he goes back to
  > the knot; lands it on the first try, which neither of you mentions)*
  — *Aftermath:* the friendship holds, changed. He is seen at the inn
  teaching Col the one-hand hitch. The town notes that the woken ASKED —
  Tilda's tint lines warm one notch regardless of band.

- **[−8, `a1_jorin_forced`] Do it anyway. He said no.** *(The option
  reads exactly that — informed cruelty, no gotcha; the player is
  surprised by how much it counts, never that it counted.)* He dozes
  before you leave — the poppy draught Tilda measures him. The shard
  reaches on its own gravity and you let it. *(The clip: he wakes with
  a perfect hand and screams worse than the fire-thaw night.)*
  > **JORIN:** What did you— *(he's holding the new hand away from his
  > body like a lantern that might spill)* It's warm. It's WARM and it
  > isn't MINE — I said no. You heard me say it. You were the one person
  > this town would've bet couldn't steal from me, and you stole a YES.
  — *Aftermath:* he ties nothing to the bedpost anymore; works the
  forge twice as hard with a hand he refuses to look at; will not sit
  when you enter the inn. Fenn gains a congregation of one, then five.
  — *Plant (Act 2/3, the lane's own arc — this lock is not a
  dead-end):* the day comes when the hand he refuses to look at is
  what saves Col — and Jorin has to live with it working. "Ask me
  again in ten years" turns ironic, not closed.

- **[0, `a1_jorin_silent`] Never offer.** The scene above doesn't happen;
  instead a quiet visit, soup jokes, the knot. You keep the mend to
  yourself. — *Delayed consequence (fires mid-P3, not silently — the
  no-false-promises rule):* the shard's hum near Jorin is audible to
  Fenn at the shrine, and Fenn — meaning well or worse — tells him.
  > **JORIN:** Fenn says the fire could've reached the hand. Says it
  > hums at me like a kettle. *(beat)* I'd have said no. That's not the
  > wound. The wound is it was mine to say no TO, and you decided in
  > your own head I couldn't be trusted with the question.

### 5.5 Tint showcase — Tilda's greetings (the §8.1 pattern, instanced)

Four tints, per portfolio §4 (two middle tints share a branch). Written
here as the canonical example; the volume pass extends the pattern.

- **Gold (≥ +50):** "There's my miracle. Don't smile — the last time I
  said that word, Widow Ash asked would you bless her hens. I told her
  you charge. Sit; eat; be ordinary in my inn or I'll have Ede invoice
  you."
- **Warm-middle (0..+49):** "Kettle's on. Marta asked after you at
  market — asked *kindly*, mind. Kindly's worth keeping. Sit."
- **Cool-middle (−1..−49):** "Kettle's on. …Corb was in earlier, asking
  after you. I told him my inn doesn't keep accounts on kin. Make that
  stay true."
- **Ink (≤ −50):** "Sit in the back tonight, love. Not for me — for the
  Marsh boys at the bar, who've had four each and one idea between them.
  I'll bring the stew to you. *(quieter)* You'll always eat here. Mind
  that always is a word I've had to defend twice this week."

---

## 6. Pearl 3 — "The Thing in the Lake" (combat spine + the bell)

The Waking arrives properly. Nets come up cut. A charcoal burner's dog
comes home wet and won't stop staring at the water. Then the bell under
the mere starts ringing where everyone can hear it — at first only at
night, then at noon, then in your footsteps.

**The beast:** the SUNKEN BELL is not a monster; it *makes* them. Its
toll wakes the drowned silt — lake-wight packs (combat spine, existing
enemy re-parameterization: drowned skins on wolf/shade AI) — and the
bell's warden-thing, a bellringer of lakeweed and ferry-rope, is the
pearl boss. (Boss design per the standing principle: its toll is an
arena-wide non-opt-in pulse that reaches a kiter; the `dist<X` splash
rings are the opt-in tells.)

**Investigation beats (short, flag-aware — two examples):**
- **FENN** (if `a1_fenn_scorned`): "You told me my bell rang before the
  rope broke. I've thought of little else. If it rings for drownings —
  who is it ringing for NOW, do you think? Count the town and tell me
  who's missing." *(He is exactly right, which is the problem with
  Fenn.)*
- **COL:** "The forge went quiet yesterday. Anvil, bellows, the lot —
  one breath, all of it silent, like the noise was *borrowed*. Master
  says air does that before a storm. It wasn't like weather. It was like
  listening."

**The resolution (at the drowned chapel, the warden down, the bell
exposed and still ringing in the water like a heartbeat; asker: it is
Col who came out on the water with you, because of course he did):**

> **COL:** That's it? That's the story — great-gran's bell? *(the toll
> rolls through the hull; he steadies himself on your shoulder, and he
> is the one person whose hand never hesitates)* It sounds like it's
> asking for something. What do we do with a thing that won't stop
> asking?

- **[+6, `a1_bell_broken`] Break it.**
  > **YOU:** We answer it once, and then never again. Cover your ears.
  — The shard cracks the bell like river ice. The silence afterward is
  total — and it STAYS total: the mere goes quiet-water, and the fish
  leave with the sound. *(Teeth: Dunmere's nets come up light all
  winter. Tilda's ferry concession is suddenly half the town's income.
  This is priced into P4 — Hale cites it.)*
- **[−6, `a1_bell_taken`] Take its voice.** The shard drinks the toll.
  > **COL:** …It's in you now. I can hear it when you breathe.
  — **Gameplay cash (portfolio §4 cheap-reactivity, made loud):** the
  player gains **Knell** — a bell-toll AoE stagger on a long cooldown —
  and with it the STORY SLOT itself unlocks (the special-ability
  system's debut beat; full spec: `SPECIAL_ABILITIES.md`). A story
  choice visibly rewrote the kit; this is the clip that sells the
  whole system. Cost: at ink bands the toll sounds faintly in your
  footsteps town-wide; the dogs (§8.4) are worse; Fenn hears it in the
  shrine like a rival church.
- **[0, `a1_bell_bound`] Sink it deeper.** Rope, stone, the old chapel
  vault, a knot Jorin taught you both. Quiet for now.
  > **COL:** It'll ring again someday. …That's someday's problem?
  > **YOU:** Someday's problem.
  — *Plant (fires in a later act, flagged here so it's never a cheat):
  the bell is a load-bearing IOU, and whoever holds Dunmere then will
  answer it.*

**Echoes, same day:** Ede: "Fish'll be back or they won't. My pond's
still stocked — funny how that happened." / Hale, `a1_bell_broken`:
"You bought quiet with the fishing. I'd have paid the same. Say so at
the vote — that arithmetic is what reeves are FOR." / Fenn,
`a1_bell_taken`: "You didn't silence it. You gave it legs."

---

## 7. Pearl 4 — "The Reeve's Question" (PIVOT 1: the vote)

Dunmere's hall, everyone in it. Hale has called the town to settle,
formally, what you now are to it: **ward** (its own, honored), **watched**
(its own, on terms), or **walked** (not its own). The pivot's engine is
the CASH layer demonstrated end-to-end: **the testimonies are assembled
from the act's flags** — the player watches their whole ledger stand up
and speak, one witness at a time. (Attribution requirement, portfolio
§6: every consequence names its cause out loud.)

### 7.1 Testimony: Jorin (the knife — keyed to the flagship flag)

- **`a1_jorin_asked`:** *(he stands with the hook he's learning, and
  takes his time)* "The lake took my hand because the fire in him moved
  faster than his asking. That's the worst I can say, and I've had a
  season to sharpen it. Here's the other thing. He CAN mend it — did
  you all know that? — and he asked. And when I said no, the asking
  stopped. *(beat)* I've known him since we were six. He's quicker than
  me at everything but one thing now, and the one thing is: he waits.
  Keep him. You're safer with him than I was without him."
- **`a1_jorin_forced`:** *(he stands, and he puts the perfect hand flat
  on the table where the whole hall can see it flex)* "Look how well it
  works. Go on — look. He grew it while I slept, after I told him no.
  Not out of cruelty. Out of certainty. That's my testimony, whole:
  the fire is kind, and it is certain, and it does not believe a no.
  Decide what that makes of a town's worth of noes."
- **`a1_jorin_silent`:** *(the seat is empty; Hale reads a paper)*
  "Jorin Aldwin declines to testify. He asks the hall to note only
  that… *(Hale squints, reads it as written)* 'the question I'd have
  answered was never put.'" *(The hollow one. The hall is quieter after
  this than after either speech.)*

### 7.2 Testimony: the institutions (keyed to §5 flags)

- **Hale** (`a1_deputy`): "Walked the fell road with me. Found the
  burners, carried the small one down alone, took orders the whole
  way — MY orders, which some of you know is the harder miracle."
  / (`a1_night_ferry`, and Hale knows more arithmetic than Corb thinks):
  "I'll say one thing and watch the face across from me while I say it:
  freight moves over ice at night, and ice has an owner now." / (neither): "I've no
  complaint on record. Note that I keep excellent records."
- **Fenn** (`a1_fenn_stood`): "It knelt. I have rung that bell for
  thirty years of drownings and I am telling this hall: it knelt, and
  the words held it, and I do not know if I was glad." /
  (`a1_fenn_scorned`): "It stood in my shrine and preached its own
  gospel back at me. You've all heard the new bell by now. Ask
  yourselves who the congregation is." / (`a1_fenn_slipped`): "It never
  came. Make of a polite absence what you like; I've buried polite."
- **Tilda** (always, band-tinted): "That's my own blood, so discount me
  — and then remember every one of you eats in my inn, and I see who sits
  easy and who sits by the door. *(gold/warm)* You sit easy. Vote like
  it." *(cool/ink)* "Lately you watch the door. Vote for the town you
  want, not the fear you brought in with you."

### 7.3 Testimony: Ede (the humor lever, cashing — this is why the bit
recurs three times)

- **`a1_ede_chores` = 3:** *(she does not stand; standing is for people
  with something to prove)* "Pond's clear. Cellar keeps. Wolves mind
  their manners. A hundred and six years I've watched this town vote on
  fear, and I never once saw fear do my chores. I don't care what color
  that neck's gone. KEEP."
- **= 1–2:** "Did my pond, anyway. Half the men in this hall never did
  that much. Keep, I say — on probation. The goat fence is the
  probation."
- **= 0:** "Never did a thing for me, and I asked NICE. Freeze a lake
  for strangers and won't tidy a pond for a neighbor — that's a
  PERFORMER, and I don't vote for performers." *(Even her scorn is
  charm; but it's a real vote against, and the middle-verdict math can
  swing on it.)*

### 7.4 The verdict (primary key: the Jorin flag; band amplifies;
secondary weights: deputy/ferry, Fenn, Ede count, bell)

- **WARD** (`a1_verdict_ward`, +5) — reachable only with `a1_jorin_asked`
  or (`a1_jorin_silent` + steady tercile + strong secondaries):
  > **HALE:** The hall's answer: Dunmere keeps its own. *(he crosses the
  > hall and hands you the second stave — the deputy's, made permanent)*
  > Ward of Dunmere. It's not a payment. It's a leash we're asking you
  > to hold yourself. You've shown you know how.
- **WATCHED** (`a1_verdict_watched`, 0) — the wide middle:
  > **HALE:** Dunmere keeps its own — with terms. You lodge with kin.
  > You answer a summons. And once a season you sit in this hall and
  > let the town look at you, because looking is how small places stay
  > kind. Don't make me regret the kindness; I regret loudly.
- **WALK** (`a1_verdict_walk`, −5) — `a1_jorin_forced` forces this
  outcome UNLESS gold-band + Ede 3 + `a1_deputy` (the one narrow
  redemption path — even then it lands as WATCHED, never WARD; a stolen
  yes cannot be voted into a leash you hold yourself):
  > **HALE:** *(he doesn't stretch it; that's his mercy)* The hall's
  > answer is no. Till the thaw at least — go. *(quieter, at the door,
  > off the record)* For what it's worth: half of them voted their
  > fear, not you. The other half voted the hand. I couldn't argue with
  > the hand.

### 7.5 Reconvergence (all three verdicts, one road)

Dawn. The east road. The rider is waiting either way — an Accord watcher
with Maren's letter (read aloud, short: *"You froze a lake. We felt it
from three valleys off, and so did things with worse manners than mine.
Come learn what you are before one of them offers to teach you."* — the
Act 2 travel hook, and the universe's only Act 1 appearance).

Who stands in the road to see you off is flag-assembled (the act's whole
ledger, one last silent read): Col always; Tilda always (gold: with a
packed satchel / ink: with the satchel and no words); Jorin only on
`a1_jorin_asked` ("Ten years. I'm counting."); Ede at chores ≥ 1 ("Goat
fence held. Off you go then"); Fenn only at `a1_fenn_stood`, at a
distance, hand raised — half blessing, half measuring.

**Flags carried into Act 2:** the full `a1_*` registry (§3). Dunmere is
revisitable mid-Act-2 (one pearl) and appears in Act 3; the verdict
decides which town you find.

---

## 8. The tint layer (patterns; the volume pass extends these)

Per the portfolio §7 split: everything in this section is the
AI-appropriate volume lane — patterns authored here by hand, extended in
bulk at build, nobody scrutinizes a greeting. Everything in §§4–7 above
is the hand lane; no generation there.

- **8.1 Greeting pattern:** every named NPC gets 4 tint greetings
  (Tilda's set in §5.5 is canon for register: the tint shows in what
  they *do* — where you sit, who they mention — never "I sense
  darkness in you"). Attribution rule: each cool/ink line names a
  concrete cause (the Marsh boys, Corb asking, the new bell).
- **8.2 System re-parameterizations (the nearly-free lane, portfolio
  §4 — one-liners on existing systems):** shop margin ±10% by tint
  (fear-gouging at ink, neighbor-discount at gold); lake-wight night
  aggro radius ×1.5 at ink; town guard posture flag (stave carried vs
  racked); inn music brightness; Knell footstep-toll at ink (§6).
- **8.3 Pillo the peddler (walking price gauge):** sells useless charms
  all bands. Gold: "Half price for you — association's good for
  trade." Ink: he presses one into your hand free, terrified: "No
  charge. NO charge. It's cedar. Cedar's… look, just take it." *(Then,
  from safety, the clip-caption line:)* "Doesn't work on him anyway.
  Nothing I stock works. It's a COMFORT item."
- **8.4 The dogs (the cheapest legible barometer in the game — critter
  AI re-parameterized):** gold: town dogs fall in behind you, a small
  procession the town pretends not to find eerie. Ink: growl, then
  won't cross your street. Ede's line, tint-agnostic: "Dogs are honest.
  It's the only thing wrong with them."
- **8.5 Codex hooks (door-not-room, portfolio §6):** per pearl, the
  codex shows sealed doors — P2: "Two offers were made. You took N of
  2." P3: "The bell answered one of three askings." P4: "The vote could
  end three ways; Dunmere chose ⟨verdict⟩." Plus the Standings page:
  band + last three deltas *with named causes* (the attribution organ).

---

## 9. Open questions for the owner + TESTs

1. ~~**Title & names.**~~ **RESOLVED (2026-08-04):** working names
   stand; red-pen at any point before build — nothing keys on them.
2. ~~**Class refraction depth.**~~ **RESOLVED (2026-08-04): v1 ships
   with class distinction.** Scope specced in §1; the six-voiced option
   sets land as this doc's v2 pass.
3. ~~**The Knell ability**~~ **RESOLVED (2026-08-04):** generalized
   into the two-branch special-ability system — see
   `SPECIAL_ABILITIES.md` (rulings 1–6). Knell = the first story-branch
   special; the story slot debuts with it at the act climax.
4. ~~**Forced-heal severity**~~ **RESOLVED (2026-08-04): hard-lock
   KEPT** — WARD is unreachable after a forced heal, under two fairness
   conditions now wired into the scene: (a) *informed cruelty* — the
   option text carries its full weight at selection time (§5.4's forced
   option reads "Do it anyway. He said no."); no player gets to be
   surprised that it counted, only by how much. (b) *punishing ≠
   dead-end* — the forced lane has its own Act 2/3 arc (planted in
   §5.4): the hand Jorin refuses to look at is one day the thing that
   saves Col, and he has to live with it *working*. "Ask me again in
   ten years" turns ironic, not closed. Clarified scope: the lock is on
   Dunmere's VERDICT, not on endings — endings read final band + the
   `a1_jorin_*` flag's thread, never the vote.
5. **[TEST — APPROVED] The Jorin vertical slice.** P2's cottage scene +
   the three aftermaths + the three P4 testimonies, playable — the
   cheapest end-to-end proof of the plant→cash loop, and the footage
   for the §2 creator seeding test.
6. **[APPROVED] Delta economy sanity (build-time):** wire the §3 ledger
   into a headless autotest walk (all-steady run, all-tempted run,
   mixed) and assert the terciles land as authored — same pattern as
   the existing balance harnesses.

## 10. Build order (when approved)

1. Flag registry + delta table into a `hearth_act1` content module
   skeleton (plant layer — existing plumbing).
2. P2 Jorin vertical slice (§9.5).
3. P1 cutscene (plates are 4 generator briefs; grammar identical to
   chapter openers).
4. P3 combat pearl (lake-wight re-skins + warden boss + bell choice).
5. P4 vote (pure convo assembly — the cash layer's reference
   implementation).
6. Class-voice pass — **authored, §11** — port with the scenes.
7. Tint volume pass (§8 patterns × cast × 4 tints), then the dogs.

---

## 11. The class-voice pass (v2, 2026-08-04)

Scope per the §1 ruling. Conventions:
- The class-agnostic options in §§4–6 are the **shared-meaning spec**;
  every voicing below maps to the same flag and delta. Six REASONS, one
  stance — the openers discipline (no shared rationale, no shared
  tagline) applies within each choice.
- **NPC replies stay shared per stance** (Hale, Fenn, Jorin and Col
  answer the *stance*, not the phrasing) — zero per-class replies in
  v2; cheap to add exceptions later if one begs.
- The forced-heal option keeps its **shared label** — "Do it anyway.
  He said no." — on all six (the §9.4 fairness ruling is verbatim,
  class-proof); the class voice lives in the internal follow-through
  line as the shard reaches.
- Temperament axis (§1): warrior blunt · assassin guarded · mage
  precise · archer distant · paladin dutiful · warlock transactional.
  The wound is shared (the ferry); the *refraction* is how each
  temperament metabolizes it.
- **Build note — button labels.** Several voicings below run to spoken
  length (2–4 sentences). For the choice UI, the streamability thesis
  wants a SHORT scannable button (chat reads it in ~2s) with the full
  voicing as the spoken confirm line. Extract a ≤6-word label per
  option at build (e.g. warlock take-voice → button "It lists once."
  / spoken: the full line). Not rewritten here; the voicings are the
  spoken layer.
- **Review pass applied (2026-08-04):** cross-choice per-class tics
  pruned (warrior "Some things you…" ×3→1, mage "exact" ×4→2, archer
  "the whole field"/"at range" duplicates, assassin secrecy tagline
  ×2→1); tempted-lane "clean" adjacency and "twelve lives" rhyme
  broken (paladin reworded). Warlock's all-financial register kept as
  deliberate characterization — its one human crack is the "Always."
  on the Jorin friendship beat (§11.3), where it belongs.

### 11.1 P1 class turn (n3.5 — between the freezing and the shore)

One beat + one plate each (`hearth_a1p1_<class>`; camera varied per
the openers rule — no six-costume repaint).

- **Warrior** *(plate: wide from the shore — a small figure, a vast
  stopped lake)*:
  > The strangest part is that it felt *practiced* — like swinging a
  > weight you'd trained with every morning of your life and never
  > once picked up. Your whole body committed, the way it does when
  > there's no half-swing left in the world. Nothing borrowed about
  > it. That's the part you don't say out loud.
- **Assassin** *(plate: your reflection in the new ice, mark already
  glowing; you are looking at it, not at the ferry)*:
  > You have spent a life being unremarkable on purpose, and it was a
  > kind of peace. The reach was silent; the lake never even creaked.
  > But two hundred people were watching the water, and now the
  > quietest thing you ever did is the only thing anyone will ever
  > know you for.
- **Mage** *(plate: extreme closeup — the eye, and in it the lattice
  of the freezing water)*:
  > You *saw* it. That's the thing. Every mote of it — the water's
  > argument, the cold's rebuttal, the lattice climbing itself
  > outward from your want like frost given a syllabus. It was the
  > most exact thing you have ever witnessed and you understood it in
  > the moment of its happening, and understanding it is the part
  > that should frighten you. It doesn't. That's the other part.
- **Archer** *(plate: impossible top-down — the whole lake at once,
  the ferry a chip of wood, the figures small)*:
  > For one breath you saw it the way a hawk must — the whole lake at
  > once, every soul on it small and clear and *countable*. Eleven on
  > the boat, one in the water, twelve strokes of arithmetic. From up
  > there even Col was a number, and the number was easy to save.
  > Coming back down to being his sibling took longer than the ice.
- **Paladin** *(plate: over your shoulder — the survivors standing on
  the ice, facing you, like a rank awaiting review)*:
  > It arrived like a writ — like something with a seal on it,
  > handed down, already decided, only waiting on your arm to be
  > carried out. Saving them didn't feel like a miracle. It felt like
  > *orders*, and you have never in your life executed anything so
  > cleanly. What frightens you, standing in the fire-light after, is
  > how badly you want the warrant to be real.
- **Warlock** *(plate: closeup of your own hands in the firelight,
  fingers half-curled as if counting)*:
  > Before Col's name, before the cheering, before you even knew your
  > knees had held — the first clear thought through you was: *what
  > does this cost?* Nothing gives like that for free. Nothing in the
  > world. Somewhere a ledger opened with your name at the head of
  > the page, and you stood on the shore watching them hug each other
  > and tried to read the interest line upside down.

### 11.2 P1 — Hale's question, six-voiced (flags/deltas per §4)

**Steady (+6, `a1_stance_steady`):**
- *Warrior:* "A new weapon nobody's trained me on. So I train — on my
  own arm, on empty ground. Not on this town."
- *Assassin:* "Something I don't control yet. Until I do, you'll know
  where I am any hour you care to ask. From me, that's not a small
  promise."
- *Mage:* "A mechanism I don't have the numbers for. I'll take it
  apart cold, in daylight, on nothing living — and you'll get what I
  find whether it flatters me or not."
- *Archer:* "Something that sees the whole field at once. I'm still
  learning the way back down to where people stand. I will learn it."
- *Paladin:* "A charge, reeve — and nobody issued it, which is the
  problem. So I answer to the town until something better than me
  shows its seal."
- *Warlock:* "A loan I never signed for. So — what you do with any
  loan: find the terms before the collector does. You'll get honest
  accounting, whatever it says."

**Tempted (−6, `a1_stance_pride`):**
- *Warrior:* "You watched my back hold twelve people in one lift.
  Whatever it weighs, it'll hold again."
- *Assassin:* "You watched nothing — that's what should interest you.
  A thing that quiet, on this town's side? I'd keep it."
- *Mage:* "The most precise work I've ever seen. It froze a lake and
  never cracked a hull plank. That's not a danger, reeve — that's a
  standard."
- *Archer:* "From inside it, everything looked simple — twelve lives,
  one reach, no argument. You've no idea how clean the world is from
  up there. I could get used to clean."
- *Paladin:* "You watched an answer, and it was right — the lake gave
  them back. When something answers that true, arguing with it starts
  to look like vanity."
- *Warlock:* "You watched a debt get collected. The lake owed this
  town twelve lives; I called it in. If there's interest later — it's
  still the best trade Dunmere ever made."

**Deflect (0, `a1_stance_rope`):**
- *Warrior:* "I saw a rope snap and ice come early. Ask me something
  I can answer with my hands."
- *Assassin:* "You watched it from the shore. I was inside it, and I
  can tell you less than you can. Leave it there."
- *Mage:* "Cold moved through water; water changed state. Everything
  past that sentence is a guess, and I don't hand guesses to a man
  holding a stave."
- *Archer:* "I saw it from further off than you did, somehow. Ask the
  water. I was only where I was standing."
- *Paladin:* "I'll say it in the hall, under oath, when I have words
  fit for oath. Not on a cold shore with my brother still shaking."
- *Warlock:* "I don't describe terms I haven't read. The rope broke.
  Past that — no signature."

### 11.3 P2 — the Jorin choice, six-voiced (flags/deltas per §5.4)

**Respect it (+8, `a1_jorin_asked`)** — spoken to him, after the no:
- *Warrior:* "Sheathed, then. For as long as you say. And it's left
  hands only at your table from now on — fair's fair."
- *Assassin:* "Heard. I won't raise it again — and Jorin, it stays
  inside these walls. No one learns it was ever possible unless you
  tell them yourself."
- *Mage:* "Then it's struck from the workbook. Your no is a constant,
  not a variable I keep re-deriving. I won't ask this year, or next."
- *Archer:* "Then it's out of range, and I don't draw on what's out
  of range. Ten years. I'm good at waiting."
- *Paladin:* "Then that's the law in this room and I'll keep it like
  law. Your hand, your verdict. …I'd have hated you a little if
  you'd said yes just to spare me."
- *Warlock:* "Then the offer's torn up — no standing balance, no
  quiet interest gathering on it. And you don't owe me an answer in
  ten years, either. Clean books between us. Always."

**Do it anyway. He said no. (−8, `a1_jorin_forced`)** — shared label
(§9.4); the class voice is the internal line as the shard reaches:
- *Warrior:* *Some things you do first and carry after. You can't
  stand in a burning house holding the bucket.*
- *Assassin:* *What he never watches happen can't wound him. You've
  kept heavier things quiet for smaller reasons.*
- *Mage:* *The work is exact and the outcome is good. Consent was the
  one variable that was never going to resolve — and perfect work
  shouldn't wait on it.*
- *Archer:* *From far enough back it's simple: a whole man on one
  side, a grudge on the other. You can live with being wrong from up
  here.*
- *Paladin:* *He is hurt, and you can mend him. What kind of oath
  waits for permission to do good? The verdict is obvious. Carry it
  out.*
- *Warlock:* *He'll hate you — and he'll have two hands to hate you
  with. Asset against debt; the ledger says do it. You know how to
  carry a debt.*

**Never offer (0, `a1_jorin_silent`)** — the internal withholding
(each line contains its own indictment; the Fenn reveal lands fair):
- *Warrior:* *Some weapons you don't show a man who just lost a
  fight. You call it kindness, and you don't look too hard at what
  else it is.*
- *Assassin:* *Information is a blade with no handle. You pocket it.
  That's what you've always done with blades like that.*
- *Mage:* *Insufficient data — on the mend, on him, on you. You file
  the question under 'later,' knowing 'later' is where questions go
  to rot.*
- *Archer:* *You leave it downrange, past asking. Closer means
  answering for it; the distance means you never quite lied.*
- *Paladin:* *You seal it like an order not yet read — telling
  yourself you're sparing him the question, pocketing that you're
  sparing yourself the answer.*
- *Warlock:* *An undisclosed liability costs nothing today. You know
  better — they always find the light — but today it costs nothing.*

### 11.4 P2 — Fenn's blessing, six-voiced (flags/deltas per §5.2)

**Kneel (+4, `a1_fenn_stood`):**
- *Warrior:* "If my knees on your floor steady this town's knees,
  they can take the cold. Say your words, keeper."
- *Assassin:* "Quietly, then. No procession, no pamphlet story — you,
  me, and the words. That's the price of my kneeling."
- *Mage:* "I'll kneel for the experiment's sake. If words can bind
  this thing by even a hair, I want that on record. Say them to the
  word, keeper."
- *Archer:* "From where I've been standing lately, kneeling is the
  closest to ground I've felt. Go on, Fenn."
- *Paladin:* "That's the first thing asked of me since the lake that
  I already know how to do. Words over a bowed head — gladly."
- *Warlock:* "A blessing's a contract with generous terms: you say
  words, I bow, two hundred people sleep. Cheap at twice the
  humility. Proceed."

**Scorn (−4, `a1_fenn_scorned`):**
- *Warrior:* "I pulled twelve out of the water while your bell hung
  quiet, keeper. The day your words hold a rope, I'll kneel to them."
- *Assassin:* "You want the town to watch the fire bend its head.
  That's not a blessing, it's a notice posted. Find another board."
- *Mage:* "Name one mechanism in your blessing. One. Words don't
  bind what froze that lake — and pretending they do is the only
  dangerous thing standing in this shrine."
- *Archer:* "You lost her to this water, so you built a room to argue
  with it. I'm done arguing with water. I win now."
- *Paladin:* "Your blessing was written downvalley, for strangers'
  fires. I answer to a higher writ than a pamphlet, keeper."
- *Warlock:* "You're asking me to sign a statement of debt — the fire
  owes, the shrine collects. I've read the terms. The fire owes
  Dunmere nothing. It's *paid*."

**Slip (0, `a1_fenn_slipped`):**
- *Warrior:* "Another day, keeper. My hands still shake too hard to
  fold."
- *Assassin:* "I don't kneel anywhere I can't see the door. Nothing
  personal, Fenn."
- *Mage:* "When I know what I'd be kneeling *to*, I'll consider the
  posture. Premature ritual is bad method."
- *Archer:* "I'm not ready to stand that close to the water. Another
  day."
- *Paladin:* "I'll kneel when I can do it honestly. Today it would be
  theater, and you deserve better than theater."
- *Warlock:* "I'll take the terms under advisement."

### 11.5 P3 — the bell, six-voiced (flags/deltas per §6; Col's
question is the shared asker)

**Break it (+6, `a1_bell_broken`):**
- *Warrior:* "You don't bargain with a thing like this. It's rung at
  this town for a hundred years. Enough."
- *Assassin:* "A thing that loud can never be trusted quiet. You
  don't gag it — you end it. Look away if you need to."
- *Mage:* "It's a resonator, Col — it will always find something to
  shake. There's no setting where this ends well except zero. I'm
  sorry. It *is* beautiful."
- *Archer:* "The asking is a call, and the call is why things keep
  coming. Cut the call, the things stop. Simplest shot on the board."
- *Paladin:* "It rang for drownings; now it makes them. That's a
  broken charge, and broken charges get discharged. Stand behind me."
- *Warlock:* "A debt that asks forever compounds forever. You don't
  service that — you default, once, and eat the loss. The fish are
  the loss, Col. Say it now so we said it out loud."

**Take its voice (−6, `a1_bell_taken`):**
- *Warrior:* "It wants carrying? Then I carry it. Better on my back
  than under this lake. I can hold it, Col. I can hold anything."
- *Assassin:* "A voice like that, pocketed where no one knows I have
  it — that's not a burden, Col, that's the best blade I'll ever own."
- *Mage:* "Broken, it teaches nothing. Carried, it can be read from
  the *inside*. Col — this is the only copy of this knowledge in the
  world."
- *Archer:* "It hears everything the water touches — that's why they
  come when it calls. I've been half-blind my whole life. I want to
  see all of it, for once."
- *Paladin:* "A voice that commands the drowned is not a curse — in
  the right hands it's an office. Someone will end up holding this.
  Better the one who answers to Dunmere."
- *Warlock:* "An asset like this lists once. Yes, there'll be
  interest. There is always interest. And I am very, very good at
  carrying interest."

**Bind it (0, `a1_bell_bound`):**
- *Warrior:* "I'm not sure enough to break it and not fool enough to
  swallow it. It goes down deep, tied the way Jorin taught us, and it
  becomes the next fight's problem."
- *Assassin:* "You keep a thing like this where you can find it and
  nobody else can. Down. Deep. Ours."
- *Mage:* "Neither destroy the data nor ingest the sample. Contain,
  label, revisit with better instruments. Hand me the rope."
- *Archer:* "Not every asking needs answering today. We put it past
  reach. Mine included."
- *Paladin:* "It's not mine to execute and not mine to wield. It sits
  in custody until someone with the right to judge it exists. That's
  all the law I trust tonight."
- *Warlock:* "We escrow it. Nobody spends it, nobody defaults — the
  claim stays open and the interest accrues. Someday's problem,
  priced accordingly."
