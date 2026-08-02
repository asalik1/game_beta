# The Seal Vigils — weekday rotating dungeons, 3 bosses each (2026-07-27)

The "daily dungeon" pillar: five compact dungeons on a Monday–Friday
rotation, each themed to one god-king's seal, each with its own three-boss
lineup. WoW's daily-heroic loop (one door is THE door today) fused with
Crownless fiction. Nothing here is installed; decision document.

Relationship to existing modes: the Crucible is the sprint, the Depths is
the marathon, Incursions are the weekly overlay — the Vigils are the
**15-minute daily loop**: short, dense, a fixed lineup you learn by heart
and race, rotating so no single one wears out.

---

## 1. The fiction

The Concord was spoken over five days — one seal bound per day, one god-king
per seal. Six hundred years later the seals still remember their day: each
strains hardest on the weekday it was bound. The Wardens keep **Vigils** —
standing watches at the five places where the strain shows — and after Act 1
(the Storm Tongue's crack) the watches have become fights. Each day,
Crownfall's Wayfinder Sanctum opens the door to the seal that strains today.

| Day | Seal | Vigil | Terrain blend |
|---|---|---|---|
| Monday | The Molten Judge | **The Smolder Court** | magma + keep |
| Tuesday | The Still Queen | **The White Vigil** | ice + crystal |
| Wednesday | The Pale Root | **The Green Dark** | bog + spore |
| Thursday | The Storm Tongue | **The Speaking Spire** | storm + void |
| Friday | Mórwyn, the Hollow Flame | **The Ashen Hospice** | graveyard + holy |

**Weekends:** Saturday/Sunday all five doors stand open (the seals rest; the
Wardens drill). The daily bank (§6) still pays once per day — weekend days
let you pick which Vigil's bank to claim, and are the catch-up window.

---

## 2. Structure

Six rooms, authored coords (no seeded layout — a Vigil is a memorized race,
the anti-chapter). Standalone chapter ids (`vigil_judge` … `vigil_morwyn`),
resolved by `Story.chapter()`, kept OUT of `CHAPTER_LIST` (the
capital/arena precedent).

```
[Watch Post] → [Approach] → [First Ward] → [Gallery] → [Second Ward] → [The Seal Door]
   safe          combat        boss 1       combat        boss 2         boss 3
```

- **Watch Post:** Warden NPC (flavor + the day's modifier stated in words —
  NO SILENT EFFECTS), alembic access (potion loadout), no merchant (stock
  in the capital, one room away — the capital is the town, the Vigil is the
  run).
- Combat rooms: 3 packs each + 1 elite ambush roll. Locks: doors seal on
  the purge rule as usual; boss doors are `clear`-locked.
- Target run length: **12–18 min** at-band. First run of a Vigil ~25 min
  (learning), the race floor ~10 (the PB track wants daylight between
  first-clear and mastery).
- No mid-run merchant, no XP, no checkpoints — die and the run resets to
  the Watch Post (the run is short; the death cost is the retry, plus the
  standard gold tithe).

## 3. Rotation, clock, seeding

- Day index = `daily_day_index()` (trusted clock — the daily-reward rule;
  no OS-clock rerolls). Weekday = `day_index % 7` mapped with a fixed
  epoch offset so Monday is Monday.
- The day's **modifier** (§5) seeds off `day_index` (bounty precedent), so
  every player faces the same exam — comparable PBs, shared table talk.
- Entry: the Wayfinder Sanctum gains a fourth portal, **the Vigil Gate**
  (gen_capital.py change). Unlock: first Crownfall arrival (i.e. Act 1
  ch1 clear — same gate as the capital itself). The Vigils are the
  post-campaign daily loop but also a mid-campaign gear supplement at
  Watch tier (§4) — deliberately: they teach boss grammar early.

## 4. Scaling — fixed content levels, tier-selected

Depth-== -content-level doctrine: one ladder, comparable for everyone. A
Vigil fights at a fixed level per tier, reusing the difficulty-tier
infrastructure (`run_tier` snapshot; endgame-style forced tier stays OFF —
Vigils DO honor tier choice):

| Tier | Name | Content level | Gate |
|---|---|---|---|
| 0 | The Watch | L42 | Crownfall unlocked |
| 1 | The Long Watch | L62 | Nightmare unlocked (`tier_unlocked_1`) |
| 2 | The Last Watch | L82 | Torment unlocked |

Mobs/bosses spawn at the tier's content level through the normal
`enemy_stats_at` path (no downscaling issues: all Vigil kinds are authored
at ≤L42 anchors). Bosses are budget-pinned per tier like Depths bosses
(`Balance.vigil_boss_pool(tier)`) so the 3-boss lineup lands the same TTK
targets at every tier: ~20s, ~25s, ~35s (Vigil bosses are one phase — the
short-form format).

## 5. The day's modifier

One seeded modifier per day, stated in words at the Watch Post. Pool =
the six live affixes applied Vigil-wide to elites + bosses (not trash), plus
Vigil-only modifiers:

- **Strained Seal** — one extra hazard family from the Vigil's terrain runs
  its event at elevated interval.
- **The Long Litany** — bosses +1 add wave; trash −20% (the fight moves to
  the bosses).
- **Wardens' Drill** — PB pace: gold +15%, but the death tithe doubles.
  Opt-in greed, Gold-Rush adjacent.
- **Waking Bleed** — one mid-pack per room spawns as a compound (two-trait)
  mob — the ch14 spawner reused.

Exclusion rule: modifiers never stack with themselves across tiers (same
modifier all three tiers that day — one exam, three weights).

---

## 6. Rewards — the faucet-one-job answer

Repeatable runs pay **like a chapter replay at the tier's band** (the
endless-mode rule verbatim: same g/min curve, flat-count/rising-quality
gems, no XP ever). The Vigils add exactly one new thing, the **daily
bank** — the time-gated faucet doing its one job ("why log in today"):

- **First full clear per day** (any Vigil, any tier): the **Vigil Cache** —
  one gear roll at the tier's chapter-band (Watch = ch7-band, Long Watch =
  ch7+4 shifted, Last Watch = ch7+8 — the `tier_chapter` shift reused), a
  Lv3 gem (Lv4 at Last Watch), and a materials satchel (professions
  faucet — see PROPOSALS/PROFESSIONS.md; until professions land, the
  satchel slot pays gold).
- **+5 Renown** with the daily first-clear, capped at 5 Vigil claims/week
  (≈ +25/week onto the ~180 engaged-week income — needs the owner's nod,
  it's a real bump to the Renown budget).
- Per-boss on ANY run: 1 gem (the boss-gem rule), gold on the replay
  curve. Nothing else repeats — the bank is once daily per account
  (trusted-clock, `vigil_bank_day` meta key, the incursion banking
  pattern).
- **Records:** per-Vigil per-class PB time at each tier
  (`pb_vigil_<seal>_<cls>_t<N>`), a Records shelf row, and a "all five
  Vigils cleared this week" achievement track. PB-delta Renown is NOT
  extended here (Crucible/Depths keep that identity).

Explicitly NOT: no new currency, no Vigil-exclusive gear tier, no
S-guarantees (the drop ladder stays owned by chapters/tiers — the Vigil
Cache rolls inside existing bands).

## 7. Co-op

Party-town flow: the party gathers in Crownfall, the host opens the Vigil
Gate, ready-check (named-content ready-check reused). Vigil rooms are
standard rooms — no new sync surface beyond the new mob verbs (which ch8+
needs anyway). The daily bank pays per-account per-day: each head banks
their own cache on a shared clear (incursion precedent). Solo-first ship is
acceptable (incursions shipped solo-only); flag co-op as the fast-follow.

---

## 8. The five Vigils

Each: terrain notes, mob flavor (kinds drawn from the Act 2 roster + Act 1
alumni — Vigils REUSE mob art/verbs; only bosses are new), three one-phase
boss kits. All bosses honor the floor rule; grammar speeds as standard.
15 new bosses total, each ONE signature — WoW dungeon-boss density, not
raid density.

### Monday — The Smolder Court (Molten Judge · magma + keep)

An assize hall where the Judge's verdicts leak into the masonry. The
fiction: the court still holds session; nobody living is on the bench.
Mobs: Foundry Thrall, Slag Hound, Verdict Drone, Bellows Imp (+ keep
skeletons at Watch tier).

1. **Bailiff Kettle-Iron** — construct bailiff, melee, phys.
   *"It maintains order. It has not been told court is out."*
   **The Docket (signature):** brands a player with a countdown seal (8s).
   Discharge it safely by standing in the marked DOCK circle before it
   pops; pop anywhere else = heavy AoE on your position. The WoW
   debuff-walk (Defile discipline) in one mechanic. Support: aimed gavel
   throws (floor), a slam ring. Co-op: brands rotate targets.
2. **The Perjurer** — twin flame wraith, ranged, magic.
   *"It testifies in fire. Half of what it says is true."*
   **False Witness (signature):** telegraphs arrive in PAIRS — one real,
   one illusory; the lie has the Vess-decoy flicker. Every 3rd pair, both
   are real. Reading the tell under time is the whole boss. Support:
   verdict-third slice at 50% (one cast, the ch8 grammar cameo).
3. **Magistrate Vhorr, the Recused** — finale, caster, magic.
   *"He recused himself six hundred years ago. The Judge never accepted."*
   **Session / Recess (signature):** alternates 12s SESSION (half-arena
   verdicts + brand fans — the Ashpriest exam at dungeon weight) and 8s
   RECESS (he seals himself in the bench; two Forge Constructs — the ch8
   add pair — take the floor; revive/reposition window by design).
   **Objection:** during Session he winds one 2.5s gavel channel —
   landing any heavy hit staggers him 3s (+damage window; the concussion
   conversion made into a mechanic). Floor: brand fans reach everywhere.

### Tuesday — The White Vigil (Still Queen · ice + crystal)

A monastery of the Long Sleep, ice-bound mid-prayer. Mobs: Chorister of
Frost, Glasshide Stalker, Rime Wolf, Sleepwalker.

1. **Warden Alba** — frost sentinel, melee, phys.
   *"She took the watch so the others could sleep. She is still taking it."*
   **Last Breath (signature):** exhales expanding stillness zones —
   standing in one builds Drowse fast; the zones drift (spore_cloud
   plumbing). Keep moving or sleep where you stand. Support: aimed ice
   lances (floor), a frost stomp ring.
2. **The Reliquary of Sleep** — animated vault, stationary, magic.
   *"The monastery's relics dream together. They do not like being counted."*
   **Inventory (signature):** three relic cases open one at a time; the
   open case is the only damage window (the rest of the time it is
   warded). Each case, while open, adds its own attack to the rotation
   (candle volleys / deep_freeze seeds / a shard ring) — and the attack
   PERSISTS after its case closes. The fight accumulates. Floor: candle
   volleys are aimed.
3. **Mother Superior Iness, Voice of the Long Sleep** — finale, caster.
   *"She sings the Queen's half of the duet. Do not learn your part."*
   **The Lullaby (signature):** every 20s an arena-wide sleep pulse with a
   4s wind-up — ANSWERED by standing on one of three wake-crystals
   (resonance crystal props; each crystal burns out after one use and
   regrows 30s later). Crystal management under a metronome. Support:
   Flash Freeze with thawed vents at 50% and 20%; aimed lances (floor).
   Council cameo: two Sleepwalker adds at 40%.

### Wednesday — The Green Dark (Pale Root · bog + spore)

A root-choked undercroft where the Wildfang cure-seekers dug too deep.
Mobs: Rootspawn, Anchor Vine, Bloat Leech, Pollen Drifter.

1. **The Tillerman** — root farmer, melee, phys.
   *"Something still works these fields. The furrows are fresh."*
   **The Plow (signature):** entangle furrows advance across the arena in
   parallel rows (line telegraphs, walking pace) — lane-hopping while he
   pressures melee. Rows wither behind him. Support: aimed thorn lob
   (floor).
2. **Sporespeaker Yem** — beastkin heretic, ranged, magic.
   *"She asked the Root for a voice. It gave her a chorus."*
   **Chorus (signature):** summons 3 puffball pods (root_anchor verb);
   while any pod lives her casts echo from each pod (the Harmony chain at
   dungeon scale). Pods are soft; the question is dropping them while
   dodging the multiplied pattern. Support: drowse clouds; venom fans
   (floor).
3. **The Seedmother** — finale, spawner, phys + magic.
   *"The Root's answer to a question nobody asked: what if the harvest
   planted itself?"*
   **Clutch (signature):** lays egg clutches on a beat (Yskara lineage,
   denser); each clutch hatches parasite-splitting Rootspawn. Burn
   clutches or drown in halves. **Compost:** any add dying within her aura
   heals her 3% — kill the brood AWAY from her (Rotmaw's lesson as the
   finale's axis; Blight answers the compost). Floor: venom volley at any
   range. This is the Vigil where AoE builds get their day.

### Thursday — The Speaking Spire (Storm Tongue · storm + void)

A Stormwarden listening-tower now transmitting the wrong direction. Mobs:
Word-Wisp, Riftling, Void Hound, Conductor Acolyte.

1. **The First Syllable** — void echo, ranged, magic.
   *"The first thing the Tongue said when it cracked. It has not stopped."*
   **Stutter (signature):** phase_shift on a fixed 1.5s/1.0s meter —
   burst timing and DoT discipline as the exam. Support: storm_word lines
   (floor; silences), a bolt ring on reappear.
2. **Conductor Vael** — lightning duelist, melee, phys + magic.
   *"He conducted the tower's choir. The lightning still takes his cues."*
   **The Baton (signature):** drops a CARRIED rod pickup — while a player
   holds it, Vael's arcs redirect to the holder (who takes reduced,
   steady tick damage) instead of forking randomly at everyone. Passing
   the rod (drop/pickup) rotates the duty. Solo: holding vs dropping is a
   sustain-vs-chaos trade; co-op: a literal hot potato role. The Veyx rod
   made mobile. Floor: unheld arcs fork at everyone, aimed-class.
3. **The Antiphon** — finale, caster, magic.
   *"Call and response. The Spire calls. Get the response wrong and it
   corrects you."*
   **Call-and-Response (signature):** the Spire speaks a word-line
   (storm_word) that also lights ONE of three rune tiles on the floor —
   crossing the lit tile before the next call (6s) answers it; missed
   answers stack **Discord** (+5% boss cast speed each, drops one stack
   per correct answer). The dance-floor boss. Support: aimed forks
   (floor), a void-tear pair that opens at 50% (the fast lane to tiles —
   using it is the mastery read). Silence never applies from calls
   (self-defeating); only from support word-lines.

### Friday — The Ashen Hospice (Hollow Flame · graveyard + holy)

Mórwyn was a battle-healer. This was her hospice; the Choir keeps it
"open." The kindest fiction in the rotation and the nastiest fights.
Mobs: Choir Radical, blight-zombies (grave_spawn kinds), Field
Chirurgeon, Bloat Leech.

1. **Matron Cindra** — hollow nurse, ranged support, magic.
   *"She still does her rounds. Her patients still improve."*
   **Triage (signature):** ward beds around the arena hold "patients"
   (dormant adds); Cindra's heal-channel wakes one bed at a time,
   IMPROVED (one random affix). Interrupt the channel (it is her only
   interruptible cast) or fight her bedside manner. Blight halves her
   channel effect — the ch12 system's tutorial-in-miniature for anyone
   who skipped to Vigils. Floor: censer lobs, aimed.
2. **The Ward of Roses** — living hospice ward, environmental, magic.
   *"The garden ward. The roses are doing very well."*
   No body: a room-boss (Heart-of-the-Root frame, 3 hearts): the
   **Matron Rose** (heals the others), the **Thorn Rose** (aimed volleys
   — the floor), the **Grave Rose** (raises blight-zombies from the bed
   rows). Creeping rose-vine floor denial grows through the fight.
   Three bars, one lesson: the ch12 finale's grammar at dungeon scale.
3. **Chaplain Morr, Keeper of the Last Fire** — finale, caster, magic.
   *"He keeps the hospice candles lit. He has opinions about the dark."*
   **The Last Light (signature):** the arena is DARK (hazard-dark: a
   ticking shadow DoT everywhere) except pools of candlelight. Candles
   burn down (~15s each); standing at a dead candle 2s relights it
   (channel — interrupted by damage). Light management under pressure:
   Morr's bolt fans (floor) chase you across the pools while
   blight-zombies shamble at lit candles to snuff them (body-block
   targeting, the Vow's whisper-adds inverted). At 30%: half the candles
   die permanently — endgame is two pools and a prayer. WoW's darkness
   mechanic (Gorefiend/Dark Beyond) at candle scale.

---

## 9. Why this shape (the design bets, stated)

- **Fixed lineup, rotating door**: chapters are explored, Vigils are
  *practiced*. The rotation prevents burnout on any single lineup while
  keeping each one's mastery arc intact — WoW's daily heroic did exactly
  this and it carried years.
- **One signature per boss**: dungeon bosses are vocabulary drills between
  raid nights. The 15 kits above reuse Act 2 verbs deliberately — the
  Vigils are where the act's grammar gets rehearsed at low stakes.
- **Five seals, five days**: the calendar IS the fiction. No abstract
  "dungeon finder" — the world strains on a schedule and the capital's
  gate room reflects it.
- **Bank once, race forever**: the daily bank keeps the login pull; the
  replay-parity payout keeps farming honest (no faucet double-dipping);
  the PB tracks give the racers a ladder that never expires.

## 10. Open questions for the owner

1. **Renown +25/week** from Vigil banks — accept the income bump, shrink
   it (3/day), or pay zero Renown and let the cache carry the pull?
2. **Watch tier at L42** — entry right after Act 1, or should tier-0
   Vigils band UP with Act 2 progress (L42 → L70 as chapters clear)?
   Proposal: fixed L42 (one ladder doctrine); revisit when Act 2 ships.
3. **Weekend rule** — all five open (proposed) vs. Sat = player's-choice +
   Sun = "the Sixth Vigil" (a scrambled remix lineup, future content
   hook). The sixth-seal fiction (the Chain-Bearer's revelation) makes
   Sunday narratively loaded — parked as an expansion hook either way.
4. **Vigil Cache gear band at Watch tier** (ch7-band proposed) — too rich
   next to first-clear mail? Alternative: ch6-band until Act 2 exists.
5. **Solo-first ship** (proposed, incursion precedent) vs. holding for
   co-op sync in the same release.

## 11. Implementation map

- `story.gd` — five `vigil_*` chapter defs (authored coords, 6 rooms,
  `"endgame": false`, out of CHAPTER_LIST) + boss/mob entries; or one
  content module per Vigil under `content/` (preferred: five modules +
  registration lines, per multi-agent etiquette).
- `balance.gd` — VIGIL_* block: tier levels, boss pools, cache tables,
  modifier pool, Renown knob.
- `game_base.gd` — `vigil_today()`, `vigil_bank_day` meta, modifier
  seeding (bounty pattern).
- `gen_capital.py` — the Vigil Gate portal in the Wayfinder Sanctum +
  Warden NPC; regenerate capital_hub.gd.
- `endgame.gd` or a new `vigils.gd` UI module — entry flow, tier select
  (reuse the replay tier picker), results card w/ PB.
- New bosses: 15 `match kind` blocks in boss.gd reusing §10 primitives
  from ACT2_BOSS_KITS.md — the Vigils should land AFTER ch8–10's verbs
  exist (build order: ch8 slice → Vigils Mon–Wed → ch11+ → Vigils
  Thu–Fri).
- Codex: a Vigils shelf (terrain/boss entries; BOSS_KINDS additions);
  Records rows; achievements track.
- econ_audit: a vigil preset measuring g/min at all three tiers before
  the cache numbers are frozen.

> The Vigil thesis: the Crucible asks how hard you can hit, the Depths ask
> how long you can last, the Vigils ask how well you know the fight — five
> exams, one per day, same paper for everyone, and the bell rings at
> midnight.
