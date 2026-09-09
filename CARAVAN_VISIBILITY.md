# Caravan visibility and placement — pass 29 validated

A normal warlock fight exposed the hero disappearing behind the loaded cart.
The cart now uses the existing scenery silhouette system for the local hero
and selected enemy. Its artwork stays opaque, with the correct root y-sort
anchor. Real attack poses follow the covered target. Both readers restrict
scenery and targets to their current world, release retired-world copies and
preserve another owner's shared mask during cleanup.

Some valid trader offers also failed to start. The original placement circle
missed usable ground in offset room interiors. A fallback grid searches the
remaining safe rectangle with the same cart footprint and interaction
clearance. Existing successful placements keep their original order. If no
safe position exists, the offer explains why Help is unavailable; restored
space restores the action. The start callback still rechecks availability.

No hero, skin or cart art, prices, payouts or network protocol were changed.
The original cart PNG retains SHA256
`15096ba4da22c26ab711694d61a91efb140d5323a9600909f813c5ac46a08d1a`.

Reproduction and coverage:

- A baseline live run reached the missing hero outline at seed 272661, room 1.
  A separate isolated test reproduced copies in another world's log. The new
  ownership regression also covers foreign targets and an old living world.
- The 32-seed real-offer baseline failed on seeds 17, 19 and 25. Repeating all
  32 after the fix starts every cart. A real collision-blocked room disables
  Help with a readable explanation and enables it after the blockage is removed.
  `build/qa/cart-placement-comparison.json` records exact before/after positions.
- `shot.bat caravan --visibility --seed=272661 --timeout=220` checks actual
  covered/front hero positions, three selected-enemy attack poses, opaque art,
  shared masks, touch and cart retirement. Eleven desktop captures pass.
- `shot.bat caravan --placement --seeds=32 --timeout=300` exercises real offers
  and blocked/restored UI. `placement_sweep.json` records all observations;
  failed starts also write footprint and nearby-interaction diagnostics.
- A normal starting-kit warlock wins on formerly failing seed 17 in 37.749s,
  minimum 51.39/95 HP and 57.1% load. Seven captures pass; ordinary keyboard
  movement, attacks and held Interact are used without injected combat damage.
- Eight real ENet caravan captures pass: late join, guest work/kills, live
  merchant prices, completed-world snapshots, home saves, travel and disconnect.
  The existing Darkwood log-cover rig also passes eight captures.

Desktop import / compile 218 / quick 122 / full 202 pass. Ten frozen sources
are synchronized to mobile, with four independently minted UID pairs. Mobile
import / compile 218 / strict quick 122 pass. Mobile visibility (11 captures),
all 32 placement offers and blocked/restored UI (2 captures), and real ENet
party checks (8 captures) pass. Representative images on both renderers were
inspected. Full preflight has no findings. There are 57 passing live captures
across eight runs; 13 unchanged representative PNGs are retained for review.

Logs are under `build/qa/cart-*`; final source/parity/path records are
`cart-source-freeze.json`, `cart-source-parity.json` and `cart-stage-paths.json`.
Reviewed unchanged PNG copies are in `cart-reviewed/`, with source paths in
`cart-reviewed-images.json`. Pass 28's existing staged work is preserved.
The owner requested committing the completed work and then pausing. This pass
and the activity reward fixes are included in the checkpoint titled
`Improve activity rewards and caravan reliability`, following `5dbbe54`.

Evidence limits: native Android/iOS hardware is outside this pass. The known
full-suite malformed-base64 fixture and bare ObjectDB exit warning remain;
windowed rigs retain the established allowed renderer shutdown diagnostics.
The disconnect harness checks cleanup and saves while bypassing actual scene
reload, so its capture does not prove the production title-screen transition.
The first placement baseline failed before any screenshot had created its
output directory: seed 17's detailed JSON was absent, but its sweep record and
failed screenshot remain. The report writer now creates the directory first.
