# Small Mercies and connected exploration

This pass connects existing quest, exploration and cosmetic systems and gives kept promises a visible home. Work stays on `codex/crownless-wayfinder`; the source snapshot remains untouched.

## Quest guidance

The first accepted side quest is tracked automatically when there is no active selection. Any active Journal card can replace or stop tracking. Tracked quests sort first, unfinished quests precede completed ones, objective text wraps, and cards preview their authored rewards.

A compact card beneath the tactical map shows the next unfinished objective. The guide indexes actual conversation flag setters and locates their authored props or live seeded NPCs; kill/hunt objectives locate surviving matching enemies. It chooses a reachable charted destination and uses the existing Wayfinder route and lock rules. In-room objectives receive a gold diamond. Unknown destinations stay unlocated until explored. Manual atlas pins stop automatic quest routing. Unsupported/off-map verbs remain honest text objectives rather than fabricated routes.

Selection belongs to the character's save and is not a multiplayer world flag. Guests see shared completion without a misleading local kill counter. Objective changes update the guide; completed or out-of-scope quests hide it. No new RPC or protocol version.

## Six discoveries, a growing sanctuary

| Companion | Chapter | Rescue site |
|---|---|---|
| Spore Pup | 1 | The Hollow Oak |
| Hearth Hopper | 1 | The Drowned Chapel |
| Cinder Bat | 1 | The Collapsed Tower |
| Ash Crow | 2 | The Cold Waystation |
| Glimmerwing | 2 | The Drowned Race |
| Pale Flutter | 2 | The Unbroken Font |

Approach and interact, then remain nearby for 2.8 seconds while freeing the creature. Distance, injury, danger, death and overlays cancel the work. Solo pause notifications cancel immediately; online overlays are checked without assuming the shared world pauses.

Each rescue grants the existing account cosmetic for free, once per hero, using the existing ownership ledger. An empty companion slot equips the rescue. No combat powers or farmable currency. Renown purchases remain available. The character's `sq_kept_rescue_*` history survives chapter wipes and stays personal in co-op; both players can rescue their own animal. Claims autosave.

The original shelter at Stillwater Reach and Accord Commons displays this hero's rescued animals, moving gently around their home. The active follower accompanies you instead of appearing a second time in the shelter. The collection opens there, in Journal → Activities, and Codex → Sanctuary. Location hints, lore and equip/return controls are available in the collection. No room indices changed.

## Companion and world presentation

September 8 follow-up: the original portrait bob was insufficient for moving
animals. All six now have actual eight-frame steps, hops or wingbeats, with
grounded idle and sanctuary walking. See [COMPANION_MOTION.md](COMPANION_MOTION.md).

A shared companion renderer uses six original painted companion portraits, alpha-body normalization, ground/flying motion and a correctly scaled fallback for horizontal idle strips. Following is frame-rate independent, pauses under overlays, hides on death and snaps after long teleports. It respects world depth sorting. This fixes the old strip-height division that could multiply a pet's size by its frame count.

The Hunter's Rounds place visible crossed trail signs at the ravine, chapel and tower. A Flame at the Window leaves a lit pine torch and warm glow. Paying Osla's debt leaves a blue ribbon at the Hollow Oak. Their kept flags restore the marks on later visits.

The painted set replaces low-resolution companion placeholders across the world, collection and Wardrobe, without changing combat-monster sprites.

New art provenance: `art_src/sanctuary_2026-09-07/README.md`.

Long HUD announcements now measure and wrap their title and detail text, expanding the plaque to keep rescue descriptions and long reward messages readable.

## Validation

The systems test covers all six authored sites, personal flag classification, duplicate claims, account ownership, every companion's frame scale, charted/unseen targets, objective advancement, manual route handoff, and character save fields. `shot.bat exploration --timeout=240` uses the real world for cancellation, successful rescues, both sanctuaries, quest routing and desktop/touch screenshots. Desktop full suite: **181 checks**, `build/qa/exploration-full.log`, strict verdict passed with no script errors. Desktop quick suite also passed. The final muted live rig produced **13 reviewed captures** in `build/qa/exploration-release-user/Godot/app_userdata/Crownless/shots/exploration/`; its log is `build/qa/exploration-release-render.log`. Final source parity covers 28 files with no drift (`build/qa/exploration-parity.json`). Preflight import/module/art checks passed; the final scoped lints retain only the seven previously documented warnings. Windowed shutdown retained the same baseline texture-RID warnings. Mobile editor import, the **161-script compile gate**, and the **100-check quick suite** passed (`build/qa/exploration-mobile-final.log`). No physical device or WAN-session validation was performed.

Remaining limits: this adds authored discoveries in Chapters 1–2; it is not a full escort/defend mission system. Quest guidance intentionally cannot infer every scripted verb or reveal unseen destinations. Physical mobile devices and WAN sessions require separate hardware/network validation.
