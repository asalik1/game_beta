# Gear art generation brief

**For:** the agent generating gear icon assets.
**Branch:** `codex/asset-quality-pass`
**Design source:** [`PROPOSALS/GEAR_SHAPE_MATRIX.md`](GEAR_SHAPE_MATRIX.md) — the
120-shape table lives in its §5. Do not duplicate it here; read it there.

You own the visuals and the *naming of unique items*. You do not own the stat
biases — those are fixed by the matrix.

---

## What you are making, in numbers

Every **shape** (= gear type) in the matrix gets a named A-tier unique and a named
S-tier unique, on top of its generic graded art.

Worked example — assassin **charm** has five types:

| Type | Named A | Named S |
|---|---|---|
| Killer's Mark | 1 | 1 |
| Poisoner's Vial | 1 | 1 |
| Ghostlight Charm | 1 | 1 |
| Bloodoath Cord | 1 | 1 |
| Wraithbone Fetish | 1 | 1 |

So the Vial family yields two uniques: one named A-tier vial, one named S-tier
vial. Same for every other type.

| | Count |
|---|---|
| Shapes (6 classes × 4 slots × 5 types) | **120** |
| Generic family sprites (tier 2, one each) | 120 |
| Generic per-grade art on B / A / S (tier 1) | 360 |
| **Named uniques (2 per shape)** | **240** |
| **Total at the recommended scope** | **720** |

Work in the order in §4 — generic coverage first, uniques last. Do not try to do
this in one pass.

---

## 1. Tool rule — read this first

**Use your own built-in image generation tool.** That is the project default for
generated art (`CLAUDE.md`, "Generated art tool authorization").

**Do NOT use PixelLab.** PixelLab requires explicit per-task owner authorization
and it has not been given for this task. Existing PixelLab assets in the repo,
PixelLab helper scripts under `tools/art/`, and PixelLab MCP tools being connected
do **not** constitute permission. If your built-in tool cannot meet a requirement,
stop and ask the owner — do not switch generators or spend external credits.

---

## 2. Technical spec

| Property | Value |
|---|---|
| Size | **32 × 32 px** |
| Format | PNG, RGBA, transparent background |
| Style | pixel art, a new cohesive Crownless gear language |
| Destination | `game/assets/icons/<key>.png` |

**The currently wired gear icons are placeholders, not art direction.** Do not
use them as style references and do not preserve their look. Replace them as
each family is covered, backing up the prior PNG as required below. New assets
within a production slice should reference that slice's newly established style
anchor so the set stays coherent.

**Pre-brighten roughly gamma 0.78.** The Forward+ tonemap renders authored PNGs
noticeably darker than they look in an image viewer. Judge from an in-game
screenshot, not the file.

**Weapons are used twice.** The same sprite is the bag icon *and* the weapon in
the hero's hand (`Art.weapon_tex`). It must read at 32px, in motion, at gameplay
zoom — silhouette first, detail second.

**Never hard-delete a replaced asset.** Back it up (project convention). Recover
an old one with `git show HEAD:<path>`.

---

## 3. File naming — the override cascade

`Art.item_icon` and `Art.weapon_tex` resolve most-specific-first. Any missing file
falls through, so you can author in any order and nothing renders as a hole.

| Tier | Filename | Treatment at runtime |
|---|---|---|
| 0 | `u_<unique_name>.png` | named unique — used exactly as authored |
| 1 | `<shape_key>_<GRADE>.png` | authored for that grade — **no tint applied** |
| 2 | `<shape_key>.png` | one sprite for the family — gently grade-tinted |
| 3 | *(none)* | procedural fallback — hard tint + auto embellish |

- `<GRADE>` is one uppercase letter: `F E D C B A S`
- `<shape_key>` is the sprite key from `Art.GEAR_SHAPES`, e.g. `w_blade`,
  `icon_shield`, `icon_striders`
- Example: `w_shuriken_S.png`, `w_shuriken.png`, `u_end_of_night.png`

**Tier 1 files receive no tint or embellishment.** Whatever you draw is exactly
what ships. Tier 2 files still get a light grade tint, so draw those neutral.

The item's name colour and bag-slot border already carry rarity. **Do not repeat
that information by turning the same drawing blue for B, brown for A and gold
for S.** The authored B / A / S art must climb through condition, material,
ornament, construction and light. The ladder should still read in grayscale,
and A must never look duller or cheaper than B.

---

## 4. The tier ladder — make grade legible at a glance

This is the part that matters most. A player should read an item's grade from its
icon alone, before reading the name.

| Grade | Prefix in-game | How it should look |
|---|---|---|
| **F** | Rusty, Cracked, Chipped, Bent | **Damaged.** Rust bloom, pitting, a notched or chipped edge, frayed binding, a crack. Cheap material. Desaturated browns and greys. It looks scavenged. |
| **E** | Worn, Plain, Sturdy, Simple | **Serviceable but plain.** Honest wear, no damage. No ornament at all. Plain iron, plain leather, plain cloth. |
| **D** | Tempered, Honed, Polished, Keen | **Maintained.** Clean lines, a slight sheen, edges true. Still undecorated but clearly cared for. |
| **C** | Fine, Gilded, Wrought, Refined | **Crafted.** Deliberate shaping, a small amount of ornament, better material. First hint of colour beyond the base metal. |
| **B** | Runed, Masterwork, Enchanted, Pristine | **Ornamented and magical.** Etched detail, inlay, a faint glow or rune accent. Quality steel, dyed leather, fine cloth. |
| **A** | Dragonforged | **Exceptional.** Exotic material and visible energy. A bigger read at a glance — more relief, ornament, contrast and a distinct glow. Clearly stronger than B without depending on an overall colour wash. |
| **S** | Emberforged | **Legendary.** Dramatic and luminous. Unmistakable in a full bag. Ember/arcane light, the richest fittings and the best material in the world. |

### The constraint that keeps the bag readable

**Silhouette stays recognisable as the same shape across every grade.** An S
Shuriken is still instantly a shuriken. Grade changes *material, condition,
ornament and light* — never what the object fundamentally is. If a player cannot
tell an S Guard from an S Plate at a glance, the tier art has gone too far.

Named uniques (§5) are the deliberate exception.

### Priority order

Do not attempt all seven grades for all 120 shapes (840 files) up front.

1. **Tier 2 first — one neutral family sprite per shape, 120 files.** This is
   coverage: it stops anything falling back to procedural art, and every grade
   immediately looks reasonable via the automatic tint.
2. **Tier 1 on B, A, S — 360 files.** This is where players live and where
   distinct art pays. 480 files total with step 1.
3. **F / E / D tier-1 only if there is appetite.** Low grades are seen briefly and
   read fine tinted.

---

## 5. Named uniques

A unique is **its own object**, not a fancier generic. Its art should be
*completely different* from the generic S of the same shape — different
silhouette details, different colour story, its own visual idea.

The one thing it must keep: it still reads as its slot and rough category. A named
Shuriken is still a thrown blade, so the player knows what slot it fills.

**Two per shape: one A, one S.** 240 in total. The A-tier unique and the S-tier
unique of the same shape are *different objects* — do not draw the A and then
brighten it for the S.

- **You choose the names.** Make them evocative and setting-appropriate — the
  world is dark fantasy, the kingdom is Crownless. Existing examples in
  `Items.A_NAMES` and `Items.S_GEAR`: *Widow's Bite*, *Oathbreaker*,
  *Dawnsplitter*, *Kingsbane, Edge of the Fallen Crown*.
- The name should read as *that type of object*. A named Poisoner's Vial is still
  a vial — the player must know what it is before reading the tooltip.
- **File key:** `u_<snake_case_name>.png`, e.g. `u_end_of_night.png`.
- **Deliver a list** of `name → shape → grade → file key` alongside the art. The
  wiring table for uniques does not exist yet, so hand back data, not code.
- Do **not** invent stat biases for them. That is design's call.

---

## 6. Wiring — required, or the suite fails

A new noun that can roll but has no art entry does **not** error at runtime —
`Art._shape_for` silently falls back to the first sprite in the slot, so a new
sword renders as a Blade. The test suite now catches this.

For every new shape you produce art for, add its entry to **`Art.GEAR_SHAPES`**
(`game/scripts/art.gd`, ~line 1899), mapping noun → sprite key:

```gdscript
"weapon": {..., "Saber": "w_saber", "Pike": "w_pike"},
```

The other three tables (`Items.SHAPE_STYLE`, `Items.SLOT_NAMES`,
`Items.CLASS_WEAPONS`) are design's job, not yours — but note that
`GEAR_SHAPES` can safely gain entries ahead of them. The assertion only fails in
the other direction (rollable noun with no art).

---

## 7. Verification

1. **Compile gate first, always** — `test_quick.bat`. Never invoke the test scene
   directly; one parse error makes the headless engine hang forever.
2. `test.bat` (full suite) green before staging.
3. `preflight.bat` — note it currently reports pre-existing `IMPORT` failures on
   this branch from earlier asset work; those are not yours unless you add to them.
4. New PNGs need an import pass: `tools\Godot_v4.4.1-stable_win64_console.exe
   --headless --path game --import` (close the editor first — `--import`
   contends with it).
5. **Look at the art in-game.** The codex gear page renders every shape at every
   grade in a gallery — that is the fastest way to see the whole ladder at once
   and check that grade reads correctly.
6. `python tools/art/asset_gallery.py` catalogues wired visual assets if you want
   a contact sheet.

---

## 8. Definition of done

- [ ] Tier-2 family sprite exists for every shape in the matrix, 120 files (no
      procedural fallbacks left for shipped nouns)
- [ ] Tier-1 art for B / A / S, 360 files
- [ ] 240 named uniques — one A and one S per shape, each its own design
- [ ] Grade is readable from the icon alone, and silhouette is stable across
      grades within a shape
- [ ] Named uniques generated, with a `name → shape → grade → key` list handed back
- [ ] `Art.GEAR_SHAPES` updated for every new shape
- [ ] Replaced assets backed up, not deleted
- [ ] `test_quick.bat` and `test.bat` green; `--import` run for new PNGs

---

## Coordination

This branch has multiple agents on it. Commits are **serialized** — run
`git status` immediately before committing and check what is actually staged. If
the index holds another agent's work, either fold it into an accurate combined
message or stop and say so. Never commit a message describing only your slice.
No author or co-author trailers.

Gear *design* work (the stat side of `Items.SHAPE_STYLE`, per-class noun lists,
the uniques table) is in flight separately. Stick to `game/assets/icons/` and the
`Art.GEAR_SHAPES` table to avoid collisions.

---

## Production progress

### 2026-07-26 — warrior weapon slice

- Tier-2 family sprites: **5 / 120**
- Tier-1 B / A / S sprites: **15 / 360**
- Named A / S uniques: **10 / 240**
- Slice total: **30 assets**
- Shape mappings: Pike, Warblade, Saber, Bulwark Blade and Claymore wired in
  `Art.GEAR_SHAPES`
- Unique handoff: [`GEAR_UNIQUE_ART_MANIFEST.md`](GEAR_UNIQUE_ART_MANIFEST.md)
- QA matrix:
  [`GEAR_ART_WARRIOR_WEAPONS_PREVIEW.png`](GEAR_ART_WARRIOR_WEAPONS_PREVIEW.png)
- Forward+ codex proof:
  [`GEAR_ART_WARRIOR_WEAPONS_INGAME.png`](GEAR_ART_WARRIOR_WEAPONS_INGAME.png)

Regeneration pass: all 15 authored B / A / S sprites were rebuilt so the grade
ladder is carried by workmanship, exotic material, relief and energy rather
than a blue / brown / gold recolour ramp. The previous 15 are backed up under
`game/assets/icons/archive/2026-07-26_warrior_weapon_regen_pass1/`.

Five named uniques were also rebuilt as independent designs: The Red Pennon,
Marchbreaker, Ashrider, The Gate That Walks and Crownfall, the Kingdom's End.
Red Horizon remains the distinctness benchmark. The five replaced unique
sprites share the same backup directory.

This slice used the built-in image generator only. PixelLab was not used, and
the legacy wired weapon icons were not used as references. The replaced
`w_claymore.png` is preserved under
`game/assets/icons/archive/2026-07-26_pre_gear_art/`.

### 2026-07-26 — remaining class weapon slice

- Tier-2 family sprites: **30 / 120**
- Tier-1 B / A / S sprites: **90 / 360**
- Named A / S uniques: **60 / 240**
- Combined weapon total: **180 assets**
- Completed classes: Warrior, Archer, Assassin, Mage, Paladin and Warlock
- Shape mappings: all 30 weapon nouns wired in `Art.GEAR_SHAPES`
- Unique handoff: [`GEAR_UNIQUE_ART_MANIFEST.md`](GEAR_UNIQUE_ART_MANIFEST.md)
- QA matrices:
  [`Archer`](GEAR_ART_ARCHER_WEAPONS_PREVIEW.png),
  [`Assassin`](GEAR_ART_ASSASSIN_WEAPONS_PREVIEW.png),
  [`Mage`](GEAR_ART_MAGE_WEAPONS_PREVIEW.png),
  [`Paladin`](GEAR_ART_PALADIN_WEAPONS_PREVIEW.png) and
  [`Warlock`](GEAR_ART_WARLOCK_WEAPONS_PREVIEW.png)

The remaining five classes add 25 neutral family sprites, 75 authored B / A / S
variants and 50 named uniques. Each grade variant was drawn independently around
the same family silhouette: B adds etching or inlay, A changes construction to
exotic material with contained energy, and S uses the most dramatic workmanship
and light. Named uniques use separate construction, silhouette details, palette
and concept while preserving the weapon noun at 32px.

This slice also used the built-in image generator only. PixelLab and the legacy
wired weapon icons were not used. All 150 desktop assets have byte-identical
mobile counterparts.

Single-object correction pass: the Aegis Mace family and its B / A / S variants
were regenerated after the original prompt produced a mace-and-shield loadout.
Each replacement is now one continuous mace: the aegis shape is forged into the
mace head as relief rather than depicted as separate equipment. The rejected
four sprites are preserved under
`game/assets/icons/archive/2026-07-26_aegis_mace_two_object_pass/`.
