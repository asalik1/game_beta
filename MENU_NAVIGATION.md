# Menu navigation and text entry

Owner: root, September 9–10 autonomous session. Initial production checkpoint:
`a47809b0f238efe5a94620bb1f2ead0a121810b1`. The accepted source and commit
identity are recorded in `build/qa/session-sept10/menu-checkpoint-validation.json`.

## September 21 pause layout update

Checkpoint 18 passes desktop compile/quick/full, mobile import/compile/strict
quick, scoped synchronization and strict preflight (all seven categories).
Native desktop and host-mobile runs each pass 318 pause checks, 371 confirmation
checks, 64 paired ENet UI checks and 149 four-reader party checks. All 112 final
original images were reviewed, including 15 opened by root. The desktop party
run is reused only with identical five-file source hashes; the other final
stages ran from frozen source snapshots. Exact evidence and limits are in
`build/qa/session-sept20/pause-layout/checkpoint-validation.json`; its
`commit-receipt.json` binds the committed checkpoint and preservation audit.
The September 9–10 results below remain historical evidence.

Pause now uses readable 18px actions with at least 44px targets, a measured
height capped at 650px, and a shared desktop/touch scrolling action list.
Resume (Return to game online) and the dismissal hint remain fixed. Long
party-removal names wrap without changing their complete text. Shorter menus
shrink around their content. Existing actions, confirmations and caller return
paths remain intact; online play continues running behind the overlay.
Keyboard entry starts on the safe Resume action after synchronous fitting;
touch and the active controller pointer retain their existing behavior.

Run `shot.bat menu_navigation --pause-layout --timeout=300` with fresh isolated
APPDATA under `build/qa/`. This strict opt-in mode covers campaign, actual
capital travel and a controlled trial-availability flag, each in desktop and
host-emulated touch mode. It observes first/settled text and action geometry,
safe initial focus, fixed controls, actual wheel/touch scrolling when content
overflows, Settings return and dismissal routes. No-overflow cases are recorded
as such. It does not start or cash out a trial, restart, remove a player or quit.
Economy checks bracket menu interactions; legitimate loot recovery during
capital travel is observed separately. Existing navigation tests remain a
separate default run. Add `--mobile --renderer=gl_compatibility` for host mobile
source; neither rendering nor emulated touch is physical-device testing.

Run `shot.bat brewing_persistence --party-pause --timeout=450` with isolated
APPDATA inside a `brewing-persistence-candidate` directory. This strict mode
uses one engine with a real ENet host and three real guests, production
snapshots and three controlled 64-character names. It observes wrapped rows
from first draw through settlement, native focus/scrolling, fixed Return/hint,
host removal-confirm cancellation and session/economy preservation. Hidden
guest readers do not consume the host's UI events; their worlds and transport
remain live. Mouse-emulated touch scrolling and raw-touch cancellation are
distinct checks. Cancelling removal must return to Pause, not close it. The
same mobile flags render mobile source on the host. These are controlled
network/UI fixtures, not ordinary co-op combat or earned progression.
The unchanged `--ui-only` 64-check episode remains a separate regression run.
Touch scrolling uses the engine's [mouse-event path](https://raw.githubusercontent.com/godotengine/godot/4.4-stable/scene/gui/scroll_container.cpp); raw outside cancellation is tested independently.

Actual Claude Opus 5 supplied the production layout draft in a bounded
medium-effort CLI call after an earlier max-effort attempt timed out without
usable code. Actual DeepSeek Flash supplied QA drafts; independent review
corrected unsupported assumptions and strengthened the existing rigs. Raw
provider input/output, independent corrections and rejected runs are retained
under `build/qa/session-sept20/pause-layout-candidate/` and `pause-layout/`.
The first old-code probe mixed layout failures with QA errors in native AUTO
text direction, touch capability and cross-world economy scope; its corrected
successor retained strict layout failures. Party pilots v1–v3 are not accepted:
input routing/touch setup and cancellation expectations required correction,
and the later focus trace exposed a real missing keyboard-entry focus. The
safe Resume focus fix is production behavior, not a test-assigned focus waiver.

The 64-character stress fixture also exposes separate existing spill from
compact party HUD names and overhead world labels. Pause wrapping does not fix
those surfaces; see the private `party-name-audit/` follow-up record. No broad
HUD, artwork or target-information approval is implied by this checkpoint.

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
