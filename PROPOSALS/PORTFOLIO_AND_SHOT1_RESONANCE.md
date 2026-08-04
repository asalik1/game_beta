# Portfolio Strategy + Shot #1: The Resonance Narrative Game

Working doc. Captures the strategy and the shot-1 concept. Owner's call on everything; where a risk is unresolved it's written as a **TEST**, not a debate to reopen.

---

## 0. Premise (low attachment)

We have options. Any single game can die in a fire and we're fine. The unit that matters is **the developer over many shots**, not this game. Velocity (a complete game in ~1 month) is the rare asset; the job is to point it well and take many cheap tickets.

---

## 1. The strategy (the meta)

- **Portfolio of bounded shots** inside the **Emberfall shared universe.** Different genres/playstyles, same world → shots fail/hit independently *and* reuse lore/pipeline/brand.
- **Build once → ship → walk away.** No live-service treadmill. Everything ships complete-in-the-box.
- **Cohorts of ~3 shots, sequenced (not batched).** Launch #1, read the data, feed it into #2, then #3. After 3, holistic review: revisit anything worth revisiting, else start a new set.
- **Pre-registered scorecard before every launch** — numbers in writing (hit above X wishlists / Y first-week / Z retention; kill below W). No grading our own homework after the fact.
- **Sort every lesson: transferable vs local.** Transferable (store-page craft, trailer, first-hour, marketing, art cohesion) carries to *all* future shots. Local (one mechanic didn't land) does not. **The real prize of cohort 1 is a much better shot #4.** Judge success by "is my worst game now better than my best used to be."
- **"Worth revisiting" = showed demand we failed to convert** (fixable leak), never "I liked making it."
- **Don't abandon Emberfall on one cohort** — audience compounding lags; 3 shots is too few to indict the world.
- **Shared universe = a compounding owned audience** (each game funnels wishlists into the next; Riot/Runeterra, Blizzard→Hearthstone). But **each game must stand alone first**; a stranger who's never heard of Emberfall must fully enjoy it. Universe is the multiplier, not the hook. Don't build the MCU before Iron Man hits.

---

## 2. What "win" means (the success model)

- **Discovery is the variable, not quality.** Median Steam game earns ~nothing; the determinant is whether the right people ever see it.
- **Free distribution = shareability.** The no-marketing hits all had massive *organic* distribution (streamers/clips), gated harder on legibility than paid distribution is. **Design shareability INTO the product.**
- **Funnel for diagnosis:** impressions → CTR → wishlist → purchase → first-hour retention → word-of-mouth. "No success point anywhere" localizes the flaw — but only **above a reach threshold** (zero signal at zero reach = noise, not a verdict).
- **Leading success-point for this template: organic clip/creator pickup.** TEST cheaply with a demo at Steam Next Fest + a handful of seeded creators before full commit.

---

## 3. Shot #1 concept: Resonance-driven narrative choice game

- **Template:** watchable/legible/clippable via the **choice-drama vector** (BG3, Until Dawn / Supermassive, Reigns). The clip is *the shocking consequence*; chat backseats the choice, then lives with it.
- **We sell a fantasy**, not literature — power-fantasy / fantasy-fulfillment market, which sells on the dopamine beat and tolerates cliché. Prose bar is "satisfying," not "prestige."
- **Core:** combat/gameplay core stays constant; the **world around it** (NPCs, quests, reactions, progression, hostility) is shaped by the player's resonance. The RPG layer is malleable, player-shaped.

---

## 4. Resonance design

- **Bands:** −100..−50, −49..0, 0..49, 50..100. Two middle bands share a branch (different tint); the two extremes each get their own branch. → **effectively 3 LANES, 4 TINTS.**
- Band **fluctuates** with choices; it accumulates from small ± deltas over the run. The lane you *end* in drives the ending.
- **Two-layer cost model:**
  - **Tint (cheap, everywhere):** band colors dialogue tone, greetings, minor gates, ambient flavor. Variable text/flags, not authored scenes. AI-appropriate volume work.
  - **Pivots (expensive, ~5–8 total):** flagged, hand-authored, fully branched, high-impact — the betrayals, closed doors, real divergence. **Tie each to a SPECIFIC remembered choice** ("you sold his brother"), not just the band; band *amplifies* the pivot, doesn't *be* it. Band is the weather; the choice is the knife.
- **Reactivity affects GAMEPLAY too — sorted by cost:**
  - **Cheap = re-parameterize existing systems** (undead aggro ×1.5 at high resonance, prices, faction hostility, spawn rates, buffs, who-attacks-you). One-liners on systems we already have. **Mine this hard — nearly free and enormous.**
  - **Expensive = new subsystems** (e.g. a stealth path = detection/LoS/takedowns = a second game). Each one is a whole new game; price it as one, or skip.
- **Class = pure flavor (tint), zero structural weight.** Already proven in `chapter_openers.gd`: n1/n2 shared across classes, n3 = class-flavored voice of the same beat, choices structurally identical (same ± resonance, same flags), all reconverge to the same `n_end`.

---

## 5. Structure (the scope control)

- **String of pearls:** shared spine → a pivot diverges → **reconverges at the next hub**, carrying a flag or two forward. **Branches MUST reconverge mid-game** or "3 lanes" explodes to 3 → 9 → 27.
- **Save permanent divergence for the ENDINGS** (3 endings — no "next scene" left to pay for).
- Concentrate expensive divergence at the finale; keep the mid-game a shared spine with reconverging detours.

---

## 6. Perception, replay, feel

- **Subtle reactivity is invisible on playthrough 1** (no counterfactual). Rescued by two things we already have:
  - **Codex** shows "you saw 1 of 4 — a path/quest you didn't take." Show the *door, not the room* (tantalize, don't spoil). This drives replay.
  - **Cross-stream aggregation:** the audience sees the same NPC warm to one streamer, cold to another → the un-spoilable, renewable-shock engine. (Retention/replay engine — **not** acquisition.)
- **Attribution requirement:** the player must be able to trace the change to their choice (NPC references *why* / band surfaced / codex connects it), or reactivity reads as random moodiness and the whole feeling collapses.
- **Acquisition** rides on the legible hook + clippable pivots + **humor** (currently lacking; cheapest, highest-leverage shareability lever — add it).
- **Quests:** replace cookie-cutter gather/deliver with consequential, band-gated ones. Gated content ("one NPC offers a quest, another refuses") is the highest-ROI reactivity tier — perceptible, cheap (gates existing content), streamable, replay-driving.

---

## 7. Content pipeline / AI

- **Tech head-start already built (from Crownless):** convo engine, ± resonance deltas, choice flags, class-refraction, a **markdown → module generator** (`tools/content/gen_chapter_openers.py` from a proposal doc), and a flag registry. **The PLANT layer is done.** The missing half is the **CASH layer** — reading accumulated band + flags at the 5–8 pivots to actually branch. That's the game.
  - Current state, as a cautionary example: ch2 opener choices set `ch2_kept_faith / ch2_fed_ember / ch2_buried_it` six times, read in exactly one place (`ch2_hub.gd:89–91`) as one swapped greeting line, then reconverge. Choice dressed as consequence. The new game *cashes* these instead.
- **AI usage:** heavy on the **tint/volume** layer (hundreds of reactive flavor lines, ambient barks). Owner's call, backed by domain experience in the fantasy-fulfillment market: AI-generated tropey content **sells**, and AI is genuinely good at branch divergence/convergence bookkeeping.
- **TEST (don't assume):** does the tolerant power-fantasy crowd buy on Steam, or does the Steam-gamer audience react to AI content? Pre-register **review sentiment on AI content + conversion** as watched metrics. **Mobile largely defuses this** — mobile audiences are AI-tolerant and the pipeline is already wired.
- AI art for splashes/backgrounds is defensible if art-directed for cohesion.

---

## 8. Monetization / distribution

- **PC = premium.** Pay once, everything unlocked.
- **Mobile = F2P via the UNLOCK model** (free chunk → one-time unlock IAP), **not** a recurring cosmetic store. Same "free on mobile" hook, keeps the walk-away (a cosmetic store = live-ops treadmill).
- Two channels → not dependent on Steam alone.

---

## 9. Next actions

1. **Pre-registered scorecard** for shot #1 (wishlist / CTR / first-hour retention / clip-pickup thresholds).
2. **String-of-pearls skeleton** for act 1 — hubs, the 5–8 pivots, reconvergence points, flags carried forward, 3 endings.
3. **Build the CASH layer** on the existing plant plumbing (band + flags → branch at pivots).
4. **Confirm F2P flavor** (unlock vs cosmetic-store) — recommend unlock to keep walk-away.
5. Alt shot parked: **survivors-like** in Emberfall (max reach / min depth) if this shape stalls.
