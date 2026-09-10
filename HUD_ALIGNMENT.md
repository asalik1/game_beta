# HUD alignment and ground warning clarity

The stat row uses one 14px body face in 20px slots. The coin is a separate
label: its fallback font has a taller ascent, so keeping it inside the gold
number's text moved the digits down even after matching font sizes. Both the
coin and the value retain the Gold popover and participate in the existing
HUD fade. Combat Rating and Resonance retain their measured chip widths.

The quest tracker owns a measured, wrapping panel beside the vitals. Its
height follows the complete objective; an empty objective leaves just the
location. Target bars move beneath the panel, with the boss portrait and
level also clearing the dossier. The cast readout follows that offset while
converting its world brackets back into local coordinates, preserving their
attachment to the actor.

Ground warnings use an analytic colored rim, a soft halo and a tapered bright
head driven by the existing attack progress. A thin chromatic core preserves
the boundary over pale ice and lava. The old scaled 64px fill edge and thick
black outline are removed. Intact terrain props have a quiet 5.4-second orbit;
priming hides that marker and shows the real fuse. Shelter chevrons and decoy
pulses remain. Radius, fuse duration, damage, status effects, cancellation and
network authority retain their existing owners and rules.

The shader rejects transparent interior/exterior rim fragments before angular
and exponential work. It uses no screen read, particle system or per-frame
image allocation. This is not a frame-rate benchmark.

## Regression checks

`scripts/tests/hud_alignment_geometry.gd` is shared by the quick/full suites
and `shot_hud_dossier --alignment`. It measures shaped text, complete values,
chip containment, panel/target clearance and visible cast text. Numeric
baselines use the entire shaped line's ascent, including fallback fonts.
Cases cover the reported strings, large values, signed resonance, an empty
objective, mob/boss/rival targets and a frozen native cast fixture.

Negative controls displace CR by eight pixels and move the tracker onto the
vitals, then require detection and exact restoration. Restoration skips
unchanged Control properties because even an unchanged `set_size()` clamps
hidden controls to their minimum size. Full snapshot equality remains required.

The headless suite sizes its dummy window to the configured logical viewport
before creating the game. Godot's default 64x64 window otherwise sets font
oversampling to 0.05 and reports a false 28px height for the 14px body font.
A small probe reproduced that behavior and showed the configured 1280x720
window restores the same 15px font height as native rendering. No font or
containment tolerance is altered to make the checks pass.

The full campaign exposed a pre-existing timing assumption in the Vargoth
enrage test: forty process frames need not cover his committed cast. The test
now observes for at most three seconds, retains the real damage/cast path,
checks that the living boss crossed 30% health, and records cast state and
elapsed time. The original failing log has no cast-state receipt, so its exact
phase cannot be reconstructed. Boss gameplay is unchanged by this test fix.
The subsequent full run recorded Vargoth at 20% health with 1.40 seconds of
windup remaining, then observed his real enrage after 1.722 seconds.

The screenshot runner rejects script and shader errors from either output
stream, even after a successful completion marker. Its 26 fixtures include
bare shader errors and compilation failures in stdout and stderr.

## Reproduce

Use a fresh isolated APPDATA directory for each windowed run.

- `shot.bat hud_dossier --alignment --timeout=240`
- `shot.bat tells --comet --fixed-fps=30 --timeout=240`
- Add `--mobile --renderer=gl_compatibility --touch` for the mobile HUD.
- Add `--mobile --renderer=gl_compatibility` for mobile warning rendering.
- Add `--motion --timeout=360` to the comet run for 81 native orbit crops
  sampled at 15fps, alongside the 15 full frames.

The warning fixture samples actual production clocks; it checks radius,
progress, pause, priming, falling-object movement and cancellation. Its
controlled room setup is presentation evidence, not ordinary combat input.
The HUD text/cast fixtures are likewise posed layout evidence, not rewards or
an attainable-build claim. Mobile captures use the mobile project on the
development host, not a physical Android/iOS device.

## Validation

Accepted native evidence under `build/qa/hud-comet-fix1/`:

- `desktop-hud-after3` and `mobile-hud-after1`: six frames and 196 checks each,
  zero failures or presentation findings. Matching gold/CR digits occupy the
  same native ink rows; the geometry checks report the same numeric baseline.
- `desktop-comet-after2`: fifteen frames and 126 checks, zero failures.
- `mobile-comet-after1`: fifteen full frames, 81 native orbit crops and 292
  checks, zero failures. Both offline report verifiers pass. The final GIF is
  288x240, has 81 frames, and preserves the 5.4-second orbit with alternating
  70/60/70ms frame durations. The cask naturally occludes the upper arc/wrap.
- `desktop-reactive-after1`: eight frames and the existing live melee,
  projectile, damage/chill, chain-fuse, pause, spent rebuild, touch and ENet
  request/state assertions pass. The hidden ENet mirror has no separate guest
  image; the forced-touch frame does not claim refreshed quest copy.

All 50 accepted full native frames and 81 motion crops were visually reviewed.
Native renderer texture/singleton shutdown diagnostics remain the established
runner exemptions; no script or shader failure is accepted. The full suite's
intentional invalid-base64 case and ObjectDB warning retain their existing
verdict treatment.

Desktop compile 232 scripts, quick 126 and full 206 reported check groups pass.
Mobile compile 232 and strict quick 126 pass. Full preflight and the 26
screenshot-verdict fixtures pass. Source/mobile hashes, independent UIDs and
unrelated-file preservation are recorded in
`checkpoint-validation.json` alongside phase-local reviews and log hashes.

Earlier failing probes, the first full run and the rejected faint comet
revision are retained and excluded from acceptance. Desktop HUD after3
preceded a QA-only conditional restoration guard; production HUD code is
unchanged. The intermediate accelerated GIF is excluded from the final preview.

## Team and Settings column — September 10 follow-up

The Team shortcut now uses the same horizontal column calculation as the
Settings gear beneath it. Its previous independent x300 anchor was eight
pixels right of Settings at x292. Both buttons remain 44px square, with Team
at y80 and Settings at y128, preserving the 4px gap. Their callbacks and
online visibility behavior are unchanged.

The existing default `shot.bat hud_dossier --timeout=300` now also measures
the shared center line, vertical gap and clearance from identity/stat text
targets. It still exercises all eight utility buttons through actual input,
including Team opening the party panel and Settings opening Pause. The
baseline records 521 checks: 512 passes, nine expected 8px alignment
observations and zero unexpected failures; 22 full images cover its controlled states and
actual menu/popover access. Geometry is measured even while Team is hidden;
two baseline images show the live host's Team button. Three remote shells
are synthetic layout fixtures, not peer-replication evidence.

Final desktop and mobile each pass 557/557, zero failures/findings, with 22
full images per project independently reviewed. Root reviewed three baseline
images and six per final project: long identity, high values, both visible
party states and actual Team/Settings access. All nine measured offsets are
zero, the gap remains 4px and all 36 label target-clearance checks pass. The
other seven utility and four label rectangles retain their baseline positions.
Desktop uses real mouse input; mobile source uses ScreenTouch on the Windows
Compatibility renderer, not physical-device execution. Both restore controlled
state and record no persistent writes. High values are measured offline;
there is no combined online/extreme-value frame or peer-replication claim.

Desktop compile/quick/full (253/143/223), mobile import/compile/explicit strict
quick (253/143), native compile (255) and all seven preflight categories pass.
The existing mobile Party footer's malformed “tapSC” wording is recorded as
a separate pre-existing follow-up; this coordinate correction does not alter
copy. Exact sources, review scopes, artifacts and commit are recorded in
`build/qa/session-sept10/party-column-checkpoint-validation.json`.
