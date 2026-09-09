# Painted default potion in the HUD

Owner request, September 9, 2026: the default potion icon looked low quality
beside the painted ability medallions. The live slot was enlarging the legacy
32 × 32 `assets/icons/potion.png` and placing a large carried count over it.

`Art.tex("potion")` now reuses the existing 128 × 128 painted
`assets/icons/consumables/apprentices_health_potion.png`, through the same cached
consumable loader as the inventory. This matches the inventory's empty-health
fallback. It remains a generic health symbol: automatic health still pours the
chapter gift first, then the cheapest carried grade. The original glyph remains
an asset-missing fallback. No artwork was generated, resized or replaced.

The desktop carried count sits at the bottom right in 15px type. Touch uses
the same placement in 16px type. Cooldown numbers remain centered on abilities.
The bottle renders at 52px on desktop and 51.2px in the 80px touch target, so
the existing master supplies over two source pixels per rendered pixel.

The touch display also now counts the selected consumable, matching desktop.
Previously it showed health-potion stock even when a mana potion was active.
Room budgets, potion effects, input handling and the spent-room indication are
unchanged.

Desktop validation passed: compile, the 123-check quick suite, and
`shot.bat potion_hud --timeout=240` (79 checks, six full frames plus native
button/bar crops). Actual Q drinks reduced carried stock 5 → 4 → 3 and room
budget 2 → 1 → 0. Other captures cover empty health stock, selected mana stock
2 alongside health stock 5, and a legal 123-bottle inventory. All six states
were visually reviewed against the owner's screenshot; no clipping or
readability regressions were found. Evidence is under
`build/qa/potion-hud-desktop1*` and `build/qa/potion-hud-desktop-review.md`.

Mobile import, compile and strict quick validation passed (124 checks,
including the guardian-discovery regression). The Compatibility touch rig
passed 81 checks and six states using actual ScreenTouch taps. Each drink
spent exactly one bottle and one room allowance. The first two touch runs
caught chapter-reveal timing in their captures. The final rig waits through
the cinematic's deferred finish as well as the real overlay/title fade before
every capture. All eighteen final images were reviewed: clear stocked/empty/
mana/triple-digit states and the intended spent-bottle dimming. Evidence is
under `build/qa/potion-hud-mobile-touch3*` and `potion-hud-mobile-review.md`;
the two earlier timing probes remain available.

The first combined mobile quick run caught a typed-array assignment in the
separate guardian test fixture; its aborted cleanup caused a later save
assertion too. An explicit `Array[int]` fixed the fixture; strict quick2 is
clean. Neither failure required a potion or save implementation change.

Final desktop compile224/full205 and mobile compile224/strictquick125 passed;
full preflight reported no findings. Use
isolated APPDATA and `shot.bat potion_hud --timeout=240 --touch --mobile
--renderer=gl_compatibility` for the mobile source and real touch tap. Final
checkpoint identity and frozen paths are recorded with the `checkpoint31-`
evidence under `build/qa/`, including `checkpoint31-validation.json`.
