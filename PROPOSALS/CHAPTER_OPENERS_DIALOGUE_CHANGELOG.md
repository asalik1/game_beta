# CHAPTER_OPENERS dialogue changelog — for the opener-build agent (2026-07-30)

The opener build (`chapter_openers.gd`, commit 586f244) was sourced from
`PROPOSALS/CHAPTER_OPENERS.md` **@2943e90**. Four revision passes have
landed since (owner-driven: canon fix, asker/internal restructure,
false-promise fixes, internal re-voicing). The current doc supersedes the
build's source — this file is the navigation layer for the sync. **The
doc carries the final text; always copy from the current doc section,
never from memory of the old one.**

**Safe to sync mechanically:** convo ids, flags (`ch6_answered_green` is
already correct in the build), resonance values, cue names, and plate
wiring are ALL unchanged. Every delta below is dialogue text.

## 0. The stem policy — the biggest item

The build fills every convo's choice stem with one invented line:
`"Before the first step, the Ember asks what you will make of what waits
ahead."` (repeated in all ~78 convos). This is exactly the tic the owner
rejected — **remove it everywhere** and apply doc §1's two-prompt-modes
rule:

- **PUBLIC chapters (ch3, ch4, ch6, ch7, ch8, ch11, ch12, ch14):** the
  n4 stem is the chapter's named ASKER speaking their quoted prompt —
  `who` = the asker (e.g. ch3's gate-cantor, ch7's Apprentice Sorrel,
  ch14's Elara). Each chapter's asker + prompt is in its "**The asker
  (n4)**" block in the doc.
- **PRIVATE chapters (ch2, ch5, ch9, ch10, ch13):** the n4 stem is the
  INTERNAL trigger text from the chapter's "**The trigger + n4
  (INTERNAL)**" block — `who: "You"` (the build's existing "You" speaker
  is correct here). In these five chapters the TEMPTATION option is the
  vice's voice in CAPS — copy exactly; the caps are the device.

## 1. Per-chapter deltas since @2943e90

**ch2** — spine n1+n2 REPLACED (canon fix: the Crown shattered at the
FIRST fall, thirty years ago, `story.gd:1273`; the player's shard
predates ch1 — the old beats contradicted Vargoth's own line). Internal
trigger added. New n3s for assassin + warlock; archer n3 now has
per-ch1-branch variants (`said_farewell` base / `cut_clean` /
`walked_silent`) plus a `req_flag` note on the deflection. All six
temptation options re-voiced in CAPS (the shard's account of the quiet
years). Maren's echo sample is now class-neutral.

**ch3** — spine n2 reworded (the "begging to die" line returns to Ilse —
verbatim collision). Asker added (the counting-cantor). Assassin
deflection REPLACED — the build still ships "Keep distance…", which
promises the player won't touch the mandatory boss.

**ch4** — spine n2 reworded (the "sermons with verdicts" line returns to
Brann). Asker added (the crew-boss).

**ch5** — internal trigger (the sister offers the pen, silent). All six
temptations re-voiced: five in CAPS, the warrior's deliberately
lowercase — a thought hidden FROM the shard. Copy the case exactly.

**ch6** — spine n2 reworded ("knelt on sight" returns to Vela); paladin
n3's kneeling phrase adjusted; warrior deflection replaced (no false
burn-promise). Asker added (the glad-eyed kneeler). Vela's echo sample
is now stance-neutral — echoes live in the SHARED briefing and must
never name a deed only some classes did.

**ch7** — archer n3 ending reworded (the gate-latch simile assumed one
ch1 branch). Asker added (Apprentice Sorrel).

**ch8** — asker added (the walked-out journeyman).

**ch9** — internal trigger (the map-runner's corrected chart). All six
temptations re-voiced (five CAPS; warlock's is lowercase with the tome
slamming shut on his hand). All six deflections reworded — the old ones
promised flooding/sealing the game never shows; new ones are
manner-of-passage. Spine conditional beat is explicitly keyed to
`chose_kaethra_sheathed` / `chose_kaethra_struck` — verify the build
reads those flags.

**ch10** — internal trigger (the singer's question answered on the climb
down, not to her face). All six temptations re-voiced in CAPS. Mage n3
softened (same-era receipts, not same-date causation).

**ch11** — spine n2: Aldric is now recognized ("the grey knight who
shared Maren's fire in the refugee years"). Warlock n3: THIRTY years,
not forty (`story.gd:1273`; the bible was corrected too).

**ch12** — all six deflections REPLACED: the finale forces destroying
the five hearts, so every containment-and-walk-away promise was a lie;
new deflections do the killing without letting it mean anything.
Assassin n3 gains the relay-contrast clause.

**ch13** — internal trigger (mouthing storm-words without choosing to).
All six temptations re-voiced in CAPS. Archer n3: the summit line no
longer says "a chapter ago."

**ch14** — warrior n3 softened (a fitting, not a crown-claim — the
temptation option keeps the strong version; temptations may lie). Asker
added: ELARA at the causeway's foot ("That is my mother's walk it is
wearing…"). Her plate change is in the plate changelog
(`opening_ch14_1`).

## 2. Also check in the build

- **Echo tiers:** wherever briefing `b1` variants were added from the
  doc's samples, re-check against the current samples — the old ch2
  (scorch-hands) and ch6 (empty-your-pockets) echoes were replaced with
  class-neutral lines.
- **Briefing trim (§7):** owner-approved, lands WITH the opener build.
  If the build didn't trim the six briefings' `b2` world-recap, apply
  §7's keep/lose spec in the same change.
- **The internal-mode `who`:** internal stems stay `"You"`; public stems
  must NOT be "You" — they are the asker's line.
- Gates per CLAUDE.md after the sync: compile gate → `test_quick` →
  full `test.bat` before staging.
