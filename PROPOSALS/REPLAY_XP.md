# Replay XP — the grey-mob rule (2026-08-17)

Owner: *you have to complete a chapter to get XP, and after that the same
chapter never pays again — that shoots replayability in the foot. In most
MMORPGs, if you lack the stats for a hard chapter you go back and grind an
earlier one for XP or loot; it isn't a one-way trip. And if you're skilled
you can clear the next chapter early anyway.*

**Status: owner-approved and BUILT 2026-08-17** (`Balance.REPLAY_XP_OVER` 3 /
`ACT_XP_CAP` 40 / `replay_xp_mult` / `replay_xp_reach`, `Story
.chapter_parity_level`, `player_core.gain_xp`, replay picker + results card +
codex Records + once-per-run toast, `econ_audit` REPLAY line, autotest pins;
standing rule promoted to DESIGN.md "Fixed chapter XP", round logged at the
top of BALANCE_HISTORY.md). §0–§4 below are the design record; §5's open
questions were resolved by taking the recommendations (OVER 3, linear
taper, tiers zero-XP, the reach printed in the replay picker AND codex).
Companion to DYNAMIC_WORLD.md (why revisit a chapter — this doc is the XP
half of that question).

---

## 0. What the code does today

- `player_core.gd:2812 gain_xp()` — returns before adding XP when
  `completed_<chapter_id>` is set (comment: playtest round 3, "clear ch1
  2000 times, come out max level"), and when `run_tier() > 0` (NG+ pays no
  XP). Autotest pins both (`autotest.gd:203-206`, `:6694`).
- **Correction to the premise:** the shutoff is *completion*, not
  *non-completion*. An UNCOMPLETED chapter pays XP on every attempt —
  re-enter it from the way-gates, die and retry (the 10% death tithe,
  `Balance.DEATH_GOLD_TITHE`, is the only brake). So the frontier IS
  grindable today; everything behind you is not. The moment you clear a
  chapter, its XP faucet is gone forever.
- Elites (`enemy.gd:1639`), event spawns, summons pay zero regardless —
  the fixed-budget rule; unaffected here.
- Chapter parity = the finale boss's level: **ch1 10 · ch2 16 · ch3 22 ·
  ch4 28 · ch5 33 · ch6 37 · ch7 41.** Talent tree fills at 40 (points ==
  level, DESIGN.md:140).
- Doctrine this changes: DESIGN.md:135 "completed chapters pay NO XP on
  replay (farm gold/gear, never levels)"; DESIGN.md:198 "XP = story
  currency, first run only … farming can't outlevel the story".

## 1. What the rule protects (keep all of it)

1. **Parity.** Every boss is tuned at its level (TTK band 40–90 s on the
   DPS king, DESIGN.md:142). Unbounded replay XP would let a farmer arrive
   +10 and trivialize the band.
2. **The tree.** Points == level, fills exactly at 40 at ch7's close.
   Overleveling early spends the last chapters with a done tree; levels
   past 40 have no home until Mastery (DESIGN.md:189: "nothing past L40
   grants XP today, so the points don't yet go dead").
3. **No downscaling.** Mobs never scale up to you before endgame, so
   over-level = content goes limp.
4. The round-3 fear was **unbounded**: ch1 → max level.

The current answer over-corrects: it removes the faucet instead of
bounding it. The MMORPG the owner is describing does NOT hand out
unbounded XP either — WoW's own fix is the **grey mob**: mobs well below
you pay nothing; going back to grind works until you outgrow the zone,
then it dries up on its own. A ceiling, not a shutoff.

## 2. Proposal — replay XP with a parity ceiling

**Rule.** A completed chapter pays FULL XP while `level < parity(ch)`,
tapers to zero across `parity … parity + REPLAY_XP_OVER`, and never pays
past `ACT_XP_CAP` (40 until Mastery lands). Uncompleted chapters and NG+
tiers unchanged (tiers stay zero-XP in v1 — Nightmare unlocks after ch7,
when you're ~40, so the cap makes tier XP moot; unify when Mastery lands).

**Knobs (first guesses):** `Balance.REPLAY_XP_OVER := 3`,
`Balance.ACT_XP_CAP := 40`. `OVER` is the whole dial: **0** reproduces
today's rule; **3** = recommended (a stuck player climbs to ~3 over the
chapter behind them, which is roughly the NEXT chapter's opener level);
**~6** = "grind the previous chapter all the way to the next chapter's
finale" (chapters sit 4–6 levels apart). One constant to move after the
playtest.

**Reach with OVER = 3:** ch1 pays until L13 · ch2 19 · ch3 25 · ch4 31 ·
ch5 36 · ch6 40 · ch7 40.

**What it fixes**
- The stuck player: replay the chapter behind you for XP + loot until
  it goes grey; the frontier then out-pays it in XP as well as gold — the
  "frontier always out-pays" doctrine (DESIGN.md:199) finally holds for
  both currencies instead of one.
- First-runners who skipped side rooms and arrive under parity
  (`xp_needed()`'s comment already admits the curve assumes side rooms,
  `player_core.gd:1594`) get a road back.
- At-parity players see the bar move a little on the first replay, so a
  replay never reads dead. (The loot half of grind-back already exists:
  replay g/min 1.3–1.5× first run, gems flat-count/rising-quality,
  boss-band gamble — nothing to add there.)

**What it keeps.** Overlevel is bounded at +3 vs the chapter behind you
= ≤ +3 vs the next chapter's first boss and ≈ 0 vs its finale; the tree
still fills at 40 and no point goes dead; the round-3 exploit is bounded
by construction (ch1 → 13, forever). Bosses' TTK band shifts at most
~15% for the first boss of a chapter and not at all for its finale.

**Co-op.** `host_award_xp` fans the raw amount today (`enemy.gd:1950`);
the multiplier applies on the RECEIVING player's `gain_xp` (per-player
level, per-player `completed_`) exactly like the current early-return.

## 3. Legibility — the felt half (the owner's real point is motivation)

- Replay picker / way-gate card: **"XP pays until Lv N"** per chapter,
  grey once you're past it — the reason to revisit is printed on the door.
- First capped kill in a run: one floating "+0 XP — you've outgrown this
  road", then quiet for the run.
- Results card: an XP line ("+N XP · Lv a → b") beside gold.
- Codex Records "Chapters" card shows each chapter's parity level.

## 4. Implementation (small; one measured round)

- `Story.chapter_parity_level(chid)` = `ALL_ENEMIES[chapter.final_boss].level`
  (the incursion roster already derives exactly this, `game_world.gd:588`).
- `Balance.replay_xp_mult(level, parity) -> float` (linear taper, or
  `soft_cap` shape — §5); `gain_xp` multiplies instead of returning; keep
  the tier early-return.
- Autotest: rewrite the round-3 pin (`autotest.gd:203-206`) as three
  asserts — full below parity, zero above parity+OVER, zero at/after
  `ACT_XP_CAP`; the NG+ zero-XP pin stays.
- `econ_audit.gd`: add an "XP/min under parity on replay" column so the
  round is measured, not felt.
- On ruling: rewrite DESIGN.md:135 / :198 to the ceiling rule; log the
  round at the top of BALANCE_HISTORY.md.

## 5. Open questions
1. `REPLAY_XP_OVER` — 3 (recommended) or 6 (previous chapter reaches the
   next finale)?
2. Taper shape — linear over 3 levels, or the `Balance.soft_cap` knee?
3. Tiers stay zero-XP in v1 — agree, revisit with Mastery?
4. Show "XP pays until Lv N" on the way-gate card, or only in the replay
   picker?
