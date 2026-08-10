# Featherweave Circlet family wave

Generator: built-in ImageGen using the shared flat `#ff00ff` chroma-key workflow. Untouched source PNGs are retained under `../generated/`; approved RGBA masters are retained under `../alpha/`.

## `h_featherweave_circlet`

Neutral mage family master: one empty standalone thin dark-silver circlet woven from layered ash-gray and muted sky-blue feathers, with a central polished moonstone and visible dark inner hollow. It is a well-made restrained wearable headpiece with no magic. This candidate was accepted after alpha inspection; its key field was removed with soft matte + despill.

Every source prompt carries the shared contract: one centered empty headpiece, no person/head/face/body/mannequin/floor/text/duplicate prop or shadow, and a uniform magenta chroma field with no magenta in the item.

## Completion wave — 2026-08-08

Built-in ImageGen made exactly one distinct source for each remaining manifest
key. No source was rejected and no retry or variant was made. Each untouched
source remains in `../generated/`; the corresponding approved RGBA master is
in `../alpha/`. Alpha removal used border auto-key, soft matte, thresholds
12/220, and despill.

| Key | Source key field | Accepted construction |
|---|---|---|
| `h_featherweave_circlet_A` | `#fb03fa` | Exceptional dark-silver circlet; dense layered ash-gray and muted sky-blue feathers, faceted moonstone and closed silver pinwork. |
| `h_featherweave_circlet_B` | `#fb04f9` | Masterwork thin circlet; tidy overlapping feather vanes, silver pinwork and a small cool-blue moonstone glint. |
| `h_featherweave_circlet_S` | `#fa03f9` | Legendary tiered feather circlet; richest silver filigree, prominent claw-set moonstone and sparse contained star glints. |
| `u_skyquill_circlet` | `#f904f8` | Independent slim swept-back circlet with one long pale sky-blue brow quill, folded side feathers and moonstone clasp. |
| `u_zero_weight_circlet_beyond_the_firmament` | `#fb04f9` | Independent airy silver circlet with three attached pale sky-blue quills, open inner hollow, minimal moonstone ring and fine aerodynamic arcs. |

All five prompts specified a centered empty standalone circlet on a perfectly
flat `#ff00ff` field, and prohibited a head, face, person, body, mannequin,
hand, duplicate item, detached feather, text, readable runes, UI, scenery,
floor, shadow, smoke, fog, watermark, and `#ff00ff` in the object.

## QA

- Non-installing `build_gear_codex_icons.py --slot helmet` accepted all five
  masters and emitted their 128px codex and hard-alpha 32px gameplay candidates
  under `tmp/gear_codex_128/helmet/`.
- Visual inspection of both generated QA sheets found a single transparent,
  empty circlet per key, no magenta fringe, a readable B/A/S construction
  ladder, and distinct 32px silhouettes for Skyquill and Zero Weight.
- Runtime icons and `mobile/` remain untouched.
