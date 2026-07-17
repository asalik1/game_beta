# Crownless — Art Quality Audit (2026-07-17)

Full-catalog review of `game/assets/` (~2,336 images) by six parallel audit agents, one per category.
Every asset family scored 1–100 overall plus five axes: **Res** (pixel density / resolution consistency vs the ~128px PixelLab hero standard at gameplay zoom), **Design** (silhouette, readability), **Theme** (muted somber dark-fantasy palette), **Creativity** (distinctiveness), **Technical** (padding, frame/direction consistency, artifacts).

Method per category: scripted metrics pass (Python/PIL — dimensions, opaque-bbox body size, alpha fill, unique colors, native-resolution estimate via modal run-length upscale detection) followed by a visual pass over labeled contact sheets. Known-intentional patterns (static idles, idle=walk reuse, kit-matched anim coverage, bright-authoring for the tonemap, gem lv9==lv10 crown-pip) were excluded from findings.

---

## Executive summary

| Category | Avg score | Range | One-line verdict |
|---|---|---|---|
| Skins (12 elite/mythic) | **82** | 62–91 | Best category; two shipped generation-drift defects (Stormforged ult, Frostfall north dirs) |
| Bosses (custom, ch1–7) | **81** | 55–87 | Strong roster dragged by 3 old-gen beasts + one catastrophic placeholder (Veyx = 12) |
| Hero classes (6) | **74** | 70–78 | Gold-standard bodies, but 6 legacy wrong-character strips still ship in death/dash/aim paths |
| Splash/cover art | **85** | 72–92 | Warlock/paladin/warrior splashes excellent; mage splash off-style |
| Icons (ability/buff/gem) | **78** | 68–86 | Immaculate set coherence; 4–5 per-icon readability failures |
| FX + projectiles | **72** | 34–89 | fx_ice/choir_censer great; fx_ripple (34) and shuriken are the outliers |
| NPCs | **55** | 10–78 | Two art generations coexist; 5 literal unpainted mannequins still live |
| Environment/props | **56** | 15–85 | Crisp hand-pixeled core vs a painterly-downscale noise cluster; wall set weakest |
| Mobs | **60** | 30–76 | Whole roster renders 2–4.4x chunkier than heroes; tick quintet + recolor farms at the bottom |

### Texel-density audit (2026-07-17) — the "everything looks coarse next to the hero" question, measured

On-screen magnification = screen-px per source texel (bigger = chunkier blocks). Derived from the real render paths: mobs `scale × 1.7 × 16 / cell` (`enemy.gd:395`), hero `52 × 1.7 / body_h` (`player_core.gd:610`), walls/obstacles a flat `Vector2(3,3)`, NPCs `48 / frame_w`, buildings `108–120 / w`.

| Layer | Magnification | Verdict |
|---|---|---|
| **Hero** | **0.81x** (supersampled — 109px source → 88px screen) | Deliberately crisp; the protagonist pop |
| NPCs | 1.45–1.55x (uniform) | Slightly finer than the world; fine |
| Buildings | 2.25–2.70x (gate is the exception) | Coherent with the world |
| **Mobs** | **42 of 50 sit at 2.5–2.9x** | Remarkably uniform — NOT a variance problem |
| Walls + obstacles | **3.00x flat** (any source) | Uniform; sits right in the mob band |

**Headline: there is no "three tiers, re-cut a layer" problem.** The entire world (mobs + walls + obstacles + buildings) clusters at ~2.5–3.0x. Only the hero sits apart, on purpose. The spider renders at **2.55x — identical to the wolf, zombie, and rat beside it**; it looks worse purely because of authoring style (122-color AA gradient vs clean cel art), confirming density is a red herring for the "coarse" feeling. Fix authoring, not density.

**Exactly two true density outliers, one-line fixes each:**
- **`gate` — 6.75x** (16px source stretched to 108px): the single worst-magnified asset in the game. Re-cut the source larger (it's placeholder-grade art anyway, scored 30).
- **`slag_brute` (`stone_broken`) — 4.14x** (23px source at scale 3.5): re-cut source to ~32px, or drop its `scale` to ~2.4 (note: also shrinks its on-screen body 95→~65px).

The <2.0x "too fine" tail (bat/direbat, echo_clone=the assassin mirror, choir_censer=projectile, grove_horror/banshee/fungus_long) is all legitimate — small creatures, projectiles, and large-cell mobs that render crisp; none are defects.

Full per-mob table + script: session scratchpad `density/texel.py` + `enemy_scales.txt`.

### Three systemic findings (bigger than any one asset)

1. **Pixel-density tiers on one screen — SUPERSEDED by the measured texel audit above.** The hero is deliberately supersampled (0.81x); the whole world (mobs, walls, obstacles, buildings) is actually density-coherent at ~2.5–3.0x, not a spread of tiers. The spider renders at the *same* 2.55x as its neighbors — the "coarse" read is authoring style (AA gradient), not density. Only `gate` (6.75x) and `slag_brute` (4.14x) are true density outliers. The earlier "props 6x coarser" figure was wrong (props are a uniform 3.0x). No layer re-cut needed; fix the two outliers + the authoring-quality offenders in finding #2.
2. **Smooth/AA art is what actually reads as "pixelated."** Assets stored with anti-aliased gradients (spider tick 122 colors, direwolf 361, tombstone 108, tree_snow 296, grave_deadtree 270, shuriken 546) turn to mush under nearest-neighbor magnification, while clean-celled art at the *same* density (Pixel Crawler mobs, 5–23 colors) reads fine. The fix lane is re-pixeling/replacing the AA offenders, not upscaling everything.
3. **Legacy generations were never fully retired.** Old art keeps shipping inside newer families: 6 pre-redesign hero strips (different characters!), 3 flat-color old-gen bosses (fangmaw/cinderhide/auroch at 13–27 colors vs 500+ for peers), the old-batch NPCs with baked shadows (double-shadowed by the engine), and the retired 32px `stormwarden` sprite cast as a ch7 boss.

---

## Verification pass (2026-07-17)

Every wiring/reachability claim was re-verified by dedicated agents tracing actual runtime paths (spawn gates, sprite-key resolution, call sites). Verdicts:

**Killed as false alarms (no player ever sees these):**
- Gardener-boss-is-a-mannequin — boss renders `rotmaw.png`; `gardener.png` is orphaned.
- Mannequin NPCs in the ch2 hub — `placeholder: true` NPCs are skipped outside `--dev` (`game_world.gd:381-382`); codex hides them too.
- Assassin stab/throw aim strips — retired 2026-07-10, dead art (`player_core.gd:491`).
- paladin_dash / mage_attack2 — no ability maps to those clips; unreachable.
- direwolf — 361-color mush confirmed, but **never spawns** (no enemy def references it).
- witch — never renders (no def, no convo speaker uses its portrait).
- storm_harrier "bird vs wolf" — its lore says "plains hounds"; the canine body is intentional (2-frame recolor note stands).
- scholar_director idle↔walk pop — that NPC never renders; the identical defect DOES ship via the Null Acolyte mob (~1.9px, subtle).
- Placeholder bosses — dev-panel only (one latent leak: `endgame.gd:451-456` fallback pool lacks the placeholder filter its comment claims — flagged as a code fix).
- warlock_walk 9-vs-7 frames — base strip never renders (dir strips swap in same tick).
- Below-feet ability-strip growth — engine's feet re-anchor handles it; no boss shifts (and the cinderhide/auroch growth numbers were wrong anyway).
- Cinderhide frame-3 flash — deliberate ignition spike (molten-core identity), not a corrupt frame.

**Confirmed exactly (the surviving real list):** Veyx placeholder; tick quintet (byte-identical alpha masks — and it spans FIVE chapters: 1,2,3,4,6); elf_ranger baked crimson halo (ships ch2 + ch7); Korrag phantom hammer (worse: frames 1-6, and it plays on ALL his moves — only one ability strip exists); boss size ladder incl. cinderhide 143/auroch 211 inversions; choirmother triple-cast (real but mitigated: deliberate, documented, and NPC-scale ~42px vs the boss's ~201px); all four skin defects (Stormforged ult 206px/16px-spread; Frostfall N-arc second outfit; Dreadknight mint frames; Voidwraith rainbow bubble); Blade Dancer white slash blob (the Golden Ronin gold FX is a faint overlay — the white frames ARE what players see, and damage lands on the biggest one); fx_ripple live (6 per marsh/bog river room); gem duplication + lv10 crown pip; HUD 44px NEAREST upscale (worse at 1080p: ×1.5 canvas scale on top); warrior_attack_e east-only swing lag (~0.23s visual trail after damage; no engine bug); archer_death frozen mid-air flail (~1.2s every death, archer-only outlier — all other classes land corpses); double shadows on villager/merchant/envoy/warden (not king); cottage/tombstone scale claims; all noisy chests (b/c/d/f) genuinely used; chest_s unreachable (S never rolls from chests).

**Corrected numbers:** mob density band is ~2.6–5.6x chunkier than heroes (was "2–4.4x"); wall_moss serves 4 shipped biomes (fae/sewer are placeholder terrains); flame_giant/great_spirit are a recolor pair, not one byte-identical sprite (both dev-only).

**Owner-decision item surfaced:** npc_hunter / npc_bandit_tracker / npc_royal_archer carry finished art but are `[ph]`-tagged, so they ship NOWHERE — `ch2_hub.gd:32-39` explicitly awaits an owner call to reposition or delete.

---

## Fixes applied (2026-07-17)

**AA-mush environment cluster — DONE.** Six painterly/AA-gradient props replaced with clean-cel art from the license-cleared Pixel Crawler Cemetery + Fairy Forest packs (same author as the game's existing art backbone; already in CREDITS.txt). Installed to `game/` + `mobile/game/`, reimported both, originals preserved in `backup/mush_originals/`. Full suite PASS (graveyard chapters load these), mobile compile gate PASS.

| Asset | Was | Now |
|---|---|---|
| tombstone | 108-color mush, two-stones-in-one | Clean rounded headstone (Cemetery Graves #0) |
| grave_cross | soft AA cross | Ornate cross-on-base (Cemetery Graves #4) — *renders tall (~1.8× hero); swap to a shorter cross if it reads too monumental* |
| grave_crack | unreadable 9px blobs | Dirt mound / disturbed earth (Cemetery Props #8) |
| grave_deadtree | blurry dead pine | Clean dead pine (Cemetery Tree #7) |
| tree_snow | 296-color pale sapling | Frost-recolored clean pine (Fairy Forest, palette-shifted) |
| flower | blurry green sprout | Clean pale daisy (Fairy Forest Props #49) |

**Spider quintet — NOT library-fixable, routed to regen. RESOLVED 2026-07-17.** The only library spider (Ninja Adventure SpiderRed/Yellow) is a bright 16px cartoon crab — wrong palette, wrong resolution, wrong silhouette. The current tick body needed a proper muted top-down spider (~32px) generated via PixelLab/ChatGPT, then recolored ×4 for bog_lurker/casket_creeper/deep_stalker/vent_skitter. **Done:** a new native-32px top-down spider (PixelLab `create_map_object`, high top-down, basic shading / single outline, 37→13 colors — clean cel, NOT AA) + a real 2-frame leg-scuttle (`animate_object` v3, frames 1 & 3 of the 5-frame clip). Recolored ×5 by luminance gradient-map (12 cel bands, shared shading structure) with a per-variant glowing-eye accent: spider = dark charcoal, bog_lurker = swamp green, casket_creeper = bone-white (dark outline kept), deep_stalker = MUTED teal (was neon cyan), vent_skitter = MUTED rust/amber (was neon orange). Installed by name to `game/` + mirrored to `mobile/game`, both reimported; base 32×32 + `_anim` 64×32 kept (32px cell → 2.55x on-screen). Originals backed up to `backup/mush_originals/`. Full suite + mobile quick suite green. Total PixelLab spend $0.02.

**Confirmed false positives — left as-is** (metric over-flagged; they read fine magnified): coffin, cottage_a/b, stall, merchant, crypt, tree_spore.

**Environment diversity pass — DONE.** The world read as "generated" because each terrain's obstacle/decor pool was thin (forests = 1 tree shape repeated; keep = a single pillar). The weighted-pool system already existed (`terrains.gd` per-biome `obstacles`/`decor` lists; `Art.tex(name)` resolves any `assets/sprites/<name>.png`), so the fix was pure content: cut clean-cel variant props from the license-cleared Pixel Crawler packs (Cemetery, Fairy Forest, Cave, Desert, Free Pack — all already in CREDITS.txt), recolor per biome (frost/autumn/volcanic/ashen tints), and expand every pool. Density (room prop `count`) held constant per the owner's 2026-07-12 anti-clutter lesson; big props (mushroom_purple, sandstone, statues) kept at weight 1 = ~1/room landmarks.

- **Graveyard**: 4 → 10 props (2 statue landmarks, grave cluster, dirt mound).
- **13 biomes** wired: village/darkwood/marsh/keep/magma/ice/desert/bog/crystal/storm/void/holy/spore — obstacle variety roughly doubled each (keep 1→4, desert 2→6, most 2→5). New shared kit: rock2, boulder, log, bush, grass, toadstool, mushroom_purple, rubble, sandstone, dead_shrub, bone + recolored rock_ice/rock_volcanic/rock_pale/bush_autumn/grass_frost/grass_autumn.
- 27 new prop PNGs installed to `game/` + `mobile/game/`, reimported both, all pools wired in both `terrains.gd`. Quick suite + mobile compile gate PASS; full suite validating.
- Placeholder terrains (ph_sewer/hall/fae) skipped (not in shipped play).

**Placement-system rework (2026-07-17) — after owner playtest feedback.** The diversity pass added variety but violated real environmental-art principles: distinctive props (whole skeletons, shovels, statues) scattered as freely as grass, a wood log appeared in the alien spore glade, density was a flat uniform count, and the cottage rendered hero-sized. Fixed the *system*, not just the data:
- **Scale hierarchy** — cottages now render ~250px wide (~2× the 88px hero); a house dwarfs a person, only bosses top a structure (`game_world.gd` `_add_building` target_w 120→250).
- **Non-uniform density** — each room rolls a fill multiplier in `Balance.SCENERY_DENSITY_JITTER` (0.6–1.3), so rooms vary sparse↔dense instead of a flat count.
- **Accent tier** — distinctive props moved to a per-terrain `accents` list, placed rarely and **never twice in a room** (seeded shuffle, sampled without replacement, `Balance.SCENERY_ACCENT_BASE` budget). Trees/rocks/grass stay in the free-scatter `obstacles`/`decor` pools (spammable by nature); skeletons/shovels/statues/big-mushrooms are now rare landmarks.
- **Thematic fit** — dropped the wood `log` from the spore glade; kept it only in wood-bearing biomes (village/darkwood/marsh/ice/storm/bog).

**REGIONS NEEDING ACCENT ALTERNATIVES** (owner asked to flag where the accent layer is thin/empty — these repeat or go bare):
- **EMPTY (0 accents, highest priority):** `crystal` (wants crystal clusters/geodes — Cave pack has partial fits), `void` (wants monoliths/rift-shards/obelisks — no library source, needs regen).
- **THIN (1 generic accent):** `village`/`darkwood`/`storm`/`ice` (only `log` — want well/cart/fence/stump/shrine/cairn; Free Pack Farm.png is a likely source), `keep`/`magma` (only `bones` — want broken statues/braziers/weapon-racks / obsidian spires/lava-vents/skull-piles; Free Pack Dungeon_Props), `spore` (only `mushroom_purple` — want giant spore pods/glowing fungi; Cave purple-mushroom variants).
- **RICH (no action):** graveyard (6), marsh/bog (4), desert (3), holy (2, statues reused).

---

## Priority fix list (cross-category, ranked)

1. **Veyx (ch7 boss) ships as the retired 32×32 `stormwarden` knight** — an 11x upscale (density 0.09 vs hero 1.19), wrong subject (should be a stormdrake), 2 frames, baked shadow (`ch7_bosses.gd:22`). Single biggest art defect in the game.
2. ~~`gardener.png` is a live ch6 boss~~ **CORRECTED 2026-07-17: false alarm.** The ch6 boss kind "gardener" sets `"sprite": "rotmaw"` (`ch6_bosses.gd:52`) and renders the proper PixelLab Rotmaw body. `gardener.png` is an orphaned unused mannequin file — delete or ignore.
3. **Hero legacy wrong-character strips (9 files) — CORRECTED 2026-07-17: mostly dead art, not live.** Verified against the runtime paths: `assassin_stab_dir`/`throw_dir` were retired 2026-07-10 (`player_core.gd:491` DIR_POSE is empty — "now dead art"); `paladin_dash` is unreachable (no paladin ability maps to the dash clip); `mage_attack2` is unreachable (mage a2 maps to cast). The five `<class>_death` strips (golden chibi paladin, purple fire-mage, leather-bandit warrior + gore pile, purple-hood assassin, old warlock) ARE live — but only on the default no-skin appearance, only on death; skins ship their own death strips that shadow them. **Action taken 2026-07-17:** the 4 dead strips + the orphans (gardener×3, direwolf×2, witch×2) moved to `backup/legacy_hero_strips/` (art preserved for reuse; mobile duplicates removed). **Still pending:** regenerate the 5 base-class death strips on the current PixelLab bodies — the archer's additionally never lands a corpse (frozen mid-air flail; the other five classes end grounded). Death beat retuned same day: 2.8s with a 1.4s ramping dim (`Balance.DEATH_BEAT_SECS/DEATH_DIM/DEATH_DIM_RAMP`) so the collapse actually reads.
4. **Frostfall Ranger (elite archer skin): NE/N/NW/W are a different outfit** (hood-down white gown vs hooded tunic; walk luminance Δ36.7 vs ≤12.7 for every other skin). Rotating mid-fight swaps her clothes. Per-direction re-roll on the original prompt.
5. **Stormforged (mythic warrior) ult/ultidle is a different character** — helmetless blue plume vs horned helm, 206px vs 230px frames, 15% proportion wobble across dirs, debris pixels in NW. Regenerate on the main body (metadata-first rule).
6. **The tick quintet** — spider, bog_lurker, casket_creeper, deep_stalker, vent_skitter: one AA-gradient tick body (byte-identical alpha masks, verified) recolored five times across FIVE chapters (1, 2, 3, 4, 6); deep_stalker/vent_skitter are neon. Replace the base body once, fix five families.
7. **Cinderhide** — Cerberus design invisible in play: near-black 13 colors on dark terrain, heads merge at 143px on-screen, smallest real boss despite armored-beast lore. Contrast lift + scale bump (≥ ~10.5); matches the standing redesign note.
8. **Auroch scale inversion** — "a weather system with horns" renders at 211px, smaller than human casters (Halla 258, Ashpriest 254). Scale ~11–12 + a corruption pass on the body.
9. **fx_ripple (score 34)** — a flat one-color disc whose 4 "frames" differ by 10–16 px; live in code. Needs actual concentric rings/alpha falloff.
10. ~~Mannequin NPCs in the ch2 hub~~ **CORRECTED: false alarm** — `placeholder: true` NPCs never spawn outside `--dev` (`game_world.gd:381-382`). The real item here is the inverse: **npc_hunter/bandit_tracker/royal_archer have finished art but ship nowhere** (same tag) — owner call pending per `ch2_hub.gd:32-39`.
11. **wall_moss** — 3 colors, ~2px features, the wall for FOUR shipped biomes (darkwood/marsh/bog/spore; fae/sewer are placeholder terrains). Still the worst asset-to-exposure ratio in the game.
12. **Icon re-rolls** — ability_warrior_a2 (grey-on-grey shield = boulder), ability_assassin_a2 (full figure = smear at 32px); both already on the CREDITS re-roll list — this audit confirms them and adds assassin_a1 (2px dagger, fill 0.122) as a watch.
13. **Hero drift strips (per-dir re-rolls)** — archer_cast_s/se (mid-cast palette hijack on the default facing), warrior_attack_e (9 frames vs 7 + armor redesign mid-strip; will desync 22fps timing), assassin_attack2_ne/nw (pink bare-chest frames), paladin_attack/attack2 (hood/weapon flicker), warlock_cast dir-split FX palettes.
14. **Dreadknight attack2 f3–f4** (full-body mint recolor) and **Voidwraith attack2 f3–f4** (pastel rainbow bubble) — one-anim skin fixes.

---

## Category detail

### 1. Hero classes + splash art

| Family | Overall | Res | Design | Theme | Creativity | Technical | Note |
|---|---|---|---|---|---|---|---|
| Warrior sprites | 78 | 85 | 92 | 96 | 85 | 55 | Best theme fit (ember black-plate); NE weapon drift, attack_e frame-count bug, legacy death |
| Archer sprites | 78 | 90 | 88 | 82 | 84 | 60 | Highest res + only complete 10-clip 8-dir family; cast S/SE character-warp, ult FX chaos per dir |
| Warlock sprites | 76 | 82 | 90 | 94 | 86 | 60 | Skull+grimoire reads great; cast FX palette splits 3 ways across dirs; walk base 9f vs dirs 7f |
| Assassin sprites | 74 | 75 | 92 | 95 | 88 | 45 | Strongest identity; stab/throw aim strips are the old purple-scarf ninja — but DEAD ART since 2026-07-10 (DIR_POSE retired) |
| Mage sprites | 70 | 80 | 86 | 90 | 80 | 45 | Beautiful frost elder; legacy purple fire-mage in attack2 (unreachable — a2 maps to cast) + death (live, no-skin only) |
| Paladin sprites | 70 | 82 | 88 | 90 | 82 | 40 | Solid body set; golden chibi knight in dash (unreachable — no paladin ability uses dash) + death (live, no-skin only) |
| Splash: warlock | 92 | 85 | 94 | 95 | 90 | 92 | Best of the six |
| Splash: warrior | 90 | 85 | 92 | 96 | 88 | 92 | Molten knight, perfect sprite match |
| Splash: paladin | 90 | 85 | 92 | 92 | 88 | 92 | Black/gold + chain-lantern, on-model |
| Splash: assassin | 88 | 90 | 90 | 92 | 84 | 90 | Grey wraith + daggers, on-model |
| phantom_splash | 85 | 88 | 90 | 92 | 86 | 75 | Square source letterboxed with baked blurred pillarbars |
| cover.png | 85 | 82 | 88 | 90 | 85 | 84 | On-title composition; AI faux-pixel checkerboard dither, no true grid |
| Splash: archer | 80 | 85 | 82 | 85 | 80 | 88 | Faceless/generic — loses the fur-mantled huntress; lightning ≠ kit |
| Splash: mage | 72 | 88 | 80 | 70 | 72 | 85 | Clean anime render breaks the painterly set; green staff crystal vs sprite's cyan |

Key evidence: legacy strips are identifiable by canvas (`warrior_death` 222px, `paladin_dash/death` 187px, `mage_attack2/death` 150px, `assassin_death` 207px, `assassin_*_dir` 207px, `warlock_death` 192px — class standards are 182/242/202/166/174/180). Bodies run 25–40% lower density than current art. **Reachability (verified 2026-07-17): only the five `_death` strips can render, and only for the default no-skin look — stab/throw poses are retired (`player_core.gd:491`), paladin_dash and mage_attack2 are unmapped in ABILITY_CLIP, and equipping any skin swaps the whole clip family (`player_core.gd:503-507`).** Zero nearest-neighbor upscaling and zero halo pixels anywhere in the hero set. `archer_death` never lands a corpse frame (ends mid-air, all 8 dirs). `archer_ultidle_nw` has stray white artifacts (frames 3–5).

### 2. Skins

| Skin | Overall | Res | Design | Theme | Creativity | Technical | Note |
|---|---|---|---|---|---|---|---|
| Paladin — Fallen Arbiter (mythic) | 91 | 90 | 92 | 92 | 90 | 88 | Black-winged fallen angel; best in set |
| Assassin — Phantom Awakened (mythic) | 90 | 90 | 92 | 90 | 92 | 88 | Hollow-hood teal-flame wraith |
| Paladin — Eclipse Knight (elite) | 88 | 90 | 90 | 84 | 88 | 90 | Sun-halo black/gold knight |
| Assassin — Phantom (mythic) | 88 | 88 | 88 | 90 | 85 | 90 | Tightest 8-dir set |
| Warlock — Hellfire Inquisitor (elite) | 87 | 90 | 87 | 88 | 85 | 90 | Fully consistent 8-dir |
| Mage — Crystal Archmage (mythic) | 86 | 90 | 90 | 78 | 86 | 90 | Brightest cast; at the palette ceiling but desaturated, passes |
| Assassin — Blade Dancer (elite) | 82 | 88 | 85 | 80 | 82 | 80 | Flat pure-white slash blob attack f3–f6 |
| Warlock — Eldritch Herald (mythic) | 82 | 88 | 82 | 85 | 75 | 88 | Closest to generic robed caster |
| Warrior — Dreadknight (elite) | 80 | 88 | 84 | 86 | 78 | 72 | attack2 f3–f4 recolors body mint + flips wings red-brown |
| Archer — Voidwraith (mythic) | 79 | 88 | 82 | 74 | 80 | 82 | attack2 pastel rainbow bubble breaks void identity |
| Mage — Void Weaver (elite) | 78 | 88 | 76 | 85 | 68 | 84 | Back views near-featureless cloak cone; least distinctive |
| Warrior — Stormforged (mythic) | 72 | 86 | 88 | 88 | 84 | 55 | Main set excellent; ult/ultidle is a different character |
| Archer — Frostfall Ranger (elite) | 62 | 88 | 78 | 80 | 70 | 45 | North-side dirs are a second outfit |

Verified non-issues (don't re-chase): zero upscaling across all 1,030 files; frame-size differences between files are engine-normalized (`player_core.gd:610`); skin body heights vs base classes normalize out. `skins/archive/` = two retired archer skins at half body res, correctly out of tree.

### 3. Bosses

| Boss | Overall | Res | Design | Theme | Creativity | Technical | Note |
|---|---|---|---|---|---|---|---|
| Saint Varo throne+standing (ch3) | 87 | 62 | 92 | 95 | 92 | 82 | Best staging in the roster |
| Halla (ch5) | 87 | 58 | 90 | 88 | 95 | 85 | Most distinctive silhouette |
| Vargoth (ch1) | 85 | 55 | 92 | 95 | 85 | 80 | Top-tier; 7.9x upscale vs hero density |
| Forgemistress (ch4) | 85 | 70 | 88 | 92 | 85 | 85 | Best density of the customs (0.61) |
| Choirmother (ch2) | 84 | 64 | 85 | 90 | 90 | 85 | Also cast as 3 hub NPCs (see below) |
| Stormmouth / Cyrraeth (ch7) | 84 | 52 | 90 | 90 | 82 | 85 | Worst custom density 0.34 — matches the standing hi-res note |
| Kaethra (ch6) | 84 | 60 | 88 | 90 | 90 | 88 | Clean, extra stab strip |
| Sexton (ch3) | 83 | 68 | 84 | 92 | 84 | 85 | — |
| Serane (ch5) | 83 | 64 | 85 | 92 | 82 | 85 | — |
| Nullwarden (ch2) | 82 | 60 | 90 | 88 | 78 | 75 | Ability cell grows 45px below feet (documented slam case) |
| Hrolgar (ch5) | 82 | 68 | 86 | 90 | 80 | 78 | — |
| Echo (ch7) | 82 | 58 | 85 | 90 | 85 | 85 | — |
| Korrag (ch2) | 81 | 62 | 85 | 88 | 80 | 78 | Idle holds chain-flail, ability swings a maul |
| Morwen (ch1) | 80 | 62 | 80 | 90 | 82 | 85 | — |
| Ashpriest (ch4) | 80 | 58 | 82 | 90 | 75 | 80 | — |
| Rotmaw (ch6) | 79 | 58 | 80 | 88 | 80 | 82 | — |
| Vess (ch3) | 76 | 55 | 78 | 88 | 75 | 72 | Base cell half padding (82×106 bbox in 216px cell) |
| Auroch (ch6) | 60 | 60 | 60 | 70 | 40 | 75 | Zero boss menace; scale-inverted |
| Fangmaw (ch1) | 55 | 45 | 55 | 75 | 40 | 70 | Generic near-black wolf; weakest first impression of the campaign |
| Cinderhide (ch4) | 55 | 50 | 45 | 80 | 70 | 60 | Cerberus invisible at gameplay size |
| Veyx / `stormwarden` (ch7) | **12** | 5 | 25 | 15 | 15 | 20 | Retired 32px knight at 354px on-screen |
| Dev placeholders (cyclops/tengu/flame_giant/great_spirit/ooze/kraken) | 22 | 25 | 30 | 5 | 20 | 40 | Pastel pack art; tengu (60px) + ooze (69px) smaller than the 88px hero; flame_giant == great_spirit (same sprite, byte-duplicated) |

Size ladder (on-screen body px): stormmouth 361 → stormwarden 354 → vargoth 308 → nullwarden 271 → halla 258 → ashpriest 254 → varo 252 → rotmaw 245 → echo 240 → kaethra 236 → korrag/vess 215 → **auroch 211 (inverted)** → morwen 205 → serane/choirmother 201 → forgemistress 197 → hrolgar/sexton 190 → **fangmaw 155** → **cinderhide 143 (worst inversion)**. Mechanism: wide beast bodies fill less cell height (0.41–0.42 vs 0.85–0.90 humanoid) and got no compensating scale stat.

### 4. Mobs (worst-first)

| Mob | Overall | Res | Design | Theme | Creativity | Technical | Note |
|---|---|---|---|---|---|---|---|
| spider | 30 | 25 | 35 | 40 | 20 | 35 | A glossy amber TICK, not a spider; 122 AA colors; base for 4 recolors |
| deep_stalker | 32 | 25 | 35 | 25 | 10 | 35 | Neon-cyan tick recolor |
| vent_skitter | 32 | 25 | 35 | 28 | 10 | 35 | Neon orange tick recolor; most saturated mob (0.59) |
| direwolf | 33 | 20 | 40 | 40 | 45 | 25 | 361 unique colors of dither — but ORPHANED: never spawns anywhere (verified) |
| storm_harrier | 35 | 40 | 30 | 35 | 15 | 55 | Saturated blue wolf recolor, 2 frames; canine body is lore-correct ("plains hounds") — recolor note only |
| bog_lurker | 36 | 25 | 35 | 45 | 10 | 35 | Dark-green tick recolor |
| casket_creeper | 38 | 25 | 38 | 50 | 12 | 35 | Bone-white tick recolor |
| elf_ranger | 45 | 55 | 60 | 50 | 55 | 25 | Baked 2px salmon halo — looks permanently aggro'd |
| sentry | 48 | 50 | 50 | 35 | 50 | 65 | Arcade-cyan armor + orange boots |
| elf_druid | 50 | 60 | 50 | 40 | 55 | 65 | Clown-pink face on green bush body |
| banshee | 52 | 55 | 50 | 55 | 60 | 55 | 18px body in 48px cell; christmas palette clash |
| beastkin | 55 | 50 | 55 | 65 | 60 | 55 | Detail soup at 32px; 2 frames |
| bat / direbat | 55/56 | 55/60 | 60 | 45/48 | 55 | 65/55 | Purchased pack, cute/cartoon lean |
| wolf / blightwolf / winterfang | 56–57 | 55 | 58–60 | 62–70 | 30–40 | 70 | Clean muted wolf + 2 recolors |
| mummy family (4) | 58–62 | 60–62 | 60–65 | 42–48 | 55–58 | 70 | Bright Egyptian teal/gold — another game's desert |
| orc / orc_rogue / orc_shaman | 58–62 | 58–62 | 62–65 | 45–55 | 55–60 | 72 | Cartoon-green skin; shaman cell size differs from siblings |
| rat family (4) | 58–65 | 62 | 58–65 | 45–62 | 58–60 | 70–72 | rat_mage vivid purple/pink |
| fungus family (4) | 60–64 | 62–68 | 62–68 | 50–55 | 58–62 | 72 | Saturated red-orange caps |
| witch | 62 | 55 | 65 | 72 | 65 | 60 | Muted, creepy — but DEAD ART: no enemy def, no convo speaker; never renders (verified) |
| duneprowler | 63 | 55 | 65 | 70 | 55 | 72 | Best of the 2-frame group |
| skeleton family (4) | 63–67 | 62–64 | 60–68 | 60–68 | 50–62 | 75 | Clean; padding bug from prior audit FIXED |
| zombie family (3) | 63–64 | 62 | 62 | 55–65 | 55–58 | 72 | Teal/purple cartoon lean |
| orc_warrior | 67 | 64 | 70 | 58 | 62 | 75 | Best orc |
| elf_wild / beastkin_caged | 66 | 60–64 | 65–68 | 68–70 | 65 | 70–75 | — |
| stone_broken | 68 | 45 | 70 | 75 | 65 | 72 | Good design; 23px cell = worst density in the game (~4.4x vs hero) |
| grove_horror | 70 | 68 | 72 | 80 | 75 | 68 | Genuinely creepy; full 8-frame anim |
| stone_lava / stone_base / stone_golem | 70–73 | 55–64 | 72–75 | 78–82 | 70 | 72–75 | On-palette |
| bandit family (3) | 70–71 | 66 | 70–72 | 75 | 62–65 | 75 | Muted, fits |
| static_caller / null_acolyte | 71–72 | 66 | 70–72 | 78–80 | 65–68 | 75 | — |
| vow_sentinel | 74 | 66 | 72 | 82 | 68 | 78 | Quiet and right |
| stormcult | 75 | 66 | 75 | 82 | 72 | 78 | — |
| cultist | 76 | 66 | 75 | 85 | 72 | 78 | Best mob vs the art bible |

Density mechanism (`enemy.gd:395`): on-screen magnification = scale × 27.2 / cell. All mobs are stored native (no baked upscales); the chunkiness is cell size (23–36px for most) vs the hero's ~106–121px source at 0.8x. The never-re-cut group (wolves, ticks, witch, beastkin, duneprowler, storm_harrier) also has only 2 frames total vs the pack-standard 1+4+6.

### 5. NPCs

| Asset | Overall | Res | Design | Theme | Creativity | Technical | Note |
|---|---|---|---|---|---|---|---|
| npc_hunter | 78 | 70 | 80 | 85 | 80 | 78 | Best NPC — yet still tagged `[ph]` (ch2_hub.gd:40) |
| scholar_censor | 76 | 70 | 78 | 70 | 76 | 78 | Brightest NPC but reads as intent |
| royal_knight | 75 | 70 | 76 | 80 | 66 | 76 | — |
| royal_priest | 74 | 70 | 75 | 78 | 70 | 76 | — |
| scholar_director | 74 | 70 | 78 | 76 | 74 | 60 | Walk 32px vs base 31px → 1.5px size pop idle↔walk |
| npc_bandit_tracker | 72 | 70 | 74 | 78 | 72 | 75 | Distinct silhouette |
| npc_scholar_a / b | 70 | 70 | 70–72 | 62–68 | 66–74 | 72 | — |
| royal_soldier | 68 | 68 | 66 | 74 | 55 | 72 | Thin (fill 0.30) |
| npc_royal_archer | 65 | 70 | 62 | 72 | 55 | 72 | Generic |
| warden | 60 | 60 | 58 | 68 | 78 | 40 | Distinctive eldritch octopus; old-batch style |
| king | 58 | 60 | 60 | 60 | 68 | 40 | Reads "fire knight" not king |
| elder | 55 | 60 | 58 | 62 | 60 | 40 | Old batch |
| merchant | 55 | 60 | 60 | 55 | 65 | 35 | 123 colors in 32px — busiest sprite |
| aldric | 52 | 60 | 55 | 62 | 45 | 40 | Named character with no visual hook |
| envoy | 48 | 60 | 52 | 35 | 60 | 40 | Pink boots + gold hair + flame hand — JRPG-cheerful |
| villager | 45 | 55 | 50 | 55 | 30 | 35 | Reused as ~25 named characters — sameness by reuse |
| npc_elder2 / npc_villager_f / npc_villager_m | 12 | 70 | 8–10 | 15 | 5 | 40 | 8-color beige mannequins — dev-launcher only, never ship (verified) |
| npc_wanderer | 10 | 70 | 8 | 12 | 5 | 40 | Naked base body — dev-launcher only, never ships (verified) |
| gardener | 10 | 65 | 8 | 12 | 5 | 35 | Orphaned file — NOT the ch6 boss (that renders `rotmaw.png`); unused, deletable |

Structural: two NPC generations coexist in the same hub rooms (old batch: black outlines + baked shadows + 2-frame idles; new batch: soft outlines, 4+6 anims). The engine composites its own shadow under every NPC (`game_world.gd:912-915`) → old-batch NPCs render **two shadows**.

### 6. Environment / props

Top tier: chest_a 85, grave_bones 82, crypt 80, tree_spore 80, rock 78, coffin 75, tree_green 75, deadtree 72.
Mid: cottages 68–70 (good art, wrong scale language — house shorter than the 88px hero, ~25px doors), tree_autumn 68, mushroom 60 (bright salmon cartoon, taller than the hero), bridge 60, stall 55.
Problem cluster (painterly-downscale noise, magnified 3x in-world): tombstone 50 (108 colors in 12×31; two stacked stones placed as one totem column), grave_cross 55, chest_d 48, chest_b/f 45, chest_c 42 (noise + a tilt matching no other prop), flower 30 (85 colors in 6×16 — a green smudge), grave_deadtree 30 (270 colors), tree_snow 25 (296 colors; ice biome's primary obstacle is a noisy sapling), grave_crack 15 (unreadable at any zoom).
Walls (weakest set): wallblock 50, wall_wood 42, wall_grave 40, wall_volcanic 40 (mean V 0.144 — risks reading as void post-tonemap), wall_sand 38, wall_ice 35 (**brightness outlier**: mean V 0.689 vs 0.14–0.42 all others), gate 30, **wall_moss 22** (3 colors, serves six biomes).
Note: `chest.png` does not exist — family is chest_a/b/c/d/f (+s).

### 7. Icons, FX, projectiles

| Asset | Overall | Res | Design | Theme | Creativity | Technical | Note |
|---|---|---|---|---|---|---|---|
| choir_censer | 89 | 88 | 90 | 92 | 90 | 85 | Excellent boss-projectile identity |
| Ability: warlock | 86 | 80 | 85 | 92 | 84 | 90 | Strongest class-color identity |
| Ability: mage | 85 | 90 | 88 | 80 | 62 | 90 | Best readability; most generic iconography |
| Ability: paladin | 85 | 88 | 86 | 76 | 82 | 90 | Crown-of-flame a2 = standout icon of the set |
| fx_ice | 85 | 85 | 90 | 82 | 75 | 88 | Best FX strip — currently unused (spare) |
| fx_slash | 82 | 85 | 85 | 82 | 60 | 88 | — |
| Gem ladder (11) | 79 | 78 | 80 | 85 | 82 | 76 | lv9==lv10 intentional (runtime crown pip); gem.png == gem_lv3.png byte-identical |
| fx_circle | 79 | 80 | 82 | 80 | 60 | 85 | — |
| Ability: archer | 78 | 82 | 78 | 74 | 70 | 90 | a3 reads as a MOON + silhouette-collides with warrior_a3 |
| dart | 78 | 78 | 80 | 88 | 65 | 80 | Near-black; risks vanishing on dark floors |
| fx_circle_spark | 77 | 78 | 80 | 78 | 65 | 85 | Unused spare |
| Buff set (7) | 74 | 88 | 75 | 70 | 55 | 72 | armor/ward + atk/blood = hue-only silhouette duplicates; buff_damp style outlier |
| fx_slash_arc | 74 | 80 | 78 | 68 | 60 | 75 | Only non-square FX frames (38×34); unused spare |
| fx_impact | 72 | 78 | 74 | 60 | 65 | 82 | Cream/orange cartoon burst — biggest FX tonal clash |
| Ability: assassin | 70 | 60 | 72 | 88 | 78 | 90 | a1 dagger ~2px line; a2 full figure = mush at slot size |
| Ability: warrior | 68 | 62 | 70 | 78 | 65 | 90 | a2 grey-on-grey shield reads as a rock |
| shuriken | 68 | 82 | 75 | 70 | 60 | 55 | Only smooth/AA non-pixel-art asset audited (546 colors) |
| fx_ripple | 34 | 35 | 30 | 45 | 25 | 50 | Flat one-color disc; frames differ by 10–16px — a static puddle |

Set-level: all 24 ability icons are exactly 32×32, 12 colors, 0 semi-alpha — the tightest set coherence in the project; failures are per-icon readability only. HUD renders icons at 44px from 32px sources (1.375x nearest → minor shimmer, systemic). Style splits in the wider icons folder: icon_shield/w_kunai (smooth-shaded) and ward_elixir/renewal_draught (ChatGPT family) sit beside 16px-native rows.

---

*Review-only audit: no game files were modified. Metrics CSVs and labeled contact sheets were generated in the session scratchpad (temporary). Score calibration: each category was judged against the PixelLab hero standard at gameplay zoom; cross-category scores are comparable at the ±5 level.*
