# Grass focus source — September 9, 2026

`grass_v3.png` is the untouched 1254×1254 RGB output of built-in OpenAI
ImageGen. `prompt_v3.txt` and `provenance_v3.json` record the exact brief,
original output location and installation status. No reference image was
used and no pixels were edited, resized, recolored or composited.

SHA-256: `5462bcb8d96e073d5786ae9bd70eb6a39a30592913c6c5ece7e3df5944ff1400`.

The runtime destination is `game/assets/sprites/ground_field_grass_painterly.png`,
canonically mirrored to mobile. The world keeps its 512px period, mipmaps,
filtering and tint. Fangmoot keeps its separate 1254px native-UV/NEAREST use.
The revision replaces repeated bright crowns with subdued painterly turf.

All 28 external comparison frames were reviewed across Village/Wildfang and
desktop/host mobile Compatibility. Installed world, Codex, Fangmoot and
ordinary warrior/mage combat checks also passed visual review. Read
GRASS_FOCUS.md for exact coverage and limits. Generation alone is not acceptance.

The outgoing source remains unchanged at
`art_src/terrain_fields_2026-09-08/masters/grass.png`, SHA-256
`47a8cef53b950229307a38b9cf0c735a3157aae014383e41bbc8074c059b3bac`,
with its historical prompt and manifest. V1 was rejected raw for retaining
crowns; V2 passed its technical comparison but was rejected for dense sharp
leaf noise. Rejected local candidates and review receipts remain preserved
outside the accepted checkpoint's explicit asset paths.
