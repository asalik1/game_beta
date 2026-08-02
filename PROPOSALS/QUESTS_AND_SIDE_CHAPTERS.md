# Quests — Chapter 2, the Capital, and the Interludes (2026-07-27)

Three quest holes, one doc: ch2's thin slate (3 side quests, worst in the
game), the capital's empty promise (ward NPCs offer "honest work daily" and
there is not one journal quest in Crownfall), and the owner's ask for
**diverging side chapters** off the Act 1 and Act 2 finales that reveal
other parts of the world. Nothing installed; decision document.

Engine constraints honored throughout (the side-quest engine's laws):
steps are convo-choice flags only, never kill counts (bounties own "slay
N"); rewards are gold + standing only; retroactive-accept for
explorer-first ordering; new choices append behind `req_flag` gates
(autotest walks index 0); content lands as modules + one registration
line.

---

## 1. Chapter 2 — the slate (6 new side quests + 1 arc step)

Written against the retrofitted ch2 (the `claude/night-systems` branch's
10 side rooms + spine). **Dependency: land the retrofit first** — three of
these quests live in its rooms. If the retrofit is reworked rather than
merged, the quests keyed to room NAMES below move with whatever rooms
survive; none depend on layout specifics.

Existing cast used throughout — ch2 already has the people; it lacks their
errands.

1. **The Second Bell** (Sentry Piet, Maren's Camp; 150g)
   Piet's watch-bell cracked in the storm that broke Korrag. Steps:
   `bell_heard` (inspect the fallen bell prop in the Howling Fields) →
   `bell_told`. Beat variant on the stormwarden boss door if done
   (`pre_stormwarden@flag:bell_heard` — Piet's bell is what Korrag's pack
   answered to; the fight gains one line of grief).
2. **What the Cage Holds** (the Caged Beastkin; 180g + wildfang ±2)
   The camp's caged beastkin asks — not for freedom — for word of whether
   the spore hollows still sing. Steps: `hollow_listened` (a listening
   prop in the spore zone) → report with a fork: tell the truth (they
   sing; wildfang +2, resonance −4 Hunger — the truth is cruel) or the
   kind lie (+4 Constancy, wildfang −2). The ch6 Far-Shore's-Door fork
   pattern, planted four chapters earlier.
3. **The Salt Reliquary** (Choir Pilgrim; 160g + choir +2)
   The pilgrim cannot make the walk to the reliquary (retrofit room).
   Carry their salt token; steps: `salt_laid` → `salt_told`.
   Retroactive-accept if you find the reliquary first.
4. **A Straight Answer** (Scholar Ivo; 200g)
   Ivo suspects the Null Bastion's warden logs contradict the Accord's
   account of the sealing. Steps: `logs_read` (Bastion prop) →
   `ivo_told` with a fork: hand him the full transcription (he publishes;
   accord −2, a `chose_ivo_truth` kept flag Act 2's archive content
   reads) or summarize kindly (accord +2). Seeds the Paper Concord
   Interlude (§4).
5. **The Ferryman's Due** (new wanderer, the Ferryman, retrofit landing
   room; 150g) — a coin for every drowned soldier he poled across the
   bog. Steps: `coins_counted` (three marker props across the bog zones,
   one flag — the pilgrimage shape) → `ferryman_paid`. Wanderer-rolled
   (~half of runs), the journal stays honest via `req_wanderer`.
6. **Widow's Arithmetic** (Widow Sera; 150g)
   Follow-up to Still Blue, gated `req_flag: mill_seen`. Sera wants the
   mill's ledger — the season's grain counts — to settle who the blight
   actually starved. Steps: `ledger_taken` → fork at turn-in: give it
   whole (+4 Constancy) or tear out the page naming her own hoard (−6,
   `chose_sera_page` kept). Quiet, nasty, very ch2.
7. **Faction arc step 2** (both recruiters): `ch2_accord2` — walk the
   camp's blight-line with Callis (two waypoint flags); `ch2_cinder2` —
   assay the recovered seal with Vessa (one prop + report). Main-quest
   strings + standing, the arc-1 pattern continued so the ch2 desks
   don't dead-end.

Also: ch2 has **no resonance/dead-end/social rooms today** — the retrofit
adds the room classes; the standard shrine/lore-prop/cache population
comes free with them. That, plus this slate, closes ch2's "reward hole"
from the content side while the graph closes it from the layout side.

---

## 2. The Capital — three layers over the same 9 rooms

The measured hole: zero journal quests, the 4 ward "contract desks" open
an empty journal, favor is earned at 2 of 16 NPCs and buys only a bench
discount, and the 3 intro quests exhaust in five minutes. The fix is
three layers, smallest first, each shippable alone.

### Layer 1 — Ward Contracts (the daily "honest work")

A rotating contract board per ward desk — finally making the desks real.
- **2 contracts/day per ward**, seeded off `daily_day_index()` (bounty
  law: relogging can't reroll). Contract types are DEEDS, not kills —
  they piggyback on flags the game already sets: *clear the weekly
  chapter's first boss*, *bank a Vigil boss*, *lay flowers at a named
  chapter prop* (a courier step into live content), *salvage 3 items*,
  *socket a gem*. Each = one flag check + turn-in at the desk.
- Pays: gold (daily-scaled), the ward's faction **standing +1**, and
  **trainer favor +5** where the ward hosts a trainer (Kesh in Accord
  Commons; Petra/Lapidary/Suli count as the Plaza "ward"). This is the
  favor faucet PROFESSIONS.md §4 assumes.
- Cap: 4 contract turn-ins/day account-wide (a coffee-break loop, not a
  chore list). Renown: none (standing and favor are the point;
  Renown's budget stays untouched).

### Layer 2 — Personal chains (the cast becomes people)

One 3-step chain per key NPC, gated on act progress and favor tier,
using `cap_` kept flags (persistent by construction — capital quests
must survive chapter wipes; the run-scoped side-quest engine gets a
`persistent: true` field, §3). Rewards: gold + a keepsake + one line of
the city's story each. The slate:

- **Petra — "A Blade Worth Naming"** (3 steps across Act 1→2): the sword
  she's forging for nobody. Doubles as the Blacksmithing rank-quest
  spine. Final step reveals she's Elara's aunt — the ch10 vessel is HER
  blood (`cap_petra_elara` kept flag; the ch10 finale reads it for one
  devastating door line).
- **Keeper Nix — "What the Tankard Hears"** (repeatable frame, 1
  rumor/week): Nix sells nothing but knows everything; each week's rumor
  points at the live weekly systems (the Waking chapter, the day's
  Vigil) with one flavor line — the tavern becomes the calendar's voice.
- **Old Fenna — "The Names of the Fire"** (3 steps): she's forgetting;
  bring her the names of the dead from three chapters' grave props
  (retroactive-accept — most players have seen some). Ends in the
  hearth's memorial page in the journal's STORY tab.
- **Clerk Voss — "The Alms Ledger"** (2 steps): where does the alms gold
  go? A small embezzlement fork: report him (standing +, he's replaced
  by a colder clerk — the daily desk's flavor changes forever) or keep
  his secret for a cut (−8 resonance, `cap_voss_kept`).
- **Marshal Corin — "The Drill Yard"** (3 steps): tiered combat drills
  in the yard (the trial-arena pattern from the awakening quests,
  capital-hosted). Pays favor + a wardrobe token, not power.
- **Ward leads (Callis / Ilse / Maren / Aldric+Vessa)** — one 3-step
  chain each, telling their faction's Act 2 stake from inside the city
  (Maren's volunteer lists; Vessa's manifest of "components"; Ilse's
  schism sermons; Callis's cure-seeker manifests). Each chain's final
  step writes one kept flag Act 2's faction content reads — the capital
  becomes where allegiance is LIVED between chapters.

### Layer 3 — The city thread: "The Crown Below" (one chain, act-gated)

A slow 5-step chain about Crownfall itself: the city is built on the old
imperial capital, and the undercity remembers the empire that bound six
god-kings, not five. Steps unlock at Act 1 clear / ch10 / ch12 / ch14 /
Act 2 clear, each a short capital scene (no combat) — and the final step
OPENS the Undercroft Interlude's door (§4). The capital's own story arc,
telling the player the city was always the sixth seal's town.

### 3. Capital engine needs (small, listed once)

- `persistent: true` on side quests: skips `_wipe_chapter_flags` purge +
  the chapter-deadline warning; capital quests use it.
- Journal surfacing: the QUESTS tab currently filters on `chapter_id` —
  add a CAPITAL section visible everywhere (contracts + active
  chains), since capital quests progress while playing chapters.
- The `cap_q_*` intro trio should migrate onto the engine with
  `persistent: true` so they appear in the journal like everything else.
- Contract seeding: the bounty Fisher-Yates, per-ward salt.

---

## 4. The Interludes — diverging side chapters

The ask: side chapters branching off the Act 1 and Act 2 finales that
reveal other parts of the world. Shape: **standalone chapters out of
`CHAPTER_LIST`** (the capital/arena precedent), 8–12 rooms, authored
spine + 2–3 side rooms, ONE new boss each, 0 XP (ECONOMY §9.1 carries
the counter-question), paying gold/gems on the replay law plus a unique
keepsake + cosmetic. Each is DIVERGENT twice: *which door you get* reads
your kept flags, and *what happens inside* forks on them again.

### Off Act 1 (available after ch7; L40 band)

**I1 — The Undercroft** (`ph_sewer` / `ph_crypt` looks; under Crownfall)
The imperial undercity: drowned archives, the first Concord chamber, and
the masonry that says SIX seals. Entered via "The Crown Below" layer-3
chain — the capital quest IS the unlock. Divergence: your faction
sponsor frames the descent — the Accord sends you for the archive (the
truth about the sixth binding), the Cinderborn for binding-text
fragments (the same rooms, different quest overlay + different final
scene). `chose_ivo_truth` (ch2) gets a payoff scene either way.
Boss: **The Archivist of the Sixth Seal** — an imperial revenant
librarian; council-frame lite (two lectern adds that read buffs onto
it); signature: *Redaction* — it erases one of YOUR abilities from the
bar for 10s at a time (silence's scarier cousin, one slot not all).
Reveals: the sixth god-king consented to the Concord. Seeds the
Chain-Bearer revelation and Act 3.

**I2 — The Moonfen** (`ph_moonfen` / `ph_fae` looks; far west of the map)
The Wildfang holy fen — where beast-blood began; the first "other part
of the world" that is beautiful, not blighted. Unlock: Act 1 clear +
wildfang standing ≥ 2 (the ambient faction finally gates a door).
Divergence on the ch6 outcome: **Kaethra spared** — the fen is in
mourning-hope, cure-seeker pilgrims everywhere, the quests are about
what her survival licenses; **Kaethra killed** — the fen is hunting, the
acceptance camp has won, the same rooms carry funeral rites and a
harder-edged quest overlay. Boss: **The First Howl** — a moon-lit
beast-spirit; signature: *Call the Blood* — players with tempted
resonance fight a harder, faster variant (conviction read as combat
state — the first fight that reads YOUR band as a mechanic; steady
players get the slower, sadder version).
Reveals: the beast-blood was the Root's FIRST cure, ages before the
cure-seekers asked again.

### Off Act 2 (available after ch14; L70 band)

**I3 — The Paper Concord** (`ph_library` look; the Chain-Bearer's archive)
The library-fortress where the Concord was drafted — every clause, every
signature, including the sixth. Unlock: Act 2 clear + at least one true
name learned. Divergence: your true-name CHOICES (shared / hoarded /
destroyed, per name) determine which wings stand open and which
archivist-ghosts will speak to you — a hoarder walks colder halls.
Boss: **The Clause** — a contract elemental (the Debt-Writer's
handiwork); signature: *Terms and Conditions* — the arena posts three
visible RULES per phase ("no standing still >2s", "no ability twice in
a row", "melee range is trespass") and breaking one is the damage —
Aldric's ledger turned into law. Warlock players get unique dialogue:
the Debt-Writer's broker signature is on the last page.
Reveals: the sixth seal's location — Act 3's map.

**I4 — The Ossuary of the First Guard** (`ph_ossuary` / `ph_barrowmoor`)
The Ember Guard founders' tomb — six graves, five bodies. Unlock: Act 2
clear + your class's S-weapon awakening trial done (the founder ghosts
are the door's voice; the missing body is the Erased's). Divergence by
CLASS (your founder walks you in; six different escort voice-tracks)
and by faction for the final chamber's rite. Boss: **The Honor Guard** —
five revenant founders fought as a gauntlet-council (one at a time,
each a compressed echo of a class kit; your OWN class's founder yields
instead of fighting — the game's quietest compliment).
Reveals: what the Erased actually tried to burn — and that the Crown
remembers being worn.

### Interlude rules (shared)

- Optional forever; never on the golden path; the journal lists them
  under a WORLD section once unlocked (the "reveal the world" promise
  needs a visible shelf).
- Replayable for the farm law like any chapter; the STORY beats fire
  once (kept flags).
- Divergent overlays are quest/convo/beat swaps over one room set —
  never two map builds (the ch11 faction-room tech reused; build cost
  stays one chapter each).
- Each Interlude ships with its codex terrain + boss entries and 1–2
  unhomed-content adoptions where they fit (the placeholder pipeline's
  Future-tab stock — e.g. the pc_ scholars belong in the Paper Concord;
  the ossuary can home a placeholder boss body if one reads right).

---

## 5. Open questions for the owner

1. **Interlude exclusivity** — all four earnable in one playthrough
   (proposed: divergence is INSIDE each) vs. hard forks where a choice
   locks one door per run (stronger divergence, replay bait, but cuts
   content per playthrough — scope philosophy leans against).
2. **Moonfen's resonance-read boss** — the first mechanic that makes
   band choice a combat variable. Sanctioned, or does it cross the
   "conviction, not virtue" line? (Both variants are winnable; the
   tempted one is harder AND pays +10% gold — Hunger's own law.)
3. **Contract cap 4/day** and favor +5/turn-in — pace check against
   PROFESSIONS' Confidant wall (~30 turn-ins to rank 4 without
   bench-spend; feels right on paper, needs the sim).
4. **Voss fork** — permanent NPC replacement is the capital's first
   irreversible world-change; cheap to build, heavy to feel. Keep?
5. **Ch2 slate before/after retrofit merge** — land quests with the
   retrofit branch (one review), or trickle the camp-cast quests (1, 2,
   6) onto current ch2 now since they need no new rooms?

## 6. Implementation map

- `content/ch2_quests.gd` — extend SIDE_QUESTS/QUEST_ITEMS (quests 1–6),
  `ch2_factions.gd` arc-2 strings; retrofit-room props ride the
  retrofit module.
- New `content/capital_quests.gd` — contracts pool + personal chains +
  The Crown Below; registration line; `gen_capital.py` gains the desk
  wiring (`ref` → contracts UI) + Suli's stall.
- Engine: `persistent: true` quest field; journal CAPITAL + WORLD
  sections; contract seeding func in `game_base.gd`.
- Interludes: one `content/interlude_*.gd` module each (zones + boss +
  quests + beats), terrains from the ph_* gallery promoted to real
  profiles, `Story.chapter()` resolution, unlock flags as listed;
  codex/BOSS_KINDS same-change.
- Tests: content-module hooks per module; a journal test that capital
  quests survive a chapter cycle; beat-variant assertions for the new
  `@flag:` doors.

> The thesis: ch2 gets its errands, the capital gets its word kept —
> every NPC who promised work now has some — and the Interludes make the
> map bigger exactly where the fiction was already pointing: under the
> city, west of the war, inside the paperwork, and six feet over the
> Guard.
