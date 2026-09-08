# HUD clearance — validated pass 27

Default camera framing and smoothing still let the upper-left information
block cover a hero near the north-west room boundary. The baseline screenshot
rig reproduces this with normal health and camera settings. The new UI module
fades only the information backdrop and its identity/gold/Combat Rating/
Resonance display when it covers the hero or current visible target. Health,
mana, experience, party frames and all utility/action buttons stay visible.
The information returns when the character moves clear or an overlay opens.
Combat & comfort includes a HUD visibility toggle.

The geometry uses the hero renderer's class body height and +22px foot anchor,
and the enemy renderer's existing head/bar metadata. It adds no image buffers
or scans through unseen actors. Short release hysteresis avoids flicker at a
panel edge. Self-modulation preserves existing information color effects.
Ownership and current-world checks exclude foreign and retired enemy actors.

A second confirmed issue was the ability notice covering the top of buff
icons. The lower-center slots now leave gaps: optional objective y428..528,
ability notice y534..568, buffs y578..626, then abilities at y634.

Validation completed September 8, 2026:

- Desktop import, compile 210, quick 119 and full 199 pass.
- Mobile import, compile 210 and strict quick 119 pass.
- Twelve desktop and twelve mobile HUD captures pass: body overlap/recovery,
  target-only coverage, touch, preserved vitals/buttons/color, readable menus
  and popovers, settings, and foreign/retired/freed target guards.
- Nine desktop and nine mobile real-ENet company captures pass: shared escort
  and ward objectives remain clear of party health, controls, notices and buffs.
- Starting-kit keyboard combat passes with archer (41.1s, minimum 22/100 HP,
  load 64%) and paladin (35.8s, minimum 61/125 HP, load 51%). Seven captures
  each; normal health and no injected combat damage.
- Ten frozen desktop/mobile source mirrors and three independent UID pairs
  verified. Full preflight: zero failures, one existing game.gd balance warning.

The before/after body views, Comfort menu, notices/buffs, live combat and party
views were inspected. Seven representative originals are copied unchanged to
build/qa/hud-clearance-reviewed. No artwork changed. Mobile visual checks use
the mobile project and Compatibility renderer on the development host; this
is not a physical Android/iOS test. The established renderer shutdown messages
and full suite's malformed-input fixture/bare ObjectDB warning remain.

Evidence under build/qa/: hud-clearance-source-freeze.json,
hud-clearance-stage-paths.json (29 explicit paths),
hud-clearance-visual-validation.json (capture paths and combat metrics),
hud-clearance-second-quick.log, hud-clearance-desktop-full.log,
hud-clearance-mobile-{import,compile,quick,verdict}.log,
hud-clearance-{verify-first,mobile-visual,desktop-archer,mobile-paladin,
desktop-company,mobile-company}.log and hud-clearance-preflight.log.
Baseline/prototype evidence: hud-default-camera-audit.md and the corresponding
hud-clearance-baseline/first logs. Pass 26's index was preserved throughout.
Included with the caravan in the user-requested checkpoint
`Add caravan defense and improve HUD visibility`, following commit 99668d4.
