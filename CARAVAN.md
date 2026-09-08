# A Wheel in the Mud — pass 26 validated September 8, 2026

A trader's loaded handcart is stuck on a quiet campaign road. The leader can
accept or leave without paying. Accepting starts two warned attacks. Hold the
normal Interact key (or touch Act) at the shafts to pull; nearby attackers stop
the work and damage the load. Players can draw them away, interrupt them or
finish them before returning to the wheel. A partner can cover the puller.

The second attack starts halfway through twelve pulls, after the first
attackers have actually died. Victory requires the freed wheel and every
attacker dead. Missing or removed enemies never count as kills. Doors remain
open; abandoning the room or losing the load ends the attempt without a
further penalty. Work uses one shared cooldown, so repeated network requests
cannot speed it up. This encounter reserves its room against other optional
fights and leaves authored chapter enemies, quests and loot budgets alone.

Success reduces equipment and supply prices at ordinary road merchants by 20%
for this chapter and run seed. It does not stack or affect upgrades, gambling,
the Crown Bazaar or separate endgame economies. The benefit belongs to the
shared road: late joiners use it while visiting and keep their own home saves.
Open shops and item inspections refresh when the road gains supplies; stale
purchase callbacks charge nothing. No XP or repeatable kill loot is added.
A completed rescue consumes its road card; an unsuccessful offer can return
on revisiting the room. The Codex's Road Deck notes explain these rules.

The original cart was made with the built-in image tool. The unchanged master,
prompt and provenance are in art_src/caravan_2026-09-08. Its wood, canvas
bundles and wheels were inspected on grass at the production width of 240px,
from in front and behind, with touch controls and during ordinary combat.
Verify_art reports no failures; its soft-alpha warning was inspected in-game
with no green rim. No existing hero or skin art was touched.

Actual keyboard play found and fixed three interaction/readability defects:
the departing trader left a freed sprite reference in facing restoration;
nearby NPCs could intercept Interact at the shafts; and the objective covered
paused dialogue and combat feedback. Placement now clears other interaction
points by 180px. Shared encounter panels hide during overlays, fade when
covering the hero or target, and sit above ability notices and buff timers.

Validation:

- Desktop import, compile 208, quick 119 and full 199 pass. Mobile import,
  compile 208 and strict quick 119 pass. All 27 frozen source/art/rig paths
  match mobile; eight GDScript UID pairs are independently minted.
- Eleven desktop plus eleven mobile functional/purchase captures pass,
  including actual gear, potion and recall purchases and stale callbacks.
- Eight desktop plus eight mobile real ENet captures pass: late joining
  unfinished work, guest pulls/kills, identity/rate/reach checks, forged
  benefit rejection, live prices, exact home-save comparison, completed-world
  rebuilding, party travel and the production session-end handler.
- Final normal starting-kit combat passes on mobile warrior (36.3s, minimum
  119/130 HP, 78% load) and desktop mage (30.6s, 90/90 HP, 84% load).
  Earlier warrior/mage probes also passed. Combat uses ordinary keyboard
  movement and abilities, with no injected damage or debug advantage.
- Nine shared-objective captures on each renderer, twelve existing escort
  captures and thirteen ward captures pass. Their active, interrupted and
  completed states retain clear party-health and touch-control placement.
- Full preflight reports no failures and one existing balance warning; Codex
  data passes. The established renderer shutdown diagnostics and existing
  full-suite malformed-code fixture/bare ObjectDB warning remain in logs.

The mobile checks use the mobile source and Compatibility renderer on the
Windows development host; no physical Android or iOS device was used. Cart,
pressure, touch, purchase, co-op and normal-combat views were inspected.

The 77 explicit checkpoint paths are in build/qa/caravan-stage-paths.json;
source hashes are in caravan-source-freeze.json and capture paths/metrics in
caravan-visual-validation.json. Logs and earlier failed-run evidence live
under build/qa/caravan-*. Further HUD candidates are documented separately
in build/qa/hud-default-camera-audit.md.
