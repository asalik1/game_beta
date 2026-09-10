# Painted material UI

September 9, 2026. Wilted Sprig, Foul Residue and Rusted Scrap (all F grade)
now use painted artwork in inventory, their detail cards, mail attachments and
merchant sale rows. Their wilted leaves, worn crock/sludge and corroded plates
retain the old item identities and match the existing painted Health Potion.
Material detail copy states the sale price without the internal “anti-haul” term.

September 10 adds Common Weed and Crude Extract (E), plus Fresh Herb and Clean
Extract (D), to the same UI override path. The herb pair preserves jagged rooted
weeds versus broad fresh leaves with cut stems. The reagent pair preserves dirty
amber sediment versus clear turquoise liquid in plain ingredient flasks. These
four early Alchemy ingredients now match the painted potion and F-grade family
in inventory and the actual brewing preview, including its 32px ingredient rows.

## Rendering and sources

`Art.material_ui_icon` loads reviewed 128px overrides from
`assets/icons/materials_ui/`, caches them separately and returns the existing
32px material texture instance when an override is absent. Inventory and mail
material buttons use linear filtering when supplied with a larger texture;
merchant and detail views already filter linearly. Slot dimensions, drag/drop,
counts, transactions and economy are unchanged.

The existing `Art.material_icon` continues to supply 32px world pickups. Their
1.1 scale still produces 35.2px sprites. All 35 legacy PNGs remain intact; the
other 28 material variants have not received painted replacements.

Built-in ImageGen produced three accepted subject masters at 1254px. Herb and
reagent retain native RGBA; scrap v3 was generated on a flat magenta background
and keyed with recorded soft-matte settings. Scrap v1/v2 painted checkerboards
were rejected and preserved separately. No PixelLab or protected artwork was
used. Exact prompts, references, hashes, the full scrap alpha intermediate and
processing provenance live in `art_src/materials_painted_2026-09-09/`.

The four E/D siblings are additional native 1254px RGBA ImageGen masters. They
use the same full-canvas resize without keying or cleanup. Sparse low-alpha RGB
speckles in the raw sources are invisible in the reviewed light/dark exports;
their bounds do not determine framing. All four v1 candidates were retained for
native review, with complete leaves, roots, stem ends, corks and flask bases.

`python tools/art/build_material_ui_icons.py` rebuilds candidate exports from
those archived sources with premultiplied LANCZOS. It preserves the full canvas
and checks approved decoded pixels. There is no alpha crop, silhouette sizing,
palette reduction, sharpening or added outline. `--install` explicitly writes
the seven desktop UI assets; mobile uses the normal scoped sync. The current
Pillow/NumPy versions reproduce the approved PNG bytes exactly.
The optional `--grade-pairs` acceptance mode requires exactly the reviewed seven
IDs and pins the three F PNGs byte-for-byte before an explicit installation.

## Native reproduction

Use isolated APPDATA and the muted, compile-gated runner:

```powershell
shot.bat material_ui --timeout=180
shot.bat material_ui --mobile --renderer=gl_compatibility --touch --timeout=180
shot.bat material_ui --grade-pairs --timeout=180
shot.bat material_ui --grade-pairs --mobile --renderer=gl_compatibility --touch --timeout=180
```

`--baseline` permits only the expected missing-resolution/filter findings on an
unmodified source checkout. Every fixture, item identity, economy, geometry and
world-size assertion stays strict. The six full captures cover inventory,
inventory detail, mail, mail detail, merchant sale rows and world size controls.
The JSON records actual texture sizes/filtering, fully visible fitted icon
rectangles through clipping ancestors, counts and all source hashes.

`--grade-pairs` retains those six captures and adds an inventory family view and
actual E/D Mana Potion previews reached through Professions and Alchemy controls.
It loans seven of each sibling, checks the displayed names and Have/Need counts,
and restores materials, remembered view and input emulation. Browsing must leave
gold, mastery, materials, potions, knowledge, mail and favor unchanged. It does
not brew or grant trade mastery. A fresh process is required after installing
textures because the art resolver caches fallback textures.

The optional `--world-prompts` follow-up runs before the art sequence. It uses
normal capital prompt selection, actual Inventory/Fangmoot builders and real
Escape/touch/controller dismissal to check menu hiding and normal restoration.
It adds two captures, for eleven with grade pairs. Only six prompt-hide findings
are baseline-qualified; the current art stays strict. See MENU_PROMPTS.md.

These are controlled presentation fixtures: loaned items, an explicitly marked
letter and posed real Pickup nodes with collection disabled. The rig uses
synthetic native pointer input to open actual controls. It does not prove
ordinary collection, sales, claims, combat or physical-device performance.

## F-grade pilot validation — September 9

The accepted desktop baseline has 90 checks, 20 expected presentation findings
and no fixture failures. The installed desktop and mobile comparisons each pass
all 90 checks with zero findings. Root reviewed all 18 full native images; an
independent reviewer also accepted all 12 desktop before/after images. Root and an
independent agent reviewed the 128/64/32 light/dark export comparison. At 32px
the sprig is naturally thin and tiny scrap rivets merge, while the three item
silhouettes remain distinct. The actual 40–64px UI views preserve material
shading, clear alpha edges, readable counts and complete detail text.

Desktop compile (235 scripts), quick (126) and full (206), mobile import,
compile (235) and strict quick (126), scoped synchronization and all seven
preflight categories pass. All 35 legacy icon hashes, four world-size controls
and 32 preserved unrelated files are unchanged. The full suite retains its
existing intentional invalid-base64 fixture and shutdown warning; desktop
native retains only the established renderer shutdown diagnostics. No verdict
was weakened. Mobile native uses the mobile project, Compatibility renderer
and touch presentation on this host, with synthetic pointer input.

The exact commit, source hashes, logs and accepted native image hashes are in
`build/qa/session-sept10/material-checkpoint-validation.json`.

## E/D sibling validation — September 10

The extended baseline has 212 checks: 196 pass, 16 expected missing-art findings,
zero fixture failures. Four absent inventory textures also inherit filtering,
adding four findings to the original prediction of twelve resolution findings.
Final desktop and mobile runs each pass all 212 checks with zero findings. Root
and an independent reviewer inspected all nine baseline and eighteen final full
native images, as well as the full 128/64/32 light/dark export proofs.

All 28 measured UI icon rectangles are fully visible; the four posed world
controls retain their previous sizes. E preview counts are Have 7 / Need 3 herbs
and 1 reagent; D requires 4 herbs and 1 reagent. The ingredient icons remain
distinct at 32px beside the 64px finished mana bottles. Desktop uses eight
synthetic mouse clicks; mobile uses four original pilot mouse clicks and four
ScreenTouch Alchemy entry/recipe/grade actions. Mobile is Compatibility rendering
on Windows, not a physical-device run. Those art-checkpoint frames retain a
pre-existing fountain interaction prompt behind some translucent menus. The
subsequent [menu prompt checkpoint](MENU_PROMPTS.md) fixes that behavior and
rechecks all current artwork.

Desktop quick/full (143/223), both project imports, compile (253 ordinary / 255
native scripts), mobile strict quick (143), scoped sync and all seven preflight
categories pass. All 35 legacy world PNGs and the original three F UI PNGs remain
byte-identical in both projects. The first three export manifest rows are exact,
and all seven approved sources reproduce their PNG and decoded RGBA hashes.
All 46 unrelated and unfinished-journey files remain intact. Exact source, image,
log, independent-review and commit hashes are recorded in
`build/qa/session-sept10/material-followup-checkpoint-validation.json`.
