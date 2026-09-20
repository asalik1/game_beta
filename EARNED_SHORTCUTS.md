# Earned shortcuts and corridor travel

Chapter 1 can gain one optional connection between neighboring rooms that
previously required at least three passages to reach each other. Reach the
deeper endpoint by the original route, secure its encounter, then use the
winch to open a shorter return route for the party. The winch remains as a
landmark. Some layouts have no suitable connection.

The selector reads the completed seeded graph without consuming randomness.
At least one endpoint must be a side room. Boss rooms, disconnected pockets,
Waking/Unlisted rooms and unplaced rooms are excluded. Removing every edge
protected by an authored lock must leave the endpoints in the same component: the shortcut cannot
replace progression through a story gate. The longest saving wins, with
stable index tie breaks. Weekly Chapter 1 uses the same rule.

Each entrance has visible bars inside its playable room. Six rectangles on
one shared body block both ends; short returns connect the bars to existing
walls. Opening disables all collision together, then fades the assembly.
Ground and canopy reservations keep the entrances readable. The supported
painted winch has collision only at its stone footing, and remains independent
of terrain decoration repaints. Its selected prompt chooses a nearby position
that clears the visible HUD, hero and winch; an unavailable fit preserves the
complete authored label. The gate uses separate painted front and side views.

Closed bars also stop limited teleports at the first safe point on their path.
This restriction applies only to shortcut barriers: Blink can still pass over
ordinary scenery. Paladin's separate Judgment leap uses the same restriction.
Saved arrivals use the room center as a trusted origin so older positions cannot
restore a character inside or behind a newly introduced closed mouth. Opened
gates leave saved positions unchanged. This is not general terrain recovery.

Keyboard, controller and touch use the ordinary interaction path. Online,
the host resolves the requesting member's current body and checks chapter,
seed, world identity, living state, room, distance and encounter clearance.
Generic guest flag writes cannot open shortcuts. The run flag participates
in normal world saves/snapshots and resets on replay; it is not kept personal
history. Network version 0.3.18 prevents mixed graph/protocol sessions.

Open doorways now accommodate the camera between the two room interiors.
Only the actual reciprocal, unlocked doorway lane widens the limits; the view
returns to the room's normal bounds as the hero moves inside. Target framing,
zoom, lead, shake and smoothing retain their existing settings. This also
repairs ordinary corridors and touching room boundaries. Encounter seals and
movement rules remain independent of this presentation change.

An unvisited destination previews its matching floor and entrance walls, with
no collision, actors, encounter initialization or discovery changes. The same
floor builder serves normal room construction. The preview retires when the
room builds or the approach is abandoned, and belongs to the current world.
It is an entrance preview, not complete scenery or actor preloading.

## Validation and limitations

Accepted after desktop compile/quick/full, scoped mobile sync/import/compile/
strict quick, renewed native desktop/mobile checks, network admission and all
seven strict preflight categories. Exact source, log, receipt and original-image
hashes are in `build/qa/session-sept20/shortcuts-checkpoint-validation.json`;
the commit and remaining local state are in `shortcuts-commit-receipt.json`.

- Graph census: seeds 1000–1199, 216 grouped checks, zero failures. It finds
  191 candidates (143 with an original three-edge walk, 48 with five) and nine
  empty layouts. This does not prove global optimality or empty-seed infeasibility.
- Final desktop and host-mobile solo runs each pass 32 checks/10 originals;
  both paired axes each pass 33/18 on each platform. Native input, current
  party-member authorization, opening, save/load and traversal are exercised.
- Blink/save arrival passes 42 checks/10 originals, Paladin 23/4. Closed mouths
  stop crossings; open gates and ordinary-scenery teleport semantics persist.
  Historical unsafe saved positions are synthetic controls, not natural saves.
- Continuous camera checks cover ordinary and shortcut lanes, both directions,
  N/S and E/W, prebuilt and first-visit/return construction. Lazy runs pass 32
  checks/12 originals per axis; prebuilt N/S passes 24/12. Full-suite geometry
  tests cover asymmetric and touching bounds, lock/exits, zoom and lifecycle.
- Hot arrivals pass 15 checks/four originals per axis on desktop/mobile with
  live enemies and vulnerability. No incoming hit was recorded. Existing
  north-edge/combat-framing/control tests also pass on desktop and mobile.
- Actual ENet admission passes 34 checks: 0.3.18 admits, 0.3.17 is rejected.
  Paired gameplay runs use two readers in one engine. This does not add
  anti-teleport security to the existing owner-authored movement model.

All final and supplemental original images were opened and reviewed. Local
heroes and carried weapons remain visible in the accepted crossing captures;
interaction labels clear the hero/HUD. Supplemental closed gate caps and some
remote actor/edge-contact poses still overlap HUD. Hot arrival chest/prompt and
foliage overlap remain separate follow-up issues. Entrance previews do not
preload complete decoration or actors, so these appear with normal room builds.
The sampled first-hot E frame is nearly black under the existing first-visit
0.55s title fade; the settled frame is clear. The minimap briefly retains its
previous status. These transitional frames are not visual-clarity acceptance.

The live default-camera hunt wins in 31.269s and earns 120 gold, with starting
stats unchanged. HP stays 130: no incoming-hit claim. Card/body overlap,
fence/sign occlusion and dying-target edge framing make its four images
functional regression evidence only, not general combat visual acceptance.

These are controlled fixtures with disclosed position/clearance/resource loans.
The ordinary seed991652 attempt reached level2 then stopped at an unrecognized
teaching dialogue; it did not reach a shortcut. Its partial saves/images and
the older Fangmaw brewing defeat remain preserved. Host Compatibility mobile
checks are not physical-device tests.

Rejected drafts, failed fixtures and rejected visual passes remain under
`build/qa/session-sept20/claude-shortcuts/`, including the offscreen-corridor
baselines and the first correction's gray unloaded ground. A ratio-rounding
false failure is retained; viewport clipping now uses strict signed margins
without tolerance. Expected malformed-code base64, established shutdown
diagnostics and soft-alpha art warnings remain disclosed, not warning-free.

Actual Claude supplied the initial shortcut implementation; root and reviewers
revised it. Actual DeepSeek supplied QA and movement candidates, independently
corrected before integration. Later Claude camera attempts timed out without
code; the camera/entrance-preview correction is Codex-authored. Raw provider
outputs and rejected drafts remain attributed. Private Inventory and generic
prompt candidates are not part of this checkpoint.
