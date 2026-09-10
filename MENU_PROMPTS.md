# Menu prompt clarity

World interaction prompts now disappear when a shared menu opens. Previously,
the selected fountain/NPC label remained behind the translucent panel because
the menu hid HUD children while the label belonged to the world. Solo pause
prevented another Game tick, and the normal interaction selector also skips
open menus. Both centered and full-screen menu builders now hide valid registered
prompt controls synchronously before requesting pause. Closing a menu lets the
unchanged selector rediscover the nearest eligible interaction on its next tick.

This changes no interaction range, target, action, pause rule or dialogue/chat
state. The helper does not retain a prompt for later restoration or force one
visible. Online menus use the same builders; their existing overlay gate prevents
the running selector from showing prompts again until the menu closes.

Mobile Party footers now name the actual **Close this panel** action and explain
that the party stays active. The old generic touch substitution matched `press E`
inside `press ESC`, yielding `tapSC`. Touch and controller substitutions now match
complete authored key phrases, preserving longer words and keys while retaining
existing punctuation, casing and contextual `tap Act` wording. Keyboard ESC
remains ESC. Live Close, Escape/Back, explicit End/Leave, and pre-launch lobby
exit behavior are unchanged.

## Reproduction and scope

Use isolated APPDATA and the existing muted, compile-gated runners:

```text
shot.bat material_ui --grade-pairs --world-prompts --timeout=180
shot.bat material_ui --grade-pairs --world-prompts --mobile --renderer=gl_compatibility --touch --timeout=180
shot.bat hud_dossier --timeout=300
shot.bat hud_dossier --mobile --renderer=gl_compatibility --touch --timeout=300
```

The optional world-prompt pass extends the material rig before its normal art
sequence. It requires a naturally selected prompt at capital arrival, opens the
actual Inventory and non-granting Fangmoot hub, and uses Escape, ScreenTouch
outside, and controller B to close. It checks immediate/paused hiding, normal
rediscovery of the same prompt, unchanged inactive dialogue/chat flags, and
resource preservation. It never poses the hero, camera or prompt visibility
for that initial positive control. The inherited material loans/god mode remain
explicit fixture setup; later world pickups remain posed presentation controls.
Two additional captures show Inventory and the restored world, for eleven total
with grade pairs. Fangmoot's full-screen builder has runtime checks, not a separate
new screenshot. `--baseline` permits only six expected new hide findings while
keeping positive selection, input, restoration and all current art checks strict.

The existing HUD dossier adds one complete live-host Party footer assertion to
its utility-button access pass. It uses a real loopback host with synthetic
party shells; no remote guest or replication claim is added. The live guest
footer is covered by source review. The existing tree-free gamepad test covers
whole-key positive/negative copy in keyboard, touch and Xbox-label modes.

These are native Windows checks, including mobile-source Compatibility rendering
and synthetic input. They do not establish physical-device operation, active
dialogue/chat behavior, ordinary progression or a new ENet prompt-restoration
scenario. CR/Resonance retain their existing filled backings with zero borders;
the ordinary body-clearance fade explains their different visibility across
world captures. HUD styling is unchanged by this checkpoint.

## September 10 validation

The accepted baseline records 233 checks: 227 pass, six expected prompt-hide
findings and no failures. Final desktop and mobile-source runs each pass all
233 checks with no findings or failures and eleven full images. The existing
HUD dossier passes 558 checks and produces 22 images per project. Its nine
column checks retain zero Team/Settings horizontal offset and four-pixel gaps;
all 36 text clearances pass. General menu navigation also passes all 158 checks,
with eight images and actual keyboard, pointer, touch and controller events.

Root reviewed four full prompt/material images and three full HUD images per
project, plus all eight general menu images. Independent reviews cover all
eleven baseline originals and all 66 final prompt/material/HUD originals.
The source freeze contains 19 exact files. All six desktop/mobile pairs match;
HUD production, all fourteen painted material UI PNGs, and all seventy legacy
world material PNGs remain unchanged. All 46 preserved unrelated/unfinished
files retain their recorded hashes.

Desktop quick/full pass 143/223; mobile import, compile (253 scripts), explicit
strict quick (143), native compile (255) and all seven preflight categories pass.
The serial pipeline completed without a runtime edit after the final freeze.
Established renderer shutdown diagnostics and the full suite's intentional
invalid-base64 fixture/bare ObjectDB warning remain documented, not suppressed.
Exact logs, source hashes, image reviews and commit verification are recorded in
`build/qa/session-sept10/menu-prompts-checkpoint-validation.json`.
