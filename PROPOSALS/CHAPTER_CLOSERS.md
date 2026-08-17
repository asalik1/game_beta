# Chapter Closers — per-class animated closing cutscenes (2026-08-17)

Proposal + build source: every chapter ENDS the way it opens — a short
illustrated storybook beat on the same `Cutscene` layer as the class openers
(`cutscene.gd`). When the chapter's final boss dies, the boss speaks its dying
lines, then the hero reflects on what the victory MEANS — refracted through
that class's wound, exactly as the openers are. **No choices** (owner call): a
closer is a passive cinematic, not a decision. It plays, ends on `fade`, and
hands off to the existing VICTORY results card.

This is the mirror of `CHAPTER_OPENERS.md`. Same engine, same
shared-spine → class-turn → fade grammar, minus the n4 choice node.

---

## 1. The grammar

Each `<ch>_closing_<class>` convo is a linear five-beat storybook:

1. **The finish** *(per class — plate + line)*. The class lands the killing
   blow, staged the way THAT class fights (mage's green light, warrior's
   blade, archer's arrow, assassin's Ember, paladin's hammer, warlock's
   tome). The killing blow is the "animation of the class beating the boss".
2. **The boss's dying lines** *(shared — the death is one event for everyone)*.
   The boss speaks. For a shard-boss like Vargoth, the words land on the
   theme the whole campaign turns on: what you carry is kin to what you just
   killed.
3. **The fall** *(shared — plate + line)*. The boss ends; the prize settles.
4. **The reflection** *(per class — plate + line)*. The hero thinks about
   what it means, keyed to that class's ch1 wound (the opener refraction
   table). This is the "hero thinks about what it means" beat.
5. **The hook** *(shared — `fade`)*. A forward line toward the next chapter,
   folding in the old epilogue's "something older stirs… TO BE CONTINUED".

**Refraction table** (identical to the openers — the closer pays off the same
wound the opener opened):

| Class | Wound (from ch1) |
|---|---|
| Warrior | violence exceeding intent — the blackout; "you kept swinging" |
| Assassin | the Ember TAKES to keep you alive — the flask, the grey lips |
| Mage | help that harms — the green light, the grey mark, the promise to undo |
| Archer | the severed thread — ties made visible, then cut; the unlatched gate |
| Paladin | the chain that argues verdicts — "HE IS YOURS. SHIELD HIM." |
| Warlock | the debt you don't remember signing — the tome, the interest |

**Continuity rules**
- The shared spine (boss death + fall + hook) must read true for all six
  classes — write to the event, never to one class's weapon or stance.
- Each reflection is a stance the boss's death takes ON that wound; no two
  classes may share a rationale. Convergence of theme, divergence of voice.
- The finish line names only what the plate shows — a mage does not swing a
  sword, an archer does not cast.

---

## 2. Wiring (build spec)

- **Content module:** `game/scripts/content/chapter_closers.gd`, a hand-authored
  content module (consistent with every non-opener module in the repo; closers
  are linear with no branching choices, so the openers' generator is
  unnecessary). This doc is the creative + art-prompt source of truth. Defines
  `const CONVOS` keyed `<ch>_closing_<class>`. Registered in
  `Story.CONTENT_MODULES` (NOT at index 0 — that slot is the openers module,
  read by `Story.chapter_opener_flags()`).
- **Cues:** new closer cue ids registered in `cutscene.gd`
  (`FRAME_SEQUENCES` + `KNOWN_CUES`); autotest validates every convo cue.
- **Trigger:** `game_flow.gd` `on_boss_died`, the final-boss branch. Today it
  plays a flat `hud.dialogue(epilogue, end_it)`. Change: when a
  `<ch>_closing_<player.cls>` convo exists AND the run is solo
  (`not net_online()`), play `run_cinematic_convo("<ch>_closing_"+cls, end_it)`
  instead; otherwise fall through to today's flat epilogue beat unchanged.
  **Co-op keeps the flat epilogue for v1** (the illustrated closer is
  per-class and local, and the victory flow is host-authoritative — a proper
  per-client closer in co-op is a follow-up, mirroring how openers replay
  per-client in `net_advance`). Solo is the reviewable slice.
- **Plate resolution:** 1672×941 (matches openers). Files land in
  `game/assets/sprites/opening/closing/` as `closing_<...>.png`, generated
  with the Codex `image_gen` lane (headless `codex exec`), staged and
  `verify`-checked before install, same as every other generated plate.

---

## 3. ch1 — The Hollow King (final boss: Vargoth)

Vargoth is the Hollow King: he wore the Ember Crown sixty years, and the
shard in the bearer's chest is "a piece of me, walking about in someone
else's chest" (`story.gd` `pre_vargoth`). The closer pays that off — you did
not defeat a stranger; you shortened your own line.

### Shared spine

**The fall** — plate `closing_ch1_crown`
> Vargoth mid-shatter on the throne dais of the Hollow Throne (keep terrain):
> a crowned figure breaking apart like fired porcelain into drifting embers,
> the Ember Crown tumbling from a dissolving brow toward the flagstones, still
> glowing warm. Wide, low angle, painterly dark-fantasy, ember motes, cold
> stone, one warm light source (the crown). No hero in frame.

- **dying** (King Vargoth): "A piece of me… walking home in someone else's chest. You did not slay your king, little flame. You only came early — for the rest of him."
- **fall** (Narrator): "The Hollow King shatters like old porcelain. The Ember Crown clatters to the stones, still warm — and the shard beneath your ribs answers it, warmth for warmth."

**The hook** — cue `fade`
- **hook** (Narrator): "Deep beneath the keep, something older turns in its sleep — and the piece of crown you carry turns with it. The flame returns to Emberfall. It was never only Vargoth's. TO BE CONTINUED — CHAPTER TWO."

### Warrior — *the blackout, mastered*
- plate `closing_ch1_warrior_finish` — A warrior driving a broadsword into the chest of a towering crowned wraith-king on a throne dais; the warrior's eyes open, present, deliberate — not the white-out of a berserk swing. Ember light on steel, keep interior, painterly dark fantasy.
- **finish** (Narrator): "Your blade finds the hollow of the crown-king, and this time you feel every inch of it — no gap, no blackout, no stranger waking in your boots after. You are awake for all of it."
- plate `closing_ch1_warrior_reflect` — The same warrior standing alone over scattered crown-embers, sword point resting on stone, head bowed but steady; counting, not reeling. Quiet aftermath, cold keep, low ember glow.
- **reflect** (You): "I remember this one. Every swing. Maybe that's all that stands between him and me — he stopped counting his blows, and woke up a crown. I'll keep counting mine."

### Assassin — *the taking, aimed*
- plate `closing_ch1_assassin_finish` — A lean hooded assassin behind the crowned wraith-king, blade drawn across from behind, faint ember-red draining from the king toward the assassin's hand; the king's light guttering. Keep dais, painterly dark fantasy, muted palette, one cold rim light.
- **finish** (Narrator): "You are behind him before the crown can gutter a warning. The Ember takes, the way it always takes — and for once you let it take a king."
- plate `closing_ch1_assassin_reflect` — The assassin looking at their own open hand, ember-warmth fading from the palm, the fallen crown behind; grey cast to the light. Somber, close, dark fantasy.
- **reflect** (You): "It fed on him and left me standing. Grey lips, a cold throne. Sixty years he called that a crown — I've called it a curse since the carter's fire. Same hunger. Only the name changes."

### Mage — *the green that harms, that heals, that ends*
- plate `closing_ch1_mage_finish` — A robed mage with hands raised, a lance of GREEN light (not gold) striking the crowned wraith-king across the throne dais, the king recoiling as the green unmakes him. Keep interior, painterly dark fantasy, the green light the dominant hue — eerie, not holy.
- **finish** (Narrator): "The green light leaves your hands one last time — not to mend, but to end. It answers as eagerly as it did the night it scarred a ferrier's boy."
- plate `closing_ch1_mage_reflect` — The mage lowering their hands, staring at faint green residue on their fingers, the fallen crown glowing warm beyond; conflicted, quiet. Dark keep, green-and-ember two-tone.
- **reflect** (You): "The same green that harms, that heals, that ends a king — and I still cannot tell it which it will choose. I promised a mother I would learn what my magic is. A dead king is not the answer. But it's a question I can no longer set down."

### Archer — *the thread, cut on purpose*
- plate `closing_ch1_archer_finish` — A lean archer at full draw across the throne hall, a single arrow flying taut toward the crowned wraith-king's heart, a faint thread-of-light trailing the shaft. Long perspective down the keep hall, painterly dark fantasy, cold light, one warm crown-glow at the end.
- **finish** (Narrator): "One arrow, one line drawn taut between you and the throne. You have cut ties before. This is the first you ever cut on purpose — and felt nothing but the release."
- plate `closing_ch1_archer_reflect` — The archer lowering the bow, the fallen crown small and warm at the hall's far end, an empty doorway beside them; a sense of something left open. Quiet, distant, dark fantasy.
- **reflect** (You): "Every thread I ever cut, I cut running. This one held a whole kingdom to a dead man's fist, and letting it go didn't lighten me. It just left a gate somewhere — still unlatched, still waiting."

### Paladin — *the chain that was right, this once*
- plate `closing_ch1_paladin_finish` — An armored paladin bringing a great warhammer down on the crowned wraith-king; faint chain-links of light coil the paladin's arm but hang slack, not pulling. Ember sparks, keep dais, painterly dark fantasy, righteous but grim.
- **finish** (Narrator): "The hammer falls, and for once the chain at your heart does not argue the verdict — it only watches a false king answer for sixty stolen years."
- plate `closing_ch1_paladin_reflect` — The paladin kneeling on one knee before the scattered crown, helm off, the slack chain of light still at the wrist; troubled, not triumphant. Cold keep, single warm crown-glow.
- **reflect** (You): "GUILTY, the chain said — and this time it was right. That is what frightens me. A false king is easy to judge. What do I do the day it says GUILTY and I agree… of someone who only knelt?"

### Warlock — *the account, closed*
- plate `closing_ch1_warlock_finish` — A warlock with an open floating tome, its pages blazing, a torrent of debt-light pouring from the book into the crowned wraith-king as he comes apart. Keep dais, purple-and-ember palette, painterly dark fantasy, occult.
- **finish** (Narrator): "The tome falls open of its own accord, and the debt you never remember signing comes due — all at once, spent on a king who signed his own centuries ago."
- plate `closing_ch1_warlock_reflect` — The warlock holding the tome half-closed, looking down at its pages where the handwriting looks like their own, the fallen crown warm behind. Occult, pensive, dark fantasy.
- **reflect** (You): "He wore his crown sixty years and called the interest a reign. My tome keeps its books in my own hand, more like me every year. I closed his account today. I still don't know the balance of mine."

---

## 4. Rollout

- **ch1 first** (this doc) — the proven vertical slice: 6 finish plates + 6
  reflection plates + 1 shared fall plate = 13 plates, all six classes, wired
  solo, suite green, owner reviews in-game.
- **ch2–ch7 after review** — same grammar, refracted through each chapter's
  theme and boss (nullwarden, saint_varo, ashpriest, sleepkeeper,
  curetwisted, stormmouth), authored as new `### ch<N>` sections here and
  regenerated. Each boss's dying lines key to that chapter's logline; each
  reflection keys the class wound to what the chapter did to it.
- **ch8–ch14** — land with each Act 2 chapter build.
