# Painted terrain fields

Four original painted surfaces replace the pixelated grass, forest litter,
desert sand and checker-patterned snow. The new textures keep each region's
palette and the original material scale. Roads, hazards, scenery, collisions
and terrain mechanics retain their existing placement.

Full 1254px square masters are used verbatim, with mipmaps and linear sampling.
The GPU repeats them at 512 world pixels (400 for forest). The existing painted
Keep field stays at 384. Art.ground_field prefers a painted sibling when one
ships; other terrain types retain their existing texture. Codex previews use
the same field and world period.

Source images and prompts: art_src/terrain_fields_2026-09-08/. Built-in OpenAI
ImageGen, with existing field material/palette references and the Keep field as
a brushwork reference. No external art service or third-party source assets.
Outgoing PNGs remain available. Masters have no image transforms.

Validation: raw opposite-edge mean RGB differences are below the
existing 12/255 seam-risk threshold on both axes for all four textures.
The extended `shot.bat floorfield --compare --timeout=180` rig captures identical
before/after scenes, native/detail scales, real attack warnings, touch controls
and the Codex. `--mobile` selects the actual mobile project/renderer while
retaining the same mute, compile gate and watchdog protections.

The mobile project defaults to Forward Mobile when launched on a desktop host;
its handheld override is Compatibility. Also run `--mobile
--renderer=gl_compatibility` to inspect that rendering path. These are renderer
checks on the development PC, not a claim of Android/iOS hardware testing.


## Renderer and capture defects found by the comparison

Godot 4.4.1 Forward Mobile plus HDR2D and BG_CANVAS clipped snow to white
and overlit desert terrain. The engine's HDR-to-LDR-to-HDR canvas post path
is the upstream defect [#106282](https://github.com/godotengine/godot/issues/106282),
fixed in 4.6 by [#109971](https://github.com/godotengine/godot/pull/109971).
On affected 4.x versions below 4.6, Game bypasses canvas post-processing in
Mobile with HDR2D. Ordinary textures, ambient tint and authored spell/hazard
sprites stay active; post-process glow and global adjustments are disabled
for that configuration. Forward+ and Compatibility retain their prior paths.
This is version-gated so a future engine upgrade restores the fixed effect.

The shared ShotRig also omitted HDR readback's linear-to-sRGB conversion.
That made old desktop captures artificially dark; it did not mean the actual
window was that dark. `capture_image()` now follows the
[Godot 4.4 ViewportTexture guidance](https://docs.godotengine.org/en/4.4/classes/class_viewporttexture.html).
Compatibility captures are already sRGB and skip conversion. A known-color
UI swatch checks each real renderer, catching both missing and doubled gamma.
Judge color using final calibrated captures, not the preliminary old readbacks.


Capture precision: the HDR image remains floating point through the sRGB
transfer function, then quantizes once to PNG bytes. Quantizing linear values
first caused coarse colored bands in dark translucent panels. The calibration
includes two dark swatches and a midtone, each within 0.006 per channel.
This is QA output handling; it does not alter the game window or source art.


Final validation: desktop 181-script compile, 108 quick
checks and 188 full checks; mobile editor import,
181-script compile and 108 quick checks. All strict
PASS, without script errors. Three calibrated renderer rigs each passed
18 captures (54 total): native/detail scale, warnings, touch and Codex.
All 14 scoped desktop/mobile files match frozen hashes. Source preflight
has zero failures and 12 structural/moved-number warnings, including the new
engine-version boundary at 6. Asset checks retain five known intentional
companion-pose warnings. Four intact masters total 9,009,131 PNG bytes; textures are
shared per material, with no high-resolution per-room bake.

Renderer checks ran on the development PC; no Android/iOS device or controller
hardware was used.
