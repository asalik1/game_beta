# Chapter 2 — Task Board (PHASE1 item 7)

Rules for parallel agents working this board:
1. **One task = one owner.** Claim it here (put your mark on the line) before starting.
2. **Each task creates NEW files** under `game/scripts/content/` plus at most
   its listed registration lines. Never edit another task's files.
3. Run the full autotest before staging. Stage with `git add` (no commits).
4. Shared files (`game.gd`, `story.gd`, `save.gd`, `menus.gd`, `player.gd`)
   belong to T0 during its window — do not touch them until T0 lands.

---

## ✅ T0 — Chapter framework + content-module registry — DONE: agent-A (2026-07-04)
**Shared files are UNLOCKED — T1/T2/T3/T5/T6 may start.**
- [x] Data-driven chapters: `Story.CHAPTER_LIST[id]` (zones/start_quest/
      final_boss/start_pos); `game.switch_chapter(id)` tears down the
      `world` container node and rebuilds; boss chain, gates, quests all
      derived from zone data (no more hardcoded fangmaw/morwen/vargoth)
- [x] New Game flow: chapter select (number keys or click) → class select;
      Chapter 2 placeholder hub "Maren's Camp" boots and plays
- [x] Saves store `chapter`; load_save switches chapters before applying;
      reconcile is generic (boss-dead OR `gate_flag` opens a zone's gate)
- [x] Content registry: modules in `scripts/content/` expose CONVOS /
      ENEMIES / QUESTS / CHAPTER_ZONES consts; register with ONE preload
      line in `Story.CONTENT_MODULES`; merged via `Story.load_content()`
      into `ALL_CONVOS` / `ALL_ENEMIES` / `ALL_QUESTS` / `CHAPTER_LIST`.
      **Format doc: `scripts/content/README.md`.** Zones support
      data-driven `"npcs"` (spawn + convo on talk) and `"gate_flag"`
- [x] Autotest hook point marked near the end of `_run()` (one func +
      one call line per task); ch2 hub smoke test added
- **Read this before starting a content task:** `scripts/content/README.md`

## T4 — New bosses ×3 (CAN START NOW — does not need T0) — CLAIMED: agent-B (2026-07-04, in progress)
Telegraphs + enrage per the existing architecture. Suggested trio:
a corrupted Stormwarden beastmaster (Fangmaw's successor), a blight
"Choir Mother" (Mórwyn's echo), and an Accord/Cinderborn-agnostic
construct in the ruins.
- [ ] Signature moves on `game.telegraph()` + enrage threshold each
- [ ] Creature-appropriate voices (real recordings > synth growls),
      per-boss music track names (override folder), codex entries
- [ ] Dev-mode spawnable (add to the F1 boss list) + autotest kill-flow
- **Owns:** `content/ch2_bosses.gd` (data) + new boss move funcs in
  boss.gd (append-only at file end), `assets/sounds/roar_*`,
  `assets/music/boss_*`
- **Done when:** each boss spawns from dev mode, fights, enrages, dies.

## ✅ T1 — Maren's camp hub — DONE: agent-A (2026-07-04)
- [x] Hub zone via `content/ch2_hub.gd` CHAPTER_ZONES (safe, merchant,
      `gate_flag: "ch2_briefed"` — road east opens after the briefing)
- [x] Maren's briefing reads the NEW COMMON opening flags
      (`chose_virtue` / `chose_temptation` / `chose_away` — all 18
      opening choices now set one; gate future content on THESE, not the
      18 per-class flags), offers a tempted-only `req_band` option, sets
      quest `ch2_act1`, and short-circuits on repeat visits
- [x] Camp NPCs: Sentry Piet (new `sentry` sprite — Crawl vault_guard)
      and Widow Sera, both with Resonance-band chatter variants (the
      Greyrun mill line is a free quest hook for T2)
- [x] Engine additions (T0 owner): convo variants may carry `next`
      (short-circuit, skips choices), nodes/choices may carry `quest`,
      choice flags go through `set_flag` so `gate_flag` gates open live
- [x] Autotest `_test_ch2_hub` at the module hook
- **For T2:** point quest `ch2_act1` onward, and consider Sera's
  blue-door mill on the Greyrun as an Act 1 side beat.

## ✅ T2 — Act 1 combat zones — DONE: agent-A (2026-07-04)
- [x] Four zones east of camp: The Greyrun Mills (bog), The Howling
      Fields (storm), The Sporewood (spore), Choir's Hollow (graveyard)
- [x] Six new ENEMIES at **Lv 3–8** (fresh ch2 heroes start at Lv 1 —
      the board's original 12–25 assumed a timeskip level grant that
      doesn't exist; T3 should run ~Lv 9–16): Waking Wolf, Greyrun
      Lurker, Wildfang Raider/Howler (beastkin sprite), Spore Shambler,
      Choir Cantor
- [x] T4's bosses placed act-scaled via new zone key `"boss_level"`
      (Stormwarden @8 ends the warband, Choir Mother @10 ends the act);
      Boss routing fixed: zone-spawned content bosses now DRIVE the
      chapter (quests/gates), dev/test spawns stay story-neutral
      (`Boss.story_boss` flag)
- [x] Arc contract honored: Mills clear sets `blight_scouted`
      (+ opens its own gate — bossless zones use `clear_flag`+`gate_flag`);
      the fallen courier yields `relic_recovered` (Cinderborn option when
      joined, mercenary or burial otherwise); Sera's blue-door mill
      stands in zone 1 (`mill_seen`, +3 Resonance)
- [x] Quest chain: briefing → clear east → Stormwarden → Choir Mother →
      `done_ch2`; merchants only in truly safe zones, wandering arrivals
      on pacification (boss OR full clear)
- [x] Autotest `_test_ch2_act1` plays the whole act

## T3 — Act 2 combat zones (after T0)
Same shape as T2: magma / ice / crystal / void / holy / desert, ~Lv 25–40,
the world "opening up as the Waking spreads" per DESIGN.md.
- **Owns:** `content/ch2_zones_act2.gd`

## ✅ T5 — Faction arcs: Accord vs Cinderborn — DONE: agent-A (2026-07-04)
- [x] Recruiters at the camp (Warden Callis / Envoy Vessa, new `warden` +
      `envoy` sprites): full pitches, band-gated barbs, exclusive JOIN
      (`joined_accord` / `joined_cinderborn` + `faction_chosen`; ±20/−10
      standing; rival short-circuits to a dismissal, no join offered)
- [x] Arc step 1 quests set on join (`ch2_accord1` / `ch2_cinder1`).
      **Contract for T2:** completing them = zone content setting flags
      `blight_scouted` / `relic_recovered` (recruiter follow-ups can then
      be added in ch2_factions.gd — my file, ping agent-A or extend)
- [x] Ambient standing encounters: the caged beastkin scout (`beastkin`
      sprite; free / water / refuse — one-time, resolves permanently) and
      the Hollow Choir pilgrim (listen / rebuke — repeatable greeting)
- [x] Standing UI: FACTIONS section in the inventory Stats tab (colored
      standing values, ⚑ JOINED marker, faction descriptions on hover)
- [x] Engine: choice gate `req_not_flag` (exclusivity), documented
- [x] Autotest `_test_ch2_factions` at the module hook

## ✅ T6 — Aldric lore NPC — DONE: agent-A (2026-07-04)
- [x] Ser Aldric at the camp's south fire (`aldric` sprite — Crawl
      imperial_myrmidon, worn armor for a burned-out legend)
- [x] Hub-and-spokes convo `ch2_aldric`: greeting with band variants
      (tempted/steady), three questions asked in any order with a
      loop-back hub — the cost of the blow, the Crown's true nature
      (req `ch2_briefed`), and "what I never told Maren"
      (req `blight_scouted` — T2's act flag): the Crown DISMISSED
      itself and the shards went LOOKING. Sets `aldric_truth`
      (council-ending material later); tempted bearers get a personal
      version of the reveal
- [x] No superboss; he cannot fight
- [x] Autotest `_test_ch2_aldric` (question count gates, hub loop, flag)

## T7 — Resonance surfacing pass (LAST — after T1/T2/T5 content exists)
- [ ] Ambient reactions per band across hub + zones: greeting variants,
      NPC emotes, small touches (e.g. merchants haggle differently with
      the tempted)
- Touches other tasks' convo files ONLY by adding `variants` entries —
  that's why it goes last, single owner, quick pass.

---

**Dependency graph:** T4 anytime · T0 first → then T1/T2/T3/T5/T6 in any
order/parallel → T7 last.
**Suggested split for two agents:** Agent A takes T0 (then T1+T5);
Agent B takes T4 now (then T2+T3+T6). T7 to whoever finishes first.
