# Grass focus — September 9, 2026

The shared grass background now uses subdued painterly turf with sparse blade
accents. The outgoing bright, repeated crowns pulled attention into empty
ground. The quieter surface makes actors, feet, roads and props easier to
separate while retaining green meadow color and visible brush texture.

## Source and rendering

The accepted original is `art_src/grass_focus_2026-09-09/grass_v3.png`, an
untouched built-in ImageGen RGB PNG, 1254×1254. Its SHA-256 is
`5462bcb8d96e073d5786ae9bd70eb6a39a30592913c6c5ece7e3df5944ff1400`.
The exact prompt and provenance are beside it. No pixels were resized,
recolored, filtered or composited. Desktop and mobile runtime PNGs are
byte-identical copies at `assets/sprites/ground_field_grass_painterly.png`.

The September-8 master remains unchanged under
`art_src/terrain_fields_2026-09-08/masters/grass.png`, SHA-256
`47a8cef53b950229307a38b9cf0c735a3157aae014383e41bbc8074c059b3bac`.
Its historical prompt, manifest and acceptance remain intact. Credits now
identify the revision. Rejected local candidates are preserved separately
from this checkpoint's accepted asset paths.

World scale stays 512px per repeat, with lossless import, mipmaps, no size
limit, LINEAR_WITH_MIPMAPS and the existing (0.94, 0.94, 0.965) modulation.
The density remains 1254/512 = 2.44921875 source pixels per world pixel.
Lighting, roads, scatter, shadows, collision, hazards, spawns, hero stats and
rewards are unchanged. Exactly two PNG entries differ between the 44-path
before/after source freezes; all recorded code, import settings/UIDs and
forest, grave-earth and stormgrass control masters match.

Grass serves Village/Outskirts, Maren's Camp, Stillwater Reach and capital
Fangmoot Circle. The `ph_garden`, `ph_fields`, `ph_camp` terrain/preview
definitions also resolve grass; the source audit found no authored campaign
assignment for those three. Codex uses the shared ground preview.

Fangmoot's arena is a separate consumer: normal Copper rules choose Village,
but its 1280×420 SubViewport uses native UVs and NEAREST filtering. Its period
is 1254 UI pixels, with (0.66, 0.66, 0.72) floor tint and the existing ambient,
key pool and vignette. This behavior stays intact and was reviewed separately.

## Selection and native validation

V1 was rejected during raw review because it retained repeated crowns and
diagonal clumps. V2 passed its seven-frame technical comparison but made the
native ground busier with sharp leaf strokes, so it was rejected. V3 passed
all 28 external comparison frames: Village and Wildfang palettes, each on
desktop Forward+ and the mobile project's host Compatibility renderer.

Within each comparison, the before/after geometry, UVs, period, modulation
and actual settled terrain tint match. The normal view is 1×; the detail
view is 2×. X/Y samples are shifted stills, with actual displacement recorded
(X -256px, Y +229px), not continuous-motion or invisible-repeat proof.
Wildfang's generated world position differs across renderers, so this is
within-renderer appearance evidence, not identical cross-renderer worlds.

| Installed coverage | Result |
| --- | --- |
| Actual generated world, desktop | 112 checks, zero failures/findings, 15 views, five keyboard legs; 77s runner |
| Actual generated world, host mobile | 112 checks, zero failures/findings, 15 views, five keyboard legs; 61s runner |
| Fangmoot Copper preview, both renderers | 31 checks each, zero failures; one fullframe plus one native crop each; 32s runners |
| Installed field and Village Codex, both renderers | Six images each, successful material checks and visible selected Village title/preview; 49s/46s runners |
| Ordinary warrior hunt | Won in 34.643s combat time; 130 starting HP, 113.250 minimum HP, 120 gold; five images |
| Ordinary mage hunt | Won in 17.435s combat time; 90 starting/minimum HP, 120 gold; four images |

All 60 before/after world images, eight before/after Fangmoot images,
twelve installed field/Codex images and nine hunt images were independently
reviewed. The 16 accepted runs contain 117 image artifacts, including the
28 external material views; `checkpoint34-native-receipts.json` hashes them.
Relevant
world mechanics dictionaries, non-animation torch fields and near-depth
receipts match before/after within each renderer. Natural flame frames,
critters, incidental boot gold and small input endpoints can differ.
The darker Compatibility shadows were already present in its baseline.

The hunts use starting level-one kits, no equipment and god mode off, with
actual keyboard movement and class inputs. Setup positions the hero at the
three signs; there is no direct damage or ability invocation during combat.
No terrain transplant or observation delay was requested. Both retain the
installed grass source through combat. Warrior received a captured hit;
mage took no damage, so that run does not prove an incoming-hit presentation.
The controller reads actual pounce timers, movement includes normal ability
displacement such as Blink, and capture waits are included in the reported
combat wall time. Escape was checked as unsealed; these runs did not leave
the room to abandon the hunt. Existing NPC-name/hunt-panel crowding remains.
These two wins are bounded playability evidence, not a balance study.

The other frames use posed/frozen actors or normal seeded UI previews.
Synthetic tell and touch-layout captures do not prove touch input, actual
capital traversal, co-op combat, physical-device performance or continuous
camera quality. Codex selection is visibly confirmed; the rig does not assert
the selected key or thumbnail pixel hash. Its no-candidate Before is legacy
grass, so the external comparisons retain the outgoing-painterly baseline.

## Reproduction and checkpoint

The existing floorfield rig now waits for three actual ambient samples within
0.0001, with an eight-second bound, and records per-view source/image hashes,
dimensions, mipmaps, filter, UV period and tint. Fangmoot's optional
`--grass-material` mode records its actual populated Copper preview and
restores borrowed UI/host state without starting a replay. Production render
math is unchanged. Commands and isolated-profile requirements are in
`tools/INDEX.md`.

Evidence is under `build/qa/`: `grass-v3-*-review.md`,
`grass-v3-mobile-native-review.md`, `grass-world-final-review.md`,
`grass-fangmoot-final-review.md`, `grass-codex-final-review.md` and
`grass-hunts-final-review.md`. The 44-path before/after freezes are
`checkpoint34-before-source.json` and `checkpoint34-after-source.json`.
The checkpoint uses the 16 explicit paths in `checkpoint34-paths.json`.

Desktop/mobile imports, scoped art verification, desktop compile225/quick125/
full205 and mobile compile225/strictquick125 passed. The initial art-check
command lacked numpy in the default Python; the unchanged checker passed
under the bundled runtime. Full preflight passed without findings. The full
suite retains its intentional invalid-base64 diagnostic and ObjectDB warning;
no SCRIPT ERROR or freed lambda capture occurred.
Known shutdown-only texture/RID/RenderingServer/ObjectDB messages remain in
the shot logs; successful verdicts do not claim clean stderr. No rendering or
startup performance improvement is claimed.
