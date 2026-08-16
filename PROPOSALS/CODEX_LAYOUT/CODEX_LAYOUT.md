# Codex layout proposal (2026-08-15)

Owner complaint: the codex is hard to navigate; some tabs are dense, others sparse.
Interactive mock (real data, real sprites, real 1000x620 panel): `codex_mock.html`
(open locally, or the published artifact link in the session that made it).

## Evidence (in-engine census, `game/shot_gemcodex.gd`)

Every tab is the same shape - pill tabs over one flat scroll - and the shape
is asked to hold a 12x spread of content:

| tab | cards | scroll px | screens (~380 px visible) |
|---|---|---|---|
| Bestiary > Monsters | 41 | 6,464 | 17 |
| Gear > Uniques (weapons) | 60 | 5,063 | 13 |
| Gear > Shapes (weapons) | 31 | 4,171 | 11 |
| Bestiary > Bosses | 21 | 3,467 | 9 |
| Terrains | 34 | 3,246 | 9 |
| Curios | 36 | 3,006 | 8 |
| Gallery > Folk | - | 2,148 | 6 |
| Bestiary > NPCs | 1 | 2,101 | 6 |
| Records | 7 | 1,256 | 3 |
| Co-op | 10 | 1,154 | 3 |
| Gallery > Bosses | - | 852 | 2 |
| Status | 7 | 725 | 2 |
| Gear > Bags | 2 | 714 | 2 |
| Gallery > Heroes | - | 690 | 2 |
| Gear > Gems | 2 | 552 | 1.5 |
| Gear > Rules | 2 | 542 | 1.4 |

Four structural findings:

1. **One chrome for twelve sizes of thing.** Collections (monsters, uniques),
   reference prose (rules, statuses, co-op) and personal progress (records) all
   render as tabs-over-scroll.
2. **Up to three rows of tabs before content.** Gear > Shapes stacks
   Bestiary/Gear/..., Shapes/Uniques/..., then seven slot pills: ~150 px of the
   620 px panel is navigation; the first weapon row starts at y~540.
3. **Prose in front of the catalogue.** Monsters opens on Elites + Temptations
   (380 px) before the first monster; Shapes opens on four sentences of budget
   rules.
4. **No index, filter, or jump.** 41 monster cards, no chapter grouping, no
   search. Boss "Mechanics & Tells" is a separate screen with a Back button.

Also seen: the Gems shelf draws colour squares though 140 authored gem icons
ship; Gallery is a 5-column 160 px portrait grid unlike the rest of the book.

## Proposal A (recommended): rail + filter bar + ledger + detail

- **Rail** (172 px, always visible) groups sections with counts:
  Bestiary (Monsters, Bosses, Folk) / Armory (Shapes, Uniques, Gems) /
  World (Terrains, Curios, Statuses) / Gallery (Heroes, Bosses, Folk) /
  You (Records, Co-op) / Field notes (Elites & Temptations, Gear rules,
  Gem rules, Bag rules). Dev-only Future stays at the bottom.
- **Filter bar** replaces the tab stacks: search box + chips (chapter for
  bestiary/terrains; slot + class + grade for the armory; regular/special for
  gems). One row, sometimes two, never three.
- **Ledger**: 44 px rows (icon, name, meta, tag) - 9-10 visible at once;
  chapter chips cut Monsters to 4-12 rows.
- **Detail**: the selected entry's full card, verbatim from today's builders;
  boss Mechanics & Tells is an inline fold (no detour).
- **Reference pages** (Field notes, Statuses, Co-op) are one 640 px reading
  column with a sticky mini-contents when long; Records and Gallery keep their
  own shapes inside the same frame.

## Proposal B (incremental)

Keep the top tabs; collapse the sub-tab rows into one filter row; move all
prose to a Field notes tab; rows-not-cards on the heavy shelves with the card
as a popover; chapter chips + search on every collection. ~70% of the benefit,
touches only `open()`'s nav block and the shelf headers.

## Mapping onto `scripts/ui/codex.gd`

- `open(m, tab)` keeps its signature and every `open_codex("...")` call site;
  the tab id picks the rail entry and (for `gear_shapes_helmet`-style ids) the
  initial filter. `BOSS_KINDS`, dev Transform buttons, `_build_chunked`
  streaming: unchanged.
- The three `_nav` rows -> one `_rail()` + one `_filter_bar()` per section.
- Each collection builder splits into `_rows(section) -> Array` (data,
  filterable) and `_detail(entry)` (today's card body).
- Prose blocks move verbatim into `_notes(page)`.
- `_boss_detail` becomes the fold content; `open_codex("bosses", kind)`
  selects the row and opens the fold.

Small fixes worth doing regardless of layout: Gems shelf should draw
`Art.gem_icon(color, lv)` at Lv 1/4/7/10; chapter grouping in
Monsters/Bosses/Terrains; 96x120 gallery frames so Heroes fits one screen.

## Status: BUILT 2026-08-15 (owner approved Proposal A the same day)

Shipped in `game/scripts/ui/codex.gd` (mirrored to mobile):

- Rail: Bestiary (Monsters, Bosses, Folk) / Armory (Shapes, Uniques, Gems) /
  World (Terrains, Curios) / You (Records, Gallery) / Reference (Field notes,
  Statuses, Co-op) / Future (dev only). Two deviations from the mock, both so
  the rail never scrolls inside the 620 px panel: Gallery is ONE rail entry
  with Heroes / Bosses / Folk chips, and Field notes is ONE entry with
  Elites & Temptations / Gear rules / Gem rules / Bags & consumables chips
  (the Future shelf already worked that way).
- Filter bar: search box on every collection; chapter chips (only chapters
  that hold entries) + Melee/Ranged on Monsters, chapter on Bosses, chapter +
  Quest givers on Folk, chapter + Hazardous/Safe on Terrains, kind on Curios,
  slot + class (+ grade) on Shapes/Uniques, Regular/Special on Gems.
- Ledger rows 44 px (icon, name, meta line, tag); 8-9 visible; ↑/↓ walk the
  rows (Godot focus), the list follows. Detail = the old card body re-flowed
  for a 396 px column (stat tiles instead of a 630 px stat row); the boss
  Mechanics & Tells is an inline fold; `open_codex("bosses", kind)` selects
  the row and opens the fold. Filters, search and selection are remembered
  per section for the session.
- Gems page draws the authored icons at Lv 1/4/7/10. Gallery frames 140x105.
- Story so far (owner follow-up, same day): a Reference page that renders the
  Journal's story archive in place (`UIJournal._archive`, one builder) —
  every conversation and choice as played, per chapter, with the transcript
  reader. Re-PLAYING an opening scene was weighed and not built: it needs a
  sandbox for the scene's choices, flags, rewards and spawns (the owner's own
  concern — replay choices must not save), and re-reading already exists.
  Owner wants it later: spec + build sketch in `PROPOSALS/STORY_THEATRE.md`.
- Terrains detail (owner follow-up, same day): a 384x192 room preview — the
  terrain's own ground with the road, tinted as in the world — on top, the
  name / zone / weather / hazards beneath (`_terrain_preview`, Art.ground).
- Every legacy tab id routes (`_resolve()`): gear / gear_shapes[_slot] /
  gear_uniques[_slot] / gear_gems / gear_bags / gear_rules / gallery_* /
  future_* / status / records / coop / curios / terrains / monsters / bosses /
  npcs. `menus._input` lets keys fall through to the search field (only ESC
  closes while it has focus).
- Census after (same rig): every collection opens with 8-9 rows in view and
  its detail on screen; the tallest reading page (Records) is 1,366 px, the
  rest under 1,300.
