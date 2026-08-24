# Fidelity audit — authored resolution vs on-screen render

**Owner rule (2026-08-24):** a master sprite should be **≥ 2× the size it renders at in game**. Below that it looks soft/mushy at its render size. Benchmark: the base classes render ~100px on-screen from ~235px art (~2.35×).

**Tooling** — re-run any time (formulas + method in `tools/INDEX.md`):
```bash
# 1. dump live entity scale/placement (a quick Godot boot; run OFF the Codex box)
tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --script res://fidelity_dump.gd -- entities.json
# 2. audit (skips enemies never placed in a zone; --include-unplaced to override)
python tools/art/fidelity_audit.py --entities entities.json --csv fidelity.csv
```
`ratio = authored_px / rendered_screen_px`, flag `< 2.0`. Render formulas (× camera base zoom **1.12**): hero body `52·1.7`; mob cell `scale·1.7·16`; boss cell `scale·1.0·16` (bosses skip the 1.7); npc body `~46·1.7·nsize`; critter `cell·_scale` (direct texture scale); prop width = `Balance.SCENERY_RENDER_WIDTH`.

---

## Verdict by category (placed assets only, 232 total)

| Category | n | median | worst | under 2× | read |
|---|---|---|---|---|---|
| **Boss** | 21 | **3.43×** | 1.59× | 1 | healthiest — the Codex regen at 627–648px paid off |
| NPC | 42 | 2.55× | 0.71× | 6 | mostly fine; low ones are props-wired-as-npc + one real upscale |
| **Class** (benchmark) | 6 | 2.12× | 1.95× | 1 | render 99px; the reference bar |
| Mob | 39 | 2.03× | 1.75× | 18 | a uniform 192px batch sits ~10% under bar (borderline) |
| Prop | 94 | 2.21× | 1.07× | 37 | trees worst; many structures borderline |
| **Skin** | 23 | 1.22× | 1.17× | **18** | the OLD skins — half base-class fidelity |
| Critter | 7 | 1.05× | 0.60× | 7 | ambient; small — likely out of scope |

**Excluded by design:** 9 enemies DEFINED but never placed (never spawned, never summoned) are skipped so they can't post phantom fails. `bat`/`direbat` were the two worst (0.59×/0.62× — art smaller than its render) and were **dropped from the codebase 2026-08-24** (commit `5a1610a`).

---

## The real priorities (things a player sees, worst first)

### 1. Skins — the biggest, most systemic gap (18 of 23)
The **5 enhanced-base variants are DONE RIGHT and PASS at 2.37×** (authored at the full 235px base body): `emberbound_heir`, `erased_name`, `severed_thread`, `ledgerbound`, `blighted_healer`. **They are NOT in this list.**

The failures are the **OLD skins** — authored at ~120px = ~1.2×, exactly the set CLAUDE.md marks off-limits pending the **planned full skin regen**. This audit quantifies why that regen matters:
- **~1.17–1.23× (14):** `mage_void_weaver`, `assassin_phantom` (+awakened), `paladin_fallen_arbiter` (+awakened), `mage_crystal_archmage` (+awakened), `archer_frostfall_ranger`, `archer_voidwraith` (+awakened), `warlock_eldritch_herald` (+awakened), `warrior_stormforged` (+awakened)
- **1.82× (4):** `assassin_blade_dancer`, `paladin_eclipse_knight`, `warlock_hellfire_inquisitor`, `warrior_dreadknight`

### 2. Genuine upscales (art SMALLER than its render)
- **`pilgrims_schism` 0.71×** (npc) — 62px art rendering at 88px
- Critters: `hawk` 0.60×, `crow` 0.89×

### 3. Trees / large scatter props (LOW, <1.5×)
`tree_snow` 1.07×, `tree_teal` 1.12×, `deadtree` 1.25×, `tree_gnarled` 1.33×, `tree_winter` 1.34×, `grave_deadtree` 1.37×, `garden_statue` 1.42×, `tree_spore` 1.43×, `storm_conductor` 1.45×

### 4. Used-but-low-fi, hidden by the placed filter
- **`choir_censer` 1.15×** — SUMMONED by the ch3 boss (so it's seen), but not a zone spawn, so the default audit skips it. A real re-art candidate. (`echo_clone`, the ch7 summon, is fine at 3.5×.) The filter counts "zone spawn OR boss," not mechanic summons — the one known blind spot.

### 5. Borderline (1.5–1.99×, THIN — nice-to-have)
- **Mobs (18):** the 192px batch — `skeleton_mage` 1.75×, `mummy`/`orc`/`vow_sentinel`/`fungus_*` ~1.8–1.85×, up to `elf_ranger` 1.97×. Authored at a uniform 192px; renders ~100–110px.
- **Props (~28):** `tree_green`/`tree_autumn` 1.5×, `crypt`, pillars, statues, forge stations… up to `ice_sled` 1.98×.
- **`veyx` 1.59×** — the only boss under bar (scale-22 giant renders 394px; needs a >788px master).
- **`archer` 1.95×** — the one base class fractionally under (193px body).

### Out of scope (owner to decide)
- **Critters** (7, all <2×) — ambient/tiny; `bat` critter 1.28×, `butterfly` 1.49×.
- **Props-wired-as-npc:** `bones` 1.30×, `fallen_bell` 1.38× (interactables, not characters).

---

## Notes
- **Excluded correctly:** unplaced enemies (`bat`/`direbat` dropped; 7 `pc_extra_mobs` reserve spared per owner; mostly ≥1.8× anyway).
- **Known filter blind spot:** boss-*summoned* adds read as "unplaced" (only `choir_censer` matters — low-fi and used).
- **Bag icons intentionally 32px** (gear + gems both) — this audit is about world/character/codex art, not the bag-slot tier.
- Full sortable data: the `--csv` output. Re-run after any resize/regen to confirm an asset crossed 2×.
