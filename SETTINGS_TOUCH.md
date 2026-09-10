# Settings touch layout

Accepted after `dedc07a`, with matching desktop/mobile source. Exact commit,
source hashes and gate artifacts are recorded in
`build/qa/session-sept10/settings-touch-checkpoint-validation.json`.

## Behavior

Touch Settings, Combat & comfort and Controller use a scrolling content area
with Back and the exit hint outside it. Buttons and sliders have at least a
44px target in the game's virtual viewport. Labels align vertically with their
sliders. Desktop Settings, Controller and Keybinds retain their existing
compact layouts. Comfort also scrolls on desktop: its existing list overflowed
the 660px panel and placed the exit hint beneath the shell. The panel and
desktop control sizes remain unchanged while Back and the hint now stay inside.

Touch Keybinds uses the existing scrolling list with larger action buttons.
Selecting an action keeps that row visible while waiting for a key. The screen
is an attached-keyboard case; touch Settings still hides its keyboard entry.
Options, bindings, settings persistence and navigation destinations retain their
existing behavior. The change is scoped to the Settings family, without a
global widget/theme size change.

## Validation scope

Run the existing muted, compile-gated menu rig with isolated APPDATA:

```powershell
.\shot.bat menu_navigation --settings-touch --baseline --timeout=180
.\shot.bat menu_navigation --settings-touch --desktop-comfort --timeout=180
```

The focused scenario measures 59 content targets, or 68 with the desktop
Comfort supplement: desktop Settings and Keybinds, optional desktop Comfort,
then touch Settings, Comfort, Controller and Keybinds. It checks full
control containment, button captions, a tap near the music slider's edge,
touch child/Back navigation, scrolling and cancellation of the last keybind.
Programmatic reveal is geometry setup; a separate gesture checks body dragging.
Eight full native views, or nine with desktop Comfort, show the representative
panels and scroll positions.
It loans one music setting and restores live settings/bindings; this is not a
save-persistence test. Mobile native runs render the mobile source on Windows,
not physical touch hardware.

The first baseline is rejected: 222 checks, 183 passes, 38 expected presentation
findings and one unexpected Keybinds drag failure. All eight images were
reviewed by root. Godot's Windows ScrollContainer requires the touchscreen
capability flag for emulated mouse dragging; the original probe set only the
opposite emulation flag. Corrected before2 passes 223 checks: 185 pass, 38
expected presentation findings and zero failures. The trace records capability
false to true, one scroll-start and the complete 41px Keybinds scroll range.
Both emulation flags are restored afterward. All eight images have root and
independent review. The exact engine gate is in
[Godot 4.4.1 ScrollContainer](https://github.com/godotengine/godot/blob/4.4.1-stable/scene/gui/scroll_container.cpp#L154).

After2 installs the touch candidate while retaining the desktop Comfort
baseline. It passes 254 of 255 checks; the sole expected finding is the
desktop hint at y697 below a panel ending at y693. All touch targets, captions,
navigation, slider-edge activation, body gestures and capture visibility pass.
The subsequent Comfort change uses the same scrolling body on desktop.

An earlier after1 preview was deliberately stopped before screenshots/report
because root started it before the quick suite exited. That rejected run is
retained; final serial gates supersede the overlapping quick run.

Exact logs, source freezes, reports and images are retained under
`build/qa/session-sept10/settings-touch-*`.

Final desktop after3 and mobile after1 each pass 255/255 checks, zero findings
and zero failures. All nine full native images per project have root and
independent review. The 37 touch targets measure 44px high, the slider-edge
tap sets music to 50%, all four body drags start scrolling, and the last
binding remains visible during capture and Escape cancellation. The binding
capture state is verified at runtime; its bottom-row image precedes capture.
The desktop Comfort hint now sits at y656–670 inside the panel. Rows partially
clipped at a scroll boundary are normal; individual revealed controls also
pass full containment and caption checks.

The broader desktop menu regression passes 158/158, with all eight native
images reviewed by root. Final serial desktop quick/full pass 143/223; mobile
import/compile (253 scripts)/explicit strict quick (143), native compile gates
(255 scripts) and all seven preflight categories pass. Existing accepted
renderer shutdown diagnostics remain. These fixtures establish host-rendered
geometry and emulated input behavior; they do not establish physical-device,
controller coexistence, settings disk persistence or ordinary gameplay results.
