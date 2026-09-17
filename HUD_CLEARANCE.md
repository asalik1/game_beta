# Quest and target clearance — September 17 validated checkpoint

The complete quest/target family now moves down when it covers the local hero,
current target or a casting boss and a clear lane is available. Text, health,
cast instructions and target cues move together; vitals and controls stay put.
It uses the existing HUD visibility preference and returns to its ordinary
layout for menus, cinematic views, popovers and disabled visibility assistance.
Room/world changes discard the retained placement. A short release delay and
retained valid placement avoid chasing small body movements.

The search reserves other HUD panels, party frames, encounter space, and the
currently selected visible interaction prompt and its explicit NPC sprite.
It reuses the existing body proxies and performs no texture readbacks. Normal
unblocked views skip interaction shaping and candidate search. If no complete
lane fits above the encounter area, it preserves the ordinary readable layout;
this does not guarantee body clearance in every crowded composition. Unselected
NPCs and decorative world labels are not reserved.

Moving a cast header exposed a first-render bug: its recorded world brackets
inherited a later pre-draw translation. Brackets now draw in an independent
canvas item owned by the same readout, retaining its state and visibility.
Its lower draw order keeps world brackets beneath HUD panels and white text.
A separate native pixel control reproduced 22 gold-over-white glyph-core
pixels before that correction; fixed desktop/mobile controls measure zero.
The shared HUD geometry fixture also restores the new placement cache, with
an actual post-draw restoration check.

Validated on September 17. Desktop quick/full pass 145/225; mobile import,
compile (274 scripts) and strict quick pass 145. Final desktop and host mobile
with touch controls each pass 365 presentation checks, 29 first-frame bracket
checks and the rendered text-core control. The old bracket route reproduces
three roughly 115px shifts; fixed recorded transforms have zero error. Native
HUD alignment/restoration passes 197 checks on each project. Existing cast and
real local ENet, HUD visibility, default framing and capital arrival regressions
pass. The latter three preceded the final bracket draw-order change; final cast,
alignment and focused desktop/mobile controls use the exact final source.
Thirteen source mirrors and full strict preflight pass. Root opened 153 native
originals across accepted and rejected evidence, including all 61 final desktop
and mobile images. Source and selected images also received independent review.
See `build/qa/session-sept17/north-edge-checkpoint-validation.json` for the commit,
owned paths, source/evidence hashes, preservation audit and exact limitations.

Scope: initial room placement, quiet existing world, removed enemies and delayed
ambient hazards; subsequent walks use held keyboard input with live physics.
Extended long text, borrowed real Talk NPC, lateral frozen wolf/Morwen and direct
cast-model calls are presentation controls, not earned progression or combat.
Target controls use the real zero-camera-lead preference; target zoom remains
live. Default-lead edge composition is a separate investigation. The rejected
first extended run retains three cast/no-space failures; its boss body obstructed
the available lane. The accepted positive fixture poses Morwen farther laterally.
No physical-device, universal actor/prompt clearance or performance benchmark is
claimed. The far-right frozen mobile boss remains partly behind touch buttons;
this change moves the tracker, not actors or controls. Existing arrival-title/Talk,
Tovin/table-caption and stacked damage/break callout overlap remain.

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
