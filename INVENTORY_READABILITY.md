# Inventory readability

Inventory keeps its seven equipment positions. Empty rows are compact, while
occupied rows retain their icon, socket and gesture geometry. Primary item names
use a readable neutral color; grade remains visible in the frame or accent.
The shared detail header and merchant cards use the same text treatment.

Category filters wrap above a separate bag-action row. Touch filters and actions
have at least 44px target height. The existing ordering, auto-equip and synthesis
callbacks are unchanged. Filters retain their existing pointer/touch focus policy;
this change does not introduce keyboard filter navigation.

Material details say **Drop one**. The explanation distinguishes removing one
unit from freeing a bag slot: the slot is freed only when the stack is empty.

The optional controlled native probe reuses the existing runner:
`shot.bat material_ui --inventory-readability --timeout=300`.
Use a fresh isolated APPDATA under `build/qa/`. Add `--touch` for host touch
emulation, or `--mobile --renderer=gl_compatibility --touch` after scoped mobile
sync/import/compile. This mode requires all eight captures and cannot be combined
with other material modes or a baseline waiver.

The fixture lends maximum legal bag capacity, mixed stock, and F/S equipment.
It records seven empty and occupied rows, actual wheel/touch scrolling to the
last bag cell, filter/action geometry, Materials/All browsing, outside dismissal,
and two real single-unit material drops. The first leaves its stack slot occupied;
the second removes the stack. Exact pocket and ground-pickup ledgers are checked,
and loans and both host input-emulation settings are restored on all exits.

These are controlled factory fixtures, not ordinary progression or physical-device
testing. Geometry and a fixed dark-background contrast proxy support inspection;
they do not establish visual quality. Equipped names retain their authored
ellipsis behavior. The material-detail prose is checked in full. Socket gestures,
merchant/mail/workshop presentation, broader gem operations, menu navigation and
paired ENet UI behavior use existing separate regression probes.

The candidate derives from actual DeepSeek output, independently reviewed and
corrected by Codex. Raw provider outputs, rejected QA drafts, exact executed
sources and native originals are preserved under
`build/qa/session-sept20/inventory-readability/`.

Validated September20 on desktop and host-rendered mobile: compile, quick/full,
scoped mobile sync/import/compile/strict quick, and all seven strict preflight
categories pass. Focused Inventory passes146 checks per desktop, host-touch and
mobile run. Material pilots pass309 each; equipment gestures49 each; gem caps
45 desktop/49 mobile; menu navigation158 each; paired ENet UI24 each. All106
selected native originals were inspected by Codex or actual Claude with retained
Read-image receipts. Root assessed findings and opened representative originals.
Exact source, image, report and provider pins are recorded in
`build/qa/session-sept20/inventory-readability/validation-collector-v3/acceptance.json`.
The resulting commit/local state is in `inventory-readability-commit-receipt.json`
in the session directory. Six passing native episodes from V2 are reused with
unchanged source bindings; V2's failed pipeline is never called a pass.

The strict original-layout diagnostic completed eight views with141 checks:
131 passed and10 presentation assertions failed. Earlier native-class shadowing,
invalid fixture gem key and missing host touchscreen emulation are preserved
failures. The initial touch baseline has no screenshots. The mislabeled after
touch-v1 actually ran desktop flags; actual touch evidence is touch-v2.

Two old regressions assumed empty equipment rows always overflowed. Actual
Claude's equipment fixture and DeepSeek's gem-cap fixture now lend six legal B
supporting items beside their original target weapon. Original equipment is
restored; real scroll, gesture and exact gem-economy assertions stay strict.
The full-suite social-room lookup now selects exactly one chapter-pool NPC by
existing conversation metadata, preserving real dialogue/choice checks. Its
original broad lookup could select a shortcut winch. Raw failures and reviewed
provider derivatives remain retained.

Limits remain explicit: factory loans do not prove earned progression; host
mobile is not a physical device. ENet UI-only proves the scoped award/travel/input
cases, not persistence roundtrips or real-scene disconnect cleanup. The existing
child-scene disconnect diagnostic can spend on a retained release and remains
unaccepted. Known engine shutdown and negative-test diagnostics remain in logs.
Coarse legacy gear/gem art, small stat/legend text, ineligible gem explanations
and compact legacy popover controls remain follow-up. This checkpoint neither
changes gear artwork nor constitutes whole-game visual or touch-target approval.


September20 painted-gear follow-up: existing128px masters now serve Inventory
gear cells, equipped wells, Stats and gear details at unchanged geometry. The
optional `--gear-fidelity` gallery adds four named-item views and strict texture
checks; current desktop and host-mobile runs pass290 checks and12 views each.
Earlier146-check counts above describe the prior checkpoint. No new art or
world/held resolver change is included. See GEAR_UI_FIDELITY.md for exact source,
visual evidence and limitations; gem/potion/material behavior remains separate.
