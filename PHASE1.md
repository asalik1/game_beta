# Phase 1 — Build Checklist

Working order for the Phase 1 scope agreed in [DESIGN.md](DESIGN.md).
Each item lists what "done" means. Check things off as they land; the
autotest must pass at every checkpoint.

---

## ✅ 1. Save / load system — DONE (2026-07-03)
- [x] JSON saves per character (`user://save_<n>.json`, up to 6 slots)
- [x] Autosave on story progress / zone change / menu close / window close
- [x] Title screen: continue, delete, new game
- [x] Resonance + faction standing fields persisted from day one
- [x] Autotest: roundtrip + fresh-boot resume

## ✅ 2. Choice dialogue + quest flag engine — DONE (2026-07-03)
The narrative engine everything else runs on.
- [x] Dialogue nodes with player CHOICES (up to 4, picked with number keys)
- [x] Choices set flags, shift Resonance, and shift faction standing
- [x] Lines gated by Resonance BAND (tempted / neutral / steady)
- [x] Lines and choices gated by story flags (`req_flag`, `req_band`)
- [x] Flags persist in the save file (`game.flags`)
- [x] Data-driven format documented at `Story.CONVOS`; engine is
      `game.run_convo()` / `run_convo_id()`
- [x] Autotest: scripted convo takes a choice, asserts flag + Resonance +
      faction shift + flag-gated and band-gated variants
- Note: faction-standing-gated lines can be added when first needed
  (same one-line pattern as `req_band`).

## ✅ 3. Pilot class opening: Warrior (retrofit) — DONE (2026-07-04)
- [x] Opening scene (`Story.CONVOS.open_warrior`): the blackout on the
      road — the scene is the aftermath, not the fight
- [x] Three-way choice (own it / excuse it / walk away) shifting
      Resonance ±12/−4 and setting `owned_the_harm` /
      `excused_the_harm` / `walked_away`
- [x] Maren's greeting (`maren_warrior`) has a distinct variant per flag
- [x] Warrior-only: other classes keep the generic intro until
      Priority 6; old saves without the flag get the classic elder beat
- [x] Autotest: plays the opening, takes a choice, asserts flag +
      Resonance, and asserts Maren's flag-gated greeting
- Note: written as Ser Aldric's opening (Chapter 1 canon); re-frames to
  the shard-bearer era wholesale when Chapter 2 arrives.

## ✅ 4. Paladin (new melee class) — DONE (2026-07-04)
Full new-class pipeline — the checklist below is the reusable template.
- [x] Kit: Judgment / Consecration (heal-on-hit) / Aegis (guard +
      redirect smite) / Chains of Wrath (tether-drag ult), bruiser base
      stats per the melee rule
- [x] Class passive (Sanctified: phys+mag res, small lifesteal) +
      ATTR_SCALE row (STR primary, INT converts to real power too)
- [x] 3 themes (Holy / Aegis / Wrath) × 4 abilities = 12 unique variant
      entries in ABILITY_THEMES
- [x] Hammer weapon shape (art + SHAPE_STYLE: crushing + sturdy)
- [x] Talent tree (4 rows × Holy/Aegis/Wrath columns)
- [x] S-grade legendary (Dawnbreaker: Judgment light pillar) + passive,
      A-name pool entries
- [x] Sprite (procedural grid — drop paladin.png in assets/sprites to
      override), ability glyphs, bell-toll ult sound (no jingle)
- [x] Class select card + codex entries (both data-driven; the select
      screen now lays out 6 cards adaptively)
- [x] Autotest: kit section (aegis smite, holy mend, chains drag)

## ✅ 5. Warlock (new ranged class) — DONE (2026-07-04)
Same pipeline as Paladin. Kit: Shadowbolt / Hex (curse EXPLODES on
death, chains) / Dark Pact (12% max-HP sacrifice, lifesteal surge) /
Void Rift (pull ticks, delayed burst). Curse / Pact / Void themes,
Tome weapon shape, ranged damage tax, Soulthirst lifesteal passive.
S-grade Grimoire splits Shadowbolt to a second enemy. Autotest covers
hex detonation, the blood price, and the rift burst.

## ✅ 6. Remaining five class openings — WRITTEN & WIRED (2026-07-04)
All on the warrior scaffold: cinematic cues, 3-way Resonance choice,
flag-gated Maren greeting. Wiring is generic (`open_<class>` /
`maren_<class>` in Story.CONVOS), so Paladin/Warlock openings activate
automatically the moment those classes are selectable.
- [x] Assassin (the carter's fire — took warmth to survive)
- [x] Mage (the heal that came out GREEN)
- [x] Archer (the thread to home, snapped like a bowstring)
- [x] Paladin (the verdict, with the chain pulling the other way)
- [x] Warlock (the tome offering a candle of knowing)
- [x] Cutscene scenes for all five (camp/sickbed/homestead/hearing/tome,
      each with a before/after variant)
- [x] Autotest: convo-graph integrity for all 12 convos + assassin
      opening E2E (temptation path)

## ✅ 7. Chapter 2 world — Act 1 → Act 2 — DONE (2026-07-04)
Built as a parallel-agent task board — **[CH2_TASKS.md](CH2_TASKS.md)**,
all eight tasks complete. What shipped:
- [x] Chapter framework + content-module registry (T0): data-driven
      chapters, chapter select, per-chapter saves
- [x] Maren's camp hub with 8 NPCs, briefing that reads your opening (T1)
- [x] Nine combat zones across 10 terrains, 12 new monsters, Lv 1→16
      arc (T2+T3); Warden Null ends the chapter with its own epilogue
- [x] Three new bosses on the telegraph/enrage architecture (T4)
- [x] Accord vs. Cinderborn exclusive arcs + Wildfang/Choir ambient
      standing + FACTIONS panel (T5)
- [x] Aldric and the truth about the Crown (T6)
- [x] Resonance surfaced: band-reactive NPCs + merchant haggling (T7)

---

# 🏁 PHASE 1 COMPLETE (2026-07-04)
Every item above is done and covered by the autotest. What ships:
six classes with cinematic, choice-driven openings; a Resonance system
the world visibly reacts to; save/load with a title screen; two full
chapters; factions; and 30+ autotest sections keeping all of it honest.
**Next milestones (from README):** balance/playtest pass → Steam
export → Android → co-op (Phase 2 / DESIGN.md).

---

**Later (Phase 2 / expansion — do not start):** co-op, Hollow Throne raid,
Death Knight, Summoner, faction promotion. See DESIGN.md Phase Plan.
