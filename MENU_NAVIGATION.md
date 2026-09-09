# Menu navigation and text entry

Owner: root, September 9–10 autonomous session. Initial production checkpoint:
`a47809b0f238efe5a94620bb1f2ead0a121810b1`. The accepted source and commit
identity are recorded in `build/qa/session-sept10/menu-checkpoint-validation.json`.

## Player-facing changes

Settings returns to its opening roster or Pause screen. Comfort, Controller
and Keybinds return to Settings. Escape, controller Back, the shell X and an
outside click use the same existing navigation routes. Ordinary inventory
closing still returns to play.

Cancelling a confirmation uses its caller's return path. Keeping an unclaimed
letter returns to that letter with its attachments intact. A confirmation's
action belongs to its original shell and cannot act on a replacement panel.

Editable text fields receive their text even when a character matches the
screen's shortcut. Talent loadout names can contain T and a remapped Skills
key. Escape retains normal navigation. Leaving Keybinds through its explicit
Back button ends pending remapping before another key can change a binding.

Outside dismissal accepts one primary pointer press. A touch uses its emulated
mouse event when enabled, or its raw touch event otherwise; it cannot dismiss
the parent panel with the same tap. Wheel scrolling outside a panel leaves it
open.

## Native reproduction and checks

Run `shot.bat menu_navigation --timeout=300` with isolated APPDATA. Add
`--mobile --renderer=gl_compatibility` for the mobile project on this host.
The rig covers both touch-emulation settings, keyboard text, remap cancellation,
actual controller B events, pointer X/Back/Cancel/outside actions, complete mail
payload preservation and settings restoration. Desktop and touch Settings
containment are measured and photographed.

The fixture opens real menus on a no-saves Game, drives actual input events,
and poses a disposable letter/hero. These are controlled UI checks. The
separate starting-kit mage caravan run uses real keyboard combat and movement
with normal health; it is ordinary combat within a seeded encounter fixture.
No physical-device result is claimed.

Initial native production reproduced 24 navigation/typing findings in 142
checks, with zero fixture/runtime failures. The first candidate passed 140 of
146 checks but failed six touch return checks and was rejected. An expanded
probe of that partial revision reproduced the six touch failures plus stale
binding capture and both wheel directions: 158 checks, nine expected findings,
zero fixture/runtime failures. Final desktop and mobile acceptance each pass
158/158 checks without `--baseline`: 61 mouse clicks, nine touch taps, 40 key
taps, two wheel events and two controller Back presses per run. All sixteen
final menu frames were reviewed; the typed talent name and complete cancelled
letter remain intact. Independent review accepted the production diff.

Desktop quick (126 checks) and full (206 checks) pass. Mobile import, compile,
strict quick (126 checks), and scoped source synchronization pass. The existing
controller rig passes analog movement, buffered triggers, overlay release,
pointer drag/scroll, virtual keyboard, dialogue, fishing and disconnect checks.
Online-menu regression passes 67/67 on each project. Its solo and empty-loopback
host cases use actual GUI input; the victory state is synthetic. It does not
claim remote-peer delivery. All nine controller and twelve online-menu frames
were reviewed, for 37 accepted native frames in this checkpoint.

Logs and images are under `build/qa/session-sept10/`, named `menu-after2`,
`menu-mobile-native`, `menu-controller`, and `menu-online-desktop/mobile`.
Earlier failed and baseline runs remain separate. Native renderer shutdown
diagnostics use the established screenshot verdict; the full suite's deliberate
invalid-base64 case and bare timer/ObjectDB teardown warning retain the existing
headless verdict. No gates were weakened. Full preflight passes all seven
categories with zero findings. The 32 unrelated file hashes remain unchanged.

These changes repair navigation and preserve layout. The current touch Settings
screen still has several controls below the 44px target; that is separate
presentation debt, not a claim of complete physical-device usability.
