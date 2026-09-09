# Painted material UI pilot

September 9, 2026. Wilted Sprig, Foul Residue and Rusted Scrap (all F grade)
now use painted artwork in inventory, their detail cards, mail attachments and
merchant sale rows. Their wilted leaves, worn crock/sludge and corroded plates
retain the old item identities and match the existing painted Health Potion.
Material detail copy states the sale price without the internal “anti-haul” term.

## Rendering and sources

`Art.material_ui_icon` loads reviewed 128px overrides from
`assets/icons/materials_ui/`, caches them separately and returns the existing
32px material texture instance when an override is absent. Inventory and mail
material buttons use linear filtering when supplied with a larger texture;
merchant and detail views already filter linearly. Slot dimensions, drag/drop,
counts, transactions and economy are unchanged.

The existing `Art.material_icon` continues to supply 32px world pickups. Their
1.1 scale still produces 35.2px sprites. All 35 legacy PNGs remain intact; the
other 32 material variants have not received painted replacements.

Built-in ImageGen produced three accepted subject masters at 1254px. Herb and
reagent retain native RGBA; scrap v3 was generated on a flat magenta background
and keyed with recorded soft-matte settings. Scrap v1/v2 painted checkerboards
were rejected and preserved separately. No PixelLab or protected artwork was
used. Exact prompts, references, hashes, the full scrap alpha intermediate and
processing provenance live in `art_src/materials_painted_2026-09-09/`.

`python tools/art/build_material_ui_icons.py` rebuilds candidate exports from
those archived sources with premultiplied LANCZOS. It preserves the full canvas
and checks approved decoded pixels. There is no alpha crop, silhouette sizing,
palette reduction, sharpening or added outline. `--install` explicitly writes
the three desktop UI assets; mobile uses the normal scoped sync. The current
Pillow/NumPy versions reproduce the approved PNG bytes exactly.

## Native reproduction

Use isolated APPDATA and the muted, compile-gated runner:

```powershell
shot.bat material_ui --timeout=180
shot.bat material_ui --mobile --renderer=gl_compatibility --touch --timeout=180
```

`--baseline` permits only the expected missing-resolution/filter findings on an
unmodified source checkout. Every fixture, item identity, economy, geometry and
world-size assertion stays strict. The six full captures cover inventory,
inventory detail, mail, mail detail, merchant sale rows and world size controls.
The JSON records actual texture sizes/filtering, fully visible fitted icon
rectangles through clipping ancestors, counts and all source hashes.

These are controlled presentation fixtures: loaned items, an explicitly marked
letter and posed real Pickup nodes with collection disabled. The rig uses
synthetic native pointer input to open actual controls. It does not prove
ordinary collection, sales, claims, combat or physical-device performance.

## Validation

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
