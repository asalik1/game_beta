# PvP balance — the one-shot problem and the durability conversion

Working proposal, drafted 2026-08-06. Investigation is measured and current;
the design section is a draft for owner red-pen. Sits on top of the PvP v1
duel system (MULTIPLAYER.md §11, `pvp.gd` / `player_combat._hit_rival` /
`net_session.pvp_strike`). Knobs live in `balance.gd` under the pvp-duels block.

---

## §0 — Decisions locked (owner, 2026-08-06)

The single source of truth for this doc's rulings. Do not re-litigate.

1. **TTK feel: ATTRITION.** A basic-attack duel should take ~12–18 connecting
   basics (~10–15 s with dodging/kiting). Sustain, cooldown-trading and
   positioning decide fights, not the opening hit.
2. **Healing: NOT nerfed in PvP** (owner 2026-08-06, reversing an earlier 0.5×).
   A flat heal cut hit the most heal-reliant kit — the paladin's holy mend —
   hardest (sim: removing it lifted paladin 26→37%), and toughness already dilutes
   lifesteal on the ×N bar; prompt death (see §9) prevents sustain stalemates.
   `PVP_HEAL_MULT` kept as a 1.0 dial for future re-tuning. Potions stay barred (v1).
3. **No hard one-shot clamp.** Fix the ratio with the durability dial alone;
   accept that a landed Meteor / big crit can still take a glass target to the
   brink (and, through prior chip, occasionally finish them). No per-hit % cap.
4. **Executes stay.** The low-HP damage *amps* (Coup de Grâce, blood_amp) remain.
   (Note: the rival path already carries **no hard instakill-execute** — the
   gold-gated Hunger execute is deliberately enemy-only, `_hit_rival` §comment.)

---

## §1 — The problem, measured

At **god-roll L100** (the dev-roster "Perfect L100": S gear, Lv10 gems, +20
smith, reforge-chased — `BenchBuild.PRESETS.perfect100`), **almost every class
one-shots almost every other class with a plain basic attack, no crit needed.**

Reproduce: `godot --headless --path game res://scenes/pvp_probe.tscn`
(`scripts/tests/pvp_probe.gd` — a throwaway instrument, builds the roster and
runs real hits through `_hit_rival → pvp_strike → take_damage`).

**The roster (a1 = the spammable basic):**

| Class | Max HP | current ATK | a1 coeff | Basic hit | Basic crit |
|---|---|---|---|---|---|
| Warrior | 2304 | 3875 | 1.00 | 3875 | 5813 |
| Archer | 1486 | 3281 | 0.85 | 2789 | 5020 |
| Mage | 1278 | 3436 | 1.50 | **5153** | 7730 |
| Assassin | 1382 | 3653 | 1.20 | 4384 | 7452 |
| Paladin | 2100 | 3377 | 1.00 | 3377 | 6079 |
| Warlock | 1382 | 3334 | 0.50 | 1667 | 2501 |

**Basic-attack damage as a share of the defender's full HP bar** (non-crit /
crit; `***` = one-shot from full at current `PVP_DMG_MULT = 1.0`):

```
atk\def     warrior   archer    mage    assassin  paladin  warlock
warrior       92/137**  261/391*** 303/455*** 280/421*** 119/178*** 280/421***
archer        66/119**  188/338*** 218/393*** 202/363***  86/154**  202/363***
mage         148/221*** 347/520*** 403/605*** 373/559*** 138/207*** 373/559***
assassin     104/176*** 295/501*** 343/583*** 317/539*** 135/229*** 317/539***
paladin       97/174**  227/409*** 264/476*** 244/440***  90/163**  244/440***
warlock        48/72    112/168*** 130/196*** 121/181***   45/67    121/181***
```

Headline pair (the owner's report):
- **Mage Firebolt → Archer: 347%** of the archer's HP in one non-crit hit (3.5×
  overkill). Crit: 520%.
- **Archer Quick Shot → Mage: 218%** (2.2× overkill). Crit: 393%.

Only the warlock's Shadowbolt (0.5 coeff — a DoT/curse class, correct identity)
fails to one-shot the two plate-ish classes, and still kills them in 2–3 hits.

**Bursts are far worse** (single hit, god-roll):

| Ult | Raw hit | vs a 1300-HP mage |
|---|---|---|
| Mage Meteor (10.0 coeff, 25% true) | 34,360 | 27× the bar |
| Warlock Void Rift (6.5, always-crit cursed) | ~32,500 | 25× |
| Paladin Conviction (2.2) | 7,430 | 5.8× |
| Assassin Death Mark (1.3, **true**) | 4,749 | 3.7× + low-HP amp |

---

## §2 — Root cause (one sentence)

Endgame god-roll gear puts **100% of its reforge budget into offense** (subs are
only ATK% / crit / pen / DEX — `BenchBuild.godroll_item`), so at L100 effective
HP is just the bare class curve (~1300–2300) while ATK inflates to ~3300–3900 to
punch through **PvE boss** armor and HP pools. PvP has neither armor nor a big
pool, so PvE-calibrated damage instantly deletes PvP-calibrated (base) HP.

Confirmed: god-roll gear added **exactly 0 HP** and **~0 resistance** to the four
glass classes. The lone existing dial, `PVP_DMG_MULT`, is resist-agnostic and
scales true damage and basics identically — it cannot fix the ratio without
turning every fight into the same slog.

---

## §3 — The fix: three PvP knobs, no clamp

All three live behind `game.pvp_active`, so **PvE is byte-for-byte untouched.**

### 3.1 Durability — `PVP_TOUGHNESS` (the main dial)

An **effective-HP multiplier** applied in `player_core.recalc`, at the very end,
*after* the HP→power unique conversions (worldroot/lastpulse atk, glove_bulwark
hit-flat) have already read the base pool:

```gdscript
# end of recalc(), after uniq_hp_atk / uniq_hit_flat are computed off base HP:
if game != null and game.pvp_active:
    max_hp *= Balance.PVP_TOUGHNESS
hp = clampf(max_hp * hp_frac, 1.0, max_hp)
```

Why HP-multiply and not a damage-divisor:
- **Covers true damage for free** — Meteor's 25% and Death Mark's 100% become a
  fraction of the big bar, no special case. A resist-based durability buff would
  miss them entirely.
- **Auto-dilutes lifesteal correctly** — attacker heals `dmg × ls` on their *own*
  ×N bar, so the lifesteal fraction shrinks by N with no extra code, then §3.3
  trims it further.
- **Keeps %-heals proportional** — Nova's "20% missing", Conviction's "10% max"
  stay meaningful on the big bar, then §3.3 scales them to taste.
- **Reads honestly to the player** — "you have far more health in a duel." The
  bar shows the real inflated pool.

**Recommended: `PVP_TOUGHNESS = 35.0`** (see §4). Sane range 30–40.

### 3.2 Damage — `PVP_DMG_MULT` (fine-tune, keep at 1.0)

The existing outgoing scalar in `_hit_rival` (and the DoT forwards in `pvp.gd`).
Leave at **1.0** — the toughness dial carries the whole shift. Kept as a second
lever only for cheap global "everyone hits a little softer/harder" nudges without
touching the durability math.

### 3.3 Healing — `PVP_HEAL_MULT` (dial, currently 1.0 = no nerf)

Owner call (§0.2): **healing is not nerfed in PvP.** The scalar exists as a dial
at **1.0** (a harmless ×1.0) so it can be re-tuned without a code change. Wired at
two sites for when it's used: `gain_hp` (discrete/percentage heals — Nova,
Conviction mend, regen, second-wind) and `_hit_rival` (the lifesteal write). Why
1.0 and not 0.5: a flat cut hits the paladin's holy-mend identity hardest (sim:
0.5→1.0 lifted paladin 26→37%), and toughness (§3.1) already dilutes lifesteal on
the ×N bar, so runaway sustain isn't the risk once death is prompt (§9).

### 3.4 No clamp

Per §0.3. The math below shows why it isn't needed for *basics*: at toughness 35
even the mage self-mirror (the worst basic) is ~9 hits. The residual is **burst**
(Meteor lands ~77% on a mage) — a deliberate, accepted swing.

### 3.5 Melee-res grant — `PVP_MELEE_RES` (the League melee/ranged comp)

The durability lever (§3.1) lifts everyone's pool uniformly, so it does nothing
for the class-specific problem §9 surfaces: **melee eats poke it can't answer
while closing.** The League fix is baseline armor/MR for melee; the direct analog
here is a **PvP-only physres+magres grant**, scaled by how much a class must eat
poke to *reach* its target:

| Class | grant | ≈ poke DR | why |
|---|---|---|---|
| warrior, paladin | **+90** | ~43% | pure bruisers — walk in, no ranged option |
| assassin | **0** | 0% | gap-closes with i-frames (Dash, Death Mark) — never eats the kite; and it's already the S-tier problem |
| archer, mage, warlock | **0** | 0% | they *are* the pokers |

Applied in `recalc` under `pvp_active` (adds to `physres`/`magres` before the
res curve). **True damage bypasses it** — Death Mark still punches a bruiser's
armor, so the assassin keeps its counter to plate.

Measured effect (`--meleeres` on both benches):
- **Analytic (the poke race):** ~doubles bruiser survival vs ranged — archer→
  warrior 5.0→9.5 s, mage→paladin 3.8→7.1 s. Directly answers "penalized for
  being kited."
- **Sim:** taxes the bruisers' incoming phys poke (Stab/Quick Shot) while true
  damage still bypasses — the intended effect. (An earlier claim that it "curbs
  the assassin 94→91%" came from the pre-death-fix runs; see §9 for the corrected
  matrix, where the assassin sits at 69% and the melee-res effect is smaller.)

**Scope note:** this fixes the *"poked down"* half of the melee/ranged problem,
not the *"can't catch the kiter"* half (warrior→mage stays a long chase in the
analytic model). The closing half is already covered by the kit — gap-closers +
stun, and CC now crosses the wire (`_hit_rival`) — which the sim shows is enough
to win once melee connects. So melee-res + existing closing tools together, no
new catch lever needed.

---

## §4 — Resulting numbers @ `TOUGHNESS 35, DMG_MULT 1.0, HEAL_MULT 0.5`

**Basic-attack hits-to-kill from full** (non-crit, connecting):

| Matchup class | Into glass (archer/mage/assassin/warlock) | Into plate-ish (warrior/paladin) |
|---|---|---|
| Mage / Assassin / Warrior (top basics) | **9–12** | 12–24 |
| Archer | 14–17 | ~20 |
| Warlock (DoT filler basic) | 24–27 | 60+ (DoTs/Void Rift carry) |

Glass-vs-glass duels land squarely in the **9–17 basic** attrition band the
owner asked for. Into-plate and warlock-basic outliers are longer *by design*
(plate is durable; the warlock kills with Hex/DoT/Void Rift, not Shadowbolt).

**Biggest single bursts** (as % of the inflated bar — none is a one-shot):

| Burst → target | % of bar |
|---|---|
| Meteor → mage | ~77% |
| Void Rift → mage (cursed, always-crit) | ~73% |
| Meteor → archer | ~66% |
| Conviction → mage | ~17% |
| Death Mark → mage (true) | ~11% + low-HP amp |

The scariest hit in the game (Meteor into the squishiest class) leaves ~23% —
huge, game-defining, survivable from full. It *can* finish a target already
chipped; that is the accepted cost of no-clamp (§0.3). If that feels too swingy,
`TOUGHNESS 40` pulls Meteor to ~67% and stretches basics ~15%.

---

## §5 — Implementation plan (current seam)

| Where | Change |
|---|---|
| `balance.gd` (pvp block) | Add `PVP_TOUGHNESS := 35.0`, `PVP_HEAL_MULT := 0.5`. `PVP_DMG_MULT` stays 1.0. |
| `player_core.gd` `recalc()` | Insert the `max_hp *= PVP_TOUGHNESS` line at end, before the hp clamp, after the HP→power conversions (§3.1). |
| `player_core.gd` `gain_hp()` | Multiply by `PVP_HEAL_MULT` when `game.pvp_active` (beside `debuff_heal_in`). |
| `player_combat.gd` `_hit_rival()` | Scale `ls_amt` and the paladin-mend `gain_hp` by `PVP_HEAL_MULT` when pvp. |
| Verify | Re-run `pvp_probe.tscn` (expect the §4 table); `net_test.bat` stage 16 (both strike directions still land, no longer instant); `test_quick.bat` for the recalc/gain_hp touch. |

No RPC/wire change → **NET_VERSION stays 0.3.0**. Mobile re-sync owed after
(`python tools/sync_mobile.py --apply --gate`), per the standing PvP mobile debt.

**BUILT + verified 2026-08-06** (uncommitted). Landed exactly the table above:
`balance.gd` (3 consts), `player_core.recalc` (pvp block, end), `player_core.gain_hp`
(heal scalar), `player_combat._hit_rival` (lifesteal scalar), `pvp._apply_round`
(recalc before revive), `game_flow.teardown_pvp_controller` (defensive revert).
Green: compile gate · `test_quick` (PvE untouched) · `net_test` stage 16 (real
2-peer duel, both strike directions, no errors). Live-code check (pvp_probe
`_verify_live_conversion`): every class max_hp ×35.0; warrior physres 80→170 /
magres 45→135, paladin 50→140 / 75→165, all others +0.

**Shipped values (owner-tuned 2026-08-06):** `PVP_TOUGHNESS 35`, `PVP_HEAL_MULT 1.0`
(healing NOT nerfed, §0.2/§3.3), `PVP_MELEE_RES` 90 for warrior/paladin, `PVP_DMG_MULT
1.0`. The assassin Death Mark PvP amp-cap was **tried and reverted** to the full
0.5 — the corrected §9 matrix showed the assassin isn't oppressive (mage counters
it), so the trim wasn't warranted. These remain the red-pen surface (§7).

---

## §6 — Edge cases (current-code status)

| Case | Status under this design |
|---|---|
| **True damage** (Meteor 25%, Death Mark 100%) | Handled — fraction of the ×N bar; no res needed. |
| **Executes** | No hard instakill in the rival path today (Hunger absent). Low-HP *amps* (Coup de Grâce `execute_dmg` at <40%, `blood_amp`) stay per §0.4 — they're damage amps, not deletes. |
| **Paladin holy = magic** | **Already fixed** by the 2026-08-02 seam refactor — `_hit_rival` forwards the real `dmg_type`, defender buckets non-phys → magres. (Was a proxy bug; retracted.) |
| **CC riders** | Now cross the wire (`apply_stun`/`apply_slow` in `_hit_rival`). In attrition TTK, chain-CC is more oppressive than in a 1-hit meta — **watch item**: consider PvP CC-duration diminishing returns if stun-locks dominate playtests. |
| **Lifesteal / mend** | Full-strength today; §3.1 + §3.3 bring them to "extends, never stalemates." |
| **DoTs** | Forwarded by `pvp.gd` at flat 0.5 s with real dmg_type × `PVP_DMG_MULT`; a fraction of the big bar. Fine. |
| **Vampiric affix** | Does not fire in PvP (defender `take_damage` runs attacker-less). No action. |
| **Crit swing** | Worst crit basic (mage mirror) ~20% of bar at T35 — variance, not a delete. |
| **Level bracket** | Orthogonal (a mismatched-level warning is a parked v2 item, MULTIPLAYER.md §11). The % framing of durability protects the lower level somewhat, but raw damage still scales — matchmaking/bracket is the real fix. |

---

## §7 — Open for red-pen

1. **`PVP_TOUGHNESS` 35 vs 30 vs 40** — 35 = the §4 tables; 40 softens burst,
   30 is punchier. Pick from feel.
2. **Meteor / Void Rift residual** — accept ~66–77% opening bursts (no-clamp
   ruling stands), or add a *per-ult* PvP scalar just for the two nukes so their
   opening can't chip-into-kill? (A narrower knife than a global clamp.)
3. **Warlock is bottom in every model (0–C)** — but under-modeled (DoT ramp / Void
   spread). Validate with a better warlock kit model before buffing.
4. **Paladin is low (C 37%)** — largely the model pinning it to HOLY (RETRI is
   +56% dmg). Watch, or model both stances before judging.
5. **CC watch item** (§6) — decide now, or wait for playtest signal?

**Resolved:** healing-nerf (dropped → 1.0, §0.2) · assassin amp-trim (tried,
reverted → 0.5; assassin isn't oppressive once the sim's death bug was fixed, §9).

---

## §8 — Derived PvP tiers (instrument + first pass)

The duel analog of `dps_bench`: `scripts/tests/pvp_bench.gd`
(`scenes/pvp_bench.tscn`) derives a class matchup matrix + tier ranking from the
god-roll roster under a candidate set of PvP knobs, and flags the degenerate
interactions a tier letter hides. It is parameterised — `--tough=N --heal=F
--dmg=F` (defaults 35 / 0.5 / 1.0) — so it doubles as the tuning dashboard for
§3's dials. Two honestly-separated layers: MEASURED (EHP, rotation-ceiling DPS,
opening burst, sustain/s, all at 0 defender res) and JUDGMENT (four hand-scored,
red-pen axes — RANGE / MOBILITY / CC / DEFWIN, each cited to the kit).

**Why it needed the durability pass first:** tiers are noise in the current
one-shot meta (first-hit-wins is a coin flip). They only mean something once §3
creates real fights, so the bench is run against the *proposed* numbers.

**First pass @ `tough 35, heal 0.5, dmg 1.0`** (measured backbone):

| Class | EHP | DPS | 2s burst | heal/s | range/mob/cc/def |
|---|---|---|---|---|---|
| Warrior | 88,850 | 16,991 | 25,918 | 1,625 | 0.0 / 0.5 / 0.7 / 0.30 |
| Archer | 52,010 | 27,525 | 95,356 | 2,172 | 1.0 / 0.6 / 0.2 / 0.15 |
| Mage | 44,730 | 34,609 | 103,961 | 2,729 | 1.0 / 0.8 / 0.6 / 0.30 |
| Assassin | 48,370 | 53,549 | 84,709 | 6,895 | 0.15 / 1.0 / 0.3 / 0.25 |
| Paladin | 80,460 | 14,510 | 34,048 | 1,459 | 0.0 / 0.45 / 0.5 / 0.35 |
| Warlock | 48,370 | 10,595 | 49,682 | 1,132 | 1.0 / 0.15 / 0.35 / 0.10 |

Derived order: **S** mage · **A** assassin, archer · **B** warrior, paladin ·
**C** warlock. **Stable** across `heal 0.5→0.3` and toughness — the ordering is
structural, not knob-sensitive.

**The three findings that matter more than the letters:**

1. **RANGE is the dominant PvP axis — and no §3 knob touches it.** In attrition,
   ranged classes control spacing: warrior→mage 183 s, paladin→archer 28 s,
   paladin→mage *cannot kill* (sustain-locked). Longer fights (the durability
   fix) *amplify* the kite. The one-shot fix is necessary but exposes a
   melee-gets-kited meta. Melee needs a PvP-specific answer (gap-close uptime,
   or ranged needs kite counterplay) — a design lever beyond the three dials.
2. **High-DPS lifesteal shrugs off `heal_mult`.** Assassin sustains ~14% of its
   EHP/s (heal/s 6,895) because lifesteal scales with its class-topping DPS — the
   global 0.5× barely dents it (warlock needs 46 s to kill it). Signal: PvP
   lifesteal may want a harder *cap*, not just the global scalar. Dropping
   `heal 0.30` breaks the sustain-*locks* (paladin→mage INF→49 s) but not the
   kite-locks.
3. **Warlock's C is largely a model artifact.** The bench is mana-blind and
   under-models DoT ramp (Hex), Void's always-crit spread, warrior Berserk, and
   the paladin Holy/Retri stance toggle (Retri = +56% dmg / no mend, would lift
   paladin out of the sustain-lock). Don't trust the bottom of the board until a
   phase-2 duel sim validates it.

**Phase 2 (if wanted):** a headless duel sim reusing the `dps_bench` rotation
drivers + the arena + the `_hit_rival` seam, with a simple kite/dodge/defensive-CD
policy, to validate the marquee cells and place the under-modeled kits. Its
numbers are bot-skill-bound, so it stays a *validator* of the matrix, not the
primary instrument.

## §9 — Phase-2 duel sim (validator) and the cross-model synthesis

`scripts/tests/pvp_duel_sim.gd` (`scenes/pvp_duel_sim.tscn`) — a 1D time-stepped
duel: real god-roll stats + a lean per-class kit + a scripted bot (kite / close /
gap-close / proactive-escape / rotation) on the bounded ~1300px arena, every
pairing run 201× → win-rate matrix. It exists to VALIDATE §8's analytic reads,
and it disagrees with them in an instructive way.

**A bug the `--trace` mode caught (2026-08-06).** The first sim build checked
death once per tick *after* regen, so a trickle of regen (and same-tick heals)
lifted a fighter off 0 HP before death registered — fights that should end at ~4 s
dragged to the 45 s timeout as fake "stalemates." A `--trace` replay of
assassin↔paladin showed the paladin sitting at 0 % for 40 s. Fixed: a hit to 0
sets a sticky `dead` flag; corpses don't regen, act, or heal. This **invalidated
the first matrix** (every stalemate cell was an artifact) — the numbers below are
post-fix.

**Win-rate matrix @ shipped `35 / 1.0 / meleeres 90 / amp 0.5` (row's win %, prompt death):**

| | war | arc | mag | asn | pal | wlk |
|---|---|---|---|---|---|---|
| **assassin** | **88** | 98 | **10** | – | 100 | 100 |
| **warrior** | – | 100 | 89 | 12 | 73 | 100 |
| **mage** | 11 | 62 | – | **90** | 100 | 100 |
| **paladin** | 27 | 59 | 0 | 0 | – | 100 |
| **archer** | 0 | – | 38 | 2 | 41 | 100 |
| **warlock** | 0 | 0 | 0 | 0 | 0 | – |

Sim order: **S** assassin 79 % · warrior 75 % · mage 72 % · **C** paladin 37 %,
archer 36 %, warlock 0 %.

**What the shipped-settings run says:**

- **A clean rock-paper-scissors at the top:** assassin > warrior (88 %, lifesteal
  out-sustains plate) > mage (89 %, stun-lock) > assassin (mage burst+kite, 90 %).
  No single dominant class — each S-tier has a counter. Healthy.
- **Assassin is strong (79 %) but checked** — mage hard-counters it. The amp-trim
  was reverted (owner): once the sim's death bug was fixed it isn't oppressive.
- **Death Mark's true damage is a red herring** (owner call, confirmed by the
  `--trace` damage-by-source): **1–6 %** of assassin output. The engine is
  **Stab + Fan + surge lifesteal (~94 %)**.
- **Dropping the heal-nerf lifted paladin 26→37 %** (owner call) — its holy-mend
  runs at full strength (vs archer 26→59, vs warrior 3→27). Still C, but that
  residual is the model pinning it to HOLY (RETRI is +56 % dmg), not a real floor.
- **Warlock still 0 %** — under-models its DoT ramp (Hex) / Void spread. Validate,
  don't buff.
- **Melee vs ranged stays model-unstable** (the §8-vs-§9 disagreement holds): 1D
  can't circle-kite, so it favors gap-close + stun; the analytic favors infinite
  kite. Skill-expressive — don't hard-tune from either.

**The durability pass survives simulation:** across the corrected runs there is
**not one one-shot** — every fight resolves on damage over seconds, never an
instant delete. The §3 dials fix the reported problem; the tier structure on top
is a separable second conversation, and this run says it's a mild one.

**Sim honest-limits:** 1D positioning (no circling — favors melee), lean kit,
i-frame-only dodging, paladin locked HOLY, mana-blind. It brackets and validates;
it does not replace playtest.

---

## §10 — Pen in PvP + gems (2026-08-07, BUILT + open)

**Pen now crosses the wire (BUILT, NET_VERSION 0.3.3).** The old PvP strike forwarded
attacker-less, so the defender applied resistance with NO pen — the melee-res grant
(§3.5) was *unpennable*, and attacker pen only met the 0-res side as a junk flat
bonus. Fixed: `pvp_strike` / `_rpc_player_hit` / `take_damage` thread the striker's
`pvp_pen`, so the defender mitigates on `res − pen`. `_hit_rival` now passes pen=0 to
its own resolve (kills the excess-pen bonus). Verified: net stage 16 green.

**Gem exploration (`pvp_duel_sim --gems=pvp`).** Every bench build was pinned to a
pure-DPS gem loadout; letting bruisers gem sustain/res and attackers gem pen showed
**"sustain is king" is FALSE — pen is king.** Flat, uncapped pen (a god-roll already
carries ~180 from gear subs; all-pen reaches ~1550) fully cancels any res, so
defensive gems are a *trap* against pen-stacking. PvE is unaffected — boss res is a
big enough sponge (65–190 on-type at L100) that pen has natural diminishing returns;
the ~90 PvP grant was the outlier, not the boss numbers.

**OPEN (red-pen):** cap PvP pen as a *percentage* of res (≤~50%, never zero it) so
res-stacking holds value and gem choice is a real res-vs-pen read — vs leaving flat
pen and accepting a pen meta. Recommended: the %-cap.

**Related PvE change (same investigation):** the boss-resistance scaling was found
FLAT for off-type on many bosses (a caster's physres never grew). Fixed in
`story.gd`: STR→physres added (brutes specialize physres, mirror of INT→magres), a
`BOSS_VIT_FLOOR` guarantees both resistances climb (nothing flat), and a
`BOSS_BASE_RES_*` tier floor makes later-story bosses start naturally harder — all
bosses-only, native-level fights unchanged. Not a PvP change; recorded here because
it fell out of the PvE pen check.

---

*Instruments (throwaway, not test tiers): `pvp_probe.gd` (raw damage numbers),
`pvp_bench.gd` (analytic tiers), `pvp_duel_sim.gd` (simulated win rates), each
with a scene. Cross-links: MULTIPLAYER.md §11 (PvP v1 spec), `balance.gd` pvp
block, DPS bench `BenchBuild` (the god-roll build source).*
