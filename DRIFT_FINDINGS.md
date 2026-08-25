# Generation-drift visual audit — findings (bosses + mobs)

Run **2026-08-24** via the eyes-only drift pipeline (method: `tools/art/DRIFT_AUDIT.md`). This is the findings SoT; re-run and update after any regen/fix. It is the VISUAL companion to `FIDELITY_AUDIT.md` (which measures resolution) — this measures per-frame **off-model drift** a geometric gate can't see.

## Coverage & method
- **21 bosses + 38 mobs**, every placed enemy. One review agent per subject over **every clip × every unique direction × every frame** (byte-identical mirror dirs deduped first). The orchestrator re-viewed every REAL flag before it landed here.
- Tooling built this run: **`tools/art/drift_sheets.py`** — dedups dirs per clip and emits per-clip ATTIRE (full-body) + FACE (head-crop) contact sheets, brightened, idle marked. Re-runnable for any base.
- Reference = the **gameplay idle** (`anim` flat f0), NOT `anim_codex` (the hi-fi codex master intentionally differs — see the structural note).

---

## CONFIRMED defects — bosses (5, verified by eye)
Ranked by player impact. Crops in `scratchpad/drift/_defects/`.

| # | boss | where | defect | cheapest fix |
|---|---|---|---|---|
| 1 | **vess** | `idle f0`, `enrage f1/f3` | blue-white light emits **from the mouth**. **Owner ruling 2026-08-24: ACCEPTED — passable now and forever. WON'T FIX.** Do not re-flag. | — (accepted as-is) |
| 2 | **choirmother** | `ability e f2-f6` | a pale human face (dark hair, red lips) appears inside the hood; the veil stays a dark empty hood in all 7 other directions | **✓ FIXED 2026-08-24** — frame-edit (restored the dark void from f0 over the intruding face+hair; hands/gold/robe/cast preserved), game/ + mobile/ |
| 3 | **fangmaw** | `ability n f1-f6` | hot-**magenta** streak down the spine, off-palette (design is grey-fur/red-bone/white), north-only — it's the open maw/throat rendered pink | **✓ FIXED 2026-08-24** — despilled (killed blue excess → in-palette red throat), game/ + mobile/ |
| 4 | **serane** | `walk_codex s f0-f3` | the south row is a **different character** (gray hooded wraith) — se/n/nw render the correct icy sorceress | **✓ FIXED 2026-08-24** — replaced the wrong strip with `serane_anim_codex` (correct front-facing icy sorceress, same 627px/4-frame; idle sway reads fine as a robed walk). game/ + mobile/ |
| 5 | **nullwarden** | legacy `anim`/`walk` sprites | held **greatsword** from the RETIRED blade design. **KEY FINDING: the in-game nullwarden was ALREADY sword-less** — `enemy.gd` renders `anim_codex` (idle) + `walk_codex_<dir>` (walk), both the energy-fist design. The sword only survived in orphaned legacy sprites nothing shipped. My earlier report wrongly used the legacy `anim_n` as the "correct" reference. | **✓ FIXED 2026-08-24** — see the legacy-sprite purge below. |

## Legacy-sprite purge (2026-08-24)
Tracing nullwarden revealed a roster-wide pattern: every one of the 21 codex-regen bosses (`BOSS_FLAT_ANIMATION_LOCOMOTION`) renders its idle from `<boss>_anim_codex` and (if directional) its walk from `<boss>_walk_codex_<dir>` — so the older `<boss>_anim_<dir>`, `<boss>_walk_<dir>`, and flat `<boss>_anim`/`<boss>_walk` gameplay sheets were **orphaned legacy** ("legacy directional sheets still present in the tree", per `enemy.gd`). Owner ruling: only the shipping copy should exist. **Removed ~1,396 files** (698 PNGs + `.import`, game/ + mobile/): all orphaned `_anim_<dir>`/`_walk_<dir>` sheets + flat `_anim` for all 21 bosses, + flat `_walk` for the directional bosses. **Kept**: bare `<boss>.png` (bestiary portrait via `Art.tex`), all `_codex` strips, action clips (`_ability`/`_bolt`/…), and the flat `_walk` for `fangmaw`/`cinderhide`/`morwen` (flat_wave-not-directional → flat `_walk` is their shipping strip). **Full suite PASS** — bosses spawn, dev_morph reverts cleanly, `_strip_info` returns `{}` on the missing files and every caller degrades gracefully.

## ~~Systemic pattern — "back-view attack clip drawn front-facing"~~ — RETRACTED (2026-08-24)
**This was largely an ORCHESTRATOR MISJUDGMENT.** Re-checked at full resolution (owner prompted): **korrag** `attack_n`/`lash_n` are already clean BACK views (back of helm, banner on the back, flail up-and-away, no face); **stormmouth** `bolt_n` is a clean BACK view (head-crop: no face vs the front's glowing orange eyes); `cast_n` is ambiguous but not clearly front; **nullwarden** `piston_n` was likely the same misread. The small verification crops read front-ish; the actual strips are back. **No fix was warranted** — korrag/nullwarden were never touched, and the unnecessary stormmouth `bolt_n`/`cast_n` regens were **reverted to the authored originals**. Lesson: judge front/back from the FULL strip at full res, not thumbnail crops; the owner's eye caught this. The ONE real item that survived is **saint_varo's weapon inconsistency** — a weapon-SHAPE call, not a front/back one.

## saint_varo standing_ability weapon — ✅ FIXED (2026-08-24)
His idle + `std_attack` wield his signature glowing **greatsword**, but `standing_ability` conjured the wrong weapon in every direction (axe s/ne/nw, scythe-blade e, spear n/sw). Regenerated all 8 directions via Codex ImageGen (both refs the greatsword, so no wrong weapon to copy; `std_attack_<dir>` locked each facing) → all 8 now wield the two-handed gold-and-purple greatsword. Green blade-glow despilled to gold; built to hi-res (fidelity upgrade from the legacy 200px cells). Installed game/ + mobile/, re-imported, **verify_art 0 fail**. Technique note: the back/profile facings came out correctly here (unlike korrag) because saint_varo's back views already exist and `std_attack_<dir>` anchored each facing.

## Structural — codex-master vs gameplay-sprite split (near-universal, mostly intentional)
Almost every regen'd boss ships two coherent renders: the hi-fi `anim_codex` master (codex UI) and the flatter in-game gameplay sprite. That's by design. Cases examined for a possible recolor-unify, **all deferred to the regen** (moderate/subtle tint difference, internally consistent per-clip, would need a risky 27–36-file recolor, and may be intentional):
- **vargoth** — inspected: all capes read dark grey/black; the "green" is only a very desaturated olive tint (e.g. 44,72,51), not a stark green cape. Not worth a 27-file recolor. → regen.
- **echo** — inspected: wings are predominantly blue-grey in every clip; `blink` (and per-audit attack/throw/split) carry a modest purple tint. Moderate, and plausibly thematic for a "shifting/mirror entity." → regen.
- **ashpriest** (gameplay drops the fire-censer + swaps cloth robe for a plated skirt) and **cinderhide** (codex = maroon brute, gameplay = charcoal ember-hound) — wholesale gameplay-vs-codex design divergence; decide which is canon → regen.

## Clean bosses (no real drift)
auroch_minotaur, forgemistress, kaethra, halla, hrolgar, rotmaw, veyx, korrag(base+reborn), sexton, morwen* — all on-model. (*morwen has a minor off-model: the 4 flat codex-walk frames tint the lower skirt purple; gameplay dirs are clean — low impact.)

---

## Mobs (38) — ZERO per-frame generation drift
Every mob is on-model across all clips/directions/frames vs its own idle. The 192px legacy batch and the flat Codex batch are both clean — drift is a hi-fi-boss-regen artifact, not a mob problem. Only non-defect notes:
- **orc_rogue** — `rogue_walk` holds a scimitar while idle/anim hold a war-horn (consistent across dirs = likely an intentional idle-prop→combat-prop swap, like the base orc's bone+axe).
- **rat_mage** — walk/death robe reads slightly greener/shaggier than idle (pose-driven, identity intact).
- **Cross-form STYLE mismatches** (not drift): zombie `brute` and orc `shaman`/`warrior` are small chibi pixel-art — a different scale/style from their base forms. Owner call whether to unify.
- **storm_harrier** is a storm **wolf**, not a bird (design/name mismatch only).
- `wolf` + `skeleton_mage` carry a faint green antialias rim = `verify_art` BLEED territory, uniform (baseline), not drift.

---

## Recommended fix order (cheapest, highest-impact first)
1. **✓ DONE (2026-08-24)** — despills: **fangmaw magenta throat** (→ red) and **morwen purple codex-walk skirt** (→ cool slate), both game/ + mobile/. **vess mouth-light deferred** (owner: passable for now).
2. **✓ DONE (2026-08-24)** — **choirmother `ability_e`** (frame-edit, hood re-voided) and **serane `walk_codex_s`** (replaced with the correct idle master), both game/ + mobile/.
3. **Deferred to the regen** (not worth a risky multi-file recolor now): **vargoth cape**, **echo wings** — subtle/moderate structural tints, likely intentional.
4. Defer to the planned boss regen: **nullwarden anim+walk to the sword-less energy design**, the back-view-attack-front-facing pattern (4 bosses), + the ashpriest/cinderhide codex-vs-gameplay lower-body decision.

**Net this session: 4 defects fixed deterministically** — fangmaw, morwen, choirmother, serane (all game/ + mobile/). Everything remaining is regen-tier or owner-deferred.
