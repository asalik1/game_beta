# Fidelity remediation — autonomous session plan (2026-08-25)

Owner brief: complete every FIDELITY_AUDIT.md item EXCEPT skins. Any touched prop that could
logically animate gets an animation (trees = wind canopy motion, trunk pinned, no sliding).
Improve audit tooling along the way. Owner reviews at the end. Baseline: 89/232 under 2.0x
(baseline_2026-08-25.csv in this dir).

## Phase 0 — tooling  [STATUS: DONE 2026-08-25]
- [x] install_prop_hires.py clamps fixed (2.5x render_w, 1024 ceiling, never-upscale guard).
- [x] build_terrain_art_fix.py SPECS doubled.
- [x] audit_prop_anims.py: FOLIAGE_PROPS band 0.12 + --fix never mangles authored foliage.
- [x] fidelity_audit.py: BOSS_MULT 1.7 (CORRECTED — bosses were inflated 1.7x), npc real
      body_target + legacy-w path, prop VARIANTS audited at family width.
- [x] fidelity_dump.gd: real NPC_BODY_TARGETS + boss-def "summons" keys (5 defs) union placed.
- [x] enemy.gd:111 stale comment fixed; CLAUDE.md/INDEX.md formula lines corrected.
- [x] asset_dump.gd: choir_censer phantom "player projectile" row removed.
- [~] derive_prop_anim sway mode: NOT needed (authored 2x2 canopy masters work; trunk drift 0).
- [x] m1_rebuild.py: references256 x4/3 approach (no builder edit needed).

## Progress log
- M1a INSTALLED (7 robe mobs @256 from masters; verify_art 0 fail; test_quick PASS).
- tree_green INSTALLED (475px static + 4-frame canopy anim; audit_prop_anims 0 flagged).
- pilgrims_schism INSTALLED (354x284 from 1536 master; 0.56x -> ~2.5x). build_runtime.py updated.
- fallen_bell INSTALLED (256w checkerboard-keyed from 1254 source; 1.75 -> 2.8x).
- veyx_ability* x9 purged (dead art, both trees; git-recoverable).
- 77-stage gen batch RUNNING (bg): 11 mob idles -> 13 misc -> 53 props. elf_druid staged+vetted.
- Wave B (17 deaths + banshee attack) prep script ready; queue after idle wave.
- M2 COMPLETE: 10/11 mobs installed at 256 (idle/static/attack/death, flat walks where mastered).
  stone_broken REJECTED by judgement (owner 08-08 ruling keeps legacy frames; regen shifted
  head/core) — stays 192, documented. All QA sheets clean; palettes converge to hi-res lanes.
- MISC WAVE INSTALLED: 7 critters at 2-4x cells + ambience.gd/audit scale tables (world size
  unchanged); mill 640w; bones 256w; rock 256w; choir_censer 256 static + NEW 4-frame anim.
- elder + caged_beastkin SKIPPED -> OWNER-CONFIRMED TO-DO (2026-08-25): document in
  FIDELITY_AUDIT.md as a future 8-dir NPC regen pass (8 stills per NPC, no walk cycles —
  cheap). Group suli 1.97 + warden_corin 1.99 into the same pass. S masters archived.
- Batch runner DIED at a Claude process restart (25/78 done); relaunched for remaining 53
  (-MinFreeGB 1.0 — five parallel claude sessions eat ~2.6GB; gate holds jobs till RAM clears).
- veyx/stormmouth/vargoth dead ability strips purged (54 files w/ imports, both trees).

## Phase M1 — mob deterministic rebuilds (zero drift, from archived masters)  [STATUS: todo]
Masters: art_src/Custom/MobWalkRepairs_2026-08-08/. Preserve per-mob body/cell fraction
(table in session notes; e.g. skeleton_rogue 0.70, null_acolyte 0.73, mummy 0.78...).
- Robe/IDLE_ONLY mobs (mummy, mummy_mage, static_caller, skeleton_mage, skeleton_warrior,
  null_acolyte, rat_mage): rebuild `_anim` (+static) at 256 from idle/motion masters. Clears audit.
- FLAT_WALK mobs: rebuild flat `_walk` at 256 (masters 443-732px/frame): skeleton_rogue, elf_druid,
  bandit_scout, elf_ranger, orc_rogue, royal_knight, orc(8fr), vow_sentinel, skeleton, zombie.
- Attacks: rebuild at 256-base grown cells for all with masters (~16 mobs + skeleton/zombie/rat_mage).
- NOT deterministic (goes to M2): 13 non-robe idles, ALL deaths, banshee everything,
  stone_broken (owner-specified legacy design — identity-locked redraw, careful).

## Phase M2 — mob regens (identity-anchored, drift-reviewed)  [STATUS: todo]
- 13 non-robe idles: 2x2 breathing idle master per mob, identity ref = current 192 strips.
- banshee: full set (idle/walk/attack/death) — no masters exist.
- Deaths x~18: identity-anchored death regen (or defer worst-only if budget tight).
- stone_broken idle/walk: faithful redraw of legacy design (owner-specified look — no redesign).
- EVERY regen: drift review per tools/art/DRIFT_AUDIT.md (agent per subject, orchestrator verifies).
- Gate: verify_art per mob, mobqa filmstrip strips (idle/walk/attack feet-row check).

## Phase P — props (38 families + tree sliver variants)  [STATUS: todo]
Full under-bar list (agent B table): tree_snow 1.07 ... grave_statue 1.999 (38) + variants
tree_autumn3 0.51, tree_winter3 0.61, tree_green4 0.62, tree_spore3 0.73, tree_snow3 0.91,
tree_teal2/3, tree_spore2, tree_gnarled2, bush3 1.79, deadtree(base only).
- Faithful re-render briefs (subject = current approved painterly asset; same design, more detail),
  style sibling ref; batch via run_codex_batch.ps1 -MaxParallel 1 -MinFreeGB 1.3 (NEVER beside suite).
- Install via fixed install_prop_hires at 2.5x render_w. Re-derive existing 12 anims from new statics
  (derive_stage; check is_derived first — authored anims must not be blindly re-derived).
- NEW anims where logical: leafy trees (green/autumn/teal/spore/snow/winter, topiary, bush3) = canopy
  rustle (authored Codex frames, trunk pinned; fallback derived sway mode); dead/bare trees = NONE;
  statues/pillars/crypt/arch/sled = static; fire props keep flicker; glow props keep pulse.
- Gate: audit_prop_anims (with foliage list), verify_art, vet sheets, in-rig GIF look (shot.bat polish --gif).

## Phase S — small fry  [STATUS: todo]
- pilgrims_schism npc 0.71x: regen 256^2 per style_unify NPC recipe. (agent C details pending)
- critters: ALL 7 under bar — regen hi-res cells + scale-table change so world size unchanged;
  update fidelity_audit CRITTER_SCALE.
- choir_censer 1.15x: regen (mob-style); fix audit blind spot so summons are audited.
- mill 1.83 (npc-path building): regen at 2x via make_npc_briefs mill lane (384 -> ~768 wide? check).
- bones 1.30 / fallen_bell 1.38 (props-wired-as-npc interactables): regen at 256-ish. Low priority.
- zombie/fungus_long npc rows: fixed by M1/M2 automatically — verify after.

## OWNER RULINGS 2026-08-25 (mid-session)
- 5% TOLERANCE RULE: <1.90x MUST FIX; 1.90-1.99x document-only. (memory: fidelity-bar-5pct-tolerance)
- veyx ~1.5x ceiling ACCEPTED for now (document + PixelLab-resize note).
- archer 1.95x documented, not fixed.
- elder/caged_beastkin: confirmed to-do (8-dir pass; group suli+warden_corin).
- stone_broken keep-legacy ruling RESCINDED: fix via design-LOCKED re-roll (waved stage).
- RULE PULL-INS -> wave D (23 stages): auroch 1.79 + halla 1.87 idle+walks (paired-frame
  landscape ~768 cells), fangmaw 1.89 idle+walk (2x2 627 = 2.42x), stone_broken v2.
- halla_ability*/fangmaw_ability* purged (dead: BOSS_FLAT_ANIMATION_LOCOMOTION blocks "ability").

## Phase V — bosses  [STATUS: rescoped 2026-08-25 after formula correction]
TRUE numbers (bosses get x1.7 like mobs — enemy.gd:312; audit was wrong): 10 under bar.
- REMEDIATE: veyx 0.94 LOW, stormmouth 1.37 LOW, vargoth 1.58 THIN (ch1 finale, visible).
  Veyx plays: idle veyx_anim_codex 627 + walk_codex 8dir + arc(8dir+flat) + storm/ring/summon/
  enrage flats (634-766 cells). veyx_ability* 216px family + veyx.png static are DEAD (purge).
  Ceiling: ImageGen ~1024/frame < the 1340 a true 2x needs -> document ceiling (~1.5x), note
  PixelLab resize could close it if owner authorizes later.
- DOCUMENT ONLY (owner triage): auroch 1.79, halla 1.87, fangmaw 1.89, ashpriest/cinderhide/
  kaethra/saint_varo 1.96 — owner-approved art within ~10% of a freshly-corrected bar; full
  regen drift risk not worth it unasked. Also archer class 1.95 (benchmark class, same call),
  suli 1.97 / warden_corin 1.99 (noise).
- NPC scope adds (from corrected dump): elder 1.89, caged_beastkin 1.87, pillar/rock 1.75 (npc
  interactables, legacy-w path), bones 1.40, fallen_bell 1.75, mill 1.83, pilgrims_schism 0.56.

## Phase F — finish  [STATUS: todo]
- Re-run fidelity dump+audit; before/after table; update FIDELITY_AUDIT.md (results section).
- preflight, --import, test_quick, full test.bat, sync_mobile --apply --gate.
- Stage everything (safe_commit path-scoped commits per phase as they green).
- Codex staleness check (codex reads data tables — art-only change, likely no-op but verify).
- Memory write: session outcome + any new standing rules.

## Machine rules
Serial gens only (-MaxParallel 1 -MinFreeGB 1.3), never beside a Godot suite. PIL rebuilds are free.
Backups: replaced committed assets recoverable via git; also archive masters under art_src/.
